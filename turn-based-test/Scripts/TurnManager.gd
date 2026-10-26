@tool
extends Node2D

const PLAYER_ACTOR_SCENE = preload("res://scenes/actor_player.tscn")

signal turn_changed(is_player_turn: bool)
signal game_over(player_won: bool)

var tile_map: TileMapLayer = null
var grid_layer: TileMapLayer = null
var friendly_actors: Array[Actor] = []
var enemy_actors: Array[Actor] = []
var friendly_remaining_moves: Array[Actor] = []
var selected_actor: Actor = null
var actor_start_global_pos: Vector2 = Vector2.ZERO
var reachable_cells: Dictionary = {}

enum Turn { USER, AI }
var current_turn: Turn = Turn.USER

enum Phase { MOVE, ATTACK }
var current_phase: Phase = Phase.MOVE
var highlighted_cells: Array[Vector2i] = []
var is_processing_move: bool = false

const TILE_SOURCE_ID = 0
const HIGHLIGHT_ATLAS_COORDS = Vector2i(0, 0)
const ATTACK_ATLAS_COORDS = Vector2i(1, 0)

var ui_layer: CanvasLayer = null
var end_turn_button: Button = null

# ✅ Custom attack cursors based on damage type
const CURSOR_SWORD = preload("res://ART/cursors/sword.png") # Physical damage
const CURSOR_MAGIC = preload("res://ART/cursors/wand.png") # Magic damage
const CURSOR_DEFAULT = preload("res://ART/cursors/arrow.png") # Normal arrow (optional fallback)
const CURSOR_HOTSPOT = Vector2(16, 16)

@onready var combat_ui: Node = get_node_or_null("../CombatUI")

func _ready() -> void:
	if Engine.is_editor_hint(): return

	tile_map = get_parent() as TileMapLayer
	grid_layer = tile_map.get_node_or_null("GridLayer") as TileMapLayer

	if not combat_ui:
		combat_ui = get_tree().root.find_child("CombatUI", true, false)
		if combat_ui:
			print("✅ Found CombatUI via search: ", combat_ui.get_path())
		else:
			print("⚠️ CombatUI not found in scene tree!")

	_create_end_turn_button()

	for child in get_children():
		if child is Actor:
			register_actor(child)

func register_actor(actor: Actor) -> void:
	if actor.is_friendly:
		friendly_actors.append(actor)
	else:
		enemy_actors.append(actor)
	actor.died.connect(_on_actor_died)

func _on_actor_died(actor: Actor) -> void:
	friendly_actors.erase(actor)
	enemy_actors.erase(actor)
	friendly_remaining_moves.erase(actor)
	if selected_actor == actor:
		selected_actor = null
		_clear_highlight()
		current_phase = Phase.MOVE
	actor.queue_free()
	_check_win_conditions()

func initialize_game() -> void:
	_snap_all_actors_to_grid()
	_start_new_round()

func _start_new_round() -> void:
	current_turn = Turn.USER
	current_phase = Phase.MOVE
	selected_actor = null
	_clear_highlight()
	friendly_remaining_moves = friendly_actors.duplicate()
	print("⚔️ Наступил Ваш ход!")
	turn_changed.emit(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover_stats()
		if current_turn == Turn.USER and tile_map:
			var target_cell = tile_map.local_to_map(tile_map.get_local_mouse_position())
			_update_attack_cursor(target_cell)
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			if current_turn == Turn.USER and not is_processing_move and selected_actor != null:
				_complete_actor_turn()
			return
		if event.is_action_pressed("end_turn"):
			_on_end_turn_button_pressed()
			return

	if Engine.is_editor_hint() or is_processing_move or current_turn != Turn.USER:
		return

	if event is InputEventMouseButton and event.pressed:
		var target_cell = tile_map.local_to_map(tile_map.get_local_mouse_position())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_current_action()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(target_cell)

func _cancel_current_action() -> void:
	if current_phase == Phase.ATTACK and selected_actor != null:
		selected_actor.global_position = actor_start_global_pos
		selected_actor = null
		_clear_highlight()
		current_phase = Phase.MOVE
	Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

func _handle_left_click(target_cell: Vector2i) -> void:
	if current_phase == Phase.MOVE:
		var clicked_friendly = _get_actor_at_cell(target_cell, friendly_actors)
		if clicked_friendly and clicked_friendly in friendly_remaining_moves:
			selected_actor = clicked_friendly
			actor_start_global_pos = selected_actor.global_position
			_highlight_available_moves(selected_actor)
			if combat_ui: combat_ui.update_player_stats(selected_actor)
			return

		if selected_actor:
			if target_cell in reachable_cells:
				is_processing_move = true
				var move_success = await _try_move_actor(selected_actor, target_cell)
				is_processing_move = false
				_clear_highlight()
				if move_success:
					_switch_to_attack_phase()
				else:
					_highlight_available_moves(selected_actor)
			else:
				_switch_to_attack_phase()

	elif current_phase == Phase.ATTACK and selected_actor:
		var actor_cell = tile_map.local_to_map(tile_map.to_local(selected_actor.global_position))
		if target_cell == actor_cell or not target_cell in highlighted_cells:
			_complete_actor_turn()
			return

		var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
		if target_enemy:
			var attacker = selected_actor
			var target = target_enemy
			
			await attacker.perform_attack(target)
			
			if is_instance_valid(attacker) and is_instance_valid(target) and not target.is_dead:
				# Добавлен await для корректного ожидания анимации получения урона
				await target.take_damage(attacker.attack_damage, attacker.attack_type)
				
				# 🔄 НОВАЯ ЛОГИКА: Ответная атака
				if not target.is_dead and target.class_data and target.class_data.can_counter_attack:
					print("🔄 %s выполняет ответную атаку по %s!" % [target.name, attacker.name])
					await target.perform_attack(attacker)
					if is_instance_valid(attacker) and not attacker.is_dead:
						await attacker.take_damage(target.attack_damage, target.attack_type)
						
			_complete_actor_turn()

func _switch_to_attack_phase() -> void:
	current_phase = Phase.ATTACK
	_highlight_attack_range(selected_actor)

func _complete_actor_turn() -> void:
	if selected_actor != null:
		friendly_remaining_moves.erase(selected_actor)
		selected_actor = null
		_clear_highlight()
		current_phase = Phase.MOVE
		Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		if friendly_remaining_moves.is_empty():
			await _end_user_turn()

func _on_end_turn_button_pressed() -> void:
	if current_turn != Turn.USER or is_processing_move: return
	if selected_actor != null and current_phase == Phase.ATTACK:
		selected_actor.global_position = actor_start_global_pos
		friendly_remaining_moves.clear()
		selected_actor = null
		_clear_highlight()
		current_phase = Phase.MOVE
	await _end_user_turn()

func _end_user_turn() -> void:
	current_turn = Turn.AI
	_clear_highlight()
	await get_tree().create_timer(0.4).timeout
	await _make_ai_moves_and_attacks()
	_start_new_round()

func _make_ai_moves_and_attacks() -> void:
	var active_enemies = enemy_actors.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead: continue

		var target_player = _find_closest_friendly(enemy)
		if not target_player: continue

		var ai_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
		var user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		var attack_range = enemy.class_data.attack_range if enemy.class_data else 1
		var total_distance = abs(user_cell.x - ai_cell.x) + abs(user_cell.y - ai_cell.y)

		if total_distance > attack_range:
			var move_range = enemy.class_data.move_range if enemy.class_data else 3
			var ai_reachable = _calculate_reachable_cells(ai_cell, move_range)
			var best_cell = ai_cell
			var best_distance = total_distance

			for cell in ai_reachable:
				var dist = abs(user_cell.x - cell.x) + abs(user_cell.y - cell.y)
				if dist < best_distance:
					best_distance = dist
					best_cell = cell

			if best_cell != ai_cell:
				print("🤖 %s moving to %s" % [enemy.name, best_cell])
				await _try_move_actor_direct(enemy, best_cell)
				ai_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))

		# Attack after moving
		user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		var final_dist = abs(user_cell.x - ai_cell.x) + abs(user_cell.y - ai_cell.y)

		if final_dist <= attack_range:
			print("🤖 %s наносит удар по %s" % [enemy.name, target_player.name])
			var attacker = enemy
			var target = target_player
			
			await attacker.perform_attack(target)
			await get_tree().create_timer(0.2).timeout
			
			if is_instance_valid(attacker) and is_instance_valid(target) and not target.is_dead:
				# Добавлен await для корректного ожидания анимации получения урона
				await target.take_damage(attacker.attack_damage, attacker.attack_type)
				
				# 🔄 НОВАЯ ЛОГИКА: Ответная атака
				if not target.is_dead and target.class_data and target.class_data.can_counter_attack:
					print("🔄 %s выполняет ответную атаку по %s!" % [target.name, attacker.name])
					await target.perform_attack(attacker)
					if is_instance_valid(attacker) and not attacker.is_dead:
						await attacker.take_damage(target.attack_damage, target.attack_type)

func _find_closest_friendly(enemy: Actor) -> Actor:
	var closest: Actor = null
	var min_dist = 99999
	var enemy_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
	for player in friendly_actors:
		if is_instance_valid(player) and not player.is_dead:
			var p_cell = tile_map.local_to_map(tile_map.to_local(player.global_position))
			var dist = abs(enemy_cell.x - p_cell.x) + abs(enemy_cell.y - p_cell.y)
			if dist < min_dist:
				min_dist = dist
				closest = player
	return closest

func _check_win_conditions() -> void:
	var live_friendlies = friendly_actors.filter(func(a): return is_instance_valid(a) and not a.is_dead)
	var live_enemies = enemy_actors.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	if live_friendlies.is_empty():
		game_over.emit(false)
	elif live_enemies.is_empty():
		game_over.emit(true)

func _get_tile_cost(cell: Vector2i) -> int:
	if not tile_map: return 1
	var tile_data = tile_map.get_cell_tile_data(cell)
	if not tile_data: return 1
	var cost = tile_data.get_custom_data("move_cost")
	if cost <= 0:
		return 9999
	return cost

func _calculate_reachable_cells(start_cell: Vector2i, max_cost: int) -> Dictionary:
	var reachable = {}
	var queue = [[start_cell, 0]]
	reachable[start_cell] = 0

	while not queue.is_empty():
		var current = queue.pop_front()
		var cell: Vector2i = current[0]
		var cost: int = current[1]
		var neighbors = [
			cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
			cell + Vector2i(0, 1), cell + Vector2i(0, -1)
		]
		for n in neighbors:
			if reachable.has(n): continue
			var tile_cost = _get_tile_cost(n)
			if tile_cost >= 9999: continue
			if _is_cell_occupied(n): continue
			var new_cost = cost + tile_cost
			if new_cost <= max_cost:
				reachable[n] = new_cost
				queue.append([n, new_cost])
				
	reachable.erase(start_cell)
	return reachable

func _highlight_available_moves(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var move_range = actor.class_data.move_range if actor.class_data else 3
	var source_id = _get_valid_source_id()
	reachable_cells = _calculate_reachable_cells(actor_cell, move_range)
	for cell in reachable_cells:
		grid_layer.set_cell(cell, source_id, HIGHLIGHT_ATLAS_COORDS)
		highlighted_cells.append(cell)

func _highlight_attack_range(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var source_id = _get_valid_source_id()
	var attack_range = actor.class_data.attack_range if actor.class_data else 1
	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var distance = abs(x) + abs(y)
			if distance <= attack_range and distance > 0:
				var check_cell = actor_cell + Vector2i(x, y)
				grid_layer.set_cell(check_cell, source_id, ATTACK_ATLAS_COORDS)
				highlighted_cells.append(check_cell)

func _clear_highlight() -> void:
	if not grid_layer: return
	for cell in highlighted_cells:
		grid_layer.set_cell(cell, -1, Vector2i(-1, -1))
	highlighted_cells.clear()

func _try_move_actor(actor: Actor, target_cell: Vector2i) -> bool:
	if _is_cell_occupied(target_cell): return false
	if not reachable_cells.has(target_cell):
		return false
	var target_global_pos = tile_map.to_global(tile_map.map_to_local(target_cell))
	await actor.move_to(target_global_pos)
	return true

func _try_move_actor_direct(actor: Actor, target_cell: Vector2i) -> bool:
	if _is_cell_occupied(target_cell): return false
	var target_global_pos = tile_map.to_global(tile_map.map_to_local(target_cell))
	await actor.move_to(target_global_pos)
	return true

func _is_cell_occupied(cell: Vector2i) -> bool:
	for actor in friendly_actors + enemy_actors:
		if is_instance_valid(actor) and not actor.is_dead:
			if cell == tile_map.local_to_map(tile_map.to_local(actor.global_position)): return true
	return false

func _get_actor_at_cell(cell: Vector2i, list: Array[Actor]) -> Actor:
	for actor in list:
		if is_instance_valid(actor) and not actor.is_dead:
			if cell == tile_map.local_to_map(tile_map.to_local(actor.global_position)): return actor
	return null

func _get_valid_source_id() -> int:
	var source_id = TILE_SOURCE_ID
	if grid_layer and grid_layer.tile_set and grid_layer.tile_set.get_source_count() > 0:
		var first_id = grid_layer.tile_set.get_source_id(0)
		if source_id == 0 and first_id != -1: source_id = first_id
	return source_id

func _snap_all_actors_to_grid() -> void:
	if not tile_map: return
	for actor in friendly_actors + enemy_actors:
		if is_instance_valid(actor):
			var cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			actor.global_position = tile_map.to_global(tile_map.map_to_local(cell))

func _create_end_turn_button() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	end_turn_button = Button.new()
	end_turn_button.text = "Конец хода"
	end_turn_button.size = Vector2(120, 40)
	end_turn_button.anchor_left = 1.0; end_turn_button.anchor_right = 1.0
	end_turn_button.anchor_top = 1.0; end_turn_button.anchor_bottom = 1.0
	end_turn_button.offset_left = -140; end_turn_button.offset_right = -20
	end_turn_button.offset_top = -60; end_turn_button.offset_bottom = -20
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	ui_layer.add_child(end_turn_button)

func _update_hover_stats() -> void:
	if current_turn != Turn.USER or not tile_map: return
	var local_mouse_pos = tile_map.get_local_mouse_position()
	var target_cell = tile_map.local_to_map(local_mouse_pos)
	var hovered_actor = _get_actor_at_cell(target_cell, friendly_actors + enemy_actors)
	if combat_ui:
		if hovered_actor and hovered_actor != selected_actor:
			combat_ui.update_target_stats(hovered_actor)
		else:
			combat_ui.clear_target_stats()

func _update_attack_cursor(target_cell: Vector2i) -> void:
	if current_phase != Phase.ATTACK or not selected_actor:
		Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		return

	var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
	var is_valid_target = target_enemy != null and target_cell in highlighted_cells

	if is_valid_target:
		if selected_actor.attack_type == ClassData.AttackType.PHYSICAL:
			Input.set_custom_mouse_cursor(CURSOR_SWORD, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		else:
			Input.set_custom_mouse_cursor(CURSOR_MAGIC, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	else:
		Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

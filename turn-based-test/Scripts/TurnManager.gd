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

@onready var combat_ui: Node = $CombatUI

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	# Direct, fast references based on world.tscn structure
	tile_map = get_parent() as TileMapLayer
	grid_layer = tile_map.get_node_or_null("GridLayer") as TileMapLayer
	
	_create_end_turn_button()
	
	# Auto-register pre-placed actors (e.g., enemies in the scene)
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
	# Удаляем из массивов
	friendly_actors.erase(actor)
	enemy_actors.erase(actor)
	friendly_remaining_moves.erase(actor)
	
	# Сбрасываем выбор, если умер выбранный персонаж
	if selected_actor == actor:
		selected_actor = null
		_clear_highlight()
		current_phase = Phase.MOVE
	
	# Физически удаляем узел со сцены
	actor.queue_free()
	
	# Проверяем условия победы
	_check_win_conditions()
	
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
		print("↩️ Ход отменен. Боец возвращается на исходную позицию.")
		selected_actor.global_position = actor_start_global_pos
	
	selected_actor = null
	_clear_highlight()
	current_phase = Phase.MOVE

func _handle_left_click(target_cell: Vector2i) -> void:
	if current_phase == Phase.MOVE:
		var clicked_friendly = _get_actor_at_cell(target_cell, friendly_actors)
		
		if clicked_friendly and clicked_friendly in friendly_remaining_moves:
			selected_actor = clicked_friendly
			actor_start_global_pos = selected_actor.global_position
			_highlight_available_moves(selected_actor)
			
			# NEW: Update Player UI
			if combat_ui: combat_ui.update_player_stats(selected_actor)
			return
			
		if selected_actor:
			if target_cell in highlighted_cells:
				is_processing_move = true
				_clear_highlight()
				var move_success = await _try_move_actor(selected_actor, target_cell)
				is_processing_move = false
				if move_success: _switch_to_attack_phase()
			else:
				_switch_to_attack_phase()
				
	elif current_phase == Phase.ATTACK and selected_actor:
		var actor_cell = tile_map.local_to_map(tile_map.to_local(selected_actor.global_position))
		
		if target_cell == actor_cell or not target_cell in highlighted_cells:
			_complete_actor_turn()
			return
			
		var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
		if target_enemy:
			target_enemy.take_damage(selected_actor.attack_damage, selected_actor.attack_type)
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
	
	if friendly_remaining_moves.is_empty():
		await _end_user_turn()

func _on_end_turn_button_pressed() -> void: # <-- CRITICAL BUG FIXED
	if current_turn != Turn.USER or is_processing_move: return
	
	print("🏁 Игрок завершил ход досрочно.")
	
	# Revert position BEFORE clearing selected_actor
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
			var desired_move_distance = mini(total_distance - attack_range, move_range)
			
			var step_x = sign(user_cell.x - ai_cell.x)
			var step_y = sign(user_cell.y - ai_cell.y)
			
			var best_cell = ai_cell
			var min_dist_to_target = total_distance
			
			var candidates = []
			if abs(user_cell.x - ai_cell.x) >= abs(user_cell.y - ai_cell.y):
				if step_x != 0: candidates.append(ai_cell + Vector2i(step_x, 0))
				if step_y != 0: candidates.append(ai_cell + Vector2i(0, step_y))
			else:
				if step_y != 0: candidates.append(ai_cell + Vector2i(0, step_y))
				if step_x != 0: candidates.append(ai_cell + Vector2i(step_x, 0))
				
			for candidate in candidates:
				if not _is_cell_occupied(candidate):
					var dist = abs(user_cell.x - candidate.x) + abs(user_cell.y - candidate.y)
					if dist < min_dist_to_target:
						min_dist_to_target = dist
						best_cell = candidate
						
			if best_cell != ai_cell:
				await _try_move_actor(enemy, best_cell)
				ai_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
		
		user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		var final_dist = abs(user_cell.x - ai_cell.x) + abs(user_cell.y - ai_cell.y)
		
		if final_dist <= attack_range:
			print("🤖 %s наносит удар по %s" % [enemy.name, target_player.name])
			await get_tree().create_timer(0.2).timeout
			target_player.take_damage(enemy.attack_damage, enemy.attack_type)
			
		await get_tree().create_timer(0.3).timeout
		
	_start_new_round()

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

# --- Helper functions (kept from original, slightly cleaned) ---
func _highlight_available_moves(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var source_id = _get_valid_source_id()
	var move_range = actor.class_data.move_range if actor.class_data else 3
	
	for x in range(-move_range, move_range + 1):
		for y in range(-move_range, move_range + 1):
			var check_cell = actor_cell + Vector2i(x, y)
			var distance = abs(x) + abs(y)
			if distance <= move_range and distance > 0 and not _is_cell_occupied(check_cell):
				grid_layer.set_cell(check_cell, source_id, HIGHLIGHT_ATLAS_COORDS)
				highlighted_cells.append(check_cell)

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
	var current_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var move_range = actor.class_data.move_range if actor.class_data else 3
	var distance = abs(target_cell.x - current_cell.x) + abs(target_cell.y - current_cell.y)
	
	if distance <= move_range and distance > 0:
		var target_global_pos = tile_map.to_global(tile_map.map_to_local(target_cell))
		await actor.move_to(target_global_pos)
		return true
	return false

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
	
	# Check if mouse is over any actor
	var hovered_actor = _get_actor_at_cell(target_cell, friendly_actors + enemy_actors)
	
	if combat_ui:
		if hovered_actor and hovered_actor != selected_actor:
			combat_ui.update_target_stats(hovered_actor)
		else:
			combat_ui.clear_target_stats()

@tool
extends Node2D

# MARK: - Signals
signal turn_changed(is_player_turn: bool)
signal game_over(player_won: bool)

# MARK: - Node References
var tile_map: TileMapLayer = null
var grid_layer: TileMapLayer = null
var combat_ui: Node = null

# MARK: - Actor Management
var friendly_actors: Array[Actor] = []
var enemy_actors: Array[Actor] = []

# MARK: - Initiative & Turn Queue
var turn_queue: Array[Actor] = []
var current_actor: Actor = null
var actor_start_global_pos: Vector2 = Vector2.ZERO

# MARK: - Grid & Highlighting
var reachable_cells: Dictionary = {}
var highlighted_cells: Array[Vector2i] = []
const TILE_SOURCE_ID = 0
const HIGHLIGHT_ATLAS_COORDS = Vector2i(0, 0)
const ATTACK_ATLAS_COORDS = Vector2i(1, 0)

# MARK: - Phase State
enum Phase { MOVE, ATTACK }
var current_phase: Phase = Phase.MOVE
var is_processing_move: bool = false

# MARK: - UI & Cursors
var ui_layer: CanvasLayer = null
var end_turn_button: Button = null
const CURSOR_SWORD = preload("res://ART/cursors/sword.png")
const CURSOR_DEFAULT = preload("res://ART/cursors/arrow.png")
const CURSOR_HOTSPOT = Vector2(16, 16)

# MARK: - Lifecycle
func _ready() -> void:
	if Engine.is_editor_hint(): return

	tile_map = get_parent() as TileMapLayer
	grid_layer = tile_map.get_node_or_null("GridLayer") as TileMapLayer
	combat_ui = get_tree().root.find_child("CombatUI", true, false)

	_create_end_turn_button()
	for child in get_children():
		if child is Actor:
			register_actor(child)

func register_actor(actor: Actor) -> void:
	if actor.is_friendly:
		friendly_actors.append(actor)
	else:
		enemy_actors.append(actor)
	if not actor.died.is_connected(_on_actor_died):
		actor.died.connect(_on_actor_died)

func _on_actor_died(actor: Actor) -> void:
	friendly_actors.erase(actor)
	enemy_actors.erase(actor)
	turn_queue.erase(actor)
	
	if current_actor == actor:
		_advance_turn()
		
	actor.queue_free()
	_check_win_conditions()

func initialize_game() -> void:
	_snap_all_actors_to_grid()
	_start_new_round()

func start_battle() -> void:
	initialize_game()

# MARK: - Initiative & Round Management
func _start_new_round() -> void:
	_build_turn_queue()
	_advance_turn()

func _build_turn_queue() -> void:
	turn_queue.clear()
	var all_actors: Array[Actor] = []
	
	for a in friendly_actors + enemy_actors:
		if is_instance_valid(a) and not a.is_dead:
			all_actors.append(a)

	all_actors.sort_custom(func(a, b):
		var init_a = _get_actor_initiative(a)
		var init_b = _get_actor_initiative(b)
		return init_a > init_b
	)
	
	turn_queue = all_actors
	print("🔄 Новый раунд! Очередь хода: ", turn_queue.map(func(a): return a.name))

func _get_actor_initiative(actor: Actor) -> int:
	return actor.class_data.initiative if actor.class_data else 0

func _advance_turn() -> void:
	_clear_highlight()
	current_actor = null
	current_phase = Phase.MOVE
	Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

	if turn_queue.is_empty():
		_start_new_round()
		return

	current_actor = turn_queue.pop_front()
	if not is_instance_valid(current_actor) or current_actor.is_dead:
		_advance_turn()
		return

	if current_actor.has_method("update_status_effects"):
		current_actor.update_status_effects()

	# Сохраняем стартовую позицию и автоматически выделяем персонажа
	actor_start_global_pos = current_actor.global_position

	if current_actor.is_friendly:
		print("⚔️ Ваш ход: %s (Init: %d)" % [current_actor.name, _get_actor_initiative(current_actor)])
		turn_changed.emit(true)
		
		# Автоматически показываем доступные ходы для текущего персонажа
		if combat_ui:
			combat_ui.update_player_stats(current_actor)
		
		if not _can_actor_act(current_actor):
			print("⚠️ %s оглушен, ход пропущен." % current_actor.name)
			await get_tree().create_timer(0.5).timeout
			_complete_actor_turn()
		else:
			# Автоматически подсвечиваем доступные клетки для движения
			_highlight_available_moves(current_actor)
	else:
		print("🤖 Ход врага: %s (Init: %d)" % [current_actor.name, _get_actor_initiative(current_actor)])
		turn_changed.emit(false)
		await get_tree().create_timer(0.4).timeout
		await _execute_ai_turn(current_actor)
		_complete_actor_turn()

# MARK: - Input Handling
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover_stats()
		if tile_map:
			var target_cell = tile_map.local_to_map(tile_map.get_local_mouse_position())
			_update_attack_cursor(target_cell)
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		# SPACEBAR: Skip current phase (Move -> Attack, or Attack -> End Turn)
		if event.keycode == KEY_SPACE:
			if current_actor and current_actor.is_friendly and not is_processing_move:
				if current_phase == Phase.MOVE:
					# Skip movement, go to attack phase
					_switch_to_attack_phase()
				elif current_phase == Phase.ATTACK:
					# Skip attack, end character's turn
					_complete_actor_turn()
			return

		# E KEY: End the entire character's turn immediately
		if event.keycode == KEY_E or event.is_action_pressed("end_turn"):
			if current_actor and current_actor.is_friendly and not is_processing_move:
				_complete_actor_turn()
			return

	# Block mouse input if it's not the player's turn or if processing
	if Engine.is_editor_hint() or is_processing_move or not current_actor or not current_actor.is_friendly:
		return

	if event is InputEventMouseButton and event.pressed:
		var target_cell = tile_map.local_to_map(tile_map.get_local_mouse_position())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_current_action()  # Right click cancels and returns to start pos
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(target_cell)

# MARK: - GDD Status Effect Checks
func _can_actor_move(actor: Actor) -> bool:
	var is_stunned = actor.get("is_stunned") if "is_stunned" in actor else false
	var is_rooted = actor.get("is_rooted") if "is_rooted" in actor else false
	return not (is_stunned or is_rooted)

func _can_actor_attack(actor: Actor) -> bool:
	var is_stunned = actor.get("is_stunned") if "is_stunned" in actor else false
	var is_disarmed = actor.get("is_disarmed") if "is_disarmed" in actor else false
	return not (is_stunned or is_disarmed)

func _can_actor_act(actor: Actor) -> bool:
	return _can_actor_move(actor) or _can_actor_attack(actor)

# MARK: - Action Handlers
func _cancel_current_action() -> void:
	# Возвращаем персонажа на исходную позицию
	if current_actor and current_actor.is_friendly:
		if current_phase == Phase.MOVE:
			# Если персонаж ещё не двигался, просто отменяем выделение
			_clear_highlight()
			current_phase = Phase.MOVE
			Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		elif current_phase == Phase.ATTACK:
			# Если персонаж уже двигался, возвращаем его на стартовую позицию
			print("↩️ Отмена хода: возврат %s на исходную позицию" % current_actor.name)
			current_actor.global_position = actor_start_global_pos
			_clear_highlight()
			current_phase = Phase.MOVE
			Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
			
			# Показываем доступные ходы снова
			if _can_actor_move(current_actor):
				_highlight_available_moves(current_actor)

func _handle_left_click(target_cell: Vector2i) -> void:
	if not current_actor or not current_actor.is_friendly:
		return

	if current_phase == Phase.MOVE:
		if target_cell in reachable_cells:
			is_processing_move = true
			var move_success = await _try_move_actor(current_actor, target_cell)
			is_processing_move = false
			_clear_highlight()
			
			if move_success:
				_switch_to_attack_phase()
			else:
				_highlight_available_moves(current_actor)

	elif current_phase == Phase.ATTACK:
		if not _can_actor_attack(current_actor):
			_complete_actor_turn()
			return

		var is_valid_target = target_cell in highlighted_cells

		if not is_valid_target:
			_complete_actor_turn()
			return

		# АТАКУЕМ ТОЛЬКО ВЫБРАННУЮ ЦЕЛЬ!
		var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
		if target_enemy:
			await _resolve_attack(current_actor, target_enemy)

		_complete_actor_turn()

func _switch_to_attack_phase() -> void:
	current_phase = Phase.ATTACK
	_highlight_attack_range(current_actor)

func _complete_actor_turn() -> void:
	_clear_highlight()
	current_phase = Phase.MOVE
	Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

	_advance_turn()

func _on_end_turn_button_pressed() -> void:
	if not current_actor or not current_actor.is_friendly or is_processing_move:
		return
	
	_complete_actor_turn()

# MARK: - Combat Resolution Helper
func _resolve_attack(attacker: Actor, target: Actor) -> void:
	await attacker.perform_attack(target)
	await get_tree().create_timer(0.2).timeout
	
	if is_instance_valid(attacker) and is_instance_valid(target) and not target.is_dead:
		await target.take_damage(attacker.attack_damage)
		
	if is_instance_valid(target) and not target.is_dead and target.has_method("can_counter_attack") and target.can_counter_attack():
		if "remaining_counter_attacks" in target:
			target.remaining_counter_attacks -= 1
		print("🔄 %s контратакует %s!" % [target.name, attacker.name])
		await target.perform_attack(attacker)
		if is_instance_valid(attacker) and not attacker.is_dead:
			await attacker.take_damage(target.attack_damage)

# MARK: - AI Logic (Per-Actor)
func _execute_ai_turn(actor: Actor) -> void:
	if not _can_actor_act(actor):
		return

	var target_player = _find_closest_friendly(actor)
	if not target_player: return

	var ai_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
	var can_attack_now = _is_cell_in_attack_pattern(ai_cell, user_cell, actor)

	if not can_attack_now and _can_actor_move(actor):
		var move_range = actor.class_data.move_range if actor.class_data else 3
		if actor.get("is_rooted"): move_range = 0

		var ai_reachable = _calculate_reachable_cells(ai_cell, move_range)
		var best_cell = ai_cell
		var best_distance = 99999
		var can_attack_from_best = false

		for cell in ai_reachable:
			var can_attack = _is_cell_in_attack_pattern(cell, user_cell, actor)
			var dist = abs(user_cell.x - cell.x) + abs(user_cell.y - cell.y)
			
			if can_attack and not can_attack_from_best:
				can_attack_from_best = true
				best_cell = cell
				best_distance = dist
			elif can_attack == can_attack_from_best and dist < best_distance:
				best_cell = cell
				best_distance = dist

		if best_cell != ai_cell:
			print("🤖 %s moving to %s" % [actor.name, best_cell])
			await _try_move_actor_direct(actor, best_cell)
			ai_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))

	if _is_cell_in_attack_pattern(ai_cell, user_cell, actor) and _can_actor_attack(actor):
		print("🤖 %s атакует %s" % [actor.name, target_player.name])
		await _resolve_attack(actor, target_player)

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

# MARK: - Grid & Highlighting Helpers
func _is_cell_in_attack_pattern(actor_cell: Vector2i, target_cell: Vector2i, actor: Actor) -> bool:
	if not actor.class_data or not actor.class_data.attack_pattern:
		return (abs(target_cell.x - actor_cell.x) + abs(target_cell.y - actor_cell.y)) <= 1
	for offset in actor.class_data.attack_pattern.relative_cells:
		if actor_cell + offset == target_cell: return true
	return false

func _get_tile_cost(cell: Vector2i) -> int:
	if not tile_map: return 1
	var tile_data = tile_map.get_cell_tile_data(cell)
	if not tile_data: return 1
	var cost = tile_data.get_custom_data("move_cost")
	return 9999 if cost <= 0 else cost

func _calculate_reachable_cells(start_cell: Vector2i, max_cost: int) -> Dictionary:
	var reachable = {}
	var queue = [[start_cell, 0]]
	reachable[start_cell] = 0

	while not queue.is_empty():
		var current = queue.pop_front()
		var cell: Vector2i = current[0]
		var cost: int = current[1]

		for n in [cell + Vector2i(1, 0), cell + Vector2i(-1, 0), cell + Vector2i(0, 1), cell + Vector2i(0, -1)]:
			if reachable.has(n): continue
			var tile_cost = _get_tile_cost(n)
			if tile_cost >= 9999 or _is_cell_occupied(n): continue
			var new_cost = cost + tile_cost
			if new_cost <= max_cost:
				reachable[n] = new_cost
				queue.append([n, new_cost])

	reachable.erase(start_cell)
	return reachable

func _highlight_available_moves(actor: Actor) -> void:
	_clear_highlight()
	if not _can_actor_move(actor): return

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
	var attack_cells: Array[Vector2i] = []

	if actor.class_data and actor.class_data.attack_pattern:
		for offset in actor.class_data.attack_pattern.relative_cells:
			attack_cells.append(actor_cell + offset)
	else:
		for x in range(-1, 2):
			for y in range(-1, 2):
				if abs(x) + abs(y) <= 1 and (x != 0 or y != 0):
					attack_cells.append(actor_cell + Vector2i(x, y))

	for cell in attack_cells:
		if cell != actor_cell:
			grid_layer.set_cell(cell, source_id, ATTACK_ATLAS_COORDS)
			highlighted_cells.append(cell)

func _clear_highlight() -> void:
	if not grid_layer: return
	for cell in highlighted_cells:
		grid_layer.set_cell(cell, -1, Vector2i(-1, -1))
	highlighted_cells.clear()
	reachable_cells.clear()

# MARK: - Movement & Collision Helpers
func _try_move_actor(actor: Actor, target_cell: Vector2i) -> bool:
	if _is_cell_occupied(target_cell) or not reachable_cells.has(target_cell): return false
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

# MARK: - UI Helpers
func _create_end_turn_button() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.size = Vector2(120, 40)
	end_turn_button.anchor_left = 1.0; end_turn_button.anchor_right = 1.0
	end_turn_button.anchor_top = 1.0; end_turn_button.anchor_bottom = 1.0
	end_turn_button.offset_left = -140; end_turn_button.offset_right = -20
	end_turn_button.offset_top = -60; end_turn_button.offset_bottom = -20
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	ui_layer.add_child(end_turn_button)

func _update_hover_stats() -> void:
	if not tile_map: return
	var local_mouse_pos = tile_map.get_local_mouse_position()
	var target_cell = tile_map.local_to_map(local_mouse_pos)
	var hovered_actor = _get_actor_at_cell(target_cell, friendly_actors + enemy_actors)

	if combat_ui:
		if hovered_actor:
			combat_ui.update_target_stats(hovered_actor)
		else:
			combat_ui.clear_target_stats()

func _update_attack_cursor(target_cell: Vector2i) -> void:
	if current_phase != Phase.ATTACK or not current_actor:
		Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		return

	var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
	var is_valid_target = target_enemy != null and target_cell in highlighted_cells

	if is_valid_target:
		# Always use the sword cursor for valid attack targets
		Input.set_custom_mouse_cursor(CURSOR_SWORD, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	else:
		Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

func _check_win_conditions() -> void:
	var live_friendlies = friendly_actors.filter(func(a): return is_instance_valid(a) and not a.is_dead)
	var live_enemies = enemy_actors.filter(func(e): return is_instance_valid(e) and not e.is_dead)

	if live_friendlies.is_empty():
		game_over.emit(false)
	elif live_enemies.is_empty():
		game_over.emit(true)

@tool
extends Node2D

var tile_map: TileMapLayer = null
var grid_layer: TileMapLayer = null

var friendly_actors: Array[Actor] = []
var enemy_actors: Array[Actor] = []
var friendly_remaining_moves: Array[Actor] = []

var selected_actor: Actor = null

enum Turn { USER, AI }
var current_turn: Turn = Turn.USER

# Состояния фаз для Игрока
enum Phase { MOVE, ATTACK }
var current_phase: Phase = Phase.MOVE

const MOVE_RANGE = 3
var highlighted_cells: Array[Vector2i] = []
var is_processing_move: bool = false

# --- НАСТРОЙКИ ТАЙЛОВ ПОДСВЕТКИ ---
const TILE_SOURCE_ID = 0           
const HIGHLIGHT_ATLAS_COORDS = Vector2i(0, 0) # Зеленая сетка для хода
const ATTACK_ATLAS_COORDS = Vector2i(1, 0)    # Пропишите координаты КРАСНОЙ сетки/рамки для атаки

func _ready() -> void:
	_initialize_game_elements()
	if Engine.is_editor_hint(): return
	_snap_all_actors_to_grid()
	_start_new_round()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_initialize_game_elements()
		_snap_all_actors_to_grid()

func _start_new_round() -> void:
	_clean_dead_actors()
	_check_win_conditions()
	
	current_turn = Turn.USER
	current_phase = Phase.MOVE
	selected_actor = null
	_clear_highlight()
	friendly_remaining_moves = friendly_actors.filter(func(a): return is_instance_valid(a))
	print("⚔️ Наступил Ваш ход!")

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or is_processing_move or current_turn != Turn.USER:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse_pos = tile_map.get_local_mouse_position()
		var target_cell = tile_map.local_to_map(local_mouse_pos)
		
		# === ФАЗА 1: ДВИЖЕНИЕ ===
		if current_phase == Phase.MOVE:
			var clicked_friendly = _get_actor_at_cell(target_cell, friendly_actors)
			if clicked_friendly and clicked_friendly in friendly_remaining_moves:
				if selected_actor == clicked_friendly:
					selected_actor = null
					_clear_highlight()
				else:
					selected_actor = clicked_friendly
					print("🎯 Выбран боец: ", selected_actor.name, ". Выберите клетку для шага.")
					_highlight_available_moves(selected_actor)
				return
				
			if selected_actor:
				# Если кликнули по клетке самого персонажа — он решает остаться на месте
				var actor_cell = tile_map.local_to_map(tile_map.to_local(selected_actor.global_position))
				if target_cell == actor_cell:
					print("🚶 Боец решил не идти. Переход к атаке.")
					_switch_to_attack_phase()
					return
					
				if target_cell in highlighted_cells:
					is_processing_move = true
					_clear_highlight()
					var move_success = await _try_move_actor(selected_actor, target_cell)
					is_processing_move = false
					
					if move_success:
						_switch_to_attack_phase()
				else:
					print("❌ Клик вне зоны хода.")
					
		# === ФАЗА 2: АТАКA ===
		elif current_phase == Phase.ATTACK and selected_actor:
			# Клик по самому себе завершает действие без атаки
			var actor_cell = tile_map.local_to_map(tile_map.to_local(selected_actor.global_position))
			if target_cell == actor_cell:
				_complete_actor_turn()
				return
				
			if target_cell in highlighted_cells:
				var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
				if target_enemy:
					print("⚔️ ", selected_actor.name, " атакует ", target_enemy.name)
					target_enemy.take_damage(selected_actor.attack_damage)
					_complete_actor_turn()
			else:
				print("❌ На этой клетке нет врага для атаки. Кликните по себе, чтобы пропустить атаку.")

# Переключение выбранного юнита в режим боя
func _switch_to_attack_phase() -> void:
	current_phase = Phase.ATTACK
	_highlight_attack_range(selected_actor)

# Завершение полного цикла действий (Ход + Атака) для одного персонажа
func _complete_actor_turn() -> void:
	friendly_remaining_moves.erase(selected_actor)
	selected_actor = null
	_clear_highlight()
	current_phase = Phase.MOVE
	
	_clean_dead_actors()
	_check_win_conditions()
	
	if friendly_remaining_moves.is_empty():
		await _end_user_turn()
	else:
		print("🔄 Выберите следующего доступного персонажа.")

# Подсветка зоны хода (Зеленая)
func _highlight_available_moves(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var source_id = _get_valid_source_id()
	
	for x in range(-MOVE_RANGE, MOVE_RANGE + 1):
		for y in range(-MOVE_RANGE, MOVE_RANGE + 1):
			var check_cell = actor_cell + Vector2i(x, y)
			var distance = abs(x) + abs(y)
			
			if distance <= MOVE_RANGE and distance > 0:
				if not _is_cell_occupied(check_cell):
					grid_layer.set_cell(check_cell, source_id, HIGHLIGHT_ATLAS_COORDS)
					highlighted_cells.append(check_cell)

# Подсветка зоны атаки (Ближайшие 4 клетки — Красная)
func _highlight_attack_range(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var source_id = _get_valid_source_id()
	
	# Направления: вверх, вниз, влево, вправо (дистанция 1 клетка)
	var attack_directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	print("🎯 Фаза Атаки! Выберите цель на красных клетках.")
	for dir in attack_directions:
		var check_cell = actor_cell + dir
		# Подсвечиваем, чтобы игрок видел, куда можно ударить
		grid_layer.set_cell(check_cell, source_id, ATTACK_ATLAS_COORDS)
		highlighted_cells.append(check_cell)

func _clear_highlight() -> void:
	if not grid_layer: return
	for cell in highlighted_cells:
		grid_layer.set_cell(cell, -1, Vector2i(-1, -1))
	highlighted_cells.clear()

func _try_move_actor(actor: Actor, target_cell: Vector2i) -> bool:
	if _is_cell_occupied(target_cell): return false
	var actor_local_pos = tile_map.to_local(actor.global_position)
	var current_cell = tile_map.local_to_map(actor_local_pos)
	var distance = abs(target_cell.x - current_cell.x) + abs(target_cell.y - current_cell.y)
	
	if distance <= MOVE_RANGE and distance > 0:
		var target_global_pos = tile_map.to_global(tile_map.map_to_local(target_cell))
		await actor.move_to(target_global_pos)
		return true
	return false

func _end_user_turn() -> void:
	current_turn = Turn.AI
	print("🤖 Ход переходит к ИИ...")
	_clear_highlight()
	await get_tree().create_timer(0.4).timeout
	await _make_ai_moves_and_attacks()

# ИИ ходит на 3 клетки И сразу атакует игрока, если оказался рядом
func _make_ai_moves_and_attacks() -> void:
	_clean_dead_actors()
	var active_enemies = enemy_actors.filter(func(e): return is_instance_valid(e))
	
	for enemy in active_enemies:
		if not is_instance_valid(enemy): continue
		var target_player = _find_closest_friendly(enemy)
		if not target_player: continue
		
		var ai_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
		var user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		
		var delta_x = user_cell.x - ai_cell.x
		var delta_y = user_cell.y - ai_cell.y
		var total_distance = abs(delta_x) + abs(delta_y)
		
		# Если ИИ еще не рядом, он сначала идет свои 3 клетки
		if total_distance > 1:
			var desired_move_distance = clampi(total_distance - 1, 0, MOVE_RANGE)
			var current_check_cell = ai_cell
			var steps_remaining = desired_move_distance
			
			while steps_remaining > 0:
				var next_step = current_check_cell
				if abs(user_cell.x - next_step.x) >= abs(user_cell.y - next_step.y) and user_cell.x != next_step.x:
					next_step.x += 1 if user_cell.x > next_step.x else -1
				elif user_cell.y != next_step.y:
					next_step.y += 1 if user_cell.y > next_step.y else -1
					
				if not _is_cell_occupied(next_step) and next_step != user_cell:
					current_check_cell = next_step
					steps_remaining -= 1
				else:
					break
					
			if current_check_cell != ai_cell:
				await _try_move_actor(enemy, current_check_cell)
				ai_cell = current_check_cell # обновляем позицию после шага
		
		# ПОСЛЕ ХОДА: Проверяем, оказался ли ИИ в упор к игроку для проведения атаки
		user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		var final_dist = abs(user_cell.x - ai_cell.x) + abs(user_cell.y - ai_cell.y)
		
		if final_dist == 1:
			print("🤖 ", enemy.name, " наносит удар по ", target_player.name)
			await get_tree().create_timer(0.2).timeout
			target_player.take_damage(enemy.attack_damage)
			
		await get_tree().create_timer(0.3).timeout
		
	_start_new_round()

# Вспомогательные проверки
func _is_cell_occupied(cell: Vector2i) -> bool:
	for actor in friendly_actors + enemy_actors:
		if is_instance_valid(actor):
			var a_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			if cell == a_cell: return true
	return false

func _get_actor_at_cell(cell: Vector2i, list: Array[Actor]) -> Actor:
	for actor in list:
		if is_instance_valid(actor):
			var a_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			if cell == a_cell: return actor
	return null

func _find_closest_friendly(enemy: Actor) -> Actor:
	var closest: Actor = null
	var min_dist = 99999
	var enemy_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
	for player in friendly_actors:
		if is_instance_valid(player):
			var p_cell = tile_map.local_to_map(tile_map.to_local(player.global_position))
			var dist = abs(enemy_cell.x - p_cell.x) + abs(enemy_cell.y - p_cell.y)
			if dist < min_dist:
				min_dist = dist
				closest = player
	return closest

func _get_valid_source_id() -> int:
	var source_id = TILE_SOURCE_ID
	if grid_layer and grid_layer.tile_set and grid_layer.tile_set.get_source_count() > 0:
		var first_id = grid_layer.tile_set.get_source_id(0)
		if source_id == 0 and first_id != -1: source_id = first_id
	return source_id

func _clean_dead_actors() -> void:
	friendly_actors = friendly_actors.filter(func(a): return is_instance_valid(a))
	enemy_actors = enemy_actors.filter(func(e): return is_instance_valid(e))

func _check_win_conditions() -> void:
	var live_friendlies = friendly_actors.filter(func(a): return is_instance_valid(a))
	var live_enemies = enemy_actors.filter(func(e): return is_instance_valid(e))
	
	var world = get_tree().current_scene
	if world and world.has_method("game_over"):
		if live_friendlies.is_empty():
			world.game_over(false) # Игрок проиграл (все союзники погибли)
		elif live_enemies.is_empty():
			world.game_over(true)  # Игрок победил (все враги уничтожены)

func _initialize_game_elements() -> void:
	friendly_actors.clear()
	enemy_actors.clear()
	var root_node = self
	while root_node.get_parent() != null:
		root_node = root_node.get_parent()
	_search_nodes_recursive(root_node)

func _search_nodes_recursive(node: Node) -> void:
	if node is TileMapLayer:
		if node.name == "GridLayer": 
			grid_layer = node
		else: 
			tile_map = node
	if node is Actor:
		if node.is_friendly: 
			friendly_actors.append(node)
		else: 
			enemy_actors.append(node)
	for child in node.get_children(): 
		_search_nodes_recursive(child)

func _snap_all_actors_to_grid() -> void:
	if not tile_map: return
	for actor in friendly_actors + enemy_actors:
		if is_instance_valid(actor):
			var cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			var cell_global_center = tile_map.to_global(tile_map.map_to_local(cell))
			actor.global_position = cell_global_center

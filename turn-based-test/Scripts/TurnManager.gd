@tool
extends Node2D

var tile_map: TileMapLayer = null
var grid_layer: TileMapLayer = null

var friendly_actors: Array[Actor] = []
var enemy_actors: Array[Actor] = []
var friendly_remaining_moves: Array[Actor] = []

var selected_actor: Actor = null
var actor_start_global_pos: Vector2 = Vector2.ZERO  # Для отмены хода

enum Turn { USER, AI }
var current_turn: Turn = Turn.USER

enum Phase { MOVE, ATTACK }
var current_phase: Phase = Phase.MOVE

var highlighted_cells: Array[Vector2i] = []
var is_processing_move: bool = false

# --- UI ---
var ui_layer: CanvasLayer = null
var end_turn_button: Button = null

# --- НАСТРОЙКИ ТАЙЛОВ ПОДСВЕТКИ ---
const TILE_SOURCE_ID = 1
const HIGHLIGHT_ATLAS_COORDS = Vector2i(0, 0)
const ATTACK_ATLAS_COORDS = Vector2i(1, 0)

func _ready() -> void:
	_initialize_game_elements()
	if Engine.is_editor_hint(): return
	_snap_all_actors_to_grid()
	_create_end_turn_button()
	_start_new_round()

func _start_new_round() -> void:
	_clean_dead_actors()
	_check_win_conditions()
	
	current_turn = Turn.USER
	current_phase = Phase.MOVE
	selected_actor = null
	_clear_highlight()
	friendly_remaining_moves = friendly_actors.filter(func(a): return is_instance_valid(a))
	print("⚔️ Наступил Ваш ход!")

# ============================================================
# ВВОД
# ============================================================
func _input(event: InputEvent) -> void:
	# Горячая клавиша завершения хода
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_E:
			_on_end_turn_button_pressed()
			return
	
	if Engine.is_editor_hint() or is_processing_move or current_turn != Turn.USER:
		return
		
	if event is InputEventMouseButton and event.pressed:
		var local_mouse_pos = tile_map.get_local_mouse_position()
		var target_cell = tile_map.local_to_map(local_mouse_pos)
		
		# === ПКМ: ОТМЕНА ===
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_phase == Phase.ATTACK and selected_actor != null:
				print("↩️ Ход отменен. Боец возвращается на исходную позицию.")
				selected_actor.global_position = actor_start_global_pos
				var start_cell = tile_map.local_to_map(tile_map.to_local(actor_start_global_pos))
				selected_actor.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
				
				# НЕ завершаем ход — игрок может выбрать персонажа снова
				selected_actor = null
				_clear_highlight()
				current_phase = Phase.MOVE
			else:
				selected_actor = null
				_clear_highlight()
				print("❌ Выбор отменен.")
			return
			
		# === ЛКМ: ОСНОВНОЕ ДЕЙСТВИЕ ===
		if event.button_index == MOUSE_BUTTON_LEFT:
			# --- ФАЗА ДВИЖЕНИЯ ---
			if current_phase == Phase.MOVE:
				var clicked_friendly = _get_actor_at_cell(target_cell, friendly_actors)
				
				if clicked_friendly and clicked_friendly in friendly_remaining_moves:
					if selected_actor == clicked_friendly:
						print("🚶 Боец остался на месте. Переход к атаке.")
						_switch_to_attack_phase()
					else:
						selected_actor = clicked_friendly
						actor_start_global_pos = selected_actor.global_position
						print("🎯 Выбран боец: ", selected_actor.name)
						_highlight_available_moves(selected_actor)
					return
					
				if selected_actor:
					var actor_cell = tile_map.local_to_map(tile_map.to_local(selected_actor.global_position))
					
					if target_cell in highlighted_cells:
						is_processing_move = true
						_clear_highlight()
						var move_success = await _try_move_actor(selected_actor, target_cell)
						is_processing_move = false
						
						if move_success:
							_switch_to_attack_phase()
						return
						
					print("🛑 Движение пропущено. Переход к фазе атаки.")
					_switch_to_attack_phase()
					return
					
			# --- ФАЗА АТАКИ ---
			elif current_phase == Phase.ATTACK and selected_actor:
				var actor_cell = tile_map.local_to_map(tile_map.to_local(selected_actor.global_position))
				
				if target_cell == actor_cell or not target_cell in highlighted_cells:
					print("🛑 Атака пропущена. Ход персонажа завершен.")
					_complete_actor_turn()
					return
					
				var target_enemy = _get_actor_at_cell(target_cell, enemy_actors)
				if target_enemy:
					print("⚔️ ", selected_actor.name, " атакует ", target_enemy.name)
					target_enemy.take_damage(selected_actor.attack_damage)
					_complete_actor_turn()
				else:
					print("❌ На этой клетке нет врага.")

# ============================================================
# ФАЗЫ
# ============================================================
func _switch_to_attack_phase() -> void:
	current_phase = Phase.ATTACK
	_highlight_attack_range(selected_actor)

func _complete_actor_turn() -> void:
	if selected_actor != null:
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

# ============================================================
# ПОДСВЕТКА
# ============================================================
func _highlight_available_moves(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var source_id = _get_valid_source_id()
	var move_range = actor.class_data.move_range if actor.class_data else 3
	
	for x in range(-move_range, move_range + 1):
		for y in range(-move_range, move_range + 1):
			var check_cell = actor_cell + Vector2i(x, y)
			var distance = abs(x) + abs(y)
			
			if distance <= move_range and distance > 0:
				if not _is_cell_occupied(check_cell):
					grid_layer.set_cell(check_cell, source_id, HIGHLIGHT_ATLAS_COORDS)
					highlighted_cells.append(check_cell)

func _highlight_attack_range(actor: Actor) -> void:
	_clear_highlight()
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var source_id = _get_valid_source_id()
	var attack_range = actor.class_data.attack_range if actor.class_data else 1
	
	print("🎯 Фаза Атаки! Радиус: ", attack_range)
	
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

# ============================================================
# ДВИЖЕНИЕ
# ============================================================
func _try_move_actor(actor: Actor, target_cell: Vector2i) -> bool:
	if _is_cell_occupied(target_cell): return false
	var actor_local_pos = tile_map.to_local(actor.global_position)
	var current_cell = tile_map.local_to_map(actor_local_pos)
	var move_range = actor.class_data.move_range if actor.class_data else 3
	var distance = abs(target_cell.x - current_cell.x) + abs(target_cell.y - current_cell.y)
	
	if distance <= move_range and distance > 0:
		var target_global_pos = tile_map.to_global(tile_map.map_to_local(target_cell))
		await actor.move_to(target_global_pos)
		return true
	return false

# ============================================================
# ХОД ИИ
# ============================================================
func _end_user_turn() -> void:
	current_turn = Turn.AI
	print("🤖 Ход переходит к ИИ...")
	_clear_highlight()
	await get_tree().create_timer(0.4).timeout
	await _make_ai_moves_and_attacks()

func _make_ai_moves_and_attacks() -> void:
	_clean_dead_actors()
	# Фильтруем только живых и валидных врагов
	var active_enemies = enemy_actors.filter(
		func(e): return is_instance_valid(e) and not e.is_dead
	)
	
	for enemy in active_enemies:
		# Теперь проверка не нужна, но оставим для безопасности
		if not is_instance_valid(enemy) or enemy.is_dead: continue
		
		var target_player = _find_closest_friendly(enemy)
		if not target_player: continue
		
		# ... остальной код без изменений ...
		
		var ai_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
		var user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		
		var delta_x = user_cell.x - ai_cell.x
		var delta_y = user_cell.y - ai_cell.y
		var total_distance = abs(delta_x) + abs(delta_y)
		
		if total_distance > 1:
			var move_range = enemy.class_data.move_range if enemy.class_data else 3
			var desired_move_distance = clampi(total_distance - 1, 0, move_range)
			var current_check_cell = ai_cell
			var steps_remaining = desired_move_distance
			
			while steps_remaining > 0:
				var step_x = current_check_cell
				var step_y = current_check_cell
				
				if user_cell.x != current_check_cell.x:
					step_x.x += 1 if user_cell.x > current_check_cell.x else -1
				if user_cell.y != current_check_cell.y:
					step_y.y += 1 if user_cell.y > current_check_cell.y else -1
				
				var moved = false
				if abs(user_cell.x - current_check_cell.x) >= abs(user_cell.y - current_check_cell.y):
					if not _is_cell_occupied(step_x) and step_x != user_cell:
						current_check_cell = step_x
						moved = true
					elif not _is_cell_occupied(step_y) and step_y != user_cell:
						current_check_cell = step_y
						moved = true
				else:
					if not _is_cell_occupied(step_y) and step_y != user_cell:
						current_check_cell = step_y
						moved = true
					elif not _is_cell_occupied(step_x) and step_x != user_cell:
						current_check_cell = step_x
						moved = true
				
				if moved:
					steps_remaining -= 1
				else:
					break
					
			if current_check_cell != ai_cell:
				await _try_move_actor(enemy, current_check_cell)
				ai_cell = current_check_cell
		
		user_cell = tile_map.local_to_map(tile_map.to_local(target_player.global_position))
		var final_dist = abs(user_cell.x - ai_cell.x) + abs(user_cell.y - ai_cell.y)
		
		if final_dist == 1:
			print("🤖 ", enemy.name, " наносит удар по ", target_player.name)
			await get_tree().create_timer(0.2).timeout
			target_player.take_damage(enemy.attack_damage)
			
		await get_tree().create_timer(0.3).timeout
		
	_start_new_round()

# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================
func _is_cell_occupied(cell: Vector2i) -> bool:
	for actor in friendly_actors + enemy_actors:
		if is_instance_valid(actor):
			var a_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			if cell == a_cell: return true
	return false

func _get_actor_at_cell(cell: Vector2i, list: Array[Actor]) -> Actor:
	for actor in list:
		if is_instance_valid(actor) or not actor.is_dead:
			var a_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
			if cell == a_cell: return actor
	return null

func _find_closest_friendly(enemy: Actor) -> Actor:
	var closest: Actor = null
	var min_dist = 99999
	var enemy_cell = tile_map.local_to_map(tile_map.to_local(enemy.global_position))
	for player in friendly_actors:
		if is_instance_valid(player) and not player.is_dead:  # <-- ДОБАВЛЕНО
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
	friendly_actors = friendly_actors.filter(
		func(a): return is_instance_valid(a) and not a.is_dead
	)
	enemy_actors = enemy_actors.filter(
		func(e): return is_instance_valid(e) and not e.is_dead
	)
	friendly_remaining_moves = friendly_remaining_moves.filter(
		func(a): return is_instance_valid(a) and not a.is_dead and a.is_friendly
	)
	
	if selected_actor and (not is_instance_valid(selected_actor) or selected_actor.is_dead):
		selected_actor = null
		_clear_highlight()
		current_phase = Phase.MOVE

func _check_win_conditions() -> void:
	var live_friendlies = friendly_actors.filter(
		func(a): return is_instance_valid(a) and not a.is_dead
	)
	var live_enemies = enemy_actors.filter(
		func(e): return is_instance_valid(e) and not e.is_dead
	)
	
	var world = get_tree().current_scene
	if world and world.has_method("game_over"):
		if live_friendlies.is_empty():
			world.game_over(false)
		elif live_enemies.is_empty():
			world.game_over(true)

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

# ============================================================
# UI — КНОПКА ЗАВЕРШЕНИЯ ХОДА
# ============================================================
func _create_end_turn_button() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	
	end_turn_button = Button.new()
	end_turn_button.text = "Конец хода"
	end_turn_button.size = Vector2(100, 30)
	
	end_turn_button.anchor_left = 1.0
	end_turn_button.anchor_right = 1.0
	end_turn_button.anchor_top = 1.0
	end_turn_button.anchor_bottom = 1.0
	
	end_turn_button.offset_left = -120
	end_turn_button.offset_right = -20
	end_turn_button.offset_top = -50
	end_turn_button.offset_bottom = -20
	
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	ui_layer.add_child(end_turn_button)

func _on_end_turn_button_pressed() -> void:
	if current_turn != Turn.USER or is_processing_move:
		return
	
	print("🏁 Игрок завершил ход досрочно.")
	
	# Если был выбран персонаж в фазе атаки — возвращаем его на исходную позицию
	if selected_actor != null and current_phase == Phase.ATTACK:
		selected_actor.global_position = actor_start_global_pos
		var start_cell = tile_map.local_to_map(tile_map.to_local(actor_start_global_pos))
		selected_actor.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
	
	friendly_remaining_moves.clear()
	selected_actor = null
	_clear_highlight()
	current_phase = Phase.MOVE
	
	await _end_user_turn()

extends Node2D

# ─── SIGNALS ───
signal turn_started(actor: Actor)
signal phase_changed(actor: Actor, new_phase: Phase)
signal actor_moved(actor: Actor, old_cell: Vector2i, new_cell: Vector2i)
signal actor_attacked(attacker: Actor, target: Actor)
signal turn_ended(actor: Actor)
signal game_over(player_won: bool)

# ─── ENUMS ───
enum Phase { MOVE, ATTACK, BUSY, OVER }

# ─── STATE VARIABLES ───
var turn_queue: Array[Actor] = []
var current_actor: Actor = null
var current_phase: Phase = Phase.MOVE
var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []

# ─── NODE REFERENCES ───
@onready var tile_map: TileMapLayer = $"../TileMap" 
@onready var grid_layer: TileMapLayer = $"../TileMap/GridLayer" 
@onready var combat_ui = $"../CanvasLayer/CombatUI" 

var is_processing: bool = false

# ─── INITIALIZATION ───
func register_actor(actor: Actor) -> void:
	if not turn_queue.has(actor):
		turn_queue.append(actor)
		actor.died.connect(_on_actor_died)

func build_initiative_queue() -> void:
	turn_queue.sort_custom(func(a: Actor, b: Actor): 
		return a.class_data.init > b.class_data.init
	)

func start_battle() -> void:
	build_initiative_queue()
	_start_next_turn()

# ─── TURN FLOW ───
func _start_next_turn() -> void:
	var friendly_alive = turn_queue.any(func(a: Actor): return a.is_friendly and not a.is_dead)
	var enemy_alive = turn_queue.any(func(a: Actor): return not a.is_friendly and not a.is_dead)
	
	if not friendly_alive:
		current_phase = Phase.OVER # 🐞 FIXED: Removed underscore
		game_over.emit(false)
		return
	if not enemy_alive:
		current_phase = Phase.OVER # 🐞 FIXED: Removed underscore
		game_over.emit(true)
		return

	if turn_queue.is_empty():
		return

	current_actor = turn_queue.pop_front()
	
	if current_actor.has_status("Stun"):
		print("⚡ %s is Stunned and skips their turn!" % current_actor.name)
		current_actor.consume_status_durations() 
		_end_current_turn()
		return

	current_actor.reset_turn_state()
	
	if current_actor.has_status("Root"):
		print("⛓️ %s is Rooted and cannot move." % current_actor.name)
		_switch_phase(Phase.ATTACK)
	else:
		_switch_phase(Phase.MOVE)
		
	turn_started.emit(current_actor)

func _switch_phase(new_phase: Phase) -> void:
	if current_phase == Phase.OVER:
		return
		
	current_phase = new_phase
	phase_changed.emit(current_actor, current_phase)
	
	if current_phase == Phase.MOVE:
		_highlight_reachable_cells(current_actor)
	elif current_phase == Phase.ATTACK:
		_highlight_attackable_cells(current_actor)

func _end_current_turn() -> void:
	_clear_highlights()
	turn_ended.emit(current_actor)
	turn_queue.append(current_actor)
	build_initiative_queue()
	is_processing = false
	await get_tree().create_timer(0.5).timeout
	_start_next_turn()

# ─── INPUT HANDLING ───
func _input(event: InputEvent) -> void:
	if not current_actor or not current_actor.is_friendly or is_processing or current_phase == Phase.OVER or current_phase == Phase.BUSY:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			if current_phase == Phase.MOVE:
				_switch_phase(Phase.ATTACK)
			elif current_phase == Phase.ATTACK:
				_end_current_turn()
			return

	if event is InputEventMouseButton and event.pressed:
		var target_cell = tile_map.local_to_map(tile_map.get_local_mouse_position())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_current_action()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(target_cell)

func _handle_left_click(target_cell: Vector2i) -> void:
	if current_phase == Phase.MOVE:
		_attempt_move(target_cell)
	elif current_phase == Phase.ATTACK:
		_attempt_attack(target_cell)

func attempt_skill(skill: SkillData, target_cell: Vector2i) -> void:
	if current_phase != Phase.ATTACK or is_processing:
		return
	var target_actor = _get_actor_at_cell(target_cell)
	if target_actor == null and skill.cast_range == 0:
		target_actor = current_actor
	_resolve_skill(current_actor, skill, target_actor, target_cell)

func _attempt_move(target_cell: Vector2i) -> void:
	if not current_actor.can_move():
		print("🚫 %s is Rooted!" % current_actor.name)
		return
	if not reachable_cells.has(target_cell):
		return 

	is_processing = true
	current_phase = Phase.BUSY
	var old_cell = tile_map.local_to_map(tile_map.to_local(current_actor.global_position))
	
	# 🐞 FIXED: Use to_global() to ensure correct coordinate space
	var target_pos = tile_map.to_global(tile_map.map_to_local(target_cell))
	await current_actor.move_to(target_pos)
	
	actor_moved.emit(current_actor, old_cell, target_cell)
	_switch_phase(Phase.ATTACK)
	is_processing = false

func _attempt_attack(target_cell: Vector2i) -> void:
	if not current_actor.can_attack():
		print("🚫 %s cannot attack!" % current_actor.name)
		return

	var target_actor = _get_actor_at_cell(target_cell)
	if not target_actor or target_actor.is_friendly == current_actor.is_friendly:
		return
	if not attackable_cells.has(target_cell):
		return

	is_processing = true
	current_phase = Phase.BUSY
	await _execute_basic_attack(current_actor, target_actor)
	_end_current_turn()

func _cancel_current_action() -> void:
	_clear_highlights()
	if current_phase == Phase.MOVE:
		_highlight_reachable_cells(current_actor)
	else:
		_highlight_attackable_cells(current_actor)

# ─── COMBAT RESOLUTION ───
func _execute_basic_attack(attacker: Actor, defender: Actor) -> void:
	actor_attacked.emit(attacker, defender)
	await attacker.perform_attack(defender)
	if defender.is_dead: return

	# 🐞 FIXED: Pass attack_type for Thraex passive calculation
	await defender.take_damage(attacker.attack_damage, attacker.attack_type)

	if not defender.is_dead and defender.remaining_counter_attacks > 0:
		var attacker_cell = tile_map.local_to_map(tile_map.to_local(attacker.global_position))
		var defender_cell = tile_map.local_to_map(tile_map.to_local(defender.global_position))
		if attacker_cell.distance_to(defender_cell) <= 1: 
			defender.remaining_counter_attacks -= 1
			print("🔄 %s counter-attacks!" % defender.name)
			await defender.perform_attack(attacker)
			if not attacker.is_dead:
				await attacker.take_damage(defender.attack_damage, defender.attack_type)

func _resolve_skill(actor: Actor, skill: SkillData, target: Actor, target_cell: Vector2i) -> void:
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	if skill.min_range > 0 and actor_cell.distance_to(target_cell) < skill.min_range:
		print("🚫 Target is too close for %s!" % skill.display_name)
		return

	if actor.has_status("Disarm") and skill.blocked_by_disarm:
		print("🚫 %s is Disarmed!" % actor.name)
		return

	is_processing = true
	current_phase = Phase.BUSY

	for effect in skill.effects:
		await effect.execute(actor, target, skill, self)

	actor.put_skill_on_cooldown(skill)

	if skill.ends_attack_phase:
		_end_current_turn()
	else:
		_switch_phase(Phase.ATTACK)
		is_processing = false

# ─── HELPERS & HIGHLIGHTING ───
func _get_actor_at_cell(cell: Vector2i) -> Actor:
	for actor in turn_queue:
		if actor.is_dead: continue
		var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
		if actor_cell == cell:
			return actor
	return null

func _is_wall_at_cell(cell: Vector2i) -> bool:
	# TODO: Replace with your actual TileMap wall checking logic
	return false 

func _get_valid_adjacent_cell(actor: Actor, target: Actor) -> Vector2i:
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var target_cell = tile_map.local_to_map(tile_map.to_local(target.global_position))
	var dir_to_target = (target_cell - actor_cell).normalized()
	
	directions.sort_custom(func(a, b): 
		return a.distance_squared_to(dir_to_target) < b.distance_squared_to(dir_to_target)
	)
	
	for dir in directions:
		var test_cell = actor_cell + dir
		if not _get_actor_at_cell(test_cell) and not _is_wall_at_cell(test_cell):
			return test_cell
	return Vector2i(-1, -1)

# 🆕 IMPLEMENTED: Actual Flood-Fill Pathfinding for Movement
func _highlight_reachable_cells(actor: Actor) -> void:
	_clear_highlights()
	if not actor.can_move():
		reachable_cells = []
	else:
		var max_steps = actor.class_data.move_range if actor.class_data else 0
		reachable_cells = _calculate_reachable_cells(actor, max_steps)
	if combat_ui:
		combat_ui.show_move_highlights(reachable_cells)

# 🆕 IMPLEMENTED: Pattern Matching for Attacks
func _highlight_attackable_cells(actor: Actor) -> void:
	_clear_highlights()
	var pattern = actor.current_basic_attack_pattern
	attackable_cells = _calculate_attackable_cells(actor, pattern)
	if combat_ui:
		combat_ui.show_attack_highlights(attackable_cells)

func _calculate_reachable_cells(actor: Actor, max_steps: int) -> Array[Vector2i]:
	var reachable = []
	var start_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	var queue = [{"cell": start_cell, "steps": 0}]
	var visited = {start_cell: true}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current.steps > 0:
			reachable.append(current.cell)
		if current.steps < max_steps:
			for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var next_cell = current.cell + dir
				if not visited.has(next_cell) and not _is_wall_at_cell(next_cell) and not _get_actor_at_cell(next_cell):
					visited[next_cell] = true
					queue.append({"cell": next_cell, "steps": current.steps + 1})
	return reachable

func _calculate_attackable_cells(actor: Actor, pattern: AttackPattern) -> Array[Vector2i]:
	var attackable = []
	if not pattern: return attackable
	var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
	for offset in pattern.relative_cells:
		var target_cell = actor_cell + offset
		if target_cell != actor_cell: # Prevent attacking self
			attackable.append(target_cell)
	return attackable

func _clear_highlights() -> void:
	reachable_cells.clear()
	attackable_cells.clear()
	if combat_ui:
		combat_ui.clear_highlights()

func _on_actor_died(actor: Actor) -> void:
	if turn_queue.has(actor):
		turn_queue.erase(actor)
	if current_actor == actor:
		_end_current_turn()
	
	var friendly_alive = turn_queue.any(func(a: Actor): return a.is_friendly and not a.is_dead)
	var enemy_alive = turn_queue.any(func(a: Actor): return not a.is_friendly and not a.is_dead)
	if not friendly_alive or not enemy_alive:
		current_phase = Phase.OVER
		game_over.emit(friendly_alive)

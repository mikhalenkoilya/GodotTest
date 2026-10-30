extends Node

# ─── SIGNALS ───
signal turn_started(actor: Actor)
signal phase_changed(actor: Actor, new_phase: Phase)
signal actor_moved(actor: Actor, old_cell: Vector2i, new_cell: Vector2i)
signal actor_attacked(attacker: Actor, target: Actor)
signal turn_ended(actor: Actor)

# ─── ENUMS ───
enum Phase { MOVE, ATTACK, BUSY, OVER }

# ─── STATE VARIABLES ───
var turn_queue: Array[Actor] = []
var current_actor: Actor = null
var current_phase: Phase = Phase.MOVE

var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []

@onready var tile_map: TileMap = $"../TileMap" # Adjust path to your TileMap
@onready var combat_ui = $"../CanvasLayer/CombatUI" # Adjust path to your UI

# ─── INITIALIZATION ───
func register_actor(actor: Actor) -> void:
	if not turn_queue.has(actor):
		turn_queue.append(actor)
		actor.died.connect(_on_actor_died)

func build_initiative_queue() -> void:
	# Sort descending by Init stat (GDD: Dimachaerus 15 goes before Crupellarius 2)
	turn_queue.sort_custom(func(a: Actor, b: Actor): 
		return a.class_data.init > b.class_data.init
	)
	print("📋 Initiative Queue: ", turn_queue.map(func(a): return a.name + " (" + str(a.class_data.init) + ")"))

func start_battle() -> void:
	build_initiative_queue()
	_start_next_turn()

# ─── TURN FLOW ───
func _start_next_turn() -> void:
	if turn_queue.is_empty():
		print("🏆 Battle Over!")
		return

	current_actor = turn_queue.pop_front()
	
	# GDD: Stun prevents ALL actions (Move and Attack)
	if current_actor.has_status("Stun"):
		print("⚡ %s is Stunned and skips their turn!" % current_actor.name)
		current_actor.consume_status_duration("Stun")
		_end_current_turn()
		return

	current_phase = Phase.MOVE
	current_actor.reset_turn_state() # Resets counter-attacks, refreshes per-turn resources
	
	# GDD: Root prevents ALL forms of movement
	if current_actor.has_status("Root"):
		print("⛓️ %s is Rooted and cannot move." % current_actor.name)
		_switch_phase(Phase.ATTACK)
	else:
		_switch_phase(Phase.MOVE)
		
	turn_started.emit(current_actor)

func _switch_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_changed.emit(current_actor, current_phase)
	
	if current_phase == Phase.MOVE:
		_highlight_reachable_cells(current_actor)
	elif current_phase == Phase.ATTACK:
		_highlight_attackable_cells(current_actor)

func _end_current_turn() -> void:
	_clear_highlights()
	turn_ended.emit(current_actor)
	
	# Put actor back in queue and re-sort (in case Init was modified by buffs/debuffs)
	turn_queue.append(current_actor)
	build_initiative_queue()
	
	await get_tree().create_timer(0.5).timeout
	_start_next_turn()

# ─── INPUT HANDLING ───
func handle_tile_click(target_cell: Vector2i) -> void:
	if current_phase == Phase.BUSY or current_phase == Phase.OVER:
		return

	if current_phase == Phase.MOVE:
		_attempt_move(target_cell)
	elif current_phase == Phase.ATTACK:
		_attempt_attack(target_cell)

func _attempt_move(target_cell: Vector2i) -> void:
	if not reachable_cells.has(target_cell):
		return # Invalid move

	current_phase = Phase.BUSY
	var old_cell = tile_map.local_to_map(tile_map.to_local(current_actor.global_position))
	
	# Execute movement
	await current_actor.move_to_cell(target_cell)
	
	actor_moved.emit(current_actor, old_cell, target_cell)
	
	# After moving, transition to Attack phase
	_switch_phase(Phase.ATTACK)

func _attempt_attack(target_cell: Vector2i) -> void:
	# Check if clicking a valid attack cell
	var target_actor = _get_actor_at_cell(target_cell)
	if not target_actor or target_actor.is_friendly == current_actor.is_friendly:
		return # Clicked empty space or friendly

	if not attackable_cells.has(target_cell):
		return # Out of range

	current_phase = Phase.BUSY
	await _execute_basic_attack(current_actor, target_actor)
	_end_current_turn()

# ─── SKILL ECONOMY (GDD COMPLIANT) ───
func execute_skill(actor: Actor, skill: SkillData, target_cell: Vector2i) -> void:
	if current_phase == Phase.BUSY or current_phase == Phase.OVER:
		return

	# GDD: Disarm prevents any skill whose primary effect is dealing damage
	if actor.has_status("Disarm") and skill.is_damage_dealing:
		print("🚫 %s is Disarmed and cannot use damage skills!" % actor.name)
		return

	current_phase = Phase.BUSY
	var target_actor = _get_actor_at_cell(target_cell)
	
	# Route to specific skill logic (to be implemented in respective classes or a SkillResolver)
	await _resolve_skill(actor, skill, target_actor, target_cell)

	# GDD: "Using any active skill immediately ends the Attack phase"
	# (Unless a specific skill explicitly overrides this, which is rare per GDD)
	if skill.ends_attack_phase:
		print("⏳ Skill usage ends the Attack phase immediately.")
		_end_current_turn()
	else:
		_switch_phase(Phase.ATTACK) # Fallback for edge cases

# ─── COMBAT RESOLUTION ───
func _execute_basic_attack(attacker: Actor, defender: Actor) -> void:
	actor_attacked.emit(attacker, defender)
	await attacker.perform_attack(defender)
	
	if defender.is_dead:
		return

	# GDD: Multi-hit resolution is handled inside take_damage if attacker has multi-hit traits
	await defender.take_damage(attacker.class_data.attack_damage, attacker.class_data.attack_type)

	# GDD: Counter-attack logic
	if not defender.is_dead and defender.class_data.max_counter_attacks > 0 and defender.remaining_counter_attacks > 0:
		if attacker.global_position.distance_to(defender.global_position) <= 70.0: # Adjacent
			defender.remaining_counter_attacks -= 1
			print("🔄 %s counter-attacks!" % defender.name)
			await defender.perform_attack(attacker)
			if not attacker.is_dead:
				await attacker.take_damage(defender.class_data.attack_damage, defender.class_data.attack_type)

func _resolve_skill(actor: Actor, skill: SkillData, target: Actor, target_cell: Vector2i) -> void:
	# Placeholder for skill-specific logic (e.g., Laquearius Pull, Murmillo Knockback)
	# This is where you'd call actor.execute_skill(skill, target) and handle the unique Dev Notes.
	print("🛠️ Resolving skill: %s on %s" % [skill.display_name, target.name if target else "Area"])
	
	# Example: Apply damage
	if target and not target.is_dead:
		await target.take_damage(int(actor.class_data.attack_damage * skill.damage_multiplier), skill.attack_type)

# ─── HELPERS & HIGHLIGHTING ───
func _get_actor_at_cell(cell: Vector2i) -> Actor:
	for actor in turn_queue:
		if actor.is_dead: continue
		var actor_cell = tile_map.local_to_map(tile_map.to_local(actor.global_position))
		if actor_cell == cell:
			return actor
	return null

func _highlight_reachable_cells(actor: Actor) -> void:
	# Stub: Replace with your existing A* or flood-fill pathfinding logic
	# reachable_cells = calculate_movement_range(actor, actor.class_data.move_range)
	pass

func _highlight_attackable_cells(actor: Actor) -> void:
	# Stub: Replace with your existing pattern-based highlighting logic
	# attackable_cells = calculate_attack_range(actor, actor.class_data.attack_pattern)
	pass

func _clear_highlights() -> void:
	reachable_cells.clear()
	attackable_cells.clear()
	# Emit signal to UI to clear visual highlights
	if combat_ui:
		combat_ui.clear_highlights()

func _on_actor_died(actor: Actor) -> void:
	if turn_queue.has(actor):
		turn_queue.erase(actor)
	if current_actor == actor:
		_end_current_turn()

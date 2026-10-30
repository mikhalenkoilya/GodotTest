extends Node

# ─── SIGNALS ───
signal turn_started(actor: Actor)
signal phase_changed(actor: Actor, new_phase: Phase)
signal actor_moved(actor: Actor, old_cell: Vector2i, new_cell: Vector2i)
signal actor_attacked(attacker: Actor, target: Actor)
signal turn_ended(actor: Actor)
signal game_over(player_won: bool) # <-- ADDED MISSING SIGNAL

# ─── ENUMS ───
enum Phase { MOVE, ATTACK, BUSY, OVER }

# ─── STATE VARIABLES ───
var turn_queue: Array[Actor] = []
var current_actor: Actor = null
var current_phase: Phase = Phase.MOVE

var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []

@onready var tile_map: TileMap = $"../TileMap"
@onready var combat_ui = $"../CanvasLayer/CombatUI"

# ─── INITIALIZATION ───
func register_actor(actor: Actor) -> void:
	if not turn_queue.has(actor):
		turn_queue.append(actor)
		actor.died.connect(_on_actor_died)

func build_initiative_queue() -> void:
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
	
	if current_actor.has_status("Stun"):
		print("⚡ %s is Stunned and skips their turn!" % current_actor.name)
		current_actor.consume_status_duration("Stun") # Now works correctly
		_end_current_turn()
		return

	current_phase = Phase.MOVE
	current_actor.reset_turn_state()
	
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
	
	# Consume all status durations at the END of the turn
	current_actor.consume_status_durations()
	current_actor.reduce_cooldowns()
	
	turn_queue.append(current_actor)
	build_initiative_queue()
	
	await get_tree().create_timer(0.5).timeout
	_start_next_turn()

# ... (keep your existing handle_tile_click, _attempt_move, _attempt_attack, execute_skill, _execute_basic_attack, _resolve_skill, _get_actor_at_cell, _highlight_reachable_cells, _highlight_attackable_cells, _clear_highlights) ...

func _on_actor_died(actor: Actor) -> void:
	if turn_queue.has(actor):
		turn_queue.erase(actor)
	if current_actor == actor:
		_end_current_turn()
	
	# Check for win/loss condition
	var allies_alive = false
	var enemies_alive = false
	for a in turn_queue:
		if a.is_friendly: allies_alive = true
		else: enemies_alive = true
		
	if not allies_alive:
		print("💀 All allies defeated!")
		game_over.emit(false)
		current_phase = Phase.OVER
	elif not enemies_alive:
		print("🏆 All enemies defeated!")
		game_over.emit(true)
		current_phase = Phase.OVER

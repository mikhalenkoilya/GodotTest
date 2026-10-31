class_name Actor
extends CharacterBody2D

signal died(actor: Actor)

@export var class_data: ClassData
@export var is_friendly: bool = true
@export var class_sprite_frames: SpriteFrames
@export var attack_pattern: AttackPattern

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_health: int = 0
var current_armor: int = 0
var is_dead: bool = false
var remaining_counter_attacks: int = 0
var active_statuses: Dictionary = {} 
var current_cooldowns: Dictionary = {} 

# 🆕 GDD: Temporary Buffs & Overrides (Provocator, Crupellarius, Hoplomachus)
var temp_armor: int = 0
var damage_reduction: float = 0.0
var _basic_attack_pattern_override: AttackPattern = null
var _override_turns_remaining: int = 0

const FRIENDLY_COLOR = Color(0.35, 0.75, 1.0)
const ENEMY_COLOR = Color(1.0, 0.35, 0.35)

var max_health: int:
	get: return class_data.max_hp if class_data else 100
var max_armor: int:
	get: return class_data.max_armor if class_data else 0
var attack_damage: int:
	get: return class_data.attack_damage if class_data else 10

# 🆕 GDD: Dynamic Attack Pattern (Supports Hoplomachus Spear Throw)
var current_basic_attack_pattern: AttackPattern:
	get:
		if _basic_attack_pattern_override != null and _override_turns_remaining > 0:
			return _basic_attack_pattern_override
		return attack_pattern if attack_pattern else (class_data.attack_pattern if class_data else null)

# MARK: - GDD Status Effects
var is_stunned: bool = false
var is_rooted: bool = false
var is_disarmed: bool = false

# Optional: Track turn duration for status effects (e.g., "Stunned for 1 turn")
var stun_duration: int = 0
var root_duration: int = 0
var disarm_duration: int = 0

# Call this at the start of a new round (TurnManager already calls this if it exists!)
func clear_status_effects() -> void:
	is_stunned = false
	is_rooted = false
	is_disarmed = false
	stun_duration = 0
	root_duration = 0
	disarm_duration = 0

# Helper to apply status effects cleanly
func apply_status_effect(effect_name: String, duration: int = 1) -> void:
	match effect_name.to_lower():
		"stun":
			is_stunned = true
			stun_duration = duration
		"root":
			is_rooted = true
			root_duration = duration
		"disarm":
			is_disarmed = true
			disarm_duration = duration

# Call this at the end of the actor's turn or round to tick down durations
func update_status_effects() -> void:
	if stun_duration > 0:
		stun_duration -= 1
		if stun_duration <= 0: is_stunned = false
		
	if root_duration > 0:
		root_duration -= 1
		if root_duration <= 0: is_rooted = false
		
	if disarm_duration > 0:
		disarm_duration -= 1
		if disarm_duration <= 0: is_disarmed = false


func _ready() -> void:
	if not class_data:
		push_warning("⚠️ Actor '%s' is missing Class Data!" % name)
	
	current_health = max_health
	current_armor = max_armor
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0
	_update_visuals()
	if sprite and not sprite.is_playing():
		sprite.play("idle")

# 🆕 GDD: Status Gating Helpers
func can_move() -> bool:
	return not has_status("Root") # GDD: Root prevents ALL movement

func can_attack() -> bool:
	return not has_status("Stun") and not has_status("Disarm")

func perform_attack(target: Node2D = null) -> void:
	if is_dead: return
	var original_pos = global_position
	var offset_applied = false
	
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= 70.0:
			var direction = (target.global_position - global_position).normalized()
			global_position += direction * 16.0
			offset_applied = true
			
	if sprite:
		sprite.play("attack")
		await sprite.animation_finished
		
	if offset_applied:
		var tween = create_tween()
		tween.tween_property(self, "global_position", original_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
		
	if not is_dead and sprite:
		sprite.play("idle")
func die() -> void:
	if is_dead: return
	
	is_dead = true
	current_health = 0
	
	# Проигрываем анимацию смерти, если она есть в SpriteFrames
	if sprite:
		if sprite.sprite_frames.has_animation("death"):
			sprite.play("death")
			await sprite.animation_finished
		else:
			push_warning("⚠️ Анимация 'death' не найдена в SpriteFrames для %s" % name)
	
	# Скрываем актера и отключаем физическое тело
	visible = false
	set_physics_process(false)
	set_process(false)
	
	print("💀 %s погиб!" % name)
	
	# Отправляем сигнал в TurnManager, чтобы убрать актера из очереди
	died.emit(self)
	
# 🔄 FIXED: Added attack_type to support Thraex Passive
func take_damage(raw_damage: int, armor_bypass_percent: float = 0.0, applied_status: StatusEffect = null) -> void:
	if is_dead: return

	# GDD: Provocator Taunt damage reduction
	var final_damage = int(raw_damage * (1.0 - damage_reduction))

	# GDD: Combine skill bypass (Velites) with class passive bypass (Thraex)
	var total_bypass_percent = armor_bypass_percent
	total_bypass_percent += class_data.passive_armor_bypass
		
	var bypass_damage = int(final_damage * total_bypass_percent)
	var remaining_damage = final_damage - bypass_damage

	# Resolve against Armor
	if current_armor > 0 and remaining_damage > 0:
		var absorbed = mini(current_armor, remaining_damage)
		current_armor -= absorbed
		remaining_damage -= absorbed 
	
	var total_hp_damage = bypass_damage + remaining_damage
	if total_hp_damage > 0:
		current_health = maxi(current_health - total_hp_damage, 0)
		
	print("💥 %s takes %d HP damage! (Armor: %d, HP: %d/%d)" % [name, total_hp_damage, current_armor, current_health, max_health])

	if applied_status != null and not is_dead:
		apply_status(applied_status)

	if current_health <= 0:
		die()
	elif not is_dead and sprite:
		sprite.play("idle")

func move_to(target_global_pos: Vector2) -> void:
	if is_dead: return
	if sprite: sprite.play("walk")
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not is_dead and sprite:
		sprite.play("idle")

# 🔄 FIXED: Clear temporary buffs and handle Hoplomachus override duration
func reset_turn_state() -> void:
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0
	consume_status_durations()
	
	# GDD: Crupellarius/Provocator buffs expire at the start of their next turn
	temp_armor = 0
	damage_reduction = 0.0
	
	# GDD: Hoplomachus shape-shift duration tick down
	if _override_turns_remaining > 0:
		_override_turns_remaining -= 1
		if _override_turns_remaining <= 0:
			_basic_attack_pattern_override = null

func _update_visuals() -> void:
	if sprite:
		sprite.modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		sprite.flip_h = not is_friendly

# --- Cooldown & Status Effect Management (Unchanged) ---
func reduce_cooldowns() -> void:
	for skill_name in current_cooldowns.keys():
		current_cooldowns[skill_name] -= 1
		if current_cooldowns[skill_name] <= 0:
			current_cooldowns.erase(skill_name)

func is_skill_on_cooldown(skill: SkillData) -> bool:
	return current_cooldowns.has(skill.display_name) and current_cooldowns[skill.display_name] > 0

func put_skill_on_cooldown(skill: SkillData) -> void:
	current_cooldowns[skill.display_name] = skill.cooldown

func get_cooldown_remaining(skill: SkillData) -> int:
	if current_cooldowns.has(skill.display_name):
		return current_cooldowns[skill.display_name]
	return 0

func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name) and active_statuses[status_name] > 0

func consume_status_durations() -> void:
	var statuses_to_remove = []
	for status_name in active_statuses.keys():
		active_statuses[status_name] -= 1
		if active_statuses[status_name] <= 0:
			statuses_to_remove.append(status_name)
	for status_name in statuses_to_remove:
		active_statuses.erase(status_name)
		print("✅ %s is no longer affected by [%s]." % [name, status_name])

func apply_status(status: StatusEffect) -> void:
	if not active_statuses.has(status.status_name):
		active_statuses[status.status_name] = 0
	active_statuses[status.status_name] = max(active_statuses[status.status_name], status.duration)
	print("⚠️ %s is now affected by [%s] for %d turn(s)!" % [name, status.status_name, active_statuses[status.status_name]])

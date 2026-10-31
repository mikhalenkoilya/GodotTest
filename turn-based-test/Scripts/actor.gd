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
var active_statuses: Array[StatusEffect] = []
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
func apply_status_effect(status: StatusEffect) -> void:
	# Update duration if status already exists
	for i in range(active_statuses.size()):
		if active_statuses[i].status_name == status.status_name:
			active_statuses[i].duration = status.duration
			print("🔄 Обновлен эффект %s на %s: %d ход(ов)" % [status.status_name, name, status.duration])
			_update_status_flags()
			return
	
	active_statuses.append(status)
	print("🔗 %s получил эффект: %s на %d ход(ов)" % [name, status.status_name, status.duration])
	_update_status_flags()

func update_status_effects() -> void:
	# Tick down durations at the start of the actor's turn
	for i in range(active_statuses.size() - 1, -1, -1):
		active_statuses[i].duration -= 1
		if active_statuses[i].duration <= 0:
			print("✅ Эффект %s на %s закончился" % [active_statuses[i].status_name, name])
			active_statuses.remove_at(i)
	
	_update_status_flags()

func _update_status_flags() -> void:
	is_stunned = false
	is_rooted = false
	is_disarmed = false
	for status in active_statuses:
		match status.type:
			StatusEffect.Type.STUN: is_stunned = true
			StatusEffect.Type.ROOT: is_rooted = true
			StatusEffect.Type.DISARM: is_disarmed = true

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
	if sprite:
		sprite.play("death")
		await sprite.animation_finished
	visible = false
	print("💀 %s погиб!" % name)
	died.emit(self)
	
func take_damage(amount: int, armor_bypass_percent: float = 0.0, status_to_apply: StatusEffect = null) -> void:
	if is_dead: return

	# 1. Calculate Armor Bypass (GDD: Thraex 10%, Velites 25%)
	var bypass_damage = int(amount * armor_bypass_percent)
	var shield_damage = amount - bypass_damage

	print("⚔️ %s получает %d урона! (Пробивает броню: %d)" % [name, amount, bypass_damage])

	# 2. Absorb damage with Armor
	if current_armor > 0 and shield_damage > 0:
		var absorbed = mini(current_armor, shield_damage)
		current_armor -= absorbed
		shield_damage -= absorbed

	# 3. Apply remaining shield damage + bypass damage directly to HP
	var total_hp_damage = shield_damage + bypass_damage
	if total_hp_damage > 0:
		current_health = maxi(current_health - total_hp_damage, 0)

	print("🛡️ Броня: %d/%d | ❤️ HP: %d/%d" % [current_armor, max_armor, current_health, max_health])

	# 4. Animations
	if sprite:
		sprite.play("hit")
		await sprite.animation_finished

	if current_health <= 0:
		die()
	elif not is_dead:
		sprite.play("idle")

	# 5. Apply Status Effect (e.g., Root from Net, Stun from Shield Bash)
	if status_to_apply != null and not is_dead:
		apply_status_effect(status_to_apply)

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

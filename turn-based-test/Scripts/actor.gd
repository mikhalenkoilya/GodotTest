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
var current_magic_resist: int = 0
var is_dead: bool = false
var remaining_counter_attacks: int = 0

var active_statuses: Dictionary = {} # Stores { "StatusName": remaining_turns }
var current_cooldowns: Dictionary = {} # skill_name -> turns remaining

const FRIENDLY_COLOR = Color(0.35, 0.75, 1.0)
const ENEMY_COLOR = Color(1.0, 0.35, 0.35)

var max_health: int:
	get: return class_data.max_hp if class_data else 100

var max_armor: int:
	get: return class_data.max_armor if class_data else 0

var max_magic_resist: int:
	get: return class_data.max_magic_resist if class_data else 0

var attack_damage: int:
	get: return class_data.attack_damage if class_data else 10

var attack_type: ClassData.AttackType:
	get: return class_data.attack_type if class_data else ClassData.AttackType.PHYSICAL

func _ready() -> void:
	if not class_data:
		push_warning("⚠️ Actor '%s' is missing Class Data assignment in the Inspector! Defaulting to base stats." % name)
	
	current_health = max_health
	current_armor = max_armor
	current_magic_resist = max_magic_resist
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0
	
	_update_visuals()
	if sprite and not sprite.is_playing():
		sprite.play("idle")

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

func take_damage(raw_damage: int, attack_type: ClassData.AttackType, armor_bypass_percent: float = 0.0, applied_status: StatusEffect = null) -> void:
	if is_dead: return

	var bypass_damage = int(raw_damage * armor_bypass_percent)
	var remaining_damage = raw_damage - bypass_damage

	if attack_type == ClassData.AttackType.PHYSICAL:
		if current_armor > 0 and remaining_damage > 0:
			var absorbed = mini(current_armor, remaining_damage)
			current_armor -= absorbed
			remaining_damage -= absorbed
		current_health = maxi(current_health - (bypass_damage + remaining_damage), 0)
	elif attack_type == ClassData.AttackType.MAGIC:
		if current_magic_resist > 0 and remaining_damage > 0:
			var absorbed = mini(current_magic_resist, remaining_damage)
			current_magic_resist -= absorbed
			remaining_damage -= absorbed
		current_health = maxi(current_health - (bypass_damage + remaining_damage), 0)

	print("💥 %s takes %d HP damage! (Armor: %d, HP: %d/%d)" % [name, bypass_damage + remaining_damage, current_armor, current_health, max_health])

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

func reset_turn_state() -> void:
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0
	# NOTE: Status durations are now consumed at the END of the turn in TurnManager, 
	# ensuring 1-turn stuns properly skip the current turn.

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
	return current_cooldowns.get(skill.display_name, 0)

func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name) and active_statuses[status_name] > 0

func consume_status_duration(status_name: String) -> void:
	if active_statuses.has(status_name):
		active_statuses[status_name] -= 1
		if active_statuses[status_name] <= 0:
			active_statuses.erase(status_name)
			print("✅ %s is no longer affected by [%s]." % [name, status_name])

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

func die() -> void:
	is_dead = true
	if sprite:
		sprite.modulate.a = 0.5
		# sprite.play("die") # Uncomment if you have a die animation
	died.emit(self)

func _update_visuals() -> void:
	if sprite:
		sprite.modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		sprite.flip_h = not is_friendly

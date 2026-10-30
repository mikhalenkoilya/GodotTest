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
# 🔄 Отслеживание оставшихся ответных атак в текущем раунде
var remaining_counter_attacks: int = 0

# Add these to the top of actor.gd with your other variables
var active_statuses: Dictionary = {} # Stores { "StatusName": remaining_turns }

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

# Add these variables at the top of actor.gd (after your existing vars)
var current_cooldowns: Dictionary = {} # skill_name -> turns remaining

func _ready() -> void:
	if not class_data:
		push_warning("⚠️ Actor '%s' is missing Class Data assignment in the Inspector! Defaulting to base stats." % name)
	
	current_health = max_health
	current_armor = max_armor
	current_magic_resist = max_magic_resist
	
	# 🔄 Инициализация счетчика ответных атак
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0
	
	_update_visuals()
	if sprite and not sprite.is_playing():
		sprite.play("idle")
		
# NEW: Attack animation function
func perform_attack(target: Node2D = null) -> void:
	if is_dead: return
	
	var original_pos = global_position
	var offset_applied = false
	
	# ✅ UPDATED: Apply 50% offset lunge if attacking an adjacent target (approx 1 tile distance)
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= 70.0: # Approx 1 tile (64px) + small margin for safety
			var direction = (target.global_position - global_position).normalized()
			var lunge_distance = 16.0
			global_position += direction * lunge_distance
			offset_applied = true
			
	if sprite:
		sprite.play("attack")
		await sprite.animation_finished
		
	# ✅ Smoothly return to original position after the attack animation
	if offset_applied:
		var tween = create_tween()
		tween.tween_property(self, "global_position", original_pos, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
		
	if not is_dead and sprite:
		sprite.play("idle")

func take_damage(raw_damage: int, attack_type: ClassData.AttackType, armor_bypass_percent: float = 0.0, applied_status: StatusEffect = null) -> void:
	if is_dead: return

	# 1. Calculate Armor Bypass (GDD: Thraex 10%, Velites 25%)
	var bypass_damage = int(raw_damage * armor_bypass_percent)
	var remaining_damage = raw_damage - bypass_damage

	# 2. Resolve against Armor / Magic Resist
	if attack_type == ClassData.AttackType.PHYSICAL:
		if current_armor > 0 and remaining_damage > 0:
			var absorbed = mini(current_armor, remaining_damage)
			current_armor -= absorbed
			remaining_damage -= absorbed # Overflow damage
		
		# Whatever is left (bypass + overflow) hits HP
		var total_hp_damage = bypass_damage + remaining_damage
		if total_hp_damage > 0:
			current_health = maxi(current_health - total_hp_damage, 0)
			
	elif attack_type == ClassData.AttackType.MAGIC:
		if current_magic_resist > 0 and remaining_damage > 0:
			var absorbed = mini(current_magic_resist, remaining_damage)
			current_magic_resist -= absorbed
			remaining_damage -= absorbed
			
		var total_hp_damage = bypass_damage + remaining_damage
		if total_hp_damage > 0:
			current_health = maxi(current_health - total_hp_damage, 0)

	print("💥 %s takes %d HP damage! (Armor: %d, HP: %d/%d)" % [name, bypass_damage + remaining_damage, current_armor, current_health, max_health])

	# 3. Apply Status Effect (if the attack inflicts one, e.g., Retiarius Net, Murmillo Shield Bash)
	if applied_status != null and not is_dead:
		apply_status(applied_status)

	# 4. Check Death
	if current_health <= 0:
		die()
	elif not is_dead and sprite:
		sprite.play("idle")

func move_to(target_global_pos: Vector2) -> void:
	if is_dead: return
	
	if sprite: sprite.play("walk")
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	if not is_dead and sprite:
		sprite.play("idle")

# 🔄 Вызывается в начале раунда для восстановления ресурсов (ответные атаки, и т.д.)
func reset_turn_state() -> void:
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0

func _update_visuals() -> void:
	if sprite:
		sprite.modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		sprite.flip_h = not is_friendly
# Add these methods to actor.gd
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
var active_statuses: Dictionary = {} # e.g., {"Stun": 1, "Root": 1}

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

func reset_turn_state() -> void:
	remaining_counter_attacks = class_data.max_counter_attacks if class_data else 0
	consume_status_durations() # GDD: Status durations tick down at the start of the actor's turn

func apply_status(status: StatusEffect) -> void:
	if not active_statuses.has(status.status_name):
		active_statuses[status.status_name] = 0
	
	# Overwrite duration if the new application is longer (or just add, depending on your design)
	active_statuses[status.status_name] = max(active_statuses[status.status_name], status.duration)
	print("⚠️ %s is now affected by [%s] for %d turn(s)!" % [name, status.status_name, active_statuses[status.status_name]])

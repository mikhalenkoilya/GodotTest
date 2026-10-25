class_name Actor
extends CharacterBody2D

signal died(actor: Actor)

@export var class_data: ClassData
@export var is_friendly: bool = true
@export var class_sprite_frames: SpriteFrames

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_health: int = 0
var current_armor: int = 0
var current_magic_resist: int = 0
var is_dead: bool = false

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
	
	_update_visuals()
	if sprite and not sprite.is_playing():
		sprite.play("idle")
		
# NEW: Attack animation function
func perform_attack(target: Node2D = null) -> void:
	if is_dead: return
	
	var original_pos = global_position
	var offset_applied = false
	
	# ✅ NEW: Apply 50% offset lunge if attacking at range 1
	if target and is_instance_valid(target) and class_data and class_data.attack_range == 1:
		var direction = (target.global_position - global_position).normalized()
		# 32.0 is 50% of a standard 64x64 tile. 
		# Adjust this value if your project uses a different tile size (e.g., 48.0 for 96x96 tiles)
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

func take_damage(amount: int, type: ClassData.AttackType) -> void:
	if is_dead: return
	
	var type_name = "Физического" if type == ClassData.AttackType.PHYSICAL else "Магического"
	print("⚔️ %s получает %d %s урона!" % [name, amount, type_name])
	
	# 1. Применяем урон к соответствующему щиту
	if type == ClassData.AttackType.PHYSICAL:
		if current_armor > 0:
			var absorbed = mini(current_armor, amount)
			current_armor -= absorbed
			amount -= absorbed # Остаток уходит в HP
	elif type == ClassData.AttackType.MAGIC:
		if current_magic_resist > 0:
			var absorbed = mini(current_magic_resist, amount)
			current_magic_resist -= absorbed
			amount -= absorbed # Остаток уходит в HP
			
	# 2. Применяем остаток урона к HP
	if amount > 0:
		current_health = maxi(current_health - amount, 0)
		
	print("🛡️ Броня: %d/%d | ✨ Сопр: %d/%d | ❤️ HP: %d/%d" % [
		current_armor, max_armor, 
		current_magic_resist, max_magic_resist, 
		current_health, max_health
	])
	
	# 3. Анимации
	if sprite:
		sprite.play("hit")
		await sprite.animation_finished
		
		if current_health <= 0:
			die()
		elif not is_dead:
			sprite.play("idle")
	else:
		if current_health <= 0:
			die()

func die() -> void:
	if is_dead: return
	
	is_dead = true
	current_health = 0
	
	if sprite:
		sprite.play("death")
		await sprite.animation_finished
	
	visible = false
	print(" %s погиб!" % name)
	died.emit(self)

func move_to(target_global_pos: Vector2) -> void:
	if is_dead: return
	
	if sprite: sprite.play("walk")
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	if not is_dead and sprite:
		sprite.play("idle")

func _update_visuals() -> void:
	if sprite:
		sprite.modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		sprite.flip_h = not is_friendly

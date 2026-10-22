class_name Actor
extends CharacterBody2D


# === ДАННЫЕ КЛАССА ===
@export var class_data: ClassData
@export var is_friendly: bool = true

# === ХАРАКТЕРИСТИКИ ===
@export var max_health: int = 100
@export var attack_damage: int = 10

var current_health: int = 0
var is_dead: bool = false

# === ЦВЕТА ФРАКЦИЙ ===
const FRIENDLY_COLOR = Color(0.35, 0.75, 1.0)  # Голубой
const ENEMY_COLOR = Color(1.0, 0.35, 0.35)     # Красный

func _ready() -> void:
	if class_data:
		max_health = class_data.max_hp
		attack_damage = class_data.attack_damage
		
		# === НАСТРОЙКА ANIMATEDSPRITE2D ===
		var anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim_sprite:
			# Запускаем анимацию "idle" (или первую доступную, если idle нет)
			if anim_sprite.sprite_frames:
				if anim_sprite.sprite_frames.has_animation("idle"):
					anim_sprite.play("idle")
				elif anim_sprite.sprite_frames.get_animation_names().size() > 0:
					anim_sprite.play(anim_sprite.sprite_frames.get_animation_names()[0])
	
	current_health = max_health
	_update_visuals()

# === ПОЛУЧЕНИЕ УРОНА ===
func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	current_health = maxi(current_health - amount, 0)
	print("⚔️ ", name, " получил ", amount, " урона! Осталось HP: ", current_health, "/", max_health)
	
	await _play_hit_animation()
	
	if current_health <= 0:
		await die() # ВАЖНО: Обязательно добавляем await перед die()

func _play_hit_animation() -> void:
	var anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not anim_sprite or not anim_sprite.sprite_frames:
		_flash_damage()
		return

	# Пытаемся сыграть анимацию удара
	if anim_sprite.sprite_frames.has_animation("hit"):
		anim_sprite.play("hit")
		await anim_sprite.animation_finished
	else:
		_flash_damage() # Если анимации нет, используем вспышку
		return

	# Возвращаемся к idle, если персонаж еще жив
	if not is_dead:
		_safe_play_anim("idle")

func _safe_play_anim(anim_name: String) -> bool:
	var anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)
		return true
	return false
	
# === ВСПЫШКА ПРИ УРОНЕ ===
func _flash_damage() -> void:
	var base_color = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
	var target_color = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	tween.tween_property(self, "modulate", target_color, 0.12)

# === СМЕРТЬ ===
# === СМЕРТЬ ===
# === СМЕРТЬ ===
func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	current_health = 0
	print("💀 ", name, " погиб!")
	
	var anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	# Проигрываем анимацию смерти и ждём её окончания
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
		await anim_sprite.animation_finished
	else:
		print("⚠️ Анимация 'death' не найдена! Ждём 0.5 сек.")
		await get_tree().create_timer(0.5).timeout
	
	# Удаляем персонажа только после завершения анимации
	visible = false
	queue_free()

# === ДВИЖЕНИЕ ===
func move_to(target_global_pos: Vector2) -> void:
	if is_dead:
		return
	
	# Запускаем анимацию ходьбы (если есть)
	if not _safe_play_anim("move"):
		_safe_play_anim("walk") # Запасной вариант, если анимация называется "walk"
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	# Возвращаемся в режим ожидания
	_safe_play_anim("idle")
# === ВНЕШНИЙ ВИД (КРИТИЧЕСКИ ВАЖНО) ===
func _update_visuals() -> void:
	# 1. Применяем цвет фракции ко всему узлу
	var target_color = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
	self.modulate = target_color
	
	# 2. Настройка и поворот AnimatedSprite2D
	var anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite:
		anim_sprite.centered = true
		anim_sprite.position = Vector2.ZERO
		
		anim_sprite.flip_h = not is_friendly 

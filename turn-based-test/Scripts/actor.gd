class_name Actor
extends Node2D

# === ДАННЫЕ КЛАССА ===
@export var class_data: ClassData
@export var is_friendly: bool = true

# === ХАРАКТЕРИСТИКИ (fallback, если ClassData не назначен) ===
@export var max_health: int = 100
@export var attack_damage: int = 10

var current_health: int = 0
var is_dead: bool = false

# === ЦВЕТА ФРАКЦИЙ ===
const FRIENDLY_COLOR = Color(0.35, 0.75, 1.0)
const ENEMY_COLOR = Color(1.0, 0.35, 0.35)

# === КОМПОНЕНТЫ (безопасно, даже если Sprite2D отсутствует) ===
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	# Подтягиваем статы из ресурса, если он назначен
	if class_data:
		max_health = class_data.max_hp
		attack_damage = class_data.attack_damage
		if sprite and class_data.sprite_texture:
			sprite.texture = class_data.sprite_texture
	
	current_health = max_health
	_update_visuals()

# === ПОЛУЧЕНИЕ УРОНА (единственная версия) ===
func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	current_health = maxi(current_health - amount, 0)
	print("⚔️ ", name, " получил ", amount, " урона! Осталось HP: ", current_health, "/", max_health)
	
	_flash_damage()
	
	if current_health <= 0:
		die()

# === ВСПЫШКА ПРИ УРОНЕ ===
func _flash_damage() -> void:
	if not sprite:
		return
	
	var base_color = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
	sprite.modulate = Color(3.0, 3.0, 3.0)  # короткая белая вспышка
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	tween.tween_property(sprite, "modulate", base_color, 0.12)

# === СМЕРТЬ (единственная версия) ===
func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	current_health = 0
	visible = false
	print("💀 ", name, " погиб!")
	
	# ВАЖНО: queue_free() отложенный, узел исчезнет в конце кака.
	# TurnManager использует is_dead, чтобы не считать его живым.
	queue_free()

# === ДВИЖЕНИЕ ===
func move_to(target_global_pos: Vector2) -> void:
	if is_dead:
		return
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_pos, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# === ВНЕШНИЙ ВИД ===
func _update_visuals() -> void:
	if not sprite:
		return
	sprite.modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
	sprite.centered = true
	sprite.position = Vector2.ZERO

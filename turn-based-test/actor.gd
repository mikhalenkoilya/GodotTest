class_name Actor extends CharacterBody2D

const FRIENDLY_COLOR: Color = Color("#1aff42")
const ENEMY_COLOR: Color = Color.RED

@export var CELL_SIZE: int = 64
@export var SPEED: float = 300.0

# === ХАРАКТЕРИСТИКИ ДЛЯ БОЯ ===
@export var max_health: int = 100
@export var current_health: int = 100
@export var attack_damage: int = 25
# ==============================

@export var is_friendly: bool = false:
	set(value):
		is_friendly = value
		_update_visuals()

var is_moving: bool = false

func _ready() -> void:
	current_health = max_health
	_update_visuals()
	set_physics_process(false)
	set_process(true)

func move_to(target_global_position: Vector2) -> void:
	if is_moving:
		return
	is_moving = true
	
	var distance = global_position.distance_to(target_global_position)
	var duration = distance / SPEED if SPEED > 0 else 0.2
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_global_position, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN_OUT)
		
	await tween.finished
	is_moving = false

# Функция получения урона
func take_damage(amount: int) -> void:
	current_health -= amount
	print("⚔️ ", name, " получил ", amount, " урона! Осталось HP: ", current_health, "/", max_health)
	
	# Эффект мигания при получении урона
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", FRIENDLY_COLOR if is_friendly else ENEMY_COLOR, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("💀 ", name, " погиб!")
	
	# Перед удалением сообщаем миру о завершении игры, если это был последний юнит
	var world = get_tree().current_scene
	if world and world.has_method("game_over"):
		# Функция game_over будет вызвана через TurnManager, когда списки обновятся,
		# но скрипт World может отслеживать глобальное состояние.
		pass
		
	queue_free()

func _update_visuals() -> void:
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		sprite.centered = true
		sprite.position = Vector2.ZERO

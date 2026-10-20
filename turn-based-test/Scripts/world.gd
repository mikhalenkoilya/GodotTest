extends Node2D

# Находим TurnManager (путь скорректирован под вашу иерархию TileMap/TurnManager)
@onready var turn_manager: Node = $TileMap/TurnManager

func _ready() -> void:
	# Проверяем, что TurnManager успешно найден, чтобы избежать новых вылетов
	if turn_manager:
		print("Мир загружен. Передаем управление TurnManager.")
		# Если в будущем вам понадобится метод старта игры, 
		# его можно будет вызвать здесь, например: turn_manager.start_game()
	else:
		push_error("Критическая ошибка: world.gd не смог найти TurnManager по указанному пути!")

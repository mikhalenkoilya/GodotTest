extends Node

func _ready():
	# Ждём 1 кадр чтобы GUT инициализировался
	await get_tree().process_frame
	
	var gut = get_node("/root/GutMain")
	if gut:
		gut.add_directory("res://tests/")
		gut.test_scripts()
	else:
		print("❌ GUT не найден! Проверьте что плагин включён.")

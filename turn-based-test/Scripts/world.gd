# res://Scripts/world.gd
extends Node2D

# Reference to the TurnManager
@onready var turn_manager = $TileMap/TurnManager
# Reference to the main TileMap for grid snapping
@onready var tile_map = $TileMap 

func _ready() -> void:
	if turn_manager:
		print("🌍 Мир загружен. Начинаем спавн отряда...")
		_spawn_squad()
		
		# Give the engine one frame to register the newly spawned nodes
		await get_tree().process_frame
		
		# Safely call the initialization function (works whether it's named initialize_game or _start_new_round)
		if turn_manager.has_method("initialize_game"):
			turn_manager.initialize_game()
		elif turn_manager.has_method("_start_new_round"):
			turn_manager._start_new_round()
		else:
			push_warning("⚠️ TurnManager не имеет функции инициализации!")
	else:              
		push_error("❌ Критическая ошибка: world.gd не смог найти TileMap/TurnManager!")

func _spawn_squad() -> void:
	# 1. Clean up any old friendly actors from previous battles
	for child in get_tree().get_nodes_in_group("actors"):
		if child is Actor and child.is_friendly:
			child.queue_free()
	
	# 2. Define spawn positions in TILE COORDINATES (X, Y)
	# Adjust these numbers to match empty, walkable tiles on your map!
	var spawn_tile_positions = [
		Vector2i(1, 1), # Slot 0
		Vector2i(1, 2), # Slot 1
		Vector2i(1, 3)  # Slot 2
	]
	
	# 3. Spawn new actors based on SquadManager choices
	for i in range(3):
		var class_data = SquadManager.get_class_data(i)
		if class_data:
			# Create a new Actor instance
			var new_actor = Actor.new()
			new_actor.name = "Hero_" + str(i + 1)
			new_actor.class_data = class_data
			new_actor.is_friendly = true
			
			# IMPORTANT: Add the actor to the TurnManager so it finds it during initialization
			turn_manager.add_child(new_actor)
			
			# Snap the actor to the grid immediately
			if tile_map:
				var local_pos = tile_map.map_to_local(spawn_tile_positions[i])
				new_actor.global_position = tile_map.to_global(local_pos)
				
			print("✅ Заспавнен: ", new_actor.name, " | Класс: ", class_data.display_name)
		else:
			push_error("❌ Не удалось загрузить данные класса для слота " + str(i))

func game_over(player_won: bool) -> void:
	print("🏁 ИГРА ОКОНЧЕНА. Победа: ", player_won)
	# Uncomment this to return to the squad selection screen after battle:
	# get_tree().change_scene_to_file("res://scenes/pre_combat_screen.tscn")

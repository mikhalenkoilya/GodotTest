# res://Scripts/world.gd
extends Node2D

@onready var turn_manager: Node = $TileMap/TurnManager

# Preload the Actor script (we will create nodes via code)
# If you have an actor.tscn, use: var actor_scene = preload("res://scenes/actor.tscn")

func _ready() -> void:
	if turn_manager:
		_spawn_squad()
		# Give TurnManager a frame to find the newly spawned actors
		await get_tree().process_frame
		turn_manager.initialize_game()
	else:
		push_error("Критическая ошибка: world.gd не смог найти TurnManager!")

func _spawn_squad() -> void:
	# 1. Remove any old friendly actors that might be in the scene
	for child in get_children():
		if child is Actor and child.is_friendly:
			child.queue_free()
	
	# 2. Define spawn positions (Adjust these X/Y values to match your TileMap grid!)
	# Use tile_map.to_global(tile_map.map_to_local(Vector2i(x, y))) for precise grid snapping
	var spawn_positions = [
		Vector2(100, 100), # Slot 0
		Vector2(100, 160), # Slot 1
		Vector2(100, 220)  # Slot 2
	]
	
	# 3. Spawn new actors based on SquadManager choices
	for i in range(3):
		var class_data = SquadManager.get_class_data(i)
		if class_data:
			var new_actor = Actor.new()
			new_actor.name = "Hero_" + str(i + 1)
			new_actor.class_data = class_data
			new_actor.is_friendly = true
			new_actor.global_position = spawn_positions[i]
			add_child(new_actor)
			
			# Optional: Add a Sprite2D child if your Actor scene doesn't handle it automatically
			# var sprite = Sprite2D.new()
			# sprite.texture = class_data.sprite_texture
			# new_actor.add_child(sprite)

func game_over(player_won: bool) -> void:
	print("ИГРА ОКОНЧЕНА. Победа: ", player_won)
	# Optionally return to menu:
	# get_tree().change_scene_to_file("res://scenes/pre_combat_screen.tscn")

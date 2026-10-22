extends Node2D

# Preload the actor scene (make sure this path matches your actual player actor scene)
const PLAYER_ACTOR_SCENE = preload("res://scenes/actor_player.tscn")

@onready var turn_manager: Node = $TileMap/TurnManager # Adjust path to match your tree
@onready var player_spawn: Marker2D = $PlayerSpawnPoint

func _ready() -> void:
	_spawn_squad()
	
	if turn_manager:
		# Give TurnManager a frame to register the new nodes, then start
		await get_tree().process_frame 
		turn_manager.initialize_game()
	else:
		push_error("TurnManager not found!")

func _spawn_squad() -> void:
	var squad_size = SquadManager.squad_classes.size()
	
	for i in range(squad_size):
		var class_path = SquadManager.squad_classes[i]
		var class_data = load(class_path) as ClassData
		
		var new_actor = PLAYER_ACTOR_SCENE.instantiate()
		new_actor.name = class_data.display_name + "_" + str(i)
		new_actor.class_data = class_data
		new_actor.is_friendly = true
		
		# Find the specific spawn point for this slot
		var spawn_point_name = "SpawnPoint_" + str(i)
		var spawn_point = get_node_or_null(spawn_point_name)
		
		if spawn_point:
			new_actor.global_position = spawn_point.global_position
		else:
			push_warning("Spawn point '", spawn_point_name, "' not found! Using fallback position.")
			new_actor.global_position = Vector2(i * 64.0, 0.0)
		
		add_child(new_actor)
		print("✅ Spawned: ", new_actor.name, " as ", class_data.display_name, " at ", new_actor.global_position)

	# 2. (Optional) Spawn Enemies dynamically here using the same logic
	# var enemy = ENEMY_ACTOR_SCENE.instantiate()
	# enemy.class_data = load("res://data/classes/warrior.tres")
	# enemy.is_friendly = false
	# add_child(enemy)

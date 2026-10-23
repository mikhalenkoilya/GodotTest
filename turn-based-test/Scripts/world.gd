extends Node2D

const PLAYER_ACTOR_SCENE = preload("res://scenes/actor_player.tscn")

# Matches: World -> Tiles -> TurnManager
@onready var turn_manager: Node = $Tiles/TurnManager

func _ready() -> void:
	_spawn_squad()
	
	if turn_manager:
		await get_tree().process_frame 
		turn_manager.initialize_game()
	else:
		push_error("TurnManager not found at $Tiles/TurnManager!")

func _spawn_squad() -> void:
	var squad_size = SquadManager.squad_classes.size()
	
	for i in range(squad_size):
		var class_data = SquadManager.get_class_data(i)
		if not class_data: continue
		
		var new_actor = PLAYER_ACTOR_SCENE.instantiate()
		new_actor.name = class_data.display_name + "_" + str(i)
		new_actor.class_data = class_data
		new_actor.is_friendly = true
		
		# Matches: SpawnPoint_0, SpawnPoint_1, etc. as direct children of World
		var spawn_point_name = "SpawnPoint_" + str(i)
		var spawn_point = get_node_or_null(spawn_point_name)
		
		if spawn_point:
			new_actor.global_position = spawn_point.global_position
		else:
			push_warning("Spawn point '%s' not found! Using fallback." % spawn_point_name)
			new_actor.global_position = Vector2(i * 64.0, 0.0)
		
		add_child(new_actor)
		
		# Explicitly register dynamically spawned allies
		turn_manager.register_actor(new_actor)
		print("✅ Spawned: ", new_actor.name)

func game_over(player_won: bool) -> void:
	print("GAME OVER! Player won: ", player_won)
	# Add your scene change or UI popup logic here

extends Node2D

# Preload the actor scene (can be used for both allies and enemies)
const ACTOR_SCENE = preload("res://scenes/actor_player.tscn")

@onready var turn_manager: Node = $Tiles/TurnManager

# Define enemy squad composition using the same .tres class system
var enemy_squad_classes: Array[String] = [
	"res://data/classes/warrior.tres",
	"res://data/classes/warrior.tres",
	"res://data/classes/warrior.tres"
]

func _ready() -> void:
	_spawn_squad()
	_spawn_enemies() # <-- Added enemy spawn logic
	
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
		
		var new_actor = _create_actor(class_data, true, i)
		add_child(new_actor)
		turn_manager.register_actor(new_actor)
		print("✅ Spawned Ally: ", new_actor.name)

func _spawn_enemies() -> void:
	for i in range(enemy_squad_classes.size()):
		var class_path = enemy_squad_classes[i]
		var class_data = load(class_path) as ClassData
		
		if not class_data:
			push_error("❌ FAILED to load enemy class: " + class_path + ". Check the file path!")
			continue
		
		var new_actor = _create_actor(class_data, false, i)
		add_child(new_actor)
		turn_manager.register_actor(new_actor)
		print("✅ Spawned Enemy: ", new_actor.name, " with move_range: ", class_data.move_range)

# Helper function to keep spawn logic DRY (Don't Repeat Yourself)
func _create_actor(class_data: ClassData, friendly: bool, index: int) -> Actor:
	var new_actor = ACTOR_SCENE.instantiate()
	new_actor.name = class_data.display_name + "_" + ("Ally" if friendly else "Enemy") + "_" + str(index)
	new_actor.class_data = class_data
	new_actor.is_friendly = friendly # This triggers the red color in actor.gd
	
	# Determine spawn point based on faction
	var spawn_point_name = ("SpawnPoint_" if friendly else "EnemySpawnPoint_") + str(index)
	var spawn_point = get_node_or_null(spawn_point_name)
	
	if spawn_point:
		new_actor.global_position = spawn_point.global_position
	else:
		push_warning("Spawn point '%s' not found! Using fallback." % spawn_point_name)
		# Fallback positions: Allies on left (x=0), Enemies on right (x=512)
		var offset_x = 0.0 if friendly else 512.0
		new_actor.global_position = Vector2(offset_x + (index * 64.0), 128.0)
	
	return new_actor

func game_over(player_won: bool) -> void:
	print("GAME OVER! Player won: ", player_won)
	# Add your scene change or UI popup logic here

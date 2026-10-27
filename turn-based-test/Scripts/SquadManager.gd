extends Node

# Example data structure for your squad
var squad_members: Array[Actor] = []

func _ready() -> void:
	print("✅ SquadManager Autoload is working!")
	# Optional: Ensure random number generation is seeded differently each run
	# randomize() 

func add_to_squad(actor: Actor) -> void:
	if actor and not squad_members.has(actor):
		squad_members.append(actor)
		print("Added ", actor.name, " to squad.")

func remove_from_squad(actor: Actor) -> void:
	squad_members.erase(actor)
	
var available_classes: Array[String] = [
	"res://data/classes/warrior.tres",
	"res://data/classes/archer.tres",
	"res://data/classes/mage.tres",
	"res://data/classes/Spearman.tres"
]

# 🔄 UPDATED: Start empty, will be populated dynamically
var squad_classes: Array[String] = []

# 🔄 NEW: Generate a random squad of enemies
func generate_random_enemy_squad(count: int = 3) -> Array[String]:
	var random_squad: Array[String] = []
	for i in range(count):
		var random_idx = randi() % available_classes.size()
		random_squad.append(available_classes[random_idx])
	return random_squad

# Get the ClassData resource for a specific squad slot
func get_class_data(slot_index: int) -> ClassData:
	if slot_index >= squad_classes.size():
		push_error("Slot index out of bounds: " + str(slot_index))
		return null
		
	var path = squad_classes[slot_index]
	var loaded_resource = load(path)
	if loaded_resource == null:
		push_error("Failed to load class data at: " + path)
		return null
	return loaded_resource as ClassData

# Cycle to the next or previous class for a specific slot (if used in UI)
func cycle_class(slot_index: int, direction: int) -> void:
	if slot_index >= squad_classes.size():
		return
		
	var current_idx = available_classes.find(squad_classes[slot_index])
	if current_idx == -1:
		current_idx = 0
	
	current_idx += direction
	if current_idx >= available_classes.size():
		current_idx = 0
	elif current_idx < 0:
		current_idx = available_classes.size() - 1
		
	squad_classes[slot_index] = available_classes[current_idx]

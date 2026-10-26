extends Node

# Example data structure for your squad
var squad_members: Array[Actor] = []

func _ready() -> void:
	print("✅ SquadManager Autoload is working!")

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
	"res://data/classes/ninja.tres"
]

# Default squad composition
var squad_classes: Array[String] = [
	"res://data/classes/warrior.tres",
	"res://data/classes/warrior.tres",
	"res://data/classes/archer.tres"
]

# Get the ClassData resource for a specific squad slot (0, 1, or 2)
func get_class_data(slot_index: int) -> ClassData:
	var path = squad_classes[slot_index]
	var loaded_resource = load(path)
	if loaded_resource == null:
		push_error("Failed to load class data at: " + path)
		return null
	return loaded_resource as ClassData

# Cycle to the next or previous class for a specific slot
func cycle_class(slot_index: int, direction: int) -> void:
	var current_idx = available_classes.find(squad_classes[slot_index])
	if current_idx == -1:
		current_idx = 0
	
	current_idx += direction
	if current_idx >= available_classes.size():
		current_idx = 0
	elif current_idx < 0:
		current_idx = available_classes.size() - 1
		
	squad_classes[slot_index] = available_classes[current_idx]

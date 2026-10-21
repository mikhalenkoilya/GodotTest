# res://Scripts/SquadManager.gd
extends Node

# Paths to your class resources
var available_classes: Array[String] = [
	"res://data/classes/warrior.tres",
	"res://data/classes/archer.tres",
	"res://data/classes/mage.tres"
]

# Default squad composition (can be changed by the player)
var squad_classes: Array[String] = [
	"res://data/classes/warrior.tres",
	"res://data/classes/archer.tres",
	"res://data/classes/mage.tres"
]

# Get the ClassData resource for a specific squad slot (0, 1, or 2)
func get_class_data(slot_index: int) -> ClassData:
	var path = squad_classes[slot_index]
	return load(path) as ClassData

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

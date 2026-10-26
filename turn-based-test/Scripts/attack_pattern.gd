class_name AttackPattern
extends Resource

@export var pattern_name: String = "Single Target"
@export var max_range_heuristic: int = 1

# Changed default to a standard 4-directional melee attack
@export var relative_cells: Array[Vector2i] = [Vector2i(0, 0)]

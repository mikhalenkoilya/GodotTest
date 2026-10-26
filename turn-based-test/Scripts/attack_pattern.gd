class_name AttackPattern
extends Resource

@export var pattern_name: String = "Single Target"

# Используется ИИ для понимания, насколько близко нужно подойти
@export var max_range_heuristic: int = 1

# Фактическая форма атаки - список относительных смещений клеток
# Например, для ромба радиусом 1: [(0,1), (0,-1), (1,0), (-1,0)]
@export var relative_cells: Array[Vector2i] = [Vector2i(0, 0)]

extends Resource
class_name SkillData

@export var display_name: String = "New Skill"
@export_multiline var description: String = "Describe what the skill does."
@export var icon: Texture2D

@export_group("Targeting & Economy")
@export var cooldown: int = 2
@export var cast_range: int = 1 
@export var min_range: int = 0 
@export var ends_attack_phase: bool = true

@export_group("Shape")
"res://data/AttackShapes/cross_1.tres"
"res://data/AttackShapes/cross_2.tres"
"res://data/AttackShapes/cross_3.tres"
"res://data/AttackShapes/cross_3_excl_cross_1.tres"
"res://data/AttackShapes/diamond_2.tres"
"res://data/AttackShapes/diamond_2_excl_cross_1.tres"
"res://data/AttackShapes/diamond_3.tres"
"res://data/AttackShapes/diamond_3_excl_cross_1.tres"
"res://data/AttackShapes/square_3x3.tres"
@export var attack_pattern: AttackPattern 

@export_group("Effects")
@export var effects: Array[SkillEffect] = []

@export_group("Restrictions")
@export var requires_melee: bool = false
@export var blocked_by_disarm: bool = true

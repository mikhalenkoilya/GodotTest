class_name ClassData
extends Resource

@export var display_name: String = "Gladiator"
@export var max_hp: int = 25
@export var attack_damage: int = 10
@export var move_range: int = 2
@export var initiative: int = 15
@export var max_armor: int = 10 # Physical shield
@export var max_counter_attacks: int = 1 # Ответные атаки за раунд

@export var attack_pattern: AttackPattern # шаблон атаки

@export var sprite_texture: Texture2D
@export var sprite_frames: SpriteFrames

@export var skills: Array[SkillData] = []

@export var passive_armor_bypass: float = 0.0 

@export var immune_to_forced_movement: bool = false 

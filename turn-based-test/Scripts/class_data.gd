class_name ClassData
extends Resource

enum AttackType { PHYSICAL, MAGIC }

@export var display_name: String = "Воин"
@export var max_hp: int = 100
@export var attack_damage: int = 15
@export var move_range: int = 3
@export var attack_range: int = 1

@export var attack_pattern: AttackPattern 

@export var sprite_texture: Texture2D
@export var sprite_frames: SpriteFrames

@export var attack_type: AttackType = AttackType.PHYSICAL
@export var max_armor: int = 30
@export var max_magic_resist: int = 30

@export var max_counter_attacks: int = 1

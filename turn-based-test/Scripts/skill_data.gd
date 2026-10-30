extends Resource
class_name SkillData

@export var display_name: String = "New Skill"
@export_multiline var description: String = "Describe what the skill does."
@export var icon: Texture2D

@export_group("Targeting & Economy")
@export var cooldown: int = 2
@export var cast_range: int = 1
@export var min_range: int = 0 # GDD: Retiarius Net cannot target adjacent (set to 2)
@export var ends_attack_phase: bool = true # GDD default

@export_group("Effects")
@export var effects: Array[SkillEffect] = []

@export_group("Restrictions")
@export var requires_melee: bool = false
@export var blocked_by_disarm: bool = true # GDD: Damage skills blocked by disarm

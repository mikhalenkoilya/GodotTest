extends Resource
class_name SkillData

@export var display_name: String = "New Skill"
@export_multiline var description: String = "Describe what the skill does."
@export var icon: Texture2D

@export_group("Combat Mechanics")
@export var cooldown: int = 2
@export var damage_multiplier: float = 1.0
@export var attack_type: ClassData.AttackType = ClassData.AttackType.PHYSICAL

# 🆕 GDD: Multi-hit & Bypass Support
@export var hit_count: int = 1 # Dimachaerus Flurry = 3
@export var armor_bypass_percent: float = 0.0 # Thraex Passive = 0.1, Velites = 0.25

@export_group("Targeting & Shape")
@export var attack_pattern: AttackPattern
@export var cast_range: int = 1

@export_group("Economy")
# GDD: "Using any active skill immediately ends the Attack phase"
@export var ends_attack_phase: bool = true 
# GDD: Disarm prevents skills whose primary effect is dealing damage
@export var is_damage_dealing: bool = true 

@export var applies_status: StatusEffect # e.g., Retiarius Net (Root), Scissor (Disarm)

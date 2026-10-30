extends Resource
class_name SkillData

@export var display_name: String = "New Skill"
@export_multiline var description: String = "Describe what the skill does."
@export var icon: Texture2D

@export_group("Economy")
@export var ends_attack_phase: bool = true # GDD: Using any active skill immediately ends the Attack phase
@export var is_damage_dealing: bool = true # For Disarm checks

@export_group("Combat Mechanics")
# How many turns the player must wait before using this skill again
@export var cooldown: int = 2 
# Multiplies the actor's base attack_damage (1.0 = 100%, 1.5 = 150%)
@export var damage_multiplier: float = 1.0 
@export var attack_type: ClassData.AttackType = ClassData.AttackType.PHYSICAL

@export_group("Targeting & Shape")
# Reusing your existing AttackPattern resource for the 1x3 shape!
@export var attack_pattern: AttackPattern 
# How far the skill can reach (1 = melee, 2+ = ranged)
@export var cast_range: int = 1 

class_name SelfBuffEffect
extends SkillEffect

@export var grants_temp_armor: int = 0 # Crupellarius: 15
@export var damage_reduction_percent: float = 0.0 # Provocator: 0.5

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if grants_temp_armor > 0:
		attacker.temp_armor += grants_temp_armor
		attacker.current_armor += grants_temp_armor
	
	if damage_reduction_percent > 0.0:
		attacker.damage_reduction = damage_reduction_percent

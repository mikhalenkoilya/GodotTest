class_name ModifyBasicAttackEffect
extends SkillEffect

@export var new_pattern: AttackPattern
@export var duration_turns: int = 2 # Hoplomachus

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	attacker._basic_attack_pattern_override = new_pattern
	attacker._override_turns_remaining = duration_turns

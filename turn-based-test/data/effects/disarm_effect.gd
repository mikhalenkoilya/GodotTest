class_name DisarmEffect
extends SkillEffect

# Scissor "Disarm": a vicious sweeping cut with the sica that wounds the
# target and knocks their weapon away, preventing them from attacking for
# a number of turns (DISARM status -> actor.is_disarmed gating).

@export var damage_multiplier: float = 0.75
@export var armor_bypass_percent: float = 0.0
@export var applies_status: StatusEffect = null

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead:
		return

	# 1. Deal the opening cut first (the disarm lands even if damage kills).
	if damage_multiplier > 0.0:
		var raw_damage = int(attacker.class_data.attack_damage * damage_multiplier)
		await target.take_damage(raw_damage, armor_bypass_percent, null)
		if target.is_dead:
			return

	# 2. Knock the weapon away: apply the Disarm status (refreshes duration
	# via Actor.apply_status_effect if already present).
	if applies_status != null:
		target.apply_status_effect(applies_status)

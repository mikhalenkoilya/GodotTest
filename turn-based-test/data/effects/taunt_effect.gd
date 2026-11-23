class_name TauntEffect
extends SkillEffect

# Assign a "Taunt" StatusEffect resource in the inspector (e.g., duration: 1 or 2)
@export var taunt_status: StatusEffect

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead:
		return

	# GDD: Classes immune to forced movement/taunt ignore it entirely.
	if target.class_data and target.class_data.get("immune_to_forced_movement"):
		print("🛡️ %s is immune to Taunt!" % target.name)
		return

	# 1. Apply the Taunt status effect
	if taunt_status:
		target.apply_status_effect(taunt_status)
	
	# 2. Mark the attacker as the source of the taunt
	target.taunt_source = attacker
	
	print("🗣️ %s taunts %s! Target will prioritize them on their next turn." % [attacker.name, target.name])

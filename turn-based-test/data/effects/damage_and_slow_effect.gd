class_name DamageAndSlowEffect
extends SkillEffect

@export var damage_multiplier: float = 1.0
@export var slow_duration: int = 1

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead: return
	
	var raw_damage = int(attacker.class_data.attack_damage * damage_multiplier)
	await target.take_damage(raw_damage, 0.0, null)
	
	# Apply Slow Status
	var slow_status = load("res://data/effects/slow_status.tres") # Ensure this exists
	if slow_status:
		var new_status = slow_status.duplicate()
		new_status.duration = slow_duration
		target.apply_status_effect(new_status)

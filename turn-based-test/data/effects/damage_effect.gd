class_name DamageEffect
extends SkillEffect

@export var damage_multiplier: float = 1.0
@export var armor_bypass_percent: float = 0.0
@export var hit_count: int = 1 # For Dimachaerus Flurry
@export var applies_status: StatusEffect = null

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead:
		return
	
	for i in range(hit_count):
		if target.is_dead:
			break
		
		var raw_damage = int(attacker.class_data.attack_damage * damage_multiplier)
		await target.take_damage(raw_damage,  armor_bypass_percent, applies_status)
		
		# Visual pause between multi-hits
		if hit_count > 1 and i < hit_count - 1:
			await turn_manager.get_tree().create_timer(0.2).timeout

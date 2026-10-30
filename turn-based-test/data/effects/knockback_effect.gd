class_name KnockbackEffect
extends SkillEffect

@export var distance: int = 1
@export var collision_damage_multiplier: float = 0.0 # Murmillo: 0.7
@export var collision_status: StatusEffect = null # Murmillo: Stun

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead or target.class_data.immune_to_forced_movement:
		return

	var actor_cell = turn_manager.tile_map.local_to_map(turn_manager.tile_map.to_local(attacker.global_position))
	var target_cell = turn_manager.tile_map.local_to_map(turn_manager.tile_map.to_local(target.global_position))
	
	var direction = (target_cell - actor_cell).normalized()
	var destination_cell = target_cell + (direction * distance).round()

	# Check for collision (wall or another actor)
	var collision_actor = turn_manager._get_actor_at_cell(destination_cell)
	var is_wall = turn_manager._is_wall_at_cell(destination_cell) # Implement this in TurnManager

	if collision_actor or is_wall:
		# GDD: Murmillo collision logic
		if collision_damage_multiplier > 0.0:
			var collision_dmg = int(attacker.class_data.attack_damage * collision_damage_multiplier)
			await target.take_damage(collision_dmg, attacker.class_data.attack_type)
		
		if collision_status != null:
			target.apply_status(collision_status)
	else:
		# Safe to move
		var target_pos = turn_manager.tile_map.map_to_local(destination_cell)
		await target.move_to(target_pos)

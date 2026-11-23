class_name PullEffect
extends SkillEffect

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead or target.class_data.immune_to_forced_movement:
		return

	var adjacent_cell = turn_manager._get_valid_adjacent_cell(attacker, target)
	if adjacent_cell != Vector2i(-1, -1):
		# FIX: Added .to_global() to match the correct coordinate conversion 
		# used in taunt_effect.gd and TurnManager._try_move_actor
		var target_pos = turn_manager.tile_map.to_global(turn_manager.tile_map.map_to_local(adjacent_cell))
		await target.move_to(target_pos)

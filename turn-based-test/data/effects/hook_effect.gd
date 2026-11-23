class_name HookEffect
extends SkillEffect

# Laquearius "Hook": lashes out with a lasso, dealing physical damage and
# dragging the target to an empty tile adjacent to the caster.

@export var damage_multiplier: float = 0.5
@export var applies_status: StatusEffect = null

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead:
		return

	# 1. Deal damage first (even if the pull is resisted/blocked).
	if damage_multiplier > 0.0:
		var raw_damage = int(attacker.class_data.attack_damage * damage_multiplier)
		await target.take_damage(raw_damage, 0.0, applies_status)
		if target.is_dead:
			return

	# 2. Forced movement: respect immunity flags, like Pull/Knockback do.
	if target.class_data.immune_to_forced_movement:
		return
	if target.has_status("Root"):
		return

	# 3. Pull the target onto an empty tile adjacent to the attacker.
	var actor_cell = turn_manager.tile_map.local_to_map(turn_manager.tile_map.to_local(attacker.global_position))
	var adjacent_cells = [
		actor_cell + Vector2i(1, 0),
		actor_cell + Vector2i(-1, 0),
		actor_cell + Vector2i(0, 1),
		actor_cell + Vector2i(0, -1),
	]

	var destination_cell = Vector2i(-1, -1)
	for cell in adjacent_cells:
		if turn_manager._is_cell_occupied(cell):
			continue
		if turn_manager._get_tile_cost(cell) >= 9999: # wall / impassable
			continue
		destination_cell = cell
		break

	if destination_cell == Vector2i(-1, -1):
		return # fully surrounded: the hook catches but cannot drag

	var target_pos = turn_manager.tile_map.to_global(turn_manager.tile_map.map_to_local(destination_cell))
	await target.move_to(target_pos)

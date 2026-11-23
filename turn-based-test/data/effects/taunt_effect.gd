class_name TauntEffect
extends SkillEffect

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead: return

	# GDD: Classes immune to forced movement (e.g. Crupellarius) ignore Taunt entirely.
	if target.class_data and target.class_data.immune_to_forced_movement:
		return

	var tile_map = turn_manager.tile_map
	var provocator_cell = tile_map.local_to_map(tile_map.to_local(attacker.global_position))
	var target_cell = tile_map.local_to_map(tile_map.to_local(target.global_position))

	# 1. Calculate target's reachable cells (Respects Root/Slow via get_effective_move_range)
	var target_move_range = target.class_data.move_range
	if target.has_method("get_effective_move_range"):
		target_move_range = target.get_effective_move_range()

	var reachable_cells = turn_manager._calculate_reachable_cells(target_cell, target_move_range)
	if not reachable_cells.has(target_cell):
		reachable_cells[target_cell] = 0

	# 2. Find valid attack tiles (Where the target can hit the Provocator).
	# FIX: Use the PROVOCATOR's melee pattern for the forced attack, not the
	# taunted unit's own attack shape (a ranged enemy would otherwise "melee" from afar).
	var provocator_pattern = null
	if attacker.attack_pattern:
		provocator_pattern = attacker.attack_pattern
	elif attacker.class_data:
		provocator_pattern = attacker.class_data.attack_pattern

	var valid_attack_tiles = []

	if provocator_pattern:
		for cell in reachable_cells.keys():
			if cell == provocator_cell: continue
			for offset in provocator_pattern.relative_cells:
				if cell + offset == provocator_cell:
					if not valid_attack_tiles.has(cell):
						valid_attack_tiles.append(cell)
					break

	var best_tile = target_cell

	if valid_attack_tiles.size() > 0:
		# Pick the closest valid attack tile; skip tiles occupied by other actors.
		var closest_tile = valid_attack_tiles[0]
		var closest_dist = abs(closest_tile.x - target_cell.x) + abs(closest_tile.y - target_cell.y)
		for tile in valid_attack_tiles:
			if tile != target_cell and turn_manager._is_cell_occupied(tile):
				continue
			var dist = abs(tile.x - target_cell.x) + abs(tile.y - target_cell.y)
			if dist < closest_dist:
				closest_dist = dist
				closest_tile = tile
		best_tile = closest_tile
	else:
		# GDD EDGE CASE: If blocked/Rooted, movement cuts short on the last accessible tile
		# (closest free tile toward the Provocator).
		var closest_tile = target_cell
		var closest_dist = abs(closest_tile.x - provocator_cell.x) + abs(closest_tile.y - provocator_cell.y)
		for cell in reachable_cells.keys():
			if cell == target_cell: continue
			if turn_manager._is_cell_occupied(cell):
				continue
			var dist = abs(cell.x - provocator_cell.x) + abs(cell.y - provocator_cell.y)
			if dist < closest_dist:
				closest_dist = dist
				closest_tile = cell
		best_tile = closest_tile

	# 3. Move the target
	if best_tile != target_cell:
		# FIX: Convert the cell to GLOBAL coordinates before moving (same as
		# TurnManager._try_move_actor). map_to_local() alone returns tile-map-local
		# coordinates, which teleported the taunted unit to the wrong place
		# whenever the TileMapLayer was offset from the origin.
		var target_global_pos = tile_map.to_global(tile_map.map_to_local(best_tile))
		await target.move_to(target_global_pos)

	# 4. Attack if in range
	var new_target_cell = tile_map.local_to_map(tile_map.to_local(target.global_position))
	var can_attack_now = false

	if provocator_pattern:
		for offset in provocator_pattern.relative_cells:
			if new_target_cell + offset == provocator_cell:
				can_attack_now = true
				break

	# GDD: "target still attacks from their current tile if in range. If out of range, skips attack."
	# FIX: Only force the attack if the target is actually able to attack
	# (not stunned/disarmed), mirroring TurnManager._can_actor_attack().
	if can_attack_now and turn_manager._can_actor_attack(target):
		await turn_manager._resolve_attack(target, attacker)

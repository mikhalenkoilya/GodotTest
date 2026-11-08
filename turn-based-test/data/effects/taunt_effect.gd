class_name TauntEffect
extends SkillEffect

func execute(attacker: Actor, target: Actor, skill_data: SkillData, turn_manager: Node) -> void:
	if not target or target.is_dead: return
	
	var tile_map = turn_manager.tile_map
	var provocator_cell = tile_map.local_to_map(tile_map.to_local(attacker.global_position))
	var target_cell = tile_map.local_to_map(tile_map.to_local(target.global_position))
	
	# 1. Calculate target's reachable cells (Respects Root/Slow via get_effective_move_range)
	var target_move_range = target.class_data.move_range
	if target.has_method("get_effective_move_range"):
		target_move_range = target.get_effective_move_range()
		
	var reachable_cells = turn_manager._calculate_reachable_cells(target_cell, target_move_range)
	if not reachable_cells.has(target_cell):
		reachable_cells.append(target_cell)
	
	# 2. Find valid attack tiles (Where the target can hit the Provocator)
	var target_pattern = target.class_data.attack_pattern
	var valid_attack_tiles = []
	
	if target_pattern:
		for cell in reachable_cells:
			for offset in target_pattern.relative_cells:
				if cell + offset == provocator_cell:
					if not valid_attack_tiles.has(cell):
						valid_attack_tiles.append(cell)
					break
	
	var best_tile = target_cell
	
	if valid_attack_tiles.size() > 0:
		# ✅ GDD: Move into melee range (Pick the closest valid attack tile)
		var closest_tile = valid_attack_tiles[0]
		var closest_dist = abs(closest_tile.x - target_cell.x) + abs(closest_tile.y - target_cell.y)
		for tile in valid_attack_tiles:
			var dist = abs(tile.x - target_cell.x) + abs(tile.y - target_cell.y)
			if dist < closest_dist:
				closest_dist = dist
				closest_tile = tile
		best_tile = closest_tile
	else:
		# ✅ GDD EDGE CASE: If blocked/Rooted, movement cuts short on the last accessible tile
		var closest_tile = reachable_cells[0]
		var closest_dist = abs(closest_tile.x - provocator_cell.x) + abs(closest_tile.y - provocator_cell.y)
		for cell in reachable_cells:
			var dist = abs(cell.x - provocator_cell.x) + abs(cell.y - provocator_cell.y)
			if dist < closest_dist:
				closest_dist = dist
				closest_tile = cell
		best_tile = closest_tile

	# 3. Move the target
	if best_tile != target_cell:
		var target_global_pos = tile_map.map_to_local(best_tile)
		await target.move_to(target_global_pos)
		
	# 4. Attack if in range
	var new_target_cell = tile_map.local_to_map(tile_map.to_local(target.global_position))
	var can_attack_now = false
	
	if target_pattern:
		for offset in target_pattern.relative_cells:
			if new_target_cell + offset == provocator_cell:
				can_attack_now = true
				break
				
	# ✅ GDD: "target still attacks from their current tile if in range. If out of range, skips attack."
	if can_attack_now:
		await turn_manager._resolve_attack(target, attacker)

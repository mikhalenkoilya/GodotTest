extends "res://addons/gut/test.gd"

# MARK: - Setup & Teardown
var actor: Actor
var class_data: ClassData

func before_each():
	# Создаём реальный ClassData ресурс вместо моков
	class_data = ClassData.new()
	class_data.max_hp = 30
	class_data.max_armor = 20
	class_data.attack_damage = 12
	class_data.move_range = 3
	class_data.initiative = 10
	# attack_pattern оставляем null — в этих тестах он не нужен
	
	actor = Actor.new()
	actor.class_data = class_data
	actor._ready()
	
	# Чистое состояние
	actor.is_stunned = false
	actor.is_rooted = false
	actor.is_disarmed = false
	actor.active_statuses.clear()

func after_each():
	if is_instance_valid(actor):
		actor.queue_free()

# ==============================================================================
# TEST 1: Armor Depletion Logic (GDD Page 1)
# ==============================================================================
func test_armor_depletion_no_bypass():
	assert_eq(actor.current_armor, 20, "Initial armor should be 20")
	assert_eq(actor.current_health, 30, "Initial HP should be 30")
	
	await actor.take_damage(25, 0.0, null)
	
	assert_eq(actor.current_armor, 0, "Armor should be depleted to 0")
	assert_eq(actor.current_health, 25, "HP should be reduced by spill-over (30 - 5 = 25)")

func test_armor_depletion_with_bypass_velites():
	# 25% bypass от 15 урона = 3 bypass, 12 shield damage
	await actor.take_damage(15, 0.25, null)
	
	assert_eq(actor.current_armor, 8, "Armor reduced by shield damage (20 - 12 = 8)")
	assert_eq(actor.current_health, 27, "HP reduced by bypass only (30 - 3 = 27)")

func test_armor_depletion_with_bypass_thraex():
	# Setup: Actor has 20 Armor, 30 HP
	# Action: Thraex deals 20 damage with 10% bypass
	# Expected: 10% of 20 = 2 bypass damage (to HP). 18 shield damage (to Armor).
	await actor.take_damage(20, 0.10, null)
	
	# Assert: Armor takes 18 (20 - 18 = 2). HP takes 2 bypass (30 - 2 = 28).
	assert_eq(actor.current_armor, 2, "Armor should be reduced by shield damage (20 - 18 = 2)")
	assert_eq(actor.current_health, 28, "HP should be reduced by bypass damage only (30 - 2 = 28)")

# ==============================================================================
# TEST 2: Status Gating - Root
# ==============================================================================
func test_root_prevents_movement():
	assert_true(actor.can_move(), "Actor should be able to move initially")
	
	actor.is_rooted = true
	assert_false(actor.can_move(), "Rooted actor MUST NOT be able to move")
	
	actor.is_rooted = false
	assert_true(actor.can_move(), "Actor should move after root expires")

# ==============================================================================
# TEST 3: Status Gating - Disarm & Stun
# ==============================================================================
func test_disarm_prevents_attack_but_allows_movement():
	actor.is_disarmed = true
	
	assert_false(actor.can_attack(), "Disarmed actor MUST NOT attack")
	assert_true(actor.can_move(), "Disarmed actor SHOULD still move")

func test_stun_prevents_all_actions():
	actor.is_stunned = true
	
	assert_false(actor.can_move(), "Stunned actor MUST NOT move")
	assert_false(actor.can_attack(), "Stunned actor MUST NOT attack")

# ==============================================================================
# TEST 4: Grid Occupancy Logic
# ==============================================================================
func test_occupancy_logic():
	var actor1 = Actor.new()
	var actor2 = Actor.new()
	var all_actors = [actor1, actor2]
	
	var is_occupied = func(target_global_pos: Vector2, actors: Array) -> bool:
		for a in actors:
			if is_instance_valid(a) and not a.is_dead:
				if a.global_position.distance_to(target_global_pos) < 10.0:
					return true
		return false
	
	actor1.global_position = Vector2(100, 100)
	actor2.global_position = Vector2(200, 200)
	
	assert_false(is_occupied.call(Vector2(300, 300), all_actors), "Empty tile not occupied")
	assert_true(is_occupied.call(Vector2(100, 100), all_actors), "Tile with Actor1 occupied")
	
	actor1.is_dead = true
	assert_false(is_occupied.call(Vector2(100, 100), all_actors), "Dead actor doesn't occupy tile")
	
	actor1.queue_free()
	actor2.queue_free()

# ==============================================================================
# TEST 5: Multi-Hit Armor Stripping (Dimachaerus Flurry)
# ==============================================================================
func test_multi_hit_armor_stripping():
	assert_eq(actor.current_armor, 20, "Initial armor check")
	
	# Hit 1: 9 damage, armor 20 -> 11
	await actor.take_damage(9, 0.0, null)
	assert_eq(actor.current_armor, 11, "After hit 1: Armor 11")
	assert_eq(actor.current_health, 30, "After hit 1: HP 30")
	
	# Hit 2: 9 damage, armor 11 -> 2
	await actor.take_damage(9, 0.0, null)
	assert_eq(actor.current_armor, 2, "After hit 2: Armor 2")
	assert_eq(actor.current_health, 30, "After hit 2: HP 30")
	
	# Hit 3: 9 damage, armor 2 -> 0, HP takes 7 spill
	await actor.take_damage(9, 0.0, null)
	assert_eq(actor.current_armor, 0, "After hit 3: Armor 0")
	assert_eq(actor.current_health, 23, "After hit 3: HP 23 (30 - 7 spill)")

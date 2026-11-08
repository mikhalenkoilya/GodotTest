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

	actor = Actor.new()
	actor.class_data = class_data
	actor._ready()
	
	# ВАЖНО: Добавляем в дерево сцены, чтобы get_tree() не возвращал null
	add_child(actor)
	
	# Чистое состояние
	actor.is_stunned = false
	actor.is_rooted = false
	actor.is_disarmed = false
	actor.active_statuses.clear()

func after_each():
	if is_instance_valid(actor):
		actor.free() # free() автоматически удаляет узел из дерева

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
	await actor.take_damage(15, 0.25, null)
	
	assert_eq(actor.current_armor, 8, "Armor reduced by shield damage (20 - 12 = 8)")
	assert_eq(actor.current_health, 27, "HP reduced by bypass only (30 - 3 = 27)")

func test_armor_depletion_with_bypass_thraex():
	await actor.take_damage(20, 0.10, null)
	
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
	add_child(actor1)
	add_child(actor2)
	
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
	
	actor1.free()
	actor2.free()

# ==============================================================================
# TEST 5: Multi-Hit Armor Stripping (Dimachaerus Flurry)
# ==============================================================================
func test_multi_hit_armor_stripping():
	assert_eq(actor.current_armor, 20, "Initial armor check")
	
	await actor.take_damage(9, 0.0, null)
	assert_eq(actor.current_armor, 11, "After hit 1: Armor 11")
	assert_eq(actor.current_health, 30, "After hit 1: HP 30")
	
	await actor.take_damage(9, 0.0, null)
	assert_eq(actor.current_armor, 2, "After hit 2: Armor 2")
	assert_eq(actor.current_health, 30, "After hit 2: HP 30")
	
	await actor.take_damage(9, 0.0, null)
	assert_eq(actor.current_armor, 0, "After hit 3: Armor 0")
	assert_eq(actor.current_health, 23, "After hit 3: HP 23 (30 - 7 spill)")

# ==============================================================================
# TEST 6: Thraex Sica Cut (Armor Bypass Logic - GDD 15%)
# ==============================================================================
func test_thraex_sica_cut_armor_bypass():
	class_data.attack_damage = 20
	actor.current_armor = 20
	actor.current_health = 30
	
	await actor.take_damage(24, 0.15, null)
	
	assert_eq(actor.current_armor, 0, "Armor should be depleted to 0")
	assert_eq(actor.current_health, 26, "HP should be 26 (30 - 4)")

# ==============================================================================
# TEST 7: Retiarius Net (Integration Test)
# ==============================================================================
func test_retiarius_net_integration():
	var net_skill = load("res://data/skills/net.tres") as SkillData
	if net_skill == null:
		net_skill = load("res://data/skills/retiarius_net.tres") as SkillData
		
	assert_not_null(net_skill, "net.tres or retiarius_net.tres must exist in data/skills/")
	
	var attacker = Actor.new()
	attacker.class_data = class_data
	attacker._ready()
	add_child(attacker) # Добавляем в дерево
	
	assert_true(actor.can_move(), "Target should be able to move initially")
	
	for effect in net_skill.effects:
		# Передаем 'actor' как turn_manager, чтобы get_tree() работал внутри эффекта
		effect.execute(attacker, actor, net_skill, actor)
	
	assert_eq(actor.current_armor, 14, "Armor should be reduced by 0.5x ATK (6)")
	assert_eq(actor.current_health, 30, "HP should remain full")
	
	assert_true(actor.is_rooted, "Target MUST be rooted after Net")
	assert_false(actor.can_move(), "Rooted actor MUST NOT be able to move")
	assert_eq(actor.active_statuses.size(), 1, "Should have exactly 1 active status (Root)")
	
	attacker.free()

# ==============================================================================
# TEST 8: Thraex Sica Cut (Integration Test)
# ==============================================================================
func test_thraex_sica_cut_integration():
	var sica_skill = load("res://data/skills/sica_cut.tres") as SkillData
	assert_not_null(sica_skill, "sica_cut.tres must exist")
	
	class_data.attack_damage = 16 
	actor.current_armor = 20
	actor.current_health = 30
	
	var attacker = Actor.new()
	attacker.class_data = class_data
	attacker._ready()
	add_child(attacker)
	
	for effect in sica_skill.effects:
		effect.execute(attacker, actor, sica_skill, actor)
	
	assert_true(actor.current_armor <= 3, "Armor should be heavily stripped")
	assert_true(actor.current_health < 30, "HP should take bypass damage")
	assert_true(actor.is_rooted == false, "Sica Cut should NOT root")
	
	attacker.free()

# ==============================================================================
# TEST 9: Velites Pinning Javelin (Integration Test)
# ==============================================================================
func test_velites_pinning_javelin_integration():
	var javelin_skill = load("res://data/skills/pinning_javelin.tres") as SkillData
	assert_not_null(javelin_skill, "pinning_javelin.tres must exist in data/skills/")
	
	var attacker = Actor.new()
	var velites_data = ClassData.new()
	velites_data.max_hp = 25
	velites_data.max_armor = 15
	velites_data.attack_damage = 15
	velites_data.move_range = 2
	velites_data.initiative = 5
	attacker.class_data = velites_data
	attacker._ready()
	add_child(attacker)
	
	actor.class_data.move_range = 3
	actor.current_health = 30
	actor.current_armor = 20
	
	for effect in javelin_skill.effects:
		effect.execute(attacker, actor, javelin_skill, actor)
	
	assert_eq(actor.current_armor, 5, "Armor should be reduced by 1.0x ATK (15)")
	assert_eq(actor.current_health, 30, "HP should remain full (no bypass)")
	
	assert_true(actor.has_status("Slow"), "Target MUST have Slow applied")
	
	var has_slow = false
	for status in actor.active_statuses:
		if status.status_name == "Slow":
			has_slow = true
			assert_eq(status.duration, 1, "Slow duration should be 1 turn")
	assert_true(has_slow, "Target must have 'Slow' status effect applied with correct duration")
	
	attacker.free()

# ==============================================================================
# TEST 10: Secutor Hamstring (Integration Test)
# ==============================================================================
func test_secutor_hamstring_integration():
	var hamstring_skill = load("res://data/skills/hamstring.tres") as SkillData
	assert_not_null(hamstring_skill, "hamstring.tres must exist in data/skills/")
	
	var attacker = Actor.new()
	var secutor_data = ClassData.new()
	secutor_data.max_hp = 30
	secutor_data.max_armor = 20
	secutor_data.attack_damage = 12
	secutor_data.move_range = 2
	secutor_data.initiative = 8
	attacker.class_data = secutor_data
	attacker._ready()
	add_child(attacker)
	
	actor.class_data.move_range = 3
	actor.current_health = 30
	actor.current_armor = 20
	
	for effect in hamstring_skill.effects:
		effect.execute(attacker, actor, hamstring_skill, actor)
	
	assert_eq(actor.current_armor, 8, "Armor should be reduced by 1.0x ATK (12)")
	assert_eq(actor.current_health, 30, "HP should remain full (no bypass)")
	
	assert_true(actor.has_status("Slow"), "Target MUST have Slow applied")
	
	var has_slow = false
	for status in actor.active_statuses:
		if status.status_name == "Slow":
			has_slow = true
			assert_eq(status.duration, 1, "Slow duration should be 1 turn")
	assert_true(has_slow, "Target must have 'Slow' status effect applied with correct duration")
	
	attacker.free()

# ==============================================================================
# TEST 11: Dimachaerus Flurry (Integration Test)
# ==============================================================================
func test_dimachaerus_flurry_integration():
	var flurry_skill = load("res://data/skills/flurry.tres") as SkillData
	if flurry_skill == null:
		flurry_skill = load("res://data/skills/flurry.tres") as SkillData
		
	assert_not_null(flurry_skill, "Flurry.tres must exist in data/skills/")
	
	var attacker = Actor.new()
	var dimachaerus_data = ClassData.new()
	dimachaerus_data.max_hp = 25
	dimachaerus_data.max_armor = 10
	dimachaerus_data.attack_damage = 10 # 10 ATK для чистой математики: 0.7 * 10 = 7 урона за удар
	dimachaerus_data.move_range = 3
	dimachaerus_data.initiative = 15
	attacker.class_data = dimachaerus_data
	attacker._ready()
	add_child(attacker)
	
	actor.current_health = 30
	actor.current_armor = 20
	
	for effect in flurry_skill.effects:
		effect.execute(attacker, actor, flurry_skill, actor)
	
	# 3 удара по 7 урона = 21 общий урон. Броня (20) поглощает 20, 1 урон проходит в HP.
	assert_eq(actor.current_armor, 0, "Armor should be depleted to 0 after 3 hits")
	assert_eq(actor.current_health, 29, "HP should take exactly 1 spill-over damage (30 - 1 = 29)")
	
	attacker.free()

extends Node2D

const ACTOR_SCENE = preload("res://scenes/actor_player.tscn")

@onready var turn_manager: Node = $Tiles/TurnManager

var enemy_squad_classes: Array[String] = []

func _ready() -> void:
	_spawn_squad()
	enemy_squad_classes = SquadManager.generate_random_enemy_squad(3)
	print("🎲 Random Enemy Squad Generated: ", enemy_squad_classes)
	
	_spawn_enemies() # ✅ Don't forget this from the previous fix!
	
	if turn_manager:
		# ✅ Connect the game_over signal to our new function
		turn_manager.game_over.connect(_on_game_over)
		
		await get_tree().process_frame
		turn_manager.initialize_game()
	else:
		push_error("TurnManager not found at $Tiles/TurnManager!")

func _spawn_squad() -> void:
	var squad_size = SquadManager.squad_classes.size()
	for i in range(squad_size):
		var class_data = SquadManager.get_class_data(i)
		if not class_data: continue
		
		var new_actor = _create_actor(class_data, true, i)
		add_child(new_actor)
		turn_manager.register_actor(new_actor)
		print("✅ Spawned Ally: ", new_actor.name)

func _spawn_enemies() -> void:
	for i in range(enemy_squad_classes.size()):
		var class_path = enemy_squad_classes[i]
		var class_data = load(class_path) as ClassData
		if not class_data:
			push_error("❌ FAILED to load enemy class: " + class_path + ". Check the file path!")
			continue
		
		var new_actor = _create_actor(class_data, false, i)
		add_child(new_actor)
		turn_manager.register_actor(new_actor)
		print("✅ Spawned Enemy: ", new_actor.name)

func _create_actor(class_data: ClassData, friendly: bool, index: int) -> Actor:
	var new_actor = ACTOR_SCENE.instantiate()
	new_actor.name = class_data.display_name + "_" + ("Ally" if friendly else "Enemy") + "_" + str(index)
	new_actor.class_data = class_data
	new_actor.is_friendly = friendly
	
	var spawn_point_name = ("SpawnPoint_" if friendly else "EnemySpawnPoint_") + str(index)
	var spawn_point = get_node_or_null(spawn_point_name)
	
	if spawn_point:
		new_actor.global_position = spawn_point.global_position
	else:
		push_warning("Spawn point '%s' not found! Using fallback." % spawn_point_name)
		var offset_x = 0.0 if friendly else 512.0
		new_actor.global_position = Vector2(offset_x + (index * 64.0), 128.0)
		
	return new_actor

# ✅ NEW: Handle battle end and show the return button
func _on_game_over(player_won: bool) -> void:
	print("GAME OVER! Player won: ", player_won)
	
	# Disable further input processing on the turn manager
	if turn_manager:
		turn_manager.set_process_input(false)
	
	# 1. Create a CanvasLayer to ensure UI is on top of everything
	var overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	
	# 2. Create a semi-transparent dark background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	
	# 3. Create a centered container for the text and button
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.offset_left = -150
	container.offset_right = 150
	container.offset_top = -100
	container.offset_bottom = 100
	container.add_theme_constant_override("separation", 20)
	overlay.add_child(container)
	
	# 4. Create the Victory/Defeat label
	var label = Label.new()
	label.text = "ПОБЕДА!" if player_won else "ПОРАЖЕНИЕ!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.GREEN if player_won else Color.RED)
	container.add_child(label)
	
	# 5. Create the "Back to Menu" button
	var back_button = Button.new()
	back_button.text = "Вернуться в меню"
	back_button.custom_minimum_size = Vector2(200, 50)
	back_button.set_anchors_preset(Control.PRESET_CENTER)
	back_button.offset_left = -100
	back_button.offset_right = 100
	back_button.offset_top = 40
	back_button.offset_bottom = 90
	back_button.pressed.connect(_on_back_to_menu_pressed)
	container.add_child(back_button)

func _on_back_to_menu_pressed() -> void:
	# ⚠️ Verify this path matches your actual pre-combat scene file name!
	get_tree().change_scene_to_file("res://scenes/pre_combat_screen.tscn")

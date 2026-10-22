# res://Scripts/control.gd
extends Control

const CHARACTER_CARD_SCENE = preload("res://scenes/character_card.tscn")

@onready var card_container: HBoxContainer = $VBoxContainer/SquadPanel/CardContainer
@onready var start_battle_button: Button = $VBoxContainer/HBoxContainer/StartBattleButton
@onready var squad_button: Button = $VBoxContainer/HBoxContainer/SquadButton

func _ready() -> void:
	print(" DEBUG: _ready() called")
	print("🔍 DEBUG: squad_button = ", squad_button)
	print("🔍 DEBUG: card_container = ", card_container)
	
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
		print("✅ StartBattleButton connected")
	else:
		push_warning("❌ StartBattleButton not found!")
		
	if squad_button:
		squad_button.pressed.connect(_on_squad_button_pressed)
		print("✅ SquadButton connected")
	else:
		push_warning("❌ SquadButton not found! Check the path.")
	
	_spawn_character_cards()

func _spawn_character_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	
	var squad_size = SquadManager.squad_classes.size()
	
	for i in range(squad_size):
		var card = CHARACTER_CARD_SCENE.instantiate()
		card_container.add_child(card)
		card.setup(i) 

func _on_start_battle_pressed() -> void:
	print("🚀 Starting Battle...")
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_squad_button_pressed() -> void:
	print("🔄 Squad button pressed!")
	
	# Скрываем/показываем весь SquadPanel, а не только CardContainer
	var squad_panel = $VBoxContainer/SquadPanel
	if squad_panel:
		squad_panel.visible = !squad_panel.visible
		print("🔍 SquadPanel visible: ", squad_panel.visible)
	else:
		card_container.visible = !card_container.visible

# res://Scripts/control.gd
extends Control

@onready var squad_panel: Control = $VBoxContainer/SquadPanel
@onready var card_container: HBoxContainer = $VBoxContainer/SquadPanel/CardContainer
@onready var start_battle_button: Button = $VBoxContainer/HBoxContainer/StartBattleButton
@onready var squad_button: Button = $VBoxContainer/HBoxContainer/SquadButton

func _ready() -> void:
	# 1. Verify nodes are actually found
	if not squad_panel:
		push_error("CRITICAL: 'SquadPanel' not found! Check your scene tree path.")
	if not card_container:
		push_warning("WARNING: 'CardContainer' not found! Check your scene tree path.")
		
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	else:
		push_warning("StartBattleButton not found! Check scene tree.")
		
	if squad_button:
		squad_button.pressed.connect(_on_squad_button_pressed)
	else:
		push_warning("SquadButton not found! Check scene tree.")

func _on_start_battle_pressed() -> void:
	print("🚀 Starting Battle...")
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_squad_button_pressed() -> void:
	# 2. Safely toggle the visibility
	if squad_panel:
		squad_panel.visible = !squad_panel.visible
		print("🔄 Squad Panel is now: ", "VISIBLE" if squad_panel.visible else "HIDDEN")
	else:
		push_error("Cannot toggle Squad Panel: squad_panel is null!")

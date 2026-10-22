# res://Scripts/control.gd
extends Control

@onready var squad_panel = $VBoxContainer/SquadPanel
@onready var card_container: HBoxContainer = $VBoxContainer/SquadPanel/CardContainer
@onready var start_battle_button: Button = $VBoxContainer/HBoxContainer/StartBattleButton
@onready var squad_button: Button = $VBoxContainer/HBoxContainer/SquadButton


func _ready() -> void:
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
	print("🔄 Toggling Squad Panel")
	# Toggle ONLY the card container, NOT the entire panel (which contains the buttons!)
	card_container.visible = !card_container.visible

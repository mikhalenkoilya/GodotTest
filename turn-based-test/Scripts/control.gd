# res://scenes/pre_combat_screen.gd
extends Control

@onready var squad_panel = $VBoxContainer/SquadPanel
@onready var cards_container = $VBoxContainer/SquadPanel/CardsContainer

var card_scene = preload("res://scenes/character_card.tscn")

func _ready() -> void:
	# Instantiate 3 character cards
	for i in range(3):
		var card = card_scene.instantiate()
		card.slot_index = i
		cards_container.add_child(card)
	
	# Wire up buttons
	$VBoxContainer/SquadButton.pressed.connect(_on_squad_pressed)
	$VBoxContainer/StartBattleButton.pressed.connect(_on_start_battle_pressed)

func _on_squad_pressed() -> void:
	squad_panel.visible = not squad_panel.visible

func _on_start_battle_pressed() -> void:
	# Transition to the battle scene
	get_tree().change_scene_to_file("res://world.tscn")

# res://scenes/character_card.gd
extends VBoxContainer

@export var slot_index: int = 0

@onready var class_name_label = $ClassNameLabel
@onready var sprite_rect = $SpriteRect
@onready var hp_label = $HPLabel
@onready var dmg_label = $DmgLabel
@onready var move_label = $MoveLabel
@onready var range_label = $RangeLabel

func _ready() -> void:
	$PrevButton.pressed.connect(_on_prev_pressed)
	$NextButton.pressed.connect(_on_next_pressed)
	update_ui()

func update_ui() -> void:
	var class_data = SquadManager.get_class_data(slot_index)
	if class_data:
		class_name_label.text = class_data.display_name
		sprite_rect.texture = class_data.sprite_texture
		hp_label.text = "❤️ HP: " + str(class_data.max_hp)
		dmg_label.text = "⚔️ DMG: " + str(class_data.attack_damage)
		move_label.text = "👟 MOVE: " + str(class_data.move_range)
		range_label.text = "🏹 RANGE: " + str(class_data.attack_range)

func _on_prev_pressed() -> void:
	SquadManager.cycle_class(slot_index, -1)
	update_ui()

func _on_next_pressed() -> void:
	SquadManager.cycle_class(slot_index, 1)
	update_ui()

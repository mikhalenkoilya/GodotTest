# res://scenes/character_card.gd
extends VBoxContainer

var slot_index: int = 0

@onready var class_name_label: Label = $ClassNameLabel
@onready var sprite_rect = $SpriteRect
@onready var hp_label = $StatsContainer/HPLabel
@onready var dmg_label = $StatsContainer/DmgLabel
@onready var move_label = $StatsContainer/MoveLabel
@onready var range_label = $StatsContainer/RangeLabel
@onready var prev_button = $ButtonsContainer/PrevButton
@onready var next_button = $ButtonsContainer/NextButton

func _ready() -> void:
	# Только подключаем сигналы, UI обновим в setup()
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)

func setup(index: int) -> void:
	slot_index = index
	update_ui()

func update_ui() -> void:
	# Проверка на случай, если узлы не найдены
	if class_name_label == null:
		push_error("UI nodes not found! Check paths in @onready.")
		return
		
	var class_data = SquadManager.get_class_data(slot_index)
	if class_data:
		class_name_label.text = class_data.display_name
		if class_data.sprite_texture:
			sprite_rect.texture = class_data.sprite_texture
			sprite_rect.visible = true
		else:
			sprite_rect.visible = false
			
		hp_label.text = "❤️ HP: " + str(class_data.max_hp)
		dmg_label.text = "⚔️ DMG: " + str(class_data.attack_damage)
		move_label.text = " MOVE: " + str(class_data.move_range)
		range_label.text = "🏹 RANGE: " + str(class_data.attack_range)

func _on_prev_pressed() -> void:
	SquadManager.cycle_class(slot_index, -1)
	update_ui()

func _on_next_pressed() -> void:
	SquadManager.cycle_class(slot_index, 1)
	update_ui()

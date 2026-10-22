extends VBoxContainer

@export var slot_index: int = 0

@onready var class_name_label = $ClassNameLabel
@onready var sprite_rect = $SpriteRect
@onready var hp_label = $StatsContainer/HPLabel
@onready var dmg_label = $StatsContainer/DmgLabel
@onready var move_label = $StatsContainer/MoveLabel
@onready var range_label = $StatsContainer/RangeLabel

func _ready() -> void:
	print("🟢 Character Card Ready. Slot: ", slot_index)

	if has_node("ButtonsContainer/PrevButton") and has_node("ButtonsContainer/NextButton"):
		$ButtonsContainer/PrevButton.pressed.connect(_on_prev_pressed)
		$ButtonsContainer/NextButton.pressed.connect(_on_next_pressed)
		print("✅ Buttons found and signals connected.")
	
	update_ui()

func update_ui() -> void:
	print("🔄 Updating UI for slot: ", slot_index)
	var class_data = SquadManager.get_class_data(slot_index)
	
	
	if class_data:
		print("✅ Class data loaded: ", class_data.display_name)
		class_name_label.text = class_data.display_name
		sprite_rect.texture = class_data.sprite_texture
		hp_label.text = "❤️ HP: " + str(class_data.max_hp)
		dmg_label.text = "️ DMG: " + str(class_data.attack_damage)
		move_label.text = "👟 MOVE: " + str(class_data.move_range)
		range_label.text = "🏹 RANGE: " + str(class_data.attack_range)
	else:
		push_error("❌ ERROR: Failed to load class data for slot " + str(slot_index))

func _on_prev_pressed() -> void:
	print("⬅️ Prev button clicked! Cycling class for slot: ", slot_index)
	SquadManager.cycle_class(slot_index, -1)
	update_ui()

func _on_next_pressed() -> void:
	print("➡️ Next button clicked! Cycling class for slot: ", slot_index)
	SquadManager.cycle_class(slot_index, 1)
	update_ui()

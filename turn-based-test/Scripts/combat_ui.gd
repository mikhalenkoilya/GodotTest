extends Node

# ✅ Corrected paths based on your scene tree screenshot
@onready var name_label: Label = $UIContainer/HBoxContainer/PlayerStats/NameLabel
@onready var hp_label: Label = $UIContainer/HBoxContainer/PlayerStats/HPLabel
@onready var type_label: Label = $UIContainer/HBoxContainer/PlayerStats/TypeLabel
@onready var dmg_label: Label = $UIContainer/HBoxContainer/PlayerStats/DmgLabel
@onready var move_label: Label = $UIContainer/HBoxContainer/PlayerStats/MoveLabel
@onready var range_label: Label = $UIContainer/HBoxContainer/PlayerStats/RangeLabel
@onready var armor_label: Label = $UIContainer/HBoxContainer/PlayerStats/ArmorLabel
@onready var magic_label: Label = $UIContainer/HBoxContainer/PlayerStats/MRLabel

@onready var target_name_label: Label = $UIContainer/HBoxContainer/TargetStats/NameLabel
@onready var target_hp_label: Label = $UIContainer/HBoxContainer/TargetStats/HPLabel
@onready var target_type_label: Label = $UIContainer/HBoxContainer/TargetStats/TypeLabel
@onready var target_dmg_label: Label = $UIContainer/HBoxContainer/TargetStats/DmgLabel
@onready var target_move_label: Label = $UIContainer/HBoxContainer/TargetStats/MoveLabel

# Skill panel (created dynamically)
var skill_panel: PanelContainer = null
var skill_container: HBoxContainer = null

signal skill_selected(skill: SkillData)
signal basic_attack_selected()

var current_actor: Actor = null

func _ready() -> void:
	_create_skill_panel()

func _create_skill_panel() -> void:
	# Create the panel container
	skill_panel = PanelContainer.new()
	skill_panel.name = "SkillPanel"
	
	# Anchor to bottom center of the UIContainer
	skill_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	skill_panel.offset_top = -80 # Height of the panel
	skill_panel.offset_bottom = 0
	
	# Add to UIContainer so it scales with the UI
	$UIContainer.add_child(skill_panel)
	
	# Create horizontal container for buttons
	skill_container = HBoxContainer.new()
	skill_container.name = "SkillContainer"
	skill_container.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_container.add_theme_constant_override("separation", 10)
	skill_panel.add_child(skill_container)
	
	# Initially hide until an actor is selected
	skill_panel.visible = false

func update_player_stats(actor: Actor) -> void:
	current_actor = actor
	
	if actor and actor.class_data:
		name_label.text = actor.class_data.display_name
		hp_label.text = "❤️ HP: %d/%d" % [actor.max_health, actor.class_data.max_hp]
		type_label.text = "Type: " + str(actor.class_data.attack_type)
		dmg_label.text = "⚔️ DMG: %d" % actor.class_data.attack_damage
		move_label.text = "👟 MOVE: %d" % actor.class_data.move_range
		range_label.text = "🏹 RANGE: %d" % actor.class_data.attack_range
		
		if armor_label:
			armor_label.text = "🛡️ ARMOR: %d" % actor.class_data.max_armor
		if magic_label:
			magic_label.text = "✨ M.RES: %d" % actor.class_data.max_magic_resist
		
		# Show skill panel and update buttons
		skill_panel.visible = true
		_update_skill_buttons(actor)
	else:
		skill_panel.visible = false

func _update_skill_buttons(actor: Actor) -> void:
	# Clear existing buttons
	for child in skill_container.get_children():
		child.queue_free()
	
	if not actor or not actor.class_data:
		return
	
	# Add "Basic Attack" button
	var basic_btn = _create_skill_button("⚔️ Basic Attack", false)
	basic_btn.pressed.connect(_on_basic_attack_pressed)
	skill_container.add_child(basic_btn)
	
	# Add skill buttons
	for skill in actor.class_data.skills:
		var cooldown = actor.get_cooldown_remaining(skill)
		var is_on_cooldown = cooldown > 0
		
		var btn_text = skill.display_name
		if is_on_cooldown:
			btn_text = "%s (CD: %d)" % [skill.display_name, cooldown]
		
		var skill_btn = _create_skill_button(btn_text, is_on_cooldown)
		skill_btn.pressed.connect(_on_skill_pressed.bind(skill))
		skill_container.add_child(skill_btn)

func _create_skill_button(text: String, disabled: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 60)
	btn.disabled = disabled
	
	if disabled:
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0) # Grayed out
	
	return btn

func _on_basic_attack_pressed() -> void:
	print("⚔️ Basic attack selected")
	basic_attack_selected.emit()

func _on_skill_pressed(skill: SkillData) -> void:
	print("🎯 Skill selected: ", skill.display_name)
	skill_selected.emit(skill)

func update_target_stats(target: Actor) -> void:
	if target and target.class_data:
		target_name_label.text = target.class_data.display_name
		target_hp_label.text = "❤️ HP: %d/%d" % [target.max_health, target.class_data.max_hp]
		target_type_label.text = "Type: " + str(target.class_data.attack_type)
		target_dmg_label.text = "⚔️ DMG: %d" % target.class_data.attack_damage
		target_move_label.text = "👟 MOVE: %d" % target.class_data.move_range

func clear_target_stats() -> void:
	target_name_label.text = ""
	target_hp_label.text = ""
	target_type_label.text = ""
	target_dmg_label.text = ""
	target_move_label.text = ""

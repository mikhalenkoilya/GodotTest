extends CanvasLayer

# --- Player Stats (Left Side) ---
@onready var player_name = $UIContainer/HBoxContainer/PlayerStats/NameLabel
@onready var player_hp = $UIContainer/HBoxContainer/PlayerStats/HPLabel
@onready var player_armor = $UIContainer/HBoxContainer/PlayerStats/ArmorLabel
@onready var player_mr = $UIContainer/HBoxContainer/PlayerStats/MRLabel
@onready var player_dmg = $UIContainer/HBoxContainer/PlayerStats/DmgLabel
@onready var player_type = $UIContainer/HBoxContainer/PlayerStats/TypeLabel
@onready var player_move = $UIContainer/HBoxContainer/PlayerStats/MoveLabel
@onready var player_range = $UIContainer/HBoxContainer/PlayerStats/RangeLabel

# --- Target Stats (Right Side) ---
@onready var target_name = $UIContainer/HBoxContainer/TargetStats/NameLabel
@onready var target_hp = $UIContainer/HBoxContainer/TargetStats/HPLabel
@onready var target_armor = $UIContainer/HBoxContainer/TargetStats/ArmorLabel
@onready var target_mr = $UIContainer/HBoxContainer/TargetStats/MRLabel
@onready var target_dmg = $UIContainer/HBoxContainer/TargetStats/DmgLabel
@onready var target_type = $UIContainer/HBoxContainer/TargetStats/TypeLabel
@onready var target_move = $UIContainer/HBoxContainer/TargetStats/MoveLabel
@onready var target_range = $UIContainer/HBoxContainer/TargetStats/RangeLabel

func update_player_stats(actor: Actor) -> void:
	if not actor: return
	player_name.text = actor.name
	player_hp.text = "❤️ HP: %d/%d" % [actor.current_health, actor.max_health]
	player_armor.text = "🛡️ Armor: %d/%d" % [actor.current_armor, actor.max_armor]
	player_mr.text = "✨ M.Res: %d/%d" % [actor.current_magic_resist, actor.max_magic_resist]
	player_dmg.text = "⚔️ DMG: %d" % actor.attack_damage
	player_type.text = "🔮 Type: " + ("Physical" if actor.attack_type == ClassData.AttackType.PHYSICAL else "Magic")
	player_move.text = "👟 Move: %d" % (actor.class_data.move_range if actor.class_data else 0)
	player_range.text = "🎯 Range: %d" % (actor.class_data.attack_range if actor.class_data else 0)

func update_target_stats(actor: Actor) -> void:
	if not actor: return
	target_name.text = actor.name
	target_hp.text = "❤️ HP: %d/%d" % [actor.current_health, actor.max_health]
	target_armor.text = "🛡️ Armor: %d/%d" % [actor.current_armor, actor.max_armor]
	target_mr.text = "✨ M.Res: %d/%d" % [actor.current_magic_resist, actor.max_magic_resist]
	target_dmg.text = "⚔️ DMG: %d" % actor.attack_damage
	target_type.text = "🔮 Type: " + ("Physical" if actor.attack_type == ClassData.AttackType.PHYSICAL else "Magic")
	target_move.text = "👟 Move: %d" % (actor.class_data.move_range if actor.class_data else 0)
	target_range.text = "🎯 Range: %d" % (actor.class_data.attack_range if actor.class_data else 0)

func clear_target_stats() -> void:
	target_name.text = ""
	target_hp.text = ""
	target_armor.text = ""
	target_mr.text = ""
	target_dmg.text = ""
	target_type.text = ""
	target_move.text = ""
	target_range.text = ""

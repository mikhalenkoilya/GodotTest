extends Control

@onready var main_menu_container: VBoxContainer = $MainMenuContainer
@onready var options_container: VBoxContainer = $OptionsContainer

func _ready() -> void:
	# При запуске показываем главное меню и скрываем настройки
	if main_menu_container:
		main_menu_container.show()
	if options_container:
		options_container.hide()

func _on_company_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/pre_combat_screen.tscn")


func _on_fast_battle_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_options_button_pressed() -> void:
	main_menu_container.hide()
	options_container.show()


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	# Возврат в главное меню
	options_container.hide()
	main_menu_container.show()

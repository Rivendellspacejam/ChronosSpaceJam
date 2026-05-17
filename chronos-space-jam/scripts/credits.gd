extends Control

@onready var back_button = $VBoxContainer/BackButton

func _ready() -> void:
	AudioManager.start_menu_music()
	back_button.pressed.connect(_on_back)
	back_button.mouse_entered.connect(AudioManager.play_ui_click)

func _on_back() -> void:
	AudioManager.play_ui_back()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

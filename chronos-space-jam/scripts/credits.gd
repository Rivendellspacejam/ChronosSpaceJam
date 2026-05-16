## Credits — Game credits screen
extends Control

@onready var back_button = $VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

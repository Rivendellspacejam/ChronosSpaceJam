extends Control

@onready var back_button = $VBoxContainer/BackButton
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

func _ready() -> void:
	AudioManager.configure_menu_music_player(background_music)
	back_button.pressed.connect(_on_back)
	back_button.mouse_entered.connect(AudioManager.play_ui_click)

func _exit_tree() -> void:
	AudioManager.remember_menu_music_position(background_music)

func _on_back() -> void:
	AudioManager.play_ui_back()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

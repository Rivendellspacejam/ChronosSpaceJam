## PauseMenu — Visual overlay for paused state
## Covers: UI-08 (Pause Menu), UI-10 (Settings Menu)
extends Control

@onready var vbox             = $VBoxContainer
@onready var resume_button        = $VBoxContainer/ResumeButton
@onready var restart_button       = $VBoxContainer/RestartButton
@onready var settings_button      = $VBoxContainer/SettingsButton
@onready var main_menu_button     = $VBoxContainer/MainMenuButton
@onready var settings_menu        = $SettingsMenu

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	settings_button.pressed.connect(_on_settings)
	main_menu_button.pressed.connect(_on_main_menu)
	visible = false

func _on_resume() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().paused = false
	visible = false

func _on_restart() -> void:
	get_tree().paused = false
	GameManager.restart_level()
	visible = false

func _on_settings() -> void:
	vbox.visible = false
	settings_menu.return_target = vbox
	settings_menu.visible = true

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	visible = false

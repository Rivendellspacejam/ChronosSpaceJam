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
	_wire_button_audio(resume_button)
	_wire_button_audio(restart_button)
	_wire_button_audio(settings_button)
	_wire_button_audio(main_menu_button)
	visible = false

func _on_resume() -> void:
	AudioManager.play_ui_back()
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().paused = false
	visible = false

func _on_restart() -> void:
	AudioManager.play_ui_click()
	get_tree().paused = false
	GameManager.restart_level()
	visible = false

func _on_settings() -> void:
	AudioManager.play_ui_click()
	vbox.visible = false
	settings_menu.return_target = vbox
	settings_menu.visible = true

func _on_main_menu() -> void:
	AudioManager.play_ui_back()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	visible = false

func _wire_button_audio(button: Button) -> void:
	button.mouse_entered.connect(AudioManager.play_ui_click)

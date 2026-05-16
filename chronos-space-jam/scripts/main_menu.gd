## MainMenu — Main menu screen
## Covers: UI-04 (Main Menu), UI-10 (Settings Menu)
extends Control

@onready var vbox           = $VBoxContainer
@onready var start_button          = $VBoxContainer/StartButton
@onready var level_select_button   = $VBoxContainer/LevelSelectButton
@onready var credits_button        = $VBoxContainer/CreditsButton
@onready var settings_button       = $VBoxContainer/SettingsButton
@onready var quit_button           = $VBoxContainer/QuitButton
@onready var settings_menu         = $SettingsMenu

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	level_select_button.pressed.connect(_on_level_select)
	credits_button.pressed.connect(_on_credits)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

func _on_start() -> void:
	GameManager.current_level_index = 0
	get_tree().change_scene_to_file("res://scenes/game/game_level.tscn")

func _on_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_credits() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")

func _on_settings() -> void:
	vbox.visible = false
	settings_menu.return_target = vbox
	settings_menu.visible = true

func _on_quit() -> void:
	get_tree().quit()

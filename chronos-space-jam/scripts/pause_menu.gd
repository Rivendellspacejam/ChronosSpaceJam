extends Control

@onready var pause_panel: PanelContainer = $PausePanel
@onready var vbox = $PausePanel/MarginContainer/VBoxContainer
@onready var resume_button = $PausePanel/MarginContainer/VBoxContainer/ResumeButton
@onready var restart_button = $PausePanel/MarginContainer/VBoxContainer/RestartButton
@onready var settings_button = $PausePanel/MarginContainer/VBoxContainer/SettingsButton
@onready var main_menu_button = $PausePanel/MarginContainer/VBoxContainer/MainMenuButton
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	_apply_pause_panel_style()
	for button in [resume_button, restart_button, settings_button, main_menu_button]:
		_apply_button_style(button)
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	settings_button.pressed.connect(_on_settings)
	main_menu_button.pressed.connect(_on_main_menu)
	_wire_pause_button_audio()
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
	pause_panel.visible = false
	settings_menu.return_target = pause_panel
	settings_menu.visible = true

func _on_main_menu() -> void:
	AudioManager.play_ui_back()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	visible = false

func _wire_pause_button_audio() -> void:
	for button in [resume_button, restart_button, settings_button, main_menu_button]:
		_wire_button_audio(button)

func _wire_button_audio(button: Button) -> void:
	button.mouse_entered.connect(AudioManager.play_ui_click)

func _apply_pause_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.02, 0.04, 0.92)
	style.border_color = Color(0.35, 0.92, 1.0, 0.82)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 18
	pause_panel.add_theme_stylebox_override("panel", style)

func _apply_button_style(button: Button) -> void:
	var normal := _make_button_box(Color(0.08, 0.16, 0.23, 0.88), Color(0.25, 0.68, 0.88, 0.58))
	var hover := _make_button_box(Color(0.12, 0.3, 0.38, 0.95), Color(0.42, 0.95, 1.0, 0.9))
	var pressed := _make_button_box(Color(0.08, 0.45, 0.44, 0.95), Color(0.35, 1.0, 0.72, 0.95))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 18)

func _make_button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

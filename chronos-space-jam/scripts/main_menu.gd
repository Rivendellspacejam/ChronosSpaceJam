extends Control

@onready var vbox = $VBoxContainer
@onready var start_button = $VBoxContainer/StartButton
@onready var level_select_button = $VBoxContainer/LevelSelectButton
@onready var credits_button = $VBoxContainer/CreditsButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var settings_menu = $SettingsMenu
@onready var title_label = $VBoxContainer/TitleLabel
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _title_phase: float = 0.0

func _ready() -> void:
	AudioManager.stop_music()
	_ensure_background_music_playing()
	start_button.pressed.connect(_on_start)
	level_select_button.pressed.connect(_on_level_select)
	credits_button.pressed.connect(_on_credits)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	_wire_menu_button_audio()
	_style_menu_buttons()

func _ensure_background_music_playing() -> void:
	_apply_background_music_volume()
	if not background_music.playing:
		background_music.play()

func _apply_background_music_volume() -> void:
	if SettingsManager.music_volume <= 0.0 or SettingsManager.mute_all:
		background_music.volume_db = -80.0
		return
	background_music.volume_db = linear_to_db(SettingsManager.music_volume / 100.0)

func _process(delta: float) -> void:
	_ensure_background_music_playing()
	_title_phase += delta * 1.8
	var pulse := (sin(_title_phase) + 1.0) * 0.5
	title_label.modulate = Color(0.75, lerpf(0.86, 1.0, pulse), 1.0, 1.0)

func _on_start() -> void:
	AudioManager.play_ui_click()
	GameManager.current_level_index = 0
	get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")

func _on_level_select() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_credits() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")

func _on_settings() -> void:
	AudioManager.play_ui_click()
	vbox.visible = false
	settings_menu.return_target = vbox
	settings_menu.visible = true

func _on_quit() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()

func _wire_menu_button_audio() -> void:
	for button in [start_button, level_select_button, credits_button, settings_button, quit_button]:
		_wire_button_audio(button)

func _wire_button_audio(button: Button) -> void:
	button.mouse_entered.connect(AudioManager.play_ui_click)

func _style_menu_buttons() -> void:
	for button in [start_button, level_select_button, credits_button, settings_button, quit_button]:
		_apply_button_style(button)

func _apply_button_style(button: Button) -> void:
	var normal := _make_button_style(Color(0.02, 0.04, 0.075, 0.94), Color(0.22, 0.62, 0.78, 0.9))
	var hover := _make_button_style(Color(0.05, 0.11, 0.16, 0.98), Color(0.6, 0.95, 1.0, 1.0))
	var pressed := _make_button_style(Color(0.08, 0.18, 0.22, 1.0), Color(1.0, 0.92, 0.45, 1.0))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
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

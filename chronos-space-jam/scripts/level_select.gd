extends Control

const LEVEL_SELECT_CARD_SCENE: PackedScene = preload("res://scenes/ui/level_select_card.tscn")

@onready var grid_container = $VBoxContainer/GridContainer
@onready var back_button = $VBoxContainer/BackButton
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

func _ready() -> void:
	AudioManager.configure_menu_music_player(background_music)
	back_button.pressed.connect(_on_back)
	back_button.mouse_entered.connect(AudioManager.play_ui_click)
	_apply_button_style(back_button)
	_build_level_buttons()

func _exit_tree() -> void:
	AudioManager.remember_menu_music_position(background_music)

func _build_level_buttons() -> void:
	_clear_level_buttons()
	for i in range(GameManager.TOTAL_LEVELS):
		var unlocked := GameManager.is_level_unlocked(i)
		var completed := GameManager.best_moves.has(i)
		var medal := ""
		if completed:
			var best := int(GameManager.best_moves[i])
			medal = GameManager.get_medal_for_moves(i, best)
		var button := LEVEL_SELECT_CARD_SCENE.instantiate() as Button
		grid_container.add_child(button)
		button.call("setup", i, unlocked, completed, StoryManager.get_level_name(i), medal)
		if unlocked:
			button.pressed.connect(_make_level_callback(i))
			button.mouse_entered.connect(AudioManager.play_ui_click)

func _clear_level_buttons() -> void:
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q and event.ctrl_pressed:
		GameManager.unlock_all_levels()
		_build_level_buttons()
		accept_event()

func _make_level_callback(index: int) -> Callable:
	return func(): _on_level_selected(index)

func _on_level_selected(index: int) -> void:
	if not GameManager.is_level_unlocked(index):
		return
	AudioManager.play_ui_click()
	AudioManager.stop_music()
	GameManager.current_level_index = index
	get_tree().change_scene_to_file("res://scenes/game/game_level.tscn")

func _on_back() -> void:
	AudioManager.play_ui_back()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _apply_button_style(button: Button) -> void:
	var normal := _make_button_style(Color(0.02, 0.04, 0.075, 0.94), Color(0.22, 0.62, 0.78, 0.9))
	var hover := _make_button_style(Color(0.05, 0.11, 0.16, 0.98), Color(0.6, 0.95, 1.0, 1.0))
	var pressed := _make_button_style(Color(0.08, 0.18, 0.22, 1.0), Color(1.0, 0.92, 0.45, 1.0))
	var disabled := _make_button_style(Color(0.015, 0.02, 0.035, 0.9), Color(0.16, 0.2, 0.28, 0.8))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.48, 0.58, 0.9))

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

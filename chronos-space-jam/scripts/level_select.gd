## LevelSelect — Level selection screen
## Covers: UI-05 (Level Select)
extends Control

@onready var grid_container = $VBoxContainer/GridContainer
@onready var back_button = $VBoxContainer/BackButton

func _ready() -> void:
	AudioManager.start_menu_music()
	back_button.pressed.connect(_on_back)
	back_button.mouse_entered.connect(AudioManager.play_ui_click)
	_build_level_buttons()

func _build_level_buttons() -> void:
	for i in range(GameManager.TOTAL_LEVELS):
		var btn = Button.new()
		btn.text = "Level " + str(i + 1)
		btn.custom_minimum_size = Vector2(120, 60)
		btn.add_theme_font_size_override("font_size", 18)
		var level_idx = i
		btn.pressed.connect(_make_level_callback(level_idx))
		btn.mouse_entered.connect(AudioManager.play_ui_click)
		grid_container.add_child(btn)

func _make_level_callback(index : int) -> Callable:
	return func(): _on_level_selected(index)

func _on_level_selected(index : int) -> void:
	AudioManager.play_ui_click()
	AudioManager.stop_music()
	GameManager.current_level_index = index
	get_tree().change_scene_to_file("res://scenes/game/game_level.tscn")

func _on_back() -> void:
	AudioManager.play_ui_back()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

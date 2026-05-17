extends Control

const TYPE_SPEED: float = 42.0

@onready var speaker_label: Label = $StoryBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var body_label: Label = $StoryBox/MarginContainer/VBoxContainer/BodyLabel
@onready var hint_label: Label = $StoryBox/MarginContainer/VBoxContainer/HintLabel
@onready var story_box: PanelContainer = $StoryBox

var _lines: Array[String] = []
var _line_index: int = 0
var _visible_chars: float = 0.0
var _typing: bool = false

func _ready() -> void:
	AudioManager.start_menu_music()
	_apply_story_box_style()
	_lines = StoryManager.get_intro_lines()
	_show_line(0)

func _process(delta: float) -> void:
	if not _typing:
		return

	var previous_count := int(_visible_chars)
	_visible_chars = minf(_visible_chars + TYPE_SPEED * delta, float(body_label.text.length()))
	body_label.visible_characters = int(_visible_chars)

	if int(_visible_chars) > previous_count and _should_blip(body_label.visible_characters - 1):
		AudioManager.play_dialog_blip()

	if body_label.visible_characters >= body_label.text.length():
		_typing = false
		hint_label.text = "Enter / Click"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or _is_click(event):
		_advance()

func _advance() -> void:
	if _typing:
		body_label.visible_characters = body_label.text.length()
		_typing = false
		hint_label.text = "Enter / Click"
		return

	_line_index += 1
	if _line_index >= _lines.size():
		AudioManager.stop_music()
		get_tree().change_scene_to_file("res://scenes/game/game_level.tscn")
		return

	_show_line(_line_index)

func _show_line(index: int) -> void:
	var text := _lines[index]
	var split_at := text.find(":")
	if split_at >= 0:
		speaker_label.text = text.substr(0, split_at)
		body_label.text = text.substr(split_at + 1).strip_edges()
	else:
		speaker_label.text = "SYSTEM"
		body_label.text = text

	body_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	hint_label.text = ""

func _is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

func _should_blip(char_index: int) -> bool:
	if char_index < 0 or char_index >= body_label.text.length():
		return false
	return not (body_label.text[char_index] in [" ", "\n", ".", ","])

func _apply_story_box_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.016, 0.03, 0.96)
	style.border_color = Color(0.58, 0.95, 1.0, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	story_box.add_theme_stylebox_override("panel", style)

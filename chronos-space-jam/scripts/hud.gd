extends CanvasLayer

const TUTORIAL_TEXTS: Dictionary = {
	0: "WASD shifts gravity.\nYou slide until something stops you.",
	1: "Every move advances time by 1 tick.\nGates open and close with time.",
	2: "You cannot wait. You must move.\nFind a path to adjust your timing.",
	3: "Traps change phase every tick.\nRead the rhythm. Cross when safe.",
	4: "Spikes warn before striking.\nWatch for the yellow flash.",
	5: "Enemies patrol on a fixed pattern.\nTime your moves to avoid them.",
	6: "The chambers start bending wider.\nTrace your stops before you shift.",
}

const GRAVITY_LABELS: Dictionary = {
	Vector2i(0, -1): "UP",
	Vector2i(0, 1): "DOWN",
	Vector2i(-1, 0): "LEFT",
	Vector2i(1, 0): "RIGHT",
	Vector2i(0, 0): "NONE",
}

@onready var stats_panel: PanelContainer = $StatsPanel
@onready var level_label: Label = $StatsPanel/MarginContainer/VBoxContainer/LevelHeader/LevelLabel
@onready var level_name_label: Label = $StatsPanel/MarginContainer/VBoxContainer/LevelHeader/LevelNameLabel
@onready var gravity_value_label: Label = $StatsPanel/MarginContainer/VBoxContainer/GravityRow/HBoxContainer/GravityValue
@onready var tick_value_label: Label = $StatsPanel/MarginContainer/VBoxContainer/TickRow/HBoxContainer/TickValue
@onready var shifts_value_label: Label = $StatsPanel/MarginContainer/VBoxContainer/ShiftsRow/HBoxContainer/ShiftsValue
@onready var coins_row: PanelContainer = $StatsPanel/MarginContainer/VBoxContainer/CoinsRow
@onready var coins_value_label: Label = $StatsPanel/MarginContainer/VBoxContainer/CoinsRow/HBoxContainer/CoinsValue
@onready var future_preview_label = $FuturePreviewLabel
@onready var death_panel = $DeathPanel
@onready var clear_panel = $ClearPanel
@onready var clear_shifts_label: Label = $ClearPanel/MarginContainer/VBoxContainer/ClearStats/ShiftsRow/HBoxContainer/ShiftsValue
@onready var clear_best_label: Label = $ClearPanel/MarginContainer/VBoxContainer/ClearStats/BestRow/HBoxContainer/BestValue
@onready var clear_medal_icon: TextureRect = $ClearPanel/MarginContainer/VBoxContainer/MedalIcon
@onready var clear_medal_label: Label = $ClearPanel/MarginContainer/VBoxContainer/ClearStats/MedalRow/HBoxContainer/MedalValue
@onready var tutorial_label = $TutorialLabel
@onready var story_panel = $StoryPanel
@onready var story_speaker_label = $StoryPanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var story_body_label = $StoryPanel/MarginContainer/VBoxContainer/BodyLabel
@onready var story_hint_label = $StoryPanel/MarginContainer/VBoxContainer/HintLabel

const STORY_TYPE_SPEED: float = 48.0
const MEDAL_COLORS: Dictionary = {
	"Gold": Color(1, 0.85, 0.2, 1),
	"Silver": Color(0.75, 0.85, 0.95, 1),
	"Bronze": Color(0.85, 0.45, 0.18, 1),
}
const MEDAL_TEXTURES: Dictionary = {
	"Gold": preload("res://assets/first-gold.png"),
	"Silver": preload("res://assets/second-silver.png"),
	"Bronze": preload("res://assets/third-bronze.png"),
}

var _story_lines: Array[String] = []
var _story_index: int = 0
var _story_visible_chars: float = 0.0
var _story_typing: bool = false
var _story_finished_callback: Callable

func _ready() -> void:
	_apply_hud_panel_style(stats_panel)
	_apply_stat_row_style($StatsPanel/MarginContainer/VBoxContainer/GravityRow, Color(0.18, 0.82, 1.0, 0.14), Color(0.45, 0.9, 1.0, 0.38))
	_apply_stat_row_style($StatsPanel/MarginContainer/VBoxContainer/TickRow, Color(0.85, 0.9, 1.0, 0.10), Color(0.6, 0.7, 1.0, 0.28))
	_apply_stat_row_style($StatsPanel/MarginContainer/VBoxContainer/ShiftsRow, Color(0.72, 0.48, 1.0, 0.12), Color(0.75, 0.55, 1.0, 0.34))
	_apply_stat_row_style(coins_row, Color(1.0, 0.7, 0.08, 0.16), Color(1.0, 0.82, 0.22, 0.48))
	_apply_panel_style(death_panel, Color(0.08, 0.015, 0.025, 0.92), Color(1.0, 0.18, 0.22, 0.95))
	_apply_panel_style(clear_panel, Color(0.015, 0.08, 0.055, 0.92), Color(0.22, 1.0, 0.72, 0.95))
	_apply_panel_style(story_panel, Color(0.015, 0.018, 0.032, 0.96), Color(0.58, 0.95, 1.0, 0.95))
	_apply_result_row_style($ClearPanel/MarginContainer/VBoxContainer/ClearStats/ShiftsRow, Color(0.4, 0.9, 1.0, 0.16))
	_apply_result_row_style($ClearPanel/MarginContainer/VBoxContainer/ClearStats/BestRow, Color(1.0, 0.83, 0.24, 0.16))
	_apply_result_row_style($ClearPanel/MarginContainer/VBoxContainer/ClearStats/MedalRow, Color(0.4, 1.0, 0.65, 0.16))
	death_panel.visible = false
	clear_panel.visible = false
	future_preview_label.visible = false
	tutorial_label.visible = false
	story_panel.visible = false
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.level_cleared.connect(_on_level_cleared)
	GameManager.level_loaded.connect(_on_level_loaded)
	TickManager.tick_advanced.connect(_on_tick_pulse)

func _process(_delta: float) -> void:
	_update_story_typewriter(_delta)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not story_panel.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or _is_click(event):
		_advance_story()

func _update_hud() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var gravity = player.gravity_direction if player and "gravity_direction" in player else Vector2i.ZERO

	gravity_value_label.text = str(GRAVITY_LABELS.get(gravity, "NONE"))
	tick_value_label.text = str(TickManager.current_tick)
	shifts_value_label.text = str(TickManager.move_count)
	level_label.text = "LEVEL " + str(GameManager.current_level_index + 1)
	level_name_label.text = StoryManager.get_level_name(GameManager.current_level_index)

	var level_manager = _get_level_manager()
	if level_manager and level_manager.has_method("get_coin_total") and level_manager.get_coin_total() > 0:
		coins_row.visible = true
		coins_value_label.text = str(level_manager.get_coin_count()) + "/" + str(level_manager.get_coin_total())
	else:
		coins_row.visible = false

func show_level_story(level_index: int, finished_callback: Callable) -> void:
	_story_lines = StoryManager.get_level_story(level_index)
	_story_finished_callback = finished_callback
	_story_index = 0
	story_panel.visible = not _story_lines.is_empty()

	if _story_lines.is_empty():
		_finish_story()
		return

	_show_story_line(_story_index)

func set_future_preview_visible(is_visible: bool) -> void:
	future_preview_label.visible = is_visible

func _on_tick_pulse(_tick: int) -> void:
	var tween = create_tween()
	tick_value_label.modulate = Color(1, 1, 0)
	tween.tween_property(tick_value_label, "modulate", Color.WHITE, 0.2)

func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.DEAD:
		_show_panel_with_fade(death_panel)
	else:
		death_panel.visible = false
	
	if new_state == GameManager.GameState.LEVEL_CLEAR:
		_show_panel_with_fade(clear_panel)
	else:
		clear_panel.visible = false

func _show_panel_with_fade(panel: CanvasItem) -> void:
	panel.visible = true
	
	var mod = panel.modulate
	mod.a = 0.0
	panel.modulate = mod
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 1.0, 0.33)

func _on_level_cleared(move_count: int, best_moves: int, medal_data: Dictionary) -> void:
	var medal := str(medal_data.get("medal", "Bronze"))
	clear_shifts_label.text = str(move_count)
	clear_best_label.text = str(best_moves)
	clear_medal_icon.texture = MEDAL_TEXTURES.get(medal, MEDAL_TEXTURES["Bronze"])
	clear_medal_label.text = medal
	clear_medal_label.add_theme_color_override("font_color", MEDAL_COLORS.get(medal, MEDAL_COLORS["Bronze"]))

func _on_level_loaded(level_index: int) -> void:
	if not TUTORIAL_TEXTS.has(level_index):
		tutorial_label.visible = false
		return

	tutorial_label.text = TUTORIAL_TEXTS[level_index]
	tutorial_label.visible = true
	_set_canvas_item_alpha(tutorial_label, 1.0)

	var tween = create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(tutorial_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_hide_tutorial)

func _hide_tutorial() -> void:
	tutorial_label.visible = false
	_set_canvas_item_alpha(tutorial_label, 1.0)

func _get_level_manager() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("LevelManager")

func _update_story_typewriter(delta: float) -> void:
	if not _story_typing:
		return

	var previous_count := int(_story_visible_chars)
	_story_visible_chars = minf(_story_visible_chars + STORY_TYPE_SPEED * delta, float(story_body_label.text.length()))
	story_body_label.visible_characters = int(_story_visible_chars)

	if int(_story_visible_chars) > previous_count and _should_story_blip(story_body_label.visible_characters - 1):
		AudioManager.play_dialog_blip()

	if story_body_label.visible_characters >= story_body_label.text.length():
		_story_typing = false
		story_hint_label.text = "Enter / Click"

func _advance_story() -> void:
	if _story_typing:
		story_body_label.visible_characters = story_body_label.text.length()
		_story_typing = false
		story_hint_label.text = "Enter / Click"
		return

	_story_index += 1
	if _story_index >= _story_lines.size():
		_finish_story()
		return

	_show_story_line(_story_index)

func _show_story_line(index: int) -> void:
	var text := _story_lines[index]
	var split_at := text.find(":")
	if split_at >= 0:
		story_speaker_label.text = text.substr(0, split_at)
		story_body_label.text = text.substr(split_at + 1).strip_edges()
	else:
		story_speaker_label.text = "SYSTEM"
		story_body_label.text = text

	story_body_label.visible_characters = 0
	_story_visible_chars = 0.0
	_story_typing = true
	story_hint_label.text = ""

func _finish_story() -> void:
	story_panel.visible = false
	_story_lines.clear()
	if _story_finished_callback.is_valid():
		_story_finished_callback.call()

func _is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

func _should_story_blip(char_index: int) -> bool:
	if char_index < 0 or char_index >= story_body_label.text.length():
		return false
	return not (story_body_label.text[char_index] in [" ", "\n", ".", ","])

func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
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
	panel.add_theme_stylebox_override("panel", style)

func _apply_hud_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.025, 0.04, 0.78)
	style.border_color = Color(0.24, 0.9, 1.0, 0.52)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.52)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

func _apply_stat_row_style(row: PanelContainer, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	row.add_theme_stylebox_override("panel", style)

func _apply_result_row_style(row: PanelContainer, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.7, 1.0, 1.0, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	row.add_theme_stylebox_override("panel", style)

func _set_canvas_item_alpha(item: CanvasItem, alpha: float) -> void:
	var item_modulate := item.modulate
	item_modulate.a = alpha
	item.modulate = item_modulate

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

@onready var gravity_label = $MarginContainer/VBoxContainer/GravityLabel
@onready var tick_label = $MarginContainer/VBoxContainer/TickLabel
@onready var shifts_label = $MarginContainer/VBoxContainer/ShiftsLabel
@onready var coins_label = $MarginContainer/VBoxContainer/CoinsLabel
@onready var level_label = $MarginContainer/VBoxContainer/LevelLabel
@onready var future_preview_label = $FuturePreviewLabel
@onready var death_panel = $DeathPanel
@onready var clear_panel = $ClearPanel
@onready var clear_shifts_label = $ClearPanel/VBoxContainer/ShiftsValue
@onready var clear_best_label = $ClearPanel/VBoxContainer/BestValue
@onready var clear_medal_label = $ClearPanel/VBoxContainer/MedalValue
@onready var clear_gold_label = $ClearPanel/VBoxContainer/GoldTargetValue
@onready var clear_silver_label = $ClearPanel/VBoxContainer/SilverTargetValue
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

var _story_lines: Array[String] = []
var _story_index: int = 0
var _story_visible_chars: float = 0.0
var _story_typing: bool = false
var _story_finished_callback: Callable

func _ready() -> void:
	_apply_panel_style(death_panel, Color(0.08, 0.015, 0.025, 0.92), Color(1.0, 0.18, 0.22, 0.95))
	_apply_panel_style(clear_panel, Color(0.015, 0.08, 0.055, 0.92), Color(0.22, 1.0, 0.72, 0.95))
	_apply_panel_style(story_panel, Color(0.015, 0.018, 0.032, 0.96), Color(0.58, 0.95, 1.0, 0.95))
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

	gravity_label.text = "Gravity: " + str(GRAVITY_LABELS.get(gravity, "NONE"))
	tick_label.text = "Tick: " + str(TickManager.current_tick)
	shifts_label.text = "Time Shifts: " + str(TickManager.move_count)
	level_label.text = "Level " + str(GameManager.current_level_index + 1) + ": " + StoryManager.get_level_name(GameManager.current_level_index)

	var level_manager = _get_level_manager()
	if level_manager and level_manager.has_method("get_coin_total") and level_manager.get_coin_total() > 0:
		coins_label.visible = true
		coins_label.text = "Coins: " + str(level_manager.get_coin_count()) + "/" + str(level_manager.get_coin_total())
	else:
		coins_label.visible = false

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
	tick_label.modulate = Color(1, 1, 0)
	tween.tween_property(tick_label, "modulate", Color.WHITE, 0.2)

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
	clear_shifts_label.text = "Time Shifts: " + str(move_count)
	clear_best_label.text = "Best: " + str(best_moves)
	clear_medal_label.text = "Medal: " + medal
	clear_medal_label.add_theme_color_override("font_color", MEDAL_COLORS.get(medal, MEDAL_COLORS["Bronze"]))
	clear_gold_label.text = "Gold: " + str(medal_data.get("gold", 0))
	clear_silver_label.text = "Silver: " + str(medal_data.get("silver", 0))

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

func _set_canvas_item_alpha(item: CanvasItem, alpha: float) -> void:
	var item_modulate := item.modulate
	item_modulate.a = alpha
	item.modulate = item_modulate

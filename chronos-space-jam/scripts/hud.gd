## HUD — Displays gravity direction, tick, phase, time shifts
## Covers: UI-01 (Basic HUD), UI-02 (Gravity Indicator), CORE-07 (Move Count), FOUND-07 (Debug Overlay)
extends CanvasLayer

# --- References ---
@onready var gravity_label = $MarginContainer/VBoxContainer/GravityLabel
@onready var tick_label = $MarginContainer/VBoxContainer/TickLabel
@onready var shifts_label = $MarginContainer/VBoxContainer/ShiftsLabel
@onready var level_label = $MarginContainer/VBoxContainer/LevelLabel
@onready var death_panel = $DeathPanel
@onready var clear_panel = $ClearPanel
@onready var clear_shifts_label = $ClearPanel/VBoxContainer/ShiftsValue
@onready var clear_best_label = $ClearPanel/VBoxContainer/BestValue
@onready var clear_target_label = $ClearPanel/VBoxContainer/TargetValue # Need to add this to tscn
@onready var tutorial_label = $TutorialLabel

# Tutorial texts per level
var _tutorial_texts : Dictionary = {
	0: "WASD shifts gravity.\nYou slide until something stops you.",
	1: "Every move advances time by 1 tick.\nGates open and close with time.",
	2: "You cannot wait. You must move.\nFind a path to adjust your timing.",
	3: "Traps change phase every tick.\nRead the rhythm. Cross when safe.",
	4: "Spikes warn before striking.\nWatch for the yellow flash.",
	5: "Enemies patrol on a fixed pattern.\nTime your moves to avoid them.",
	6: "Blockers restrict movement by direction.\nApproach from the right angle.",
	7: "Everything combines here.\nMaster both space and time.",
}

var _gravity_arrows : Dictionary = {
	Vector2i(0, -1): "UP",
	Vector2i(0, 1): "DOWN",
	Vector2i(-1, 0): "LEFT",
	Vector2i(1, 0): "RIGHT",
	Vector2i(0, 0): "NONE",
}

func _ready() -> void:
	death_panel.visible = false
	clear_panel.visible = false
	tutorial_label.visible = false
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.level_cleared.connect(_on_level_cleared)
	GameManager.player_died.connect(_on_player_died)
	GameManager.level_loaded.connect(_on_level_loaded)
	TickManager.tick_advanced.connect(_on_tick_pulse)

func _on_tick_pulse(_tick: int) -> void:
	# Pulse the tick label
	var tween = create_tween()
	tick_label.modulate = Color(1, 1, 0) # Flash yellow
	tween.tween_property(tick_label, "modulate", Color.WHITE, 0.2)

func _process(_delta : float) -> void:
	_update_hud()

func _update_hud() -> void:
	# Get player reference
	var player = get_tree().get_first_node_in_group("player")
	var grav = Vector2i(0, 0)
	if player and "gravity_direction" in player:
		grav = player.gravity_direction

	var arrow_text = _gravity_arrows.get(grav, "NONE")
	gravity_label.text = "Gravity: " + str(arrow_text)
	tick_label.text = "Tick: " + str(TickManager.current_tick)
	shifts_label.text = "Time Shifts: " + str(TickManager.move_count)
	level_label.text = "Level " + str(GameManager.current_level_index + 1)

func _on_state_changed(new_state : int) -> void:
	if new_state == GameManager.GameState.DEAD:
		death_panel.visible = true
		clear_panel.visible = false
	elif new_state == GameManager.GameState.LEVEL_CLEAR:
		death_panel.visible = false
		clear_panel.visible = true
	else:
		death_panel.visible = false
		clear_panel.visible = false

func _on_level_cleared(move_count : int, best_moves : int, target : int) -> void:
	clear_shifts_label.text = "Time Shifts: " + str(move_count)
	clear_best_label.text = "Best: " + str(best_moves)
	if clear_target_label:
		clear_target_label.text = "Target: " + str(target)

func _on_player_died() -> void:
	pass  # death_panel shown by state change

func _on_level_loaded(level_index : int) -> void:
	# Show tutorial text
	if _tutorial_texts.has(level_index):
		tutorial_label.text = _tutorial_texts[level_index]
		tutorial_label.visible = true
		tutorial_label.modulate.a = 1.0
		# Hide after a few seconds
		var tween = create_tween()
		tween.tween_interval(4.0)
		tween.tween_property(tutorial_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(_hide_tutorial)
	else:
		tutorial_label.visible = false

func _hide_tutorial() -> void:
	tutorial_label.visible = false
	tutorial_label.modulate.a = 1.0

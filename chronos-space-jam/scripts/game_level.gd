## GameLevel — Main game scene controller
## Orchestrates level loading, player spawning, HUD connection
## Covers: CORE-03, CORE-04, CORE-08
extends Node2D

@onready var level_manager = $LevelManager
@onready var player = $Player
@onready var camera = $Camera2D
@onready var pause_menu = $HUD/PauseMenu

# --- Shake Effect ---
var _shake_intensity : float = 0.0
var _shake_duration : float = 0.0

func _ready() -> void:
	AudioManager.stop_music()
	player.add_to_group("player")
	GameManager.level_loaded.connect(_on_level_loaded)
	GameManager.player_died.connect(_on_player_died)
	GameManager.level_cleared.connect(_on_level_cleared)
	TickManager.tick_advanced.connect(_on_tick_advanced)

	# Load first level
	_load_current_level()

func _load_current_level() -> void:
	# Reset tick system
	TickManager.reset()

	# Load level data into the level manager
	var start_pos = level_manager.load_level(GameManager.current_level_index)

	# Initialize player at start position
	player.init_player(start_pos, level_manager)

	# Center camera on level
	var center_x = float(level_manager.grid_width * level_manager.TILE_SIZE) / 2.0
	var center_y = float(level_manager.grid_height * level_manager.TILE_SIZE) / 2.0
	camera.position = Vector2(center_x, center_y)

	# Adjust zoom based on level size
	var max_dim = maxf(float(level_manager.grid_width), float(level_manager.grid_height))
	var tile_f = float(level_manager.TILE_SIZE)
	var target_zoom = 800.0 / (max_dim * tile_f)
	target_zoom = clampf(target_zoom, 0.5, 2.0)
	camera.zoom = Vector2(target_zoom, target_zoom)

	# Reset pause menu
	if pause_menu:
		pause_menu.visible = false

	# Set game state
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().paused = false

func _process(delta: float) -> void:
	if _shake_duration > 0:
		_shake_duration -= delta
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
		camera.offset = offset
		if _shake_duration <= 0:
			camera.offset = Vector2.ZERO

func apply_shake(intensity: float, duration: float) -> void:
	if not SettingsManager.screen_shake_enabled:
		return
	_shake_intensity = intensity * (SettingsManager.screen_shake_intensity / 100.0)
	_shake_duration = duration

func _on_tick_advanced(_tick: int) -> void:
	AudioManager.play_tick()
	# Subtle shake on tick
	apply_shake(2.0, 0.1)

func _on_level_loaded(_level_index: int) -> void:
	_load_current_level()

func _on_player_died() -> void:
	AudioManager.play_death()
	# Strong shake on death
	apply_shake(15.0, 0.4)

func _on_level_cleared(_move_count: int, _best_moves: int, _target: int) -> void:
	AudioManager.play_level_clear()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		if GameManager.current_state == GameManager.GameState.DEAD or \
		   GameManager.current_state == GameManager.GameState.LEVEL_CLEAR or \
		   GameManager.current_state == GameManager.GameState.PLAYING:
			AudioManager.play_ui_click()
			GameManager.restart_level()
	elif event.is_action_pressed("ui_accept"):
		if GameManager.current_state == GameManager.GameState.LEVEL_CLEAR:
			AudioManager.play_ui_click()
			GameManager.next_level()
	elif event.is_action_pressed("ui_cancel"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			AudioManager.play_ui_click()
			GameManager.set_state(GameManager.GameState.PAUSED)
			get_tree().paused = true
			if pause_menu:
				pause_menu.visible = true
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			AudioManager.play_ui_back()
			GameManager.set_state(GameManager.GameState.PLAYING)
			get_tree().paused = false
			if pause_menu:
				pause_menu.visible = false

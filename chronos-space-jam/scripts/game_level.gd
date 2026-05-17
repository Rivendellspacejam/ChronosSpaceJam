extends Node2D

@onready var level_manager = $LevelManager
@onready var player = $Player
@onready var camera = $Camera2D
@onready var pause_menu = $HUD/PauseMenu

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0

func _ready() -> void:
	AudioManager.stop_music()
	player.add_to_group("player")
	GameManager.level_loaded.connect(_on_level_loaded)
	GameManager.player_died.connect(_on_player_died)
	GameManager.level_cleared.connect(_on_level_cleared)
	TickManager.tick_advanced.connect(_on_tick_advanced)
	_load_current_level()

func _process(delta: float) -> void:
	if _shake_duration <= 0:
		return

	_shake_duration -= delta
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
	if _shake_duration <= 0:
		camera.offset = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and _can_restart():
		AudioManager.play_ui_click()
		GameManager.restart_level()
	elif event.is_action_pressed("ui_accept") and GameManager.current_state == GameManager.GameState.LEVEL_CLEAR:
		AudioManager.play_ui_click()
		GameManager.next_level()
	elif event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func apply_shake(intensity: float, duration: float) -> void:
	if not SettingsManager.screen_shake_enabled:
		return

	_shake_intensity = intensity * (SettingsManager.screen_shake_intensity / 100.0)
	_shake_duration = duration

func _load_current_level() -> void:
	TickManager.reset()
	var start_pos = level_manager.load_level(GameManager.current_level_index)
	player.init_player(start_pos, level_manager)
	_center_camera_on_level()

	if pause_menu:
		pause_menu.visible = false

	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().paused = false

func _center_camera_on_level() -> void:
	var level_size = Vector2(
		float(level_manager.grid_width * level_manager.TILE_SIZE),
		float(level_manager.grid_height * level_manager.TILE_SIZE)
	)
	camera.position = level_size / 2.0

	var max_dim = maxf(float(level_manager.grid_width), float(level_manager.grid_height))
	var target_zoom = 800.0 / (max_dim * float(level_manager.TILE_SIZE))
	camera.zoom = Vector2.ONE * clampf(target_zoom, 0.5, 2.0)

func _can_restart() -> bool:
	return GameManager.current_state in [
		GameManager.GameState.DEAD,
		GameManager.GameState.LEVEL_CLEAR,
		GameManager.GameState.PLAYING,
	]

func _toggle_pause() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		AudioManager.play_ui_click()
		_set_paused(true)
	elif GameManager.current_state == GameManager.GameState.PAUSED:
		AudioManager.play_ui_back()
		_set_paused(false)

func _set_paused(paused: bool) -> void:
	GameManager.set_state(GameManager.GameState.PAUSED if paused else GameManager.GameState.PLAYING)
	get_tree().paused = paused
	if pause_menu:
		pause_menu.visible = paused

func _on_tick_advanced(_tick: int) -> void:
	AudioManager.play_tick()
	apply_shake(2.0, 0.1)

func _on_level_loaded(_level_index: int) -> void:
	_load_current_level()

func _on_player_died() -> void:
	AudioManager.play_death()
	apply_shake(15.0, 0.4)

func _on_level_cleared(_move_count: int, _best_moves: int, _target: int) -> void:
	AudioManager.play_level_clear()

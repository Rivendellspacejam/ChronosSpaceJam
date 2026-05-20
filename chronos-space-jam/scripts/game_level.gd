extends Node2D

const GAMEPLAY_GRAVITY_MUSIC := preload("res://assets/audio/gameplay_gravity_loop.wav")
const GAMEPLAY_HAZARD_MUSIC := preload("res://assets/audio/gameplay_hazard_loop.wav")
const GAMEPLAY_PATROL_MUSIC := preload("res://assets/audio/gameplay_patrol_loop.wav")
const GAMEPLAY_GOLD_MUSIC := preload("res://assets/audio/gameplay_gold_loop.wav")
const GAMEPLAY_BOUNCE_MUSIC := preload("res://assets/audio/gameplay_bounce_loop.wav")
const GAMEPLAY_PHASE_MUSIC := preload("res://assets/audio/gameplay_phase_loop.wav")

@onready var level_manager = $LevelManager
@onready var player = $Player
@onready var camera = $Camera2D
@onready var hud = $HUD
@onready var pause_menu = $HUD/PauseMenu
@onready var arena_backdrop = $ArenaBackdrop
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0

func _ready() -> void:
	AudioManager.stop_music()
	_ensure_background_music_playing()
	player.add_to_group("player")
	GameManager.level_loaded.connect(_on_level_loaded)
	GameManager.player_died.connect(_on_player_died)
	GameManager.level_cleared.connect(_on_level_cleared)
	TickManager.tick_advanced.connect(_on_tick_advanced)
	_load_current_level()

func _ensure_background_music_playing() -> void:
	_apply_background_music_volume()
	if not background_music.playing:
		background_music.play()

func _apply_background_music_volume() -> void:
	if SettingsManager.music_volume <= 0.0 or SettingsManager.mute_all:
		background_music.volume_db = -80.0
		return
	background_music.volume_db = -15.0 + linear_to_db(SettingsManager.music_volume / 100.0)

func _process(delta: float) -> void:
	_ensure_background_music_playing()
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
	var level_bundle = GameManager.load_level_bundle(GameManager.current_level_index)
	var start_tick = level_bundle.get("start_tick", 0)
	TickManager.reset(start_tick)
	_configure_level_music(GameManager.current_level_index)
	var start_pos = level_manager.load_level(GameManager.current_level_index)
	player.init_player(start_pos, level_manager)
	_configure_arena_backdrop()
	_center_camera_on_level()

	if pause_menu:
		pause_menu.visible = false

	get_tree().paused = false
	_start_level_story_or_play()

func _center_camera_on_level() -> void:
	var level_size = Vector2(
		float(level_manager.grid_width * level_manager.TILE_SIZE),
		float(level_manager.grid_height * level_manager.TILE_SIZE)
	)
	camera.position = level_size / 2.0

	var max_dim = maxf(float(level_manager.grid_width), float(level_manager.grid_height))
	var target_zoom = 800.0 / (max_dim * float(level_manager.TILE_SIZE))
	camera.zoom = Vector2.ONE * clampf(target_zoom, 0.5, 2.0)

func _configure_arena_backdrop() -> void:
	if arena_backdrop and arena_backdrop.has_method("configure"):
		if arena_backdrop.has_method("set_theme"):
			arena_backdrop.set_theme(GameManager.current_level_index)
		arena_backdrop.configure(level_manager.grid_width, level_manager.grid_height)

func _configure_level_music(level_index: int) -> void:
	var target_stream := _music_stream_for_level(level_index)
	if background_music.stream == target_stream:
		return
	background_music.stop()
	background_music.stream = target_stream
	_ensure_background_music_playing()

func _music_stream_for_level(index: int) -> AudioStream:
	if index <= 2:
		return GAMEPLAY_GRAVITY_MUSIC
	if index <= 4:
		return GAMEPLAY_HAZARD_MUSIC
	if index <= 11:
		return GAMEPLAY_PATROL_MUSIC
	if index <= 14:
		return GAMEPLAY_GOLD_MUSIC
	if index <= 19:
		return GAMEPLAY_BOUNCE_MUSIC
	return GAMEPLAY_PHASE_MUSIC

func _can_restart() -> bool:
	return GameManager.current_state in [
		GameManager.GameState.DEAD,
		GameManager.GameState.LEVEL_CLEAR,
		GameManager.GameState.PLAYING,
		GameManager.GameState.STORY,
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

func _start_level_story_or_play() -> void:
	if hud and StoryManager.should_show_level_story(GameManager.current_level_index):
		GameManager.set_state(GameManager.GameState.STORY)
		hud.show_level_story(GameManager.current_level_index, _on_level_story_finished)
		return

	GameManager.set_state(GameManager.GameState.PLAYING)

func _on_level_story_finished() -> void:
	StoryManager.mark_level_story_seen(GameManager.current_level_index)
	GameManager.set_state(GameManager.GameState.PLAYING)

func _on_tick_advanced(_tick: int) -> void:
	AudioManager.play_tick()
	apply_shake(2.0, 0.1)

func _on_level_loaded(_level_index: int) -> void:
	_load_current_level()

func _on_player_died() -> void:
	AudioManager.play_death()
	apply_shake(15.0, 0.4)

func _on_level_cleared(_move_count: int, _best_moves: int, _medal_data: Dictionary) -> void:
	AudioManager.play_level_clear()

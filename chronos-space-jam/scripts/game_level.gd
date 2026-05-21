extends Node2D

const GAMEPLAY_GRAVITY_MUSIC := preload("res://assets/audio/gameplay_gravity_loop.wav")
const GAMEPLAY_HAZARD_MUSIC := preload("res://assets/audio/gameplay_hazard_loop.wav")
const GAMEPLAY_PATROL_MUSIC := preload("res://assets/audio/gameplay_patrol_loop.wav")
const GAMEPLAY_GOLD_MUSIC := preload("res://assets/audio/gameplay_gold_loop.wav")
const GAMEPLAY_BOUNCE_MUSIC := preload("res://assets/audio/gameplay_bounce_loop.wav")
const GAMEPLAY_PHASE_MUSIC := preload("res://assets/audio/gameplay_phase_loop.wav")
const MUSIC_TARGET_VOLUME_DB: float = 1.0
const MUSIC_FADE_OUT_TIME: float = 0.5
const MUSIC_TRANSITION_PAUSE: float = 0.18
const MUSIC_FADE_IN_TIME: float = 0.85
const MUSIC_SILENCE_DB: float = -34.0
const PAUSE_MUFFLE_BUS := "PauseMuffledMusic"
const PAUSE_MUFFLE_CUTOFF_HZ: float = 850.0
const PAUSE_MUFFLE_RESONANCE: float = 0.45
const CAMERA_REFERENCE_FIT: float = 800.0
const CAMERA_MIN_ZOOM: float = 0.24
const CAMERA_MAX_ZOOM: float = 2.0
const CAMERA_SAFE_MARGIN: float = 24.0

@onready var level_manager = $LevelManager
@onready var player = $Player
@onready var camera = $Camera2D
@onready var hud = $HUD
@onready var pause_menu = $HUD/PauseMenu
@onready var arena_backdrop = $ArenaBackdrop
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _music_transitioning: bool = false
var _music_transition_id: int = 0
var _current_music_stream: AudioStream
var _pause_muffle_effect_index: int = -1
var _pause_muffle_enabled: bool = false
# One-step undo only: this snapshot is the state before the latest accepted shift.
var _undo_snapshot: Dictionary = {}

func _ready() -> void:
	_ensure_pause_muffle_bus()
	AudioManager.stop_music()
	background_music.stop()
	background_music.process_mode = Node.PROCESS_MODE_ALWAYS
	background_music.bus = PAUSE_MUFFLE_BUS
	background_music.volume_db = MUSIC_SILENCE_DB
	player.add_to_group("player")
	GameManager.level_loaded.connect(_on_level_loaded)
	GameManager.player_died.connect(_on_player_died)
	GameManager.level_cleared.connect(_on_level_cleared)
	GameManager.state_changed.connect(_on_game_state_changed_for_undo)
	TickManager.tick_advanced.connect(_on_tick_advanced)
	SettingsManager.settings_changed.connect(_apply_background_music_volume)
	if hud.has_signal("undo_requested"):
		hud.undo_requested.connect(_attempt_undo)
	_load_current_level()

func _ensure_background_music_playing() -> void:
	if _music_transitioning:
		return
	_apply_background_music_volume()
	if not background_music.playing:
		background_music.play()

func _apply_background_music_volume() -> void:
	if SettingsManager.music_volume <= 0.0 or SettingsManager.mute_all:
		background_music.volume_db = -80.0
		return
	background_music.volume_db = _target_music_volume_db()

func _target_music_volume_db() -> float:
	return MUSIC_TARGET_VOLUME_DB + linear_to_db(SettingsManager.music_volume / 100.0)

func _process(delta: float) -> void:
	_set_pause_muffle(GameManager.current_state == GameManager.GameState.PAUSED)
	_ensure_background_music_playing()
	if _shake_duration <= 0:
		return

	_shake_duration -= delta
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
	if _shake_duration <= 0:
		camera.offset = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("undo_tick"):
		_attempt_undo()
		return
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
	_set_pause_muffle(false)
	_clear_undo_snapshot()
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

func capture_undo_snapshot() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_undo_snapshot = {
		"tick": TickManager.current_tick,
		"move_count": TickManager.move_count,
		"player": player.capture_undo_state() if player.has_method("capture_undo_state") else {},
		"level": level_manager.capture_undo_state() if level_manager.has_method("capture_undo_state") else {},
	}
	_update_undo_available()

func _attempt_undo() -> void:
	if not _can_undo():
		return

	var snapshot := _undo_snapshot.duplicate(true)
	_undo_snapshot.clear()
	TickManager.restore_tick_state(int(snapshot.get("tick", TickManager.current_tick)), int(snapshot.get("move_count", TickManager.move_count)))
	if level_manager.has_method("restore_undo_state"):
		level_manager.restore_undo_state(snapshot.get("level", {}))
	if player.has_method("restore_undo_state"):
		player.restore_undo_state(snapshot.get("player", {}))
	GameManager.set_state(GameManager.GameState.PLAYING)
	AudioManager.play_ui_click()
	_update_undo_available()

func _can_undo() -> bool:
	if _undo_snapshot.is_empty():
		return false
	if GameManager.current_state not in [GameManager.GameState.PLAYING, GameManager.GameState.DEAD]:
		return false
	return not player.is_sliding()

func _clear_undo_snapshot() -> void:
	_undo_snapshot.clear()
	_update_undo_available()

func _update_undo_available() -> void:
	if hud != null and hud.has_method("set_undo_available"):
		hud.set_undo_available(_can_undo())

func _on_game_state_changed_for_undo(_new_state: int) -> void:
	_update_undo_available()

func _center_camera_on_level() -> void:
	var level_size: Vector2 = Vector2(
		float(level_manager.grid_width * level_manager.TILE_SIZE),
		float(level_manager.grid_height * level_manager.TILE_SIZE)
	)
	var level_center: Vector2 = level_size / 2.0
	var viewport_size: Vector2 = get_viewport_rect().size
	var default_zoom: float = _default_level_zoom()
	var default_screen_rect: Rect2 = _level_screen_rect(level_size, default_zoom, viewport_size * 0.5)
	var hud_rect: Rect2 = _hud_safe_rect()

	if not default_screen_rect.intersects(hud_rect):
		camera.position = level_center
		camera.zoom = Vector2.ONE * default_zoom
		return

	var safe_rect: Rect2 = _gameplay_safe_rect(viewport_size, hud_rect)
	var safe_zoom: float = _zoom_to_fit_level(level_size, safe_rect.size)
	camera.zoom = Vector2.ONE * safe_zoom
	camera.position = _camera_position_for_screen_center(level_center, viewport_size, safe_rect.get_center(), safe_zoom)

func _default_level_zoom() -> float:
	var max_dim = maxf(float(level_manager.grid_width), float(level_manager.grid_height))
	var target_zoom = CAMERA_REFERENCE_FIT / (max_dim * float(level_manager.TILE_SIZE))
	return clampf(target_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)

func _level_screen_rect(level_size: Vector2, zoom: float, screen_center: Vector2) -> Rect2:
	var screen_size := level_size * zoom
	return Rect2(screen_center - screen_size * 0.5, screen_size)

func _hud_safe_rect() -> Rect2:
	if hud != null and hud.has_method("get_stats_panel_screen_rect"):
		return hud.get_stats_panel_screen_rect()
	return Rect2(Vector2(16.0, 16.0), Vector2(312.0, 230.0))

func _gameplay_safe_rect(viewport_size: Vector2, hud_rect: Rect2) -> Rect2:
	var reserved_left := minf(hud_rect.end.x + CAMERA_SAFE_MARGIN, viewport_size.x * 0.48)
	var size := Vector2(
		maxf(1.0, viewport_size.x - reserved_left - CAMERA_SAFE_MARGIN),
		maxf(1.0, viewport_size.y - CAMERA_SAFE_MARGIN * 2.0)
	)
	return Rect2(Vector2(reserved_left, CAMERA_SAFE_MARGIN), size)

func _zoom_to_fit_level(level_size: Vector2, frame_size: Vector2) -> float:
	var target_zoom := minf(frame_size.x / level_size.x, frame_size.y / level_size.y)
	return clampf(target_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)

func _camera_position_for_screen_center(level_center: Vector2, viewport_size: Vector2, screen_center: Vector2, zoom: float) -> Vector2:
	return level_center - (screen_center - viewport_size * 0.5) / zoom

func _configure_arena_backdrop() -> void:
	if arena_backdrop and arena_backdrop.has_method("configure"):
		if arena_backdrop.has_method("set_theme"):
			arena_backdrop.set_theme(GameManager.current_level_index)
		arena_backdrop.configure(level_manager.grid_width, level_manager.grid_height)

func _configure_level_music(level_index: int) -> void:
	var target_stream := _music_stream_for_level(level_index)
	if _current_music_stream == target_stream and background_music.playing:
		return
	_transition_to_music(target_stream)

func _transition_to_music(target_stream: AudioStream) -> void:
	_music_transition_id += 1
	var transition_id := _music_transition_id
	_music_transitioning = true

	if background_music.playing:
		var fade_out := create_tween()
		fade_out.tween_property(background_music, "volume_db", MUSIC_SILENCE_DB, MUSIC_FADE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await fade_out.finished
		if transition_id != _music_transition_id:
			return

	await get_tree().create_timer(MUSIC_TRANSITION_PAUSE).timeout
	if transition_id != _music_transition_id:
		return

	background_music.stop()
	background_music.stream = target_stream
	_current_music_stream = target_stream
	background_music.volume_db = MUSIC_SILENCE_DB
	background_music.play()

	var fade_in := create_tween()
	fade_in.tween_property(background_music, "volume_db", _target_music_volume_db(), MUSIC_FADE_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	if transition_id != _music_transition_id:
		return

	_music_transitioning = false
	_apply_background_music_volume()

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
	_set_pause_muffle(paused)
	get_tree().paused = paused
	if pause_menu:
		pause_menu.visible = paused

func _exit_tree() -> void:
	_set_pause_muffle(false)

func _ensure_pause_muffle_bus() -> void:
	var bus_idx := AudioServer.get_bus_index(PAUSE_MUFFLE_BUS)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, PAUSE_MUFFLE_BUS)
		AudioServer.set_bus_send(bus_idx, "Master")

	_pause_muffle_effect_index = _find_pause_muffle_effect(bus_idx)
	if _pause_muffle_effect_index == -1:
		var effect := AudioEffectLowPassFilter.new()
		effect.cutoff_hz = PAUSE_MUFFLE_CUTOFF_HZ
		effect.resonance = PAUSE_MUFFLE_RESONANCE
		AudioServer.add_bus_effect(bus_idx, effect)
		_pause_muffle_effect_index = AudioServer.get_bus_effect_count(bus_idx) - 1

	AudioServer.set_bus_effect_enabled(bus_idx, _pause_muffle_effect_index, false)

func _find_pause_muffle_effect(bus_idx: int) -> int:
	for effect_idx in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect := AudioServer.get_bus_effect(bus_idx, effect_idx)
		if effect is AudioEffectLowPassFilter:
			return effect_idx
	return -1

func _set_pause_muffle(enabled: bool) -> void:
	if _pause_muffle_enabled == enabled:
		return

	var bus_idx := AudioServer.get_bus_index(PAUSE_MUFFLE_BUS)
	if bus_idx == -1 or _pause_muffle_effect_index == -1:
		return

	AudioServer.set_bus_effect_enabled(bus_idx, _pause_muffle_effect_index, enabled)
	_pause_muffle_enabled = enabled

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
	apply_shake(2.0, 0.1)

func _on_level_loaded(_level_index: int) -> void:
	_load_current_level()

func _on_player_died() -> void:
	AudioManager.play_death()
	apply_shake(15.0, 0.4)

func _on_level_cleared(_move_count: int, _best_moves: int, _medal_data: Dictionary) -> void:
	AudioManager.play_level_clear()

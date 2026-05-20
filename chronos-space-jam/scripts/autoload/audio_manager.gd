extends Node

const MENU_MUSIC := preload("res://assets/audio/menu_loop.wav")
const GAMEPLAY_MUSIC := preload("res://assets/audio/gameplay_loop.wav")
const ENDING_MUSIC := preload("res://assets/audio/ending_loop.wav")
const UI_CLICK := preload("res://assets/audio/ui_click.wav")
const UI_BACK := preload("res://assets/audio/ui_back.wav")
const SLIDE_START := preload("res://assets/audio/slide_start.wav")
const TICK := preload("res://assets/audio/tick.wav")
const DEATH := preload("res://assets/audio/death.wav")
const LEVEL_CLEAR := preload("res://assets/audio/level_clear.wav")
const SFX_POOL_SIZE := 8
const MUSIC_KEEPALIVE_INTERVAL: float = 0.2

var _music_player: AudioStreamPlayer
var _current_music_source: AudioStream
var _music_track_volume_db: float = 0.0
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _music_resume_attempts: int = 0
var _music_keepalive_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_ensure_audio_buses()
	_setup_music_player()
	_setup_sfx_pool()
	SettingsManager.settings_changed.connect(_apply_music_volume)
	_resume_music_if_needed()

func _process(delta: float) -> void:
	if _current_music_source == null or _music_player == null or _music_player.playing:
		return

	_music_keepalive_timer -= delta
	if _music_keepalive_timer > 0.0:
		return

	_music_keepalive_timer = MUSIC_KEEPALIVE_INTERVAL
	_resume_music_if_needed()

func _input(_event: InputEvent) -> void:
	_resume_music_if_needed()

func start_menu_music() -> void:
	_start_music(MENU_MUSIC, 0.0)

func start_gameplay_music() -> void:
	_start_music(GAMEPLAY_MUSIC, -2.0)

func start_ending_music() -> void:
	_start_music(ENDING_MUSIC, -1.0)

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_current_music_source = null

func get_music_player() -> AudioStreamPlayer:
	return _music_player

func play_ui_click() -> void:
	_play_sfx(UI_CLICK, -4.0)

func play_ui_back() -> void:
	_play_sfx(UI_BACK, -4.0)

func play_slide_start() -> void:
	_play_sfx(SLIDE_START, -6.0)

func play_tick() -> void:
	_play_sfx(TICK, -12.0)

func play_death() -> void:
	_play_sfx(DEATH, -3.0)

func play_level_clear() -> void:
	_play_sfx(LEVEL_CLEAR, -4.0)

func play_dialog_blip() -> void:
	_play_sfx(TICK, -18.0, randf_range(1.6, 2.1))

func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	_apply_music_volume()

func _start_music(stream: AudioStream, volume_db: float) -> void:
	if _current_music_source == stream and _music_player.playing:
		return

	_recreate_music_player()
	_current_music_source = stream
	_music_track_volume_db = volume_db
	_music_resume_attempts = 0
	_music_keepalive_timer = 0.0
	_music_player.stop()
	_music_player.stream = _looping_music(stream)
	_apply_music_volume()
	if is_node_ready():
		_music_player.call_deferred("play")
	else:
		call_deferred("_resume_music_if_needed")
	_schedule_music_resume_retries()

func _recreate_music_player() -> void:
	if _music_player != null:
		_music_player.stop()
		remove_child(_music_player)
		_music_player.queue_free()
		_music_player = null
	_setup_music_player()

func _apply_music_volume() -> void:
	if _music_player == null:
		return
	if SettingsManager.music_volume <= 0.0 or SettingsManager.mute_all:
		_music_player.volume_db = -80.0
		return

	_music_player.volume_db = _music_track_volume_db + linear_to_db(SettingsManager.music_volume / 100.0)

func _resume_music_if_needed() -> void:
	if _music_player == null or _current_music_source == null:
		return
	_music_resume_attempts += 1
	if _music_player.stream == null:
		_music_player.stream = _looping_music(_current_music_source)
	if not _music_player.playing:
		_apply_music_volume()
		_music_player.call_deferred("play")

func _schedule_music_resume_retries() -> void:
	if not is_inside_tree():
		call_deferred("_schedule_music_resume_retries")
		return

	for delay in [0.05, 0.2, 0.5, 1.0]:
		get_tree().create_timer(delay).timeout.connect(_resume_music_if_needed)

func _setup_sfx_pool() -> void:
	_ensure_audio_bus("SFX")
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

func _ensure_audio_buses() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _looping_music(stream: AudioStream) -> AudioStream:
	var music_stream := stream.duplicate()
	if music_stream is AudioStreamWAV:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return music_stream

func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if _sfx_players.is_empty():
		_resume_music_if_needed()
		return

	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	_resume_music_after_audio_interaction()

func _resume_music_after_audio_interaction() -> void:
	if _music_player == null or _current_music_source == null:
		return
	if _music_resume_attempts >= 16 and _music_player.playing:
		return

	_music_player.stream = _looping_music(_current_music_source)
	_music_player.call_deferred("play")

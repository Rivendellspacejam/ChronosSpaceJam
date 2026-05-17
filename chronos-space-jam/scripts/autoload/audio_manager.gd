extends Node

const MENU_MUSIC := preload("res://assets/audio/menu_loop.wav")
const UI_CLICK := preload("res://assets/audio/ui_click.wav")
const UI_BACK := preload("res://assets/audio/ui_back.wav")
const SLIDE_START := preload("res://assets/audio/slide_start.wav")
const TICK := preload("res://assets/audio/tick.wav")
const DEATH := preload("res://assets/audio/death.wav")
const LEVEL_CLEAR := preload("res://assets/audio/level_clear.wav")
const SFX_POOL_SIZE := 8

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_music_player()
	_setup_sfx_pool()

func start_menu_music() -> void:
	if _music_player != null and not _music_player.playing:
		_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()

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

func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = _looping_menu_music()
	_music_player.volume_db = -8.0
	add_child(_music_player)

func _setup_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

func _looping_menu_music() -> AudioStream:
	var music_stream := MENU_MUSIC.duplicate()
	if music_stream is AudioStreamWAV:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return music_stream

func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _sfx_players.is_empty():
		return

	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()

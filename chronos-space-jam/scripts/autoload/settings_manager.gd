extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

var master_volume : float = 50.0
var music_volume  : float = 50.0
var sfx_volume    : float = 50.0
var mute_all      : bool  = false

var fullscreen : bool = false
var vsync      : bool = true

var screen_shake_enabled   : bool  = true
var screen_shake_intensity : float = 50.0

func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	apply_audio()
	apply_display()

func apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")

	_apply_bus_volume(master_idx, master_volume, mute_all)
	_apply_bus_volume(music_idx, music_volume, false)
	_apply_bus_volume(sfx_idx, sfx_volume, false)
	settings_changed.emit()

func apply_display() -> void:
	var window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var vsync_mode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED

	DisplayServer.window_set_mode(window_mode)
	DisplayServer.window_set_vsync_mode(vsync_mode)
	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume",  music_volume)
	cfg.set_value("audio", "sfx_volume",    sfx_volume)
	cfg.set_value("audio", "mute_all",      mute_all)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync",      vsync)
	cfg.set_value("gameplay", "screen_shake",           screen_shake_enabled)
	cfg.set_value("gameplay", "screen_shake_intensity", screen_shake_intensity)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	master_volume = cfg.get_value("audio", "master_volume", 50.0)
	music_volume  = cfg.get_value("audio", "music_volume",  50.0)
	sfx_volume    = cfg.get_value("audio", "sfx_volume",    50.0)
	mute_all      = cfg.get_value("audio", "mute_all",      false)
	fullscreen = cfg.get_value("display", "fullscreen", false)
	vsync      = cfg.get_value("display", "vsync",      true)
	screen_shake_enabled   = cfg.get_value("gameplay", "screen_shake",           true)
	screen_shake_intensity = cfg.get_value("gameplay", "screen_shake_intensity", 50.0)

func _ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _apply_bus_volume(bus_idx: int, percent: float, muted: bool) -> void:
	if bus_idx == -1:
		return

	var should_mute = muted or percent <= 0.0
	AudioServer.set_bus_mute(bus_idx, should_mute)
	if not should_mute:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(percent / 100.0))

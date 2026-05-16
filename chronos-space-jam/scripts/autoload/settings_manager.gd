## SettingsManager — Global settings singleton
## Covers: UI-10 (Settings Menu)
## Persists to user://settings.cfg
extends Node

signal settings_changed

# --- Audio ---
var master_volume : float = 100.0
var music_volume  : float = 100.0
var sfx_volume    : float = 100.0
var mute_all      : bool  = false

# --- Display ---
var fullscreen : bool = false
var vsync      : bool = true

# --- Gameplay ---
var screen_shake_enabled   : bool  = true
var screen_shake_intensity : float = 100.0

const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	apply_audio()
	apply_display()

# ---------------------------------------------------------------------------
# Audio bus helpers
# ---------------------------------------------------------------------------
func _ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

# ---------------------------------------------------------------------------
# Apply methods
# ---------------------------------------------------------------------------
func apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx  := AudioServer.get_bus_index("Music")
	var sfx_idx    := AudioServer.get_bus_index("SFX")

	if mute_all:
		AudioServer.set_bus_mute(master_idx, true)
	else:
		AudioServer.set_bus_mute(master_idx, false)
		if master_idx != -1:
			if master_volume <= 0:
				AudioServer.set_bus_mute(master_idx, true)
			else:
				AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume / 100.0))
		if music_idx != -1:
			if music_volume <= 0:
				AudioServer.set_bus_mute(music_idx, true)
			else:
				AudioServer.set_bus_mute(music_idx, false)
				AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume / 100.0))
		if sfx_idx != -1:
			if sfx_volume <= 0:
				AudioServer.set_bus_mute(sfx_idx, true)
			else:
				AudioServer.set_bus_mute(sfx_idx, false)
				AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume / 100.0))

	emit_signal("settings_changed")

func apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	emit_signal("settings_changed")

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
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
		return  # file doesn't exist yet — keep defaults

	master_volume = cfg.get_value("audio", "master_volume", 100.0)
	music_volume  = cfg.get_value("audio", "music_volume",  100.0)
	sfx_volume    = cfg.get_value("audio", "sfx_volume",    100.0)
	mute_all      = cfg.get_value("audio", "mute_all",      false)

	fullscreen = cfg.get_value("display", "fullscreen", false)
	vsync      = cfg.get_value("display", "vsync",      true)

	screen_shake_enabled   = cfg.get_value("gameplay", "screen_shake",           true)
	screen_shake_intensity = cfg.get_value("gameplay", "screen_shake_intensity", 100.0)

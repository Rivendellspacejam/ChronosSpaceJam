## SettingsMenu — Reusable settings panel
## Covers: UI-10 (Settings Menu)
## Opened from Main Menu or Pause Menu; returns to whichever called it.
extends Control

## The Control to show again when the player presses BACK.
## Set by the caller before showing this menu.
var return_target : Control = null

# --- Audio controls ---
@onready var master_slider : HSlider     = $CenterContainer/PanelContainer/VBoxContainer/AudioSection/MasterRow/MasterSlider
@onready var music_slider  : HSlider     = $CenterContainer/PanelContainer/VBoxContainer/AudioSection/MusicRow/MusicSlider
@onready var sfx_slider    : HSlider     = $CenterContainer/PanelContainer/VBoxContainer/AudioSection/SFXRow/SFXSlider
@onready var mute_button   : CheckButton = $CenterContainer/PanelContainer/VBoxContainer/AudioSection/MuteRow/MuteButton

# --- Display controls ---
@onready var fullscreen_button : CheckButton = $CenterContainer/PanelContainer/VBoxContainer/DisplaySection/FullscreenRow/FullscreenButton
@onready var vsync_button      : CheckButton = $CenterContainer/PanelContainer/VBoxContainer/DisplaySection/VSyncRow/VSyncButton

# --- Gameplay controls ---
@onready var shake_button    : CheckButton = $CenterContainer/PanelContainer/VBoxContainer/GameplaySection/ShakeRow/ShakeButton
@onready var shake_slider    : HSlider     = $CenterContainer/PanelContainer/VBoxContainer/GameplaySection/ShakeIntensityRow/ShakeSlider
@onready var shake_intensity_row : Control = $CenterContainer/PanelContainer/VBoxContainer/GameplaySection/ShakeIntensityRow

@onready var back_button : Button = $CenterContainer/PanelContainer/VBoxContainer/BackButton

func _ready() -> void:
	# Populate controls from current settings
	master_slider.value = SettingsManager.master_volume
	music_slider.value  = SettingsManager.music_volume
	sfx_slider.value    = SettingsManager.sfx_volume
	mute_button.button_pressed = SettingsManager.mute_all

	fullscreen_button.button_pressed = SettingsManager.fullscreen
	vsync_button.button_pressed      = SettingsManager.vsync

	shake_button.button_pressed = SettingsManager.screen_shake_enabled
	shake_slider.value          = SettingsManager.screen_shake_intensity
	shake_intensity_row.visible = SettingsManager.screen_shake_enabled

	# Connect signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	mute_button.toggled.connect(_on_mute_toggled)

	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	vsync_button.toggled.connect(_on_vsync_toggled)

	shake_button.toggled.connect(_on_shake_toggled)
	shake_slider.value_changed.connect(_on_shake_intensity_changed)

	back_button.pressed.connect(_on_back)

# ---------------------------------------------------------------------------
# Audio handlers
# ---------------------------------------------------------------------------
func _on_master_volume_changed(value: float) -> void:
	SettingsManager.master_volume = value
	SettingsManager.apply_audio()

func _on_music_volume_changed(value: float) -> void:
	SettingsManager.music_volume = value
	SettingsManager.apply_audio()

func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	SettingsManager.apply_audio()

func _on_mute_toggled(pressed: bool) -> void:
	SettingsManager.mute_all = pressed
	SettingsManager.apply_audio()

# ---------------------------------------------------------------------------
# Display handlers
# ---------------------------------------------------------------------------
func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.fullscreen = pressed
	SettingsManager.apply_display()

func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.vsync = pressed
	SettingsManager.apply_display()

# ---------------------------------------------------------------------------
# Gameplay handlers
# ---------------------------------------------------------------------------
func _on_shake_toggled(pressed: bool) -> void:
	SettingsManager.screen_shake_enabled = pressed
	shake_intensity_row.visible = pressed

func _on_shake_intensity_changed(value: float) -> void:
	SettingsManager.screen_shake_intensity = value

# ---------------------------------------------------------------------------
# Back
# ---------------------------------------------------------------------------
func _on_back() -> void:
	SettingsManager.save_settings()
	visible = false
	if return_target != null:
		return_target.visible = true

extends Control

var return_target: Control = null

@onready var master_slider: HSlider = $VBoxContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXRow/SFXSlider
@onready var mute_button: CheckButton = $VBoxContainer/MuteRow/MuteButton
@onready var master_value_label: Label = $VBoxContainer/MasterRow/MasterValueLabel
@onready var music_value_label: Label = $VBoxContainer/MusicRow/MusicValueLabel
@onready var sfx_value_label: Label = $VBoxContainer/SFXRow/SFXValueLabel

@onready var fullscreen_button: CheckButton = $VBoxContainer/FullscreenRow/FullscreenButton
@onready var vsync_button: CheckButton = $VBoxContainer/VSyncRow/VSyncButton

@onready var shake_button: CheckButton = $VBoxContainer/ShakeRow/ShakeButton
@onready var shake_slider: HSlider = $VBoxContainer/ShakeIntensityRow/ShakeSlider
@onready var shake_value_label: Label = $VBoxContainer/ShakeIntensityRow/ShakeValueLabel
@onready var shake_intensity_row: Control = $VBoxContainer/ShakeIntensityRow
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	_sync_controls_from_settings()
	_wire_signals()
	_update_value_labels()

func _sync_controls_from_settings() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	mute_button.button_pressed = SettingsManager.mute_all
	fullscreen_button.button_pressed = SettingsManager.fullscreen
	vsync_button.button_pressed = SettingsManager.vsync
	shake_button.button_pressed = SettingsManager.screen_shake_enabled
	shake_slider.value = SettingsManager.screen_shake_intensity
	shake_intensity_row.visible = SettingsManager.screen_shake_enabled

func _wire_signals() -> void:
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	master_slider.drag_ended.connect(_on_slider_drag_ended)
	music_slider.drag_ended.connect(_on_slider_drag_ended)
	sfx_slider.drag_ended.connect(_on_slider_drag_ended)
	mute_button.toggled.connect(_on_mute_toggled)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	vsync_button.toggled.connect(_on_vsync_toggled)
	shake_button.toggled.connect(_on_shake_toggled)
	shake_slider.value_changed.connect(_on_shake_intensity_changed)
	shake_slider.drag_ended.connect(_on_slider_drag_ended)
	back_button.pressed.connect(_on_back)

func _on_master_volume_changed(value: float) -> void:
	SettingsManager.master_volume = value
	_apply_audio_setting()

func _on_music_volume_changed(value: float) -> void:
	SettingsManager.music_volume = value
	_apply_audio_setting()

func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	_apply_audio_setting()

func _on_mute_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	SettingsManager.mute_all = pressed
	SettingsManager.apply_audio()

func _on_fullscreen_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	SettingsManager.fullscreen = pressed
	SettingsManager.apply_display()

func _on_vsync_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	SettingsManager.vsync = pressed
	SettingsManager.apply_display()

func _on_shake_toggled(pressed: bool) -> void:
	AudioManager.play_ui_click()
	SettingsManager.screen_shake_enabled = pressed
	shake_intensity_row.visible = pressed

func _on_shake_intensity_changed(value: float) -> void:
	SettingsManager.screen_shake_intensity = value
	_update_value_labels()

func _on_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		AudioManager.play_ui_click()

func _update_value_labels() -> void:
	master_value_label.text = _format_percent(master_slider.value)
	music_value_label.text = _format_percent(music_slider.value)
	sfx_value_label.text = _format_percent(sfx_slider.value)
	shake_value_label.text = _format_percent(shake_slider.value)

func _apply_audio_setting() -> void:
	SettingsManager.apply_audio()
	_update_value_labels()

func _format_percent(value: float) -> String:
	return str(roundi(value)) + "%"

func _on_back() -> void:
	AudioManager.play_ui_back()
	SettingsManager.save_settings()
	visible = false
	if return_target != null:
		return_target.visible = true

## Laser — Phase-based trap, alternates active/inactive
## Covers: TIME-05 (Laser Trap)
extends Node2D

# --- Config ---
@export var phase_count : int = 2
@export var active_pattern : Array[bool] = [false, true]

# --- State ---
var grid_pos : Vector2i = Vector2i.ZERO
var current_phase : int = 0
var _is_active_state : bool = false

# --- Visual ---
var _visual_rect : ColorRect = null
var _beam_rect : ColorRect = null

const TILE_SIZE : int = 64

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	var ts = float(TILE_SIZE)
	# Base tile
	_visual_rect = ColorRect.new()
	_visual_rect.size = Vector2(ts - 4.0, ts - 4.0)
	_visual_rect.position = Vector2(-ts / 2.0 + 2.0, -ts / 2.0 + 2.0)
	add_child(_visual_rect)

	# Beam/laser center
	_beam_rect = ColorRect.new()
	_beam_rect.size = Vector2(ts - 16.0, ts - 16.0)
	_beam_rect.position = Vector2(-ts / 2.0 + 8.0, -ts / 2.0 + 8.0)
	add_child(_beam_rect)

func update_phase(current_tick : int) -> void:
	if phase_count <= 0:
		phase_count = active_pattern.size()
	current_phase = current_tick % phase_count
	if current_phase < active_pattern.size():
		_is_active_state = active_pattern[current_phase]
	else:
		_is_active_state = false
	_update_visual()

func is_active() -> bool:
	return _is_active_state

func _update_visual() -> void:
	if _visual_rect == null or _beam_rect == null:
		return
	if _is_active_state:
		# Active: bright red, deadly
		_visual_rect.color = Color(1.0, 0.1, 0.1, 0.6)
		_beam_rect.color = Color(1.0, 0.2, 0.2, 0.9)
	else:
		# Inactive: dim, safe
		_visual_rect.color = Color(0.3, 0.08, 0.08, 0.3)
		_beam_rect.color = Color(0.4, 0.1, 0.1, 0.3)

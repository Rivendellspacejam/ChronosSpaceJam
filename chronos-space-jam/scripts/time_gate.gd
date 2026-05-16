## TimeGate — Opens/closes based on tick phase
## Covers: TIME-04 (Time Gate)
extends Node2D

# --- Config ---
@export var phase_count : int = 2
@export var open_pattern : Array[bool] = [false, true]

# --- State ---
var grid_pos : Vector2i = Vector2i.ZERO
var current_phase : int = 0
var _is_open : bool = false

# --- Visual ---
var _visual_rect : ColorRect = null
var _border_rect : ColorRect = null

const TILE_SIZE : int = 64

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	var ts = float(TILE_SIZE)
	# Border/frame
	_border_rect = ColorRect.new()
	_border_rect.size = Vector2(ts - 4.0, ts - 4.0)
	_border_rect.position = Vector2(-ts / 2.0 + 2.0, -ts / 2.0 + 2.0)
	add_child(_border_rect)

	# Inner
	_visual_rect = ColorRect.new()
	_visual_rect.size = Vector2(ts - 12.0, ts - 12.0)
	_visual_rect.position = Vector2(-ts / 2.0 + 6.0, -ts / 2.0 + 6.0)
	add_child(_visual_rect)

func update_phase(current_tick : int) -> void:
	if phase_count <= 0:
		phase_count = open_pattern.size()
	current_phase = current_tick % phase_count
	if current_phase < open_pattern.size():
		_is_open = open_pattern[current_phase]
	else:
		_is_open = false
	_update_visual()

func is_closed() -> bool:
	return not _is_open

func _update_visual() -> void:
	if _border_rect == null or _visual_rect == null:
		return
	if _is_open:
		# Open gate: transparent blue outline
		_border_rect.color = Color(0.2, 0.5, 1.0, 0.3)
		_visual_rect.color = Color(0.1, 0.3, 0.8, 0.1)
	else:
		# Closed gate: solid red/orange barrier
		_border_rect.color = Color(1.0, 0.3, 0.1, 0.9)
		_visual_rect.color = Color(0.9, 0.2, 0.1, 0.7)

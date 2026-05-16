## TimeGate — Opens/closes based on tick phase
## Covers: TIME-04 (Time Gate)
extends Node2D

# --- Config ---
@export var phase_count: int = 2
## Pattern: array of booleans, true = open, false = closed
## Default: [false, true] = closed on even ticks, open on odd ticks
@export var open_pattern: Array[bool] = [false, true]

# --- State ---
var grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var _is_open: bool = false

# --- Visual ---
var _visual_rect: ColorRect
var _border_rect: ColorRect

const TILE_SIZE := 64

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	# Border/frame
	_border_rect = ColorRect.new()
	_border_rect.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
	_border_rect.position = Vector2(-TILE_SIZE / 2.0 + 2, -TILE_SIZE / 2.0 + 2)
	add_child(_border_rect)

	# Inner
	_visual_rect = ColorRect.new()
	_visual_rect.size = Vector2(TILE_SIZE - 12, TILE_SIZE - 12)
	_visual_rect.position = Vector2(-TILE_SIZE / 2.0 + 6, -TILE_SIZE / 2.0 + 6)
	add_child(_visual_rect)

func update_phase(current_tick: int) -> void:
	"""Called by TickManager every tick."""
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
	if _is_open:
		# Open gate: transparent blue outline
		_border_rect.color = Color(0.2, 0.5, 1.0, 0.3)
		_visual_rect.color = Color(0.1, 0.3, 0.8, 0.1)
	else:
		# Closed gate: solid red/orange barrier
		_border_rect.color = Color(1.0, 0.3, 0.1, 0.9)
		_visual_rect.color = Color(0.9, 0.2, 0.1, 0.7)

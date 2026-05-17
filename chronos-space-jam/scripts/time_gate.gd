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
var _sprite : Sprite2D = null

const TILE_SIZE : int = 48

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/time_gate_tile.png")
	add_child(_sprite)

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
	if _sprite == null:
		return
	if _is_open:
		# Open gate: dim/transparent
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.2)
	else:
		# Closed gate: solid
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

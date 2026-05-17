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
var _sprite : Sprite2D = null

const TILE_SIZE : int = 48

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/laser_tile.png")
	add_child(_sprite)

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
	if _sprite == null:
		return
	if _is_active_state:
		# Active: fully bright
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Inactive: dim, transparent
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)

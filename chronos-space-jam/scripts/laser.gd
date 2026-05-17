## Laser — Line hazard. Fires a beam along a row or column when active.
## The beam kills the player if the slide PATH crosses it (not just the laser tile itself).
## Laser never blocks movement. It is only dangerous when active.
## Covers: TIME-05 (Laser Trap)
extends Node2D

# --- Config ---
@export var phase_count : int = 2
@export var active_pattern : Array[bool] = [false, true]

# Beam direction: Vector2i(1,0)=horizontal, Vector2i(0,1)=vertical.
# TODO: For full level-design control, load beam_direction from level metadata
#       (e.g. a suffix on the tile symbol like "LH"/"LV"). For now, default
#       to HORIZONTAL and expose as an exported property so it can be set in
#       the scene or overridden per-instance in the editor.
@export_enum("Horizontal:0", "Vertical:1") var beam_axis : int = 0

# --- State ---
var grid_pos : Vector2i = Vector2i.ZERO
var current_phase : int = 0
var _is_active_state : bool = false

# --- Visual ---
var _sprite : Sprite2D = null
var _beam_overlay : ColorRect = null  # visual beam stripe

const TILE_SIZE : int = 48

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/laser_tile.png")
	add_child(_sprite)
	# Beam overlay: a thin colored stripe that shows the beam direction
	_beam_overlay = ColorRect.new()
	if beam_axis == 0:
		# Horizontal beam — full width stripe
		_beam_overlay.size = Vector2(TILE_SIZE, 6)
		_beam_overlay.position = Vector2(-TILE_SIZE / 2.0, -3)
	else:
		# Vertical beam — full height stripe
		_beam_overlay.size = Vector2(6, TILE_SIZE)
		_beam_overlay.position = Vector2(-3, -TILE_SIZE / 2.0)
	_beam_overlay.color = Color(1.0, 0.2, 0.2, 0.7)
	_beam_overlay.visible = false
	add_child(_beam_overlay)

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

# Returns the beam direction vector for this laser.
# Horizontal (beam_axis=0) → fires left/right along the row  → dir = (1,0)
# Vertical   (beam_axis=1) → fires up/down along the column → dir = (0,1)
func get_beam_direction() -> Vector2i:
	if beam_axis == 0:
		return Vector2i(1, 0)   # horizontal
	else:
		return Vector2i(0, 1)   # vertical

func _update_visual() -> void:
	if _sprite == null:
		return
	if _is_active_state:
		# Active: fully bright emitter tile + visible beam overlay
		_sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
		if _beam_overlay:
			_beam_overlay.visible = true
			_beam_overlay.color = Color(1.0, 0.2, 0.2, 0.7)
	else:
		# Inactive: dim/off, no beam
		_sprite.modulate = Color(0.5, 0.3, 0.3, 0.4)
		if _beam_overlay:
			_beam_overlay.visible = false

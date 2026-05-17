extends Node2D

const TILE_SIZE: int = 48

@export var phase_count: int = 2
@export var active_pattern: Array[bool] = [false, true]
@export_enum("Horizontal:0", "Vertical:1") var beam_axis: int = 0

var grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var _is_active_state: bool = false
var _sprite: Sprite2D = null
var _beam_overlay: ColorRect = null

func _ready() -> void:
	_build_visual()
	update_phase(0)

func update_phase(current_tick: int) -> void:
	if phase_count <= 0:
		phase_count = active_pattern.size()

	current_phase = current_tick % phase_count
	_is_active_state = current_phase < active_pattern.size() and active_pattern[current_phase]
	_update_visual()

func is_active() -> bool:
	return _is_active_state

func get_beam_direction() -> Vector2i:
	if beam_axis == 0:
		return Vector2i(1, 0)
	return Vector2i(0, 1)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/laser_tile.png")
	add_child(_sprite)

	_beam_overlay = ColorRect.new()
	if beam_axis == 0:
		_beam_overlay.size = Vector2(TILE_SIZE, 6)
		_beam_overlay.position = Vector2(-TILE_SIZE / 2.0, -3)
	else:
		_beam_overlay.size = Vector2(6, TILE_SIZE)
		_beam_overlay.position = Vector2(-3, -TILE_SIZE / 2.0)

	_beam_overlay.color = Color(1.0, 0.2, 0.2, 0.7)
	_beam_overlay.visible = false
	add_child(_beam_overlay)

func _update_visual() -> void:
	if _sprite == null:
		return

	if _is_active_state:
		_sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
		_beam_overlay.visible = true
		_beam_overlay.color = Color(1.0, 0.2, 0.2, 0.7)
	else:
		_sprite.modulate = Color(0.5, 0.3, 0.3, 0.4)
		_beam_overlay.visible = false

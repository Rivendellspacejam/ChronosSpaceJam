extends Node2D

const TILE_SIZE: int = 48

@export var patrol_offsets: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

var grid_pos: Vector2i = Vector2i.ZERO
var current_grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0

func _ready() -> void:
	_build_visual()
	update_phase(0)

func update_phase(current_tick: int) -> void:
	if patrol_offsets.is_empty():
		return

	current_phase = current_tick % patrol_offsets.size()
	current_grid_pos = grid_pos + patrol_offsets[current_phase]
	_snap_to_current_grid_pos()

func _build_visual() -> void:
	var body = _make_rect(Vector2(TILE_SIZE - 8.0, TILE_SIZE - 8.0), 4.0, Color(1.0, 0.3, 0.7, 0.8))
	var core = _make_rect(Vector2(TILE_SIZE - 24.0, TILE_SIZE - 24.0), 12.0, Color(1.0, 0.1, 0.5, 1.0))
	add_child(body)
	add_child(core)

func _make_rect(size: Vector2, inset: float, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.size = size
	rect.position = Vector2(-TILE_SIZE / 2.0 + inset, -TILE_SIZE / 2.0 + inset)
	rect.color = color
	return rect

func _snap_to_current_grid_pos() -> void:
	var objects_node = get_parent()
	if objects_node == null:
		return

	var level_manager = objects_node.get_parent()
	if level_manager != null and level_manager.has_method("grid_to_world"):
		position = level_manager.grid_to_world(current_grid_pos)

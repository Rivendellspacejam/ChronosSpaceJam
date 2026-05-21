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
	update_phase(0)

func get_grid_pos_for_tick(tick: int) -> Vector2i:
	if patrol_offsets.is_empty():
		return grid_pos

	var phase := TickManager.phase_for_tick(tick, patrol_offsets.size())
	return grid_pos + patrol_offsets[phase]

func get_next_grid_pos() -> Vector2i:
	return get_grid_pos_for_tick(TickManager.current_tick + 1)

func update_phase(current_tick: int) -> void:
	if patrol_offsets.is_empty():
		return
	current_phase = TickManager.phase_for_tick(current_tick, patrol_offsets.size())
	current_grid_pos = get_grid_pos_for_tick(current_tick)
	_snap_to_current_grid_pos()

func _snap_to_current_grid_pos() -> void:
	var objects_node = get_parent()
	if objects_node == null:
		return

	var level_manager = objects_node.get_parent()
	if level_manager != null and level_manager.has_method("grid_to_world"):
		position = level_manager.grid_to_world(current_grid_pos)

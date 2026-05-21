extends Node2D

const TILE_SIZE: int = 48
const FRAME_IDLE: int = 0
const FRAME_NORTH: int = 1
const FRAME_EAST: int = 2
const FRAME_SOUTH: int = 3
const FRAME_WEST: int = 4

@export var patrol_offsets: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

var grid_pos: Vector2i = Vector2i.ZERO
var current_grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0

@onready var _visual: Sprite2D = $EnemyVisual

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
	_update_direction_frame(current_tick)
	_snap_to_current_grid_pos()
	_update_anchor_overlap_visibility()

func _update_direction_frame(current_tick: int) -> void:
	var next_grid_pos := get_grid_pos_for_tick(current_tick + 1)
	var move_delta := next_grid_pos - current_grid_pos
	_visual.frame = _frame_for_move_delta(move_delta)

func _frame_for_move_delta(move_delta: Vector2i) -> int:
	if move_delta == Vector2i.ZERO:
		return FRAME_IDLE
	if abs(move_delta.x) >= abs(move_delta.y):
		return FRAME_EAST if move_delta.x > 0 else FRAME_WEST
	return FRAME_SOUTH if move_delta.y > 0 else FRAME_NORTH

func _snap_to_current_grid_pos() -> void:
	var objects_node = get_parent()
	if objects_node == null:
		return

	var level_manager = objects_node.get_parent()
	if level_manager != null and level_manager.has_method("grid_to_world"):
		position = level_manager.grid_to_world(current_grid_pos)

func _update_anchor_overlap_visibility() -> void:
	var objects_node = get_parent()
	if objects_node == null:
		return

	var level_manager = objects_node.get_parent()
	if level_manager == null or not level_manager.has_method("update_anchor_overlap_visibility"):
		return

	_visual.modulate = Color.WHITE
	level_manager.update_anchor_overlap_visibility()

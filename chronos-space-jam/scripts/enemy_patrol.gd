extends Node2D

const TILE_SIZE: int = 48
const FRAME_IDLE: int = 0
const FRAME_NORTH: int = 1
const FRAME_EAST: int = 2
const FRAME_SOUTH: int = 3
const FRAME_WEST: int = 4
const PHASE_FADE_OUT_TIME: float = 0.08
const PHASE_FADE_IN_TIME: float = 0.14
const PHASE_SCALE_PEAK: Vector2 = Vector2(1.22, 1.22)

@export var patrol_offsets: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

var grid_pos: Vector2i = Vector2i.ZERO
var current_grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var _has_positioned_visual: bool = false
var _phase_tween: Tween = null

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
	var previous_grid_pos := current_grid_pos
	var previous_position := position
	current_phase = TickManager.phase_for_tick(current_tick, patrol_offsets.size())
	current_grid_pos = get_grid_pos_for_tick(current_tick)
	_update_direction_frame(current_tick)
	_snap_to_current_grid_pos(previous_grid_pos, previous_position)
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

func _snap_to_current_grid_pos(previous_grid_pos: Vector2i, previous_position: Vector2) -> void:
	var objects_node = get_parent()
	if objects_node == null:
		return

	var level_manager = objects_node.get_parent()
	if level_manager != null and level_manager.has_method("grid_to_world"):
		var target_position: Vector2 = level_manager.grid_to_world(current_grid_pos)
		if not _has_positioned_visual or previous_grid_pos == current_grid_pos:
			position = target_position
			_visual.modulate = Color.WHITE
			_visual.scale = Vector2.ONE
			_has_positioned_visual = true
			return
		_play_phase_transition(previous_position, target_position)

func _play_phase_transition(from_position: Vector2, target_position: Vector2) -> void:
	if _phase_tween != null:
		_phase_tween.kill()
	position = from_position
	_visual.modulate = Color.WHITE
	_visual.scale = Vector2.ONE

	_phase_tween = create_tween()
	_phase_tween.tween_property(_visual, "modulate:a", 0.15, PHASE_FADE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_phase_tween.parallel().tween_property(_visual, "scale", PHASE_SCALE_PEAK, PHASE_FADE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_phase_tween.tween_callback(func() -> void:
		position = target_position
	)
	_phase_tween.tween_property(_visual, "modulate:a", 1.0, PHASE_FADE_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_phase_tween.parallel().tween_property(_visual, "scale", Vector2.ONE, PHASE_FADE_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_anchor_overlap_visibility() -> void:
	var objects_node = get_parent()
	if objects_node == null:
		return

	var level_manager = objects_node.get_parent()
	if level_manager == null or not level_manager.has_method("update_anchor_overlap_visibility"):
		return

	level_manager.update_anchor_overlap_visibility()

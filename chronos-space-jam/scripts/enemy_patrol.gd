## EnemyPatrol — Phase-based patrolling enemy
## Covers: TIME-07 (Enemy Patrol)
extends Node2D

# --- Config ---
## Patrol path as array of Vector2i offsets from origin
@export var patrol_offsets: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

# --- State ---
var grid_pos: Vector2i = Vector2i.ZERO  # original spawn position
var current_grid_pos: Vector2i = Vector2i.ZERO  # current position
var current_phase: int = 0

# --- Visual ---
var _visual_rect: ColorRect
var _inner_rect: ColorRect

const TILE_SIZE := 64

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	_visual_rect = ColorRect.new()
	_visual_rect.size = Vector2(TILE_SIZE - 8, TILE_SIZE - 8)
	_visual_rect.position = Vector2(-TILE_SIZE / 2.0 + 4, -TILE_SIZE / 2.0 + 4)
	_visual_rect.color = Color(1.0, 0.3, 0.7, 0.8)  # magenta enemy
	add_child(_visual_rect)

	_inner_rect = ColorRect.new()
	_inner_rect.size = Vector2(TILE_SIZE - 24, TILE_SIZE - 24)
	_inner_rect.position = Vector2(-TILE_SIZE / 2.0 + 12, -TILE_SIZE / 2.0 + 12)
	_inner_rect.color = Color(1.0, 0.1, 0.5, 1.0)  # bright magenta core
	add_child(_inner_rect)

func update_phase(current_tick: int) -> void:
	if patrol_offsets.is_empty():
		return
	current_phase = current_tick % patrol_offsets.size()
	var offset: Vector2i = patrol_offsets[current_phase]
	current_grid_pos = grid_pos + offset
	# Move visual to new position
	var level_manager = get_parent().get_parent()  # objects_container -> LevelManager
	if level_manager and level_manager.has_method("grid_to_world"):
		position = level_manager.grid_to_world(current_grid_pos)

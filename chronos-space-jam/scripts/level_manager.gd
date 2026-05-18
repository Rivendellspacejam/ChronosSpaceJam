extends Node2D

const TILE_SIZE: int = 48

const SYM_WALL: String = "#"
const SYM_EMPTY: String = "."
const SYM_PLAYER: String = "P"
const SYM_GOAL: String = "G"
const SYM_ANCHOR: String = "A"
const SYM_LASER: String = "L"
const SYM_SPIKE: String = "S"
const SYM_ENEMY: String = "E"
const SYM_TIME_GATE: String = "T"
const SYM_BLOCKER_H: String = "-"
const SYM_BLOCKER_V: String = "|"

const FLOOR_TEXTURE := preload("res://assets/floor_tile.png")
const WALL_TEXTURE := preload("res://assets/wall_tile.png")
const GOAL_TEXTURE := preload("res://assets/goal_tile.png")
const ANCHOR_TEXTURE := preload("res://assets/anchor_tile.png")
const TIME_GATE_SCENE := preload("res://scenes/objects/time_gate.tscn")
const LASER_SCENE := preload("res://scenes/objects/laser.tscn")
const SPIKE_SCENE := preload("res://scenes/objects/spike.tscn")
const ENEMY_SCENE := preload("res://scenes/objects/enemy_patrol.tscn")

var grid: Array = []
var grid_width: int = 0
var grid_height: int = 0
var player_start: Vector2i = Vector2i.ZERO

var _time_gates: Dictionary = {}
var _lasers: Dictionary = {}
var _spikes: Dictionary = {}
var _enemies: Dictionary = {}
var _current_slide_direction: Vector2i = Vector2i.ZERO

@onready var walls_container: Node2D = $Walls
@onready var floors_container: Node2D = $Floors
@onready var objects_container: Node2D = $Objects

class TileInfo:
	var type: String = "empty"
	var blocks: bool = false
	var kills_in_path: bool = false
	var kills_on_stop: bool = false
	var is_goal: bool = false
	var is_anchor: bool = false

func load_level(level_index: int) -> Vector2i:
	clear_level()

	var rows = GameManager.load_level_data(level_index)
	if rows.is_empty():
		push_error("Empty level data for index %d" % level_index)
		return Vector2i.ZERO

	_read_grid(rows)
	_build_visuals()
	return player_start

func clear_level() -> void:
	TickManager.clear_phase_objects()
	_time_gates.clear()
	_lasers.clear()
	_spikes.clear()
	_enemies.clear()
	grid.clear()
	_clear_children(walls_container)
	_clear_children(floors_container)
	_clear_children(objects_container)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		float(grid_pos.x * TILE_SIZE) + float(TILE_SIZE) / 2.0,
		float(grid_pos.y * TILE_SIZE) + float(TILE_SIZE) / 2.0
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / float(TILE_SIZE)), int(world_pos.y / float(TILE_SIZE)))

func set_slide_direction(direction: Vector2i) -> void:
	_current_slide_direction = direction

func get_tile_at(gpos: Vector2i) -> String:
	if _is_out_of_bounds(gpos) or gpos.y >= grid.size():
		return SYM_WALL

	var row: Array = grid[gpos.y]
	if gpos.x >= row.size():
		return SYM_WALL

	return row[gpos.x]

func is_laser_active(laser_pos: Vector2i) -> bool:
	return _lasers.has(laser_pos) and _lasers[laser_pos].is_active()

func get_laser_beam_cells(laser_pos: Vector2i) -> Array:
	var cells: Array = []
	if not is_laser_active(laser_pos):
		return cells

	var beam_dir: Vector2i = _lasers[laser_pos].get_beam_direction()
	cells.append(laser_pos)
	_collect_beam_cells(cells, laser_pos, beam_dir)
	_collect_beam_cells(cells, laser_pos, -beam_dir)
	return cells

func is_cell_hit_by_active_laser(gpos: Vector2i) -> bool:
	for laser_pos in _lasers:
		if gpos in get_laser_beam_cells(laser_pos):
			return true
	return false

func is_spike_active(spike_pos: Vector2i) -> bool:
	return _spikes.has(spike_pos) and _spikes[spike_pos].is_active()

func is_time_gate_open(gpos: Vector2i) -> bool:
	return _time_gates.has(gpos) and _time_gates[gpos].is_open()

func is_tile_blocking(gpos: Vector2i, direction: Vector2i) -> bool:
	return is_blocked(gpos, direction)

func is_static_blocked_before_tick(gpos: Vector2i, direction: Vector2i) -> bool:
	if _is_out_of_bounds(gpos):
		return true

	var symbol: String = get_tile_at(gpos)
	if symbol == SYM_WALL:
		return true
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0

	return false

func is_blocked(gpos: Vector2i, direction: Vector2i) -> bool:
	if _is_out_of_bounds(gpos):
		return true

	var symbol: String = get_tile_at(gpos)
	if symbol == SYM_WALL:
		return true
	if _time_gates.has(gpos):
		return _time_gates[gpos].is_closed()
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0

	return false

func get_slide_tile_info(gpos: Vector2i) -> TileInfo:
	var info = _base_tile_info(gpos)
	_apply_enemy_hazard(info, gpos)
	return info

func get_hazard_tile_info(gpos: Vector2i) -> TileInfo:
	var info = _base_tile_info(gpos)
	_apply_laser_beam_hazard(info, gpos)
	return info

func is_enemy_at(gpos: Vector2i) -> bool:
	for enemy_pos in _enemies:
		if _enemies[enemy_pos].current_grid_pos == gpos:
			return true
	return false

func _base_tile_info(gpos: Vector2i) -> TileInfo:
	var info = TileInfo.new()

	if _is_out_of_bounds(gpos):
		info.type = "wall"
		info.blocks = true
		return info

	_apply_base_tile_info(info, gpos, get_tile_at(gpos))
	return info

func _read_grid(rows: Array) -> void:
	grid_height = rows.size()
	grid_width = 0
	player_start = Vector2i.ZERO

	for y in range(grid_height):
		var row_str: String = rows[y]
		var row: Array = []
		grid_width = maxi(grid_width, row_str.length())

		for x in range(row_str.length()):
			var symbol: String = row_str[x]
			row.append(symbol)
			if symbol == SYM_PLAYER:
				player_start = Vector2i(x, y)

		grid.append(row)

func _apply_base_tile_info(info: TileInfo, gpos: Vector2i, symbol: String) -> void:
	match symbol:
		SYM_WALL:
			info.type = "wall"
			info.blocks = true
		SYM_GOAL:
			info.type = "goal"
			info.is_goal = true
		SYM_ANCHOR:
			info.type = "anchor"
			info.is_anchor = true
		SYM_LASER:
			info.type = "laser"
		SYM_SPIKE:
			info.type = "spike"
			info.kills_on_stop = is_spike_active(gpos)
		SYM_TIME_GATE:
			info.type = "time_gate"
			info.blocks = _time_gates.has(gpos) and _time_gates[gpos].is_closed()
		SYM_BLOCKER_H:
			info.type = "blocker_h"
			info.blocks = _current_slide_direction.x != 0
		SYM_BLOCKER_V:
			info.type = "blocker_v"
			info.blocks = _current_slide_direction.y != 0
		_:
			info.type = "empty"

func _apply_enemy_hazard(info: TileInfo, gpos: Vector2i) -> void:
	for enemy_pos in _enemies:
		if _enemies[enemy_pos].current_grid_pos == gpos:
			info.kills_in_path = true
			return

func _apply_laser_beam_hazard(info: TileInfo, gpos: Vector2i) -> void:
	if get_tile_at(gpos) != SYM_LASER and is_cell_hit_by_active_laser(gpos):
		info.kills_in_path = true

func _collect_beam_cells(cells: Array, laser_pos: Vector2i, direction: Vector2i) -> void:
	var probe = laser_pos + direction
	while not _is_solid_obstacle(probe):
		cells.append(probe)
		probe += direction

func _is_solid_obstacle(pos: Vector2i) -> bool:
	if _is_out_of_bounds(pos):
		return true

	var symbol: String = get_tile_at(pos)
	if symbol == SYM_WALL:
		return true
	if symbol == SYM_TIME_GATE and _time_gates.has(pos):
		return _time_gates[pos].is_closed()

	return false

func _is_out_of_bounds(gpos: Vector2i) -> bool:
	return gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height or gpos.x >= grid_width

func _build_visuals() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var gpos = Vector2i(x, y)
			var world_pos = grid_to_world(gpos)
			var symbol: String = get_tile_at(gpos)

			_create_sprite(FLOOR_TEXTURE, world_pos, floors_container)

			match symbol:
				SYM_WALL:
					_create_sprite(WALL_TEXTURE, world_pos, walls_container)
				SYM_GOAL:
					_create_sprite(GOAL_TEXTURE, world_pos, objects_container)
				SYM_ANCHOR:
					_create_sprite(ANCHOR_TEXTURE, world_pos, objects_container)
				SYM_TIME_GATE:
					_create_phase_object(TIME_GATE_SCENE, gpos, world_pos, _time_gates)
				SYM_LASER:
					_create_phase_object(LASER_SCENE, gpos, world_pos, _lasers)
				SYM_SPIKE:
					_create_phase_object(SPIKE_SCENE, gpos, world_pos, _spikes)
				SYM_ENEMY:
					_create_enemy(gpos, world_pos)
				SYM_BLOCKER_H:
					_create_blocker(world_pos, true)
				SYM_BLOCKER_V:
					_create_blocker(world_pos, false)

func _create_sprite(texture: Texture2D, world_pos: Vector2, parent: Node) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.position = world_pos
	parent.add_child(sprite)

func _create_blocker(world_pos: Vector2, horizontal: bool) -> void:
	var ts = float(TILE_SIZE)
	var rect = ColorRect.new()

	if horizontal:
		rect.size = Vector2(ts - 4.0, ts / 3.0)
		rect.position = world_pos - Vector2(ts / 2.0 - 2.0, ts / 6.0)
	else:
		rect.size = Vector2(ts / 3.0, ts - 4.0)
		rect.position = world_pos - Vector2(ts / 6.0, ts / 2.0 - 2.0)

	rect.color = Color(0.6, 0.4, 0.8, 0.9)
	objects_container.add_child(rect)

func _create_phase_object(scene: PackedScene, gpos: Vector2i, world_pos: Vector2, registry: Dictionary) -> Node:
	var instance = scene.instantiate()
	instance.position = world_pos
	instance.grid_pos = gpos
	objects_container.add_child(instance)
	registry[gpos] = instance
	TickManager.register_environment_object(instance)
	return instance

func _create_enemy(gpos: Vector2i, world_pos: Vector2) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.position = world_pos
	enemy.grid_pos = gpos
	enemy.current_grid_pos = gpos
	objects_container.add_child(enemy)
	_enemies[gpos] = enemy
	TickManager.register_enemy_object(enemy)

func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()

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
const SYM_COIN: String = "C"
const SYM_COIN_GATE: String = "K"
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
var _coin_nodes: Dictionary = {}
var _coin_gate_nodes: Dictionary = {}
var _collected_coins: Dictionary = {}
var _current_slide_direction: Vector2i = Vector2i.ZERO

const DEFAULT_ENEMY_PATH: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

const CUSTOM_ENEMY_PATHS: Dictionary = {
	6: {
		Vector2i(6, 3): [
			Vector2i(0, 0),
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(0, 1),
		],
	},
	8: {
		Vector2i(2, 5): [
			Vector2i(0, 0),
			Vector2i(0, -1),
			Vector2i(0, -2),
			Vector2i(0, -3),
		],
	},
	9: {
		Vector2i(8, 6): [
			Vector2i(0, 0),
			Vector2i(-1, 0),
			Vector2i(0, 0),
			Vector2i(0, -1),
		],
	},
	12: {
		Vector2i(7, 2): [
			Vector2i(0, 0),
			Vector2i(0, -1),
			Vector2i(1, -1),
			Vector2i(0, -1),
		],
	},
	16: {
		Vector2i(5, 2): [
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
			Vector2i(1, 0),
		],
	},
	20: {
		Vector2i(3, 4): [
			Vector2i(0, 0),
			Vector2i(0, -1),
			Vector2i(0, 0),
			Vector2i(1, 0),
		],
	},
	23: {
		Vector2i(6, 3): [
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, 1),
			Vector2i(0, 1),
		],
	},
	24: {
		Vector2i(6, 3): [
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, 1),
			Vector2i(0, 1),
		],
	},
}

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
	var is_coin: bool = false

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
	_coin_nodes.clear()
	_coin_gate_nodes.clear()
	_collected_coins.clear()
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

func get_coin_total() -> int:
	return _coin_nodes.size()

func get_coin_count() -> int:
	return _collected_coins.size()

func collect_coin(gpos: Vector2i) -> void:
	if not _coin_nodes.has(gpos) or _collected_coins.has(gpos):
		return

	_collected_coins[gpos] = true
	var coin_node = _coin_nodes[gpos]
	if is_instance_valid(coin_node):
		coin_node.visible = false
	_update_coin_gate_visuals()

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
	if symbol == SYM_COIN_GATE:
		return not _all_coins_collected()

	return false

func is_blocked(gpos: Vector2i, direction: Vector2i) -> bool:
	if _is_out_of_bounds(gpos):
		return true

	var symbol: String = get_tile_at(gpos)
	if symbol == SYM_WALL:
		return true
	if _time_gates.has(gpos):
		return _time_gates[gpos].is_closed()
	if symbol == SYM_COIN_GATE:
		return not _all_coins_collected()
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0

	return false

func get_slide_tile_info(gpos: Vector2i, extra_collected_coins: int = 0) -> TileInfo:
	var info = _base_tile_info(gpos, extra_collected_coins)
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

func _base_tile_info(gpos: Vector2i, extra_collected_coins: int = 0) -> TileInfo:
	var info = TileInfo.new()

	if _is_out_of_bounds(gpos):
		info.type = "wall"
		info.blocks = true
		return info

	_apply_base_tile_info(info, gpos, get_tile_at(gpos), extra_collected_coins)
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

func _apply_base_tile_info(info: TileInfo, gpos: Vector2i, symbol: String, extra_collected_coins: int = 0) -> void:
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
		SYM_COIN:
			info.type = "coin"
			info.is_coin = not _collected_coins.has(gpos)
		SYM_COIN_GATE:
			info.type = "coin_gate"
			info.blocks = not _all_coins_collected(extra_collected_coins)
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
	if symbol == SYM_COIN_GATE:
		return not _all_coins_collected()

	return false

func _all_coins_collected(extra_collected_coins: int = 0) -> bool:
	return _coin_nodes.is_empty() or _collected_coins.size() + extra_collected_coins >= _coin_nodes.size()

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
				SYM_COIN:
					_create_coin(gpos, world_pos)
				SYM_COIN_GATE:
					_create_coin_gate(gpos, world_pos)
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

func _create_coin(gpos: Vector2i, world_pos: Vector2) -> void:
	var marker = Node2D.new()
	marker.position = world_pos
	objects_container.add_child(marker)

	var glow = ColorRect.new()
	glow.size = Vector2(30.0, 30.0)
	glow.position = -Vector2(15.0, 15.0)
	glow.color = Color(1.0, 0.85, 0.2, 0.35)
	marker.add_child(glow)

	var core = ColorRect.new()
	core.size = Vector2(16.0, 16.0)
	core.position = -Vector2(8.0, 8.0)
	core.color = Color(1.0, 0.95, 0.35, 1.0)
	marker.add_child(core)
	_coin_nodes[gpos] = marker

func _create_coin_gate(gpos: Vector2i, world_pos: Vector2) -> void:
	var rect = ColorRect.new()
	rect.size = Vector2(float(TILE_SIZE) - 8.0, float(TILE_SIZE) - 8.0)
	rect.position = world_pos - Vector2(float(TILE_SIZE) / 2.0 - 4.0, float(TILE_SIZE) / 2.0 - 4.0)
	rect.color = Color(1.0, 0.72, 0.18, 0.95)
	objects_container.add_child(rect)
	_coin_gate_nodes[gpos] = rect

func _update_coin_gate_visuals() -> void:
	var open := _all_coins_collected()
	for gpos in _coin_gate_nodes:
		var gate_node = _coin_gate_nodes[gpos]
		if not is_instance_valid(gate_node):
			continue
		gate_node.color = Color(0.1, 1.0, 0.6, 0.22) if open else Color(1.0, 0.72, 0.18, 0.95)

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
	enemy.patrol_offsets = _get_enemy_patrol_offsets(gpos)
	objects_container.add_child(enemy)
	_enemies[gpos] = enemy
	TickManager.register_enemy_object(enemy)

func _get_enemy_patrol_offsets(gpos: Vector2i) -> Array[Vector2i]:
	var level_number := GameManager.current_level_index + 1
	var level_paths: Dictionary = CUSTOM_ENEMY_PATHS.get(level_number, {})
	if level_paths.has(gpos):
		var configured_path: Array[Vector2i] = []
		for offset in level_paths[gpos]:
			configured_path.append(offset)
		return configured_path

	var default_path: Array[Vector2i] = []
	for offset in DEFAULT_ENEMY_PATH:
		default_path.append(offset)
	return default_path

func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()

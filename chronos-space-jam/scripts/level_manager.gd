## LevelManager — Core level loading and tile management
## Loads level data from text files, manages grid, provides tile info for collision.
## Covers: FOUND-02, FOUND-03, FOUND-04, CORE-02, CORE-06, SPACE-06
extends Node2D

# --- Constants ---
const TILE_SIZE : int = 64  # pixels per grid cell

# --- Tile Type Symbols ---
const SYM_WALL : String = "#"
const SYM_EMPTY : String = "."
const SYM_PLAYER : String = "P"
const SYM_GOAL : String = "G"
const SYM_ANCHOR : String = "A"
const SYM_LASER : String = "L"
const SYM_SPIKE : String = "S"
const SYM_ENEMY : String = "E"
const SYM_TIME_GATE : String = "T"
const SYM_BLOCKER_H : String = "-"  # horizontal blocker (blocks left/right)
const SYM_BLOCKER_V : String = "|"  # vertical blocker (blocks up/down)

# --- Level Grid ---
var grid : Array = []  # 2D array of tile symbols
var grid_width : int = 0
var grid_height : int = 0
var player_start : Vector2i = Vector2i.ZERO

# --- Phase Objects stored by position ---
var _time_gates : Dictionary = {}  # Vector2i -> TimeGate node
var _lasers : Dictionary = {}      # Vector2i -> Laser node
var _spikes : Dictionary = {}      # Vector2i -> Spike node
var _enemies : Dictionary = {}     # Vector2i -> Enemy node (also tracks current_pos)

# --- Slide direction context for blocker checks ---
var _current_slide_direction : Vector2i = Vector2i.ZERO

# --- Object container nodes ---
@onready var walls_container = $Walls
@onready var floors_container = $Floors
@onready var objects_container = $Objects

# --- Tile Info Result ---
class TileInfo:
	var type : String = "empty"
	var blocks : bool = false
	var kills : bool = false
	var is_goal : bool = false
	var is_anchor : bool = false

func _ready() -> void:
	pass

# --- Grid ↔ World Conversion (FOUND-02) ---
func grid_to_world(grid_pos : Vector2i) -> Vector2:
	return Vector2(
		float(grid_pos.x * TILE_SIZE) + float(TILE_SIZE) / 2.0,
		float(grid_pos.y * TILE_SIZE) + float(TILE_SIZE) / 2.0
	)

func world_to_grid(world_pos : Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / float(TILE_SIZE)), int(world_pos.y / float(TILE_SIZE)))

# --- Level Loading (FOUND-03) ---
func load_level(level_index : int) -> Vector2i:
	clear_level()
	var rows = GameManager.load_level_data(level_index)
	if rows.is_empty():
		push_error("Empty level data for index %d" % level_index)
		return Vector2i.ZERO

	grid_height = rows.size()
	grid_width = 0
	grid = []

	for y in range(grid_height):
		var row_str : String = rows[y]
		var row : Array = []
		if row_str.length() > grid_width:
			grid_width = row_str.length()
		for x in range(row_str.length()):
			var symbol : String = row_str[x]
			row.append(symbol)
			if symbol == SYM_PLAYER:
				player_start = Vector2i(x, y)
		grid.append(row)

	# Build visual representation
	_build_visuals()
	return player_start

func clear_level() -> void:
	TickManager.clear_phase_objects()
	_time_gates.clear()
	_lasers.clear()
	_spikes.clear()
	_enemies.clear()
	# Safely remove children
	if walls_container:
		for child in walls_container.get_children():
			child.queue_free()
	if floors_container:
		for child in floors_container.get_children():
			child.queue_free()
	if objects_container:
		for child in objects_container.get_children():
			child.queue_free()
	grid.clear()

# --- Set slide direction context for blocker checks ---
func set_slide_direction(dir : Vector2i) -> void:
	_current_slide_direction = dir

# --- Tile Query (CORE-06, SPACE-06) ---
func get_tile_at(gpos : Vector2i) -> String:
	if gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height:
		return SYM_WALL  # out of bounds = wall
	if gpos.y >= grid.size():
		return SYM_WALL
	var row : Array = grid[gpos.y]
	if gpos.x >= row.size():
		return SYM_WALL
	return row[gpos.x]

func is_blocked(gpos : Vector2i, direction : Vector2i) -> bool:
	# Out of bounds
	if gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height or gpos.x >= grid_width:
		return true
	var symbol : String = get_tile_at(gpos)
	# Wall always blocks
	if symbol == SYM_WALL:
		return true
	# Time Gate — check if closed
	if _time_gates.has(gpos):
		return _time_gates[gpos].is_closed()
	# Horizontal blocker blocks left/right movement
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	# Vertical blocker blocks up/down movement
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0
	return false

func get_tile_info(gpos : Vector2i) -> TileInfo:
	var info = TileInfo.new()
	var symbol : String = get_tile_at(gpos)

	# Out of bounds
	if gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height or gpos.x >= grid_width:
		info.type = "wall"
		info.blocks = true
		return info

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
			if _lasers.has(gpos):
				info.kills = _lasers[gpos].is_active()
		SYM_SPIKE:
			info.type = "spike"
			if _spikes.has(gpos):
				info.kills = _spikes[gpos].is_active()
		SYM_TIME_GATE:
			info.type = "time_gate"
			if _time_gates.has(gpos):
				info.blocks = _time_gates[gpos].is_closed()
		SYM_BLOCKER_H:
			info.type = "blocker_h"
			# Block left/right movement during slide
			if _current_slide_direction.x != 0:
				info.blocks = true
		SYM_BLOCKER_V:
			info.type = "blocker_v"
			# Block up/down movement during slide
			if _current_slide_direction.y != 0:
				info.blocks = true
		_:
			info.type = "empty"

	# Check for enemy at this position
	for epos in _enemies:
		var enemy = _enemies[epos]
		if enemy.current_grid_pos == gpos:
			info.kills = true
			break

	return info

# --- Visual Building (FOUND-04) ---
func _build_visuals() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var gpos = Vector2i(x, y)
			var symbol : String = grid[y][x]
			var world_pos = grid_to_world(gpos)

			# Always draw floor
			_create_floor_tile(world_pos)

			match symbol:
				SYM_WALL:
					_create_wall_tile(world_pos)
				SYM_GOAL:
					_create_goal_tile(world_pos)
				SYM_ANCHOR:
					_create_anchor_tile(world_pos)
				SYM_TIME_GATE:
					_create_time_gate(gpos, world_pos)
				SYM_LASER:
					_create_laser(gpos, world_pos)
				SYM_SPIKE:
					_create_spike(gpos, world_pos)
				SYM_ENEMY:
					_create_enemy(gpos, world_pos)
				SYM_BLOCKER_H:
					_create_blocker_tile(world_pos, true)
				SYM_BLOCKER_V:
					_create_blocker_tile(world_pos, false)

# --- Tile Creation Functions ---
func _create_floor_tile(world_pos : Vector2) -> void:
	var rect = ColorRect.new()
	var ts = float(TILE_SIZE)
	rect.size = Vector2(ts - 2.0, ts - 2.0)
	rect.position = world_pos - Vector2(ts / 2.0 - 1.0, ts / 2.0 - 1.0)
	rect.color = Color(0.08, 0.08, 0.14, 1.0)  # dark floor
	floors_container.add_child(rect)

func _create_wall_tile(world_pos : Vector2) -> void:
	var ts = float(TILE_SIZE)
	var rect = ColorRect.new()
	rect.size = Vector2(ts, ts)
	rect.position = world_pos - Vector2(ts / 2.0, ts / 2.0)
	rect.color = Color(0.18, 0.18, 0.25, 1.0)  # dark wall
	walls_container.add_child(rect)

	# Wall border highlight
	var border = ColorRect.new()
	border.size = Vector2(ts - 4.0, ts - 4.0)
	border.position = world_pos - Vector2(ts / 2.0 - 2.0, ts / 2.0 - 2.0)
	border.color = Color(0.25, 0.25, 0.35, 1.0)
	walls_container.add_child(border)

func _create_goal_tile(world_pos : Vector2) -> void:
	var ts = float(TILE_SIZE)
	var rect = ColorRect.new()
	rect.size = Vector2(ts - 4.0, ts - 4.0)
	rect.position = world_pos - Vector2(ts / 2.0 - 2.0, ts / 2.0 - 2.0)
	rect.color = Color(0.1, 0.9, 0.6, 0.8)  # green/cyan glow
	objects_container.add_child(rect)

func _create_anchor_tile(world_pos : Vector2) -> void:
	var ts = float(TILE_SIZE)
	var rect = ColorRect.new()
	rect.size = Vector2(ts - 8.0, ts - 8.0)
	rect.position = world_pos - Vector2(ts / 2.0 - 4.0, ts / 2.0 - 4.0)
	rect.color = Color(0.2, 0.5, 1.0, 0.7)  # blue anchor
	objects_container.add_child(rect)

	# Inner circle indicator
	var inner = ColorRect.new()
	inner.size = Vector2(ts - 24.0, ts - 24.0)
	inner.position = world_pos - Vector2(ts / 2.0 - 12.0, ts / 2.0 - 12.0)
	inner.color = Color(0.3, 0.6, 1.0, 0.9)
	objects_container.add_child(inner)

func _create_blocker_tile(world_pos : Vector2, horizontal : bool) -> void:
	var ts = float(TILE_SIZE)
	var rect = ColorRect.new()
	if horizontal:
		rect.size = Vector2(ts - 4.0, ts / 3.0)
		rect.position = world_pos - Vector2(ts / 2.0 - 2.0, ts / 6.0)
	else:
		rect.size = Vector2(ts / 3.0, ts - 4.0)
		rect.position = world_pos - Vector2(ts / 6.0, ts / 2.0 - 2.0)
	rect.color = Color(0.6, 0.4, 0.8, 0.9)  # purple blocker
	objects_container.add_child(rect)

# --- Phase Object Creation ---
func _create_time_gate(gpos : Vector2i, world_pos : Vector2) -> void:
	var gate = preload("res://scenes/objects/time_gate.tscn").instantiate()
	gate.position = world_pos
	gate.grid_pos = gpos
	objects_container.add_child(gate)
	_time_gates[gpos] = gate
	TickManager.register_phase_object(gate)

func _create_laser(gpos : Vector2i, world_pos : Vector2) -> void:
	var laser = preload("res://scenes/objects/laser.tscn").instantiate()
	laser.position = world_pos
	laser.grid_pos = gpos
	objects_container.add_child(laser)
	_lasers[gpos] = laser
	TickManager.register_phase_object(laser)

func _create_spike(gpos : Vector2i, world_pos : Vector2) -> void:
	var spike = preload("res://scenes/objects/spike.tscn").instantiate()
	spike.position = world_pos
	spike.grid_pos = gpos
	objects_container.add_child(spike)
	_spikes[gpos] = spike
	TickManager.register_phase_object(spike)

func _create_enemy(gpos : Vector2i, world_pos : Vector2) -> void:
	var enemy = preload("res://scenes/objects/enemy_patrol.tscn").instantiate()
	enemy.position = world_pos
	enemy.grid_pos = gpos
	enemy.current_grid_pos = gpos
	objects_container.add_child(enemy)
	_enemies[gpos] = enemy
	TickManager.register_phase_object(enemy)

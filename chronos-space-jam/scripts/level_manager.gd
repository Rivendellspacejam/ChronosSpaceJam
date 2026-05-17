## LevelManager — Core level loading and tile management
## Loads level data from text files, manages grid, provides tile info for collision.
## Covers: FOUND-02, FOUND-03, FOUND-04, CORE-02, CORE-06, SPACE-06
extends Node2D

# --- Constants ---
const TILE_SIZE : int = 48  # pixels per grid cell

# --- Tile Type Symbols ---
const SYM_WALL : String = "#"
# Solid obstacle. Blocks player movement and acts as the main arena boundary.

const SYM_EMPTY : String = "."
# Walkable/slidable floor tile. Player can pass through this tile while sliding.

const SYM_PLAYER : String = "P"
# Player start position. Used to spawn the player when the level begins or restarts.

const SYM_GOAL : String = "G"
# Goal tile. Level is cleared when the player reaches this tile.

const SYM_ANCHOR : String = "A"
# Stop tile. Player immediately stops on this tile when sliding over it.

const SYM_LASER : String = "L"
# LINE HAZARD. Fires a beam along a row or column when active.
# → Does NOT block movement.
# → Does NOT kill by standing on the laser tile itself.
# → Kills the player if the slide PATH crosses an ACTIVE beam cell.
# → Safe to cross when inactive.

const SYM_SPIKE : String = "S"
# STOP-POSITION HAZARD. Cycles: Safe → Warning → Active.
# → Does NOT block movement.
# → Does NOT kill during the slide path (player can slide over it freely).
# → Only kills if the player's FINAL STOP POSITION is on an ACTIVE spike.

const SYM_ENEMY : String = "E"
# Time-based enemy tile. Kills the player and may move/change position each tick.

const SYM_TIME_GATE : String = "T"
# TIMED BLOCKER. Never a hazard — never kills the player.
# → When CLOSED: acts exactly like a wall. Player stops before it.
# → When OPEN:   acts like empty floor. Player passes through freely.

const SYM_BLOCKER_H : String = "-"
# Horizontal gravity blocker. Blocks left/right sliding movement, but allows vertical movement.

const SYM_BLOCKER_V : String = "|"
# Vertical gravity blocker. Blocks up/down sliding movement, but allows horizontal movement.

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

# ---------------------------------------------------------------------------
# TileInfo — returned by get_tile_info()
#
# Field summary:
#   blocks        → slide stops BEFORE this tile (wall, closed gate, blocker)
#   kills_in_path → player dies immediately upon entering this cell mid-slide
#                   (active laser BEAM cell — line hazard)
#   kills_on_stop → player dies if this is the FINAL stop position
#                   (active spike — stop-position hazard)
#   is_goal       → level cleared on reaching this cell
#   is_anchor     → slide stops ON this tile
# ---------------------------------------------------------------------------
class TileInfo:
	var type : String = "empty"
	var blocks : bool = false         # hard blocker (wall / closed gate / blocker)
	var kills_in_path : bool = false  # LASER: active beam crossing → die mid-slide
	var kills_on_stop : bool = false  # SPIKE: active spike at final stop → die after slide
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

# ---------------------------------------------------------------------------
# LASER HELPERS
# ---------------------------------------------------------------------------

# Returns true when a laser at laser_pos is currently active.
func is_laser_active(laser_pos : Vector2i) -> bool:
	if _lasers.has(laser_pos):
		return _lasers[laser_pos].is_active()
	return false

# Returns all grid cells hit by the beam of an active laser at laser_pos.
# The beam fires in both directions along the laser's axis until it hits a
# solid obstacle (wall or closed time gate). The laser tile itself is included.
#
# TODO: If future levels need per-laser direction metadata encoded in the level
#       file (e.g. "LH" / "LV"), parse it in load_level() and store it here.
func get_laser_beam_cells(laser_pos : Vector2i) -> Array:
	var cells : Array = []
	if not _lasers.has(laser_pos):
		return cells

	var laser = _lasers[laser_pos]
	if not laser.is_active():
		return cells   # inactive — beam covers no cells

	var beam_dir : Vector2i = laser.get_beam_direction()
	# Include the laser origin tile itself
	cells.append(laser_pos)

	# Shoot in +dir until blocked
	var probe = laser_pos + beam_dir
	while not _is_solid_obstacle(probe):
		cells.append(probe)
		probe = probe + beam_dir

	# Shoot in -dir until blocked
	probe = laser_pos - beam_dir
	while not _is_solid_obstacle(probe):
		cells.append(probe)
		probe = probe - beam_dir

	return cells

# Returns true if cell at pos is a solid obstacle that stops a laser beam.
# Walls and closed time gates stop beams. Spikes, anchors, etc. do NOT.
func _is_solid_obstacle(pos : Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.y >= grid_height or pos.x >= grid_width:
		return true   # out of bounds counts as wall
	var sym : String = get_tile_at(pos)
	if sym == SYM_WALL:
		return true
	if sym == SYM_TIME_GATE and _time_gates.has(pos):
		return _time_gates[pos].is_closed()
	return false

# Returns true if gpos is currently hit by any active laser beam.
func is_cell_hit_by_active_laser(gpos : Vector2i) -> bool:
	for laser_pos in _lasers:
		var laser = _lasers[laser_pos]
		if not laser.is_active():
			continue
		var beam_cells : Array = get_laser_beam_cells(laser_pos)
		if gpos in beam_cells:
			return true
	return false

# ---------------------------------------------------------------------------
# SPIKE HELPER
# ---------------------------------------------------------------------------

# Returns true when the spike at spike_pos is in ACTIVE phase.
# Used after slide ends to check final stop position.
func is_spike_active(spike_pos : Vector2i) -> bool:
	if _spikes.has(spike_pos):
		return _spikes[spike_pos].is_active()
	return false

# ---------------------------------------------------------------------------
# TIME GATE HELPER
# ---------------------------------------------------------------------------

# Returns true when the time gate at gpos is currently open (passable).
func is_time_gate_open(gpos : Vector2i) -> bool:
	if _time_gates.has(gpos):
		return _time_gates[gpos].is_open()
	return false  # if no gate node, treat as not open

# Returns true if the tile at gpos blocks movement in the given direction.
# Checks walls, closed time gates, and directional blockers.
# Laser and Spike are NEVER blockers.
func is_tile_blocking(gpos : Vector2i, direction : Vector2i) -> bool:
	return is_blocked(gpos, direction)

# Returns true only for blockers that cannot change during the upcoming tick.
# Used by player.gd BEFORE TickManager.advance_tick().
#
# Time Gates are intentionally excluded here because the intended order is:
# Input -> Tick++ -> Phase Update -> Player Slide. A gate that is closed now
# may open after the tick advances, so checking it before the tick creates a
# stale collision bug.
func is_static_blocked_before_tick(gpos : Vector2i, direction : Vector2i) -> bool:
	# Out of bounds cannot change with time.
	if gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height or gpos.x >= grid_width:
		return true

	var symbol : String = get_tile_at(gpos)

	# Walls cannot change with time.
	if symbol == SYM_WALL:
		return true

	# Directional blockers are static space blockers.
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0

	# Time Gates, lasers, spikes, enemies, anchors, goals, and floor are not
	# rejected before ticking. Their current state is evaluated after phase update
	# inside get_tile_info() during slide path construction.
	return false

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

# Returns true if the tile at gpos stops the player's slide (hard blocker).
# Laser and Spike are intentionally NOT blockers — they are hazards only.
# Time Gate blocks only when CLOSED.
func is_blocked(gpos : Vector2i, direction : Vector2i) -> bool:
	# Out of bounds
	if gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height or gpos.x >= grid_width:
		return true
	var symbol : String = get_tile_at(gpos)
	# Wall always blocks
	if symbol == SYM_WALL:
		return true
	# Time Gate — blocks only when CLOSED (never kills)
	if _time_gates.has(gpos):
		return _time_gates[gpos].is_closed()
	# Horizontal blocker blocks left/right movement
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	# Vertical blocker blocks up/down movement
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0
	# Laser: NOT a blocker. Handled as a beam hazard (kills_in_path).
	# Spike: NOT a blocker. Handled as a stop-position hazard (kills_on_stop).
	return false

# ---------------------------------------------------------------------------
# get_tile_info — unified query used by player.gd during slide path building.
#
# Collision rule summary:
#   During slide (checked each tile before entering):
#     blocks=true       → stop BEFORE tile (wall / closed gate / blocker)
#   During slide (checked after entering tile):
#     kills_in_path=true → die immediately (active laser beam)
#     is_goal=true       → level clear
#     is_anchor=true     → stop here
#   After slide ends:
#     kills_on_stop=true → die (active spike at final stop position)
# ---------------------------------------------------------------------------
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
			# LASER = line hazard tile (the emitter).
			# The tile itself does NOT block movement.
			# Beam hazard is evaluated via is_cell_hit_by_active_laser().
			info.type = "laser"
			# No blocks, no kills_on_stop — laser is handled per-cell in slide loop.

		SYM_SPIKE:
			# SPIKE = stop-position hazard.
			# Does NOT block movement. Does NOT kill during slide path traversal.
			# kills_on_stop is set so player.gd checks it AFTER the slide ends.
			info.type = "spike"
			if _spikes.has(gpos):
				info.kills_on_stop = _spikes[gpos].is_active()

		SYM_TIME_GATE:
			# TIME GATE = timed blocker. Never a hazard. Never kills.
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

	# Check for enemy at this position (mid-slide kill)
	for epos in _enemies:
		var enemy = _enemies[epos]
		if enemy.current_grid_pos == gpos:
			info.kills_in_path = true
			break

	# Check active laser beam hitting this cell (mid-slide kill).
	# NOTE: We only check beam for non-laser tiles. The laser emitter tile
	#       itself is handled above (it does not block or kill by itself).
	if symbol != SYM_LASER and is_cell_hit_by_active_laser(gpos):
		info.kills_in_path = true

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
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/floor_tile.png")
	sprite.position = world_pos
	floors_container.add_child(sprite)

func _create_wall_tile(world_pos : Vector2) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/wall_tile.png")
	sprite.position = world_pos
	walls_container.add_child(sprite)

func _create_goal_tile(world_pos : Vector2) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/goal_tile.png")
	sprite.position = world_pos
	objects_container.add_child(sprite)

func _create_anchor_tile(world_pos : Vector2) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/anchor_tile.png")
	sprite.position = world_pos
	objects_container.add_child(sprite)

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
	# TODO: If level metadata specifies a beam axis per laser (e.g. "LH"/"LV"),
	#       set laser.beam_axis here. For now, all lasers default to horizontal (0).
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

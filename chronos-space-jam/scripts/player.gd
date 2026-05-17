## Player — Main player controller
## Handles gravity-based sliding movement, collision scanning, death, and level clear.
## Covers: CORE-01, CORE-02, CORE-05, CORE-06, FOUND-05
##
## Tile collision rule (see also LevelManager.get_tile_info):
##
##   During slide — checked per-cell BEFORE entering:
##     tile_info.blocks       → stop BEFORE this tile (wall/closed gate/blocker)
##   During slide — checked per-cell AFTER entering:
##     tile_info.kills_in_path → die immediately (active laser BEAM crossing)
##     tile_info.is_goal      → level clear
##     tile_info.is_anchor    → stop here
##   After slide ends — checked at final stop position:
##     tile_info.kills_on_stop → die (active spike at stop position)
extends Node2D

# --- Signals ---
signal slide_started(direction : Vector2i)
signal slide_finished(final_pos : Vector2i)
signal player_died_signal()
signal player_reached_goal()

# --- Constants ---
const SLIDE_SPEED : float = 600.0  # pixels per second during slide animation

# --- State ---
enum PlayerState { IDLE, SLIDING, DEAD, LEVEL_CLEAR }
var state : int = PlayerState.IDLE
var grid_pos : Vector2i = Vector2i.ZERO
var gravity_direction : Vector2i = Vector2i.ZERO  # current gravity direction

# --- References ---
var level_manager = null  # set by GameLevel

# --- Slide animation ---
var _slide_path : Array = []  # tiles to traverse (Array of Vector2i)
var _slide_index : int = 0
var _slide_from : Vector2 = Vector2.ZERO  # world pos start
var _slide_to : Vector2 = Vector2.ZERO    # world pos target
var _slide_progress : float = 0.0
var _slide_stopped_by : String = ""  # what stopped the slide
var _slide_direction : Vector2i = Vector2i.ZERO  # direction of current slide

func _ready() -> void:
	pass

func init_player(start_grid_pos : Vector2i, lvl_manager) -> void:
	grid_pos = start_grid_pos
	level_manager = lvl_manager
	state = PlayerState.IDLE
	gravity_direction = Vector2i.ZERO
	position = level_manager.grid_to_world(grid_pos)
	visible = true

func _unhandled_input(event : InputEvent) -> void:
	if state != PlayerState.IDLE:
		return
	if not GameManager.can_accept_input():
		return

	var direction = Vector2i.ZERO
	if event.is_action_pressed("move_up"):
		direction = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):
		direction = Vector2i(0, 1)
	elif event.is_action_pressed("move_left"):
		direction = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		direction = Vector2i(1, 0)
	elif event.is_action_pressed("restart"):
		GameManager.restart_level()
		return

	if direction == Vector2i.ZERO:
		return

	# Pre-tick validation may only reject STATIC blockers.
	# Do NOT check closed Time Gates here: gates are allowed to change phase after
	# TickManager.advance_tick(), before the slide path is built.
	# This fixes the bug where a gate that should open on the next tick still blocks
	# because the player checked collision against the previous tick state.
	var next_pos = grid_pos + direction
	if level_manager.is_static_blocked_before_tick(next_pos, direction):
		# Input into an immediate wall / out-of-bounds / directional blocker is ignored,
		# so the player cannot use a wall bump as a free wait action.
		return

	# Valid input: ORDER = Input → Tick++ → Phase Update → Player Slide (GDD §7.2.4)
	gravity_direction = direction
	TickManager.advance_tick()
	_start_slide(direction)

func _start_slide(direction : Vector2i) -> void:
	state = PlayerState.SLIDING
	GameManager.set_state(GameManager.GameState.SLIDING)
	AudioManager.play_slide_start()
	slide_started.emit(direction)
	_slide_direction = direction

	# Set direction context on level manager for directional blocker checks
	level_manager.set_slide_direction(direction)

	# --- Build slide path ---
	# Scan tiles one-by-one from current position in direction.
	#
	# Stop conditions (in order):
	#   1. BEFORE tile: tile_info.blocks (wall / closed gate / directional blocker)
	#   2. ON tile:     tile_info.kills_in_path (active laser beam cell) → die
	#   3. ON tile:     tile_info.is_goal                                 → clear
	#   4. ON tile:     tile_info.is_anchor                               → stop
	#   5. Otherwise:   continue sliding
	#
	# NOTE: Spike (kills_on_stop) does NOT stop the slide here.
	#       The player slides OVER spikes freely.
	#       The spike kill-check happens in _finish_slide() after the path ends.
	_slide_path.clear()
	var check_pos = grid_pos + direction
	_slide_stopped_by = ""

	while true:
		var tile_info = level_manager.get_tile_info(check_pos)

		# 1. Hard blocker → stop BEFORE this tile, do not enter it
		if tile_info.blocks:
			_slide_stopped_by = tile_info.type
			break

		# Enter the tile — add it to path
		_slide_path.append(check_pos)

		# 2. Active laser beam crossing → die here (line hazard, checked mid-slide)
		if tile_info.kills_in_path:
			_slide_stopped_by = "laser_beam"
			break

		# 3. Goal → level clear here
		if tile_info.is_goal:
			_slide_stopped_by = "goal"
			break

		# 4. Anchor tile → stop on it
		if tile_info.is_anchor:
			_slide_stopped_by = "anchor"
			break

		# 5. Continue sliding (empty, spike-pass-through, open gate, etc.)
		check_pos = check_pos + direction

	if _slide_path.is_empty():
		# Shouldn't happen since we pre-checked the first tile, but safety valve
		_finish_slide()
		return

	# Start animating the slide
	_slide_index = 0
	_begin_slide_segment()

func _begin_slide_segment() -> void:
	_slide_from = position
	_slide_to = level_manager.grid_to_world(_slide_path[_slide_index])
	_slide_progress = 0.0

func _process(delta : float) -> void:
	if state != PlayerState.SLIDING:
		return

	var distance = _slide_from.distance_to(_slide_to)
	if distance < 0.1:
		# Already at target
		_arrive_at_tile()
		return

	_slide_progress += (SLIDE_SPEED * delta) / distance
	if _slide_progress > 1.0:
		_slide_progress = 1.0
	position = _slide_from.lerp(_slide_to, _slide_progress)

	if _slide_progress >= 1.0:
		_arrive_at_tile()

func _arrive_at_tile() -> void:
	var arrived_pos : Vector2i = _slide_path[_slide_index]
	grid_pos = arrived_pos
	position = level_manager.grid_to_world(grid_pos)

	var tile_info = level_manager.get_tile_info(arrived_pos)

	# Mid-slide death check: active laser beam (kills_in_path)
	if tile_info.kills_in_path:
		_die()
		return

	# Goal check
	if tile_info.is_goal:
		_reach_goal()
		return

	# Anchor check — stop here
	if tile_info.is_anchor:
		_finish_slide()
		return

	# Advance to next tile in path
	_slide_index += 1
	if _slide_index >= _slide_path.size():
		# Reached the end of the slide path → run post-slide checks
		_finish_slide()
		return

	_begin_slide_segment()

func _finish_slide() -> void:
	# --- Post-slide check: active spike at final stop position ---
	# Spike is a STOP-POSITION hazard. It does not kill during the slide.
	# Only check it here, after the full slide has ended.
	var final_info = level_manager.get_tile_info(grid_pos)
	if final_info.kills_on_stop:
		_die()
		return

	state = PlayerState.IDLE
	GameManager.set_state(GameManager.GameState.PLAYING)
	slide_finished.emit(grid_pos)

func _die() -> void:
	state = PlayerState.DEAD
	GameManager.on_player_died()
	player_died_signal.emit()

func _reach_goal() -> void:
	state = PlayerState.LEVEL_CLEAR
	GameManager.on_level_cleared(TickManager.move_count)
	player_reached_goal.emit()

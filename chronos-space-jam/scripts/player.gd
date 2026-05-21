extends Node2D

signal slide_started(direction: Vector2i)
signal slide_finished(final_pos: Vector2i)
signal player_died_signal()
signal player_reached_goal()

const SLIDE_SPEED: float = 600.0

enum PlayerState { IDLE, SLIDING, DEAD, LEVEL_CLEAR }

var state: int = PlayerState.IDLE
var grid_pos: Vector2i = Vector2i.ZERO
var gravity_direction: Vector2i = Vector2i.ZERO
var level_manager = null

var _slide_path: Array = []
var _slide_index: int = 0
var _slide_from: Vector2 = Vector2.ZERO
var _slide_to: Vector2 = Vector2.ZERO
var _slide_progress: float = 0.0
var _glow_phase: float = 0.0
var _move_tick_committed: bool = false

var input_buffer_window = 0.15
var buffered_direction: Vector2i = Vector2i.ZERO
var buffer_timer: float = 0.0

@onready var _visual: Sprite2D = $PlayerVisual
@onready var _glow: ColorRect = $PlayerGlow

func init_player(start_grid_pos: Vector2i, lvl_manager) -> void:
	grid_pos = start_grid_pos
	level_manager = lvl_manager
	state = PlayerState.IDLE
	gravity_direction = Vector2i.ZERO
	position = level_manager.grid_to_world(grid_pos)
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state in [
		GameManager.GameState.DEAD,
		GameManager.GameState.LEVEL_CLEAR,
		GameManager.GameState.PAUSED,
		GameManager.GameState.STORY,
	]:
		return

	if event.is_action_pressed("restart"):
		GameManager.restart_level()
		return

	var direction = _input_to_direction(event)
	if direction == Vector2i.ZERO:
		return
	if state != PlayerState.IDLE:
		buffered_direction = direction
		buffer_timer = input_buffer_window
		return

	_start_slide(direction)

func _process(delta: float) -> void:
	_update_visual_pulse(delta)
	
	if buffer_timer > 0.0:
		buffer_timer -= delta
	
		if buffer_timer <= 0.0:
			buffered_direction = Vector2i.ZERO
	
	if state != PlayerState.SLIDING:
		return

	var distance = _slide_from.distance_to(_slide_to)
	if distance < 0.1:
		_arrive_at_tile()
		return

	_slide_progress = minf(_slide_progress + (SLIDE_SPEED * delta) / distance, 1.0)
	position = _slide_from.lerp(_slide_to, _slide_progress)

	if _slide_progress >= 1.0:
		_arrive_at_tile()

func _input_to_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if event.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	if event.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if event.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO

func _is_blocked_before_tick(direction: Vector2i) -> bool:
	return level_manager.is_static_blocked_before_tick(grid_pos + direction, direction)

func _start_slide(direction: Vector2i) -> void:
	level_manager.set_slide_direction(direction)

	var first_step := grid_pos + direction
	if level_manager.is_static_blocked_before_tick(first_step, direction):
		level_manager.set_slide_direction(Vector2i.ZERO)
		AudioManager.play_blocked_move()
		return

	var move_tick := TickManager.current_tick + 1
	_slide_path = _build_slide_path(direction, move_tick)

	# Invalid inputs that do not move the player should not advance time.
	# This prevents walls, blockers, or closed time gates from becoming a wait button.
	if _slide_path.is_empty():
		level_manager.set_slide_direction(Vector2i.ZERO)
		AudioManager.play_blocked_move()
		return

	gravity_direction = direction
	_move_tick_committed = false
	_commit_move_tick()
	state = PlayerState.SLIDING
	GameManager.set_state(GameManager.GameState.SLIDING)
	AudioManager.play_slide_start()
	slide_started.emit(direction)

	_slide_index = 0
	_begin_slide_segment()

func _build_slide_path(direction: Vector2i, hazard_tick: int) -> Array:
	var path: Array = []
	var check_pos = grid_pos + direction
	var extra_collected_coins := 0

	while true:
		var tile_info = level_manager.get_slide_tile_info_for_tick(check_pos, direction, hazard_tick, extra_collected_coins)

		if tile_info.blocks:
			break

		path.append(check_pos)
		if tile_info.is_coin:
			extra_collected_coins += 1

		if tile_info.kills_in_path or tile_info.is_goal or tile_info.is_anchor:
			break

		if tile_info.is_bounce:
			var bounce_destination: Vector2i = level_manager.get_bounce_destination(check_pos, direction)
			var fallback_destination: Vector2i = path[path.size() - 2] if path.size() >= 2 else grid_pos
			if not level_manager.is_valid_bounce_destination(bounce_destination, direction, hazard_tick):
				bounce_destination = fallback_destination
			path.append(bounce_destination)
			break

		check_pos += direction

	return path

func _begin_slide_segment() -> void:
	_slide_from = position
	_slide_to = level_manager.grid_to_world(_slide_path[_slide_index])
	_slide_progress = 0.0
	var target_info = level_manager.get_slide_tile_info(_slide_path[_slide_index])
	if target_info.is_bounce:
		level_manager.play_bounce_impact(_slide_path[_slide_index], gravity_direction)
	_drop_trail()

func _arrive_at_tile() -> void:
	grid_pos = _slide_path[_slide_index]
	position = level_manager.grid_to_world(grid_pos)

	var tile_info = level_manager.get_slide_tile_info(grid_pos)
	if tile_info.is_coin:
		level_manager.collect_coin(grid_pos)
	if _is_killed_by_active_laser():
		_die()
		return
	if tile_info.is_goal:
		AudioManager.play_goal_enter()
		_reach_goal()
		return
	if _is_killed_by_enemy():
		_die()
		return
	if tile_info.is_anchor:
		level_manager.play_anchor_capture(grid_pos, gravity_direction)
		AudioManager.play_anchor_stop()
		_finish_slide()
		return
	if tile_info.is_bounce:
		AudioManager.play_bounce_pad()

	_slide_index += 1
	if _slide_index >= _slide_path.size():
		_finish_slide()
		return

	_begin_slide_segment()

func _finish_slide() -> void:
	if _is_killed_by_enemy():
		level_manager.set_slide_direction(Vector2i.ZERO)
		_die()
		return

	_commit_move_tick()
	level_manager.set_slide_direction(Vector2i.ZERO)

	if _is_killed_by_hazard():
		_die()
		return

	state = PlayerState.IDLE
	GameManager.set_state(GameManager.GameState.PLAYING)
	slide_finished.emit(grid_pos)
	if buffered_direction != Vector2i.ZERO:
		var dir = buffered_direction
		buffered_direction = Vector2i.ZERO
		buffer_timer = 0.0
		_start_slide(dir)

func _commit_move_tick() -> void:
	if _move_tick_committed:
		return

	_move_tick_committed = true
	TickManager.advance_tick()

func _is_killed_by_enemy() -> bool:
	return level_manager.is_enemy_at(grid_pos)

func _is_killed_by_active_laser() -> bool:
	return level_manager.is_active_laser_beam_at(grid_pos)

func _is_killed_by_hazard() -> bool:
	var info = level_manager.get_hazard_tile_info(grid_pos)
	return info.kills_on_stop or info.kills_in_path

func _die() -> void:
	if level_manager != null:
		level_manager.set_slide_direction(Vector2i.ZERO)
	state = PlayerState.DEAD
	GameManager.on_player_died()
	player_died_signal.emit()

func _reach_goal() -> void:
	_commit_move_tick()
	level_manager.set_slide_direction(Vector2i.ZERO)
	level_manager.play_goal_collect_tween()
	state = PlayerState.LEVEL_CLEAR
	GameManager.on_level_cleared(TickManager.move_count)
	player_reached_goal.emit()

func _update_visual_pulse(delta: float) -> void:
	if _glow == null or _visual == null:
		return

	_glow_phase += delta * (6.0 if state == PlayerState.SLIDING else 2.4)
	var pulse := (sin(_glow_phase) + 1.0) * 0.5
	var glow_modulate := _glow.modulate
	glow_modulate.a = lerpf(0.45, 0.95, pulse)
	_glow.modulate = glow_modulate
	_visual.modulate = Color(0.85, 1.0, 1.0, 1.0) if state == PlayerState.SLIDING else Color.WHITE
	var shader_material := _visual.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("slide_boost", 1.0 if state == PlayerState.SLIDING else 0.0)

func _drop_trail() -> void:
	if level_manager == null:
		return

	var trail := ColorRect.new()
	trail.size = Vector2(34.0, 34.0)
	trail.position = position - Vector2(17.0, 17.0)
	trail.color = Color(0.2, 0.9, 1.0, 0.22)
	level_manager.add_child(trail)

	var tween := create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.22)
	tween.tween_callback(trail.queue_free)

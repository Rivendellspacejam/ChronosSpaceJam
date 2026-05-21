extends Node

signal tick_advanced(current_tick: int)
signal phase_update_requested(current_tick: int)

var current_tick: int = 0
var move_count: int = 0
var _display_tick_start: int = 0
var _environment_objects: Array = []
var _enemy_objects: Array = []

func reset(start_tick: int = 0) -> void:
	# Allow initializing the tick counter to a custom start (e.g. -1)
	current_tick = start_tick
	_display_tick_start = start_tick
	move_count = 0

func get_display_tick() -> int:
	return current_tick - _display_tick_start

func prepare_enemies_for_move() -> void:
	_update_enemies(current_tick + 1)

func sync_enemies_to_current_tick() -> void:
	_update_enemies(current_tick)

func advance_tick() -> void:
	current_tick += 1
	move_count += 1
	_update_environment_objects()
	_update_enemies(current_tick)
	phase_update_requested.emit(current_tick)
	tick_advanced.emit(current_tick)

func restore_tick_state(tick: int, moves: int) -> void:
	current_tick = tick
	move_count = moves
	_update_environment_objects()
	_update_enemies(current_tick)
	phase_update_requested.emit(current_tick)
	tick_advanced.emit(current_tick)

func register_environment_object(obj: Node) -> void:
	if obj not in _environment_objects:
		_environment_objects.append(obj)

func register_enemy_object(obj: Node) -> void:
	if obj not in _enemy_objects:
		_enemy_objects.append(obj)

func unregister_phase_object(obj: Node) -> void:
	_environment_objects.erase(obj)
	_enemy_objects.erase(obj)

func clear_phase_objects() -> void:
	_environment_objects.clear()
	_enemy_objects.clear()

func get_phase(phase_count: int) -> int:
	if phase_count <= 0:
		return 0
	return phase_for_tick(current_tick, phase_count)

func phase_for_tick(tick: int, count: int) -> int:
	# Normalize phase so it's always in [0, count-1], even for negative ticks
	if count <= 0:
		return 0
	var p := tick % count
	if p < 0:
		p += count
	return p

func _update_environment_objects() -> void:
	for obj in _environment_objects:
		if is_instance_valid(obj) and obj.has_method("update_phase"):
			obj.update_phase(current_tick)

func _update_enemies(tick: int) -> void:
	for obj in _enemy_objects:
		if is_instance_valid(obj) and obj.has_method("update_phase"):
			obj.update_phase(tick)

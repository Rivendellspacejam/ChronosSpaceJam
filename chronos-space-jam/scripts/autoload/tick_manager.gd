extends Node

signal tick_advanced(current_tick: int)
signal phase_update_requested(current_tick: int)

var current_tick: int = 0
var move_count: int = 0
var _phase_objects: Array = []

func reset() -> void:
	current_tick = 0
	move_count = 0

func advance_tick() -> void:
	current_tick += 1
	move_count += 1
	_update_all_phase_objects()
	phase_update_requested.emit(current_tick)
	tick_advanced.emit(current_tick)

func register_phase_object(obj: Node) -> void:
	if obj not in _phase_objects:
		_phase_objects.append(obj)

func unregister_phase_object(obj: Node) -> void:
	_phase_objects.erase(obj)

func clear_phase_objects() -> void:
	_phase_objects.clear()

func get_phase(phase_count: int) -> int:
	if phase_count <= 0:
		return 0
	return current_tick % phase_count

func _update_all_phase_objects() -> void:
	for obj in _phase_objects:
		if is_instance_valid(obj) and obj.has_method("update_phase"):
			obj.update_phase(current_tick)

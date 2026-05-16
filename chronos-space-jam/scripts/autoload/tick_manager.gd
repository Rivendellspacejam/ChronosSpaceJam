## TickManager — Autoload singleton
## Global tick counter. Every player input advances tick by 1.
## Covers: TIME-01 (Global Tick Manager), TIME-02 (Tick Update Order), TIME-09 (No-Wait Rule)
extends Node

# --- Signals ---
signal tick_advanced(current_tick: int)
signal phase_update_requested(current_tick: int)

# --- State ---
var current_tick: int = 0
var move_count: int = 0

# --- Registered phase objects ---
var _phase_objects: Array = []

func _ready() -> void:
	pass

# --- Tick Logic ---
func reset() -> void:
	"""Reset tick and move count for new level / restart."""
	current_tick = 0
	move_count = 0

func advance_tick() -> void:
	"""
	Called when player makes a valid directional input.
	Order: Input → Tick++ → Phase Update → Player Slide
	(GDD §7.2.4 Recommended Order)
	"""
	current_tick += 1
	move_count += 1
	tick_advanced.emit(current_tick)
	# Update all registered phase-based objects
	_update_all_phase_objects()
	phase_update_requested.emit(current_tick)

func _update_all_phase_objects() -> void:
	"""Notify all phase objects to update their phase."""
	for obj in _phase_objects:
		if is_instance_valid(obj) and obj.has_method("update_phase"):
			obj.update_phase(current_tick)

# --- Phase Object Registration ---
func register_phase_object(obj: Node) -> void:
	"""Register a time-based object (gate, laser, spike, enemy) for tick updates."""
	if obj not in _phase_objects:
		_phase_objects.append(obj)

func unregister_phase_object(obj: Node) -> void:
	"""Unregister a phase object."""
	_phase_objects.erase(obj)

func clear_phase_objects() -> void:
	"""Clear all registered phase objects (on level reload)."""
	_phase_objects.clear()

func get_phase(phase_count: int) -> int:
	"""Utility: Get current phase for an object with given phase_count."""
	if phase_count <= 0:
		return 0
	return current_tick % phase_count

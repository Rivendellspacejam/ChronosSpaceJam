## TickManager — Autoload singleton
## Global tick counter. Every player input advances tick by 1.
## Covers: TIME-01 (Global Tick Manager), TIME-02 (Tick Update Order), TIME-09 (No-Wait Rule)
extends Node

# --- Signals ---
signal tick_advanced(current_tick : int)
signal phase_update_requested(current_tick : int)

# --- State ---
var current_tick : int = 0
var move_count : int = 0

# --- Registered phase objects ---
var _phase_objects : Array = []

func _ready() -> void:
	pass

# --- Tick Logic ---
func reset() -> void:
	# Reset tick and move count for new level / restart.
	current_tick = 0
	move_count = 0

func advance_tick() -> void:
	# Called when player makes a valid directional input.
	# Correct order: Input -> Tick++ -> Phase Update -> Player Slide.
	#
	# IMPORTANT:
	# Phase objects must update BEFORE tick_advanced is emitted.
	# Otherwise listeners can start player movement while gates/traps are still
	# using the previous tick state, causing visual-open gates to still block.
	current_tick += 1
	move_count += 1

	# Update all registered phase-based objects first.
	_update_all_phase_objects()

	# Optional signal for any object that chooses signal-based phase updates.
	# Emit before tick_advanced so world phase is finalized before UI/player reactions.
	phase_update_requested.emit(current_tick)

	# Emit last. UI/SFX and other listeners now observe the finalized tick state.
	tick_advanced.emit(current_tick)

func _update_all_phase_objects() -> void:
	for obj in _phase_objects:
		if is_instance_valid(obj) and obj.has_method("update_phase"):
			obj.update_phase(current_tick)

# --- Phase Object Registration ---
func register_phase_object(obj : Node) -> void:
	if obj not in _phase_objects:
		_phase_objects.append(obj)

func unregister_phase_object(obj : Node) -> void:
	_phase_objects.erase(obj)

func clear_phase_objects() -> void:
	_phase_objects.clear()

func get_phase(phase_count : int) -> int:
	if phase_count <= 0:
		return 0
	return current_tick % phase_count

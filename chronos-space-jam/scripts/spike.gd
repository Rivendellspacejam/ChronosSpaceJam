## Spike — 3-phase trap: Safe, Warning, Active
## Covers: TIME-06 (Spike Trap)
extends Node2D

# --- Config ---
@export var phase_count : int = 3

# --- State ---
enum SpikePhase { SAFE, WARNING, ACTIVE }
var grid_pos : Vector2i = Vector2i.ZERO
var current_phase : int = 0
var spike_state : int = SpikePhase.SAFE

# --- Visual ---
var _visual_rect : ColorRect = null
var _inner_rect : ColorRect = null

const TILE_SIZE : int = 64

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	var ts = float(TILE_SIZE)
	_visual_rect = ColorRect.new()
	_visual_rect.size = Vector2(ts - 4.0, ts - 4.0)
	_visual_rect.position = Vector2(-ts / 2.0 + 2.0, -ts / 2.0 + 2.0)
	add_child(_visual_rect)

	_inner_rect = ColorRect.new()
	_inner_rect.size = Vector2(ts - 20.0, ts - 20.0)
	_inner_rect.position = Vector2(-ts / 2.0 + 10.0, -ts / 2.0 + 10.0)
	add_child(_inner_rect)

func update_phase(current_tick : int) -> void:
	current_phase = current_tick % phase_count
	match current_phase:
		0:
			spike_state = SpikePhase.SAFE
		1:
			spike_state = SpikePhase.WARNING
		2:
			spike_state = SpikePhase.ACTIVE
		_:
			spike_state = SpikePhase.SAFE
	_update_visual()

func is_active() -> bool:
	return spike_state == SpikePhase.ACTIVE

func _update_visual() -> void:
	if _visual_rect == null or _inner_rect == null:
		return
	if spike_state == SpikePhase.SAFE:
		_visual_rect.color = Color(0.15, 0.15, 0.2, 0.3)
		_inner_rect.color = Color(0.2, 0.2, 0.3, 0.2)
	elif spike_state == SpikePhase.WARNING:
		# Yellow flash warning
		_visual_rect.color = Color(1.0, 0.85, 0.1, 0.6)
		_inner_rect.color = Color(1.0, 0.9, 0.2, 0.8)
	elif spike_state == SpikePhase.ACTIVE:
		# Red active, deadly
		_visual_rect.color = Color(1.0, 0.15, 0.15, 0.8)
		_inner_rect.color = Color(1.0, 0.1, 0.1, 1.0)

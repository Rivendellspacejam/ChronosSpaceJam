## Spike — 3-phase trap: Safe, Warning, Active
## Covers: TIME-06 (Spike Trap)
extends Node2D

# --- Config ---
@export var phase_count: int = 3

# --- State ---
enum SpikePhase { SAFE, WARNING, ACTIVE }
var grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var spike_state: SpikePhase = SpikePhase.SAFE

# --- Visual ---
var _visual_rect: ColorRect
var _inner_rect: ColorRect

const TILE_SIZE := 64

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	_visual_rect = ColorRect.new()
	_visual_rect.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
	_visual_rect.position = Vector2(-TILE_SIZE / 2.0 + 2, -TILE_SIZE / 2.0 + 2)
	add_child(_visual_rect)

	_inner_rect = ColorRect.new()
	_inner_rect.size = Vector2(TILE_SIZE - 20, TILE_SIZE - 20)
	_inner_rect.position = Vector2(-TILE_SIZE / 2.0 + 10, -TILE_SIZE / 2.0 + 10)
	add_child(_inner_rect)

func update_phase(current_tick: int) -> void:
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
	match spike_state:
		SpikePhase.SAFE:
			_visual_rect.color = Color(0.15, 0.15, 0.2, 0.3)
			_inner_rect.color = Color(0.2, 0.2, 0.3, 0.2)
		SpikePhase.WARNING:
			# Yellow flash warning
			_visual_rect.color = Color(1.0, 0.85, 0.1, 0.6)
			_inner_rect.color = Color(1.0, 0.9, 0.2, 0.8)
		SpikePhase.ACTIVE:
			# Red active, deadly
			_visual_rect.color = Color(1.0, 0.15, 0.15, 0.8)
			_inner_rect.color = Color(1.0, 0.1, 0.1, 1.0)

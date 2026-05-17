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
var _sprite : Sprite2D = null

const TILE_SIZE : int = 48

func _ready() -> void:
	_build_visual()
	update_phase(0)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/spike_tile.png")
	add_child(_sprite)

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
	if _sprite == null:
		return
	if spike_state == SpikePhase.SAFE:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
	elif spike_state == SpikePhase.WARNING:
		# Yellow flash warning
		_sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)
	elif spike_state == SpikePhase.ACTIVE:
		# Full bright
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

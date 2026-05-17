## Spike — Stop-position hazard. 3-phase cycle: Safe → Warning → Active.
## IMPORTANT: Spike does NOT block or kill during the slide path.
## It ONLY kills the player if the player's FINAL STOP POSITION is on an ACTIVE spike.
## Pass-through during slide. Check kill only after slide ends.
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

# Returns true only when the spike is in ACTIVE phase.
# Used by level_manager to set kills_on_stop (checked after slide, not during).
func is_active() -> bool:
	return spike_state == SpikePhase.ACTIVE

func _update_visual() -> void:
	if _sprite == null:
		return
	match spike_state:
		SpikePhase.SAFE:
			# Safe: dim / retracted
			_sprite.modulate = Color(0.6, 0.6, 0.6, 0.35)
		SpikePhase.WARNING:
			# Warning: yellow flash — dangerous soon but not yet lethal
			_sprite.modulate = Color(1.0, 0.85, 0.1, 1.0)
		SpikePhase.ACTIVE:
			# Active: full red — will kill on stop
			_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)

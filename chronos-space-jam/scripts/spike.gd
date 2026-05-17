extends Node2D

@export var phase_count: int = 3

enum SpikePhase { SAFE, WARNING, ACTIVE }

var grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var spike_state: int = SpikePhase.SAFE
var _sprite: Sprite2D = null

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/spike_tile.png")
	add_child(_sprite)
	update_phase(0)

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
	if _sprite == null:
		return

	match spike_state:
		SpikePhase.SAFE:
			_sprite.modulate = Color(0.6, 0.6, 0.6, 0.35)
		SpikePhase.WARNING:
			_sprite.modulate = Color(1.0, 0.85, 0.1, 1.0)
		SpikePhase.ACTIVE:
			_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)

extends Node2D

@export var phase_count: int = 2
@export var open_pattern: Array[bool] = [false, true]

var grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var _is_open: bool = false
var _sprite: Sprite2D = null

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/time_gate_tile.png")
	add_child(_sprite)
	update_phase(0)

func update_phase(current_tick: int) -> void:
	if phase_count <= 0:
		phase_count = open_pattern.size()

	current_phase = current_tick % phase_count
	_is_open = current_phase < open_pattern.size() and open_pattern[current_phase]
	_update_visual()

func is_closed() -> bool:
	return not _is_open

func is_open() -> bool:
	return _is_open

func get_state_for_tick(tick: int) -> Dictionary:
	var count := phase_count if phase_count > 0 else open_pattern.size()
	var phase := tick % count
	var open_at_tick := phase < open_pattern.size() and open_pattern[phase]
	return {"is_open": open_at_tick}

func play_phase_pulse() -> void:
	if _sprite == null:
		return
	var base := _sprite.modulate
	var peak := base.lightened(0.35)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", peak, 0.12)
	tween.tween_property(_sprite, "modulate", base, 0.13)

func _update_visual() -> void:
	if _sprite == null:
		return

	if _is_open:
		_sprite.modulate = Color(0.4, 1.0, 0.6, 0.25)
	else:
		_sprite.modulate = Color(0.4, 0.8, 1.0, 1.0)

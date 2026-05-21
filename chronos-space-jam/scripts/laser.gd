extends Node2D

const TILE_SIZE: int = 48
const LASER_BEAM_THICKNESS: float = 8.0
const LASER_CHARGE_TIME: float = 0.12
const LASER_RELEASE_TIME: float = 0.1
const LASER_FADE_TIME: float = 0.16
const LASER_ACTIVE_COLOR := Color(1.0, 0.16, 0.2, 0.78)
const LASER_INACTIVE_COLOR := Color(0.45, 0.16, 0.18, 0.45)
const LASER_CORE_ACTIVE_COLOR := Color(1.0, 0.24, 0.22, 1.0)
const LASER_CORE_INACTIVE_COLOR := Color(0.42, 0.18, 0.2, 0.72)

@export var phase_count: int = 2
@export var active_pattern: Array[bool] = [false, true]
@export_enum("Horizontal:0", "Vertical:1") var beam_axis: int = 0

var grid_pos: Vector2i = Vector2i.ZERO
var current_phase: int = 0
var _is_active_state: bool = false
var _visual_ready: bool = false
var _sprite: Sprite2D = null
var _beam_overlay: ColorRect = null
var _emitter_visual: Node2D = null
var _emitter_core: ColorRect = null
var _laser_tween: Tween = null

func _ready() -> void:
	_build_visual()
	update_phase(0)

func update_phase(current_tick: int) -> void:
	if phase_count <= 0:
		phase_count = active_pattern.size()
	var was_active := _is_active_state
	current_phase = TickManager.phase_for_tick(current_tick, phase_count)
	_is_active_state = current_phase < active_pattern.size() and active_pattern[current_phase]
	_update_visual(was_active)

func is_active() -> bool:
	return _is_active_state

func get_state_for_tick(tick: int) -> Dictionary:
	var count := phase_count if phase_count > 0 else active_pattern.size()
	var phase := TickManager.phase_for_tick(tick, count)
	var active_at_tick := phase < active_pattern.size() and active_pattern[phase]
	return {"is_active": active_at_tick}

func play_phase_pulse() -> void:
	if _sprite == null:
		return
	var base := _sprite.modulate
	var peak := base.lightened(0.35)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", peak, 0.12)
	tween.tween_property(_sprite, "modulate", base, 0.13)

func get_beam_direction() -> Vector2i:
	if beam_axis == 0:
		return Vector2i(1, 0)
	return Vector2i(0, 1)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/laser_tile.png")
	add_child(_sprite)
	_build_emitter_visual()

	_beam_overlay = ColorRect.new()
	_beam_overlay.color = LASER_ACTIVE_COLOR
	_beam_overlay.visible = false
	_beam_overlay.z_index = 1
	add_child(_beam_overlay)

func _build_emitter_visual() -> void:
	_emitter_visual = Node2D.new()
	_emitter_visual.z_index = 2
	add_child(_emitter_visual)

	var base := _make_emitter_rect(Vector2(30.0, 18.0), Color(0.06, 0.025, 0.03, 0.92), Vector2.ZERO)
	_emitter_visual.add_child(base)

	var left_barrel := _make_emitter_rect(Vector2(22.0, 7.0), Color(0.18, 0.04, 0.05, 0.94), Vector2(-17.0, 0.0))
	var right_barrel := _make_emitter_rect(Vector2(22.0, 7.0), Color(0.18, 0.04, 0.05, 0.94), Vector2(17.0, 0.0))
	var left_tip := _make_emitter_rect(Vector2(5.0, 15.0), Color(0.6, 0.06, 0.09, 0.95), Vector2(-28.0, 0.0))
	var right_tip := _make_emitter_rect(Vector2(5.0, 15.0), Color(0.6, 0.06, 0.09, 0.95), Vector2(28.0, 0.0))
	_emitter_visual.add_child(left_barrel)
	_emitter_visual.add_child(right_barrel)
	_emitter_visual.add_child(left_tip)
	_emitter_visual.add_child(right_tip)

	_emitter_core = _make_emitter_rect(Vector2(13.0, 13.0), LASER_CORE_INACTIVE_COLOR, Vector2.ZERO)
	_emitter_visual.add_child(_emitter_core)
	_emitter_visual.rotation = PI * 0.5 if beam_axis == 1 else 0.0

func _make_emitter_rect(size: Vector2, color: Color, center_offset: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.position = center_offset - (size * 0.5)
	rect.color = color
	return rect

func _update_visual(was_active: bool) -> void:
	if _sprite == null:
		return

	if _is_active_state:
		_fit_beam_to_active_cells()
		if _visual_ready and not was_active:
			_animate_laser_activation()
		else:
			_set_laser_active_visual()
	elif _visual_ready and was_active:
		_animate_laser_deactivation()
	else:
		_set_laser_inactive_visual()
	_visual_ready = true

func _set_laser_active_visual() -> void:
	_kill_laser_tween()
	_sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
	_beam_overlay.visible = true
	_beam_overlay.color = LASER_ACTIVE_COLOR
	_beam_overlay.modulate = Color.WHITE
	_emitter_visual.scale = Vector2.ONE
	_emitter_visual.modulate = Color.WHITE
	if _emitter_core != null:
		_emitter_core.color = LASER_CORE_ACTIVE_COLOR

func _set_laser_inactive_visual() -> void:
	_kill_laser_tween()
	_sprite.modulate = Color(0.5, 0.3, 0.3, 0.4)
	_beam_overlay.visible = false
	_beam_overlay.modulate = Color.WHITE
	_emitter_visual.scale = Vector2.ONE
	_emitter_visual.modulate = Color(0.72, 0.5, 0.55, 0.78)
	if _emitter_core != null:
		_emitter_core.color = LASER_CORE_INACTIVE_COLOR

func _animate_laser_activation() -> void:
	_kill_laser_tween()
	_sprite.modulate = Color(1.0, 0.3, 0.32, 1.0)
	_beam_overlay.visible = true
	_beam_overlay.color = LASER_ACTIVE_COLOR
	_beam_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_emitter_visual.scale = Vector2(0.82, 0.82)
	_emitter_visual.modulate = Color(1.0, 0.36, 0.38, 1.0)
	if _emitter_core != null:
		_emitter_core.color = LASER_CORE_ACTIVE_COLOR

	_laser_tween = create_tween()
	_laser_tween.tween_property(_emitter_visual, "scale", Vector2(1.18, 1.18), LASER_CHARGE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_laser_tween.parallel().tween_property(_emitter_visual, "modulate", Color.WHITE, LASER_CHARGE_TIME)
	_laser_tween.tween_property(_beam_overlay, "modulate:a", 1.0, LASER_RELEASE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_laser_tween.parallel().tween_property(_emitter_visual, "scale", Vector2.ONE, LASER_RELEASE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_laser_deactivation() -> void:
	_kill_laser_tween()
	_sprite.modulate = Color(0.5, 0.3, 0.3, 0.4)
	_beam_overlay.visible = true
	_beam_overlay.modulate = Color.WHITE
	_emitter_visual.modulate = Color(0.72, 0.5, 0.55, 0.78)
	if _emitter_core != null:
		_emitter_core.color = LASER_CORE_INACTIVE_COLOR

	_laser_tween = create_tween()
	_laser_tween.tween_property(_beam_overlay, "modulate:a", 0.0, LASER_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_laser_tween.parallel().tween_property(_emitter_visual, "scale", Vector2(0.92, 0.92), LASER_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_laser_tween.tween_callback(func() -> void:
		_beam_overlay.visible = false
		_beam_overlay.modulate = Color.WHITE
		_emitter_visual.scale = Vector2.ONE
	)

func _kill_laser_tween() -> void:
	if _laser_tween != null:
		_laser_tween.kill()
		_laser_tween = null

func _fit_beam_to_active_cells() -> void:
	var level_manager = _get_level_manager()
	if level_manager == null or not level_manager.has_method("get_laser_beam_cells"):
		_fit_beam_to_single_tile()
		return

	var cells: Array = level_manager.get_laser_beam_cells(grid_pos)
	if cells.is_empty():
		_fit_beam_to_single_tile()
		return

	var min_x := grid_pos.x
	var max_x := grid_pos.x
	var min_y := grid_pos.y
	var max_y := grid_pos.y

	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	if beam_axis == 0:
		_beam_overlay.size = Vector2(float(max_x - min_x + 1) * TILE_SIZE, LASER_BEAM_THICKNESS)
		_beam_overlay.position = Vector2(float(min_x - grid_pos.x) * TILE_SIZE - TILE_SIZE / 2.0, -LASER_BEAM_THICKNESS / 2.0)
	else:
		_beam_overlay.size = Vector2(LASER_BEAM_THICKNESS, float(max_y - min_y + 1) * TILE_SIZE)
		_beam_overlay.position = Vector2(-LASER_BEAM_THICKNESS / 2.0, float(min_y - grid_pos.y) * TILE_SIZE - TILE_SIZE / 2.0)

func _fit_beam_to_single_tile() -> void:
	if beam_axis == 0:
		_beam_overlay.size = Vector2(TILE_SIZE, LASER_BEAM_THICKNESS)
		_beam_overlay.position = Vector2(-TILE_SIZE / 2.0, -LASER_BEAM_THICKNESS / 2.0)
	else:
		_beam_overlay.size = Vector2(LASER_BEAM_THICKNESS, TILE_SIZE)
		_beam_overlay.position = Vector2(-LASER_BEAM_THICKNESS / 2.0, -TILE_SIZE / 2.0)

func _get_level_manager() -> Node:
	var objects_node = get_parent()
	if objects_node == null:
		return null
	return objects_node.get_parent()

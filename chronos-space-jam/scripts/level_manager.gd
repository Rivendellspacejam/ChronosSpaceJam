extends Node2D

const TILE_SIZE: int = 48

const SYM_WALL: String = "#"
const SYM_EMPTY: String = "."
const SYM_PLAYER: String = "P"
const SYM_GOAL: String = "G"
const SYM_ANCHOR: String = "A"
const SYM_LASER: String = "L"
const SYM_SPIKE: String = "S"
const SYM_ENEMY: String = "E"
const SYM_TIME_GATE: String = "T"
const SYM_COIN: String = "C"
const SYM_COIN_GATE: String = "K"
const SYM_BOUNCE: String = "O"
const SYM_BLOCKER_H: String = "-"
const SYM_BLOCKER_V: String = "|"

const FLOOR_TEXTURE := preload("res://assets/floor_tile.png")
const WALL_TEXTURE := preload("res://assets/wall_tile-new.png")
const GOAL_TEXTURE := preload("res://assets/goal_tile-new.png")
const GOAL_PORTAL_SHADER := preload("res://assets/shaders/goal_portal_pulse.gdshader")
const ANCHOR_TEXTURE := preload("res://assets/anchor_tile.png")
const ANCHOR_CAPTURE_SHADER := preload("res://assets/shaders/anchor_capture_pulse.gdshader")
const COIN_TEXTURE := preload("res://assets/coin.png")
const BOUNCE_TEXTURE := preload("res://assets/bounce.png")
const HORIZONTAL_BLOCKER_TEXTURE := preload("res://assets/horizontal_blocker.png")
const VERTICAL_BLOCKER_TEXTURE := preload("res://assets/vertical_blocker.png")
const ENEMY_TEXTURE := preload("res://assets/enemy-new.png")
const BOUNCE_IMPACT_SHADER := preload("res://assets/shaders/bounce_tile_impact.gdshader")
const TIME_GATE_SCENE := preload("res://scenes/objects/time_gate.tscn")
const LASER_SCENE := preload("res://scenes/objects/laser.tscn")
const SPIKE_SCENE := preload("res://scenes/objects/spike.tscn")
const ENEMY_SCENE := preload("res://scenes/objects/enemy_patrol.tscn")

const TIME_GATE_TEXTURE := preload("res://assets/time_gate_tile.png")
const COIN_GATE_CLOSED_TEXTURE := preload("res://assets/gate_closed.png")
const COIN_GATE_OPEN_TEXTURE := preload("res://assets/gate_opened.png")
const LASER_TEXTURE := preload("res://assets/laser_tile.png")
const SPIKE_TEXTURE := preload("res://assets/spike_tile.png")
const ENEMY_OBJECT_Z_INDEX: int = 2
const ANCHOR_OCCUPIED_ALPHA: float = 0.42
const ANCHOR_NORMAL_ALPHA: float = 1.0
const ANCHOR_CAPTURE_TIME: float = 0.28

var grid: Array = []
var grid_width: int = 0
var grid_height: int = 0
var player_start: Vector2i = Vector2i.ZERO

var _time_gates: Dictionary = {}
var _lasers: Dictionary = {}
var _spikes: Dictionary = {}
var _enemies: Dictionary = {}
var _anchor_nodes: Dictionary = {}
var _coin_nodes: Dictionary = {}
var _coin_gate_nodes: Dictionary = {}
var _bounce_nodes: Dictionary = {}
var _bounce_base_positions: Dictionary = {}
var _bounce_impact_tweens: Dictionary = {}
var _anchor_capture_tweens: Dictionary = {}
var _collected_coins: Dictionary = {}
var _enemy_patrol_paths: Array = []
var _enemy_path_assign_index: int = 0
var _current_slide_direction: Vector2i = Vector2i.ZERO
var _preview_key_was_held: bool = false
var _phase_goal_period: int = 0
var _phase_goal_active_phases: Array[int] = []
var _goal_grid_pos: Vector2i = Vector2i(-1, -1)

@onready var walls_container: Node2D = $Walls
@onready var floors_container: Node2D = $Floors
@onready var future_preview_layer: Node2D = $FuturePreviewLayer
@onready var future_preview_effect: ColorRect = $FuturePreviewEffect
@onready var objects_container: Node2D = $Objects
@onready var hud: CanvasLayer = $"../HUD"

var _goal_node: Sprite2D = null

func _ready() -> void:
	TickManager.tick_advanced.connect(_on_tick_advanced_refresh_previews)
	GameManager.state_changed.connect(_on_game_state_changed_refresh_previews)
	SettingsManager.move_previews_changed.connect(_on_move_previews_setting_changed)
	set_process(true)

func _process(_delta: float) -> void:
	var held := _is_preview_key_held()
	if held == _preview_key_was_held:
		return
	_preview_key_was_held = held
	if held:
		refresh_all_move_previews()
	else:
		_clear_all_previews()

class TileInfo:
	var type: String = "empty"
	var blocks: bool = false
	var kills_in_path: bool = false
	var kills_on_stop: bool = false
	var is_goal: bool = false
	var is_anchor: bool = false
	var is_coin: bool = false
	var is_bounce: bool = false

func load_level(level_index: int) -> Vector2i:
	clear_level()

	var level_bundle = GameManager.load_level_bundle(level_index)
	var rows: Array = level_bundle.get("rows", [])
	if rows.is_empty():
		push_error("Empty level data for index %d" % level_index)
		return Vector2i.ZERO

	_enemy_patrol_paths = level_bundle.get("enemy_paths", [])
	_enemy_path_assign_index = 0
	_configure_phase_goal(level_bundle.get("phase_goal", {}))
	_read_grid(rows)
	_build_visuals()
	_update_goal_visual_for_tick(TickManager.current_tick)
	update_anchor_overlap_visibility()
	_configure_future_preview_effect()
	refresh_all_move_previews()
	return player_start

func clear_level() -> void:
	_preview_key_was_held = false
	TickManager.clear_phase_objects()
	_time_gates.clear()
	_lasers.clear()
	_spikes.clear()
	_enemies.clear()
	_anchor_nodes.clear()
	_coin_nodes.clear()
	_coin_gate_nodes.clear()
	_clear_bounce_impacts()
	_clear_anchor_capture_tweens()
	_bounce_nodes.clear()
	_bounce_base_positions.clear()
	_collected_coins.clear()
	_enemy_patrol_paths.clear()
	_enemy_path_assign_index = 0
	_phase_goal_period = 0
	_phase_goal_active_phases.clear()
	_goal_grid_pos = Vector2i(-1, -1)
	_goal_node = null
	grid.clear()
	_clear_children(walls_container)
	_clear_children(floors_container)
	_clear_all_previews()
	_clear_children(objects_container)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		float(grid_pos.x * TILE_SIZE) + float(TILE_SIZE) / 2.0,
		float(grid_pos.y * TILE_SIZE) + float(TILE_SIZE) / 2.0
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / float(TILE_SIZE)), int(world_pos.y / float(TILE_SIZE)))

func set_slide_direction(direction: Vector2i) -> void:
	_current_slide_direction = direction

func capture_undo_state() -> Dictionary:
	return {
		"collected_coins": _collected_coins.duplicate(),
		"slide_direction": _current_slide_direction,
	}

func restore_undo_state(snapshot: Dictionary) -> void:
	_current_slide_direction = snapshot.get("slide_direction", Vector2i.ZERO)
	_collected_coins.clear()
	var collected_snapshot: Dictionary = snapshot.get("collected_coins", {})
	for coin_pos in collected_snapshot:
		_collected_coins[coin_pos] = collected_snapshot[coin_pos]

	_restore_coin_visuals()
	_update_coin_gate_visuals()
	_clear_bounce_impacts()
	_clear_anchor_capture_tweens()
	_clear_all_previews()
	_update_goal_visual_for_tick(TickManager.current_tick)
	update_anchor_overlap_visibility()

func _restore_coin_visuals() -> void:
	for gpos in _coin_nodes:
		var coin_node := _coin_nodes[gpos] as Sprite2D
		if is_instance_valid(coin_node):
			coin_node.visible = not _collected_coins.has(gpos)

func get_tile_at(gpos: Vector2i) -> String:
	if _is_out_of_bounds(gpos) or gpos.y >= grid.size():
		return SYM_WALL

	var row: Array = grid[gpos.y]
	if gpos.x >= row.size():
		return SYM_WALL

	return row[gpos.x]

func is_laser_active(laser_pos: Vector2i) -> bool:
	return _lasers.has(laser_pos) and _lasers[laser_pos].is_active()

func is_laser_active_at_tick(laser_pos: Vector2i, tick: int) -> bool:
	if not _lasers.has(laser_pos):
		return false

	var laser = _lasers[laser_pos]
	if laser.has_method("get_state_for_tick"):
		return laser.get_state_for_tick(tick).get("is_active", laser.is_active())
	return laser.is_active()

func get_laser_beam_cells(laser_pos: Vector2i) -> Array:
	return get_laser_beam_cells_for_tick(laser_pos, TickManager.current_tick)

func get_laser_beam_cells_for_tick(laser_pos: Vector2i, tick: int) -> Array:
	var cells: Array = []
	if not is_laser_active_at_tick(laser_pos, tick):
		return cells

	var beam_dir: Vector2i = _lasers[laser_pos].get_beam_direction()
	cells.append(laser_pos)
	_collect_beam_cells_for_tick(cells, laser_pos, beam_dir, tick)
	_collect_beam_cells_for_tick(cells, laser_pos, -beam_dir, tick)
	return cells

func is_active_laser_beam_at(gpos: Vector2i) -> bool:
	return is_active_laser_beam_at_for_tick(gpos, TickManager.current_tick)

func is_active_laser_beam_at_for_tick(gpos: Vector2i, tick: int) -> bool:
	for laser_pos in _lasers:
		if gpos in get_laser_beam_cells_for_tick(laser_pos, tick):
			return true
	return false

func is_cell_hit_by_active_laser(gpos: Vector2i) -> bool:
	return is_active_laser_beam_at(gpos)

func is_spike_active(spike_pos: Vector2i) -> bool:
	return _spikes.has(spike_pos) and _spikes[spike_pos].is_active()

func is_time_gate_open(gpos: Vector2i) -> bool:
	return _time_gates.has(gpos) and _time_gates[gpos].is_open()

func is_time_gate_open_at_tick(gpos: Vector2i, tick: int) -> bool:
	if not _time_gates.has(gpos):
		return false

	var gate = _time_gates[gpos]
	if gate.has_method("get_state_for_tick"):
		return gate.get_state_for_tick(tick).get("is_open", gate.is_open())
	return gate.is_open()

func get_coin_total() -> int:
	return _coin_nodes.size()

func get_coin_count() -> int:
	return _collected_coins.size()

func is_phase_goal_configured() -> bool:
	return _phase_goal_period > 0 and not _phase_goal_active_phases.is_empty()

func is_goal_active_at_tick(tick: int) -> bool:
	if not is_phase_goal_configured():
		return true

	var phase := TickManager.phase_for_tick(tick, _phase_goal_period)
	return phase in _phase_goal_active_phases

func get_bounce_destination(bounce_pos: Vector2i, direction: Vector2i) -> Vector2i:
	return bounce_pos - (direction * 2)

func is_valid_bounce_destination(gpos: Vector2i, direction: Vector2i, tick: int) -> bool:
	return not is_blocked_for_tick(gpos, direction, tick)

func play_bounce_impact(bounce_pos: Vector2i, incoming_direction: Vector2i) -> void:
	var sprite := _bounce_nodes.get(bounce_pos) as Sprite2D
	if sprite == null:
		return

	var base_position: Vector2 = _bounce_base_positions.get(bounce_pos, grid_to_world(bounce_pos))
	var material := sprite.material as ShaderMaterial
	if material == null:
		return

	if _bounce_impact_tweens.has(bounce_pos):
		var existing_tween := _bounce_impact_tweens[bounce_pos] as Tween
		if existing_tween != null:
			existing_tween.kill()

	var compression := 0.50
	var offset := float(TILE_SIZE) * (1.0 - compression) * 0.5
	sprite.position = base_position + Vector2(float(incoming_direction.x), float(incoming_direction.y)) * offset
	sprite.scale = Vector2(
		compression if incoming_direction.x != 0 else 1.0,
		compression if incoming_direction.y != 0 else 1.0
	)

	material.set_shader_parameter(
		"impact_direction",
		Vector2(float(incoming_direction.x), float(incoming_direction.y))
	)
	material.set_shader_parameter("impact_amount", 1.0)

	var tween := create_tween()
	_bounce_impact_tweens[bounce_pos] = tween
	tween.set_parallel(true)
	tween.tween_property(material, "shader_parameter/impact_amount", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", base_position, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _bounce_impact_tweens.get(bounce_pos) == tween:
			_bounce_impact_tweens.erase(bounce_pos)
	)

func collect_coin(gpos: Vector2i) -> void:
	if not _coin_nodes.has(gpos) or _collected_coins.has(gpos):
		return

	_collected_coins[gpos] = true
	var coin_node = _coin_nodes[gpos]
	if is_instance_valid(coin_node):
		coin_node.visible = false
	AudioManager.play_coin_pickup()
	_update_coin_gate_visuals()
	if _all_coins_collected() and not _coin_gate_nodes.is_empty():
		AudioManager.play_coin_gate_open()

func is_tile_blocking(gpos: Vector2i, direction: Vector2i) -> bool:
	return is_blocked(gpos, direction)

func is_static_blocked_before_tick(gpos: Vector2i, direction: Vector2i) -> bool:
	if _is_out_of_bounds(gpos):
		return true

	var symbol: String = get_tile_at(gpos)
	if symbol == SYM_WALL:
		return true
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0
	if symbol == SYM_COIN_GATE:
		return not _all_coins_collected()

	return false

func is_blocked(gpos: Vector2i, direction: Vector2i) -> bool:
	return is_blocked_for_tick(gpos, direction, TickManager.current_tick)

func is_blocked_for_tick(gpos: Vector2i, direction: Vector2i, tick: int) -> bool:
	if _is_out_of_bounds(gpos):
		return true

	var symbol: String = get_tile_at(gpos)
	if symbol == SYM_WALL:
		return true
	if _time_gates.has(gpos):
		return not is_time_gate_open_at_tick(gpos, tick)
	if symbol == SYM_COIN_GATE:
		return not _all_coins_collected()
	if symbol == SYM_BLOCKER_H:
		return direction.x != 0
	if symbol == SYM_BLOCKER_V:
		return direction.y != 0

	return false

func get_slide_tile_info(gpos: Vector2i, extra_collected_coins: int = 0) -> TileInfo:
	var info = get_slide_tile_info_for_tick(gpos, _current_slide_direction, TickManager.current_tick, extra_collected_coins)
	return info

func get_slide_tile_info_for_tick(gpos: Vector2i, direction: Vector2i, tick: int, extra_collected_coins: int = 0) -> TileInfo:
	var info = _base_tile_info_for_tick(gpos, direction, tick, extra_collected_coins)
	_apply_enemy_hazard_for_tick(info, gpos, tick)
	return info

func get_hazard_tile_info(gpos: Vector2i) -> TileInfo:
	var info = _base_tile_info_for_tick(gpos, _current_slide_direction, TickManager.current_tick)
	_apply_laser_beam_hazard_for_tick(info, gpos, TickManager.current_tick)
	return info

func is_enemy_at(gpos: Vector2i) -> bool:
	for enemy_pos in _enemies:
		if _enemies[enemy_pos].current_grid_pos == gpos:
			return true
	return false

func update_anchor_overlap_visibility() -> void:
	for gpos in _anchor_nodes:
		var anchor := _anchor_nodes[gpos] as Sprite2D
		if not is_instance_valid(anchor):
			continue
		var alpha := ANCHOR_OCCUPIED_ALPHA if is_enemy_at(gpos) else ANCHOR_NORMAL_ALPHA
		anchor.modulate = Color(1.0, 1.0, 1.0, alpha)

func _base_tile_info(gpos: Vector2i, extra_collected_coins: int = 0) -> TileInfo:
	return _base_tile_info_for_tick(gpos, _current_slide_direction, TickManager.current_tick, extra_collected_coins)

func _base_tile_info_for_tick(gpos: Vector2i, direction: Vector2i, tick: int, extra_collected_coins: int = 0) -> TileInfo:
	var info = TileInfo.new()

	if _is_out_of_bounds(gpos):
		info.type = "wall"
		info.blocks = true
		return info

	_apply_base_tile_info_for_tick(info, gpos, get_tile_at(gpos), direction, tick, extra_collected_coins)
	return info

func _read_grid(rows: Array) -> void:
	grid_height = rows.size()
	grid_width = 0
	player_start = Vector2i.ZERO

	for y in range(grid_height):
		var row_str: String = rows[y]
		var row: Array = []
		grid_width = maxi(grid_width, row_str.length())

		for x in range(row_str.length()):
			var symbol: String = row_str[x]
			row.append(symbol)
			if symbol == SYM_PLAYER:
				player_start = Vector2i(x, y)

		grid.append(row)

func _configure_phase_goal(config: Dictionary) -> void:
	_phase_goal_period = int(config.get("period", 0))
	_phase_goal_active_phases.clear()
	var active_phases: Array = config.get("active", [])
	for phase in active_phases:
		_phase_goal_active_phases.append(int(phase))

func _apply_base_tile_info(info: TileInfo, gpos: Vector2i, symbol: String, extra_collected_coins: int = 0) -> void:
	_apply_base_tile_info_for_tick(info, gpos, symbol, _current_slide_direction, TickManager.current_tick, extra_collected_coins)

func _apply_base_tile_info_for_tick(info: TileInfo, gpos: Vector2i, symbol: String, direction: Vector2i, tick: int, extra_collected_coins: int = 0) -> void:
	match symbol:
		SYM_WALL:
			info.type = "wall"
			info.blocks = true
		SYM_GOAL:
			info.type = "goal"
			info.is_goal = is_goal_active_at_tick(tick)
		SYM_ANCHOR:
			info.type = "anchor"
			info.is_anchor = true
		SYM_BOUNCE:
			info.type = "bounce"
			info.is_bounce = true
		SYM_COIN:
			info.type = "coin"
			info.is_coin = not _collected_coins.has(gpos)
		SYM_COIN_GATE:
			info.type = "coin_gate"
			info.blocks = not _all_coins_collected(extra_collected_coins)
		SYM_LASER:
			info.type = "laser"
		SYM_SPIKE:
			info.type = "spike"
			info.kills_on_stop = _is_spike_active_at_tick(gpos, tick)
		SYM_TIME_GATE:
			info.type = "time_gate"
			info.blocks = _time_gates.has(gpos) and not is_time_gate_open_at_tick(gpos, tick)
		SYM_BLOCKER_H:
			info.type = "blocker_h"
			info.blocks = direction.x != 0
		SYM_BLOCKER_V:
			info.type = "blocker_v"
			info.blocks = direction.y != 0
		_:
			info.type = "empty"

func _apply_enemy_hazard(info: TileInfo, gpos: Vector2i) -> void:
	_apply_enemy_hazard_for_tick(info, gpos, TickManager.current_tick)

func _apply_enemy_hazard_for_tick(info: TileInfo, gpos: Vector2i, tick: int) -> void:
	for enemy_pos in _enemies:
		var enemy = _enemies[enemy_pos]
		var enemy_grid_pos: Vector2i = enemy.current_grid_pos
		if enemy.has_method("get_grid_pos_for_tick"):
			enemy_grid_pos = enemy.get_grid_pos_for_tick(tick)
		if enemy_grid_pos == gpos:
			info.kills_in_path = true
			return

func _apply_laser_beam_hazard(info: TileInfo, gpos: Vector2i) -> void:
	_apply_laser_beam_hazard_for_tick(info, gpos, TickManager.current_tick)

func _apply_laser_beam_hazard_for_tick(info: TileInfo, gpos: Vector2i, tick: int) -> void:
	if is_active_laser_beam_at_for_tick(gpos, tick):
		info.kills_in_path = true

func _collect_beam_cells(cells: Array, laser_pos: Vector2i, direction: Vector2i) -> void:
	_collect_beam_cells_for_tick(cells, laser_pos, direction, TickManager.current_tick)

func _collect_beam_cells_for_tick(cells: Array, laser_pos: Vector2i, direction: Vector2i, tick: int) -> void:
	var probe = laser_pos + direction
	while not _is_solid_obstacle_at_tick(probe, tick):
		cells.append(probe)
		probe += direction

func _is_solid_obstacle(pos: Vector2i) -> bool:
	return _is_solid_obstacle_at_tick(pos, TickManager.current_tick)

func _is_solid_obstacle_at_tick(pos: Vector2i, tick: int) -> bool:
	if _is_out_of_bounds(pos):
		return true

	var symbol: String = get_tile_at(pos)
	if symbol == SYM_WALL:
		return true
	if symbol == SYM_TIME_GATE and _time_gates.has(pos):
		return not is_time_gate_open_at_tick(pos, tick)
	if symbol == SYM_COIN_GATE:
		return not _all_coins_collected()

	return false

func _is_spike_active_at_tick(spike_pos: Vector2i, tick: int) -> bool:
	if not _spikes.has(spike_pos):
		return false

	var spike = _spikes[spike_pos]
	if spike.has_method("get_state_for_tick"):
		return spike.get_state_for_tick(tick).get("spike_state", spike.spike_state) == spike.SpikePhase.ACTIVE
	return spike.is_active()

func _all_coins_collected(extra_collected_coins: int = 0) -> bool:
	return _coin_nodes.is_empty() or _collected_coins.size() + extra_collected_coins >= _coin_nodes.size()

func _is_out_of_bounds(gpos: Vector2i) -> bool:
	return gpos.x < 0 or gpos.y < 0 or gpos.y >= grid_height or gpos.x >= grid_width

func _build_visuals() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var gpos = Vector2i(x, y)
			var world_pos = grid_to_world(gpos)
			var symbol: String = get_tile_at(gpos)

			_create_sprite(FLOOR_TEXTURE, world_pos, floors_container)

			match symbol:
				SYM_WALL:
					_create_sprite(WALL_TEXTURE, world_pos, walls_container)
				SYM_GOAL:
					_goal_node = _create_sprite(GOAL_TEXTURE, world_pos, objects_container)
					_goal_grid_pos = gpos
					_apply_goal_shader(_goal_node)
				SYM_ANCHOR:
					_create_anchor_tile(gpos, world_pos)
				SYM_BOUNCE:
					_create_bounce_tile(gpos, world_pos)
				SYM_COIN:
					_create_coin(gpos, world_pos)
				SYM_COIN_GATE:
					_create_coin_gate(gpos, world_pos)
				SYM_TIME_GATE:
					_create_phase_object(TIME_GATE_SCENE, gpos, world_pos, _time_gates)
				SYM_LASER:
					_create_phase_object(LASER_SCENE, gpos, world_pos, _lasers)
				SYM_SPIKE:
					_create_phase_object(SPIKE_SCENE, gpos, world_pos, _spikes)
				SYM_ENEMY:
					_create_enemy(gpos, world_pos)
				SYM_BLOCKER_H:
					_create_blocker(HORIZONTAL_BLOCKER_TEXTURE, world_pos)
				SYM_BLOCKER_V:
					_create_blocker(VERTICAL_BLOCKER_TEXTURE, world_pos)

func _create_sprite(texture: Texture2D, world_pos: Vector2, parent: Node) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.position = world_pos
	parent.add_child(sprite)
	return sprite

func _create_anchor_tile(gpos: Vector2i, world_pos: Vector2) -> void:
	var anchor := _create_sprite(ANCHOR_TEXTURE, world_pos, objects_container)
	var material := ShaderMaterial.new()
	material.shader = ANCHOR_CAPTURE_SHADER
	anchor.material = material
	_anchor_nodes[gpos] = anchor

func play_anchor_capture(anchor_pos: Vector2i, incoming_direction: Vector2i) -> void:
	var anchor := _anchor_nodes.get(anchor_pos) as Sprite2D
	if anchor == null:
		return

	if _anchor_capture_tweens.has(anchor_pos):
		var existing_tween := _anchor_capture_tweens[anchor_pos] as Tween
		if existing_tween != null:
			existing_tween.kill()

	var shader_material := _get_anchor_material(anchor)
	if shader_material == null:
		return

	var direction := Vector2(float(incoming_direction.x), float(incoming_direction.y))
	if direction.length_squared() <= 0.0:
		direction = Vector2.UP

	shader_material.set_shader_parameter("capture_direction", direction.normalized())
	shader_material.set_shader_parameter("capture_amount", 1.0)

	var tween := create_tween()
	_anchor_capture_tweens[anchor_pos] = tween
	tween.tween_property(shader_material, "shader_parameter/capture_amount", 0.0, ANCHOR_CAPTURE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _anchor_capture_tweens.get(anchor_pos) == tween:
			_anchor_capture_tweens.erase(anchor_pos)
	)

func _get_anchor_material(anchor: Sprite2D) -> ShaderMaterial:
	return anchor.material as ShaderMaterial

func _apply_goal_shader(sprite: Sprite2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = GOAL_PORTAL_SHADER
	sprite.material = material

func _update_goal_visual_for_tick(tick: int) -> void:
	if _goal_node == null:
		return

	var active := is_goal_active_at_tick(tick)
	_goal_node.modulate = Color(0.4, 1.0, 0.95, 1.0) if active else Color(0.18, 0.36, 0.42, 0.55)
	var shader_material := _goal_node.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("pulse_strength", 1.0 if active else 0.15)

func _create_blocker(texture: Texture2D, world_pos: Vector2) -> void:
	_create_sprite(texture, world_pos, objects_container)

func _create_bounce_tile(gpos: Vector2i, world_pos: Vector2) -> void:
	var sprite := _create_sprite(BOUNCE_TEXTURE, world_pos, objects_container)
	var material := ShaderMaterial.new()
	material.shader = BOUNCE_IMPACT_SHADER
	sprite.material = material
	_bounce_nodes[gpos] = sprite
	_bounce_base_positions[gpos] = world_pos

func _create_coin(gpos: Vector2i, world_pos: Vector2) -> void:
	var marker := _create_sprite(COIN_TEXTURE, world_pos, objects_container)
	_coin_nodes[gpos] = marker

func _create_coin_gate(gpos: Vector2i, world_pos: Vector2) -> void:
	var gate := _create_sprite(COIN_GATE_CLOSED_TEXTURE, world_pos, objects_container)
	_coin_gate_nodes[gpos] = gate

func _update_coin_gate_visuals() -> void:
	var open := _all_coins_collected()
	for gpos in _coin_gate_nodes:
		var gate_node := _coin_gate_nodes[gpos] as Sprite2D
		if not is_instance_valid(gate_node):
			continue
		gate_node.texture = COIN_GATE_OPEN_TEXTURE if open else COIN_GATE_CLOSED_TEXTURE

func _create_phase_object(scene: PackedScene, gpos: Vector2i, world_pos: Vector2, registry: Dictionary) -> Node:
	var instance = scene.instantiate()
	instance.position = world_pos
	instance.grid_pos = gpos
	objects_container.add_child(instance)
	registry[gpos] = instance
	TickManager.register_environment_object(instance)
	if instance.has_method("update_phase"):
		instance.update_phase(TickManager.current_tick)
	return instance

func _create_enemy(gpos: Vector2i, world_pos: Vector2) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.position = world_pos
	enemy.grid_pos = gpos
	enemy.current_grid_pos = gpos
	enemy.patrol_offsets = _patrol_path_for_next_enemy()
	enemy.z_index = ENEMY_OBJECT_Z_INDEX
	objects_container.add_child(enemy)
	_enemies[gpos] = enemy
	TickManager.register_enemy_object(enemy)
	if enemy.has_method("update_phase"):
		enemy.update_phase(TickManager.current_tick)


func refresh_all_move_previews() -> void:
	_clear_all_previews()
	if not _should_show_move_previews():
		return

	var next_tick := TickManager.current_tick + 1
	_set_live_phase_objects_visible(false)
	_refresh_future_board_preview(next_tick)
	_set_future_preview_effect_visible(true)
	_set_future_preview_cue_visible(true)


func _is_preview_key_held() -> bool:
	return (
		SettingsManager.move_previews_enabled
		and GameManager.is_playing()
		and Input.is_action_pressed("preview_future")
	)

func _should_show_move_previews() -> bool:
	return (
		_is_preview_key_held()
		and future_preview_layer != null
	)


func _clear_all_previews() -> void:
	if future_preview_layer != null:
		_clear_children(future_preview_layer)
	update_anchor_overlap_visibility()
	_set_future_preview_effect_visible(false)
	_set_live_phase_objects_visible(true)
	_set_future_preview_cue_visible(false)

func _update_anchor_preview_overlap_visibility(tick: int) -> void:
	for gpos in _anchor_nodes:
		var anchor := _anchor_nodes[gpos] as Sprite2D
		if not is_instance_valid(anchor):
			continue
		var alpha := ANCHOR_OCCUPIED_ALPHA if _is_enemy_at_for_tick(gpos, tick) else ANCHOR_NORMAL_ALPHA
		anchor.modulate = Color(1.0, 1.0, 1.0, alpha)

func _is_enemy_at_for_tick(gpos: Vector2i, tick: int) -> bool:
	for enemy in _enemies.values():
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("get_grid_pos_for_tick"):
			if enemy.get_grid_pos_for_tick(tick) == gpos:
				return true
		elif enemy.current_grid_pos == gpos:
			return true
	return false


func _configure_future_preview_effect() -> void:
	if future_preview_effect == null:
		return

	future_preview_effect.position = Vector2.ZERO
	future_preview_effect.size = Vector2(
		float(grid_width * TILE_SIZE),
		float(grid_height * TILE_SIZE)
	)
	future_preview_effect.visible = false


func _refresh_future_board_preview(next_tick: int) -> void:
	_update_anchor_preview_overlap_visibility(next_tick)
	_add_phase_goal_future_preview(next_tick)
	for gate in _time_gates.values():
		_add_time_gate_future_preview(gate, next_tick)
	for laser in _lasers.values():
		_add_laser_future_preview(laser, next_tick)
	for spike in _spikes.values():
		_add_spike_future_preview(spike, next_tick)
	for enemy in _enemies.values():
		_add_enemy_future_preview(enemy, next_tick)

func _add_phase_goal_future_preview(next_tick: int) -> void:
	if not is_phase_goal_configured() or _goal_node == null:
		return

	var sprite := Sprite2D.new()
	sprite.texture = GOAL_TEXTURE
	sprite.position = grid_to_world(_goal_grid_pos)
	sprite.modulate = Color(0.4, 1.0, 0.95, 0.85) if is_goal_active_at_tick(next_tick) else Color(0.1, 0.22, 0.28, 0.82)
	future_preview_layer.add_child(sprite)


func _add_time_gate_future_preview(gate: Node, next_tick: int) -> void:
	if not is_instance_valid(gate) or not gate.has_method("get_state_for_tick"):
		return

	var sprite := Sprite2D.new()
	sprite.texture = TIME_GATE_TEXTURE
	sprite.position = gate.position
	var next_open: bool = gate.get_state_for_tick(next_tick).get("is_open", gate.is_open())
	sprite.modulate = Color(0.4, 1.0, 0.6, 0.25) if next_open else Color(0.4, 0.8, 1.0, 1.0)
	future_preview_layer.add_child(sprite)


func _add_laser_future_preview(laser: Node, next_tick: int) -> void:
	if not is_instance_valid(laser) or not laser.has_method("get_state_for_tick"):
		return

	var preview := Node2D.new()
	preview.position = laser.position
	future_preview_layer.add_child(preview)

	var sprite := Sprite2D.new()
	sprite.texture = LASER_TEXTURE
	preview.add_child(sprite)

	var next_active: bool = laser.get_state_for_tick(next_tick).get("is_active", laser.is_active())
	if next_active:
		sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
		_add_laser_beam_future_preview(preview, laser, next_tick)
	else:
		sprite.modulate = Color(0.5, 0.3, 0.3, 0.4)


func _add_laser_beam_future_preview(preview: Node2D, laser: Node, next_tick: int) -> void:
	var beam := ColorRect.new()
	beam.color = Color(1.0, 0.2, 0.2, 0.7)
	var cells := get_laser_beam_cells_for_tick(laser.grid_pos, next_tick)
	if cells.is_empty():
		cells = [laser.grid_pos]

	var min_x: int = laser.grid_pos.x
	var max_x: int = laser.grid_pos.x
	var min_y: int = laser.grid_pos.y
	var max_y: int = laser.grid_pos.y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	if laser.get_beam_direction().x != 0:
		beam.size = Vector2(float(max_x - min_x + 1) * TILE_SIZE, 8.0)
		beam.position = Vector2(float(min_x - laser.grid_pos.x) * TILE_SIZE - TILE_SIZE / 2.0, -4.0)
	else:
		beam.size = Vector2(8.0, float(max_y - min_y + 1) * TILE_SIZE)
		beam.position = Vector2(-4.0, float(min_y - laser.grid_pos.y) * TILE_SIZE - TILE_SIZE / 2.0)
	preview.add_child(beam)


func _add_spike_future_preview(spike: Node, next_tick: int) -> void:
	if not is_instance_valid(spike) or not spike.has_method("get_state_for_tick"):
		return

	var sprite := Sprite2D.new()
	sprite.texture = SPIKE_TEXTURE
	sprite.position = spike.position
	var next_state: int = spike.get_state_for_tick(next_tick).get("spike_state", spike.spike_state)
	match next_state:
		spike.SpikePhase.WARNING:
			sprite.modulate = Color(1.0, 0.85, 0.1, 1.0)
		spike.SpikePhase.ACTIVE:
			sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		_:
			sprite.modulate = Color(0.6, 0.6, 0.6, 0.35)
	future_preview_layer.add_child(sprite)


func _add_enemy_future_preview(enemy: Node, next_tick: int) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("get_grid_pos_for_tick"):
		return

	var next_grid_pos: Vector2i = enemy.get_grid_pos_for_tick(next_tick)
	var sprite := Sprite2D.new()
	sprite.texture = ENEMY_TEXTURE
	sprite.hframes = 5
	sprite.frame = 0
	sprite.position = grid_to_world(next_grid_pos)
	future_preview_layer.add_child(sprite)


func _make_preview_rect(size: Vector2, inset: float, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.position = Vector2(-TILE_SIZE / 2.0 + inset, -TILE_SIZE / 2.0 + inset)
	rect.color = color
	return rect


func _play_environment_phase_pulses(tick: int) -> void:
	if not GameManager.is_playing() or tick <= 0:
		return

	var previous_tick := tick - 1
	for registry in [_time_gates, _lasers, _spikes]:
		for obj in registry.values():
			if not is_instance_valid(obj) or not obj.has_method("get_state_for_tick"):
				continue
			if obj.get_state_for_tick(tick) == obj.get_state_for_tick(previous_tick):
				continue
			if obj.has_method("play_phase_pulse"):
				obj.play_phase_pulse()


func _set_live_phase_objects_visible(is_visible: bool) -> void:
	for registry in [_time_gates, _lasers, _spikes, _enemies]:
		for obj in registry.values():
			if is_instance_valid(obj):
				obj.visible = is_visible


func _set_future_preview_effect_visible(is_visible: bool) -> void:
	if future_preview_effect != null:
		future_preview_effect.visible = is_visible


func _set_future_preview_cue_visible(is_visible: bool) -> void:
	if hud != null and hud.has_method("set_future_preview_visible"):
		hud.set_future_preview_visible(is_visible)


func _on_tick_advanced_refresh_previews(tick: int) -> void:
	_play_environment_phase_pulses(tick)
	_update_goal_visual_for_tick(tick)
	refresh_all_move_previews()


func _on_game_state_changed_refresh_previews(new_state: int) -> void:
	_preview_key_was_held = false
	if new_state == GameManager.GameState.PLAYING:
		refresh_all_move_previews()
	else:
		_clear_all_previews()


func _on_move_previews_setting_changed(enabled: bool) -> void:
	_preview_key_was_held = false
	if enabled and _is_preview_key_held():
		refresh_all_move_previews()
	else:
		_clear_all_previews()


func _patrol_path_for_next_enemy() -> Array[Vector2i]:
	var path: Array[Vector2i] = GameManager.DEFAULT_ENEMY_PATROL.duplicate()
	if _enemy_path_assign_index < _enemy_patrol_paths.size():
		path = _enemy_patrol_paths[_enemy_path_assign_index]
	_enemy_path_assign_index += 1
	return path

func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()

func _clear_bounce_impacts() -> void:
	for bounce_pos in _bounce_impact_tweens:
		var tween := _bounce_impact_tweens[bounce_pos] as Tween
		if tween != null:
			tween.kill()
	_bounce_impact_tweens.clear()

func _clear_anchor_capture_tweens() -> void:
	for anchor_pos in _anchor_capture_tweens:
		var tween := _anchor_capture_tweens[anchor_pos] as Tween
		if tween != null:
			tween.kill()
	_anchor_capture_tweens.clear()

func play_goal_collect_tween() -> void:
	if _goal_node == null:
		return
	
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_goal_node, "scale", Vector2.ZERO, 0.25)

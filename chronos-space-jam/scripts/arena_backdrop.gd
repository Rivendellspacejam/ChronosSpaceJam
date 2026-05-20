extends Node2D

const THEME_GRAVITY := preload("res://assets/backgrounds/gameplay_gravity.png")
const THEME_HAZARD := preload("res://assets/backgrounds/gameplay_hazard.png")
const THEME_PATROL := preload("res://assets/backgrounds/gameplay_patrol.png")
const THEME_GOLD := preload("res://assets/backgrounds/gameplay_gold.png")
const THEME_BOUNCE := preload("res://assets/backgrounds/gameplay_bounce.png")
const THEME_PHASE := preload("res://assets/backgrounds/gameplay_phase.png")
const TILE_SIZE: int = 48

var grid_width: int = 0
var grid_height: int = 0
var _theme_texture: Texture2D = THEME_GRAVITY
var _theme_tint: Color = Color(0.58, 0.86, 1.0, 0.58)
var _theme_base_color: Color = Color(0.015, 0.055, 0.085, 1.0)
var _theme_line_color: Color = Color(0.38, 0.95, 1.0, 0.16)

func set_theme(level_index: int) -> void:
	if level_index <= 2:
		_theme_texture = THEME_GRAVITY
		_theme_tint = Color(0.58, 0.86, 1.0, 0.58)
		_theme_base_color = Color(0.015, 0.055, 0.085, 1.0)
		_theme_line_color = Color(0.38, 0.95, 1.0, 0.16)
	elif level_index <= 4:
		_theme_texture = THEME_HAZARD
		_theme_tint = Color(1.0, 0.45, 0.34, 0.54)
		_theme_base_color = Color(0.12, 0.025, 0.018, 1.0)
		_theme_line_color = Color(1.0, 0.24, 0.18, 0.15)
	elif level_index <= 11:
		_theme_texture = THEME_PATROL
		_theme_tint = Color(0.6, 0.75, 1.0, 0.55)
		_theme_base_color = Color(0.035, 0.05, 0.11, 1.0)
		_theme_line_color = Color(0.45, 0.68, 1.0, 0.15)
	elif level_index <= 14:
		_theme_texture = THEME_GOLD
		_theme_tint = Color(1.0, 0.82, 0.32, 0.52)
		_theme_base_color = Color(0.13, 0.082, 0.012, 1.0)
		_theme_line_color = Color(1.0, 0.78, 0.20, 0.16)
	elif level_index <= 19:
		_theme_texture = THEME_BOUNCE
		_theme_tint = Color(0.42, 1.0, 0.82, 0.54)
		_theme_base_color = Color(0.012, 0.10, 0.075, 1.0)
		_theme_line_color = Color(0.35, 1.0, 0.76, 0.15)
	else:
		_theme_texture = THEME_PHASE
		_theme_tint = Color(0.72, 0.58, 1.0, 0.58)
		_theme_base_color = Color(0.060, 0.035, 0.12, 1.0)
		_theme_line_color = Color(0.72, 0.52, 1.0, 0.16)
	queue_redraw()

func configure(width: int, height: int) -> void:
	grid_width = width
	grid_height = height
	queue_redraw()

func _draw() -> void:
	if grid_width <= 0 or grid_height <= 0:
		return

	var arena_size := Vector2(float(grid_width * TILE_SIZE), float(grid_height * TILE_SIZE))
	var outer := Rect2(Vector2(-18.0, -18.0), arena_size + Vector2(36.0, 36.0))
	var inner := Rect2(Vector2.ZERO, arena_size)
	var backdrop_rect := _viewport_backdrop_rect(arena_size)

	draw_rect(backdrop_rect, _theme_base_color, true)
	draw_texture_rect(_theme_texture, backdrop_rect, true, _theme_tint, true)
	_draw_viewport_theme_grid(backdrop_rect, arena_size * 0.5)
	draw_rect(outer, Color(0.018, 0.025, 0.05, 1.0), true)
	draw_rect(outer, Color(0.1, 0.62, 0.78, 0.22), false, 4.0)
	draw_rect(inner, Color(0.02, 0.04, 0.075, 0.82), true)
	draw_rect(inner, Color(0.42, 0.95, 1.0, 0.04), true)

	for x in range(grid_width + 1):
		var px := float(x * TILE_SIZE)
		draw_line(Vector2(px, 0), Vector2(px, arena_size.y), Color(0.18, 0.52, 0.68, 0.16), 1.0)

	for y in range(grid_height + 1):
		var py := float(y * TILE_SIZE)
		draw_line(Vector2(0, py), Vector2(arena_size.x, py), Color(0.18, 0.52, 0.68, 0.16), 1.0)

	var center := arena_size * 0.5
	draw_arc(center, maxf(arena_size.x, arena_size.y) * 0.58, 0.18, TAU - 0.18, 96, Color(0.35, 0.95, 1.0, 0.11), 2.0, true)
	draw_arc(center, maxf(arena_size.x, arena_size.y) * 0.42, 0.0, TAU, 96, Color(1.0, 0.86, 0.36, 0.07), 1.0, true)
	draw_line(Vector2.ZERO, Vector2(arena_size.x, arena_size.y), Color(0.65, 0.95, 1.0, 0.05), 2.0)
	_draw_corner_brackets(inner)

func _draw_corner_brackets(rect: Rect2) -> void:
	var corner_length := 34.0
	var color := Color(0.68, 0.98, 1.0, 0.58)
	var width := 3.0
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y

	draw_line(Vector2(left, top), Vector2(left + corner_length, top), color, width)
	draw_line(Vector2(left, top), Vector2(left, top + corner_length), color, width)
	draw_line(Vector2(right, top), Vector2(right - corner_length, top), color, width)
	draw_line(Vector2(right, top), Vector2(right, top + corner_length), color, width)
	draw_line(Vector2(left, bottom), Vector2(left + corner_length, bottom), color, width)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - corner_length), color, width)
	draw_line(Vector2(right, bottom), Vector2(right - corner_length, bottom), color, width)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - corner_length), color, width)

func _viewport_backdrop_rect(arena_size: Vector2) -> Rect2:
	var viewport_size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var zoom := Vector2(maxf(camera.zoom.x, 0.01), maxf(camera.zoom.y, 0.01))
		var visible_size := viewport_size / zoom
		var center := to_local(camera.get_screen_center_position())
		return Rect2(center - (visible_size * 0.5) - Vector2(1200.0, 800.0), visible_size + Vector2(2400.0, 1600.0))

	var padded_size := Vector2(maxf(arena_size.x + 2400.0, viewport_size.x), maxf(arena_size.y + 1600.0, viewport_size.y))
	return Rect2((arena_size - padded_size) * 0.5, padded_size)

func _draw_viewport_theme_grid(rect: Rect2, orbit_center: Vector2) -> void:
	var spacing := 92.0
	var start_x: float = floorf(rect.position.x / spacing) * spacing
	var x: float = start_x
	while x <= rect.end.x:
		var alpha := 0.08 + (0.04 * absf(sin(x * 0.011)))
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(_theme_line_color.r, _theme_line_color.g, _theme_line_color.b, alpha), 1.0)
		x += spacing

	var start_y: float = floorf(rect.position.y / spacing) * spacing
	var y: float = start_y
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(_theme_line_color.r, _theme_line_color.g, _theme_line_color.b, 0.045), 1.0)
		y += spacing

	var radius_base := maxf(rect.size.x, rect.size.y) * 0.25
	for index in range(4):
		var radius := radius_base + float(index * 160)
		draw_arc(orbit_center, radius, 0.0, TAU, 160, Color(_theme_line_color.r, _theme_line_color.g, _theme_line_color.b, 0.055), 2.0, true)

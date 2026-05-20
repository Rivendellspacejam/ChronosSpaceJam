extends Node2D

const GAMEPLAY_VOID := preload("res://assets/backgrounds/gameplay_void.png")
const TILE_SIZE: int = 48

var grid_width: int = 0
var grid_height: int = 0

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
	var void_rect := Rect2(Vector2(-420.0, -300.0), arena_size + Vector2(840.0, 600.0))

	draw_texture_rect(GAMEPLAY_VOID, void_rect, true, Color(0.5, 0.78, 1.0, 0.52), true)
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

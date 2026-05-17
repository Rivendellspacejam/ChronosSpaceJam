extends Node2D

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

	draw_rect(outer, Color(0.018, 0.025, 0.05, 1.0), true)
	draw_rect(outer, Color(0.1, 0.62, 0.78, 0.22), false, 4.0)
	draw_rect(inner, Color(0.02, 0.04, 0.075, 0.82), true)

	for x in range(grid_width + 1):
		var px := float(x * TILE_SIZE)
		draw_line(Vector2(px, 0), Vector2(px, arena_size.y), Color(0.18, 0.52, 0.68, 0.12), 1.0)

	for y in range(grid_height + 1):
		var py := float(y * TILE_SIZE)
		draw_line(Vector2(0, py), Vector2(arena_size.x, py), Color(0.18, 0.52, 0.68, 0.12), 1.0)

	draw_line(Vector2.ZERO, Vector2(arena_size.x, arena_size.y), Color(0.65, 0.95, 1.0, 0.05), 2.0)

## GameLevel — Main game scene controller
## Orchestrates level loading, player spawning, HUD connection
## Covers: CORE-03, CORE-04, CORE-08
extends Node2D

@onready var level_manager := $LevelManager
@onready var player := $Player
@onready var camera := $Camera2D

func _ready() -> void:
	player.add_to_group("player")
	GameManager.level_loaded.connect(_on_level_loaded)
	GameManager.player_died.connect(_on_player_died)

	# Load first level
	_load_current_level()

func _load_current_level() -> void:
	# Reset tick system
	TickManager.reset()

	# Load level data into the level manager
	var start_pos := level_manager.load_level(GameManager.current_level_index)

	# Initialize player at start position
	player.init_player(start_pos, level_manager)

	# Center camera on level
	var center_x := level_manager.grid_width * level_manager.TILE_SIZE / 2.0
	var center_y := level_manager.grid_height * level_manager.TILE_SIZE / 2.0
	camera.position = Vector2(center_x, center_y)

	# Adjust zoom based on level size
	var max_dim := maxf(level_manager.grid_width, level_manager.grid_height)
	var target_zoom := 800.0 / (max_dim * level_manager.TILE_SIZE)
	target_zoom = clampf(target_zoom, 0.5, 2.0)
	camera.zoom = Vector2(target_zoom, target_zoom)

	# Set game state
	GameManager.set_state(GameManager.GameState.PLAYING)

func _on_level_loaded(_level_index: int) -> void:
	_load_current_level()

func _on_player_died() -> void:
	# Wait a bit then allow restart
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		if GameManager.current_state == GameManager.GameState.DEAD or \
		   GameManager.current_state == GameManager.GameState.LEVEL_CLEAR or \
		   GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.restart_level()
	elif event.is_action_pressed("ui_accept"):
		if GameManager.current_state == GameManager.GameState.LEVEL_CLEAR:
			GameManager.next_level()
	elif event.is_action_pressed("ui_cancel"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.set_state(GameManager.GameState.PAUSED)
			get_tree().paused = true
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.set_state(GameManager.GameState.PLAYING)
			get_tree().paused = false

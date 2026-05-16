## GameManager — Autoload singleton
## Manages game state, level progression, and global signals.
## Covers: FOUND-06 (Game State Machine), CORE-08 (Level Progression)
extends Node

# --- Signals ---
signal state_changed(new_state: GameState)
signal level_loaded(level_index: int)
signal level_cleared(move_count: int, best_moves: int)
signal player_died()

# --- Enums ---
enum GameState {
	MENU,
	PLAYING,
	SLIDING,
	DEAD,
	LEVEL_CLEAR,
	PAUSED,
}

# --- Constants ---
const LEVEL_DIR := "res://levels/"
const TOTAL_LEVELS := 8

# --- State ---
var current_state: GameState = GameState.MENU
var current_level_index: int = 0
var best_moves: Dictionary = {}  # level_index -> best move count

# --- Level Data Cache ---
var _level_data_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# --- State Machine ---
func set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_sliding() -> bool:
	return current_state == GameState.SLIDING

func can_accept_input() -> bool:
	return current_state == GameState.PLAYING

# --- Level Progression ---
func load_level(index: int) -> void:
	current_level_index = clampi(index, 0, TOTAL_LEVELS - 1)
	level_loaded.emit(current_level_index)

func next_level() -> void:
	if current_level_index < TOTAL_LEVELS - 1:
		load_level(current_level_index + 1)
	else:
		# Return to menu after final level
		set_state(GameState.MENU)
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func restart_level() -> void:
	load_level(current_level_index)

func on_level_cleared(move_count: int) -> void:
	# Track best moves
	if not best_moves.has(current_level_index) or move_count < best_moves[current_level_index]:
		best_moves[current_level_index] = move_count
	set_state(GameState.LEVEL_CLEAR)
	level_cleared.emit(move_count, best_moves.get(current_level_index, move_count))

func on_player_died() -> void:
	set_state(GameState.DEAD)
	player_died.emit()

# --- Level Data Loading ---
func get_level_path(index: int) -> String:
	return LEVEL_DIR + "level_%d.txt" % (index + 1)

func load_level_data(index: int) -> Array:
	"""Load level grid data from text file. Returns array of strings (rows)."""
	var path := get_level_path(index)
	if _level_data_cache.has(index):
		return _level_data_cache[index]

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open level file: %s" % path)
		return []

	var rows: Array = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.length() > 0:
			rows.append(line)
	file.close()

	_level_data_cache[index] = rows
	return rows

func clear_level_cache() -> void:
	_level_data_cache.clear()

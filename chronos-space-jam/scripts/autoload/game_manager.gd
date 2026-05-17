extends Node

signal state_changed(new_state: int)
signal level_loaded(level_index: int)
signal level_cleared(move_count: int, best_moves: int, target: int)
signal player_died()

enum GameState {
	MENU,
	PLAYING,
	SLIDING,
	STORY,
	DEAD,
	LEVEL_CLEAR,
	PAUSED,
}

const LEVEL_DIR: String = "res://levels/"
const TOTAL_LEVELS: int = 12
const LEVEL_TARGETS: Dictionary = {
	0: 3,
	1: 3,
	2: 5,
	3: 5,
	4: 8,
	5: 8,
	6: 9,
	7: 10,
	8: 11,
	9: 12,
	10: 14,
	11: 15,
}

var current_state: int = GameState.MENU
var current_level_index: int = 0
var best_moves: Dictionary = {}

var _level_data_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_state(new_state: int) -> void:
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

func load_level(index: int) -> void:
	current_level_index = clampi(index, 0, TOTAL_LEVELS - 1)
	clear_level_cache()
	level_loaded.emit(current_level_index)

func next_level() -> void:
	if current_level_index < TOTAL_LEVELS - 1:
		load_level(current_level_index + 1)
		return

	set_state(GameState.MENU)
	get_tree().change_scene_to_file("res://scenes/ui/ending.tscn")

func restart_level() -> void:
	load_level(current_level_index)

func on_level_cleared(move_count: int) -> void:
	if not best_moves.has(current_level_index) or move_count < best_moves[current_level_index]:
		best_moves[current_level_index] = move_count

	var target = LEVEL_TARGETS.get(current_level_index, 0)
	set_state(GameState.LEVEL_CLEAR)
	level_cleared.emit(move_count, best_moves.get(current_level_index, move_count), target)

func on_player_died() -> void:
	set_state(GameState.DEAD)
	player_died.emit()

func get_level_path(index: int) -> String:
	return LEVEL_DIR + "level_" + str(index + 1) + ".txt"

func load_level_data(index: int) -> Array:
	if _level_data_cache.has(index):
		return _level_data_cache[index]

	var path = get_level_path(index)
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open level file: " + path)
		return []

	var rows: Array = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.length() > 0:
			rows.append(line)

	file.close()
	_level_data_cache[index] = rows
	return rows

func clear_level_cache() -> void:
	_level_data_cache.clear()

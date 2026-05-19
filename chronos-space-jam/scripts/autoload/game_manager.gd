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
const ENEMY_PATH_PREFIX: String = "@enemy_path"
const DEFAULT_ENEMY_PATROL: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]
const TOTAL_LEVELS: int = 24
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
	12: 2,
	13: 5,
	14: 5,
	15: 8,
	16: 6,
	17: 5,
	18: 5,
	19: 5,
	20: 5,
	21: 8,
	22: 9,
	23: 9,
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
	return load_level_bundle(index).get("rows", [])


func load_enemy_patrol_paths(index: int) -> Array:
	return load_level_bundle(index).get("enemy_paths", [])


func load_level_bundle(index: int) -> Dictionary:
	if _level_data_cache.has(index):
		return _level_data_cache[index]

	var path = get_level_path(index)
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open level file: " + path)
		return {"rows": [], "enemy_paths": []}

	var rows: Array = []
	var enemy_paths: Array = []
	var start_tick: int = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		if line.begins_with(ENEMY_PATH_PREFIX):
			var offsets = _parse_enemy_path_line(line)
			if not offsets.is_empty():
				enemy_paths.append(offsets)
			continue
		if line.begins_with("@start_tick"):
			var val_text = line.substr("@start_tick".length()).strip_edges()
			if val_text.begins_with("="):
				val_text = val_text.substr(1).strip_edges()
			if not val_text.is_empty():
				start_tick = int(val_text)
			continue
		rows.append(line)

	file.close()
	var bundle = {"rows": rows, "enemy_paths": enemy_paths, "start_tick": start_tick}
	_level_data_cache[index] = bundle
	return bundle


func _parse_enemy_path_line(line: String) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	var coords_text = line.substr(ENEMY_PATH_PREFIX.length()).strip_edges()
	for part in coords_text.split(";", false):
		var trimmed = part.strip_edges()
		if trimmed.is_empty():
			continue
		var pieces = trimmed.split(",", false)
		if pieces.size() != 2:
			push_warning("Invalid enemy path coordinate: %s" % trimmed)
			continue
		offsets.append(Vector2i(int(pieces[0]), int(pieces[1])))
	return offsets

func clear_level_cache() -> void:
	_level_data_cache.clear()

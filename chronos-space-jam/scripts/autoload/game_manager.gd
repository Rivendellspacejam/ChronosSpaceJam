extends Node

signal state_changed(new_state: int)
signal level_loaded(level_index: int)
signal level_cleared(move_count: int, best_moves: int, medal_data: Dictionary)
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
const LEVEL_MEDAL_TARGETS: Dictionary = {
	0: {"gold": 3, "silver": 5},
	1: {"gold": 3, "silver": 5},
	2: {"gold": 5, "silver": 7},
	3: {"gold": 5, "silver": 7},
	4: {"gold": 8, "silver": 10},
	5: {"gold": 8, "silver": 10},
	6: {"gold": 9, "silver": 11},
	7: {"gold": 10, "silver": 12},
	8: {"gold": 11, "silver": 13},
	9: {"gold": 12, "silver": 14},
	10: {"gold": 14, "silver": 16},
	11: {"gold": 15, "silver": 17},
	12: {"gold": 2, "silver": 4},
	13: {"gold": 5, "silver": 7},
	14: {"gold": 5, "silver": 7},
	15: {"gold": 8, "silver": 10},
	16: {"gold": 6, "silver": 8},
	17: {"gold": 5, "silver": 7},
	18: {"gold": 5, "silver": 7},
	19: {"gold": 5, "silver": 7},
	20: {"gold": 5, "silver": 7},
	21: {"gold": 8, "silver": 10},
	22: {"gold": 9, "silver": 11},
	23: {"gold": 9, "silver": 11},
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

	var medal_data = get_level_medal_data(current_level_index, move_count)
	set_state(GameState.LEVEL_CLEAR)
	level_cleared.emit(move_count, best_moves.get(current_level_index, move_count), medal_data)

func on_player_died() -> void:
	set_state(GameState.DEAD)
	player_died.emit()

func get_level_path(index: int) -> String:
	return LEVEL_DIR + "level_" + str(index + 1) + ".txt"

func get_level_medal_targets(level_index: int) -> Dictionary:
	return LEVEL_MEDAL_TARGETS.get(level_index, {"gold": 0, "silver": 0}).duplicate()

func get_medal_for_moves(level_index: int, move_count: int) -> String:
	var targets := get_level_medal_targets(level_index)
	var gold_target := int(targets.get("gold", 0))
	var silver_target := int(targets.get("silver", gold_target))
	if move_count <= gold_target:
		return "Gold"
	if move_count <= silver_target:
		return "Silver"
	return "Bronze"

func get_level_medal_data(level_index: int, move_count: int) -> Dictionary:
	var targets := get_level_medal_targets(level_index)
	return {
		"medal": get_medal_for_moves(level_index, move_count),
		"gold": int(targets.get("gold", 0)),
		"silver": int(targets.get("silver", 0)),
	}

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

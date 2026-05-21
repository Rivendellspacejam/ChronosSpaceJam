extends SceneTree

const PERSISTENT_MENU_SCENES: Array[Dictionary] = [
	{"scene": "res://scenes/ui/main_menu.tscn", "label": "menu"},
	{"scene": "res://scenes/ui/level_select.tscn", "label": "level_select"},
	{"scene": "res://scenes/ui/credits.tscn", "label": "credits"},
]

const SCENE_MUSIC_CHECKS: Array[Dictionary] = [
	{"scene": "res://scenes/game/game_level.tscn", "label": "gameplay"},
	{"scene": "res://scenes/ui/ending.tscn", "label": "ending"},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio_manager = root.get_node_or_null("AudioManager")
	if audio_manager == null:
		push_error("AudioManager autoload missing")
		quit(1)
		return

	if not await _check_persistent_menu_music(audio_manager):
		quit(1)
		return
	if not await _check_dialog_click("res://scenes/ui/intro.tscn", "intro"):
		quit(1)
		return
	if not await _check_dialog_click("res://scenes/ui/ending.tscn", "ending"):
		quit(1)
		return

	for check in SCENE_MUSIC_CHECKS:
		var packed := load(str(check["scene"]))
		if packed == null:
			push_error("Could not load " + str(check["scene"]))
			quit(1)
			return

		var scene = packed.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		audio_manager.play_ui_click()
		await process_frame
		await create_timer(0.6).timeout
		await process_frame
		if not _check_music_state(scene, str(check["label"])):
			quit(1)
			return

		root.remove_child(scene)
		scene.free()
		audio_manager.stop_music()
		await process_frame

	print("OK audio runtime")
	call_deferred("quit", 0)

func _check_persistent_menu_music(audio_manager: Node) -> bool:
	var previous_saved_position := -1.0
	for check in PERSISTENT_MENU_SCENES:
		var packed := load(str(check["scene"]))
		if packed == null:
			push_error("Could not load " + str(check["scene"]))
			return false

		var scene = packed.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		audio_manager.play_ui_click()
		await create_timer(0.55).timeout
		await process_frame

		var current_player = scene.get_node_or_null("BackgroundMusic")
		if current_player == null:
			push_error(str(check["label"]) + ": persistent music player missing")
			return false
		if not current_player.playing:
			push_error(str(check["label"]) + ": persistent menu music did not play")
			return false
		if current_player.stream == null:
			push_error(str(check["label"]) + ": persistent menu music has no stream")
			return false
		var position: float = current_player.get_playback_position()
		if previous_saved_position >= 0.0 and position <= previous_saved_position:
			push_error(str(check["label"]) + ": menu music did not resume from stored position")
			return false

		root.remove_child(scene)
		scene.free()
		await process_frame
		var saved_position: float = float(audio_manager.get_menu_music_position())
		if saved_position + 0.001 < position:
			push_error(str(check["label"]) + ": menu music position was not remembered")
			return false
		previous_saved_position = saved_position
	return true

func _check_dialog_click(scene_path: String, label: String) -> bool:
	var packed := load(scene_path)
	if packed == null:
		push_error("Could not load " + scene_path)
		return false

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var body_label: Label = scene.get_node_or_null("StoryBox/MarginContainer/VBoxContainer/BodyLabel")
	if body_label == null:
		push_error(label + ": dialogue body label missing")
		return false

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	if not scene.has_method("_on_dialog_gui_input"):
		push_error(label + ": dialogue click handler missing")
		return false
	scene.call("_on_dialog_gui_input", click)
	await process_frame
	if body_label.visible_characters < body_label.text.length():
		push_error(label + ": click did not advance dialogue typing")
		return false

	root.remove_child(scene)
	scene.free()
	await process_frame
	return true

func _check_music_state(scene: Node, label: String) -> bool:
	var music_player = scene.get_node_or_null("BackgroundMusic")
	if music_player == null:
		push_error(label + ": scene background music player missing")
		return false
	if music_player.bus != "Master":
		push_error(label + ": scene background music should route through Master")
		return false
	if music_player.stream == null:
		push_error(label + ": music player has no stream")
		return false
	if music_player.volume_db < -20.0:
		push_error(label + ": music player volume is too low")
		return false
	if not music_player.playing:
		print(label + ": bus=", music_player.bus, " stream=", music_player.stream, " db=", music_player.volume_db, " pos=", music_player.get_playback_position())
		push_error(label + ": scene background music did not start")
		return false
	return true

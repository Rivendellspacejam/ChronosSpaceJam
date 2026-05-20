extends SceneTree

const CHECKS: Array[Dictionary] = [
	{"scene": "res://scenes/ui/main_menu.tscn", "label": "menu"},
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

	for check in CHECKS:
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

extends SceneTree

const SCENES: Array[String] = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/intro.tscn",
	"res://scenes/game/game_level.tscn",
	"res://scenes/ui/ending.tscn",
	"res://scenes/ui/level_select.tscn",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene_path in SCENES:
		var packed := load(scene_path)
		if packed == null:
			push_error("Could not load scene: " + scene_path)
			quit(1)
			return

		var instance = packed.instantiate()
		if instance == null:
			push_error("Could not instantiate scene: " + scene_path)
			quit(1)
			return

		root.add_child(instance)
		await process_frame
		await process_frame
		root.remove_child(instance)
		instance.free()
		packed = null
		await process_frame
		await process_frame

	var audio_manager = root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.stop_music()

	print("OK Godot smoke scenes")
	call_deferred("quit", 0)

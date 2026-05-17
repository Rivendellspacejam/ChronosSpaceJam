extends Node

const INTRO_LINES: Array[String] = [
	"CHRONOS LAB, 03:17. The clock refuses to move unless you do.",
	"You are the only pilot still linked to the gravity rig.",
	"Every shift bends space. Every shift spends one second of the station's life.",
	"OPERATOR: I can open the test chambers from here. You just need to find the exit path.",
]

const ENDING_LINES: Array[String] = [
	"The final door opens without a sound.",
	"OPERATOR: Signal is clean. The station is moving again.",
	"SYSTEM: Chronos jam resolved. Twelve chambers stabilized.",
	"OPERATOR: Nice work, pilot. Time remembers your direction.",
]

const LEVEL_STORIES: Dictionary = {}

const LEVEL_NAMES: Dictionary = {
	0: "First Shift",
	1: "Pulse Door",
	2: "No Waiting",
	3: "Red Silence",
	4: "Warning Teeth",
	5: "Patrol Memory",
	6: "Bent Hall",
	7: "Doubt Loop",
	8: "Foldback",
	9: "Pressure Route",
	10: "Clock Floor",
	11: "Direction for Time",
}

var _seen_level_stories: Dictionary = {}

func get_intro_lines() -> Array[String]:
	return _to_string_array(INTRO_LINES)

func get_ending_lines() -> Array[String]:
	return _to_string_array(ENDING_LINES)

func get_level_story(level_index: int) -> Array[String]:
	return _to_string_array(LEVEL_STORIES.get(level_index, []))

func get_level_name(level_index: int) -> String:
	return str(LEVEL_NAMES.get(level_index, "Chamber " + str(level_index + 1)))

func should_show_level_story(level_index: int) -> bool:
	return not _seen_level_stories.has(level_index) and not get_level_story(level_index).is_empty()

func mark_level_story_seen(level_index: int) -> void:
	_seen_level_stories[level_index] = true

func _to_string_array(lines: Array) -> Array[String]:
	var typed_lines: Array[String] = []
	for line in lines:
		typed_lines.append(str(line))
	return typed_lines

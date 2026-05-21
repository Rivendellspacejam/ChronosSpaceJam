class_name LevelSelectCard
extends Button

const MEDAL_TEXTURES: Dictionary = {
	"Gold": preload("res://assets/first-gold.png"),
	"Silver": preload("res://assets/second-silver.png"),
	"Bronze": preload("res://assets/third-bronze.png"),
}

const MEDAL_COLORS: Dictionary = {
	"Gold": Color(1, 0.85, 0.2, 1),
	"Silver": Color(0.75, 0.85, 0.95, 1),
	"Bronze": Color(0.85, 0.45, 0.18, 1),
}

@onready var number_label: Label = $Content/NumberLabel
@onready var name_label: Label = $Content/NameLabel
@onready var medal_icon: TextureRect = $Content/MedalIcon

func setup(level_index: int, is_unlocked: bool, is_completed: bool, level_name: String, medal: String) -> void:
	disabled = not is_unlocked
	number_label.text = str(level_index + 1)
	name_label.text = level_name if is_unlocked else "LOCKED"

	if not is_unlocked:
		medal_icon.visible = false
		number_label.add_theme_color_override("font_color", Color(0.42, 0.48, 0.58, 0.9))
		name_label.add_theme_color_override("font_color", Color(0.42, 0.48, 0.58, 0.9))
		return

	number_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1, 1))
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1))
	medal_icon.visible = is_completed and MEDAL_TEXTURES.has(medal)
	if medal_icon.visible:
		medal_icon.texture = MEDAL_TEXTURES[medal]

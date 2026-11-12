## Lists GameConfig.levels with stars / lock state and starts the chosen level.
##
## Dependencies: Profile, SceneManager autoloads, LevelBase.start_level
extends Control

const LEVEL_CARD: PackedScene = preload("res://Scenes/Menus/LevelSelect/LevelCard.tscn")

@onready var _level_list: VBoxContainer = %LevelList
@onready var _stars_label: IconLabel = %StarsLabel


func _ready() -> void:
	var config: GameConfig = GameConfig.get_default()
	_stars_label.text = str(Profile.levels.get_total_stars())
	for level_index: int in config.levels.size():
		var level: LevelData = config.levels[level_index]
		var card: LevelCard = LEVEL_CARD.instantiate() as LevelCard
		_level_list.add_child(card)
		card.setup(level, level_index + 1, Profile.levels.is_unlocked(level), Profile.levels.get_stars(level.id), Profile.levels.get_best_score(level.id))
		card.level_chosen.connect(_on_level_chosen)
		card.modulate.a = 0.0
		var tween: Tween = card.create_tween()
		tween.tween_interval(0.04 * level_index)
		tween.tween_property(card, "modulate:a", 1.0 if Profile.levels.is_unlocked(level) else 0.55, 0.2)


func _on_level_chosen(level: LevelData) -> void:
	LevelBase.start_level(level)


func _on_back_button_pressed() -> void:
	if not SceneManager.go_back():
		SceneManager.go_to_main_menu()

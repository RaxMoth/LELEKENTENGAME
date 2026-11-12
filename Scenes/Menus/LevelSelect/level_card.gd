## One entry in the level list: number, title, description, stars or lock.
## The whole card is a Button so it gets the global press feedback.
##
## Dependencies: StarsDisplay
class_name LevelCard
extends Button

signal level_chosen(level: LevelData)

var level: LevelData

@onready var _index_label: Label = %IndexLabel
@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _stars_display: StarsDisplay = %StarsDisplay
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _best_label: Label = %BestLabel


func setup(level_definition: LevelData, level_number: int, is_unlocked: bool, earned_stars: int, best_score: int) -> void:
	level = level_definition
	_index_label.text = str(level_number)
	_title_label.text = level.title
	_description_label.text = level.description
	_description_label.visible = not level.description.is_empty()
	_stars_display.set_stars(earned_stars)
	_stars_display.visible = is_unlocked
	_lock_icon.visible = not is_unlocked
	_best_label.visible = is_unlocked and best_score > 0
	_best_label.text = "%s: %s" % [tr("Best"), NumberFormat.compact(best_score)]
	disabled = not is_unlocked
	modulate.a = 1.0 if is_unlocked else 0.55


func _pressed() -> void:
	level_chosen.emit(level)

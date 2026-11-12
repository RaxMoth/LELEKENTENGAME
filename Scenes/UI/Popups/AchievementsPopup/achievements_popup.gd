## Lists every achievement from GameConfig with its progress.
##
## Dependencies: BasePopup, Profile autoload
class_name AchievementsPopup
extends BasePopup

@onready var _list: VBoxContainer = %AchievementList
@onready var _summary_label: Label = %SummaryLabel


func _on_opened(_data: Dictionary) -> void:
	var achievements: Array[AchievementData] = GameConfig.get_default().achievements
	_summary_label.text = "%d / %d" % [Profile.achievements.get_unlocked_count(), achievements.size()]
	for achievement: AchievementData in achievements:
		var is_unlocked: bool = Profile.achievements.is_unlocked(achievement.id)
		if achievement.hidden_until_unlocked and not is_unlocked:
			continue
		_list.add_child(_create_row(achievement, is_unlocked))


func _create_row(achievement: AchievementData, is_unlocked: bool) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var title_label: Label = Label.new()
	title_label.text = ("✓ " if is_unlocked else "") + achievement.title
	if is_unlocked:
		title_label.add_theme_color_override("font_color", Palette.SUCCESS)
	column.add_child(title_label)
	var description_label: Label = Label.new()
	description_label.theme_type_variation = &"SmallLabel"
	description_label.text = achievement.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description_label)
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 18
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	progress_bar.value = Profile.achievements.get_progress_ratio(achievement)
	column.add_child(progress_bar)
	return card


func _on_close_button_pressed() -> void:
	close(null)

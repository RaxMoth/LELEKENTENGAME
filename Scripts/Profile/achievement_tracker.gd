## Unlocks AchievementData entries when their statistic reaches the target.
##
## Dependencies: Events, Profile autoloads
class_name AchievementTracker
extends ProfileModule

## achievement id -> unix time of unlock
var _unlocked: Dictionary[StringName, int] = {}


func _init(game_config: GameConfig) -> void:
	super(game_config)
	Events.stat_changed.connect(_on_stat_changed)


func get_save_key() -> StringName:
	return &"achievements"


func to_dict() -> Dictionary:
	return _unlocked


func from_dict(data: Dictionary) -> void:
	_unlocked = to_int_dictionary(data)


func reset() -> void:
	_unlocked = {}


func is_unlocked(achievement_id: StringName) -> bool:
	return _unlocked.has(achievement_id)


func get_progress_ratio(achievement: AchievementData) -> float:
	if is_unlocked(achievement.id):
		return 1.0
	return clampf(Profile.stats.get_value(achievement.stat_id) / maxf(achievement.target_value, 0.0001), 0.0, 1.0)


func get_unlocked_count() -> int:
	return _unlocked.size()


func _on_stat_changed(stat_id: StringName, new_value: float) -> void:
	for achievement: AchievementData in config.achievements:
		if achievement.stat_id == stat_id and new_value >= achievement.target_value and not is_unlocked(achievement.id):
			_unlock(achievement)


func _unlock(achievement: AchievementData) -> void:
	_unlocked[achievement.id] = Global.unix_now()
	mark_dirty()
	Profile.grant_rewards(achievement.rewards)
	Events.achievement_unlocked.emit(achievement)

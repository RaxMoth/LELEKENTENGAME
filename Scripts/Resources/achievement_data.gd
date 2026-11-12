## Achievement unlocked when a Profile statistic reaches a target value.
##
## Dependencies: none
class_name AchievementData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Statistic id tracked by Profile.stats (see Types.STAT_*).
@export var stat_id: StringName = &""
@export var target_value: float = 1.0
@export var rewards: Dictionary[StringName, int] = {}
@export var hidden_until_unlocked: bool = false

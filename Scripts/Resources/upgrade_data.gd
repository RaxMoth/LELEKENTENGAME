## Persistent upgrade bought with currency (shop upgrades, idle generators...).
## Cost grows geometrically per level; value grows linearly per level.
##
## Dependencies: none
class_name UpgradeData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var currency_id: StringName = &"coins"
@export var base_cost: int = 10
@export var cost_growth: float = 1.15
## 0 = unlimited.
@export var max_level: int = 0
@export var base_value: float = 0.0
@export var value_per_level: float = 1.0
## Format for displaying the value, e.g. "+%s/s" or "x%s".
@export var value_format: String = "%s"
## Listed in the global Shop scene (disable for upgrades a game mode shows itself).
@export var show_in_shop: bool = true


func get_cost(current_level: int) -> int:
	return int(round(base_cost * pow(cost_growth, current_level)))


func get_value(current_level: int) -> float:
	return base_value + value_per_level * current_level


func is_maxed(current_level: int) -> bool:
	return max_level > 0 and current_level >= max_level

## Persistent upgrade bought with cash in the office or the Shop (e.g.
## "Bigger Batches": more units per press run). Levels read the current value with
## Profile.upgrades.get_value(upgrade).
## Cost grows geometrically per level; value grows linearly per level.
##
## Dependencies: none
class_name UpgradeData
extends Resource

## Progression branches in display order (UpgradeData.branch values).
const BRANCHES: Array[StringName] = [&"production", &"sales", &"defense", &"workforce", &"house"]
const BRANCH_TITLES: Dictionary[StringName, String] = {
	&"production": "Production",
	&"sales": "Sales",
	&"defense": "Defense",
	&"workforce": "Workforce",
	&"house": "House",
}

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var currency_id: StringName = &"cash"
@export var base_cost: int = 10
@export var cost_growth: float = 1.15
## 0 = unlimited.
@export var max_level: int = 0
@export var base_value: float = 0.0
@export var value_per_level: float = 1.0
## Format for displaying the value, e.g. "+%s units" (empty = show the level only).
@export var value_format: String = "%s"
## Listed in the global Shop scene (disable for upgrades a game mode shows itself).
@export var show_in_shop: bool = true
## Progression branch it belongs to (production, sales, defense, workforce, house).
@export var branch: StringName = &""
## Reputation needed before it can be bought.
@export var required_reputation: int = 0


func get_cost(current_level: int) -> int:
	return int(round(base_cost * pow(cost_growth, current_level)))


func get_value(current_level: int) -> float:
	return base_value + value_per_level * current_level


func is_maxed(current_level: int) -> bool:
	return max_level > 0 and current_level >= max_level


static func get_branch_title(branch_id: StringName) -> String:
	return BRANCH_TITLES.get(branch_id, String(branch_id).capitalize())

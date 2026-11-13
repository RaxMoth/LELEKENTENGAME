## Stages the house after every renovation and the upgrades that change its
## look (Reinforced Door, Steel Door Frame, Bigger Stash) at their top level,
## with a stocked stash: the well-kept old house a long-running operation
## ends up in. house_patched_showcase.gd shows the step in between.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_renovated`.
##
## Dependencies: HouseLevel, Operation, GameConfig, Profile, Types autoloads
extends RefCounted

## Every upgrade that changes how the house looks.
const LOOK_UPGRADES: Array[StringName] = [Types.UPGRADE_HOUSE_EXTENSION, Types.UPGRADE_RENOVATE_WALLS, Types.UPGRADE_RENOVATE_FLOOR, Types.UPGRADE_RENOVATE_FACADE, Types.UPGRADE_RENOVATE_ROOF, Types.UPGRADE_DOOR, Types.UPGRADE_SECURITY, Types.UPGRADE_STORAGE]


static func apply(scene: Node) -> void:
	apply_levels(scene, 99)


## Sets every look upgrade to [param level] (capped at its max level) and
## fills the stash a bit, so the shelves show.
static func apply_levels(scene: Node, level: int) -> void:
	var house: HouseLevel = scene as HouseLevel
	var config: GameConfig = GameConfig.get_default()
	var levels: Dictionary = Profile.upgrades.to_dict().duplicate()
	for upgrade_id: StringName in LOOK_UPGRADES:
		levels[upgrade_id] = mini(level, config.find_upgrade(upgrade_id).max_level)
	Profile.upgrades.from_dict(levels)
	house.apply_upgrades()
	var operation: Operation = house.operation
	operation.add_product(operation.recipes[0], 3, 14)

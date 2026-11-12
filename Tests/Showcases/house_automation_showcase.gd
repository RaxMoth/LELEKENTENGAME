## Stages a late-game, automated house: the cellar dug with three grow
## racks under grow lights and the auto picker, motors on every station,
## conveyor belts, the ingredient hopper and the perks; the racks' plants
## at different stages, some ripe. house_cellar_showcase.gd puts the player
## down in the cellar.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_automation`.
##
## Dependencies: HouseLevel, Cellar, ShroomPlant, GameConfig, Profile, Types autoloads
extends RefCounted

## Every upgrade the shot shows (at its top level).
const SHOWN_UPGRADES: Array[StringName] = [Types.UPGRADE_PLANTS, Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER, Types.UPGRADE_PRESS, Types.UPGRADE_CELLAR, Types.UPGRADE_GROW_RACKS, Types.UPGRADE_GROW_LIGHTS, Types.UPGRADE_AUTO_PICKER, Types.UPGRADE_GRINDER_MOTOR, Types.UPGRADE_COOKER_MOTOR, Types.UPGRADE_PRESS_MOTOR, Types.UPGRADE_CONVEYOR, Types.UPGRADE_HOPPER, Types.UPGRADE_SHOES, Types.UPGRADE_STORAGE]


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var config: GameConfig = GameConfig.get_default()
	var levels: Dictionary = Profile.upgrades.to_dict().duplicate()
	for upgrade_id: StringName in SHOWN_UPGRADES:
		levels[upgrade_id] = config.find_upgrade(upgrade_id).max_level
	Profile.upgrades.from_dict(levels)
	level.apply_upgrades()
	var cellar: Cellar = level.get_front(Cellar) as Cellar
	var plants: Array[ShroomPlant] = cellar.get_plants()
	for plant_index: int in plants.size():
		# A mix of seedlings, half-grown and ripe plants.
		plants[plant_index].grow(plants[plant_index].grow_seconds * float(plant_index % 4) / 3.0)

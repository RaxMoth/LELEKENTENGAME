## Trouble in the lab: a batch left on the cooker has caught fire (flames,
## smoke) next to the extinguisher on the wall.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_fire`.
##
## Dependencies: HouseLevel, Lab, StationFire, Workstation, BatchItem, Pools, Profile
extends RefCounted

const BATCH_SCENE: PackedScene = preload("res://Scenes/Levels/House/Lab/BatchItem.tscn")


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var lab: Lab = level.get_front(Lab) as Lab
	var config: GameConfig = GameConfig.get_default()
	Profile.wallet.add(Types.CURRENCY_CASH, 1000)
	for upgrade_id: StringName in [Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER]:
		Profile.upgrades.purchase(config.find_upgrade(upgrade_id))
	level.apply_upgrades()
	var tray: ItemSocket = lab.get_station(&"Cooker").get_output_socket()
	var batch: BatchItem = Pools.spawn(BATCH_SCENE, Global.get_world_root(), tray.global_position) as BatchItem
	var accuracies: Array[float] = [0.8]
	batch.setup(level.operation.find_recipe(&"glow"), accuracies)
	batch.home_socket = tray
	tray.insert(batch)
	var fire: StationFire = lab.get_fire()
	fire.step(fire.ignite_seconds + 1.0)

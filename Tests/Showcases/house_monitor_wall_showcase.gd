## The office's monitor wall: four big screens with live views of the roof
## turrets and field towers (Security PC and Monitor Wall bought, towers built).
## Loaded by Tests/screenshot_tool.gd with `showcase=house_monitor_wall`.
##
## Dependencies: HouseLevel, FrontGarden, TowerField, Office
extends RefCounted

const TOWERS_SHOWCASE: Script = preload("res://Tests/Showcases/house_towers_showcase.gd")


static func apply(scene: Node) -> void:
	TOWERS_SHOWCASE.call("apply", scene)
	var level: HouseLevel = scene as HouseLevel
	var config: GameConfig = GameConfig.get_default()
	Profile.wallet.add(Types.CURRENCY_CASH, 20000)
	Profile.operation.add_reputation(100)
	for upgrade_id: StringName in [&"house_extension", Types.UPGRADE_TURRETS, Types.UPGRADE_SECURITY_PC, Types.UPGRADE_MONITOR_WALL]:
		Profile.upgrades.purchase(config.find_upgrade(upgrade_id))
	level.apply_upgrades()

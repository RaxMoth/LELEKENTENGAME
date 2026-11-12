## Stages a busy moment at the house for screenshots: raiders of every kind
## crossing the yard (cops in cover, SWAT, a battering ram), roof turrets,
## customers queuing at the back window, a station running in the lab, a
## stocked stash and hired crew.
## Loaded by Tests/screenshot_tool.gd with `showcase=house`.
##
## Dependencies: HouseLevel and its fronts (FrontGarden, SalesWindow, Lab), Yard, Raider
extends RefCounted

const COP: PackedScene = preload("res://Scenes/Levels/House/Garden/Cop.tscn")
const SWAT: PackedScene = preload("res://Scenes/Levels/House/Garden/Swat.tscn")
const RAM_TEAM: PackedScene = preload("res://Scenes/Levels/House/Garden/RamTeam.tscn")
const CUSTOMER_TYPES: Array[String] = ["regular", "connoisseur", "haggler", "bulk_buyer"]
## Where the staged raiders stand (x, z, facing the house).
const RAIDER_SPOTS: Array[Vector2] = [Vector2(-3.5, -12.5), Vector2(1.8, -12.7), Vector2(4.4, -14.2), Vector2(-0.8, -14.2), Vector2(-6.4, -13.4), Vector2(0.2, -9.5), Vector2(3.0, -18.2)]


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var operation: Operation = level.operation
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	var lab: Lab = level.get_front(Lab) as Lab
	garden.director.is_active = false
	window.flow.is_active = false
	Profile.wallet.add(Types.CURRENCY_CASH, 4000)
	Profile.operation.add_reputation(60)
	var config: GameConfig = GameConfig.get_default()
	for upgrade_id: StringName in [Types.UPGRADE_CRAFTER, Types.UPGRADE_DEALER, Types.UPGRADE_GUARD, Types.UPGRADE_GUARD, Types.UPGRADE_TURRETS, Types.UPGRADE_TURRETS, Types.UPGRADE_TURRETS, Types.UPGRADE_SECURITY_PC, Types.UPGRADE_RECIPE_FIZZ]:
		Profile.upgrades.purchase(config.find_upgrade(upgrade_id))
	# One product already cooked: the recipe book shows a found and a hidden entry.
	Profile.operation.discover_recipe(&"glow")
	level.apply_upgrades()
	var raider_scenes: Array[PackedScene] = [COP, COP, SWAT, COP, SWAT, RAM_TEAM, COP]
	for raider_index: int in raider_scenes.size():
		var raider: Raider = garden.director.spawn_raider(raider_scenes[raider_index])
		var spot: Vector2 = RAIDER_SPOTS[raider_index]
		raider.global_position = Vector3(spot.x, 0.0, spot.y)
		raider.rotation.y = atan2(-spot.x, -5.0 - spot.y)
		raider.freeze()
	# Hold the turrets still for the picture (they would clear the yard).
	for turret: HouseTurret in garden.get_turrets():
		turret.set_manual(true)
	var recipes: Array[RecipeData] = operation.get_unlocked_recipes()
	operation.add_product(recipes[0], 3, 9)
	operation.add_product(recipes[1], 4, 5)
	operation.add_product(recipes[0], 2, 4)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 11
	for type_name: String in CUSTOMER_TYPES:
		var customer_type: CustomerTypeData = load("res://Ressources/Customers/%s.tres" % type_name) as CustomerTypeData
		window.spawn_customer(customer_type.create_order(recipes, random))
	lab.get_station(&"Grinder").get_input_sockets()[0].insert(lab.get_crate(&"glowcap").take_item())

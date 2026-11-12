## Stages a busy moment at the house for screenshots: towers and attackers of
## every faction in the garden, customers queuing at the back window, a
## station running in the lab, a stocked stash and hired crew.
## Loaded by Tests/screenshot_tool.gd with `showcase=house`.
##
## Dependencies: HouseLevel and its fronts (FrontGarden, SalesWindow, Lab)
extends RefCounted

const JUNKIE: PackedScene = preload("res://Scenes/Levels/House/Garden/Junkie.tscn")
const COP: PackedScene = preload("res://Scenes/Levels/House/Garden/Cop.tscn")
const GOON: PackedScene = preload("res://Scenes/Levels/House/Garden/Goon.tscn")
const BOSS: PackedScene = preload("res://Scenes/Levels/House/Garden/Boss.tscn")
const TURRET: TowerData = preload("res://Ressources/Towers/turret.tres")
const HEAVY_GUN: TowerData = preload("res://Ressources/Towers/heavy_gun.tres")
const BARRICADE: TowerData = preload("res://Ressources/Towers/barricade.tres")
const CUSTOMER_TYPES: Array[String] = ["regular", "connoisseur", "haggler", "bulk_buyer"]


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var operation: Operation = level.operation
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	var lab: Lab = level.get_front(Lab) as Lab
	var board: LaneBoard = garden.board
	garden.director.is_active = false
	window.flow.is_active = false
	Profile.wallet.add(Types.CURRENCY_CASH, 4000)
	Profile.operation.add_reputation(60)
	var config: GameConfig = GameConfig.get_default()
	for upgrade_id: StringName in [Types.UPGRADE_CRAFTER, Types.UPGRADE_DEALER, Types.UPGRADE_GUARD, Types.UPGRADE_GUARD, Types.UPGRADE_HEAVY_GUN, Types.UPGRADE_RECIPE_FIZZ]:
		Profile.upgrades.purchase(config.find_upgrade(upgrade_id))
	level.apply_upgrades()
	for lane: int in board.lane_count:
		board.place_tower(TURRET, Vector2i(lane, 0))
	board.place_tower(HEAVY_GUN, Vector2i(1, 1))
	board.place_tower(BARRICADE, Vector2i(0, 2))
	board.place_tower(BARRICADE, Vector2i(2, 2))
	var attackers: Array[PackedScene] = [JUNKIE, COP, JUNKIE, GOON, BOSS, JUNKIE, COP]
	for attacker_index: int in attackers.size():
		var enemy: LaneEnemy = board.spawn_enemy(attackers[attacker_index])
		enemy.global_position.z = board.grid.get_column_z(5) - (attacker_index % 4) * 0.9 + attacker_index * 0.35
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

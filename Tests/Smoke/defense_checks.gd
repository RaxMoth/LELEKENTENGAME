## Smoke checks of the defense front: the build board, building, turrets,
## the blaster, attackers at the door, theft, raids, the boss wave and
## guards. Owned by whoever works on the FrontGarden.
##
## Dependencies: SmokeTest, HouseLevel, FrontGarden, Office, LaneBoard, LaneEnemy
class_name DefenseSmokeChecks
extends RefCounted

const JUNKIE: String = "res://Scenes/Levels/House/Garden/Junkie.tscn"
const COP: String = "res://Scenes/Levels/House/Garden/Cop.tscn"
const GOON: String = "res://Scenes/Levels/House/Garden/Goon.tscn"


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var operation: Operation = level.operation
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var board: LaneBoard = garden.board
	var door: FrontDoor = garden.door
	rig.locomotion.travel_to_spot(1)
	test.check(garden.is_in_defense_zone(), "the front room is the defense position")

	var build_screen: WorldScreen = garden.get_build_screen()
	rig.tap_world_point(build_screen.pixel_to_world(garden.get_build_board().get_card_center(0)))
	await test.frames(3)
	test.check(garden.selected_tower == 0, "pointer picks a tower card on the board above the gate")
	var cash_before: int = operation.get_cash()
	var cell: Vector2i = Vector2i(1, 2)
	rig.tap_world_point(board.grid.cell_to_position(cell))
	await test.frames(3)
	test.check(not board.can_place(cell) and operation.get_cash() < cash_before, "clicking a garden tile builds the tower for cash")

	var junkie: LaneEnemy = _spawn_in_lane(board, JUNKIE, cell.x, board.grid.get_column_z(5))
	test.check(await test.wait_until(func() -> bool: return junkie.health_component.get_health_ratio() < 1.0 or not junkie.is_alive()), "the turret shoots the attacker in its lane")
	var cop: LaneEnemy = _spawn_in_lane(board, COP, 0, board.grid.get_column_z(4))
	var cop_health: float = cop.health_component.current_health
	await test.frames(20)
	rig.tap_world_point(cop.get_hit_center())
	await test.frames(3)
	test.check(cop.health_component.current_health < cop_health, "clicking an attacker fires the blaster")
	cop.global_position.z = board.get_home_z() - 0.5
	var door_health: float = door.health_component.current_health
	test.check(await test.wait_until(func() -> bool: return door.health_component.current_health < door_health), "an attacker at the door breaks it down")

	operation.add_product(operation.recipes[0], 2, 4)
	var stock_before: int = operation.stash.get_total()
	_spawn_in_lane(board, JUNKIE, 2, board.get_home_z() - 0.4)
	test.check(await test.wait_until(func() -> bool: return operation.stash.get_total() < stock_before), "a junkie reaching the door steals stock")
	cop.take_hit(100000.0)
	door.health_component.heal(100000.0)

	operation.add_heat(60.0)
	garden.director.is_active = true
	garden.director.step(0.01)
	garden.director.is_active = false
	test.check(garden.director.get_pending_spawn_count() > 0, "high heat sends a police raid")
	var pending_before_boss: int = garden.director.get_pending_spawn_count()
	garden.director.start_boss_wave()
	test.check(garden.director.get_pending_spawn_count() - pending_before_boss == 4, "the boss wave brings the boss and three escorts")

	# Crew: a hired guard shoots attackers near the door.
	Profile.operation.add_reputation(100)
	(level.get_front(Office) as Office).buy_upgrade(GameConfig.get_default().find_upgrade(Types.UPGRADE_GUARD))
	await test.frames(3)
	var guard: Worker = garden.get_node("%Guards").get_child(0) as Worker
	var goon: LaneEnemy = _spawn_in_lane(board, GOON, 0, board.get_home_z() - 2.0)
	var goon_health: float = goon.health_component.current_health
	guard.work_now()
	test.check(guard.is_working() and goon.health_component.current_health < goon_health, "a hired guard shoots attackers near the door")
	goon.take_hit(100000.0)


## Spawns an attacker and moves it into a chosen lane and depth.
static func _spawn_in_lane(board: LaneBoard, scene_path: String, lane: int, z: float) -> LaneEnemy:
	var enemy: LaneEnemy = board.spawn_enemy(load(scene_path) as PackedScene)
	enemy.enter_lane(board, lane)
	enemy.global_position.x = board.grid.get_lane_x(lane)
	enemy.global_position.z = z
	return enemy

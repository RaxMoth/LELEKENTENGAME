## Smoke checks of the cellar and the automation tab (house area): the
## boarded-up opening, digging the cellar and walking down its stairs, grow
## racks and grow lights, the Green Thumb and Running Shoes perks, the auto
## picker, station motors, conveyor belts and the ingredient hopper running
## a batch through the lab on their own.
## Runs after the lab's checks (the grinder, cooker and press are bought).
## Takes the machines back out at the end, so the later checks find a lab
## and stash that only change when they change them.
##
## Dependencies: SmokeTest, HouseLevel, Cellar, Lab, LabAutomation, Office, AutoPicker,
##               GrowRack, ShroomPlant, Workstation, ItemSocket, WalkableArea, GameConfig,
##               Profile, Pools, Types autoloads
class_name CellarSmokeChecks
extends RefCounted

## A spot on the stash-room floor over the boarded-up opening.
const OVER_THE_OPENING: Vector3 = Vector3(2.6, 0.0, 2.1)
## A spot on the cellar floor.
const CELLAR_SPOT: Vector3 = Vector3(2.6, -2.6, 0.0)
## Upgrades that work on their own (taken back out after the checks).
const MACHINES: Array[StringName] = [Types.UPGRADE_GROW_RACKS, Types.UPGRADE_GROW_LIGHTS, Types.UPGRADE_AUTO_PICKER, Types.UPGRADE_GRINDER_MOTOR, Types.UPGRADE_COOKER_MOTOR, Types.UPGRADE_PRESS_MOTOR, Types.UPGRADE_CONVEYOR, Types.UPGRADE_HOPPER]


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var cellar: Cellar = level.get_front(Cellar) as Cellar
	var walkable: WalkableArea = level.rig.walkable_area
	test.check(cellar != null and not cellar.is_open() and walkable.contains(OVER_THE_OPENING), "the cellar starts boarded up: the stash-room floor is solid there")
	test.check(not walkable.contains(CELLAR_SPOT), "no cellar floor before it is dug")
	var office: Office = level.get_front(Office) as Office
	_buy(office, Types.UPGRADE_CELLAR)
	await test.frames(2)
	test.check(cellar.is_open() and not walkable.contains(OVER_THE_OPENING) and walkable.contains(CELLAR_SPOT), "Dig the Cellar opens the stairwell and the cellar floor")
	var opening: Rect2 = cellar.get_opening()
	var is_floor_cut: bool = level.get_house_shell().floor_openings.any(func(cut: Rect2) -> bool: return cut.is_equal_approx(opening))
	var is_ceiling_cut: bool = cellar.get_cellar_shell().ceiling_openings.any(func(cut: Rect2) -> bool: return cut.is_equal_approx(opening))
	test.check(is_floor_cut and is_ceiling_cut and opening.encloses(cellar.stairwell_hole), "the stairwell is cut in the same place in the house floor, the ground and the cellar ceiling")
	await _check_stairs(test, level)
	await _check_racks(test, level, cellar, office)
	await _check_lab_automation(test, level, office)
	var speed_before: float = level.rig.locomotion.speed_multiplier
	_buy(office, Types.UPGRADE_SHOES)
	test.check(level.rig.locomotion.speed_multiplier > speed_before, "Running Shoes make the player walk faster")
	level.rig.locomotion.travel_to_spot(0)
	test.check(absf(level.rig.get_feet_position().y) < 0.01, "quick travel brings the player back up from the cellar")
	var levels: Dictionary = Profile.upgrades.to_dict().duplicate()
	for upgrade_id: StringName in MACHINES:
		levels.erase(upgrade_id)
	Profile.upgrades.from_dict(levels)
	level.apply_upgrades()


## Walks onto the top step and down the stairs with the flat simulator's keys.
static func _check_stairs(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	# By the opening's open end, facing it (-Z), then down the stairs (+X).
	rig.locomotion.teleport_to(Vector3(1.15, 0.0, 2.9), 0.0)
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	for frame_index: int in 90:
		await test.physics_frames(1)
		if rig.get_feet_position().z < 2.2:
			break
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	await test.physics_frames(10)
	test.check(rig.get_feet_position().z < 2.35 and rig.get_feet_position().z > 1.9, "the player steps onto the top of the stairs")
	# Let the walk settle, then head down the middle of the steps (+X).
	await test.physics_frames(40)
	var top: Vector3 = rig.get_feet_position()
	rig.locomotion.teleport_to(Vector3(top.x, top.y, 2.12), -PI * 0.5)
	await _walk_forward(test, 150)
	var feet: Vector3 = rig.get_feet_position()
	test.check(feet.x > 4.0 and absf(feet.y - CELLAR_SPOT.y) < 0.15, "walking down the stairs takes the player into the cellar")
	var near: Node3D = level.get_front(Cellar).get_node("%Near") as Node3D
	await test.frames(20)
	test.check(near.visible, "the cellar is drawn while the player is down there")
	rig.locomotion.travel_to_spot(0)
	await test.frames(20)
	test.check(not near.visible, "and not while the player is in the lab")
	rig.locomotion.teleport_to(feet)


static func _check_racks(test: SmokeTest, level: HouseLevel, cellar: Cellar, office: Office) -> void:
	var operation: Operation = level.operation
	var racks: Array[GrowRack] = cellar.get_racks()
	test.check(racks.all(func(rack: GrowRack) -> bool: return not rack.is_active()), "no grow racks before they are bought")
	_buy(office, Types.UPGRADE_GROW_RACKS)
	var rack: GrowRack = racks[0]
	test.check(rack.is_active() and not racks[1].is_active() and rack.get_plants().all(func(plant: ShroomPlant) -> bool: return plant.is_active()), "Grow Racks puts a rack of four plants in the cellar")
	var plant: ShroomPlant = rack.get_plants()[0]
	var growth_before: float = plant.growth_multiplier
	_buy(office, Types.UPGRADE_GROW_LIGHTS)
	test.check(plant.growth_multiplier > growth_before, "Grow Lights make the cellar plants grow faster")
	if operation.stash.get_free_space() < 16:
		_buy(office, Types.UPGRADE_STORAGE)
	_buy(office, Types.UPGRADE_GREEN_THUMB)
	plant.grow(plant.grow_seconds)
	var shrooms_before: int = operation.stash.count(&"shroom")
	var picked: ProductBag = plant.pick()
	test.check(picked != null and picked.units == operation.get_batch_size(plant.crop) + 1 and operation.stash.count(&"shroom") == shrooms_before, "Green Thumb: one more shroom in the bag from a plant picked by hand")
	if picked != null:
		Pools.despawn(picked)
	_buy(office, Types.UPGRADE_AUTO_PICKER)
	var picker: AutoPicker = cellar.get_picker()
	test.check(picker.visible, "Auto Picker mounts a picker under the cellar ceiling")
	# Quicker than in play, so the check doesn't wait.
	picker.move_speed = 6.0
	picker.set_pick_seconds(0.3)
	var target: ShroomPlant = rack.get_plants()[1]
	target.grow(target.grow_seconds)
	shrooms_before = operation.stash.count(&"shroom")
	test.check(await test.wait_until(func() -> bool: return not target.is_ripe() and operation.stash.count(&"shroom") > shrooms_before), "the auto picker harvests a ripe plant on its own")


static func _check_lab_automation(test: SmokeTest, level: HouseLevel, office: Office) -> void:
	var lab: Lab = level.get_front(Lab) as Lab
	var operation: Operation = level.operation
	var grinder: Workstation = lab.get_station(&"Grinder")
	var cooker: Workstation = lab.get_station(&"Cooker")
	var press: Workstation = lab.get_station(&"Press")
	# The stations themselves come from the lab area's checks; buy them if they didn't run.
	for gadget_id: StringName in [Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER, Types.UPGRADE_PRESS]:
		if not Profile.upgrades.is_owned(gadget_id):
			_buy(office, gadget_id)
	for station: Workstation in [grinder, cooker, press]:
		_clear(station)
	_buy(office, Types.UPGRADE_GRINDER_MOTOR)
	test.check(grinder.is_motorized() and not cooker.is_motorized(), "Grinder Motor fits a motor to the grinder")
	for station: Workstation in [grinder, cooker, press]:
		station.motor_seconds = 0.2
		# Jams are checked with the crafter (lab_checks); here the line must run through.
		station.jam_chance = 0.0
	var glowcap: Grabbable = lab.get_crate(&"glowcap").take_item()
	grinder.get_input_sockets()[0].insert(glowcap)
	test.check(await test.wait_until(func() -> bool: return not grinder.get_output_socket().is_empty()), "the motor finishes the grinder's skill check on its own")
	_buy(office, Types.UPGRADE_COOKER_MOTOR)
	_buy(office, Types.UPGRADE_PRESS_MOTOR)
	_buy(office, Types.UPGRADE_CONVEYOR)
	var automation: LabAutomation = lab.get_automation()
	automation.travel_speed = 8.0
	test.check(await test.wait_until(func() -> bool: return grinder.get_output_socket().is_empty() and _holds(cooker, &"glowcap")), "the conveyor belt carries the ground glowcap into the cooker")
	if operation.stash.get_free_space() < 8:
		_buy(office, Types.UPGRADE_STORAGE)
	_buy(office, Types.UPGRADE_HOPPER)
	automation.hopper_recipe = _find_recipe(lab, &"glow")
	test.check(await test.wait_until(func() -> bool: return press.get_output_socket().item is ProductBag and (press.get_output_socket().item as ProductBag).recipe.id == &"glow"), "with motors, belts and the hopper the lab packs a bag of Glow on its own (somebody still carries it to the stash)")
	# Let the last item land, then leave the stations empty.
	automation.set_parts(false, false)
	await test.wait_until(func() -> bool: return not automation.is_moving() and not grinder.is_running() and not cooker.is_running() and not press.is_running())
	for station: Workstation in [grinder, cooker, press]:
		_clear(station)


## Buys [param upgrade_id] at the office with cash added for it (the checks
## before may have spent the budget).
static func _buy(office: Office, upgrade_id: StringName) -> void:
	var upgrade: UpgradeData = GameConfig.get_default().find_upgrade(upgrade_id)
	Profile.wallet.add(Types.CURRENCY_CASH, Profile.upgrades.get_next_cost(upgrade), false)
	office.buy_upgrade(upgrade)


static func _walk_forward(test: SmokeTest, physics_frames: int) -> void:
	Input.action_press(Types.ACTION_MOVE_FORWARD)
	await test.physics_frames(physics_frames)
	Input.action_release(Types.ACTION_MOVE_FORWARD)
	await test.physics_frames(10)


## True when an input slot of [param station] holds the ingredient [param ingredient_id].
static func _holds(station: Workstation, ingredient_id: StringName) -> bool:
	for socket: ItemSocket in station.get_input_sockets():
		var ingredient: IngredientItem = socket.item as IngredientItem
		if ingredient != null and ingredient.data.id == ingredient_id:
			return true
	return false


static func _clear(station: Workstation) -> void:
	var sockets: Array[ItemSocket] = station.get_input_sockets()
	sockets.append(station.get_output_socket())
	for socket: ItemSocket in sockets:
		var item: Grabbable = socket.remove_item()
		if item != null:
			Pools.despawn(item)


static func _find_recipe(lab: Lab, recipe_id: StringName) -> RecipeData:
	for recipe: RecipeData in lab.recipes:
		if recipe.id == recipe_id:
			return recipe
	return null

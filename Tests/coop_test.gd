## Two-player co-op test: one copy of the game hosts the House, a second
## copy joins over the network (127.0.0.1) and plays a few steps; each copy
## checks its side. Run both with Tools/coop_test.sh (exit 0 = both passed).
##
##   godot --headless res://Tests/CoopTest.tscn -- role=host port=17777
##   godot --headless res://Tests/CoopTest.tscn -- role=guest port=17777
##
## The guest buys an ingredient with its (forwarded) click and puts it into
## the grinder; the host must see the guest, carry out both in its world and
## pay from the shared cash; the guest must see the item in its own hand,
## the shared cash and the grinder running.
##
## Dependencies: Coop, HouseLevel, HouseCoopSync, Lab, Workstation,
##               IngredientCrate, SceneManager, Profile autoloads
extends Node

const HOUSE_SCENE: String = "res://Scenes/Levels/House/House.tscn"
const TIMEOUT_MSEC: int = 30000
const LAB_SPOT: int = 0
const FRONT_SPOT: int = 1
const WINDOW_SPOT: int = 2
const COP_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/Cop.tscn")
const CUSTOMER_SCENE_PATH: String = "res://Scenes/Levels/House/Sales/Customer.tscn"
const REGULAR_CUSTOMER: CustomerTypeData = preload("res://Ressources/Customers/regular.tres")

var _role: String = "host"
var _port: int = 17777
var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=")
		if parts.size() == 2 and parts[0] == "role":
			_role = parts[1]
		elif parts.size() == 2 and parts[0] == "port":
			_port = int(parts[1])
	_run.call_deferred()


func _run() -> void:
	# Detach from current_scene so SceneManager can swap scenes without freeing the test.
	get_tree().current_scene = null
	await _frames(10)
	if _role == "host":
		await _run_host()
	else:
		await _run_guest()
	print("\n==== COOP %s: %d checks, %d failures ====" % [_role.to_upper(), _checks, _failures.size()])
	for failure: String in _failures:
		print("  FAIL: " + failure)
	Coop.leave()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _run_host() -> void:
	Profile.reset_progress()
	SceneManager.change_scene(HOUSE_SCENE)
	_check(await _wait_until(func() -> bool: return _get_house() != null and _get_house().is_playing()), "host: the house loads and the shift runs")
	var level: HouseLevel = _get_house()
	var lab: Lab = level.get_front(Lab) as Lab
	var crate: IngredientCrate = lab.get_crate(&"glowcap")
	var grinder: Workstation = lab.get_station(&"Grinder")
	# The lab's gadgets come from the office: buy them so the guest can grind.
	Profile.wallet.add(Types.CURRENCY_CASH, 5000)
	for gadget_id: StringName in [Types.UPGRADE_GRINDER, Types.UPGRADE_COOKER, Types.UPGRADE_PRESS]:
		Profile.upgrades.purchase(GameConfig.get_default().find_upgrade(gadget_id))
	level.apply_upgrades()
	var cash_before: int = level.operation.get_cash()
	_check(Coop.host(_port, false) == OK, "host: hosting on port %d" % _port)
	_check(await _wait_until(func() -> bool: return Coop.get_ready_peers().size() == 1), "host: the guest joined and loaded the house")
	var sync: HouseCoopSync = level.get_node("%CoopSync") as HouseCoopSync
	_check(await _wait_until(func() -> bool: return sync.get_remote_players().size() == 1), "host: the guest appears as a second player")
	var guest: RemotePlayer = sync.get_remote_players()[0]
	_check(await _wait_until(func() -> bool: return guest.hands.get_held_items().size() == 1), "host: the guest's click buys an ingredient into their hand")
	_check(level.operation.get_cash() == cash_before - crate.ingredient.cost, "host: it is paid from the shared cash")
	_check(await _wait_until(func() -> bool: return grinder.is_running()), "host: the guest put it into the grinder")
	_check(await _wait_until(func() -> bool: return grinder.get_output_socket().item != null), "host: the guest's press on Stop ground it")
	# Things the guest should see walk around in its copy (and sell to / shoot at).
	for recipe: RecipeData in level.operation.get_unlocked_recipes():
		level.operation.add_product(recipe, 4, 10)
		level.operation.set_price(recipe, recipe.base_price)
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	window.spawn_customer(REGULAR_CUSTOMER.create_order(level.operation.get_unlocked_recipes(), RandomNumberGenerator.new()))
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	garden.director.spawn_raider(COP_SCENE)
	var units_before: int = level.operation.stash.get_total()
	_check(await _wait_until(func() -> bool: return level.operation.stash.get_total() < units_before), "host: the guest's press on Sell sold from the stash")
	_check(await _wait_until(func() -> bool: return garden.door.is_passable()), "host: the guest swung the front door open")
	_check(await _wait_until(func() -> bool: return Coop.get_ready_peers().is_empty()), "host: the guest left again")


func _run_guest() -> void:
	_check(await _join_host(), "guest: joined the host")
	_check(await _wait_until(func() -> bool: return _get_house() != null and _get_house().is_mirror), "guest: shows the host's house as a mirror")
	var level: HouseLevel = _get_house()
	var sync: HouseCoopSync = level.get_node("%CoopSync") as HouseCoopSync
	var lab: Lab = level.get_front(Lab) as Lab
	var crate: IngredientCrate = lab.get_crate(&"glowcap")
	var grinder: Workstation = lab.get_station(&"Grinder")
	var rig: XRPlayerRig = level.rig
	_check(await _wait_until(func() -> bool: return sync.get_remote_players().size() == 1), "guest: sees the host")
	# Let the first shared state arrive before reading the cash.
	await _seconds(1.0)
	var cash_before: int = level.operation.get_cash()
	rig.locomotion.travel_to_spot(LAB_SPOT)
	await _frames(5)
	rig.tap_world_point(crate.get_grab_center())
	var my_hand: Vector2i = Vector2i(Coop.get_local_peer_id(), rig.dominant_hand)
	_check(await _wait_until(func() -> bool: return sync.entities.find_held_by(my_hand) != null), "guest: the bought ingredient shows up in my hand")
	var held: IngredientItem = sync.entities.find_held_by(my_hand) as IngredientItem
	_check(held != null and held.data != null and held.data.id == &"glowcap", "guest: it looks like a glowcap")
	_check(await _wait_until(func() -> bool: return level.operation.get_cash() == cash_before - crate.ingredient.cost), "guest: the shared cash went down")
	rig.tap_world_point(grinder.get_input_sockets()[0].global_position)
	_check(await _wait_until(func() -> bool: return grinder.get_stop_button().visible), "guest: the grinder runs its skill check")
	_check(sync.entities.find_held_by(my_hand) == null, "guest: my hand is empty again")
	await _frames(5)
	rig.tap_world_point(grinder.get_stop_button().get_press_center())
	_check(await _wait_until(func() -> bool: return not grinder.get_stop_button().visible), "guest: my press on Stop finished the skill check")
	_check(await _wait_until(func() -> bool: return not sync.entities.get_stand_ins_of(CUSTOMER_SCENE_PATH).is_empty()), "guest: sees the host's customer")
	_check(await _wait_until(func() -> bool: return not sync.entities.get_stand_ins_of(COP_SCENE.resource_path).is_empty()), "guest: sees the host's raider")

	# Selling: the window board shows the host's customer; pressing Sell sells in the host's world.
	rig.locomotion.travel_to_spot(WINDOW_SPOT)
	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	var sales_screen: WorldScreen = window.get_node("%SalesScreen") as WorldScreen
	var sell_button: Button = sales_screen.content.find_child("SellButton", true, false) as Button
	_check(await _wait_until(func() -> bool: return sell_button.is_visible_in_tree() and not sell_button.disabled), "guest: my window board shows the customer's order")
	var cash_before_sale: int = level.operation.get_cash()
	# The order shows while the customer still walks up; like a player, press again until they're there.
	var has_sold: bool = false
	var sale_deadline_msec: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while not has_sold and Time.get_ticks_msec() < sale_deadline_msec:
		rig.tap_world_point(sales_screen.pixel_to_world(sell_button.get_global_rect().get_center()))
		has_sold = await _wait_until(func() -> bool: return level.operation.get_cash() > cash_before_sale, 1500)
	_check(has_sold, "guest: selling at the window earns shared cash")

	# The front door: open it from inside, then the doorway is walkable here too.
	rig.locomotion.travel_to_spot(FRONT_SPOT)
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	await _frames(5)
	rig.tap_world_point(garden.door.get_inside_handle().get_grab_center())
	_check(await _wait_until(func() -> bool: return garden.door.is_passable()), "guest: the door I opened stands open here too")
	_check(rig.walkable_area.contains(Vector3(garden.doorway_region.get_center().x, 0.0, garden.doorway_region.get_center().y)), "guest: I can walk through the open doorway")

	# A shot with the gun trigger: the host fires it and its tracer comes back.
	var tracers: Array[int] = [0]
	Events.beam_fired.connect(func(_from: Vector3, _to: Vector3) -> void: tracers[0] += 1)
	var cop: Node3D = sync.entities.get_stand_ins_of(COP_SCENE.resource_path)[0]
	rig.aim_at_world_point(cop.global_position + Vector3(0.0, 1.0, 0.0))
	var off_hand: Types.Hand = Types.Hand.LEFT if rig.dominant_hand == Types.Hand.RIGHT else Types.Hand.RIGHT
	rig.handle_controller_button(off_hand, Types.XR_ACTION_TRIGGER_CLICK, true)
	rig.handle_controller_button(off_hand, Types.XR_ACTION_TRIGGER_CLICK, false)
	_check(await _wait_until(func() -> bool: return tracers[0] > 0), "guest: my gun trigger fires (the host's shot comes back as a tracer)")


## Retries until the host is up (it loads the house first).
func _join_host() -> bool:
	var deadline_msec: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		Coop.join("127.0.0.1:%d" % _port)
		if await _wait_until(func() -> bool: return _get_house() != null or not Coop.is_online(), 4000):
			if _get_house() != null:
				return true
		await _seconds(0.5)
	return false


func _get_house() -> HouseLevel:
	var house: HouseLevel = get_tree().current_scene as HouseLevel
	if house == null or SceneManager.is_transitioning or not house.is_node_ready():
		return null
	return house


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok   " + description)
	else:
		print("  FAIL " + description)
		_failures.append(description)


func _frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _wait_until(condition: Callable, timeout_msec: int = TIMEOUT_MSEC) -> bool:
	var deadline_msec: int = Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline_msec:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()

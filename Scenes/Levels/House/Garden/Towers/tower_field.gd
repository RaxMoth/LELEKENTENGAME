## The player's towers out in the garden and the town. The tower depot (a
## terminal and a table by the porch) sells kits; carry one outside, point
## at the ground and pull the trigger to build the tower there — while a
## kit is in hand a ring on the ground shows where it would stand (green:
## fine, red: not here). Towers fight on their own, can be taken over from
## the Security PC and the monitor wall, are upgraded with the button on
## their post, and are still standing the next day (Profile.towers).
## Part of the defense front (FrontGarden owns it and steps it).
##
##   field.buy_kit(tower_data)                 # the depot's board
##   field.build(tower_data, spot)             # a kit's trigger (or tests)
##   field.upgrade_tower(tower)
##
## Dependencies: FieldTower, TowerKit, TowerBoard, TowerData, TowerCatalog,
##               TowerPlacements, HouseContext, Yard, WalkableArea, WorldScreen,
##               RayMath, Pools, Profile, Audio autoloads, Palette
class_name TowerField
extends Node3D

## A tower was built (a new one, or one rebuilt from the save at the start).
signal tower_built(tower: FieldTower)

const TOWER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/Towers/FieldTower.tscn")
const KIT_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/Towers/TowerKit.tscn")

## Every kind of tower the depot sells.
@export var catalog: TowerCatalog
## Kits waiting on the depot's table at most.
@export_range(1, 8) var max_kits: int = 4
## No tower closer than this (meters) to the front door (the way in stays free).
@export var door_clearance: float = 3.5
## Radius (meters) the player can't walk into around a tower.
@export var tower_body_radius: float = 0.5
## Farthest a kit's pointer reaches to build (meters).
@export var build_reach: float = 25.0

var _context: HouseContext = null
var _yard: Yard = null
var _towers: Array[FieldTower] = []
var _kits: Array[TowerKit] = []
var _is_preview_valid: bool = true

@onready var _screen: WorldScreen = %TowerScreen
@onready var _kit_spot: Marker3D = %KitSpot
@onready var _towers_root: Node3D = %PlacedTowers
@onready var _preview: MeshInstance3D = %PlacementPreview


## Called by the FrontGarden at setup: wires the depot and rebuilds the saved towers.
func setup(context: HouseContext, yard: Yard) -> void:
	_context = context
	_yard = yard
	var board: TowerBoard = get_board()
	board.set_catalog(catalog)
	board.kit_buy_requested.connect(func(tower_data: TowerData) -> void: buy_kit(tower_data))
	_preview.visible = false
	# Nobody walks through the depot's table.
	var walkable: WalkableArea = context.rig.walkable_area
	if walkable != null:
		var table: Vector3 = _kit_spot.global_position
		walkable.add_rect_blockers([Rect2(table.x - 1.0, table.z - 0.75, 2.0, 1.0)])
	var placements: TowerPlacements = Profile.towers.placements
	for index: int in placements.get_count():
		var tower_data: TowerData = catalog.find_tower(placements.get_id(index))
		if tower_data != null:
			_spawn_tower(tower_data, index)
	board.refresh()


## One frame: towers fight, the build ring follows a kit in hand.
func step(delta: float) -> void:
	for tower: FieldTower in _towers:
		tower.step(delta)
	_update_preview()


## Keeps the depot's screen drawing only while in sight.
func refresh_display(front: HouseFront) -> void:
	front.update_screen_rendering(_screen)


func get_board() -> TowerBoard:
	return _screen.content as TowerBoard


func get_screen() -> WorldScreen:
	return _screen


## Every tower standing.
func get_towers() -> Array[FieldTower]:
	return _towers


## Kits waiting on the table (or in a hand).
func get_kits() -> Array[TowerKit]:
	return _kits


## Buys a kit for cash: it appears on the depot's table. Returns it, or
## null (no cash, or the table is full).
func buy_kit(tower_data: TowerData) -> TowerKit:
	_forget_used_kits()
	if tower_data == null or _kits.size() >= max_kits or not _context.operation.spend_cash(tower_data.cost, "towers"):
		Audio.play_ui(Audio.UI_ERROR)
		return null
	var slot: Vector3 = _kit_spot.global_position + _kit_spot.global_transform.basis.x * ((_kits.size() - (max_kits - 1) * 0.5) * 0.42)
	var kit: TowerKit = Pools.spawn(KIT_SCENE, _towers_root, slot) as TowerKit
	kit.setup(tower_data, self, slot)
	_kits.append(kit)
	Audio.play_ui(Audio.UI_CONFIRM)
	get_board().refresh()
	return kit


## A kit's trigger: builds its tower where [param pointer] meets the ground.
func build_from_kit(kit: TowerKit, pointer: XRPointer) -> FieldTower:
	var spot: Vector3 = _get_ground_point(pointer)
	if not is_valid_spot(spot):
		Audio.play_ui(Audio.UI_ERROR)
		return null
	var tower: FieldTower = build(kit.data, Vector2(spot.x, spot.z))
	if tower != null:
		kit.detach()
		_kits.erase(kit)
		Pools.despawn(kit)
	return tower


## Builds a [param tower_data] tower at [param spot] (world X / Z), facing
## away from the house. Returns it, or null when the spot isn't allowed.
func build(tower_data: TowerData, spot: Vector2) -> FieldTower:
	if tower_data == null or not is_valid_spot(Vector3(spot.x, 0.0, spot.y)):
		return null
	var away: Vector2 = spot - _yard.get_door_point()
	var index: int = Profile.towers.placements.add(tower_data.id, spot, atan2(away.x, away.y) + PI)
	if index < 0:
		return null
	var tower: FieldTower = _spawn_tower(tower_data, index)
	Audio.play_sfx_at(SfxSynth.get_preset(&"machine"), tower.global_position, 0.1)
	get_board().refresh()
	return tower


## True where a tower may stand: outside the house, on open ground (no
## building, tree or car), clear of the front door and of other towers.
func is_valid_spot(spot: Vector3) -> bool:
	if not spot.is_finite() or _yard == null:
		return false
	var flat: Vector2 = Vector2(spot.x, spot.z)
	if not _yard.is_outdoors(spot) or flat.distance_to(_yard.get_door_point()) < door_clearance:
		return false
	if not Profile.towers.placements.can_place(flat):
		return false
	var walkable: WalkableArea = _context.rig.walkable_area
	return walkable == null or walkable.contains(Vector3(spot.x, walkable.floor_height, spot.z))


## Pays for and builds the next level of [param tower]. Returns true on success.
func upgrade_tower(tower: FieldTower) -> bool:
	var placements: TowerPlacements = Profile.towers.placements
	var cost: int = tower.data.get_upgrade_cost(tower.level)
	if cost <= 0 or not _context.operation.spend_cash(cost, "towers"):
		Audio.play_ui(Audio.UI_ERROR)
		return false
	placements.upgrade(tower.placement_index, tower.data.get_max_level())
	var new_level: int = placements.get_level(tower.placement_index)
	tower.configure(tower.data, new_level, _yard, tower.data.get_upgrade_cost(new_level))
	Audio.play_ui(Audio.UI_CONFIRM)
	return true


## The day is over: kits still in their box are paid back (kits aren't
## kept overnight, towers are).
func refund_kits() -> void:
	_forget_used_kits()
	for kit: TowerKit in _kits:
		if kit.data != null:
			_context.operation.refund_cash(kit.data.cost)
		kit.detach()
		Pools.despawn(kit)
	_kits.clear()


## Takes every tower down (admin, tests): gone from the field and from the save.
func remove_all_towers() -> void:
	var walkable: WalkableArea = _context.rig.walkable_area
	for tower: FieldTower in _towers:
		if walkable != null:
			walkable.remove_blockers([Vector3(tower.global_position.x, tower.global_position.z, tower_body_radius)])
		Pools.despawn(tower)
	_towers.clear()
	Profile.towers.placements.clear()
	Profile.towers.mark_dirty()
	get_board().refresh()


## Every turret the player can see through and take over: field towers.
func get_controllable() -> Array[HouseTurret]:
	var turrets: Array[HouseTurret] = []
	for tower: FieldTower in _towers:
		turrets.append(tower)
	return turrets


func _spawn_tower(tower_data: TowerData, index: int) -> FieldTower:
	var placements: TowerPlacements = Profile.towers.placements
	var spot: Vector2 = placements.get_spot(index)
	var tower: FieldTower = Pools.spawn(TOWER_SCENE, _towers_root, Vector3(spot.x, 0.0, spot.y)) as FieldTower
	tower.rotation.y = placements.get_yaw(index)
	tower.placement_index = index
	var level: int = placements.get_level(index)
	tower.configure(tower_data, level, _yard, tower_data.get_upgrade_cost(level))
	if not tower.upgrade_requested.is_connected(upgrade_tower):
		tower.upgrade_requested.connect(upgrade_tower)
	_towers.append(tower)
	var walkable: WalkableArea = _context.rig.walkable_area
	if walkable != null:
		walkable.add_blockers([Vector3(spot.x, spot.y, tower_body_radius)])
	tower_built.emit(tower)
	return tower


## The ground point [param pointer] aims at (INF when it misses or is too far).
func _get_ground_point(pointer: XRPointer) -> Vector3:
	if pointer == null:
		return Vector3.INF
	var distance: float = RayMath.intersect_ground(pointer.ray_origin, pointer.ray_direction, 0.0)
	if distance == RayMath.NO_HIT or distance > build_reach:
		return Vector3.INF
	return pointer.get_point(distance)


## Shows the build ring under the pointer while a kit is in hand.
func _update_preview() -> void:
	var holding_kit: bool = false
	for item: Grabbable in _context.rig.get_held_items():
		if item is TowerKit:
			holding_kit = true
	if not holding_kit:
		_preview.visible = false
		return
	var spot: Vector3 = _get_ground_point(_context.rig.get_tool_pointer())
	if not spot.is_finite():
		_preview.visible = false
		return
	_preview.visible = true
	_preview.global_position = spot + Vector3(0.0, 0.03, 0.0)
	# Recolored only when it changes (a new color rebuilds the mesh).
	var is_valid: bool = is_valid_spot(spot)
	if is_valid != _is_preview_valid:
		_is_preview_valid = is_valid
		(_preview as PlaceholderMesh3D).color = Palette.SUCCESS if is_valid else Palette.DANGER


func _forget_used_kits() -> void:
	for kit_index: int in range(_kits.size() - 1, -1, -1):
		if not is_instance_valid(_kits[kit_index]) or Pools.is_in_pool(_kits[kit_index]):
			_kits.remove_at(kit_index)

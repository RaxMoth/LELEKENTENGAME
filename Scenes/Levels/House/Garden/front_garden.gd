## The defense front: the garden lanes up to the front door. Owns the
## LaneBoard, the door, the build board above the gate, the guards and the
## AttackerDirector, and the player's part in it — building towers on tiles
## and firing the gun in hand (bought at the armory), both from the front
## room or the porch (the defense zone).
##
## Selling days are quiet out here; the police come only in a raid
## (HouseCycle → on_raid_started / on_raid_wave_started), and the wave lasts
## until every officer is down (get_raiders_left). The front door swings,
## latches and bolts (FrontDoor); while it stands open the doorway to the
## porch is walkable.
##
## Reports to the House level only through HouseFront's signals: the door
## breaking loses the shift, raids and thefts are warnings, stopped
## attackers are score.
##
## Dependencies: HouseFront, LaneBoard, FrontDoor, BuildBoard, AttackerDirector,
##               TowerData, WeaponCatalog, WeaponData, RaidWave, BeamTracer,
##               PopEffect3D, FloatingText3D, RayMath, WalkableArea, Pools,
##               Profile, Audio, Types autoloads, Palette, SfxSynth
class_name FrontGarden
extends HouseFront

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")

## Towers the build board offers, in order.
@export var towers: Array[TowerData] = []
## Every gun there is (the player fires the one equipped in Profile.armory).
@export var weapon_catalog: WeaponCatalog

@export_group("Defense zone")
## Floor area (world X / Z) the player must stand in to shoot or build — the
## front room. The build board only redraws while the player stands here.
@export var defense_zone: Rect2 = Rect2(-5.0, -5.0, 10.0, 3.0)

@export_group("Front door")
## The step outside the front door (world X / Z): walkable, and the player
## can defend from it too.
@export var porch_region: Rect2 = Rect2(-1.1, -6.3, 2.2, 1.0)
## The threshold (world X / Z): walkable only while the door stands open.
@export var doorway_region: Rect2 = Rect2(-0.5, -5.35, 1.0, 0.7)

var selected_tower: int = 0

var _tower_cooldowns: Array[float] = []
var _weapon_cooldown: float = 0.0

@onready var board: LaneBoard = %LaneBoard
@onready var door: FrontDoor = %FrontDoor
@onready var director: AttackerDirector = %AttackerDirector
@onready var _build_screen: WorldScreen = %BuildScreen
@onready var _guards: Node3D = %Guards

# ============================================
# FRONT HOOKS
# ============================================

func _on_setup() -> void:
	_tower_cooldowns.resize(towers.size())
	_tower_cooldowns.fill(0.0)
	var build_board: BuildBoard = get_build_board()
	build_board.set_towers(towers)
	build_board.tower_chosen.connect(select_tower)
	build_board.set_hint(
		tr("Pick a tower, point at a tile, pull the trigger · Other hand: your gun") if context.rig.is_xr_active
		else tr("Pick a tower, click a tile · Right-click: your gun"))
	context.rig.primary_action_pressed.connect(_on_rig_primary_action_pressed)
	context.rig.secondary_action_pressed.connect(_on_rig_secondary_action_pressed)
	board.enemy_reached_home.connect(_on_thief_reached_door)
	board.enemy_defeated.connect(func(enemy: LaneEnemy) -> void: score_earned.emit(enemy.score_value))
	door.broken.connect(_on_door_broken)
	door.passage_changed.connect(_on_door_passage_changed)
	if context.rig.walkable_area != null:
		context.rig.walkable_area.add_region(porch_region)
	director.setup(context, board)
	for guard: Node in _guards.get_children():
		(guard as Worker).operation = context.operation
	apply_upgrades()
	select_tower(0)


func _shift_process(delta: float) -> void:
	_weapon_cooldown = maxf(0.0, _weapon_cooldown - delta)
	_update_tower_cooldowns(delta)
	director.step(delta)
	_update_pointers()


func _refresh_displays() -> void:
	var build_board: BuildBoard = get_build_board()
	build_board.set_cash(context.operation.get_cash())
	build_board.set_heat(context.operation.heat.value)
	build_board.set_door_health(door.get_health_ratio())
	_build_screen.set_rendering(is_in_defense_zone())


func apply_upgrades() -> void:
	var new_max_health: float = door.base_max_health + context.operation.get_upgrade_value(Types.UPGRADE_DOOR)
	if not is_equal_approx(new_max_health, door.health_component.max_health):
		door.health_component.set_max_health(new_max_health)
	for tower_index: int in towers.size():
		get_build_board().set_locked(tower_index, not Profile.upgrades.is_owned(towers[tower_index].unlock_upgrade_id))


func finish_shift(_result: LevelResult) -> void:
	director.clear_pending()
	board.freeze()
	for pointer: XRPointer in context.rig.get_active_pointers():
		pointer.set_world_hit_distance(RayMath.NO_HIT)


func on_raid_started(_raid_number: int, _wave_count: int) -> void:
	if not door.is_locked():
		warning_requested.emit(tr("Close and lock the front door!"))


func on_raid_wave_started(wave: RaidWave) -> void:
	var spawn_interval: float = context.cycle.raid_data.seconds_between_spawns if context.cycle != null else -1.0
	director.queue_wave(wave, spawn_interval)


func get_raiders_left() -> int:
	return director.get_raiders_left()


func remove_raiders() -> void:
	director.clear_pending()
	for enemy: LaneEnemy in board.get_enemies().duplicate():
		if enemy.is_alive():
			enemy.take_hit(1000000.0, self, false, true)


func get_status_line() -> String:
	var door_state: String = tr("open") if door.is_open() else (tr("locked") if door.is_locked() else tr("unlocked"))
	return tr("Door %d%% %s") % [roundi(door.get_health_ratio() * 100.0), door_state]

# ============================================
# PUBLIC API
# ============================================

func get_build_board() -> BuildBoard:
	return _build_screen.content as BuildBoard


func get_build_screen() -> WorldScreen:
	return _build_screen


func select_tower(tower_index: int) -> void:
	if towers.is_empty():
		return
	selected_tower = posmod(tower_index, towers.size())
	get_build_board().set_selected(selected_tower)


## True while the player stands in the front room or on the porch, where they can defend.
func is_in_defense_zone() -> bool:
	var feet: Vector3 = context.rig.get_feet_position()
	var floor_point: Vector2 = Vector2(feet.x, feet.z)
	return defense_zone.has_point(floor_point) or porch_region.has_point(floor_point)


## The gun in the player's hand (Profile.armory), or null without a catalog.
func get_equipped_weapon() -> WeaponData:
	return Profile.armory.loadout.get_equipped(weapon_catalog)


## Builds the selected tower on a garden cell if it is free, unlocked,
## affordable and off cooldown.
func try_build(cell: Vector2i, pointer: XRPointer = null) -> bool:
	if not context.is_playing() or not board.grid.is_valid_cell(cell) or towers.is_empty():
		return false
	var tower_data: TowerData = towers[selected_tower]
	var world_position: Vector3 = board.grid.cell_to_position(cell)
	var refusal: String = ""
	if not Profile.upgrades.is_owned(tower_data.unlock_upgrade_id):
		refusal = tr("Locked")
	elif not board.can_place(cell):
		refusal = tr("Taken")
	elif _tower_cooldowns[selected_tower] > 0.0:
		refusal = tr("Not ready")
	elif not context.operation.can_afford(tower_data.cost):
		refusal = tr("Need $%d") % tower_data.cost
	if not refusal.is_empty():
		Audio.play_ui(Audio.UI_ERROR)
		FloatingText3D.spawn(refusal, world_position + Vector3(0.0, 0.9, 0.0), Palette.DANGER, board.get_effects_root())
		return false
	context.operation.spend_cash(tower_data.cost, "towers")
	board.place_tower(tower_data, cell)
	_tower_cooldowns[selected_tower] = tower_data.cooldown_seconds
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), world_position, 0.05)
	PopEffect3D.spawn(world_position + Vector3(0.0, 0.3, 0.0), tower_data.icon_color, 0.9, board.get_effects_root())
	if pointer != null:
		context.rig.pulse(pointer, Types.HapticStrength.MEDIUM)
	return true


## Fires the equipped gun along a pointer's ray: its damage (plus the Better
## Blaster upgrade), range and armor piercing, one round of its ammo. Returns
## the attacker it hit, or null.
func fire_weapon(pointer: XRPointer) -> LaneEnemy:
	var weapon: WeaponData = get_equipped_weapon()
	if not context.is_playing() or weapon == null or _weapon_cooldown > 0.0:
		return null
	_weapon_cooldown = weapon.fire_interval_seconds
	if not Profile.armory.loadout.try_fire(weapon):
		Audio.play_ui(Audio.UI_ERROR)
		FloatingText3D.spawn(tr("Out of ammo"), pointer.get_point(1.5), Palette.WARNING, board.get_effects_root())
		return null
	var enemy: LaneEnemy = board.pick_enemy(pointer.ray_origin, pointer.ray_direction, weapon.range_meters) if is_in_defense_zone() else null
	var beam_end: Vector3 = pointer.get_point(weapon.range_meters)
	if enemy != null:
		beam_end = enemy.get_hit_center()
		enemy.take_hit(weapon.damage + context.operation.get_upgrade_value(Types.UPGRADE_BLASTER), self, false, weapon.pierces_armor)
		PopEffect3D.spawn(beam_end, Palette.PROJECTILE, 0.4, board.get_effects_root())
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, board.get_effects_root(), pointer.ray_origin) as BeamTracer
	tracer.fire(_get_muzzle_position(pointer), beam_end)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shoot"), pointer.ray_origin, 0.1, -4.0)
	context.rig.pulse(pointer, weapon.recoil as Types.HapticStrength)
	return enemy

# ============================================
# INTERNALS
# ============================================

func _on_rig_primary_action_pressed(pointer: XRPointer) -> void:
	if not context.is_playing() or not is_in_defense_zone():
		return
	# One cursor does everything on a flat screen: attackers first, then tiles.
	if not context.rig.is_xr_active and board.pick_enemy(pointer.ray_origin, pointer.ray_direction, _get_weapon_range()) != null:
		fire_weapon(pointer)
		return
	var cell: Vector2i = board.pick_cell(pointer.ray_origin, pointer.ray_direction)
	if board.grid.is_valid_cell(cell):
		try_build(cell, pointer)


func _on_rig_secondary_action_pressed(pointer: XRPointer) -> void:
	fire_weapon(pointer)


func _on_thief_reached_door(enemy: LaneEnemy) -> void:
	if not context.is_playing():
		return
	var security_level: int = context.operation.get_upgrade_level(Types.UPGRADE_SECURITY)
	var stolen: int = context.operation.lose_stock(maxi(0, enemy.units_stolen - security_level))
	if stolen > 0:
		warning_requested.emit(tr("Stock stolen: %d") % stolen)


func _on_door_broken() -> void:
	shift_lost.emit(tr("The door is down"))


## The threshold is walkable only while the door stands wide open.
func _on_door_passage_changed(is_passable: bool) -> void:
	var walkable: WalkableArea = context.rig.walkable_area if context != null else null
	if walkable == null:
		return
	if is_passable:
		walkable.add_region(doorway_region)
	else:
		walkable.remove_region(doorway_region)


func _get_weapon_range() -> float:
	var weapon: WeaponData = get_equipped_weapon()
	return weapon.range_meters if weapon != null else 30.0


func _update_tower_cooldowns(delta: float) -> void:
	var build_board: BuildBoard = get_build_board()
	for tower_index: int in _tower_cooldowns.size():
		if _tower_cooldowns[tower_index] <= 0.0:
			continue
		_tower_cooldowns[tower_index] = maxf(0.0, _tower_cooldowns[tower_index] - delta)
		build_board.set_cooldown_ratio(tower_index, _tower_cooldowns[tower_index] / maxf(0.001, towers[tower_index].cooldown_seconds))


## Per frame: mark the tile under the using pointer and end each beam on
## what it points at in the garden.
func _update_pointers() -> void:
	var tool_pointer: XRPointer = context.rig.get_tool_pointer()
	var can_defend: bool = is_in_defense_zone()
	for pointer: XRPointer in context.rig.get_active_pointers():
		if pointer.is_over_screen() or not can_defend:
			if pointer == tool_pointer:
				board.show_highlight(LaneGrid.INVALID_CELL, false)
			pointer.set_world_hit_distance(RayMath.NO_HIT)
			continue
		var hit_distance: float = RayMath.NO_HIT
		var cell: Vector2i = board.pick_cell(pointer.ray_origin, pointer.ray_direction)
		if pointer == tool_pointer:
			board.show_highlight(cell, board.can_place(cell) and Profile.upgrades.is_owned(towers[selected_tower].unlock_upgrade_id))
		if board.grid.is_valid_cell(cell):
			hit_distance = board.get_ground_distance(pointer.ray_origin, pointer.ray_direction)
		var enemy: LaneEnemy = board.pick_enemy(pointer.ray_origin, pointer.ray_direction, _get_weapon_range())
		if enemy != null:
			hit_distance = pointer.ray_origin.distance_to(enemy.get_hit_center())
		pointer.set_world_hit_distance(hit_distance)


## The flat simulator's ray starts in the camera, so its beam is drawn from
## a little below the view instead.
func _get_muzzle_position(pointer: XRPointer) -> Vector3:
	if context.rig.is_xr_active:
		return pointer.ray_origin
	var head: Transform3D = context.rig.get_head_transform()
	return head.origin - head.basis.y * 0.25 + head.basis.x * 0.2

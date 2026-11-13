## The defense front: the open yard in front of the house, the front door,
## the house's roof turrets and the Security PC that steers them, the
## guards and the AttackerDirector — and the player's part in it: the gun
## in hand (bought at the armory), fired from the front room or the porch
## (the defense zone).
##
## Selling days are quiet out here; the police come only in a raid
## (HouseCycle → on_raid_started / on_raid_wave_started), cross the yard in
## squads from cover to cover, rush the door together, and the wave lasts
## until every raider is down (get_raiders_left). The front door swings,
## latches and bolts (FrontDoor); while it stands open the doorway to the
## porch is walkable. Turrets are house upgrades ("Roof Turrets", "Security
## PC" in the office), not things built in the yard.
##
## If the door breaks the raiders storm in and hunt the players through the
## house (Yard.start_hunting); the gun then hits from anywhere. The players'
## health (PlayerVitals) is the House level's: going down ends the shift.
##
## Reports to the House level only through HouseFront's signals: raids and
## the broken door are warnings, stopped raiders are score.
##
## Dependencies: HouseFront, Yard, Raider, FrontDoor, HouseTurret, SecurityPc,
##               AttackerDirector, GunModel, WeaponCatalog, WeaponData,
##               RaidWave, BeamTracer, PopEffect3D, FloatingText3D, RayMath,
##               WalkableArea, Pools, Profile, Audio, Types autoloads,
##               Palette, SfxSynth
class_name FrontGarden
extends HouseFront

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")

## Every gun there is (the player fires the one equipped in Profile.armory).
@export var weapon_catalog: WeaponCatalog

@export_group("Defense zone")
## Floor area (world X / Z) the player may shoot from inside — the front
## room (the porch and the garden count too).
@export var defense_zone: Rect2 = Rect2(-5.0, -5.0, 10.0, 3.0)

@export_group("Front door")
## The step outside the front door (world X / Z): walkable, and the player
## can defend from it too.
@export var porch_region: Rect2 = Rect2(-1.1, -6.3, 2.2, 1.0)
## The threshold (world X / Z): walkable only while the door stands open.
@export var doorway_region: Rect2 = Rect2(-0.5, -5.35, 1.0, 0.7)

@export_group("Garden")
## The player may walk out into the yard (through the open front door) and
## defend from there; the fence keeps them this far inside (meters).
@export var garden_fence_margin: float = 0.35

var _weapon_cooldown: float = 0.0
## The pointer whose trigger is held (automatic guns keep firing), or null.
var _held_trigger_pointer: XRPointer = null
## Shots fired in the current burst (automatic spread grows with it).
var _shots_in_burst: int = 0
var _seconds_since_shot: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## Co-op: the other player's own trigger — same gun and ammo, own pace,
## own burst spread, held for automatic guns (HouseContext.guest_fired).
var _guest_trigger_pointer: XRPointer = null
var _guest_feet: Vector3 = Vector3.ZERO
var _guest_recoil: Callable = Callable()
var _guest_weapon_cooldown: float = 0.0
var _guest_shots_in_burst: int = 0
var _guest_seconds_since_shot: float = 0.0
var _turrets: Array[HouseTurret] = []
## Gun models by weapon id, made once and swapped when another gun is equipped.
var _gun_models: Dictionary[StringName, GunModel] = {}
var _shown_gun: GunModel = null

@onready var yard: Yard = %Yard
@onready var door: FrontDoor = %FrontDoor
@onready var director: AttackerDirector = %AttackerDirector
@onready var security_pc: SecurityPc = %SecurityPc
@onready var turret_seat: TurretSeat = %TurretSeat
@onready var _turret_root: Node3D = %Turrets
@onready var _guards: Node3D = %Guards

# ============================================
# FRONT HOOKS
# ============================================

func _on_setup() -> void:
	context.rig.primary_action_pressed.connect(_on_rig_primary_action_pressed)
	context.rig.secondary_action_pressed.connect(_on_rig_secondary_action_pressed)
	context.rig.secondary_action_released.connect(func(_pointer: XRPointer) -> void:
		_stop_trigger()
		turret_seat.set_firing(false, false))
	context.rig.primary_action_released.connect(func(_pointer: XRPointer) -> void: turret_seat.set_firing(false, true))
	context.guest_fired.connect(_on_guest_fired)
	context.guest_trigger_released.connect(func() -> void: _guest_trigger_pointer = null)
	_random.randomize()
	yard.raider_defeated.connect(func(raider: Raider) -> void: score_earned.emit(raider.score_value))
	door.broken.connect(_on_door_broken)
	door.passage_changed.connect(_on_door_passage_changed)
	yard.walkable = context.rig.walkable_area
	if context.rig.walkable_area != null:
		context.rig.walkable_area.add_region(porch_region)
		# The garden: out of the front door, across the yard up to its fence,
		# around its trees, rocks and the car — and out through the gate
		# into the street (the town around makes the rest walkable).
		context.rig.walkable_area.add_region(get_garden_region())
		context.rig.walkable_area.add_blockers(yard.get_obstacle_circles())
		context.rig.walkable_area.add_rect_blockers(yard.get_fence_blockers())
	director.setup(context, yard)
	for turret_node: Node in _turret_root.get_children():
		var turret: HouseTurret = turret_node as HouseTurret
		turret.setup(yard)
		_turrets.append(turret)
	security_pc.setup(_turrets, yard)
	security_pc.goggles_used.connect(func(turret: HouseTurret) -> void: turret_seat.enter(turret))
	turret_seat.setup(context.rig)
	for guard: Node in _guards.get_children():
		(guard as Worker).operation = context.operation
	apply_upgrades()


func _shift_process(delta: float) -> void:
	_weapon_cooldown = maxf(0.0, _weapon_cooldown - delta)
	_seconds_since_shot += delta
	_guest_weapon_cooldown = maxf(0.0, _guest_weapon_cooldown - delta)
	_guest_seconds_since_shot += delta
	_step_trigger()
	director.step(delta)
	for turret: HouseTurret in _turrets:
		turret.step(delta)
	security_pc.step(delta)
	turret_seat.step(delta)
	_update_gun()
	_update_pointers()


func _refresh_displays() -> void:
	if security_pc.is_available():
		update_screen_rendering(security_pc.get_screen())


func apply_upgrades() -> void:
	var new_max_health: float = door.base_max_health + context.operation.get_upgrade_value(Types.UPGRADE_DOOR)
	if not is_equal_approx(new_max_health, door.health_component.max_health):
		door.health_component.set_max_health(new_max_health)
	door.damage_reduction = context.operation.get_upgrade_value(Types.UPGRADE_SECURITY)
	var turret_level: int = context.operation.get_upgrade_level(Types.UPGRADE_TURRETS)
	for turret: HouseTurret in _turrets:
		turret.set_mounted(turret_level >= turret.mount_level)
	security_pc.set_available(context.operation.get_upgrade_level(Types.UPGRADE_SECURITY_PC) > 0)


func finish_shift(_result: LevelResult) -> void:
	director.clear_pending()
	yard.freeze()
	_stop_trigger()
	_guest_trigger_pointer = null
	turret_seat.leave()
	security_pc.release_control()
	for pointer: XRPointer in context.rig.get_active_pointers():
		pointer.set_world_hit_distance(RayMath.NO_HIT)


func on_raid_started(_raid_number: int, _wave_count: int) -> void:
	if not door.is_locked():
		warning_requested.emit(tr("Close and lock the front door!"))


func on_raid_wave_started(wave: RaidWave) -> void:
	var spawn_interval: float = context.cycle.raid_data.seconds_between_spawns if context.cycle != null else -1.0
	director.queue_wave(wave, spawn_interval)
	if wave.ram_count > 0:
		warning_requested.emit(tr("Battering ram incoming!"))


func get_raiders_left() -> int:
	return director.get_raiders_left()


func remove_raiders() -> void:
	director.clear_pending()
	for raider: Raider in yard.get_raiders().duplicate():
		if raider.is_alive():
			raider.take_hit(1000000.0, self, false, true)


func get_status_line() -> String:
	if door.is_broken():
		return tr("Door broken")
	var door_state: String = tr("open") if door.is_open() else (tr("locked") if door.is_locked() else tr("unlocked"))
	return tr("Door %d%% %s") % [roundi(door.get_health_ratio() * 100.0), door_state]

# ============================================
# PUBLIC API
# ============================================

## True while the player stands in the front room or on the porch, where they can defend.
func is_in_defense_zone() -> bool:
	return _is_defense_spot(context.rig.get_feet_position())


## True where the player's shots hit raiders: in the front room, on the
## porch or in the garden — and anywhere in the house once they stormed in.
func can_defend() -> bool:
	return is_in_defense_zone() or yard.is_hunting()


func _is_defense_spot(feet: Vector3) -> bool:
	var floor_point: Vector2 = Vector2(feet.x, feet.z)
	return defense_zone.has_point(floor_point) or porch_region.has_point(floor_point) or get_garden_region().has_point(floor_point)


## The walkable garden (world X / Z): the yard inside its fence, from the
## far edge up to the front of the house (the porch's outer side).
func get_garden_region() -> Rect2:
	var bounds: Rect2 = yard.bounds
	var start: Vector2 = bounds.position + Vector2(garden_fence_margin, garden_fence_margin)
	var house_side_z: float = porch_region.end.y
	return Rect2(start, Vector2(bounds.size.x - garden_fence_margin * 2.0, house_side_z - start.y))


## The gun in the player's hand (Profile.armory), or null without a catalog.
func get_equipped_weapon() -> WeaponData:
	return Profile.armory.loadout.get_equipped(weapon_catalog)


## The roof turret mounts (mounted or not).
func get_turrets() -> Array[HouseTurret]:
	return _turrets


## The model of the gun in hand, or null while it is put away.
func get_shown_gun() -> GunModel:
	return _shown_gun


## Fires the equipped gun along a pointer's ray, the way that gun shoots
## (WeaponBallistics): its projectiles (a shotgun's pellets) fly in a cone
## that widens during a burst, each loses damage with distance, goes through
## up to pierce_count raiders (a rifle round) and is stopped by cover. One
## round of ammo per shot; Better Rounds adds damage. Returns the first
## raider hit, or null.
func fire_weapon(pointer: XRPointer) -> Raider:
	var weapon: WeaponData = get_equipped_weapon()
	if not context.is_playing() or weapon == null or _weapon_cooldown > 0.0:
		return null
	_weapon_cooldown = weapon.fire_interval_seconds
	if not Profile.armory.loadout.try_fire(weapon):
		_stop_trigger()
		Audio.play_ui(Audio.UI_ERROR)
		if _shown_gun != null:
			_shown_gun.play_dry_fire()
		FloatingText3D.spawn(tr("Out of ammo"), pointer.get_point(1.5), Palette.WARNING, yard.get_effects_root())
		return null
	var bloom: float = WeaponBallistics.get_bloom(weapon, _shots_in_burst)
	_shots_in_burst += 1
	_seconds_since_shot = 0.0
	var first_hit: Raider = _fire_projectiles(pointer, _get_muzzle_position(pointer), weapon, bloom, can_defend())
	if _shown_gun != null:
		_shown_gun.play_shot()
	Audio.play_sfx_at(SfxSynth.get_preset(weapon.sound_preset), pointer.ray_origin, 0.06, -3.0)
	context.rig.pulse(pointer, weapon.recoil as Types.HapticStrength)
	return first_hit


## The projectiles of one shot from [param muzzle] along [param pointer]'s
## ray (WeaponBallistics: pellets in a cone widened by [param bloom],
## damage falling off with distance, piercing, cover). Hits raiders only
## when [param can_hit] (fired from the front room or porch). Returns the
## first raider hit, or null.
func _fire_projectiles(pointer: XRPointer, muzzle: Vector3, weapon: WeaponData, bloom: float, can_hit: bool) -> Raider:
	# Better Rounds is per shot: a shotgun shares it among its pellets.
	var bonus: float = context.operation.get_upgrade_value(Types.UPGRADE_BLASTER) / maxf(1.0, weapon.pellets)
	var first_hit: Raider = null
	for direction: Vector3 in WeaponBallistics.get_shot_directions(pointer.ray_direction, weapon, bloom, _random):
		var shot_end: Vector3 = pointer.ray_origin + direction * weapon.range_meters
		var ground: float = yard.get_ground_distance(pointer.ray_origin, direction)
		if ground != RayMath.NO_HIT and ground < weapon.range_meters:
			shot_end = pointer.ray_origin + direction * ground
		var hits: Array[Array] = []
		if can_hit:
			hits = yard.pick_raiders(pointer.ray_origin, direction, weapon.range_meters, weapon.pierce_count)
		for hit: Array in hits:
			var raider: Raider = hit[0] as Raider
			raider.take_hit(WeaponBallistics.get_damage_at(weapon, float(hit[1])) + bonus, self, false, weapon.pierces_armor)
			PopEffect3D.spawn(raider.get_hit_center(), Palette.PROJECTILE, 0.3, yard.get_effects_root())
			if first_hit == null:
				first_hit = raider
		# The projectile stops in the last raider it can reach.
		if not hits.is_empty() and hits.size() >= weapon.pierce_count:
			shot_end = (hits[hits.size() - 1][0] as Raider).get_hit_center()
		var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, yard.get_effects_root(), muzzle) as BeamTracer
		tracer.fire(muzzle, shot_end)
	return first_hit

# ============================================
# INTERNALS
# ============================================

## Flat simulator: one cursor does everything, so a click on a raider fires.
## In a headset the dominant trigger stays for screens and buttons.
func _on_rig_primary_action_pressed(pointer: XRPointer) -> void:
	if turret_seat.is_active():
		# Seated in a turret, either trigger fires it (flat: a click fires one burst).
		turret_seat.set_firing(true)
		if not context.rig.is_xr_active:
			turret_seat.get_turret().fire()
			turret_seat.set_firing(false)
		return
	if not context.is_playing() or not can_defend() or context.rig.is_xr_active:
		return
	if yard.pick_raider(pointer.ray_origin, pointer.ray_direction, _get_weapon_range()) != null:
		fire_weapon(pointer)


func _on_rig_secondary_action_pressed(pointer: XRPointer) -> void:
	if turret_seat.is_active():
		turret_seat.set_firing(true, false)
		return
	_held_trigger_pointer = pointer
	fire_weapon(pointer)


## Automatic guns keep firing while the trigger is held; a pause between
## shots lets the spread settle again (for each player on their own).
func _step_trigger() -> void:
	var weapon: WeaponData = get_equipped_weapon()
	if weapon != null and _seconds_since_shot > weapon.fire_interval_seconds * 2.5:
		_shots_in_burst = 0
	if weapon != null and _guest_seconds_since_shot > weapon.fire_interval_seconds * 2.5:
		_guest_shots_in_burst = 0
	if _held_trigger_pointer != null and weapon != null and weapon.is_automatic:
		fire_weapon(_held_trigger_pointer)
	if _guest_trigger_pointer != null and weapon != null and weapon.is_automatic:
		_fire_for_guest()


## Co-op: the other player pulled their gun trigger where they stand.
func _on_guest_fired(pointer: XRPointer, feet: Vector3, recoil_pulse: Callable) -> void:
	_guest_trigger_pointer = pointer
	_guest_feet = feet
	_guest_recoil = recoil_pulse
	_fire_for_guest()


## One shot of the shared gun for the other player: their own pace and
## burst spread, the shared ammo, the muzzle at their hand.
func _fire_for_guest() -> void:
	var weapon: WeaponData = get_equipped_weapon()
	var pointer: XRPointer = _guest_trigger_pointer
	if pointer == null or not context.is_playing() or weapon == null or _guest_weapon_cooldown > 0.0:
		return
	_guest_weapon_cooldown = weapon.fire_interval_seconds
	if not Profile.armory.loadout.try_fire(weapon):
		_guest_trigger_pointer = null
		Audio.play_ui(Audio.UI_ERROR)
		FloatingText3D.spawn(tr("Out of ammo"), pointer.get_point(1.5), Palette.WARNING, yard.get_effects_root())
		return
	var bloom: float = WeaponBallistics.get_bloom(weapon, _guest_shots_in_burst)
	_guest_shots_in_burst += 1
	_guest_seconds_since_shot = 0.0
	_fire_projectiles(pointer, pointer.ray_origin, weapon, bloom, _is_defense_spot(_guest_feet) or yard.is_hunting())
	Audio.play_sfx_at(SfxSynth.get_preset(weapon.sound_preset), pointer.ray_origin, 0.06, -3.0)
	if _guest_recoil.is_valid():
		_guest_recoil.call(weapon.recoil as Types.HapticStrength)


func _stop_trigger() -> void:
	_held_trigger_pointer = null


## The door is down: the raiders storm in after the players. The shift goes
## on — beat them (or go down: HouseLevel ends the shift then).
func _on_door_broken() -> void:
	warning_requested.emit(tr("The door is down! They're coming in!"))
	yard.start_hunting()


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


## Puts the equipped gun's model in the off hand (or the flat view's lower
## right while defending) and swaps it when another gun is equipped.
func _update_gun() -> void:
	var weapon: WeaponData = get_equipped_weapon()
	var wanted: GunModel = _get_gun_model(weapon)
	var anchor: Node3D = context.rig.get_weapon_anchor()
	var should_show: bool = wanted != null and anchor != null and not context.rig.is_weapon_hand_busy() \
		and not turret_seat.is_active() and (context.rig.is_xr_active or can_defend())
	if _shown_gun != null and (_shown_gun != wanted or not should_show):
		_shown_gun.visible = false
		_shown_gun = null
	if not should_show:
		return
	if wanted.get_parent() != anchor:
		if wanted.get_parent() != null:
			wanted.get_parent().remove_child(wanted)
		anchor.add_child(wanted)
		wanted.transform = Transform3D.IDENTITY
	wanted.visible = true
	_shown_gun = wanted


## Gun models not in a hand right now are outside the tree: free them with the level.
func _exit_tree() -> void:
	for model: GunModel in _gun_models.values():
		if is_instance_valid(model) and not model.is_inside_tree():
			model.free()
	_gun_models.clear()


func _get_gun_model(weapon: WeaponData) -> GunModel:
	if weapon == null or weapon.model_scene == null:
		return null
	if not _gun_models.has(weapon.id):
		var model: GunModel = weapon.model_scene.instantiate() as GunModel
		model.visible = false
		_gun_models[weapon.id] = model
	return _gun_models[weapon.id]


## Per frame: end each beam on the raider or ground it points at in the yard.
func _update_pointers() -> void:
	var is_defending: bool = can_defend()
	for pointer: XRPointer in context.rig.get_active_pointers():
		if pointer.is_over_screen() or not is_defending:
			pointer.set_world_hit_distance(RayMath.NO_HIT)
			continue
		var hit_distance: float = yard.get_ground_distance(pointer.ray_origin, pointer.ray_direction)
		var raider: Raider = yard.pick_raider(pointer.ray_origin, pointer.ray_direction, _get_weapon_range())
		if raider != null:
			hit_distance = pointer.ray_origin.distance_to(raider.get_hit_center())
		pointer.set_world_hit_distance(hit_distance)


## Shots start at the gun's muzzle; without a gun model, a little below the view.
func _get_muzzle_position(pointer: XRPointer) -> Vector3:
	if _shown_gun != null:
		return _shown_gun.get_muzzle_position()
	if context.rig.is_xr_active:
		return pointer.ray_origin
	var head: Transform3D = context.rig.get_head_transform()
	return head.origin - head.basis.y * 0.25 + head.basis.x * 0.2

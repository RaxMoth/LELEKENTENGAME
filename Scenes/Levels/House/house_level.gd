## The House: one shift (a day and a night) of running the operation. Craft
## product by hand in the lab, sell it at the back window, hold the front
## door against junkies, cops and the mafia — all at once, walking between
## the fronts. Money goes back into upgrades at the office. The shift is won
## at dawn and lost when the front door breaks (the stash is lost and
## repairs cost cash; upgrades and banked cash stay).
##
## XR: grip grabs, the dominant trigger uses (buttons, screens, building on a
## garden tile), the off-hand trigger fires the blaster, thumbsticks move and
## turn. Flat: click to grab / place / press / build, right-click shoots,
## WASD walks, 1-4 jump to the lab, front, window and office.
##
## Dependencies: LevelBase, Operation, DayCycle, PressureDirector, LaneBoard,
##               FrontDoor, SalesWindow, BuildBoard, OfficeBoard, Worker,
##               WristStatus, StashShelf, XRPlayerRig, WorldScreen, Profile,
##               Audio, UI, Events, Types autoloads, Palette, SfxSynth
extends LevelBase

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")
## Announcements appear this far ahead of the player's head, where they look.
const ANNOUNCE_DISTANCE: float = 3.0
## Share of the cash lost to repairs when the door breaks.
const REPAIR_COST_SHARE: float = 0.2
## Seconds between refreshes of the in-world displays.
const DISPLAY_REFRESH_SECONDS: float = 0.25
## In-world screens farther than this from the head, or behind it, stop redrawing.
const SCREEN_RENDER_DISTANCE: float = 7.0

## Towers the build board offers, in order.
@export var towers: Array[TowerData] = []

@export_group("Blaster")
@export var blaster_damage: float = 20.0
@export var blaster_interval_seconds: float = 0.3
@export var blaster_range: float = 30.0

@export_group("Defense")
## Floor area the player must stand in to shoot or build (the front room).
@export var defense_zone: Rect2 = Rect2(-5.0, -5.0, 10.0, 3.0)
## The build board is used from the front room, however far away it hangs.
@export var build_screen_render_zone: Rect2 = Rect2(-5.0, -5.0, 10.0, 3.0)

@export_group("Rendering")
## Bloom is a full-screen pass per eye: too expensive on standalone headsets and phones.
@export var glow_on_mobile: bool = false

var selected_tower: int = 0

var _tower_cooldowns: Array[float] = []
var _blaster_cooldown: float = 0.0
var _display_refresh: float = 0.0
var _last_paid_hour: int = 0

@onready var operation: Operation = %Operation
@onready var day_cycle: DayCycle = %DayCycle
@onready var director: PressureDirector = %PressureDirector
@onready var board: LaneBoard = %LaneBoard
@onready var door: FrontDoor = %FrontDoor
@onready var sales_window: SalesWindow = %SalesWindow
@onready var _build_screen: WorldScreen = %BuildScreen
@onready var _office_screen: WorldScreen = %OfficeScreen
@onready var _workers: Node3D = %Workers
@onready var _wrist_status: WristStatus = %WristStatus
@onready var _travel_spots: Node3D = %TravelSpots
@onready var _world_environment: WorldEnvironment = %WorldEnvironment

# ============================================
# LEVEL HOOKS
# ============================================

func _on_level_setup() -> void:
	if Platform.is_mobile() and not glow_on_mobile:
		_world_environment.environment.glow_enabled = false
	rig.walkable_area = %WalkableArea
	var spots: Array[Node3D] = []
	for spot: Node in _travel_spots.get_children():
		spots.append(spot as Node3D)
	rig.locomotion.travel_spots = spots
	_wrist_status.attach_to(rig.get_wrist_anchor())
	_tower_cooldowns.resize(towers.size())
	_tower_cooldowns.fill(0.0)
	var build_board: BuildBoard = get_build_board()
	build_board.set_towers(towers)
	build_board.tower_chosen.connect(select_tower)
	build_board.set_hint(
		tr("Pick a tower, point at a tile, pull the trigger · Other hand: blaster") if rig.is_xr_active
		else tr("Pick a tower, click a tile · Right-click: blaster"))
	var office_board: OfficeBoard = get_office_board()
	office_board.upgrade_requested.connect(buy_upgrade)
	office_board.bribe_requested.connect(_on_bribe_requested)
	board.enemy_reached_home.connect(_on_thief_reached_door)
	board.enemy_defeated.connect(func(enemy: LaneEnemy) -> void: add_score(enemy.score_value))
	door.broken.connect(_on_door_broken)
	operation.sale_made.connect(func(_order: CustomerOrder, _units: int, cash_earned: int) -> void: add_score(cash_earned))
	director.raid_started.connect(func(_raid_level: int) -> void: _warn(tr("Police raid!")))
	director.mafia_crew_started.connect(func() -> void: _warn(tr("Mafia crew incoming")))
	director.boss_wave_started.connect(func() -> void: _warn(tr("The boss is here")))
	day_cycle.nightfall.connect(_on_nightfall)
	Events.upgrade_purchased.connect(func(_upgrade_id: StringName, _level: int) -> void: apply_upgrades())
	_last_paid_hour = floori(day_cycle.clock.get_hour())
	apply_upgrades()
	select_tower(0)
	_refresh_displays()


func _on_level_started() -> void:
	announce(tr("Day %d") % Profile.operation.day_number)


func _level_process(delta: float) -> void:
	_blaster_cooldown = maxf(0.0, _blaster_cooldown - delta)
	_update_tower_cooldowns(delta)
	day_cycle.advance(delta)
	director.step(delta)
	operation.cool_heat(delta)
	_pay_wages_on_the_hour()
	_update_pointers()
	_display_refresh -= delta
	if _display_refresh <= 0.0:
		_display_refresh = DISPLAY_REFRESH_SECONDS
		_refresh_displays()
	if day_cycle.clock.is_shift_over():
		win()


func _on_level_finished(result: LevelResult) -> void:
	board.freeze()
	sales_window.clear_queue()
	for pointer: XRPointer in rig.get_active_pointers():
		pointer.set_world_hit_distance(RayMath.NO_HIT)
	if result.is_won():
		Profile.operation.complete_day()
	else:
		# The house was overrun: the stock is gone and the door needs fixing.
		operation.stash.clear()
		operation.spend_cash(roundi(operation.get_cash() * REPAIR_COST_SHARE), "repairs")
	operation.save()

# ============================================
# PUBLIC API
# ============================================

func get_build_board() -> BuildBoard:
	return _build_screen.content as BuildBoard


func get_office_board() -> OfficeBoard:
	return _office_screen.content as OfficeBoard


func select_tower(tower_index: int) -> void:
	if towers.is_empty():
		return
	selected_tower = posmod(tower_index, towers.size())
	get_build_board().set_selected(selected_tower)


## Re-applies everything upgrades change (hired crew, stash size, door).
func apply_upgrades() -> void:
	operation.apply_upgrades()
	for worker: Node in _workers.get_children():
		(worker as Worker).refresh_hired()
	for tower_index: int in towers.size():
		get_build_board().set_locked(tower_index, not Profile.upgrades.is_owned(towers[tower_index].unlock_upgrade_id))
	var new_max_health: float = door.base_max_health + operation.get_upgrade_value(Types.UPGRADE_DOOR)
	if not is_equal_approx(new_max_health, door.health_component.max_health):
		door.health_component.set_max_health(new_max_health)
	get_office_board().refresh()


## Buys an upgrade from the office (or a tutorial). Returns true on success.
func buy_upgrade(upgrade: UpgradeData) -> bool:
	if not Profile.upgrades.purchase(upgrade):
		Audio.play_ui(Audio.UI_ERROR)
		return false
	Audio.play_ui(Audio.UI_CONFIRM)
	return true


## Shows the announcement world-locked in front of wherever the player looks
## right now: they move between rooms, so a fixed spot would often be out of view.
func announce(message: String, color: Color = Palette.TEXT, hold_seconds: float = 1.0) -> void:
	var head: Transform3D = rig.get_head_transform()
	var forward: Vector3 = Vector3(-head.basis.z.x, 0.0, -head.basis.z.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	announcer.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), head.origin + forward * ANNOUNCE_DISTANCE + Vector3(0.0, 0.35, 0.0))
	super(message, color, hold_seconds)


## True while the player stands in the front room, where they can defend.
func is_in_defense_zone() -> bool:
	var feet: Vector3 = rig.get_feet_position()
	return defense_zone.has_point(Vector2(feet.x, feet.z))


## Builds the selected tower on a garden cell if it is free, unlocked,
## affordable and off cooldown.
func try_build(cell: Vector2i, pointer: XRPointer = null) -> bool:
	if not is_playing() or not board.grid.is_valid_cell(cell) or towers.is_empty():
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
	elif not operation.can_afford(tower_data.cost):
		refusal = tr("Need $%d") % tower_data.cost
	if not refusal.is_empty():
		Audio.play_ui(Audio.UI_ERROR)
		FloatingText3D.spawn(refusal, world_position + Vector3(0.0, 0.9, 0.0), Palette.DANGER, board.get_effects_root())
		return false
	operation.spend_cash(tower_data.cost, "towers")
	board.place_tower(tower_data, cell)
	_tower_cooldowns[selected_tower] = tower_data.cooldown_seconds
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), world_position, 0.05)
	PopEffect3D.spawn(world_position + Vector3(0.0, 0.3, 0.0), tower_data.icon_color, 0.9, board.get_effects_root())
	if pointer != null:
		rig.pulse(pointer, Types.HapticStrength.MEDIUM)
	return true


## Fires the blaster along a pointer's ray. Returns the attacker it hit, or null.
func fire_blaster(pointer: XRPointer) -> LaneEnemy:
	if not is_playing() or _blaster_cooldown > 0.0:
		return null
	_blaster_cooldown = blaster_interval_seconds
	var enemy: LaneEnemy = board.pick_enemy(pointer.ray_origin, pointer.ray_direction, blaster_range) if is_in_defense_zone() else null
	var beam_end: Vector3 = pointer.get_point(blaster_range)
	if enemy != null:
		beam_end = enemy.get_hit_center()
		enemy.take_hit(blaster_damage + operation.get_upgrade_value(Types.UPGRADE_BLASTER), self)
		PopEffect3D.spawn(beam_end, Palette.PROJECTILE, 0.4, board.get_effects_root())
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, board.get_effects_root(), pointer.ray_origin) as BeamTracer
	tracer.fire(_get_muzzle_position(pointer), beam_end)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shoot"), pointer.ray_origin, 0.1, -4.0)
	rig.pulse(pointer, Types.HapticStrength.LIGHT)
	return enemy

# ============================================
# PLAYER INPUT (connected in House.tscn)
# ============================================

func _on_rig_primary_action_pressed(pointer: XRPointer) -> void:
	if not is_playing() or not is_in_defense_zone():
		return
	# One cursor does everything on a flat screen: attackers first, then tiles.
	if not rig.is_xr_active and board.pick_enemy(pointer.ray_origin, pointer.ray_direction, blaster_range) != null:
		fire_blaster(pointer)
		return
	var cell: Vector2i = board.pick_cell(pointer.ray_origin, pointer.ray_direction)
	if board.grid.is_valid_cell(cell):
		try_build(cell, pointer)


func _on_rig_secondary_action_pressed(pointer: XRPointer) -> void:
	fire_blaster(pointer)

# ============================================
# EVENTS
# ============================================

func _on_thief_reached_door(enemy: LaneEnemy) -> void:
	if not is_playing():
		return
	var security_level: int = operation.get_upgrade_level(Types.UPGRADE_SECURITY)
	var units_to_steal: int = maxi(0, enemy.units_stolen - security_level)
	var stolen: int = operation.lose_stock(units_to_steal)
	if stolen > 0:
		_warn(tr("Stock stolen: %d") % stolen)


func _on_door_broken() -> void:
	if is_playing():
		_warn(tr("The door is down"))
		lose()


func _on_nightfall() -> void:
	announce(tr("Night falls"), Palette.MOONLIGHT)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.0, -14.0)


func _on_bribe_requested() -> void:
	if operation.bribe():
		Audio.play_ui(Audio.UI_CONFIRM)
		announce(tr("Heat dropped"), Palette.SUCCESS, 0.6)
	else:
		Audio.play_ui(Audio.UI_ERROR)

# ============================================
# INTERNALS
# ============================================

func _warn(message: String) -> void:
	announce(message, Palette.DANGER)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.0, -6.0)
	for pointer: XRPointer in rig.get_active_pointers():
		rig.pulse(pointer, Types.HapticStrength.HEAVY)


func _update_tower_cooldowns(delta: float) -> void:
	var build_board: BuildBoard = get_build_board()
	for tower_index: int in _tower_cooldowns.size():
		if _tower_cooldowns[tower_index] <= 0.0:
			continue
		_tower_cooldowns[tower_index] = maxf(0.0, _tower_cooldowns[tower_index] - delta)
		build_board.set_cooldown_ratio(tower_index, _tower_cooldowns[tower_index] / maxf(0.001, towers[tower_index].cooldown_seconds))


## Crew are paid every in-game hour; unpaid crew strike until the next payday.
func _pay_wages_on_the_hour() -> void:
	var current_hour: int = floori(day_cycle.clock.get_hour())
	if current_hour <= _last_paid_hour:
		return
	_last_paid_hour = current_hour
	for worker: Node in _workers.get_children():
		(worker as Worker).pay_wage()


## Per frame: mark the tile under the using pointer and end each beam on
## what it points at in the garden.
func _update_pointers() -> void:
	var tool_pointer: XRPointer = rig.get_tool_pointer()
	var can_defend: bool = is_in_defense_zone()
	for pointer: XRPointer in rig.get_active_pointers():
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
		var enemy: LaneEnemy = board.pick_enemy(pointer.ray_origin, pointer.ray_direction, blaster_range)
		if enemy != null:
			hit_distance = pointer.ray_origin.distance_to(enemy.get_hit_center())
		pointer.set_world_hit_distance(hit_distance)


## The flat simulator's ray starts in the camera, so its beam is drawn from
## a little below the view instead.
func _get_muzzle_position(pointer: XRPointer) -> Vector3:
	if rig.is_xr_active:
		return pointer.ray_origin
	var head: Transform3D = rig.get_head_transform()
	return head.origin - head.basis.y * 0.25 + head.basis.x * 0.2


## Only screens the player can use right now keep redrawing.
func _update_screen_rendering() -> void:
	var head: Transform3D = rig.get_head_transform()
	var feet: Vector3 = rig.get_feet_position()
	_build_screen.set_rendering(build_screen_render_zone.has_point(Vector2(feet.x, feet.z)))
	for screen: WorldScreen in [_office_screen, sales_window.get_screen()]:
		var to_screen: Vector3 = screen.global_position - head.origin
		var is_in_front: bool = to_screen.dot(-head.basis.z) > 0.0
		screen.set_rendering(to_screen.length() <= SCREEN_RENDER_DISTANCE and is_in_front)


func _refresh_displays() -> void:
	_update_screen_rendering()
	var build_board: BuildBoard = get_build_board()
	build_board.set_cash(operation.get_cash())
	build_board.set_heat(operation.heat.value)
	build_board.set_door_health(door.get_health_ratio())
	get_office_board().set_heat(operation.heat.value, operation.get_bribe_cost())
	_wrist_status.show_status(day_cycle.clock.format_time(), day_cycle.is_night(), operation.get_cash(), Profile.operation.reputation,
		operation.stash.get_total(), operation.stash.capacity, operation.heat.value, door.get_health_ratio(), sales_window.get_queue_size())

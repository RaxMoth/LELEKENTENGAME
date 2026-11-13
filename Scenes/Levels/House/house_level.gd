## The House: one shift (a day and a night) of running the operation. Craft
## in the Lab, sell at the SalesWindow, hold the FrontGarden — all at once,
## walking between them; spend cash at the Office. The shift is won at dawn
## and lost when a player goes down (PlayerVitals: raiders that got in
## through a broken front door hit them) or a front says so: the stash is
## lost and repairs cost cash; upgrades and banked cash stay.
##
## Shifts run in 3-day cycles (HouseCycle): days 1-3 only bring customers;
## when night falls on day 3 the police raid the house in waves, time stops
## and the shift is won once every wave is beaten (not at dawn). Then the
## next cycle of selling begins, ending in a harder raid.
##
## This script only runs the shift: time, wages, winning and losing, the
## wrist status and announcements. Every front is its own scene and script
## (a HouseFront), found through Types.GROUP_HOUSE_FRONT and handed a
## HouseContext at setup — so the defense, customer and house sides can be
## developed without touching each other's files.
##
## Co-op: on the host this is the real shift. A guest's copy is a mirror
## (is_mirror): its fronts and cycle stand still and HouseCoopSync shows the
## host's world — time, money, stash, items, stations — instead.
##
## Dependencies: LevelBase, HouseFront, HouseContext, HouseCycle, Operation, DayCycle,
##               HouseShell, UpgradeReaction, WalkBlocker, Ghost, Worker, WristStatus, PlayerVitals, XRPlayerRig, HouseCoopSync, Profile, Audio,
##               Events, Platform, Coop, Types autoloads, Palette, SfxSynth
class_name HouseLevel
extends LevelBase

## Seconds between wrist status refreshes.
const WRIST_REFRESH_SECONDS: float = 0.25
const DAY_SUMMARY_POPUP: PackedScene = preload("res://Scenes/UI/Popups/DaySummaryPopup/DaySummaryPopup.tscn")

@export_group("Shift")
## Share of the cash lost to repairs when the shift is lost (the door broke).
@export_range(0.0, 1.0, 0.05) var repair_cost_share: float = 0.2
## Seconds the end of a day lingers before its summary shows.
@export_range(0.0, 10.0, 0.1) var day_end_hold_seconds: float = 1.2
## Seconds the "raid beaten" announcement shows before the shift's results.
@export_range(0.0, 10.0, 0.1) var raid_cleared_hold_seconds: float = 2.5

@export_group("Announcements")
## Announcements appear this far ahead of the player's head, where they look.
@export_range(1.0, 8.0, 0.1) var announce_distance: float = 3.0

@export_group("Rendering")
## Bloom is a full-screen pass per eye: too expensive on standalone headsets and phones.
@export var glow_on_mobile: bool = false

var context: HouseContext = null
## Co-op guest: this level only shows the host's world (no game logic runs).
var is_mirror: bool = false

var _fronts: Array[HouseFront] = []
var _last_paid_hour: int = 0
var _seconds_until_wrist_refresh: float = 0.0
## What the day that just ended brought (DaySummaryPopup keys).
var _day_summary: Dictionary = {}
## Co-op guest: the host's wrist status lines (cycle and fronts).
var _mirrored_wrist_lines: PackedStringArray = PackedStringArray()

@onready var operation: Operation = %Operation
@onready var day_cycle: DayCycle = %DayCycle
@onready var cycle: HouseCycle = %HouseCycle
## This player's health (a co-op guest's mirrors the host's numbers).
@onready var player_vitals: PlayerVitals = %PlayerVitals
@onready var _wrist_status: WristStatus = %WristStatus
@onready var _travel_spots: Node3D = %TravelSpots
@onready var _world_environment: WorldEnvironment = %WorldEnvironment
@onready var _coop_sync: HouseCoopSync = %CoopSync
@onready var _house_shell: HouseShell = %HouseShell
@onready var _ghost: Ghost = %Ghost

# ============================================
# LEVEL HOOKS
# ============================================

func _on_level_setup() -> void:
	is_mirror = Coop.is_client()
	if Platform.is_mobile() and not glow_on_mobile:
		_world_environment.environment.glow_enabled = false
	rig.walkable_area = %WalkableArea
	var spots: Array[Node3D] = []
	for spot: Node in _travel_spots.get_children():
		spots.append(spot as Node3D)
	rig.locomotion.travel_spots = spots
	_wrist_status.attach_to(rig.get_wrist_anchor())
	player_vitals.feet_source = rig.get_feet_position
	player_vitals.is_mirror = is_mirror
	player_vitals.hit_taken.connect(_on_player_hit)
	player_vitals.health_changed.connect(_wrist_status.show_health)
	player_vitals.died.connect(report_player_down.bind(""))
	_wrist_status.show_health(player_vitals.get_health(), player_vitals.get_max_health())
	context = HouseContext.new(self, rig, operation, day_cycle, cycle)
	for node: Node in get_tree().get_nodes_in_group(Types.GROUP_HOUSE_FRONT):
		var front: HouseFront = node as HouseFront
		if front != null and is_ancestor_of(front):
			_fronts.append(front)
	for front: HouseFront in _fronts:
		front.announcement_requested.connect(announce)
		front.warning_requested.connect(_warn)
		front.score_earned.connect(add_score)
		front.shift_lost.connect(_on_shift_lost)
		front.setup(context)
	cycle.setup(context, _fronts)
	cycle.raid_started.connect(_on_raid_started)
	cycle.wave_started.connect(_on_raid_wave_started)
	cycle.wave_cleared.connect(_on_raid_wave_cleared)
	cycle.raid_cleared.connect(_on_raid_cleared)
	day_cycle.nightfall.connect(_on_nightfall)
	Events.upgrade_purchased.connect(func(_upgrade_id: StringName, _level: int) -> void: apply_upgrades())
	_last_paid_hour = floori(day_cycle.clock.get_hour())
	apply_upgrades()
	if is_mirror:
		# The host runs the shift; this copy only shows it.
		for front: HouseFront in _fronts:
			front.process_mode = Node.PROCESS_MODE_DISABLED
		cycle.process_mode = Node.PROCESS_MODE_DISABLED
	_coop_sync.setup(self)
	_refresh_wrist()


func _on_level_started() -> void:
	if is_mirror:
		return
	announce(cycle.get_day_announcement(), Palette.WARNING if cycle.is_raid_day() else Palette.TEXT, 2.0)
	for front: HouseFront in _fronts:
		front.on_shift_started()


func _level_process(delta: float) -> void:
	if is_mirror:
		_seconds_until_wrist_refresh -= delta
		if _seconds_until_wrist_refresh <= 0.0:
			_seconds_until_wrist_refresh = WRIST_REFRESH_SECONDS
			_refresh_wrist()
		return
	# The raid night has no clock: it lasts until the last wave is beaten.
	if not cycle.is_raid_active():
		day_cycle.advance(delta)
		operation.cool_heat(delta)
		_pay_wages_on_the_hour()
	for front: HouseFront in _fronts:
		front.process_shift(delta)
	_seconds_until_wrist_refresh -= delta
	if _seconds_until_wrist_refresh <= 0.0:
		_seconds_until_wrist_refresh = WRIST_REFRESH_SECONDS
		_refresh_wrist()
	if day_cycle.clock.is_shift_over() and not cycle.is_raid_active():
		win()


func _on_level_finished(result: LevelResult) -> void:
	operation.close_shift()
	for front: HouseFront in _fronts:
		front.finish_shift(result)
	var day: int = Profile.operation.day_number
	var is_raid_beaten: bool = result.is_won() and cycle.phase == HouseCycle.Phase.CLEARED
	var units_lost: int = 0
	var repair_cost: int = 0
	if result.is_won():
		if is_raid_beaten:
			operation.clear_heat()
		Profile.operation.complete_day()
	else:
		# The house was overrun: the stock is gone and the door needs fixing.
		units_lost = operation.stash.get_total()
		repair_cost = roundi(operation.get_cash() * repair_cost_share)
		operation.stash.clear()
		operation.spend_cash(repair_cost, "repairs")
	operation.save()
	_day_summary = {
		DaySummaryPopup.KEY_DAY: day,
		DaySummaryPopup.KEY_WON: result.is_won(),
		DaySummaryPopup.KEY_RAID_BEATEN: is_raid_beaten,
		DaySummaryPopup.KEY_CASH_EARNED: operation.shift_cash_earned,
		DaySummaryPopup.KEY_UNITS_SOLD: operation.shift_units_sold,
		DaySummaryPopup.KEY_UNITS_CRAFTED: operation.shift_units_crafted,
		DaySummaryPopup.KEY_UNITS_LOST: units_lost,
		DaySummaryPopup.KEY_REPAIR_COST: repair_cost,
	}


## The house is the only world: no level results, just the day's summary
## and then the next morning (or the same day again after a loss). In
## co-op the guest follows the host into the new day.
func _present_result(_result: LevelResult) -> void:
	await Global.wait(day_end_hold_seconds, false)
	await UI.open_popup(DAY_SUMMARY_POPUP, _day_summary).closed
	restart_level()

# ============================================
# PUBLIC API
# ============================================

## Hands every piece of furniture that stands in the house now (bought
## stations, shelves, racks) to the player's walkable area, so nobody walks
## through tables.
func _refresh_furniture() -> void:
	var walkable: WalkableArea = rig.walkable_area
	if walkable == null:
		return
	walkable.clear_obstacles()
	for node: Node in get_tree().get_nodes_in_group(Types.GROUP_WALK_BLOCKER):
		var blocker: WalkBlocker = node as WalkBlocker
		if blocker != null and is_ancestor_of(blocker) and blocker.is_blocking():
			walkable.add_obstacle(blocker.get_footprint(), blocker.global_position.y)


## The night-4 ghost (tests).
func get_ghost() -> Ghost:
	return _ghost


## The house's walls, floor, ceiling and roof (renovations change their materials).
func get_house_shell() -> HouseShell:
	return _house_shell


## The front of [param front_script] (FrontGarden, SalesWindow, Lab, Office), or null.
func get_front(front_script: Script) -> HouseFront:
	for front: HouseFront in _fronts:
		if is_instance_of(front, front_script):
			return front
	return null


## Re-applies everything upgrades change: the operation, the player's
## perks (walking speed), the house's size and looks (renovated walls,
## floor, facade and roof; every UpgradeReaction: the cabin or the full
## house, door straps, stash shelves, things that move when the house
## grows), hired crew, every front, and the furniture the player can't
## walk through.
func apply_upgrades() -> void:
	operation.apply_upgrades()
	rig.locomotion.speed_multiplier = operation.get_walk_speed_multiplier()
	_house_shell.apply_renovations(Profile.upgrades)
	for node: Node in get_tree().get_nodes_in_group(Types.GROUP_UPGRADE_LOOK):
		var reaction: UpgradeReaction = node as UpgradeReaction
		if reaction != null and is_ancestor_of(reaction):
			reaction.apply_level(Profile.upgrades.get_level(reaction.upgrade_id))
	for worker: Node in get_tree().get_nodes_in_group(Types.GROUP_CREW):
		(worker as Worker).refresh_hired()
	for front: HouseFront in _fronts:
		front.apply_upgrades()
	_refresh_furniture()


## Shows the announcement world-locked in front of wherever the player looks
## right now: they move between rooms, so a fixed spot would often be out of view.
func announce(message: String, color: Color = Palette.TEXT, hold_seconds: float = 1.0) -> void:
	var head: Transform3D = rig.get_head_transform()
	var forward: Vector3 = Vector3(-head.basis.z.x, 0.0, -head.basis.z.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	announcer.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), head.origin + forward * announce_distance + Vector3(0.0, 0.35, 0.0))
	super(message, color, hold_seconds)
	if Coop.is_host():
		_coop_sync.broadcast_announcement(message, color, hold_seconds)


## The wrist status lines: the cycle's and every front's (co-op streams them).
func get_wrist_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray([cycle.get_status_line()])
	for front: HouseFront in _fronts:
		var line: String = front.get_status_line()
		if not line.is_empty():
			lines.append(line)
	return lines


## Co-op guest: the host's wrist lines to show.
func set_mirrored_wrist_lines(lines: PackedStringArray) -> void:
	_mirrored_wrist_lines = lines


## A player went down — this one ([param player_name] empty) or, on the
## host, a co-op guest: the shift is lost for everyone.
func report_player_down(player_name: String) -> void:
	_on_shift_lost(tr("You're down") if player_name.is_empty() else tr("%s is down") % player_name)

# ============================================
# INTERNALS
# ============================================

func _warn(message: String) -> void:
	announce(message, Palette.DANGER)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.0, -6.0)
	for pointer: XRPointer in rig.get_active_pointers():
		rig.pulse(pointer, Types.HapticStrength.HEAVY)


## Hit by a raider: both controllers rumble (the wrist shows what's left).
func _on_player_hit(_amount: float, _current: float) -> void:
	for pointer: XRPointer in rig.get_active_pointers():
		rig.pulse(pointer, Types.HapticStrength.HEAVY)


func _on_shift_lost(reason: String) -> void:
	if is_playing():
		_warn(reason)
		lose()


func _on_nightfall() -> void:
	# Each player meets the ghost on their own (the guest's too).
	if Profile.operation.day_number == _ghost.night_number:
		_ghost.haunt(rig)
	if is_mirror:
		return
	announce(tr("Night falls"), Palette.MOONLIGHT)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.0, -14.0)
	for front: HouseFront in _fronts:
		front.on_nightfall()
	if cycle.is_raid_day():
		cycle.start_raid()


func _on_raid_started(raid_number: int, wave_count: int) -> void:
	_warn(tr("Police raid %d! %d waves incoming") % [raid_number, wave_count])


func _on_raid_wave_started(wave: RaidWave, wave_count: int) -> void:
	announce(tr("Wave %d of %d") % [wave.wave_index + 1, wave_count], Palette.DANGER)


func _on_raid_wave_cleared(wave: RaidWave, wave_count: int) -> void:
	if wave.wave_index + 1 < wave_count:
		announce(tr("Wave beaten — next one is coming"), Palette.SUCCESS)


## The last wave is down: let the announcement land, then the shift is won.
func _on_raid_cleared(_raid_number: int) -> void:
	announce(tr("Raid beaten! Back to business"), Palette.SUCCESS, raid_cleared_hold_seconds)
	Audio.play_sfx(SfxSynth.get_preset(&"coin"))
	await get_tree().create_timer(raid_cleared_hold_seconds, false).timeout
	if is_playing():
		win()


## Crew are paid every in-game hour; unpaid crew strike until the next payday.
func _pay_wages_on_the_hour() -> void:
	var current_hour: int = floori(day_cycle.clock.get_hour())
	if current_hour <= _last_paid_hour:
		return
	_last_paid_hour = current_hour
	for worker: Node in get_tree().get_nodes_in_group(Types.GROUP_CREW):
		(worker as Worker).pay_wage()


func _refresh_wrist() -> void:
	var front_lines: PackedStringArray = _mirrored_wrist_lines if is_mirror else get_wrist_lines()
	_wrist_status.show_status(day_cycle.clock.format_time(), day_cycle.is_night(), operation.get_cash(), Profile.operation.reputation,
		operation.stash.get_total(), operation.stash.capacity, operation.heat.value, front_lines)

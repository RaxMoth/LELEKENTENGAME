## The House: one shift (a day and a night) of running the operation. Craft
## in the Lab, sell at the SalesWindow, hold the FrontGarden — all at once,
## walking between them; spend cash at the Office. The shift is won at dawn
## and lost when a front says so (the front door breaking): the stash is
## lost and repairs cost cash; upgrades and banked cash stay.
##
## This script only runs the shift: time, wages, winning and losing, the
## wrist status and announcements. Every front is its own scene and script
## (a HouseFront), found through Types.GROUP_HOUSE_FRONT and handed a
## HouseContext at setup — so the defense, customer and house sides can be
## developed without touching each other's files.
##
## Dependencies: LevelBase, HouseFront, HouseContext, Operation, DayCycle,
##               Worker, WristStatus, XRPlayerRig, Profile, Audio, Events,
##               Platform, Types autoloads, Palette, SfxSynth
class_name HouseLevel
extends LevelBase

## Announcements appear this far ahead of the player's head, where they look.
const ANNOUNCE_DISTANCE: float = 3.0
## Share of the cash lost to repairs when the shift is lost.
const REPAIR_COST_SHARE: float = 0.2
## Seconds between wrist status refreshes.
const WRIST_REFRESH_SECONDS: float = 0.25

@export_group("Rendering")
## Bloom is a full-screen pass per eye: too expensive on standalone headsets and phones.
@export var glow_on_mobile: bool = false

var context: HouseContext = null

var _fronts: Array[HouseFront] = []
var _last_paid_hour: int = 0
var _seconds_until_wrist_refresh: float = 0.0

@onready var operation: Operation = %Operation
@onready var day_cycle: DayCycle = %DayCycle
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
	context = HouseContext.new(self, rig, operation, day_cycle)
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
	day_cycle.nightfall.connect(_on_nightfall)
	Events.upgrade_purchased.connect(func(_upgrade_id: StringName, _level: int) -> void: apply_upgrades())
	_last_paid_hour = floori(day_cycle.clock.get_hour())
	apply_upgrades()
	_refresh_wrist()


func _on_level_started() -> void:
	announce(tr("Day %d") % Profile.operation.day_number)
	for front: HouseFront in _fronts:
		front.on_shift_started()


func _level_process(delta: float) -> void:
	day_cycle.advance(delta)
	operation.cool_heat(delta)
	_pay_wages_on_the_hour()
	for front: HouseFront in _fronts:
		front.process_shift(delta)
	_seconds_until_wrist_refresh -= delta
	if _seconds_until_wrist_refresh <= 0.0:
		_seconds_until_wrist_refresh = WRIST_REFRESH_SECONDS
		_refresh_wrist()
	if day_cycle.clock.is_shift_over():
		win()


func _on_level_finished(result: LevelResult) -> void:
	for front: HouseFront in _fronts:
		front.finish_shift(result)
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

## The front of [param front_script] (FrontGarden, SalesWindow, Lab, Office), or null.
func get_front(front_script: Script) -> HouseFront:
	for front: HouseFront in _fronts:
		if is_instance_of(front, front_script):
			return front
	return null


## Re-applies everything upgrades change: the operation, hired crew, every front.
func apply_upgrades() -> void:
	operation.apply_upgrades()
	for worker: Node in get_tree().get_nodes_in_group(Types.GROUP_CREW):
		(worker as Worker).refresh_hired()
	for front: HouseFront in _fronts:
		front.apply_upgrades()


## Shows the announcement world-locked in front of wherever the player looks
## right now: they move between rooms, so a fixed spot would often be out of view.
func announce(message: String, color: Color = Palette.TEXT, hold_seconds: float = 1.0) -> void:
	var head: Transform3D = rig.get_head_transform()
	var forward: Vector3 = Vector3(-head.basis.z.x, 0.0, -head.basis.z.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	announcer.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), head.origin + forward * ANNOUNCE_DISTANCE + Vector3(0.0, 0.35, 0.0))
	super(message, color, hold_seconds)

# ============================================
# INTERNALS
# ============================================

func _warn(message: String) -> void:
	announce(message, Palette.DANGER)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.0, -6.0)
	for pointer: XRPointer in rig.get_active_pointers():
		rig.pulse(pointer, Types.HapticStrength.HEAVY)


func _on_shift_lost(reason: String) -> void:
	if is_playing():
		_warn(reason)
		lose()


func _on_nightfall() -> void:
	announce(tr("Night falls"), Palette.MOONLIGHT)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.0, -14.0)
	for front: HouseFront in _fronts:
		front.on_nightfall()


## Crew are paid every in-game hour; unpaid crew strike until the next payday.
func _pay_wages_on_the_hour() -> void:
	var current_hour: int = floori(day_cycle.clock.get_hour())
	if current_hour <= _last_paid_hour:
		return
	_last_paid_hour = current_hour
	for worker: Node in get_tree().get_nodes_in_group(Types.GROUP_CREW):
		(worker as Worker).pay_wage()


func _refresh_wrist() -> void:
	var front_lines: PackedStringArray = PackedStringArray()
	for front: HouseFront in _fronts:
		var line: String = front.get_status_line()
		if not line.is_empty():
			front_lines.append(line)
	_wrist_status.show_status(day_cycle.clock.format_time(), day_cycle.is_night(), operation.get_cash(), Profile.operation.reputation,
		operation.stash.get_total(), operation.stash.capacity, operation.heat.value, front_lines)

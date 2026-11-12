## Sends the police into the yard during a raid. The HouseCycle decides when
## a wave starts and what it brings (a RaidWave: cops, SWAT, battering rams,
## toughness); the FrontGarden hands each wave here. The director lets the
## officers in one after another at the yard's edges, splits them into
## RaidSquads (which leapfrog from cover to cover and rush the door
## together) and gives each its own spot at the door. On selling days
## nothing comes (customers only).
##
##   director.queue_wave(wave)          # from FrontGarden.on_raid_wave_started
##   director.get_raiders_left()        # pending + still standing; 0 = wave beaten
##
## Dependencies: HouseContext, Yard, Raider, RaidSquad, RaidWave
class_name AttackerDirector
extends Node

@export var cop_scene: PackedScene
## Heavier officers with better equipment (from a later raid on).
@export var swat_scene: PackedScene
## Two officers carrying a battering ram (late in later raids).
@export var ram_scene: PackedScene
## Seconds between two officers of one wave entering the yard.
@export var group_spawn_interval: float = 1.4
## Officers per squad.
@export_range(1, 8) var squad_size: int = 3

## Off = queued officers wait (tutorials, tests).
var is_active: bool = true

var _context: HouseContext = null
var _yard: Yard = null
## Officers waiting to enter: [{"scene", "delay", "health", "squad", "spot"}].
var _pending_spawns: Array[Dictionary] = []
var _squads: Array[RaidSquad] = []


func setup(context: HouseContext, yard: Yard) -> void:
	_context = context
	_yard = yard


## One frame: lets queued officers in and moves the squads' plans on
## (called by the FrontGarden while the shift runs).
func step(delta: float) -> void:
	if not is_active or _context == null:
		return
	_step_pending_spawns(delta)
	for squad_index: int in range(_squads.size() - 1, -1, -1):
		var squad: RaidSquad = _squads[squad_index]
		squad.step(delta)
		if squad.get_alive_members().is_empty() and not _has_pending_for(squad):
			_squads.remove_at(squad_index)


## Queues every officer of [param wave] in squads: cops first, then SWAT,
## rams last (they join the final squad).
func queue_wave(wave: RaidWave, spawn_interval: float = -1.0) -> void:
	var interval: float = group_spawn_interval if spawn_interval < 0.0 else spawn_interval
	var scenes: Array[PackedScene] = []
	for cop_index: int in wave.cop_count:
		scenes.append(cop_scene)
	for swat_index: int in wave.swat_count:
		scenes.append(swat_scene if swat_scene != null else cop_scene)
	for ram_index: int in wave.ram_count:
		scenes.append(ram_scene if ram_scene != null else cop_scene)
	var size: int = maxi(1, squad_size)
	var squad_count: int = maxi(1, ceili(float(scenes.size()) / size))
	# A lone last officer joins the squad before instead of going it alone.
	if squad_count > 1 and scenes.size() % size == 1:
		squad_count -= 1
	var squads: Array[RaidSquad] = []
	for squad_index: int in squad_count:
		squads.append(RaidSquad.new())
	_squads.append_array(squads)
	for raider_index: int in scenes.size():
		_pending_spawns.append({
			"scene": scenes[raider_index], "delay": interval * raider_index,
			"health": wave.health_multiplier, "squad": squads[mini(raider_index / size, squad_count - 1)],
			"spot": raider_index,
		})


## Sends one raider into the yard now (tests, tutorials). Without a squad it
## goes straight for the door once it has reached the house.
func spawn_raider(raider_scene: PackedScene, health_multiplier: float = 1.0, squad: RaidSquad = null, door_spot: int = 0) -> Raider:
	if raider_scene == null or _yard == null:
		return null
	var raider: Raider = _yard.spawn_raider(raider_scene, squad, door_spot)
	raider.apply_wave_modifiers(health_multiplier, 1.0)
	return raider


func get_pending_spawn_count() -> int:
	return _pending_spawns.size()


## Officers of the current wave still to come or still standing.
func get_raiders_left() -> int:
	return _pending_spawns.size() + (_yard.get_alive_count() if _yard != null else 0)


## The squads of the waves in the yard (tests).
func get_squads() -> Array[RaidSquad]:
	return _squads


## Forgets officers that have not entered yet (the shift ended, admin).
func clear_pending() -> void:
	_pending_spawns.clear()


func _has_pending_for(squad: RaidSquad) -> bool:
	for pending: Dictionary in _pending_spawns:
		if pending["squad"] == squad:
			return true
	return false


func _step_pending_spawns(delta: float) -> void:
	for spawn_index: int in range(_pending_spawns.size() - 1, -1, -1):
		var pending: Dictionary = _pending_spawns[spawn_index]
		pending["delay"] = float(pending["delay"]) - delta
		if float(pending["delay"]) <= 0.0:
			_pending_spawns.remove_at(spawn_index)
			spawn_raider(pending["scene"] as PackedScene, float(pending["health"]), pending["squad"] as RaidSquad, int(pending["spot"]))

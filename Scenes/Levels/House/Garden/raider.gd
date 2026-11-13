## A police raider. In a raid it first jogs its way through the town
## (march(): a street route from the AttackerDirector) and climbs into the
## yard; officers spawned without a route enter at the yard's edge. In the
## yard it works its way to the front door with its RaidSquad: dashes to the next cover (a tree, rock,
## bush or the car, picked by YardNavigation), crouches there a while —
## longer when it is being shot at — and waits for the squad; from the last
## cover before the house the whole squad rushes the door together and
## hammers it. A battering-ram team skips cover, waits for the rush and hits
## the door very hard. Officers differ by exports (health, armor, speed,
## door damage). Pooled.
## Once the door is down (Yard.start_hunting) it hunts the nearest living
## player into the house — along WalkableArea routes, sliding along walls and
## furniture like the player does — and hits them when in reach. A player
## who comes out into the yard and close draws it into a fight too; while
## the door holds, it goes back to the door once nobody is left outside.
## State: Alive { Moving <-> InCover, Attacking, Hunting } -> Dead, Dead ->
## Alive on respawn (pool reuse).
##
## Dependencies: Yard, RaidSquad, FrontDoor, YardNavigation, HealthComponent,
##               HitFlash3DComponent, NpcVoice, VoiceLineData, WalkableArea,
##               PlayerVitals, Pools, Profile,
##               Events, Audio, Types autoloads, SfxSynth
class_name Raider
extends Node3D

signal defeated(raider: Raider)

const DEATH_SECONDS: float = 0.25
## Chance an officer cries out when hit / calls taking cover (chatter is
## rationed on top, so a raid never becomes a wall of voices).
const HIT_LINE_CHANCE: float = 0.5
const COVER_LINE_CHANCE: float = 0.35
## Damage a hit always does, however thick the armor.
const MIN_HIT_DAMAGE: float = 1.0
## Arrived when this close to the destination (meters).
const ARRIVE_DISTANCE: float = 0.15
## Seconds after a hit during which the raider counts as pinned down.
const SUPPRESSION_SECONDS: float = 2.5
const TURN_SPEED: float = 8.0
## Hit spheres of a crouching raider sit this much lower.
const CROUCHED_HIT_SCALE: float = 0.7
## Hunting: seconds between two routes to the player (they keep moving) ...
const ROUTE_SECONDS: float = 0.5
## ... and how close a waypoint counts as reached.
const WAYPOINT_REACHED: float = 0.35
## A player more than this far above or below (another floor) is out of reach.
const STRIKE_HEIGHT: float = 1.2
## Seconds between two looks for a player close by in the yard.
const ENGAGE_CHECK_SECONDS: float = 0.25
## A strike: how far the body lunges (a ram team further), and the lunge's
## out and back seconds.
## A hunting raider shut out stops this close (meters) to the door to hit it.
const DOOR_STRIKE_REACH: float = 1.4
const STRIKE_LUNGE: float = 0.25
const RAM_STRIKE_LUNGE: float = 0.45
const STRIKE_OUT_SECONDS: float = 0.08
const STRIKE_BACK_SECONDS: float = 0.22
## Stuck head-on, a hunting raider tries stepping around at this angle (radians) and twice it.
const SIDESTEP_ANGLE: float = PI * 0.25
## Seconds it keeps stepping around an obstacle once it started.
const SIDESTEP_HOLD_SECONDS: float = 0.4

@export var base_max_health: float = 120.0
## Meters per second between covers...
@export var move_speed: float = 1.7
## ...and when the squad rushes the door.
@export var rush_speed: float = 2.6
@export var door_damage: float = 16.0
@export var hit_interval_seconds: float = 1.0
@export var score_value: int = 15
## Display name for announcements ("Cops").
@export var faction_name: String = "Cops"

@export_group("Defense")
## Subtracted from every hit that doesn't pierce armor.
@export var armor: float = 0.0
## Multiplier on damage from turrets and guards.
@export var tower_damage_multiplier: float = 1.0

@export_group("Tactics")
## Seconds spent in each cover (random between x and y).
@export var cover_seconds: Vector2 = Vector2(1.5, 3.5)
## Farthest dash between two covers.
@export var max_cover_step: float = 7.0
## Closer than this to the door, the raider waits for the squad's rush.
@export var stage_distance: float = 6.5
## A battering-ram team: no cover, waits at the stage line, rams the door.
@export var is_battering_ram: bool = false

@export_group("Through the town")
## Meters per second while jogging through the streets to the house.
@export var march_speed: float = 3.2
## On the way, a player this close (meters) out in the street draws the
## officer into a fight...
@export var street_engage_range: float = 9.0
## ...and one who gets farther away than this (meters) is let go: back to the march.
@export var chase_range: float = 28.0

@export_group("Hunting")
## Damage each hit does to a player once the door is down.
@export var player_damage: float = 10.0
## How close (meters, across the floor) a player must be to be hit.
@export var strike_range: float = 1.3
## Out in the yard, a player this close (meters) draws the raider into a fight.
@export var engage_range: float = 3.0

@export_group("Body")
## Radius of the sphere shots hit.
@export var hit_radius: float = 0.45
## Height of that sphere's center above the node origin.
@export var hit_height: float = 0.8
## Radius kept clear of obstacles and other raiders.
@export var body_radius: float = 0.35

## The squad this raider moves with (set by the director).
var squad: RaidSquad = null
## Waiting in the last cover for the squad's rush.
var is_staged: bool = false
## Which spot in front of the door is this raider's (set by the director).
var door_spot_index: int = 0

var _yard: Yard = null
var _destination: Vector2 = Vector2.ZERO
var _is_heading_for_door: bool = false
var _is_in_motion: bool = true
var _speed: float = 0.0
var _health_multiplier: float = 1.0
var _seconds_until_move: float = 0.0
var _seconds_since_hit: float = SUPPRESSION_SECONDS
var _seconds_until_hit: float = 0.0
var _last_direction: Vector2 = Vector2.ZERO
var _has_been_used: bool = false
var _is_frozen: bool = false
var _is_hunting: bool = false
## Hunting: the waypoints still ahead (WalkableArea.find_path).
var _route: PackedVector3Array = PackedVector3Array()
var _seconds_until_route: float = 0.0
var _seconds_until_engage_check: float = 0.0
## The way through the town still ahead (world X / Z) and the next point on it.
var _street_route: PackedVector2Array = PackedVector2Array()
var _street_index: int = 0
var _is_far_drawn: bool = false
## Which side (+1 / -1) it steps around obstacles to.
var _sidestep_sign: float = 1.0
var _sidestep_seconds_left: float = 0.0
var _tween: Tween

@onready var health_component: HealthComponent = %HealthComponent
@onready var hit_flash_component: HitFlash3DComponent = %HitFlash3DComponent
@onready var state_chart: StateChart = %StateChart
@onready var _visual: Node3D = %Visual
## The officer's voice (shouts in a raid).
@onready var voice: NpcVoice = %Voice
## The bodies under Visual (one per officer; a ram team has two).
var _bodies: Array[RaiderBody] = []


func _ready() -> void:
	add_to_group(Types.GROUP_ENEMY)
	health_component.died.connect(func() -> void: state_chart.send_event(Types.EVENT_DIED))
	health_component.damaged.connect(func(_damage_info: DamageInfo) -> void: _seconds_since_hit = 0.0)
	_reset_stats()
	for child: Node in _visual.get_children():
		if child is RaiderBody:
			_bodies.append(child as RaiderBody)

# ============================================
# PUBLIC API
# ============================================

## Called by the yard for a raider that comes through the town: it jogs
## [param route] (world X / Z, from where it stands to a point in the yard),
## then fights in the yard like one that entered there.
func march(route: PackedVector2Array, yard: Yard) -> void:
	_yard = yard
	_street_route = route
	_street_index = 1
	_on_march_started()
	if _street_route.size() < 2:
		_finish_march()


## True while it is still on its way through the town.
func is_marching() -> bool:
	return not _street_route.is_empty()


## Called by the yard after spawning.
func enter_yard(yard: Yard) -> void:
	_yard = yard
	_plan_next_move()
	if yard.is_hunting():
		start_hunting()


## The front door is down: from now on it goes after the nearest player.
func start_hunting() -> void:
	if not is_alive() or _is_hunting:
		return
	# Still on the way through the town: it hunts once it reaches the yard
	# (_finish_march), instead of cutting straight through the buildings.
	if is_marching():
		return
	_is_hunting = true
	is_staged = false
	_is_heading_for_door = false
	# Deferred: a raider spawned this frame enters its chart's first state
	# only at the end of the frame, and an event before that is lost.
	state_chart.send_event.call_deferred(Types.EVENT_HUNT)


## True once it is going after the players.
func is_hunting() -> bool:
	return _is_hunting


## Scales the raider (later raids). Speed is kept: tougher, not faster.
func apply_wave_modifiers(health_multiplier: float, _speed_multiplier: float) -> void:
	_health_multiplier = health_multiplier
	_reset_stats()


func is_alive() -> bool:
	return not health_component.is_dead and not Pools.is_in_pool(self)


## Out of cover and on the way somewhere (squads let only some move at once).
func is_moving() -> bool:
	return _is_in_motion


## Where it is heading (a cover spot or its spot at the door).
func get_destination() -> Vector2:
	return _destination


## True while it is hitting the front door.
func is_at_door() -> bool:
	return _is_heading_for_door and not _is_in_motion and is_alive()


## Applies a hit. Turret and guard hits are scaled by tower_damage_multiplier;
## armor is subtracted unless [param pierces_armor].
func take_hit(amount: float, source: Node = null, from_tower: bool = false, pierces_armor: bool = false) -> void:
	var damage: float = amount * (tower_damage_multiplier if from_tower else 1.0)
	if not pierces_armor:
		damage -= armor
	health_component.damage(maxf(MIN_HIT_DAMAGE, damage), source)
	if not health_component.is_dead and randf() < HIT_LINE_CHANCE:
		voice.say(VoiceLineData.HIT)


## How tall the body stands for fists and blades (lower while crouching).
func get_body_height() -> float:
	return (get_hit_center().y - global_position.y) * 2.0


## Center of the sphere shots aim at (lower while crouching in cover).
func get_hit_center() -> Vector3:
	var crouch: float = _bodies[0].get_crouch_amount() if not _bodies.is_empty() else 0.0
	return global_position + Vector3(0.0, hit_height * lerpf(1.0, CROUCHED_HIT_SCALE, crouch), 0.0)


## The squad rushes: everyone heads for the door.
func on_squad_rush() -> void:
	if not is_alive():
		return
	voice.say(VoiceLineData.ADVANCE)
	is_staged = false
	_head_for_door()


## The call that opens a raid ("Polizei! Aufmachen!"), always heard.
func shout_raid_call() -> void:
	voice.say(VoiceLineData.RAID, true)


## True for a single officer (not a ram team or a vehicle): far away a
## CrowdLod draws it as a simple figure instead of its jointed body.
func uses_crowd_figure() -> bool:
	return _bodies.size() == 1


## Far away (true): the jointed body is hidden and a CrowdLod draws it.
func set_far_drawn(is_far: bool) -> void:
	_is_far_drawn = is_far
	_visual.visible = not is_far


## True while far away and drawn by a CrowdLod.
func is_far_drawn() -> bool:
	return _is_far_drawn


## True while it keeps its wave going (alive; a vehicle that has done its
## job and is leaving doesn't).
func counts_for_wave() -> bool:
	return is_alive()


## The simple figure's colors: [uniform, head (cap or helmet)].
func get_crowd_colors() -> PackedColorArray:
	if _bodies.is_empty():
		return PackedColorArray([Palette.STROKE, Palette.BACKGROUND])
	return PackedColorArray([_bodies[0].uniform_color, _bodies[0].vest_color])


## Stops it where it stands (end of the shift, staged scenes) or lets it go again.
func freeze(should_freeze: bool = true) -> void:
	_is_frozen = should_freeze

# ============================================
# POOLING
# ============================================

func _on_pool_spawned() -> void:
	_health_multiplier = 1.0
	_reset_stats()
	hit_flash_component.reset()
	if _tween != null:
		_tween.kill()
	_visual.scale = Vector3.ONE
	_visual.position = Vector3.ZERO
	set_far_drawn(false)
	_visual.rotation = Vector3.ZERO
	for body: RaiderBody in _bodies:
		body.reset_pose()
	squad = null
	is_staged = false
	door_spot_index = 0
	_is_heading_for_door = false
	_is_hunting = false
	_route = PackedVector3Array()
	_seconds_until_engage_check = randf() * ENGAGE_CHECK_SECONDS
	_sidestep_sign = 1.0
	_sidestep_seconds_left = 0.0
	_street_route = PackedVector2Array()
	_street_index = 0
	# Every (re)spawn starts in Moving (the chart's initial / respawn state).
	_is_in_motion = true
	_is_frozen = false
	_last_direction = Vector2.ZERO
	_seconds_since_hit = SUPPRESSION_SECONDS
	voice.reset()
	if _has_been_used:
		state_chart.send_event(Types.EVENT_RESPAWN)
	_has_been_used = true


func _on_pool_despawned() -> void:
	voice.reset()
	_yard = null
	squad = null

# ============================================
# STATE CHART CALLBACKS (connected in Raider.tscn)
# ============================================

func _on_moving_state_entered() -> void:
	_is_in_motion = true
	_set_crouched(false)


func _on_moving_state_physics_processing(delta: float) -> void:
	if _yard == null or _is_frozen:
		return
	# On the way through the town it keeps going (it fights in the yard).
	if is_marching():
		# A player out in the street close by is fought right there.
		if not _watch_for_players(delta, street_engage_range):
			_step_march(delta)
		return
	if _watch_for_players(delta):
		return
	_seconds_since_hit += delta
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	if here.distance_to(_destination) <= ARRIVE_DISTANCE:
		_arrive()
		return
	var direction: Vector2 = YardNavigation.steer(here, _destination, _yard.get_obstacle_circles(), _yard.get_raider_positions(), body_radius, _last_direction)
	_last_direction = direction
	var next: Vector2 = here + direction * _speed * delta
	next = YardNavigation.resolve_overlap(next, _yard.get_obstacle_circles(), body_radius)
	# Door spots lie right against the house; everything else stays in the field.
	if not _is_heading_for_door:
		next = _yard.clamp_to_bounds(next)
	global_position = Vector3(next.x, global_position.y, next.y)
	_face(direction, delta)
	_animate_bodies(delta, _speed / maxf(0.1, move_speed))


func _on_in_cover_state_entered() -> void:
	_is_in_motion = false
	_set_crouched(not is_battering_ram)
	_seconds_until_move = randf_range(cover_seconds.x, cover_seconds.y)
	if randf() < COVER_LINE_CHANCE:
		voice.say(VoiceLineData.COVER)
	_face_toward(_yard.get_door_point() if _yard != null else Vector2.ZERO, 1.0)


func _on_in_cover_state_physics_processing(delta: float) -> void:
	_animate_bodies(delta, 0.0)
	if _yard == null or _is_frozen or _watch_for_players(delta):
		return
	_seconds_since_hit += delta
	# Pinned down: shots keep the head low.
	if _seconds_since_hit < SUPPRESSION_SECONDS:
		return
	if is_staged:
		return
	_seconds_until_move -= delta
	if _seconds_until_move <= 0.0 and (squad == null or squad.may_move(self)):
		_plan_next_move()


func _on_attacking_state_entered() -> void:
	_is_in_motion = false
	_set_crouched(false)
	_seconds_until_hit = hit_interval_seconds * 0.5
	if is_battering_ram:
		voice.say(VoiceLineData.RAM)
	_face_toward(_yard.get_door_point() if _yard != null else Vector2.ZERO, 1.0)


func _on_attacking_state_physics_processing(delta: float) -> void:
	_animate_bodies(delta, 0.0)
	if _yard == null or _is_frozen or _watch_for_players(delta) or _yard.door == null or not _yard.door.is_alive():
		return
	_seconds_until_hit -= delta
	if _seconds_until_hit > 0.0:
		return
	_seconds_until_hit = hit_interval_seconds
	# A steel frame takes some of every hit (FrontDoor.get_damage_multiplier).
	_yard.door.health_component.damage(door_damage * _yard.door.get_damage_multiplier(), self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.15, -2.0 if is_battering_ram else -6.0)
	_play_strike(RAM_STRIKE_LUNGE if is_battering_ram else STRIKE_LUNGE)


func _on_hunting_state_entered() -> void:
	_is_in_motion = true
	_set_crouched(false)
	_route = PackedVector3Array()
	# Spread over the interval, so a whole squad doesn't plan its routes in the same frame.
	_seconds_until_route = randf() * ROUTE_SECONDS
	_seconds_until_hit = hit_interval_seconds * 0.5
	voice.say(VoiceLineData.ADVANCE)


func _on_hunting_state_physics_processing(delta: float) -> void:
	if _yard == null or _is_frozen:
		_animate_bodies(delta, 0.0)
		return
	# While the door holds, a raider outside (yard or street) only fights
	# players outside too, and lets them go once they got away.
	var is_outdoor_fight: bool = not _yard.is_hunting() and _yard.is_outdoors(global_position)
	var target: PlayerVitals = _yard.find_hunt_target(global_position, is_outdoor_fight, chase_range if is_outdoor_fight else INF)
	if target == null:
		if is_outdoor_fight:
			_give_up_hunting()
			return
		_animate_bodies(delta, 0.0)
		return
	var target_feet: Vector3 = target.get_feet_position()
	var to_target: Vector3 = target_feet - global_position
	if Vector2(to_target.x, to_target.z).length() <= strike_range and absf(to_target.y) < STRIKE_HEIGHT:
		_animate_bodies(delta, 0.0)
		_face_toward(Vector2(target_feet.x, target_feet.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
		_seconds_until_hit -= delta
		if _seconds_until_hit <= 0.0:
			_seconds_until_hit = hit_interval_seconds
			_strike_player(target)
		return
	# Storming the house but shut out (the door was shut again): break it
	# down first. A fight out in the street is not about the door.
	if _yard.is_hunting() and _yard.is_outdoors(global_position) and _yard.door != null and _yard.door.is_alive() and not _yard.door.is_passable():
		_hit_door_on_the_way(delta)
		return
	var walkable: WalkableArea = _yard.walkable
	if walkable == null or not walkable.contains(global_position):
		# Off the player's floors (beyond the garden fence, in a bush): no
		# route from here — make for the front door, the floors start on the way.
		var door_point: Vector2 = _yard.get_door_point()
		_walk_toward(Vector3(door_point.x, global_position.y, door_point.y), rush_speed, delta)
		return
	_seconds_until_route -= delta
	if _seconds_until_route <= 0.0:
		_seconds_until_route = ROUTE_SECONDS
		_route = walkable.find_path(global_position, target_feet)
	# No route (the player is somewhere it can't reach yet): close in along the walls.
	var waypoint: Vector3 = target_feet
	while not _route.is_empty():
		waypoint = _route[0]
		if _route.size() == 1 or Vector2(waypoint.x - global_position.x, waypoint.z - global_position.z).length() > WAYPOINT_REACHED:
			break
		_route.remove_at(0)
	_walk_toward(waypoint, rush_speed, delta)


## On the hunt but shut out: walks to the door and hammers it until it gives.
func _hit_door_on_the_way(delta: float) -> void:
	var door_point: Vector2 = _yard.get_door_point()
	var to_door: Vector2 = door_point - Vector2(global_position.x, global_position.z)
	if to_door.length() > DOOR_STRIKE_REACH:
		_walk_toward(Vector3(door_point.x, global_position.y, door_point.y), rush_speed, delta)
		return
	_animate_bodies(delta, 0.0)
	_face_toward(door_point, clampf(TURN_SPEED * delta, 0.0, 1.0))
	_seconds_until_hit -= delta
	if _seconds_until_hit > 0.0:
		return
	_seconds_until_hit = hit_interval_seconds
	_yard.door.health_component.damage(door_damage * _yard.door.get_damage_multiplier(), self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.15, -6.0)
	_play_strike(STRIKE_LUNGE)


## Out in the yard: a player close by draws the raider into a fight
## (checked a few times a second). Returns true when it starts hunting.
func _watch_for_players(delta: float, reach: float = -1.0) -> bool:
	_seconds_until_engage_check -= delta
	if _seconds_until_engage_check > 0.0:
		return false
	_seconds_until_engage_check = ENGAGE_CHECK_SECONDS
	if _yard.find_hunt_target(global_position, true, engage_range if reach < 0.0 else reach) == null:
		return false
	_engage()
	return true


## Goes after a player out here now (in the yard or the street), dropping
## its march; it picks the march up again if the player gets away.
func _engage() -> void:
	if not is_alive() or _is_hunting:
		return
	_street_route = PackedVector2Array()
	_street_index = 0
	_is_hunting = true
	is_staged = false
	_is_heading_for_door = false
	state_chart.send_event.call_deferred(Types.EVENT_HUNT)


## Nobody left to fight out here while the door holds: rush the door again.
func _give_up_hunting() -> void:
	_is_hunting = false
	_route = PackedVector3Array()
	# Out in the town: back through the streets to the yard first.
	if not _yard.is_in_yard(global_position):
		state_chart.send_event(Types.EVENT_MOVE)
		march(_yard.plan_route_to_yard(Vector2(global_position.x, global_position.z)), _yard)
		return
	_head_for_door()
	state_chart.send_event(Types.EVENT_MOVE)


## Hits [param player] (the same blow as at the door).
func _strike_player(player: PlayerVitals) -> void:
	player.take_damage(player_damage, self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.15, -4.0)
	_play_strike(STRIKE_LUNGE)


## The blow itself (at the door or at a player): every body swings and the
## raider lunges [param lunge] meters forward and back.
func _play_strike(lunge: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	for body: RaiderBody in _bodies:
		body.play_strike()
	_tween.tween_property(_visual, "position:z", lunge, STRIKE_OUT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "position:z", 0.0, STRIKE_BACK_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## One step toward [param point]. On the player's floors, walls, holes and
## furniture stop it like they stop the player (it slides along them) and
## stairs carry it up or down; off them it walks freely (onto them).
func _walk_toward(point: Vector3, speed: float, delta: float) -> void:
	var direction: Vector2 = Vector2(point.x - global_position.x, point.z - global_position.z)
	if direction.length() < 0.01:
		_animate_bodies(delta, 0.0)
		return
	direction = direction.normalized()
	var next: Vector3 = global_position + Vector3(direction.x, 0.0, direction.y) * speed * delta
	var walkable: WalkableArea = _yard.walkable
	if walkable != null and walkable.contains(global_position):
		var step_length: float = speed * delta
		var wanted: Vector3 = next
		next = walkable.clamp_move(global_position, wanted)
		# Head-on into a post, a tree or a tower: sliding along an axis goes
		# nowhere — step around it to the side it went last time, and keep
		# stepping that way a moment (else it turns straight back into it).
		if _sidestep_seconds_left > 0.0:
			_sidestep_seconds_left -= delta
			var held: Vector2 = direction.rotated(SIDESTEP_ANGLE * 2.0 * _sidestep_sign)
			var held_step: Vector3 = walkable.clamp_move(global_position, global_position + Vector3(held.x, 0.0, held.y) * step_length)
			if held_step.distance_to(global_position) >= step_length * 0.2:
				next = held_step
		elif next.distance_to(global_position) < step_length * 0.2:
			for turn: float in [SIDESTEP_ANGLE, SIDESTEP_ANGLE * 2.0]:
				var side: Vector2 = direction.rotated(turn * _sidestep_sign)
				var around: Vector3 = walkable.clamp_move(global_position, global_position + Vector3(side.x, 0.0, side.y) * step_length)
				if around.distance_to(global_position) >= step_length * 0.2:
					next = around
					_sidestep_seconds_left = SIDESTEP_HOLD_SECONDS
					break
			if next.distance_to(global_position) < step_length * 0.2:
				_sidestep_sign = -_sidestep_sign
	global_position = next
	_last_direction = direction
	_face(direction, delta)
	_animate_bodies(delta, speed / maxf(0.1, move_speed))


func _on_dead_state_entered() -> void:
	_is_in_motion = false
	is_staged = false
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	Events.enemy_defeated.emit(self)
	defeated.emit(self)
	voice.say_last_words(VoiceLineData.DOWN)
	Audio.play_sfx_at(SfxSynth.get_preset(&"pop"), global_position, 0.15)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, DEATH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Pools.despawn.bind(self))

# ============================================
# INTERNALS
# ============================================

## One frame of jogging through the town toward the next point of the way.
func _step_march(delta: float) -> void:
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	var target: Vector2 = _street_route[_street_index]
	var to_target: Vector2 = target - here
	var step_length: float = march_speed * delta
	if to_target.length() <= step_length:
		global_position = Vector3(target.x, global_position.y, target.y)
		_street_index += 1
		if _street_index >= _street_route.size():
			_finish_march()
		return
	var direction: Vector2 = to_target.normalized()
	global_position += Vector3(direction.x, 0.0, direction.y) * step_length
	_face(direction, delta)
	_animate_bodies(delta, march_speed / maxf(0.1, move_speed))


## @virtual Setting off through the town (vehicles take off, lift up...).
func _on_march_started() -> void:
	pass


## @virtual At the end of the way through the town: an officer is in the
## yard now and fights there like one that entered at its edge.
func _finish_march() -> void:
	_street_route = PackedVector2Array()
	_street_index = 0
	_plan_next_move()
	if _yard != null and _yard.is_hunting():
		start_hunting()


## Picks where to go next: the squad's rush → the door; otherwise the next
## cover toward the house, or — near the house — wait here for the rush.
func _plan_next_move() -> void:
	if _yard == null:
		return
	if squad != null and squad.is_rushing():
		_head_for_door()
		return
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	var door_point: Vector2 = _yard.get_door_point()
	if is_battering_ram:
		var stage_point: Vector2 = door_point + (here - door_point).normalized() * stage_distance
		if here.distance_to(door_point) <= stage_distance + 0.3:
			_stage()
		else:
			_go_to(stage_point, move_speed)
		return
	var cover: Vector2 = YardNavigation.NO_SPOT
	if here.distance_to(door_point) > stage_distance:
		cover = YardNavigation.find_cover_spot(here, door_point, _yard.get_obstacle_circles(), _yard.get_reserved_spots(self), max_cover_step, 1.5, body_radius)
	if cover == YardNavigation.NO_SPOT:
		if here.distance_to(door_point) <= stage_distance + max_cover_step * 0.5:
			_stage()
		else:
			# Open ground ahead: dash a stretch straight at the house.
			_go_to(here + (door_point - here).normalized() * minf(max_cover_step, here.distance_to(door_point) - stage_distance), move_speed)
		return
	_go_to(cover, move_speed)


func _stage() -> void:
	is_staged = true
	_destination = Vector2(global_position.x, global_position.z)
	if squad == null:
		_head_for_door()
	elif _is_in_motion:
		state_chart.send_event(Types.EVENT_TAKE_COVER)


func _head_for_door() -> void:
	if _yard == null:
		return
	var spots: PackedVector2Array = _yard.get_door_spots(door_spot_index + 1)
	_is_heading_for_door = true
	_go_to(spots[door_spot_index], rush_speed)


func _go_to(destination: Vector2, speed: float) -> void:
	_destination = destination
	_speed = speed
	if not _is_in_motion:
		state_chart.send_event(Types.EVENT_MOVE)


func _arrive() -> void:
	if _is_heading_for_door:
		state_chart.send_event(Types.EVENT_TARGET_IN_RANGE)
	else:
		state_chart.send_event(Types.EVENT_TAKE_COVER)


func _set_crouched(is_crouched: bool) -> void:
	for body: RaiderBody in _bodies:
		body.set_crouched(is_crouched)


func _face(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_yaw: float = atan2(direction.x, direction.y)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _face_toward(point: Vector2, weight: float) -> void:
	var direction: Vector2 = point - Vector2(global_position.x, global_position.z)
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.y), weight)


func _reset_stats() -> void:
	health_component.revive(base_max_health * _health_multiplier)


## Walk cycle, crouch easing and strikes of every body (a ram team has two).
func _animate_bodies(delta: float, speed_ratio: float) -> void:
	for body: RaiderBody in _bodies:
		body.animate(delta, speed_ratio)

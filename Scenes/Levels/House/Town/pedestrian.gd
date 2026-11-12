## A person walking the town's sidewalks: from corner to corner around the
## blocks and across the streets, pausing now and then, muttering a remark
## when the player passes close by. Point at them and pull the trigger to
## talk (the Town runs the conversation); they stop and face the player.
## Pooled. State: Walking <-> Pausing, either -> Talking -> Walking.
##
## Dependencies: TownLayout, RaiderBody, NpcVoice, VoiceData, VoiceLineData,
##               PointerButton, Pools, Types autoloads, Palette
class_name Pedestrian
extends Node3D

## The player pressed the trigger on this person.
signal talk_requested(pedestrian: Pedestrian)

## Seconds between checks whether the player is close enough for a remark.
const REMARK_CHECK_SECONDS: float = 2.5
const REMARK_DISTANCE: float = 4.5
const REMARK_CHANCE: float = 0.3
## Clothes, skin and hair to dress people from (realistic, muted tones).
const JACKET_COLORS: Array[Color] = [
	Color(0.18, 0.2, 0.26), Color(0.32, 0.3, 0.27), Color(0.42, 0.16, 0.15), Color(0.16, 0.27, 0.22),
	Color(0.55, 0.53, 0.5), Color(0.12, 0.12, 0.13), Color(0.6, 0.45, 0.22), Color(0.22, 0.3, 0.45),
]
const LEGS_COLORS: Array[Color] = [Color(0.15, 0.19, 0.3), Color(0.1, 0.1, 0.11), Color(0.36, 0.33, 0.28), Color(0.25, 0.26, 0.29)]
const SKIN_COLORS: Array[Color] = [Color(0.96, 0.8, 0.69), Color(0.87, 0.69, 0.55), Color(0.72, 0.53, 0.39), Color(0.52, 0.36, 0.25), Color(0.36, 0.24, 0.17)]
const HAIR_COLORS: Array[Color] = [Color(0.1, 0.08, 0.07), Color(0.3, 0.2, 0.12), Color(0.55, 0.42, 0.25), Color(0.7, 0.7, 0.7), Color(0.2, 0.2, 0.22)]

## Walking pace on the sidewalks (m/s).
@export var walk_speed: float = 1.25

## Pitched once already today (they won't be asked twice).
var was_pitched: bool = false
## The corner they are walking to (TownLayout.corners index).
var target_corner: int = -1

var _layout: TownLayout = null
var _previous_corner: int = -1
var _pause_left: float = 0.0
var _seconds_until_remark_check: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _face_point: Vector3 = Vector3.ZERO
var _has_been_used: bool = false

@onready var body: RaiderBody = %Body
@onready var voice: NpcVoice = %Voice
@onready var _talk_button: PointerButton = %TalkButton
@onready var state_chart: StateChart = %StateChart


func _ready() -> void:
	_random.randomize()
	_talk_button.pressed.connect(func(_button: PointerButton) -> void: talk_requested.emit(self))


## Puts this person on the sidewalks of [param layout] at corner
## [param corner], dressed at random and speaking with [param person_voice].
func setup(layout: TownLayout, corner: int, person_voice: VoiceData) -> void:
	_layout = layout
	voice.voice = person_voice
	was_pitched = false
	_dress()
	place_at_corner(corner)


## Moves straight to [param corner] (recycling a person far from the player).
func place_at_corner(corner: int) -> void:
	if _layout == null or corner < 0:
		return
	var spot: Vector2 = _layout.corners[corner]
	global_position = Vector3(spot.x, 0.0, spot.y)
	_previous_corner = -1
	target_corner = corner
	_pick_next_corner()


## Stops and turns to the player at [param player_position] for a talk.
func begin_talk(player_position: Vector3) -> void:
	_face_point = player_position
	voice.stop()
	# The panel beside them shows the words.
	voice.shows_subtitles = false
	state_chart.send_event(Types.EVENT_TALK)


## Walks on after a talk.
func end_talk() -> void:
	voice.shows_subtitles = true
	state_chart.send_event(Types.EVENT_WALK)


## A random voice name for the dialogue panel ("Passer-by" when unknown).
func get_display_name() -> String:
	return voice.voice.display_name if voice.voice != null else ""


func _on_pool_spawned() -> void:
	voice.reset()
	body.reset_pose()
	if _has_been_used:
		state_chart.send_event(Types.EVENT_WALK)
	_has_been_used = true


func _on_pool_despawned() -> void:
	voice.reset()

# ============================================
# STATE CHART CALLBACKS (connected in Pedestrian.tscn)
# ============================================

func _on_walking_state_physics_processing(delta: float) -> void:
	if _layout == null or target_corner < 0:
		body.animate(delta, 0.0)
		return
	var spot: Vector2 = _layout.corners[target_corner]
	var to_target: Vector3 = Vector3(spot.x - global_position.x, 0.0, spot.y - global_position.z)
	var distance: float = to_target.length()
	if distance < 0.1:
		_pick_next_corner()
		if _random.randf() < 0.35:
			_pause_left = _random.randf_range(1.0, 3.5)
			state_chart.send_event(Types.EVENT_ARRIVED)
		return
	var step: float = minf(distance, walk_speed * delta)
	global_position += to_target / distance * step
	_turn_toward(to_target, delta)
	body.animate(delta, walk_speed / 1.4)
	_seconds_until_remark_check -= delta
	if _seconds_until_remark_check <= 0.0:
		_seconds_until_remark_check = REMARK_CHECK_SECONDS
		_maybe_remark()


func _on_pausing_state_processing(delta: float) -> void:
	body.animate(delta, 0.0)
	_pause_left -= delta
	if _pause_left <= 0.0:
		state_chart.send_event(Types.EVENT_WALK)


func _on_talking_state_physics_processing(delta: float) -> void:
	body.animate(delta, 0.0)
	_turn_toward(_face_point - global_position, delta)

# ============================================
# INTERNALS
# ============================================

## Next corner: around the block or across a street, never straight back.
func _pick_next_corner() -> void:
	var links: PackedInt32Array = _layout.corner_links[target_corner]
	var options: Array[int] = []
	for link: int in links:
		if link != _previous_corner:
			options.append(link)
	if options.is_empty():
		options.append(_previous_corner)
	_previous_corner = target_corner
	target_corner = options[_random.randi_range(0, options.size() - 1)]


func _turn_toward(direction: Vector3, delta: float) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(flat.x, flat.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, minf(1.0, delta * 8.0))


func _maybe_remark() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(global_position) > REMARK_DISTANCE:
		return
	if _random.randf() < REMARK_CHANCE:
		voice.say(VoiceLineData.AMBIENT)


func _dress() -> void:
	body.uniform_color = JACKET_COLORS[_random.randi_range(0, JACKET_COLORS.size() - 1)]
	body.vest_color = body.uniform_color.lightened(0.35)
	body.legs_color = LEGS_COLORS[_random.randi_range(0, LEGS_COLORS.size() - 1)]
	body.skin_color = SKIN_COLORS[_random.randi_range(0, SKIN_COLORS.size() - 1)]
	body.hair_color = HAIR_COLORS[_random.randi_range(0, HAIR_COLORS.size() - 1)]
	body.headgear = RaiderBody.Headgear.BEANIE if _random.randf() < 0.25 else RaiderBody.Headgear.HAIR
	var height_scale: float = _random.randf_range(0.92, 1.06)
	body.scale = Vector3(height_scale, height_scale, height_scale)

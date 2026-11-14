## The house's alarm once the first raider comes through the front door
## (broken or left open; FrontGarden): it is all or nothing now. A stinger hit, a shouted "Zugriff!" at the door and a hard
## rumble in both hands jolt the player (a jump scare by sound and touch —
## never a camera move or a screen flash); then sirens wail out in the
## street, a loud chase track kicks in and police beacons turn on the
## ceilings, sweeping red and blue light beams (no real lights: they are
## too expensive on a standalone headset) — until the raid is beaten.
##
##   alarm.setup(rig)
##   alarm.start(door.global_position)   # HouseLevel on Events.house_breached (a raider came in)
##   alarm.stop()                        # on Events.house_breach_ended
##
## The sounds are made by MusicSynth on a worker thread at level start.
##
## Dependencies: XRPlayerRig, XRPointer, MusicSynth, Audio, Types autoloads
class_name BreachAlarm
extends Node3D

## How loud the chase track plays (on the music bus).
@export var music_volume_db: float = 0.0
@export var siren_volume_db: float = 4.0
@export var stinger_volume_db: float = 3.0
## The shout at the door ("Zugriff, Zugriff, Zugriff!").
@export var shout: AudioStream
@export var shout_volume_db: float = 8.0
## The music comes in after the stinger and the shout.
@export var music_delay_seconds: float = 0.9
## Seconds the sirens and the music take to die away after the raid.
@export var fade_out_seconds: float = 2.5
## Beacon rotors turn this often a second (slow: a sweep, not a strobe).
@export var beacon_turns_per_second: float = 0.8
## The beacons (shown only during a breach) and their spinning rotors.
@export var beacons: Array[Node3D] = []
@export var rotors: Array[Node3D] = []
## Sirens out in the street (positional, looping).
@export var sirens: Array[AudioStreamPlayer3D] = []

var _rig: XRPlayerRig = null
var _is_active: bool = false
var _sound_task: int = -1
var _fade_tween: Tween = null


func _ready() -> void:
	set_process(false)
	_show_beacons(false)
	if not MusicSynth.is_breach_ready():
		_sound_task = WorkerThreadPool.add_task(MusicSynth.prepare_breach_sounds, false, "breach sounds")


func _exit_tree() -> void:
	if _is_active:
		Audio.stop_music(0.3)
	_finish_sound_task()

# ============================================
# PUBLIC API
# ============================================

## The player whose hands rumble.
func setup(rig: XRPlayerRig) -> void:
	_rig = rig


## The door is down: stinger, shout and rumble, then sirens, music and beacons.
func start(door_position: Vector3) -> void:
	if _is_active:
		return
	_is_active = true
	_finish_sound_task()
	if _fade_tween != null:
		_fade_tween.kill()
	Audio.play_sfx(MusicSynth.get_stinger(), 0.0, stinger_volume_db)
	if shout != null:
		Audio.play_sfx_at(shout, door_position + Vector3(0.0, 1.6, 0.0), 0.0, shout_volume_db)
	if _rig != null:
		for pointer: XRPointer in _rig.get_active_pointers():
			_rig.pulse(pointer, Types.HapticStrength.HEAVY)
	var siren_stream: AudioStreamWAV = MusicSynth.get_siren()
	var siren_seconds: float = siren_stream.get_length()
	for siren_index: int in sirens.size():
		var siren: AudioStreamPlayer3D = sirens[siren_index]
		siren.stream = siren_stream
		siren.volume_db = siren_volume_db
		# Out of step with each other, like two cars.
		siren.play(siren_seconds * float(siren_index) / float(maxi(1, sirens.size())) * 0.37)
	_show_beacons(true)
	set_process(true)
	await get_tree().create_timer(music_delay_seconds, false).timeout
	if _is_active:
		Audio.play_music(MusicSynth.get_chase_loop(), 0.2, music_volume_db)


## The raid is beaten: everything dies away.
func stop() -> void:
	if not _is_active:
		return
	_is_active = false
	Audio.stop_music(fade_out_seconds)
	_fade_tween = create_tween().set_parallel(true)
	for siren: AudioStreamPlayer3D in sirens:
		_fade_tween.tween_property(siren, "volume_db", -60.0, fade_out_seconds)
	_fade_tween.chain().tween_callback(_silence)


func is_active() -> bool:
	return _is_active

# ============================================
# INTERNALS
# ============================================

func _process(delta: float) -> void:
	for rotor: Node3D in rotors:
		rotor.rotate_y(TAU * beacon_turns_per_second * delta)


func _silence() -> void:
	for siren: AudioStreamPlayer3D in sirens:
		siren.stop()
	_show_beacons(false)
	set_process(false)


func _show_beacons(is_shown: bool) -> void:
	for beacon: Node3D in beacons:
		beacon.visible = is_shown


## Every worker task must be waited for; the sounds are needed now anyway.
func _finish_sound_task() -> void:
	if _sound_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_sound_task)
		_sound_task = -1

## Lets an NPC speak: plays one of its voice's lines from where its head is
## (positional, so the player hears who is talking) and shows the words as a
## subtitle above it while the line plays. Place it at head height.
##
##   %Voice.voice = order.customer_type.voice
##   %Voice.say(VoiceLineData.GREET, true)          # important: always spoken
##   await %Voice.line_finished
##
## Chatter (passing remarks, cries in a raid) is rationed: only a few NPCs
## talk at once, and each waits a moment between lines, so a street or a
## raid never turns into a wall of voices. Important lines (dialogue, the
## customer at the window) always play.
##
## Dependencies: VoiceData, VoiceLineData, LinePicker, Settings, Audio autoloads, Palette
class_name NpcVoice
extends Node3D

## The line that was playing ended, or was cut off (by stop(), another line
## or the NPC leaving): anyone awaiting it always wakes up.
signal line_finished

## Chatter lines playing at once across all NPCs.
const MAX_CHATTER_SPEAKERS: int = 2
## Subtitles of NPCs farther away than this (meters) stay hidden.
const SUBTITLE_DISTANCE: float = 9.0
## Within this distance (meters) a voice plays at full volume; beyond it,
## it drops by 6 dB every time the distance doubles (inverse square, like
## real speech), so a voice near you is clear and one across the house quiet.
const VOICE_UNIT_SIZE: float = 2.0
## Farther than this (meters) a voice is not heard at all.
const VOICE_MAX_DISTANCE: float = 24.0

## Milliseconds between two last words (say_last_words) across all NPCs.
const LAST_WORDS_GAP_MSEC: int = 1500

## Shared across every NPC: how many chatter lines are playing right now.
static var _chatter_speakers: int = 0
## Shared across every NPC: no last words before this time.
static var _last_words_quiet_until_msec: int = 0

## Whose voice this is (a customer type's, a passer-by's, the police).
@export var voice: VoiceData
## Seconds an NPC stays quiet after a chatter line.
@export var chatter_cooldown_seconds: float = 4.0
## Subtitle height above this node (meters).
@export var subtitle_offset: float = 0.38

## The line playing now (null when quiet).
var current_line: VoiceLineData = null
## Off while the words show somewhere else (a conversation panel).
var shows_subtitles: bool = true

var _player: AudioStreamPlayer3D = null
var _subtitle: Label3D = null
var _picker: LinePicker = LinePicker.new()
var _is_chatter: bool = false
var _quiet_until_msec: int = 0
## Counts lines, so a timer of an earlier line never ends a newer one.
var _line_serial: int = 0


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.bus = Settings.BUS_SFX
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	_player.unit_size = VOICE_UNIT_SIZE
	_player.max_distance = VOICE_MAX_DISTANCE
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	_subtitle = Label3D.new()
	_subtitle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_subtitle.pixel_size = 0.0022
	_subtitle.font_size = 40
	_subtitle.outline_size = 12
	_subtitle.modulate = Palette.TEXT
	_subtitle.outline_modulate = Palette.BACKGROUND
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.width = 640.0
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.position = Vector3(0.0, subtitle_offset, 0.0)
	_subtitle.visible = false
	add_child(_subtitle)


func _exit_tree() -> void:
	stop()


## Says a line of [param category]. [param is_important] lines always play
## (cutting off this NPC's own line); chatter only when few others talk and
## this NPC hasn't just spoken. Returns the line's length in seconds, or 0
## when nothing was said (no such lines, or chatter held back).
func say(category: StringName, is_important: bool = false) -> float:
	if voice == null or _player == null:
		return 0.0
	var lines: Array[VoiceLineData] = voice.get_lines(category)
	if lines.is_empty():
		return 0.0
	if not is_important:
		if is_speaking() or Time.get_ticks_msec() < _quiet_until_msec or _chatter_speakers >= MAX_CHATTER_SPEAKERS:
			return 0.0
	var line: VoiceLineData = lines[_picker.pick(category, lines.size())]
	var was_speaking: bool = is_speaking()
	_end_line()
	_line_serial += 1
	var serial: int = _line_serial
	current_line = line
	_is_chatter = not is_important
	if _is_chatter:
		_chatter_speakers += 1
		_quiet_until_msec = Time.get_ticks_msec() + roundi(chatter_cooldown_seconds * 1000.0)
	_subtitle.text = line.text
	_subtitle.visible = shows_subtitles and _is_near_camera()
	if line.stream == null:
		# A line without a recording still shows its subtitle for a reading time.
		var reading_seconds: float = 0.6 + line.text.length() * 0.06
		get_tree().create_timer(reading_seconds, false).timeout.connect(func() -> void:
			if _line_serial == serial:
				_on_player_finished())
		_wake_cut_off_listeners(was_speaking)
		return reading_seconds
	_player.stream = line.stream
	_player.volume_db = voice.volume_db
	_player.play()
	# Woken only now, so an awaiting caller sees the new line playing.
	_wake_cut_off_listeners(was_speaking)
	return line.stream.get_length()


## Says a line of [param category] that outlives this NPC (a cry as an
## officer goes down and vanishes): played from here through the shared
## positional players, no subtitle. Rationed like chatter. Returns false
## when nothing was said.
func say_last_words(category: StringName) -> bool:
	if voice == null or not is_inside_tree():
		return false
	var lines: Array[VoiceLineData] = voice.get_lines(category)
	var now: int = Time.get_ticks_msec()
	if lines.is_empty() or now < _last_words_quiet_until_msec:
		return false
	var line: VoiceLineData = lines[_picker.pick(category, lines.size())]
	if line.stream == null:
		return false
	stop()
	_last_words_quiet_until_msec = now + LAST_WORDS_GAP_MSEC
	Audio.play_sfx_at(line.stream, global_position, 0.0, voice.volume_db)
	return true


## True while a line plays.
func is_speaking() -> bool:
	return current_line != null


## Cuts the current line off.
func stop() -> void:
	if not is_speaking():
		return
	_end_line()
	line_finished.emit()


## Quiet and forgetful again (the NPC goes back to its pool).
func reset() -> void:
	stop()
	shows_subtitles = true
	_picker.reset()
	_quiet_until_msec = 0


func _wake_cut_off_listeners(was_speaking: bool) -> void:
	if was_speaking:
		line_finished.emit()


func _on_player_finished() -> void:
	if not is_speaking():
		return
	_end_line()
	line_finished.emit()


func _end_line() -> void:
	if _is_chatter:
		_chatter_speakers = maxi(0, _chatter_speakers - 1)
	_is_chatter = false
	current_line = null
	if _player != null:
		_player.stop()
	if _subtitle != null:
		_subtitle.visible = false


func _is_near_camera() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera != null and camera.global_position.distance_to(global_position) <= SUBTITLE_DISTANCE

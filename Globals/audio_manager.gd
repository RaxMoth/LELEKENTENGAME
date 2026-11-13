## Music with cross-fades plus pooled one-shot sound effects.
##
##   Audio.play_music(preload("res://Assets/Audio/theme.ogg"))
##   Audio.play_sfx(hit_sound, 0.1)            # 10% random pitch variation
##   Audio.play_sfx_at(explosion, global_position)   # spatialized for the headset
##   Audio.play_ui(Audio.UI_CLICK)            # built-in synthesized UI sounds
##
## Volumes are controlled by Settings through the Music / SFX / UI buses.
##
## Dependencies: Settings autoload, SfxSynth
extends Node

const SFX_POOL_SIZE: int = 12
const POSITIONAL_POOL_SIZE: int = 12
## Distance in meters at which a positional sound has dropped to about half volume.
const POSITIONAL_UNIT_SIZE: float = 6.0
const POSITIONAL_MAX_DISTANCE: float = 40.0
const UI_CLICK: StringName = &"click"
const UI_CONFIRM: StringName = &"confirm"
const UI_ERROR: StringName = &"error"
const UI_REWARD: StringName = &"reward"

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index: int = 0
var _music_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _positional_players: Array[AudioStreamPlayer3D] = []
var _next_sfx_index: int = 0
var _next_positional_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for music_index: int in 2:
		var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
		music_player.bus = Settings.BUS_MUSIC
		add_child(music_player)
		_music_players.append(music_player)
	for sfx_index: int in SFX_POOL_SIZE:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx_player.bus = Settings.BUS_SFX
		add_child(sfx_player)
		_sfx_players.append(sfx_player)
	for positional_index: int in POSITIONAL_POOL_SIZE:
		var positional_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		positional_player.bus = Settings.BUS_SFX
		positional_player.unit_size = POSITIONAL_UNIT_SIZE
		positional_player.max_distance = POSITIONAL_MAX_DISTANCE
		add_child(positional_player)
		_positional_players.append(positional_player)

func _exit_tree() -> void:
	SfxSynth.clear_cache()

# ============================================
# MUSIC
# ============================================

func play_music(stream: AudioStream, fade_seconds: float = 1.0, volume_db: float = 0.0) -> void:
	var current_player: AudioStreamPlayer = _music_players[_active_music_index]
	if current_player.stream == stream and current_player.playing:
		return
	_active_music_index = 1 - _active_music_index
	var next_player: AudioStreamPlayer = _music_players[_active_music_index]
	next_player.stream = stream
	next_player.volume_db = -60.0 if fade_seconds > 0.0 else volume_db
	next_player.play()
	_crossfade(current_player, next_player, volume_db, fade_seconds)


func stop_music(fade_seconds: float = 1.0) -> void:
	var current_player: AudioStreamPlayer = _music_players[_active_music_index]
	_crossfade(current_player, null, 0.0, fade_seconds)


func is_music_playing() -> bool:
	return _music_players[_active_music_index].playing


func _crossfade(outgoing: AudioStreamPlayer, incoming: AudioStreamPlayer, target_volume_db: float, fade_seconds: float) -> void:
	if _music_tween != null:
		_music_tween.kill()
	if fade_seconds <= 0.0:
		outgoing.stop()
		return
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(outgoing, "volume_db", -60.0, fade_seconds)
	if incoming != null:
		_music_tween.tween_property(incoming, "volume_db", target_volume_db, fade_seconds)
	_music_tween.chain().tween_callback(outgoing.stop)

# ============================================
# SOUND EFFECTS
# ============================================

## Plays a non-positional sound. [param pitch_variation] 0.1 = ±10%.
func play_sfx(stream: AudioStream, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var sfx_player: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	sfx_player.stream = stream
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	sfx_player.play()


## Plays a sound at a world position, spatialized for the current Camera3D /
## XR headset, so the player hears where it happened.
func play_sfx_at(stream: AudioStream, world_position: Vector3, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var positional_player: AudioStreamPlayer3D = _positional_players[_next_positional_index]
	_next_positional_index = (_next_positional_index + 1) % _positional_players.size()
	positional_player.stream = stream
	positional_player.global_position = world_position
	positional_player.volume_db = volume_db
	positional_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	positional_player.play()
	Events.positional_sound_played.emit(stream, world_position, pitch_variation, volume_db)


## Plays one of the built-in synthesized sounds (see SfxSynth presets) on the UI bus.
## Replace with real assets by calling play_sfx with your own streams.
func play_ui(preset_name: StringName) -> void:
	var stream: AudioStream = SfxSynth.get_preset(preset_name)
	if stream == null:
		return
	var sfx_player: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	sfx_player.stream = stream
	sfx_player.volume_db = -6.0
	sfx_player.pitch_scale = 1.0
	sfx_player.play()

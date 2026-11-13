## Generates tiny placeholder sound effects at runtime so the game has
## audio feedback without shipping any sound files. Results are cached.
##
## Swap for real assets whenever you have them — nothing depends on this
## beyond Audio.play_ui() and SfxSynth.get_preset() calls.
##
## Dependencies: none
class_name SfxSynth
extends RefCounted

const SAMPLE_RATE: int = 22050

## preset -> [start_hz, end_hz, duration_seconds, waveform (0 sine, 1 square, 2 noise), volume]
const PRESETS: Dictionary[StringName, Array] = {
	&"click": [900.0, 600.0, 0.05, 0, 0.5],
	&"confirm": [600.0, 1200.0, 0.12, 0, 0.5],
	&"error": [220.0, 140.0, 0.18, 1, 0.3],
	&"reward": [700.0, 1600.0, 0.25, 0, 0.5],
	&"coin": [1300.0, 1900.0, 0.08, 1, 0.25],
	&"hit": [300.0, 80.0, 0.08, 2, 0.4],
	&"shoot": [1200.0, 300.0, 0.06, 1, 0.2],
	&"jump": [300.0, 700.0, 0.12, 1, 0.25],
	&"explosion": [200.0, 40.0, 0.35, 2, 0.5],
	&"pop": [500.0, 900.0, 0.07, 0, 0.5],
	&"step": [150.0, 70.0, 0.06, 2, 0.22],
	&"shot_pistol": [1100.0, 260.0, 0.07, 2, 0.3],
	&"shot_smg": [1500.0, 420.0, 0.045, 2, 0.22],
	&"shot_shotgun": [420.0, 50.0, 0.22, 2, 0.5],
	&"shot_rifle": [900.0, 110.0, 0.14, 2, 0.42],
	&"machine": [180.0, 120.0, 0.14, 1, 0.14],
	&"ghost": [540.0, 170.0, 1.1, 0, 0.16],
	&"punch": [190.0, 60.0, 0.07, 2, 0.45],
	&"slash": [2600.0, 900.0, 0.09, 2, 0.28],
	&"chop": [260.0, 70.0, 0.13, 2, 0.5],
	&"whoosh": [900.0, 320.0, 0.12, 2, 0.1],
	&"squeak": [2700.0, 3500.0, 0.08, 0, 0.16],
}

static var _cache: Dictionary[StringName, AudioStreamWAV] = {}


## The preset [param stream] was made from, or &"" for any other sound
## (co-op sends sounds by name).
static func get_preset_name(stream: AudioStream) -> StringName:
	for preset_name: StringName in _cache:
		if _cache[preset_name] == stream:
			return preset_name
	return &""


static func get_preset(preset_name: StringName) -> AudioStreamWAV:
	if _cache.has(preset_name):
		return _cache[preset_name]
	if not PRESETS.has(preset_name):
		return null
	var preset: Array = PRESETS[preset_name]
	var stream: AudioStreamWAV = generate(float(preset[0]), float(preset[1]), float(preset[2]), int(preset[3]), float(preset[4]))
	_cache[preset_name] = stream
	return stream


static func clear_cache() -> void:
	_cache.clear()


## Builds a pitch-sweeping blip with a fast attack and exponential decay.
static func generate(start_frequency: float, end_frequency: float, duration_seconds: float, waveform: int, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration_seconds)
	var pcm_data: PackedByteArray = PackedByteArray()
	pcm_data.resize(sample_count * 2)
	var phase: float = 0.0
	for sample_index: int in sample_count:
		var progress: float = float(sample_index) / float(sample_count)
		var frequency: float = lerpf(start_frequency, end_frequency, progress)
		phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
		var raw_sample: float
		match waveform:
			1:
				raw_sample = 1.0 if phase < 0.5 else -1.0
			2:
				raw_sample = randf_range(-1.0, 1.0)
			_:
				raw_sample = sin(phase * TAU)
		var envelope: float = minf(1.0, progress * 40.0) * pow(1.0 - progress, 2.0)
		pcm_data.encode_s16(sample_index * 2, int(clampf(raw_sample * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm_data
	return stream

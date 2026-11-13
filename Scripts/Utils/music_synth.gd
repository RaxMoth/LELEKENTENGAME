## Generates the longer sounds of a break-in at runtime (no sound files
## shipped, like SfxSynth): a German police two-tone siren loop, a loud
## driving chase track (D minor, 150 BPM, eight bars) and a stinger hit for
## the moment the door goes down. Pure PCM math, safe on a worker thread;
## the results are cached once made.
##
##   var task: int = WorkerThreadPool.add_task(MusicSynth.prepare_breach_sounds)
##   Audio.play_music(MusicSynth.get_chase_loop(), 0.3)
##
## Swap for real recordings whenever there are some: only BreachAlarm uses these.
##
## Dependencies: none
class_name MusicSynth
extends RefCounted

const SAMPLE_RATE: int = 22050
const BEATS_PER_MINUTE: float = 150.0
const BARS: int = 8
const STEPS_PER_BAR: int = 16
## Chord root of each bar (Hz, bass octave): D, D, Bb, C, D, D, F, A.
const BAR_ROOTS: Array[float] = [73.42, 73.42, 58.27, 65.41, 73.42, 73.42, 87.31, 55.0]
## Chord tones of each bar for the arpeggio (Hz, an octave up from D5).
const BAR_CHORDS: Array[Array] = [
	[587.33, 698.46, 880.0], [587.33, 698.46, 880.0], [466.16, 587.33, 698.46], [523.25, 659.26, 783.99],
	[587.33, 698.46, 880.0], [587.33, 698.46, 880.0], [698.46, 880.0, 1046.5], [440.0, 554.37, 659.26]]
## The two notes of the siren (a German "Martinshorn": A4, D5) and how long each sounds.
const SIREN_TONES: Array[float] = [440.0, 587.33]
const SIREN_TONE_SECONDS: float = 0.62

static var _siren: AudioStreamWAV = null
static var _chase: AudioStreamWAV = null
static var _stinger: AudioStreamWAV = null
static var _mutex: Mutex = Mutex.new()


## Makes all three (slow-ish: run it on a worker thread at level start).
static func prepare_breach_sounds() -> void:
	get_siren()
	get_chase_loop()
	get_stinger()


## True once prepare_breach_sounds() is done (playing then costs nothing).
static func is_breach_ready() -> bool:
	_mutex.lock()
	var is_ready: bool = _siren != null and _chase != null and _stinger != null
	_mutex.unlock()
	return is_ready


## The siren, two tones back and forth, looping.
static func get_siren() -> AudioStreamWAV:
	_mutex.lock()
	var cached: AudioStreamWAV = _siren
	_mutex.unlock()
	if cached != null:
		return cached
	var made: AudioStreamWAV = _to_stream(render_siren(), true)
	_mutex.lock()
	_siren = made
	_mutex.unlock()
	return made


## The chase track, looping.
static func get_chase_loop() -> AudioStreamWAV:
	_mutex.lock()
	var cached: AudioStreamWAV = _chase
	_mutex.unlock()
	if cached != null:
		return cached
	var made: AudioStreamWAV = _to_stream(render_chase(), true)
	_mutex.lock()
	_chase = made
	_mutex.unlock()
	return made


## The hit when the door goes down (once).
static func get_stinger() -> AudioStreamWAV:
	_mutex.lock()
	var cached: AudioStreamWAV = _stinger
	_mutex.unlock()
	if cached != null:
		return cached
	var made: AudioStreamWAV = _to_stream(render_stinger(), false)
	_mutex.lock()
	_stinger = made
	_mutex.unlock()
	return made


## Seconds of one 16th step of the chase track.
static func get_step_seconds() -> float:
	return 60.0 / BEATS_PER_MINUTE / 4.0


## Samples of the siren loop (two cycles of the two tones), -1..1.
static func render_siren() -> PackedFloat32Array:
	var tone_samples: int = int(SIREN_TONE_SECONDS * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(tone_samples * 4)
	var phase: float = 0.0
	var frequency: float = SIREN_TONES[0]
	for sample_index: int in samples.size():
		var target: float = SIREN_TONES[(sample_index / tone_samples) % 2]
		# A short glide between the tones, like the real horn.
		frequency = lerpf(frequency, target, 0.004)
		phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
		var wave: float = sin(phase * TAU) + 0.45 * sin(phase * TAU * 3.0) + 0.25 * sin(phase * TAU * 5.0)
		samples[sample_index] = wave * 0.42
	return samples


## Samples of the chase track: kick, snare, hats, a saw bass in 8ths and a
## square arpeggio in 16ths, softly clipped. -1..1.
static func render_chase() -> PackedFloat32Array:
	var step_seconds: float = get_step_seconds()
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(step_seconds * STEPS_PER_BAR * BARS * SAMPLE_RATE))
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 150
	for bar_index: int in BARS:
		for step_index: int in STEPS_PER_BAR:
			var start: int = int((bar_index * STEPS_PER_BAR + step_index) * step_seconds * SAMPLE_RATE)
			if step_index % 4 == 0 or (step_index == 10 and bar_index % 2 == 1):
				_add_kick(samples, start, 0.9)
			if step_index == 4 or step_index == 12 or (bar_index == BARS - 1 and step_index >= 13):
				_add_snare(samples, start, 0.5, random)
			_add_hat(samples, start, 0.16 if step_index % 2 == 0 else 0.07, random)
			if step_index % 2 == 0:
				var octave: float = 2.0 if step_index % 8 == 6 else 1.0
				_add_bass(samples, start, BAR_ROOTS[bar_index] * octave, step_seconds * 1.8, 0.34)
			var chord: Array = BAR_CHORDS[bar_index]
			var arp_order: Array[int] = [0, 1, 2, 1]
			_add_arp(samples, start, float(chord[arp_order[step_index % 4]]) * (2.0 if step_index >= 12 and bar_index >= 4 else 1.0), step_seconds * 0.9, 0.1)
	for sample_index: int in samples.size():
		samples[sample_index] = tanh(samples[sample_index] * 1.3) * 0.9
	return samples


## Samples of the stinger: a detuned saw chord hit over a noise crack and a
## sub thump, ringing out. -1..1.
static func render_stinger() -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(1.6 * SAMPLE_RATE))
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	var chord: Array[float] = [146.83, 220.0, 293.66, 349.23, 440.0]
	for sample_index: int in samples.size():
		var time: float = float(sample_index) / SAMPLE_RATE
		var envelope: float = minf(1.0, time * 200.0) * exp(-time * 2.6)
		var hit: float = 0.0
		for note: float in chord:
			for detune: float in [0.995, 1.005]:
				hit += (fmod(time * note * detune, 1.0) * 2.0 - 1.0) * 0.09
		var crack: float = random.randf_range(-1.0, 1.0) * exp(-time * 40.0) * 0.6
		var thump: float = sin(TAU * 55.0 * time) * exp(-time * 5.0) * 0.6
		samples[sample_index] = tanh((hit * envelope + crack + thump) * 1.4) * 0.95
	return samples


static func _add_kick(samples: PackedFloat32Array, start: int, volume: float) -> void:
	var length: int = mini(int(0.28 * SAMPLE_RATE), samples.size() - start)
	var phase: float = 0.0
	for offset: int in length:
		var time: float = float(offset) / SAMPLE_RATE
		phase += (45.0 + 110.0 * exp(-time * 30.0)) / SAMPLE_RATE
		samples[start + offset] += sin(phase * TAU) * exp(-time * 14.0) * volume


static func _add_snare(samples: PackedFloat32Array, start: int, volume: float, random: RandomNumberGenerator) -> void:
	var length: int = mini(int(0.18 * SAMPLE_RATE), samples.size() - start)
	for offset: int in length:
		var time: float = float(offset) / SAMPLE_RATE
		var body: float = sin(TAU * 190.0 * time) * exp(-time * 30.0) * 0.4
		samples[start + offset] += (random.randf_range(-1.0, 1.0) * exp(-time * 22.0) * 0.6 + body) * volume


static func _add_hat(samples: PackedFloat32Array, start: int, volume: float, random: RandomNumberGenerator) -> void:
	var length: int = mini(int(0.05 * SAMPLE_RATE), samples.size() - start)
	var previous: float = 0.0
	for offset: int in length:
		var noise: float = random.randf_range(-1.0, 1.0)
		# The difference of two noise samples keeps only the hiss.
		samples[start + offset] += (noise - previous) * exp(-float(offset) / SAMPLE_RATE * 80.0) * volume
		previous = noise


static func _add_bass(samples: PackedFloat32Array, start: int, frequency: float, seconds: float, volume: float) -> void:
	var length: int = mini(int(seconds * SAMPLE_RATE), samples.size() - start)
	var filtered: float = 0.0
	for offset: int in length:
		var time: float = float(offset) / SAMPLE_RATE
		var saw: float = fmod(time * frequency, 1.0) * 2.0 - 1.0
		# A one-pole low-pass keeps the saw warm under the drums.
		filtered += (saw - filtered) * 0.18
		samples[start + offset] += filtered * minf(1.0, time * 300.0) * exp(-time * 4.0) * volume


static func _add_arp(samples: PackedFloat32Array, start: int, frequency: float, seconds: float, volume: float) -> void:
	var length: int = mini(int(seconds * SAMPLE_RATE), samples.size() - start)
	for offset: int in length:
		var time: float = float(offset) / SAMPLE_RATE
		var square: float = 1.0 if fmod(time * frequency, 1.0) < 0.5 else -1.0
		samples[start + offset] += square * minf(1.0, time * 400.0) * exp(-time * 18.0) * volume


## 16-bit mono stream from [param samples]; looping over all of it when [param loops].
static func _to_stream(samples: PackedFloat32Array, loops: bool) -> AudioStreamWAV:
	var pcm_data: PackedByteArray = PackedByteArray()
	pcm_data.resize(samples.size() * 2)
	for sample_index: int in samples.size():
		pcm_data.encode_s16(sample_index * 2, int(clampf(samples[sample_index], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm_data
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

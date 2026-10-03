class_name SoundSynth
extends RefCounted
## Procedurally synthesises every sound effect in the game into
## AudioStreamWAVs at runtime, rather than shipping recorded audio files —
## the same reason court.gd builds geometry in code: no asset pipeline or
## licensing to manage, and the parameters (pitch, decay, season) live in
## one place. Pure functions of their arguments (seeded RNG), so they're
## GUT-testable and a given sound is identical every run.
##
## Wood impacts are modal synthesis: a sum of exponentially decaying sine
## "modes" plus a short noise click for the contact transient. The karttu's
## modes use the free-free bar ratios (1 : 2.76 : 5.40), since it's a long
## round bar; a kyykkä is short and stubby, so its modes sit higher and
## closer together. Ground impacts are a low pitch-dropping thump plus
## filtered noise — grit crackle on sand, a granular crunch on snow.
##
## Streams are cached (see cached()) because synthesis runs per-sample in
## GDScript: done once per season rather than on every Rematch.

const MIX_RATE := 24000  ## Hz; wood knocks have little energy above 12 kHz, and it halves synthesis time vs. 48 kHz
const PEAK := 0.9  ## every sound is normalised to this peak; loudness is set at playback

const KARTTU_MODE_RATIOS: Array[float] = [1.0, 2.76, 5.40]
const KYYKKA_MODE_RATIOS: Array[float] = [1.0, 1.58, 2.37, 3.10]

static var _cache: Dictionary = {}


## Returns the stream stored under `key`, building it with `build` the
## first time.
static func cached(key: String, build: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


## The stream stored under `key`, or null. With store(), for streams
## built somewhere cached() can't wait on (a worker thread).
static func lookup(key: String) -> AudioStreamWAV:
	return _cache.get(key)


static func store(key: String, stream: AudioStreamWAV) -> void:
	_cache[key] = stream


# Impacts ---------------------------------------------------------------------

## Karttu striking a kyykkä: the struck piece's bright knock over the
## karttu's own lower ring, with a sharp contact click.
static func karttu_hit(seed: int) -> AudioStreamWAV:
	var rng := _rng(seed)
	var buf := _silence(0.35)
	_add_modes(buf, rng.randf_range(1050.0, 1300.0), KYYKKA_MODE_RATIOS, [1.0, 0.6, 0.4, 0.25], 0.035, rng)
	_add_modes(buf, rng.randf_range(380.0, 460.0), KARTTU_MODE_RATIOS, [0.8, 0.45, 0.2], 0.08, rng)
	_add_click(buf, rng, 0.004, 0.9, 2500.0)
	return _to_stream(buf)


## Kyykkä knocking into another kyykkä: small, high and short.
static func kyykka_clack(seed: int) -> AudioStreamWAV:
	var rng := _rng(seed)
	var buf := _silence(0.18)
	_add_modes(buf, rng.randf_range(1300.0, 1700.0), KYYKKA_MODE_RATIOS, [1.0, 0.55, 0.35, 0.2], 0.022, rng)
	_add_click(buf, rng, 0.003, 0.6, 3500.0)
	return _to_stream(buf)


## Something landing on the court. `heavy` is the karttu (a deep thump
## and its own wooden ring); otherwise a kyykkä toppling or dropping.
static func ground_impact(seed: int, winter: bool, heavy: bool) -> AudioStreamWAV:
	var rng := _rng(seed)
	var buf := _silence(0.4 if heavy else 0.22)
	if heavy:
		_add_thump(buf, rng.randf_range(120.0, 150.0), 55.0, 0.07, 1.0)
		_add_modes(buf, rng.randf_range(380.0, 460.0), KARTTU_MODE_RATIOS, [0.3, 0.15, 0.08], 0.05, rng)
	else:
		_add_thump(buf, rng.randf_range(220.0, 280.0), 110.0, 0.03, 0.7)
		_add_modes(buf, rng.randf_range(1100.0, 1500.0), KYYKKA_MODE_RATIOS, [0.35, 0.2, 0.12, 0.08], 0.015, rng)

	var grains := _silence(buf.size() / float(MIX_RATE))
	if winter:
		# Snow: a dense burst of tiny grains, bandpassed bright, fading out.
		_add_grains(grains, rng, 220 if heavy else 90, 0.06 if heavy else 0.03, 0.0005, 0.002)
		_mix(buf, _bandpass(grains, 2600.0, 0.9), 0.9 if heavy else 0.6)
		_mix(buf, _lowpass(grains, 700.0), 0.5)
	else:
		# Sand: fewer, duller grains over a short "shh" of spray.
		_add_grains(grains, rng, 70 if heavy else 25, 0.05 if heavy else 0.025, 0.001, 0.004)
		_mix(buf, _lowpass(grains, 1600.0), 0.8 if heavy else 0.5)
		var spray := _silence(buf.size() / float(MIX_RATE))
		_add_decaying_noise(spray, rng, 0.0, 0.06 if heavy else 0.03, 1.0)
		_mix(buf, _lowpass(spray, 1000.0), 0.35)
	return _to_stream(buf)


# Loops and one-shots ---------------------------------------------------------

## Karttu sliding along the court, looped: a gritty scrape on sand, a
## smoother, brighter hiss on snow. Played with volume following speed.
static func slide_loop(winter: bool) -> AudioStreamWAV:
	var rng := _rng(7 if winter else 3)
	var length := 1.5
	var crossfade := 0.1
	var buf := _silence(length + crossfade)
	for i in range(buf.size()):
		buf[i] = rng.randf_range(-1.0, 1.0)
	if winter:
		buf = _bandpass(buf, 2800.0, 0.9)
	else:
		var grit := _silence(length + crossfade)
		_add_grains(grit, rng, 180, length + crossfade, 0.001, 0.003, false)
		buf = _lowpass(buf, 700.0)
		_mix(buf, _lowpass(grit, 2000.0), 0.8)
	return _to_stream(_loop_crossfade(buf, int(crossfade * MIX_RATE)), true)


## The karttu leaving the thrower's hand: bandpassed noise swept up and
## back down, swelling and fading.
static func whoosh(seed: int) -> AudioStreamWAV:
	var rng := _rng(seed)
	var duration := 0.45
	var buf := _silence(duration)
	var low := 0.0
	var band := 0.0
	for i in range(buf.size()):
		var t := i / float(buf.size())
		var centre := 350.0 + 1300.0 * sin(PI * pow(t, 0.8))
		var f := 2.0 * sin(PI * centre / MIX_RATE)
		var high := rng.randf_range(-1.0, 1.0) - low - 0.7 * band
		band += f * high
		low += f * band
		buf[i] = band * pow(sin(PI * pow(t, 0.7)), 2.0)
	return _to_stream(buf)


## Swing ran off the end of the gauge: a soft descending "bwoop".
static func swing_miss() -> AudioStreamWAV:
	var buf := _silence(0.28)
	var phase := 0.0
	for i in range(buf.size()):
		var t := i / float(buf.size())
		phase += TAU * lerpf(392.0, 196.0, t) / MIX_RATE
		var env := minf(t * 40.0, 1.0) * pow(1.0 - t, 1.5)
		buf[i] = env * (sin(phase) + 0.3 * sin(2.0 * phase))
	return _to_stream(buf)


## Kyykkä knocked out of the pesä: two bell tones a fifth apart.
static func score_chime() -> AudioStreamWAV:
	var buf := _silence(1.1)
	_add_bell(buf, 1046.5, 0.0, 0.7, 1.0)
	_add_bell(buf, 1568.0, 0.09, 0.8, 0.8)
	return _to_stream(buf)


## Match over: a rising major arpeggio, the last note held.
static func match_end_jingle() -> AudioStreamWAV:
	var buf := _silence(2.2)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for n in range(notes.size()):
		var last := n == notes.size() - 1
		_add_bell(buf, notes[n], 0.15 * n, 1.2 if last else 0.45, 1.0)
	return _to_stream(buf)


# Voices ----------------------------------------------------------------------
# Source-filter synthesis: a buzzy sawtooth "glottal" source with a pitch
# contour, vibrato and breath noise, shaped into a vowel by three formant
# bandpasses. Voices sharing a vowel are summed first and filtered once.

## Formant frequencies (F1, F2, F3 in Hz) of a male voice; a female
## voice's are ~17 % higher.
const VOWEL_A := Vector3(730, 1090, 2440)
const VOWEL_AE := Vector3(660, 1720, 2410)  ## Finnish "ä"
const VOWEL_E := Vector3(530, 1840, 2480)
const VOWEL_I := Vector3(300, 2250, 2950)
const VOWEL_U := Vector3(320, 870, 2240)
const FEMALE_FORMANTS := 1.17


## Crowd cheering: a wave of voices shouting "jee!" / "aah" / "huu",
## rising in pitch and falling away, some of them chanting short
## syllables, over clapping and a whistle or two. `big` is the longer,
## fuller cheer for the end of a match.
static func crowd_cheer(seed: int, big: bool) -> AudioStreamWAV:
	var rng := _rng(seed)
	var duration := 4.5 if big else 2.6
	var vowels: Array[Vector3] = [VOWEL_AE, VOWEL_A, VOWEL_U]
	var sources: Array[PackedFloat32Array] = []  # [vowel * 2 + female]
	for i in range(vowels.size() * 2):
		sources.append(_silence(duration))

	for v in range(34 if big else 20):
		var female := rng.randf() < 0.5
		var source := sources[rng.randi() % vowels.size() * 2 + int(female)]
		var f0 := rng.randf_range(210.0, 330.0) if female else rng.randf_range(120.0, 190.0)
		var amp := rng.randf_range(0.5, 1.0)
		if rng.randf() < 0.25:
			# Chanting: "jee! jee! jee!"
			var at := rng.randf_range(0.1, 0.5)
			for syllable in range(rng.randi_range(2, 4)):
				_add_voice(source, rng, at, 0.22, f0 * 1.2, f0 * 1.35, f0 * 1.1, amp * 0.8, 0.25)
				at += rng.randf_range(0.3, 0.38)
		else:
			var start := pow(rng.randf(), 2.0) * 0.35
			var length := rng.randf_range(0.7, duration * 0.65)
			_add_voice(source, rng, start, length, f0 * 0.95, f0 * rng.randf_range(1.25, 1.5), f0 * 0.8, amp, 0.3)
		if big and rng.randf() < 0.4:  # a second breath
			var again := rng.randf_range(1.6, 2.6)
			_add_voice(source, rng, again, rng.randf_range(0.6, 1.4), f0, f0 * 1.3, f0 * 0.8, amp * 0.6, 0.3)

	var buf := _silence(duration)
	for i in range(sources.size()):
		var formants := vowels[i >> 1] * (FEMALE_FORMANTS if i % 2 == 1 else 1.0)
		_mix(buf, _formants(sources[i], formants, formants), 1.0)

	# Clapping: dense at first, thinning out.
	var claps := _silence(duration)
	var clap_rate := 40.0 if big else 24.0
	var t := 0.2
	while t < duration * 0.85:
		var density := clap_rate * (1.0 - t / duration)
		t += -log(maxf(rng.randf(), 1e-6)) / density
		_add_decaying_noise_burst(claps, rng, t, 0.006, rng.randf_range(0.4, 1.0))
	_mix(buf, _bandpass(claps, 1400.0, 1.1), 0.5)

	for w in range(2 if big else int(rng.randf() < 0.6)):
		_add_whistle(buf, rng, rng.randf_range(0.2, 0.9), 0.14)

	# Everyone's run out of breath by the end.
	var fade_from := int(duration * 0.5 * MIX_RATE)
	for i in range(fade_from, buf.size()):
		buf[i] *= pow(1.0 - float(i - fade_from) / (buf.size() - fade_from), 1.5)
	return _to_stream(buf)


## A few voices shouting "HEI!" together — breathy "h", then "e" gliding to
## "i", pitch falling. Returned as a raw buffer, peak 1, for MusicSynth.
static func group_shout(seed: int, voices: int = 5) -> PackedFloat32Array:
	var rng := _rng(seed)
	var source := _silence(0.34)
	_add_decaying_noise(source, rng, 0.0, 0.03, 0.35)  # the "h"
	for v in range(voices):
		var f0 := rng.randf_range(135.0, 185.0)
		_add_voice(source, rng, rng.randf_range(0.03, 0.05), 0.24, f0 * 1.08, f0 * 1.12, f0 * 0.85, rng.randf_range(0.7, 1.0), 0.2)
	var out := _formants(source, VOWEL_E, VOWEL_I, 0.11, 0.24)
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	for i in range(out.size()):
		out[i] /= peak
	return out


## One voice into `buf`: pitch rising from `f0_from` to `f0_peak` over the
## first quarter of the note, then falling to `f0_to`, with vibrato, a
## little breath noise, and a soft attack and release.
static func _add_voice(buf: PackedFloat32Array, rng: RandomNumberGenerator, start: float, duration: float, f0_from: float, f0_peak: float, f0_to: float, amp: float, breath: float) -> void:
	var offset := int(start * MIX_RATE)
	var n := mini(int(duration * MIX_RATE), buf.size() - offset)
	var attack := 0.03 * MIX_RATE
	var vibrato_phase := rng.randf() * TAU
	var vibrato_step := TAU * rng.randf_range(4.5, 6.5) / MIX_RATE
	var phase := rng.randf()
	for i in range(n):
		var t := i / float(n)
		var f0 := lerpf(f0_from, f0_peak, t * 4.0) if t < 0.25 else lerpf(f0_peak, f0_to, (t - 0.25) / 0.75)
		f0 *= 1.0 + 0.015 * sin(vibrato_phase + vibrato_step * i)
		phase += f0 / MIX_RATE
		if phase >= 1.0:
			phase -= 1.0
		var env := minf(i / attack, 1.0) * (1.0 if t < 0.6 else pow((1.0 - t) / 0.4, 1.5))
		buf[offset + i] += amp * env * (2.0 * phase - 1.0 + breath * rng.randf_range(-1.0, 1.0))


## Three formant bandpasses summed, their centres gliding from `from` to
## `to` between `glide_start` and `glide_end` seconds; returns a new buffer.
static func _formants(source: PackedFloat32Array, from: Vector3, to: Vector3, glide_start: float = 0.0, glide_end: float = 0.0) -> PackedFloat32Array:
	var out := _silence(source.size() / float(MIX_RATE))
	var gains := [1.0, 0.6, 0.3]
	var start_i := glide_start * MIX_RATE
	var glide_n := maxf((glide_end - glide_start) * MIX_RATE, 1.0)
	for k in range(3):
		var f_from := 2.0 * sin(PI * from[k] / MIX_RATE)
		var f_to := 2.0 * sin(PI * to[k] / MIX_RATE)
		var low := 0.0
		var band := 0.0
		for i in range(source.size()):
			var f := lerpf(f_from, f_to, clampf((i - start_i) / glide_n, 0.0, 1.0))
			var high := source[i] - low - 0.15 * band
			band += f * high
			low += f * band
			out[i] += gains[k] * band
	return out


static func _add_decaying_noise_burst(buf: PackedFloat32Array, rng: RandomNumberGenerator, start: float, decay: float, amp: float) -> void:
	var k := exp(-1.0 / (decay * MIX_RATE))
	var env := amp
	for i in range(int(start * MIX_RATE), mini(int((start + decay * 6.0) * MIX_RATE), buf.size())):
		buf[i] += env * rng.randf_range(-1.0, 1.0)
		env *= k


## A two-finger whistle: a pure tone swooping up, holding, then dropping.
static func _add_whistle(buf: PackedFloat32Array, rng: RandomNumberGenerator, start: float, amp: float) -> void:
	var duration := rng.randf_range(0.6, 1.0)
	var low := rng.randf_range(1600.0, 1900.0)
	var high := rng.randf_range(2700.0, 3200.0)
	var offset := int(start * MIX_RATE)
	var n := mini(int(duration * MIX_RATE), buf.size() - offset)
	var phase := 0.0
	for i in range(n):
		var t := i / float(n)
		var f := lerpf(low, high, minf(t * 5.0, 1.0)) if t < 0.75 else lerpf(high, high * 0.8, (t - 0.75) / 0.25)
		phase += TAU * f * (1.0 + 0.004 * sin(TAU * 6.0 * i / MIX_RATE)) / MIX_RATE
		buf[offset + i] += amp * minf(t * 30.0, 1.0) * minf((1.0 - t) * 10.0, 1.0) * sin(phase)


# Building blocks -------------------------------------------------------------

static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _silence(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	return buf


## Adds one exponentially decaying sine per ratio, detuned slightly so no
## two variants ring identically. Higher modes decay faster, as in real wood.
static func _add_modes(buf: PackedFloat32Array, base: float, ratios: Array[float], amps: Array, decay: float, rng: RandomNumberGenerator) -> void:
	for m in range(ratios.size()):
		var freq := base * ratios[m] * rng.randf_range(0.98, 1.02)
		if freq >= MIX_RATE / 2.0:
			continue
		_add_sine(buf, freq, 0.0, decay / (1.0 + 0.6 * m), amps[m])


static func _add_sine(buf: PackedFloat32Array, freq: float, start: float, decay: float, amp: float) -> void:
	var k := exp(-1.0 / (decay * MIX_RATE))
	var env := amp
	var step := TAU * freq / MIX_RATE
	var offset := int(start * MIX_RATE)
	for i in range(buf.size() - offset):
		buf[offset + i] += env * sin(step * i)
		env *= k
		if env < 1e-4:
			break


static func _add_bell(buf: PackedFloat32Array, freq: float, start: float, decay: float, amp: float) -> void:
	var partials: Array[float] = [1.0, 2.0, 3.0, 4.2]
	var amps: Array[float] = [1.0, 0.45, 0.2, 0.1]
	for p in range(partials.size()):
		_add_sine(buf, freq * partials[p], start, decay / (1.0 + p), amp * amps[p])


## Low sine gliding from `from_freq` down to `to_freq`: the body of a thud.
static func _add_thump(buf: PackedFloat32Array, from_freq: float, to_freq: float, decay: float, amp: float) -> void:
	var k := exp(-1.0 / (decay * MIX_RATE))
	var glide := exp(-1.0 / (0.5 * decay * MIX_RATE))
	var env := amp
	var freq := from_freq
	var phase := 0.0
	for i in range(buf.size()):
		buf[i] += env * sin(phase)
		phase += TAU * freq / MIX_RATE
		freq = to_freq + (freq - to_freq) * glide
		env *= k
		if env < 1e-4:
			break


## Contact transient: a few milliseconds of highpassed noise.
static func _add_click(buf: PackedFloat32Array, rng: RandomNumberGenerator, duration: float, amp: float, highpass: float) -> void:
	var n := mini(int(duration * MIX_RATE), buf.size())
	var a := exp(-TAU * highpass / MIX_RATE)
	var low := 0.0
	for i in range(n):
		var x := rng.randf_range(-1.0, 1.0)
		low = a * low + (1.0 - a) * x
		buf[i] += amp * (x - low) * (1.0 - i / float(n))


static func _add_decaying_noise(buf: PackedFloat32Array, rng: RandomNumberGenerator, start: float, decay: float, amp: float) -> void:
	var k := exp(-1.0 / (decay * MIX_RATE))
	var env := amp
	for i in range(int(start * MIX_RATE), buf.size()):
		buf[i] += env * rng.randf_range(-1.0, 1.0)
		env *= k


## Scatters `count` tiny noise grains, their onsets exponentially
## distributed with time constant `spread` (dense at first, thinning out),
## or uniformly across the buffer when `decaying` is false.
static func _add_grains(buf: PackedFloat32Array, rng: RandomNumberGenerator, count: int, spread: float, min_len: float, max_len: float, decaying: bool = true) -> void:
	for g in range(count):
		var onset := -log(maxf(rng.randf(), 1e-6)) * spread if decaying else rng.randf() * buf.size() / MIX_RATE
		var start := int(onset * MIX_RATE)
		var length := int(rng.randf_range(min_len, max_len) * MIX_RATE)
		var amp := rng.randf_range(0.3, 1.0) * (exp(-onset / (2.0 * spread)) if decaying else 1.0)
		for i in range(length):
			var idx := (start + i) % buf.size() if not decaying else start + i
			if idx >= buf.size():
				break
			buf[idx] += amp * rng.randf_range(-1.0, 1.0) * (1.0 - i / float(length))


## Chamberlin state-variable filter; returns a new buffer.
static func _svf(buf: PackedFloat32Array, cutoff: float, damping: float, bandpass: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buf.size())
	var f := 2.0 * sin(PI * minf(cutoff, MIX_RATE / 6.0) / MIX_RATE)
	var low := 0.0
	var band := 0.0
	for i in range(buf.size()):
		var high := buf[i] - low - damping * band
		band += f * high
		low += f * band
		out[i] = band if bandpass else low
	return out


static func _lowpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	return _svf(buf, cutoff, 1.4, false)


static func _bandpass(buf: PackedFloat32Array, centre: float, damping: float) -> PackedFloat32Array:
	return _svf(buf, centre, damping, true)


static func _mix(into: PackedFloat32Array, other: PackedFloat32Array, gain: float) -> void:
	for i in range(mini(into.size(), other.size())):
		into[i] += gain * other[i]


## Folds the last `overlap` samples back over the start so the loop point
## is seamless: the result is `overlap` samples shorter than `buf`.
static func _loop_crossfade(buf: PackedFloat32Array, overlap: int) -> PackedFloat32Array:
	var length := buf.size() - overlap
	var out := buf.slice(0, length)
	for i in range(overlap):
		var t := i / float(overlap)
		out[i] = buf[i] * t + buf[length + i] * (1.0 - t)
	return out


## Normalises to PEAK, fades out the last few milliseconds (so a truncated
## decay never ends on a click) and packs as mono 16-bit PCM.
static func _to_stream(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := PEAK / peak if peak > 0.0 else 0.0

	var fade := 0 if loop else mini(int(0.005 * MIX_RATE), buf.size())
	var data := PackedByteArray()
	# A loop gets one guard frame after it, a copy of its first: Godot's
	# mixer reads up to and *including* frame loop_end when looping
	# (AudioStreamPlaybackWAV::_mix_internal), and doesn't pad the data, so
	# without it every pass read one sample past the buffer — which crashed
	# on Android (SIGSEGV on the AudioTrack thread).
	data.resize((buf.size() + (1 if loop else 0)) * 2)
	for i in range(buf.size()):
		var v := buf[i] * gain
		var from_end := buf.size() - 1 - i
		if from_end < fade:
			v *= from_end / float(fade)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	if loop:
		data.encode_s16(buf.size() * 2, data.decode_s16(0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream

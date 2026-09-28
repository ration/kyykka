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
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		var v := buf[i] * gain
		var from_end := buf.size() - 1 - i
		if from_end < fade:
			v *= from_end / float(fade)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))

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

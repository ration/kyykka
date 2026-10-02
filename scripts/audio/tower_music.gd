class_name TowerMusic
extends RefCounted
## The tower's music: four-on-the-floor house in A minor, for a match on a
## skyscraper roof (see the Music autoload).
##
## A punchy kick on every beat, claps on 2 and 4, off-beat open hats, a
## resonant filtered saw bass on the off-beats, a detuned-saw chord pad
## pumping against the kick (sidechain ducking), a sixteenth-note pluck
## arpeggio through a dotted-eighth echo, and a saw lead. Am-F-C-G
## throughout: groove, groove with the lead, a breakdown (kick and bass out,
## the pad opens up, a noise riser and snare roll build back in), then the
## lead again, whose last bar runs into the top of the loop.
##
## Every sound is rendered once (per pitch or per chord) and mixed in where
## it's played, so the loop renders quickly.

const TEMPO_BPM := 124.0
const BEATS_PER_BAR := 4
const EIGHTHS_PER_BAR := 8
const STEPS_PER_BAR := 16

const CHORDS := {
	"Am": [9, [0, 3, 7]],
	"F": [5, [0, 4, 7]],
	"C": [0, [0, 4, 7]],
	"G": [7, [0, 4, 7]],
}
const PROGRESSION := ["Am", "F", "C", "G"]

## Lead lines ("note:eighths" tokens filling one bar) for the two lead
## sections; the other bars have none.
const LEAD_A := [
	"E5:2 A5:2 G5:1 E5:1 D5:1 E5:1",
	"C5:2 A4:2 C5:1 D5:1 E5:2",
	"G5:2 E5:2 D5:1 C5:1 D5:1 E5:1",
	"D5:3 B4:1 G4:2 r:2",
]
const LEAD_B := [
	"A5:1 r:1 A5:1 G5:1 E5:2 C6:2",
	"A5:2 G5:1 F5:1 E5:2 C5:2",
	"E5:1 G5:1 C6:1 G5:1 E5:1 G5:1 D6:2",
	"B5:3 A5:1 G5:2 D5:2",
]
## Arpeggio, as indices into the chord's tones plus an octave above.
const ARP_PATTERN := [0, 1, 2, 3, 2, 1, 0, 2, 1, 2, 3, 4, 3, 2, 1, 2]
const PLUCK_HARMONICS: Array[float] = [1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14, 0.0, 0.11]
const PAD_DETUNE: Array[float] = [-11.0, 11.0]
const LEAD_DETUNE: Array[float] = [0.0, 9.0]


## 16 bars: sections of four, flagged for what plays.
static func arrangement() -> Array:
	var bars := []
	for section in range(4):
		for i in range(4):
			var bar := {"chords": PROGRESSION[i]}
			match section:
				1:
					bar.lead = LEAD_A[i]
				2:
					bar.breakdown = true
					bar.riser = i == 2  # over the last two bars
					bar.roll = i == 3
				3:
					bar.lead = LEAD_B[i]
			bar.crash = i == 0 and section != 2
			bars.append(bar)
	return bars


static func beat_seconds() -> float:
	return 60.0 / TEMPO_BPM


static func loop_seconds() -> float:
	return arrangement().size() * BEATS_PER_BAR * beat_seconds()


static func render() -> AudioStreamWAV:
	var rng := SoundSynth._rng(1987)  # the year house left Chicago
	var beat := beat_seconds()
	var eighth := beat / 2.0
	var step := beat / 4.0
	var bars := arrangement()
	var seconds := loop_seconds()
	var drums := SoundSynth._silence(seconds)
	var synths := SoundSynth._silence(seconds)  # ducked against the kick
	var arp := SoundSynth._silence(seconds)     # ducked, and through the echo
	var lead := SoundSynth._silence(seconds)
	var hats := SoundSynth._silence(seconds)
	var noise := SoundSynth._silence(seconds)

	var kick := _kick(rng)
	var clap := _clap(rng)
	var saw_low := MusicSynth._saw_table(40)
	var saw_high := MusicSynth._saw_table(14)
	var pluck_table := MusicSynth._wavetable(PLUCK_HARMONICS)
	var basses := {}
	var pads := {}
	var plucks := {}
	var ducked := PackedByteArray()  # per bar: does the kick duck the synths
	ducked.resize(bars.size())

	for b in range(bars.size()):
		var bar: Dictionary = bars[b]
		var bar_start: float = b * BEATS_PER_BAR * beat
		var chord: Array = CHORDS[bar.chords]
		var breakdown: bool = bar.get("breakdown", false)
		ducked[b] = 0 if breakdown else 1

		if not breakdown:
			for i in range(BEATS_PER_BAR):
				MusicSynth._mix_wrapped(drums, kick, bar_start + i * beat, 0.9)
				if i % 2 == 1:
					MusicSynth._mix_wrapped(drums, clap, bar_start + i * beat, 0.45)
				MusicSynth._add_noise_hit(hats, rng, bar_start + i * beat + eighth, 0.07, 0.8)  # open hat
				# The bass on the off-beat, the octave jump on beat 4's.
				var root := 33 + posmod(chord[0] - 9, 12)  # A1..G#2
				var note := root + (12 if i == 3 else 0)
				if not basses.has(note):
					basses[note] = _bass(saw_low, note, eighth * 0.8, rng)
				MusicSynth._mix_wrapped(synths, basses[note], bar_start + i * beat + eighth, 0.5)
		if not breakdown or b % 4 >= 2:
			for s in range(STEPS_PER_BAR):
				MusicSynth._add_noise_hit(hats, rng, bar_start + s * step, 0.012, 0.5 if s % 2 == 1 else 0.3)

		# The pad, brighter in the breakdown where it carries the track.
		var key := "%s:%s" % [bar.chords, breakdown]
		if not pads.has(key):
			pads[key] = _pad(saw_high, chord, BEATS_PER_BAR * beat, 3500.0 if breakdown else 1400.0, rng)
		MusicSynth._mix_wrapped(synths, pads[key], bar_start, 0.55 if breakdown else 0.4)

		var tones: Array = chord[1].duplicate()
		tones.append(12)
		tones.append(chord[1][1] + 12)
		for s in range(STEPS_PER_BAR):
			var note: int = 60 + chord[0] + tones[ARP_PATTERN[s]]  # from C4..A4
			if not plucks.has(note):
				plucks[note] = MusicSynth.render_note(pluck_table, MusicSynth._freq(note), [0.0], 0.05, 0.002, 0.08, 0.09, rng)
			MusicSynth._mix_wrapped(arp, plucks[note], bar_start + s * step, 0.22 if s % 4 == 0 else 0.15)

		if bar.has("lead"):
			MusicSynth._play_line(lead, saw_high, LEAD_DETUNE, bar.lead, bar_start, eighth, 0.01, 0.09, 0.0, 0.3, 0.0, rng)
		if bar.get("riser", false):
			_add_riser(noise, rng, bar_start, bar_start + 2 * BEATS_PER_BAR * beat)
		if bar.get("roll", false):
			# Snare roll: eighths, then sixteenths, getting louder.
			for s in range(STEPS_PER_BAR):
				if s < 8 and s % 2 == 1:
					continue
				MusicSynth._mix_wrapped(drums, clap, bar_start + s * step, 0.15 + 0.3 * s / STEPS_PER_BAR)
		if bar.get("crash", false):
			MusicSynth._add_noise_hit(noise, rng, bar_start, 0.6, 0.8)

	_add_ping_pong(arp, beat * 0.75, 0.42)
	SoundSynth._mix(synths, arp, 1.0)
	_duck(synths, ducked, beat)
	var mix := drums
	SoundSynth._mix(mix, synths, 1.0)
	SoundSynth._mix(mix, SoundSynth._svf(lead, 3200.0, 0.8, false), 1.0)
	SoundSynth._mix(mix, _highpass(hats, 6000.0), 0.22)
	SoundSynth._mix(mix, _highpass(noise, 1500.0), 0.12)
	MusicSynth._add_echoes(mix, [0.045, 0.071], 0.35, 2500.0, 0.1)
	return SoundSynth._to_stream(mix, true)


## Kick: a sine sweeping 150 -> 48 Hz with a click on top.
static func _kick(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var rate := float(SoundSynth.MIX_RATE)
	var buf := SoundSynth._silence(0.42)
	var phase := 0.0
	for i in range(buf.size()):
		var t := i / rate
		phase += TAU * (48.0 + 102.0 * exp(-t / 0.03)) / rate
		buf[i] = sin(phase) * exp(-t / 0.16) * minf(t / 0.002, 1.0)
	SoundSynth._add_click(buf, rng, 0.004, 0.6, 1500.0)
	return buf


## Clap: three quick noise slaps and a short tail, bandpassed.
static func _clap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := SoundSynth._silence(0.25)
	for s in range(3):
		var slap := SoundSynth._silence(0.25 - s * 0.011)
		SoundSynth._add_decaying_noise(slap, rng, 0.0, 0.004, 1.0)
		for i in range(slap.size()):
			buf[i + int(s * 0.011 * SoundSynth.MIX_RATE)] += slap[i]
	SoundSynth._add_decaying_noise(buf, rng, 0.022, 0.06, 0.6)
	return SoundSynth._bandpass(buf, 1300.0, 0.9)


## Bass: a saw through a resonant lowpass that snaps shut after the attack.
static func _bass(table: PackedFloat32Array, midi: int, hold: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var raw := MusicSynth.render_note(table, MusicSynth._freq(midi), [0.0, 6.0], hold, 0.002, 0.03, 0.0, rng)
	var rate := float(SoundSynth.MIX_RATE)
	var low := 0.0
	var band := 0.0
	for i in range(raw.size()):
		var cutoff := 220.0 + 1600.0 * exp(-i / (0.06 * rate))
		var f := 2.0 * sin(PI * cutoff / rate)
		var high := raw[i] - low - 0.35 * band
		band += f * high
		low += f * band
		raw[i] = low
	return raw


## Pad: the chord (plus the root an octave down) in detuned saws, lowpassed.
static func _pad(table: PackedFloat32Array, chord: Array, hold: float, cutoff: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := SoundSynth._silence(hold + 0.3)
	var notes := [45 + posmod(chord[0] - 9, 12)]  # A2..G#3
	for interval in chord[1]:
		notes.append(57 + posmod(chord[0] + interval - 9, 12))  # A3..G#4
	for note in notes:
		SoundSynth._mix(buf, MusicSynth.render_note(table, MusicSynth._freq(note), PAD_DETUNE, hold, 0.08, 0.28, 0.0, rng), 0.25)
	return SoundSynth._svf(buf, cutoff, 0.7, false)


## White noise swelling from `from` to `to`, its bandpass opening upward.
static func _add_riser(buf: PackedFloat32Array, rng: RandomNumberGenerator, from: float, to: float) -> void:
	var rate := float(SoundSynth.MIX_RATE)
	var start := int(from * rate)
	var length := int((to - from) * rate)
	var low := 0.0
	var band := 0.0
	for i in range(length):
		var x := float(i) / length
		var f := 2.0 * sin(PI * (300.0 + 3500.0 * x * x) / rate)
		var high := rng.randf_range(-1.0, 1.0) - low - 0.6 * band
		band += f * high
		low += f * band
		buf[posmod(start + i, buf.size())] += band * x * x * 2.5


## Sidechain pumping: the synths duck on every kick and swell back in
## across the beat, in the bars the kick plays.
static func _duck(buf: PackedFloat32Array, ducked: PackedByteArray, beat: float) -> void:
	var rate := float(SoundSynth.MIX_RATE)
	var bar_samples := BEATS_PER_BAR * beat * rate
	for i in range(buf.size()):
		var bar := mini(int(i / bar_samples), ducked.size() - 1)
		if ducked[bar] == 0:
			continue
		var into_beat := fmod(i / rate, beat) / beat
		buf[i] *= 0.25 + 0.75 * smoothstep(0.0, 0.55, into_beat)


## A dotted-eighth echo (mono, despite the name: it's the rhythm that
## matters), wrapping round the loop.
static func _add_ping_pong(buf: PackedFloat32Array, delay: float, feedback: float) -> void:
	var size := buf.size()
	var d := int(delay * SoundSynth.MIX_RATE)
	var echo := PackedFloat32Array()
	echo.resize(size)
	for _pass in range(2):
		for i in range(size):
			var j := posmod(i - d, size)
			echo[i] = feedback * (buf[j] + echo[j])
	SoundSynth._mix(buf, echo, 0.7)


## One-pole highpass.
static func _highpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := exp(-TAU * cutoff / SoundSynth.MIX_RATE)
	var low := 0.0
	var out := PackedFloat32Array()
	out.resize(buf.size())
	for i in range(buf.size()):
		low = a * low + (1.0 - a) * buf[i]
		out[i] = buf[i] - low
	return out

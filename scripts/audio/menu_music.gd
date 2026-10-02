class_name MenuMusic
extends RefCounted
## The main menu's music: a slow Finnish folk tune on the kantele over a
## soft drone, in D minor — calm, after the match tracks' racket (see the
## Music autoload for which plays when).
##
## The kantele is Karplus-Strong plucked strings, each note rendered once
## and mixed in wherever it's played, so the whole loop renders quickly.
## The tune is played twice, the second time an octave up with the drone
## opened out. Everything is written modulo the buffer length (strings and
## the hall ringing past the end wrap round to the start), so the loop is
## seamless.

const TEMPO_BPM := 80.0
const BEATS_PER_BAR := 4
const EIGHTHS_PER_BAR := 8

## Chord name -> [root pitch class, intervals above the root].
const CHORDS := {
	"Dm": [2, [0, 3, 7]],
	"C": [0, [0, 4, 7]],
	"Am": [9, [0, 3, 7]],
	"F": [5, [0, 4, 7]],
	"G": [7, [0, 4, 7]],
}

## `lead`: "note:eighths" tokens filling one bar (see MusicSynth.parse_line()).
const TUNE := [
	{"chords": "Dm", "lead": "A4:2 D5:2 C5:1 A4:1 G4:2"},
	{"chords": "C", "lead": "E4:2 G4:2 A4:4"},
	{"chords": "Dm", "lead": "A4:2 C5:2 D5:2 E5:2"},
	{"chords": "Am", "lead": "C5:2 A4:2 A4:4"},
	{"chords": "F", "lead": "F5:2 E5:1 D5:1 C5:2 A4:2"},
	{"chords": "C", "lead": "G4:2 C5:2 E5:4"},
	{"chords": "G", "lead": "D5:2 C5:1 A4:1 G4:2 E4:2"},
	{"chords": "Dm", "lead": "D4:6 r:2"},
]

## Pad: a soft, mostly-fundamental tone for the drone.
const PAD_HARMONICS: Array[float] = [1.0, 0.3, 0.12, 0.05]
const PAD_VOICES: Array[float] = [0.0, 7.0, -7.0]


## The tune twice, the second time an octave up.
static func arrangement() -> Array:
	var bars := []
	bars.append_array(TUNE)
	for bar in TUNE:
		var high: Dictionary = bar.duplicate()
		high.octave_up = true
		bars.append(high)
	return bars


static func beat_seconds() -> float:
	return 60.0 / TEMPO_BPM


static func loop_seconds() -> float:
	return arrangement().size() * BEATS_PER_BAR * beat_seconds()


static func render() -> AudioStreamWAV:
	var rng := SoundSynth._rng(1835)  # the Kalevala's first edition
	var beat := beat_seconds()
	var eighth := beat / 2.0
	var bars := arrangement()
	var buf := SoundSynth._silence(loop_seconds())
	var pad := MusicSynth._wavetable(PAD_HARMONICS)
	var strings := {}  # midi note -> rendered pluck

	for b in range(bars.size()):
		var bar: Dictionary = bars[b]
		var bar_start: float = b * BEATS_PER_BAR * beat
		var chord: Array = CHORDS[bar.chords]
		var high: bool = bar.get("octave_up", false)
		var root := 38 + posmod(chord[0] - 2, 12)  # D2..C#3

		# Drone: root and fifth swelling in and out across the bar; the
		# second time round with the octave and third added.
		var drone := [root, root + 7]
		if high:
			drone.append_array([root + 12, root + 12 + chord[1][1]])
		for note in drone:
			MusicSynth._add_note(buf, pad, MusicSynth._freq(note), PAD_VOICES, bar_start - 0.4, BEATS_PER_BAR * beat, 1.2, 1.4, 0.0, 0.07, rng)

		# Accompaniment: the chord's strings plucked upward, low on the
		# instrument, ringing into each other.
		var pattern := [0, 2, 1, 2, 3, 2, 1, 2]  # index into root, third, fifth, octave
		var tones := [chord[1][0], chord[1][1], chord[1][2], 12]
		for e in range(EIGHTHS_PER_BAR):
			var note: int = 50 + posmod(chord[0] - 2, 12) + tones[pattern[e]]  # from D3
			var t := bar_start + e * eighth + rng.randf_range(-0.008, 0.008)
			MusicSynth._mix_wrapped(buf, _string(strings, note, rng), t, (0.22 if e % 4 == 0 else 0.15) * rng.randf_range(0.85, 1.05))

		# The tune, its long notes struck again halfway through as a
		# kantele player would.
		var at := 0
		for note in MusicSynth.parse_line(bar.lead):
			if note[0] >= 0:
				var midi: int = note[0] + (12 if high else 0)
				var t := bar_start + at * eighth + rng.randf_range(-0.01, 0.01)
				MusicSynth._mix_wrapped(buf, _string(strings, midi, rng), t, 0.5 * rng.randf_range(0.9, 1.05))
				if note[1] >= 4:
					MusicSynth._mix_wrapped(buf, _string(strings, midi, rng), t + note[1] / 2 * eighth, 0.3)
			at += note[1]

		# A soft frame drum on the first beat, and the third every other bar.
		MusicSynth._add_kick(buf, bar_start, 0.28, 75.0)
		if b % 2 == 1:
			MusicSynth._add_kick(buf, bar_start + 2 * beat, 0.16, 75.0)

	MusicSynth._add_echoes(buf, [0.083, 0.121, 0.167], 0.62, 1800.0, 0.2)
	return SoundSynth._to_stream(buf, true)


static func _string(cache: Dictionary, midi: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	if not cache.has(midi):
		cache[midi] = MusicSynth.pluck(MusicSynth._freq(midi), 3.0, 0.55, 0.997, rng)
	return cache[midi]

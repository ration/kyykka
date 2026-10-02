class_name SummerMusic
extends RefCounted
## Summer's music: a sunny steel-pan calypso in C major — as far from
## winter's humppa as it gets (see the Music autoload).
##
## A lead pan sings the tune, rolling its long notes (quick repeated
## strikes, as pan players do) over a second pan strumming the chords on
## the off-beats, a plucked bass bouncing between root and fifth, and soca
## percussion: four-on-the-floor kick, son clave on a woodblock, shaker
## sixteenths, congas, a timbale fill into the top.
##
## A pan note is two wavetables: a bright metallic attack (strong octave
## and twelfth partials) dying away fast into a mellow body. Each pitch is
## rendered once and mixed in wherever it's struck.

const TEMPO_BPM := 122.0
const BEATS_PER_BAR := 4
const EIGHTHS_PER_BAR := 8
const STEPS_PER_BAR := 16

const CHORDS := {
	"C": [0, [0, 4, 7]],
	"F": [5, [0, 4, 7]],
	"G": [7, [0, 4, 7]],
	"G7": [7, [0, 4, 7, 10]],
	"Am": [9, [0, 3, 7]],
	"Dm": [2, [0, 3, 7]],
}

## `lead`: "note:eighths" tokens filling one bar. Flags: crash (cymbal on
## beat 1), fill (timbale fill over the bar, no clave).
const TUNE := [
	{"chords": "C", "lead": "E5:1 G5:1 r:1 G5:1 A5:1 G5:1 E5:2", "flags": ["crash"]},
	{"chords": "F", "lead": "F5:1 A5:1 r:1 A5:1 C6:1 A5:1 F5:2"},
	{"chords": "G7", "lead": "D5:1 F5:1 r:1 G5:1 B5:1 A5:1 G5:1 F5:1"},
	{"chords": "C", "lead": "E5:3 C5:1 E5:4"},
	{"chords": "Am", "lead": "C6:1 B5:1 A5:1 G5:1 A5:2 E5:2"},
	{"chords": "Dm", "lead": "F5:1 E5:1 D5:1 F5:1 A5:2 D6:2"},
	{"chords": "G7", "lead": "B5:1 A5:1 G5:1 F5:1 D5:2 B4:2"},
	{"chords": "C", "lead": "C5:2 E5:1 G5:1 C6:2 r:2"},
	{"chords": "F", "lead": "A5:2 A5:1 G5:1 A5:2 C6:2", "flags": ["crash"]},
	{"chords": "G", "lead": "B5:2 B5:1 A5:1 G5:2 D5:2"},
	{"chords": "C", "lead": "E5:1 G5:1 C6:1 G5:1 E5:1 G5:1 C6:2"},
	{"chords": "Am", "lead": "E6:2 D6:1 C6:1 A5:4"},
	{"chords": "F", "lead": "A5:1 C6:1 A5:1 F5:1 C6:2 A5:2"},
	{"chords": "G7", "lead": "B5:1 D6:1 B5:1 G5:1 F5:2 D5:2"},
	{"chords": "C", "lead": "E5:2 G5:1 E5:1 C5:2 E5:2"},
	{"chords": "C", "lead": "C5:4 r:4", "flags": ["fill"]},
]

## Bass line per bar as [semitones above the root, eighths]: the calypso
## bounce, anticipating beat 3.
const BASS_PATTERN := [[0, 3], [0, 1], [7, 2], [12, 1], [7, 1]]
const CLAVE_STEPS := [0, 3, 6, 10, 12]  ## son clave, 3-2
const PAN_ATTACK: Array[float] = [1.0, 0.9, 0.6, 0.35, 0.25, 0.15]
const PAN_BODY: Array[float] = [1.0, 0.3, 0.12]


static func arrangement() -> Array:
	return TUNE


static func beat_seconds() -> float:
	return 60.0 / TEMPO_BPM


static func loop_seconds() -> float:
	return arrangement().size() * BEATS_PER_BAR * beat_seconds()


static func render() -> AudioStreamWAV:
	var rng := SoundSynth._rng(1962)  # Trinidad and Tobago's independence
	var beat := beat_seconds()
	var eighth := beat / 2.0
	var step := beat / 4.0
	var bars := arrangement()
	var seconds := loop_seconds()
	var buf := SoundSynth._silence(seconds)
	var shaker := SoundSynth._silence(seconds)
	var cymbals := SoundSynth._silence(seconds)
	var attack_table := MusicSynth._wavetable(PAN_ATTACK)
	var body_table := MusicSynth._wavetable(PAN_BODY)
	var bass_table := MusicSynth._wavetable(MusicSynth.BASS_HARMONICS)
	var pans := {}
	var basses := {}
	var block := _woodblock(rng)

	for b in range(bars.size()):
		var bar: Dictionary = bars[b]
		var bar_start: float = b * BEATS_PER_BAR * beat
		var chord: Array = CHORDS[bar.chords]
		var flags: Array = bar.get("flags", [])

		# Lead pan; long notes rolled in sixteenths, softer than the strike.
		var at := 0
		for note in MusicSynth.parse_line(bar.lead):
			if note[0] >= 0:
				var t := bar_start + at * eighth + rng.randf_range(-0.006, 0.006)
				var sample := _pan(pans, note[0], attack_table, body_table, rng)
				MusicSynth._mix_wrapped(buf, sample, t, 0.5 * rng.randf_range(0.9, 1.05))
				if note[1] >= 2:
					for r in range(1, note[1] * 2):
						MusicSynth._mix_wrapped(buf, sample, t + r * step, 0.24 * rng.randf_range(0.85, 1.05))
			at += note[1]

		# Strum pan: the chord on every off-beat, tones a few ms apart.
		for i in range(BEATS_PER_BAR):
			var t := bar_start + i * beat + eighth
			var tones: Array = chord[1]
			for k in range(tones.size()):
				var note: int = 67 + posmod(chord[0] + tones[k] - 7, 12)  # G4..F#5
				MusicSynth._mix_wrapped(buf, _pan(pans, note, attack_table, body_table, rng), t + k * 0.012, 0.13)

		var root: int = 36 + chord[0]  # C2..B2
		var pos := 0
		for part in BASS_PATTERN:
			var note: int = root + part[0]
			if not basses.has(note):
				basses[note] = MusicSynth.render_note(bass_table, MusicSynth._freq(note), [0.0], 0.28, 0.003, 0.05, 0.25, rng)
			MusicSynth._mix_wrapped(buf, basses[note], bar_start + pos * eighth, 0.55)
			pos += part[1]

		# Percussion, on the sixteenth grid.
		for s in range(STEPS_PER_BAR):
			var t := bar_start + s * step
			if s % 4 == 0:
				MusicSynth._add_kick(buf, t, 0.45, 95.0)
			MusicSynth._add_noise_hit(shaker, rng, t + rng.randf_range(-0.004, 0.004), 0.018, 0.9 if s % 2 == 1 else 0.5)
			if "fill" in flags:
				if s >= 8:
					MusicSynth._add_kick(buf, t, 0.12 + 0.02 * (s - 8), 330.0 if s % 2 == 0 else 250.0)  # timbales
				continue
			if s in CLAVE_STEPS:
				MusicSynth._mix_wrapped(buf, block, t, 0.22)
			if s in [7, 15]:
				MusicSynth._add_kick(buf, t, 0.16, 210.0)  # low conga
			elif s in [6, 14]:
				MusicSynth._add_kick(buf, t, 0.12, 290.0)  # high conga
		if "crash" in flags:
			MusicSynth._add_noise_hit(cymbals, rng, bar_start, 0.5, 1.0)

	SoundSynth._mix(buf, SoundSynth._bandpass(shaker, 3800.0, 0.9), 0.1)
	SoundSynth._mix(buf, SoundSynth._bandpass(cymbals, 3200.0, 1.0), 0.15)
	MusicSynth._add_echoes(buf, [0.037, 0.059], 0.4, 3000.0, 0.15)
	return SoundSynth._to_stream(buf, true)


## A steel-pan note: the bright attack table fades out fast, leaving the
## mellow body ringing.
static func _pan(cache: Dictionary, midi: int, attack_table: PackedFloat32Array, body_table: PackedFloat32Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	if not cache.has(midi):
		var freq := MusicSynth._freq(midi)
		var note := MusicSynth.render_note(body_table, freq, [0.0, 3.0], 0.9, 0.002, 0.1, 0.45, rng)
		SoundSynth._mix(note, MusicSynth.render_note(attack_table, freq, [0.0], 0.25, 0.001, 0.05, 0.06, rng), 0.8)
		cache[midi] = note
	return cache[midi]


## A woodblock clave: a short high tone plus a click.
static func _woodblock(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf := SoundSynth._silence(0.12)
	SoundSynth._add_sine(buf, 1750.0, 0.0, 0.025, 1.0)
	SoundSynth._add_sine(buf, 2650.0, 0.0, 0.012, 0.4)
	SoundSynth._add_click(buf, rng, 0.004, 0.5, 2000.0)
	return buf

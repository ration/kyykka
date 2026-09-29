class_name MusicSynth
extends RefCounted
## Synthesises the background music, a looping humppa in the style of
## Eläkeläiset, into an AudioStreamWAV at runtime — no audio files, like
## SoundSynth.
##
## Humppa is a fast "um-pa" two-beat: bass (and kick) on beats 1 and 3,
## a short chord stab (and snare) on the offbeats 2 and 4, hi-hat on every
## "and". The Eläkeläiset sound on top of that: breakneck tempo, a cheesy
## combo organ doing the chord stabs and trading lines with a musette
## accordion, a sing-along major-key tune, drum fills with the bass walking
## up into each new section, and a stop-time break with the band shouting
## "HEI!". G major: verse (accordion sings, organ answers), chorus (both in
## thirds), verse again with the roles swapped, chorus, break — whose fill
## runs straight back into the top, so the loop is seamless.
##
## Instruments are wavetables (one band-limited cycle, read at each
## note's rate) so the loop renders in a couple of seconds — still too
## long for the main thread; see the Music autoload. Everything is written
## into the buffer modulo its length, so notes and reverb ringing past the
## end wrap around to the start of the loop.

const TEMPO_BPM := 280.0
const BEATS_PER_BAR := 4
const EIGHTHS_PER_BAR := 8

const TABLE_SIZE := 2048
## Accordion reed: bright and buzzy, capped at 10 harmonics so the
## highest note (E6, ~1.3 kHz) stays under the synth's Nyquist.
const REED_HARMONICS: Array[float] = [1.0, 0.8, 0.6, 0.5, 0.45, 0.3, 0.25, 0.2, 0.15, 0.12]
## Combo organ: drawbar-style — strong octave and fifth partials, a
## little 8th harmonic sparkle, gaps between.
const ORGAN_HARMONICS: Array[float] = [1.0, 0.9, 0.6, 0.55, 0.0, 0.35, 0.0, 0.4]
const BASS_HARMONICS: Array[float] = [1.0, 0.5, 0.25, 0.12]
## Musette tuning: three reeds per note, two detuned (cents) either side
## of the middle one — the wavering beat is the sound of it.
const ACCORDION_REEDS: Array[float] = [0.0, 14.0, -14.0]
const ORGAN_VOICES: Array[float] = [0.0, 5.0]
const ORGAN_TREMOLO_HZ := 6.3

## Chord name -> [root pitch class, intervals above the root].
const CHORDS := {
	"G": [7, [0, 4, 7]],
	"C": [0, [0, 4, 7]],
	"D7": [2, [0, 4, 7, 10]],
	"A7": [9, [0, 4, 7, 10]],
	"E7": [4, [0, 4, 7, 10]],
	"Em": [4, [0, 3, 7]],
}

## Each bar: `chords` is one chord for the whole bar or "X/Y" for one per
## half bar. `lead` (accordion, or organ when `swap`) and `answer` (the
## other one) are "note:eighths" tokens, "r" a rest, filling exactly
## EIGHTHS_PER_BAR; so is `bass` when it overrides the um-pa root/fifth
## (walk-ups). `flags`: crash (cymbal on beat 1), fill (snare fill over
## beats 3-4), roll (snare fill all bar), stop (the band only hits beats 1
## and 3). `hei`: beats with a shouted "HEI!".
const VERSE := [
	{"chords": "G", "lead": "B4:2 B4:2 B4:1 A4:1 B4:1 D5:1", "answer": "", "flags": ["crash"]},
	{"chords": "G", "lead": "C5:2 B4:2 A4:4", "answer": "r:4 G5:1 F#5:1 E5:1 D5:1"},
	{"chords": "D7", "lead": "A4:2 A4:2 A4:1 G4:1 A4:1 C5:1"},
	{"chords": "D7", "lead": "B4:2 A4:2 G4:4", "answer": "r:4 D5:1 E5:1 F#5:1 A5:1"},
	{"chords": "C", "lead": "E5:2 E5:2 E5:1 D5:1 E5:1 G5:1"},
	{"chords": "G", "lead": "D5:2 B4:2 G4:4", "answer": "r:4 B4:1 C5:1 D5:1 E5:1"},
	{"chords": "A7/D7", "lead": "C#5:2 E5:2 D5:2 C5:2"},
	{"chords": "G", "lead": "B4:2 G4:2 G4:2 r:2", "answer": "r:5 D5:1 E5:1 F#5:1", "bass": "G2:2 G2:2 A2:2 B2:2", "flags": ["fill"]},
]
## The verse again with the organ singing: the accordion's answers get
## busier.
const VERSE_ANSWERS := [
	"r:6 D5:1 E5:1",
	"r:4 D6:1 C6:1 B5:1 A5:1",
	"r:6 F#5:1 G5:1",
	"r:4 A5:1 B5:1 C6:1 A5:1",
	"r:6 F#5:1 G5:1",
	"r:4 G5:1 A5:1 B5:1 D6:1",
	"r:4 A5:1 F#5:1 D5:1 F#5:1",
	"r:4 B5:1 A5:1 G5:1 F#5:1",
]
const CHORUS := [
	{"chords": "C", "lead": "E5:1 G5:1 E5:1 G5:1 C6:2 G5:2", "answer": "C5:1 E5:1 C5:1 E5:1 G5:2 E5:2", "flags": ["crash"]},
	{"chords": "G", "lead": "D5:1 G5:1 D5:1 G5:1 B5:2 G5:2", "answer": "B4:1 D5:1 B4:1 D5:1 G5:2 D5:2"},
	{"chords": "D7", "lead": "F#5:1 A5:1 F#5:1 A5:1 C6:2 A5:2", "answer": "D5:1 F#5:1 D5:1 F#5:1 A5:2 F#5:2"},
	{"chords": "G", "lead": "B5:2 A5:1 G5:1 D5:4", "answer": "G5:2 F#5:1 E5:1 B4:4"},
	{"chords": "C", "lead": "E5:1 G5:1 E5:1 G5:1 C6:2 E6:2", "answer": "C5:1 E5:1 C5:1 E5:1 G5:2 C6:2"},
	{"chords": "G/E7", "lead": "D6:2 B5:1 G5:1 E5:2 G#5:2", "answer": "B5:2 G5:1 D5:1 B4:2 E5:2"},
	{"chords": "A7/D7", "lead": "A5:1 G5:1 E5:1 C#5:1 D5:1 E5:1 F#5:1 A5:1", "answer": "E5:1 E5:1 C#5:1 A4:1 A4:1 C5:1 D5:1 F#5:1"},
	{"chords": "G", "lead": "G5:2 D5:1 B4:1 G4:2 r:2", "answer": "D5:2 B4:1 G4:1 D4:2 r:2", "bass": "G2:2 D2:2 E2:2 F#2:2", "flags": ["fill"]},
]
const BREAK := [
	{"chords": "D7", "lead": "D5:2 r:2 D5:2 r:2", "answer": "F#4:2 r:2 A4:2 r:2", "flags": ["stop"], "hei": [1, 3]},
	{"chords": "D7", "lead": "A5:1 G5:1 F#5:1 E5:1 D5:1 C5:1 A4:1 C5:1", "bass": "D2:2 E2:2 F#2:2 A2:2", "flags": ["roll"]},
]

const NOTE_CLASSES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


## The whole tune, bar by bar.
static func arrangement() -> Array:
	var bars := []
	bars.append_array(VERSE)
	bars.append_array(CHORUS)
	for i in range(VERSE.size()):
		var bar: Dictionary = VERSE[i].duplicate()
		bar.swap = true
		bar.answer = VERSE_ANSWERS[i]
		bars.append(bar)
	bars.append_array(CHORUS)
	bars.append_array(BREAK)
	return bars


static func beat_seconds() -> float:
	return 60.0 / TEMPO_BPM


static func loop_seconds() -> float:
	return arrangement().size() * BEATS_PER_BAR * beat_seconds()


## "G#5" -> 80 (MIDI note number); -1 for a rest.
static func midi_note(name: String) -> int:
	if name == "r":
		return -1
	var pc: int = NOTE_CLASSES[name[0]]
	var rest := name.substr(1)
	if rest.begins_with("#"):
		pc += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		pc -= 1
		rest = rest.substr(1)
	return 12 * (int(rest) + 1) + pc


## Parses a line into [midi note, length in eighths] pairs.
static func parse_line(line: String) -> Array:
	var notes := []
	for token in line.split(" ", false):
		var parts := token.split(":")
		notes.append([midi_note(parts[0]), int(parts[1])])
	return notes


static func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# The tune ---------------------------------------------------------------------

static func humppa() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1979
	var beat := beat_seconds()
	var eighth := beat / 2.0
	var bars := arrangement()
	var seconds := bars.size() * BEATS_PER_BAR * beat
	var buf := SoundSynth._silence(seconds)
	var reed := _wavetable(REED_HARMONICS)
	var organ := _wavetable(ORGAN_HARMONICS)
	var bass := _wavetable(BASS_HARMONICS)
	var snares := SoundSynth._silence(seconds)
	var hats := SoundSynth._silence(seconds)
	var cymbals := SoundSynth._silence(seconds)
	var hei := SoundSynth.group_shout(5)

	for b in range(bars.size()):
		var bar: Dictionary = bars[b]
		var bar_start: float = b * BEATS_PER_BAR * beat
		var chords: PackedStringArray = bar.chords.split("/")
		var flags: Array = bar.get("flags", [])
		var walking: bool = bar.has("bass")
		for i in range(BEATS_PER_BAR):
			var t := bar_start + i * beat
			var half := 0 if i < BEATS_PER_BAR / 2 or chords.size() == 1 else 1
			var chord: Array = CHORDS[chords[half]]
			var root := 40 + posmod(chord[0] - 4, 12)  # E2..D#3
			if "stop" in flags:
				# Stop-time: everyone hits beats 1 and 3 together, then silence.
				if i % 2 == 0:
					_add_note(buf, bass, _freq(root), [0.0], t, beat * 0.6, 0.003, 0.03, 0.3, 1.0, rng)
					_add_chord(buf, organ, chord, t, beat * 0.5, rng)
					_add_kick(buf, t, 0.6)
					_add_noise_hit(cymbals, rng, t, 0.35, 0.8)
				continue
			if i % 2 == 0:
				# "Um": bass on the root, or on beat 3 the fifth below it —
				# unless the chord changes there, then its new root.
				if not walking:
					var note := root - 5 if i == 2 and chords.size() == 1 else root
					_add_note(buf, bass, _freq(note), [0.0], t, beat * 0.85, 0.003, 0.03, 0.35, 0.9, rng)
				_add_kick(buf, t, 0.6)
			else:
				# "Pa": the organ's chop, with the snare.
				_add_chord(buf, organ, chord, t, 0.085, rng)
				if not ("roll" in flags or ("fill" in flags and i >= 2)):
					_add_noise_hit(snares, rng, t, 0.07, 1.0)
					_add_kick(buf, t, 0.12, 190.0)  # the snare's body
			if "roll" in flags or ("fill" in flags and i >= 2):
				for e in range(2):
					var loudness := 0.45 + 0.55 * (i * 2 + e) / 7.0
					_add_noise_hit(snares, rng, t + e * eighth, 0.05, loudness)
					_add_kick(buf, t + e * eighth, 0.08 * loudness, 190.0)
			else:
				_add_noise_hit(hats, rng, t + eighth, 0.025, 0.8 if i % 2 == 1 else 0.5)
		if "crash" in flags:
			_add_noise_hit(cymbals, rng, bar_start, 0.4, 1.0)
		if walking:
			_play_line(buf, bass, [0.0], bar.bass, bar_start, eighth, 0.003, 0.03, 0.35, 0.9, 0.0, rng)
		for shout_beat in bar.get("hei", []):
			_mix_wrapped(buf, hei, bar_start + shout_beat * beat, 2.5)

		var accordion_leads: bool = not bar.get("swap", false)
		var answer: String = bar.get("answer", "")
		var harmony := answer != "" and not answer.begins_with("r")  # in thirds, not answering
		for part in ["lead", "answer"]:
			var line: String = bar.get(part, "")
			if line == "":
				continue
			var on_accordion: bool = (part == "lead") == accordion_leads
			# A line in thirds under the tune sits back a little.
			var amp := 0.6 if part == "answer" and harmony else 1.0
			if on_accordion:
				_play_line(buf, reed, ACCORDION_REEDS, line, bar_start, eighth, 0.012, 0.05, 0.0, 0.3 * amp, 0.0, rng)
			else:
				_play_line(buf, organ, ORGAN_VOICES, line, bar_start, eighth, 0.004, 0.03, 0.0, 0.32 * amp, 0.25, rng)

	SoundSynth._mix(buf, SoundSynth._bandpass(snares, 2200.0, 1.2), 0.4)
	SoundSynth._mix(buf, SoundSynth._bandpass(hats, 5500.0, 0.8), 0.16)
	SoundSynth._mix(buf, SoundSynth._bandpass(cymbals, 3200.0, 1.0), 0.22)  # (Chamberlin SVF: damping + f must stay under 2)
	_add_room(buf)
	return SoundSynth._to_stream(buf, true)


## Plays a "note:eighths" line starting at `start`, slightly humanised.
static func _play_line(buf: PackedFloat32Array, table: PackedFloat32Array, voices: Array, line: String, start: float, eighth: float, attack: float, release: float, decay: float, amp: float, tremolo: float, rng: RandomNumberGenerator) -> void:
	var at := 0
	for note in parse_line(line):
		if note[0] >= 0:
			var t := start + at * eighth + rng.randf_range(-0.004, 0.004)
			var accent := 1.15 if at % 4 == 0 else 1.0
			_add_note(buf, table, _freq(note[0]), voices, t, note[1] * eighth * 0.88, attack, release, decay, amp * accent * rng.randf_range(0.9, 1.05), rng, tremolo)
		at += note[1]


## A short chord stab, every tone voiced in A3..G#4.
static func _add_chord(buf: PackedFloat32Array, table: PackedFloat32Array, chord: Array, start: float, hold: float, rng: RandomNumberGenerator) -> void:
	for interval in chord[1]:
		var note := 57 + posmod(chord[0] + interval - 9, 12)
		_add_note(buf, table, _freq(note), ORGAN_VOICES, start, hold, 0.004, 0.035, 0.0, 0.09, rng, 0.2)


# Instruments ------------------------------------------------------------------

## One cycle of a waveform with the given harmonic amplitudes.
static func _wavetable(harmonics: Array[float]) -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(TABLE_SIZE)
	for i in range(TABLE_SIZE):
		var x := TAU * i / TABLE_SIZE
		for h in range(harmonics.size()):
			table[i] += harmonics[h] * sin((h + 1) * x)
	return table


## A note read from `table` by one oscillator per detune (cents), held for
## `hold` seconds with linear attack/release. `decay` > 0 also fades it
## exponentially from the start, for plucked notes; `tremolo` is the depth
## of the organ's amplitude wobble (in phase with the song's clock, so
## overlapping notes wobble together).
static func _add_note(buf: PackedFloat32Array, table: PackedFloat32Array, freq: float, detunes: Array, start: float, hold: float, attack: float, release: float, decay: float, amp: float, rng: RandomNumberGenerator, tremolo: float = 0.0) -> void:
	var incs := PackedFloat32Array()
	var phases := PackedFloat32Array()
	for cents in detunes:
		incs.append(freq * pow(2.0, cents / 1200.0) * TABLE_SIZE / SoundSynth.MIX_RATE)
		phases.append(rng.randf() * TABLE_SIZE)
	var rate := float(SoundSynth.MIX_RATE)
	var offset := int(start * rate)
	var length := int((hold + release) * rate)
	var attack_n := maxf(attack * rate, 1.0)
	var hold_n := hold * rate
	var release_n := maxf(release * rate, 1.0)
	var k := exp(-1.0 / (decay * rate)) if decay > 0.0 else 1.0
	var tremolo_step := TAU * ORGAN_TREMOLO_HZ / rate
	var fade := amp
	var size := buf.size()
	for i in range(length):
		var env := fade * minf(i / attack_n, 1.0)
		if i > hold_n:
			env *= 1.0 - (i - hold_n) / release_n
		if tremolo > 0.0:
			env *= 1.0 + tremolo * sin(tremolo_step * (offset + i))
		var v := 0.0
		for r in range(incs.size()):
			v += table[int(phases[r])]
			phases[r] = fmod(phases[r] + incs[r], TABLE_SIZE)
		buf[posmod(offset + i, size)] += env * v
		fade *= k


## A sine dropping from `freq` to half of it: a kick drum, or at a higher
## pitch the tone under a snare.
static func _add_kick(buf: PackedFloat32Array, start: float, amp: float, freq: float = 110.0) -> void:
	var rate := float(SoundSynth.MIX_RATE)
	var offset := int(start * rate)
	var k := exp(-1.0 / (0.07 * rate))
	var env := amp
	var phase := 0.0
	for i in range(int(0.3 * rate)):
		var f := freq * (0.5 + 0.5 * exp(-i / (0.02 * rate)))
		phase += TAU * f / rate
		buf[posmod(offset + i, buf.size())] += env * sin(phase)
		env *= k


static func _add_noise_hit(buf: PackedFloat32Array, rng: RandomNumberGenerator, start: float, decay: float, amp: float) -> void:
	var rate := float(SoundSynth.MIX_RATE)
	var offset := int(start * rate)
	var k := exp(-1.0 / (decay * rate))
	var env := amp
	for i in range(int(decay * 6.0 * rate)):
		buf[posmod(offset + i, buf.size())] += env * rng.randf_range(-1.0, 1.0)
		env *= k


static func _mix_wrapped(buf: PackedFloat32Array, sound: PackedFloat32Array, start: float, gain: float) -> void:
	var offset := int(start * SoundSynth.MIX_RATE)
	for i in range(sound.size()):
		buf[posmod(offset + i, buf.size())] += gain * sound[i]


## A little dance-hall room: two feedback delays whose echoes wrap around
## the loop. Two passes, so the echoes of the end reach the start.
static func _add_room(buf: PackedFloat32Array) -> void:
	var size := buf.size()
	var wet := PackedFloat32Array()
	wet.resize(size)
	for delay_s in [0.041, 0.067]:
		var comb := PackedFloat32Array()
		comb.resize(size)
		var d := int(delay_s * SoundSynth.MIX_RATE)
		for _pass in range(2):
			for i in range(size):
				var j := posmod(i - d, size)
				comb[i] = buf[j] + 0.45 * comb[j]
		SoundSynth._mix(wet, comb, 1.0)
	SoundSynth._mix(buf, SoundSynth._lowpass(wet, 3000.0), 0.12)

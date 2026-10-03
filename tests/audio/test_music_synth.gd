extends GutTest


func test_every_line_fills_exactly_one_bar() -> void:
	for bar in MusicSynth.arrangement():
		for part in ["lead", "answer", "bass"]:
			if bar.get(part, "") == "":
				continue
			var eighths := 0
			for note in MusicSynth.parse_line(bar[part]):
				eighths += note[1]
			assert_eq(eighths, MusicSynth.EIGHTHS_PER_BAR, "%s of %s" % [part, bar])


func test_every_chord_is_defined() -> void:
	for bar in MusicSynth.arrangement():
		var chords: PackedStringArray = bar.chords.split("/")
		assert_between(chords.size(), 1, 2)
		for chord in chords:
			assert_has(MusicSynth.CHORDS, chord)


func test_note_names_map_to_midi() -> void:
	assert_eq(MusicSynth.midi_note("A4"), 69)
	assert_eq(MusicSynth.midi_note("C4"), 60)
	assert_eq(MusicSynth.midi_note("G#5"), 80)
	assert_eq(MusicSynth.midi_note("Bb3"), 58)
	assert_eq(MusicSynth.midi_note("r"), -1)


func test_humppa_is_a_seamless_loop_of_the_whole_tune() -> void:
	var stream := MusicSynth.humppa()
	var samples := stream.loop_end  # the data has one guard frame after the loop (SoundSynth._to_stream())
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.data.size() / 2, samples + 1)
	assert_eq(stream.data.decode_s16(samples * 2), stream.data.decode_s16(0), "guard frame = loop start")
	assert_almost_eq(samples / float(SoundSynth.MIX_RATE), MusicSynth.loop_seconds(), 0.01)
	# Wrapped rendering: the loop point is no jump bigger than a normal step.
	var first := stream.data.decode_s16(0) / 32767.0
	var last := stream.data.decode_s16((samples - 1) * 2) / 32767.0
	assert_lt(absf(first - last), 0.05)

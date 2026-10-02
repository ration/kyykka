extends GutTest
## The menu, summer and tower tracks (MusicSynth's humppa has its own test).

var TRACKS := [MenuMusic, SummerMusic, TowerMusic]


func test_every_line_fills_exactly_one_bar() -> void:
	for track in TRACKS:
		for bar in track.arrangement():
			for part in ["lead"]:
				if bar.get(part, "") == "":
					continue
				var eighths := 0
				for note in MusicSynth.parse_line(bar[part]):
					eighths += note[1]
				assert_eq(eighths, track.EIGHTHS_PER_BAR, "%s of %s" % [part, bar])


func test_every_chord_is_defined() -> void:
	for track in TRACKS:
		for bar in track.arrangement():
			assert_has(track.CHORDS, bar.chords)


func test_tracks_are_seamless_loops_of_the_whole_tune() -> void:
	for track in TRACKS:
		var stream: AudioStreamWAV = track.render()
		var samples := stream.data.size() / 2
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_almost_eq(samples / float(SoundSynth.MIX_RATE), track.loop_seconds(), 0.01)
		var peak := 0
		for i in range(0, samples, 7):
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		assert_gt(peak, 20000, "normalised, not silent (a filter blowing up gives NaN -> silence)")
		var first := stream.data.decode_s16(0) / 32767.0
		var last := stream.data.decode_s16((samples - 1) * 2) / 32767.0
		assert_lt(absf(first - last), 0.1)


func test_each_mode_has_its_own_track() -> void:
	assert_eq(Music.track_for_mode(GameMode.Mode.SUMMER), "summer")
	assert_eq(Music.track_for_mode(GameMode.Mode.WINTER), "winter")
	assert_eq(Music.track_for_mode(GameMode.Mode.TOWER), "tower")

extends GutTest


func _samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(stream.data.size() / 2)
	for i in range(out.size()):
		out[i] = stream.data.decode_s16(i * 2) / 32767.0
	return out


func _peak(stream: AudioStreamWAV) -> float:
	var peak := 0.0
	for v in _samples(stream):
		peak = maxf(peak, absf(v))
	return peak


func _all_one_shots() -> Array[AudioStreamWAV]:
	return [
		SoundSynth.karttu_hit(1),
		SoundSynth.kyykka_clack(1),
		SoundSynth.ground_impact(1, false, true),
		SoundSynth.ground_impact(1, false, false),
		SoundSynth.ground_impact(1, true, true),
		SoundSynth.ground_impact(1, true, false),
		SoundSynth.whoosh(1),
		SoundSynth.swing_miss(),
		SoundSynth.score_chime(),
		SoundSynth.match_end_jingle(),
	]


func test_sounds_are_mono_16_bit_at_the_synth_rate() -> void:
	for stream in _all_one_shots():
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_false(stream.stereo)
		assert_eq(stream.mix_rate, SoundSynth.MIX_RATE)


func test_sounds_are_normalised_without_clipping() -> void:
	for stream in _all_one_shots():
		assert_almost_eq(_peak(stream), SoundSynth.PEAK, 0.01)


func test_one_shots_end_silent_so_they_never_click() -> void:
	for stream in _all_one_shots():
		var samples := _samples(stream)
		assert_almost_eq(samples[samples.size() - 1], 0.0, 0.001)


func test_same_seed_gives_the_same_sound() -> void:
	assert_eq(SoundSynth.karttu_hit(5).data, SoundSynth.karttu_hit(5).data)


func test_different_seeds_give_different_variants() -> void:
	assert_ne(SoundSynth.karttu_hit(5).data, SoundSynth.karttu_hit(6).data)


func test_seasons_sound_different_on_landing() -> void:
	assert_ne(SoundSynth.ground_impact(1, false, true).data, SoundSynth.ground_impact(1, true, true).data)


func test_slide_loop_loops_over_the_whole_stream() -> void:
	for winter in [false, true]:
		var stream := SoundSynth.slide_loop(winter)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_eq(stream.loop_begin, 0)
		assert_eq(stream.loop_end, stream.data.size() / 2)


func test_slide_loop_seam_has_no_jump() -> void:
	var samples := _samples(SoundSynth.slide_loop(false))
	var seam := absf(samples[0] - samples[samples.size() - 1])
	var typical := 0.0
	for i in range(1, samples.size()):
		typical = maxf(typical, absf(samples[i] - samples[i - 1]))
	assert_lt(seam, typical)


func test_cached_builds_only_once() -> void:
	var calls := [0]
	var build := func() -> AudioStreamWAV:
		calls[0] += 1
		return SoundSynth.swing_miss()
	var first := SoundSynth.cached("test_cached_builds_only_once", build)
	var second := SoundSynth.cached("test_cached_builds_only_once", build)
	assert_eq(calls[0], 1)
	assert_same(first, second)


func test_full_strength_impact_plays_at_full_volume() -> void:
	assert_almost_eq(CourtAudio.impact_volume_db(8.0, 8.0), 0.0, 0.001)
	assert_almost_eq(CourtAudio.impact_volume_db(20.0, 8.0), 0.0, 0.001)


func test_half_strength_impact_is_about_6_db_quieter() -> void:
	assert_almost_eq(CourtAudio.impact_volume_db(4.0, 8.0), -6.02, 0.01)


func test_faint_impact_is_floored_not_silent() -> void:
	assert_almost_eq(CourtAudio.impact_volume_db(0.01, 8.0), linear_to_db(CourtAudio.MIN_GAIN), 0.001)


func test_crowd_cheers_are_loud_then_fade_out() -> void:
	for big in [false, true]:
		var samples := _samples(SoundSynth.crowd_cheer(1, big))
		assert_almost_eq(_peak(SoundSynth.crowd_cheer(1, big)), SoundSynth.PEAK, 0.01)
		var quarter := samples.size() / 4
		assert_gt(_rms(samples.slice(0, quarter)), 4.0 * _rms(samples.slice(3 * quarter)), "big=%s" % big)


func test_crowd_cheer_is_deterministic_per_seed() -> void:
	assert_eq(SoundSynth.crowd_cheer(3, false).data, SoundSynth.crowd_cheer(3, false).data)


func test_group_shout_is_short_and_normalised() -> void:
	var shout := SoundSynth.group_shout(1)
	assert_lt(shout.size() / float(SoundSynth.MIX_RATE), 0.5)
	var peak := 0.0
	for v in shout:
		peak = maxf(peak, absf(v))
	assert_almost_eq(peak, 1.0, 0.001)


func _rms(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in samples:
		sum += v * v
	return sqrt(sum / samples.size())

extends GutTest


## Two kyykkä and a karttu (last); kyykkä 0 starts moving at frame 3 and
## ends 1 m away, kyykkä 1 never moves.
func _frames() -> Array:
	var frames: Array = []
	for f in range(6):
		var moved := 0.0 if f < 3 else 0.25 * (f - 2)
		frames.append([
			Transform3D(Basis.IDENTITY, Vector3(1, 0, 10 + moved)),
			Transform3D(Basis.IDENTITY, Vector3(-1, 0, 10)),
			Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 2.0 * f)),
		])
	return frames


func test_impact_is_the_first_frame_a_kyykka_moves() -> void:
	assert_eq(ThrowReplay.impact_frame(_frames()), 3)


func test_no_impact_when_only_the_karttu_moves() -> void:
	var frames := _frames().slice(0, 3)
	assert_eq(ThrowReplay.impact_frame(frames), -1)
	assert_eq(ThrowReplay.impact_frame([]), -1)


func test_focus_is_where_the_kyykka_that_went_out_started() -> void:
	assert_eq(ThrowReplay.focus_point(_frames(), 3), Vector3(1, 0, 10))


func test_full_speed_on_the_way_in_slow_from_the_impact_on() -> void:
	assert_almost_eq(ThrowReplay.playback_speed(-1.0), 1.0, 0.001)
	assert_almost_eq(ThrowReplay.playback_speed(0.0), ThrowReplay.SLOW_SPEED, 0.001)
	assert_almost_eq(ThrowReplay.playback_speed(1.0), ThrowReplay.SLOW_SPEED, 0.001)
	var mid := ThrowReplay.playback_speed(-ThrowReplay.SLOWDOWN_SECONDS / 2.0)
	assert_between(mid, ThrowReplay.SLOW_SPEED, 1.0)


func test_only_more_than_three_out_is_worth_a_replay() -> void:
	var replay: ThrowReplay = add_child_autofree(ThrowReplay.new())
	replay.enabled = true
	replay._frames = _frames()
	assert_false(replay.worth_replaying(ThrowResult.new(0, 0, 0, 3, 3)))
	assert_true(replay.worth_replaying(ThrowResult.new(0, 0, 0, 4, 4)))
	replay.enabled = false
	assert_false(replay.worth_replaying(ThrowResult.new(0, 0, 0, 4, 4)))

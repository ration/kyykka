extends GutTest

const G := 9.8


func _height_at(speed: float, elevation_degrees: float, distance: float) -> float:
	var rad := deg_to_rad(elevation_degrees)
	var t := distance / (speed * cos(rad))
	return speed * sin(rad) * t - 0.5 * G * t * t


func test_solved_elevation_lands_at_requested_distance() -> void:
	var elevation := Ballistics.launch_elevation(16.0, 10.0, 0.0, G)
	assert_almost_eq(_height_at(16.0, elevation, 10.0), 0.0, 0.0001)


func test_solved_elevation_honours_height_delta() -> void:
	var elevation := Ballistics.launch_elevation(16.0, 10.0, 0.07, G)
	assert_almost_eq(_height_at(16.0, elevation, 10.0), 0.07, 0.0001)


func test_picks_the_low_flat_arc_not_the_lob() -> void:
	assert_lt(Ballistics.launch_elevation(16.0, 10.0, 0.0, G), 45.0)


func test_nearer_target_needs_a_lower_angle() -> void:
	assert_lt(
		Ballistics.launch_elevation(16.0, 5.0, 0.0, G),
		Ballistics.launch_elevation(16.0, 10.0, 0.0, G)
	)


func test_out_of_range_falls_back_to_max_range_angle() -> void:
	# max range at 5 m/s is 5^2 / 9.8 ~= 2.55 m
	assert_eq(Ballistics.launch_elevation(5.0, 10.0, 0.0, G), 45.0)


func test_flight_time_matches_horizontal_speed() -> void:
	assert_almost_eq(Ballistics.flight_time(10.0, 5.0, 60.0), 1.0, 0.0001)

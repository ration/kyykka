extends GutTest


func test_time_of_flight_matches_projectile_formula() -> void:
	# speed=10, elevation=30deg, gravity=9.8 -> 2*10*sin(30)/9.8 = 10/9.8
	var t := SpinCalculator.time_of_flight(10.0, 30.0, 9.8)
	assert_almost_eq(t, 10.0 / 9.8, 0.0001)


func test_middle_release_gives_exactly_one_rotation() -> void:
	var flight := 2.0
	var rate := SpinCalculator.spin_rate(90.0, flight)
	assert_almost_eq(rate * flight, TAU, 0.0001)


func test_zero_release_gives_zero_spin() -> void:
	assert_eq(SpinCalculator.spin_rate(0.0, 2.0), 0.0)


func test_full_release_gives_double_the_ideal_rate() -> void:
	var flight := 2.0
	var ideal := SpinCalculator.spin_rate(90.0, flight)
	var maxed := SpinCalculator.spin_rate(180.0, flight)
	assert_almost_eq(maxed, ideal * 2.0, 0.0001)

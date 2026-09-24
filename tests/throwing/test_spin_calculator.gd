extends GutTest


func test_middle_release_gives_exactly_half_a_rotation() -> void:
	var flight := 2.0
	var rate := SpinCalculator.spin_rate(90.0, flight)
	assert_almost_eq(rate * flight, PI, 0.0001)


func test_zero_release_gives_zero_spin() -> void:
	assert_eq(SpinCalculator.spin_rate(0.0, 2.0), 0.0)


func test_full_release_gives_double_the_ideal_rate() -> void:
	var flight := 2.0
	var ideal := SpinCalculator.spin_rate(90.0, flight)
	var maxed := SpinCalculator.spin_rate(180.0, flight)
	assert_almost_eq(maxed, ideal * 2.0, 0.0001)

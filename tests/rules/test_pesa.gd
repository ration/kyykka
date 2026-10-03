extends GutTest


func test_starts_with_every_kyykka_in_play_in_the_square() -> void:
	var pesa := Pesa.new(4)
	assert_eq(pesa.akka, 4)
	assert_eq(pesa.pappi, 0)
	assert_eq(pesa.kuokkavieras, 0)
	assert_eq(pesa.removed, 0)
	assert_false(pesa.is_cleared())


func test_set_counts_replaces_the_zone_counts() -> void:
	var pesa := Pesa.new(10)
	pesa.set_counts(5, 2, 1, 2)
	assert_eq([pesa.akka, pesa.pappi, pesa.kuokkavieras, pesa.removed], [5, 2, 1, 2])


func test_is_cleared_only_once_nothing_is_left_anywhere() -> void:
	var pesa := Pesa.new(3)
	pesa.set_counts(0, 1, 0, 2)
	assert_false(pesa.is_cleared(), "a pappi still has to go")
	pesa.set_counts(0, 0, 1, 2)
	assert_false(pesa.is_cleared(), "so does a kuokkavieras")
	pesa.set_counts(0, 0, 0, 3)
	assert_true(pesa.is_cleared())


func test_penalty_points() -> void:
	var pesa := Pesa.new(10)
	pesa.set_counts(3, 2, 1, 4)
	assert_eq(pesa.penalty(), 3 * 2 + 2 * 1 + 1 * 2)

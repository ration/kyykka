extends GutTest


func test_starts_with_all_kyykka_in_square() -> void:
	var pesa := Pesa.new(4)
	assert_eq(pesa.in_square, 4)
	assert_eq(pesa.on_line, 0)
	assert_eq(pesa.removed, 0)
	assert_false(pesa.is_cleared())


func test_apply_moves_pieces_between_states() -> void:
	var pesa := Pesa.new(10)

	pesa.apply(2, 3, 0)  # 2 removed directly, 3 moved onto the line
	assert_eq(pesa.in_square, 5)
	assert_eq(pesa.on_line, 3)
	assert_eq(pesa.removed, 2)

	pesa.apply(0, 0, 1)  # 1 of the on-line pieces gets removed too
	assert_eq(pesa.in_square, 5)
	assert_eq(pesa.on_line, 2)
	assert_eq(pesa.removed, 3)


func test_is_cleared_once_nothing_remains() -> void:
	var pesa := Pesa.new(2)
	pesa.apply(1, 1, 0)
	assert_false(pesa.is_cleared(), "one piece is still on the line")

	pesa.apply(0, 0, 1)
	assert_true(pesa.is_cleared())

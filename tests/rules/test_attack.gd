extends GutTest


func test_clearing_early_scores_removed_plus_unused_karttu() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(4), 10)

	attack.throw(ThrowResult.new(2, 0, 0))
	attack.throw(ThrowResult.new(2, 0, 0))

	assert_true(attack.is_finished())
	assert_eq(attack.unused_karttu(), 8)
	assert_eq(attack.score(), 4 + 8)  # 4 removed, 8 unused karttu


func test_running_out_of_karttu_with_pieces_in_square_is_penalized() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(4), 2)

	attack.throw(ThrowResult.new(1, 0, 0))
	attack.throw(ThrowResult.new())  # miss

	assert_true(attack.is_finished())
	assert_eq(attack.unused_karttu(), 0, "no bonus for an unfinished pesä")
	# 1 removed, 3 left in_square at -2 each
	assert_eq(attack.score(), 1 - 3 * Attack.PENALTY_IN_SQUARE)


func test_pieces_left_on_line_are_penalized_less_than_in_square() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(4), 1)

	attack.throw(ThrowResult.new(0, 4, 0))  # all 4 knocked onto the line, none removed

	assert_true(attack.is_finished())
	assert_eq(attack.score(), -4 * Attack.PENALTY_ON_LINE)

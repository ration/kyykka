extends GutTest
## Scoring per the official rules (kyykkaliiga.fi, "Kyykän säännöt" §6):
## removed kyykkä score nothing; each one left in the square or on its
## front line ("akka") is -2, on a side/back line ("pappi") -1, knocked
## into the gap between the squares ("kuokkavieras") -2; clearing the
## square early instead scores +1 per unused karttu.


func _result(akka: int, pappi: int = 0, kuokkavieras: int = 0, removed: int = 0, knocked_out: int = 0) -> ThrowResult:
	return ThrowResult.new(akka, pappi, kuokkavieras, removed, knocked_out)


func test_clearing_early_scores_the_unused_karttu() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(4), 16)
	attack.throw(_result(2, 0, 0, 2, 2))
	attack.throw(_result(0, 0, 0, 4, 2))
	assert_true(attack.is_finished())
	assert_eq(attack.unused_karttu(), 14)
	assert_eq(attack.score(), 14)


func test_running_out_of_karttu_is_scored_by_penalties() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(10), 2)
	attack.throw(_result(8, 0, 0, 2, 2))
	attack.throw(_result(5, 2, 1, 2))
	assert_true(attack.is_finished())
	assert_eq(attack.unused_karttu(), 0, "no bonus for an uncleared square")
	assert_eq(attack.score(), -(5 * 2 + 2 * 1 + 1 * 2))


func test_score_is_only_final_once_finished_but_running_score_is_always_available() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(4), 16)
	attack.throw(_result(3, 1, 0, 0))
	assert_false(attack.is_finished())
	assert_eq(attack.running_score(), -(3 * 2 + 1))


func test_opening_from_the_back_line_until_a_kyykka_is_out() -> void:
	var attack := Attack.new(Team.new("A"), Pesa.new(4), 16)
	assert_true(attack.throws_from_back_line(), "first throw")
	attack.throw(_result(3, 1))
	assert_true(attack.throws_from_back_line(), "a pappi isn't out")
	attack.throw(_result(2, 1, 1))
	assert_true(attack.throws_from_back_line(), "nor is a kuokkavieras")
	attack.throw(_result(1, 1, 1, 1, 1))
	assert_false(attack.throws_from_back_line(), "opened: move up to the front line")


func test_knocked_out_counts_what_left_the_square_this_throw() -> void:
	var result := _result(2, 0, 0, 2, 2)
	assert_eq(result.knocked_out, 2)
	assert_false(result.is_miss())
	assert_true(_result(4).is_miss())

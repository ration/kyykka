extends GutTest

var team_a: Team
var team_b: Team


func before_each() -> void:
	team_a = Team.new("A")
	team_b = Team.new("B")


func test_score_for_returns_each_teams_own_attack_score() -> void:
	var half := Half.new(
		Attack.new(team_a, Pesa.new(2), 3),
		Attack.new(team_b, Pesa.new(2), 1)
	)

	half.attack_by_team_a.throw(ThrowResult.new(2, 0, 0))  # clears with 2 unused
	half.attack_by_team_b.throw(ThrowResult.new())  # miss, budget exhausted

	assert_eq(half.score_for(team_a), 2 + 2)
	assert_eq(half.score_for(team_b), -2 * Attack.PENALTY_IN_SQUARE)


func test_is_finished_requires_both_attacks_finished() -> void:
	var half := Half.new(
		Attack.new(team_a, Pesa.new(1), 1),
		Attack.new(team_b, Pesa.new(1), 1)
	)

	half.attack_by_team_a.throw(ThrowResult.new(1, 0, 0))
	assert_false(half.is_finished(), "team B hasn't thrown yet")

	half.attack_by_team_b.throw(ThrowResult.new(1, 0, 0))
	assert_true(half.is_finished())


func test_next_attack_alternates_while_both_unfinished() -> void:
	var half := Half.new(
		Attack.new(team_a, Pesa.new(4), 10),
		Attack.new(team_b, Pesa.new(4), 10)
	)
	half.attack_by_team_a.throw(ThrowResult.new(1, 0, 0))

	assert_eq(half.next_attack(half.attack_by_team_a), half.attack_by_team_b)
	assert_eq(half.next_attack(half.attack_by_team_b), half.attack_by_team_a)


func test_next_attack_stays_on_current_if_other_side_finished() -> void:
	var half := Half.new(
		Attack.new(team_a, Pesa.new(1), 1),
		Attack.new(team_b, Pesa.new(4), 10)
	)
	half.attack_by_team_a.throw(ThrowResult.new(1, 0, 0))  # team A's attack is now finished
	half.attack_by_team_b.throw(ThrowResult.new(1, 0, 0))  # team B still has more to throw

	assert_eq(half.next_attack(half.attack_by_team_b), half.attack_by_team_b)

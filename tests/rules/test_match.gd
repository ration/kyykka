extends GutTest

var team_a: Team
var team_b: Team


func before_each() -> void:
	team_a = Team.new("A")
	team_b = Team.new("B")


func _play_half(match_: KyykkaMatch, a_result: ThrowResult, b_result: ThrowResult) -> void:
	var half := match_.start_half()
	half.attack_by_team_a.throw(a_result)
	half.attack_by_team_b.throw(b_result)


func test_total_score_sums_across_halves() -> void:
	# 1 kyykkä pair (2 pieces) per pesä, 1 karttu budget per attack.
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)

	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new())  # A clears, B misses
	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new())  # A clears again

	assert_true(m.is_finished())
	assert_eq(m.total_score(team_a), 4)  # 2 removed x 2 halves, no unused karttu (budget 1)
	assert_eq(m.total_score(team_b), -2 * Attack.PENALTY_IN_SQUARE * 2)


func test_winner_is_the_higher_scoring_team() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)

	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new())
	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new())

	assert_eq(m.winner(), team_a)


func test_winner_is_null_on_a_tie() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)

	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new(2, 0, 0))
	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new(2, 0, 0))

	assert_true(m.is_finished())
	assert_eq(m.winner(), null)


func test_is_finished_false_until_all_halves_played() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)
	assert_false(m.is_finished())

	_play_half(m, ThrowResult.new(2, 0, 0), ThrowResult.new(2, 0, 0))
	assert_false(m.is_finished(), "only 1 of 2 halves played")

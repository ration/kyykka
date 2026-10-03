extends GutTest

var team_a: Team
var team_b: Team


func before_each() -> void:
	team_a = Team.new("A")
	team_b = Team.new("B")


func _play_half(match_: KyykkaMatch, a_clears: bool, b_clears: bool) -> void:
	var half := match_.start_half()
	var pieces := match_.kyykka_pairs * 2
	half.attack_by_team_a.throw(ThrowResult.new(0, 0, 0, pieces, pieces) if a_clears else ThrowResult.new(pieces, 0, 0, 0))
	half.attack_by_team_b.throw(ThrowResult.new(0, 0, 0, pieces, pieces) if b_clears else ThrowResult.new(pieces, 0, 0, 0))


func test_official_defaults() -> void:
	var m := KyykkaMatch.new(team_a, team_b)
	assert_eq(m.kyykka_pairs, 20, "20 stacked pairs, 40 kyykkä")
	assert_eq(m.karttu_budget, 16, "4 players x 4 karttu")
	assert_eq(KyykkaMatch.HALVES_PER_MATCH, 2)


func test_total_score_sums_across_halves() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)  # 2 kyykkä, 1 karttu
	_play_half(m, true, false)
	_play_half(m, true, false)
	assert_true(m.is_finished())
	assert_eq(m.total_score(team_a), 0, "cleared with the last karttu: nothing unused")
	assert_eq(m.total_score(team_b), -4 * 2)


func test_winner_is_the_higher_scoring_team() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)
	_play_half(m, true, false)
	_play_half(m, true, false)
	assert_eq(m.winner(), team_a)


func test_winner_is_null_on_a_tie() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)
	_play_half(m, true, true)
	_play_half(m, true, true)
	assert_eq(m.winner(), null)


func test_is_finished_false_until_all_halves_played() -> void:
	var m := KyykkaMatch.new(team_a, team_b, 1, 1)
	assert_false(m.is_finished())
	_play_half(m, true, true)
	assert_false(m.is_finished(), "only 1 of 2 halves played")
	_play_half(m, true, true)
	assert_true(m.is_finished())


func test_the_starting_team_changes_between_halves() -> void:
	var m := KyykkaMatch.new(team_a, team_b)
	var first := m.start_half()
	assert_eq(m.starting_attack(first), first.attack_by_team_a)
	var second := m.start_half()
	assert_eq(m.starting_attack(second), second.attack_by_team_b)

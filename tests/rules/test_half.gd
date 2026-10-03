extends GutTest

var team_a: Team
var team_b: Team


func before_each() -> void:
	team_a = Team.new("A")
	team_b = Team.new("B")


func _miss(pieces: int) -> ThrowResult:
	return ThrowResult.new(pieces, 0, 0, 0)


func test_score_for_returns_each_teams_own_attack_score() -> void:
	var half := Half.new(Attack.new(team_a, Pesa.new(2), 3), Attack.new(team_b, Pesa.new(2), 1))
	half.attack_by_team_a.throw(ThrowResult.new(0, 0, 0, 2, 2))  # cleared with 2 unused
	half.attack_by_team_b.throw(_miss(2))  # budget gone, both still there
	assert_eq(half.score_for(team_a), 2)
	assert_eq(half.score_for(team_b), -4)


func test_is_finished_requires_both_attacks_finished() -> void:
	var half := Half.new(Attack.new(team_a, Pesa.new(1), 1), Attack.new(team_b, Pesa.new(1), 1))
	half.attack_by_team_a.throw(ThrowResult.new(0, 0, 0, 1, 1))
	assert_false(half.is_finished(), "team B hasn't thrown yet")
	half.attack_by_team_b.throw(ThrowResult.new(0, 0, 0, 1, 1))
	assert_true(half.is_finished())


## Official turn: two players throw two karttu each, 4 in all
## (kyykkaliiga.fi §4: "heittovuoro").
func test_a_turn_is_four_throws_then_the_other_team() -> void:
	var half := Half.new(Attack.new(team_a, Pesa.new(40), 16), Attack.new(team_b, Pesa.new(40), 16))
	var order: Array[String] = []
	var current := half.attack_by_team_a
	for i in range(12):
		order.append(current.attacking_team.team_name)
		current.throw(_miss(40))
		current = half.next_attack(current)
	assert_eq("".join(order), "AAAABBBBAAAA")


func test_turn_position_for_the_hud() -> void:
	var half := Half.new(Attack.new(team_a, Pesa.new(40), 16), Attack.new(team_b, Pesa.new(40), 16))
	assert_eq(half.throws_left_in_turn(), Half.THROWS_PER_TURN)
	half.attack_by_team_a.throw(_miss(40))
	half.next_attack(half.attack_by_team_a)
	assert_eq(half.throws_left_in_turn(), 3)


func test_once_one_side_is_finished_the_other_throws_on_alone() -> void:
	var half := Half.new(Attack.new(team_a, Pesa.new(1), 16), Attack.new(team_b, Pesa.new(40), 16))
	half.attack_by_team_a.throw(ThrowResult.new(0, 0, 0, 1, 1))  # cleared on the first karttu
	var next := half.next_attack(half.attack_by_team_a)
	assert_eq(next, half.attack_by_team_b, "A is done: B's turn straight away")
	for i in range(6):
		next.throw(_miss(40))
		next = half.next_attack(next)
		assert_eq(next, half.attack_by_team_b, "B carries on past the end of its turn")


func test_a_side_that_finishes_mid_turn_hands_over_at_once() -> void:
	var half := Half.new(Attack.new(team_a, Pesa.new(1), 16), Attack.new(team_b, Pesa.new(40), 16))
	half.attack_by_team_a.throw(_miss(1))
	assert_eq(half.next_attack(half.attack_by_team_a), half.attack_by_team_a, "still A's turn")
	half.attack_by_team_a.throw(ThrowResult.new(0, 0, 0, 1, 1))
	assert_eq(half.next_attack(half.attack_by_team_a), half.attack_by_team_b, "cleared: B's turn")

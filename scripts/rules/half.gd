class_name Half
extends RefCounted
## One half ("erä") of a match: both teams attack each other's square, in
## turns ("heittovuoro") of THROWS_PER_TURN karttu — two players throwing
## two each — alternating until each side has thrown its budget or cleared
## the square. A side that's finished hands over at once; the other then
## throws on alone. A half is finished once both attacks are.

const THROWS_PER_TURN := 4

var attack_by_team_a: Attack
var attack_by_team_b: Attack
var _throws_this_turn: int = 0


func _init(p_attack_by_team_a: Attack, p_attack_by_team_b: Attack) -> void:
	attack_by_team_a = p_attack_by_team_a
	attack_by_team_b = p_attack_by_team_b


func is_finished() -> bool:
	return attack_by_team_a.is_finished() and attack_by_team_b.is_finished()


func score_for(team: Team) -> int:
	if attack_by_team_a.attacking_team == team:
		return attack_by_team_a.score()
	if attack_by_team_b.attacking_team == team:
		return attack_by_team_b.score()
	push_error("Team is not part of this half")
	return 0


## Which Attack throws next, given `current` has just thrown. Stays with
## `current` until it's thrown THROWS_PER_TURN in a row, then switches —
## unless one side is finished, in which case the other carries on. Only
## meaningful while is_finished() is false.
func next_attack(current: Attack) -> Attack:
	var other := attack_by_team_b if current == attack_by_team_a else attack_by_team_a
	_throws_this_turn += 1
	if current.is_finished():
		_throws_this_turn = 0
		return other
	if other.is_finished():
		return current
	if _throws_this_turn >= THROWS_PER_TURN:
		_throws_this_turn = 0
		return other
	return current


## Karttu left in the current turn.
func throws_left_in_turn() -> int:
	return THROWS_PER_TURN - _throws_this_turn

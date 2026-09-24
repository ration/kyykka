class_name Attack
extends RefCounted
## One team's attempt to clear the opponent's pesä within a karttu budget.
## Scoring follows README.md: +1 per kyykkä removed, +1 per karttu left
## unused once the pesä is cleared, and a penalty per kyykkä still
## IN_SQUARE or ON_LINE once the budget runs out.
##
## The penalty values are the best figures found while researching the
## rules (Wikipedia's "Finnish skittles" scoring section); confirm them
## against the official Suomen Kyykkäliitto rulebook if exact numbers
## start to matter (e.g. for a ranked/official game mode).

const PENALTY_IN_SQUARE := 2
const PENALTY_ON_LINE := 1

var attacking_team: Team
var pesa: Pesa
var karttu_budget: int
var karttu_used: int = 0
var throws: Array[ThrowResult] = []


func _init(p_attacking_team: Team, p_pesa: Pesa, p_karttu_budget: int) -> void:
	attacking_team = p_attacking_team
	pesa = p_pesa
	karttu_budget = p_karttu_budget


func is_finished() -> bool:
	return pesa.is_cleared() or karttu_used >= karttu_budget


func throw(result: ThrowResult) -> void:
	assert(not is_finished(), "Attack already finished")
	pesa.apply(result.removed_from_square, result.moved_to_line, result.removed_from_line)
	throws.append(result)
	karttu_used += 1


## Bonus karttu only count once the pesä is actually cleared — running out
## of karttu with kyykkä still standing leaves nothing "unused".
func unused_karttu() -> int:
	return karttu_budget - karttu_used if pesa.is_cleared() else 0


func score() -> int:
	assert(is_finished(), "score() is only meaningful once the attack has finished")
	return (
		pesa.removed
		+ unused_karttu()
		- pesa.in_square * PENALTY_IN_SQUARE
		- pesa.on_line * PENALTY_ON_LINE
	)

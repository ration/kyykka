class_name Attack
extends RefCounted
## One team's half against the opponent's square: a karttu budget (16 —
## four players, four karttu each) to clear it. Scored per the official
## rules (kyykkaliiga.fi "Kyykän säännöt" §6): knocked-out kyykkä earn
## nothing; what's left when the karttu run out costs penalty points (see
## Pesa); clearing the square early instead scores +1 per unused karttu.

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
	pesa.set_counts(result.akka, result.pappi, result.kuokkavieras, result.removed)
	throws.append(result)
	karttu_used += 1


## The opening ("avaus"): throw from the back line of the throwing square
## until a kyykkä has gone out of play — a pappi or kuokkavieras doesn't
## count — then from its front line.
func throws_from_back_line() -> bool:
	return pesa.removed == 0


## Only once the square's cleared — running out with kyykkä left leaves
## nothing "unused".
func unused_karttu() -> int:
	return karttu_budget - karttu_used if pesa.is_cleared() else 0


func score() -> int:
	assert(is_finished(), "score() is only final once the attack has finished")
	return running_score()


## What the score would be if it ended now: the bonus if cleared,
## otherwise minus the penalties for what's left. For the HUD mid-attack.
func running_score() -> int:
	return unused_karttu() if pesa.is_cleared() else -pesa.penalty()

class_name KyykkaMatch
extends RefCounted
## Orchestrates a full match: two teams, HALVES_PER_MATCH halves, each
## worth a fresh Attack per team against a freshly-stocked Pesa.
##
## Defaults follow the official rules (kyykkaliiga.fi "Kyykän säännöt"):
## 20 stacked pairs (40 kyykkä) on each square's front line, and 16 karttu
## per team per half — four players throwing four each, in turns of four
## (see Half). Constructor args so tests and other formats can change them.

const DEFAULT_KYYKKA_PAIRS := 20
const DEFAULT_KARTTU_BUDGET := 16
const HALVES_PER_MATCH := 2

var team_a: Team
var team_b: Team
var kyykka_pairs: int
var karttu_budget: int
var halves: Array[Half] = []


func _init(
	p_team_a: Team,
	p_team_b: Team,
	p_kyykka_pairs: int = DEFAULT_KYYKKA_PAIRS,
	p_karttu_budget: int = DEFAULT_KARTTU_BUDGET
) -> void:
	team_a = p_team_a
	team_b = p_team_b
	kyykka_pairs = p_kyykka_pairs
	karttu_budget = p_karttu_budget


func start_half() -> Half:
	assert(halves.size() < HALVES_PER_MATCH, "Match already has all its halves")
	var kyykka_count := kyykka_pairs * 2
	var half := Half.new(
		Attack.new(team_a, Pesa.new(kyykka_count), karttu_budget),
		Attack.new(team_b, Pesa.new(kyykka_count), karttu_budget)
	)
	halves.append(half)
	return half


func is_finished() -> bool:
	if halves.size() < HALVES_PER_MATCH:
		return false
	return halves.all(func(half: Half) -> bool: return half.is_finished())


func total_score(team: Team) -> int:
	var total := 0
	for half in halves:
		total += half.score_for(team)
	return total


## The attack that throws first in `half`: team A in the first half, then
## alternating — the starting team changes between halves
## ("aloittava joukkue vaihtuu").
func starting_attack(half: Half) -> Attack:
	var index := halves.find(half)
	return half.attack_by_team_a if index % 2 == 0 else half.attack_by_team_b


## Returns the winning Team, or null on a tie.
func winner() -> Team:
	assert(is_finished(), "Match is not finished yet")
	var score_a := total_score(team_a)
	var score_b := total_score(team_b)
	if score_a == score_b:
		return null
	return team_a if score_a > score_b else team_b

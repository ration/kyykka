class_name KyykkaMatch
extends RefCounted
## Orchestrates a full match: two teams, HALVES_PER_MATCH halves, each
## worth a fresh Attack per team against a freshly-stocked Pesa.
##
## Defaults follow README.md: 10 kyykkä pairs (20 pieces, stacked two high
## per position) per pesä and a 10-karttu budget per attack (one nominal
## throw per pair). Named as constants/constructor args so they're easy to
## correct once confirmed against the official rulebook, and so Phase 2+
## can wire up alternate formats (pairs, individual play) without changing
## this class's shape.

const DEFAULT_KYYKKA_PAIRS := 10
const DEFAULT_KARTTU_BUDGET := 10
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


## Returns the winning Team, or null on a tie.
func winner() -> Team:
	assert(is_finished(), "Match is not finished yet")
	var score_a := total_score(team_a)
	var score_b := total_score(team_b)
	if score_a == score_b:
		return null
	return team_a if score_a > score_b else team_b

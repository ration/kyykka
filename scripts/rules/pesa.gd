class_name Pesa
extends RefCounted
## One team's target square during an Attack, as counts of its kyykkä in
## each zone (official rules, kyykkaliiga.fi "Kyykän säännöt"):
##
## - akka — still in play inside the square, or on its front line (or a
##   side line within 10 cm of it): -2 each when the karttu run out;
## - pappi — on a side or back line, stood upright there: -1;
## - kuokkavieras — knocked forward into the gap between the squares: -2,
##   and never lifted as a pappi;
## - removed — out of play: nothing.
##
## A piece can move between these in any direction (a pappi knocked into
## the gap, a kuokkavieras knocked clean out), so the whole state comes in
## with each throw (set_counts()) rather than as transitions.

const PENALTY_AKKA := 2
const PENALTY_PAPPI := 1
const PENALTY_KUOKKAVIERAS := 2

var kyykka_count: int
var akka: int
var pappi: int = 0
var kuokkavieras: int = 0
var removed: int = 0


func _init(p_kyykka_count: int) -> void:
	kyykka_count = p_kyykka_count
	akka = p_kyykka_count


func set_counts(p_akka: int, p_pappi: int, p_kuokkavieras: int, p_removed: int) -> void:
	assert(p_akka + p_pappi + p_kuokkavieras + p_removed == kyykka_count, "every kyykkä is in exactly one zone")
	akka = p_akka
	pappi = p_pappi
	kuokkavieras = p_kuokkavieras
	removed = p_removed


## Everything is out of play.
func is_cleared() -> bool:
	return removed == kyykka_count


## Minus points for what's still left.
func penalty() -> int:
	return akka * PENALTY_AKKA + pappi * PENALTY_PAPPI + kuokkavieras * PENALTY_KUOKKAVIERAS

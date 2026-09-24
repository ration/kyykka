class_name Pesa
extends RefCounted
## Tracks one team's playing square (pesä) during an Attack.
##
## Each kyykkä piece moves IN_SQUARE -> ON_LINE -> REMOVED, or directly
## IN_SQUARE -> REMOVED. Pieces are tracked as counts rather than
## individually, since positions aren't modeled until the physics in
## Phase 3 (ROADMAP.md) — apply() is the seam that will eventually be fed
## by classifying each kyykkä's final resting position on the court.

var kyykka_count: int
var in_square: int
var on_line: int = 0
var removed: int = 0


func _init(p_kyykka_count: int) -> void:
	kyykka_count = p_kyykka_count
	in_square = p_kyykka_count


func is_cleared() -> bool:
	return in_square == 0 and on_line == 0


## Applies one throw's effect on this pesä.
func apply(removed_from_square: int = 0, moved_to_line: int = 0, removed_from_line: int = 0) -> void:
	assert(removed_from_square >= 0 and moved_to_line >= 0 and removed_from_line >= 0)
	assert(removed_from_square + moved_to_line <= in_square)
	assert(removed_from_line <= on_line)

	in_square -= removed_from_square + moved_to_line
	on_line += moved_to_line - removed_from_line
	removed += removed_from_square + removed_from_line

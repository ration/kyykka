class_name ThrowResult
extends RefCounted
## One karttu throw's effect on the target pesä. Phase 1 constructs these
## directly (e.g. in tests); Phase 3's physics will construct them by
## classifying where each kyykkä piece ended up after a throw.

var removed_from_square: int
var moved_to_line: int
var removed_from_line: int


func _init(p_removed_from_square: int = 0, p_moved_to_line: int = 0, p_removed_from_line: int = 0) -> void:
	removed_from_square = p_removed_from_square
	moved_to_line = p_moved_to_line
	removed_from_line = p_removed_from_line


func is_miss() -> bool:
	return removed_from_square == 0 and moved_to_line == 0 and removed_from_line == 0

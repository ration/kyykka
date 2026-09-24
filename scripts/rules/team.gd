class_name Team
extends RefCounted
## One side in a KyykkaMatch. Deliberately minimal for now — player
## rosters, pairs vs. individual play, etc. belong to later phases
## (see ROADMAP.md Phase 6/7) and can be added here without touching
## the rest of scripts/rules/.

var team_name: String


func _init(p_team_name: String) -> void:
	team_name = p_team_name

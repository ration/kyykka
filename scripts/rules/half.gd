class_name Half
extends RefCounted
## One half of a match: both teams simultaneously attack each other's
## pesä. A half is finished once both attacks are finished.

var attack_by_team_a: Attack
var attack_by_team_b: Attack


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


## Which Attack should throw next, given `current` just finished a throw.
## Alternates to the other side unless it's already finished, in which
## case the still-unfinished side continues alone. Only meaningful while
## is_finished() is false.
func next_attack(current: Attack) -> Attack:
	var other := attack_by_team_b if current == attack_by_team_a else attack_by_team_a
	return other if not other.is_finished() else current

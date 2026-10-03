class_name ThrowResult
extends RefCounted
## Where one karttu throw left the target pesä's kyykkä: how many are in
## each zone afterwards (see Pesa for the zones), plus how many of them
## were knocked out of play by this throw — for the cheering and the chime.
## Built by PesaScorer from the pieces' resting positions.

var akka: int
var pappi: int
var kuokkavieras: int
var removed: int
var knocked_out: int  ## left play (became `removed`) on this throw


func _init(p_akka: int = 0, p_pappi: int = 0, p_kuokkavieras: int = 0, p_removed: int = 0, p_knocked_out: int = 0) -> void:
	akka = p_akka
	pappi = p_pappi
	kuokkavieras = p_kuokkavieras
	removed = p_removed
	knocked_out = p_knocked_out


## Nothing went out (the zone counts may still have shifted).
func is_miss() -> bool:
	return knocked_out == 0

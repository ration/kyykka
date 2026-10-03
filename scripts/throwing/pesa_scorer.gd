class_name PesaScorer
extends RefCounted
## Bridges a PesaView's live 3D piece positions to the rules engine: after
## each throw settles, classifies every piece (PieceClassifier) and
## reports the pesä's zone counts as a ThrowResult for Attack.throw().
## Pieces that end up a pappi are stood upright on their line, as the
## referee does.
##
## It also remembers where every piece last came to rest, so when the
## defending team knocks its own kyykkä — a short throw landing in its own
## throwing square — restore_moved() puts them back (kyykkaliiga.fi §7.8:
## the opponent's kyykkä must not be moved; any that are, are put back).

const STOOD_UP_TOLERANCE := 0.03  ## metres a stood-up piece can drift and still be a pappi
const MOVED_TOLERANCE := 0.02     ## metres a piece can be nudged before it counts as moved

var pesa_view: PesaView
var attack: Attack
var _zones: Dictionary = {}       # Node -> PieceClassifier.Zone, as of the last scoring
var _stood_up: Dictionary = {}    # Node -> where stand_up_on_line() left it
var _resting: Dictionary = {}     # Node -> local Transform3D where it last came to rest


func _init(p_pesa_view: PesaView, p_attack: Attack) -> void:
	pesa_view = p_pesa_view
	attack = p_attack
	for piece in pesa_view.get_children():
		_zones[piece] = _classify(piece)
		_resting[piece] = piece.transform


func _classify(piece: Node3D) -> PieceClassifier.Zone:
	var local := pesa_view.to_pesa_local(piece.global_position)
	return PieceClassifier.classify(
		local.x,
		local.y,  # Vector2's y holds "depth" here, see to_pesa_local()
		pesa_view.pesa_half_width,
		pesa_view.pesa_depth,
		pesa_view.gap_length,
		pesa_view.kyykka_diameter / 2.0
	)


## Re-classifies every piece and returns the zone counts as a ThrowResult,
## with how many left play since the last call. Every new pappi is stood
## upright on its line (PesaView.stand_up_on_line()); a piece already
## stood up sits exactly on the line, right on the classifier's boundary,
## so it stays a pappi until it's actually been moved again (more than
## STOOD_UP_TOLERANCE) rather than whatever solver jitter makes of it.
## Out of play is out for good, even if a piece rolls back.
func score_current_state() -> ThrowResult:
	var counts := {}
	for zone: int in PieceClassifier.Zone.values():
		counts[zone] = 0
	var knocked_out := 0
	for piece: RigidBody3D in _zones.keys():
		var previous: PieceClassifier.Zone = _zones[piece]
		var current := previous
		if previous != PieceClassifier.Zone.REMOVED:
			current = _classify(piece)
			if _stood_up.has(piece):
				if piece.global_position.distance_to(_stood_up[piece]) < STOOD_UP_TOLERANCE:
					current = PieceClassifier.Zone.PAPPI
				else:
					_stood_up.erase(piece)
			if current == PieceClassifier.Zone.PAPPI and not _stood_up.has(piece):
				pesa_view.stand_up_on_line(piece)
				_stood_up[piece] = piece.global_position
			if current == PieceClassifier.Zone.REMOVED:
				knocked_out += 1
		_zones[piece] = current
		_resting[piece] = piece.transform
		counts[current] += 1
	return ThrowResult.new(
		counts[PieceClassifier.Zone.AKKA],
		counts[PieceClassifier.Zone.PAPPI],
		counts[PieceClassifier.Zone.KUOKKAVIERAS],
		counts[PieceClassifier.Zone.REMOVED],
		knocked_out
	)


## Puts back every piece that's moved since it last came to rest (§7.8,
## see the class comment). Returns how many it restored.
func restore_moved() -> int:
	var restored := 0
	for piece: RigidBody3D in _resting.keys():
		var was: Transform3D = _resting[piece]
		if piece.transform.origin.distance_to(was.origin) > MOVED_TOLERANCE:
			pesa_view.restore(piece, was)
			restored += 1
	return restored

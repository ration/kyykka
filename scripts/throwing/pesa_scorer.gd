class_name PesaScorer
extends RefCounted
## Bridges a PesaView's live 3D piece positions to the rules engine: after
## each throw settles, classifies every piece and reports the transitions
## since the last call as a ThrowResult, ready for Attack.throw().

var pesa_view: PesaView
var attack: Attack
var _zones: Dictionary = {}  # Node -> PieceClassifier.Zone
var _stood_up: Dictionary = {}  # Node -> where stand_up_on_line() left it


const STOOD_UP_TOLERANCE := 0.03  ## metres a stood-up piece can drift and still be on the line


func _init(p_pesa_view: PesaView, p_attack: Attack) -> void:
	pesa_view = p_pesa_view
	attack = p_attack
	for piece in pesa_view.get_children():
		_zones[piece] = _classify(piece)


func _classify(piece: Node3D) -> PieceClassifier.Zone:
	var local := pesa_view.to_pesa_local(piece.global_position)
	return PieceClassifier.classify(
		local.x,
		local.y,  # Vector2's y holds "depth" here, see to_pesa_local()
		pesa_view.pesa_half_width,
		pesa_view.pesa_depth,
		pesa_view.kyykka_diameter / 2.0
	)


## Re-classifies every piece and returns the transitions since the last
## call (or since construction) as a ThrowResult. Every piece now ON_LINE
## is stood upright on the line (PesaView.stand_up_on_line()).
##
## A piece stood up sits exactly on the line, right on the classifier's
## boundary, so it stays ON_LINE until it's actually been moved again
## (more than STOOD_UP_TOLERANCE) rather than whatever solver jitter makes
## of it.
func score_current_state() -> ThrowResult:
	var removed_from_square := 0
	var moved_to_line := 0
	var removed_from_line := 0

	for piece in _zones.keys():
		var previous: PieceClassifier.Zone = _zones[piece]
		if previous == PieceClassifier.Zone.REMOVED:
			continue

		var current := _classify(piece)
		if _stood_up.has(piece):
			if piece.global_position.distance_to(_stood_up[piece]) < STOOD_UP_TOLERANCE:
				current = PieceClassifier.Zone.ON_LINE
			else:
				_stood_up.erase(piece)
		if current == PieceClassifier.Zone.ON_LINE:
			pesa_view.stand_up_on_line(piece)
			_stood_up[piece] = piece.global_position
		if current == previous:
			continue

		match [previous, current]:
			[PieceClassifier.Zone.IN_SQUARE, PieceClassifier.Zone.ON_LINE]:
				moved_to_line += 1
			[PieceClassifier.Zone.IN_SQUARE, PieceClassifier.Zone.REMOVED]:
				removed_from_square += 1
			[PieceClassifier.Zone.ON_LINE, PieceClassifier.Zone.REMOVED]:
				removed_from_line += 1
			# A piece moving back toward IN_SQUARE isn't modeled by Pesa
			# (see scripts/rules/pesa.gd) and shouldn't happen in
			# practice once knocked outward; ignore rather than crash.
			_:
				continue

		_zones[piece] = current

	return ThrowResult.new(removed_from_square, moved_to_line, removed_from_line)

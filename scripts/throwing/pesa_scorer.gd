class_name PesaScorer
extends RefCounted
## Bridges a PesaView's live 3D piece positions to the rules engine: after
## each throw settles, classifies every piece and reports the transitions
## since the last call as a ThrowResult, ready for Attack.throw().

var pesa_view: PesaView
var attack: Attack
var _zones: Dictionary = {}  # Node -> PieceClassifier.Zone


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
## call (or since construction) as a ThrowResult.
func score_current_state() -> ThrowResult:
	var removed_from_square := 0
	var moved_to_line := 0
	var removed_from_line := 0

	for piece in _zones.keys():
		var previous: PieceClassifier.Zone = _zones[piece]
		if previous == PieceClassifier.Zone.REMOVED:
			continue

		var current := _classify(piece)
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

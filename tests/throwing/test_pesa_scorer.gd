extends GutTest

var view: PesaView
var attack: Attack
var scorer: PesaScorer


func before_each() -> void:
	view = PesaView.new()
	view.kyykka_scene = preload("res://scenes/kyykka.tscn")
	view.piece_count = 2
	view.pesa_half_width = 2.5
	view.pesa_depth = 5.0
	view.depth_direction = 1.0
	add_child_autofree(view)

	attack = Attack.new(Team.new("Test"), Pesa.new(2), 16)
	scorer = PesaScorer.new(view, attack)


func _counts(result: ThrowResult) -> Array:
	return [result.akka, result.pappi, result.kuokkavieras, result.removed]


func test_freshly_set_up_pieces_are_all_akka() -> void:
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [2, 0, 0, 0])
	assert_true(result.is_miss())


func test_piece_knocked_out_the_back_is_removed_and_counted_as_knocked_out() -> void:
	view.get_child(0).global_position.z = view.global_position.z + 6.0  # past the back line
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [1, 0, 0, 1])
	assert_eq(result.knocked_out, 1)
	attack.throw(result)
	assert_eq(attack.pesa.removed, 1)
	assert_false(attack.throws_from_back_line(), "opened")


func test_piece_knocked_forward_into_the_gap_is_kuokkavieras() -> void:
	view.get_child(0).global_position.z = view.global_position.z - 2.0
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [1, 0, 1, 0])
	assert_eq(result.knocked_out, 0, "still in play")


func test_kuokkavieras_knocked_out_later_is_removed() -> void:
	var piece: Node3D = view.get_child(0)
	piece.global_position.z = view.global_position.z - 2.0
	scorer.score_current_state()
	piece.global_position.x = view.global_position.x + 4.0  # off the side of the court
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [1, 0, 0, 1])
	assert_eq(result.knocked_out, 1)


func test_once_out_always_out() -> void:
	var piece: Node3D = view.get_child(0)
	piece.global_position.z = view.global_position.z + 6.0
	scorer.score_current_state()
	piece.global_position.z = view.global_position.z + 2.0  # rolled back in
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [1, 0, 0, 1])
	assert_eq(result.knocked_out, 0, "not knocked out twice")


func test_pappi_is_stood_up_on_the_back_line_and_stays_a_pappi() -> void:
	var piece: RigidBody3D = view.get_child(0)
	piece.global_position = view.global_position + Vector3(1.0, 0.035, 4.98)
	piece.rotation = Vector3(PI / 2.0, 0.3, 0.0)  # lying on its side
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [1, 1, 0, 0])
	assert_almost_eq(piece.global_position.z, view.global_position.z + 5.0, 0.001, "on the back line")
	assert_almost_eq(piece.global_position.y, view.kyykka_height / 2.0, 0.001, "standing on the ground")
	assert_almost_eq(piece.global_basis.y, Vector3.UP, Vector3.ONE * 0.001, "upright")
	# Solver jitter nudging it off the exact line doesn't change its zone...
	piece.global_position.z += 0.02
	assert_eq(_counts(scorer.score_current_state()), [1, 1, 0, 0])
	# ...but knocking it out does.
	piece.global_position.z = view.global_position.z + 6.0
	assert_eq(_counts(scorer.score_current_state()), [1, 0, 0, 1])


func test_on_the_front_line_is_akka_and_not_stood_up() -> void:
	var piece: RigidBody3D = view.get_child(0)
	piece.global_position = view.global_position + Vector3(1.0, 0.035, -0.02)
	var before := piece.global_position
	var result := scorer.score_current_state()
	assert_eq(_counts(result), [2, 0, 0, 0])
	assert_eq(piece.global_position, before, "left where it is")


func test_restore_moved_puts_pieces_back_where_they_rested() -> void:
	var piece: RigidBody3D = view.get_child(0)
	var rested := piece.transform
	piece.global_position.z = view.global_position.z + 6.0
	piece.rotation = Vector3(1, 0, 0)
	assert_eq(scorer.restore_moved(), 1)
	assert_almost_eq(piece.transform.origin, rested.origin, Vector3.ONE * 0.001)
	assert_eq(_counts(scorer.score_current_state()), [2, 0, 0, 0], "as if nothing happened")
	assert_eq(scorer.restore_moved(), 0)

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

	attack = Attack.new(Team.new("Test"), Pesa.new(2), 10)
	scorer = PesaScorer.new(view, attack)


func test_initial_state_is_in_square_with_no_transitions() -> void:
	var result := scorer.score_current_state()
	assert_true(result.is_miss())
	assert_eq(attack.pesa.in_square, 2)


func test_piece_moved_to_line_is_reported() -> void:
	view.get_child(0).global_position.z = view.global_position.z + 0.01  # depth ~0.01, within margin
	var result := scorer.score_current_state()

	assert_eq(result.moved_to_line, 1)
	assert_eq(result.removed_from_square, 0)
	assert_eq(result.removed_from_line, 0)

	attack.throw(result)
	assert_eq(attack.pesa.in_square, 1)
	assert_eq(attack.pesa.on_line, 1)


func test_piece_removed_from_square_is_reported() -> void:
	view.get_child(0).global_position.z = view.global_position.z - 1.0  # well past the front line

	var result := scorer.score_current_state()
	assert_eq(result.removed_from_square, 1)

	attack.throw(result)
	assert_eq(attack.pesa.removed, 1)
	assert_eq(attack.pesa.in_square, 1)


func test_piece_removed_after_being_on_line_counts_as_removed_from_line() -> void:
	var piece: Node3D = view.get_child(0)

	piece.global_position.z = view.global_position.z + 0.01
	attack.throw(scorer.score_current_state())
	assert_eq(attack.pesa.on_line, 1)

	piece.global_position.z = view.global_position.z - 1.0
	var result := scorer.score_current_state()
	assert_eq(result.removed_from_line, 1)
	assert_eq(result.removed_from_square, 0)

	attack.throw(result)
	assert_eq(attack.pesa.on_line, 0)
	assert_eq(attack.pesa.removed, 1)


func test_unmoved_piece_reports_no_transition() -> void:
	scorer.score_current_state()  # settle initial state
	var result := scorer.score_current_state()
	assert_true(result.is_miss())


func test_piece_on_the_line_is_stood_up_on_it_and_stays_on_line() -> void:
	var piece: RigidBody3D = view.get_child(0)
	piece.global_position = view.global_position + Vector3(1.0, 0.035, 0.02)
	piece.rotation = Vector3(PI / 2.0, 0.3, 0.0)  # lying on its side
	var result := scorer.score_current_state()
	assert_eq(result.moved_to_line, 1)
	assert_almost_eq(piece.global_position.z, view.global_position.z, 0.001, "on the front line")
	assert_almost_eq(piece.global_position.y, view.kyykka_height / 2.0, 0.001, "standing on the ground")
	assert_almost_eq(piece.global_basis.y, Vector3.UP, Vector3.ONE * 0.001, "upright")
	attack.throw(result)

	# Solver jitter nudging it off the exact line doesn't change its zone...
	piece.global_position.z += 0.02
	assert_true(scorer.score_current_state().is_miss())
	# ...but knocking it out does.
	piece.global_position.z = view.global_position.z - 1.0
	result = scorer.score_current_state()
	assert_eq(result.removed_from_line, 1)

extends GutTest


func test_spawns_piece_count_children() -> void:
	var view := PesaView.new()
	view.kyykka_scene = preload("res://scenes/kyykka.tscn")
	view.piece_count = 8
	add_child_autofree(view)

	assert_eq(view.get_child_count(), 8)


func test_default_piece_count_matches_rules_engine() -> void:
	var view: PesaView = autofree(PesaView.new())
	assert_eq(view.piece_count, KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2)


func _colors(view: PesaView) -> Array[Color]:
	var colors: Array[Color] = []
	for piece in view.get_children():
		colors.append(piece.get_node("MeshInstance3D").material_override.albedo_color)
	return colors


func test_targeted_kyykka_turn_red_and_back() -> void:
	var view := PesaView.new()
	view.kyykka_scene = preload("res://scenes/kyykka.tscn")
	view.piece_count = 4
	add_child_autofree(view)
	var wood := _colors(view)

	view.set_targeted(true)
	for color in _colors(view):
		assert_eq(color, PesaView.TARGET_COLOR)
	view.set_targeted(false)
	assert_eq(_colors(view), wood)

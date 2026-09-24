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

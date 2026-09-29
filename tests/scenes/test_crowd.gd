extends GutTest


func _layout() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = Crowd.SEED
	return Crowd.layout(rng, 2.5, 10.0)


func test_crowd_stands_clear_of_the_court() -> void:
	var spots := _layout()
	assert_gt(spots.size(), 40)
	for spot in spots:
		assert_gte(absf(spot.position.x), 2.5 + Crowd.MIN_SIDE_CLEARANCE - 0.001)


func test_spectators_do_not_overlap() -> void:
	var spots := _layout()
	for i in range(spots.size()):
		for j in range(i + 1, spots.size()):
			assert_gte(spots[i].position.distance_to(spots[j].position), Crowd.MIN_SPACING)


func test_spectators_face_the_court() -> void:
	for spot in _layout():
		var facing := Basis(Vector3.UP, spot.yaw) * Vector3.BACK  # meshes face +Z
		assert_lt(facing.x * signf(spot.position.x), 0.0, "facing %s at %s" % [facing, spot.position])


func test_every_pose_builds_for_both_seasons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for winter in [false, true]:
		var look := SpectatorMesh.random_look(rng, Color.RED, winter)
		look.can = Color.BLUE
		for pose in SpectatorMesh.Pose.values():
			var mesh := SpectatorMesh.build(look, pose)
			assert_eq(mesh.get_surface_count(), 1)
			var aabb := mesh.get_aabb()
			assert_almost_eq(aabb.position.y, 0.0, 0.01, "feet on the ground")
			assert_gt(aabb.end.y, 1.7 if pose == SpectatorMesh.Pose.CHEER else 1.6)


func test_drinking_brings_the_can_up_to_the_mouth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var look := SpectatorMesh.random_look(rng, Color.RED, false)
	look.can = Color.BLUE
	var can_top := func(pose: SpectatorMesh.Pose) -> float:
		# The can is the only blue in the mesh.
		var arrays := SpectatorMesh.build(look, pose).surface_get_arrays(0)
		var top := -1.0
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if arrays[Mesh.ARRAY_COLOR][i].is_equal_approx(Color.BLUE):
				top = maxf(top, arrays[Mesh.ARRAY_VERTEX][i].y)
		return top
	assert_lt(can_top.call(SpectatorMesh.Pose.DOWN), 1.0, "held at the hip")
	assert_between(can_top.call(SpectatorMesh.Pose.DRINK), 1.55, 1.75, "at the mouth")


func test_logo_wearer_is_front_row_near_the_middle() -> void:
	var spots := _layout()
	var wearer := Crowd.logo_wearer_index(spots, 2.5)
	assert_gte(wearer, 0)
	var at: Vector3 = spots[wearer].position
	assert_lte(absf(at.x), 2.5 + Crowd.MIN_SIDE_CLEARANCE + 0.6)
	assert_lt(absf(at.z), 3.0)

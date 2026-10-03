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


func test_bend_keeps_limb_lengths_and_bends_toward_the_pole() -> void:
	var root := Vector3(0.1, 0.9, 0)
	var joints := SpectatorMesh._bend(root, Vector3(0.12, 0.15, 0.1), SpectatorMesh.THIGH, SpectatorMesh.SHIN, Vector3.BACK)
	var knee: Vector3 = joints[0]
	var ankle: Vector3 = joints[1]
	assert_almost_eq(root.distance_to(knee), SpectatorMesh.THIGH, 0.001)
	assert_almost_eq(knee.distance_to(ankle), SpectatorMesh.SHIN, 0.001)
	assert_gt(knee.z, (root.z + ankle.z) / 2.0, "knee bends forward")
	# Out of reach: the end stops short instead of stretching the limb.
	joints = SpectatorMesh._bend(root, root + Vector3.DOWN * 2.0, SpectatorMesh.THIGH, SpectatorMesh.SHIN, Vector3.BACK)
	assert_almost_eq(root.distance_to(joints[1]), SpectatorMesh.THIGH + SpectatorMesh.SHIN, 0.01)


func test_every_stance_and_hairstyle_builds_on_the_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for winter in [false, true]:
		for stance in SpectatorMesh.STANCES:
			for style in SpectatorMesh.HAIR_STYLES:
				var look := SpectatorMesh.random_look(rng, Color.RED, winter)
				look.stance = stance
				look.hair_style = style
				look.can = null
				var aabb := SpectatorMesh.build(look, SpectatorMesh.Pose.DOWN).get_aabb()
				assert_almost_eq(aabb.position.y, 0.0, 0.01, "%s/%s feet on the ground" % [stance, style])
				assert_between(aabb.end.y, 1.65, 1.85, "%s/%s height" % [stance, style])
				assert_lt(aabb.size.x, 0.85, "%s/%s width" % [stance, style])


func test_build_poses_matches_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var look := SpectatorMesh.random_look(rng, Color.RED, false)
	look.can = Color.BLUE
	var poses := SpectatorMesh.Pose.values()
	var meshes := SpectatorMesh.build_poses(look, poses)
	for pose in poses:
		var shared: Array = meshes[pose].surface_get_arrays(0)
		var alone: Array = SpectatorMesh.build(look, pose).surface_get_arrays(0)
		assert_eq(shared[Mesh.ARRAY_VERTEX], alone[Mesh.ARRAY_VERTEX])
		assert_eq(shared[Mesh.ARRAY_INDEX], alone[Mesh.ARRAY_INDEX])


func test_spectators_near_measures_on_the_ground_plane() -> void:
	var positions: Array[Vector3] = [Vector3(4.5, 0, 0), Vector3(5.2, 0, 0.3), Vector3(8.0, 0, 0), Vector3(4.5, 0, 3.0)]
	assert_eq(Crowd.spectators_near(positions, Vector3(4.6, 1.5, 0.1), 0.9), [0, 1] as Array[int], "height ignored")
	assert_eq(Crowd.spectators_near(positions, Vector3(0, 0.2, 0), 0.9), [] as Array[int], "over the court")


func _crowd() -> Crowd:
	var crowd := Crowd.new()
	add_child_autofree(crowd)
	return crowd


func test_boo_makes_those_nearby_duck_and_the_rest_boo() -> void:
	var crowd := _crowd()
	var target: Vector3 = crowd._spectators[0].base.origin
	crowd.cheer(1.0, 5.0)
	watch_signals(crowd)
	crowd.boo(target)
	assert_signal_emitted_with_parameters(crowd, "booed", [target])
	var near := Crowd.spectators_near(crowd._positions(), target, Crowd.DUCK_RADIUS)
	assert_true(0 in near)
	for i in range(crowd._spectators.size()):
		var s: Dictionary = crowd._spectators[i]
		assert_lt(s.cheer_until, crowd._time, "cheering stops")
		if i in near:
			assert_gt(s.duck_until, crowd._time, "ducks")
		assert_gt(s.boo_until, s.boo_from, "boos")
	# Rendered pose: the one it came at is ducking right away.
	crowd._process(0.01)
	assert_eq(crowd._spectators[0].node.mesh, crowd._spectators[0].duck)


func test_only_one_boo_per_throw() -> void:
	var crowd := _crowd()
	watch_signals(crowd)
	crowd.boo(crowd._spectators[0].base.origin)
	crowd.boo(crowd._spectators[3].base.origin)
	assert_signal_emit_count(crowd, "booed", 1)

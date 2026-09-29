extends GutTest


func test_snapshot_round_trips_positions_and_rotations() -> void:
	var bodies: Array[RigidBody3D] = []
	for i in range(3):
		var body: RigidBody3D = add_child_autofree(RigidBody3D.new())
		body.freeze = true
		body.global_transform = Transform3D(Basis(Vector3(1, 2, 0.5).normalized(), 0.7 * i), Vector3(i, 0.05 * i, -3.0 * i))
		bodies.append(body)

	var data := OnlineLink.pack_snapshot(bodies)
	assert_eq(data.size(), 3 * 7)
	var transforms := OnlineLink.unpack_snapshot(data)
	assert_eq(transforms.size(), 3)
	for i in range(3):
		assert_almost_eq(transforms[i].origin, bodies[i].global_position, Vector3.ONE * 1e-5)
		assert_true(transforms[i].basis.is_equal_approx(bodies[i].global_transform.basis), "rotation %d" % i)


func test_empty_snapshot_unpacks_to_nothing() -> void:
	assert_eq(OnlineLink.unpack_snapshot(PackedFloat32Array()).size(), 0)

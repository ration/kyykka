extends GutTest


func _look() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return SpectatorMesh.random_look(rng, Color.RED, false)


func test_falls_over_and_comes_to_rest_on_its_own_floor() -> void:
	# Far from any other ground: only the ragdoll's own floor holds it up.
	var at := Transform3D(Basis.IDENTITY, Vector3(40, 0, 40))
	var ragdoll := Ragdoll.create(_look(), at, Vector3(-200, 30, 0), at.origin + Vector3(0, 1.1, 0))
	add_child_autofree(ragdoll)
	for i in range(150):
		await get_tree().physics_frame
	var pelvis: RigidBody3D = ragdoll.bodies.pelvis
	var head: RigidBody3D = ragdoll.bodies.head
	assert_lt(head.global_position.y, 0.5, "lying down")
	assert_gt(head.global_position.y, 0.0, "on the floor, not through it")
	assert_lt(pelvis.global_position.distance_to(at.origin), 6.0, "knocked a few metres, not flung")
	assert_gt(pelvis.global_position.x, -999.0)


func test_only_collides_with_static_ground_and_its_own_layer() -> void:
	var ragdoll := Ragdoll.create(_look(), Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)
	add_child_autofree(ragdoll)
	for body: RigidBody3D in ragdoll.bodies.values():
		assert_eq(body.collision_layer, Ragdoll.LAYER)
		assert_eq(body.collision_mask & ~(1 | Ragdoll.LAYER), 0)
	# The kyykkä and karttu only look at layer 1, so they never see a ragdoll.
	var kyykka: RigidBody3D = autofree(preload("res://scenes/kyykka.tscn").instantiate())
	var karttu: RigidBody3D = autofree(preload("res://scenes/karttu.tscn").instantiate())
	assert_eq(kyykka.collision_mask & Ragdoll.LAYER, 0)
	assert_eq(karttu.collision_mask & Ragdoll.LAYER, 0)


func test_finishes_after_lying_there_and_frees_itself() -> void:
	var ragdoll := Ragdoll.create(_look(), Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)
	add_child(ragdoll)
	# Recorded by callback: the ragdoll frees itself right after emitting,
	# so a signal watcher reading it afterwards would touch a freed object.
	var finished := [false]
	ragdoll.finished.connect(func() -> void: finished[0] = true)
	ragdoll._age = Ragdoll.LIE_SECONDS
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(finished[0])
	assert_false(is_instance_valid(ragdoll), "freed")

extends GutTest

var thrower: ThrowController


func before_each() -> void:
	var parent: Node3D = add_child_autofree(Node3D.new())
	var camera := Camera3D.new()
	parent.add_child(camera)
	thrower = ThrowController.new()
	thrower.karttu_scene = preload("res://scenes/karttu.tscn")
	thrower.camera = camera
	thrower.line_half_width = 2.5
	parent.add_child(thrower)
	thrower.configure(Vector3(0, 0, -5), Vector3(0, 0, 1), null)


func test_steps_along_the_line_only() -> void:
	thrower.set_line_offset(1.2)
	# Facing +Z, the thrower's right is -X.
	assert_almost_eq(thrower.global_position, Vector3(-1.2, 0, -5), Vector3.ONE * 0.001)


func test_cannot_step_off_the_ends_of_the_line() -> void:
	thrower.set_line_offset(10.0)
	assert_almost_eq(thrower.line_offset(), 2.5, 0.001)
	thrower.set_line_offset(-10.0)
	assert_almost_eq(thrower.global_position.x, 2.5, 0.001)
	assert_almost_eq(thrower.global_position.z, -5.0, 0.001, "never over the line")


func test_karttu_in_hand_comes_along() -> void:
	thrower.set_line_offset(-1.0)
	assert_almost_eq(thrower._karttu.global_position.x, thrower.global_position.x, 0.001)


func test_each_turn_starts_in_the_middle() -> void:
	thrower.set_line_offset(2.0)
	thrower.configure(Vector3(0, 0, 5), Vector3(0, 0, -1), null)
	assert_eq(thrower.line_offset(), 0.0)
	assert_almost_eq(thrower.global_position, Vector3(0, 0, 5), Vector3.ONE * 0.001)


func test_right_drag_steps_and_does_not_aim() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	thrower._unhandled_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(100, 40)
	thrower._unhandled_input(drag)
	assert_almost_eq(thrower.line_offset(), 100 * thrower.step_sensitivity, 0.001)
	assert_eq(thrower._yaw_degrees, 0.0)
	assert_eq(thrower._elevation_degrees, thrower.launch_elevation_degrees)

	press.pressed = false
	thrower._unhandled_input(press)
	thrower._unhandled_input(drag)
	assert_almost_eq(thrower.line_offset(), 100 * thrower.step_sensitivity, 0.001, "released: aims again")
	assert_ne(thrower._yaw_degrees, 0.0)


func test_no_stepping_mid_swing() -> void:
	thrower._swinging = true
	thrower.set_line_offset(1.0)
	assert_eq(thrower.line_offset(), 0.0)

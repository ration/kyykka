extends GutTest

var thrower: ThrowController
var touch: TouchControls


func before_each() -> void:
	var parent: Node3D = add_child_autofree(Node3D.new())
	var camera := Camera3D.new()
	parent.add_child(camera)
	thrower = ThrowController.new()
	thrower.karttu_scene = preload("res://scenes/karttu.tscn")
	thrower.camera = camera
	thrower.line_half_width = 2.5
	parent.add_child(thrower)
	thrower.configure(Vector3(0, 0, -5), Vector3(0, 0, 1), parent)
	touch = TouchControls.new()
	touch.thrower = thrower
	parent.add_child(touch)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	touch._input(event)


func _drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	touch._input(event)


func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_dragging_on_the_screen_aims() -> void:
	var start := Vector2(400, 200)
	_touch(0, start, true)
	_drag(0, start + Vector2(50, 30), Vector2(50, 30))
	assert_lt(thrower._yaw_degrees, 0.0, "dragging right turns right")
	assert_lt(thrower._elevation_degrees, thrower.launch_elevation_degrees, "dragging down looks down")


func test_holding_throw_swings_and_releasing_throws() -> void:
	var at := _centre(touch._throw_button)
	_touch(1, at, true)
	assert_true(thrower._swinging)
	thrower._gauge_degrees = 90.0
	_touch(1, at, false)
	assert_false(thrower._swinging)
	assert_true(thrower.is_throwing())


func test_aiming_with_one_finger_while_holding_throw_with_another() -> void:
	_touch(1, _centre(touch._throw_button), true)
	_touch(0, Vector2(300, 200), true)
	_drag(0, Vector2(340, 200), Vector2(40, 0))
	assert_true(thrower._swinging, "the swing carries on")
	assert_ne(thrower._yaw_degrees, 0.0)


func test_dragging_the_step_pad_steps_along_the_line() -> void:
	var at := _centre(touch._step_pad)
	_touch(0, at, true)
	_drag(0, at + Vector2(100, 40), Vector2(100, 40))
	assert_gt(thrower.line_offset(), 0.0)
	assert_eq(thrower._yaw_degrees, 0.0, "stepping doesn't aim")


func test_pinching_zooms_in() -> void:
	_touch(0, Vector2(300, 300), true)
	_touch(1, Vector2(400, 300), true)
	_drag(1, Vector2(420, 300), Vector2(20, 0))
	_drag(1, Vector2(500, 300), Vector2(80, 0))
	assert_lt(thrower._fov_degrees, thrower.default_fov_degrees)


func test_pause_button_signals() -> void:
	watch_signals(touch)
	_touch(0, _centre(touch._pause_button), true)
	assert_signal_emitted(touch, "pause_pressed")


func test_no_input_while_suspended() -> void:
	thrower.suspended = true
	_touch(1, _centre(touch._throw_button), true)
	assert_false(thrower._swinging)

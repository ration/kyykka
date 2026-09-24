class_name ThrowController
extends Node3D
## Player-controlled aiming/throwing rig. Pure input/physics — knows
## nothing about the rules engine or whose turn it is. Reuses a single
## karttu instance per throw and reports completion via throw_settled;
## whoever owns this node (MatchController) is responsible for scoring
## the result and repositioning it (via configure()) for the next turn.
##
## Aiming is "point at where you want it to land": the camera's look ray
## is cast onto the ground at kyykkä height, and the launch angle is
## solved (see Ballistics) so the fixed-speed karttu arcs to that point.
## Throwing straight along the look direction instead made the natural
## move — pointing the camera at the kyykkä — throw the karttu downward
## into the ground less than a metre out.
##
## Throw speed is fixed for now (power is a later feature); the skill
## mechanic is the swing timing: holding the button sweeps a 0-180 degree
## gauge, and release timing sets spin (see SpinCalculator). Releasing at
## the middle (90) spins the karttu exactly half a rotation by the time
## it lands, so it hits flush (parallel to the stack again — see
## SpinCalculator); releasing early/late under/over-rotates it. Running
## the gauge past 180 without releasing cancels the swing.

signal throw_settled

@export var karttu_scene: PackedScene
@export var camera: Camera3D
@export var enabled: bool = true  ## set false to stop accepting input once the match is over

@export var aim_cone_degrees: float = 25.0  ## how far left/right of forward you can aim
@export var mouse_sensitivity: float = 0.2  ## degrees per pixel of mouse motion

@export var swing_seconds: float = 1.0  ## time for the gauge to sweep 0 -> 180
@export var throw_speed: float = 16.0  ## fixed for now; variable power is a later feature
@export var launch_elevation_degrees: float = -7.5  ## camera pitch reset each turn; looks at the target pesä's kyykkä row from the default camera spot
@export var min_elevation_degrees: float = -20.0  ## steepest downward look, i.e. the shortest throw (~3 m out)
@export var max_elevation_degrees: float = 0.0  ## looking at or above the horizon aims at max_throw_distance
@export var aim_target_height: float = 0.1  ## height the look ray is cast onto: mid-height of a stacked kyykkä pair
@export var min_throw_distance: float = 2.0
@export var max_throw_distance: float = 16.0  ## a little past the far pesä's back line

@export var camera_height: float = 1.6
@export var camera_back_offset: float = 1.2
@export var default_fov_degrees: float = 70.0  ## neutral zoom, reset each turn
@export var min_fov_degrees: float = 15.0  ## most zoomed in (scroll up)
@export var max_fov_degrees: float = 70.0  ## least zoomed in / default (scroll down)
@export var zoom_step_degrees: float = 4.0  ## FOV change per scroll notch
@export var settle_timeout_seconds: float = 5.0
@export var karttu_rest_height: float = 0.03  ## roughly its radius, so it rests on the ground rather than clipping into it
@export var miss_indicator_seconds: float = 0.8

var watch_root: Node3D  ## subtree whose RigidBody3Ds must settle (the current target PesaView); set via configure()

var _yaw_degrees: float = 0.0
var _elevation_degrees: float = 0.0  ## current camera pitch; reset to launch_elevation_degrees in configure()
var _fov_degrees: float = 70.0  ## current zoom level; reset to default_fov_degrees in configure()
var _forward_direction: Vector3 = Vector3(0, 0, 1)  ## yaw=0 aim direction; set via configure()
var _karttu: Karttu
var _busy: bool = false

var _swinging: bool = false
var _gauge_degrees: float = 0.0
var _awaiting_release: bool = false  ## true after a cancel, until the button is actually let go

var _gauge_layer: CanvasLayer
var _gauge_bar: ColorRect
var _gauge_marker: ColorRect
var _miss_label: Label
var _miss_timer: float = 0.0

const GAUGE_WIDTH := 200.0
const GAUGE_HEIGHT := 16.0


func _ready() -> void:
	assert(karttu_scene != null and camera != null)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_karttu = karttu_scene.instantiate()
	get_parent().add_child(_karttu)
	_build_gauge_ui()


## Positions this thrower for a turn: where it stands, which way is
## "straight ahead" (yaw=0), and which PesaView's kyykkä to watch for
## settling. Called once right after this node enters the tree for the
## first turn, and again whenever the active side changes.
func configure(p_position: Vector3, p_forward: Vector3, p_watch_root: Node3D) -> void:
	position = p_position
	_forward_direction = p_forward.normalized()
	watch_root = p_watch_root
	_yaw_degrees = 0.0
	_elevation_degrees = launch_elevation_degrees
	_fov_degrees = default_fov_degrees
	camera.fov = _fov_degrees
	_reset_karttu()
	_update_camera()


func _reset_karttu() -> void:
	_karttu.stop_spin_lock()
	_karttu.freeze = true
	_karttu.linear_velocity = Vector3.ZERO
	_karttu.angular_velocity = Vector3.ZERO
	_karttu.global_position = global_position + Vector3.UP * karttu_rest_height
	_karttu.global_rotation = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventMouseMotion and not _busy:
		_yaw_degrees = clampf(
			_yaw_degrees - event.relative.x * mouse_sensitivity,
			-aim_cone_degrees,
			aim_cone_degrees
		)
		# relative.y is positive moving down the screen, so subtracting it
		# means moving the mouse up raises the aim, same convention as a
		# typical mouse-look.
		_elevation_degrees = clampf(
			_elevation_degrees - event.relative.y * mouse_sensitivity,
			min_elevation_degrees,
			max_elevation_degrees
		)
		_update_camera()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _busy and not _awaiting_release:
				_swinging = true
				_gauge_degrees = 0.0
		else:
			_awaiting_release = false
			if _swinging:
				_swinging = false
				var gauge := _gauge_degrees
				_gauge_bar.hide()
				_throw(gauge)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var step := -zoom_step_degrees if event.button_index == MOUSE_BUTTON_WHEEL_UP else zoom_step_degrees
		_fov_degrees = clampf(_fov_degrees + step, min_fov_degrees, max_fov_degrees)
		camera.fov = _fov_degrees


func _process(delta: float) -> void:
	if _swinging:
		_gauge_degrees += (180.0 / swing_seconds) * delta
		if _gauge_degrees >= 180.0:
			_gauge_degrees = 180.0
			_swinging = false
			_awaiting_release = true
			_gauge_bar.hide()
			_show_miss_indicator()
		else:
			_update_gauge_marker()

	if _miss_timer > 0.0:
		_miss_timer -= delta
		if _miss_timer <= 0.0:
			_miss_label.hide()


## Horizontal-only facing (yaw applied to _forward_direction). Used as the
## camera's stand-off direction and as the base for _look_direction().
func _aim_direction() -> Vector3:
	return _forward_direction.rotated(Vector3.UP, deg_to_rad(_yaw_degrees))


## Full 3D camera look direction (yaw + pitch). Not the throw direction —
## see _aim_distance().
func _look_direction() -> Vector3:
	var horizontal := _aim_direction()
	var elevation := deg_to_rad(_elevation_degrees)
	return (horizontal * cos(elevation) + Vector3.UP * sin(elevation)).normalized()


func _camera_position() -> Vector3:
	return global_position + Vector3.UP * camera_height - _aim_direction() * camera_back_offset


func _update_camera() -> void:
	camera.global_position = _camera_position()
	camera.look_at(camera.global_position + _look_direction(), Vector3.UP)


## Horizontal distance from the thrower to where the camera's look ray
## crosses aim_target_height — what the player is pointing at.
func _aim_distance() -> float:
	var origin := _camera_position()
	var look := _look_direction()
	if look.y >= -0.001:
		return max_throw_distance
	var hit := origin + look * ((aim_target_height - origin.y) / look.y)
	var ahead := (hit - global_position).dot(_aim_direction())
	return clampf(ahead, min_throw_distance, max_throw_distance)


func _throw(gauge_degrees: float) -> void:
	_busy = true
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var distance := _aim_distance()
	var elevation := Ballistics.launch_elevation(
		throw_speed, distance, aim_target_height - karttu_rest_height, gravity
	)
	var rad := deg_to_rad(elevation)
	var launch_dir := _aim_direction() * cos(rad) + Vector3.UP * sin(rad)
	var flight := Ballistics.flight_time(throw_speed, distance, elevation)
	var rate := SpinCalculator.spin_rate(gauge_degrees, flight)

	_karttu.freeze = false
	_karttu.sleeping = false
	_karttu.linear_velocity = launch_dir * throw_speed
	# Spin about the vertical axis — a level, flat spin (like a twirled
	# baton or a thrown frisbee), not a horizontal-axis tumble that would
	# pitch it up onto its end. The karttu's length starts broadside
	# (perpendicular to travel, sweeping across a row of kyykkä); yawing
	# it 180 degrees returns it to that same broadside alignment (it's
	# symmetric end-to-end), while 90/270 degrees points it lengthwise
	# down the throw direction instead — narrow, hits far fewer kyykkä.
	# Driven by the karttu itself via _integrate_forces, not set once.
	_karttu.start_spin_lock(Vector3.UP, rate)

	await _await_settle()
	_reset_karttu()
	_busy = false
	throw_settled.emit()


func _await_settle() -> void:
	var bodies := _rigid_bodies_under(watch_root)
	bodies.append(_karttu)

	var elapsed := 0.0
	var step := get_physics_process_delta_time()
	while elapsed < settle_timeout_seconds:
		await get_tree().physics_frame
		elapsed += step
		if bodies.all(func(b: RigidBody3D) -> bool: return b.sleeping):
			return


func _rigid_bodies_under(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is RigidBody3D:
			result.append(child)
		result.append_array(_rigid_bodies_under(child))
	return result


## Bare-bones swing gauge, just enough to play by — Phase 5 owns the real
## HUD. Plain shapes built in code, matching how court.gd builds geometry.
func _build_gauge_ui() -> void:
	_gauge_layer = CanvasLayer.new()
	add_child(_gauge_layer)

	# The mouse is captured, so without this there's nothing on screen
	# showing what the look ray (and so the throw) is aimed at.
	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.size = Vector2(4, 4)
	crosshair.position = Vector2(-2, -2)
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_layer.add_child(crosshair)

	_gauge_bar = ColorRect.new()
	_gauge_bar.color = Color(0.15, 0.15, 0.15, 0.85)
	_gauge_bar.size = Vector2(GAUGE_WIDTH, GAUGE_HEIGHT)
	_gauge_bar.position = Vector2(-GAUGE_WIDTH / 2.0, -60)
	_gauge_bar.anchor_left = 0.5
	_gauge_bar.anchor_right = 0.5
	_gauge_bar.anchor_top = 1.0
	_gauge_bar.anchor_bottom = 1.0
	_gauge_bar.hide()
	_gauge_layer.add_child(_gauge_bar)

	var middle_tick := ColorRect.new()
	middle_tick.color = Color(0.1, 0.8, 0.1, 1.0)
	middle_tick.size = Vector2(2, GAUGE_HEIGHT)
	middle_tick.position = Vector2(GAUGE_WIDTH / 2.0 - 1, 0)
	_gauge_bar.add_child(middle_tick)

	_gauge_marker = ColorRect.new()
	_gauge_marker.color = Color(0.9, 0.1, 0.1, 1.0)
	_gauge_marker.size = Vector2(3, GAUGE_HEIGHT)
	_gauge_bar.add_child(_gauge_marker)

	_miss_label = Label.new()
	_miss_label.text = "MISSED SWING"
	_miss_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_miss_label.position = Vector2(-60, -90)
	_miss_label.anchor_left = 0.5
	_miss_label.anchor_right = 0.5
	_miss_label.anchor_top = 1.0
	_miss_label.anchor_bottom = 1.0
	_miss_label.hide()
	_gauge_layer.add_child(_miss_label)


func _update_gauge_marker() -> void:
	if not _gauge_bar.visible:
		_gauge_bar.show()
	var t := _gauge_degrees / 180.0
	_gauge_marker.position.x = t * GAUGE_WIDTH - _gauge_marker.size.x / 2.0


func _show_miss_indicator() -> void:
	_miss_label.show()
	_miss_timer = miss_indicator_seconds

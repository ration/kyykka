class_name ThrowController
extends Node3D
## Player-controlled aiming/throwing rig. Pure input/physics — knows
## nothing about the rules engine. Reuses a single karttu instance per
## throw and reports completion via throw_settled; whoever owns this node
## (court.gd) is responsible for scoring the result.
##
## Throw distance is fixed for now (power is a later feature); the skill
## mechanic is the swing timing: holding the button sweeps a 0-180 degree
## gauge, and release timing sets spin (see SpinCalculator). Releasing at
## the middle (90) spins the karttu exactly one full rotation by the time
## it lands, so it hits flush; releasing early/late under/over-rotates
## it. Running the gauge past 180 without releasing cancels the swing.

signal throw_settled

@export var karttu_scene: PackedScene
@export var watch_root: Node3D  ## subtree whose RigidBody3Ds must settle (the target PesaView)
@export var camera: Camera3D

@export var aim_cone_degrees: float = 25.0
@export var mouse_sensitivity: float = 0.2  ## degrees per pixel of mouse motion

@export var swing_seconds: float = 1.0  ## time for the gauge to sweep 0 -> 180
@export var throw_speed: float = 17.0  ## fixed for now; variable power is a later feature
@export var launch_elevation_degrees: float = 15.0

@export var camera_height: float = 1.6
@export var camera_back_offset: float = 1.2
@export var settle_timeout_seconds: float = 5.0
@export var karttu_rest_height: float = 0.03  ## roughly its radius, so it rests on the ground rather than clipping into it
@export var miss_indicator_seconds: float = 0.8

var _yaw_degrees: float = 0.0
var _karttu: RigidBody3D
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
	assert(karttu_scene != null and watch_root != null and camera != null)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_karttu = karttu_scene.instantiate()
	get_parent().add_child(_karttu)
	_reset_karttu()
	_update_camera()
	_build_gauge_ui()


func _reset_karttu() -> void:
	_karttu.freeze = true
	_karttu.linear_velocity = Vector3.ZERO
	_karttu.angular_velocity = Vector3.ZERO
	_karttu.global_position = global_position + Vector3.UP * karttu_rest_height
	_karttu.global_rotation = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _busy:
		_yaw_degrees = clampf(
			_yaw_degrees - event.relative.x * mouse_sensitivity,
			-aim_cone_degrees,
			aim_cone_degrees
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


func _aim_direction() -> Vector3:
	var yaw := deg_to_rad(_yaw_degrees)
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


func _update_camera() -> void:
	var dir := _aim_direction()
	camera.global_position = global_position + Vector3.UP * camera_height - dir * camera_back_offset
	camera.look_at(camera.global_position + dir, Vector3.UP)


func _throw(gauge_degrees: float) -> void:
	_busy = true
	var dir := _aim_direction()
	var elevation := deg_to_rad(launch_elevation_degrees)
	var launch_dir := (dir * cos(elevation) + Vector3.UP * sin(elevation)).normalized()

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var flight := SpinCalculator.time_of_flight(throw_speed, launch_elevation_degrees, gravity)
	var rate := SpinCalculator.spin_rate(gauge_degrees, flight)

	_karttu.freeze = false
	_karttu.linear_velocity = launch_dir * throw_speed
	# Spin about the flight direction itself (a barrel roll along the
	# path), not dir.cross(UP): the karttu's length already lies along
	# the aim direction's perpendicular at rest, so spinning about the
	# travel axis is what actually alternates it between lying flat and
	# standing on end as it flies — see plan/commit notes.
	_karttu.angular_velocity = launch_dir * rate

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

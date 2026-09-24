class_name ThrowController
extends Node3D
## Player-controlled aiming/throwing rig. Pure input/physics — knows
## nothing about the rules engine. Reuses a single karttu instance per
## throw and reports completion via throw_settled; whoever owns this node
## (court.gd) is responsible for scoring the result.

signal throw_settled

@export var karttu_scene: PackedScene
@export var watch_root: Node3D  ## subtree whose RigidBody3Ds must settle (the target PesaView)
@export var camera: Camera3D

@export var aim_cone_degrees: float = 25.0
@export var mouse_sensitivity: float = 0.2  ## degrees per pixel of mouse motion

@export var charge_seconds: float = 1.5
@export var min_throw_speed: float = 8.0
@export var max_throw_speed: float = 17.0
@export var launch_elevation_degrees: float = 15.0
@export var spin_speed: float = 10.0  ## radians/sec, purely visual tumble

@export var camera_height: float = 1.6
@export var camera_back_offset: float = 1.2
@export var settle_timeout_seconds: float = 5.0
@export var karttu_rest_height: float = 0.03  ## roughly its radius, so it rests on the ground rather than clipping into it

var _yaw_degrees: float = 0.0
var _charging: bool = false
var _power: float = 0.0
var _karttu: RigidBody3D
var _busy: bool = false


func _ready() -> void:
	assert(karttu_scene != null and watch_root != null and camera != null)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_karttu = karttu_scene.instantiate()
	get_parent().add_child(_karttu)
	_reset_karttu()
	_update_camera()


func _reset_karttu() -> void:
	_karttu.freeze = true
	_karttu.linear_velocity = Vector3.ZERO
	_karttu.angular_velocity = Vector3.ZERO
	_karttu.global_position = global_position + Vector3.UP * karttu_rest_height
	_karttu.global_rotation = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return

	if event is InputEventMouseMotion:
		_yaw_degrees = clampf(
			_yaw_degrees - event.relative.x * mouse_sensitivity,
			-aim_cone_degrees,
			aim_cone_degrees
		)
		_update_camera()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_charging = true
			_power = 0.0
		else:
			_charging = false
			_throw()


func _process(delta: float) -> void:
	if _charging:
		_power = clampf(_power + delta / charge_seconds, 0.0, 1.0)


func _aim_direction() -> Vector3:
	var yaw := deg_to_rad(_yaw_degrees)
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


func _update_camera() -> void:
	var dir := _aim_direction()
	camera.global_position = global_position + Vector3.UP * camera_height - dir * camera_back_offset
	camera.look_at(camera.global_position + dir, Vector3.UP)


func _throw() -> void:
	_busy = true
	var dir := _aim_direction()
	var elevation := deg_to_rad(launch_elevation_degrees)
	var launch_dir := (dir * cos(elevation) + Vector3.UP * sin(elevation)).normalized()
	var speed := lerpf(min_throw_speed, max_throw_speed, _power)

	_karttu.freeze = false
	_karttu.linear_velocity = launch_dir * speed
	_karttu.angular_velocity = dir.cross(Vector3.UP) * spin_speed

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

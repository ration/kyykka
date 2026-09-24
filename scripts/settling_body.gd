class_name SettlingBody
extends RigidBody3D
## Shared safety net for equipment props (kyykkä, karttu): Godot's own
## sleep detection has repeatedly proven unreliable for these at rest —
## diagnosed directly for kyykkä (a corner-balanced piece can spin in
## place indefinitely without ever setting sleeping = true) and the
## karttu shows the identical pattern (stuck at a tiny residual velocity
## forever, only ever "settling" because ThrowController forcibly resets
## it after the full settle_timeout_seconds — meaning every single throw
## was silently taking the full timeout instead of the ~1s a real
## settle takes, diagnosed via tools/simulate_throws.gd). If a body
## isn't asleep but also hasn't moved more than STUCK_POSITION_THRESHOLD
## in STUCK_TIMEOUT_SECONDS, force it to settle.

const STUCK_TIMEOUT_SECONDS := 2.0
const STUCK_POSITION_THRESHOLD := 0.02  ## metres

var _stuck_timer: float = 0.0
var _last_position: Vector3


func _ready() -> void:
	_last_position = global_position


func _physics_process(delta: float) -> void:
	if sleeping:
		_stuck_timer = 0.0
		_last_position = global_position
		return

	if global_position.distance_to(_last_position) < STUCK_POSITION_THRESHOLD:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIMEOUT_SECONDS:
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			sleeping = true
	else:
		_stuck_timer = 0.0
		_last_position = global_position

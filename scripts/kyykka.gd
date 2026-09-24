class_name Kyykka
extends RigidBody3D
## Safety net for a rare physics edge case: after an extended play
## session, a struck piece can occasionally end up balanced on a
## BoxShape3D corner/edge and spin in place indefinitely — diagnosed
## directly: reported velocity (linear + angular magnitude) stayed
## around 3-3.5 for 10+ seconds straight while its position barely
## changed at all, i.e. spinning on the spot rather than tumbling
## anywhere, with damping alone (linear_damp/angular_damp on
## kyykka.tscn) never fully arresting it. Rather than chasing this exact
## unstable-equilibrium case through more material tuning, this just
## detects "clearly not going anywhere, but also not asleep" and forces
## it to settle.

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

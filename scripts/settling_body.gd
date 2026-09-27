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
##
## A body knocked or slid past the edge of the ground collision falls
## forever and never sleeps, which used to stall every such throw for the
## full settle_timeout_seconds (diagnosed via tools/simulate_throws.gd: a
## winter karttu sliding off the end of the court on every throw, and
## struck kyykkä occasionally pushed off it in summer too). Once a body
## drops below FELL_OFF_HEIGHT it's frozen in place instead.

const STUCK_TIMEOUT_SECONDS := 2.0
const STUCK_POSITION_THRESHOLD := 0.02  ## metres
const FELL_OFF_HEIGHT := -1.0  ## metres; the ground's top surface is y = 0

var _stuck_timer: float = 0.0
var _last_position: Vector3
var _still_timer: float = 0.0
var _still_anchor: Vector3


func _ready() -> void:
	_last_position = global_position
	_still_anchor = global_position


## Whether ThrowController can treat this body as done moving. Not just
## `sleeping`: a stuck body the watchdog forced to sleep can be woken again
## straight away by contact with another one (two struck kyykkä leaning on
## each other, one rocking a few millimetres on a corner, kept each other
## awake and stalled throws until settle_timeout_seconds), and a frozen
## body needn't report sleeping at all.
##
## That needs its own timer rather than _stuck_timer: the forced sleep holds
## for a frame, which resets _stuck_timer, so the pair cycled through
## "stuck" for a single frame every 2s. _still_timer is only reset by real
## movement, never by sleeping, so it can't drive the watchdog itself: it
## would still be high on a resting piece's first frame of a genuine hit
## and cancel the impact.
func is_settled() -> bool:
	return sleeping or freeze or _still_timer > STUCK_TIMEOUT_SECONDS


func _physics_process(delta: float) -> void:
	if freeze:
		_stuck_timer = 0.0
		_last_position = global_position
		_still_timer = 0.0
		_still_anchor = global_position
		return

	if global_position.distance_to(_still_anchor) < STUCK_POSITION_THRESHOLD:
		_still_timer += delta
	else:
		_still_timer = 0.0
		_still_anchor = global_position

	if global_position.y < FELL_OFF_HEIGHT:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
		return

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

class_name Karttu
extends SettlingBody
## Extends SettlingBody for the shared "force-settle if stuck" watchdog
## (the karttu turned out to need this just as much as kyykkä do —
## diagnosed via tools/simulate_throws.gd: every single throw was
## silently taking the full settle_timeout_seconds because the karttu
## never naturally reached sleeping on its own, only ever "settling"
## because ThrowController resets it after that timeout).
##
## Also drives its own spin during flight via _integrate_forces (called by
## the physics engine as part of its own step, before the step
## finalizes) rather than an external post-step transform poke from
## ThrowController. The previous approach overwrote global_transform
## from Node._physics_process every frame, which runs *after* that
## step's physics (including its continuous-collision-detection sweep)
## has already completed — diagnosed after reports of "sometimes
## hitting perfectly it just passes through": externally rewriting the
## transform each frame was desyncing the physics server's own per-step
## motion tracking, silently defeating continuous_cd on some frames even
## though it tested fine in isolation (bypassing this spin lock
## entirely). Setting state inside _integrate_forces instead keeps the
## motion the engine's CCD sweep sees continuous.
##
## ThrowController calls start_spin_lock() at launch and stop_spin_lock()
## on reset; the lock releases itself on first genuine contact (contacts
## are ignored for a short grace period after launch, since
## get_contact_count() can briefly still report the pre-launch
## resting-on-ground contact right after unfreezing).
##
## linear_damp/angular_damp are switched between two very different
## values depending on flight phase, not left at one constant — high
## damping is needed to make a landed karttu actually stop (see
## SettlingBody), but that same damping applied throughout the flight
## itself acts like heavy air resistance, diagnosed directly with
## tools/simulate_throws.gd: at landed_linear_damp (3.0) the whole flight,
## horizontal speed decayed from ~17 m/s to ~3.7 m/s within 0.5s,
## covering only ~5m instead of the ~10m needed to reach the pesä.
## flight_linear_damp/flight_angular_damp (near zero) apply while
## _locking_spin is true; the moment the lock releases on contact, damping
## switches to the landed_* values so it still settles quickly afterward.

const LOCK_GRACE_SECONDS := 0.15

@export var flight_linear_damp: float = 0.0
@export var flight_angular_damp: float = 0.0
@export var landed_linear_damp: float = 3.0
@export var landed_angular_damp: float = 3.0

var _locking_spin: bool = false
var _lock_axis: Vector3 = Vector3.ZERO
var _lock_rate: float = 0.0
var _lock_elapsed: float = 0.0
var _lock_start_basis: Basis = Basis.IDENTITY


func _ready() -> void:
	super._ready()
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = landed_linear_damp
	angular_damp = landed_angular_damp


func start_spin_lock(axis: Vector3, rate: float) -> void:
	_lock_axis = axis
	_lock_rate = rate
	_lock_elapsed = 0.0
	_lock_start_basis = global_transform.basis
	_locking_spin = true
	linear_damp = flight_linear_damp
	angular_damp = flight_angular_damp


func stop_spin_lock() -> void:
	_locking_spin = false
	linear_damp = landed_linear_damp
	angular_damp = landed_angular_damp


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _locking_spin:
		return

	_lock_elapsed += state.step

	if _lock_elapsed > LOCK_GRACE_SECONDS and get_contact_count() > 0:
		stop_spin_lock()
		# The angular velocity up to this point was a kinematic override
		# (the locked spin), not real accumulated momentum, so handing it
		# to the solver as-is at the exact moment of first contact made
		# landings tumble/cartwheel chaotically instead of settling —
		# diagnosed directly by tracing rotation frame-by-frame through a
		# landing, which showed it swinging through multiple full
		# rotations in the few frames right after touchdown. Let the real
		# contact impulse determine any post-landing rotation instead.
		state.angular_velocity = Vector3.ZERO
		return

	state.angular_velocity = _lock_axis * _lock_rate
	var t := state.transform
	t.basis = _lock_start_basis.rotated(_lock_axis, _lock_rate * _lock_elapsed)
	state.transform = t

class_name Karttu
extends RigidBody3D
## Drives its own spin during flight via _integrate_forces (called by
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

const LOCK_GRACE_SECONDS := 0.15

var _locking_spin: bool = false
var _lock_axis: Vector3 = Vector3.ZERO
var _lock_rate: float = 0.0
var _lock_elapsed: float = 0.0
var _lock_start_basis: Basis = Basis.IDENTITY


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4


func start_spin_lock(axis: Vector3, rate: float) -> void:
	_lock_axis = axis
	_lock_rate = rate
	_lock_elapsed = 0.0
	_lock_start_basis = global_transform.basis
	_locking_spin = true


func stop_spin_lock() -> void:
	_locking_spin = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _locking_spin:
		return

	_lock_elapsed += state.step

	if _lock_elapsed > LOCK_GRACE_SECONDS and get_contact_count() > 0:
		_locking_spin = false
		return

	state.angular_velocity = _lock_axis * _lock_rate
	var t := state.transform
	t.basis = _lock_start_basis.rotated(_lock_axis, _lock_rate * _lock_elapsed)
	state.transform = t

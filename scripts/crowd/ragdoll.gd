class_name Ragdoll
extends Node3D
## A spectator the karttu hit, falling over: eleven capsule RigidBody3Ds
## (pelvis, chest, head, upper/lower arms, thighs, shins) joined by
## ConeTwistJoint3Ds, laid out like SpectatorMesh's proportions and
## coloured like that person (overalls, shirt, skin, hair), thrown along
## the karttu's velocity. Crowd hides the person's mesh while this is up
## and shows it again — standing — once it's done lying there.
##
## On its own collision layer (LAYER), colliding with layer 1's static
## ground and its own floor (a big plane on LAYER, since court.gd's ground
## collision ends 5 m past the side lines and the crowd stands up to ~7 m
## out): the kyykkä and the karttu don't see either at all, so a falling
## spectator can't change a throw's outcome, delay settling (it isn't a
## SettlingBody, and ThrowController only watches the target pesä and the
## karttu) or desync an online match.

signal finished

const LAYER := 1 << 1           ## physics layer 2: ragdolls only
const LIE_SECONDS := 3.5        ## how long they lie there before getting up
const MASS := 70.0              ## kg, shared out over the parts below
const TOPPLE := 0.35             ## extra forward speed per metre of height, so the top goes over first

## name -> [from, to (both in the person's own frame, feet at the origin,
## facing +Z), radius, share of MASS, colour key]
const PARTS := {
	"pelvis": [Vector3(0, 0.86, 0), Vector3(0, 1.02, 0), 0.15, 0.16, "overall"],
	"chest": [Vector3(0, 1.08, 0), Vector3(0, 1.42, 0), 0.17, 0.26, "top"],
	"head": [Vector3(0, 1.53, 0.01), Vector3(0, 1.71, 0.01), 0.1, 0.08, "skin"],
	"upper_arm_l": [Vector3(-0.2, 1.4, 0), Vector3(-0.22, 1.14, 0), 0.055, 0.03, "sleeve"],
	"lower_arm_l": [Vector3(-0.22, 1.12, 0.01), Vector3(-0.23, 0.86, 0.03), 0.045, 0.02, "forearm"],
	"upper_arm_r": [Vector3(0.2, 1.4, 0), Vector3(0.22, 1.14, 0), 0.055, 0.03, "sleeve"],
	"lower_arm_r": [Vector3(0.22, 1.12, 0.01), Vector3(0.23, 0.86, 0.03), 0.045, 0.02, "forearm"],
	"thigh_l": [Vector3(-0.09, 0.88, 0), Vector3(-0.1, 0.5, 0), 0.08, 0.1, "overall"],
	"shin_l": [Vector3(-0.1, 0.48, 0), Vector3(-0.11, 0.08, 0), 0.07, 0.05, "overall"],
	"thigh_r": [Vector3(0.09, 0.88, 0), Vector3(0.1, 0.5, 0), 0.08, 0.1, "overall"],
	"shin_r": [Vector3(0.1, 0.48, 0), Vector3(0.11, 0.08, 0), 0.07, 0.05, "overall"],
}
## [parent, child, joint point (own frame), swing limit degrees]
const JOINTS := [
	["pelvis", "chest", Vector3(0, 1.05, 0), 30.0],
	["chest", "head", Vector3(0, 1.49, 0), 40.0],
	["chest", "upper_arm_l", Vector3(-0.2, 1.4, 0), 90.0],
	["upper_arm_l", "lower_arm_l", Vector3(-0.22, 1.13, 0), 70.0],
	["chest", "upper_arm_r", Vector3(0.2, 1.4, 0), 90.0],
	["upper_arm_r", "lower_arm_r", Vector3(0.22, 1.13, 0), 70.0],
	["pelvis", "thigh_l", Vector3(-0.09, 0.88, 0), 60.0],
	["thigh_l", "shin_l", Vector3(-0.1, 0.49, 0), 60.0],
	["pelvis", "thigh_r", Vector3(0.09, 0.88, 0), 60.0],
	["thigh_r", "shin_r", Vector3(0.1, 0.49, 0), 60.0],
]

var bodies: Dictionary = {}  ## part name -> RigidBody3D
var _age: float = 0.0
var _impulse := Vector3.ZERO
var _impulse_at := Vector3.ZERO


## A ragdoll of the person with `look` (SpectatorMesh.random_look()) standing
## at `xf` (scale = their height), pushed by `impulse` (N·s) where the
## karttu hit them, at world `at`.
static func create(look: Dictionary, xf: Transform3D, impulse: Vector3, at: Vector3) -> Ragdoll:
	var ragdoll := Ragdoll.new()
	ragdoll._build(look, xf)
	ragdoll._impulse = impulse
	ragdoll._impulse_at = at
	return ragdoll


func _ready() -> void:
	# Velocities, not impulses: apply_central_impulse() on a body that hasn't
	# had its first physics step yet came out as impulse / 1 kg rather than
	# impulse / mass (measured: 10 N·s on a 10 kg body gave 10 m/s), which
	# flung the first ragdolls ~40 m. Everything moves off together at
	# impulse / MASS; the part nearest the hit also gets a bit more and a
	# spin about the axis across the push, so they topple instead of sliding.
	var velocity := _impulse / MASS
	var nearest: RigidBody3D = null
	for body: RigidBody3D in bodies.values():
		body.linear_velocity = velocity
		if nearest == null or body.global_position.distance_to(_impulse_at) < nearest.global_position.distance_to(_impulse_at):
			nearest = body
	var across := Vector3.UP.cross(Vector3(velocity.x, 0, velocity.z)).normalized()
	for body: RigidBody3D in bodies.values():
		# Topple: the higher a part is, the faster it goes over.
		body.linear_velocity += Vector3(velocity.x, 0, velocity.z) * body.position.y * TOPPLE
		body.angular_velocity = across * 3.0
	if nearest != null:
		nearest.linear_velocity += velocity * 0.5


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIE_SECONDS:
		finished.emit()
		queue_free()


func _build(look: Dictionary, xf: Transform3D) -> void:
	add_child(_floor(xf.origin))
	var scale := xf.basis.get_scale().y
	var rotation := xf.basis.orthonormalized()
	var colours := {
		"overall": look.overall,
		"top": look.overall if look.winter else look.shirt,
		"sleeve": look.overall if look.winter else look.shirt,
		"forearm": look.overall if look.winter else look.skin,
		"skin": look.skin,
	}
	for part: String in PARTS:
		var spec: Array = PARTS[part]
		var from: Vector3 = spec[0] * scale
		var to: Vector3 = spec[1] * scale
		var radius: float = spec[2] * scale
		var body := RigidBody3D.new()
		body.name = part
		body.mass = MASS * spec[3]
		body.collision_layer = LAYER
		body.collision_mask = 1 | LAYER
		body.linear_damp = 0.3
		body.angular_damp = 2.0
		body.continuous_cd = part == "head"
		var length := maxf(from.distance_to(to), 0.01)
		var axis := (to - from).normalized()
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = length + 2.0 * radius
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = length + 2.0 * radius
		mesh.radial_segments = 12
		mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.albedo_color = colours[spec[4]]
		material.roughness = 0.9
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		body.add_child(visual)
		if part == "head":
			_add_hair(body, look, radius)
		elif part.begins_with("shin"):
			_add_end_cap(body, length / 2.0 + radius * 0.6, Vector3(radius * 1.3, radius * 1.1, radius * 2.4), look.shoes, Vector3(0, 0, radius * 0.9))
		elif part.begins_with("lower_arm"):
			_add_end_cap(body, length / 2.0 + radius * 0.9, Vector3.ONE * radius * 1.2, look.accessory if look.winter else look.skin, Vector3.ZERO)
		body.transform = Transform3D(rotation * _basis_along(axis), xf.origin + rotation * ((from + to) / 2.0))
		add_child(body)
		bodies[part] = body
	for joint_spec: Array in JOINTS:
		var joint := ConeTwistJoint3D.new()
		var parent: RigidBody3D = bodies[joint_spec[0]]
		var child: RigidBody3D = bodies[joint_spec[1]]
		joint.position = xf.origin + rotation * (joint_spec[2] * scale)
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(joint_spec[3]))
		joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(20.0))
		add_child(joint)
		joint.node_a = joint.get_path_to(parent)
		joint.node_b = joint.get_path_to(child)


## Something to land on wherever they stand: a 20 m plane at ground level
## on LAYER only.
func _floor(around: Vector3) -> StaticBody3D:
	var plane := StaticBody3D.new()
	plane.name = "Floor"
	plane.collision_layer = LAYER
	plane.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	shape.shape = box
	plane.add_child(shape)
	plane.position = Vector3(around.x, -0.1, around.z)
	return plane


## A shoe or hand: a small ellipsoid at the far end of a limb capsule —
## local +Y, since each capsule's Y runs from its PARTS `from` (knee,
## elbow) to its `to` (ankle, wrist).
func _add_end_cap(limb: RigidBody3D, offset: float, radii: Vector3, colour: Color, nudge: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	var visual := MeshInstance3D.new()
	visual.mesh = sphere
	visual.material_override = material
	visual.scale = radii
	visual.position = Vector3(0, offset, 0) + nudge
	limb.add_child(visual)


## A cap of hair (or the beanie / student cap) over the top of the head.
func _add_hair(head: RigidBody3D, look: Dictionary, radius: float) -> void:
	var colour: Color = look.hair
	match look.hat:
		"beanie":
			colour = look.accessory
		"student_cap":
			colour = SpectatorMesh.STUDENT_CAP_WHITE
	var cap := SphereMesh.new()
	cap.radius = radius * 1.08
	cap.height = radius * 1.4
	cap.is_hemisphere = true
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	var visual := MeshInstance3D.new()
	visual.mesh = cap
	visual.material_override = material
	visual.position = Vector3(0, radius * 0.55, 0)
	head.add_child(visual)


## A rotation taking +Y to `dir`.
static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))

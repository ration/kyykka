class_name SpectatorMesh
extends RefCounted
## Builds one low-poly spectator: a Finnish university student in
## *haalarit* — one-piece student overalls in their guild's colour, the
## legs covered in sewn-on patches (haalarimerkit). In summer the top half
## is tied around the waist by its sleeves over a T-shirt; in winter it's
## zipped up, with a scarf and beanie. Some summer students wear the
## white student cap with a long tassel, or sunglasses.
##
## Vertex-coloured boxes, cylinders and ellipsoids in one mesh (one draw
## call per person), built facing +Z, feet at the origin. Each person gets
## one mesh per Pose — arms down, arms up (cheering) and, for those who
## brought a can, drinking from it (right arm bent up to the mouth, head
## tipped back) — and Crowd swaps between them rather than rigging arms.

enum Pose { DOWN, CHEER, DRINK }

const SKIN_TONES: Array[Color] = [
	Color(0.96, 0.80, 0.69), Color(0.93, 0.75, 0.62), Color(0.89, 0.69, 0.56),
	Color(0.80, 0.60, 0.45), Color(0.62, 0.43, 0.30), Color(0.42, 0.28, 0.19),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.85, 0.72, 0.45), Color(0.72, 0.56, 0.32), Color(0.45, 0.31, 0.18),
	Color(0.25, 0.17, 0.10), Color(0.08, 0.07, 0.06), Color(0.60, 0.25, 0.10),
	Color(0.90, 0.40, 0.65), Color(0.30, 0.45, 0.90),  # students dye their hair
]
const SHIRT_COLORS: Array[Color] = [
	Color(0.93, 0.93, 0.92), Color(0.12, 0.12, 0.13), Color(0.55, 0.56, 0.58),
	Color(0.20, 0.30, 0.55), Color(0.70, 0.15, 0.18), Color(0.85, 0.80, 0.55),
]
const STUDENT_CAP_WHITE := Color(0.95, 0.95, 0.93)
const BLACK := Color(0.06, 0.06, 0.07)
const CAN_COLORS: Array[Color] = [
	Color(0.15, 0.30, 0.75), Color(0.80, 0.12, 0.12), Color(0.95, 0.75, 0.10),
	Color(0.10, 0.45, 0.20), Color(0.08, 0.08, 0.10), Color(0.55, 0.20, 0.55),
]
const CAN_SILVER := Color(0.78, 0.79, 0.8)
const NECK := Vector3(0, 1.48, 0)  ## the head tips back around this
const DRINK_HEAD_TILT := 0.35      ## radians
## Where a logo goes (Crowd puts a Sprite3D there), just in front of the
## torso, and its width: printed big across a summer T-shirt, or in winter
## a small sewn-on patch on the overalls' left chest, like the
## haalarimerkit on the legs.
const SHIRT_PRINT_CENTRE := Vector3(0, 1.28, 0.113)
const SHIRT_PRINT_WIDTH := 0.2
const CHEST_PATCH_CENTRE := Vector3(0.09, 1.36, 0.118)
const CHEST_PATCH_WIDTH := 0.065


## A random student wearing overalls of `overall` colour.
static func random_look(rng: RandomNumberGenerator, overall: Color, winter: bool) -> Dictionary:
	var hat := "none"
	if winter:
		hat = "beanie" if rng.randf() < 0.8 else "none"
	elif rng.randf() < 0.2:
		hat = "student_cap"
	var patches := []
	for i in range(rng.randi_range(8, 20)):
		patches.append({
			"side": -1 if rng.randf() < 0.5 else 1,
			"face": rng.randi_range(0, 2),  # front, outer side, back
			"y": rng.randf_range(0.18, 0.86),
			"along": rng.randf_range(-1.0, 1.0),
			"size": rng.randf_range(0.035, 0.07),
			"aspect": rng.randf_range(0.6, 1.3),
			"color": Color.from_hsv(rng.randf(), rng.randf_range(0.3, 1.0), rng.randf_range(0.5, 1.0)),
		})
	return {
		"winter": winter,
		"overall": overall,
		"shirt": SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()],
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()],
		"hair": HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
		"long_hair": rng.randf() < 0.4,
		"shoes": BLACK if rng.randf() < 0.5 else Color(0.9, 0.9, 0.88),
		"hat": hat,
		"accessory": Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.9), rng.randf_range(0.5, 0.9)),
		"sunglasses": not winter and rng.randf() < 0.15,
		"rolled_cuffs": rng.randf() < 0.5,
		"patches": patches,
		"can": CAN_COLORS[rng.randi() % CAN_COLORS.size()] if rng.randf() < 0.55 else null,
	}


static func build(look: Dictionary, pose: Pose) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var overall: Color = look.overall
	var worn := overall.darkened(0.18)
	var skin: Color = look.skin
	var winter: bool = look.winter

	for side: int in [-1, 1]:
		_box(st, Vector3(0.1 * side, 0.04, 0.03), Vector3(0.12, 0.08, 0.26), look.shoes)
		_box(st, Vector3(0.1 * side, 0.49, 0.0), Vector3(0.15, 0.82, 0.17), overall)
		if look.rolled_cuffs:
			_box(st, Vector3(0.1 * side, 0.13, 0.0), Vector3(0.16, 0.07, 0.18), worn)
	for patch in look.patches:
		_add_patch(st, patch)
	_box(st, Vector3(0, 0.95, 0), Vector3(0.36, 0.16, 0.2), overall)

	if winter:
		_box(st, Vector3(0, 1.22, 0), Vector3(0.38, 0.46, 0.21), overall)
		if look.get("chest_patch", false):
			# The patch's white fabric, for the logo to sit on.
			_box(st, Vector3(CHEST_PATCH_CENTRE.x, CHEST_PATCH_CENTRE.y, 0.108), Vector3(CHEST_PATCH_WIDTH + 0.02, CHEST_PATCH_WIDTH + 0.02, 0.006), Color(0.95, 0.95, 0.94))
		_box(st, Vector3(0, 1.46, 0), Vector3(0.22, 0.08, 0.22), look.accessory)  # scarf
	else:
		_box(st, Vector3(0, 1.22, 0), Vector3(0.36, 0.44, 0.2), look.shirt)
		# The overalls' top half, tied around the waist by its sleeves.
		_box(st, Vector3(0, 1.0, 0), Vector3(0.39, 0.09, 0.23), worn)
		_box(st, Vector3(0, 1.0, 0.12), Vector3(0.11, 0.09, 0.06), worn)
		for side: int in [-1, 1]:
			_box(st, Vector3(0.035 * side, 0.83, 0.125), Vector3(0.06, 0.28, 0.05), worn)
	_box(st, Vector3(0, 1.48, 0), Vector3(0.09, 0.06, 0.09), skin)

	var head := Transform3D.IDENTITY
	if pose == Pose.DRINK:
		head = Transform3D(Basis(Vector3.RIGHT, -DRINK_HEAD_TILT), NECK) * Transform3D(Basis.IDENTITY, -NECK)
	_add_head(st, look, head)
	for side: int in [-1, 1]:
		_add_arm(st, look, side, pose)

	var mesh := st.commit()
	return mesh


static func _add_head(st: SurfaceTool, look: Dictionary, xf: Transform3D) -> void:
	_ellipsoid(st, Vector3(0, 1.6, 0), Vector3(0.1, 0.12, 0.11), look.skin, 0.0, xf)
	var hair: Color = look.hair
	match look.hat:
		"beanie":
			_ellipsoid(st, Vector3(0, 1.62, -0.005), Vector3(0.115, 0.13, 0.123), look.accessory, 0.58, xf)
			_ellipsoid(st, Vector3(0, 1.755, -0.005), Vector3(0.035, 0.035, 0.035), look.accessory.lightened(0.4), 0.0, xf)
		"student_cap":
			_ellipsoid(st, Vector3(0, 1.615, -0.008), Vector3(0.108, 0.12, 0.118), hair, 0.55, xf)
			_cylinder(st, Vector3(0, 1.66, 0), 0.113, 0.113, 0.035, BLACK, xf)
			_cylinder(st, Vector3(0, 1.695, 0), 0.114, 0.122, 0.055, STUDENT_CAP_WHITE, xf)
			# The long tassel, hanging from the crown down past the ear.
			_box(st, Vector3(0.13, 1.6, -0.03), Vector3(0.015, 0.26, 0.015), BLACK, xf)
			_box(st, Vector3(0.08, 1.745, -0.02), Vector3(0.1, 0.012, 0.012), BLACK, xf)
		_:
			_ellipsoid(st, Vector3(0, 1.615, -0.008), Vector3(0.108, 0.12, 0.118), hair, 0.55, xf)
	if look.long_hair:
		_box(st, Vector3(0, 1.5, -0.08), Vector3(0.2, 0.26, 0.06), hair, xf)
	if look.sunglasses:
		_box(st, Vector3(0, 1.62, 0.105), Vector3(0.17, 0.035, 0.02), BLACK, xf)
	else:
		for side: int in [-1, 1]:
			_box(st, Vector3(0.035 * side, 1.615, 0.104), Vector3(0.022, 0.022, 0.01), BLACK, xf)


## An arm from shoulder to elbow to wrist: hanging, raised in a V for
## cheering, or (the right arm, when drinking) bent up to bring the can to
## the mouth. The can, if they have one, is in the right hand.
static func _add_arm(st: SurfaceTool, look: Dictionary, side: int, pose: Pose) -> void:
	var shoulder := Vector3(0.225 * side, 1.42, 0)
	var elbow: Vector3
	var wrist: Vector3
	var drinking := pose == Pose.DRINK and side == 1 and look.can != null
	if drinking:
		elbow = Vector3(0.28, 1.3, 0.2)
		wrist = Vector3(0.07, 1.57, 0.14)
	else:
		var angle := PI - 0.35 if pose == Pose.CHEER else 0.08
		var dir := Vector3(sin(angle) * side, -cos(angle), 0)
		elbow = shoulder + dir * 0.28
		wrist = elbow + dir * 0.26
	var winter: bool = look.winter
	if winter:
		_limb(st, shoulder, elbow, 0.1, 0.11, look.overall)
		_limb(st, elbow, wrist, 0.1, 0.11, look.overall)
	else:
		var sleeve_end := shoulder.lerp(elbow, 0.57)
		_limb(st, shoulder, sleeve_end, 0.1, 0.11, look.shirt)
		_limb(st, sleeve_end, elbow, 0.085, 0.095, look.skin)
		_limb(st, elbow, wrist, 0.085, 0.095, look.skin)
	var forearm := (wrist - elbow).normalized()
	# Mittens in winter.
	_limb(st, wrist - forearm * 0.01, wrist + forearm * 0.08, 0.08, 0.09, look.accessory if winter else look.skin)

	if side == 1 and look.can != null:
		if drinking:
			# Bottom up, top at the lips.
			var top_dir := Vector3(0, -0.45, -0.89).normalized()
			var mouth := Transform3D(Basis(Vector3.RIGHT, -DRINK_HEAD_TILT), NECK) * (Vector3(0, 1.56, 0.105) - NECK)
			_add_can(st, mouth - top_dir * 0.07, top_dir, look.can)
		else:
			_add_can(st, wrist + forearm * 0.045 + Vector3(0, 0, 0.035), Vector3.UP, look.can)


## A drinks can: coloured body, silver top and bottom rims.
static func _add_can(st: SurfaceTool, center: Vector3, up: Vector3, color: Color) -> void:
	var xf := Transform3D(_basis_along(up), center)
	_cylinder(st, Vector3(0, -0.06, 0), 0.03, 0.033, 0.012, CAN_SILVER, xf)
	_cylinder(st, Vector3(0, -0.048, 0), 0.033, 0.033, 0.096, color, xf)
	_cylinder(st, Vector3(0, 0.048, 0), 0.033, 0.03, 0.012, CAN_SILVER, xf)


## A patch sewn on the front, outer side or back of a trouser leg.
static func _add_patch(st: SurfaceTool, patch: Dictionary) -> void:
	var side: int = patch.side
	var size: float = patch.size
	var height: float = size * patch.aspect
	var x := 0.1 * side
	match patch.face:
		0:
			_box(st, Vector3(x + patch.along * (0.075 - size / 2.0), patch.y, 0.087), Vector3(size, height, 0.006), patch.color)
		1:
			_box(st, Vector3(x + 0.077 * side, patch.y, patch.along * (0.085 - size / 2.0)), Vector3(0.006, height, size), patch.color)
		_:
			_box(st, Vector3(x + patch.along * (0.075 - size / 2.0), patch.y, -0.087), Vector3(size, height, 0.006), patch.color)


# Primitives -------------------------------------------------------------------
# Godot's front faces wind clockwise; normals are set explicitly (flat on
# boxes, smooth on round parts).

## An axis-aligned box of `size` at `center`, optionally placed by `parent`.
static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, parent := Transform3D.IDENTITY) -> void:
	var xf := parent * Transform3D(Basis.from_scale(size), center)
	var normal_basis := xf.basis.inverse().transposed()
	st.set_color(color)
	# Each face: its normal, and two axes u, v with u x v = normal.
	for face in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]:
		var n: Vector3 = face[0] * 0.5
		var u: Vector3 = face[1] * 0.5
		var v: Vector3 = face[2] * 0.5
		st.set_normal((normal_basis * face[0]).normalized())
		for corner in [n - u - v, n + u + v, n + u - v, n - u - v, n - u + v, n + u + v]:
			st.add_vertex(xf * corner)


## A box stretched from `a` to `b` (a limb segment), `width` x `depth` across.
static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, width: float, depth: float, color: Color) -> void:
	var basis := _basis_along(b - a)
	var xf := Transform3D(Basis(basis.x * width, basis.y * a.distance_to(b), basis.z * depth), (a + b) / 2.0)
	_box(st, Vector3.ZERO, Vector3.ONE, color, xf)


## A right-handed rotation whose Y axis points along `dir`.
static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))


## An ellipsoid, or with `from` > 0 only its top part: from `from` * PI
## (0 = bottom pole) up to the top pole — a hair cap or a beanie.
static func _ellipsoid(st: SurfaceTool, center: Vector3, radii: Vector3, color: Color, from: float = 0.0, parent := Transform3D.IDENTITY) -> void:
	var longitudes := 10
	var latitudes := 6
	st.set_color(color)
	var rings: Array = []
	for lat in range(latitudes + 1):
		var theta := lerpf(from * PI, PI, float(lat) / latitudes)
		var ring: Array[Vector3] = []
		for lon in range(longitudes):
			var phi := TAU * lon / longitudes
			ring.append(Vector3(sin(theta) * cos(phi), -cos(theta), sin(theta) * sin(phi)))
		rings.append(ring)
	for lat in range(latitudes):
		for lon in range(longitudes):
			var next := (lon + 1) % longitudes
			for unit in [rings[lat][lon], rings[lat + 1][next], rings[lat + 1][lon], rings[lat][lon], rings[lat][next], rings[lat + 1][next]]:
				st.set_normal((parent.basis * (unit / radii)).normalized())
				st.add_vertex(parent * (center + unit * radii))


## A capped cylinder (or cone section) standing on `base`.
static func _cylinder(st: SurfaceTool, base: Vector3, bottom_radius: float, top_radius: float, height: float, color: Color, parent := Transform3D.IDENTITY) -> void:
	var sides := 12
	st.set_color(color)
	var top := base + Vector3.UP * height
	for s in range(sides):
		var d0 := Vector3(cos(TAU * s / sides), 0, sin(TAU * s / sides))
		var d1 := Vector3(cos(TAU * (s + 1) / sides), 0, sin(TAU * (s + 1) / sides))
		var b0 := base + d0 * bottom_radius
		var b1 := base + d1 * bottom_radius
		var t0 := top + d0 * top_radius
		var t1 := top + d1 * top_radius
		for v in [[b0, d0], [t1, d1], [t0, d0], [b0, d0], [b1, d1], [t1, d1]]:
			st.set_normal((parent.basis * v[1]).normalized())
			st.add_vertex(parent * v[0])
		st.set_normal((parent.basis * Vector3.UP).normalized())
		for v in [t0, t1, top]:
			st.add_vertex(parent * v)
		st.set_normal((parent.basis * Vector3.DOWN).normalized())
		for v in [base, b1, b0]:
			st.add_vertex(parent * v)

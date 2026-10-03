class_name SpectatorMesh
extends RefCounted
## Builds one spectator: a Finnish university student in *haalarit* —
## one-piece student overalls in their guild's colour, the legs covered in
## sewn-on patches (haalarimerkit). In summer the top half is tied around
## the waist by its sleeves over a T-shirt; in winter it's zipped up, with
## a scarf, mittens and a beanie. Some summer students wear the white
## student cap with a long tassel, or sunglasses.
##
## Smooth vertex-coloured parts (every limb, the torso and the head are
## surfaces of revolution, see _lathe()) in one indexed mesh — one draw
## call per person — built facing +Z, feet at the origin. Knees and elbows
## are placed with two-bone IK (_bend()), so a stance is just where the
## feet and hands go: each person stands their own way (weight on one leg,
## hands in pockets, on hips, arms crossed, behind the back), has their
## own hairstyle and face, and looks a little to one side.
##
## Each person gets one mesh per Pose — standing, cheering (arms up, mouth
## open) and, for those who brought a can, drinking from it (right arm
## bent up to the mouth, head tipped back) — and Crowd swaps between them
## rather than rigging arms. build_poses() builds the body below the neck
## once and reuses it for every pose.

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
const HAIR_STYLES: Array[String] = ["short", "short", "long", "ponytail", "bun", "curly", "buzz"]
## Where the left hand is when not cheering or drinking (the right one too,
## unless it's holding a can).
const STANCES: Array[String] = ["relaxed", "relaxed", "pockets", "hips", "crossed", "behind"]
const SHIRT_COLORS: Array[Color] = [
	Color(0.93, 0.93, 0.92), Color(0.12, 0.12, 0.13), Color(0.55, 0.56, 0.58),
	Color(0.20, 0.30, 0.55), Color(0.70, 0.15, 0.18), Color(0.85, 0.80, 0.55),
]
const STUDENT_CAP_WHITE := Color(0.95, 0.95, 0.93)
const BLACK := Color(0.06, 0.06, 0.07)
const EYE_WHITE := Color(0.93, 0.92, 0.9)
const ZIP_SILVER := Color(0.7, 0.71, 0.72)
const CAN_COLORS: Array[Color] = [
	Color(0.15, 0.30, 0.75), Color(0.80, 0.12, 0.12), Color(0.95, 0.75, 0.10),
	Color(0.10, 0.45, 0.20), Color(0.08, 0.08, 0.10), Color(0.55, 0.20, 0.55),
]
const CAN_SILVER := Color(0.78, 0.79, 0.8)
const NECK := Vector3(0, 1.49, 0)  ## the head turns and tips around this
const HEAD := Vector3(0, 1.625, 0)
const MOUTH := Vector3(0, 1.56, 0.097)
const DRINK_HEAD_TILT := 0.35      ## radians
const CHEER_HEAD_TILT := 0.12
const HIP_HEIGHT := 0.9
const THIGH := 0.41
const SHIN := 0.40
const ANKLE_HEIGHT := 0.1
const UPPER_ARM := 0.28
const FOREARM := 0.25
## Where a logo goes (Crowd puts a Sprite3D there), just in front of the
## torso, and its width: printed big across a summer T-shirt, or in winter
## a small sewn-on patch on the overalls' left chest, like the
## haalarimerkit on the legs.
const SHIRT_PRINT_CENTRE := Vector3(0, 1.27, 0.12)
const SHIRT_PRINT_WIDTH := 0.17
const CHEST_PATCH_CENTRE := Vector3(0.075, 1.33, 0.118)
const CHEST_PATCH_WIDTH := 0.06


## Vertex arrays for one mesh under construction.
class Parts:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func copy() -> Parts:
		var other := Parts.new()
		other.verts = verts.duplicate()
		other.normals = normals.duplicate()
		other.colors = colors.duplicate()
		other.indices = indices.duplicate()
		return other

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


## A random student wearing overalls of `overall` colour.
static func random_look(rng: RandomNumberGenerator, overall: Color, winter: bool) -> Dictionary:
	var hat := "none"
	if winter:
		hat = "beanie" if rng.randf() < 0.8 else "none"
	elif rng.randf() < 0.2:
		hat = "student_cap"
	var patches := []
	for i in range(rng.randi_range(10, 22)):
		patches.append({
			"side": -1 if rng.randf() < 0.5 else 1,
			"face": rng.randi_range(0, 2),  # front, outer side, back
			"y": rng.randf_range(0.18, 0.86),
			"along": rng.randf_range(-1.0, 1.0),
			"size": rng.randf_range(0.035, 0.065),
			"aspect": rng.randf_range(0.6, 1.3),
			"round": rng.randf() < 0.35,
			"color": Color.from_hsv(rng.randf(), rng.randf_range(0.3, 1.0), rng.randf_range(0.5, 1.0)),
			"border": Color.from_hsv(rng.randf(), rng.randf_range(0.2, 1.0), rng.randf_range(0.1, 1.0)),
		})
	var hair_style := HAIR_STYLES[rng.randi() % HAIR_STYLES.size()]
	var can: Variant = CAN_COLORS[rng.randi() % CAN_COLORS.size()] if rng.randf() < 0.55 else null
	return {
		"winter": winter,
		"overall": overall,
		"shirt": SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()],
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()],
		"hair": HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
		"hair_style": hair_style,
		"long_hair": hair_style == "long",
		"beard": hair_style in ["short", "buzz"] and rng.randf() < 0.25,
		"hair_seed": rng.randi(),
		"build": rng.randf_range(0.9, 1.1),  # shoulder width
		"stance": STANCES[rng.randi() % STANCES.size()],
		"weight": rng.randi_range(-1, 1),    # which leg they lean on, 0 = both
		"head_turn": rng.randf_range(-0.35, 0.35),
		"head_tilt": rng.randf_range(-0.08, 0.1),
		"cheer_spread": rng.randf_range(0.25, 0.6),
		"shoes": BLACK if rng.randf() < 0.5 else Color(0.9, 0.9, 0.88),
		"hat": hat,
		"accessory": Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.9), rng.randf_range(0.5, 0.9)),
		"sunglasses": not winter and rng.randf() < 0.15,
		"rolled_cuffs": rng.randf() < 0.5,
		"patches": patches,
		"can": can,
	}


static func build(look: Dictionary, pose: Pose) -> ArrayMesh:
	var body := Parts.new()
	_add_body(body, look)
	_add_pose(body, look, pose)
	return body.commit()


## A mesh for each of `poses`, sharing the body below the neck.
static func build_poses(look: Dictionary, poses: Array) -> Dictionary:
	var body := Parts.new()
	_add_body(body, look)
	var meshes := {}
	for pose: Pose in poses:
		var parts := body.copy()
		_add_pose(parts, look, pose)
		meshes[pose] = parts.commit()
	return meshes


# The figure -------------------------------------------------------------------

## Everything that doesn't change with the pose: legs, shoes, patches,
## torso, shoulders, neck and (winter) scarf.
static func _add_body(p: Parts, look: Dictionary) -> void:
	var overall: Color = look.overall
	var worn := overall.darkened(0.18)
	var winter: bool = look.winter
	var build: float = look.build
	var weight: int = look.weight

	for side: int in [-1, 1]:
		# The leg carrying the weight is straight; the other hip drops and
		# its foot steps out a little, bending the knee.
		var resting := weight != 0 and side != weight
		var hip := Vector3(0.09 * side, HIP_HEIGHT - (0.03 if resting else 0.0), 0)
		var ankle := Vector3(0.11 * side, ANKLE_HEIGHT, 0.0)
		if resting:
			ankle += Vector3(0.05 * side, 0, 0.09)
		var leg := _bend(hip, ankle, THIGH, SHIN, Vector3.BACK)
		var knee: Vector3 = leg[0]
		ankle = leg[1]
		_tube(p, hip, knee, 0.085, 0.072, overall, 10)
		_tube(p, knee, ankle + Vector3(0, -0.01, 0), 0.072, 0.074, overall, 10)
		if look.rolled_cuffs:
			_tube(p, ankle + Vector3(0, 0.0, 0), ankle + Vector3(0, 0.06, 0), 0.081, 0.08, worn, 12, 0.3)
		_add_shoe(p, look, ankle, side)
		for patch in look.patches:
			if patch.side == side:
				_add_patch(p, patch, hip, knee, ankle)

	# Hips and seat (the overalls), then the torso: the T-shirt in summer,
	# the zipped-up overalls in winter. Superelliptic cross-sections, so the
	# chest is flatter in front than a cylinder.
	_lathe(p, [
		Vector3(0.78, 0.0, 0.0), Vector3(0.79, 0.09, 0.06), Vector3(0.83, 0.15, 0.1),
		Vector3(0.9, 0.172, 0.112), Vector3(0.98, 0.165, 0.108), Vector3(1.05, 0.158, 0.105),
	], overall, Transform3D.IDENTITY, 14, 2.6)
	var top: Color = overall if winter else look.shirt
	_lathe(p, [
		Vector3(1.0, 0.157, 0.104), Vector3(1.1, 0.158 * build, 0.106),
		Vector3(1.22, 0.172 * build, 0.114), Vector3(1.33, 0.182 * build, 0.112),
		Vector3(1.41, 0.172 * build, 0.098), Vector3(1.46, 0.13 * build, 0.08),
		Vector3(1.49, 0.07, 0.055), Vector3(1.5, 0.0, 0.0),
	], top, Transform3D.IDENTITY, 14, 2.6)
	for side: int in [-1, 1]:
		_ellipsoid(p, _shoulder(look, side) + Vector3(-0.012 * side, 0, 0), Vector3(0.062, 0.058, 0.06), top)
	_tube(p, Vector3(0, 1.44, -0.005), Vector3(0, 1.56, 0.005), 0.044, 0.042, look.skin, 10)

	if winter:
		# Zip, chest pocket flap, and the scarf: wound round the neck, one
		# end hanging down the front.
		_box(p, Vector3(0, 1.2, 0.11), Vector3(0.012, 0.42, 0.012), ZIP_SILVER, Basis(Vector3.RIGHT, 0.04))
		if look.get("chest_patch", false):
			# The patch's white fabric, for the logo to sit on.
			_box(p, Vector3(CHEST_PATCH_CENTRE.x, CHEST_PATCH_CENTRE.y, CHEST_PATCH_CENTRE.z - 0.008), Vector3(CHEST_PATCH_WIDTH + 0.016, CHEST_PATCH_WIDTH + 0.016, 0.008), Color(0.95, 0.95, 0.94))
		else:
			_box(p, Vector3(-0.08, 1.31, 0.111), Vector3(0.07, 0.022, 0.01), worn)
		var scarf: Color = look.accessory
		_torus(p, Vector3(0, 1.485, 0.005), 0.062, 0.058, 0.032, scarf)
		_torus(p, Vector3(0, 1.43, 0.0), 0.085, 0.072, 0.03, scarf)
		_tube(p, Vector3(0.05, 1.45, 0.09), Vector3(0.07, 1.22, 0.128), 0.035, 0.038, scarf, 10, 0.3, Transform3D.IDENTITY, Vector3.RIGHT)
		for k in range(3):  # fringe
			_box(p, Vector3(0.056 + 0.014 * k, 1.17, 0.127), Vector3(0.008, 0.045, 0.008), scarf.darkened(0.2))
	else:
		# The overalls' top half, tied around the waist by its sleeves: a
		# bunched roll, a knot at the front and the two sleeve ends hanging.
		_torus(p, Vector3(0, 1.0, 0), 0.172, 0.114, 0.035, worn, 18)
		_ellipsoid(p, Vector3(0, 0.99, 0.123), Vector3(0.05, 0.042, 0.035), worn)
		for side: int in [-1, 1]:
			_tube(p, Vector3(0.02 * side, 0.97, 0.13), Vector3(0.06 * side, 0.7, 0.14), 0.033, 0.042, worn, 10, 0.45)


## The pose-dependent parts: head (turned, tipped, mouth open when
## cheering), arms, hands and can.
static func _add_pose(p: Parts, look: Dictionary, pose: Pose) -> void:
	var turn: float = look.head_turn
	var tilt: float = look.head_tilt
	match pose:
		Pose.CHEER:
			tilt = CHEER_HEAD_TILT
		Pose.DRINK:
			if look.can != null:
				turn = 0.0
				tilt = DRINK_HEAD_TILT
	_add_head(p, look, _head_transform(turn, tilt), pose == Pose.CHEER)
	for side: int in [-1, 1]:
		_add_arm(p, look, side, pose)


## Rotates the head about the neck: `turn` to the side, then `tilt` back.
static func _head_transform(turn: float, tilt: float) -> Transform3D:
	var rotation := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, -tilt)
	return Transform3D(rotation, NECK) * Transform3D(Basis.IDENTITY, -NECK)


static func _shoulder(look: Dictionary, side: int) -> Vector3:
	return Vector3(0.185 * look.build * side, 1.405, -0.005)


static func _add_head(p: Parts, look: Dictionary, xf: Transform3D, open_mouth: bool) -> void:
	var skin: Color = look.skin
	var hair: Color = look.hair
	# Cranium and a narrower jaw, nose, ears.
	_lathe(p, [
		Vector3(-0.115, 0.0, 0.0), Vector3(-0.108, 0.036, 0.05), Vector3(-0.088, 0.058, 0.08),
		Vector3(-0.055, 0.075, 0.095), Vector3(-0.015, 0.086, 0.1), Vector3(0.025, 0.086, 0.094),
		Vector3(0.065, 0.07, 0.074), Vector3(0.095, 0.04, 0.044), Vector3(0.106, 0.0, 0.0),
	], skin, xf * Transform3D(Basis.IDENTITY, HEAD + Vector3(0, 0, 0.004)), 14)
	_ellipsoid(p, Vector3(0, 1.6, 0.1), Vector3(0.014, 0.024, 0.018), skin.darkened(0.04), xf)
	for side: int in [-1, 1]:
		_ellipsoid(p, Vector3(0.088 * side, 1.615, -0.005), Vector3(0.013, 0.026, 0.018), skin.darkened(0.06), xf)

	if look.sunglasses:
		for side: int in [-1, 1]:
			_ellipsoid(p, Vector3(0.034 * side, 1.625, 0.092), Vector3(0.026, 0.018, 0.008), BLACK, xf)
		_box(p, Vector3(0, 1.632, 0.1), Vector3(0.03, 0.006, 0.006), BLACK, Basis.IDENTITY, xf)
		for side: int in [-1, 1]:
			_box(p, Vector3(0.082 * side, 1.632, 0.05), Vector3(0.005, 0.006, 0.09), BLACK, Basis.IDENTITY, xf)
	else:
		for side: int in [-1, 1]:
			_ellipsoid(p, Vector3(0.032 * side, 1.623, 0.087), Vector3(0.016, 0.01, 0.01), EYE_WHITE, xf, 0.0, 1.0, 4, 6)
			_ellipsoid(p, Vector3(0.032 * side, 1.623, 0.094), Vector3(0.007, 0.007, 0.006), BLACK, xf, 0.0, 1.0, 3, 5)
	for side: int in [-1, 1]:
		var brow := Basis(Vector3.BACK, -0.12 * side)
		_box(p, Vector3(0.032 * side, 1.645, 0.093), Vector3(0.03, 0.007, 0.008), hair.darkened(0.2), brow, xf)

	if look.beard:
		_ellipsoid(p, Vector3(0, 1.567, 0.016), Vector3(0.077, 0.066, 0.087), hair, xf, 0.0, 0.5)
	if open_mouth:
		_ellipsoid(p, MOUTH + Vector3(0, -0.004, 0), Vector3(0.022, 0.016, 0.01), Color(0.25, 0.06, 0.06), xf, 0.0, 1.0, 4, 8)
	else:
		_ellipsoid(p, MOUTH, Vector3(0.02, 0.005, 0.008), skin.darkened(0.35).lerp(Color(0.6, 0.2, 0.2), 0.3), xf, 0.0, 1.0, 3, 8)

	_add_hair(p, look, xf)


static func _add_hair(p: Parts, look: Dictionary, xf: Transform3D) -> void:
	var hair: Color = look.hair
	var style: String = look.hair_style
	# The cap of hair, tipped back so the hairline is higher at the front
	# than at the nape.
	# Equal Y and Z radii, so tipping it doesn't change its shape and it
	# keeps covering the (narrower, shallower) cranium everywhere.
	var cap_radii := Vector3(0.095, 0.118, 0.118)
	var cap_from := 0.45
	match style:
		"buzz":
			cap_radii = Vector3(0.091, 0.115, 0.115)
		"curly":
			cap_radii = Vector3(0.104, 0.126, 0.126)
	var cap := xf * Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(0, 1.632, -0.008))

	match look.hat:
		"beanie":
			var beanie: Color = look.accessory
			_ellipsoid(p, Vector3.ZERO, Vector3(0.107, 0.128, 0.117), beanie, cap * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.005, 0)), 0.53)
			_torus(p, Vector3.ZERO, 0.105, 0.112, 0.018, beanie.darkened(0.15), 16, 6, _pivot(xf, Vector3(0, 1.648, -0.004), Basis(Vector3.RIGHT, -0.15)))
			_ellipsoid(p, Vector3(0, 1.765, -0.02), Vector3(0.038, 0.036, 0.038), beanie.lightened(0.45), xf)
			if style == "long" or style == "ponytail":
				_add_long_hair(p, hair, xf)
			return
		"student_cap":
			_ellipsoid(p, Vector3.ZERO, cap_radii, hair, cap, cap_from)
			# Black band, white crown, and the long tassel from the crown
			# down past the ear to a pompom.
			var band := _pivot(xf, HEAD, Basis(Vector3.RIGHT, -0.12)) * Transform3D(Basis.IDENTITY, -HEAD)
			_lathe(p, [Vector3(1.66, 0.0, 0.0), Vector3(1.66, 0.104, 0.112), Vector3(1.695, 0.106, 0.114), Vector3(1.695, 0.0, 0.0)], BLACK, band, 16)
			_lathe(p, [Vector3(1.694, 0.0, 0.0), Vector3(1.694, 0.108, 0.116), Vector3(1.735, 0.116, 0.124), Vector3(1.75, 0.112, 0.12), Vector3(1.752, 0.0, 0.0)], STUDENT_CAP_WHITE, band, 16)
			_ellipsoid(p, Vector3(0, 1.704, 0.112), Vector3(0.012, 0.012, 0.006), Color(0.85, 0.7, 0.3), band, 0.0, 1.0, 3, 6)
			_tube(p, Vector3(0, 1.755, -0.01), Vector3(0.1, 1.74, -0.04), 0.006, 0.006, BLACK, 5, 1.0, xf)
			_tube(p, Vector3(0.1, 1.74, -0.04), Vector3(0.135, 1.5, -0.05), 0.006, 0.006, BLACK, 5, 1.0, xf)
			_ellipsoid(p, Vector3(0.137, 1.485, -0.05), Vector3(0.02, 0.03, 0.02), BLACK, xf, 0.0, 1.0, 4, 6)
			return

	_ellipsoid(p, Vector3.ZERO, cap_radii, hair, cap, cap_from)
	match style:
		"long":
			_add_long_hair(p, hair, xf)
		"ponytail":
			_tube(p, Vector3(0, 1.67, -0.1), Vector3(0, 1.45, -0.15), 0.034, 0.014, hair, 8, 0.8, xf)
			_torus(p, Vector3.ZERO, 0.022, 0.022, 0.008, look.accessory, 8, 4, _pivot(xf, Vector3(0, 1.665, -0.105), Basis(Vector3.RIGHT, 1.0)))
		"bun":
			_ellipsoid(p, Vector3(0, 1.725, -0.075), Vector3(0.048, 0.042, 0.045), hair, xf)
		"curly":
			var rng := RandomNumberGenerator.new()
			rng.seed = look.hair_seed
			for i in range(14):
				var angle := rng.randf() * TAU
				var up := rng.randf_range(0.15, 0.95)
				var dir := Vector3(cos(angle) * sqrt(1.0 - up * up), up, sin(angle) * sqrt(1.0 - up * up) - 0.25)
				if dir.z > 0.55 and up < 0.5:
					continue  # keep the face clear
				_ellipsoid(p, Vector3(0, 1.63, -0.01) + dir.normalized() * Vector3(0.1, 0.12, 0.11), Vector3.ONE * rng.randf_range(0.03, 0.042), hair, xf, 0.0, 1.0, 4, 6)


## Hair to the shoulders: a thick curtain down the back, framing the face.
static func _add_long_hair(p: Parts, hair: Color, xf: Transform3D) -> void:
	_tube(p, Vector3(0, 1.66, -0.045), Vector3(0, 1.43, -0.07), 0.1, 0.09, hair, 12, 0.5, xf, Vector3.RIGHT)
	for side: int in [-1, 1]:
		_tube(p, Vector3(0.085 * side, 1.65, 0.0), Vector3(0.09 * side, 1.47, -0.03), 0.025, 0.03, hair, 8, 1.0, xf)


## An arm from shoulder to elbow to wrist, then a hand (a mitten in
## winter). Hands in pockets aren't drawn; the can, if they have one, is
## in the right hand.
static func _add_arm(p: Parts, look: Dictionary, side: int, pose: Pose) -> void:
	var shoulder := _shoulder(look, side)
	var holding := side == 1 and look.can != null
	var stance: String = "relaxed" if holding else look.stance
	var wrist: Vector3
	var pole: Vector3
	var hand_side := Vector3.BACK  # the hand's width axis: palm faces in
	var show_hand := true
	if pose == Pose.CHEER:
		var spread: float = look.cheer_spread
		wrist = shoulder + Vector3(sin(spread) * side, cos(spread), 0.08) * (UPPER_ARM + FOREARM)
		pole = Vector3(side, 0, -0.4)
		hand_side = Vector3.RIGHT
	elif pose == Pose.DRINK and holding:
		wrist = Vector3(0.06, 1.5, 0.17)
		pole = Vector3(1, -0.6, 0.2)
		hand_side = Vector3.RIGHT
	else:
		match stance:
			"pockets":
				wrist = Vector3(0.155 * side, 0.86, 0.06)
				pole = Vector3(side, 0, -0.6)
				show_hand = false
			"hips":
				wrist = Vector3(0.165 * side, 1.0, 0.03)
				pole = Vector3(side, 0.3, -0.3)
				hand_side = Vector3.UP
			"crossed":
				wrist = Vector3(-0.1 * side, 1.23 + 0.025 * side, 0.155 + 0.02 * side)
				pole = Vector3(side, -0.8, 0.0)
				hand_side = Vector3.UP
			"behind":
				wrist = Vector3(0.05 * side, 0.98, -0.15)
				pole = Vector3(side, 0, -0.2)
				hand_side = Vector3.RIGHT
			_:
				wrist = shoulder + Vector3(0.04 * side, -0.51, 0.04)
				pole = Vector3(0.3 * side, 0, -1)
	var arm := _bend(shoulder, wrist, UPPER_ARM, FOREARM, pole)
	var elbow: Vector3 = arm[0]
	wrist = arm[1]

	var skin: Color = look.skin
	var winter: bool = look.winter
	if winter:
		var overall: Color = look.overall
		_tube(p, shoulder, elbow, 0.062, 0.056, overall)
		_tube(p, elbow, wrist, 0.056, 0.05, overall)
		_tube(p, wrist.lerp(elbow, 0.12), wrist, 0.054, 0.054, overall.darkened(0.18), 10, 0.3)
	else:
		var sleeve_end := shoulder.lerp(elbow, 0.45)
		_tube(p, shoulder, sleeve_end, 0.06, 0.057, look.shirt, 12, 0.3)
		_tube(p, shoulder.lerp(elbow, 0.1), elbow, 0.044, 0.04, skin, 10)
		_tube(p, elbow, wrist, 0.04, 0.032, skin, 10)
	if not show_hand:
		return
	var forearm := (wrist - elbow).normalized()
	var frame := Transform3D(_basis_along(forearm, hand_side), wrist + forearm * 0.05)
	if winter:
		var mitten: Color = look.accessory
		_ellipsoid(p, Vector3.ZERO, Vector3(0.042, 0.058, 0.03), mitten, frame)
		_ellipsoid(p, Vector3(0.03 * side, -0.01, 0.012), Vector3(0.014, 0.03, 0.014), mitten, frame, 0.0, 1.0, 4, 6)
	else:
		_ellipsoid(p, Vector3.ZERO, Vector3(0.035, 0.052, 0.018), skin, frame)
		_tube(p, Vector3(0.025 * side, -0.025, 0.008), Vector3(0.04 * side, 0.015, 0.012), 0.01, 0.009, skin, 6, 1.0, frame)

	if holding:
		if pose == Pose.DRINK:
			# Bottom up, top at the lips.
			var top_dir := Vector3(0, -0.45, -0.89).normalized()
			var mouth := _head_transform(0.0, DRINK_HEAD_TILT) * (MOUTH + Vector3(0, 0, 0.008))
			_add_can(p, mouth - top_dir * 0.07, top_dir, look.can)
		elif pose == Pose.DOWN:
			_add_can(p, wrist + forearm * 0.05 + Vector3(0, 0, 0.03), Vector3.UP, look.can)
		else:
			_add_can(p, wrist + forearm * 0.06, forearm, look.can)


## A sneaker (a boot in winter): an upper over a rounded sole, toes turned
## out a little.
static func _add_shoe(p: Parts, look: Dictionary, ankle: Vector3, side: int) -> void:
	var forward := Vector3(sin(0.12 * side), 0, cos(0.12 * side))
	var foot := Vector3(ankle.x, 0, ankle.z)
	var shoe: Color = look.shoes
	if look.winter:
		shoe = Color(0.16, 0.11, 0.08) if shoe == BLACK else Color(0.08, 0.08, 0.09)
		_tube(p, foot + Vector3(0, 0.05, 0), foot + Vector3(0, 0.15, 0), 0.06, 0.062, shoe, 10)
	var sole := Color(0.92, 0.91, 0.88) if shoe == BLACK else Color(0.2, 0.2, 0.21)
	_tube(p, foot - forward * 0.065 + Vector3(0, 0.016, 0), foot + forward * 0.13 + Vector3(0, 0.016, 0), 0.05, 0.048, sole, 10, 0.32, Transform3D.IDENTITY, Vector3.RIGHT)
	_tube(p, foot - forward * 0.055 + Vector3(0, 0.055, 0), foot + forward * 0.11 + Vector3(0, 0.045, 0), 0.047, 0.044, shoe, 10, 0.75, Transform3D.IDENTITY, Vector3.RIGHT)


## A patch sewn on the front, outer side or back of a trouser leg: a thin
## coloured panel lying on the leg's surface, some with a contrasting border.
static func _add_patch(p: Parts, patch: Dictionary, hip: Vector3, knee: Vector3, ankle: Vector3) -> void:
	var side: int = patch.side
	var height: float = patch.y
	var a := knee if height < knee.y else hip
	var b := ankle if height < knee.y else knee
	var t := clampf((height - a.y) / (b.y - a.y), 0.05, 0.95)
	var centre := a.lerp(b, t)
	var radius := lerpf(0.085, 0.072, t) if a == hip else lerpf(0.072, 0.074, t)
	var along: float = patch.along
	var angle: float = [0.0, PI / 2.0 * side, PI][patch.face] + along * 0.5
	var outward := Vector3(sin(angle), 0, cos(angle))
	var dir := (b - a).normalized()
	outward = (outward - dir * outward.dot(dir)).normalized()
	var size: float = patch.size
	var basis := Basis(dir.cross(outward).normalized(), dir, outward)
	var at := centre + outward * radius
	var color: Color = patch.color
	if patch.round:
		var disc := Transform3D(Basis(basis.x, basis.z, -basis.y), at)
		_lathe(p, [Vector3(-0.003, 0.0, 0.0), Vector3(-0.003, size / 2.0, size / 2.0), Vector3(0.003, size / 2.0, size / 2.0), Vector3(0.003, 0.0, 0.0)], patch.border, disc, 8)
		_lathe(p, [Vector3(0.003, size * 0.4, size * 0.4), Vector3(0.0045, 0.0, 0.0)], color, disc, 8)
	else:
		_box(p, at, Vector3(size, size * patch.aspect, 0.006), patch.border, basis)
		_box(p, at + outward * 0.0015, Vector3(size - 0.008, size * patch.aspect - 0.008, 0.006), color, basis)


## A drinks can: coloured body, silver top and bottom rims.
static func _add_can(p: Parts, center: Vector3, up: Vector3, color: Color) -> void:
	var xf := Transform3D(_basis_along(up), center)
	_lathe(p, [Vector3(-0.06, 0.0, 0.0), Vector3(-0.06, 0.03, 0.03), Vector3(-0.048, 0.033, 0.033)], CAN_SILVER, xf, 12)
	_lathe(p, [Vector3(-0.048, 0.033, 0.033), Vector3(0.048, 0.033, 0.033)], color, xf, 12)
	_lathe(p, [Vector3(0.048, 0.033, 0.033), Vector3(0.06, 0.03, 0.03), Vector3(0.06, 0.0, 0.0)], CAN_SILVER, xf, 12)


## Two-bone IK: where the middle joint (knee, elbow) goes for a limb from
## `root` reaching for `target`, bending toward `pole`. Returns [joint,
## end]; the end is pulled in if the target is out of reach.
static func _bend(root: Vector3, target: Vector3, upper: float, lower: float, pole: Vector3) -> Array:
	var to := target - root
	var dir := to.normalized()
	var reach := clampf(to.length(), absf(upper - lower) + 0.01, upper + lower - 0.002)
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var out := sqrt(maxf(upper * upper - along * along, 0.0))
	var bend := (pole - dir * pole.dot(dir)).normalized()
	return [root + dir * along + bend * out, root + dir * reach]


# Primitives -------------------------------------------------------------------
# Godot's front faces wind clockwise. Round parts get smooth normals from
# their own surface (_lathe()); boxes get flat ones.

## A surface of revolution about `xf`'s local Y axis: `profile` is
## (y, x radius, z radius) per ring, bottom to top; a ring with zero radius
## closes the end. Cross-sections are superellipses with `exponent` (2 =
## ellipse, higher = boxier).
static func _lathe(p: Parts, profile: Array, color: Color, xf: Transform3D, sides := 12, exponent := 2.0) -> void:
	var rings := profile.size()
	var base := p.verts.size()
	var around_x := PackedFloat32Array()
	var around_z := PackedFloat32Array()
	for j in range(sides):
		var c := cos(TAU * j / sides)
		var s := sin(TAU * j / sides)
		if exponent != 2.0:
			c = signf(c) * pow(absf(c), 2.0 / exponent)
			s = signf(s) * pow(absf(s), 2.0 / exponent)
		around_x.append(c)
		around_z.append(s)
	var points := PackedVector3Array()
	var centres := PackedVector3Array()
	for ring: Vector3 in profile:
		centres.append(xf * Vector3(0, ring.x, 0))
		for j in range(sides):
			points.append(xf * Vector3(around_x[j] * ring.y, ring.x, around_z[j] * ring.z))
	for i in range(rings):
		var below := maxi(i - 1, 0)
		var above := mini(i + 1, rings - 1)
		for j in range(sides):
			var here := points[i * sides + j]
			var tangent := points[i * sides + (j + 1) % sides] - points[i * sides + (j + sides - 1) % sides]
			var up := points[above * sides + j] - points[below * sides + j]
			var normal := up.cross(tangent)
			var outward := here - centres[i]
			if outward.length_squared() < 1e-12:
				# A pole: point away from the nearest ring with a different centre.
				var k := 1 if i == 0 else rings - 2
				var step := 1 if i == 0 else -1
				while k >= 0 and k < rings and (here - centres[k]).length_squared() < 1e-12:
					k += step
				outward = here - centres[clampi(k, 0, rings - 1)]
				normal = outward
			elif normal.length_squared() < 1e-14:
				normal = outward
			if normal.dot(outward) < 0.0:
				normal = -normal
			p.verts.append(here)
			p.normals.append(normal.normalized())
			p.colors.append(color)
	# Wind each quad clockwise seen from outside.
	var middle := (rings - 1) >> 1
	var a0 := points[middle * sides]
	var flip := (points[middle * sides + 1] - a0).cross(points[(middle + 1) * sides + 1] - a0).dot(p.normals[base + middle * sides] + p.normals[base + (middle + 1) * sides]) > 0.0
	for i in range(rings - 1):
		for j in range(sides):
			var a := base + i * sides + j
			var b := base + i * sides + (j + 1) % sides
			var c := a + sides
			var d := b + sides
			if flip:
				p.indices.append_array([a, d, b, a, c, d])
			else:
				p.indices.append_array([a, b, d, a, d, c])


## An ellipsoid, or the band of it from `from` * PI to `to` * PI (0 = bottom
## pole): `from` > 0 for a hair cap or a beanie, `to` < 1 for a beard.
static func _ellipsoid(p: Parts, center: Vector3, radii: Vector3, color: Color, parent := Transform3D.IDENTITY, from := 0.0, to := 1.0, latitudes := 6, sides := 10) -> void:
	var profile := []
	for lat in range(latitudes + 1):
		var theta := lerpf(from * PI, to * PI, float(lat) / latitudes)
		var r := sin(theta)
		if absf(r) < 1e-4:
			r = 0.0
		profile.append(Vector3(-cos(theta) * radii.y, r * radii.x, r * radii.z))
	_lathe(p, profile, color, parent * Transform3D(Basis.IDENTITY, center), sides)


## A rounded, tapered limb from `a` to `b`: radius `ra` at `a`, `rb` at `b`,
## `flat` times as deep (along the limb's local Z) as wide, with domed ends
## `dome` radii deep. `side` picks which way the width faces.
static func _tube(p: Parts, a: Vector3, b: Vector3, ra: float, rb: float, color: Color, sides := 8, dome := 0.6, parent := Transform3D.IDENTITY, side := Vector3.ZERO, flat := 1.0) -> void:
	var length := a.distance_to(b)
	var profile := []
	for k in range(3):
		var angle := PI / 2.0 * k / 2.0
		profile.append(Vector3(-ra * dome * cos(angle), ra * sin(angle), ra * sin(angle) * flat))
	profile.append(Vector3(length * 0.5, (ra + rb) * 0.52, (ra + rb) * 0.52 * flat))
	for k in range(3):
		var angle := PI / 2.0 * (2 - k) / 2.0
		profile.append(Vector3(length + rb * dome * cos(angle), rb * sin(angle), rb * sin(angle) * flat))
	if side != Vector3.ZERO:
		# A flattened limb: `flat` is ignored, the width runs along `side`
		# and the depth is `dome` x the width (sole, hair, sleeve ends).
		profile.clear()
		for k in range(3):
			var angle := PI / 2.0 * k / 2.0
			profile.append(Vector3(-ra * 0.6 * cos(angle), ra * sin(angle), ra * sin(angle) * dome))
		for k in range(3):
			var angle := PI / 2.0 * (2 - k) / 2.0
			profile.append(Vector3(length + rb * 0.6 * cos(angle), rb * sin(angle), rb * sin(angle) * dome))
	_lathe(p, profile, color, parent * Transform3D(_basis_along(b - a, side), a), sides)


## A ring around the vertical axis through `center`: `rx` x `rz` across,
## `thickness` the radius of its cross-section.
static func _torus(p: Parts, center: Vector3, rx: float, rz: float, thickness: float, color: Color, segments := 16, sides := 6, parent := Transform3D.IDENTITY) -> void:
	var base := p.verts.size()
	for i in range(segments):
		var angle := TAU * i / segments
		var spoke := Vector3(cos(angle), 0, sin(angle))
		var ring_centre := center + Vector3(spoke.x * rx, 0, spoke.z * rz)
		for j in range(sides):
			var phi := TAU * j / sides
			var normal := spoke * cos(phi) + Vector3.UP * sin(phi)
			p.verts.append(parent * (ring_centre + normal * thickness))
			p.normals.append((parent.basis * normal).normalized())
			p.colors.append(color)
	for i in range(segments):
		for j in range(sides):
			var a := base + i * sides + j
			var b := base + i * sides + (j + 1) % sides
			var c := base + ((i + 1) % segments) * sides + j
			var d := base + ((i + 1) % segments) * sides + (j + 1) % sides
			p.indices.append_array([a, d, b, a, c, d])


## A box of `size` at `center`, turned by `basis`, optionally placed by `parent`.
static func _box(p: Parts, center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY, parent := Transform3D.IDENTITY) -> void:
	var xf := parent * Transform3D(basis * Basis.from_scale(size), center)
	var normal_basis := xf.basis.inverse().transposed()
	# Each face: its normal, and two axes u, v with u x v = normal.
	for face in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]:
		var n: Vector3 = face[0] * 0.5
		var u: Vector3 = face[1] * 0.5
		var v: Vector3 = face[2] * 0.5
		var normal: Vector3 = (normal_basis * face[0]).normalized()
		var base := p.verts.size()
		for corner in [n - u - v, n + u - v, n + u + v, n - u + v]:
			p.verts.append(xf * corner)
			p.normals.append(normal)
			p.colors.append(color)
		p.indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


## `parent`, then `basis` placed at `pivot` (in `parent`'s space).
static func _pivot(parent: Transform3D, pivot: Vector3, basis: Basis) -> Transform3D:
	return parent * Transform3D(basis, pivot)


## A right-handed rotation whose Y axis points along `dir`, its X axis as
## close to `side` as possible if given.
static func _basis_along(dir: Vector3, side := Vector3.ZERO) -> Basis:
	var y := dir.normalized()
	var x: Vector3
	if side != Vector3.ZERO and absf(side.normalized().dot(y)) < 0.95:
		x = (side - y * side.dot(y)).normalized()
	else:
		var ref := Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT
		x = y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))

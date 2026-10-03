class_name WinterLandscape
extends Landscape
## Winter scenery (see Landscape): kyykkä the way it's played in a Finnish
## winter — on a big ploughed office-park parking lot after hours, modelled
## loosely on Hermia in Hervanta, Tampere, where it's usually played. The
## court is packed snow; alongside it run more courts with other teams
## mid-game, then one car someone left parked, shielded with plywood, lamp posts and
## the plough's snowbanks round the edge. Beyond them, about six-storey
## office blocks (shaders/building.gdshader, windows lit in the low sun),
## then the snowfield, spruces and hills of the base Landscape. Light
## snowfall over everything.
##
## None of it has collision, and the nearest neighbour court starts
## LOT_COURT_GAP past this court's side line — further out than the
## crowd (Crowd.MIN_SIDE_CLEARANCE + ROWS_DEPTH) — so it doesn't interfere
## with play.

@export var snowfall_amount: int = 2500

const LOT_HALF_SIZE := Vector2(56.0, 64.0)  ## the ploughed lot, X x Z half-extents
const LOT_COURT_GAP := 9.0     ## metres between neighbouring courts' side lines
const NEIGHBOUR_COURTS := [-3, -2, -1, 1, 2, 3]  ## slots either side of ours (0)
const COURT_SIZE := Vector2(5.0, 20.0)
const PESA_DEPTH := 5.0
const OFFICE_RING := Vector2(110.0, 175.0)  ## office blocks between these distances
const OFFICE_COUNT := 14  ## once round the lot, so any one view shows about eight or fewer
const OFFICE_FLOOR := 3.6      ## metres per storey
const SNOWBANK_HEIGHT := 1.6
const CAR_POSITION := Vector3(-14.0, 0.0, -24.0)  ## the one car: front of the nearest row, side-on to our court
const CAR_YAW := 0.0  ## parked along the lot, its long side to our court
const PAINT_MARKER := Color(1, 0, 1)  ## car vertex colour replaced by the instance's paint
const BUILDING_SHADER := preload("res://shaders/building.gdshader")


func _init() -> void:
	super._init()
	name = "WinterLandscape"
	# The base field's flat zone and forest clearance cover the whole lot
	# and office park, so the hills and trees start beyond them.
	flat_half_width = LOT_HALF_SIZE.x + 8.0
	flat_half_length = LOT_HALF_SIZE.y + 8.0
	tree_min_clearance = 30.0
	tree_count = 500
	hill_start_radius = 200.0
	hill_end_radius = 340.0


func _atmosphere() -> Dictionary:
	return {
		sky_top = Color(0.42, 0.58, 0.80),
		sky_horizon = Color(0.82, 0.87, 0.93),
		sky_ground = Color(0.90, 0.93, 0.97),
		ambient_color = Color(0.62, 0.70, 0.85),
		ambient_energy = 0.45,
		fog_color = Color(0.80, 0.85, 0.92),
		fog_density = 0.0015,
		# Low (~17°) and off to one side, so shadows fall diagonally across
		# the court and pick out the snow's surface texture.
		sun_elevation = 17.0,
		sun_yaw = 35.0,
		sun_color = Color(1.0, 0.91, 0.80),
		sun_energy = 0.9,
	}


## Fresh snow around the lot; `packed` (the courts and the ploughed lot)
## is flatter, less mottled and less sparkly. Snow albedo stays below
## white — see Landscape.apply_atmosphere() for why white snow clipped.
func _ground_parameters(packed: bool) -> Dictionary:
	if packed:
		return {
			bright_color = GameMode.ground_high_color(),
			dark_color = GameMode.ground_low_color(),
			mottle_contrast = 0.9,
			normal_depth = 0.3,
			sparkle_amount = 0.025,
			roughness_value = 0.6,
		}
	return {
		bright_color = Color(0.93, 0.93, 0.95),
		dark_color = Color(0.78, 0.82, 0.90),
		sparkle_amount = 0.06,
	}


func court_material() -> Material:
	return ground_material(true)


func _tree_allowed(x: float, z: float) -> bool:
	return Vector2(x, z).length() > OFFICE_RING.y + 15.0


func _add_extras() -> void:
	add_child(_build_lot())
	add_child(_build_snowbanks())
	add_child(_build_neighbour_courts())
	add_child(_build_cars())
	add_child(_build_lamps())
	add_child(_build_offices())
	add_child(_build_snowfall())


# The parking lot -------------------------------------------------------------

## Ploughed, trodden snow over the whole lot, a little above the field
## (but below the court plane at y = 0), with faint grey tyre tracks in
## the car rows.
func _build_lot() -> Node3D:
	var lot := Node3D.new()
	lot.name = "ParkingLot"
	var plane := PlaneMesh.new()
	plane.size = LOT_HALF_SIZE * 2.0
	var surface := MeshInstance3D.new()
	surface.mesh = plane
	surface.material_override = ground_material(true)
	surface.position.y = -0.012
	lot.add_child(surface)

	var tracks := _vertex_color_material(0.85)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 20
	for row_z in _car_row_zs():
		for side: float in [-1.0, 1.0]:
			var z: float = row_z + side * 5.5
			for lane in range(2):
				var offset := rng.randf_range(-0.2, 0.2) + (lane - 0.5) * 1.6
				_flat_quad(st, Vector3(0, -0.006, z + offset), Vector2(LOT_HALF_SIZE.x * 2.0 - 6.0, 0.45), Color(0.70, 0.72, 0.76))
	st.generate_normals()
	var track_mesh := MeshInstance3D.new()
	track_mesh.mesh = st.commit()
	track_mesh.material_override = tracks
	lot.add_child(track_mesh)
	return lot


## The plough's snowbanks along every edge of the lot, lumpy and uneven,
## with a gap on two sides where the access roads come in.
func _build_snowbanks() -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 21
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var snow := Color(0.92, 0.93, 0.96)
	var dirty := Color(0.70, 0.72, 0.76)
	for edge in range(4):
		var along_x := edge < 2
		var half_length: float = LOT_HALF_SIZE.x if along_x else LOT_HALF_SIZE.y
		var fixed: float = (LOT_HALF_SIZE.y if along_x else LOT_HALF_SIZE.x) * (1.0 if edge % 2 == 0 else -1.0)
		var t := -half_length
		while t < half_length:
			var length := rng.randf_range(3.0, 7.0)
			var centre := t + length / 2.0
			t += length * 0.75
			if edge == 0 and absf(centre) < 9.0 or edge == 3 and absf(centre - 20.0) < 9.0:
				continue  # entrances
			var height := SNOWBANK_HEIGHT * rng.randf_range(0.6, 1.25)
			var width := rng.randf_range(3.0, 4.5)
			var at := Vector3(centre, 0, fixed) if along_x else Vector3(fixed, 0, centre)
			var radii := Vector3(length * 0.65, height, width / 2.0) if along_x else Vector3(width / 2.0, height, length * 0.65)
			_mound(st, at, radii, snow, dirty)
	st.generate_normals()
	var banks := MeshInstance3D.new()
	banks.name = "Snowbanks"
	banks.mesh = st.commit()
	banks.material_override = _vertex_color_material(0.7)
	return banks


## More kyykkä courts alongside this one — red lines on packed snow, the
## kyykkä of a game in progress (some still stacked on the line, some
## scattered), a karttu or two lying about and a few players.
func _build_neighbour_courts() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 22
	var courts := Node3D.new()
	courts.name = "NeighbourCourts"
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pieces := SurfaceTool.new()
	pieces.begin(Mesh.PRIMITIVE_TRIANGLES)
	var line_color := GameMode.court_line_color()
	var wood := Color(0.45, 0.31, 0.19)
	var karttu := Color(0.55, 0.40, 0.24)
	var hw := COURT_SIZE.x / 2.0
	var hl := COURT_SIZE.y / 2.0
	var people_rng := RandomNumberGenerator.new()
	people_rng.seed = random_seed + 23
	var people_material := StandardMaterial3D.new()
	people_material.vertex_color_use_as_albedo = true
	people_material.roughness = 0.9

	for slot: int in NEIGHBOUR_COURTS:
		var cx := slot * (COURT_SIZE.x + LOT_COURT_GAP)
		var cz := rng.randf_range(-1.0, 1.0)
		# Boundary and the two pesä front lines, a little worn.
		for segment in [
			[Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl)], [Vector3(-hw, 0, hl), Vector3(hw, 0, hl)],
			[Vector3(-hw, 0, -hl), Vector3(-hw, 0, hl)], [Vector3(hw, 0, -hl), Vector3(hw, 0, hl)],
			[Vector3(-hw, 0, -hl + PESA_DEPTH), Vector3(hw, 0, -hl + PESA_DEPTH)],
			[Vector3(-hw, 0, hl - PESA_DEPTH), Vector3(hw, 0, hl - PESA_DEPTH)],
		]:
			var a: Vector3 = segment[0] + Vector3(cx, 0, cz)
			var b: Vector3 = segment[1] + Vector3(cx, 0, cz)
			_flat_quad(lines, (a + b) / 2.0 + Vector3(0, 0.01, 0), Vector2(maxf(absf(b.x - a.x), 0.08), maxf(absf(b.z - a.z), 0.08)), line_color.darkened(rng.randf_range(0.0, 0.15)))
		# Each end: how far that game has got.
		for end: float in [-1.0, 1.0]:
			var line_z := cz + end * (hl - PESA_DEPTH)
			var cleared := rng.randf()
			for pair in range(10):
				var x := cx - 2.25 + pair * 0.5
				if rng.randf() > cleared:
					# Still standing: a stacked pair on the line.
					_kyykka(pieces, Vector3(x, 0.05, line_z + end * 0.15), Vector3.UP, wood)
					_kyykka(pieces, Vector3(x, 0.15, line_z + end * 0.15), Vector3.UP, wood)
				else:
					# Knocked about: lying somewhere in or past the pesä.
					for k in range(2):
						var at := Vector3(x + rng.randf_range(-1.5, 1.5), 0.035, line_z + end * rng.randf_range(0.5, 7.5))
						_kyykka(pieces, at, Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)), wood)
			if rng.randf() < 0.6:
				var at := Vector3(cx + rng.randf_range(-2.0, 2.0), 0.03, line_z + end * rng.randf_range(1.0, 6.0))
				_stick(pieces, at, rng.randf() * PI, 0.85, 0.025, karttu)
		# A few players: one at each throwing line, a couple waiting their turn.
		var guild := Crowd.GUILD_COLORS[rng.randi() % Crowd.GUILD_COLORS.size()]
		var rival := Crowd.GUILD_COLORS[rng.randi() % Crowd.GUILD_COLORS.size()]
		for end: float in [-1.0, 1.0]:
			var team_color: Color = guild if end < 0 else rival
			var line_z := cz + end * (hl - PESA_DEPTH + rng.randf_range(0.3, 1.5))
			courts.add_child(_player(people_rng, Vector3(cx + rng.randf_range(-1.5, 1.5), 0, line_z), end, team_color, people_material))
			for k in range(rng.randi_range(1, 3)):
				var waiting := Vector3(cx + (hw + rng.randf_range(0.8, 2.0)) * (1.0 if rng.randf() < 0.5 else -1.0), 0, cz + end * rng.randf_range(hl - 4.0, hl + 1.0))
				courts.add_child(_player(people_rng, waiting, end, team_color, people_material))

	lines.generate_normals()
	var line_mesh := MeshInstance3D.new()
	line_mesh.name = "Lines"
	line_mesh.mesh = lines.commit()
	line_mesh.material_override = _vertex_color_material(0.8)
	courts.add_child(line_mesh)
	pieces.generate_normals()
	var piece_mesh := MeshInstance3D.new()
	piece_mesh.name = "Kyykka"
	piece_mesh.mesh = pieces.commit()
	piece_mesh.material_override = _vertex_color_material(0.8)
	courts.add_child(piece_mesh)
	return courts


## A player on another court in their guild's overalls, facing down the
## court toward the far end (`end` -1: from the -Z end toward +Z).
func _player(rng: RandomNumberGenerator, at: Vector3, end: float, color: Color, material: Material) -> MeshInstance3D:
	var look := SpectatorMesh.random_look(rng, color, true)
	look.can = null
	var person := MeshInstance3D.new()
	person.mesh = SpectatorMesh.build(look, SpectatorMesh.Pose.DOWN)
	person.material_override = material
	var yaw := (0.0 if end < 0 else PI) + rng.randf_range(-0.5, 0.5)
	person.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.92, 1.1)), at)
	return person


## The car rows' centre lines: north and south of the courts, clear of
## their ends (and of the crowd and the thrower's back line).
func _car_row_zs() -> Array[float]:
	return [-27.0, -47.0, 27.0, 47.0]


## One car left in the lot — someone who parked too close to the courts —
## with a plywood screen propped up between it and our court so a stray
## karttu doesn't dent it. One car mesh with its paint set through the
## same instance-paint path the old rows of cars used.
func _build_cars() -> Node3D:
	var cars := Node3D.new()
	cars.name = "Cars"
	var at := CAR_POSITION
	var facing := Basis(Vector3.UP, CAR_YAW)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# On the Compatibility renderer a MultiMesh without use_colors hands
	# the shader a black COLOR, wiping out the vertex colours; white
	# instance colours leave them as they are.
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _car_mesh(true)
	multimesh.instance_count = 1
	multimesh.set_instance_transform(0, Transform3D(facing, at))
	multimesh.set_instance_custom_data(0, Color(0.15, 0.22, 0.42))
	multimesh.set_instance_color(0, Color.WHITE)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _car_paint_material()
	cars.add_child(instance)
	cars.add_child(_build_plywood_screen())
	return cars


## Plywood sheets (1.22 x 2.44 m, the standard size) stood on edge between
## the car and the court, propped from behind on 2x4 struts, with a couple
## of sheets laid over the roof; the odd darker, weathered sheet, a strip
## of red spray paint along the front and snow along the tops.
func _build_plywood_screen() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ply := Color(0.80, 0.66, 0.45)
	var weathered := Color(0.64, 0.52, 0.36)
	var timber := Color(0.58, 0.45, 0.30)
	var snow := Color(0.93, 0.94, 0.97)
	var paint := Color(0.75, 0.10, 0.10)
	var facing := Basis(Vector3.UP, CAR_YAW)
	var xf := Transform3D(facing, CAR_POSITION)
	# The screen stands along the car's length (local Z), on whichever of
	# its sides (local ±X) faces our court at the origin.
	var to_court := xf.affine_inverse() * Vector3.ZERO
	var side := signf(to_court.x)
	var screen_x := side * 1.45
	var sheets := 4
	for i in range(sheets):
		var z := (i - (sheets - 1) / 2.0) * 1.24
		var lean := Basis(Vector3.BACK, side * -0.06)  # leaning onto the struts
		var colour := weathered if i == 2 else ply
		_oriented_box(st, xf * Transform3D(lean.scaled(Vector3(0.018, 2.0, 1.22)), Vector3(screen_x, 1.0, z)), colour)
		_oriented_box(st, xf * Transform3D(lean.scaled(Vector3(0.03, 0.05, 1.2)), Vector3(screen_x, 2.02, z)), snow)
		# A strut from the top of the sheet down to the ground behind it.
		var top := Vector3(screen_x - side * 0.08, 1.7, z)
		var foot := Vector3(screen_x - side * 0.9, 0.0, z)
		var strut := Basis(Vector3.UP, 0.0)
		var dir := (top - foot).normalized()
		var x_axis := dir.cross(Vector3.BACK).normalized()
		strut = Basis(x_axis * 0.045, dir * top.distance_to(foot), x_axis.cross(dir) * 0.09)
		_oriented_box(st, xf * Transform3D(strut, (top + foot) / 2.0), timber)
	# Spray paint across the front: a wobbly stripe.
	for i in range(sheets * 3):
		var z := (i - (sheets * 3 - 1) / 2.0) * 0.41
		var y := 1.05 + 0.08 * sin(i * 1.7)
		_oriented_box(st, xf * Transform3D(Basis.from_scale(Vector3(0.004, 0.09, 0.42)), Vector3(screen_x + side * 0.012, y, z)), paint)
	# Two sheets over the roof, weighed down with snow.
	for i in range(2):
		var z := (i - 0.5) * 1.24
		_oriented_box(st, xf * Transform3D(Basis.from_scale(Vector3(1.22, 0.018, 1.22)), Vector3(0, 1.52, z)), ply if i == 0 else weathered)
		_oriented_box(st, xf * Transform3D(Basis.from_scale(Vector3(1.1, 0.06, 1.1)), Vector3(0.05, 1.56, z)), snow)
	st.generate_normals()
	var screen := MeshInstance3D.new()
	screen.name = "PlywoodScreen"
	screen.mesh = st.commit()
	screen.material_override = _vertex_color_material(0.9)
	return screen


## One car, facing +Z: body (painted with the instance colour — vertex
## colour PAINT_MARKER), glass, wheels, lights and a snow cap on the roof, bonnet
## and boot (vertex colours that ignore the paint; see _car_paint_material()).
## `estate` is a longer, boxier roofline.
func _car_mesh(estate: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := PAINT_MARKER
	var glass := Color(0.10, 0.13, 0.17)
	var tyre := Color(0.05, 0.05, 0.05)
	var snow := Color(0.93, 0.94, 0.97)
	var light := Color(0.95, 0.92, 0.8)
	var tail := Color(0.6, 0.05, 0.05)
	var length := 4.7 if estate else 4.4
	# Lower body and the cabin.
	_box(st, Vector3(0, 0.55, 0), Vector3(1.8, 0.6, length), paint)
	var cabin_length := length * (0.62 if estate else 0.5)
	var cabin_z := -0.35 if estate else -0.1
	_box(st, Vector3(0, 1.08, cabin_z), Vector3(1.62, 0.5, cabin_length), glass)
	_box(st, Vector3(0, 1.08, cabin_z), Vector3(1.66, 0.36, cabin_length - 0.5), paint)  # pillars between the windows
	_box(st, Vector3(0, 1.34, cabin_z), Vector3(1.6, 0.04, cabin_length - 0.1), paint)
	# Snow on roof, bonnet and boot.
	_box(st, Vector3(0, 1.42, cabin_z), Vector3(1.58, 0.12, cabin_length - 0.15), snow)
	_box(st, Vector3(0, 0.9, length / 2.0 - 0.6), Vector3(1.7, 0.1, 1.0), snow)
	if not estate:
		_box(st, Vector3(0, 0.9, -length / 2.0 + 0.45), Vector3(1.7, 0.08, 0.7), snow)
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			_box(st, Vector3(side * 0.8, 0.32, end * length * 0.32), Vector3(0.25, 0.64, 0.64), tyre)
		_box(st, Vector3(side * 0.6, 0.65, length / 2.0 + 0.01), Vector3(0.35, 0.12, 0.04), light)
		_box(st, Vector3(side * 0.65, 0.68, -length / 2.0 - 0.01), Vector3(0.3, 0.14, 0.04), tail)
	st.generate_normals()
	return st.commit()


## Cars' material: PAINT_MARKER vertices take the instance's paint
## (custom data); the rest keep their vertex colour (glass, tyres,
## lights, snow).
func _car_paint_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 paint;
varying float painted;
void vertex() {
	paint = INSTANCE_CUSTOM.rgb;
	painted = step(distance(COLOR.rgb, vec3(1.0, 0.0, 1.0)), 0.05);
}
void fragment() {
	ALBEDO = mix(COLOR.rgb, paint, painted);
	ROUGHNESS = mix(0.6, 0.3, painted);
	SPECULAR = mix(0.3, 0.6, painted);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## Lamp posts down the middle of each car row and along the courts' ends.
func _build_lamps() -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pole := Color(0.30, 0.31, 0.33)
	var head := Color(0.85, 0.85, 0.80)
	for row_z in _car_row_zs():
		var x := -LOT_HALF_SIZE.x + 12.0
		while x < LOT_HALF_SIZE.x - 6.0:
			_box(st, Vector3(x, 4.0, row_z), Vector3(0.16, 8.0, 0.16), pole)
			_box(st, Vector3(x, 0.4, row_z), Vector3(0.6, 0.8, 0.6), Color(0.75, 0.75, 0.73))  # concrete footing
			for side: float in [-1.0, 1.0]:
				_box(st, Vector3(x, 7.9, row_z + side * 0.8), Vector3(0.1, 0.1, 1.6), pole)
				_box(st, Vector3(x, 7.8, row_z + side * 1.5), Vector3(0.4, 0.15, 0.7), head)
				_box(st, Vector3(x, 7.98, row_z + side * 1.5), Vector3(0.38, 0.06, 0.66), Color(0.93, 0.94, 0.97))
			x += 22.0
	st.generate_normals()
	var lamps := MeshInstance3D.new()
	lamps.name = "Lamps"
	lamps.mesh = st.commit()
	lamps.material_override = _vertex_color_material(0.6)
	return lamps


## An office park around the lot: OFFICE_COUNT separate blocks of about
## six storeys (five to seven) with open snow between them, glass curtain
## walls or punched windows in brick/concrete, snow on the flat roofs. The same unit-box
## MultiMesh and shader as the tower mode's city.
func _build_offices() -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 25
	var buildings: Array[Dictionary] = []
	# Hermia-style: red-brown brick, light render, grey panels.
	var palette: Array[Color] = [
		Color(0.52, 0.30, 0.22), Color(0.58, 0.36, 0.27), Color(0.84, 0.82, 0.78),
		Color(0.74, 0.72, 0.68), Color(0.42, 0.45, 0.50), Color(0.30, 0.32, 0.36),
	]
	var start := rng.randf() * TAU
	for i in range(OFFICE_COUNT):
		var angle := start + (i + rng.randf_range(-0.3, 0.3)) * TAU / OFFICE_COUNT
		var distance := rng.randf_range(OFFICE_RING.x, OFFICE_RING.y)
		var width := rng.randf_range(24.0, 60.0)
		var depth := rng.randf_range(14.0, 22.0)
		var storeys := rng.randi_range(5, 7)
		var at := Vector2(cos(angle), sin(angle)) * distance
		# Keep them off the lot and its banks: push out along the same bearing.
		while absf(at.x) < LOT_HALF_SIZE.x + depth and absf(at.y) < LOT_HALF_SIZE.y + depth:
			at *= 1.1
		# Long side roughly facing the lot.
		var yaw := atan2(at.x, at.y) + rng.randf_range(-0.15, 0.15)
		var glassy := rng.randf()
		var style := Vector4(rng.randf_range(1.6, 2.6), OFFICE_FLOOR, rng.randf_range(0.02, 0.1), glassy)
		var color := palette[rng.randi() % palette.size()]
		var height := storeys * OFFICE_FLOOR + 0.6
		var basis := Basis(Vector3.UP, yaw)
		buildings.append(_building(basis, Vector3(at.x, height / 2.0, at.y), Vector3(width, height, depth), color, style))
		# A plant room on the roof, and some L-shaped with a wing.
		buildings.append(_building(basis, Vector3(at.x, height + 1.5, at.y) + basis * Vector3(rng.randf_range(-width, width) * 0.3, 0, 0), Vector3(6.0, 3.0, 5.0), Color(0.6, 0.6, 0.6), Vector4(1.0, 10.0, 0.0, 0.0)))
		if rng.randf() < 0.4:
			var wing_height := (storeys - rng.randi_range(0, 2)) * OFFICE_FLOOR + 0.6
			var wing := basis * Vector3(width / 2.0 - depth / 2.0, 0, -depth)
			buildings.append(_building(basis, Vector3(at.x + wing.x, wing_height / 2.0, at.y + wing.z), Vector3(depth, wing_height, depth * 1.4), color, style))

	var material := ShaderMaterial.new()
	material.shader = BUILDING_SHADER
	material.set_shader_parameter("street_level", 0.0)
	material.set_shader_parameter("sky_reflection", _atmosphere().sky_horizon)
	material.set_shader_parameter("roof_snow", 1.0)
	material.set_shader_parameter("lit_window_energy", 0.35)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = buildings.size()
	for i in range(buildings.size()):
		multimesh.set_instance_transform(i, buildings[i].transform)
		multimesh.set_instance_color(i, buildings[i].color)
		var style: Vector4 = buildings[i].style
		multimesh.set_instance_custom_data(i, Color(style.x, style.y, style.z, style.w))
	var offices := MultiMeshInstance3D.new()
	offices.name = "Offices"
	offices.multimesh = multimesh
	offices.material_override = material
	return offices


func _building(basis: Basis, position: Vector3, size: Vector3, color: Color, style: Vector4) -> Dictionary:
	return {"transform": Transform3D(basis * Basis.from_scale(size), position), "color": color, "style": style}


# Shared bits -----------------------------------------------------------------

func _vertex_color_material(roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	return material


## A flat rectangle on the ground (`size` along X and Z) at `centre`.
func _flat_quad(st: SurfaceTool, centre: Vector3, size: Vector2, color: Color) -> void:
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	st.set_color(color)
	for corner in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		st.add_vertex(centre + corner)


## An axis-aligned box.
func _box(st: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	_oriented_box(st, Transform3D(Basis.from_scale(size), centre), color)


func _oriented_box(st: SurfaceTool, xf: Transform3D, color: Color) -> void:
	st.set_color(color)
	for face in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]:
		var n: Vector3 = face[0] * 0.5
		var u: Vector3 = face[1] * 0.5
		var v: Vector3 = face[2] * 0.5
		for corner in [n - u - v, n + u + v, n + u - v, n - u - v, n - u + v, n + u + v]:
			st.add_vertex(xf * corner)


## One kyykkä (a squat 10 x 7 cm cylinder, as a box at this distance)
## standing along `up`.
func _kyykka(st: SurfaceTool, centre: Vector3, up: Vector3, color: Color) -> void:
	var y := up.normalized()
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(x * 0.07, y * 0.1, x.cross(y) * 0.07)
	_oriented_box(st, Transform3D(basis, centre), color)


## A stick lying flat on the ground (a karttu), turned `yaw`.
func _stick(st: SurfaceTool, centre: Vector3, yaw: float, length: float, thickness: float, color: Color) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(length, thickness * 2.0, thickness * 2.0))
	_oriented_box(st, Transform3D(basis, centre), color)


## A ploughed snow mound: a squashed, lumpy half-ellipsoid, grubby at the base.
func _mound(st: SurfaceTool, centre: Vector3, radii: Vector3, top_color: Color, base_color: Color) -> void:
	var sides := 10
	var rings := 4
	var points := []
	for r in range(rings + 1):
		var theta := PI / 2.0 * float(r) / rings
		var ring := []
		for s in range(sides):
			var phi := TAU * s / sides
			var wobble := 1.0 + 0.12 * sin(phi * 3.0 + centre.x * 0.7 + centre.z * 0.3)
			ring.append(centre + Vector3(cos(phi) * cos(theta) * radii.x * wobble, sin(theta) * radii.y, sin(phi) * cos(theta) * radii.z * wobble))
		points.append(ring)
	for r in range(rings):
		var c0 := base_color.lerp(top_color, minf(float(r) / 1.5, 1.0))
		var c1 := base_color.lerp(top_color, minf(float(r + 1) / 1.5, 1.0))
		for s in range(sides):
			var n := (s + 1) % sides
			for v in [[points[r][s], c0], [points[r + 1][n], c1], [points[r + 1][s], c1], [points[r][s], c0], [points[r][n], c0], [points[r + 1][n], c1]]:
				st.set_color(v[1])
				st.add_vertex(v[0])


## One spruce: a short trunk plus stacked cone tiers, each fading from dark
## green at its lower edge to snow on its upper slope, via vertex colours.
func _build_tree_mesh(_variant: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 9
	var bark := Color(0.23, 0.16, 0.11)
	var needles := Color(0.04, 0.12, 0.07)
	var dusted := Color(0.55, 0.62, 0.64)
	var snow := Color(0.97, 0.98, 1.0)

	_add_frustum(st, sides, 0.0, 1.4, 0.2, 0.16, bark, bark)
	var tiers := 5
	for t in range(tiers):
		var f := float(t) / (tiers - 1)
		var base_y := lerpf(1.0, 6.4, f)
		var tier_height := lerpf(2.8, 2.2, f)
		var radius := lerpf(2.3, 0.8, f)
		# Underside, so looking up at a tier doesn't show through it.
		_add_frustum(st, sides, base_y, base_y, 0.0, radius, needles, needles)
		_add_frustum(st, sides, base_y, base_y + tier_height * 0.3, radius, radius * 0.7, needles, dusted)
		_add_frustum(st, sides, base_y + tier_height * 0.3, base_y + tier_height, radius * 0.7, 0.0, dusted, snow)
	st.generate_normals()

	st.set_material(_tree_material())
	return st.commit()


## Light snowfall over the whole court, already under way when the match
## starts (preprocess). Tiny soft billboards drifting slightly with the wind.
func _build_snowfall() -> CPUParticles3D:
	var flake_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			flake_image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	var flake_mat := StandardMaterial3D.new()
	flake_mat.albedo_texture = ImageTexture.create_from_image(flake_image)
	flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var flake := QuadMesh.new()
	flake.size = Vector2(0.035, 0.035)
	flake.material = flake_mat

	var snowfall := CPUParticles3D.new()
	snowfall.name = "Snowfall"
	snowfall.mesh = flake
	snowfall.amount = snowfall_amount
	snowfall.lifetime = 14.0
	snowfall.preprocess = 14.0
	snowfall.position = Vector3(0, 12, 0)
	snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snowfall.emission_box_extents = Vector3(18, 0.5, 24)
	snowfall.direction = Vector3(0.25, -1.0, 0.1)
	snowfall.spread = 12.0
	snowfall.initial_velocity_min = 0.6
	snowfall.initial_velocity_max = 1.1
	snowfall.gravity = Vector3(0.05, -0.12, 0.0)
	snowfall.scale_amount_min = 0.6
	snowfall.scale_amount_max = 1.4
	return snowfall

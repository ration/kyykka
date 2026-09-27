class_name WinterLandscape
extends Node3D
## Winter-mode scenery around the court, all generated at runtime like the
## court itself (see court.gd): a snowfield that stays flat around the court
## and rolls up into distant hills, a scattered snow-capped spruce forest,
## and light snowfall. Purely visual — nothing here has collision, and the
## flat zone around the court covers the ground collision court.gd builds,
## so no scenery pokes up through the playing surface.
##
## court.gd adds this in winter only, calling apply_atmosphere() (sky, sun,
## fog, tonemapping) *before* adding it to the tree — the snowfield's glints
## need the final sun direction — and snow_material() for the court plane
## itself, so the court and the field around it share one snow look.

@export var field_size: float = 700.0  ## metres per side of the square snowfield mesh
@export var field_cells: int = 140     ## grid cells per side (5 m each at the defaults)
@export var flat_half_width: float = 9.0   ## flat zone around the court, X half-extent
@export var flat_half_length: float = 16.0 ## flat zone around the court, Z half-extent
@export var roll_height: float = 1.5   ## gentle undulation amplitude once clear of the court
@export var hill_start_radius: float = 110.0
@export var hill_end_radius: float = 300.0
@export var hill_min_height: float = 12.0
@export var hill_max_height: float = 55.0
@export var tree_count: int = 650
@export var tree_min_clearance: float = 14.0  ## metres from the flat zone to the nearest tree
@export var tree_max_radius: float = 230.0
@export var snowfall_amount: int = 2500
@export var random_seed: int = 7  ## fixed so every winter match gets the same landscape

const SNOW_SHADER := preload("res://shaders/snow.gdshader")

var _roll_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _mottle_texture: ImageTexture
var _normal_texture: ImageTexture
var _sun: DirectionalLight3D


func _init() -> void:
	name = "WinterLandscape"
	_roll_noise.seed = random_seed
	_roll_noise.frequency = 0.012
	_hill_noise.seed = random_seed + 1
	_hill_noise.frequency = 0.9
	_build_snow_textures()


func _ready() -> void:
	add_child(_build_field())
	add_child(_build_forest())
	add_child(_build_snowfall())


## Cold, pale sky with a low sun: long shadows across the snow pick out its
## surface texture. Fog blends the distant hills and the field's edge into
## the horizon.
##
## Tuned by sampling rendered pixels (tools/screenshot.gd), not by eye from
## the numbers. Two findings on the Compatibility renderer: sky-sourced
## ambient light washed the snow out to saturated blue and ignored
## ambient_light_energy entirely, so ambient is an explicit colour here; and
## filmic tonemapping *brightened* the snow into clipping rather than
## rolling it off, so tonemapping stays linear and the snow albedo is kept
## below white instead.
func apply_atmosphere(world_environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.58, 0.80)
	sky_material.sky_horizon_color = Color(0.82, 0.87, 0.93)
	sky_material.ground_horizon_color = Color(0.82, 0.87, 0.93)
	sky_material.ground_bottom_color = Color(0.90, 0.93, 0.97)
	var sky := Sky.new()
	sky.sky_material = sky_material

	# Duplicated rather than edited in place: court.tscn's Environment is a
	# shared resource, so edits would leak into a later summer match.
	var env: Environment = world_environment.environment.duplicate()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.85)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.85, 0.92)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	world_environment.environment = env

	# Low (~17°) and off to one side, so shadows fall diagonally across the court.
	sun.global_rotation = Vector3(deg_to_rad(-17.0), deg_to_rad(35.0), 0.0)
	sun.light_color = Color(1.0, 0.91, 0.80)
	sun.light_energy = 0.9
	sun.directional_shadow_max_distance = 120.0
	_sun = sun


## Snow material for any ground surface. `packed` is the trodden court:
## flatter, less mottled and less sparkly than fresh snow.
func snow_material(packed: bool) -> ShaderMaterial:
	assert(_sun != null, "call apply_atmosphere() first")
	var mat := ShaderMaterial.new()
	mat.shader = SNOW_SHADER
	mat.set_shader_parameter("mottle_noise", _mottle_texture)
	mat.set_shader_parameter("detail_normal", _normal_texture)
	# The DirectionalLight3D shines along its -Z; the shader wants the direction toward the sun.
	mat.set_shader_parameter("sun_direction", _sun.global_transform.basis.z.normalized())
	if packed:
		mat.set_shader_parameter("snow_color", GameMode.ground_high_color())
		mat.set_shader_parameter("hollow_color", GameMode.ground_low_color())
		mat.set_shader_parameter("mottle_contrast", 0.9)
		mat.set_shader_parameter("normal_depth", 0.3)
		mat.set_shader_parameter("sparkle_amount", 0.025)
		mat.set_shader_parameter("roughness_value", 0.6)
	return mat


## Terrain height at a world XZ position: zero across the flat zone around
## the court, gentle rolls once clear of it, rising into a ring of hills.
func height_at(x: float, z: float) -> float:
	var dx := maxf(absf(x) - flat_half_width, 0.0)
	var dz := maxf(absf(z) - flat_half_length, 0.0)
	var clear_of_court := smoothstep(0.0, 30.0, sqrt(dx * dx + dz * dz))
	var height := _roll_noise.get_noise_2d(x, z) * roll_height * clear_of_court

	var radius := Vector2(x, z).length()
	var toward_hills := smoothstep(hill_start_radius, hill_end_radius, radius)
	if toward_hills > 0.0:
		# Sampled on a unit circle so the hill silhouette wraps around seamlessly.
		var angle := atan2(z, x)
		var ridge := _hill_noise.get_noise_2d(cos(angle), sin(angle)) * 0.5 + 0.5
		ridge = clampf(ridge * 0.8 + (_roll_noise.get_noise_2d(x * 0.5, z * 0.5) * 0.5 + 0.5) * 0.4, 0.0, 1.0)
		height += toward_hills * lerpf(hill_min_height, hill_max_height, ridge)
	return height


func _build_snow_textures() -> void:
	var mottle := FastNoiseLite.new()
	mottle.seed = random_seed + 2
	mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mottle.frequency = 0.02
	mottle.fractal_octaves = 3
	var mottle_image := mottle.get_seamless_image(256, 256)
	mottle_image.generate_mipmaps()
	_mottle_texture = ImageTexture.create_from_image(mottle_image)

	var bumps := FastNoiseLite.new()
	bumps.seed = random_seed + 3
	bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bumps.frequency = 0.05
	bumps.fractal_octaves = 4
	var bump_image := bumps.get_seamless_image(256, 256)
	bump_image.convert(Image.FORMAT_RGBA8)
	bump_image.bump_map_to_normal_map(4.0)
	bump_image.generate_mipmaps()
	_normal_texture = ImageTexture.create_from_image(bump_image)


func _build_field() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := field_size / field_cells
	var half := field_size / 2.0
	for iz in range(field_cells + 1):
		for ix in range(field_cells + 1):
			var x := -half + ix * cell
			var z := -half + iz * cell
			st.set_uv(Vector2(ix, iz))
			st.add_vertex(Vector3(x, height_at(x, z), z))
	var row := field_cells + 1
	for iz in range(field_cells):
		for ix in range(field_cells):
			var i := iz * row + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row)
			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i + row)
	st.generate_normals()
	st.generate_tangents()

	var field := MeshInstance3D.new()
	field.name = "Snowfield"
	field.mesh = st.commit()
	# Just below the court plane (y = 0) so the two don't z-fight in the flat zone.
	field.position.y = -0.02
	field.material_override = snow_material(false)
	return field


func _build_forest() -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var clumping := FastNoiseLite.new()
	clumping.seed = random_seed + 4
	clumping.frequency = 0.02

	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < tree_count and attempts < tree_count * 20:
		attempts += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * tree_max_radius
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var dx := maxf(absf(x) - flat_half_width, 0.0)
		var dz := maxf(absf(z) - flat_half_length, 0.0)
		if sqrt(dx * dx + dz * dz) < tree_min_clearance:
			continue
		# Clumps of forest with open clearings between them, not an even sprinkle.
		if clumping.get_noise_2d(x, z) < -0.05:
			continue
		var scale := rng.randf_range(0.7, 1.5)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.9, 1.15), scale))
		transforms.append(Transform3D(basis, Vector3(x, height_at(x, z) - 0.1, z)))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _build_spruce_mesh()
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var forest := MultiMeshInstance3D.new()
	forest.name = "Forest"
	forest.multimesh = multimesh
	return forest


## One spruce: a short trunk plus stacked cone tiers, each fading from dark
## green at its lower edge to snow on its upper slope, via vertex colours
## (so the whole forest is one mesh, one material and one draw call).
func _build_spruce_mesh() -> ArrayMesh:
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

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	st.set_material(mat)
	return st.commit()


## A cone section between two rings (bottom_radius at y0, top_radius at y1),
## coloured bottom_color -> top_color.
func _add_frustum(st: SurfaceTool, sides: int, y0: float, y1: float, bottom_radius: float, top_radius: float, bottom_color: Color, top_color: Color) -> void:
	for s in range(sides):
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var b0 := Vector3(cos(a0) * bottom_radius, y0, sin(a0) * bottom_radius)
		var b1 := Vector3(cos(a1) * bottom_radius, y0, sin(a1) * bottom_radius)
		var t0 := Vector3(cos(a0) * top_radius, y1, sin(a0) * top_radius)
		var t1 := Vector3(cos(a1) * top_radius, y1, sin(a1) * top_radius)
		for v in [[b0, bottom_color], [t1, top_color], [t0, top_color], [b0, bottom_color], [b1, bottom_color], [t1, top_color]]:
			st.set_color(v[1])
			st.add_vertex(v[0])


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

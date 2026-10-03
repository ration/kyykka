class_name Landscape
extends Node3D
## Scenery around the court, all generated at runtime like the court itself
## (see court.gd): a ground field that stays flat around the court and rolls
## up into a ring of distant hills, a scattered forest, and a sky/sun/fog
## setup. Purely visual — nothing here has collision, and the flat zone
## around the court covers the ground collision court.gd builds, so no
## scenery pokes up through the playing surface.
##
## Each season is a subclass (WinterLandscape, SummerLandscape) supplying the
## season-specific parts through the hooks at the bottom: ground look, tree
## mesh, sky/sun, extras. court.gd builds the one for GameMode.current,
## calling apply_atmosphere() *before* adding it to the tree (the ground's
## sun-dependent effects need the final sun direction), and court_material()
## for the court plane itself.

@export var field_size: float = 700.0  ## metres per side of the square field mesh
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
@export var random_seed: int = 7  ## fixed so every match of a season gets the same landscape

const GROUND_SHADER := preload("res://shaders/ground.gdshader")

var _roll_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _mottle_texture: ImageTexture
var _normal_texture: ImageTexture
var _sun: DirectionalLight3D


func _init() -> void:
	name = "Landscape"
	_roll_noise.seed = random_seed
	_roll_noise.frequency = 0.012
	_hill_noise.seed = random_seed + 1
	_hill_noise.frequency = 0.9
	_build_ground_textures()


func _ready() -> void:
	add_child(_build_field())
	add_child(_build_forest())
	_add_extras()


## Sets up sky, sun, ambient light and fog for the season (_atmosphere()).
##
## Tuned by sampling rendered pixels (tools/screenshot.gd), not by eye from
## the numbers. Two findings on the Compatibility renderer: sky-sourced
## ambient light washed the ground out to saturated blue and ignored
## ambient_light_energy entirely, so ambient is an explicit colour here; and
## filmic tonemapping *brightened* bright ground (snow) into clipping rather
## than rolling it off, so tonemapping stays linear.
func apply_atmosphere(world_environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var a := _atmosphere()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = a.sky_top
	sky_material.sky_horizon_color = a.sky_horizon
	sky_material.ground_horizon_color = a.sky_horizon
	sky_material.ground_bottom_color = a.sky_ground
	var sky := Sky.new()
	sky.sky_material = sky_material

	# Duplicated rather than edited in place: court.tscn's Environment is a
	# shared resource, so edits would leak into a later match of the other season.
	var env: Environment = world_environment.environment.duplicate()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = a.ambient_color
	env.ambient_light_energy = a.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = a.fog_color
	env.fog_density = a.fog_density
	env.fog_sky_affect = 0.0
	world_environment.environment = env

	sun.global_rotation = Vector3(deg_to_rad(-a.sun_elevation), deg_to_rad(a.sun_yaw), 0.0)
	sun.light_color = a.sun_color
	sun.light_energy = a.sun_energy
	sun.directional_shadow_max_distance = 120.0
	_sun = sun


## Ground shader material with this season's look. `packed` is for the court
## plane itself where the season uses the same ground for it (winter's
## trodden snow), rather than the surrounding field.
func ground_material(packed: bool) -> ShaderMaterial:
	assert(_sun != null, "call apply_atmosphere() first")
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("mottle_noise", _mottle_texture)
	mat.set_shader_parameter("detail_normal", _normal_texture)
	# The DirectionalLight3D shines along its -Z; the shader wants the direction toward the sun.
	mat.set_shader_parameter("sun_direction", _sun.global_transform.basis.z.normalized())
	var parameters := _ground_parameters(packed)
	for key in parameters:
		mat.set_shader_parameter(key, parameters[key])
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


# Season hooks -----------------------------------------------------------------

## Sky, sun, ambient and fog settings for apply_atmosphere(), as a Dictionary
## with keys sky_top, sky_horizon, sky_ground, ambient_color, ambient_energy,
## fog_color, fog_density, sun_elevation (degrees), sun_yaw (degrees),
## sun_color, sun_energy.
func _atmosphere() -> Dictionary:
	push_error("Landscape subclasses must override _atmosphere()")
	return {}


## shaders/ground.gdshader uniform overrides for this season's ground.
func _ground_parameters(_packed: bool) -> Dictionary:
	return {}


## Material for the court plane, or null to keep court.gd's own.
func court_material() -> Material:
	return null


## How many different tree meshes to scatter (one MultiMesh each), so the
## forest isn't one tree endlessly rotated.
func _tree_variant_count() -> int:
	return 1


## One tree mesh (variant in [0, _tree_variant_count())), instanced across
## the forest.
func _build_tree_mesh(_variant: int) -> Mesh:
	push_error("Landscape subclasses must override _build_tree_mesh()")
	return null


## Whether a tree may stand at (x, z), beyond the flat-zone clearance
## (winter keeps them out of the office buildings).
func _tree_allowed(_x: float, _z: float) -> bool:
	return true


## Anything else the season adds (winter's snowfall).
func _add_extras() -> void:
	pass


# Shared builders --------------------------------------------------------------

func _build_ground_textures() -> void:
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
	field.name = "Field"
	field.mesh = st.commit()
	# Just below the court plane (y = 0) so the two don't z-fight in the flat zone.
	field.position.y = -0.02
	field.material_override = ground_material(false)
	return field


func _build_forest() -> Node3D:
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
		if clumping.get_noise_2d(x, z) < -0.05 or not _tree_allowed(x, z):
			continue
		var scale := rng.randf_range(0.7, 1.5)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.9, 1.15), scale))
		transforms.append(Transform3D(basis, Vector3(x, height_at(x, z) - 0.1, z)))

	var forest := Node3D.new()
	forest.name = "Forest"
	var variants := _tree_variant_count()
	for variant in range(variants):
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _build_tree_mesh(variant)
		var mine := range(variant, transforms.size(), variants)
		multimesh.instance_count = mine.size()
		for i in range(mine.size()):
			multimesh.set_instance_transform(i, transforms[mine[i]])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		forest.add_child(instance)
	return forest


## Vertex-coloured material for tree meshes, so each tree variant is one
## mesh, one material and one draw call for the whole forest.
func _tree_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	return mat


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

class_name WinterLandscape
extends Landscape
## Winter scenery (see Landscape): a snowfield with the court as packed snow,
## snow-capped spruces, a low sun with long shadows, a pale sky, and light
## snowfall.

@export var snowfall_amount: int = 2500


func _init() -> void:
	super._init()
	name = "WinterLandscape"


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


## Fresh snow around the court; `packed` (the court) is flatter, less
## mottled and less sparkly. Snow albedo stays below white — see
## Landscape.apply_atmosphere() for why white snow clipped.
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


func _add_extras() -> void:
	add_child(_build_snowfall())


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

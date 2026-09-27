class_name SummerLandscape
extends Landscape
## Summer scenery (see Landscape): a grass field around the sand court (the
## court keeps court.gd's own sand texture), birch forest, a high warm sun
## and a clear blue sky.


func _init() -> void:
	super._init()
	name = "SummerLandscape"


func _atmosphere() -> Dictionary:
	return {
		sky_top = Color(0.28, 0.50, 0.84),
		sky_horizon = Color(0.72, 0.82, 0.92),
		sky_ground = Color(0.52, 0.60, 0.48),
		ambient_color = Color(0.60, 0.66, 0.74),
		ambient_energy = 0.5,
		fog_color = Color(0.74, 0.82, 0.91),
		fog_density = 0.0012,
		sun_elevation = 42.0,
		sun_yaw = 35.0,
		sun_color = Color(1.0, 0.96, 0.88),
		sun_energy = 1.0,
	}


## Grass: greener/yellower patches at two scales and a finer, rougher bump
## than snow; no glints.
func _ground_parameters(_packed: bool) -> Dictionary:
	return {
		bright_color = Color(0.46, 0.60, 0.24),
		dark_color = Color(0.24, 0.38, 0.13),
		mottle_contrast = 1.5,
		fine_mottle_scale = 7.0,
		fine_mottle_weight = 0.35,
		detail_scale = 1.6,
		normal_depth = 0.7,
		roughness_value = 0.9,
		specular_value = 0.15,
	}


func _tree_variant_count() -> int:
	return 4


## One birch: a slender white trunk with irregular dark bark bands (darker
## and rougher at the base, as on real birches), under an airy, irregular
## crown of separate lumpy leaf clusters with gaps between them where the
## trunk shows through. Each variant gets its own random crown and banding.
func _build_tree_mesh(variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 5 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var bark_white := Color(0.88, 0.87, 0.83)
	var bark_dark := Color(0.13, 0.12, 0.11)
	var base_grey := Color(0.30, 0.28, 0.25)

	var trunk_height := 10.5
	var y := 0.0
	while y < trunk_height:
		var f := y / trunk_height
		var segment := rng.randf_range(0.12, 0.45)
		var color := bark_white
		if y < 0.7:
			color = base_grey.lerp(bark_white, y / 0.7 * 0.5)
		elif rng.randf() < 0.3:
			color = bark_dark
			segment = rng.randf_range(0.04, 0.1)  # the dark bands are thin
		var y1 := minf(y + segment, trunk_height)
		_add_frustum(st, sides, y, y1, lerpf(0.17, 0.05, f), lerpf(0.17, 0.05, y1 / trunk_height), color, color)
		y = y1

	var leaf_light := Color(0.58, 0.73, 0.28)
	var leaf_dark := Color(0.27, 0.43, 0.14)
	var clusters := rng.randi_range(13, 16)
	for c in range(clusters):
		var f := float(c) / (clusters - 1)
		# Many smaller, overlapping clusters forming one loose, irregular
		# crown: widest a little above the middle and hanging lower at the
		# sides. Fewer, larger ones read as a column (too few gaps) or as
		# separate pom-poms (too much gap).
		var spread := sin(lerpf(0.3, 1.0, f) * PI) * rng.randf_range(1.1, 2.1)
		var angle := rng.randf() * TAU
		var center := Vector3(cos(angle) * spread, lerpf(5.6, 11.3, f) - spread * 0.5 + rng.randf_range(-0.3, 0.3), sin(angle) * spread)
		var width := lerpf(1.25, 0.75, f) * rng.randf_range(0.8, 1.2)
		var radii := Vector3(width, width * rng.randf_range(0.7, 0.9), width * rng.randf_range(0.8, 1.0))
		_add_leaf_cluster(st, rng, center, radii, leaf_light.lerp(leaf_dark, rng.randf() * 0.35), leaf_dark)
	st.generate_normals()
	st.set_material(_tree_material())
	return st.commit()


## A lumpy low-poly ellipsoid: lighter on top, shaded underneath.
func _add_leaf_cluster(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, radii: Vector3, top_color: Color, bottom_color: Color) -> void:
	var longitudes := 9
	var latitudes := 6
	# Vertices first (shared between neighbouring faces) so the jitter stays watertight.
	var rings: Array = []
	for lat in range(latitudes + 1):
		var theta := PI * lat / latitudes  # 0 = bottom pole, PI = top pole
		var ring: Array[Vector3] = []
		for lon in range(longitudes):
			var phi := TAU * lon / longitudes
			var jitter := rng.randf_range(0.8, 1.15) if lat > 0 and lat < latitudes else 1.0
			ring.append(center + Vector3(
				sin(theta) * cos(phi) * radii.x * jitter,
				-cos(theta) * radii.y * jitter,
				sin(theta) * sin(phi) * radii.z * jitter
			))
		rings.append(ring)
	for lat in range(latitudes):
		var bottom_color_here := bottom_color.lerp(top_color, float(lat) / latitudes)
		var top_color_here := bottom_color.lerp(top_color, float(lat + 1) / latitudes)
		for lon in range(longitudes):
			var next := (lon + 1) % longitudes
			var b0: Vector3 = rings[lat][lon]
			var b1: Vector3 = rings[lat][next]
			var t0: Vector3 = rings[lat + 1][lon]
			var t1: Vector3 = rings[lat + 1][next]
			# Same winding as Landscape._add_frustum.
			for v in [[b0, bottom_color_here], [t1, top_color_here], [t0, top_color_here], [b0, bottom_color_here], [b1, bottom_color_here], [t1, top_color_here]]:
				st.set_color(v[1])
				st.add_vertex(v[0])

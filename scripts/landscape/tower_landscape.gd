class_name TowerLandscape
extends Landscape
## Tower scenery (see Landscape): the court is painted on the roof of a
## skyscraper, TOWER_HEIGHT above the street, and all around is a metropolis
## in the low late-afternoon sun. Replaces the base field and forest
## entirely (_ready() doesn't call super).
##
## Unlike the other landscapes this one has collision: the roof deck and its
## parapet, plus the rooftop plant room and water tank. The court's own
## ground collision (court.gd) only reaches ground_margin past the lines,
## and here a piece knocked past it would sink through the visible roof, so
## the whole deck is solid and the parapet keeps everything on the roof.
##
## The city is one MultiMesh of unit boxes (scaled per instance, windows
## drawn by shaders/building.gdshader from world position), laid out on a
## street grid: shorter blocks near the tower so you look down on them, a
## downtown of taller ones further out, and a few supertalls that rise above
## the roof into the skyline.

const TOWER_HEIGHT := 160.0
const ROOF_SIZE := Vector2(26.0, 44.0)  ## the tower's footprint, X x Z
const PARAPET_HEIGHT := 1.1
const PARAPET_THICKNESS := 0.3
const BLOCK_PITCH := 64.0  ## street grid spacing
const STREET_WIDTH := 16.0
const CITY_RADIUS := 1500.0
const NEAR_RADIUS := 140.0  ## buildings this close stay below the roof
const BUILDING_SHADER := preload("res://shaders/building.gdshader")

var _beacon: MeshInstance3D
var _time: float = 0.0


func _init() -> void:
	super._init()
	name = "TowerLandscape"


func _ready() -> void:
	add_child(_build_roof())
	add_child(_build_parapet())
	add_child(_build_roof_plant())
	add_child(_build_city())
	add_child(_build_streets())


func _process(delta: float) -> void:
	# Aviation warning light on the mast: a short blink every 1.5 s.
	_time += delta
	_beacon.visible = fmod(_time, 1.5) < 0.25


func _atmosphere() -> Dictionary:
	return {
		sky_top = Color(0.30, 0.48, 0.78),
		sky_horizon = Color(0.92, 0.80, 0.64),
		sky_ground = Color(0.62, 0.58, 0.54),
		ambient_color = Color(0.66, 0.64, 0.68),
		ambient_energy = 0.5,
		fog_color = Color(0.86, 0.78, 0.68),
		fog_density = 0.0011,
		# Late afternoon: low and warm, so the city's facades pick up long
		# shadows and the glass catches the light.
		sun_elevation = 24.0,
		sun_yaw = 35.0,
		sun_color = Color(1.0, 0.88, 0.72),
		sun_energy = 1.0,
	}


## Weathered roof concrete: grey, finely mottled, no glints.
func _ground_parameters(_packed: bool) -> Dictionary:
	return {
		bright_color = Color(0.58, 0.57, 0.55),
		dark_color = Color(0.42, 0.42, 0.41),
		mottle_contrast = 1.1,
		mottle_scale = 0.15,
		fine_mottle_scale = 6.0,
		fine_mottle_weight = 0.45,
		detail_scale = 2.0,
		normal_depth = 0.4,
		roughness_value = 0.9,
		specular_value = 0.2,
	}


func _build_roof() -> Node3D:
	var roof := Node3D.new()
	roof.name = "Roof"
	var plane := PlaneMesh.new()
	plane.size = ROOF_SIZE
	var deck := MeshInstance3D.new()
	deck.mesh = plane
	deck.material_override = ground_material(false)
	# Just below the court plane (y = 0) so the two don't z-fight.
	deck.position.y = -0.02
	roof.add_child(deck)
	roof.add_child(_static_box(Vector3(0, -0.1, 0), Vector3(ROOF_SIZE.x, 0.2, ROOF_SIZE.y)))
	return roof


func _build_parapet() -> Node3D:
	var parapet := Node3D.new()
	parapet.name = "Parapet"
	var hx := ROOF_SIZE.x / 2.0
	var hz := ROOF_SIZE.y / 2.0
	var t := PARAPET_THICKNESS
	var y := PARAPET_HEIGHT / 2.0
	var concrete := _plain_material(Color(0.62, 0.61, 0.59))
	for side: float in [-1.0, 1.0]:
		for wall in [
			[Vector3(side * (hx - t / 2.0), y, 0), Vector3(t, PARAPET_HEIGHT, ROOF_SIZE.y)],
			[Vector3(0, y, side * (hz - t / 2.0)), Vector3(ROOF_SIZE.x - 2.0 * t, PARAPET_HEIGHT, t)],
		]:
			parapet.add_child(_box_mesh(wall[0], wall[1], concrete))
			parapet.add_child(_static_box(wall[0], wall[1]))
			# A metal coping along the top.
			parapet.add_child(_box_mesh(wall[0] + Vector3(0, y + 0.02, 0), wall[1] * Vector3(1.0, 0.0, 1.0) + Vector3(0.06, 0.04, 0.06), _plain_material(Color(0.35, 0.36, 0.38), 0.4, 0.6)))
	return parapet


## The usual rooftop clutter, kept off the court and clear of the crowd
## (|x| < ~7, |z| < ~12) and out of the thrower's line of sight: a plant
## room with fans on its roof, a water tank on legs and a radio mast with
## a blinking red aviation light.
func _build_roof_plant() -> Node3D:
	var plant := Node3D.new()
	plant.name = "RoofPlant"
	var metal := _plain_material(Color(0.66, 0.67, 0.68), 0.45, 0.5)
	var dark_metal := _plain_material(Color(0.22, 0.23, 0.25), 0.5, 0.6)

	var room_size := Vector3(4.5, 2.6, 5.0)
	var room_at := Vector3(-9.6, room_size.y / 2.0, -17.5)
	plant.add_child(_box_mesh(room_at, room_size, _plain_material(Color(0.70, 0.68, 0.64))))
	plant.add_child(_static_box(room_at, room_size))
	for i in range(2):
		var fan_at := room_at + Vector3(0, room_size.y / 2.0 + 0.3, -1.2 + i * 2.4)
		plant.add_child(_box_mesh(fan_at, Vector3(1.6, 0.6, 1.6), metal))
		plant.add_child(_cylinder_mesh(fan_at + Vector3(0, 0.31, 0), 0.65, 0.02, dark_metal))

	var unit_size := Vector3(2.2, 1.4, 3.0)
	for i in range(2):
		var unit_at := Vector3(9.8, unit_size.y / 2.0, 14.5 + i * 3.6)
		plant.add_child(_box_mesh(unit_at, unit_size, metal))
		plant.add_child(_static_box(unit_at, unit_size))
		plant.add_child(_cylinder_mesh(unit_at + Vector3(0, unit_size.y / 2.0 + 0.01, 0), 0.8, 0.02, dark_metal))

	var tank_at := Vector3(9.5, 0.0, -17.0)
	for leg in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		plant.add_child(_box_mesh(tank_at + leg * 1.2 + Vector3(0, 1.0, 0), Vector3(0.15, 2.0, 0.15), dark_metal))
	var wood := _plain_material(Color(0.45, 0.32, 0.22))
	plant.add_child(_cylinder_mesh(tank_at + Vector3(0, 3.6, 0), 1.9, 3.2, wood))
	plant.add_child(_cone_mesh(tank_at + Vector3(0, 5.2, 0), 2.0, 0.9, dark_metal))
	plant.add_child(_static_box(tank_at + Vector3(0, 2.6, 0), Vector3(3.0, 5.2, 3.0)))

	var mast_at := Vector3(-10.8, 0.0, 19.5)
	plant.add_child(_cylinder_mesh(mast_at + Vector3(0, 7.0, 0), 0.12, 14.0, metal))
	for i in range(3):
		plant.add_child(_box_mesh(mast_at + Vector3(0.0, 4.0 + i * 3.5, 0.0), Vector3(0.9, 0.05, 0.05), metal))
	var beacon_material := StandardMaterial3D.new()
	beacon_material.albedo_color = Color(1.0, 0.1, 0.05)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(1.0, 0.1, 0.05)
	beacon_material.emission_energy_multiplier = 4.0
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bulb := SphereMesh.new()
	bulb.radius = 0.18
	bulb.height = 0.36
	_beacon = MeshInstance3D.new()
	_beacon.mesh = bulb
	_beacon.material_override = beacon_material
	_beacon.position = mast_at + Vector3(0, 14.2, 0)
	plant.add_child(_beacon)
	plant.add_child(_static_box(mast_at + Vector3(0, 7.0, 0), Vector3(0.3, 14.0, 0.3)))
	return plant


## The street grid, each block split into one to four lots with a building
## on each (a few blocks left as parks), plus the tower itself.
func _build_city() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 10
	var buildings: Array[Dictionary] = []
	var parks: Array[Transform3D] = []
	# The tower: its own roof deck covers the top face.
	buildings.append(_building(Vector3(0, -TOWER_HEIGHT / 2.0 - 0.05, 0), Vector3(ROOF_SIZE.x, TOWER_HEIGHT, ROOF_SIZE.y), Color(0.55, 0.60, 0.66), Vector4(2.2, 4.0, 0.05, 1.0)))

	var block := BLOCK_PITCH - STREET_WIDTH
	var blocks := int(CITY_RADIUS / BLOCK_PITCH)
	for bz in range(-blocks, blocks + 1):
		for bx in range(-blocks, blocks + 1):
			var centre := Vector2(bx, bz) * BLOCK_PITCH
			if centre.length() > CITY_RADIUS or (bx == 0 and bz == 0):
				continue
			if rng.randf() < 0.05 and centre.length() > NEAR_RADIUS:
				parks.append(Transform3D(Basis.from_scale(Vector3(block, 0.4, block)), Vector3(centre.x, -TOWER_HEIGHT + 0.2, centre.y)))
				continue
			var split := Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2))
			var lot := Vector2(block / split.x, block / split.y)
			for lz in range(split.y):
				for lx in range(split.x):
					var lot_centre := centre + Vector2((lx + 0.5) * lot.x, (lz + 0.5) * lot.y) - Vector2(block, block) / 2.0
					var inset := Vector2(rng.randf_range(1.0, 5.0), rng.randf_range(1.0, 5.0))
					var footprint := lot - inset * 2.0
					var height := _building_height(rng, lot_centre.length())
					var color := _facade_color(rng)
					var style := Vector4(rng.randf_range(1.8, 3.4), rng.randf_range(3.2, 4.2), rng.randf_range(0.0, 0.08), rng.randf())
					buildings.append(_building(Vector3(lot_centre.x, -TOWER_HEIGHT + height / 2.0, lot_centre.y), Vector3(footprint.x, height, footprint.y), color, style))
					# Tall ones step back near the top, some with a spire.
					if height > 70.0 and rng.randf() < 0.45:
						var top := rng.randf_range(0.15, 0.3) * height
						var narrower := footprint * rng.randf_range(0.55, 0.8)
						buildings.append(_building(Vector3(lot_centre.x, -TOWER_HEIGHT + height + top / 2.0, lot_centre.y), Vector3(narrower.x, top, narrower.y), color, style))
						height += top
						if rng.randf() < 0.3:
							var spire := rng.randf_range(10.0, 30.0)
							buildings.append(_building(Vector3(lot_centre.x, -TOWER_HEIGHT + height + spire / 2.0, lot_centre.y), Vector3(0.8, spire, 0.8), Color(0.5, 0.5, 0.52), Vector4(1.0, 1.0, 0.0, 0.0)))

	var city := Node3D.new()
	city.name = "City"
	var material := ShaderMaterial.new()
	material.shader = BUILDING_SHADER
	material.set_shader_parameter("street_level", -TOWER_HEIGHT)
	material.set_shader_parameter("sky_reflection", _atmosphere().sky_horizon)
	var box := BoxMesh.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = box
	multimesh.instance_count = buildings.size()
	for i in range(buildings.size()):
		multimesh.set_instance_transform(i, buildings[i].transform)
		multimesh.set_instance_color(i, buildings[i].color)
		var style: Vector4 = buildings[i].style
		multimesh.set_instance_custom_data(i, Color(style.x, style.y, style.z, style.w))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Buildings"
	instance.multimesh = multimesh
	instance.material_override = material
	city.add_child(instance)

	var park_mesh := MultiMesh.new()
	park_mesh.transform_format = MultiMesh.TRANSFORM_3D
	park_mesh.mesh = box
	park_mesh.instance_count = parks.size()
	for i in range(parks.size()):
		park_mesh.set_instance_transform(i, parks[i])
	var park_instance := MultiMeshInstance3D.new()
	park_instance.name = "Parks"
	park_instance.multimesh = park_mesh
	park_instance.material_override = _plain_material(Color(0.24, 0.38, 0.16))
	city.add_child(park_instance)
	return city


## Asphalt under the whole city; the gaps between blocks read as streets.
func _build_streets() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (CITY_RADIUS * 2.0 + 600.0)
	var streets := MeshInstance3D.new()
	streets.name = "Streets"
	streets.mesh = plane
	streets.material_override = _plain_material(Color(0.20, 0.20, 0.21))
	streets.position.y = -TOWER_HEIGHT
	return streets


## Mostly mid-rise, taller toward a downtown a few hundred metres out, the
## odd supertall above the roof; nothing near the tower reaches it.
func _building_height(rng: RandomNumberGenerator, distance: float) -> float:
	var downtown := exp(-absf(distance - 350.0) / 300.0)
	var height := rng.randf_range(14.0, 50.0) + pow(rng.randf(), 2.0) * 190.0 * downtown
	if distance > NEAR_RADIUS + 100.0 and rng.randf() < 0.06 * downtown:
		height = rng.randf_range(190.0, 320.0)
	if distance < NEAR_RADIUS:
		height = minf(height, TOWER_HEIGHT - 30.0)
	return height


func _facade_color(rng: RandomNumberGenerator) -> Color:
	var palette: Array[Color] = [
		Color(0.62, 0.60, 0.56), Color(0.72, 0.68, 0.60), Color(0.48, 0.50, 0.54),
		Color(0.55, 0.42, 0.34), Color(0.80, 0.78, 0.74), Color(0.36, 0.40, 0.46),
	]
	var color: Color = palette[rng.randi() % palette.size()]
	return color.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.08)


func _building(position: Vector3, size: Vector3, color: Color, style: Vector4) -> Dictionary:
	return {"transform": Transform3D(Basis.from_scale(size), position), "color": color, "style": style}


func _static_box(position: Vector3, size: Vector3) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = position
	body.add_child(collision)
	return body


func _box_mesh(position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.position = position
	return instance


func _cylinder_mesh(position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	return _cone_mesh(position, radius, height, material, radius)


func _cone_mesh(position: Vector3, bottom_radius: float, height: float, material: Material, top_radius: float = 0.0) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom_radius
	cylinder.top_radius = top_radius
	cylinder.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.material_override = material
	instance.position = position
	return instance


func _plain_material(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

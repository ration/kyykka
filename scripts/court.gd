extends Node3D
## Procedurally builds the static kyykkä court: a ground plane plus the
## boundary and pesä (playing square) lines described in README.md, plus
## ground collision. Built at runtime rather than hand-placed so the
## dimensions stay in one place and can be tuned via the exported fields
## below. Equipment and game-flow (pesäs, turns, halves, the match) are
## MatchController's job, not this script's — it just hands over the
## dimensions/scenes MatchController needs.

@export var court_width: float = 5.0    ## metres, along X
@export var court_length: float = 20.0  ## metres, along Z
@export var pesa_size: float = 5.0      ## each pesä square is pesa_size x court_width
@export var pesa_side_margin: float = 0.25  ## gap between kyykkä pairs and the pesä's side lines
@export var line_width: float = 0.08    ## metres
@export var line_color: Color = Color.WHITE
@export var ground_texture_size: int = 128  ## pixels per side of the procedural ground noise; higher = crisper, slower to build
@export var ground_texture_frequency: float = 0.04  ## FastNoiseLite frequency; higher = smaller mottling
@export var ground_texture_tiling: float = 4.0  ## how many times the texture repeats across the court
@export var ground_margin: float = 5.0  ## collision extends this far past the drawn court on each side
@export var ground_thickness: float = 0.2


func _ready() -> void:
	var hw := court_width / 2.0
	var hl := court_length / 2.0
	var near_pesa_z := -hl + pesa_size
	var far_pesa_z := hl - pesa_size

	add_child(_build_ground())
	add_child(_build_ground_collision(hw, hl))
	add_child(_build_lines(hw, hl, near_pesa_z, far_pesa_z))

	var match_controller := MatchController.new()
	match_controller.name = "MatchController"
	match_controller.court_width = court_width
	match_controller.pesa_size = pesa_size
	match_controller.near_pesa_z = near_pesa_z
	match_controller.far_pesa_z = far_pesa_z
	match_controller.pesa_side_margin = pesa_side_margin
	match_controller.kyykka_scene = preload("res://scenes/kyykka.tscn")
	match_controller.karttu_scene = preload("res://scenes/karttu.tscn")
	match_controller.camera = $Camera3D
	add_child(match_controller)

	# Pause menu handles Esc during the match; the results screen owns
	# exits once the match ends, so mute the pause menu at that point.
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	match_controller.match_finished.connect(func() -> void: pause_menu.enabled = false)

	var hud := HUD.new()
	hud.name = "HUD"
	hud.match_controller = match_controller
	add_child(hud)

	var results := ResultsScreen.new()
	results.name = "ResultsScreen"
	results.match_controller = match_controller
	add_child(results)


func _build_ground() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(court_width, court_length)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _build_ground_texture()
	mat.uv1_scale = Vector3(ground_texture_tiling, ground_texture_tiling, 1)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	return ground


## Procedural noise texture whose two-colour ramp is chosen by GameMode
## (sandy tones in summer, snow in winter — see scripts/game_mode.gd).
## Built pixel-by-pixel via FastNoiseLite into an ImageTexture rather than
## via NoiseTexture2D so it's ready synchronously here (NoiseTexture2D
## generates in a background thread and might leave the first frame
## untextured), and small enough (128 px default) that the one-off cost
## is negligible.
func _build_ground_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = ground_texture_frequency
	var low_color: Color = GameMode.ground_low_color()
	var high_color: Color = GameMode.ground_high_color()

	var image := Image.create(ground_texture_size, ground_texture_size, false, Image.FORMAT_RGB8)
	for y in range(ground_texture_size):
		for x in range(ground_texture_size):
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			image.set_pixel(x, y, low_color.lerp(high_color, n))
	return ImageTexture.create_from_image(image)


## Flat collision slab under the whole court (plus a margin) so kyykkä and
## karttu RigidBody3D props have something to rest on. Deliberately no
## low-friction override here — Godot combines two bodies' friction
## multiplicatively, so a low ground friction dragged down *everything*
## touching it (diagnosed directly: a struck kyykkä given a modest 4 m/s
## slide never fully stopped, stuck rocking at ~0.07 m/s forever). The
## karttu's own low-friction material (karttu.tscn) is enough on its own
## to let it slide through a target; the ground stays at normal friction
## so kyykkä (kyykka.tscn's own higher-friction material) actually stop.
func _build_ground_collision(hw: float, hl: float) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		court_width + 2.0 * ground_margin,
		ground_thickness,
		court_length + 2.0 * ground_margin
	)

	var collision := CollisionShape3D.new()
	collision.shape = shape

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.position.y = -ground_thickness / 2.0
	body.add_child(collision)
	return body


## Boundary rectangle plus the two pesä front lines (the inner edge of each
## playing square, at pesa_size in from each end).
func _build_lines(hw: float, hl: float, near_pesa_z: float, far_pesa_z: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_segment(st, Vector3(-hw, 0, -hl), Vector3(-hw, 0, hl))  # left side
	_add_segment(st, Vector3(hw, 0, -hl), Vector3(hw, 0, hl))    # right side
	_add_segment(st, Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl))  # near end
	_add_segment(st, Vector3(-hw, 0, hl), Vector3(hw, 0, hl))    # far end
	_add_segment(st, Vector3(-hw, 0, near_pesa_z), Vector3(hw, 0, near_pesa_z))
	_add_segment(st, Vector3(-hw, 0, far_pesa_z), Vector3(hw, 0, far_pesa_z))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = line_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var lines := MeshInstance3D.new()
	lines.name = "CourtLines"
	lines.mesh = st.commit()
	lines.material_override = mat
	lines.position.y = 0.01  # avoid z-fighting with the ground
	return lines


func _add_segment(st: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var dir := (to - from).normalized()
	var perp := Vector3(-dir.z, 0, dir.x) * (line_width / 2.0)
	var a := from + perp
	var b := from - perp
	var c := to - perp
	var d := to + perp

	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

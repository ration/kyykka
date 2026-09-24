extends Node3D
## Procedurally builds the kyykkä court: a ground plane plus the boundary
## and pesä (playing square) lines described in README.md. Built at
## runtime rather than hand-placed so the dimensions stay in one place
## and can be tuned via the exported fields below.

@export var court_width: float = 5.0    ## metres, along X
@export var court_length: float = 20.0  ## metres, along Z
@export var pesa_size: float = 5.0      ## each pesä square is pesa_size x court_width
@export var pesa_side_margin: float = 0.25  ## gap between kyykkä pairs and the pesä's side lines
@export var line_width: float = 0.08    ## metres
@export var line_color: Color = Color.WHITE
@export var ground_color: Color = Color(0.76, 0.66, 0.47)  ## sand/gravel
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
	add_child(_build_pesa_view(near_pesa_z))
	add_child(_build_pesa_view(far_pesa_z))


func _build_ground() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(court_width, court_length)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	return ground


## Flat collision slab under the whole court (plus a margin) so kyykkä and
## karttu RigidBody3D props have something to rest on.
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


func _build_pesa_view(z: float) -> PesaView:
	var view := PesaView.new()
	view.name = "PesaView"
	view.kyykka_scene = preload("res://scenes/kyykka.tscn")
	view.usable_width = court_width - 2.0 * pesa_side_margin
	view.position = Vector3(0, 0, z)
	return view


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

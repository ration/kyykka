class_name PesaView
extends Node3D
## Spawns one pesä's kyykkä pieces as physical props: piece_count / 2
## positions evenly spaced along local X at local Z = 0, each holding a
## pair of kyykkä stacked one on top of the other (per README.md: 10
## pairs, stacked two high, not 20 pairs side by side). Position (and,
## if needed, rotate) this node to place it at a specific pesä's front
## line — it doesn't know its own world position.
##
## piece_count defaults to KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2 so the
## visual count stays wired to the Phase 1 rules engine instead of being
## a second hardcoded number.

@export var kyykka_scene: PackedScene
@export var piece_count: int = KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2
@export var usable_width: float = 4.5  ## court width minus side margins
@export var kyykka_diameter: float = 0.07
@export var kyykka_height: float = 0.10

## Pesä square geometry, for to_pesa_local() — independent of usable_width,
## which only governs how the initial kyykkä pairs are laid out.
@export var pesa_half_width: float = 2.5   ## court_width / 2
@export var pesa_depth: float = 5.0        ## pesa_size
## +1 if local +Z points from this pesä's front line toward its back line
## (the far pesä), -1 if local +Z points the other way (the near pesä).
@export var depth_direction: float = 1.0
## How far in from the front line (depth 0) freshly spawned pieces sit.
## Must clear PieceClassifier's margin (kyykka_diameter / 2) by a
## comfortable amount — resting RigidBody3D pieces standing upright on a
## flat plane are prone to slow physics-solver jitter/drift even while
## "settled" (observed directly: 5+ seconds of undisturbed simulation
## measurably drifted pieces placed only 1.5cm past the margin), so this
## needs real slack, not just enough to clear the margin on paper.
@export var spawn_inward_offset: float = 0.15

const TARGET_COLOR := Color(0.78, 0.13, 0.1)  ## painted wood

static var _target_material: StandardMaterial3D
var _wood_material: Material  ## the kyykkä scene's own, restored by set_targeted(false)


func _ready() -> void:
	_spawn_pieces()


## Paints this pesä's kyykkä red while they're the ones being thrown at,
## so it's obvious at a glance which end — and so whose turn — it is.
func set_targeted(targeted: bool) -> void:
	if _target_material == null:
		_target_material = StandardMaterial3D.new()
		_target_material.albedo_color = TARGET_COLOR
		_target_material.roughness = 0.8
		# A faint glow keeps them reading red from the far end, even in shade.
		_target_material.emission_enabled = true
		_target_material.emission = TARGET_COLOR
		_target_material.emission_energy_multiplier = 0.35
	for piece in get_children():
		var mesh: MeshInstance3D = piece.get_node("MeshInstance3D")
		if _wood_material == null:
			_wood_material = mesh.material_override
		mesh.material_override = _target_material if targeted else _wood_material


## Converts a world position into (x, depth) relative to this pesä, where
## depth runs from 0 at the front line to pesa_depth at the back line —
## the coordinate space PieceClassifier.classify() expects.
func to_pesa_local(world_pos: Vector3) -> Vector2:
	var local := to_local(world_pos)
	return Vector2(local.x, local.z * depth_direction)


## Stands `piece` upright on the nearest line of this pesä (PieceClassifier.
## snap_to_line()), at rest — what players do with a kyykkä that lands on
## the line.
func stand_up_on_line(piece: RigidBody3D) -> void:
	var at := to_pesa_local(piece.global_position)
	var on_line := PieceClassifier.snap_to_line(at.x, at.y, pesa_half_width, pesa_depth)
	piece.linear_velocity = Vector3.ZERO
	piece.angular_velocity = Vector3.ZERO
	piece.transform = Transform3D(Basis.IDENTITY, Vector3(on_line.x, kyykka_height / 2.0, on_line.y * depth_direction))
	piece.sleeping = true


func _spawn_pieces() -> void:
	assert(kyykka_scene != null, "PesaView.kyykka_scene must be set")
	assert(piece_count % 2 == 0, "kyykkä are arranged in stacked pairs")

	@warning_ignore("integer_division")  # piece_count is always even (see assert above)
	var stack_count := piece_count / 2
	var spacing := usable_width / (stack_count - 1) if stack_count > 1 else 0.0
	var start_x := -usable_width / 2.0

	for i in range(stack_count):
		var x := 0.0 if stack_count <= 1 else start_x + i * spacing
		_spawn_piece(x, kyykka_height / 2.0)      # bottom of the pair, resting on the ground
		_spawn_piece(x, kyykka_height * 1.5)      # top of the pair, resting on the bottom one


func _spawn_piece(x: float, y: float) -> void:
	var piece := kyykka_scene.instantiate()
	add_child(piece)
	piece.position = Vector3(x, y, spawn_inward_offset * depth_direction)

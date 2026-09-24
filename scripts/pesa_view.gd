class_name PesaView
extends Node3D
## Spawns one pesä's kyykkä pieces as physical props, arranged in pairs
## evenly spaced along local X at local Z = 0. Position (and, if needed,
## rotate) this node to place it at a specific pesä's front line — it
## doesn't know its own world position.
##
## piece_count defaults to KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2 so the
## visual count stays wired to the Phase 1 rules engine instead of being
## a second hardcoded number.

@export var kyykka_scene: PackedScene
@export var piece_count: int = KyykkaMatch.DEFAULT_KYYKKA_PAIRS * 2
@export var usable_width: float = 4.5  ## court width minus side margins
@export var kyykka_diameter: float = 0.07
@export var kyykka_height: float = 0.10
@export var pair_gap: float = 0.02  ## gap between the two kyykkä of a pair

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


func _ready() -> void:
	_spawn_pieces()


## Converts a world position into (x, depth) relative to this pesä, where
## depth runs from 0 at the front line to pesa_depth at the back line —
## the coordinate space PieceClassifier.classify() expects.
func to_pesa_local(world_pos: Vector3) -> Vector2:
	var local := to_local(world_pos)
	return Vector2(local.x, local.z * depth_direction)


func _spawn_pieces() -> void:
	assert(kyykka_scene != null, "PesaView.kyykka_scene must be set")
	assert(piece_count % 2 == 0, "kyykkä are arranged in pairs")

	@warning_ignore("integer_division")  # piece_count is always even (see assert above)
	var pair_count := piece_count / 2
	var spacing := usable_width / (pair_count - 1) if pair_count > 1 else 0.0
	var start_x := -usable_width / 2.0
	var half_pair_span := (kyykka_diameter + pair_gap) / 2.0

	for i in range(pair_count):
		var pair_x := 0.0 if pair_count <= 1 else start_x + i * spacing
		_spawn_piece(pair_x - half_pair_span)
		_spawn_piece(pair_x + half_pair_span)


func _spawn_piece(x: float) -> void:
	var piece := kyykka_scene.instantiate()
	add_child(piece)
	piece.position = Vector3(x, kyykka_height / 2.0, spawn_inward_offset * depth_direction)

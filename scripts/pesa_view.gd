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


func _ready() -> void:
	_spawn_pieces()


func _spawn_pieces() -> void:
	assert(kyykka_scene != null, "PesaView.kyykka_scene must be set")
	assert(piece_count % 2 == 0, "kyykkä are arranged in pairs")

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
	piece.position = Vector3(x, kyykka_height / 2.0, 0.0)

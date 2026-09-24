class_name MatchController
extends Node3D
## Owns the full game-flow: the KyykkaMatch, both pesäs' equipment across
## halves, and the single (hot-seat) ThrowController. court.gd builds the
## static court (ground/lines/collision) and hands this node the
## dimensions/scenes it needs; this node owns everything that changes
## over the course of a match.
##
## Minimal hot-seat for now: the same player/controls handle both teams'
## turns, repositioned to face whichever pesä they're attacking. Real
## per-player polish is Phase 7's job; AI is Phase 6's — see ROADMAP.md.

@export var court_width: float
@export var pesa_size: float
@export var near_pesa_z: float
@export var far_pesa_z: float
@export var pesa_side_margin: float
@export var kyykka_scene: PackedScene
@export var karttu_scene: PackedScene
@export var camera: Camera3D

var kyykka_match: KyykkaMatch
var current_half: Half
var current_attack: Attack

var near_pesa_view: PesaView  # team A's own square; team B attacks it
var far_pesa_view: PesaView   # team B's own square; team A attacks it
var near_scorer: PesaScorer
var far_scorer: PesaScorer

var thrower: ThrowController


func _ready() -> void:
	kyykka_match = KyykkaMatch.new(Team.new("Team A"), Team.new("Team B"))
	_start_half()

	thrower = ThrowController.new()
	thrower.name = "ThrowController"
	thrower.karttu_scene = karttu_scene
	thrower.camera = camera
	thrower.throw_settled.connect(_on_throw_settled)
	add_child(thrower)
	_configure_thrower_for_current_attack()


func _start_half() -> void:
	current_half = kyykka_match.start_half()

	if near_pesa_view:
		near_pesa_view.queue_free()
	if far_pesa_view:
		far_pesa_view.queue_free()

	near_pesa_view = _build_pesa_view(near_pesa_z, -1.0)
	far_pesa_view = _build_pesa_view(far_pesa_z, 1.0)
	add_child(near_pesa_view)
	add_child(far_pesa_view)

	# Team A defends the near pesä and attacks the far one; team B the
	# reverse (see scripts/rules/kyykka_match.gd / half.gd).
	near_scorer = PesaScorer.new(near_pesa_view, current_half.attack_by_team_b)
	far_scorer = PesaScorer.new(far_pesa_view, current_half.attack_by_team_a)
	current_attack = current_half.attack_by_team_a

	print("-- Half %d begins --" % kyykka_match.halves.size())


func _build_pesa_view(z: float, depth_direction: float) -> PesaView:
	var view := PesaView.new()
	view.name = "PesaView"
	view.kyykka_scene = kyykka_scene
	view.usable_width = court_width - 2.0 * pesa_side_margin
	view.pesa_half_width = court_width / 2.0
	view.pesa_depth = pesa_size
	view.depth_direction = depth_direction
	view.position = Vector3(0, 0, z)
	return view


func _configure_thrower_for_current_attack() -> void:
	if current_attack == current_half.attack_by_team_a:
		thrower.configure(Vector3(0, 0, near_pesa_z), Vector3(0, 0, 1), far_pesa_view)
	else:
		thrower.configure(Vector3(0, 0, far_pesa_z), Vector3(0, 0, -1), near_pesa_view)
	print("%s's turn" % current_attack.attacking_team.team_name)


func _on_throw_settled() -> void:
	var scorer := far_scorer if current_attack == current_half.attack_by_team_a else near_scorer
	current_attack.throw(scorer.score_current_state())

	print("%s: karttu_used=%d/%d in_square=%d on_line=%d removed=%d finished=%s score=%s" % [
		current_attack.attacking_team.team_name,
		current_attack.karttu_used, current_attack.karttu_budget,
		current_attack.pesa.in_square, current_attack.pesa.on_line, current_attack.pesa.removed,
		current_attack.is_finished(),
		current_attack.score() if current_attack.is_finished() else "n/a",
	])

	_advance_turn()


func _advance_turn() -> void:
	if current_half.is_finished():
		if kyykka_match.is_finished():
			_end_match()
		else:
			_start_half()
			_configure_thrower_for_current_attack()
		return

	current_attack = current_half.next_attack(current_attack)
	_configure_thrower_for_current_attack()


func _end_match() -> void:
	thrower.enabled = false
	var team_a := kyykka_match.team_a
	var team_b := kyykka_match.team_b
	var winner := kyykka_match.winner()
	print("-- Match over -- %s: %d, %s: %d -- %s" % [
		team_a.team_name, kyykka_match.total_score(team_a),
		team_b.team_name, kyykka_match.total_score(team_b),
		("Winner: %s" % winner.team_name) if winner else "Tie",
	])

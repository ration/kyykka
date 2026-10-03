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
##
## Signals let the HUD (and results screen) subscribe to match-state
## changes instead of this node poking UI directly.
##
## Online (see Net / OnlineLink) the same node runs on both machines. The
## host scores its own physics as usual; the client sets remote_results
## and is fed the host's ThrowResults through apply_result(), so both
## advance the rules engine identically. `local_team` limits input to that
## team's turns.

signal half_started(half_number: int)
signal turn_changed
signal attack_scored
signal match_finished
## A throw has been scored, before it's applied and the turn moves on (the
## pesäs are still as the throw left them) — for OnlineLink to send.
## `own_pesa` is what it did to the thrower's own pesä (see apply_result()).
signal throw_resolved(result: ThrowResult, own_pesa: ThrowResult)

@export var court_width: float
@export var pesa_size: float
@export var near_pesa_z: float
@export var far_pesa_z: float
@export var court_length: float = 20.0  ## the back lines are at -/+ court_length / 2
@export var pesa_side_margin: float
@export var kyykka_scene: PackedScene
@export var karttu_scene: PackedScene
@export var camera: Camera3D
## Online client: scores come from the host via apply_result(), not from
## this machine's physics.
@export var remote_results: bool = false
## Online: the team (0 = A, 1 = B) played on this machine, whose turns
## alone take input. -1 is hot-seat: every turn is local.
@export var local_team: int = -1

var waiting_for_opponent: bool = false:  ## online: hold input until the other side is ready
	set(value):
		waiting_for_opponent = value
		_update_input()

var kyykka_match: KyykkaMatch
var current_half: Half
var current_attack: Attack

var near_pesa_view: PesaView  # team A's own square; team B attacks it
var far_pesa_view: PesaView   # team B's own square; team A attacks it
var near_scorer: PesaScorer
var far_scorer: PesaScorer

var thrower: ThrowController
var last_throw_result: ThrowResult  ## the most recent throw's effect, for attack_scored listeners


func _ready() -> void:
	kyykka_match = KyykkaMatch.new(Team.new(GameMode.team_names[0]), Team.new(GameMode.team_names[1]))
	_start_half()

	thrower = ThrowController.new()
	thrower.name = "ThrowController"
	thrower.karttu_scene = karttu_scene
	thrower.camera = camera
	thrower.line_half_width = court_width / 2.0
	thrower.remote_throws = remote_results
	if not remote_results:
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
	half_started.emit(kyykka_match.halves.size())


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


## Also paints the kyykkä being attacked red (see PesaView.set_targeted()),
## so the end changing colour shows whose turn it is.
func _configure_thrower_for_current_attack() -> void:
	var team_a := is_team_a_turn()
	var target := far_pesa_view if team_a else near_pesa_view
	thrower.configure(throwing_position(), Vector3(0, 0, 1 if team_a else -1), target, target.global_position)
	far_pesa_view.set_targeted(team_a)
	near_pesa_view.set_targeted(not team_a)
	_update_input()
	print("%s's turn" % current_attack.attacking_team.team_name)
	turn_changed.emit()


func _on_throw_settled() -> void:
	var team_a := is_team_a_turn()
	var result := (far_scorer if team_a else near_scorer).score_current_state()
	var own_pesa := (near_scorer if team_a else far_scorer).score_current_state()
	throw_resolved.emit(result, own_pesa)
	apply_result(result, own_pesa)


## Applies one throw's result and moves the match on. Called by
## _on_throw_settled() normally, or with the host's result on an online
## client. `own_pesa` is what the throw did to the thrower's *own* pesä (a
## short one landing in it): kyykkä knocked about there are credited to
## the other team's attack straight away (Attack.credit()), so removing one
## lets them move up to their pesä line on their next throw.
func apply_result(result: ThrowResult, own_pesa: ThrowResult = null) -> void:
	last_throw_result = result
	var defenders := current_half.attack_by_team_b if is_team_a_turn() else current_half.attack_by_team_a
	current_attack.throw(last_throw_result)
	if own_pesa != null and not own_pesa.is_miss():
		print("%s hit their own pesä: %d out, %d onto the line, credited to %s" % [
			current_attack.attacking_team.team_name,
			own_pesa.removed_from_square + own_pesa.removed_from_line, own_pesa.moved_to_line,
			defenders.attacking_team.team_name,
		])
		defenders.credit(own_pesa)

	print("%s: karttu_used=%d/%d in_square=%d on_line=%d removed=%d finished=%s score=%s" % [
		current_attack.attacking_team.team_name,
		current_attack.karttu_used, current_attack.karttu_budget,
		current_attack.pesa.in_square, current_attack.pesa.on_line, current_attack.pesa.removed,
		current_attack.is_finished(),
		current_attack.score() if current_attack.is_finished() else "n/a",
	])
	attack_scored.emit()

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


## Where the current team throws from: the back edge of the court at
## their own end until they've knocked a kyykkä out, then their own pesä's
## front line (Attack.throws_from_back_line()).
func throwing_position() -> Vector3:
	var team_a := is_team_a_turn()
	if current_attack.throws_from_back_line():
		return Vector3(0, 0, -court_length / 2.0 if team_a else court_length / 2.0)
	return Vector3(0, 0, near_pesa_z if team_a else far_pesa_z)


## Team A attacks the far pesä, team B the near one.
func is_team_a_turn() -> bool:
	return current_attack == current_half.attack_by_team_a


func current_team() -> int:
	return 0 if is_team_a_turn() else 1


func is_local_turn() -> bool:
	return local_team < 0 or local_team == current_team()


## Every body a throw can move, in an order both online machines agree on
## (same spawn order): both pesäs' kyykkä, then the karttu.
func synced_bodies() -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	for view in [near_pesa_view, far_pesa_view]:
		for piece in view.get_children():
			bodies.append(piece)
	bodies.append(thrower._karttu)
	return bodies


func _update_input() -> void:
	if thrower == null or kyykka_match == null or kyykka_match.is_finished():
		return
	thrower.enabled = is_local_turn() and not waiting_for_opponent


func _end_match() -> void:
	thrower.enabled = false
	far_pesa_view.set_targeted(false)
	near_pesa_view.set_targeted(false)
	var team_a := kyykka_match.team_a
	var team_b := kyykka_match.team_b
	var winner := kyykka_match.winner()
	print("-- Match over -- %s: %d, %s: %d -- %s" % [
		team_a.team_name, kyykka_match.total_score(team_a),
		team_b.team_name, kyykka_match.total_score(team_b),
		("Winner: %s" % winner.team_name) if winner else "Tie",
	])
	match_finished.emit()

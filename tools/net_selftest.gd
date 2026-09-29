extends SceneTree
## Headless end-to-end check of online play: runs one side of a real
## online match over localhost, throwing on its own turns (aimed at the
## outermost standing kyykkä, like tools/simulate_throws.gd), and prints a
## RESULT line per throw with the score and a checksum of every body's
## final position. Run a host and a client side by side and compare:
##
##   godot --headless --path . --script tools/net_selftest.gd -- host 6 > host.log &
##   godot --headless --path . --script tools/net_selftest.gd -- client 6 > client.log
##   diff <(grep RESULT host.log) <(grep RESULT client.log)
##
## Identical RESULT lines mean both machines agree on every throw's
## outcome, the score, the turn order and where everything ended up.
## Untyped against game classes and load()-free of them at compile time,
## like the other tools (see CLAUDE.md).

var net: Node
var role: String
var throws: int
var results: int = 0
var mc = null
var cooldown: float = 1.0
var elapsed: float = 0.0
var address: String
var connected := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	throws = int(args[1]) if args.size() > 1 else 6
	address = args[2] if args.size() > 2 else "127.0.0.1"
	net = get_root().get_node("Net")


## On the first frame, not in _initialize(): the autoloads aren't in the
## tree yet there, so Net has no `multiplayer`.
func _connect() -> void:
	net.lobby_failed.connect(func(text: String) -> void: print("FAILED: ", text); quit(1))
	if role == "host":
		get_root().get_node("GameMode").current = 0
		print("host: ", net.host("Hosts"))
	else:
		print("client: ", net.join(address, "Guests"))


func _physics_process(delta: float) -> bool:
	if not connected:
		connected = true
		_connect()
	elapsed += delta
	if elapsed > 900.0:
		print("TIMEOUT after %d results" % results)
		quit(1)
		return true
	if mc == null:
		var scene := current_scene
		if scene != null and scene.has_node("MatchController"):
			mc = scene.get_node("MatchController")
			mc.attack_scored.connect(_on_scored)
		return false
	var thrower = mc.thrower
	cooldown -= delta
	if cooldown > 0.0 or results >= throws or not mc.is_local_turn() or not thrower.enabled or thrower.is_throwing():
		return false
	var view = mc.far_pesa_view if mc.is_team_a_turn() else mc.near_pesa_view
	var target := _outermost_standing(view)
	if target == null:
		return false
	# Step along the line a little, differently each throw, then aim.
	thrower.set_line_offset([0.0, 1.0, -1.5][results % 3])
	_aim_at(thrower, target.global_position)
	cooldown = 1.0
	thrower.release_swing(90.0)
	return false


func _on_scored() -> void:
	results += 1
	var m = mc.kyykka_match
	var checksum := 0.0
	for body in mc.synced_bodies():
		checksum += body.global_position.dot(Vector3(1.0, 3.0, 7.0))
	var r = mc.last_throw_result
	print("RESULT %d team=%s out=%d line=%d back=%d karttu=%d/%d pesa=%d/%d/%d checksum=%.4f" % [
		results, mc.current_attack.attacking_team.team_name,
		r.removed_from_square, r.moved_to_line, r.removed_from_line,
		mc.current_attack.karttu_used, mc.current_attack.karttu_budget,
		mc.current_attack.pesa.in_square, mc.current_attack.pesa.on_line, mc.current_attack.pesa.removed,
		checksum,
	])
	if results >= throws:
		# Give the last message time to go out before closing.
		create_timer(1.0).timeout.connect(func() -> void: quit(0))


func _outermost_standing(view) -> Node3D:
	var best: Node3D = null
	for piece in view.get_children():
		if piece.global_position.y < 0.042 or absf(piece.global_position.x) > view.pesa_half_width:
			continue
		if best == null or absf(piece.global_position.x) > absf(best.global_position.x):
			best = piece
	return best


func _aim_at(thrower, point: Vector3) -> void:
	var offset: Vector3 = point - thrower.global_position
	offset.y = 0.0
	thrower._yaw_degrees = rad_to_deg(thrower._forward_direction.signed_angle_to(offset, Vector3.UP))
	var drop: float = thrower.camera_height - thrower.aim_target_height
	thrower._elevation_degrees = -rad_to_deg(atan(drop / (offset.length() + thrower.camera_back_offset)))

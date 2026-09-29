class_name OnlineLink
extends Node
## Connects one online match's court to the other machine through Net.
## Added by court.gd only when Net.is_online(); hot-seat play never sees
## it. See Net for the overall scheme (host-authoritative, results not
## physics).
##
## Host: runs the match as usual. On the client's turns it throws what the
## client asked for; for every throw it tells the client the throw has
## started, streams body transforms while things move, then sends the
## ThrowResult with a final snapshot.
##
## Client: never simulates. Its kyykkä and karttu are frozen (kinematic)
## and eased toward the host's snapshots, snapped exactly to the final one,
## and each result is fed to MatchController.apply_result().
##
## Both: whoever's turn it is sends their aim (unreliably, a few times a
## second) so the other player watches them line up; input waits until
## both courts have loaded.

const SNAPSHOT_EVERY_FRAMES := 2  ## 30 Hz at 60 physics ticks/s
const AIM_EVERY_FRAMES := 4
const SMOOTHING := 20.0  ## client easing rate toward the latest snapshot, 1/s

var match_controller: MatchController
var audio: CourtAudio

var _throw_number: int = 0
var _streaming: bool = false  ## host: a throw is moving
var _receiving: bool = false  ## client: a throw is moving on the host
var _targets: Array[Transform3D] = []
var _frame: int = 0
var _last_sent_aim := Vector3.INF

var _overlay: CanvasLayer
var _message: Label
var _menu_button: Button


func _ready() -> void:
	assert(match_controller != null)
	name = "OnlineLink"
	_build_overlay()
	var thrower := match_controller.thrower

	if Net.is_host():
		thrower.thrown.connect(_on_host_thrown)
		match_controller.throw_resolved.connect(_on_host_throw_resolved)
		Net.throw_requested_by_client.connect(_on_client_throw_request)
		if audio != null:
			audio.impact_played.connect(Net.send_impact)
	else:
		thrower.throw_requested.connect(_on_local_throw_request)
		Net.throw_started.connect(_on_remote_throw_started)
		Net.snapshot_received.connect(_on_snapshot)
		Net.result_received.connect(_on_result)
		if audio != null:
			Net.impact_received.connect(audio.play_impact)

	Net.aim_received.connect(_on_aim_received)
	Net.opponent_ready.connect(_on_opponent_ready)
	Net.peer_left.connect(_on_peer_left)
	match_controller.turn_changed.connect(func() -> void: _last_sent_aim = Vector3.INF)

	match_controller.waiting_for_opponent = not Net.opponent_court_ready
	if not Net.opponent_court_ready:
		_show_message("Waiting for %s…" % _opponent_name())
	Net.send_court_ready()


func _opponent_name() -> String:
	return GameMode.team_names[1 - Net.local_team]


func _physics_process(delta: float) -> void:
	_frame += 1
	var thrower := match_controller.thrower
	if Net.is_host() and _streaming and _frame % SNAPSHOT_EVERY_FRAMES == 0:
		Net.send_snapshot(_throw_number, pack_snapshot(match_controller.synced_bodies()))

	if Net.is_client():
		var bodies := match_controller.synced_bodies()
		for body in bodies:
			if not body.freeze or body.freeze_mode != RigidBody3D.FREEZE_MODE_KINEMATIC:
				body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				body.freeze = true
		if _receiving and _targets.size() == bodies.size():
			var weight := 1.0 - exp(-SMOOTHING * delta)
			for i in range(bodies.size()):
				bodies[i].global_transform = bodies[i].global_transform.interpolate_with(_targets[i], weight)

	if match_controller.is_local_turn() and thrower.enabled and not thrower.is_throwing() and _frame % AIM_EVERY_FRAMES == 0:
		var aim := thrower.aim_state()
		if not aim.is_equal_approx(_last_sent_aim):
			_last_sent_aim = aim
			Net.send_aim(aim.x, aim.y, aim.z)


func _on_aim_received(yaw: float, elevation: float, offset: float) -> void:
	if not match_controller.is_local_turn():
		match_controller.thrower.apply_aim(yaw, elevation, offset)


# Host ------------------------------------------------------------------------

func _on_client_throw_request(yaw: float, elevation: float, offset: float, gauge: float) -> void:
	var thrower := match_controller.thrower
	if match_controller.current_team() != 1 or thrower.is_throwing() or match_controller.kyykka_match.is_finished():
		return  # not their turn (a stale or duplicate request)
	thrower.apply_aim(yaw, elevation, offset)
	thrower.release_swing(clampf(gauge, 0.0, 180.0))


func _on_host_thrown() -> void:
	_throw_number += 1
	_streaming = true
	Net.send_throw_started(_throw_number)


func _on_host_throw_resolved(result: ThrowResult) -> void:
	_streaming = false
	var m := match_controller
	Net.send_result({
		"removed_from_square": result.removed_from_square,
		"moved_to_line": result.moved_to_line,
		"removed_from_line": result.removed_from_line,
		# What the client should be at, to catch a desync early.
		"half": m.kyykka_match.halves.size(),
		"team": m.current_team(),
		"karttu_used": m.current_attack.karttu_used,
	}, pack_snapshot(m.synced_bodies()))


# Client ----------------------------------------------------------------------

func _on_local_throw_request(gauge: float) -> void:
	var aim := match_controller.thrower.aim_state()
	Net.send_throw_request(aim.x, aim.y, aim.z, gauge)


func _on_remote_throw_started(number: int) -> void:
	_throw_number = number
	_receiving = true
	_targets.clear()
	match_controller.thrower.begin_remote_throw()


func _on_snapshot(number: int, data: PackedFloat32Array) -> void:
	if _receiving and number == _throw_number:
		_targets = unpack_snapshot(data)


func _on_result(result: Dictionary, snapshot: PackedFloat32Array) -> void:
	_receiving = false
	var m := match_controller
	var bodies := m.synced_bodies()
	var final := unpack_snapshot(snapshot)
	if final.size() == bodies.size():
		for i in range(bodies.size()):
			bodies[i].global_transform = final[i]
	if result.half != m.kyykka_match.halves.size() or result.team != m.current_team() or result.karttu_used != m.current_attack.karttu_used:
		push_error("Online match out of sync: host is at half %d, team %d, karttu %d" % [result.half, result.team, result.karttu_used])
	m.apply_result(ThrowResult.new(result.removed_from_square, result.moved_to_line, result.removed_from_line))


# Both ------------------------------------------------------------------------

func _on_opponent_ready() -> void:
	match_controller.waiting_for_opponent = false
	_overlay.hide()


func _on_peer_left() -> void:
	match_controller.waiting_for_opponent = true
	_streaming = false
	_receiving = false
	_show_message("%s left the match." % _opponent_name(), true)


## Every body's position and rotation, 7 floats each.
static func pack_snapshot(bodies: Array[RigidBody3D]) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	for body in bodies:
		var t := body.global_transform
		var q := t.basis.get_rotation_quaternion()
		data.append_array(PackedFloat32Array([t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w]))
	return data


static func unpack_snapshot(data: PackedFloat32Array) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for i in range(0, data.size() - 6, 7):
		var q := Quaternion(data[i + 3], data[i + 4], data[i + 5], data[i + 6]).normalized()
		transforms.append(Transform3D(Basis(q), Vector3(data[i], data[i + 1], data[i + 2])))
	return transforms


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.45
	panel.anchor_bottom = 0.45
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	box.add_child(_message)
	_menu_button = Button.new()
	_menu_button.text = "Main Menu"
	_menu_button.custom_minimum_size = Vector2(200, 40)
	_menu_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(_menu_button)
	_overlay.hide()


func _show_message(text: String, with_menu_button: bool = false) -> void:
	_message.text = text
	_menu_button.visible = with_menu_button
	_overlay.show()
	if with_menu_button:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

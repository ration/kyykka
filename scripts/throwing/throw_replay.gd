class_name ThrowReplay
extends Node
## Slow-motion instant replay of a particularly good throw: one that
## knocked more than three kyykkä out (MIN_KNOCKED_OUT). Added and driven
## by MatchController.
##
## It's a replay rather than slowing the game down live: whether a throw
## was good is only known once everything has settled and been scored, and
## online only the host runs the physics. So every throw is recorded —
## the transform of every synced body (MatchController.synced_bodies()),
## each physics frame — and a good one is played back afterwards before the
## turn moves on: from a little before the karttu reaches the kyykkä, at
## full speed easing down to SLOW_SPEED by the moment of impact, with the
## camera zoomed in close and side-on, slowly circling the pieces that
## went out. Physics, scoring and online sync never see it: the bodies are
## frozen while it plays and put back exactly as they were. Online, each
## machine replays its own recording (the client's is the host's
## snapshots), so it works the same on both.
##
## A click, tap or Enter/Space skips it.

signal started
signal finished

const MIN_KNOCKED_OUT := 4  ## "more than 3 out"
const LEAD_IN_SECONDS := 0.8  ## recorded time shown before the first kyykkä moves
const FOLLOW_SECONDS := 1.2  ## recorded time shown after it
const SLOW_SPEED := 0.25  ## playback rate around the impact
const SLOWDOWN_SECONDS := 0.3  ## recorded time over which it eases from full speed to SLOW_SPEED
const MOVED_THRESHOLD := 0.02  ## metres a kyykkä has to move to count as hit
const OUT_THRESHOLD := 0.3  ## metres a kyykkä has to travel to be framed by the camera
const REPLAY_FOV := 38.0
const CAMERA_DISTANCE := 3.0  ## horizontal, from the pieces that went out
const CAMERA_HEIGHT := 0.8
const ORBIT_DEGREES := Vector2(55.0, 20.0)  ## camera angle off the throw line at the start / end
const FADE_SECONDS := 0.25

@export var camera: Camera3D
## Off under --headless (tests, tools): nobody is watching, and the tools
## shouldn't wait for it.
var enabled: bool = DisplayServer.get_name() != "headless"

var _bodies: Array[RigidBody3D] = []
var _frames: Array = []  ## per physics frame, an Array[Transform3D] in _bodies order
var _recording: bool = false
var _playing: bool = false
var _skip: bool = false

var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _title: Label


func _ready() -> void:
	_build_ui()


## Starts recording a new throw (the karttu has just been thrown). The last
## entry of `bodies` is the karttu.
func record(bodies: Array[RigidBody3D]) -> void:
	_bodies = bodies.duplicate()
	_frames.clear()
	_recording = true


## The throw has come to rest; keep what's recorded.
func end_recording() -> void:
	_recording = false


## The throw wasn't worth a replay: drop the recording.
func stop_recording() -> void:
	_recording = false
	_frames.clear()


## Ends a replay that's playing on its next frame (online: the other player
## has already moved on).
func skip() -> void:
	_skip = true


func is_playing() -> bool:
	return _playing


func worth_replaying(result: ThrowResult) -> bool:
	return enabled and result.knocked_out >= MIN_KNOCKED_OUT and impact_frame(_frames) >= 0


func _physics_process(_delta: float) -> void:
	if not _recording:
		return
	var frame: Array[Transform3D] = []
	for body in _bodies:
		frame.append(body.global_transform if is_instance_valid(body) else Transform3D())
	_frames.append(frame)


## Plays the recorded throw back; await it. `knocked_out` is for the title.
func play(knocked_out: int) -> void:
	_recording = false
	var impact := impact_frame(_frames)
	if impact < 0 or _bodies.any(func(b: RigidBody3D) -> bool: return not is_instance_valid(b)):
		finished.emit()
		return
	_playing = true
	_skip = false

	var rate := float(Engine.physics_ticks_per_second)
	var start := maxf(impact - LEAD_IN_SECONDS * rate, 0.0)
	var end := minf(impact + FOLLOW_SECONDS * rate, _frames.size() - 1)
	var focus := focus_point(_frames, impact)
	var karttu_index := _bodies.size() - 1
	var karttu_start: Vector3 = _frames[0][karttu_index].origin
	var approach := Vector3(focus.x - karttu_start.x, 0, focus.z - karttu_start.z).normalized()
	if approach == Vector3.ZERO:
		approach = Vector3.FORWARD
	# Circle in from the side nearer the middle of the court, so the camera
	# doesn't end up out among the spectators.
	var side := approach.cross(Vector3.UP)
	if absf(focus.x + side.x) > absf(focus.x - side.x):
		side = -side

	# Hold the bodies still for the physics engine while they're posed by
	# hand, and remember how to put everything back.
	var settled: Array[Transform3D] = []
	var frozen: Array[bool] = []
	for body in _bodies:
		settled.append(body.global_transform)
		frozen.append(body.freeze)
		body.freeze = true
	var camera_transform := camera.global_transform
	var camera_fov := camera.fov

	started.emit()
	_title.text = "REPLAY — %d KYYKKÄ OUT!" % knocked_out
	_layer.show()
	var look := Vector3.INF
	var t := start
	var shown := 0.0
	while t < end and not _skip:
		if get_tree().paused:  # the pause menu is open
			await get_tree().process_frame
			continue
		var delta := get_process_delta_time()
		shown += delta
		_pose(t)
		var progress := (t - start) / maxf(end - start, 1.0)
		var angle := deg_to_rad(lerpf(ORBIT_DEGREES.x, ORBIT_DEGREES.y, smoothstep(0.0, 1.0, progress)))
		var away := -approach * cos(angle) + side * sin(angle)
		camera.global_position = focus + away * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
		var karttu_at: Vector3 = _frame_transform(t, karttu_index).origin
		var wanted := focus.lerp(karttu_at, 0.3) + Vector3.UP * 0.1
		look = wanted if look == Vector3.INF else look.lerp(wanted, 1.0 - exp(-6.0 * delta))
		camera.look_at(look, Vector3.UP)
		camera.fov = REPLAY_FOV
		_fade(minf(shown, (end - t) / rate / SLOW_SPEED) / FADE_SECONDS)
		await get_tree().process_frame
		t += delta * rate * playback_speed((t - impact) / rate)

	for i in range(_bodies.size()):
		_bodies[i].global_transform = settled[i]
		_bodies[i].linear_velocity = Vector3.ZERO
		_bodies[i].angular_velocity = Vector3.ZERO
		_bodies[i].freeze = frozen[i]
	camera.global_transform = camera_transform
	camera.fov = camera_fov
	_layer.hide()
	_frames.clear()
	_playing = false
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed \
			or event.is_action_pressed("ui_accept"):
		skip()
		get_viewport().set_input_as_handled()


## Puts every body where it was at (fractional) recorded frame `t`.
func _pose(t: float) -> void:
	for i in range(_bodies.size()):
		_bodies[i].global_transform = _frame_transform(t, i)


func _frame_transform(t: float, index: int) -> Transform3D:
	var i := clampi(int(t), 0, _frames.size() - 1)
	var j := mini(i + 1, _frames.size() - 1)
	var a: Transform3D = _frames[i][index]
	var b: Transform3D = _frames[j][index]
	return a.interpolate_with(b, t - i)


## Playback rate at `seconds` of recorded time from the impact: full speed
## on the way in, easing down to SLOW_SPEED by the impact and staying there.
static func playback_speed(seconds: float) -> float:
	return lerpf(1.0, SLOW_SPEED, smoothstep(-SLOWDOWN_SECONDS, 0.0, seconds))


## The first recorded frame in which a kyykkä (every body but the last, the
## karttu) has moved, or -1 if none did.
static func impact_frame(frames: Array) -> int:
	if frames.is_empty():
		return -1
	var first: Array = frames[0]
	for f in range(frames.size()):
		var frame: Array = frames[f]
		for i in range(frame.size() - 1):
			if frame[i].origin.distance_to(first[i].origin) > MOVED_THRESHOLD:
				return f
	return -1


## Where the camera looks: the middle of where the kyykkä that travelled
## furthest started, or the karttu at the impact if none went far.
static func focus_point(frames: Array, impact: int) -> Vector3:
	var first: Array = frames[0]
	var last: Array = frames[frames.size() - 1]
	var sum := Vector3.ZERO
	var count := 0
	for i in range(first.size() - 1):
		if last[i].origin.distance_to(first[i].origin) > OUT_THRESHOLD:
			sum += first[i].origin
			count += 1
	if count == 0:
		return frames[impact][first.size() - 1].origin
	return sum / count


func _fade(alpha: float) -> void:
	_layer.get_child(0).modulate.a = clampf(alpha, 0.0, 1.0)


## Letterbox bars and a title, built in code like the rest of the UI.
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4  # over the HUD, under the touch controls and menus
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.88
		bar.anchor_bottom = 0.12 if top else 1.0
		root.add_child(bar)
		_bars.append(bar)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars[0].add_child(_title)
	var hint := Label.new()
	hint.text = "click to skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.offset_right = -24
	_bars[1].add_child(hint)
	_layer.hide()

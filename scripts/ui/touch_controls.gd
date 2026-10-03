class_name TouchControls
extends CanvasLayer
## On-screen controls for touchscreens (Android), driving the same
## ThrowController actions the mouse does:
##
## - drag a finger anywhere on the screen to aim (yaw and pitch), like
##   moving the mouse;
## - hold the THROW button to sweep the swing gauge and let go to throw,
##   like the left mouse button — same timing, same cancel past 180;
## - drag along the STEP pad to step sideways along the line, like the
##   right mouse button;
## - pinch with two fingers to zoom, like the scroll wheel;
## - the pause button in the corner opens the pause menu (there's no Esc).
##
## Added by court.gd only on a touchscreen device (is_touch_device()), so
## the desktop game is unchanged. Each finger is tracked by its touch
## index from the moment it goes down, so a thumb on THROW and another
## finger aiming don't interfere.

signal pause_pressed

const AIM_SENSITIVITY := 0.12   ## degrees per pixel dragged, at 1080 px screen height
const STEP_SENSITIVITY := 0.008 ## metres per pixel dragged on the STEP pad, at 1080 px
const PINCH_SENSITIVITY := 0.08 ## FOV degrees per pixel the fingers move apart
const BUTTON_SIZE := 0.2        ## THROW button diameter, fraction of screen height

var thrower: ThrowController

var _throw_button: Control
var _step_pad: Control
var _pause_button: Control
var _throw_label: Label
## touch index -> what that finger is doing: "aim", "throw", "step", "ui"
var _fingers: Dictionary = {}
var _positions: Dictionary = {}  ## touch index -> last known position, for pinching
var _pinch_distance: float = -1.0


## True on phones and tablets: a touchscreen and no mouse to capture.
static func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")


func _ready() -> void:
	layer = 5  # above the HUD, below the pause menu
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_ui() -> void:
	_throw_button = _round_panel(Color(0.85, 0.2, 0.15, 0.55))
	_throw_label = _label("THROW")
	_throw_button.add_child(_throw_label)
	add_child(_throw_button)

	_step_pad = _round_panel(Color(1, 1, 1, 0.18))
	var step_label := _label("◀ STEP ▶")
	_step_pad.add_child(step_label)
	add_child(_step_pad)

	_pause_button = _round_panel(Color(0, 0, 0, 0.45))
	_pause_button.add_child(_label("II"))
	add_child(_pause_button)


func _round_panel(color: Color) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(999)
	style.border_color = Color(1, 1, 1, 0.6)
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # touches are read in _input()
	return panel


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Sizes everything from the screen height, so it's thumb-sized on any
## phone: THROW bottom right, STEP bottom left, pause top right (below the
## HUD's corner panel).
func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var unit := screen.y
	var margin := unit * 0.04
	var throw_size := Vector2.ONE * unit * BUTTON_SIZE
	_throw_button.size = throw_size
	_throw_button.position = screen - throw_size - Vector2(margin * 1.5, margin)
	_throw_label.add_theme_font_size_override("font_size", int(unit * 0.035))

	var step_size := Vector2(unit * 0.42, unit * 0.13)
	_step_pad.size = step_size
	_step_pad.position = Vector2(margin * 1.5, screen.y - step_size.y - margin)
	for label in _step_pad.get_children():
		label.add_theme_font_size_override("font_size", int(unit * 0.03))

	var pause_size := Vector2.ONE * unit * 0.09
	_pause_button.size = pause_size
	_pause_button.position = Vector2(screen.x - pause_size.x - margin, screen.y * 0.22)
	for label in _pause_button.get_children():
		label.add_theme_font_size_override("font_size", int(unit * 0.035))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var role := "aim"
		if _hit(_pause_button, event.position):
			role = "ui"
			pause_pressed.emit()
		elif _hit(_throw_button, event.position):
			role = "throw"
			_set_pressed(_throw_button, true)
			if thrower != null:
				thrower.begin_swing()
		elif _hit(_step_pad, event.position):
			role = "step"
		_fingers[event.index] = role
		_positions[event.index] = event.position
		_pinch_distance = -1.0
	else:
		var role: String = _fingers.get(event.index, "")
		_fingers.erase(event.index)
		_positions.erase(event.index)
		_pinch_distance = -1.0
		if role == "throw":
			_set_pressed(_throw_button, false)
			if thrower != null:
				thrower.end_swing()


func _on_drag(event: InputEventScreenDrag) -> void:
	_positions[event.index] = event.position
	if thrower == null:
		return
	var scale := 1080.0 / get_viewport().get_visible_rect().size.y
	match _fingers.get(event.index, ""):
		"aim":
			var aiming := _fingers.values().filter(func(r: String) -> bool: return r == "aim")
			if aiming.size() >= 2:
				_pinch(event)
			else:
				thrower.aim_by(event.relative * scale * AIM_SENSITIVITY)
		"step":
			thrower.step_by(event.relative.x * scale * STEP_SENSITIVITY)


## Two aiming fingers: zoom by how much further apart (zoom in) or closer
## together (out) they've moved. Godot reports each finger's drag
## separately, so the distance is re-measured from both positions.
func _pinch(_event: InputEventScreenDrag) -> void:
	var aim_indices := _fingers.keys().filter(func(i: int) -> bool: return _fingers[i] == "aim" and _positions.has(i))
	if aim_indices.size() < 2:
		return
	var distance: float = (_positions[aim_indices[0]] as Vector2).distance_to(_positions[aim_indices[1]])
	if _pinch_distance >= 0.0 and thrower.accepts_input():
		thrower.zoom_by(-(distance - _pinch_distance) * PINCH_SENSITIVITY)
	_pinch_distance = distance


func _hit(control: Control, at: Vector2) -> bool:
	if not control.visible:
		return false
	var rect := control.get_global_rect()
	# The buttons are round: test against the circle (or the pad's pill).
	var centre := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) / 2.0
	var half_straight := maxf(rect.size.x - rect.size.y, 0.0) / 2.0
	var nearest := Vector2(clampf(at.x, centre.x - half_straight, centre.x + half_straight), centre.y) if rect.size.x >= rect.size.y else centre
	return at.distance_to(nearest) <= radius * 1.15  # a little forgiving


func _set_pressed(control: Control, pressed: bool) -> void:
	control.scale = Vector2.ONE * (0.92 if pressed else 1.0)
	control.pivot_offset = control.size / 2.0


func _process(_delta: float) -> void:
	# Only show THROW / STEP when they'd do something.
	var usable := thrower != null and thrower.accepts_input()
	_throw_button.visible = usable and not thrower.is_throwing()
	_step_pad.visible = usable and not thrower.is_throwing()

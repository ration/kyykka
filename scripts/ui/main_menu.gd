extends Control
## Landing screen: Start Match / Quit. Set as the project's main scene
## so the game boots here instead of jumping straight into the court.

const COURT_SCENE := "res://scenes/court.tscn"


func _ready() -> void:
	# Any previous scene (a match) may have captured the mouse; make sure
	# it's back to a normal cursor for menu navigation.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Reset in case Return-to-menu came from a paused match.
	get_tree().paused = false
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var title := Label.new()
	title.text = "Kyykkä"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Hot-seat match, two teams, two halves"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	box.add_child(subtitle)

	box.add_child(_menu_button("Start Summer Match", _start_summer))
	box.add_child(_menu_button("Start Winter Match", _start_winter))
	box.add_child(_menu_button("Quit", _quit_game))


func _menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	button.pressed.connect(callback)
	return button


func _start_summer() -> void:
	GameMode.current = GameMode.Mode.SUMMER
	get_tree().change_scene_to_file(COURT_SCENE)


func _start_winter() -> void:
	GameMode.current = GameMode.Mode.WINTER
	get_tree().change_scene_to_file(COURT_SCENE)


func _quit_game() -> void:
	get_tree().quit()

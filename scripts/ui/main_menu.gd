extends Control
## Landing screen: Start Summer / Winter Match / Quit. Set as the
## project's main scene so the game boots here instead of jumping straight
## into the court. Picking a season opens a second panel to name the two
## teams (prefilled with the last names used) before the match starts.

const COURT_SCENE := "res://scenes/court.tscn"

var _menu_box: VBoxContainer
var _names_box: VBoxContainer
var _name_edits: Array[LineEdit] = []


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

	_menu_box = _centered_box()
	add_child(_menu_box)
	_menu_box.add_child(_title("Kyykkä", 56))
	_menu_box.add_child(_subtitle("Hot-seat match, two teams, two halves"))
	_menu_box.add_child(_menu_button("Start Summer Match", _choose_season.bind(GameMode.Mode.SUMMER)))
	_menu_box.add_child(_menu_button("Start Winter Match", _choose_season.bind(GameMode.Mode.WINTER)))
	_menu_box.add_child(_menu_button("Quit", _quit_game))

	_names_box = _centered_box()
	_names_box.hide()
	add_child(_names_box)
	_names_box.add_child(_title("Name the teams", 36))
	for i in range(2):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()  # the team's colour in the HUD
		swatch.color = GameMode.TEAM_COLORS[i]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var edit := LineEdit.new()
		edit.placeholder_text = GameMode.DEFAULT_TEAM_NAMES[i]
		edit.max_length = GameMode.MAX_TEAM_NAME_LENGTH
		edit.custom_minimum_size = Vector2(260, 40)
		edit.select_all_on_focus = true
		row.add_child(edit)
		_names_box.add_child(row)
		_name_edits.append(edit)
	# Enter moves from the first name to the second, then starts the match.
	_name_edits[0].text_submitted.connect(func(_text: String) -> void: _name_edits[1].grab_focus())
	_name_edits[1].text_submitted.connect(func(_text: String) -> void: _start_match())
	_names_box.add_child(_menu_button("Start Match", _start_match))
	_names_box.add_child(_menu_button("Back", _back_to_menu))


func _centered_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return box


func _title(text: String, size: int) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", size)
	title.add_theme_color_override("font_color", Color.WHITE)
	return title


func _subtitle(text: String) -> Label:
	var subtitle := Label.new()
	subtitle.text = text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	return subtitle


func _menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	button.pressed.connect(callback)
	return button


func _choose_season(mode: GameMode.Mode) -> void:
	GameMode.current = mode
	for i in range(2):
		# Blank when still the default, so the placeholder shows through.
		var current_name: String = GameMode.team_names[i]
		_name_edits[i].text = "" if current_name == GameMode.DEFAULT_TEAM_NAMES[i] else current_name
	_menu_box.hide()
	_names_box.show()
	_name_edits[0].grab_focus()


func _start_match() -> void:
	GameMode.set_team_names(_name_edits[0].text, _name_edits[1].text)
	get_tree().change_scene_to_file(COURT_SCENE)


func _back_to_menu() -> void:
	_names_box.hide()
	_menu_box.show()


func _unhandled_input(event: InputEvent) -> void:
	if _names_box.visible and event.is_action_pressed("ui_cancel"):
		_back_to_menu()
		get_viewport().set_input_as_handled()


func _quit_game() -> void:
	get_tree().quit()

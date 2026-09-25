class_name ResultsScreen
extends CanvasLayer
## End-of-match overlay: final per-half breakdown, winner, and
## Rematch / Main Menu buttons. Hidden until MatchController emits
## match_finished; before then the HUD/gameplay own the screen.

const COURT_SCENE := "res://scenes/court.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

var match_controller: MatchController

var _panel: PanelContainer
var _title_label: Label
var _score_label: Label


func _ready() -> void:
	assert(match_controller != null)
	_build_ui()
	_panel.hide()
	match_controller.match_finished.connect(_on_match_finished)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_content_margin_all(28)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(_title_label)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(_score_label)

	box.add_child(_menu_button("Rematch", _rematch))
	box.add_child(_menu_button("Main Menu", _return_to_main_menu))
	box.add_child(_menu_button("Quit", _quit_game))

	add_child(_panel)


func _menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 40)
	button.pressed.connect(callback)
	return button


func _on_match_finished() -> void:
	var m := match_controller.kyykka_match
	var team_a := m.team_a
	var team_b := m.team_b
	var winner := m.winner()

	_title_label.text = "Tie" if winner == null else "%s wins!" % winner.team_name
	_score_label.text = "%s %d — %d %s" % [
		team_a.team_name, m.total_score(team_a),
		m.total_score(team_b), team_b.team_name,
	]

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.show()


func _rematch() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(COURT_SCENE)


func _return_to_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit_game() -> void:
	get_tree().quit()

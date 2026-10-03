class_name PauseMenu
extends CanvasLayer
## Esc-toggled overlay during a match: Resume / Music on-off / Main Menu /
## Quit.
## Runs even while the tree is paused (process_mode = ALWAYS) so it can
## un-pause itself, and takes over mouse capture from ThrowController
## while open so its buttons are actually clickable.
##
## Online the game can't pause (the other player is still playing), so the
## menu just opens over it and `toggled` tells court.gd to stop the
## thrower taking input meanwhile. Main Menu then also leaves the match.
##
## Silent until the user presses Esc during the match; if the results
## screen is up (match already finished), it stays out of the way and
## lets the results screen own the exit flow instead.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

signal toggled(open: bool)

var enabled: bool = true  ## set to false once the match ends; results screen owns exits from there

var _panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	box.add_child(_menu_button("Resume", _resume))
	var music := _menu_button(_music_label(), Callable())
	music.pressed.connect(_toggle_music.bind(music))
	box.add_child(music)
	box.add_child(_menu_button("Main Menu", _return_to_main_menu))
	box.add_child(_menu_button("Quit", _quit_game))

	add_child(_panel)


func _menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 40)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _music_label() -> String:
	return "Music: On" if Music.enabled else "Music: Off"


func _toggle_music(button: Button) -> void:
	Music.enabled = not Music.enabled
	button.text = _music_label()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


## Opens or closes the menu: Esc, or TouchControls' pause button.
func toggle() -> void:
	if not enabled:
		return
	if _panel.visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	get_tree().paused = not Net.is_online()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.show()
	toggled.emit(true)


func _resume() -> void:
	_panel.hide()
	get_tree().paused = false
	if not TouchControls.is_touch_device():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	toggled.emit(false)


func _return_to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit_game() -> void:
	get_tree().quit()

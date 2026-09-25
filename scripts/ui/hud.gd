class_name HUD
extends CanvasLayer
## In-game overlay: running match score, whose turn it is, karttu
## remaining in the current attack, and the target pesä's kyykkä count.
## Built in code to match how the rest of this project constructs UI
## (see court.gd / throw_controller.gd's swing gauge).
##
## Owns nothing about game state — subscribes to MatchController's
## turn_changed/attack_scored/half_started signals and re-reads state
## from it on each notification.

var match_controller: MatchController

var _score_label: Label
var _turn_label: Label
var _karttu_label: Label
var _kyykka_label: Label
var _half_label: Label


func _ready() -> void:
	assert(match_controller != null)
	_build_ui()
	match_controller.half_started.connect(func(_n: int) -> void: _refresh())
	match_controller.turn_changed.connect(_refresh)
	match_controller.attack_scored.connect(_refresh)
	match_controller.match_finished.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var margin := 16.0

	var top_left := _panel()
	top_left.position = Vector2(margin, margin)
	add_child(top_left)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	top_left.add_child(box)

	_half_label = _label("Half 1")
	box.add_child(_half_label)

	_score_label = _label("")
	box.add_child(_score_label)

	var top_center := _panel()
	top_center.position = Vector2(0, margin)
	top_center.anchor_left = 0.5
	top_center.anchor_right = 0.5
	top_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top_center)

	var center_box := VBoxContainer.new()
	center_box.add_theme_constant_override("separation", 2)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_center.add_child(center_box)

	_turn_label = _label("")
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(_turn_label)

	var top_right := _panel()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.position = Vector2(-margin, margin)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(top_right)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 2)
	top_right.add_child(right_box)

	_karttu_label = _label("")
	right_box.add_child(_karttu_label)
	_kyykka_label = _label("")
	right_box.add_child(_kyykka_label)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh() -> void:
	var m := match_controller.kyykka_match
	var team_a := m.team_a
	var team_b := m.team_b
	var half_number := m.halves.size()

	_half_label.text = "Half %d / %d" % [half_number, KyykkaMatch.HALVES_PER_MATCH]
	_score_label.text = "%s %d — %d %s" % [
		team_a.team_name, _running_score(team_a),
		_running_score(team_b), team_b.team_name,
	]

	var attack := match_controller.current_attack
	if attack == null or m.is_finished():
		_turn_label.text = "Match over"
		_karttu_label.text = ""
		_kyykka_label.text = ""
		return

	_turn_label.text = "%s to throw" % attack.attacking_team.team_name
	_karttu_label.text = "Karttu %d / %d" % [
		attack.karttu_budget - attack.karttu_used, attack.karttu_budget,
	]
	var pesa := attack.pesa
	_kyykka_label.text = "Kyykkä  in %d · on line %d · out %d" % [
		pesa.in_square, pesa.on_line, pesa.removed,
	]


## KyykkaMatch.total_score() asserts every attack has finished, since a
## final score isn't well-defined mid-attack (penalties and unused-karttu
## bonuses depend on the finished state). For the running scoreboard we
## just want a live provisional total: settled attacks contribute their
## real score, in-progress attacks contribute the "positive" piece count
## they've knocked out so far.
func _running_score(team: Team) -> int:
	var total := 0
	for half in match_controller.kyykka_match.halves:
		var a := _attack_for_team(half, team)
		if a == null:
			continue
		total += a.score() if a.is_finished() else a.pesa.removed
	return total


func _attack_for_team(half: Half, team: Team) -> Attack:
	if half.attack_by_team_a.attacking_team == team:
		return half.attack_by_team_a
	if half.attack_by_team_b.attacking_team == team:
		return half.attack_by_team_b
	return null

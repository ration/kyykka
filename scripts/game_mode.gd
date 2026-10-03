extends Node
## Autoload singleton (registered as `GameMode` in project.godot). Holds
## the current season chosen from the main menu so the court and karttu
## can look at it during their own _ready() without needing a scene-arg
## channel through change_scene_to_file(). Also holds the team names typed
## in on the main menu, which carry over to Rematches.
##
## Summer keeps the current sand-court defaults; winter uses a snow-lit
## palette and lowers karttu friction so the karttu keeps sliding across
## the pesä after landing (real winter kyykkä on ice). Tower puts a summer
## match on a painted court on a skyscraper roof (see TowerLandscape); its
## karttu plays like summer.
## Only the karttu is affected — the kyykkä pieces still use the sturdy
## damping they need to stay upright and settle without rocking on
## BoxShape3D corners (see the corner-balance note in CLAUDE.md).

enum Mode { SUMMER, WINTER, TOWER }
var current: Mode = Mode.SUMMER

const DEFAULT_TEAM_NAMES: Array[String] = ["Team A", "Team B"]
const MAX_TEAM_NAME_LENGTH := 20
## Team A, team B: the HUD's turn cues and the name dialog's swatches.
const TEAM_COLORS: Array[Color] = [Color(0.35, 0.62, 1.0), Color(1.0, 0.78, 0.2)]
## UI scale on phones and tablets: the 1280x720 layout (project.godot's
## canvas_items stretch) fills a ~6" screen, so buttons and text came out
## about half their desktop size physically — too small to read or tap.
const TOUCH_UI_SCALE := 1.6

var team_names: Array[String] = DEFAULT_TEAM_NAMES.duplicate()


func _ready() -> void:
	if TouchControls.is_touch_device():
		get_tree().root.content_scale_factor = TOUCH_UI_SCALE
	# Android's Back button arrives as a "go back" request, which by default
	# quits the app — from anywhere, mid-match included. Make it Esc instead:
	# back out of a submenu, or open the pause menu.
	get_tree().quit_on_go_back = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# A press and a release: an action left "pressed" never reads as
		# just-pressed again, so only the first Back would have worked.
		for pressed in [true, false]:
			var back := InputEventAction.new()
			back.action = "ui_cancel"
			back.pressed = pressed
			Input.parse_input_event(back)


## Stores the names typed in for team A and B: trimmed, capped at
## MAX_TEAM_NAME_LENGTH, blank falling back to the default, and a
## duplicate of A's name numbered so the two can be told apart.
func set_team_names(a: String, b: String) -> void:
	var names: Array[String] = []
	for i in range(2):
		var trimmed := ([a, b][i] as String).strip_edges().left(MAX_TEAM_NAME_LENGTH)
		names.append(trimmed if trimmed != "" else DEFAULT_TEAM_NAMES[i])
	if names[0].to_lower() == names[1].to_lower():
		names[1] = names[1].left(MAX_TEAM_NAME_LENGTH - 2) + " 2"
	team_names = names


func mode_name() -> String:
	match current:
		Mode.WINTER:
			return "Winter"
		Mode.TOWER:
			return "Tower"
	return "Summer"


# Karttu tuning ---------------------------------------------------------------
# Summer values are the current tuned defaults from CLAUDE.md's karttu note
# (friction 0.1, landed_linear_damp 2.0, landed_angular_damp 3.0). Winter
# drops friction 5x so a landed karttu slides further on the "ice": it
# comes to rest ~13 m out (just past the pesä's 10 m back line) instead of
# summer's ~11.7 m. Measured with a karttu slide sweep:
# - Landed linear damping was only lowered a little (2.0 -> 1.8). Halving
#   it (0.7) slid the karttu off the end of the ground on every throw, and
#   even 1.3 did on 9 of 10.
# - Landed angular damping is *raised* (3.0 -> 5.0): on near-frictionless
#   ground a stopped karttu kept turning slowly (~0.1-0.25 rad/s), above
#   the sleep threshold but too slowly for SettlingBody's watchdog, and hit
#   settle_timeout_seconds (5s) on most throws. At 5.0 none did.

func karttu_friction() -> float:
	return 0.02 if current == Mode.WINTER else 0.1


func karttu_landed_linear_damp() -> float:
	return 1.8 if current == Mode.WINTER else 2.0


func karttu_landed_angular_damp() -> float:
	return 5.0 if current == Mode.WINTER else 3.0


# Ground appearance -----------------------------------------------------------
# Summer: the two ends of the court's low-frequency sand-noise texture (see
# court.gd's _build_ground_texture). Tower: the same texture as a green
# painted sports surface on the roof. Winter: the hollow/drift colours of the
# court's packed snow in shaders/ground.gdshader (see WinterLandscape), kept
# close and below white so the court reads as trodden snow, not white paint.

func ground_low_color() -> Color:
	match current:
		Mode.WINTER:
			return Color(0.80, 0.83, 0.89)
		Mode.TOWER:
			return Color(0.17, 0.36, 0.30)
	return Color(0.55, 0.48, 0.34)


func ground_high_color() -> Color:
	match current:
		Mode.WINTER:
			return Color(0.90, 0.91, 0.93)
		Mode.TOWER:
			return Color(0.22, 0.43, 0.35)
	return Color(0.82, 0.72, 0.52)


## The aiming dot: white, except black in winter, where white disappears
## against the snow.
func crosshair_color() -> Color:
	return Color(0, 0, 0, 0.85) if current == Mode.WINTER else Color(1, 1, 1, 0.8)


## White lines vanish on snow, so winter courts are marked in red instead.
func court_line_color() -> Color:
	return Color(0.72, 0.08, 0.10) if current == Mode.WINTER else Color.WHITE

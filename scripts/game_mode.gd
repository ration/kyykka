extends Node
## Autoload singleton (registered as `GameMode` in project.godot). Holds
## the current season chosen from the main menu so the court and karttu
## can look at it during their own _ready() without needing a scene-arg
## channel through change_scene_to_file(). Also holds the team names typed
## in on the main menu, which carry over to Rematches.
##
## Summer keeps the current sand-court defaults; winter uses a snow-lit
## palette and lowers karttu friction so the karttu keeps sliding across
## the pesä after landing (real winter kyykkä on ice).
## Only the karttu is affected — the kyykkä pieces still use the sturdy
## damping they need to stay upright and settle without rocking on
## BoxShape3D corners (see the corner-balance note in CLAUDE.md).

enum Mode { SUMMER, WINTER }

var current: Mode = Mode.SUMMER

const DEFAULT_TEAM_NAMES: Array[String] = ["Team A", "Team B"]
const MAX_TEAM_NAME_LENGTH := 20
## Team A, team B: the HUD's turn cues and the name dialog's swatches.
const TEAM_COLORS: Array[Color] = [Color(0.35, 0.62, 1.0), Color(1.0, 0.78, 0.2)]

var team_names: Array[String] = DEFAULT_TEAM_NAMES.duplicate()


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
	return "Winter" if current == Mode.WINTER else "Summer"


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
# court.gd's _build_ground_texture). Winter: the hollow/drift colours of the
# court's packed snow in shaders/ground.gdshader (see WinterLandscape), kept
# close and below white so the court reads as trodden snow, not white paint.

func ground_low_color() -> Color:
	return Color(0.80, 0.83, 0.89) if current == Mode.WINTER else Color(0.55, 0.48, 0.34)


func ground_high_color() -> Color:
	return Color(0.90, 0.91, 0.93) if current == Mode.WINTER else Color(0.82, 0.72, 0.52)


## White lines vanish on snow, so winter courts are marked in red instead.
func court_line_color() -> Color:
	return Color(0.72, 0.08, 0.10) if current == Mode.WINTER else Color.WHITE

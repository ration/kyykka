extends Node
## Autoload singleton (registered as `GameMode` in project.godot). Holds
## the current season chosen from the main menu so the court and karttu
## can look at it during their own _ready() without needing a scene-arg
## channel through change_scene_to_file().
##
## Summer keeps the current sand-court defaults; winter uses a snow-lit
## palette and lowers karttu friction/landed-damping so the karttu keeps
## sliding across the pesä after landing (real winter kyykkä on ice).
## Only the karttu is affected — the kyykkä pieces still use the sturdy
## damping they need to stay upright and settle without rocking on
## BoxShape3D corners (see the corner-balance note in CLAUDE.md).

enum Mode { SUMMER, WINTER }

var current: Mode = Mode.SUMMER


func mode_name() -> String:
	return "Winter" if current == Mode.WINTER else "Summer"


# Karttu tuning ---------------------------------------------------------------
# Summer values are the current tuned defaults from CLAUDE.md's karttu note
# (friction 0.1, landed_linear_damp 2.0, landed_angular_damp 3.0). Winter
# drops friction 5x and roughly halves landed damping so a landed karttu
# slides much further on the "ice"; still short enough that the karttu
# settles within settle_timeout_seconds (5s), verified via
# tools/simulate_throws.gd.

func karttu_friction() -> float:
	return 0.02 if current == Mode.WINTER else 0.1


func karttu_landed_linear_damp() -> float:
	return 0.7 if current == Mode.WINTER else 2.0


func karttu_landed_angular_damp() -> float:
	return 1.5 if current == Mode.WINTER else 3.0


# Ground appearance -----------------------------------------------------------
# Two colours per mode form a low-frequency noise texture (see court.gd's
# _build_ground) so the field isn't just a flat colour. Winter's colours
# stay very close so the surface reads as snow rather than sky-blue paint.

func ground_low_color() -> Color:
	return Color(0.86, 0.90, 0.96) if current == Mode.WINTER else Color(0.55, 0.48, 0.34)


func ground_high_color() -> Color:
	return Color(0.98, 0.99, 1.0) if current == Mode.WINTER else Color(0.82, 0.72, 0.52)

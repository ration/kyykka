extends Node
## Autoload singleton (registered as `GameMode` in project.godot). Holds
## the current season chosen from the main menu so the court and karttu
## can look at it during their own _ready() without needing a scene-arg
## channel through change_scene_to_file().
##
## Summer keeps the current sand-court defaults; winter uses a snow-lit
## palette and lowers karttu friction so the karttu keeps sliding across
## the pesä after landing (real winter kyykkä on ice).
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
# Two colours per mode form a low-frequency noise texture (see court.gd's
# _build_ground) so the field isn't just a flat colour. Winter's colours
# stay very close so the surface reads as snow rather than sky-blue paint.

func ground_low_color() -> Color:
	return Color(0.86, 0.90, 0.96) if current == Mode.WINTER else Color(0.55, 0.48, 0.34)


func ground_high_color() -> Color:
	return Color(0.98, 0.99, 1.0) if current == Mode.WINTER else Color(0.82, 0.72, 0.52)

class_name PieceClassifier
extends RefCounted
## Pure geometry: classifies a kyykkä's position relative to a pesä
## rectangle and the gap in front of it. No Node/physics dependency, so
## PesaScorer (which reads real 3D positions) and GUT tests can both drive
## it directly.
##
## `depth` is the piece's distance from the pesä's front line (0) toward
## its back line (pesa_depth); negative is in front of the square, toward
## the other one — see PesaView.to_pesa_local(), which produces coordinates
## in this space regardless of which end of the court the pesä is at.

enum Zone { AKKA, PAPPI, KUOKKAVIERAS, REMOVED }

## How far along a side line from the front line still counts as the
## front line (kyykkaliiga.fi: on a side line "alle 10 cm etäisyydellä
## eturajasta" is -2 and not a pappi).
const FRONT_CORNER := 0.1


## Which zone (see Pesa) a kyykkä at (x, depth) is in; within `margin` of a
## line counts as on it. On the front line — or a side line within
## FRONT_CORNER of it — it's still an akka; on a side or back line, a
## pappi; past the front line but inside the court's width and short of
## the other square (`gap` metres away), a kuokkavieras; anywhere else, out.
static func classify(x: float, depth: float, half_width: float, pesa_depth: float, gap: float, margin: float) -> Zone:
	var inside_x := half_width - absf(x)
	var inside_front := depth
	var inside_back := pesa_depth - depth
	if inside_x >= -margin and inside_front >= -margin and inside_back >= -margin:
		var on_side := inside_x < margin
		var on_back := inside_back < margin
		if on_back or (on_side and depth > FRONT_CORNER):
			return Zone.PAPPI
		return Zone.AKKA
	if depth < 0.0 and depth > -gap and inside_x >= -margin:
		return Zone.KUOKKAVIERAS
	return Zone.REMOVED


## Where a pappi is stood up: the nearest point on the side or back line
## (the front line doesn't make papit), as (x, depth).
static func snap_to_line(x: float, depth: float, half_width: float, pesa_depth: float) -> Vector2:
	var to_side := absf(half_width - absf(x))
	var to_back := absf(pesa_depth - depth)
	if to_back <= to_side:
		return Vector2(clampf(x, -half_width, half_width), pesa_depth)
	return Vector2(signf(x) * half_width if x != 0.0 else half_width, clampf(depth, 0.0, pesa_depth))

class_name PieceClassifier
extends RefCounted
## Pure geometry: classifies a kyykkä's position relative to a pesä
## rectangle. No Node/physics dependency, so Phase 3's PesaScorer (which
## reads real 3D positions) and GUT tests can both drive it directly.
##
## `depth` is the piece's distance from the pesä's front line (0) toward
## its back line (pesa_depth) — see PesaView.to_pesa_local(), which
## produces coordinates in this space regardless of which end of the
## court the pesä is at.

enum Zone { IN_SQUARE, ON_LINE, REMOVED }


## Classifies by distance to the nearest of the three relevant edges
## (front, back, left/right side). Positive "inside margin" means the
## point is that far inside the rectangle from its nearest edge;
## negative means it's already past that edge.
static func classify(x: float, depth: float, half_width: float, pesa_depth: float, margin: float) -> Zone:
	var inside_margin_x := half_width - absf(x)
	var inside_margin_front := depth
	var inside_margin_back := pesa_depth - depth
	var nearest_edge_margin := minf(inside_margin_x, minf(inside_margin_front, inside_margin_back))

	if nearest_edge_margin < -margin:
		return Zone.REMOVED
	if nearest_edge_margin < margin:
		return Zone.ON_LINE
	return Zone.IN_SQUARE


## Where a kyykkä that ended up ON_LINE is stood up: the nearest point on
## the pesä's outline (front, back or a side line), as (x, depth). Rules:
## a kyykkä landing on the line is turned upright on the line, where it
## counts as on the line (Attack.PENALTY_ON_LINE) until knocked out.
static func snap_to_line(x: float, depth: float, half_width: float, pesa_depth: float) -> Vector2:
	var to_side := half_width - absf(x)
	var to_front := absf(depth)
	var to_back := absf(pesa_depth - depth)
	var nearest := minf(absf(to_side), minf(to_front, to_back))
	if nearest == to_front:
		return Vector2(clampf(x, -half_width, half_width), 0.0)
	if nearest == to_back:
		return Vector2(clampf(x, -half_width, half_width), pesa_depth)
	return Vector2(signf(x) * half_width if x != 0.0 else half_width, clampf(depth, 0.0, pesa_depth))

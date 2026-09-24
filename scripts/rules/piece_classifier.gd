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

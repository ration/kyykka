extends GutTest
## half_width=2.5, pesa_depth=5.0, gap (between the squares) 10 m,
## margin=0.035 throughout, matching the court/kyykkä dimensions (court.gd,
## PesaView). Depth runs 0 at the front line to 5 at the back line;
## negative depth is in front of the square, toward the other one.

const HALF_WIDTH := 2.5
const DEPTH := 5.0
const GAP := 10.0
const MARGIN := 0.035
const Zone := PieceClassifier.Zone


func _zone(x: float, depth: float) -> PieceClassifier.Zone:
	return PieceClassifier.classify(x, depth, HALF_WIDTH, DEPTH, GAP, MARGIN)


func test_inside_the_square_is_akka() -> void:
	assert_eq(_zone(0.0, 2.5), Zone.AKKA)


func test_on_the_front_line_is_still_akka() -> void:
	assert_eq(_zone(0.0, 0.01), Zone.AKKA)
	assert_eq(_zone(1.0, -0.02), Zone.AKKA)


func test_on_a_side_line_near_the_front_counts_as_the_front_line() -> void:
	assert_eq(_zone(HALF_WIDTH - 0.01, 0.05), Zone.AKKA, "within 10 cm of the front line")
	assert_eq(_zone(HALF_WIDTH - 0.01, 0.3), Zone.PAPPI, "further back it's a pappi")


func test_on_the_back_or_a_side_line_is_pappi() -> void:
	assert_eq(_zone(0.0, DEPTH - 0.01), Zone.PAPPI)
	assert_eq(_zone(-HALF_WIDTH + 0.02, 2.5), Zone.PAPPI)
	assert_eq(_zone(HALF_WIDTH, DEPTH), Zone.PAPPI, "corner pappi")


func test_in_the_gap_between_the_squares_is_kuokkavieras() -> void:
	assert_eq(_zone(0.0, -0.5), Zone.KUOKKAVIERAS)
	assert_eq(_zone(2.0, -9.5), Zone.KUOKKAVIERAS)


func test_out_of_the_square_and_the_gap_is_removed() -> void:
	assert_eq(_zone(HALF_WIDTH + 0.5, 2.5), Zone.REMOVED, "off the side")
	assert_eq(_zone(0.0, DEPTH + 0.5), Zone.REMOVED, "off the back")
	assert_eq(_zone(HALF_WIDTH + 0.5, -2.0), Zone.REMOVED, "beside the gap")
	assert_eq(_zone(0.0, -GAP - 0.5), Zone.REMOVED, "into the other square")


func test_snap_to_line_picks_the_nearest_side_or_back_line() -> void:
	assert_eq(PieceClassifier.snap_to_line(-2.0, 4.98, 2.5, 5.0), Vector2(-2.0, 5.0))
	assert_eq(PieceClassifier.snap_to_line(2.52, 3.0, 2.5, 5.0), Vector2(2.5, 3.0))
	assert_eq(PieceClassifier.snap_to_line(-2.47, 1.0, 2.5, 5.0), Vector2(-2.5, 1.0))
	var on_line := PieceClassifier.snap_to_line(2.52, 3.0, 2.5, 5.0)
	assert_eq(_zone(on_line.x, on_line.y), Zone.PAPPI, "stood up, it's still a pappi")

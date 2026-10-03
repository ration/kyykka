extends GutTest
## half_width=2.5, pesa_depth=5.0, margin=0.035 throughout, matching the
## default court/kyykkä dimensions (see court.gd, PesaView).

const HALF_WIDTH := 2.5
const DEPTH := 5.0
const MARGIN := 0.035


func test_center_is_in_square() -> void:
	assert_eq(
		PieceClassifier.classify(0.0, 2.5, HALF_WIDTH, DEPTH, MARGIN),
		PieceClassifier.Zone.IN_SQUARE
	)


func test_near_front_line_is_on_line() -> void:
	assert_eq(
		PieceClassifier.classify(0.0, 0.01, HALF_WIDTH, DEPTH, MARGIN),
		PieceClassifier.Zone.ON_LINE
	)


func test_near_back_line_is_on_line() -> void:
	assert_eq(
		PieceClassifier.classify(0.0, DEPTH - 0.01, HALF_WIDTH, DEPTH, MARGIN),
		PieceClassifier.Zone.ON_LINE
	)


func test_near_side_line_is_on_line() -> void:
	assert_eq(
		PieceClassifier.classify(HALF_WIDTH - 0.01, 2.5, HALF_WIDTH, DEPTH, MARGIN),
		PieceClassifier.Zone.ON_LINE
	)


func test_past_front_line_is_removed() -> void:
	assert_eq(
		PieceClassifier.classify(0.0, -0.5, HALF_WIDTH, DEPTH, MARGIN),
		PieceClassifier.Zone.REMOVED
	)


func test_past_side_line_is_removed() -> void:
	assert_eq(
		PieceClassifier.classify(HALF_WIDTH + 0.5, 2.5, HALF_WIDTH, DEPTH, MARGIN),
		PieceClassifier.Zone.REMOVED
	)


func test_snap_to_line_picks_the_nearest_line() -> void:
	# Near the front line, just inside and just outside.
	assert_eq(PieceClassifier.snap_to_line(1.0, 0.02, 2.5, 5.0), Vector2(1.0, 0.0))
	assert_eq(PieceClassifier.snap_to_line(1.0, -0.03, 2.5, 5.0), Vector2(1.0, 0.0))
	# Back line.
	assert_eq(PieceClassifier.snap_to_line(-2.0, 4.98, 2.5, 5.0), Vector2(-2.0, 5.0))
	# Side lines, either side.
	assert_eq(PieceClassifier.snap_to_line(2.52, 3.0, 2.5, 5.0), Vector2(2.5, 3.0))
	assert_eq(PieceClassifier.snap_to_line(-2.47, 1.0, 2.5, 5.0), Vector2(-2.5, 1.0))
	# A stood-up piece is on the line, by the classifier's own rule.
	var on_line := PieceClassifier.snap_to_line(2.52, 3.0, 2.5, 5.0)
	assert_eq(PieceClassifier.classify(on_line.x, on_line.y, 2.5, 5.0, 0.035), PieceClassifier.Zone.ON_LINE)

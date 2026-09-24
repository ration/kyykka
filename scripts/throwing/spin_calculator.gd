class_name SpinCalculator
extends RefCounted
## Pure math for the swing-timing spin mechanic: how long a throw is
## airborne, and what spin rate a given release timing should produce.
## No Node dependency, so it's directly GUT-testable like PieceClassifier.


## Time (seconds) for a throw launched at `elevation_degrees` above
## horizontal at `speed` m/s to return to its launch height, under
## `gravity` m/s^2. Symmetric-parabola approximation — good enough since
## the karttu's release height is tiny relative to the arc.
static func time_of_flight(speed: float, elevation_degrees: float, gravity: float) -> float:
	return 2.0 * speed * sin(deg_to_rad(elevation_degrees)) / gravity


## Spin rate (radians/sec) for a swing released at `gauge_degrees` (0-180,
## see ThrowController). Releasing at exactly the middle (90) yields
## exactly half a rotation (PI radians) over `flight_seconds` — enough to
## bring the karttu back to lying parallel to the stack it started
## broadside to (a symmetric rod looks the same after a half turn), i.e.
## a "flush" landing. Below 90 spins slower (under-rotates by landing);
## above 90 spins faster (over-rotates).
static func spin_rate(gauge_degrees: float, flight_seconds: float) -> float:
	return (PI / flight_seconds) * (gauge_degrees / 90.0)

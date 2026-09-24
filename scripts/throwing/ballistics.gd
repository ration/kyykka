class_name Ballistics
extends RefCounted
## Pure projectile math (no drag) for turning "where the player is aiming"
## into a launch angle at the fixed throw speed. No Node dependency, so
## it's directly GUT-testable. Exact only while the karttu flies with no
## damping — see Karttu, which replaces (not combines with) the project's
## default damping during flight for this reason.


## Lowest launch elevation (degrees) that carries a projectile at `speed`
## over `distance` horizontally while rising by `height_delta` (negative
## = ends lower than it started), under `gravity`. Falls back to 45
## degrees — the maximum-range angle — when the target is out of reach.
static func launch_elevation(speed: float, distance: float, height_delta: float, gravity: float) -> float:
	# y(x) = x*u - a*(1 + u^2) with u = tan(elevation), a = g*x^2 / (2*v^2);
	# solving y(distance) = height_delta for u is a quadratic.
	var a := gravity * distance * distance / (2.0 * speed * speed)
	var discriminant := distance * distance - 4.0 * a * (height_delta + a)
	if discriminant < 0.0:
		return 45.0
	return rad_to_deg(atan((distance - sqrt(discriminant)) / (2.0 * a)))


## Seconds to cover `distance` horizontally at `speed`, launched at
## `elevation_degrees`.
static func flight_time(speed: float, distance: float, elevation_degrees: float) -> float:
	return distance / (speed * cos(deg_to_rad(elevation_degrees)))

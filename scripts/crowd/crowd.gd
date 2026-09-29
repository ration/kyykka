class_name Crowd
extends Node3D
## Spectators along both sides of the court: groups of university students,
## each group one guild in its own colour of overalls (see SpectatorMesh),
## now and then a friend from another guild tagging along. Purely visual —
## no collision, and they stand clear of where struck kyykkä and the
## karttu end up (see layout()).
##
## About half of them brought a can and take a swig from it every so
## often. They sway idly and cheer — arms up, jumping — when a throw knocks kyykkä
## out (more of them, for longer, the more it knocked out), and all of them
## when the match ends. One of them, front row near the middle (so the
## thrower sees him from either end), wears `shirt_logo` on his chest. Added by court.gd and handed the MatchController,
## like the HUD; CourtAudio listens to `cheered` for the sound.

signal cheered(fraction: float, seconds: float)

## Overall colours, one per guild.
const GUILD_COLORS: Array[Color] = [
	Color(0.75, 0.10, 0.10), Color(0.08, 0.08, 0.09), Color(0.95, 0.45, 0.08),
	Color(0.95, 0.80, 0.10), Color(0.12, 0.25, 0.70), Color(0.42, 0.15, 0.55),
	Color(0.95, 0.45, 0.70), Color(0.50, 0.80, 0.15), Color(0.10, 0.65, 0.65),
	Color(0.90, 0.90, 0.88), Color(0.45, 0.05, 0.15), Color(0.45, 0.70, 0.90),
	Color(0.10, 0.35, 0.15), Color(0.45, 0.45, 0.48),
]

const MIN_SIDE_CLEARANCE := 1.8  ## metres from the court's side line to the front row
const ROWS_DEPTH := 2.6          ## how far back from the front row the crowd goes
const MIN_SPACING := 0.55        ## metres between two spectators
const SEED := 2024
const DRINK_SECONDS := Vector2(1.6, 2.8)     ## how long one swig lasts
const BETWEEN_DRINKS := Vector2(8.0, 25.0)   ## seconds from one swig to the next

var match_controller: MatchController
var court_width: float = 5.0
var court_length: float = 20.0
var shirt_logo: Texture2D  ## optional; printed on one spectator's chest

var _spectators: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	name = "Crowd"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var winter := GameMode.current == GameMode.Mode.WINTER
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9

	var colors := GUILD_COLORS.duplicate()
	for i in range(colors.size()):  # seeded shuffle, so neighbouring groups differ
		var j := rng.randi_range(i, colors.size() - 1)
		var swap: Color = colors[i]
		colors[i] = colors[j]
		colors[j] = swap

	var spots := layout(rng, court_width / 2.0, court_length / 2.0)
	var logo_wearer := logo_wearer_index(spots, court_width / 2.0) if shirt_logo != null else -1
	for index in range(spots.size()):
		var spot := spots[index]
		var overall: Color = colors[spot.group % colors.size()]
		if rng.randf() < 0.12:
			overall = GUILD_COLORS[rng.randi() % GUILD_COLORS.size()]
		var look := SpectatorMesh.random_look(rng, overall, winter)
		if index == logo_wearer:
			look.shirt = Color(0.95, 0.95, 0.94)
			look.long_hair = false
			look.chest_patch = winter  # the shirt's under zipped-up overalls
		var person := MeshInstance3D.new()
		person.material_override = material
		var down := SpectatorMesh.build(look, SpectatorMesh.Pose.DOWN)
		person.mesh = down
		var height := rng.randf_range(0.92, 1.1)
		var base := Transform3D(Basis(Vector3.UP, spot.yaw).scaled(Vector3.ONE * height), spot.position)
		person.transform = base
		add_child(person)
		if index == logo_wearer:
			person.add_child(_logo_sprite(winter))
		_spectators.append({
			"node": person, "down": down, "up": SpectatorMesh.build(look, SpectatorMesh.Pose.CHEER), "base": base,
			"drink": SpectatorMesh.build(look, SpectatorMesh.Pose.DRINK) if look.can != null else null,
			"next_drink": rng.randf_range(1.0, BETWEEN_DRINKS.y), "drink_until": -1.0,
			"phase": rng.randf() * TAU, "sway_rate": rng.randf_range(0.8, 1.6),
			"jump_rate": rng.randf_range(8.0, 11.0), "cheer_from": -1.0, "cheer_until": -1.0,
		})

	if match_controller != null:
		match_controller.attack_scored.connect(_on_attack_scored)
		match_controller.match_finished.connect(cheer.bind(1.0, 4.0))


## Where everyone stands: groups of 3-8 along both long sides, in a band
## from MIN_SIDE_CLEARANCE past the side line to ROWS_DEPTH further back,
## each turned roughly toward the middle of the court. Returns
## [{position, yaw, group}].
## The front-row spectator closest to the middle of the court.
static func logo_wearer_index(spots: Array[Dictionary], half_width: float) -> int:
	var best := -1
	for i in range(spots.size()):
		var at: Vector3 = spots[i].position
		if absf(at.x) > half_width + MIN_SIDE_CLEARANCE + 0.6:
			continue
		if best < 0 or absf(at.z) < absf(spots[best].position.z):
			best = i
	return best


## The logo, on the T-shirt or (winter) a patch on the chest; moves with
## the person's node as they sway and jump.
func _logo_sprite(winter: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = shirt_logo
	var width := SpectatorMesh.CHEST_PATCH_WIDTH if winter else SpectatorMesh.SHIRT_PRINT_WIDTH
	sprite.pixel_size = width / shirt_logo.get_width()
	sprite.shaded = true
	sprite.double_sided = false
	sprite.position = SpectatorMesh.CHEST_PATCH_CENTRE if winter else SpectatorMesh.SHIRT_PRINT_CENTRE
	return sprite


static func layout(rng: RandomNumberGenerator, half_width: float, half_length: float) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var group := 0
	for side: float in [-1.0, 1.0]:
		var z := -half_length - 2.0 + rng.randf_range(0.0, 1.5)
		while z < half_length + 2.0:
			var size := rng.randi_range(3, 8)
			var span := 0.35 * size + 0.4
			var centre := z + span / 2.0
			for i in range(size):
				for attempt in range(12):
					var x := side * (half_width + MIN_SIDE_CLEARANCE + pow(rng.randf(), 1.5) * ROWS_DEPTH)
					var at := Vector3(x, 0, centre + rng.randf_range(-span / 2.0, span / 2.0))
					if spots.any(func(s: Dictionary) -> bool: return s.position.distance_to(at) < MIN_SPACING):
						continue
					var look_at := Vector3(0, 0, at.z * 0.6)
					var yaw := atan2(look_at.x - at.x, look_at.z - at.z) + rng.randf_range(-0.4, 0.4)
					spots.append({"position": at, "yaw": yaw, "group": group})
					break
			group += 1
			z += span + rng.randf_range(0.4, 2.5)
	return spots


## `fraction` of the crowd, picked at random, cheers for about `seconds`,
## each starting with a little delay.
func cheer(fraction: float, seconds: float) -> void:
	cheered.emit(fraction, seconds)
	for s in _spectators:
		if randf() < fraction:
			s.cheer_from = _time + randf_range(0.0, 0.4)
			s.cheer_until = s.cheer_from + seconds * randf_range(0.7, 1.1)


func _on_attack_scored() -> void:
	var result := match_controller.last_throw_result
	if result == null:
		return
	var removed := result.removed_from_square + result.removed_from_line
	if removed > 0:
		cheer(minf(0.35 + 0.15 * removed, 1.0), 1.0 + 0.3 * mini(removed, 5))


func _process(delta: float) -> void:
	_time += delta
	for s in _spectators:
		var node: MeshInstance3D = s.node
		var cheering: bool = _time >= s.cheer_from and _time < s.cheer_until
		if s.drink != null and _time >= s.next_drink:
			if cheering:
				s.next_drink = s.cheer_until + randf_range(0.5, 3.0)  # finish cheering first
			else:
				s.drink_until = _time + randf_range(DRINK_SECONDS.x, DRINK_SECONDS.y)
				s.next_drink = s.drink_until + randf_range(BETWEEN_DRINKS.x, BETWEEN_DRINKS.y)
		var mesh: ArrayMesh = s.down
		if cheering:
			mesh = s.up
		elif _time < s.drink_until:
			mesh = s.drink
		if node.mesh != mesh:
			node.mesh = mesh
		var sway := sin(_time * s.sway_rate + s.phase) * 0.025
		var lift := absf(sin((_time - s.cheer_from) * s.jump_rate)) * 0.12 if cheering else 0.0
		node.transform = s.base * Transform3D(Basis(Vector3.BACK, sway), Vector3(0, lift, 0))

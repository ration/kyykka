class_name CourtAudio
extends Node3D
## All of the court's sound effects: wooden knocks and ground landings
## positioned where they happen, the karttu's slide along the court, the
## throw's whoosh, and cues for a missed swing, kyykkä knocked out and the
## match ending. Streams come from SoundSynth (no audio files); instantiated
## by court.gd and handed the MatchController, like the HUD.
##
## Impacts come from every SettlingBody's `impacted` signal. Both bodies of
## a colliding pair report the same contact, and the karttu's own report
## can undercount (see Karttu._reference_velocity()), so reports are
## gathered per pair for the physics frame and only the stronger one plays.
## Resting contact jitter (a stacked pair settling, a piece rocking) stays
## under IMPACT_THRESHOLD, and a pair that just played is muted for
## PAIR_COOLDOWN_MS so a bouncing landing doesn't rattle.
##
## The crowd's cheers and boo take ~0.5-1 s each to synthesise, so they're rendered
## on a WorkerThreadPool task (then kept in SoundSynth's cache); a cheer
## before they're ready is just silent.

## An impact sound was played (the host sends these to an online client,
## whose own bodies don't collide — see OnlineLink).
signal impact_played(kind: int, strength: float, at: Vector3)

enum Kind { KARTTU_HIT, KYYKKA_CLACK, KARTTU_LAND, KYYKKA_LAND }

const IMPACT_THRESHOLD := 0.4  ## m/s of velocity change; below this is silent
const PAIR_COOLDOWN_MS := 120
const VARIANTS := 4  ## synthesised versions of each impact, picked at random
const POOL_SIZE := 16
const MIN_GAIN := 0.08  ## linear gain of the faintest audible impact

## Velocity change (m/s) that plays an impact at full volume.
const FULL_STRENGTH := {
	Kind.KARTTU_HIT: 8.0,
	Kind.KYYKKA_CLACK: 4.0,
	Kind.KARTTU_LAND: 6.0,
	Kind.KYYKKA_LAND: 3.0,
}
const BASE_DB := {
	Kind.KARTTU_HIT: 0.0,
	Kind.KYYKKA_CLACK: -4.0,
	Kind.KARTTU_LAND: -2.0,
	Kind.KYYKKA_LAND: -8.0,
}

const SLIDE_FULL_SPEED := 8.0  ## m/s at which the slide loop is at full volume
const SLIDE_MIN_SPEED := 0.3
const SILENT_DB := -60.0
const CHEER_VARIANTS := 2

var match_controller: MatchController
var crowd: Crowd  ## optional; its cheers play here
## Online client: bodies are moved by the host's snapshots, so impacts
## come from play_impact() calls instead of local contacts, and the slide
## follows the karttu's movement rather than its (zero) velocity.
var remote_physics: bool = false
var _last_karttu_position := Vector3.ZERO

var _impact_streams: Dictionary = {}  ## Kind -> Array[AudioStreamWAV]
var _pool: Array[AudioStreamPlayer3D] = []
var _next_in_pool: int = 0
var _pending: Dictionary = {}  ## pair key -> [Kind, strength, position]
var _last_played_ms: Dictionary = {}  ## pair key -> Time.get_ticks_msec()

var _karttu: Karttu
var _slide_player: AudioStreamPlayer3D
var _whoosh_player: AudioStreamPlayer
var _cue_player: AudioStreamPlayer

var _whoosh_streams: Array[AudioStreamWAV] = []
var _miss_stream: AudioStreamWAV
var _chime_stream: AudioStreamWAV
var _jingle_stream: AudioStreamWAV

var _cheer_streams: Array[AudioStreamWAV] = []  ## small cheers, once rendered
var _big_cheer_stream: AudioStreamWAV
var _cheer_players: Array[AudioStreamPlayer] = []
var _cheer_task: int = -1
var _rendered_cheers: Array[AudioStreamWAV] = []  ## written by the render task only
var _boo_stream: AudioStreamWAV  ## once rendered (with the cheers)
var _boo_player: AudioStreamPlayer


func _ready() -> void:
	assert(match_controller != null)
	_build_streams()
	_build_players()

	get_tree().node_added.connect(_on_node_added)
	for body in _settling_bodies_under(get_parent()):
		_watch(body)

	match_controller.thrower.thrown.connect(_on_thrown)
	match_controller.thrower.swing_cancelled.connect(_play_cue.bind(_miss_stream, -6.0))
	match_controller.attack_scored.connect(_on_attack_scored)
	match_controller.match_finished.connect(_play_cue.bind(_jingle_stream, -3.0))
	if crowd != null:
		crowd.cheered.connect(_on_crowd_cheered)
		crowd.booed.connect(_on_crowd_booed)
		_boo_player = AudioStreamPlayer.new()
		add_child(_boo_player)
		_start_cheer_render()


func _build_streams() -> void:
	var winter := GameMode.current == GameMode.Mode.WINTER
	var season := "winter" if winter else "summer"
	for kind in Kind.values():
		var variants: Array[AudioStreamWAV] = []
		for v in range(VARIANTS):
			var key := "%s:%d:%s" % [Kind.keys()[kind], v, season]
			variants.append(SoundSynth.cached(key, _impact_builder(kind, v, winter)))
		_impact_streams[kind] = variants

	for v in range(VARIANTS):
		_whoosh_streams.append(SoundSynth.cached("whoosh:%d" % v, SoundSynth.whoosh.bind(100 + v)))
	_miss_stream = SoundSynth.cached("swing_miss", SoundSynth.swing_miss)
	_chime_stream = SoundSynth.cached("score_chime", SoundSynth.score_chime)
	_jingle_stream = SoundSynth.cached("match_end", SoundSynth.match_end_jingle)


func _impact_builder(kind: Kind, variant: int, winter: bool) -> Callable:
	match kind:
		Kind.KARTTU_HIT:
			return SoundSynth.karttu_hit.bind(variant)
		Kind.KYYKKA_CLACK:
			return SoundSynth.kyykka_clack.bind(variant)
		Kind.KARTTU_LAND:
			return SoundSynth.ground_impact.bind(variant, winter, true)
		_:
			return SoundSynth.ground_impact.bind(variant, winter, false)


func _build_players() -> void:
	for i in range(POOL_SIZE):
		var player := _positional_player()
		_pool.append(player)
		add_child(player)

	var season := "winter" if GameMode.current == GameMode.Mode.WINTER else "summer"
	_slide_player = _positional_player()
	_slide_player.stream = SoundSynth.cached("slide:" + season, SoundSynth.slide_loop.bind(season == "winter"))
	_slide_player.volume_db = SILENT_DB
	add_child(_slide_player)

	_whoosh_player = AudioStreamPlayer.new()
	add_child(_whoosh_player)
	_cue_player = AudioStreamPlayer.new()
	add_child(_cue_player)
	for i in range(2):  # so a new cheer doesn't cut off the last one
		var player := AudioStreamPlayer.new()
		_cheer_players.append(player)
		add_child(player)


## The far pesä is 10-15 m from the listener (the camera), so the default
## unit_size of 1 m would make every hit there ~22 dB quieter than one at
## your feet; 6 m keeps the far end clearly audible but still distant.
func _positional_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.unit_size = 6.0
	player.max_db = 3.0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	return player


func _settling_bodies_under(node: Node) -> Array[SettlingBody]:
	var result: Array[SettlingBody] = []
	for child in node.get_children():
		if child is SettlingBody:
			result.append(child)
		result.append_array(_settling_bodies_under(child))
	return result


## Each half's fresh PesaViews bring new kyykkä into the tree.
func _on_node_added(node: Node) -> void:
	if node is SettlingBody:
		_watch(node)


func _watch(body: SettlingBody) -> void:
	if body.impacted.is_connected(_on_impacted):
		return
	body.impacted.connect(_on_impacted.bind(body))
	if body is Karttu:
		_karttu = body


func _on_impacted(other: Node, strength: float, body: SettlingBody) -> void:
	if remote_physics:
		return
	var kind := _kind_for(body, other)
	if kind < 0:
		return
	var a := body.get_instance_id()
	var b := other.get_instance_id()
	var key := "%d:%d" % [mini(a, b), maxi(a, b)]
	# Sound from the kyykkä, not the karttu's centre up to 0.4 m away.
	var at: Vector3 = other.global_position if other is Kyykka and body is Karttu else body.global_position
	if not _pending.has(key) or _pending[key][1] < strength:
		_pending[key] = [kind, strength, at]


func _kind_for(body: SettlingBody, other: Node) -> int:
	var karttu := body is Karttu or other is Karttu
	if other is StaticBody3D:
		return Kind.KARTTU_LAND if karttu else Kind.KYYKKA_LAND
	if other is SettlingBody:
		return Kind.KARTTU_HIT if karttu else Kind.KYYKKA_CLACK
	return -1


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for key in _pending:
		var report: Array = _pending[key]
		if report[1] < IMPACT_THRESHOLD:
			continue
		if now - _last_played_ms.get(key, -PAIR_COOLDOWN_MS) < PAIR_COOLDOWN_MS:
			continue
		_last_played_ms[key] = now
		play_impact(report[0], report[1], report[2])
	_pending.clear()
	_update_slide(delta)


func play_impact(kind: int, strength: float, at: Vector3) -> void:
	if not _impact_streams.has(kind):
		return
	impact_played.emit(kind, strength, at)
	var player := _free_player()
	var variants: Array = _impact_streams[kind]
	player.stream = variants[randi() % variants.size()]
	player.global_position = at
	player.volume_db = BASE_DB[kind] + impact_volume_db(strength, FULL_STRENGTH[kind])
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()


## An idle player if there is one, otherwise the next one round-robin
## (cutting off the oldest sound in a big scatter).
func _free_player() -> AudioStreamPlayer3D:
	for i in range(POOL_SIZE):
		var player := _pool[(_next_in_pool + i) % POOL_SIZE]
		if not player.playing:
			_next_in_pool = (_next_in_pool + i + 1) % POOL_SIZE
			return player
	var oldest := _pool[_next_in_pool]
	_next_in_pool = (_next_in_pool + 1) % POOL_SIZE
	return oldest


## Loudness of an impact: amplitude proportional to the velocity change,
## capped at full volume, with a floor so the faintest audible knock isn't
## inaudible.
static func impact_volume_db(strength: float, full_strength: float) -> float:
	return linear_to_db(clampf(strength / full_strength, MIN_GAIN, 1.0))


## Fades the slide loop in and out with the karttu's speed while it's in
## contact with the ground (not while it's airborne or knocking kyykkä).
func _update_slide(delta: float) -> void:
	var target_db := SILENT_DB
	var speed := 0.0
	if _karttu != null and remote_physics:
		var moved := _karttu.global_position - _last_karttu_position
		_last_karttu_position = _karttu.global_position
		speed = Vector2(moved.x, moved.z).length() / delta
		if speed > 30.0:  # reset to the thrower between turns, not a slide
			speed = 0.0
		if _karttu.global_position.y < 0.06 and speed > SLIDE_MIN_SPEED:
			target_db = linear_to_db(clampf(speed / SLIDE_FULL_SPEED, MIN_GAIN, 1.0)) - 6.0
		_slide_player.global_position = _karttu.global_position
	elif _karttu != null and not _karttu.freeze:
		speed = Vector2(_karttu.linear_velocity.x, _karttu.linear_velocity.z).length()
		var on_ground := _karttu.get_colliding_bodies().any(func(b: Node) -> bool: return b is StaticBody3D)
		if on_ground and speed > SLIDE_MIN_SPEED:
			target_db = linear_to_db(clampf(speed / SLIDE_FULL_SPEED, MIN_GAIN, 1.0)) - 6.0
		_slide_player.global_position = _karttu.global_position

	# Quick attack, slower release, so bounces don't chop it up.
	var rate := 0.5 if target_db > _slide_player.volume_db else 0.15
	_slide_player.volume_db = lerpf(_slide_player.volume_db, target_db, rate)
	_slide_player.pitch_scale = lerpf(0.85, 1.15, clampf(speed / SLIDE_FULL_SPEED, 0.0, 1.0))
	if _slide_player.volume_db > SILENT_DB + 1.0:
		if not _slide_player.playing:
			_slide_player.play()
	elif _slide_player.playing:
		_slide_player.stop()


func _on_thrown() -> void:
	_whoosh_player.stream = _whoosh_streams[randi() % _whoosh_streams.size()]
	_whoosh_player.volume_db = -8.0
	_whoosh_player.pitch_scale = randf_range(0.92, 1.08)
	_whoosh_player.play()


## Chime when the throw knocked kyykkä out of the pesä, pitched up a
## little for each extra piece.
func _on_attack_scored() -> void:
	var result := match_controller.last_throw_result
	if result == null:
		return
	var removed := result.removed_from_square + result.removed_from_line
	if removed > 0:
		_play_cue(_chime_stream, -8.0, 1.0 + 0.06 * mini(removed - 1, 6))


func _play_cue(stream: AudioStreamWAV, volume_db: float, pitch: float = 1.0) -> void:
	_cue_player.stream = stream
	_cue_player.volume_db = volume_db
	_cue_player.pitch_scale = pitch
	_cue_player.play()


func _start_cheer_render() -> void:
	if SoundSynth.lookup("cheer_big") != null:
		for v in range(CHEER_VARIANTS):
			_cheer_streams.append(SoundSynth.lookup("cheer:%d" % v))
		_big_cheer_stream = SoundSynth.lookup("cheer_big")
		_boo_stream = SoundSynth.lookup("boo")
	elif DisplayServer.get_name() != "headless":  # nobody listening in tests/tools
		_cheer_task = WorkerThreadPool.add_task(_render_cheers)


func _render_cheers() -> void:
	for v in range(CHEER_VARIANTS):
		_rendered_cheers.append(SoundSynth.crowd_cheer(200 + v, false))
	_rendered_cheers.append(SoundSynth.crowd_cheer(300, true))
	_rendered_cheers.append(SoundSynth.crowd_boo(400))


func _process(_delta: float) -> void:
	if _cheer_task < 0 or not WorkerThreadPool.is_task_completed(_cheer_task):
		return
	WorkerThreadPool.wait_for_task_completion(_cheer_task)
	_cheer_task = -1
	for v in range(CHEER_VARIANTS):
		SoundSynth.store("cheer:%d" % v, _rendered_cheers[v])
		_cheer_streams.append(_rendered_cheers[v])
	_big_cheer_stream = _rendered_cheers[CHEER_VARIANTS]
	SoundSynth.store("cheer_big", _big_cheer_stream)
	_boo_stream = _rendered_cheers[CHEER_VARIANTS + 1]
	SoundSynth.store("boo", _boo_stream)


func _exit_tree() -> void:
	if _cheer_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_cheer_task)


## Louder the more of the crowd is cheering; the whole crowd for a long
## time (the match ending) gets the big cheer.
func _on_crowd_cheered(fraction: float, seconds: float) -> void:
	if _cheer_streams.is_empty():
		return
	var big := fraction >= 1.0 and seconds >= 3.0
	var player := _cheer_players[0] if not _cheer_players[0].playing else _cheer_players[1]
	player.stream = _big_cheer_stream if big else _cheer_streams[randi() % _cheer_streams.size()]
	player.volume_db = -6.0 + linear_to_db(clampf(fraction, 0.3, 1.0))
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


## The karttu went into the crowd: they boo, and whoever it came at cut
## off their cheer.
func _on_crowd_booed(_point: Vector3) -> void:
	for player in _cheer_players:
		player.stop()
	if _boo_stream == null:
		return
	_boo_player.stream = _boo_stream
	_boo_player.volume_db = -5.0
	_boo_player.pitch_scale = randf_range(0.95, 1.05)
	_boo_player.play()

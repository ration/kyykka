extends Node
## Autoload singleton (registered as `Music` in project.godot) playing the
## background music: a track for the main menu and one per game mode —
## MenuMusic (kantele folk), SummerMusic (steel-pan calypso), MusicSynth's
## humppa (winter) and TowerMusic (house). The main menu and the court each
## call play() when they load; a different track crossfades in, the same
## one (a Rematch) just carries on. An autoload so the music survives scene
## changes.
##
## Each track takes a second or two of GDScript to render, so they render
## on WorkerThreadPool tasks at boot: the menu's first on its own (so it's
## on as soon as possible, ~3 s), then the other three together. A track asked for before it's
## ready starts as soon as it is (the old one keeps playing meanwhile).
## Skipped entirely under --headless (tests, tools/simulate_throws.gd),
## where nobody's listening.

const VOLUME_DB := -12.0
## Per-track trim on VOLUME_DB: every track is normalised to the same peak,
## and the menu's sustained strings and drone sound louder than the match
## tracks' drums at the same peak.
const TRACK_TRIM_DB := {"menu": -3.0}
const SILENT_DB := -40.0
const FADE_IN_SECONDS := 2.0
const FADE_OUT_SECONDS := 1.2
const TRACKS: Array[String] = ["menu", "summer", "winter", "tower"]  ## the first renders first

var enabled: bool = true:
	set(value):
		enabled = value
		_apply_enabled()

var _player: AudioStreamPlayer  ## the track playing (or about to)
var _streams := {}               ## track -> AudioStreamWAV, once rendered
var _tasks := {}                 ## track -> WorkerThreadPool task id, while rendering
var _rendered := {}              ## track -> AudioStreamWAV, written by the tasks
var _rendered_lock := Mutex.new()
var _wanted: String = "menu"
var _playing: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while paused
	set_process(false)
	if DisplayServer.get_name() == "headless":
		return
	_tasks[TRACKS[0]] = WorkerThreadPool.add_task(_render.bind(TRACKS[0]))
	set_process(true)


## The track for a GameMode.Mode.
static func track_for_mode(mode: int) -> String:
	match mode:
		GameMode.Mode.WINTER:
			return "winter"
		GameMode.Mode.TOWER:
			return "tower"
	return "summer"


## Switches to `track` (one of TRACKS), crossfading from whatever's on.
func play(track: String) -> void:
	assert(track in TRACKS, "unknown music track %s" % track)
	_wanted = track
	_apply_enabled()


func _render(track: String) -> void:
	var stream: AudioStreamWAV
	match track:
		"menu":
			stream = MenuMusic.render()
		"summer":
			stream = SummerMusic.render()
		"winter":
			stream = MusicSynth.humppa()
		"tower":
			stream = TowerMusic.render()
	_rendered_lock.lock()
	_rendered[track] = stream
	_rendered_lock.unlock()


func _process(_delta: float) -> void:
	for track in _tasks.keys():
		if not WorkerThreadPool.is_task_completed(_tasks[track]):
			continue
		WorkerThreadPool.wait_for_task_completion(_tasks[track])
		_tasks.erase(track)
		_rendered_lock.lock()
		_streams[track] = _rendered[track]
		_rendered_lock.unlock()
		if track == _wanted:
			_apply_enabled()
	if _tasks.is_empty():
		var rest := TRACKS.filter(func(track: String) -> bool: return not _streams.has(track))
		for track in rest:
			_tasks[track] = WorkerThreadPool.add_task(_render.bind(track))
		if rest.is_empty():
			set_process(false)


func _exit_tree() -> void:
	for task in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(task)


func _apply_enabled() -> void:
	if not enabled:
		_fade_out()
		_playing = ""
		return
	if _playing == _wanted or not _streams.has(_wanted):
		return
	_fade_out()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.stream = _streams[_wanted]
	_player.volume_db = SILENT_DB
	_player.play()
	create_tween().tween_property(_player, "volume_db", VOLUME_DB + TRACK_TRIM_DB.get(_wanted, 0.0), FADE_IN_SECONDS)
	_playing = _wanted


func _fade_out() -> void:
	if _player == null:
		return
	var old := _player
	_player = null
	var tween := create_tween()
	tween.tween_property(old, "volume_db", SILENT_DB, FADE_OUT_SECONDS)
	tween.tween_callback(old.queue_free)

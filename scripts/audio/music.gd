extends Node
## Autoload singleton (registered as `Music` in project.godot) playing the
## looping humppa from MusicSynth. An autoload so the music carries on
## across the menu -> court -> Rematch scene changes instead of restarting
## with each scene.
##
## Rendering the loop takes a second or two of GDScript, so it happens on
## a WorkerThreadPool task at boot and the music fades in once it's done.
## Skipped entirely under --headless (tests, tools/simulate_throws.gd),
## where nobody's listening.

const VOLUME_DB := -12.0
const FADE_IN_SECONDS := 2.0

var enabled: bool = true:
	set(value):
		enabled = value
		_apply_enabled()

var _player: AudioStreamPlayer
var _stream: AudioStreamWAV
var _task_id: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while paused
	set_process(false)
	if DisplayServer.get_name() == "headless":
		return
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_task_id = WorkerThreadPool.add_task(_render)
	set_process(true)


func _render() -> void:
	_stream = MusicSynth.humppa()


func _process(_delta: float) -> void:
	if not WorkerThreadPool.is_task_completed(_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	set_process(false)
	_player.stream = _stream
	_apply_enabled()


func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)


func _apply_enabled() -> void:
	if _player == null or _player.stream == null:
		return
	if enabled and not _player.playing:
		_player.volume_db = -40.0
		_player.play()
		create_tween().tween_property(_player, "volume_db", VOLUME_DB, FADE_IN_SECONDS)
	elif not enabled:
		_player.stop()

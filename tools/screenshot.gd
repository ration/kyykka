extends SceneTree
## Renders a few fixed views of the court to PNGs, for checking visual
## changes without playing. Needs a real display (it opens a window for a
## few seconds); --headless renders nothing.
##
## Usage:
##   godot --path . --resolution 1280x720 --script tools/screenshot.gd -- [summer|winter|tower] [out_dir]
## (default out_dir: user://screenshots)
##
## Like tools/simulate_throws.gd, stays untyped against game classes and
## load()s the court at runtime, so court.gd/karttu.gd compile after the
## GameMode autoload is registered.

const VIEWS := {
	# The in-game view: whatever ThrowController does with the camera for the first turn.
	"thrower": null,
	"overview": [Vector3(9.0, 7.0, 16.0), Vector3(0.0, 0.0, -2.0)],
	"horizon": [Vector3(-2.0, 1.7, 14.0), Vector3(3.0, 3.0, -60.0)],
	"closeup": [Vector3(1.5, 1.2, -1.5), Vector3(0.0, 0.0, -5.0)],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode_name := args[0] if args.size() > 0 else "summer"
	var out_dir := args[1] if args.size() > 1 else "user://screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var game_mode := get_root().get_node("GameMode")
	game_mode.current = game_mode.Mode.get(mode_name.to_upper(), game_mode.Mode.SUMMER)
	var court: Node = load("res://scenes/court.tscn").instantiate()
	get_root().add_child(court)
	# A scene added during _initialize() only runs _ready() on the first frame.
	await process_frame
	# Hide the HUD, menus and swing gauge so the shots show only the scene.
	for layer in court.find_children("*", "CanvasLayer", true, false):
		layer.visible = false

	var camera := Camera3D.new()
	court.add_child(camera)
	for view_name in VIEWS:
		var view = VIEWS[view_name]
		if view != null:
			camera.look_at_from_position(view[0], view[1])
			camera.make_current()
		for i in range(20):
			await process_frame
		var path := out_dir.path_join("%s_%s.png" % [mode_name, view_name])
		get_root().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	quit()

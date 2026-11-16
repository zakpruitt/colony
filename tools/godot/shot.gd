extends SceneTree
## Runs the main scene in a real window and saves what it shows as PNG files,
## so an agent can look at the game. Needs a display: do not pass --headless.
##
## Run through `python tools/dev.py shot`, which passes:
##   --out=<absolute path without extension>  where to save
##   --seconds=<float>                        how long to run before each shot
##   --count=<int>                            how many shots to take
##   --scene=<res:// path>                    scene to run instead of the main scene

var _out: String = ""
var _seconds: float = 2.0
var _count: int = 1
var _scene: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--seconds="):
			_seconds = arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--count="):
			_count = arg.trim_prefix("--count=").to_int()
		elif arg.begins_with("--scene="):
			_scene = arg.trim_prefix("--scene=")
	if _out.is_empty():
		print("[shot] FAIL no --out given")
		quit(1)
		return
	if _scene.is_empty():
		_scene = ProjectSettings.get_setting("application/run/main_scene")
	var scene: PackedScene = load(_scene)
	if scene == null:
		print("[shot] FAIL could not load %s" % _scene)
		quit(1)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	current_scene = main
	_take_shots()


func _take_shots() -> void:
	for index: int in _count:
		await create_timer(_seconds).timeout
		await RenderingServer.frame_post_draw
		var path: String = _out + ".png" if _count == 1 else "%s_%02d.png" % [_out, index + 1]
		var error: Error = root.get_texture().get_image().save_png(path)
		if error != OK:
			print("[shot] FAIL could not save %s (%s)" % [path, error_string(error)])
			quit(1)
			return
		print("[shot] saved %s" % path)
	quit(0)

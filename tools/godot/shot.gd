extends SceneTree
## Runs the main scene in a real window and saves what it shows as PNG files,
## so an agent can look at the game. Needs a display: do not pass --headless.
##
## Each shot is the whole composed window (spec 058 R9): the world and the sharp UI layer over it,
## at the window's size, 1280x720 unless told. So that a size bigger than the screen still works,
## the scene runs in a [SubViewport] of exactly that size which stretches the world's 640x360
## pixels over it as the game's window does (its canvas items scaled by a whole number), and the
## shot is that viewport's picture.
##
## Run through `python tools/dev.py shot`, which passes:
##   --out=<absolute path without extension>  where to save
##   --seconds=<float>                        how long to run before each shot
##   --count=<int>                            how many shots to take
##   --scene=<res:// path>                    scene to run instead of the main scene
##   --window=<W>x<H>                         the window's size (1280x720 unless told)

var _out: String = ""
var _seconds: float = 2.0
var _count: int = 1
var _scene: String = ""
var _window: Vector2i = Vector2i(1280, 720)
var _frame: SubViewport


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
		elif arg.begins_with("--window="):
			var sides: PackedStringArray = arg.trim_prefix("--window=").split("x")
			if sides.size() == 2:
				_window = Vector2i(sides[0].to_int(), sides[1].to_int())
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
	_frame = frame_for(_window)
	root.add_child(_frame)
	_frame.add_child(scene.instantiate())
	_take_shots()


## The viewport a shot of a [param window]-sized window runs the scene in: that size, stretching
## the world's 640x360 pixels over it by a whole number as the game's window does. (A test makes
## one to check the layers come out as in the game.)
static func frame_for(window: Vector2i) -> SubViewport:
	var frame := SubViewport.new()
	frame.name = "ShotWindow"
	frame.size = window
	frame.size_2d_override = UiRoot.WORLD_SIZE
	frame.size_2d_override_stretch = true
	frame.snap_2d_transforms_to_pixel = true
	frame.snap_2d_vertices_to_pixel = true
	frame.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return frame


func _take_shots() -> void:
	for index: int in _count:
		await create_timer(_seconds).timeout
		await RenderingServer.frame_post_draw
		var path: String = _out + ".png" if _count == 1 else "%s_%02d.png" % [_out, index + 1]
		var error: Error = _composed().save_png(path)
		if error != OK:
			print("[shot] FAIL could not save %s (%s)" % [path, error_string(error)])
			quit(1)
			return
		print("[shot] saved %s" % path)
	quit(0)


## What the window shows now, at the window's size.
func _composed() -> Image:
	return _frame.get_texture().get_image()

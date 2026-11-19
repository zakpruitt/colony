class_name WindowSettings
extends Node
## How the game's window opens, and what the player made of it (spec 067): its mode (windowed,
## maximized, full screen) and, when windowed, its size and place, kept in a small JSON file of
## their own under [code]user://[/code], apart from the save and the other settings.
##
## On a first run the window opens maximized if the screen has room for the UI at twice its
## size ([method first_mode]); after that it opens as it was left. [kbd]F11[/kbd] switches
## between full screen and the window as it was.
##
## Every decision is made here from plain values (a screen's size, the file, what the window was
## seen to be), so tests check them with no window. Only when [member window] is set, which
## [method for_game] does for a game someone plays, is a real window read and changed.

## The window's mode, as this class remembers it.
enum Mode { WINDOWED, MAXIMIZED, FULL_SCREEN }

## Where the window's settings live unless told otherwise.
const DEFAULT_PATH: String = "user://colony.window"
## The command-line flag that leaves the window as the project opens it (the shot tool passes it).
const DEFAULT_FLAG: String = "--window-default"
## The least usable space a screen needs for a first run to open maximized: the UI's smallest
## room at twice the size.
const LARGE_ENOUGH: Vector2i = Vector2i(1920, 1080)
## How long the window must hold still, in seconds, before a change of it is taken and saved: a
## resize or a move is then one write, not one per frame.
const SETTLE_SECONDS: float = 0.5
## How much of the top of a remembered window must be on one screen for its place to be used.
const GRIP: Vector2i = Vector2i(128, 32)
## The modes' names in the file.
const NAMES: Dictionary[Mode, String] = {
	Mode.WINDOWED: "windowed",
	Mode.MAXIMIZED: "maximized",
	Mode.FULL_SCREEN: "full_screen",
}
const MODE_KEY: String = "mode"
const BACK_KEY: String = "back"
const SIZE_KEY: String = "size"
const PLACE_KEY: String = "place"

## The window's mode.
var mode: Mode = Mode.WINDOWED
## What [kbd]F11[/kbd] goes back to from full screen: windowed or maximized.
var back: Mode = Mode.WINDOWED
## The window's size and place when windowed. A size of zero: none remembered, the project's.
var rect: Rect2i = Rect2i()
## True when [member rect]'s place is to be used: remembered, and on a screen now.
var place_known: bool = false
## The real window this reads and changes, or null (tests): then it only decides and saves.
var window: Window

var _path: String
var _loaded: bool = false
## What the window was last seen to be, and for how long it has been so.
var _seen_mode: Mode = Mode.WINDOWED
var _seen_rect: Rect2i = Rect2i()
var _still: float = 0.0


## Window settings kept in the file at [param path].
func _init(path: String = DEFAULT_PATH) -> void:
	name = "WindowSettings"
	_path = path


func _ready() -> void:
	load_file()
	set_process(window != null)
	if window == null:
		return
	var screens: Array[Rect2i] = []
	for index: int in DisplayServer.get_screen_count():
		screens.append(DisplayServer.screen_get_usable_rect(index))
	decide(DisplayServer.screen_get_usable_rect(window.current_screen).size, screens)
	_apply(true)


func _process(delta: float) -> void:
	if window.mode != Window.MODE_MINIMIZED:
		observe(_mode_of(window.mode), Rect2i(window.position, window.size), delta)


func _exit_tree() -> void:
	if window != null:
		_take(_seen_mode, _seen_rect)  # a change made just before closing


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F11:
		return
	toggle_full_screen()
	get_viewport().set_input_as_handled()


## True for a game someone plays: on a display named [param display] (not headless), and not
## run by a script or told [constant DEFAULT_FLAG] in [param args]. Tests, the shot tool and
## every headless run get no window settings.
static func wanted(display: String, args: PackedStringArray) -> bool:
	if display == "headless":
		return false
	for arg: String in args:
		if arg == "-s" or arg == "--script" or arg == DEFAULT_FLAG:
			return false
	return true


## The window settings of the game [param host] is: [param given] if a test named its own (it
## then changes no window), else new ones on the real window if this run is [method wanted],
## else none. They become [param host]'s child.
static func for_game(host: Node, given: WindowSettings) -> WindowSettings:
	var made: WindowSettings = given
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if made == null and wanted(DisplayServer.get_name(), args):
		made = WindowSettings.new()
		made.window = host.get_window()
	if made != null:
		host.add_child(made)
	return made


## How the window opens on a first run on a screen with [param usable] pixels free: maximized
## if that is at least [constant LARGE_ENOUGH], else windowed at the project's size.
static func first_mode(usable: Vector2i) -> Mode:
	if usable.x >= LARGE_ENOUGH.x and usable.y >= LARGE_ENOUGH.y:
		return Mode.MAXIMIZED
	return Mode.WINDOWED


## True if a window at [param place] can be reached on one of [param screens]: at least
## [constant GRIP] of its top edge is on it.
static func on_a_screen(place: Rect2i, screens: Array[Rect2i]) -> bool:
	var top := Rect2i(place.position, Vector2i(place.size.x, GRIP.y))
	for screen: Rect2i in screens:
		var shown: Rect2i = top.intersection(screen)
		if shown.size.x >= GRIP.x and shown.size.y >= GRIP.y:
			return true
	return false


## The file this keeps.
func file_path() -> String:
	return _path


## Reads the file. False, with nothing changed, if it is missing or cannot be understood: the
## next [method decide] is then a first run's.
func load_file() -> bool:
	_loaded = false
	if not FileAccess.file_exists(_path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK or not (json.data is Dictionary):
		return false
	var data: Dictionary = json.data
	var read_mode: Variant = NAMES.find_key(data.get(MODE_KEY))
	if read_mode == null:
		return false
	var read_index: int = read_mode
	mode = read_index as Mode
	back = Mode.MAXIMIZED if data.get(BACK_KEY) == NAMES[Mode.MAXIMIZED] else Mode.WINDOWED
	var size: Vector2i = _pair(data.get(SIZE_KEY))
	rect = Rect2i(_pair(data.get(PLACE_KEY)), size) if size.x > 0 and size.y > 0 else Rect2i()
	_loaded = true
	return true


## Decides how the window opens on a screen with [param usable] pixels free, [param screens]
## being every screen's usable part: as the file said if [method load_file] read one (its
## place only if it is still [method on_a_screen]), else as [method first_mode] says.
func decide(usable: Vector2i, screens: Array[Rect2i]) -> void:
	if not _loaded:
		mode = first_mode(usable)
		back = Mode.WINDOWED
		rect = Rect2i()
	place_known = rect.size != Vector2i.ZERO and on_a_screen(rect, screens)
	if not place_known:
		rect.size = rect.size.min(usable)
	_seen_mode = mode
	_seen_rect = rect
	_still = 0.0


## What [kbd]F11[/kbd] does: full screen, or from full screen the window as it was. Saved.
func toggle_full_screen() -> void:
	if mode == Mode.FULL_SCREEN:
		mode = back
	else:
		back = mode
		mode = Mode.FULL_SCREEN
	_apply(false)
	save()


## Tells what the window is now: [param seen_mode], and at [param seen_rect] (which counts
## only when windowed), [param delta] seconds after the last telling. A change that has held
## for [constant SETTLE_SECONDS] is taken and saved.
func observe(seen_mode: Mode, seen_rect: Rect2i, delta: float) -> void:
	var moved: bool = seen_mode == Mode.WINDOWED and seen_rect != _seen_rect
	if seen_mode != _seen_mode or moved:
		_seen_mode = seen_mode
		_seen_rect = seen_rect
		_still = 0.0
		return
	_still += delta
	if _still >= SETTLE_SECONDS:
		_take(seen_mode, seen_rect)


## Writes the file. Returns true if it was written.
func save() -> bool:
	var data: Dictionary = {MODE_KEY: NAMES[mode], BACK_KEY: NAMES[back]}
	if rect.size != Vector2i.ZERO:
		data[SIZE_KEY] = [rect.size.x, rect.size.y]
		data[PLACE_KEY] = [rect.position.x, rect.position.y]
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(JSON.stringify(data))
	file.close()
	return stored


## Makes what the window was seen to be the remembered state, and saves if that changes it.
func _take(seen_mode: Mode, seen_rect: Rect2i) -> void:
	var changed: bool = false
	if seen_mode != mode:
		if seen_mode == Mode.FULL_SCREEN:
			back = mode
		mode = seen_mode
		changed = true
	if seen_mode == Mode.WINDOWED and seen_rect != rect:
		rect = seen_rect
		place_known = true
		changed = true
	if changed:
		save()


## Two whole numbers from a saved [param value], or zero for anything else.
static func _pair(value: Variant) -> Vector2i:
	if not (value is Array):
		return Vector2i.ZERO
	var pair: Array = value
	if pair.size() != 2 or not (pair[0] is float and pair[1] is float):
		return Vector2i.ZERO
	var x: float = pair[0]
	var y: float = pair[1]
	return Vector2i(roundi(x), roundi(y))


## This class's name for a real window's [param real] mode.
static func _mode_of(real: Window.Mode) -> Mode:
	match real:
		Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN:
			return Mode.FULL_SCREEN
		Window.MODE_MAXIMIZED:
			return Mode.MAXIMIZED
	return Mode.WINDOWED


## Gives the real window, if there is one, the remembered mode. The remembered size and place
## are set when windowed, and with [param place_first] (the start) under any other mode too, so
## leaving it later goes back to them.
func _apply(place_first: bool) -> void:
	if window == null:
		return
	if (mode == Mode.WINDOWED or place_first) and rect.size != Vector2i.ZERO:
		window.mode = Window.MODE_WINDOWED
		window.size = rect.size
		if place_known:
			window.position = rect.position
		else:
			window.move_to_center()
	match mode:
		Mode.WINDOWED:
			window.mode = Window.MODE_WINDOWED
		Mode.MAXIMIZED:
			window.mode = Window.MODE_MAXIMIZED
		Mode.FULL_SCREEN:
			window.mode = Window.MODE_FULLSCREEN

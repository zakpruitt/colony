class_name WindowSettings
extends Node
## How the game's window opens, and what the player made of it (spec 067): its mode (windowed,
## maximized, full screen) and, when windowed, its size and place, kept in a small JSON file of
## their own under [code]user://[/code], apart from the save and the other settings.
##
## On a first run the window opens maximized if a maximized window on the screen has room for
## the UI at twice its size, in full screen if only the bare screen has ([method first_mode]);
## after that it opens as it was left. [kbd]F11[/kbd] switches between full screen and the
## window as it was.
##
## Every decision is made here from plain values (a screen's size, the file, what the window was
## seen to be), so tests check them with no window. Only when [member window] is set, which
## [method for_game] does for a game someone plays, is a real window read and changed.

## The window's mode, as this class remembers it.
enum Mode { WINDOWED, MAXIMIZED, FULL_SCREEN }

## Where the window's settings live unless told otherwise.
const DEFAULT_PATH: String = "user://colony.window"
## Appended to the path for the file written before it is renamed into place, as the save does.
const TEMP_SUFFIX: String = ".tmp"
## The command-line flag that leaves the window as the project opens it (the shot tool passes it).
const DEFAULT_FLAG: String = "--window-default"
## The room a first run wants inside the window: the UI's smallest room at twice the size.
const LARGE_ENOUGH: Vector2i = Vector2i(1920, 1080)
## The height a maximized window's frame (its title bar) is taken to have when the real window
## cannot say: 23 pixels on Windows at 100%, more at larger text sizes.
const FRAME_HEIGHT: int = 32
## The least size a remembered window is given: a smaller one in the file is raised to it.
const MIN_SIZE: Vector2i = Vector2i(640, 360)
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
## How many times the file has been written by this object.
var writes: int = 0

var _path: String
var _loaded: bool = false
## True if the file gave [member rect] a place as well as a size.
var _place_read: bool = false
## What the window was last seen to be, and for how long it has been so.
var _seen_mode: Mode = Mode.WINDOWED
var _seen_rect: Rect2i = Rect2i()
var _still: float = 0.0
## True once the window has been seen to hold still: what it was then is where it started.
var _based: bool = false


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
	var screen: int = window.current_screen
	# The frame's height, measured on the window as it opens (windowed, with its title bar).
	var frame: int = window.get_size_with_decorations().y - window.size.y
	decide(
		DisplayServer.screen_get_size(screen),
		DisplayServer.screen_get_usable_rect(screen).size,
		screens,
		frame if frame > 0 else FRAME_HEIGHT
	)
	_apply(true)


func _process(delta: float) -> void:
	if window.mode != Window.MODE_MINIMIZED:
		observe(_mode_of(window.mode), Rect2i(window.position, window.size), delta)


func _exit_tree() -> void:
	if window != null:
		flush()


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


## How the window opens on a first run on a screen of [param screen] pixels with [param usable]
## of them free (no taskbar), a maximized window's frame taking [param frame_height] of those:
## maximized if what is left inside the frame is at least [constant LARGE_ENOUGH]; in full
## screen if only the bare screen is (a 1920x1080 screen); else windowed at the project's size.
static func first_mode(
	screen: Vector2i, usable: Vector2i, frame_height: int = FRAME_HEIGHT
) -> Mode:
	if usable.x >= LARGE_ENOUGH.x and usable.y - frame_height >= LARGE_ENOUGH.y:
		return Mode.MAXIMIZED
	if screen.x >= LARGE_ENOUGH.x and screen.y >= LARGE_ENOUGH.y:
		return Mode.FULL_SCREEN
	return Mode.WINDOWED


## The one of [param screens] a window at [param place] lands on: the one most of its top edge
## is on, the window taken to be no wider than the screen, and at least [constant GRIP] of it.
## An empty rectangle if there is none: the window could not be reached.
static func screen_of(place: Rect2i, screens: Array[Rect2i]) -> Rect2i:
	var best := Rect2i()
	var most: int = 0
	for screen: Rect2i in screens:
		var top := Rect2i(place.position, Vector2i(mini(place.size.x, screen.size.x), GRIP.y))
		var shown: Rect2i = top.intersection(screen)
		if shown.size.x >= GRIP.x and shown.size.y >= GRIP.y and shown.size.x > most:
			best = screen
			most = shown.size.x
	return best


## True if a window at [param place] can be reached on one of [param screens].
static func on_a_screen(place: Rect2i, screens: Array[Rect2i]) -> bool:
	return screen_of(place, screens).size != Vector2i.ZERO


## The file this keeps.
func file_path() -> String:
	return _path


## Reads the file. False, with nothing changed, if it is missing or cannot be understood (not
## JSON, no known mode): the next [method decide] is then a first run's. A size smaller than
## [constant MIN_SIZE] is raised to it; a size that cannot be read is no size, and a place that
## cannot be read no place.
func load_file() -> bool:
	_loaded = false
	if not FileAccess.file_exists(_path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK or not (json.data is Dictionary):
		return false
	var data: Dictionary = json.data
	var read_mode: int = _mode_named(data.get(MODE_KEY))
	if read_mode < 0:
		return false
	mode = read_mode as Mode
	back = Mode.MAXIMIZED if _mode_named(data.get(BACK_KEY)) == Mode.MAXIMIZED else Mode.WINDOWED
	var size: Variant = _pair(data.get(SIZE_KEY))
	var place: Variant = _pair(data.get(PLACE_KEY))
	rect = Rect2i()
	_place_read = false
	if size is Vector2i:
		var read_size: Vector2i = size
		rect.size = read_size.max(MIN_SIZE)
		if place is Vector2i:
			var read_place: Vector2i = place
			rect.position = read_place
			_place_read = true
	_loaded = true
	return true


## Decides how the window opens on a screen of [param screen] pixels with [param usable] of
## them free, [param screens] being every screen's usable part and [param frame_height] a
## maximized window's frame: as the file said if [method load_file] read one, else as
## [method first_mode] says. A remembered place is used only if it is still on a screen
## ([method screen_of]), and a remembered size is cut down to the screen it lands on.
func decide(
	screen: Vector2i, usable: Vector2i, screens: Array[Rect2i], frame_height: int = FRAME_HEIGHT
) -> void:
	if not _loaded:
		mode = first_mode(screen, usable, frame_height)
		back = Mode.WINDOWED
		rect = Rect2i()
		_place_read = false
	var lands_on: Rect2i = screen_of(rect, screens) if _place_read else Rect2i()
	place_known = lands_on.size != Vector2i.ZERO
	if rect.size != Vector2i.ZERO:
		rect.size = rect.size.min(lands_on.size if place_known else usable)
	_seen_mode = mode
	_seen_rect = rect
	_still = 0.0
	_based = false


## What [kbd]F11[/kbd] does: full screen, or from full screen the window as it was. Saved.
func toggle_full_screen() -> void:
	if mode == Mode.FULL_SCREEN:
		mode = back
	else:
		back = mode
		mode = Mode.FULL_SCREEN
	_seen_mode = mode  # so closing before the window is next looked at keeps the new mode
	_still = 0.0
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


## Takes what the window was last seen to be without waiting for it to hold still: for a
## change made just before the game closes.
func flush() -> void:
	_take(_seen_mode, _seen_rect)


## Writes the file: to a temporary file renamed into place, so a write cut short leaves the
## old file or none, never half of one. Returns true if it was written.
func save() -> bool:
	var data: Dictionary = {MODE_KEY: NAMES[mode], BACK_KEY: NAMES[back]}
	if rect.size != Vector2i.ZERO:
		data[SIZE_KEY] = [rect.size.x, rect.size.y]
		data[PLACE_KEY] = [rect.position.x, rect.position.y]
	var temp_path: String = _path + TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(JSON.stringify(data))
	file.close()
	if not stored:
		DirAccess.remove_absolute(temp_path)
		return false
	if FileAccess.file_exists(_path):  # a rename does not replace a file on every system
		DirAccess.remove_absolute(_path)
	if DirAccess.rename_absolute(temp_path, _path) != OK:
		DirAccess.remove_absolute(temp_path)
		return false
	writes += 1
	return true


## Makes what the window was seen to be the remembered state, and saves if that changes it.
## The first time a window with no remembered size is seen holding still, windowed as it was
## decided, that is only where the project's window opened: taken, but not a change.
func _take(seen_mode: Mode, seen_rect: Rect2i) -> void:
	var changed: bool = false
	if seen_mode != mode:
		if seen_mode == Mode.FULL_SCREEN:
			back = mode
		mode = seen_mode
		changed = true
	if seen_mode == Mode.WINDOWED and seen_rect != rect:
		var as_opened: bool = not _based and not changed and rect.size == Vector2i.ZERO
		rect = seen_rect
		place_known = true
		changed = changed or not as_opened
	_based = true
	if changed:
		save()


## The mode [param value] names in the file, or -1 if it is not a mode's name.
static func _mode_named(value: Variant) -> int:
	if not (value is String):
		return -1
	var found: Variant = NAMES.find_key(value)
	if found == null:
		return -1
	var index: int = found
	return index


## Two whole numbers from a saved [param value] as a [Vector2i], or null for anything else.
static func _pair(value: Variant) -> Variant:
	if not (value is Array):
		return null
	var pair: Array = value
	if pair.size() != 2 or not (pair[0] is float and pair[1] is float):
		return null
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

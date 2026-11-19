extends "res://tests/acceptance/ui_layer_test.gd"
## Acceptance tests for specs/067-opens-at-a-size-you-can-read/spec.md, one per requirement.
##
## A headless run has no real window to maximize, so what [WindowSettings] decides is tested
## from a screen's size and a saved file, the file one of this process's own under user://.
## What only a real window exercises (setting its mode, size and place, and reading them back
## each frame) is said in the pull request, with how it was run by hand.

const WIKI_PAGE: String = "res://docs/wiki/index.html"
## A screen of this machine's kind (3440x1440 with a taskbar) and smaller ones.
const WIDE: Vector2i = Vector2i(3440, 1392)
const FULL_HD_USABLE: Vector2i = Vector2i(1920, 1032)
const SCREEN: Rect2i = Rect2i(0, 0, 3440, 1392)
const SIDE_SCREEN: Rect2i = Rect2i(-1920, 0, 1920, 1032)
## Sizes a real window takes: the project's, a maximized one's on three screens (the title bar
## taken off), full screen on four, and one smaller than the UI's smallest room.
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(3440, 1361),
	Vector2i(2560, 1361),
	Vector2i(1920, 1001),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
	Vector2i(1366, 768),
	Vector2i(900, 500),
]

var _window_path: String = "user://test_067_window_%d.window" % OS.get_process_id()
var _real_size: Vector2i


func before_all() -> void:
	_real_size = get_window().size


func after_each() -> void:
	super.after_each()
	_delete_window_file()
	get_window().size = _real_size


func after_all() -> void:
	super.after_all()
	_delete_window_file()
	get_window().size = _real_size


func _delete_window_file() -> void:
	if FileAccess.file_exists(_window_path):
		DirAccess.remove_absolute(_window_path)


## Window settings kept in this process's own file, with no real window to change.
func _kept() -> WindowSettings:
	var made := WindowSettings.new(_window_path)
	autofree(made)
	return made


## Shows [param kept] the same windowed or maximized state for long enough that it takes it.
func _settle(kept: WindowSettings, mode: WindowSettings.Mode, place: Rect2i) -> void:
	for frame: int in 4:
		kept.observe(mode, place, WindowSettings.SETTLE_SECONDS / 2.0)


# --- R1 ------------------------------------------------------------------------


func test_r1_opens_large() -> void:
	var maximized: WindowSettings.Mode = WindowSettings.Mode.MAXIMIZED
	var windowed: WindowSettings.Mode = WindowSettings.Mode.WINDOWED
	for usable: Vector2i in [
		WIDE, Vector2i(1920, 1080), Vector2i(2560, 1392), Vector2i(3840, 2112)
	]:
		assert_eq(WindowSettings.first_mode(usable), maximized, "%s: opens maximized" % usable)
	for usable: Vector2i in [
		FULL_HD_USABLE, Vector2i(1366, 728), Vector2i(1280, 720), Vector2i(2560, 1040)
	]:
		assert_eq(WindowSettings.first_mode(usable), windowed, "%s: opens as today" % usable)

	# A first run (no file) takes the screen's answer, and has no size or place of its own.
	var first: WindowSettings = _kept()
	assert_false(first.load_file(), "no file on a first run")
	first.decide(WIDE, [SCREEN])
	assert_eq(first.mode, maximized, "first run on a large screen: maximized")
	assert_false(first.place_known, "no place of its own")
	assert_eq(first.rect.size, Vector2i.ZERO, "nor a size: the project's 1280x720 stands")
	var small: WindowSettings = _kept()
	small.load_file()
	small.decide(FULL_HD_USABLE, [Rect2i(Vector2i.ZERO, FULL_HD_USABLE)])
	assert_eq(small.mode, windowed, "first run on a small screen: as today")
	assert_eq(small.rect.size, Vector2i.ZERO, "at the project's size")
	assert_false(FileAccess.file_exists(_window_path), "deciding writes nothing")


# --- R2 ------------------------------------------------------------------------


func test_r2_full_screen() -> void:
	var full: WindowSettings.Mode = WindowSettings.Mode.FULL_SCREEN
	# From each kind of window to full screen and back to the window as it was.
	for was: WindowSettings.Mode in [WindowSettings.Mode.WINDOWED, WindowSettings.Mode.MAXIMIZED]:
		_delete_window_file()
		var kept: WindowSettings = _kept()
		var place := Rect2i(200, 150, 1600, 900)
		_settle(kept, WindowSettings.Mode.WINDOWED, place)
		_settle(kept, was, place)
		assert_eq(kept.mode, was, "set up: %s" % was)
		kept.toggle_full_screen()
		assert_eq(kept.mode, full, "%s: F11 goes full screen" % was)
		assert_eq(kept.rect, place, "%s: the window's size and place are kept meanwhile" % was)
		kept.toggle_full_screen()
		assert_eq(kept.mode, was, "%s: F11 again, the window as it was" % was)
		assert_eq(kept.rect, place, "%s: where it was" % was)

	# The key itself, in a game that has window settings (a file of this test's own, no window).
	var main: Main = MAIN_SCENE.instantiate()
	var own: WindowSettings = WindowSettings.new(_window_path)
	main.window_settings = own
	add_child_autofree(main)
	var before: WindowSettings.Mode = own.mode
	var real: Window.Mode = get_window().mode
	_key(KEY_F11)
	assert_eq(own.mode, full, "F11 in the game: full screen")
	_key(KEY_F11)
	assert_eq(own.mode, before, "F11 again: back")
	assert_eq(get_window().mode, real, "the test's own window was left alone")

	# The help lists it.
	var listed: bool = false
	for entry: Array in HelpPanel.KEYS:
		if str(entry[0]) == "F11":
			listed = true
			assert_true(str(entry[1]).to_lower().contains("full screen"), "help says what F11 does")
	assert_true(listed, "F11 is in the help's keys")
	assert_true(HelpPanel.keycodes("F11").has(KEY_F11), "and the list reads it as the F11 key")


# --- R3 ------------------------------------------------------------------------


func test_r3_remembered() -> void:
	var windowed: WindowSettings.Mode = WindowSettings.Mode.WINDOWED
	var maximized: WindowSettings.Mode = WindowSettings.Mode.MAXIMIZED
	var place := Rect2i(300, 120, 1500, 880)
	var kept: WindowSettings = _kept()
	kept.load_file()
	kept.decide(WIDE, [SCREEN])
	assert_ne(kept.file_path(), SoundSettings.DEFAULT_PATH, "a file of its own")
	assert_ne(WindowSettings.DEFAULT_PATH, SoundSettings.DEFAULT_PATH, "not the settings file")
	assert_ne(WindowSettings.DEFAULT_PATH, SaveStore.DEFAULT_PATH, "not the save")
	assert_true(WindowSettings.DEFAULT_PATH.begins_with("user://"), "under user://")

	# Nothing changed: nothing written.
	_settle(kept, maximized, Rect2i(0, 23, 3440, 1369))
	assert_false(FileAccess.file_exists(_window_path), "an unchanged window writes no file")

	# Saved when the window changes: once it holds still, not on every frame of a resize.
	kept.observe(windowed, Rect2i(10, 40, 1000, 600), 0.016)
	kept.observe(windowed, Rect2i(10, 40, 1200, 700), 0.016)
	assert_false(FileAccess.file_exists(_window_path), "nothing saved in the middle of a resize")
	_settle(kept, windowed, place)
	assert_true(FileAccess.file_exists(_window_path), "saved when it changed")
	assert_eq(kept.mode, windowed)
	assert_eq(kept.rect, place)

	# Restored on the next start: the mode, the size and the place.
	var next: WindowSettings = _kept()
	assert_true(next.load_file(), "the file is read")
	next.decide(WIDE, [SCREEN, SIDE_SCREEN])
	assert_eq(next.mode, windowed, "windowed, though a first run here would maximize")
	assert_eq(next.rect, place, "its size and place")
	assert_true(next.place_known, "the place is on a screen: used")

	# Maximized is remembered, and so is the windowed size and place under it.
	_settle(next, maximized, Rect2i(0, 23, 3440, 1369))
	var third: WindowSettings = _kept()
	third.load_file()
	third.decide(FULL_HD_USABLE, [Rect2i(Vector2i.ZERO, FULL_HD_USABLE)])
	assert_eq(third.mode, maximized, "maximized, though a first run here would not be")
	assert_eq(third.rect, place, "the windowed size and place wait under it")

	# Full screen is remembered, with the window to go back to.
	third.toggle_full_screen()
	var fourth: WindowSettings = _kept()
	fourth.load_file()
	fourth.decide(WIDE, [SCREEN])
	assert_eq(fourth.mode, WindowSettings.Mode.FULL_SCREEN, "full screen is remembered")
	fourth.toggle_full_screen()
	assert_eq(fourth.mode, maximized, "and F11 still goes back to the window as it was")

	# A place off every screen now (the side screen is gone) is ignored; the size stays.
	var side := Rect2i(-1700, 200, 1400, 800)
	_settle(fourth, windowed, side)
	var here: WindowSettings = _kept()
	here.load_file()
	here.decide(WIDE, [SCREEN, SIDE_SCREEN])
	assert_true(here.place_known, "on the side screen while it is there")
	var gone: WindowSettings = _kept()
	gone.load_file()
	gone.decide(WIDE, [SCREEN])
	assert_eq(gone.mode, windowed)
	assert_false(gone.place_known, "off every screen now: the place is ignored")
	assert_eq(gone.rect.size, side.size, "the size is kept")
	assert_true(WindowSettings.on_a_screen(Rect2i(3000, 1000, 1280, 720), [SCREEN]), "partly on")
	assert_false(WindowSettings.on_a_screen(Rect2i(3400, 1380, 1280, 720), [SCREEN]), "a sliver")
	assert_false(WindowSettings.on_a_screen(Rect2i(100, -300, 1280, 720), [SCREEN]), "bar above")
	assert_false(WindowSettings.on_a_screen(place, []), "no screens")

	# A file that cannot be read is a first run.
	var file: FileAccess = FileAccess.open(_window_path, FileAccess.WRITE)
	file.store_string('{"mode": "sideways", "size": "big"')
	file.close()
	var broken: WindowSettings = _kept()
	assert_false(broken.load_file(), "a broken file is not read")
	broken.decide(WIDE, [SCREEN])
	assert_eq(broken.mode, maximized, "and the window opens as on a first run")


# --- R4 ------------------------------------------------------------------------


## Checks the UI layer of [param main] is laid out for a window of [param size] as spec 058 rules.
func _check_fits(main: Main, size: Vector2i, what: String) -> void:
	var ui: UiRoot = main.ui
	var room: Vector2i = UiRoot.room_for(size)
	assert_eq(ui.ui_scale(), UiRoot.ui_scale_for(size), "%s: the UI's scale" % what)
	assert_eq(ui.world_scale(), UiRoot.world_scale_for(size), "%s: the world's scale" % what)
	assert_eq(ui.room(), room, "%s: the room" % what)
	assert_eq(ui.frame.size, Vector2(room), "%s: the layer is as big as the room" % what)
	var whole := Rect2(Vector2.ZERO, Vector2(room))
	var roomy: bool = room.x >= UiRoot.MIN_ROOM.x and room.y >= UiRoot.MIN_ROOM.y
	if roomy:
		assert_true(whole.encloses(ui.bar.get_global_rect()), "%s: the bar is not cut" % what)
	for id: StringName in ui.windows.ids():
		var shown: UiWindow = ui.windows.window(id)
		if not shown.is_open():
			continue
		var bar: Rect2 = shown.title_bar.get_global_rect()
		assert_true(
			bar.position.y >= 0.0 and bar.end.y <= room.y + 0.5, "%s: %s's bar is in" % [what, id]
		)
		assert_true(whole.intersects(bar), "%s: %s's bar can be reached" % [what, id])
		if roomy and not shown.is_dragging():
			assert_true(
				whole.grow(0.5).encloses(shown.get_global_rect()),
				"%s: %s is not cut (%s)" % [what, id, shown.get_global_rect()]
			)


func test_r4_the_ui_follows() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.driver.set_process(false)
	main.hud_layer.layer = 129
	main.ui.layer = 130
	var ui: UiRoot = main.ui
	var windows: UiWindows = ui.windows
	# Windows open, some dragged, one of each hero's.
	for id: StringName in [UiRoot.HELP, UiRoot.JOURNAL, ShopWindow.ID, TallyWindow.ID]:
		windows.open_window(id)
	main.hud.hero_windows.open(main.simulation.party.heroes[0].id)
	main.hud.hero_windows.open(main.simulation.party.heroes[3].id)
	get_window().size = Vector2i(1920, 1080)
	await _frames()
	windows.raise(windows.window(UiRoot.JOURNAL))
	_drag(ui, windows.window(UiRoot.JOURNAL), Vector2(500, 300))
	windows.raise(windows.window(ShopWindow.ID))
	_drag(ui, windows.window(ShopWindow.ID), Vector2(-200, 250))
	assert_true(windows.window(UiRoot.JOURNAL).placed, "set up: the journal was dragged")

	# Any change of the real window's size, larger or smaller, with windows open.
	for size: Vector2i in SIZES + SIZES.slice(0, 3):
		get_window().size = size
		await _frames()
		_check_fits(main, size, "%s" % size)

	# In the middle of a drag: the size changes under the held mouse, and the drag goes on.
	get_window().size = Vector2i(1920, 1080)
	await _frames()
	var help: UiWindow = windows.window(UiRoot.HELP)
	windows.raise(help)
	var grip: Vector2 = help.title_bar.get_global_rect().position + Vector2(12, 6)
	_move(ui.ui_to_world(grip))
	_button(ui.ui_to_world(grip), true)
	_move(ui.ui_to_world(grip + Vector2(-60, 40)), true)
	assert_true(help.is_dragging(), "set up: help is being dragged")
	var held: Vector2 = help.position
	for size: Vector2i in [Vector2i(3440, 1361), Vector2i(1280, 720), Vector2i(3440, 1440)]:
		get_window().size = size
		await _frames()
		assert_true(help.is_dragging(), "%s mid-drag: still held" % size)
		_check_fits(main, size, "%s mid-drag" % size)
	get_window().size = Vector2i(1920, 1080)
	await _frames()
	assert_eq(help.position, held, "back at the size it was held in: where it was held")
	_move(ui.ui_to_world(grip + Vector2(-160, 90)), true)
	assert_eq(help.position, held + Vector2(-100, 50), "the drag goes on from there")
	_button(ui.ui_to_world(grip + Vector2(-160, 90)), false)
	assert_false(help.is_dragging(), "and ends")
	assert_true(help.placed, "placed where it was dropped")
	_check_fits(main, Vector2i(1920, 1080), "after the drag")
	assert_engine_error_count(0)


# --- R5 ------------------------------------------------------------------------


func test_r5_tools_are_unchanged() -> void:
	# Who gets window settings: only a game someone plays, not told otherwise.
	var played := PackedStringArray(["--path", "."])
	assert_true(WindowSettings.wanted("Windows", played), "a played game in a window")
	assert_true(WindowSettings.wanted("X11", PackedStringArray()), "on any display")
	assert_false(WindowSettings.wanted("headless", played), "not headless")
	for told: PackedStringArray in [
		PackedStringArray(["-s", "res://addons/gut/gut_cmdln.gd"]),
		PackedStringArray(["--script", "res://tools/godot/shot.gd"]),
		PackedStringArray(["--path", ".", WindowSettings.DEFAULT_FLAG]),
	]:
		assert_false(WindowSettings.wanted("Windows", told), "not when run as %s" % told)
	assert_eq(WindowSettings.DEFAULT_FLAG, "--window-default", "the flag the shot tool passes")
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	assert_false(WindowSettings.wanted(DisplayServer.get_name(), args), "not in this test run")

	# A game made in a test has none, and F11 there changes nothing and touches no file.
	var real: String = WindowSettings.DEFAULT_PATH
	var existed: bool = FileAccess.file_exists(real)
	var stamp: int = FileAccess.get_modified_time(real) if existed else 0
	var mode: Window.Mode = get_window().mode
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_null(main.window_settings, "a test's game has no window settings")
	_key(KEY_F11)
	await _frames()
	assert_eq(get_window().mode, mode, "the window's mode is as it was")
	main.free()
	assert_eq(FileAccess.file_exists(real), existed, "the real file was not made or removed")
	if existed:
		assert_eq(FileAccess.get_modified_time(real), stamp, "nor written")

	# A test that names a file of its own gets it used, and still no real window is touched.
	var own: WindowSettings = WindowSettings.new(_window_path)
	var named: Main = MAIN_SCENE.instantiate()
	named.window_settings = own
	add_child_autofree(named)
	assert_eq(named.window_settings, own, "the test's own settings are kept")
	assert_true(own.is_inside_tree(), "and held by the game")
	assert_null(own.window, "with no real window to change")
	_key(KEY_F11)
	assert_true(FileAccess.file_exists(_window_path), "written to the test's own file")
	assert_eq(get_window().mode, mode, "the window's mode is as it was")
	assert_eq(FileAccess.file_exists(real), existed, "the real file still untouched")


# --- R6 ------------------------------------------------------------------------


func test_r6_wiki() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI_PAGE)
	assert_true(wiki.contains("<kbd>F11</kbd>"), "the wiki names F11")
	var lower: String = wiki.to_lower()
	for words: String in ["maximized", "full screen", "colony.window", "1920 by 1080"]:
		assert_true(lower.contains(words), "the wiki says: %s" % words)

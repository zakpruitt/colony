extends "res://tests/support/main_fixture.gd"
## Acceptance tests for specs/058-sharp-ui-and-windows/spec.md, R5 to R8 (the rest are in
## test_058_sharp_ui_and_windows.gd): the windows in both rooms a player has, 960x540 and
## 1280x720, where they open, what moves or closes them, and the goals beside them.


## A window's rectangle at its default place, in UI pixels.
func _default_rect(window: UiWindow) -> Rect2:
	return Rect2(window.default_place, window.size)


## Review 1: a window the player never moved takes the default place of whatever room the game
## opens in; only a window they dragged keeps its place from the last session.
func test_r6_an_unmoved_window_takes_each_rooms_default() -> void:
	var first: Main = _main(ROOM_LARGE, SoundSettings.new(_settings_path))
	assert_true(first.ui.windows.is_open(UiRoot.HELP), "help welcomes a first game, not dragged")
	first.ui.windows.open_window(UiRoot.ORDERS)
	await _frames()
	# Somewhere every room keeps, the headless window's own 640x360 too (the windows are put back
	# before the test sets the room).
	_drag(first.ui, first.ui.windows.window(UiRoot.ORDERS), Vector2(40, -300))
	var orders_at: Vector2 = first.ui.windows.window(UiRoot.ORDERS).position
	first.free()

	var second: Main = _main(ROOM_SMALL, SoundSettings.new(_settings_path))
	var help: UiWindow = second.ui.windows.window(UiRoot.HELP)
	assert_true(help.is_open(), "open as it was left")
	assert_eq(help.position, help.default_place, "at the smaller room's default place")
	var room := Rect2(Vector2.ZERO, Vector2(ROOM_SMALL))
	assert_true(room.encloses(help.get_rect()), "wholly on screen: %s" % help.get_rect())
	assert_eq(second.ui.windows.window(UiRoot.ORDERS).position, orders_at, "the dragged one kept")


## Review 4: a window the room has shrunk away from is moved wholly back on screen when it fits;
## only a drag may leave part of one off screen.
func test_r5_a_window_is_moved_wholly_back_when_the_room_shrinks() -> void:
	var main: Main = _main(ROOM_LARGE)
	var ui: UiRoot = main.ui
	var journal: UiWindow = ui.windows.window(UiRoot.JOURNAL)
	ui.windows.open_window(UiRoot.JOURNAL)
	await _frames()
	_drag(ui, journal, Vector2(ROOM_LARGE) - journal.get_rect().end - Vector2(4, 4))
	assert_true(Rect2(Vector2.ZERO, Vector2(ROOM_LARGE)).encloses(journal.get_rect()), "on screen")
	ui.set_room_for_test(ROOM_SMALL)
	var room := Rect2(Vector2.ZERO, Vector2(ROOM_SMALL))
	assert_true(room.encloses(journal.get_rect()), "wholly back in: %s" % journal.get_rect())
	assert_true(journal.placed, "still the player's place, as near as fits")


## Review 2: a point on a window or the button bar is nowhere for the old HUD under it.
func test_r5_the_mouse_on_a_window_is_not_on_the_hud() -> void:
	var main: Main = _main(ROOM_SMALL)
	var ui: UiRoot = main.ui
	var hud: Hud = main.hud
	hud.advance(0.016)
	assert_true(hud.goals_view.rows[0].visible, "the goals show")
	var on_goal: Vector2 = UiFormat.on_screen(hud.goals_view.rows[0]).get_center()
	var journal: UiWindow = ui.windows.window(UiRoot.JOURNAL)
	press(KEY_J)
	await _frames()
	assert_true(journal.get_rect().has_point(ui.world_to_ui(on_goal)), "the journal over the goals")
	mouse_move(on_goal)
	hud.frame_tip.advance(UiTip.DELAY + 0.1)
	assert_eq(hud.frame_tip.shown_text(), "", "no HUD tooltip through the journal")
	var note_mouse: Vector2 = hud.defeat_note.get(&"_mouse")
	assert_eq(note_mouse, UiTip.NOWHERE, "nor the defeat note's hover")
	mouse_move(ui.ui_to_world(ui.bar.get_global_rect().get_center()))
	note_mouse = hud.defeat_note.get(&"_mouse")
	assert_eq(note_mouse, UiTip.NOWHERE, "the button bar too")
	press(KEY_J)
	mouse_move(on_goal + Vector2(1, 0))
	hud.frame_tip.advance(UiTip.DELAY + 0.1)
	assert_ne(hud.frame_tip.shown_text(), "", "with the journal closed, the goal's tooltip shows")


## Review 3a: at both rooms, the orders and help open clear of the goals.
func test_r6_default_places_clear_the_goals() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var main: Main = _main(room)
		var ui: UiRoot = main.ui
		await _frames()
		main.hud.advance(0.016)
		var goals: Rect2 = main.hud.goals_view.get_global_rect()
		assert_gt(goals.size.y, 0.0, "%s: the goals show" % room)
		var orders: Rect2 = _default_rect(ui.windows.window(UiRoot.ORDERS))
		var help: Rect2 = _default_rect(ui.windows.window(UiRoot.HELP))
		assert_false(orders.intersects(goals), "%s: orders clear the goals" % room)
		assert_false(help.intersects(goals), "%s: help clears the goals" % room)
		main.free()


## Review 8: every window's default place keeps clear of the hero frames' line and the button bar,
## at both rooms.
func test_r6_default_places_clear_the_frames_and_the_bar() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var main: Main = _main(room)
		var ui: UiRoot = main.ui
		await _frames()
		var frames_top: float = ui.world_to_ui(main.hud.frames[0].get_global_rect().position).y
		var bar: Rect2 = ui.bar.get_global_rect()
		for id: StringName in _bar_ids(ui.windows):
			var place: Rect2 = _default_rect(ui.windows.window(id))
			assert_lte(place.end.y, frames_top, "%s: %s above the frames' line" % [room, id])
			assert_false(place.intersects(bar), "%s: %s clear of the button bar" % [room, id])
		main.free()


## Review 3b: a window its key closes and opens again comes back where it was, the other windows
## and a hero window opened by a click on its frame staying open beside it.
func test_r5_a_window_reopened_by_its_key_keeps_its_place() -> void:
	var main: Main = _main(ROOM_SMALL)
	var ui: UiRoot = main.ui
	var hud: Hud = main.hud
	var windows: UiWindows = ui.windows
	for id: StringName in _bar_ids(windows):
		windows.open_window(id)
	await _frames()
	hud.advance(0.016)
	var places: Dictionary[StringName, Vector2] = {}
	for id: StringName in _bar_ids(windows):
		places[id] = windows.window(id).position
	click(UiFormat.on_screen(hud.frames[0]).get_center())
	hud.advance(0.016)
	for keycode: Key in [KEY_U, KEY_T, KEY_W]:  # each closes its window, then opens it again
		press(keycode)
		press(keycode)
		hud.advance(0.016)
	await _frames()
	hud.advance(0.016)
	assert_true(hud.hero_windows.is_open(), "the hero window stays open")
	for id: StringName in _bar_ids(windows):
		assert_true(windows.is_open(id), "%s stays open" % id)
		assert_eq(windows.window(id).position, places[id], "%s keeps its place" % id)


## The windows of spec 058, each with a button on the bar: every window but the hero windows of
## spec 060, which open from their frames, are as tall as the room allows and cascade at 960x540.
func _bar_ids(windows: UiWindows) -> Array[StringName]:
	var made: Array[StringName] = []
	for id: StringName in windows.ids():
		if windows.window(id).on_bar:
			made.append(id)
	return made

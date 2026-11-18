extends "res://tests/acceptance/ui_layer_test.gd"
## Acceptance tests for specs/058-sharp-ui-and-windows/spec.md, R5 to R8 (the rest are in
## test_058_sharp_ui_and_windows.gd): the windows in both rooms a player has, 960x540 and
## 1280x720, and beside the old HUD's panels until specs 059 to 061 move them onto the UI layer.


## [param world_rect], in the world's 640x360 screen pixels, in UI pixels on [param ui].
func _in_ui(ui: UiRoot, world_rect: Rect2) -> Rect2:
	var at: Vector2 = ui.world_to_ui(world_rect.position)
	return Rect2(at, ui.world_to_ui(world_rect.end) - at)


## A window's rectangle at its default place, in UI pixels.
func _default_rect(window: UiWindow) -> Rect2:
	return Rect2(window.default_place, window.size)


## Where each old panel opens and where the goals are, in UI pixels on [param main]'s layer:
## the hero sheet, opened by a click on a hero's frame and closed again. (Spec 059 made the shop,
## the tally and the area map windows.)
func _old_panels(main: Main) -> Dictionary[String, Rect2]:
	var hud: Hud = main.hud
	var ui: UiRoot = main.ui
	var found: Dictionary[String, Rect2] = {}
	hud.advance(0.016)
	found["goals"] = _in_ui(ui, hud.goals.panel.get_global_rect())
	_click_world(hud.frames[0].get_global_rect().get_center())
	hud.advance(0.016)
	assert_true(hud.hero_sheet.is_visible_in_tree(), "the hero sheet opened by a click")
	found["hero sheet"] = _in_ui(ui, hud.hero_sheet.get_global_rect())
	hud.hero_sheet.close()
	return found


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
	assert_false(hud.goals.rows.is_empty(), "the goals show")
	var on_goal: Vector2 = hud.goals.rows[0].get_global_rect().get_center()
	var journal: UiWindow = ui.windows.window(UiRoot.JOURNAL)
	_key(KEY_J)
	await _frames()
	assert_true(journal.get_rect().has_point(ui.world_to_ui(on_goal)), "the journal over the goals")
	_move(on_goal)
	hud.tooltip.advance(HudTooltip.DELAY + 0.1)
	assert_eq(hud.tooltip.shown_text(), "", "no HUD tooltip through the journal")
	var note_mouse: Vector2 = hud.defeat_note.get(&"_mouse")
	assert_eq(note_mouse, HudTooltip.NOWHERE, "nor the defeat note's hover")
	_move(ui.ui_to_world(ui.bar.get_global_rect().get_center()))
	note_mouse = hud.defeat_note.get(&"_mouse")
	assert_eq(note_mouse, HudTooltip.NOWHERE, "the button bar too")
	_key(KEY_J)
	_move(on_goal + Vector2(1, 0))
	hud.tooltip.advance(HudTooltip.DELAY + 0.1)
	assert_ne(hud.tooltip.shown_text(), "", "with the journal closed, the goal's tooltip shows")


## Review 3a: the default places beside what the old HUD shows and opens, at both rooms. The
## orders keep clear of all of it. Help keeps clear of the goals, the hero sheet and the tally; it
## covers where the shop and the area map open. The journal covers the goals, and where the hero
## sheet, the tally and the area map open: the three windows side by side are as wide as a 960x540
## room and those panels fill the top of it, so it cannot. A window over a panel closes as the panel
## opens (the next test but one). With that, stands in for 045 R1 (the tally opens over nothing).
func test_r6_default_places_beside_the_old_hud() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var main: Main = _main(room)
		var ui: UiRoot = main.ui
		await _frames()
		var panels: Dictionary[String, Rect2] = _old_panels(main)
		assert_gt(panels["goals"].size.y, 0.0, "%s: the goals show" % room)
		var orders: Rect2 = _default_rect(ui.windows.window(UiRoot.ORDERS))
		var help: Rect2 = _default_rect(ui.windows.window(UiRoot.HELP))
		for panel: String in panels:
			assert_false(
				orders.intersects(panels[panel]), "%s: orders clear the %s" % [room, panel]
			)
		for panel: String in ["goals", "hero sheet"]:
			assert_false(help.intersects(panels[panel]), "%s: help clears the %s" % [room, panel])
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
		for id: StringName in ui.windows.ids():
			var place: Rect2 = _default_rect(ui.windows.window(id))
			assert_lte(place.end.y, frames_top, "%s: %s above the frames' line" % [room, id])
			assert_false(place.intersects(bar), "%s: %s clear of the button bar" % [room, id])
		main.free()


## Review 3b: an old panel opening closes every window over it, keeps each window's place, and
## writes nothing in the journal. Since spec 059 the hero sheet is the one old panel left (the
## shop, the tally and the area map are windows, and open beside the others: spec 059 R1). Stands
## in for 027 R6 and 037 R6 (the old journal and goals panels kept clear of the hero sheet) and
## 041 R5 (nothing opens hidden).
func test_r5_an_old_panel_opening_closes_the_windows_over_it() -> void:
	var main: Main = _main(ROOM_SMALL)
	var ui: UiRoot = main.ui
	var hud: Hud = main.hud
	var windows: UiWindows = ui.windows
	var frame_at: Vector2 = hud.frames[0].get_global_rect().get_center()
	var openers: Array[Array] = [
		["hero sheet", hud.hero_sheet, func() -> void: _click_world(frame_at)],
	]
	for opener: Array in openers:
		var panel_name: String = opener[0]
		var panel: Control = opener[1]
		var open_it: Callable = opener[2]
		for id: StringName in windows.ids():
			windows.open_window(id)
		await _frames()
		hud.advance(0.016)
		var places: Dictionary[StringName, Vector2] = {}
		for id: StringName in windows.ids():
			assert_true(windows.is_open(id), "%s: %s open before" % [panel_name, id])
			places[id] = windows.window(id).position
		var written: Array[String] = hud.journal.lines()
		open_it.call()
		hud.advance(0.016)
		assert_true(panel.is_visible_in_tree(), "the %s opened" % panel_name)
		var over: Rect2 = _in_ui(ui, panel.get_global_rect())
		var closed: int = 0
		for id: StringName in windows.ids():
			var window: UiWindow = windows.window(id)
			var covers: bool = window.get_rect().intersects(over)
			assert_eq(window.is_open(), not covers, "%s: %s closed if over it" % [panel_name, id])
			assert_eq(window.position, places[id], "%s: %s keeps its place" % [panel_name, id])
			closed += 0 if window.is_open() else 1
		assert_gt(closed, 0, "%s: a window was over it" % panel_name)
		assert_eq(hud.journal.lines(), written, "%s: the journal says nothing" % panel_name)
		panel.call(&"close")
		hud.advance(0.016)
		for id: StringName in windows.ids():
			windows.close_window(id)


## Review 3c: windows left open last session open only once the away report has gone.
func test_r6_windows_left_open_wait_for_the_away_report() -> void:
	var first: Main = _main(ROOM_SMALL, SoundSettings.new(_settings_path))
	first.ui.windows.close_window(UiRoot.HELP)
	first.ui.windows.open_window(UiRoot.JOURNAL)
	first.free()
	var played := Simulation.new(Main.SIMULATION_SEED)
	for i: int in 600:
		played.step()
	played.drain_events()
	var data: Dictionary = played.to_save()
	data[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system()
	assert_true(SaveStore.new(_save_path).write(data), "the test's save was written")

	var main: Main = MAIN_SCENE.instantiate()
	main.settings = SoundSettings.new(_settings_path)
	main.save_store = SaveStore.new(_save_path)
	main.away_seconds_override = 600.0
	add_child_autofree(main)
	await wait_until(func() -> bool: return not main.is_catching_up(), 60.0, "replay ends")
	main.hud_layer.layer = 129
	main.ui.layer = 130
	assert_not_null(main.away_panel, "the away report shows")
	assert_false(main.ui.windows.is_open(UiRoot.JOURNAL), "the journal waits behind it")
	_click_world(Vector2(320, 200))  # a click anywhere puts the report away
	await _frames()
	assert_false(is_instance_valid(main.away_panel), "the report went")
	assert_true(main.ui.windows.is_open(UiRoot.JOURNAL), "then the journal opens as it was left")

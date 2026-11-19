extends "res://tests/acceptance/ui_layer_test.gd"
## Acceptance tests for specs/068-a-button-bar-that-says-what-it-opens/spec.md, one per
## requirement. Each runs the main scene laid out for a room ([method UiRoot.set_room_for_test]),
## measures the bar's rectangles there and drives it with real clicks and keys (the helpers are in
## ui_layer_test.gd).

const ROOMS: Array[Vector2i] = [ROOM_SMALL, ROOM_LARGE]
## The word each window's button says (R1), in the bar's order.
const NAMES: Dictionary[StringName, String] = {
	&"help": "Help",
	&"journal": "Journal",
	&"orders": "Orders",
	&"shop": "Camp",
	&"map": "Map",
	&"tally": "Tally",
}
const WIKI: String = "res://docs/wiki/index.html"
const STEP: float = 1.0 / 60.0


## A main scene laid out for [param room], its frame of the screen and its bar settled.
func _settled(room: Vector2i) -> Main:
	var main: Main = _main(room)
	main.hud.advance(STEP)
	await _frames()
	main.ui.bar.refresh()
	return main


## Every place [param text] says [param word], whatever its capitals, as it is spelled there.
func _spellings(text: String, word: String) -> Array[String]:
	var pattern := RegEx.new()
	pattern.compile("(?i)\\b%s\\b" % word)
	var found: Array[String] = []
	for each: RegExMatch in pattern.search_all(text):
		found.append(each.get_string())
	return found


## What the help's key list says the key [param keycode] does; "" when it does not list it.
func _help_says(keycode: Key) -> String:
	for entry: Array in HelpPanel.KEYS:
		if HelpPanel.keycodes(str(entry[0])).has(keycode):
			return str(entry[1])
	return ""


## The bar's buttons from left to right as it holds them: one per window, then the reset.
func _row(bar: UiButtonBar) -> Array[UiButton]:
	var row: Array[UiButton] = []
	for id: StringName in bar.buttons:
		row.append(bar.buttons[id])
	row.append(bar.reset_button)
	return row


## Checks the bar's buttons stand in one row inside the bar, none on another, none squeezed.
func _check_one_row(bar: UiButtonBar, what: String) -> void:
	var whole: Rect2 = bar.get_global_rect()
	var row: Array[UiButton] = _row(bar)
	var first: Rect2 = row[0].get_global_rect()
	var last_end: float = whole.position.x
	for button: UiButton in row:
		var rect: Rect2 = button.get_global_rect()
		var named: String = "%s: %s" % [what, button.text]
		assert_eq(rect.position.y, first.position.y, "%s in the one row" % named)
		assert_eq(rect.size.y, first.size.y, "%s as tall as the rest" % named)
		assert_gte(rect.position.x, last_end, "%s after the one before" % named)
		assert_true(whole.encloses(rect), "%s inside the bar" % named)
		assert_gte(rect.size.x, button.get_minimum_size().x, "%s not squeezed" % named)
		assert_false(button.clip_text, "%s: its name not cut" % named)
		assert_eq(
			button.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s: nor trimmed" % named
		)
		last_end = rect.end.x


# --- R1 ------------------------------------------------------------------------


func test_r1_a_name_on_every_button() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		var bar: UiButtonBar = main.ui.bar
		var what: String = "%s" % room
		assert_eq(bar.buttons.keys(), NAMES.keys(), "%s: a button per window" % what)
		if room == ROOM_LARGE:
			assert_true(bar.shows_keys, "%s: every button shows its key" % what)
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons.get(id, null)
			var named: String = "%s: %s" % [what, id]
			assert_not_null(button, "%s has a button" % named)
			if button == null:
				continue
			var window: UiWindow = main.ui.windows.window(id)
			assert_not_null(button.icon, "%s: its icon" % named)
			assert_eq(button.icon.get_size(), Vector2(16, 16), "%s: 16x16" % named)
			assert_eq(button.text, NAMES[id], "%s: its window's name in words" % named)
			if not bar.shows_keys:
				continue
			assert_eq(button.key_hint, window.key_hint, "%s: and its key" % named)
			assert_true(button.key_cap, "%s: in a key cap" % named)
			var cap: Rect2 = button.key_rect()
			var letter: float = UiText.width(window.key_hint) - UiText.SPACING
			assert_gte(cap.size.x, letter + 6.0, "%s: the cap has an edge round the letter" % named)
			assert_gte(cap.size.y, UiText.CAP_HEIGHT + 4.0, "%s: above and below it too" % named)
			assert_true(
				Rect2(Vector2.ZERO, button.size).grow(-1.0).encloses(cap),
				"%s: the cap inside the button: %s in %s" % [named, cap, button.size]
			)
			var box: StyleBox = button.get_theme_stylebox(&"normal")
			var name_end: float = (
				box.get_margin(SIDE_LEFT)
				+ button.icon.get_width()
				+ button.get_theme_constant(&"h_separation")
				+ UiText.width(button.text, button.get_theme_font(&"font") == UiText.font(true))
				- UiText.SPACING
			)
			assert_gte(cap.position.x, name_end + 4.0, "%s: set apart from the name" % named)
		var reset: UiButton = bar.reset_button
		assert_not_null(reset.icon, "%s: the reset button keeps its icon" % what)
		assert_eq(reset.text, "Reset", "%s: and gets the word" % what)
		main.free()


# --- R2 ------------------------------------------------------------------------


func test_r2_one_name_per_window_everywhere() -> void:
	var main: Main = await _settled(ROOM_LARGE)
	var bar: UiButtonBar = main.ui.bar
	var said: Array[String] = []
	for entry: Array in HelpPanel.KEYS:
		said.append(str(entry[1]))
	said.append_array(HelpPanel.IDEA)
	for id: StringName in NAMES:
		var named: String = NAMES[id]
		var window: UiWindow = main.ui.windows.window(id)
		var button: UiButton = bar.buttons.get(id, null)
		assert_not_null(button, "%s has a button" % id)
		if button == null:
			continue
		assert_eq(button.text, named, "%s: on its button" % id)
		assert_eq(window.short_name, named, "%s: the window keeps it" % id)
		assert_eq(window.title_label.text, window.title, "%s: its title shows" % id)
		assert_eq(
			_spellings(window.title, named).size(),
			1,
			"%s: its title '%s' has the word '%s'" % [id, window.title, named]
		)
		var tip: String = bar.tip.text_for(button)
		assert_gt(_spellings(tip, named).size(), 0, "%s: its tooltip has it: %s" % [id, tip])
		var does: String = _help_says(window.keycode)
		assert_true(does.contains(named), "%s: the help's line for its key: '%s'" % [id, does])
		# Wherever the help names the window, it is this word, spelled this way.
		for line: String in said:
			for spelled: String in _spellings(line, named):
				assert_eq(spelled, named, "%s: the help says '%s' in '%s'" % [id, spelled, line])
	# The shop: titled Camp upgrades, called Camp, and Shop nowhere beside it.
	assert_eq(main.ui.windows.window(&"shop").title, "Camp upgrades", "the shop's title")
	for line: String in said:
		assert_eq(_spellings(line, "shop"), [] as Array[String], "the help says Camp: %s" % line)
	assert_eq(_spellings(Hud.GOLD_TIP, "shop"), [] as Array[String], "so does the gold's tooltip")
	assert_gt(_spellings(Hud.GOLD_TIP, "Camp").size(), 0, "which names the Camp")


# --- R3 ------------------------------------------------------------------------


func test_r3_reads_lit_tagged_and_disabled() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		var ui: UiRoot = main.ui
		var bar: UiButtonBar = ui.bar
		var told: Dictionary[String, StringName] = {}
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons[id]
			var window: UiWindow = ui.windows.window(id)
			var named: String = "%s: %s" % [room, id]
			# The tag: at the top right corner, on the button's edge and never on what it shows.
			window.badge = 12
			bar.refresh()
			var tag: UiBadge = bar.badges[id]
			var at: Rect2 = button.get_global_rect()
			var tagged: Rect2 = tag.get_global_rect()
			var rest: StyleBoxFlat = button.get_theme_stylebox(&"normal") as StyleBoxFlat
			assert_true(tag.is_visible_in_tree(), "%s: its tag shows" % named)
			assert_true(tagged.intersects(at), "%s: on the button" % named)
			assert_lt(tagged.position.y, at.position.y, "%s: at its top" % named)
			assert_between(
				tagged.end.x, at.end.x, at.end.x + 6.0, "%s: at its right corner" % named
			)
			assert_lte(
				tagged.end.y,
				at.position.y + rest.get_margin(SIDE_TOP),
				"%s: above its icon, name and key" % named
			)
			if bar.shows_keys:
				var cap := Rect2(at.position + button.key_rect().position, button.key_rect().size)
				assert_true(cap.has_area(), "%s: a key to keep clear of" % named)
				assert_false(tagged.intersects(cap), "%s: the tag clear of the key" % named)
			# Lit while its window is open, by a real click, and still named.
			_click_ui(ui, at.get_center())
			bar.refresh()
			assert_true(window.is_open(), "%s: the click opens it" % named)
			assert_true(button.lit, "%s: lit while open" % named)
			assert_true(button.button_pressed, "%s: drawn lit" % named)
			var lit: StyleBoxFlat = button.get_theme_stylebox(&"pressed") as StyleBoxFlat
			assert_ne(
				lit.bg_color, rest.bg_color, "%s: a lit button's face is another colour" % named
			)
			assert_ne(lit.border_color, rest.border_color, "%s: and its edge" % named)
			assert_eq(button.text, NAMES[id], "%s: still named while lit" % named)
			window.close()
			bar.refresh()
			assert_false(button.lit, "%s: dark again" % named)
			# The tooltip: the name, the key, and what the window is for in a sentence of its own.
			var tip: String = bar.tip.text_for(button)
			assert_true(tip.contains("(%s)" % window.key_hint), "%s: its key: %s" % [named, tip])
			assert_true(tip.ends_with("."), "%s: a sentence: %s" % [named, tip])
			assert_false(tip.trim_suffix(".").contains(". "), "%s: only one: %s" % [named, tip])
			var about: String = tip.get_slice("(%s)" % window.key_hint, 1)
			assert_gte(
				about.split(" ", false).size(), 5, "%s: says what it is for: '%s'" % [named, about]
			)
			assert_false(told.has(about), "%s says what %s says" % [named, told.get(about, &"")])
			told[about] = id
		# The tooltip shows after a rest on the button.
		var help: UiButton = bar.buttons[&"help"]
		_move(ui.ui_to_world(help.get_global_rect().get_center()))
		bar.tip.advance(UiTip.DELAY + 0.05)
		assert_eq(bar.tip.shown_text(), bar.tip.text_for(help), "%s: the tooltip shows" % room)
		# Disabled: the name stays, in a colour that shows on the sunken face.
		help.disabled = true
		var off: StyleBoxFlat = help.get_theme_stylebox(&"disabled") as StyleBoxFlat
		assert_eq(help.text, "Help", "%s: a disabled button keeps its name" % room)
		assert_ne(help.get_theme_color(&"font_disabled_color"), off.bg_color, "%s: readable" % room)
		assert_ne(off.bg_color, rest_of(help).bg_color, "%s: and told apart" % room)
		_move(Vector2(-10, -10))
		main.free()


## The box [param button] is drawn in at rest.
func rest_of(button: UiButton) -> StyleBoxFlat:
	return button.get_theme_stylebox(&"normal") as StyleBoxFlat


# --- R4 ------------------------------------------------------------------------


func test_r4_fits_both_rooms() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		var hud: Hud = main.hud
		var bar: UiButtonBar = main.ui.bar
		var what: String = "%s" % room
		var rect: Rect2 = bar.get_global_rect()
		assert_true(
			Rect2(Vector2.ZERO, Vector2(room)).encloses(rect),
			"%s: wholly on screen %s" % [what, rect]
		)
		_check_one_row(bar, what)
		var line: float = hud.frames[0].get_global_rect().position.y
		assert_lte(rect.end.y, line, "%s: above the hero frames' line" % what)
		var pieces: Dictionary[String, Control] = {
			"the stage list": hud.ladder, "the goals": hud.goals_view
		}
		for frame: HeroFrameView in hud.frames:
			pieces["%s's frame" % frame.name] = frame
		assert_eq(pieces.size(), 6, "%s: four frames, the stage list and the goals" % what)
		for piece: String in pieces:
			assert_true(pieces[piece].is_visible_in_tree(), "%s: %s shows" % [what, piece])
			assert_false(
				rect.intersects(pieces[piece].get_global_rect()), "%s: clear of %s" % [what, piece]
			)
		# Every name whole; the key on the button or, where the row has no room, in the tooltip.
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons[id]
			var key: String = main.ui.windows.window(id).key_hint
			assert_eq(button.text, NAMES[id], "%s: %s's name whole" % [what, id])
			assert_eq(button.key_hint, key if bar.shows_keys else "", "%s: %s's key" % [what, id])
			assert_true(
				bar.tip.text_for(button).contains("(%s)" % key),
				"%s: %s's tooltip names the key" % [what, id]
			)
		main.free()
	# Where the row has no room for all of it, the keys go and every name stays whole.
	var squeezed: Main = await _settled(ROOM_LARGE)
	var tight: UiButtonBar = squeezed.ui.bar
	var with_keys: float = tight.size.x
	assert_true(tight.shows_keys, "the keys show at 1280x720")
	tight.fit_room(Vector2i(1100, 620))
	await _frames()
	assert_false(tight.shows_keys, "a narrower room drops the keys")
	assert_lt(tight.size.x, with_keys, "for a narrower bar")
	_check_one_row(tight, "narrower")
	for id: StringName in NAMES:
		var button: UiButton = tight.buttons[id]
		assert_eq(button.text, NAMES[id], "narrower: %s's name whole" % id)
		assert_eq(button.key_hint, "", "narrower: %s's key off the button" % id)
		assert_false(button.key_rect().has_area(), "narrower: and no cap drawn")
		assert_true(
			tight.tip.text_for(button).contains("(%s)" % squeezed.ui.windows.window(id).key_hint),
			"narrower: %s's tooltip still names the key" % id
		)
	tight.fit_room(ROOM_LARGE)
	assert_true(tight.shows_keys, "and they come back with the room")
	assert_eq(tight.size.x, with_keys, "as wide as before")


# --- R5 ------------------------------------------------------------------------


func test_r5_nothing_lost() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		var ui: UiRoot = main.ui
		var bar: UiButtonBar = ui.bar
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons[id]
			var window: UiWindow = ui.windows.window(id)
			var named: String = "%s: %s" % [room, id]
			window.badge = 9  # a tag never takes its button's click
			bar.refresh()
			assert_false(window.is_open(), "%s: closed at first" % named)
			_click_ui(ui, button.get_global_rect().get_center())
			assert_true(window.is_open(), "%s: a click opens it" % named)
			_click_ui(ui, button.get_global_rect().get_center())
			assert_false(window.is_open(), "%s: and closes it" % named)
			_key(window.keycode)
			assert_true(window.is_open(), "%s: its key opens it" % named)
			_key(window.keycode)
			assert_false(window.is_open(), "%s: and closes it" % named)
		# The reset button puts a dragged window back.
		var journal: UiWindow = ui.windows.window(&"journal")
		ui.windows.open_window(&"journal")
		await _frames()
		_drag(ui, journal, Vector2(60, 40))
		assert_ne(journal.position, journal.default_place, "%s: the journal dragged away" % room)
		_click_ui(ui, bar.reset_button.get_global_rect().get_center())
		assert_eq(journal.position, journal.default_place, "%s: Reset puts it back" % room)
		# The tags stay on their own layer, over the bar and under every window (spec 062 R12).
		assert_eq(
			bar.tag_layer.get_parent(), bar.get_parent(), "%s: the tags beside the bar" % room
		)
		assert_eq(bar.tag_layer.get_index(), bar.get_index() + 1, "%s: just over it" % room)
		assert_lt(bar.tag_layer.get_index(), ui.windows.get_index(), "%s: under the windows" % room)
		for id: StringName in NAMES:
			assert_eq(bar.badges[id].get_parent(), bar.tag_layer, "%s: %s's tag on it" % [room, id])
		_move(Vector2(-10, -10))
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_help_and_wiki() -> void:
	var main: Main = await _settled(ROOM_SMALL)
	var help: HelpPanel = main.ui.windows.window(&"help").content as HelpPanel
	var shown: Array[String] = help.lines()
	for id: StringName in NAMES:
		var window: UiWindow = main.ui.windows.window(id)
		var does: String = _help_says(window.keycode)
		assert_true(does.contains(NAMES[id]), "the help names %s for %s" % [NAMES[id], id])
		assert_has(shown, "%s  %s" % [window.key_hint, does], "and the panel shows that line")
		assert_lte(UiText.width(does), HelpPanel.DOES_WIDTH, "on one line: %s" % does)
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	assert_true(wiki.contains("068 A button bar that says what it opens"), "the wiki lists 068")
	var row: String = ""
	for line: String in wiki.split("\n"):
		if line.contains("<td>The button bar</td>"):
			row = line
	assert_ne(row, "", "the wiki's table of the screen has the button bar")
	for word: String in ["Help", "Journal", "Orders", "Camp", "Map", "Tally", "Reset", "key cap"]:
		assert_true(row.contains(word), "the wiki's button bar says: %s" % word)
	assert_false(wiki.contains("The Shop button"), "the wiki no longer calls it the Shop button")
	assert_true(wiki.contains("The Camp button"), "but the Camp button")

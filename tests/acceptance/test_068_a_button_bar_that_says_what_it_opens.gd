extends "res://tests/support/main_fixture.gd"
## Acceptance tests for specs/068-a-button-bar-that-says-what-it-opens/spec.md, one per
## requirement. Each runs the main scene laid out for a room ([method UiRoot.set_room_for_test]),
## measures the bar's rectangles there and drives it with real clicks and keys (the helpers are in
## MainFixture).

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
## The most the bar may be wide at each room, in UI pixels: what stands at its left leaves it this
## (a hero window's default place and the ticker's longest line; the fourth cascaded hero window).
const WIDEST: Dictionary[Vector2i, float] = {ROOM_SMALL: 317.0, ROOM_LARGE: 518.0}
## The most a tag may reach outside its button, in UI pixels (R3).
const TAG_OUTSIDE: float = 2.0


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
	for entry: Array in KeyBook.entries():
		if KeyBook.keycodes(str(entry[0])).has(keycode):
			return str(entry[1])
	return ""


## Every string in double quotes in the code of every script under [param folder], comments left
## out, by "file:line". Names of things ([code]&"shop"[/code]) are not strings a player reads.
func _strings_in(folder: String, into: Dictionary[String, String]) -> void:
	var quoted := RegEx.new()
	quoted.compile('(?<!&)"((?:[^"\\\\]|\\\\.)*)"')
	for child: String in DirAccess.get_directories_at(folder):
		_strings_in(folder.path_join(child), into)
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() != "gd":
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(folder.path_join(file)).split(
			"\n"
		)
		for i: int in lines.size():
			if lines[i].strip_edges().begins_with("#"):
				continue
			var found: Array[RegExMatch] = quoted.search_all(lines[i])
			for k: int in found.size():
				into["%s:%d:%d" % [folder.path_join(file), i + 1, k]] = found[k].get_string(1)


## The row of the wiki's table of keys for the key [param key]; "" when it has none.
func _wiki_key_row(wiki: String, key: String) -> String:
	for line: String in wiki.split("\n"):
		if line.contains("<tr><td><kbd>%s</kbd></td>" % key):
			return line
	return ""


## [param rect], a rectangle in [param button]'s own pixels, on the UI layer.
func _on_layer(button: UiButton, rect: Rect2) -> Rect2:
	return Rect2(button.get_global_rect().position + rect.position, rect.size)


## Every window on [param ui] that shows now.
func _open_windows(ui: UiRoot) -> Array[UiWindow]:
	var all: Array[Control] = []
	_controls(ui.frame, all)
	var open: Array[UiWindow] = []
	for each: Control in all:
		if each is UiWindow and each.is_visible_in_tree():
			open.append(each as UiWindow)
	return open


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
			assert_true(button.key_cap, "%s: in a key cap" % named)
			var cap: Rect2 = button.key_rect()
			var letter: float = UiText.width(window.key_hint) - UiText.SPACING
			var face := Rect2(Vector2.ZERO, button.size)
			# Icon over name, the cap is smaller and stands on the button's corner (R4).
			var air: float = 2.0 if bar.stacked else 3.0
			assert_gte(
				cap.size.x, letter + 2.0 * air, "%s: the cap has an edge round the letter" % named
			)
			assert_gte(cap.size.y, UiText.CAP_HEIGHT + 4.0, "%s: above and below it too" % named)
			assert_true(
				face.grow(0.0 if bar.stacked else -1.0).encloses(cap),
				"%s: the cap inside the button: %s in %s" % [named, cap, button.size]
			)
			var said: Rect2 = button.name_rect()
			assert_true(said.has_area(), "%s: its name has a place" % named)
			assert_false(cap.intersects(said), "%s: the cap clear of the name" % named)
			assert_false(cap.intersects(button.icon_rect()), "%s: and of the icon" % named)
			if not bar.stacked:
				assert_gte(cap.position.x, said.end.x + 4.0, "%s: set apart from the name" % named)
			# Drawn: the cap's box and the letter in it, at the last draw.
			assert_true(button.cap_drawn.has_area(), "%s: the cap is drawn" % named)
			assert_eq(button.cap_drawn, cap, "%s: where the key is" % named)
			assert_eq(button.key_drawn, window.key_hint, "%s: with its letter" % named)
		var reset: UiButton = bar.reset_button
		assert_not_null(reset.icon, "%s: the reset button keeps its icon" % what)
		assert_eq(reset.text, "Reset", "%s: and gets the word" % what)
		assert_eq(reset.key_drawn, "", "%s: and no key" % what)
		main.free()


# --- R2 ------------------------------------------------------------------------


func test_r2_one_name_per_window_everywhere() -> void:
	var main: Main = await _settled(ROOM_LARGE)
	var bar: UiButtonBar = main.ui.bar
	var said: Array[String] = []
	for entry: Array in KeyBook.entries():
		said.append(str(entry[1]))
	said.append_array(HelpPanel.IDEA)
	for id: StringName in NAMES:
		var named: String = NAMES[id]
		var window: UiWindow = main.ui.windows.window(id)
		var button: UiButton = bar.buttons.get(id, null)
		assert_not_null(button, "%s has a button" % id)
		if button == null:
			continue
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
	assert_eq(_spellings(Purse.GOLD_TIP, "shop"), [] as Array[String], "so does the gold's tooltip")
	assert_gt(_spellings(Purse.GOLD_TIP, "Camp").size(), 0, "which names the Camp")
	# Every goal, note, caption and tooltip in the game's code: no other word for a window, and
	# a window's word spelled as its button spells it (a caption in capitals, in capitals).
	var titles: Array[String] = []
	for id: StringName in NAMES:
		titles.append(main.ui.windows.window(id).title)
	var texts: Dictionary[String, String] = {}
	_strings_in("res://game", texts)
	assert_gt(texts.size(), 200, "the game's strings were read")
	for where: String in texts:
		var text: String = texts[where]
		if titles.has(text):
			continue  # a title holds the word in a phrase of its own (Camp upgrades, Area map)
		assert_eq(_spellings(text, "shop"), [] as Array[String], "%s says Camp: %s" % [where, text])
		assert_eq(
			_spellings(text, "area map"), [] as Array[String], "%s says Map: %s" % [where, text]
		)
		var shouted: bool = text == text.to_upper()
		for id: StringName in NAMES:
			var word: String = NAMES[id].to_upper() if shouted else NAMES[id]
			for spelled: String in _spellings(text, word):
				assert_eq(spelled, word, "%s: '%s' in '%s'" % [where, spelled, text])
	# The ones that name a window do say its word.
	var naming: Dictionary[String, String] = {
		Goals.CLICKS[Goals.Kind.UPGRADE]: "Camp",
		Goals.CLICKS[Goals.Kind.GUARDIAN]: "Orders",
		Goals.CLICKS[Goals.Kind.VISIT]: "Map",
		DefeatNote.TIPS[DefeatNote.Help.UPGRADE]: "Camp",
		HudFrame.area_tip(): "Map",
		Showcase.caption(&"shop"): "CAMP",
		Showcase.caption(&"area_map"): "MAP",
	}
	for text: String in naming:
		assert_gt(_spellings(text, naming[text]).size(), 0, "'%s' names the window" % text)
	# The wiki: Camp, never the shop; and its table of keys names each window as its button does.
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	assert_eq(_spellings(wiki, "shop"), [] as Array[String], "the wiki says Camp, not shop")
	for id: StringName in NAMES:
		var row: String = _wiki_key_row(wiki, main.ui.windows.window(id).key_hint)
		assert_true(row.contains(NAMES[id]), "the wiki's key for %s names it: %s" % [id, row])


# --- R3 ------------------------------------------------------------------------


func test_r3_reads_lit_tagged_and_disabled() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		var ui: UiRoot = main.ui
		var bar: UiButtonBar = ui.bar
		var told: Dictionary[String, StringName] = {}
		await _check_tags(main, "%s" % room)
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons[id]
			var window: UiWindow = ui.windows.window(id)
			var named: String = "%s: %s" % [room, id]
			var at: Rect2 = button.get_global_rect()
			var rest: StyleBoxFlat = button.get_theme_stylebox(&"normal") as StyleBoxFlat
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
		mouse_move(ui.ui_to_world(help.get_global_rect().get_center()))
		bar.tip.advance(UiTip.DELAY + 0.05)
		assert_eq(bar.tip.shown_text(), bar.tip.text_for(help), "%s: the tooltip shows" % room)
		# Disabled: the name stays, in a colour that shows on the sunken face.
		help.disabled = true
		var off: StyleBoxFlat = help.get_theme_stylebox(&"disabled") as StyleBoxFlat
		assert_eq(help.text, "Help", "%s: a disabled button keeps its name" % room)
		assert_ne(help.get_theme_color(&"font_disabled_color"), off.bg_color, "%s: readable" % room)
		assert_ne(off.bg_color, rest_of(help).bg_color, "%s: and told apart" % room)
		mouse_move(Vector2(-10, -10))
		main.free()


## Spec 068 R3: with two hero windows open at their default places, every button's tag shows whole
## on the corner of its icon: no window over it, none of it more than 2 pixels outside its button
## or on another button, and clear of the name and the key.
func _check_tags(main: Main, what: String) -> void:
	var ui: UiRoot = main.ui
	var bar: UiButtonBar = ui.bar
	var heroes: Array[Hero] = main.simulation.party.heroes
	for hero: Hero in [heroes[0], heroes[1]]:
		main.hud.hero_windows.open(hero.id)
	await _frames()
	var open: Array[UiWindow] = _open_windows(ui)
	assert_eq(open.size(), 2, "%s: two hero windows open" % what)
	for shown: UiWindow in open:
		assert_eq(shown.position, shown.default_place, "%s: %s where it opens" % [what, shown.name])
	for count: int in [3, 12]:
		for id: StringName in NAMES:
			ui.windows.window(id).badge = count
		bar.refresh()
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons[id]
			var tag: UiBadge = bar.badges[id]
			var named: String = "%s: %s's tag of %d" % [what, id, count]
			var at: Rect2 = button.get_global_rect()
			var tagged: Rect2 = tag.get_global_rect()
			assert_true(tag.is_visible_in_tree(), "%s shows" % named)
			assert_true(tagged.has_area(), "%s has a size" % named)
			assert_true(
				at.grow(TAG_OUTSIDE).encloses(tagged),
				"%s reaches no more than 2 outside its button: %s on %s" % [named, tagged, at]
			)
			assert_true(
				tagged.has_point(_on_layer(button, button.icon_rect()).position),
				"%s on the corner of the icon" % named
			)
			assert_false(
				tagged.intersects(_on_layer(button, button.name_rect())),
				"%s clear of the name" % named
			)
			var cap: Rect2 = _on_layer(button, button.key_rect())
			assert_true(cap.has_area(), "%s: a key to keep clear of" % named)
			assert_false(tagged.intersects(cap), "%s clear of the key" % named)
			for shown: UiWindow in open:
				assert_false(
					tagged.intersects(shown.get_global_rect()),
					"%s whole beside %s: %s" % [named, shown.name, tagged]
				)
			for other: UiButton in _row(bar):
				if other != button:
					assert_false(
						tagged.intersects(other.get_global_rect()),
						"%s not on the %s button" % [named, other.text]
					)
	for id: StringName in NAMES:
		ui.windows.window(id).badge = 0
	bar.refresh()
	main.hud.hero_windows.close_all()
	await _frames()


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
		assert_gt(rect.end.y, line - 16.0, "%s: just above" % what)
		assert_gt(rect.position.x, room.x / 2.0, "%s: at the right" % what)
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
		# No wider than what stands at its left leaves it.
		assert_lte(rect.size.x, WIDEST[room], "%s: no wider than its room" % what)
		assert_eq(bar.stacked, room == ROOM_SMALL, "%s: icon over name only at 960x540" % what)
		assert_true(bar.shows_keys, "%s: the keys on the buttons" % what)
		# Every name whole, with its icon and its key, each wholly on the button and none on
		# another.
		for id: StringName in NAMES:
			var button: UiButton = bar.buttons[id]
			var named: String = "%s: %s" % [what, id]
			assert_gte(
				button.size.x, button.hinted_width(), "%s: room for the icon and the key" % named
			)
			var face := Rect2(Vector2.ZERO, button.size)
			var icon: Rect2 = button.icon_rect()
			var said: Rect2 = button.name_rect()
			var cap: Rect2 = button.key_rect()
			assert_eq(icon.size, Vector2(16, 16), "%s: the icon whole" % named)
			assert_eq(said.size.y, float(UiText.LINE_HEIGHT), "%s: a whole line" % named)
			assert_true(face.grow(-1.0).encloses(icon), "%s: the icon inside: %s" % [named, icon])
			assert_true(
				face.grow(-1.0).encloses(said),
				"%s: the name inside: %s in %s" % [named, said, button.size]
			)
			assert_false(icon.intersects(said), "%s: the icon clear of the name" % named)
			if bar.stacked:
				assert_gte(said.position.y, icon.end.y + 1.0, "%s: the icon over the name" % named)
				assert_eq(cap.end.x, button.size.x, "%s: the cap at the right corner" % named)
				assert_eq(cap.position.y, 0.0, "%s: at the top" % named)
				assert_lt(cap.size.y, icon.size.y, "%s: a small cap" % named)
			else:
				assert_gte(said.position.x, icon.end.x, "%s: the name after the icon" % named)
				assert_gte(cap.position.x, said.end.x, "%s: the key after the name" % named)
		# The tooltip of a button at the bar's corner stays on screen.
		var help: UiButton = bar.buttons[&"help"]
		mouse_move(main.ui.ui_to_world(help.get_global_rect().get_center()))
		bar.tip.advance(UiTip.DELAY + 0.05)
		assert_eq(bar.tip.shown_text(), bar.tip.text_for(help), "%s: setup: the tooltip" % what)
		assert_true(
			Rect2(Vector2.ZERO, Vector2(room)).encloses(bar.tip.get_global_rect()),
			"%s: the tooltip on screen" % what
		)
		mouse_move(Vector2(-10, -10))
		main.free()
	# Between the two rooms the keys stay, each at its button's corner.
	var squeezed: Main = await _settled(ROOM_LARGE)
	var tight: UiButtonBar = squeezed.ui.bar
	var with_keys: float = tight.size.x
	assert_true(tight.shows_keys and not tight.stacked, "side by side at 1280x720")
	tight.fit_room(Vector2i(1100, 620))
	await _frames()
	assert_true(tight.stacked, "a narrower room puts each icon over its name")
	assert_true(tight.shows_keys, "and keeps the keys")
	assert_lt(tight.size.x, with_keys, "for a narrower bar")
	_check_one_row(tight, "narrower")
	var cornered: float = tight.size.x
	# Only where even that has no room do the keys go, and every name stays whole.
	tight.fit_room(Vector2i(930, 524))
	await _frames()
	assert_true(tight.stacked, "narrower still: each icon still over its name")
	assert_false(tight.shows_keys, "narrower still: the keys are dropped")
	assert_lt(tight.size.x, cornered, "for a bar narrower again")
	_check_one_row(tight, "narrowest")
	for id: StringName in NAMES:
		var button: UiButton = tight.buttons[id]
		assert_eq(button.text, NAMES[id], "narrowest: %s's name whole" % id)
		assert_eq(button.key_hint, "", "narrowest: %s's key off the button" % id)
		assert_false(button.key_rect().has_area(), "narrowest: and no cap drawn")
		assert_true(
			tight.tip.text_for(button).contains("(%s)" % squeezed.ui.windows.window(id).key_hint),
			"narrowest: %s's tooltip still names the key" % id
		)
	tight.fit_room(ROOM_LARGE)
	assert_true(tight.shows_keys and not tight.stacked, "and they come back with the room")
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
			# A tag never takes its button's click: the first click is on the tag itself.
			window.badge = 9
			bar.refresh()
			var tagged: Rect2 = bar.badges[id].get_global_rect()
			assert_true(bar.badges[id].is_visible_in_tree(), "%s: tagged" % named)
			assert_true(
				button.get_global_rect().has_point(tagged.get_center()),
				"%s: the tag's middle is on the button" % named
			)
			assert_false(window.is_open(), "%s: closed at first" % named)
			_click_ui(ui, tagged.get_center())
			assert_true(window.is_open(), "%s: a click on its tag opens it" % named)
			_click_ui(ui, button.get_global_rect().get_center())
			assert_false(window.is_open(), "%s: and closes it" % named)
			press(window.keycode)
			assert_true(window.is_open(), "%s: its key opens it" % named)
			press(window.keycode)
			assert_false(window.is_open(), "%s: and closes it" % named)
		# The reset button puts a dragged window back.
		var journal: UiWindow = ui.windows.window(&"journal")
		ui.windows.open_window(&"journal")
		await _frames()
		_drag(ui, journal, Vector2(60, 40))
		assert_ne(journal.position, journal.default_place, "%s: the journal dragged away" % room)
		_click_ui(ui, bar.reset_button.get_global_rect().get_center())
		assert_eq(journal.position, journal.default_place, "%s: Reset puts it back" % room)
		mouse_move(Vector2(-10, -10))
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_help_and_wiki() -> void:
	var main: Main = await _settled(ROOM_SMALL)
	var help: HelpPanel = main.ui.windows.window(&"help").content as HelpPanel
	var shown: Array[String] = help.lines()
	for id: StringName in NAMES:
		var window: UiWindow = main.ui.windows.window(id)
		var does: String = _help_says(window.keycode)
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
	assert_true(row.contains("top right corner"), "and where the key is in the smallest room")
	assert_false(wiki.contains("The Shop button"), "the wiki no longer calls it the Shop button")
	assert_true(wiki.contains("The Camp button"), "but the Camp button")

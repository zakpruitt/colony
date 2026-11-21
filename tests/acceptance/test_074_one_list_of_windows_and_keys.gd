extends "res://tests/support/main_fixture.gd"
## Acceptance tests for specs/074-one-list-of-windows-and-keys/spec.md, one per requirement. The
## window and key tests run the main scene at both rooms; the code tests read every script under
## res://game.

const ROOMS: Array[Vector2i] = [ROOM_SMALL, ROOM_LARGE]
## Each bar window as today: its button's word, its key cap, its tooltip and its help line.
const WINDOWS: Dictionary[StringName, Array] = {
	&"help":
	[
		"Help",
		"H",
		"Help (H): how Colony works, and every key it answers to.",
		"H  Open or close Help",
	],
	&"journal":
	[
		"Journal",
		"J",
		"Journal (J): what has happened to the party, newest first.",
		"J  Open or close the Journal",
	],
	&"orders":
	[
		"Orders",
		"O",
		"Party orders (O): how careful the party is, and whether it fights guardians.",
		"O  Open or close the Orders",
	],
	&"shop":
	[
		"Camp",
		"U",
		"Camp upgrades (U): spend gold on upgrades for the whole party.",
		"U  Open or close the Camp",
	],
	&"map":
	[
		"Map",
		"W",
		"Area map (W): the areas the party can go to, and what each holds.",
		"W  Open or close the Map",
	],
	&"tally":
	[
		"Tally",
		"T",
		"Party tally (T): who deals, heals and takes the damage.",
		"T  Open or close the Tally",
	],
}
## The help's key lines today, in order.
const HELP_KEYS: Array[String] = [
	"H  Open or close Help",
	"Esc  Close the front window",
	"- +  Target a stage back or further",
	"A  Auto on or off: go on when it is safe",
	"U  Open or close the Camp",
	"B  Camp in front: auto-buy on or off",
	"1-5  Camp in front: buy that upgrade",
	"1-3  Talents tab: a paragon point to a stat",
	"Q E  Hero window or Tally: change tab",
	"Tab  Open the next hero's window",
	"Shift+Tab  Close the front hero window",
	"J  Open or close the Journal",
	"O  Open or close the Orders",
	"T  Open or close the Tally",
	"L  Show or hide the stage list",
	"W  Open or close the Map",
	"G  Show or hide the goals",
	"Z  Zoom in or out",
	"F  Game speed: 1x, 2x or 4x",
	"M  Sound on or off",
	"F11  Full screen on or off",
	"F3  Show the clock (for testing)",
]
## The window R3 adds: its id, and a key no other answers to.
const ADDED: StringName = &"notes"
const ADDED_KEY: Key = KEY_N


func after_each() -> void:
	WindowBook.remove(ADDED)
	super()


## A main scene for [param room] with its bar settled.
func _settled(room: Vector2i, settings: SoundSettings = null) -> Main:
	var main: Main = _main(room, settings)
	main.hud.advance(STEP)
	await _frames()
	main.ui.bar.refresh()
	return main


## The help window's lines from "Keys" to the footer.
func _help_keys(main: Main) -> Array[String]:
	var help: HelpPanel = main.ui.windows.window(UiRoot.HELP).content as HelpPanel
	var lines: Array[String] = help.lines()
	return lines.slice(lines.find("Keys") + 1, lines.find(HelpPanel.FOOTER))


## The entry called [param id] of [param ui]'s list, or null.
func _entry(ui: UiRoot, id: StringName) -> WindowEntry:
	for entry: WindowEntry in ui.entries:
		if entry.id == id:
			return entry
	return null


## The window R3 adds: a plain label in it.
func _added_entry() -> WindowEntry:
	var made := WindowEntry.new(
		ADDED,
		"Field notes",
		"Notes",
		ADDED_KEY,
		"what the party wrote down.",
		func() -> WindowContent:
			var content := WindowContent.new()
			content.add_child(UiText.label("A plain note", &"white"))
			return content
	)
	return made


# --- R2 ------------------------------------------------------------------------


func test_r2_bar_tips_and_help_come_from_the_list() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		var bar: UiButtonBar = main.ui.bar
		var help: Array[String] = _help_keys(main)
		assert_eq(main.ui.entries.size(), WINDOWS.size(), "%s: six entries" % room)
		var order: Array[StringName] = []
		for entry: WindowEntry in main.ui.entries:
			order.append(entry.id)
		assert_eq(order, WINDOWS.keys() as Array[StringName], "%s: in the bar's order" % room)
		for id: StringName in WINDOWS:
			var today: Array = WINDOWS[id]
			var entry: WindowEntry = _entry(main.ui, id)
			var button: UiButton = bar.buttons.get(id, null)
			assert_not_null(entry, "%s: %s has an entry" % [room, id])
			assert_not_null(button, "%s: %s has a button" % [room, id])
			if entry == null or button == null:
				continue
			var cap: String = KeyBook.key_name(entry.key)
			assert_eq(button.text, entry.short_name, "%s: %s's name is its entry's" % [room, id])
			assert_eq(button.text, str(today[0]), "%s: %s's name" % [room, id])
			assert_eq(cap, str(today[1]), "%s: %s's key" % [room, id])
			assert_eq(button.key_hint, cap if bar.shows_keys else "", "%s: %s's cap" % [room, id])
			assert_eq(button.key_drawn, button.key_hint, "%s: %s's cap drawn" % [room, id])
			assert_eq(bar.tip.text_for(button), entry.tip(), "%s: %s's tooltip" % [room, id])
			assert_eq(entry.tip(), str(today[2]), "%s: %s's tooltip" % [room, id])
			var line: String = "%s  %s" % [cap, entry.help_text()]
			assert_eq(line, str(today[3]), "%s: %s's help line" % [room, id])
			assert_has(help, line, "%s: the help says it" % room)
		main.free()


# --- R3 ------------------------------------------------------------------------


func test_r3_a_new_entry_gets_a_button_a_key_and_a_help_line() -> void:
	for room: Vector2i in ROOMS:
		# Without the entry: nothing of it.
		var plain: Main = await _settled(room)
		assert_null(plain.ui.windows.window(ADDED), "%s: no window without the entry" % room)
		assert_false(plain.ui.bar.buttons.has(ADDED), "%s: no button" % room)
		assert_eq(_help_keys(plain).size(), HELP_KEYS.size(), "%s: no help line" % room)
		_press(plain, ADDED_KEY)
		assert_null(plain.ui.windows.front(), "%s: its key opens nothing" % room)
		plain.free()

		# With it.
		WindowBook.add(_added_entry())
		var settings := SoundSettings.new(_settings_path)
		var main: Main = await _settled(room, settings)
		var shown: UiWindow = main.ui.windows.window(ADDED)
		assert_not_null(shown, "%s: the window is made" % room)
		if shown == null:
			WindowBook.remove(ADDED)
			main.free()
			continue
		assert_eq(shown.title, "Field notes", "%s: its title" % room)
		var button: UiButton = main.ui.bar.buttons.get(ADDED, null)
		assert_not_null(button, "%s: a button on the bar" % room)
		assert_eq(button.text, "Notes", "%s: with its name" % room)
		if main.ui.bar.shows_keys:
			assert_eq(button.key_hint, "N", "%s: and its key" % room)
		assert_eq(
			main.ui.bar.tip.text_for(button),
			"Field notes (N): what the party wrote down.",
			"%s: a tooltip" % room
		)
		var help: Array[String] = _help_keys(main)
		assert_eq(help.size(), HELP_KEYS.size() + 1, "%s: one more help line" % room)
		assert_eq(help[-1], "N  Open or close the Notes", "%s: at the end" % room)
		_press(main, ADDED_KEY)
		assert_true(shown.is_open(), "%s: its key opens it" % room)
		_press(main, ADDED_KEY)
		assert_false(shown.is_open(), "%s: and closes it" % room)
		_click(main, button)
		assert_true(shown.is_open(), "%s: its button opens it" % room)
		main.free()

		# Remembered: open as the next game starts.
		var again: Main = await _settled(room, SoundSettings.new(_settings_path))
		again.ui.windows.open_waiting()
		assert_true(again.ui.windows.is_open(ADDED), "%s: remembered open" % room)
		again.free()
		WindowBook.remove(ADDED)
		DirAccess.remove_absolute(_settings_path)


# --- R4 ------------------------------------------------------------------------


func test_r4_every_window_content_is_a_window_content() -> void:
	var main: Main = await _settled(ROOM_LARGE)
	for id: StringName in WINDOWS:
		var shown: UiWindow = main.ui.windows.window(id)
		assert_not_null(shown, "%s: a window" % id)
		if shown == null:
			continue
		assert_true(shown.content is WindowContent, "%s: a WindowContent" % id)
		var script: Script = shown.content.get_script() as Script
		assert_eq(
			script.resource_path.get_base_dir(),
			"res://game/ui/windows",
			"%s: under game/ui/windows" % id
		)
		var methods: Array[String] = []
		while script != null:
			for method: Dictionary in script.get_script_method_list():
				methods.append(str(method["name"]))
			script = script.get_base_script()
		assert_false(methods.has("_process"), "%s: no _process of its own" % id)
		assert_true(methods.has("advance"), "%s: advanced by its owner" % id)
	# Help, the journal and the orders are the layer's to advance, the rest the HUD's.
	var journal: JournalView = main.ui.windows.window(UiRoot.JOURNAL).content as JournalView
	main.hud.journal.write("A line for the layer")
	main.ui.advance(STEP)
	assert_eq(journal.shown_lines(), main.hud.journal.lines(), "the layer advances the journal")


# --- R5 ------------------------------------------------------------------------


func test_r5_help_lists_the_keys_in_the_same_order() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = await _settled(room)
		assert_eq(_help_keys(main), HELP_KEYS, "%s: the help's lines" % room)
		main.free()
	var from_table: Array[String] = []
	for entry: Array in KeyBook.entries():
		from_table.append("%s  %s" % [entry[0], entry[1]])
	assert_eq(from_table, HELP_KEYS, "built from the table")


func test_r5_keys_are_guarded_one_way() -> void:
	var texts: Dictionary[String, String] = {}
	scripts_in("res://game", texts)
	assert_gt(texts.size(), 100, "the game's scripts were read")
	var guarded: Array[String] = []
	for path: String in texts:
		if texts[path].contains(".echo"):
			guarded.append(path)
	assert_eq(guarded, ["res://game/ui/key_book.gd"] as Array[String], "only KeyBook asks")
	# The guards that were written by hand ask it.
	for path: String in [
		"res://game/audio/sound_player.gd",
		"res://game/hud/goals.gd",
		"res://game/hud/hud.gd",
		"res://game/main.gd",
		"res://game/ui/frame/stage_list.gd",
		"res://game/ui/ui_windows.gd",
		"res://game/window_settings.gd",
		"res://game/world/world.gd",
	]:
		assert_true(texts[path].contains("KeyBook."), "%s asks KeyBook" % path)


# --- R6 ------------------------------------------------------------------------


func test_r6_no_sentence_spells_a_key_itself() -> void:
	var quoted := RegEx.new()
	quoted.compile('"((?:[^"\\\\]|\\\\.)*)"')
	var texts: Dictionary[String, String] = {}
	scripts_in("res://game", texts)
	var read: int = 0
	for path: String in texts:
		var lines: PackedStringArray = texts[path].split("\n")
		for i: int in lines.size():
			if lines[i].strip_edges().begins_with("#"):
				continue
			for found: RegExMatch in quoted.search_all(lines[i]):
				read += 1
				var text: String = found.get_string(1)
				for spelled: String in ["(O)", "(U)", "(W)", "press F"]:
					assert_false(
						text.contains(spelled), "%s:%d spells %s: %s" % [path, i + 1, spelled, text]
					)
	assert_gt(read, 200, "the game's strings were read")
	# The words on screen are as they were, each sentence that asks KeyBook for a key in full.
	var said: Dictionary[String, String] = {
		HudFrame.area_tip(): "The area the party is in: click (or press W) to open the Map.",
		HudFrame.speed_tip(): "How fast the game runs: click (or press F) for 1x, 2x or 4x.",
		HudFrame.holding_tip():
		"The Hold order keeps the party from the guardian: Orders (O) sends it in.",
		HudFrame.holding_next(): "Orders (O) to go in",
		Goals.upgrade_hint(): "Open the Camp (U) and spend gold on the whole party.",
		Goals.holding_hint():
		"The party is holding back on the Hold order: Orders (O) sends it in.",
		AreaNews.visit_hint("The Claypits"):
		"The Claypits is open: send the party there from the Map (W).",
		DefeatNote.holding_tip():
		"The party stays away from guardians until Orders (O) sends it in.",
	}
	assert_eq(said.size(), 8, "eight different sentences")
	for text: String in said:
		assert_eq(text, said[text], "the sentence on screen")
	assert_eq(KeyBook.label(UiRoot.ORDERS), "O", "the orders' key")
	assert_eq(KeyBook.label(ShopWindow.ID), "U", "the Camp's key")
	assert_eq(KeyBook.label(AreaMapWindow.ID), "W", "the Map's key")
	assert_eq(KeyBook.label(&"speed"), "F", "the speed's key")

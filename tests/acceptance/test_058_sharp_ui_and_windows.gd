extends "res://tests/acceptance/ui_layer_test_base.gd"
## Acceptance tests for specs/058-sharp-ui-and-windows/spec.md, one per requirement (more for R5
## to R8, beside the old HUD, are in test_058_windows_beside_the_old_hud.gd).
##
## Most tests run the main scene with its processing turned off and step it by hand, the UI layer
## laid out for a chosen room ([method UiRoot.set_room_for_test]); the helpers are in
## ui_layer_test_base.gd.

const SPECIMEN: PackedScene = preload("res://game/ui/font_specimen.tscn")
## The window sizes R1 lists: each with its world scale, its UI scale and its room.
const WINDOWS: Array[Array] = [
	[Vector2i(1280, 720), 2, 1, Vector2i(1280, 720)],
	[Vector2i(1920, 1080), 3, 2, Vector2i(960, 540)],
	[Vector2i(2560, 1440), 4, 2, Vector2i(1280, 720)],
	[Vector2i(3840, 2160), 6, 4, Vector2i(960, 540)],
]
## Every KEY_ name written in the game's scripts must be in the help list (spec 030 R3).
## The three windows spec 058 made; spec 059 added the shop, the map and the tally beside them.
const OWN_WINDOWS: Array[StringName] = [UiRoot.HELP, UiRoot.JOURNAL, UiRoot.ORDERS]
const KEY_PATTERN: String = "\\bKEY_[A-Z0-9_]+\\b"
## A string literal in a script or a resource.
const STRING_PATTERN: String = '"((?:[^"\\\\\\n]|\\\\.)*)"'
const WIKI: String = "res://docs/wiki/index.html"


## The pixels [param text] inks in the UI font, each glyph placed after the last one's advance.
func _inked(text: String, bold: bool) -> Dictionary[Vector2i, bool]:
	var inked: Dictionary[Vector2i, bool] = {}
	var x: int = 0
	for character: String in text:
		for pixel: Vector2i in UiText.ink(character, bold):
			inked[pixel + Vector2i(x, 0)] = true
		x += UiText.advance(character, bold)
	return inked


## How many pixels differ between [param a] and [param b] in the UI font.
func _difference(a: String, b: String, bold: bool) -> int:
	var first: Dictionary[Vector2i, bool] = _inked(a, bold)
	var second: Dictionary[Vector2i, bool] = _inked(b, bold)
	var differ: int = 0
	for pixel: Vector2i in first:
		if not second.has(pixel):
			differ += 1
	for pixel: Vector2i in second:
		if not first.has(pixel):
			differ += 1
	return differ


## Every character in the string literals of the scripts and resources under [param dir].
func _characters_in(dir: String, into: Dictionary[String, String]) -> void:
	var pattern := RegEx.new()
	pattern.compile(STRING_PATTERN)
	for file: String in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or file.ends_with(".tres")):
			continue
		var path: String = dir.path_join(file)
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
			for character: String in found.get_string(1):
				if character != "\\":
					into[character] = path
	for sub: String in DirAccess.get_directories_at(dir):
		_characters_in(dir.path_join(sub), into)


func _key_names_in(dir: String, into: Dictionary[String, String]) -> void:
	var pattern := RegEx.new()
	pattern.compile(KEY_PATTERN)
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var path: String = dir.path_join(file)
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
			into[found.get_string()] = path
	for sub: String in DirAccess.get_directories_at(dir):
		_key_names_in(dir.path_join(sub), into)


# --- R1 ------------------------------------------------------------------------


func test_r1_two_layers() -> void:
	for entry: Array in WINDOWS:
		var window: Vector2i = entry[0]
		var world_scale: int = entry[1]
		var ui_scale: int = entry[2]
		var ui_room: Vector2i = entry[3]
		assert_eq(UiRoot.world_scale_for(window), world_scale, "%s: the world's scale" % window)
		assert_eq(UiRoot.ui_scale_for(window), ui_scale, "%s: the UI's scale" % window)
		assert_eq(UiRoot.room_for(window), ui_room, "%s: the UI's room" % window)
		var room: Vector2i = UiRoot.room_for(window)
		assert_true(
			room.x >= 960 and room.x <= 1280 and room.y >= 540 and room.y <= 720, "%s" % room
		)

	var main: Main = _main(ROOM_SMALL)
	# The world: drawn at 640x360 into its own viewport, shown scaled by a whole number, hard edged.
	assert_eq(main.world_viewport.size, Vector2i(640, 360), "the world is drawn at 640x360")
	assert_eq(main.world.get_viewport(), main.world_viewport, "the world is in it")
	assert_eq(main.effects.get_viewport(), main.world_viewport, "and its effects")
	assert_eq(main.hud_layer.custom_viewport, main.world_viewport, "and the old HUD draws there")
	assert_true(main.world_viewport.snap_2d_transforms_to_pixel, "on whole world pixels")
	assert_eq(
		main.world_viewport.canvas_item_default_texture_filter,
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"sprites unfiltered"
	)
	assert_eq(
		main.world_view.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "scaled hard-edged"
	)
	assert_true(main.world_view.stretch, "the view stretches the world")
	assert_eq(main.world_view.stretch_shrink, 1)
	var root: Window = get_tree().root
	assert_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "rendered at size")
	assert_eq(root.content_scale_size, Vector2i(640, 360), "in the world's pixels")
	assert_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER, "a whole scale")
	var sprite: Sprite2D = main.world.find_children("*", "Sprite2D", true, false)[0] as Sprite2D
	assert_eq(sprite.get_viewport(), main.world_viewport, "a world sprite is drawn at 640x360")

	# The UI layer: one UI pixel is a whole number of screen pixels, and nothing sits between.
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		main.ui.set_room_for_test(room)
		for id: StringName in main.ui.windows.ids():
			main.ui.windows.open_window(id)
		await _frames()
		var ui: UiRoot = main.ui
		assert_eq(ui.room(), room, "the room")
		var screen_scale: float = ui.scale.x * ui.world_scale()
		assert_almost_eq(
			screen_scale,
			float(ui.ui_scale()),
			0.0001,
			"%s: a UI pixel is %d screen pixels" % [room, ui.ui_scale()]
		)
		var controls: Array[Control] = []
		_controls(ui.frame, controls)
		assert_gt(controls.size(), 50, "the layer is full of controls")
		for control: Control in controls:
			if not control.is_visible_in_tree():
				continue
			var in_ui: Vector2 = control.get_global_rect().position
			assert_eq(in_ui, in_ui.round(), "%s %s at whole UI pixels" % [room, control.get_path()])
			var at: Vector2 = in_ui * float(ui.ui_scale())
			assert_eq(at, at.round(), "%s %s at whole pixels" % [room, control.get_path()])
		assert_eq(ui.world_to_ui(ui.ui_to_world(Vector2(13, 7))), Vector2(13, 7), "the two ways")

	# Resizing the window re-fits both: a fresh layer follows the viewport's size.
	var was: Vector2i = root.size
	var fresh: Main = make_main()
	add_child_autofree(fresh)
	root.size = Vector2i(1920, 1080)
	assert_eq(fresh.ui.room(), Vector2i(960, 540), "a 1920x1080 window: 960x540 of room")
	assert_eq(fresh.ui.ui_scale(), 2, "at a UI scale of 2")
	assert_eq(fresh.ui.world_scale(), 3, "over a world scaled by 3")
	root.size = Vector2i(1280, 720)
	assert_eq(fresh.ui.room(), Vector2i(1280, 720), "a 1280x720 window: 1280x720 of room")
	root.size = was


# --- R2 ------------------------------------------------------------------------


func test_r2_the_old_hud_still_works() -> void:
	var main: Main = _main(ROOM_SMALL)
	var hud: Hud = main.hud
	# Its old buttons, at their old places, still act on a real click.
	var target: int = main.simulation.expedition.target_depth
	click(Hud.on_screen(hud.place_panel.plus_button).get_center())
	main.simulation.step()
	assert_eq(
		main.simulation.expedition.target_depth, target + 1, "the + button still sets the target"
	)
	# Spec 059: the Shop button moved to the bar, and the shop is a window Esc closes.
	await _frames()
	_click_ui(main.ui, main.ui.bar.buttons[ShopWindow.ID].get_global_rect().get_center())
	assert_true(hud.shop.is_open(), "the Shop button still opens the shop")
	press(KEY_ESCAPE)
	assert_false(hud.shop.is_open(), "Esc closes it, the front window")
	click(Hud.on_screen(hud.frames[0]).get_center())
	assert_true(hud.hero_windows.is_open(), "a hero frame still opens its hero window")
	press(KEY_U)
	assert_true(hud.shop.is_open(), "U still opens the shop")
	hud.shop.close()
	# The moved panels are gone from the old HUD, with their buttons: never shown twice.
	for gone: String in ["help", "help_button", "orders", "orders_button"]:
		assert_false(gone in hud, "the old HUD has no %s" % gone)
	assert_false(&"open" in hud.journal, "the journal keeps no panel of its own")
	assert_eq(hud.find_children("*", "HelpPanel", true, false).size(), 0, "no help on the old HUD")
	assert_eq(hud.find_children("*", "OrdersPanel", true, false).size(), 0, "no orders there")
	assert_eq(hud.find_children("*", "JournalView", true, false).size(), 0, "no journal list there")
	assert_eq(main.ui.frame.find_children("*", "HelpPanel", true, false).size(), 1, "one help")
	assert_eq(main.ui.frame.find_children("*", "OrdersPanel", true, false).size(), 1, "one orders")
	assert_eq(main.ui.frame.find_children("*", "JournalView", true, false).size(), 1, "one journal")
	assert_not_null(hud.ticker, "the ticker stays")


# --- R3 ------------------------------------------------------------------------


func test_r3_a_font_made_for_reading() -> void:
	# Every character the game's texts use has a glyph, in both weights.
	var used: Dictionary[String, String] = {}
	_characters_in("res://game", used)
	_characters_in("res://data", used)
	_characters_in("res://sim", used)
	assert_gt(used.size(), 60, "the game's texts were found")
	for character: String in used:
		if character == "\n" or character == "\t":
			continue
		for bold: bool in [false, true]:
			assert_true(
				UiText.has_glyph(character, bold),
				(
					"'%s' (in %s) has a glyph%s"
					% [character, used[character], " in bold" if bold else ""]
				)
			)
	for code: int in range(32, 127):
		assert_true(UiText.has_glyph(char(code)), "printable '%s' has a glyph" % char(code))

	for bold: bool in [false, true]:
		var weight: String = "bold" if bold else "regular"
		# Capitals and digits: 9 pixels tall, standing on the baseline.
		for character: String in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			var rows: Vector2i = _rows(character, bold)
			assert_eq(
				rows, Vector2i(0, UiText.CAP_HEIGHT - 1), "%s %s: 9 tall" % [weight, character]
			)
		# Lower case: an x-height of 6, with real descenders.
		for character: String in "acemnorsuvwxz":
			var rows: Vector2i = _rows(character, bold)
			assert_eq(
				rows.x, UiText.CAP_HEIGHT - UiText.X_HEIGHT, "%s %s: x-height" % [weight, character]
			)
			assert_eq(rows.y, UiText.CAP_HEIGHT - 1, "%s %s: on the baseline" % [weight, character])
		for character: String in "gjpqy":
			assert_gte(
				_rows(character, bold).y,
				UiText.CAP_HEIGHT + 1,
				"%s %s descends" % [weight, character]
			)
		for character: String in "bdhkl":
			assert_eq(
				_rows(character, bold).x, 0, "%s %s rises to the capitals" % [weight, character]
			)
		# Digits all one width.
		for digit: String in "0123456789":
			assert_eq(
				UiText.advance(digit, bold),
				UiText.advance("0", bold),
				"%s %s: one width" % [weight, digit]
			)
		assert_eq(
			UiText.width("1111", bold),
			UiText.width("8888", bold),
			"%s numbers keep their width" % weight
		)
		# Look-alikes told apart at a glance: at least 3 pixels between each pair.
		for pair: Array in [
			["1", "l"], ["1", "I"], ["l", "I"], ["0", "O"], ["5", "S"], ["rn", "m"]
		]:
			var differ: int = _difference(str(pair[0]), str(pair[1]), bold)
			assert_gte(
				differ,
				3,
				"%s '%s' and '%s' differ in %d pixels" % [weight, pair[0], pair[1], differ]
			)
	# Letters with their own widths, strokes one pixel wide (no 2x2 block of ink in a letter or digit).
	var widths: Dictionary[int, bool] = {}
	for character: String in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
		widths[UiText.drawn_width(character)] = true
		var ink: Array[Vector2i] = UiText.ink(character)
		for pixel: Vector2i in ink:
			var block: bool = (
				ink.has(pixel + Vector2i(1, 0))
				and ink.has(pixel + Vector2i(0, 1))
				and ink.has(pixel + Vector2i(1, 1))
			)
			assert_false(block, "'%s': strokes one pixel wide (at %s)" % [character, pixel])
	assert_gte(widths.size(), 4, "letters have their own widths: %s" % [widths.keys()])
	assert_lt(UiText.width("i"), UiText.width("m"), "an i is narrower than an m")
	# The bold is the same size, heavier.
	assert_eq(UiText.font(true).fixed_size, UiText.font().fixed_size, "the bold is the same size")
	assert_gt(UiText.ink("A", true).size(), UiText.ink("A").size(), "and heavier")
	# The old font stays, for the world and the old HUD.
	assert_not_null(PixelText.font(), "the old font still loads")
	assert_eq(
		get_tree().root.get_theme_default_font(), PixelText.font(), "and is still the default"
	)

	# The specimen shows the new font, its bold and the old one.
	var specimen: FontSpecimen = SPECIMEN.instantiate()
	add_child_autofree(specimen)
	var fonts: Dictionary[String, bool] = {}
	var labels: Array[Control] = []
	_controls(specimen, labels)
	_controls(specimen.ui.frame, labels)
	for control: Control in labels:
		if control is Label:
			var font: Font = (control as Label).get_theme_font(&"font")
			if font == UiText.font():
				fonts["ui"] = true
			elif font == UiText.font(true):
				fonts["bold"] = true
			elif font == PixelText.font():
				fonts["old"] = true
	assert_eq(
		fonts.size(), 3, "the specimen shows the new, the bold and the old: %s" % [fonts.keys()]
	)


## The first and last rows [param character] inks.
func _rows(character: String, bold: bool) -> Vector2i:
	var top: int = 99
	var bottom: int = -1
	for pixel: Vector2i in UiText.ink(character, bold):
		top = mini(top, pixel.y)
		bottom = maxi(bottom, pixel.y)
	return Vector2i(top, bottom)


# --- R4 ------------------------------------------------------------------------


func test_r4_a_theme() -> void:
	var main: Main = _main(ROOM_SMALL)
	var palette: PackedColorArray = Palette.all()
	var button := UiButton.new("Shop", "U")
	main.ui.frame.add_child(button)
	var plain := UiButton.new("Shop")
	main.ui.frame.add_child(plain)
	await _frames()
	# Four states, each drawn its own way.
	var looks: Dictionary[String, bool] = {}
	var states: Array[Array] = [
		[&"normal", &"font_color"],
		[&"hover", &"font_hover_color"],
		[&"pressed", &"font_pressed_color"],
		[&"disabled", &"font_disabled_color"],
	]
	main.ui.windows.open_window(UiRoot.ORDERS)
	var close: UiButton = main.ui.windows.window(UiRoot.ORDERS).close_button
	for padded: UiButton in [button, close]:
		for state: Array in states:
			var padded_state: StringName = state[0]
			var box: StyleBoxFlat = padded.get_theme_stylebox(padded_state) as StyleBoxFlat
			var what: String = "%s %s" % [padded.text, padded_state]
			assert_not_null(box, "%s: a flat box" % what)
			if box == null:
				continue
			# At least 4 UI pixels of padding inside the edge, round the text.
			assert_gte(box.content_margin_left - box.border_width_left, 4.0, "%s: left" % what)
			assert_gte(box.content_margin_right - box.border_width_right, 4.0, "%s: right" % what)
			assert_gte(box.content_margin_top - box.border_width_top, 4.0, "%s: top" % what)
			assert_gte(
				box.content_margin_bottom - box.border_width_bottom, 4.0, "%s: bottom" % what
			)
	for state: Array in states:
		var state_name: StringName = state[0]
		var colour_name: StringName = state[1]
		var box: StyleBoxFlat = button.get_theme_stylebox(state_name) as StyleBoxFlat
		assert_not_null(box, "%s: a flat box" % state[0])
		if box == null:
			continue
		var text: Color = button.get_theme_color(colour_name)
		looks["%s %s %s" % [box.bg_color, box.border_color, text]] = true
		for colour: Color in [box.bg_color, box.border_color, text]:
			assert_true(palette.has(colour), "%s: %s is a palette colour" % [state[0], colour])
		assert_false(box.anti_aliasing, "%s: hard edges" % state[0])
	assert_eq(looks.size(), 4, "four states drawn apart")
	# Measured: tall enough to hit, wide enough for the text, the key hint shown after it.
	for made: UiButton in [button, plain]:
		assert_gte(made.size.y, 20.0, "%s: a hit area at least 20 tall" % made.text)
		assert_gte(made.size.x, UiText.width(made.text, true) + 8.0, "%s: padded" % made.text)
	assert_eq(button.key_hint, "U", "the key hint")
	assert_eq(button.alignment, HORIZONTAL_ALIGNMENT_LEFT, "the text first")
	var hinted: float = (
		UiText.width("Shop", true)
		+ UiButton.HINT_GAP
		+ UiText.width("U")
		+ 2.0 * UiTheme.BUTTON_PAD_X
	)
	assert_gte(button.size.x, hinted, "room for the text, the gap and the key")
	assert_gt(button.size.x, plain.size.x, "wider than without the key")
	# The window's look: a dark panel, a one-pixel light edge, a slightly lighter title bar.
	main.ui.windows.open_window(UiRoot.ORDERS)
	await _frames()
	var window: UiWindow = main.ui.windows.window(UiRoot.ORDERS)
	var panel: StyleBoxFlat = window.get_theme_stylebox(&"panel") as StyleBoxFlat
	var bar: StyleBoxFlat = window.title_bar.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(panel.border_width_top, 1, "a one-pixel edge")
	assert_gt(
		panel.border_color.get_luminance(), panel.bg_color.get_luminance() + 0.2, "a light edge"
	)
	assert_lt(panel.bg_color.get_luminance(), 0.2, "on a dark panel")
	assert_gt(bar.bg_color.get_luminance(), panel.bg_color.get_luminance(), "a lighter title bar")
	assert_lt(bar.bg_color.get_luminance() - panel.bg_color.get_luminance(), 0.1, "slightly")
	for colour: Color in [panel.bg_color, panel.border_color, bar.bg_color]:
		assert_true(palette.has(colour), "%s is a palette colour" % colour)
	assert_gte(window.close_button.size.y, 20.0, "the close button can be hit")
	# Defined in one place: everything on the layer takes the one theme.
	assert_eq(main.ui.frame.theme, UiTheme.theme(), "the layer's theme")
	for control: Control in [window, window.title_bar, button, main.ui.bar]:
		assert_eq(control.theme, null, "%s takes it from the layer" % control.name)
	var tip: StyleBoxFlat = main.ui.bar.tip.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_true(palette.has(tip.bg_color), "the tooltip is themed too")
	var scroll: StyleBoxFlat = window.get_theme_stylebox(&"grabber", &"VScrollBar") as StyleBoxFlat
	assert_not_null(scroll, "and the scroll bars")


# --- R5 ------------------------------------------------------------------------


func test_r5_windows() -> void:
	var main: Main = _main(ROOM_SMALL)
	var ui: UiRoot = main.ui
	var windows: UiWindows = ui.windows
	var journal: UiWindow = windows.window(UiRoot.JOURNAL)
	var orders: UiWindow = windows.window(UiRoot.ORDERS)
	var help: UiWindow = windows.window(UiRoot.HELP)
	# Spec 059: this spec's three windows; the shop, map and tally (spec 059) open over them.
	for id: StringName in OWN_WINDOWS:
		windows.open_window(id)
	await _frames()
	assert_true(journal.is_open() and orders.is_open() and help.is_open(), "all open at once")
	assert_eq(journal.title_label.text, "Journal", "a title bar with its name")
	assert_not_null(journal.close_button, "and a close button")

	# Dragged by the title bar, by a real mouse.
	var start: Vector2 = journal.position
	_drag(ui, journal, Vector2(90, 30))
	assert_eq(journal.position, start + Vector2(90, 30), "the drag moved it")
	# A drag of the body does nothing.
	var body: Vector2 = journal.get_global_rect().get_center()
	mouse_move(ui.ui_to_world(body))
	mouse_button(ui.ui_to_world(body), true)
	mouse_move(ui.ui_to_world(body + Vector2(50, 50)), true)
	mouse_button(ui.ui_to_world(body + Vector2(50, 50)), false)
	assert_eq(journal.position, start + Vector2(90, 30), "only the title bar drags")

	# Overlapping, and a click anywhere on one brings it to the front.
	orders.place_at(journal.position + Vector2(40, 40), Vector2(ui.room()))
	windows.raise(journal)
	assert_eq(windows.front(), journal, "the journal in front")
	var corner: Vector2 = orders.get_global_rect().end - Vector2(6, 6)
	assert_false(journal.get_global_rect().has_point(corner), "a corner of the orders shows")
	_click_ui(ui, corner)
	assert_eq(windows.front(), orders, "a click on the orders brings them to the front")

	# A click on a window never reaches a window under it: the journal covers the orders' Bold.
	var bold: UiButton = (orders.content as OrdersPanel).choice_buttons[PartyOrders.PACE][2]
	await _frames()
	journal.place_at(bold.get_global_rect().position - Vector2(30, 30), Vector2(ui.room()))
	windows.raise(journal)
	assert_true(journal.get_global_rect().has_point(bold.get_global_rect().get_center()), "covered")
	var pace: Expedition.Pace = main.simulation.expedition.pace
	_click_ui(ui, bold.get_global_rect().get_center())
	main.simulation.step()
	assert_eq(main.simulation.expedition.pace, pace, "the hidden Bold was not pressed")

	# Nor the world or the old HUD: the target stage and the hero sheet are unchanged.
	var plus: Vector2 = Hud.on_screen(main.hud.place_panel.plus_button).get_center()
	var frame: Vector2 = Hud.on_screen(main.hud.frames[1]).get_center()
	var target: int = main.simulation.expedition.target_depth
	for under: Vector2 in [plus, frame]:
		journal.place_at(ui.world_to_ui(under) - Vector2(60, 60), Vector2(ui.room()))
		windows.raise(journal)
		assert_true(journal.get_global_rect().has_point(ui.world_to_ui(under)), "over %s" % under)
		click(under)
	main.simulation.step()
	assert_eq(main.simulation.expedition.target_depth, target, "the target is unchanged")
	assert_false(main.hud.hero_windows.is_open(), "no hero window opened")

	# Esc closes the front window only, and nothing of the old HUD with it.
	main.hud.shop.open()
	windows.raise(orders)
	press(KEY_ESCAPE)
	assert_false(orders.is_open(), "Esc closed the front window")
	assert_true(journal.is_open() and help.is_open(), "only that one")
	assert_true(main.hud.shop.is_open(), "and left the shop open")
	main.hud.shop.close()
	_click_ui(ui, journal.close_button.get_global_rect().get_center())
	assert_false(journal.is_open(), "the close button closes it")
	windows.open_window(UiRoot.JOURNAL)
	await _frames()

	# Never dragged so far that its title bar leaves the screen.
	var room: Vector2 = Vector2(ui.room())
	for away: Vector2 in [Vector2(-3000, 0), Vector2(3000, 0), Vector2(0, -3000), Vector2(0, 3000)]:
		_drag(ui, journal, away, 4)
		var bar: Rect2 = journal.title_bar.get_global_rect()
		assert_gte(bar.position.y, 0.0, "%s: the bar's top on screen" % away)
		assert_lte(bar.end.y, room.y, "%s: the bar's bottom on screen" % away)
		var shown: float = minf(bar.end.x, room.x) - maxf(bar.position.x, 0.0)
		assert_gte(shown, UiWindow.KEEP_SHOWN - 2.0, "%s: some of the bar on screen" % away)
		journal.place_at(Vector2(300, 200), room)
	# A window off screen after the window shrinks is moved back in.
	journal.place_at(Vector2(room.x - 60, room.y - 40), room)
	ui.set_room_for_test(Vector2i(640, 360))
	var bar_now: Rect2 = journal.title_bar.get_global_rect()
	assert_lte(bar_now.end.y, 360.0, "moved back in when the room shrank: %s" % bar_now)
	assert_gte(640.0 - bar_now.position.x, UiWindow.KEEP_SHOWN - 2.0, "and across")

	# The game keeps running behind them.
	var tick: int = main.simulation.tick
	main.driver.advance(1_000_000)
	assert_gt(main.simulation.tick, tick, "the game runs behind open windows")
	assert_false(get_tree().paused, "unpaused")


# --- R6 ------------------------------------------------------------------------


func test_r6_remembered() -> void:
	var first_settings := SoundSettings.new(_settings_path)
	first_settings.set_muted(true)
	var first: Main = _main(ROOM_SMALL, SoundSettings.new(_settings_path))
	var windows: UiWindows = first.ui.windows
	assert_true(windows.is_open(UiRoot.HELP), "a first game welcomes with help")
	windows.close_window(UiRoot.HELP)
	windows.open_window(UiRoot.JOURNAL)
	windows.open_window(UiRoot.ORDERS)
	await _frames()
	_drag(first.ui, windows.window(UiRoot.JOURNAL), Vector2(120, 40))
	var journal_at: Vector2 = windows.window(UiRoot.JOURNAL).position
	windows.close_window(UiRoot.ORDERS)
	windows.open_window(UiRoot.ORDERS)
	# Somewhere the headless window's own small room keeps too: the room is set after the windows
	# are put back.
	_drag(first.ui, windows.window(UiRoot.ORDERS), Vector2(200, -200))
	var orders_at: Vector2 = windows.window(UiRoot.ORDERS).position
	first.free()

	# Beside the sound setting, not in the save.
	var kept := SoundSettings.new(_settings_path)
	assert_true(kept.muted(), "the sound setting is kept beside them")
	var text: String = FileAccess.get_file_as_string(_settings_path)
	assert_string_contains(text, UiWindows.SETTINGS_KEY, "the windows are in the settings file")
	assert_false(Simulation.new(1).to_save().has(UiWindows.SETTINGS_KEY), "and not in the save")

	var second: Main = _main(ROOM_SMALL, SoundSettings.new(_settings_path))
	var again: UiWindows = second.ui.windows
	assert_eq(again.window(UiRoot.JOURNAL).position, journal_at, "the journal where it was left")
	assert_eq(again.window(UiRoot.ORDERS).position, orders_at, "and the orders")
	assert_true(again.is_open(UiRoot.JOURNAL), "open as it was")
	assert_true(again.is_open(UiRoot.ORDERS), "both")
	assert_false(again.is_open(UiRoot.HELP), "help closed as it was")

	# One control resets every window to its default place.
	_click_ui(second.ui, second.ui.bar.reset_button.get_global_rect().get_center())
	for id: StringName in again.ids():
		assert_eq(
			again.window(id).position, again.window(id).default_place, "%s back in place" % id
		)
	second.free()

	# A new game's default places do not overlap at 960x540, nor the button bar.
	var fresh: Main = _main(ROOM_SMALL)
	var rects: Dictionary[StringName, Rect2] = {}
	# Spec 059: this spec's three windows; spec 059 R8 checks its own three do not overlap.
	for id: StringName in OWN_WINDOWS:
		var made: UiWindow = fresh.ui.windows.window(id)
		assert_eq(made.position, made.default_place, "%s at its default place" % id)
		rects[id] = made.get_global_rect()
		var room := Rect2(Vector2.ZERO, Vector2(ROOM_SMALL))
		assert_true(room.encloses(rects[id]), "%s inside the room %s" % [id, rects[id]])
		var bar: Rect2 = fresh.ui.bar.get_global_rect()
		assert_false(rects[id].intersects(bar), "%s clear of the button bar" % id)
	for a: StringName in rects:
		for b: StringName in rects:
			if a < b:
				assert_false(rects[a].intersects(rects[b]), "%s and %s do not overlap" % [a, b])


# --- R7 ------------------------------------------------------------------------


func test_r7_a_button_bar() -> void:
	# Spec 068: at both rooms, since the bar has a form for each and shows the key in both.
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var main: Main = _main(room)
		var ui: UiRoot = main.ui
		var bar: UiButtonBar = ui.bar
		await _frames()
		assert_eq(bar.buttons.keys(), _bar_ids(ui.windows), "one button per window, in order")
		# At the bottom right, above the hero frames' line.
		var rect: Rect2 = bar.get_global_rect()
		var frames_top: float = main.hud.frames[0].get_global_rect().position.y
		assert_lte(rect.end.y, frames_top, "%s: above the frames' line" % room)
		assert_gt(rect.end.y, frames_top - 16.0, "%s: just above" % room)
		assert_lte(rect.end.x, float(ui.room().x), "%s: on screen" % room)
		assert_gt(rect.position.x, ui.room().x / 2.0, "%s: at the right" % room)
		for id: StringName in bar.buttons:
			var button: UiButton = bar.buttons[id]
			var window: UiWindow = ui.windows.window(id)
			var named: String = "%s: %s" % [room, id]
			assert_not_null(button.icon, "%s: a small icon" % named)
			assert_eq(button.icon.get_size(), Vector2(16, 16), "%s: 16x16" % named)
			var tip: String = bar.tip.text_for(button)
			assert_string_contains(tip, window.title, "%s: its name in the tooltip" % named)
			assert_string_contains(tip, "(%s)" % window.key_hint, "%s: and its key" % named)
			assert_eq(button.key_hint, window.key_hint, "%s: the key shown on the button" % named)
			assert_true(button.key_rect().has_area(), "%s: which has a place on it" % named)
			assert_true(
				Rect2(Vector2.ZERO, button.size).encloses(button.key_rect()),
				"%s: inside the button" % named
			)
			assert_gte(
				button.size.x, button.hinted_width(), "%s: room for the icon and the key" % named
			)
			assert_false(button.lit, "%s: dark while closed" % named)
			_click_ui(ui, button.get_global_rect().get_center())
			assert_true(window.is_open(), "%s: a click opens it" % named)
			bar.refresh()
			assert_true(button.lit, "%s: lit while open" % named)
			assert_true(button.button_pressed, "%s: drawn lit" % named)
			_click_ui(ui, button.get_global_rect().get_center())
			assert_false(window.is_open(), "%s: and closes it" % named)
			bar.refresh()
			assert_false(button.lit, "%s: dark again" % named)
		# The tooltip shows after a rest.
		var help_button: UiButton = bar.buttons[UiRoot.HELP]
		mouse_move(ui.ui_to_world(help_button.get_global_rect().get_center()))
		bar.tip.advance(UiTip.DELAY + 0.05)
		assert_eq(bar.tip.shown_text(), bar.tip.text_for(help_button), "the tooltip shows")
		assert_true(
			Rect2(Vector2.ZERO, Vector2(ui.room())).encloses(bar.tip.get_global_rect()), "on screen"
		)
		mouse_move(Vector2(-10, -10))
		main.free()


# --- R8 ------------------------------------------------------------------------


func test_r8_three_panels_become_windows() -> void:
	var main: Main = _main(ROOM_SMALL)
	var ui: UiRoot = main.ui
	var windows: UiWindows = ui.windows
	# Their keys toggle them, all three open together.
	for pair: Array in [[KEY_H, UiRoot.HELP], [KEY_J, UiRoot.JOURNAL], [KEY_O, UiRoot.ORDERS]]:
		var keycode: Key = pair[0]
		var id: StringName = pair[1]
		press(keycode)
		assert_true(windows.is_open(id), "%s opens with its key" % id)
	assert_eq(windows.front(), windows.window(UiRoot.ORDERS), "the last opened in front")
	for id: StringName in OWN_WINDOWS:
		assert_true(windows.is_open(id), "%s open beside the others" % id)
	await _frames()

	# Help: every key, in two columns.
	var help: HelpPanel = windows.window(UiRoot.HELP).content as HelpPanel
	for entry: Array in KeyBook.entries():
		assert_has(help.lines(), "%s  %s" % [entry[0], entry[1]], "help lists %s" % entry[0])
	var columns: Dictionary[float, bool] = {}
	var keys_shown: Array[String] = []
	var help_rect: Rect2 = windows.window(UiRoot.HELP).get_global_rect()
	var controls: Array[Control] = []
	_controls(help, controls)
	for control: Control in controls:
		var label: Label = control as Label
		if label == null or not label.is_visible_in_tree():
			continue
		assert_true(
			help_rect.encloses(label.get_global_rect()), "%s inside the window" % label.text
		)
		for entry: Array in KeyBook.entries():
			if label.text == str(entry[0]):
				columns[label.get_global_rect().position.x] = true
				keys_shown.append(label.text)
	assert_eq(keys_shown.size(), KeyBook.entries().size(), "every key shown")
	assert_eq(columns.size(), 2, "in two columns")
	# Each key's row on one line, at both rooms: what it does fits beside it without wrapping.
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		ui.set_room_for_test(room)
		await _frames()
		var grid: GridContainer = help.get_node(^"Keys") as GridContainer
		var rows: int = 0
		for cell: Node in grid.get_children():
			var key_label: Label = cell as Label
			if key_label == null or key_label.get_index() + 1 >= grid.get_child_count():
				continue
			var does: Label = grid.get_child(key_label.get_index() + 1) as Label
			if does == null or not KeyBook.keycodes(key_label.text).size() > 0:
				continue
			rows += 1
			assert_eq(does.get_line_count(), 1, "%s: '%s' on one line" % [room, does.text])
			assert_lte(
				float(UiText.width(does.text)), does.size.x, "%s: '%s' not cut" % [room, does.text]
			)
			assert_lte(does.size.y, key_label.size.y, "%s: '%s' one row tall" % [room, does.text])
		assert_eq(rows, KeyBook.entries().size(), "%s: every key's row" % room)

	# Orders: a full sentence for each choice, and both orders' commands sent by real clicks.
	var orders: OrdersPanel = windows.window(UiRoot.ORDERS).content as OrdersPanel
	for order: int in OrdersPanel.LINES.size():
		for value: int in (OrdersPanel.LINES[order] as Array).size():
			var sentence: String = OrdersPanel.LINES[order][value]
			assert_true(sentence.ends_with("."), "%s: a full sentence" % sentence)
			assert_gt(sentence.split(" ").size(), 6, "%s: says what it does" % sentence)
	windows.raise(windows.window(UiRoot.ORDERS))
	_click_ui(
		ui,
		(
			(orders.choice_buttons[PartyOrders.PACE][Expedition.Pace.BOLD] as Control)
			. get_global_rect()
			. get_center()
		)
	)
	_click_ui(
		ui,
		(
			(orders.choice_buttons[PartyOrders.GUARDIANS][Expedition.GuardianOrder.HOLD] as Control)
			. get_global_rect()
			. get_center()
		)
	)
	assert_eq(
		orders.line(PartyOrders.PACE), OrdersPanel.LINES[0][Expedition.Pace.BOLD], "lit at once"
	)
	main.simulation.step()
	assert_eq(main.simulation.expedition.pace, Expedition.Pace.BOLD, "Bold sent")
	assert_eq(main.simulation.expedition.guardian_order, Expedition.GuardianOrder.HOLD, "Hold sent")
	main.world.sync(0.016)  # the world passes the simulation's events on to the HUD
	main.hud.advance(0.016)
	orders.advance(0.0)
	assert_true(
		(orders.choice_buttons[PartyOrders.PACE][Expedition.Pace.BOLD] as UiButton).lit, "Bold lit"
	)
	assert_string_contains(main.hud.journal.lines()[0], "Ordered", "the journal heard it")

	# The journal: its lines against the simulation's, 20 in view, the wheel reaching the 50th.
	var view: JournalView = windows.window(UiRoot.JOURNAL).content as JournalView
	view.refresh()
	assert_eq(view.shown_lines(), main.hud.journal.lines(), "the journal's own lines")
	for i: int in 60:
		main.hud.journal.write("Line number %d" % i)
	view.refresh()
	await _frames()
	assert_eq(view.shown_lines(), main.hud.journal.lines(), "all of them")
	assert_eq(view.shown_lines().size(), Journal.CAPACITY, "50 kept")
	var shown: Rect2 = view.get_global_rect()
	var in_view: int = 0
	for i: int in Journal.CAPACITY:
		if shown.encloses(view.row(i).get_global_rect()):
			in_view += 1
	assert_gte(in_view, 20, "at least 20 entries in view")
	assert_false(shown.encloses(view.row(Journal.CAPACITY - 1).get_global_rect()), "not the 50th")
	windows.raise(windows.window(UiRoot.JOURNAL))
	var wheel_at: Vector2 = ui.ui_to_world(shown.get_center())
	mouse_move(wheel_at)
	for i: int in 60:
		mouse_button(wheel_at, true, MOUSE_BUTTON_WHEEL_DOWN)
		mouse_button(wheel_at, false, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames()
	assert_true(
		shown.encloses(view.row(Journal.CAPACITY - 1).get_global_rect()),
		"the wheel reaches the 50th"
	)
	var oldest: Label = view.row(Journal.CAPACITY - 1).get_child(1) as Label
	assert_eq(oldest.text, "Line number 10", "the oldest kept")


# --- R9 ------------------------------------------------------------------------


func test_r9_screenshots_show_what_the_player_sees() -> void:
	# The shot itself is tested in tools/tests/test_058_shot.py; here, that the tool draws the
	# layers as the window does: a viewport of the window's size stretching the world's pixels.
	var script: String = FileAccess.get_file_as_string("res://tools/godot/shot.gd")
	assert_string_contains(script, "size_2d_override = UiRoot.WORLD_SIZE", "the world's pixels")
	assert_string_contains(script, "size_2d_override_stretch = true", "stretched over the window")
	assert_string_contains(script, "--window=", "at the window's size")
	# The shot's path to the layers (a viewport of the window's size) and the game's (the window
	# itself) agree: the same UI room, scales and on-screen transform for the UI layer, and the
	# world scaled the same.
	var shot_script: GDScript = load("res://tools/godot/shot.gd") as GDScript
	var root: Window = get_tree().root
	var was: Vector2i = root.size
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var frame: SubViewport = shot_script.call(&"frame_for", window) as SubViewport
		add_child_autofree(frame)
		var shot: Main = make_main()
		frame.add_child(shot)
		root.size = window
		var game: Main = make_main()
		add_child_autofree(game)
		await _frames()
		assert_eq(shot.ui.room(), game.ui.room(), "%s: the same room" % window)
		assert_eq(shot.ui.ui_scale(), game.ui.ui_scale(), "%s: the same UI scale" % window)
		assert_eq(shot.ui.world_scale(), game.ui.world_scale(), "%s: the same world scale" % window)
		assert_eq(
			_on_screen(shot.ui), _on_screen(game.ui), "%s: the UI layer drawn the same" % window
		)
		assert_eq(
			_world_on_screen(shot), _world_on_screen(game), "%s: the world drawn the same" % window
		)
		assert_eq(_world_on_screen(game), float(game.ui.world_scale()), "%s: at its scale" % window)
		game.free()
	root.size = was


## [param layer]'s transform on screen: its own, then its viewport's stretch.
func _on_screen(layer: CanvasLayer) -> Transform2D:
	return layer.get_viewport().get_final_transform() * layer.get_final_transform()


## How many screen pixels one of [param main]'s world pixels is.
func _world_on_screen(main: Main) -> float:
	var view: SubViewportContainer = main.world_view
	var shown: Transform2D = view.get_viewport().get_final_transform() * view.get_global_transform()
	return shown.get_scale().x * view.size.x / float(UiRoot.WORLD_SIZE.x)


# --- R10 -----------------------------------------------------------------------


## The lines [param view] shows that came from the simulation's events: not the goals tracker's
## "Goal: …" lines, which it writes when it sees a goal finish on a frame (spec 037), so a goal
## begun and finished inside one crowded frame is never seen. Those are not the journal's events.
func _event_lines(view: JournalView) -> Array[String]:
	var lines: Array[String] = []
	for line: String in view.shown_lines():
		if not line.get_slice("  ", 1).begins_with("Goal: "):
			lines.append(line)
	return lines


func test_r10_true_in_a_crowded_frame() -> void:
	# The same game, one tick a frame and 300 ticks in one frame: the same journal lines.
	var calm: Main = _main(ROOM_SMALL)
	var crowded: Main = _main(ROOM_SMALL)
	var calm_view: JournalView = calm.ui.windows.window(UiRoot.JOURNAL).content as JournalView
	var crowded_view: JournalView = crowded.ui.windows.window(UiRoot.JOURNAL).content as JournalView
	var ticks: int = 3000
	for i: int in ticks:
		calm.simulation.step()
		calm.world.sync(0.016)
		calm.hud.advance(0.016)
		calm_view.refresh()
	for i: int in ticks / 300:
		for j: int in 300:
			crowded.simulation.step()
		crowded.world.sync(0.016)
		crowded.hud.advance(0.016)
		crowded_view.refresh()
	assert_gt(_event_lines(calm_view).size(), 3, "things happened: %s" % [calm_view.shown_lines()])
	assert_eq(
		_event_lines(crowded_view), _event_lines(calm_view), "the same lines, in the same order"
	)
	assert_eq(crowded_view.shown_lines(), crowded.hud.journal.lines(), "as the journal wrote them")
	assert_eq(calm_view.shown_lines(), calm.hud.journal.lines(), "both")
	crowded.free()

	# A drag while the game runs at 4x drops no input.
	calm.set_speed(4)
	calm.driver.step_budget_usec = 50_000
	var journal: UiWindow = calm.ui.windows.window(UiRoot.JOURNAL)
	calm.ui.windows.open_window(UiRoot.JOURNAL)
	await _frames()
	var start: Vector2 = journal.position
	var frame: Callable = func() -> void:
		calm.driver.advance(16_667)
		calm.world.sync(0.016)
		calm.hud.advance(0.016)
	var tick: int = calm.simulation.tick
	_drag(calm.ui, journal, Vector2(150, 90), 30, frame)
	assert_gte(calm.simulation.tick, tick + 18, "the game ran at 4x meanwhile")
	assert_eq(journal.position, start + Vector2(150, 90), "the drag ends where the mouse did")


# --- R11 -----------------------------------------------------------------------


func test_r11_in_the_help_list_and_the_wiki() -> void:
	# Spec 030's R3, as amended: every key the game's code names is in KeyBook.entries().
	var listed: Dictionary[int, bool] = {}
	for entry: Array in KeyBook.entries():
		for code: int in KeyBook.keycodes(str(entry[0])):
			listed[code] = true
	var handled: Dictionary[String, String] = {}
	_key_names_in("res://game", handled)
	for key_name: String in handled:
		var code: int = OS.find_keycode_from_string(key_name.trim_prefix("KEY_").replace("_", " "))
		assert_true(
			listed.has(code), "%s (in %s) is in the help list" % [key_name, handled[key_name]]
		)
	for key: Key in [KEY_H, KEY_J, KEY_O, KEY_ESCAPE]:
		assert_true(listed.has(key), "%s is listed" % OS.get_keycode_string(key))
	# The wiki says how windows work and that the overhaul is under way.
	var wiki: String = FileAccess.get_file_as_string(WIKI).to_lower()
	for words: String in ["window", "title bar", "esc", "button bar", "overhaul"]:
		assert_true(wiki.contains(words), "the wiki says: %s" % words)


## The windows of spec 058 and their like, each with a button on the bar: every window but the
## hero windows of spec 060, which open from their frames and cascade at 960x540 by design.
func _bar_ids(windows: UiWindows) -> Array[StringName]:
	var made: Array[StringName] = []
	for id: StringName in windows.ids():
		if windows.window(id).on_bar:
			made.append(id)
	return made

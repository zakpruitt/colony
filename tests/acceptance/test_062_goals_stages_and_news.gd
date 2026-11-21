extends "res://tests/acceptance/frame_062_test_base.gd"
## Spec 062: the goals, the stage list, the ticker, the note after a defeat, the report after time
## away and the catching-up bar on the sharp layer, and the old HUD layer gone. Driven by real
## clicks, keys and wheel events pushed into the viewport, at both rooms.

## The widest line the ticker shows in a real game: a defeat deep in The Old Crypt.
const WIDEST_TICKER: String = (
	"Beaten on The Old Crypt 118 by 2 crystal beetles, 2 deep horrors and a bone lord;"
	+ " falling back to The Old Crypt 117"
)
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const SPECIMEN: PackedScene = preload("res://game/ui/font_specimen.tscn")
const GALLERY: PackedScene = preload("res://game/art/gallery.tscn")

# --- R1 ------------------------------------------------------------------------


func test_r1_goals() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = "%s" % room
		_gold_situation(main)
		var view: GoalsView = hud.goals_view
		assert_true(main.ui.is_ancestor_of(view), "%s: the goals are on the sharp layer" % what)
		assert_true(view.is_visible_in_tree(), "%s: and shown" % what)
		var place: Rect2 = hud.place_panel.get_global_rect()
		var rect: Rect2 = view.get_global_rect()
		assert_gte(rect.position.y, place.end.y, "%s: under the place panel" % what)
		assert_lt(rect.position.y, place.end.y + 12.0, "%s: just under it" % what)
		assert_almost_eq(rect.position.x, place.position.x, 2.0, "%s: on its left" % what)
		var lines: Array[String] = hud.goals.lines()
		assert_eq(
			lines,
			["Reach Mossy Hollow 2", "Train a hero", "Buy an upgrade"] as Array[String],
			"%s: the gold situation" % what
		)
		for i: int in lines.size():
			var row: GoalRow = view.rows[i]
			assert_true(row is Button, "%s: %s is a button" % [what, lines[i]])
			assert_true(row.is_visible_in_tree(), "%s: %s shows" % [what, lines[i]])
			assert_eq(row.sentence_label.text, lines[i], "%s: its text" % what)
			assert_eq(_font_of(row.sentence_label), UiText.font(), "%s: in the new font" % what)
			var gold: bool = i > 0
			assert_eq(row.arrow_rect().has_area(), gold, "%s: %s's >" % [what, lines[i]])
			assert_eq(row.bar_rect().has_area(), not gold, "%s: %s's bar" % [what, lines[i]])
			if gold:
				assert_false(row.detail_label.text.is_empty(), "%s: %s's price" % [what, lines[i]])
		await _frames()
		var drawn_bar: Array = view.rows[0].drawn.get(&"bar", [])
		assert_eq(drawn_bar, [view.rows[0].bar_rect()], "%s: the bar is drawn" % what)
		var no_tick: Array = view.rows[0].drawn.get(&"tick", [])
		assert_eq(no_tick, [], "%s: no tick before it is done" % what)
		for i: int in range(lines.size(), view.rows.size()):
			assert_false(view.rows[i].visible, "%s: no fourth goal" % what)
		# A click opens the window where it is done.
		_click(main, view.rows[2])
		assert_true(hud.shop.is_open(), "%s: Buy an upgrade opens the shop" % what)
		hud.shop.close()
		hud.advance(STEP)
		_click(main, view.rows[1])
		var trainee: int = -1
		for hero: Hero in main.simulation.party.heroes:
			if trainee < 0 and hero.paragon_points() > 0:
				trainee = hero.id
		assert_true(hud.hero_windows.is_open(trainee), "%s: Train opens the hero's window" % what)
		hud.hero_windows.close_all()
		hud.advance(STEP)
		_click(main, view.rows[0])
		assert_true(hud.ladder.is_flashing(2), "%s: Reach flashes its stage" % what)
		# The tooltip: how to get there, then what a click does.
		assert_eq(_rest_on(main, view.rows[2]), view.tip(2), "%s: its tip" % what)
		assert_string_contains(view.tip(2), "Click to open the Camp.")
		# A click on the goals goes no further.
		var heard: Array[Vector2] = []
		_probe(main, heard)
		_click_ui(main.ui, view.title_label.get_global_rect().get_center())
		_click_ui(main.ui, rect.end - Vector2(2, 2))
		assert_eq(heard, [] as Array[Vector2], "%s: a click on the goals goes no further" % what)
		# G hides and shows them.
		_press(main, KEY_G)
		assert_false(view.is_visible_in_tree(), "%s: G hides the goals" % what)
		_press(main, KEY_G)
		assert_true(view.is_visible_in_tree(), "%s: G shows them again" % what)
		# A goal done flashes, then shows its tick in green.
		var e: Expedition = main.simulation.expedition
		e.depth = 2
		e.deepest_depth = 2
		hud.advance(STEP)
		var done: GoalRow = view.rows[0]
		assert_eq(done.sentence_label.text, "Reach Mossy Hollow 2", "%s: it stays" % what)
		assert_true(hud.goals.is_finished(0), "%s: finished" % what)
		assert_gt(hud.goals.flash(0), 0.0, "%s: flashing" % what)
		assert_true(done.disabled, "%s: no longer a click" % what)
		hud.advance(Goals.FLASH_SECONDS)
		assert_eq(
			done.sentence_label.get_theme_color(&"font_color"),
			Palette.color(&"green"),
			"%s: then green, with its tick" % what
		)
		await _frames()
		var tick: Array = done.drawn.get(&"tick", [])
		assert_eq(tick.size(), 1, "%s: the tick is drawn" % what)
		if tick.size() == 1:
			var tick_box: Rect2 = tick[0]
			assert_true(Rect2(Vector2.ZERO, done.size).encloses(tick_box), "%s: on its row" % what)
		main.free()


# --- R2 ------------------------------------------------------------------------


func test_r2_stage_list() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var e: Expedition = sim.expedition
		var what: String = "%s" % room
		_situation(main, 1, 12, 1)  # been deep, so the list scrolls (spec 047)
		var list: StageList = hud.ladder
		await _frames()
		_assert_drawn(list, &"party_frame", 1, "%s: the party's frame" % what)
		_assert_drawn(list, &"target_frame", 1, "%s: the target's frame" % what)
		_assert_drawn(list, &"arrow", 1, "%s: the target's arrow" % what)
		assert_true(main.ui.is_ancestor_of(list), "%s: the list is on the sharp layer" % what)
		assert_true(list.is_visible_in_tree(), "%s: and shown" % what)
		var rect: Rect2 = list.get_global_rect()
		assert_almost_eq(
			rect.end.x, room.x - HudFrame.FRAME_EDGE, 1.0, "%s: at the right edge" % what
		)
		var caption: Label = list.find_child("Caption", true, false)
		assert_eq(caption.text, PlaceText.area_name(e.place), "%s: headed by the area" % what)
		assert_eq(_font_of(caption), UiText.font(true), "%s: in the new font" % what)
		# The guardian's name beside its stage, struck through once beaten.
		var guardian: String = list.ladder.guardian_name(GUARDIAN_DEPTH)
		var named: Label = _guardian_label(list, guardian)
		assert_not_null(named, "%s: the guardian is named" % what)
		if named == null:
			main.free()
			continue
		var rung: Rect2 = list.get_global_transform() * list.rung_rect(GUARDIAN_DEPTH)
		var name_y: float = named.get_global_rect().get_center().y
		assert_between(name_y, rung.position.y, rung.end.y, "%s: on its stage's row" % what)
		assert_true(list.get_global_rect().encloses(_ink(named)), "%s: the name not cut" % what)
		assert_false(list.marks(GUARDIAN_DEPTH).has(&"guardian_beaten"), "%s: not beaten" % what)
		# Each number coloured by its risk.
		var seen: Dictionary[DepthLadder.Risk, int] = {}
		for i: int in StageList.RUNGS:
			var number: Label = list.find_child("Number%d" % i, true, false)
			var depth: int = int(number.text)
			var colour: StringName = DepthLadder.RISK_COLOURS[list.risk(depth)]
			assert_eq(
				number.get_theme_color(&"font_color"),
				Palette.color(colour),
				"%s: stage %d's colour" % [what, depth]
			)
			if not seen.has(list.risk(depth)):
				seen[list.risk(depth)] = depth
		assert_true(seen.has(DepthLadder.Risk.SAFE), "%s: a safe stage on show" % what)
		assert_true(seen.has(DepthLadder.Risk.DANGEROUS), "%s: a dangerous one" % what)
		# The tooltip says so, as spec 043 rules: nothing for a safe stage.
		var dangerous: int = seen[DepthLadder.Risk.DANGEROUS]
		var on_screen: Rect2 = list.get_global_rect()
		_rest_at(main, _row_at(list, dangerous), StageList.DELAY + 0.05)
		assert_string_contains(list.hint_text(), "Dangerous", "%s: the dangerous tip" % what)
		_rest_at(main, _row_at(list, seen[DepthLadder.Risk.SAFE]), StageList.DELAY + 0.05)
		assert_false(list.hint_text().is_empty(), "%s: a safe stage's line" % what)
		assert_false(list.hint_text().contains("\n"), "%s: with no risk line" % what)
		# No line through a window lying over the list.
		var dangerous_at: Vector2 = _row_at(list, dangerous)
		main.ui.windows.open_window(UiRoot.HELP)
		var over: UiWindow = main.ui.windows.window(UiRoot.HELP)
		await _frames()
		over.position = dangerous_at - Vector2(over.size.x - 20.0, 40.0)
		main.ui.windows.raise(over)
		assert_true(over.get_global_rect().has_point(dangerous_at), "%s: a window there" % what)
		_rest_at(main, dangerous_at, StageList.DELAY + 0.05)
		assert_eq(list.hint_text(), "", "%s: no line through the window" % what)
		main.ui.windows.close_window(UiRoot.HELP)
		_rest_at(main, dangerous_at, StageList.DELAY + 0.05)
		assert_ne(list.hint_text(), "", "%s: the line again with the window gone" % what)
		# A click sets the target.
		_click_ui(main.ui, _row_at(list, 3))
		hud.advance(STEP)
		sim.step()
		assert_eq(e.target_depth, 3, "%s: a click on stage 3 targets it" % what)
		assert_true(list.marks(3).has(&"target"), "%s: shown as the target" % what)
		hud.advance(STEP)
		await _frames()
		_assert_drawn(list, &"target_frame", 3, "%s: the target's frame moves" % what)
		_assert_drawn(list, &"arrow", 3, "%s: and its arrow" % what)
		_assert_drawn(list, &"party_frame", 1, "%s: the party's stays" % what)
		# The wheel scrolls; the arrow returns to the party.
		var middle: Vector2 = main.ui.ui_to_world(_row_at(list, 4))
		mouse_move(middle)
		for i: int in 3:
			mouse_button(middle, true, MOUSE_BUTTON_WHEEL_DOWN)
			mouse_button(middle, false, MOUSE_BUTTON_WHEEL_DOWN)
		hud.advance(STEP)
		assert_false(list.is_following(), "%s: the wheel scrolls away" % what)
		assert_eq(list.first_depth(), 4, "%s: three rows down" % what)
		var arrow: Rect2 = list.arrow_rect()
		assert_true(arrow.has_area(), "%s: an arrow back" % what)
		_click_ui(main.ui, on_screen.position + arrow.get_center())
		hud.advance(STEP)
		assert_true(list.is_following(), "%s: the arrow returns to the party" % what)
		# A guardian beaten: its name struck through.
		mouse_move(NOWHERE_WORLD)
		assert_true(_guardian_fight(main), "%s: a guardian fight" % what)
		assert_true(
			_until(main, func() -> bool: return list.ladder.guardian_beaten(GUARDIAN_DEPTH)),
			"%s: the guardian is beaten" % what
		)
		hud.advance(STEP)
		named = _guardian_label(list, guardian)
		assert_not_null(named, "%s: still named" % what)
		if named != null:
			assert_eq(named.get_theme_color(&"font_color"), Palette.color(&"steel"), "dimmed")
		assert_true(list.marks(GUARDIAN_DEPTH).has(&"guardian_beaten"), "%s: struck" % what)
		await _frames()
		var strikes: Array = list.drawn.get(&"strike", [])
		var name_box: Rect2 = list.mark_rect(GUARDIAN_DEPTH, &"name")
		var struck: bool = false
		for line: Rect2 in strikes:
			struck = (
				struck
				or (
					line.size.x >= name_box.size.x
					and line.position.y > name_box.position.y
					and line.end.y < name_box.end.y
				)
			)
		assert_true(struck, "%s: a line through the name %s %s" % [what, name_box, strikes])
		# L hides and shows it.
		_press(main, KEY_L)
		assert_false(list.is_visible_in_tree(), "%s: L hides the list" % what)
		_press(main, KEY_L)
		assert_true(list.is_visible_in_tree(), "%s: L shows it again" % what)
		main.free()


## Asserts [param list] drew a [param kind] on the row of [param depth] when last drawn.
func _assert_drawn(list: StageList, kind: StringName, depth: int, what: String) -> void:
	var row: Rect2 = list.rung_rect(depth)
	var found: bool = false
	for rect: Rect2 in list.drawn.get(kind, []):
		found = found or row.encloses(rect)  # the arrow is noted a column at a time
	assert_true(found, "%s: %s on row %s: %s" % [what, kind, row, list.drawn.get(kind, [])])


## The middle of the row of [param depth] on [param list], in UI pixels.
func _row_at(list: StageList, depth: int) -> Vector2:
	return list.get_global_rect().position + list.rung_rect(depth).get_center()


# --- R3 ------------------------------------------------------------------------


func test_r3_ticker() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = "%s" % room
		var sentence: String = "Mira learned Lockpicking at Mossy Hollow 12, far below"
		hud.journal.announce(sentence)
		hud.advance(STEP)
		var ticker: Ticker = hud.ticker
		assert_true(main.ui.is_ancestor_of(ticker), "%s: the ticker is on the sharp layer" % what)
		assert_true(ticker.is_visible_in_tree(), "%s: it shows the newest line" % what)
		assert_eq(ticker.label.text, sentence, "%s: that line" % what)
		assert_eq(_font_of(ticker.label), UiText.font(), "%s: in the new font" % what)
		var rect: Rect2 = ticker.get_global_rect()
		var frames: float = hud.frames[0].get_global_rect().position.y
		assert_lte(rect.end.y, frames, "%s: above the hero frames" % what)
		assert_gt(rect.end.y, frames - 12.0, "%s: just above" % what)
		assert_true(rect.encloses(_ink(ticker.label)), "%s: the line not cut" % what)
		# Never over a window's title bar at the default places.
		main.ui.windows.reset_places()
		for id: StringName in main.ui.windows.ids():
			var window: UiWindow = main.ui.windows.window(id)
			var bar := Rect2(window.default_place, Vector2(window.size.x, window.title_bar.size.y))
			assert_false(bar.intersects(rect), "%s: clear of %s's title bar" % [what, id])
		for hero: Hero in main.simulation.party.heroes:
			hud.hero_windows.open(hero.id)
		for hero: Hero in main.simulation.party.heroes:
			var window: HeroWindow = hud.hero_windows.window_of(hero.id)
			assert_false(
				window.title_bar.get_global_rect().intersects(rect),
				"%s: clear of hero %d's title bar" % [what, hero.id]
			)
		hud.hero_windows.close_all()
		# For 4 seconds, then it fades and goes.
		hud.advance(Journal.TICKER_SECONDS - 0.1)
		assert_eq(ticker.label.text, sentence, "%s: still there before 4 s" % what)
		assert_eq(ticker.label.get_theme_color(&"font_color"), Palette.color(&"white"))
		hud.advance(0.2)
		assert_ne(
			ticker.label.get_theme_color(&"font_color"), Palette.color(&"white"), "then it fades"
		)
		hud.advance(Journal.FADE_STEP * Journal.FADE_COLOURS.size())
		assert_false(ticker.is_visible_in_tree(), "%s: and goes" % what)
		# A click on it opens the Journal, and goes no further.
		hud.journal.announce(sentence)
		hud.advance(STEP)
		var heard: Array[Vector2] = []
		_probe(main, heard)
		_click(main, ticker)
		assert_true(main.ui.windows.is_open(UiRoot.JOURNAL), "%s: a click opens the Journal" % what)
		assert_eq(heard, [] as Array[Vector2], "%s: and goes no further" % what)
		main.free()


# --- R4 ------------------------------------------------------------------------


func test_r4_defeat_note_over_every_window() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = "%s" % room
		assert_true(_guardian_wipe(main), "%s: beaten by the guardian" % what)
		hud.advance(STEP)
		var note: DefeatNote = hud.defeat_note
		var panel: DefeatNoteView = note.panel
		assert_true(note.is_shown(), "%s: the note shows" % what)
		assert_true(main.ui.is_ancestor_of(panel), "%s: on the sharp layer" % what)
		assert_true(panel.is_visible_in_tree(), "%s: drawn" % what)
		var guardian: String = (
			Content.monster(main.simulation.expedition.guardian_of(GUARDIAN_DEPTH)).display_name
		)
		var first: Label = panel.labels[0]
		assert_string_contains(first.text, guardian, "%s: what beat the party" % what)
		assert_string_contains(first.text, "Mossy Hollow %d" % GUARDIAN_DEPTH, "and where")
		assert_eq(_font_of(first), UiText.font(true), "%s: in the new font" % what)
		_assert_not_cut(panel, "%s note" % what)
		var texts: Array[String] = note.suggestions()
		assert_true(texts.has("Buy an upgrade"), "%s: a fortune suggests the shop" % what)
		var shown: int = 0
		for button: UiButton in panel.buttons:
			if button.is_visible_in_tree():
				shown += 1
		assert_eq(shown, texts.size(), "%s: a button per suggestion" % what)
		assert_lte(shown, DefeatNote.MOST, "%s: up to three" % what)
		# Every window open, one dragged over the note: the note is drawn over them all.
		for id: StringName in main.ui.windows.ids():
			main.ui.windows.open_window(id)
		var shop: UiWindow = main.ui.windows.window(ShopWindow.ID)
		shop.position = panel.get_global_rect().position - Vector2(10, 10)
		main.ui.windows.raise(shop)
		hud.advance(STEP)
		assert_true(note.is_shown(), "%s: the windows hide nothing" % what)
		assert_true(shop.get_global_rect().intersects(panel.get_global_rect()), "under it")
		assert_eq(_drawn_over(main.ui, panel), [] as Array[String], "%s: over every one" % what)
		# A click on a button does what it said, through every window.
		for id: StringName in main.ui.windows.ids():
			main.ui.windows.close_window(id)
		main.ui.windows.open_window(UiRoot.HELP)
		var help: UiWindow = main.ui.windows.window(UiRoot.HELP)
		var upgrade: UiButton = panel.buttons[texts.find("Buy an upgrade")]
		help.position = upgrade.get_global_rect().position - Vector2(20, 30)
		assert_true(help.get_global_rect().encloses(upgrade.get_global_rect()), "a window under")
		var said: String = _rest_on(main, upgrade)
		assert_ne(said, "", "%s: the button's tip shows over the window" % what)
		# The stage list's line may lie over windows, as a tip does, but never over the note.
		assert_true(_is_over(main.ui, panel, hud.ladder.hint), "%s: the note over its line" % what)
		_click(main, upgrade)
		assert_true(hud.shop.is_open(), "%s: the button opens the shop" % what)
		assert_true(note.is_shown(), "%s: and the note stays" % what)
		# A click on the note goes no further.
		var heard: Array[Vector2] = []
		_probe(main, heard)
		for id: StringName in main.ui.windows.ids():
			main.ui.windows.close_window(id)
		_click_ui(main.ui, first.get_global_rect().get_center())
		assert_eq(heard, [] as Array[Vector2], "%s: a click on the note goes no further" % what)
		main.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_away_report_window() -> void:
	_away_files(ROOM_SMALL)
	for room: Vector2i in ROOMS:
		var what: String = "%s" % room
		var main: Main = _main_after_away(600.0, SoundSettings.new(_away_settings))
		await wait_until(func() -> bool: return not main.is_catching_up(), 60.0, "replay ends")
		main.hud.set_process(false)
		main.hud_layer.layer = 129
		main.ui.layer = 130
		main.ui.set_room_for_test(room)
		var report: AwayWindow = main.away_window
		assert_not_null(report, "%s: the report opens by itself" % what)
		if report == null:
			main.free()
			continue
		assert_true(report is UiWindow, "%s: as a window" % what)
		assert_true(report.is_open(), "%s: open" % what)
		assert_eq(main.ui.windows.front(), report, "%s: above the others" % what)
		var centre: Vector2 = report.get_global_rect().get_center()
		assert_almost_eq(centre.x, room.x / 2.0, 1.0, "%s: in the middle across" % what)
		assert_almost_eq(centre.y, room.y / 2.0, 1.0, "%s: and down" % what)
		assert_true(
			Rect2(Vector2.ZERO, Vector2(room)).encloses(report.get_global_rect()), "in the room"
		)
		# Dragged, it keeps its place when the room changes and back; it is not centred again.
		await _frames()
		_drag(main.ui, report, Vector2(-60, -40))
		await _frames()
		var dragged: Vector2 = report.position
		assert_ne(report.get_global_rect().get_center(), centre, "%s: dragged" % what)
		for other: Vector2i in [ROOM_SMALL, ROOM_LARGE, room]:
			main.ui.set_room_for_test(other)
			var inside := Rect2(Vector2.ZERO, Vector2(main.ui.room()))
			assert_true(inside.encloses(report.get_global_rect()), "%s: on screen" % other)
		assert_eq(report.position, dragged, "%s: where the player put it" % what)
		var journal: UiWindow = main.ui.windows.window(UiRoot.JOURNAL)
		assert_true(journal.is_open(), "%s: the window left open opens" % what)
		var order: Array[UiWindow] = main.ui.windows.order()
		assert_lt(order.find(journal), order.find(report), "%s: under the report" % what)
		# The story as a short list, the numbers right-aligned.
		assert_string_contains(report.text(), "Away 10m", "%s: how long" % what)
		assert_string_contains(report.text(), "Gold +", "%s: the gold" % what)
		var right: float = -1.0
		for value: Label in report.values:
			if value.text.is_empty():
				continue
			assert_eq(value.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "right-aligned")
			assert_eq(_font_of(value), UiText.font(true), "%s: in the new font" % what)
			var label_end: float = value.get_global_rect().end.x
			assert_gte(
				value.size.x, value.get_minimum_size().x, "%s: '%s' whole" % [what, value.text]
			)
			if right < 0.0:
				right = label_end
			assert_almost_eq(label_end, right, 0.5, "%s: one column" % what)
		_assert_not_cut(report, "%s report" % what)
		# Not by itself while the mouse is on it.
		mouse_move(main.ui.ui_to_world(report.get_global_rect().get_center()))
		report.advance(AwayWindow.SHOW_SECONDS + 1.0)
		assert_true(report.is_open(), "%s: it stays while the mouse is on it" % what)
		# Nor by a click elsewhere or a key other than Esc.
		click(main.ui.ui_to_world(Vector2(room.x * 0.3, room.y * 0.78)))  # the world
		press(KEY_SPACE)
		await _frames()
		assert_true(report.is_open(), "%s: a stray click or key leaves it" % what)
		# Esc closes it.
		press(KEY_ESCAPE)
		await _frames()
		assert_false(is_instance_valid(report) and report.is_open(), "%s: Esc closes it" % what)
		assert_true(journal.is_open(), "%s: the journal stays" % what)
		# Its button closes another.
		var again: AwayWindow = main.ui.show_away(main.away_report, main.simulation.party)
		_click(main, again.close_button_bottom)
		await _frames()
		assert_false(
			is_instance_valid(again) and again.is_open(), "%s: its button closes it" % what
		)
		# And with the mouse off it, it goes by itself.
		var timed: AwayWindow = main.ui.show_away(main.away_report, main.simulation.party)
		mouse_move(NOWHERE_WORLD)
		timed.advance(AwayWindow.SHOW_SECONDS - 0.5)
		assert_true(timed.is_open(), "%s: up before 12 s" % what)
		timed.advance(1.0)
		assert_false(timed.is_open(), "%s: gone after" % what)
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_catching_up_bar() -> void:
	_away_files(ROOM_SMALL)
	var main: Main = _main_after_away(3600.0, null)
	assert_true(main.is_catching_up(), "a replay")
	var bar: CatchUpBar = main.catch_up_bar
	assert_not_null(bar, "the catching-up bar shows")
	assert_true(main.ui.is_ancestor_of(bar), "on the sharp layer")
	assert_true(bar.is_visible_in_tree(), "drawn")
	var labels: Array[Label] = _shown_labels(bar)
	assert_eq(labels.size(), 1, "its text")
	if labels.size() == 1:
		assert_eq(labels[0].text, "Catching up...")
		assert_eq(_font_of(labels[0]), UiText.font(true), "in the new font")
	for child: Node in main.hud_layer.get_children():
		var item: CanvasItem = child as CanvasItem
		assert_true(item == null or not item.visible, "nothing on the old layer: %s" % child.name)
	await wait_until(func() -> bool: return not main.is_catching_up(), 60.0, "replay ends")
	assert_false(is_instance_valid(bar), "then it goes")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_old_layer_is_gone() -> void:
	var main: Main = _main(ROOM_SMALL)
	var hud: Hud = main.hud
	assert_true(_guardian_wipe(main), "a defeat")
	hud.journal.announce("Something happened.")
	hud.advance(STEP)
	# Nothing drawn on the old layer but the world's own: the dark of a crossing.
	var drawn: Array[Control] = []
	_controls(main.hud_layer, drawn)
	for control: Control in drawn:
		if not control.is_visible_in_tree() or control == hud:
			continue
		var worlds: bool = hud.veil == control or hud.veil.is_ancestor_of(control)
		assert_true(worlds, "%s is drawn on the old layer" % control.get_path())
	# Every text on the sharp layer is in the new font.
	for label: Label in _shown_labels(main.ui):
		var font: Font = _font_of(label)
		assert_true(
			font == UiText.font() or font == UiText.font(true),
			"%s ('%s') in the new font" % [label.get_path(), label.text]
		)
	# The font specimen shows the old font as the world's.
	var specimen: FontSpecimen = SPECIMEN.instantiate()
	add_child_autofree(specimen)
	var said: bool = false
	var specimen_labels: Array[Control] = []
	_controls(specimen, specimen_labels)
	for control: Control in specimen_labels:
		var label: Label = control as Label
		if label != null and label.text.contains("world's font"):
			said = said or _font_of(label) == PixelText.font()
	assert_true(said, "the specimen names the old font the world's font, in it")
	# The gallery still opens, its captions in the world's font.
	var gallery: Control = GALLERY.instantiate()
	add_child_autofree(gallery)
	var captions: Array[Control] = []
	_controls(gallery, captions)
	var old: int = 0
	for control: Control in captions:
		if control is Label and _font_of(control as Label) == PixelText.font():
			old += 1
	assert_gt(old, 0, "the gallery's captions are in the world's font")


# --- R8 ------------------------------------------------------------------------


func test_r8_nothing_lost() -> void:
	var main: Main = _main(ROOM_SMALL)
	var hud: Hud = main.hud
	_gold_situation(main)
	# The list stays while the shop is open, and the goals while the tally is: windows are drawn
	# over them (R2, R10).
	hud.shop.open()
	hud.advance(STEP)
	assert_true(hud.shop.is_open(), "the shop is open")
	assert_true(hud.ladder.is_shown(), "the list stays under the shop")
	assert_true(hud.ladder.is_visible_in_tree(), "drawn")
	hud.shop.close()
	hud.tally.open()
	hud.advance(STEP)
	assert_true(hud.tally.is_open(), "the tally is open")
	assert_true(hud.goals.is_shown(), "the goals stay under the tally")
	assert_true(hud.goals_view.is_visible_in_tree(), "drawn")
	hud.tally.close()


# --- R9 ------------------------------------------------------------------------


func test_r9_true_in_a_crowded_frame() -> void:
	var main: Main = _main(ROOM_SMALL)
	var hud: Hud = main.hud
	var sim: Simulation = main.simulation
	raise_party(main.simulation, 6)
	sim.set_auto_push(true)
	assert_true(_fight(main), "a fight")
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	main.effects.advance(STEP)
	hud.advance(STEP)
	var e: Expedition = sim.expedition
	var shown: Array[String] = []
	for row: GoalRow in hud.goals_view.rows:
		if row.visible:
			shown.append(row.sentence_label.text)
	assert_eq(shown, hud.goals.lines(), "the goals as the tracker has them")
	var applicable: Array[String] = []
	for goal: Goals.Goal in hud.goals.applicable():
		applicable.append(goal.sentence)
	for line: String in shown:
		assert_true(
			applicable.has(line) or hud.goals.is_finished(shown.find(line)),
			"'%s' is true now" % line
		)
	var list: StageList = hud.ladder
	assert_true(list.marks(e.depth).has(&"party"), "the party's stage on the list")
	assert_true(
		e.depth >= list.first_depth() and e.depth < list.first_depth() + StageList.RUNGS,
		"and on show"
	)
	assert_true(list.marks(e.last_stable_depth).has(&"safe"), "the safe stage")
	assert_true(list.marks(e.target_depth).has(&"target"), "the target")
	var newest: String = hud.journal.ticker_text()
	assert_eq(hud.ticker.label.text if hud.ticker.visible else "", newest, "the ticker's line")
	# A defeat heard late but still recent: the party is beaten by the guardian of stage 5 and has
	# fallen back to stage 4 by the time the frame's events arrive. They are recent by spec 046 R5
	# (stamped with the frame's tick, as a frame that has just stepped them has them: a real revival
	# takes longer than 4x keeps a wipe recent), and the note tells of the lost fight from them.
	var fresh: Main = _main(ROOM_SMALL)
	var fe: Expedition = fresh.simulation.expedition
	before_guardian(fresh.simulation, GUARDIAN_DEPTH)
	fe.last_stable_depth = GUARDIAN_DEPTH - 1
	assert_true(_fight(fresh), "a guardian fight")
	var guardian: String = Content.monster(fe.guardian_of(GUARDIAN_DEPTH)).display_name
	for fighter: Combatant in fe.battle.heroes:
		fighter.health = 0
	var wiped: bool = false
	for i: int in LIMIT_TICKS:
		fresh.simulation.step()
		wiped = wiped or fe.state == Expedition.State.REVIVING
		if wiped and fe.state != Expedition.State.REVIVING:
			break
	assert_true(wiped, "wiped")
	assert_eq(fe.depth, GUARDIAN_DEPTH - 1, "fallen back by the frame's end")
	for event: SimEvent in fresh.simulation.drain_events():
		event.tick = fresh.simulation.tick
		assert_true(fresh.world.is_recent(event), "recent")
		fresh.world.sim_event.emit(event)
	fresh.hud.advance(STEP)
	assert_true(fresh.hud.defeat_note.is_shown(), "the note shows")
	assert_true(fresh.hud.defeat_note.panel.is_visible_in_tree(), "drawn")
	assert_string_contains(
		fresh.hud.defeat_note.panel.labels[0].text,
		"Beaten by the %s on Mossy Hollow %d" % [guardian, GUARDIAN_DEPTH],
		"the lost fight: its monster and its stage, not where the party is now"
	)


# --- R10 -----------------------------------------------------------------------


func test_r10_fits_both_rooms() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = "%s" % room
		# The widest goals the data makes (a talent goal with its count and >, wider than the
		# panel's least width), and the widest line the ticker shows.
		main.simulation.party.gold = RICH
		raise_party(main.simulation, GOAL_LEVEL)  # points unspent
		_situation(main, 1, 1, 1)
		hud.journal.announce(WIDEST_TICKER)
		hud.advance(STEP)
		assert_eq(hud.ticker.label.text, WIDEST_TICKER, "%s: the widest line" % what)
		var widest: float = 0.0
		for i: int in hud.goals.count():
			widest = maxf(widest, GoalRow.needed_width(hud.goals.goal_at(i)))
		assert_gt(
			widest + GoalsView.PAD * 2.0, GoalsView.MIN_WIDTH, "%s: wider than the least" % what
		)
		for row: GoalRow in hud.goals_view.rows:
			if not row.visible:
				continue
			var words: Rect2 = _ink(row.sentence_label)
			var said: String = row.sentence_label.text
			if not row.detail_label.text.is_empty():
				var count: Rect2 = _ink(row.detail_label)
				assert_false(words.intersects(count), "%s: '%s' clear of its count" % [what, said])
			var arrow: Rect2 = row.get_global_transform() * row.arrow_rect()
			if arrow.has_area():
				assert_false(words.intersects(arrow), "%s: '%s' clear of its >" % [what, said])
		var pieces: Dictionary[String, Control] = _pieces(main)
		pieces["button bar"] = main.ui.bar
		var news: Dictionary[String, Control] = {
			"goals": hud.goals_view, "stage list": hud.ladder, "ticker": hud.ticker
		}
		var room_rect := Rect2(Vector2.ZERO, Vector2(room))
		for name_key: String in news:
			var piece: Control = news[name_key]
			assert_true(piece.is_visible_in_tree(), "%s: %s shows" % [what, name_key])
			var rect: Rect2 = piece.get_global_rect()
			assert_true(room_rect.encloses(rect), "%s: %s inside the room" % [what, name_key])
			for other: String in pieces:
				assert_false(
					rect.intersects(pieces[other].get_global_rect()),
					"%s: %s clear of %s" % [what, name_key, other]
				)
			for other: String in news:
				if other != name_key:
					assert_false(
						rect.intersects(news[other].get_global_rect()),
						"%s: %s clear of %s" % [what, name_key, other]
					)
			_assert_not_cut(piece, "%s %s" % [what, name_key])
		# Every area's guardian, named beside its stage, fits the list.
		for id: StringName in Content.area_ids():
			var named: String = Content.monster(Content.area(id).guardian).display_name
			assert_lte(
				StageList.NAME_X + GoalRow.ink(named),
				StageList.WIDTH - StageList.PADDING,
				"%s: '%s' fits beside its stage" % [what, named]
			)
		# Windows are drawn over the goals and the list, as over the world.
		for id: StringName in main.ui.windows.ids():
			var window: UiWindow = main.ui.windows.window(id)
			assert_true(_is_over(main.ui, window, hud.goals_view), "%s over the goals" % id)
			assert_true(_is_over(main.ui, window, hud.ladder), "%s over the list" % id)
		main.free()
	# The catching-up bar inside each room.
	_away_files(ROOM_SMALL)
	var away: Main = _main_after_away(3600.0, null)
	for room: Vector2i in ROOMS:
		away.ui.set_room_for_test(room)
		away.catch_up_bar.fit(Vector2(away.ui.room()))
		var rect: Rect2 = away.catch_up_bar.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, Vector2(room)).encloses(rect), "%s: the bar fits" % room)
		_assert_not_cut(away.catch_up_bar, "%s catching up" % room)
	await wait_until(func() -> bool: return not away.is_catching_up(), 60.0, "replay ends")


# --- R11 -----------------------------------------------------------------------


func test_r11_showcase_help_and_wiki() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for said: String in ["Goals", "stage list", "ticker", "Back to the game"]:
		assert_string_contains(wiki, said, "the wiki tells of %s" % said)
	# The showcase, run to its moment, shows the report as a window.
	var show: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(show)
	await _frames()
	show.skip_to(&"away_report")
	await _frames()
	assert_eq(show.moment(), &"away_report", "the showcase's moment")
	var report: AwayWindow = show.main.away_window
	assert_true(is_instance_valid(report) and report.is_open(), "the report window is open")
	if is_instance_valid(report):
		assert_true(show.main.ui.windows.is_ancestor_of(report), "among the windows")


# --- R12 -----------------------------------------------------------------------


func test_r12_tags_stay_under_windows() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var what: String = "%s" % room
		var ui: UiRoot = main.ui
		for id: StringName in ui.windows.ids():
			ui.windows.window(id).badge = 9
		ui.bar.refresh()
		for id: StringName in ui.bar.badges:
			var tag: UiBadge = ui.bar.badges[id]
			var button: UiButton = ui.bar.buttons[id]
			assert_true(tag.is_visible_in_tree(), "%s: %s's tag shows" % [what, id])
			assert_true(_is_over(ui, tag, button), "%s: over its button" % what)
			assert_true(
				tag.get_global_rect().intersects(button.get_global_rect()), "%s: on it" % what
			)
		# A window dragged across the bar is drawn over every tag.
		ui.windows.open_window(UiRoot.JOURNAL)
		var journal: UiWindow = ui.windows.window(UiRoot.JOURNAL)
		await _frames()  # its title bar laid out
		var bar: Rect2 = ui.bar.get_global_rect()
		var to: Vector2 = bar.position + Vector2(-40.0, -20.0)
		_drag(ui, journal, to - journal.position)
		await _frames()
		assert_true(
			journal.get_global_rect().intersects(bar),
			"%s: the window on the bar %s %s" % [what, journal.get_global_rect(), bar]
		)
		for id: StringName in ui.bar.badges:
			var tag: UiBadge = ui.bar.badges[id]
			if journal.get_global_rect().intersects(tag.get_global_rect()):
				assert_true(_is_over(ui, journal, tag), "%s: the window over %s's tag" % [what, id])
		var covered: Array[String] = _drawn_over(ui, journal)
		for path: String in covered:
			assert_false(path.contains("Badge"), "%s: no tag over the window: %s" % [what, path])
		# Tooltips stay above everything: the bar's and the frame's.
		var tip: UiTip = main.hud.frame_tip
		assert_true(_is_over(ui, tip, journal), "%s: the frame's tip over the window" % what)
		for id: StringName in ui.bar.badges:
			assert_true(_is_over(ui, tip, ui.bar.badges[id]), "%s: and over the tags" % what)
			assert_true(_is_over(ui, ui.bar.tip, ui.bar.badges[id]), "%s: the bar's too" % what)
		assert_true(_is_over(ui, ui.bar.tip, journal), "%s: the bar's tip over windows" % what)
		assert_true(_is_over(ui, tip, main.hud.defeat_note.panel), "%s: over the note" % what)
		main.free()

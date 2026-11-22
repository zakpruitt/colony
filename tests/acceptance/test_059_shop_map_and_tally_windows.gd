extends "res://tests/support/main_fixture.gd"
## Acceptance tests for specs/059-shop-map-and-tally-windows/spec.md, one per requirement.
##
## Each test runs the main scene with its processing off, the UI layer laid out for a chosen room,
## puts the simulation where it wants it by hand and steps it a tick at a time (the world and the
## HUD after each), and drives the three windows with real keys and clicks (helpers in
## MainFixture), checking the simulation after each command.

const STRONG_LEVEL: int = 60
const ARMOR: StringName = &"stout_armor"
const MEDICINE: StringName = &"field_medicine"
const MOSSY: StringName = &"mossy_hollow"
const CLAYPITS: StringName = &"claypits"
const IDS: Array[StringName] = [&"shop", &"map", &"tally"]
const WIKI: String = "res://docs/wiki/index.html"
const SHOWCASE: String = "res://game/dev/showcase.tscn"
## The stage each batch of [method test_r7_true_in_a_crowded_frame] sends the party to.
const CROWD_TARGETS: Array[int] = [3, 1, 4, 2, 5, 3]
## "Last fight: 2 cave bats, Mossy Hollow 1, 4 s" (or "This fight: ..." while one goes on).
const FIGHT_LINE: String = "^(?<head>Last|This) fight: .+, (?<place>[A-Z].+ \\d+), (?<secs>\\d+) s$"

## Every event the world told of in the main scene a test made last, oldest first.
var _events: Array[SimEvent] = []

# --- Helpers -------------------------------------------------------------------


func _start(room: Vector2i = ROOM_SMALL) -> Main:
	var main: Main = _main(room)
	_events.clear()
	main.world.sim_event.connect(func(event: SimEvent) -> void: _events.append(event))
	main.hud.advance(STEP)
	return main


func _window(main: Main, id: StringName) -> UiWindow:
	return main.ui.windows.window(id)


func _count(kind: SimEvent.Kind) -> int:
	var count: int = 0
	for event: SimEvent in _events:
		if event.kind == kind:
			count += 1
	return count


## The texts a window shows, top to bottom: every visible label's and button's text, in tree
## order.
func _texts(node: Node, into: Array[String]) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if child is Label:
			into.append((child as Label).text)
		elif child is Button:
			into.append((child as Button).text)
		_texts(child, into)


func _shown(main: Main, id: StringName) -> Array[String]:
	var found: Array[String] = []
	_texts(_window(main, id).content, found)
	return found


func _bold(label: Label) -> bool:
	return label.get_theme_font(&"font") == UiText.font(true)


# --- R1 ------------------------------------------------------------------------


func test_r1_three_windows() -> void:
	var main: Main = _start()
	var ui: UiRoot = main.ui
	var hud: Hud = main.hud
	var contents: Array[Control] = [hud.shop, hud.area_map, hud.tally]
	for i: int in IDS.size():
		var shown: UiWindow = _window(main, IDS[i])
		assert_not_null(shown, "a %s window" % IDS[i])
		if shown == null:
			return
		assert_eq(shown.content, contents[i], "holding the %s" % IDS[i])
		assert_true(ui.bar.buttons.has(IDS[i]), "with a button on the bar")
		assert_not_null(shown.icon, "and an icon for it")
	assert_eq(_window(main, &"shop").key_hint, "U")
	assert_eq(_window(main, &"map").key_hint, "W")
	assert_eq(_window(main, &"tally").key_hint, "T")
	# The old panels and their buttons are gone.
	for old: String in ["shop_button", "shop_marker", "tally_button"]:
		assert_false(old in hud, "the HUD has no %s" % old)
	for old: String in ["ShopPanel", "TallyPanel", "AreaMap", "ShopButton", "TallyButton"]:
		assert_null(hud.find_child(old, true, false), "no %s in the HUD" % old)

	# The keys open them, all six together.
	for code: Key in [KEY_U, KEY_W, KEY_T, KEY_H, KEY_J, KEY_O]:
		press(code)
	for id: StringName in IDS + [UiRoot.HELP, UiRoot.JOURNAL, UiRoot.ORDERS]:
		assert_true(ui.windows.is_open(id), "%s is open with the other five" % id)
	await _frames()
	# The bar's buttons close and open them.
	for id: StringName in IDS:
		_click_on(main, ui.bar.buttons[id])
		assert_false(ui.windows.is_open(id), "its button closes the %s" % id)
		_click_on(main, ui.bar.buttons[id])
		assert_true(ui.windows.is_open(id), "and opens it")
	# Esc closes the front one only.
	ui.windows.raise(_window(main, &"tally"))
	press(KEY_ESCAPE)
	assert_false(ui.windows.is_open(&"tally"), "Esc closes the front window")
	assert_true(ui.windows.is_open(&"shop"), "and only that")
	# The area's name still opens the map.
	ui.windows.close_window(&"map")
	await _frames()
	click(UiFormat.on_screen(hud.place_panel.area_button).get_center())
	assert_true(ui.windows.is_open(&"map"), "a click on the area's name opens the map")


# --- R3 ------------------------------------------------------------------------


func test_r3_the_map_reads_at_a_glance() -> void:
	var main: Main = _start(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var e: Expedition = sim.expedition
	set_party_level(main.simulation, STRONG_LEVEL)
	e.travel.open[CLAYPITS] = true
	e.travel.stages[CLAYPITS] = Vector2i(2, 4)
	var map: AreaMapWindow = main.hud.area_map
	press(KEY_W)
	main.hud.advance(STEP)
	await _frames()
	assert_true(map.is_open(), "W opens the map")
	var mossy: AreaMapRow = map.row(MOSSY)
	var clay: AreaMapRow = map.row(CLAYPITS)
	assert_true(_bold(mossy.name_label), "in bold")

	# Choosing a card shows the stage chooser and a Go that says what it will do.
	assert_false(map.go_button.is_visible_in_tree(), "no Go before a choice")
	_click_on(main, clay)
	main.hud.advance(STEP)
	await _frames()
	assert_eq(map.chosen(), CLAYPITS, "a click chooses the card")
	assert_eq(map.stage_label.text, "2", "at its safe stage")
	var safe: StringName = DepthLadder.RISK_COLOURS[map.risk(CLAYPITS, 2)]
	assert_eq(_colour(map.stage_label), Palette.color(safe), "coloured by how it looks")
	assert_eq(map.risk_label.text, "Safe", "with that word beside it")
	assert_eq(map.go_button.text, "Travel to The Claypits 2")
	_click_on(main, map.plus_button)
	_click_on(main, map.plus_button)
	main.hud.advance(STEP)
	assert_eq(map.stage_shown(), 4, "+ twice")
	assert_eq(map.risk_label.text, "Within reach", "a stage not yet held, at the party's level")
	assert_eq(map.go_button.text, "Travel to The Claypits 4")
	_click_on(main, map.minus_button)
	main.hud.advance(STEP)
	await _frames()
	_click_on(main, map.go_button)
	_frame(main)
	assert_eq(e.state, Expedition.State.JOURNEYING, "Go sends the party")
	assert_eq(e.area, CLAYPITS, "to the Claypits")
	assert_eq(e.travel.stage, 3, "stage 3")

	# In the area the party is in, Go sets the target.
	var other: Main = _start(ROOM_LARGE)
	other.simulation.expedition.last_stable_depth = 3
	other.simulation.expedition.deepest_depth = 5
	var here: AreaMapWindow = other.hud.area_map
	here.open()
	here.choose(MOSSY)
	here.step_stage(1)
	other.hud.advance(STEP)
	await _frames()
	assert_eq(here.go_button.text, "Set target: stage 4")
	_click_on(other, here.go_button)
	_frame(other)
	assert_eq(other.simulation.expedition.target_depth, 4, "the target is set")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_tally_reads_at_a_glance() -> void:
	var main: Main = _start(ROOM_LARGE)
	var tally: TallyWindow = main.hud.tally
	var heroes: Array[Hero] = main.simulation.party.heroes
	for i: int in LIMIT_TICKS:
		_frame(main)
		var healed: bool = _count(SimEvent.Kind.HEALED) > 0
		var fighting: bool = main.simulation.expedition.state == Expedition.State.FIGHTING
		if _count(SimEvent.Kind.ENCOUNTER_ENDED) >= 2 and healed and not fighting:
			break
	assert_gte(_count(SimEvent.Kind.ENCOUNTER_ENDED), 2, "setup: two fights")
	press(KEY_T)
	main.hud.advance(STEP)
	await _frames()
	assert_true(tally.is_open(), "T opens the tally")
	var names: Array[String] = ["Damage", "Healing", "Taken"]
	for measure: int in names.size():
		assert_eq(tally.tab_buttons[measure].text, names[measure], "a tab for %s" % names[measure])
		_click_on(main, tally.tab_buttons[measure])
		main.hud.advance(STEP)
		assert_eq(tally.measure(), measure, "a click opens the %s tab" % names[measure])
		assert_true(tally.tab_buttons[measure].lit, "lit")
	_click_on(main, tally.tab_buttons[Tally.Measure.DAMAGE])
	assert_eq(tally.span_buttons[0].text, "Last fight")
	assert_eq(tally.span_buttons[1].text, "Session")
	_click_on(main, tally.span_buttons[Tally.Span.SESSION])
	main.hud.advance(STEP)
	await _frames()
	assert_eq(tally.span(), Tally.Span.SESSION, "the switch chooses the span")
	var right_edge: float = -1.0
	for i: int in heroes.size():
		var hero: Hero = heroes[i]
		var colours: Array = TallyWindow.CLASS_BARS[hero.class_id]
		var own: StringName = colours[0]
		assert_eq(tally.bars[i].fill, own, "%s's bar in its colour" % hero.class_id)
		var value: int = tally.tally.value(hero.id, Tally.Measure.DAMAGE, Tally.Span.SESSION)
		assert_eq(tally.value_labels[i].text, UiFormat.group_thousands(value), "its number")
		assert_eq(tally.value_labels[i].horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
		var edge: float = tally.value_labels[i].get_global_rect().end.x
		if right_edge >= 0.0:
			assert_eq(edge, right_edge, "the numbers right-aligned in one column")
		right_edge = edge
		assert_string_ends_with(tally.share_labels[i].text, "%", "and its share")
	# A click on a hero's line opens its abilities under it, indented, each with a bar.
	_click_on(main, tally.hero_lines[0])
	main.hud.advance(STEP)
	await _frames()
	assert_eq(tally.opened_hero(), heroes[0].id, "a click opens the line")
	assert_false(tally.ability_lines.is_empty(), "its abilities show")
	var line_top: float = tally.hero_lines[0].get_global_rect().end.y
	for line: Control in tally.ability_lines:
		var at: Rect2 = line.get_global_rect()
		assert_gte(at.position.y, line_top, "under the hero's line")
		assert_gt(at.position.x, tally.hero_lines[0].get_global_rect().position.x, "indented")
		assert_eq(line.find_children("*", "UiBar", true, false).size(), 1, "with its own bar")
	assert_lt(
		tally.ability_lines[-1].get_global_rect().end.y,
		tally.hero_lines[1].get_global_rect().position.y,
		"above the next hero's line"
	)
	# Frames with nothing new keep the same lines: updated in place, not made afresh each frame.
	var kept: Array[Control] = tally.ability_lines.duplicate()
	var size_before: Vector2 = _window(main, &"tally").size
	for i: int in 3:
		main.hud.advance(STEP)
		await get_tree().process_frame
	assert_eq(tally.ability_lines, kept, "the same line nodes after quiet frames")
	for line: Control in kept:
		assert_true(is_instance_valid(line) and not line.is_queued_for_deletion(), "none freed")
	assert_eq(_window(main, &"tally").size, size_before, "and the window keeps its size")
	# New numbers update those lines; a line is made only when the set of lines changes.
	var count: int = tally.ability_lines.size()
	for i: int in LIMIT_TICKS:
		_frame(main)
		if _count(SimEvent.Kind.HIT) > 0 and main.simulation.expedition.battle != null:
			break
	for i: int in 30:
		_frame(main)
	assert_eq(tally.ability_lines.size(), count, "setup: the same set of lines")
	assert_eq(tally.ability_lines, kept, "a fight's new numbers keep the lines")
	# Q and E change tab while the tally is in front, and only then.
	press(KEY_E)
	assert_eq(tally.measure(), Tally.Measure.HEALING, "E: the next tab")
	press(KEY_Q)
	press(KEY_Q)
	assert_eq(tally.measure(), Tally.Measure.TAKEN, "Q: the previous, wrapping")
	press(KEY_J)
	press(KEY_E)
	assert_eq(tally.measure(), Tally.Measure.TAKEN, "E does nothing with the journal in front")


# --- R5 ------------------------------------------------------------------------


func test_r5_nothing_lost() -> void:
	var main: Main = _start(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var hud: Hud = main.hud
	set_party_level(main.simulation, 2)
	sim.party.gold = 10_000
	sim.expedition.travel.open[CLAYPITS] = true
	sim.expedition.travel.stages[CLAYPITS] = Vector2i(1, 3)
	for code: Key in [KEY_U, KEY_W, KEY_T]:
		press(code)
	hud.advance(STEP)
	await _frames()
	# Stout Armor costs a resource too from rank 4 (spec 052).
	sim.upgrades.set_rank(ARMOR, 3)
	hud.advance(STEP)
	await _frames()
	var armor: int = Content.upgrade_ids().find(ARMOR)
	# Each row's tooltip still says both prices and where the resource comes from.
	var card: UiTip.Card = hud.shop.tip.card_for(hud.shop.rows[armor])  # spec 065: a card
	var tip: String = card.body if card != null else ""
	var next: String = "Rank %d:" % (sim.upgrades.rank(ARMOR) + 1)
	assert_string_contains(tip, next, "the next rank's prices")
	assert_string_contains(tip, "comes from", "and where its resource comes from")
	# The map: a dangerous Go to another area travels and warns, once.
	var map: AreaMapWindow = hud.area_map
	map.choose(CLAYPITS)
	map.step_stage(1)
	hud.advance(STEP)
	await _frames()
	_click_on(main, map.go_button)
	_frame(main)
	assert_eq(sim.expedition.area, CLAYPITS, "set_destination")
	assert_eq(sim.expedition.travel.stage, 2)
	var warned: int = 0
	for line: String in hud.journal.lines():
		if line.ends_with("Target set to The Claypits 2: dangerous for level 2 heroes"):
			warned += 1
	assert_eq(warned, 1, "the ladder's warning in the journal, once")
	# The tally: its tabs and switch keep their tooltips; it sends nothing.
	var tally: TallyWindow = hud.tally
	for i: int in tally.tab_buttons.size():
		assert_eq(tally.tip.text_for(tally.tab_buttons[i]), TallyWindow.TAB_TIPS[i])
	for i: int in tally.span_buttons.size():
		assert_eq(tally.tip.text_for(tally.span_buttons[i]), TallyWindow.SPAN_TIPS[i])
	assert_string_starts_with(tally.rows()[0], "No fight yet", "the fight's line")
	# The hero frames still read their statuses from the tally's book.
	assert_eq(tally.status_line(sim.party.heroes[0].id), "", "no status on a hero at rest")


# --- R6 ------------------------------------------------------------------------


func test_r6_the_amber_tag_survives() -> void:
	var main: Main = _start()
	var sim: Simulation = main.simulation
	var bar: UiButtonBar = main.ui.bar
	sim.party.gold = sim.upgrades.cost(MEDICINE)  # 25: field medicine and quick march
	main.hud.advance(STEP)
	bar.advance(STEP)
	var pulse: float = bar.badges[&"shop"].pulse()
	bar.advance(0.3)
	assert_ne(bar.badges[&"shop"].pulse(), pulse, "and it pulses")

	# A new area: the Map button's mark, until the map is opened.
	assert_false(bar.badges[&"map"].visible, "no mark in a new game")
	sim.expedition.travel.open[CLAYPITS] = true
	var index: int = Content.area_ids().find(CLAYPITS)
	main.world.sim_event.emit(SimEvent.new(SimEvent.Kind.AREA_OPENED, sim.tick, -1, -1, index))
	main.hud.advance(STEP)
	bar.advance(STEP)
	assert_true(bar.badges[&"map"].is_visible_in_tree(), "the Map button carries the mark")
	assert_true(main.hud.area_map.has_mark())
	press(KEY_W)
	main.hud.advance(STEP)
	press(KEY_W)
	main.hud.advance(STEP)
	bar.advance(STEP)
	assert_false(bar.badges[&"map"].visible, "gone once the map was opened")


# --- R7 ------------------------------------------------------------------------


## Opens the three windows of [param main], chooses the Claypits on the map and the first hero on
## the tally's session span, with auto-buy on and gold to spend.
func _crowd_ready(main: Main) -> void:
	var sim: Simulation = main.simulation
	sim.party.gold = 2000
	sim.set_auto_buy(true)
	sim.expedition.travel.open[CLAYPITS] = true
	for id: StringName in IDS:
		main.ui.windows.open_window(id)
	main.hud.area_map.choose(MOSSY)
	main.hud.tally.set_span(Tally.Span.SESSION)
	main.hud.tally.open_hero(sim.party.heroes[0].id)
	# Strong heroes, sent up and down the stages, so a frame of 300 ticks often holds a fight
	# and then a move to another stage: the last fight is heard after the party has gone on.
	set_party_level(main.simulation, 12)
	sim.set_auto_push(false)
	main.hud.advance(STEP)


## [param shown] with the fight's line cut to its head, where it was and how long it took.
func _fight_from_place(shown: Array[String], fight_line: RegEx) -> Array[String]:
	var cut: Array[String] = []
	for text: String in shown:
		var found: RegExMatch = fight_line.search(text)
		if found == null:
			cut.append(text)
		else:
			var parts: Array[String] = [
				found.get_string("head"), found.get_string("place"), found.get_string("secs")
			]
			cut.append("%s fight: ..., %s, %s s" % parts)
	return cut


func test_r7_true_in_a_crowded_frame() -> void:
	var crowded: Main = _start()
	var steady: Main = _start()
	_crowd_ready(crowded)
	_crowd_ready(steady)
	var fight_line := RegEx.create_from_string(FIGHT_LINE)
	var places: Dictionary[String, bool] = {}
	# Every target once, then round again until fights were seen on more than two stages: a
	# party that takes side paths is longer on each.
	for batch: int in CROWD_TARGETS.size() * 3:
		if batch >= CROWD_TARGETS.size() and places.size() > 2:
			break
		for main: Main in [crowded, steady]:
			main.simulation.set_target_depth(CROWD_TARGETS[batch % CROWD_TARGETS.size()])
		_frame(crowded, 300)
		for i: int in 300:
			_frame(steady)
		assert_eq(crowded.simulation.tick, steady.simulation.tick, "setup: the same ticks")
		for id: StringName in IDS:
			assert_eq(_shown(crowded, id), _shown(steady, id), "batch %d: the %s" % [batch, id])
		# The Last fight span too: its line (where the fight was, how long) and its numbers.
		for main: Main in [crowded, steady]:
			main.hud.tally.set_span(Tally.Span.LAST_FIGHT)
		# A fight heard late names its monsters by count alone ("2 monsters"), as the old panel
		# did: the line is compared from where it was on.
		var last: Array[String] = _fight_from_place(_shown(crowded, &"tally"), fight_line)
		var heard: Array[String] = _fight_from_place(_shown(steady, &"tally"), fight_line)
		assert_eq(last, heard, "batch %d: the tally's last fight" % batch)
		var found: RegExMatch = fight_line.search(crowded.hud.tally.rows()[0])
		assert_not_null(found, "batch %d: the fight's line: %s" % [batch, last])
		if found != null:
			places[found.get_string("place")] = true
		for main: Main in [crowded, steady]:
			main.hud.tally.set_span(Tally.Span.SESSION)
	assert_gt(places.size(), 2, "setup: fights on several stages %s" % [places.keys()])
	var sim: Simulation = crowded.simulation
	assert_gt(_count(SimEvent.Kind.UPGRADE_BOUGHT), 0, "setup: auto-buy bought")
	var shop: Array[String] = _shown(crowded, &"shop")
	for id: StringName in Content.upgrade_ids():
		var rank: String = "%d / %d" % [sim.upgrades.rank(id), Content.upgrade(id).max_rank]
		assert_has(shop, rank, "%s's rank as the simulation has it" % id)
	var map: Array[String] = _shown(crowded, &"map")
	var progress: Vector2i = sim.area_progress(MOSSY)
	assert_has(map, "Safe %d, furthest %d" % [progress.x, progress.y], "the area's progress")
	var tally: TallyWindow = crowded.hud.tally
	for i: int in sim.party.heroes.size():
		var id: int = sim.party.heroes[i].id
		var value: int = tally.tally.value(id, Tally.Measure.DAMAGE, Tally.Span.SESSION)
		assert_gt(value, 0, "setup: hero %d has dealt damage" % id)
		assert_eq(
			tally.value_labels[i].text, UiFormat.group_thousands(value), "hero %d's number" % id
		)


# --- R8 ------------------------------------------------------------------------


## Fills each window with the longest texts the data can give it: every upgrade short of gold
## and of its resource, every area open and on the way, a tally of nine-figure numbers with the
## first hero's line open.
func _fill_longest(main: Main) -> void:
	var sim: Simulation = main.simulation
	for id: StringName in Content.upgrade_ids():
		sim.upgrades.set_rank(id, Content.upgrade(id).max_rank - 1)
	sim.party.gold = 0
	for id: StringName in Content.area_ids():
		sim.expedition.travel.open[id] = true
		sim.expedition.travel.stages[id] = Vector2i(98, 99)
	for id: StringName in Content.resource_ids():
		sim.party.set_resource(id, 0)
	for hero: Hero in sim.party.heroes:
		for i: int in 3:
			var hit := SimEvent.new(
				SimEvent.Kind.HIT, 0, hero.id, Expedition.FIRST_MONSTER_ID, 33_333_333
			)
			main.hud.tally.tally.observe(hit)
	main.hud.tally.set_span(Tally.Span.SESSION)
	main.hud.tally.open_hero(sim.party.heroes[0].id)
	main.hud.area_map.choose(&"ember_deep")
	main.hud.area_map.step_stage(99)
	main.hud.advance(STEP)


func test_r8_fits_both_rooms() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var main: Main = _start(room)
		var ui: UiRoot = main.ui
		_fill_longest(main)
		for id: StringName in IDS:
			ui.windows.open_window(id)
		main.hud.advance(STEP)
		await _frames()
		var frames_top: float = floorf(ui.world_to_ui(Vector2(0, ui.frames_top())).y)
		var space := Rect2(Vector2.ZERO, Vector2(room.x, frames_top))
		var rects: Dictionary[StringName, Rect2] = {}
		for id: StringName in IDS:
			var shown: UiWindow = _window(main, id)
			assert_eq(shown.position, shown.default_place, "%s at its default place" % id)
			rects[id] = shown.get_rect()
			assert_true(
				space.encloses(rects[id]),
				"%s, %s: above the frames' line: %s" % [room, id, rects[id]]
			)
			# Above the button bar's line too, with half the gap windows keep from each other, so
			# the bar's buttons and the windows never touch whichever way a window is dragged.
			var bar_top: float = ui.bar.get_global_rect().position.y - UiRoot.PLACE_GAP / 2.0
			assert_lte(
				rects[id].end.y,
				bar_top,
				"%s, %s: above the button bar: %s, bar at %s" % [room, id, rects[id], bar_top]
			)
			var needed: Vector2 = shown.get_combined_minimum_size()
			assert_true(
				shown.size.x >= needed.x and shown.size.y >= needed.y, "%s fits its content" % id
			)
			var labels: Array[Label] = []
			_labels(shown.content, labels)
			for label: Label in labels:
				var at: Rect2 = label.get_global_rect()
				var where: String = "%s, %s: '%s' %s" % [room, id, label.text, at]
				assert_true(rects[id].encloses(at), "%s inside its window" % where)
				if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
					assert_gte(
						at.size.x,
						float(UiText.width(label.text, _bold(label)) - UiText.SPACING),
						"%s not cut" % where
					)
			for a: int in labels.size():
				for b: int in range(a + 1, labels.size()):
					var one: Rect2 = labels[a].get_global_rect()
					var two: Rect2 = labels[b].get_global_rect()
					if labels[a].text.is_empty() or labels[b].text.is_empty():
						continue
					assert_false(
						one.intersects(two),
						"%s, %s: '%s' and '%s' overlap" % [room, id, labels[a].text, labels[b].text]
					)
		for a: int in IDS.size():
			for b: int in range(a + 1, IDS.size()):
				assert_false(
					rects[IDS[a]].intersects(rects[IDS[b]]),
					(
						"%s: the %s and the %s overlap %s %s"
						% [room, IDS[a], IDS[b], rects[IDS[a]], rects[IDS[b]]]
					)
				)
		# The tally's ability column fits the longest ability name in the data.
		var longest: int = 0
		for id: StringName in Content.ability_ids():
			longest = maxi(longest, UiText.width(Content.ability(id).display_name))
		assert_gte(
			main.hud.tally.ability_name_width(), longest, "%s: the longest ability fits" % room
		)
		main.free()


## Since spec 060: the three windows and two hero windows open at once, each at its default
## place, at both rooms, all clear the button bar and the hero frames' line (they may overlap each
## other: a click brings one to the front).
func test_r8_beside_the_hero_windows() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var main: Main = _start(room)
		var ui: UiRoot = main.ui
		for id: StringName in IDS:
			ui.windows.open_window(id)
		for hero: Hero in main.simulation.party.heroes.slice(0, 2):
			main.hud.hero_windows.open(hero.id)
		main.hud.advance(STEP)
		await _frames()
		var frames_top: float = floorf(ui.world_to_ui(Vector2(0, ui.frames_top())).y)
		var bar_top: float = ui.bar.get_global_rect().position.y - UiRoot.PLACE_GAP / 2.0
		var shown: Array[UiWindow] = []
		for id: StringName in IDS:
			shown.append(_window(main, id))
		for hero: Hero in main.simulation.party.heroes.slice(0, 2):
			shown.append(main.hud.hero_windows.window_of(hero.id))
		for each: UiWindow in shown:
			assert_true(each.is_open(), "%s, %s: open" % [room, each.window_id])
			var rect: Rect2 = each.get_rect()
			var where: String = "%s, %s: %s" % [room, each.window_id, rect]
			assert_eq(each.position, each.default_place, "%s at its default place" % where)
			assert_true(Rect2(Vector2.ZERO, Vector2(room)).encloses(rect), "%s on screen" % where)
			assert_lte(rect.end.y, frames_top, "%s above the frames' line" % where)
			var bar: Rect2 = ui.bar.get_global_rect()
			var beside: bool = rect.end.x <= bar.position.x
			assert_true(rect.end.y <= bar_top or beside, "%s clear of the bar" % where)
		main.free()


# --- R9 ------------------------------------------------------------------------


func test_r9_help_wiki_and_showcase() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for phrase: String in ["Camp window", "Area map window", "Party tally window"]:
		assert_string_contains(wiki, phrase, "the wiki describes the %s" % phrase)
	for pair: Array in [[&"shop", &"shop"], [&"area_map", &"map"]]:
		var moment: StringName = pair[0]
		assert_has(Showcase.names(), moment, "the showcase has a %s moment" % moment)
		var showcase: Showcase = (load(SHOWCASE) as PackedScene).instantiate() as Showcase
		add_child_autofree(showcase)
		showcase.set_process(false)
		showcase.skip_to(moment)
		var start: float = showcase.elapsed
		while showcase.moment() == moment and showcase.elapsed - start < 10.0:
			showcase.advance(1.0 / 30.0)
			if showcase.evidence.has(moment):
				break
		assert_true(showcase.evidence.has(moment), "the %s moment happens" % moment)
		var id: StringName = pair[1]
		assert_true(showcase.main.ui.windows.is_open(id), "in the %s window" % id)
		showcase.free()

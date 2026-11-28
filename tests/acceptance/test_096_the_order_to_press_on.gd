extends "res://tests/support/side_path_fixture.gd"
## Acceptance tests for specs/096-the-order-to-press-on/spec.md, one per requirement: the third
## party order, Side paths, at Explore or Press on.
##
## Each test of the walk finds a side path over the seeds and stands a party before it (spec
## 093's fixture).

const EXPLORE: Expedition.SidePaths = Expedition.SidePaths.EXPLORE
const PRESS_ON: Expedition.SidePaths = Expedition.SidePaths.PRESS_ON
## A level at which every hero has every microskill of its class.
const SKILLED: int = 12
## The events of a gate or its cache.
const GATE_KINDS: Array[SimEvent.Kind] = [
	SimEvent.Kind.GATE_STARTED,
	SimEvent.Kind.GATE_OPENED,
	SimEvent.Kind.GATE_SEALED,
	SimEvent.Kind.CACHE_OPENED,
]
## The state hash of seed 3's winding game, its party raised to level 12, after 3000 ticks with
## no order given, recorded on the code before this spec.
## Re-recorded by spec 104, whose quests take longer and are worked by every able hero.
const HASH_SEED: int = 3
const HASH_TICKS: int = 3000
const EXPLORE_HASH: int = 3549241326
const SAVED: Array[String] = ["explore", "press_on"]
const NAMES: Array[String] = ["Explore", "Press on"]
const LINES: Array[String] = [
	"The party takes every side path it can open.", "The party walks past every gate it meets."
]
const PRESSING: String = "The party is pressing on"
const AWAY_SECONDS: float = 3600.0
const ROOMS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720)]

# --- Helpers -------------------------------------------------------------------


## A winding game of [param seed_value] that stays on its stage, its heroes all able to open
## every gate (or, not [param skilled], none ever), the side path order [param order] in force.
func _ordered(seed_value: int, order: Expedition.SidePaths, skilled: bool = true) -> Simulation:
	var sim: Simulation = winding_simulation(seed_value)
	sim.set_auto_push(false)
	if skilled:
		raise_party(sim, SKILLED)
	else:
		_keep_unskilled(sim)
	sim.set_side_paths(order)
	sim.step()
	sim.drain_events()
	return sim


## How many of [param events] are a gate's or a cache's.
func _gate_events(events: Array[SimEvent]) -> int:
	var count: int = 0
	for kind: SimEvent.Kind in GATE_KINDS:
		count += _of_kind(events, kind).size()
	return count


## Walks [param sim]'s party past side path [param index] of stage 1 going [param way] and
## checks it never stops or turns off and that nothing is told of a gate.
func _walk_past(sim: Simulation, index: int, way: int, what: String) -> void:
	var e: Expedition = sim.expedition
	var path: SidePath = _stand_before(sim, 1, index, way)
	var events: Array[SimEvent] = []
	for i: int in 10:
		sim.step()
		events.append_array(sim.drain_events())
		assert_eq(e.side_path, -1, "%s: it does not turn off" % what)
		assert_eq(e.state, Expedition.State.TRAVELLING, "%s: it does not stop" % what)
	assert_gt((e.x - path.at) * way, 1.0, "%s: it walks past" % what)
	assert_eq(_gate_events(events), 0, "%s: nothing is told of a gate" % what)
	assert_true(SidePathRules.is_full(e, 1, index), "%s: its cache stays full" % what)


## The state hash of the recorded run after its ticks, the order [param order] given first if
## [param given]; and, in [param caches], one entry for each cache it opened.
func _hash_of_run(order: Expedition.SidePaths, given: bool, caches: Array[int]) -> int:
	var sim: Simulation = winding_simulation(HASH_SEED)
	raise_party(sim, SKILLED)
	if given:
		sim.set_side_paths(order)
	for event: SimEvent in _of_kind(run_ticks(sim, HASH_TICKS), SimEvent.Kind.CACHE_OPENED):
		caches.append(event.amount)
	return sim.state_hash()


## The main scene laid out for [param room], its own processing off, with the tests'
## simulation, world, HUD and UI layer pointed at its own. The test frees it.
func _orders_main(room: Vector2i) -> Main:
	var main: Main = make_main()
	add_child(main)
	for part: Node in [main.driver, main.world, main.effects, main.hud]:
		part.set_process(false)
	main.ui.set_room_for_test(room)
	# Above GUT's runner (canvas layer 128), whose window would otherwise take the mouse.
	main.hud_layer.layer = 129
	main.ui.layer = 130
	_sim = main.simulation
	_world = main.world
	_fx = main.effects
	_hud = main.hud
	_ui = main.ui
	_frame_parts = [_hud.advance]
	_hud.advance(0.0)
	return main


## The choice lit in the side paths row of [param orders]: one at most.
func _lit_side_paths(orders: OrdersPanel) -> int:
	var lit: int = -1
	var buttons: Array = orders.choice_buttons[PartyOrders.SIDE_PATHS]
	for value: int in buttons.size():
		if (buttons[value] as UiButton).lit:
			assert_eq(lit, -1, "one choice lit")
			lit = value
	return lit


# --- R1 ------------------------------------------------------------------------


## R1: a party that would open a gate walks past it with no stop and no gate event; given on a
## side path, the trip is finished first; back at Explore the next gate is opened.
func test_r1_press_on_passes_every_gate() -> void:
	var found: Vector2i = _find(1, false)
	var index: int = found.y
	var sim: Simulation = _ordered(found.x, PRESS_ON)
	var e: Expedition = sim.expedition
	assert_eq(e.side_paths, PRESS_ON, "the order is Press on")
	assert_not_null(SidePathRules.opener(e, 1, index), "someone could open the gate")
	_walk_past(sim, index, 1, "pressing on")
	_walk_past(sim, index, -1, "pressing on the other way")

	# Nobody able: no gate is said to be sealed either.
	var unskilled: Simulation = _ordered(found.x, PRESS_ON, false)
	assert_null(SidePathRules.opener(unskilled.expedition, 1, index), "nobody can open it")
	_walk_past(unskilled, index, 1, "pressing on with nobody able")

	# Back at Explore the party opens the gate it comes by.
	sim.set_side_paths(EXPLORE)
	sim.step()
	_stand_before(sim, 1, index, 1)
	var exploring: Array[SimEvent] = _events_until(
		sim, func() -> bool: return not SidePathRules.is_full(e, 1, index), 1200
	)
	assert_eq(_of_kind(exploring, SimEvent.Kind.GATE_OPENED).size(), 1, "exploring opens it")
	assert_eq(_of_kind(exploring, SimEvent.Kind.CACHE_OPENED).size(), 1, "and its cache")

	# Given on a side path: the trip is finished, and the party rejoins the main course.
	var trip: Simulation = _ordered(found.x, EXPLORE)
	var run: Expedition = trip.expedition
	var path: SidePath = _stand_before(trip, 1, index, 1)
	_events_until(trip, func() -> bool: return run.side_path >= 0, 30)
	trip.set_side_paths(PRESS_ON)
	trip.step()
	assert_eq(run.side_paths, PRESS_ON, "the order is given on the side path")
	assert_eq(run.side_path, index, "and the party is still on it")
	var rest: Array[SimEvent] = _events_until(trip, func() -> bool: return run.side_path < 0, 1500)
	assert_eq(_of_kind(rest, SimEvent.Kind.GATE_OPENED).size(), 1, "it opens the gate")
	assert_eq(_of_kind(rest, SimEvent.Kind.CACHE_OPENED).size(), 1, "and the cache")
	assert_almost_eq(run.x, path.at, 0.001, "and is back where the path left the course")
	assert_eq(run.facing, 1, "going the way it was going")
	run_ticks(trip, 10)
	assert_eq(run.side_path, -1, "and it walks on along the main course")
	assert_gt(run.x, path.at + 1.0, "past the path")

	# The unskilled party under Explore is told of the gate, as it was.
	var told: Simulation = _ordered(found.x, EXPLORE, false)
	_stand_before(told, 1, index, 1)
	var said: Array[SimEvent] = run_ticks(told, 10)
	assert_eq(_of_kind(said, SimEvent.Kind.GATE_SEALED).size(), 1, "Explore says a sealed gate")


# --- R2 ------------------------------------------------------------------------


## R2: the event and its numbers, none for the value held; a run at Explore has the hash
## recorded before this spec, one at Press on differs.
func test_r2_the_order_is_an_order() -> void:
	assert_eq(PartyOrders.SIDE_PATHS, 2, "the order's number")
	var sim := Simulation.new(1)
	sim.step()
	sim.drain_events()
	assert_eq(sim.expedition.side_paths, EXPLORE, "a new game explores")
	sim.set_side_paths(PRESS_ON)
	assert_eq(sim.expedition.side_paths, EXPLORE, "the order waits for the next step")
	sim.step()
	assert_eq(sim.expedition.side_paths, PRESS_ON, "and is so from it")
	var changed: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.ORDER_CHANGED)
	assert_eq(changed.size(), 1, "one event")
	if changed.size() == 1:
		assert_eq(changed[0].target_id, PartyOrders.SIDE_PATHS, "about the side paths")
		assert_eq(changed[0].amount, PRESS_ON, "with the new value")
		assert_eq(changed[0].source_id, -1, "from nobody")
		assert_eq(changed[0].tick, sim.tick, "stamped with the step")
	sim.set_side_paths(PRESS_ON)
	sim.step()
	var again: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.ORDER_CHANGED)
	assert_eq(again.size(), 0, "the value already held reports nothing")
	var no_order: int = 5
	sim.set_side_paths(no_order as Expedition.SidePaths)
	sim.step()
	assert_eq(sim.expedition.side_paths, PRESS_ON, "a value the order does not have is ignored")
	sim.set_side_paths(EXPLORE)
	sim.step()
	changed = _of_kind(sim.drain_events(), SimEvent.Kind.ORDER_CHANGED)
	assert_eq(changed.size(), 1, "back to Explore is told")
	if changed.size() == 1:
		assert_eq([changed[0].target_id, changed[0].amount], [2, EXPLORE], "with its numbers")
	# The other orders are still given through the one command.
	sim.set_pace(Expedition.Pace.BOLD)
	sim.set_guardian_order(Expedition.GuardianOrder.HOLD)
	sim.step()
	assert_eq(sim.expedition.pace, Expedition.Pace.BOLD, "the pace is still an order")
	assert_eq(sim.expedition.guardian_order, Expedition.GuardianOrder.HOLD, "and the guardians'")

	# The hash: Explore is not in it, Press on is.
	var plain := Simulation.new(1)
	var back := Simulation.new(1)
	back.set_side_paths(PRESS_ON)
	plain.step()
	back.step()
	assert_ne(back.state_hash(), plain.state_hash(), "Press on is in the hash")
	back.set_side_paths(EXPLORE)
	plain.step()
	back.step()
	assert_eq(back.state_hash(), plain.state_hash(), "and Explore is not")
	plain.set_side_paths(EXPLORE)
	assert_eq(back.state_hash(), plain.state_hash(), "nor is asking for it while it is held")

	var caches: Array[int] = []
	assert_eq(_hash_of_run(EXPLORE, false, caches), EXPLORE_HASH, "the hash it had")
	assert_gt(caches.size(), 0, "of a run that opens caches")
	var explored: int = caches.size()
	assert_eq(_hash_of_run(EXPLORE, true, caches), EXPLORE_HASH, "Explore given: the same")
	assert_eq(caches.size(), 2 * explored, "and the same caches")
	assert_ne(_hash_of_run(PRESS_ON, true, caches), EXPLORE_HASH, "Press on: another")
	assert_eq(caches.size(), 2 * explored, "with no cache opened")


# --- R3 ------------------------------------------------------------------------


## R3: the round trip of both values; a version 8 save loads at Explore; a bad value is refused
## by name.
func test_r3_the_order_is_saved() -> void:
	assert_eq(Simulation.SAVE_VERSION, 11, "the save's version")
	assert_eq(PartyOrders.SIDE_PATHS_SAVED, SAVED, "the names the save writes")
	var pressing: Dictionary = {}
	for order: Expedition.SidePaths in [EXPLORE, PRESS_ON]:
		var sim := Simulation.new(1)
		sim.set_side_paths(order)
		run_ticks(sim, 5)
		var data: Dictionary = _through_json(sim.to_save())
		var version: int = data["version"]
		assert_eq(version, 11, "%s: saved as version 11" % SAVED[order])
		assert_eq(str(data.get("side_paths")), SAVED[order], "%s: by name" % SAVED[order])
		assert_eq(Simulation.save_problems(data).size(), 0, "%s: sound" % SAVED[order])
		var loaded: Simulation = Simulation.from_save(data)
		assert_not_null(loaded, "%s: it loads" % SAVED[order])
		if loaded != null:
			assert_eq(loaded.expedition.side_paths, order, "%s: it comes back" % SAVED[order])
		pressing = data

	# Older saves have no such order: they load at Explore.
	for version: int in [8, 4]:
		var old: Dictionary = pressing.duplicate(true)
		old["version"] = version
		old.erase("side_paths")
		if version < 5:
			old.erase("pace")
			old.erase("guardian_order")
		var problems: PackedStringArray = Simulation.save_problems(old)
		assert_eq(problems.size(), 0, "version %d is sound: %s" % [version, problems])
		var upgraded: Dictionary = Simulation.upgrade_save(old)
		var reached: int = upgraded["version"]
		assert_eq(reached, 11, "version %d comes up to 11" % version)
		assert_eq(str(upgraded.get("side_paths")), "explore", "version %d: at Explore" % version)
		var old_loaded: Simulation = Simulation.from_save(old)
		assert_not_null(old_loaded, "version %d loads" % version)
		if old_loaded != null:
			assert_eq(old_loaded.expedition.side_paths, EXPLORE, "version %d explores" % version)

	# Any other value is refused, the field named.
	for bad_value: Variant in [null, 1, "walk", "Explore", "press on", true, [], {}]:
		var bad: Dictionary = pressing.duplicate(true)
		if bad_value == null:
			bad.erase("side_paths")
		else:
			bad["side_paths"] = bad_value
		var named: bool = false
		for problem: String in Simulation.save_problems(bad):
			named = named or problem.begins_with("side_paths: ")
		assert_true(named, "%s is refused by name" % [bad_value])
		assert_null(Simulation.from_save(bad), "%s is not loaded" % [bad_value])
	assert_push_error_count(0)
	assert_engine_error_count(0)


# --- R4 ------------------------------------------------------------------------


## R4: real clicks on both choices change the simulation; the lit choice follows a change made
## by the simulation; the window is inside the screen in both rooms.
func test_r4_the_orders_window_has_the_row() -> void:
	for room: Vector2i in ROOMS:
		var what: String = "%dx%d" % [room.x, room.y]
		var main: Main = _orders_main(room)
		var ui: UiRoot = main.ui
		ui.windows.open_window(UiRoot.ORDERS)
		var window: UiWindow = ui.windows.window(UiRoot.ORDERS)
		var orders: OrdersPanel = window.content as OrdersPanel
		orders.advance(0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(orders.choice_buttons.size(), 3, "%s: three rows" % what)
		if orders.choice_buttons.size() != 3:
			main.free()
			continue
		var row: int = PartyOrders.SIDE_PATHS
		assert_eq(orders.name_labels[row].text, "Side paths", "%s: the row's name" % what)
		var texts: Array[String] = []
		for choice: UiButton in orders.choice_buttons[row]:
			texts.append(choice.text)
		assert_eq(texts, NAMES, "%s: its choices" % what)
		assert_eq(_lit_side_paths(orders), EXPLORE, "%s: Explore lit at first" % what)
		assert_eq(orders.line_labels[row].text, LINES[EXPLORE], "%s: Explore's line" % what)
		for value: int in NAMES.size():
			var worded: String = OrdersPanel.LINES[row][value]
			assert_eq(worded, LINES[value], "%s's line" % NAMES[value])
			var tip: String = OrdersPanel.tip(row, value)
			assert_true(tip.ends_with("."), "%s has a tip: %s" % [NAMES[value], tip])

		# Real clicks.
		var explore: UiButton = orders.choice_buttons[row][EXPLORE]
		var press_on: UiButton = orders.choice_buttons[row][PRESS_ON]
		await _click(press_on)
		assert_eq(_lit_side_paths(orders), PRESS_ON, "%s: Press on lit at once" % what)
		_frame(1, 0.0)
		orders.advance(0.0)
		assert_eq(_sim.expedition.side_paths, PRESS_ON, "%s: the click reached the game" % what)
		assert_eq(_lit_side_paths(orders), PRESS_ON, "%s: Press on stays lit" % what)
		assert_eq(orders.line_labels[row].text, LINES[PRESS_ON], "%s: Press on's line" % what)
		await _click(explore)
		_frame(1, 0.0)
		orders.advance(0.0)
		assert_eq(_sim.expedition.side_paths, EXPLORE, "%s: and the click on Explore" % what)
		assert_eq(_lit_side_paths(orders), EXPLORE, "%s: Explore lit again" % what)

		# A change the simulation makes itself is followed.
		_sim.set_side_paths(PRESS_ON)
		_frame(1, 0.0)
		orders.advance(0.0)
		assert_eq(_lit_side_paths(orders), PRESS_ON, "%s: the simulation's value is lit" % what)
		assert_eq(orders.line_labels[row].text, LINES[PRESS_ON], "%s: and explained" % what)

		# The window fits its place, everything in it inside it.
		window.place_at(window.default_place, Vector2(ui.room()))
		await get_tree().process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(ui.room()))
		var panel: Rect2 = window.get_global_rect()
		assert_true(screen.encloses(panel), "%s: the window on screen %s" % [what, panel])
		var frames: float = ui.world_to_ui(Vector2(0, ui.frames_top())).y
		assert_lte(panel.end.y, frames, "%s: above the hero frames %s" % [what, panel])
		assert_false(panel.intersects(ui.bar.get_global_rect()), "%s: clear of the bar" % what)
		for line: Label in orders.line_labels:
			assert_eq(line.get_line_count(), 1, "%s: '%s' on one line" % [what, line.text])
		var inside: Array[Control] = []
		inside.assign(orders.name_labels + orders.line_labels)
		for buttons: Array in orders.choice_buttons:
			for choice: UiButton in buttons:
				inside.append(choice)
		for control: Control in inside:
			var rect: Rect2 = control.get_global_rect()
			assert_true(panel.encloses(rect), "%s: %s inside the window" % [what, control.name])
			for other: Control in inside:
				if other != control and other.get_global_rect().intersects(rect):
					fail_test("%s: %s overlaps %s" % [what, control.name, other.name])
		_sim = null
		_world = null
		_fx = null
		_hud = null
		_ui = null
		main.free()


# --- R5 ------------------------------------------------------------------------


## R5: both lines.
func test_r5_the_journal_says_it() -> void:
	_make_hud(Simulation.new(1), false)
	var said: Array[String] = ["Orders: side paths, explore", "Orders: side paths, press on"]
	for order: Expedition.SidePaths in [PRESS_ON, EXPLORE]:
		var before: int = _hud.journal.lines().size()
		_sim.set_side_paths(order)
		_frame(1, 0.0)
		var lines: Array[String] = _hud.journal.lines()
		assert_eq(lines.size(), before + 1, "%s: one line more" % NAMES[order])
		var newest: String = lines[0].get_slice("  ", 1) if not lines.is_empty() else ""
		assert_eq(newest, said[order], "%s: its line" % NAMES[order])


# --- R6 ------------------------------------------------------------------------


## R6: no rising line and no journal line under Press on; the tip's added words.
func test_r6_a_sealed_gate_is_quiet() -> void:
	var found: Vector2i = _find(1, false)
	var index: int = found.y
	for order: Expedition.SidePaths in [EXPLORE, PRESS_ON]:
		var what: String = NAMES[order]
		var sim: Simulation = _ordered(found.x, order, false)
		var path: SidePath = _stand_before(sim, 1, index, 1)
		var def: GateDef = Content.gate(path.gate)
		var skill: int = Content.microskill_ids().find(def.microskill)
		_make_hud(sim, false)
		_hear_events()
		_world.side_props.follows_mouse = false
		for i: int in 12:
			_frame(1, STEP)
		assert_gt(sim.expedition.x, path.at + 1.0, "%s: the party walked past the gate" % what)
		var rising: int = 0
		for node: Node2D in _world.fx.nodes(&"quest_text"):
			rising += int((node as FxText).text == GateTip.sealed_line(skill))
		var written: int = 0
		for line: String in _hud.journal.lines():
			written += int(line.ends_with("  " + SidePathWords.sealed(def)))
		var sealed: int = _of_kind(_events, SimEvent.Kind.GATE_SEALED).size()
		var said: int = 1 if order == EXPLORE else 0
		assert_eq(sealed, said, "%s: GATE_SEALED %d times" % [what, said])
		assert_eq(rising, said, "%s: %d rising lines" % [what, said])
		assert_eq(written, said, "%s: %d journal lines" % [what, said])

		# The closed gate's tip still says what would open it.
		var props: SideProps = _world.side_props
		var gate: Sprite2D = props.gate(1, index)
		var rect := Rect2(gate.position + gate.offset, gate.texture.get_size())
		props.point_at(rect.get_center())
		assert_true(props.tip.visible, "%s: the gate has its tip" % what)
		assert_eq(props.tip.title, def.display_name, "%s: its name" % what)
		assert_eq(props.tip.who, GateTip.who_line(sim, 1, index), "%s: what would open it" % what)
		assert_string_contains(props.tip.who, "could open this", "%s: in those words" % what)
		var added: String = PRESSING if order == PRESS_ON else ""
		assert_eq(props.tip.order, added, "%s: the tip's added words" % what)
		assert_eq(props.tip.shown_lines().has(PRESSING), order == PRESS_ON, "%s: drawn" % what)

		# The order changed with the mouse resting on the gate: the words follow.
		var other: Expedition.SidePaths = EXPLORE if order == PRESS_ON else PRESS_ON
		sim.set_side_paths(other)
		_frame(1, STEP)
		_world.side_props.animate(STEP)
		var then: String = PRESSING if other == PRESS_ON else ""
		assert_eq(props.tip.order, then, "%s: the tip follows a change of the order" % what)
		_world.free()
		_fx.free()
		_hud.free()


# --- R7 ------------------------------------------------------------------------


## R7: an hour away under each order: caches and the row with Explore, neither with Press on.
func test_r7_time_away_presses_on() -> void:
	var gold: Array[int] = []
	for order: Expedition.SidePaths in [EXPLORE, PRESS_ON]:
		var what: String = NAMES[order]
		var sim: Simulation = winding_simulation(3)
		sim.set_side_paths(order)
		sim.step()
		var replay := AwayReplay.new(sim, AWAY_SECONDS)
		while not replay.run(1_000_000):
			pass
		var report: AwayReport = replay.report
		var cache_rows: int = 0
		var passed_rows: int = 0
		for row: AwayStory.Row in AwayStory.rows(report, sim.party):
			cache_rows += int(row.label.begins_with("Caches opened"))
			passed_rows += int(row.label.begins_with("Passed"))
		gold.append(report.gold_gained)
		assert_eq(sim.expedition.side_paths, order, "%s: the order holds through the hour" % what)
		if order == EXPLORE:
			assert_gt(report.caches_opened, 0, "%s: an hour away opens caches" % what)
			assert_eq(cache_rows, 1, "%s: and the report has their row" % what)
		else:
			assert_eq(report.caches_opened, 0, "%s: no cache is opened" % what)
			assert_eq(cache_rows, 0, "%s: and the report has no cache row" % what)
			assert_eq(report.gates_sealed, 0, "%s: no gate is said to be sealed" % what)
			assert_eq(passed_rows, 0, "%s: so no row of gates passed" % what)
	assert_gt(gold[EXPLORE], 0, "the hour away earned gold")

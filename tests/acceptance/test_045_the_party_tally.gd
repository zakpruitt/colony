extends GutTest
## Acceptance tests for specs/045-the-party-tally/spec.md, one per requirement.
##
## Most tests build a World on a seeded simulation with the CombatEffects and the Hud on it (on a
## CanvasLayer above GUT's window, so a pushed click reaches the HUD's buttons), every _process
## turned off, and step the simulation by hand, a tick per frame unless a test says otherwise. A
## listener on the world keeps every event the HUD was told of, so the tally can be checked against
## sums made here. R5 also runs the main scene over a save of its own, under user://, named for
## this process, and deletes it.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 45
const STEP: float = 1.0 / 60.0
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 30000
const STRONG_LEVEL: int = 40
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(320, 200)

const DAMAGE: Tally.Measure = Tally.Measure.DAMAGE
const HEALING: Tally.Measure = Tally.Measure.HEALING
const TAKEN: Tally.Measure = Tally.Measure.TAKEN
const LAST: Tally.Span = Tally.Span.LAST_FIGHT
const SESSION: Tally.Span = Tally.Span.SESSION

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## Every event the world has told of since the HUD was made, oldest first.
var _events: Array[SimEvent] = []
var _save_path: String = "user://test_045_tally_%d.save" % OS.get_process_id()


func before_each() -> void:
	_events.clear()
	_build(Simulation.new(SEED))


func after_each() -> void:
	_mouse(Vector2(-1000, -1000))
	_delete_files()


## Also after the last test: a Main with a save store saves again when GUT frees it.
func after_all() -> void:
	_delete_files()


func _delete_files() -> void:
	for path: String in [
		_save_path, _save_path + SaveStore.BACKUP_SUFFIX, _save_path + SaveStore.TEMP_SUFFIX
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# --- Helpers -------------------------------------------------------------------


func _build(simulation: Simulation) -> void:
	_sim = simulation
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	var layer := CanvasLayer.new()
	layer.layer = 129
	add_child_autofree(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_world.sim_event.connect(_on_event)
	_hud.advance(0.0)


func _on_event(event: SimEvent) -> void:
	_events.append(event)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


## Clicks the left button in the middle of [param control], as the window would.
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_mouse(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
	_mouse(AWAY)


## One frame: [param ticks] ticks of the simulation, then the world and the HUD.
func _frame(ticks: int = 1) -> void:
	for i: int in ticks:
		_sim.step()
	_world.sync(STEP)
	_hud.advance(STEP)


## Runs frames of [param ticks] ticks until [param done] returns true (true), or the limit.
func _run_until(done: Callable, ticks: int = 1, limit: int = LIMIT_TICKS) -> bool:
	var run: int = 0
	while run < limit:
		_frame(ticks)
		run += ticks
		if done.call():
			return true
	return false


func _fighting() -> bool:
	return _sim.expedition.state == Expedition.State.FIGHTING and _sim.expedition.battle != null


func _count(kind: SimEvent.Kind) -> int:
	var count: int = 0
	for event: SimEvent in _events:
		if event.kind == kind:
			count += 1
	return count


func _raise(level: int) -> void:
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


func _is_hero(id: int) -> bool:
	return id >= 0 and id < Expedition.FIRST_MONSTER_ID


## Each hero's sum of [param measure] over [param events], by hero id, as the spec defines it:
## damage dealt to monsters, healing done to heroes, damage received.
func _sums(events: Array[SimEvent], measure: Tally.Measure) -> Dictionary[int, int]:
	var sums: Dictionary[int, int] = {}
	for hero: Hero in _sim.party.heroes:
		sums[hero.id] = 0
	for event: SimEvent in events:
		var who: int = -1
		match measure:
			DAMAGE:
				if event.kind == SimEvent.Kind.HIT and not _is_hero(event.target_id):
					who = event.source_id
			HEALING:
				if event.kind == SimEvent.Kind.HEALED and _is_hero(event.target_id):
					who = event.source_id
			TAKEN:
				if event.kind == SimEvent.Kind.HIT and _is_hero(event.target_id):
					who = event.target_id
		if sums.has(who):
			sums[who] += event.amount
	return sums


## The events from the last ENCOUNTER_STARTED on (all of them if none), without hazards.
func _last_fight_events() -> Array[SimEvent]:
	var start: int = 0
	for i: int in _events.size():
		if _events[i].kind == SimEvent.Kind.ENCOUNTER_STARTED:
			start = i
	var fight: Array[SimEvent] = []
	for event: SimEvent in _events.slice(start):
		if not (event.kind == SimEvent.Kind.HIT and event.source_id < 0):
			fight.append(event)
	return fight


## The tick of the last event of [param kind], or -1.
func _last_tick(kind: SimEvent.Kind) -> int:
	for i: int in range(_events.size() - 1, -1, -1):
		if _events[i].kind == kind:
			return _events[i].tick
	return -1


## Sets the party up just before the guardian of [param depth] (as spec 030's tests do).
func _before_guardian(depth: int) -> void:
	var e: Expedition = _sim.expedition
	var shaft: LabyrinthChamber = _sim.labyrinth.level(depth).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


## Checks every hero's numbers on the panel's open measure and span against [param sums]: the
## row's number and share, the tally's own value, and the bar's scale.
func _check_rows(sums: Dictionary[int, int], what: String) -> void:
	var tally: TallyPanel = _hud.tally
	var heroes: Array[Hero] = _sim.party.heroes
	var rows: Array[String] = tally.rows()
	var largest: int = 0
	var total: int = 0
	for hero: Hero in heroes:
		largest = maxi(largest, sums[hero.id])
		total += sums[hero.id]
	var percent_sum: int = 0
	for i: int in heroes.size():
		var hero: Hero = heroes[i]
		var value: int = sums[hero.id]
		var who: String = hero.def().display_name
		assert_eq(
			tally.tally.value(hero.id, tally.measure(), tally.span()), value, "%s: %s" % [what, who]
		)
		var row: String = rows[i + 1]
		var parts: PackedStringArray = row.split(" ")
		assert_eq(parts[0], who, "%s: row %d is the %s" % [what, i, who])
		assert_eq(parts[1], Hud.group_thousands(value), "%s: %s's number" % [what, who])
		var percent: int = parts[2].trim_suffix("%").to_int()
		percent_sum += percent
		if total > 0:
			var share: float = 100.0 * value / total
			assert_almost_eq(float(percent), share, 1.0, "%s: %s's share" % [what, who])
		var scale: float = float(value) / largest if largest > 0 else 0.0
		assert_almost_eq(tally.bar_goal(hero.id), scale, 0.0001, "%s: %s's bar" % [what, who])
	assert_eq(percent_sum, 100 if total > 0 else 0, "%s: the shares sum to 100%%" % what)


## Opens [param panel] by its own way in, with the tally open, and back.
func _check_exclusion(panel: String, opening: Callable, is_open: Callable) -> void:
	var tally: TallyPanel = _hud.tally
	tally.open()
	opening.call()
	_hud.advance(STEP)
	var other: bool = is_open.call()
	assert_true(other, "%s opens over the tally" % panel)
	assert_false(tally.is_open(), "the %s closes the tally" % panel)
	opening.call()
	_hud.advance(STEP)
	tally.open()
	_hud.advance(STEP)
	other = is_open.call()
	assert_true(tally.is_open(), "the tally opens over the %s" % panel)
	assert_false(other, "the tally closes the %s" % panel)
	tally.close()


# --- R1 ------------------------------------------------------------------------


func test_r1_tally_panel() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	assert_false(tally.is_open(), "closed at first")
	_key(KEY_T)
	assert_true(tally.is_open(), "T opens it")
	_key(KEY_T)
	assert_false(tally.is_open(), "T closes it")
	_click(_hud.tally_button)
	assert_true(tally.is_open(), "the button opens it")
	_hud.advance(STEP)
	assert_true(_hud.tally_button.lit, "the button is lit while it is open")
	_click(_hud.tally_button)
	assert_false(tally.is_open(), "the button closes it")
	tally.open()
	_key(KEY_ESCAPE)
	assert_false(tally.is_open(), "Esc closes it")

	# The heroes in party order, with the portraits the frames show.
	tally.open()
	_hud.advance(STEP)
	var rows: Array[String] = tally.rows()
	var heroes: Array[Hero] = _sim.party.heroes
	assert_eq(rows.size(), heroes.size() + 1, "a fight line and a row per hero: %s" % [rows])
	assert_eq(tally.portraits.size(), heroes.size(), "a portrait per hero")
	for i: int in heroes.size():
		var who: String = heroes[i].def().display_name
		assert_true(rows[i + 1].begins_with(who + " "), "row %d is the %s: %s" % [i, who, rows])
		assert_eq(tally.portraits[i].texture, _hud.icon(heroes[i].class_id), "%s's portrait" % who)
		assert_eq(
			tally.portraits[i].texture, _hud.frames[i].icon.texture, "as frame %d shows it" % i
		)
	tally.close()

	# Never with the sheet, the journal, the shop, the orders or help, either way round.
	var hero: int = heroes[0].id
	_check_exclusion("hero sheet", _hud.hero_sheet.open.bind(hero), _hud.hero_sheet.is_open)
	_check_exclusion("journal", _hud.journal.open, _hud.journal.is_open)
	_check_exclusion("shop", _hud.shop.open, _hud.shop.is_open)
	_check_exclusion("orders", _hud.orders.open, _hud.orders.is_open)
	_check_exclusion("help", _hud.help.open, _hud.help.is_open)
	# The keys of the others open them over the tally too.
	for pair: Array in [[KEY_J, _hud.journal.is_open], [KEY_U, _hud.shop.is_open]]:
		var code: Key = pair[0]
		var other: Callable = pair[1]
		tally.open()
		_key(code)
		_hud.advance(STEP)
		var opened: bool = other.call()
		assert_true(opened, "key %d opens its panel" % code)
		assert_false(tally.is_open(), "key %d closes the tally" % code)
		_key(KEY_ESCAPE)
		_hud.shop.close()
		_hud.journal.close()


# --- R2 ------------------------------------------------------------------------


func test_r2_three_measures() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	# Play until two fights are over and the healer has healed.
	var primed: Callable = func() -> bool:
		var healed: int = 0
		for event: SimEvent in _events:
			if event.kind == SimEvent.Kind.HEALED:
				healed += event.amount
		return (
			_count(SimEvent.Kind.ENCOUNTER_ENDED) >= 2
			and healed > 0
			and _sim.expedition.state != Expedition.State.FIGHTING
		)
	assert_true(_run_until(primed), "two fights and some healing")
	tally.open()
	tally.set_span(SESSION)
	var names: Array[String] = ["Damage", "Healing", "Taken"]
	for measure: Tally.Measure in [DAMAGE, HEALING, TAKEN]:
		_click(tally.tab_buttons[measure])
		_hud.advance(STEP)
		assert_eq(tally.measure(), measure, "the %s tab opens %s" % [names[measure], measure])
		for i: int in tally.tab_buttons.size():
			assert_eq(tally.tab_buttons[i].lit, i == measure, "only the open tab is lit")
		_check_rows(_sums(_events, measure), "%s, session" % names[measure])
	# Healing counts only what the heroes gained: the simulation's HEALED amount stops at full
	# health, so overhealing is never in it.
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.HEALED:
			assert_true(event.amount >= 0, "a heal's amount is what was restored")
	# Q and E move between the tabs, wrapping.
	tally.set_measure(DAMAGE)
	_key(KEY_E)
	assert_eq(tally.measure(), HEALING, "E: the next tab")
	_key(KEY_Q)
	_key(KEY_Q)
	assert_eq(tally.measure(), TAKEN, "Q: the previous tab, wrapping")
	assert_false(_hud.hero_sheet.is_open(), "Q and E leave the hero sheet alone")


# --- R3 ------------------------------------------------------------------------


func test_r3_two_spans() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	# Note each fight's monsters and depth as it starts.
	var fights: Array[Dictionary] = []
	var note: Callable = func(event: SimEvent) -> void:
		if event.kind == SimEvent.Kind.ENCOUNTER_STARTED:
			var met: Array[StringName] = []
			for monster: Combatant in _sim.expedition.battle.monsters:
				met.append(monster.def_id)
			fights.append({"depth": _sim.expedition.depth, "kinds": met})
	_world.sim_event.connect(note)
	var two: Callable = func() -> bool:
		return _count(SimEvent.Kind.ENCOUNTER_ENDED) >= 2 and not _fighting()
	assert_true(_run_until(two), "two fights")
	tally.open()
	tally.set_measure(DAMAGE)
	tally.set_span(LAST)
	_hud.advance(STEP)
	assert_eq(tally.span(), LAST)
	_check_rows(_sums(_last_fight_events(), DAMAGE), "last fight")
	var last: Dictionary[int, int] = _sums(_last_fight_events(), DAMAGE)
	var session: Dictionary[int, int] = _sums(_events, DAMAGE)
	var differs: bool = false
	for id: int in last:
		differs = differs or last[id] != session[id]
	assert_true(differs, "the last fight is not the session")
	# Healing and Taken on the last fight too (spec 046 R10).
	for measure: Tally.Measure in [HEALING, TAKEN]:
		tally.set_measure(measure)
		_hud.advance(STEP)
		_check_rows(_sums(_last_fight_events(), measure), "last fight, measure %d" % measure)
	tally.set_measure(DAMAGE)
	_hud.advance(STEP)
	# The fight's line: what was fought, where and for how long.
	var fight: Dictionary = fights[-1]
	var seconds: int = roundi(
		(
			float(
				(
					_last_tick(SimEvent.Kind.ENCOUNTER_ENDED)
					- _last_tick(SimEvent.Kind.ENCOUNTER_STARTED)
				)
			)
			/ Simulation.TICKS_PER_SECOND
		)
	)
	var line: String = tally.rows()[0]
	assert_true(line.begins_with("Last fight: "), line)
	assert_true(line.ends_with(", depth %d, %d s" % [fight["depth"], seconds]), line)
	var kinds: Array[StringName] = fight["kinds"]
	var counts: Dictionary[StringName, int] = {}
	for kind: StringName in kinds:
		counts[kind] = counts.get(kind, 0) + 1
	if counts.size() == 1:
		var only: StringName = counts.keys()[0]
		var named: String = Content.monster(only).display_name.to_lower()
		var phrase: String = "%d %s%s" % [kinds.size(), named, "s" if kinds.size() > 1 else ""]
		assert_eq(line, "Last fight: %s, depth %d, %d s" % [phrase, fight["depth"], seconds])
	else:
		var all_named: bool = true
		for kind: StringName in counts:
			all_named = all_named and line.contains(Content.monster(kind).display_name.to_lower())
		assert_true(all_named or line.contains("%d monsters" % kinds.size()), line)
	# Session: every fight together, and the line says so.
	_click(tally.span_buttons[SESSION])
	_hud.advance(STEP)
	assert_eq(tally.span(), SESSION, "the Session switch")
	assert_true(tally.span_buttons[SESSION].lit and not tally.span_buttons[LAST].lit)
	_check_rows(session, "session")
	var fought: int = _count(SimEvent.Kind.ENCOUNTER_STARTED)
	assert_true(tally.rows()[0].begins_with("Session: %d fights" % fought), tally.rows()[0])
	_click(tally.span_buttons[LAST])
	assert_eq(tally.span(), LAST, "the Last fight switch")

	# A guardian: named, and the current fight while it lasts.
	_before_guardian(5)
	_raise(STRONG_LEVEL)
	var guardian: String = Content.monster(_sim.expedition.guardian_of(5)).display_name
	var meeting: Callable = func() -> bool:
		return _fighting() and _sim.tick - _last_tick(SimEvent.Kind.ENCOUNTER_STARTED) >= 15
	assert_true(_run_until(meeting), "a guardian fight")
	var now: int = roundi(
		float(_sim.tick - _last_tick(SimEvent.Kind.ENCOUNTER_STARTED)) / Simulation.TICKS_PER_SECOND
	)
	assert_eq(tally.rows()[0], "This fight: the %s, depth 5, %d s" % [guardian, now])
	_check_rows(_sums(_last_fight_events(), DAMAGE), "the fight under way")
	assert_true(_run_until(func() -> bool: return not _fighting()), "the guardian fight ends")
	var lasted: int = roundi(
		(
			float(
				(
					_last_tick(SimEvent.Kind.ENCOUNTER_ENDED)
					- _last_tick(SimEvent.Kind.ENCOUNTER_STARTED)
				)
			)
			/ Simulation.TICKS_PER_SECOND
		)
	)
	assert_eq(tally.rows()[0], "Last fight: the %s, depth 5, %d s" % [guardian, lasted])
	_world.sim_event.disconnect(note)

	# A lost fight: after the wipe and the revival it is still the last fight (spec 046 R10).
	var started: int = _count(SimEvent.Kind.ENCOUNTER_STARTED)
	var next: Callable = func() -> bool:
		return _fighting() and _count(SimEvent.Kind.ENCOUNTER_STARTED) > started
	assert_true(_run_until(next), "another fight")
	var struck: Callable = func() -> bool:
		return _sums(_last_fight_events(), DAMAGE).values().max() > 0 or not _fighting()
	assert_true(_run_until(struck), "blows are struck")
	assert_true(_fighting(), "still fighting")
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	var up: Callable = func() -> bool:
		return _count(SimEvent.Kind.PARTY_REVIVED) > 0 and not _fighting()
	assert_true(_run_until(up), "wiped and revived")
	assert_eq(_count(SimEvent.Kind.ENCOUNTER_STARTED), started + 1, "no fight since")
	_hud.advance(STEP)
	assert_true(tally.rows()[0].begins_with("Last fight: "), tally.rows()[0])
	for measure: Tally.Measure in [DAMAGE, HEALING, TAKEN]:
		tally.set_measure(measure)
		_hud.advance(STEP)
		_check_rows(_sums(_last_fight_events(), measure), "the lost fight, measure %d" % measure)
	var lost: Dictionary[int, int] = _sums(_last_fight_events(), DAMAGE)
	var most: int = lost.values().max()
	assert_gt(most, 0, "the lost fight's damage")


# --- R4 ------------------------------------------------------------------------


func test_r4_side_quests_count() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	tally.open()
	tally.set_span(SESSION)
	_hud.advance(STEP)
	assert_eq(tally.rows().size(), _sim.party.heroes.size() + 1, "no quest lines before any")
	# A party that can do every side quest walks the first depths until two are done.
	_raise(STRONG_LEVEL)
	var two: Callable = func() -> bool: return _count(SimEvent.Kind.SIDE_QUEST_DONE) >= 2
	assert_true(_run_until(two, 10, 200000), "two side quests done")
	_hud.advance(STEP)
	var done: Dictionary[int, int] = {}
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.SIDE_QUEST_DONE:
			done[event.source_id] = done.get(event.source_id, 0) + 1
	var wanted: Array[String] = []
	for hero: Hero in _sim.party.heroes:
		var count: int = done.get(hero.id, 0)
		assert_eq(tally.tally.side_quests(hero.id), count, "%s" % hero.class_id)
		if count > 0:
			var noun: String = "side quest" if count == 1 else "side quests"
			wanted.append("%s: %d %s" % [hero.def().display_name, count, noun])
	var rows: Array[String] = tally.rows()
	assert_eq(rows.slice(_sim.party.heroes.size() + 1), wanted, "a line per hero with any")
	assert_lt(done.size(), _sim.party.heroes.size(), "some hero did none, and has no line")


# --- R5 ------------------------------------------------------------------------


func test_r5_updates_live() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	tally.open()
	tally.set_measure(DAMAGE)
	tally.set_span(LAST)
	for speed: int in [1, 4]:
		_world.speed = speed
		var started: int = _count(SimEvent.Kind.ENCOUNTER_STARTED)
		var fight: Callable = func() -> bool:
			return _fighting() and _count(SimEvent.Kind.ENCOUNTER_STARTED) > started
		assert_true(_run_until(fight, speed), "a fight at %dx" % speed)
		var before: Array[String] = tally.rows()
		var bars: Array[float] = []
		for hero: Hero in _sim.party.heroes:
			bars.append(tally.bar_fraction(hero.id))
		var moved: Callable = func() -> bool:
			return tally.rows() != before and _sums(_last_fight_events(), DAMAGE).values().max() > 0
		assert_true(
			_run_until(moved, speed, 600), "the rows change during the fight at %dx" % speed
		)
		assert_true(_fighting(), "still fighting at %dx" % speed)
		_check_rows(_sums(_last_fight_events(), DAMAGE), "during a fight at %dx" % speed)
		for i: int in 30:
			_frame(speed)
			if not _fighting():
				break
		var changed: bool = false
		for i: int in _sim.party.heroes.size():
			changed = changed or tally.bar_fraction(_sim.party.heroes[i].id) != bars[i]
		assert_true(changed, "the bars move at %dx" % speed)
		assert_true(tally.is_open(), "still open at %dx" % speed)


func test_r5_nothing_from_time_away() -> void:
	var played := Simulation.new(Main.SIMULATION_SEED)
	for i: int in 3000:
		played.step()
	played.drain_events()
	var data: Dictionary = played.to_save()
	data[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system()
	assert_true(SaveStore.new(_save_path).write(data), "the test's save was written")
	var main: Main = MAIN_SCENE.instantiate()
	main.save_store = SaveStore.new(_save_path)
	main.away_seconds_override = 600.0
	# Time stands still once the replay ends: the driver is stopped as soon as it is made.
	main.child_entered_tree.connect(
		func(node: Node) -> void:
			if node is SimDriver:
				node.ready.connect(func() -> void: node.set_process(false))
	)
	add_child_autofree(main)
	await wait_until(func() -> bool: return not main.is_catching_up(), 60.0, "replay ends")
	await wait_process_frames(2)
	assert_not_null(main.away_report, "there was time away")
	if main.away_report == null or main.hud == null:
		return
	assert_gt(main.away_report.kills, 0, "the party fought while away")
	var tally: TallyPanel = main.hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	assert_eq(tally.tally.fights(), 0, "no fight from the time away")
	for hero: Hero in main.simulation.party.heroes:
		for measure: Tally.Measure in [DAMAGE, HEALING, TAKEN]:
			for span: Tally.Span in [LAST, SESSION]:
				assert_eq(tally.tally.value(hero.id, measure, span), 0, "%s" % hero.class_id)
		assert_eq(tally.tally.side_quests(hero.id), 0, "%s's side quests" % hero.class_id)


# --- R6 ------------------------------------------------------------------------


## The sentence the tooltip shows after the mouse rests on [param control].
func _tip_of(control: Control) -> String:
	_hud.tooltip.point_at(AWAY)
	_hud.advance(1.0)
	_hud.tooltip.point_at(control.get_global_rect().get_center())
	_hud.advance(0.2)
	_hud.advance(0.25)
	return _hud.tooltip.shown_text()


func test_r6_explains_itself() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	tally.open()
	_hud.advance(STEP)
	var seen: Dictionary[String, bool] = {}
	var controls: Array[Control] = []
	controls.assign(tally.tab_buttons + tally.span_buttons)
	controls.append(_hud.tally_button)
	for control: Control in controls:
		var text: String = _tip_of(control)
		assert_ne(text, "", "%s has a tooltip" % control.name)
		assert_true(text.ends_with("."), "%s: a sentence: %s" % [control.name, text])
		assert_false(
			text.trim_suffix(".").contains(". "), "%s: only one: %s" % [control.name, text]
		)
		assert_false(seen.has(text), "%s says what another says" % control.name)
		seen[text] = true
		var box: Rect2 = _hud.tooltip.box.get_global_rect()
		assert_false(box.intersects(control.get_global_rect()), "%s: not covered" % control.name)
	# T is in the help panel's list, and spec 030's test presses it.
	var listed: bool = false
	for entry: Array in HelpPanel.KEYS:
		listed = listed or HelpPanel.keycodes(str(entry[0])).has(KEY_T)
	assert_true(listed, "T is in the help panel's keys")
	var source: String = FileAccess.get_file_as_string(
		"res://tests/acceptance/test_030_help_and_hints.gd"
	)
	assert_true(source.contains('"T":'), "spec 030's test has a case for T")


# --- R7 ------------------------------------------------------------------------


func test_r7_fits_and_changes_nothing() -> void:
	var tally: TallyPanel = _hud.tally
	assert_not_null(tally, "the HUD has a tally")
	if tally == null:
		return
	tally.open()
	_hud.advance(STEP)
	var rect: Rect2 = tally.get_global_rect()
	assert_true(rect.size.x <= HeroSheet.SIZE.x and rect.size.y <= HeroSheet.SIZE.y, "%s" % rect)
	assert_true(rect.position.y >= TOP_BAND, "below the top band: %s" % rect)
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(rect), "on the screen")
	for frame: HeroFrame in _hud.frames:
		assert_false(rect.intersects(frame.get_global_rect()), "clear of %s" % frame.name)
		assert_false(
			_hud.tally_button.get_global_rect().intersects(frame.get_global_rect()),
			"the button is beside %s, not on it" % frame.name
		)
	var button: Rect2 = _hud.tally_button.get_global_rect()
	assert_true(button.position.y >= SCREEN.y - Hud.BOTTOM_BAND, "the button is in the bottom band")
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(button), "the button is on the screen")
	# The game runs behind it, and its state is the same open, closed or not drawn at all.
	var bare := Simulation.new(SEED)
	var closed := Simulation.new(SEED)
	var shown: Simulation = _sim
	var shown_world: World = _world
	var shown_hud: Hud = _hud
	var tick_before: int = shown.tick
	_build(closed)
	var closed_hud: Hud = _hud
	var closed_world: World = _world
	for i: int in 3000:
		bare.step()
		closed.step()
		shown.step()
		for world: World in [shown_world, closed_world]:
			world.sync(STEP)
		shown_hud.advance(STEP)
		closed_hud.advance(STEP)
		if i % 500 == 499:
			assert_eq(shown.state_hash(), bare.state_hash(), "open, tick %d" % shown.tick)
			assert_eq(closed.state_hash(), bare.state_hash(), "closed, tick %d" % closed.tick)
	assert_gt(shown.tick, tick_before, "the game ran behind the panel")
	assert_true(tally.is_open(), "the panel stayed open")

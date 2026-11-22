extends "res://tests/support/side_path_fixture.gd"
## Spec 095: gates and caches in words. The journal and the ticker, the tally, the away report,
## the microskill goal and the status line tell of side paths, each from the events it hears.

## A level at which every hero has every microskill of its class.
const SKILLED: int = 12
## What the journal says of each gate opened, and the status while it is worked.
const OPENED: Dictionary[StringName, String] = {
	&"locked_gate": "The Rogue picked a lock",
	&"rubble": "The Knight cleared the rubble",
	&"rune_seal": "The Mage read a rune seal",
	&"hidden_crack": "The Rogue found a hidden crack",
}
const WORKING: Dictionary[StringName, String] = {
	&"locked_gate": "Picking a lock",
	&"rubble": "Clearing rubble",
	&"rune_seal": "Reading a rune seal",
	&"hidden_crack": "Searching a crack",
}
const EXPLORING: String = "Exploring a side path"
## Each gate passed more than once, and who it needs, as the away report says them.
const PASSED: Dictionary[StringName, String] = {
	&"locked_gate": "Passed %d locked gates: needs a Lockpicker",
	&"rubble": "Passed rubble %d times: needs a Strongarm",
	&"rune_seal": "Passed %d rune seals: needs a Runereader",
	&"hidden_crack": "Passed %d hidden cracks: needs a Trapspotter",
}
const AWAY_SECONDS: float = 3600.0

## The gate ids as the data has them, while a test has added one; empty otherwise.
var _real_gates: Array = []
var _added_gate: StringName = &""


func after_each() -> void:
	if _added_gate != &"":
		Content._defs[Content.Kind.GATES].erase(_added_gate)
		Content._ids[Content.Kind.GATES] = _real_gates
		_added_gate = &""
	super()


## A winding game with its party at [param level], stood a step before the first side path of
## stage 1, that path's gate made [param gate]; the HUD over it, every event heard from here.
func _at_gate(gate: StringName, level: int, seed_value: int = 1) -> SidePath:
	_sim = winding_simulation(seed_value)
	if level > 1:
		raise_party(_sim, level)
	var path: SidePath = _stand_before(_sim, 1, 0, 1)
	path.gate = gate
	_make_hud(_sim)
	_hear_events()
	return path


## Plays until [param count] events of [param kind] have been heard.
func _until_heard(kind: SimEvent.Kind, count: int = 1, ticks: int = 1500) -> bool:
	return _step_until(func() -> bool: return _of_kind(_events, kind).size() >= count, ticks)


## Plays until the party is back on the main course with [param count] caches opened.
func _until_back(count: int) -> bool:
	var back: Callable = func() -> bool:
		var opened: int = _of_kind(_events, SimEvent.Kind.CACHE_OPENED).size()
		return opened >= count and _sim.expedition.side_path < 0
	return _step_until(back, 1500)


## How many times the gate at [param gate] in the data's list was said to be sealed.
func _said_sealed(gate: int) -> int:
	var count: int = 0
	for event: SimEvent in _of_kind(_events, SimEvent.Kind.GATE_SEALED):
		count += 1 if event.target_id == gate else 0
	return count


## How many of the journal's lines say [param sentence].
func _told(sentence: String) -> int:
	var count: int = 0
	for line: String in _hud.journal.lines():
		if line.ends_with("  " + sentence):
			count += 1
	return count


## The gains of the caches opened in [param events], summed: gold, every hero's XP, one hero's
## XP at the last cache, and each resource by id.
func _paid(events: Array[SimEvent]) -> Paid:
	var ticks: Dictionary[int, bool] = {}
	for event: SimEvent in _of_kind(events, SimEvent.Kind.CACHE_OPENED):
		ticks[event.tick] = true
	var paid := Paid.new()
	for event: SimEvent in events:
		if not ticks.has(event.tick):
			continue
		match event.kind:
			SimEvent.Kind.GOLD_GAINED:
				paid.gold += event.amount
			SimEvent.Kind.XP_GAINED:
				paid.xp += event.amount
				paid.xp_each = event.amount
			SimEvent.Kind.RESOURCE_GAINED:
				var id: StringName = Content.resource_ids()[event.target_id]
				paid.resources[id] = paid.resources.get(id, 0) + event.amount
	return paid


## [param paid] as the tally words it: "+240 gold, +18 glowcaps, 80 XP".
func _sums(paid: Paid) -> String:
	var parts: Array[String] = ["+%s gold" % UiFormat.group_thousands(paid.gold)]
	for id: StringName in Content.resource_ids():
		if paid.resources.has(id):
			parts.append("+%d %s" % [paid.resources[id], Content.resource_def(id).plural])
	parts.append("%s XP" % UiFormat.group_thousands(paid.xp))
	return ", ".join(parts)


## The microskill goal as the goals have it now, or "".
func _skill_goal() -> String:
	var found: Array[String] = []
	for goal: Goals.Goal in _hud.goals.applicable():
		if goal.kind == Goals.Kind.MICROSKILL:
			found.append(goal.sentence)
	assert_lt(found.size(), 2, "the goals have one microskill row at most")
	return found[0] if not found.is_empty() else ""


## Puts [param def] among the gates the data has, until the test ends.
func _add_gate(def: GateDef) -> void:
	_real_gates = Content.gate_ids()
	var ids: Array[StringName] = []
	ids.assign(_real_gates)
	ids.append(def.id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	Content._defs[Content.Kind.GATES][def.id] = def
	Content._ids[Content.Kind.GATES] = ids
	_added_gate = def.id


# --- R1 ------------------------------------------------------------------------


## R1: the journal writes a line for each gate opened, one for what a cache paid and one for a
## gate nobody could open, once for each GATE_SEALED; the ticker shows the newest.
func test_r1_the_journal_tells_each_gate_and_cache() -> void:
	var example := CacheReader.Pay.new()
	example.gold = 120
	example.resource = &"clay"
	example.resource_amount = 9
	example.xp_each = 40
	assert_eq(
		SidePathWords.cache(example),
		"Cache: +120 gold, +9 clay, 40 XP each",
		"a cache's line, as the spec words it"
	)
	for gate: StringName in OPENED:
		_at_gate(gate, SKILLED)
		assert_true(_until_heard(SimEvent.Kind.GATE_OPENED), "%s: the gate is opened" % gate)
		assert_eq(_told(OPENED[gate]), 1, "%s: one line for the gate" % gate)
		assert_eq(_hud.journal.ticker_text(), OPENED[gate], "%s: and the ticker shows it" % gate)
		assert_eq(_hud.ticker.label.text, OPENED[gate], "%s: on the screen" % gate)

		assert_true(_until_heard(SimEvent.Kind.CACHE_OPENED), "%s: the cache is opened" % gate)
		var paid: Paid = _paid(_events)
		var area: AreaDef = Content.area(_sim.expedition.place)
		var held: int = paid.resources.get(area.resource, 0)
		assert_gt(paid.gold, 0, "%s: the cache paid gold" % gate)
		assert_gt(held, 0, "%s: the area's resource" % gate)
		assert_gt(paid.xp_each, 0, "%s: and XP" % gate)
		var line: String = (
			"Cache: +%d gold, +%d %s, %d XP each"
			% [paid.gold, held, Content.resource_def(area.resource).plural, paid.xp_each]
		)
		assert_eq(_told(line), 1, "%s: one line, '%s', its amounts the events'" % [gate, line])
		assert_eq(_hud.journal.ticker_text(), line, "%s: the ticker shows the cache's line" % gate)
		assert_true(_until_back(1), "%s: the party comes back" % gate)
		assert_eq(_told(OPENED[gate]) + _told(line), 2, "%s: and nothing is told twice" % gate)

	# A gate nobody can open: once for each time the simulation says so.
	var sealed: String = "A rune seal: needs a Runereader"
	_at_gate(&"rune_seal", 1)
	_keep_unskilled(_sim)
	var rune_seal: int = Content.gate_ids().find(&"rune_seal")
	_step_until(func() -> bool: return false, 10)
	assert_eq(_said_sealed(rune_seal), 1, "the party walked past a rune seal")
	assert_eq(_told(sealed), 1, "and the journal says so once")
	assert_eq(_hud.journal.ticker_text(), sealed, "in the ticker too")
	_stand_before(_sim, 1, 0, -1, 1.5, false)
	_step_until(func() -> bool: return false, 10)
	assert_eq(_said_sealed(rune_seal), 1, "passing it again says nothing")
	assert_eq(_told(sealed), 1, "and writes nothing")
	_stand_before(_sim, 1, 0, 1)
	_step_until(func() -> bool: return false, 10)
	assert_eq(_said_sealed(rune_seal), 2, "arriving on the stage again, it is said again")
	assert_eq(_told(sealed), 2, "and written again")


# --- R2 ------------------------------------------------------------------------


## R2: the tally counts gates opened, caches opened and what the caches paid, for the session
## and by area.
func test_r2_the_tally_counts_side_paths() -> void:
	var areas: Array[StringName] = Content.area_ids()
	_sim = winding_simulation(2)
	var e: Expedition = _sim.expedition
	raise_party(_sim, SKILLED)
	_stand_before(_sim, 1, 0, 1)
	_make_hud(_sim)
	_hear_events()
	assert_true(_until_back(1), "a first cache")
	var first: Array[SimEvent] = _events.duplicate()
	_stand_before(_sim, 2, 0, 1)
	assert_true(_until_back(2), "a second, on the next stage")
	var here: Array[SimEvent] = _events.duplicate()
	e.travel.open[areas[1]] = true
	_sim.set_destination(areas[1], 1)
	assert_true(_step_until(func() -> bool: return e.place == areas[1], 600), "to the next area")
	_stand_before(_sim, 1, 0, 1)
	assert_true(_until_back(3), "and a third cache there")
	var there: Array[SimEvent] = _events.slice(here.size())

	var counted: SidePathTally = _hud.tally.tally.side_paths
	var parts: Dictionary[StringName, Array] = {&"": _events, areas[0]: here, areas[1]: there}
	for area: StringName in parts:
		var events: Array[SimEvent] = []
		events.assign(parts[area])
		var paid: Paid = _paid(events)
		var what: String = "in every area" if area == &"" else "in %s" % area
		var gates: int = _of_kind(events, SimEvent.Kind.GATE_OPENED).size()
		var caches: int = _of_kind(events, SimEvent.Kind.CACHE_OPENED).size()
		assert_eq(caches, 3 if area == &"" else (2 if area == areas[0] else 1), what)
		assert_eq(counted.count(SidePathTally.Count.GATES, area), gates, "gates opened " + what)
		assert_eq(counted.count(SidePathTally.Count.CACHES, area), caches, "caches opened " + what)
		assert_eq(counted.count(SidePathTally.Count.GOLD, area), paid.gold, "their gold " + what)
		assert_eq(counted.count(SidePathTally.Count.XP, area), paid.xp, "their XP " + what)
		assert_eq(counted.resources(area), paid.resources, "their resources " + what)
	assert_gt(_paid(first).gold, 0, "a cache pays gold")
	assert_eq(counted.resources().size(), 2, "two areas' caches gave two resources")

	# The window says it, for the session: the whole, then each area.
	_hud.tally.open()
	_hud.tally.set_span(Tally.Span.SESSION)
	_hud.advance(STEP)
	var rows: Array[String] = _hud.tally.rows()
	var want: Array[String] = [
		"Side paths: 3 gates, 3 caches",
		_sums(_paid(_events)),
		"%s: 2 gates, 2 caches" % Content.area(areas[0]).display_name,
		_sums(_paid(here)),
		"%s: 1 gate, 1 cache" % Content.area(areas[1]).display_name,
		_sums(_paid(there)),
	]
	assert_eq(_hud.tally.side_path_rows(), want, "the side paths' lines")
	for line: String in want:
		assert_has(rows, line, "the session's rows hold '%s'" % line)
	_hud.tally.set_span(Tally.Span.LAST_FIGHT)
	_hud.advance(STEP)
	assert_eq(_hud.tally.side_path_rows().size(), 0, "the last fight's rows have none of them")


# --- R3 ------------------------------------------------------------------------


## R3: the report after an hour away has a row for the caches opened and one naming the kind of
## gate passed most often for want of a skill; what the caches paid is in its totals; and a
## party that met no side path has neither row.
func test_r3_the_away_report_tells_of_caches_and_sealed_gates() -> void:
	var replay := AwayReplay.new(winding_simulation(3), AWAY_SECONDS)
	while not replay.run(1_000_000):
		pass
	var report: AwayReport = replay.report
	var stepped: Simulation = winding_simulation(3)
	var gold_before: int = stepped.party.gold
	var events: Array[SimEvent] = run_ticks(stepped, replay.total_ticks)
	var caches: int = _of_kind(events, SimEvent.Kind.CACHE_OPENED).size()
	var passed: Dictionary[int, int] = {}
	var most: int = -1
	for event: SimEvent in _of_kind(events, SimEvent.Kind.GATE_SEALED):
		passed[event.target_id] = passed.get(event.target_id, 0) + 1
	for gate: int in passed:
		if most < 0 or passed[gate] > passed[most]:
			most = gate
	assert_gt(caches, 0, "an hour on winding stages opens caches")
	assert_gt(most, -1, "and passes gates nobody can open yet")
	if caches == 0 or most < 0:
		return
	assert_gt(passed[most], 1, "one kind more than once")
	var gate_id: StringName = Content.gate_ids()[most]
	var rows: Array[AwayStory.Row] = AwayStory.rows(report, stepped.party)
	var texts: Array[String] = []
	for row: AwayStory.Row in rows:
		texts.append(row.text())
	assert_eq(report.caches_opened, caches, "the report counts the caches")
	assert_has(texts, "Caches opened %d" % caches, "and has their row")
	assert_has(texts, PASSED[gate_id] % passed[most], "and the gate passed most often")

	var cache_gold: int = _paid(events).gold
	var gathered: Dictionary[StringName, int] = {}
	for event: SimEvent in _of_kind(events, SimEvent.Kind.RESOURCE_GAINED):
		var id: StringName = Content.resource_ids()[event.target_id]
		gathered[id] = gathered.get(id, 0) + event.amount
	assert_gt(cache_gold, 0, "the caches paid gold")
	assert_eq(report.gold_gained, stepped.party.gold - gold_before, "which the gold counts")
	assert_eq(report.resources_gained, gathered, "as the resources count the caches'")

	# A party that meets no side path: stages with none.
	var plain := AwayReplay.new(Simulation.new(3), 600.0)
	while not plain.run(1_000_000):
		pass
	assert_eq(plain.report.caches_opened, 0, "no cache on a stage with no side path")
	for row: AwayStory.Row in AwayStory.rows(plain.report, stepped.party):
		assert_false(row.label.begins_with("Caches opened"), "so no row of caches")
		assert_false(row.label.begins_with("Passed"), "and none of a gate passed")


# --- R4 ------------------------------------------------------------------------


## R4: after a gate is passed for want of a skill a hero will learn, the microskill goal names
## that skill and what it opens; with no such gate, or no hero to learn it, it is as it was.
func test_r4_the_goal_names_the_gate_a_skill_would_open() -> void:
	var plain: String = "Rogue learns Lockpicker at level 2"
	var pointed: String = "Mage learns Runereader at level 4: opens rune seals"
	_at_gate(&"rune_seal", 1)
	var e: Expedition = _sim.expedition
	assert_eq(_skill_goal(), plain, "before any gate, the nearest microskill")
	assert_true(_until_heard(SimEvent.Kind.GATE_SEALED, 1, 20), "the party passes a rune seal")
	assert_eq(_skill_goal(), pointed, "the goal names the skill that opens it")
	var mage: Hero = _hero_of(&"mage")
	var shown: Goals.Goal = null
	for goal: Goals.Goal in _hud.goals.applicable():
		if goal.kind == Goals.Kind.MICROSKILL:
			shown = goal
	assert_eq(shown.hero_id, mage.id, "it is the Mage's row")
	assert_eq(shown.key, "skill/%d/runereader" % mage.id, "the row a microskill has always had")
	assert_eq(shown.done, "Goal: Mage learned Runereader", "and its line when learned")

	# On to another stage: the gate is behind, and the goal is as it was.
	e.x = _sim.labyrinth.level(1).course.exit - 0.5
	e.facing = 1
	_sim.set_target_depth(2)
	assert_true(_step_until(func() -> bool: return e.depth == 2, 300), "on to stage 2")
	if _of_kind(_events, SimEvent.Kind.GATE_SEALED).size() == 1:
		assert_eq(_skill_goal(), plain, "no such gate on this stage: the goal as it was")

	# The one hero who could has learned it and lies dead: nobody will learn it.
	_sim = winding_simulation(1)
	var dead: Hero = _hero_of(&"mage")
	raise(dead, SKILLED)
	dead.health = 0
	var path: SidePath = _stand_before(_sim, 1, 0, 1)
	path.gate = &"rune_seal"
	_make_hud(_sim)
	_hear_events()
	assert_eq(_skill_goal(), plain, "the nearest microskill")
	assert_true(_until_heard(SimEvent.Kind.GATE_SEALED, 1, 20), "a rune seal is passed")
	assert_eq(_skill_goal(), plain, "and with no hero to learn it the goal is unchanged")


## The hero of [member _sim] of class [param class_id].
func _hero_of(class_id: StringName) -> Hero:
	for hero: Hero in _sim.party.heroes:
		if hero.class_id == class_id:
			return hero
	return null


# --- R5 ------------------------------------------------------------------------


## R5: through a whole side trip the status names the gate while it is worked and reads
## "Exploring a side path" for the rest of it.
func test_r5_the_status_names_the_gate() -> void:
	for gate: StringName in [&"locked_gate", &"rune_seal"]:
		_at_gate(gate, SKILLED)
		var e: Expedition = _sim.expedition
		_hud.advance(STEP)
		var ours: Array[String] = [EXPLORING, WORKING[gate]]
		assert_does_not_have(ours, _hud.status_text(), "%s: on the main course, neither" % gate)
		var seen: Dictionary[String, int] = {}
		var wrong: Array[String] = []
		var been: bool = false
		for i: int in 1500:
			_step_until(func() -> bool: return true, 1)
			if e.side_path < 0 and been:
				break
			if e.side_path < 0:
				continue
			been = true
			var want: String = WORKING[gate] if e.state == Expedition.State.WORKING else EXPLORING
			seen[want] = seen.get(want, 0) + 1
			if _hud.status_text() != want or _hud.place_panel.status_label.text != want:
				wrong.append("tick %d: '%s', not '%s'" % [_sim.tick, _hud.status_text(), want])
		assert_eq(wrong.size(), 0, "%s: the status all along:\n%s" % [gate, "\n".join(wrong)])
		assert_eq(e.side_path, -1, "%s: the trip is over" % gate)
		assert_eq(_of_kind(_events, SimEvent.Kind.CACHE_OPENED).size(), 1, "%s: a cache" % gate)
		var work: int = ticks_in(Content.gate(gate).work_seconds)
		var worked: int = seen.get(WORKING[gate], 0)
		var explored: int = seen.get(EXPLORING, 0)
		assert_almost_eq(worked, work, 1, "%s: named while worked" % gate)
		assert_gt(explored, 20, "%s: exploring there and back" % gate)
		assert_does_not_have(ours, _hud.status_text(), "%s: and neither once back" % gate)
		assert_ne(_hud.status_text(), "Working", "%s: nor a bare 'Working'" % gate)


# --- R6 ------------------------------------------------------------------------


## R6: a gate's and a microskill's name in these lines is its definition's; a gate the data
## gains is told with its own name, with no words written for it.
func test_r6_a_new_gate_needs_only_its_line() -> void:
	for id: StringName in Content.gate_ids():
		var gate: GateDef = Content.gate(id)
		var skill: String = Content.microskill(gate.microskill).display_name
		var named: String = gate.display_name
		for line: String in [SidePathWords.sealed(gate), SidePathWords.passed(gate, 4)]:
			assert_string_contains(line.to_lower(), named.to_lower(), "%s's name" % id)
			assert_string_ends_with(line, skill, "%s's microskill's name" % id)
		assert_string_contains(SidePathWords.opens(gate), named.to_lower(), "%s's name" % id)
		assert_true(SidePathWords.SENTENCES.has(id), "%s has its sentence in the table" % id)
	var seal: GateDef = Content.gate(&"rune_seal")
	seal.display_name = "Glyph Door"
	var as_renamed: String = SidePathWords.sealed(seal)
	seal.display_name = "Rune Seal"
	assert_eq(as_renamed, "A glyph door: needs a Runereader", "a gate renamed in the data")

	var door := GateDef.new()
	door.id = &"moss_door"
	door.display_name = "Moss Door"
	door.description = "A door grown over with moss"
	door.microskill = &"mender"
	door.work_seconds = 3.0
	_add_gate(door)
	assert_eq(door.validate().size(), 0, "a gate as the data would have it")
	assert_false(SidePathWords.SENTENCES.has(door.id), "with no sentence of its own yet")

	# Passed: the journal, the goal and the away report name it.
	_at_gate(door.id, 1)
	assert_true(_until_heard(SimEvent.Kind.GATE_SEALED, 1, 20), "the party passes it")
	assert_eq(_told("A moss door: needs a Mender"), 1, "the journal names it and its skill")
	assert_eq(_skill_goal(), "Cleric learns Mender at level 3: opens moss doors", "the goal too")
	var report := AwayReport.new()
	report.most_sealed_gate = door.id
	report.gates_sealed = 2
	var texts: Array[String] = []
	for row: AwayStory.Row in AwayStory.rows(report, _sim.party):
		texts.append(row.text())
	assert_has(texts, "Passed 2 moss doors: needs a Mender", "and the away report")

	# Opened: the status and the journal, in the words any gate has until it has its own.
	_at_gate(door.id, SKILLED)
	assert_true(_until_heard(SimEvent.Kind.GATE_STARTED), "a Mender sets to work on it")
	assert_eq(_hud.status_text(), "Opening a moss door", "the status names it")
	assert_true(_until_heard(SimEvent.Kind.GATE_OPENED), "and opens it")
	assert_eq(_told("The Cleric opened a moss door"), 1, "the journal names it")


## What caches paid, as a test sums it from the events.
class Paid:
	extends RefCounted

	var gold: int = 0
	var xp: int = 0
	var xp_each: int = 0
	var resources: Dictionary[StringName, int] = {}

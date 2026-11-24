extends "res://tests/support/side_path_fixture.gd"
## Spec 104: a quest takes 10 to 15 seconds, every living hero with its microskill works on it,
## the lowest id leading, and each helper shortens the work.

## Each quest's work, in seconds.
const QUEST_SECONDS: Dictionary[StringName, float] = {
	&"tripwire": 10.0,
	&"locked_chest": 12.0,
	&"hurt_wanderer": 12.0,
	&"stuck_door": 14.0,
	&"rune_stone": 14.0,
}
## A 12-second quest's ticks with 1, 2 and 3 workers.
const TWELVE_SECOND_TICKS: Array[int] = [120, 89, 71]
const KNIGHT_ID: int = 1
## The clerics' ids: the starting party's cleric, then the ones added.
const FIRST_CLERIC: int = 4
## The level a cleric learns to mend at.
const MENDER_LEVEL: int = 3
const QUEST: StringName = &"hurt_wanderer"
## A level at which every hero has every microskill of its class.
const SKILLED: int = 12

## Where [method _before_quest] put the party: Vector2i(depth, chamber index).
var _quest_at: Vector2i = Vector2i(0, -1)
## The GATE_STARTED events [method _at_gate] saw.
var _gate_started: Array[SimEvent] = []

# --- Setting up ----------------------------------------------------------------


## A flat simulation whose party stands one step outside a chamber holding [constant QUEST] on its
## first visit, walking in, with auto-push off. Its party is a level-3 knight (id 1) and one
## cleric per entry of [param cleric_levels], at that level, ids from 4 up.
func _before_quest(cleric_levels: Array[int]) -> Simulation:
	for seed_value: int in range(1, 1000):
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for room: LabyrinthChamber in sim.labyrinth.level(1).chambers:
			if e.quest_in(1, room.index) != QUEST:
				continue
			sim.set_auto_push(false)
			e.target_depth = 1
			e.x = room.rect.position.x - 0.1
			e.facing = 1
			_quest_at = Vector2i(1, room.index)
			var knight: Hero = sim.party.hero(KNIGHT_ID)
			raise(knight, MENDER_LEVEL)
			sim.party.heroes.assign([knight])
			for i: int in cleric_levels.size():
				var cleric := Hero.new(FIRST_CLERIC + i, Content.hero_class(&"cleric"))
				raise(cleric, cleric_levels[i])
				sim.party.heroes.append(cleric)
			return sim
	fail_test("no seed has a %s on stage 1" % QUEST)
	return null


## The levels of [param count] clerics who can mend.
func _menders(count: int) -> Array[int]:
	var levels: Array[int] = []
	for i: int in count:
		levels.append(MENDER_LEVEL)
	return levels


## Steps [param sim] once into the quest and on until the work is done, at most 400 ticks.
## Returns every event; [param ticks][0] is the steps taken after the one the work started on.
func _do_quest(sim: Simulation, ticks: Array[int]) -> Array[SimEvent]:
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	ticks[0] = 0
	while sim.expedition.state == Expedition.State.WORKING and ticks[0] < 400:
		sim.step()
		ticks[0] += 1
		events.append_array(sim.drain_events())
	return events


## The one event of [param kind] in [param events], or null (and a failure) if not exactly one.
func _one(events: Array[SimEvent], kind: SimEvent.Kind, what: String) -> SimEvent:
	var found: Array[SimEvent] = _of_kind(events, kind)
	assert_eq(found.size(), 1, "%s: one %s" % [what, SimEvent.Kind.keys()[kind]])
	return found[0] if found.size() == 1 else null


## A winding simulation whose party, at a level where it knows every microskill, with a second
## hero of every class, stands working at a stage-1 gate. Returns the gate's definition.
func _at_gate(sim_out: Array[Simulation]) -> GateDef:
	var found: Vector2i = _find(1, false)
	var sim: Simulation = winding_simulation(found.x)
	for i: int in 4:
		var twin := Hero.new(5 + i, Content.hero_class(sim.party.heroes[i].class_id))
		sim.party.heroes.append(twin)
	raise_party(sim, SKILLED)
	var path: SidePath = _stand_before(sim, 1, found.y, 1)
	var e: Expedition = sim.expedition
	sim_out.append(sim)
	var events: Array[SimEvent] = _events_until(
		sim, func() -> bool: return e.state == Expedition.State.WORKING, 200
	)
	_gate_started = _of_kind(events, SimEvent.Kind.GATE_STARTED)
	return Content.gate(path.gate)


# --- R1 ------------------------------------------------------------------------


func test_r1_quests_take_ten_to_fifteen_seconds() -> void:
	assert_eq(Content.quest_ids().size(), QUEST_SECONDS.size(), "five quests")
	for id: StringName in QUEST_SECONDS:
		var def: QuestDef = Content.quest(id)
		assert_eq(def.work_seconds, QUEST_SECONDS[id], "%s's work_seconds" % id)
		assert_eq(def.validate(), PackedStringArray(), "%s is valid" % id)
	var made: QuestDef = Content.quest(&"locked_chest").duplicate()
	for seconds: float in [7.9, 18.1]:
		made.work_seconds = seconds
		assert_true(
			"\n".join(made.validate()).contains("work_seconds"), "%s s is reported" % seconds
		)
	for seconds: float in [8.0, 18.0]:
		made.work_seconds = seconds
		assert_eq(made.validate(), PackedStringArray(), "%s s is not" % seconds)
	for id: StringName in Content.gate_ids():
		var gate: GateDef = Content.gate(id)
		assert_between(gate.work_seconds, 3.0, 6.0, "gate %s still takes 3 to 6 seconds" % id)
		assert_eq(gate.work_range(), Vector2(3.0, 6.0), "and allows 3 to 6")


# --- R2 ------------------------------------------------------------------------


func test_r2_every_able_hero_works() -> void:
	var sim: Simulation = _before_quest([MENDER_LEVEL, MENDER_LEVEL])
	if sim == null:
		return
	# The second cleric stands before the first: the lead is the lower id, not the front one.
	var second: Hero = sim.party.heroes.pop_back()
	sim.party.heroes.insert(0, second)
	assert_eq(
		sim.party.heroes_with_microskill(&"mender"),
		[sim.party.hero(4), sim.party.hero(5)] as Array[Hero],
		"the menders, in ascending id order"
	)
	var e: Expedition = sim.expedition
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	assert_eq(e.state, Expedition.State.WORKING, "the party stops to work")
	assert_eq(QuestWork.workers(e), [4, 5] as Array[int], "both clerics work")
	assert_eq(e.worker_id(), 4, "the lower id leads")
	var gold_before: int = sim.party.gold
	var ticks: Array[int] = [0]
	events.append_array(_do_quest_from_working(sim, ticks))
	var started: SimEvent = _one(events, SimEvent.Kind.QUEST_STARTED, "two clerics")
	var done: SimEvent = _one(events, SimEvent.Kind.QUEST_DONE, "two clerics")
	var gold: SimEvent = _one(events, SimEvent.Kind.GOLD_GAINED, "two clerics")
	for event: SimEvent in [started, done, gold]:
		if event != null:
			assert_eq(event.source_id, 4, "the lead is the source of %s" % event)
	assert_gt(sim.party.gold, gold_before, "the quest paid")

	# One cleric dead: only the other works, and leads.
	sim = _before_quest([MENDER_LEVEL, MENDER_LEVEL])
	sim.party.hero(4).health = 0
	events = _do_quest(sim, ticks)
	started = _one(events, SimEvent.Kind.QUEST_STARTED, "one cleric dead")
	if started != null:
		assert_eq(started.source_id, 5, "the living cleric works")
		assert_eq(started.amount, QuestWork.work_ticks(Content.quest(QUEST), 1), "alone")
	done = _one(events, SimEvent.Kind.QUEST_DONE, "one cleric dead")
	if done != null:
		assert_eq(done.source_id, 5)

	# A cleric too young to mend does not work either.
	sim = _before_quest([MENDER_LEVEL, MENDER_LEVEL - 1])
	sim.step()
	assert_eq(QuestWork.workers(sim.expedition), [4] as Array[int], "only the one who can")

	# No cleric: the party walks past.
	sim = _before_quest([])
	var x_before: float = sim.expedition.x
	sim.step()
	events = sim.drain_events()
	assert_eq(sim.expedition.state, Expedition.State.TRAVELLING, "nobody able: it walks on")
	assert_gt(sim.expedition.x, x_before, "it did not stop")
	assert_eq(_of_kind(events, SimEvent.Kind.QUEST_MISSED).size(), 1, "and says it missed it")
	assert_eq(QuestWork.workers(sim.expedition), [] as Array[int], "nobody works")


## Steps [param sim], already WORKING, until the work is done; as [method _do_quest] after its
## first step.
func _do_quest_from_working(sim: Simulation, ticks: Array[int]) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	ticks[0] = 0
	while sim.expedition.state == Expedition.State.WORKING and ticks[0] < 400:
		sim.step()
		ticks[0] += 1
		events.append_array(sim.drain_events())
	return events


# --- R3 ------------------------------------------------------------------------


func test_r3_helpers_shorten_the_work() -> void:
	var def: QuestDef = Content.quest(QUEST)
	assert_eq(def.work_seconds, 12.0, "a 12-second quest")
	for i: int in TWELVE_SECOND_TICKS.size():
		var count: int = i + 1
		var expected: int = TWELVE_SECOND_TICKS[i]
		assert_eq(QuestWork.work_ticks(def, count), expected, "%d workers" % count)
		var sim: Simulation = _before_quest(_menders(count))
		if sim == null:
			return
		var ticks: Array[int] = [0]
		var events: Array[SimEvent] = _do_quest(sim, ticks)
		var started: SimEvent = _one(events, SimEvent.Kind.QUEST_STARTED, "%d workers" % count)
		if started != null:
			assert_eq(started.amount, expected, "%d workers: STARTED says the work" % count)
		assert_eq(ticks[0], expected, "%d workers: the work takes that long" % count)
		assert_eq(_of_kind(events, SimEvent.Kind.QUEST_DONE).size(), 1, "and is done")
	assert_eq(QuestWork.HELPER_SHARE, 0.35)
	var quick: QuestDef = def.duplicate()
	quick.work_seconds = 0.01
	assert_eq(QuestWork.work_ticks(quick, 1), 1, "at least one tick")
	assert_eq(QuestWork.work_ticks(quick, 4), 1, "however many help")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_workers_can_be_read() -> void:
	var sim: Simulation = _before_quest([MENDER_LEVEL, MENDER_LEVEL, MENDER_LEVEL])
	if sim == null:
		return
	var e: Expedition = sim.expedition
	assert_eq(QuestWork.workers(e), [] as Array[int], "empty while travelling")
	sim.step()
	assert_eq(e.state, Expedition.State.WORKING)
	assert_eq(QuestWork.workers(e), [4, 5, 6] as Array[int], "every worker, lead first")
	var ticks: Array[int] = [0]
	_do_quest_from_working(sim, ticks)
	assert_eq(e.state, Expedition.State.TRAVELLING, "the work is done")
	assert_eq(QuestWork.workers(e), [] as Array[int], "and nobody works")

	var holder: Array[Simulation] = []
	var gate: GateDef = _at_gate(holder)
	var at_gate: Expedition = holder[0].expedition
	var opener: int = _lowest_with(holder[0], gate.microskill)
	assert_eq(at_gate.state, Expedition.State.WORKING, "at the gate")
	assert_eq(QuestWork.workers(at_gate), [opener] as Array[int], "only the opener at a gate")
	_events_until(holder[0], func() -> bool: return at_gate.state != Expedition.State.WORKING, 200)
	assert_eq(QuestWork.workers(at_gate), [] as Array[int], "and nobody once it is open")

	# Two runs that differ only in whether a second cleric can mend.
	var hashes: Array[int] = []
	for level: int in [MENDER_LEVEL, MENDER_LEVEL - 1]:
		var run: Simulation = _before_quest([MENDER_LEVEL, level])
		run.step()
		assert_eq(run.expedition.state, Expedition.State.WORKING)
		hashes.append(run.state_hash())
		if level == MENDER_LEVEL:
			assert_true(_holds_workers(run.expedition.hash_parts(), [4, 5]), "workers hashed")
	assert_ne(hashes[0], hashes[1], "they hash differently while working")


## True if one of [param parts] is the list of workers [param ids].
func _holds_workers(parts: Array, ids: Array[int]) -> bool:
	for part: Variant in parts:
		if part is Array and (part as Array).size() == ids.size():
			var same: bool = true
			for i: int in ids.size():
				var value: Variant = (part as Array)[i]
				same = same and value is int and value == ids[i]
			if same:
				return true
	return false


# --- R5 ------------------------------------------------------------------------


func test_r5_the_reward_does_not_depend_on_workers() -> void:
	var paid: Array[int] = []
	for count: int in [1, 2]:
		var sim: Simulation = _before_quest(_menders(count))
		if sim == null:
			return
		var ticks: Array[int] = [0]
		var events: Array[SimEvent] = _do_quest(sim, ticks)
		var done: SimEvent = _one(events, SimEvent.Kind.QUEST_DONE, "%d workers" % count)
		paid.append(done.amount if done != null else -1)
	assert_gt(paid[0], 0, "the quest pays")
	assert_eq(paid[1], paid[0], "the same gold with one worker and with two")

	var holder: Array[Simulation] = []
	var gate: GateDef = _at_gate(holder)
	var opener: int = _lowest_with(holder[0], gate.microskill)
	assert_eq(_gate_started.size(), 1, "GATE_STARTED once")
	if _gate_started.size() == 1:
		assert_eq(_gate_started[0].source_id, opener, "the lowest id opens it, alone")
		assert_eq(
			_gate_started[0].amount,
			Combatant.seconds_to_ticks(gate.work_seconds),
			"in the gate's own seconds, though another could help"
		)
	var twins: int = 0
	for hero: Hero in holder[0].party.heroes:
		if hero.is_alive() and hero.has_microskill(gate.microskill):
			twins += 1
	assert_gt(twins, 1, "(two heroes could open it)")
	var e: Expedition = holder[0].expedition
	var worked: Array[SimEvent] = _events_until(
		holder[0], func() -> bool: return e.state != Expedition.State.WORKING, 200
	)
	var opened: SimEvent = _one(worked, SimEvent.Kind.GATE_OPENED, "the gate")
	if opened != null:
		assert_eq(opened.source_id, opener, "and the opener opens it")

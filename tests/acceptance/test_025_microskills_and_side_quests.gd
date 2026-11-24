extends ColonyTest
## Acceptance tests for specs/025-microskills-and-side-quests/spec.md, one per requirement.
##
## Most tests find a seed whose labyrinth has the quest wanted on its first visit, put the
## party one step outside that chamber walking in, and step the simulation.

## [microskill, class, level learned at, description].
const MICROSKILLS: Array = [
	[&"lockpicker", &"rogue", 2, "Opens locks"],
	[&"strongarm", &"knight", 3, "Forces what is stuck"],
	[&"mender", &"cleric", 3, "Patches up strangers"],
	[&"runereader", &"mage", 4, "Reads old runes"],
	[&"trapspotter", &"rogue", 6, "Sees a trap before it sees you"],
]
## [quest, microskill, reward, kills worth, share of max health lost when it springs].
const QUESTS: Array = [
	[&"locked_chest", &"lockpicker", QuestDef.Reward.GOLD, 3.0, 0.0],
	[&"stuck_door", &"strongarm", QuestDef.Reward.GOLD, 2.0, 0.0],
	[&"hurt_wanderer", &"mender", QuestDef.Reward.GOLD, 2.0, 0.0],
	[&"rune_stone", &"runereader", QuestDef.Reward.XP, 2.0, 0.0],
	[&"tripwire", &"trapspotter", QuestDef.Reward.GOLD, 1.0, 0.2],
]
## Hero ids of the starting party, by class.
const HERO_OF_CLASS: Dictionary[StringName, int] = {
	&"knight": 1, &"rogue": 2, &"mage": 3, &"cleric": 4
}
## A reward "worth N kills" is within this share of N times a kill's mean value at that depth.
const KILL_SLACK: float = 0.25
const HOUR_TICKS: int = 36_000

## Where [method _before_quest] put the party: Vector2i(depth, chamber index).
var _quest_at: Vector2i = Vector2i(0, -1)


## A simulation whose party stands one step outside a chamber holding [param kind] on its first
## visit, at [param min_depth] or a little deeper, walking in, with auto-push off. Its place is
## left in [member _quest_at].
func _before_quest(kind: StringName, min_depth: int = 1) -> Simulation:
	for seed_value: int in range(1, 1000):
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for depth: int in range(min_depth, min_depth + 3):
			for room: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
				if e.quest_in(depth, room.index) != kind:
					continue
				sim.set_auto_push(false)
				e.depth = depth
				e.target_depth = depth
				e.x = room.rect.position.x - 0.1
				e.facing = 1
				_quest_at = Vector2i(depth, room.index)
				return sim
	fail_test("no seed has a %s near depth %d" % [kind, min_depth])
	return null


## The mean gold and XP of one kill at [param depth], each monster as likely as an encounter
## makes it (by its base level, as encounters weighed them before spec 049): Vector2(gold, xp).
func _kill_value(depth: int) -> Vector2:
	var gold: float = 0.0
	var xp: float = 0.0
	var weight: float = 0.0
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if def.guardian or def.base_level > depth:
			continue
		gold += def.base_level * (def.gold_min + def.gold_max) / 2.0
		xp += def.base_level * def.xp
		weight += def.base_level
	return Vector2(gold, xp) / weight


func _assert_worth(amount: int, kills: float, per_kill: float, what: String) -> void:
	var expected: float = kills * per_kill
	assert_between(
		float(amount),
		expected * (1.0 - KILL_SLACK),
		expected * (1.0 + KILL_SLACK),
		"%s: %d is worth about %s kills of %.1f" % [what, amount, kills, per_kill]
	)


## Steps until the expedition leaves WORKING; returns every event, and the ticks taken in
## [param ticks][0].
func _work_out(sim: Simulation, ticks: Array[int]) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	ticks[0] = 0
	while sim.expedition.state == Expedition.State.WORKING and ticks[0] < 1000:
		sim.step()
		ticks[0] += 1
		events.append_array(sim.drain_events())
	return events


# --- R1 ------------------------------------------------------------------------


func test_r1_microskills() -> void:
	assert_eq(Content.microskill_ids().size(), MICROSKILLS.size(), "five microskills")
	for row: Array in MICROSKILLS:
		var id: StringName = row[0]
		var class_id: StringName = row[1]
		var level: int = row[2]
		var description: String = row[3]
		var def: MicroskillDef = Content.microskill(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate(), PackedStringArray(), "%s is valid" % id)
		assert_false(def.display_name.is_empty(), "%s has a name" % id)
		assert_eq(def.description, description, "%s's description" % id)
		var class_def: HeroClassDef = Content.hero_class(class_id)
		var at: int = class_def.microskills.find(id)
		assert_gte(at, 0, "%s learns %s" % [class_id, id])
		if at >= 0:
			var learned_at: int = class_def.microskill_levels[at]
			assert_eq(learned_at, level, "%s learns %s at %d" % [class_id, id, level])
	for class_id: StringName in Content.hero_class_ids():
		var class_def: HeroClassDef = Content.hero_class(class_id)
		assert_eq(class_def.validate(), PackedStringArray(), "%s is valid" % class_id)
		var expected: Array[StringName] = []
		for row: Array in MICROSKILLS:
			var learner: StringName = row[1]
			var id: StringName = row[0]
			if learner == class_id:
				expected.append(id)
		assert_eq(class_def.microskills, expected, "%s's list" % class_id)

	# A hero has one exactly from its level.
	var party := Party.new()
	for row: Array in MICROSKILLS:
		var id: StringName = row[0]
		var class_id: StringName = row[1]
		var level: int = row[2]
		var hero: Hero = party.hero(HERO_OF_CLASS[class_id])
		_set_level(hero, level - 1)
		assert_false(hero.has_microskill(id), "not %s at level %d" % [id, level - 1])
		assert_false(hero.microskills().has(id))
		_set_level(hero, level)
		assert_true(hero.has_microskill(id), "%s at level %d" % [id, level])
		assert_true(hero.microskills().has(id))
		_set_level(hero, level + 5)
		assert_true(hero.has_microskill(id), "%s above level %d" % [id, level])
	_set_level(party.hero(2), 6)
	assert_eq(party.hero(2).microskills(), [&"lockpicker", &"trapspotter"] as Array[StringName])
	_set_level(party.hero(2), 1)
	assert_eq(party.hero(2).microskills(), [] as Array[StringName], "a level-1 rogue has none")

	# Nothing new is saved.
	var sim := Simulation.new(1)
	_set_level(sim.party.hero(2), 6)
	var loaded: Simulation = Simulation.from_save(sim.to_save())
	assert_eq(loaded.party.hero(2).microskills(), sim.party.hero(2).microskills(), "from level")


# --- R2 ------------------------------------------------------------------------


func test_r2_side_quests_are_valid() -> void:
	assert_eq(Content.quest_ids().size(), QUESTS.size(), "five quests")
	for row: Array in QUESTS:
		var id: StringName = row[0]
		var skill: StringName = row[1]
		var reward: QuestDef.Reward = row[2]
		var kills: float = row[3]
		var hazard: float = row[4]
		var def: QuestDef = Content.quest(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate(), PackedStringArray(), "%s is valid" % id)
		assert_eq(def.microskill, skill, "%s needs %s" % [id, skill])
		assert_eq(def.reward, reward, "%s's reward" % id)
		assert_eq(def.reward_factor, kills, "%s is worth %s kills" % [id, kills])
		assert_eq(def.miss_damage, hazard, "%s's hazard" % id)
		assert_between(def.work_seconds, 3.0, 6.0, "%s takes 3 to 6 seconds" % id)
		_with_and_without(row)


## Does the quest of [param row] at depth 6 or so, with the microskill and without it.
func _with_and_without(row: Array) -> void:
	var id: StringName = row[0]
	var skill: StringName = row[1]
	var reward: QuestDef.Reward = row[2]
	var kills: float = row[3]
	var hazard: float = row[4]
	var learner_class: StringName = &""
	var learner_level: int = 0
	for skill_row: Array in MICROSKILLS:
		var skill_id: StringName = skill_row[0]
		if skill_id == skill:
			learner_class = skill_row[1]
			learner_level = skill_row[2]

	# With it.
	var sim: Simulation = _before_quest(id, 6)
	if sim == null:
		return
	var worth: Vector2 = _kill_value(_quest_at.x)
	_set_level(sim.party.hero(HERO_OF_CLASS[learner_class]), learner_level)
	var gold_before: int = sim.party.gold
	var xp_before: Dictionary[int, int] = {}
	for hero: Hero in sim.party.heroes:
		xp_before[hero.id] = hero.xp
	sim.step()
	sim.drain_events()
	assert_eq(sim.expedition.state, Expedition.State.WORKING, "%s: the party does it" % id)
	var ticks: Array[int] = [0]
	_work_out(sim, ticks)
	if reward == QuestDef.Reward.GOLD:
		_assert_worth(sim.party.gold - gold_before, kills, worth.x, "%s's gold" % id)
		for hero: Hero in sim.party.heroes:
			assert_eq(hero.xp, xp_before[hero.id], "%s gives no XP" % id)
	else:
		assert_eq(sim.party.gold, gold_before, "%s gives no gold" % id)
		for hero: Hero in sim.party.heroes:
			_assert_worth(hero.xp - xp_before[hero.id], kills, worth.y, "%s's XP" % id)

	# Without it.
	sim = _before_quest(id, 6)
	gold_before = sim.party.gold
	var health_before: Dictionary[int, int] = {}
	for hero: Hero in sim.party.heroes:
		health_before[hero.id] = hero.health
	var x_before: float = sim.expedition.x
	sim.step()
	sim.drain_events()
	assert_eq(sim.expedition.state, Expedition.State.TRAVELLING, "%s: the party walks on" % id)
	assert_gt(sim.expedition.x, x_before, "%s: it did not stop" % id)
	assert_eq(sim.party.gold, gold_before, "%s: no gold without it" % id)
	for hero: Hero in sim.party.heroes:
		var lost: int = roundi(hazard * hero.max_health())
		assert_eq(
			hero.health, health_before[hero.id] - lost, "%s: hero %d's health" % [id, hero.id]
		)


# --- R3 ------------------------------------------------------------------------


func test_r3_some_chambers_hold_side_quests() -> void:
	var visits: int = 0
	var quests: int = 0
	var kinds: Dictionary[StringName, int] = {}
	var others: int = 0
	var wrong: int = 0
	var seed_value: int = 0
	while visits < 2000:
		seed_value += 1
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for depth: int in range(1, 21):
			var level: LabyrinthLevel = sim.labyrinth.level(depth)
			var shaft: LabyrinthChamber = level.shaft_chamber()
			for room: LabyrinthChamber in level.chambers:
				var quest: StringName = e.quest_in(depth, room.index)
				var populated: bool = e.is_populated(depth, room.index)
				var guardian: bool = (
					e.guardian_of(depth) != &"" and shaft != null and shaft.index == room.index
				)
				if room.kind != LabyrinthChamber.Kind.PLAIN or guardian:
					others += 1
					if quest != &"":
						wrong += 1
					continue
				if quest != &"" and populated:
					wrong += 1
				if quest == &"" and not populated:
					continue  # always empty: the shaft or the landing
				visits += 1
				if quest != &"":
					quests += 1
					kinds[quest] = kinds.get(quest, 0) + 1
	var share: float = float(quests) / visits
	gut.p("%d plain visits over %d seeds, %.3f quests: %s" % [visits, seed_value, share, kinds])
	assert_between(share, 0.25, 0.35, "quests are 25% to 35% of plain-chamber visits")
	for id: StringName in Content.quest_ids():
		assert_true(kinds.has(id), "%s appears" % id)
	assert_gt(others, 100, "plenty of other chambers looked at")
	assert_eq(wrong, 0, "no other chamber holds one, and none holds both monsters and a quest")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_party_does_it() -> void:
	# The tie rule: the living hero with the lowest id, wherever it stands in the formation.
	var party := Party.new()
	var second := Hero.new(5, Content.hero_class(&"rogue"))
	party.heroes.insert(0, second)
	assert_null(party.hero_with_microskill(&"lockpicker"), "nobody yet")
	_set_level(second, 2)
	assert_eq(party.hero_with_microskill(&"lockpicker"), second, "the only one")
	_set_level(party.hero(2), 2)
	assert_eq(party.hero_with_microskill(&"lockpicker"), party.hero(2), "the lowest id")
	party.hero(2).health = 0
	assert_eq(party.hero_with_microskill(&"lockpicker"), second, "a dead hero does nothing")

	var sim: Simulation = _before_quest(&"locked_chest")
	if sim == null:
		return
	var e: Expedition = sim.expedition
	var at: Vector2i = _quest_at
	var front := Hero.new(5, Content.hero_class(&"rogue"))
	_set_level(front, 2)
	sim.party.heroes.insert(0, front)
	_set_level(sim.party.hero(2), 2)
	var def: QuestDef = Content.quest(&"locked_chest")
	var gold_before: int = sim.party.gold
	sim.step()
	sim.drain_events()
	assert_eq(e.state, Expedition.State.WORKING, "the party stops to work")
	assert_eq(e.working_quest(), &"locked_chest")
	assert_eq(e.worker_id(), 2, "the lowest hero id with the microskill")
	assert_almost_eq(e.work_progress(), 0.0, 0.001)
	var x_working: float = e.x
	var work_ticks: int = ticks_in(def.work_seconds)
	for i: int in work_ticks / 2:
		sim.step()
	assert_almost_eq(e.work_progress(), float(work_ticks / 2) / work_ticks, 0.001, "half way")
	assert_eq(e.x, x_working, "the party stands still while it works")
	var ticks: Array[int] = [0]
	_work_out(sim, ticks)
	assert_eq(ticks[0] + work_ticks / 2, work_ticks, "the work takes work_seconds")
	assert_eq(e.state, Expedition.State.TRAVELLING, "then the party travels on")
	assert_eq(e.working_quest(), &"")
	assert_eq(e.worker_id(), -1)
	assert_eq(e.work_progress(), 0.0)
	_assert_worth(sim.party.gold - gold_before, 3.0, _kill_value(at.x).x, "the chest's gold")
	assert_eq(e.quest_in(at.x, at.y), &"", "done: the chamber is cleared")
	assert_false(e.is_populated(at.x, at.y), "and holds no monsters")

	# Refilled after the usual respawn time, and not before. The expedition is stepped on its own
	# so the party, still in the chamber, does not walk away first.
	var done_tick: int = sim.tick
	var respawn: int = ticks_in(DepthTiming.respawn_seconds_at(at.x))  # quicker near the surface
	e.step(done_tick + respawn - 1)
	assert_eq(e.quest_in(at.x, at.y), &"", "still empty just before the respawn time")
	assert_false(e.is_populated(at.x, at.y))
	e.step(done_tick + respawn)
	var refilled: bool = e.quest_in(at.x, at.y) != &"" or e.is_populated(at.x, at.y)
	assert_true(refilled, "refilled after the respawn time")


# --- R5 ------------------------------------------------------------------------


func test_r5_the_party_passes() -> void:
	var sim: Simulation = _before_quest(&"locked_chest")
	if sim == null:
		return
	var e: Expedition = sim.expedition
	var at: Vector2i = _quest_at
	var rogue: Hero = sim.party.hero(2)
	var x_before: float = e.x
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	assert_ne(e.state, Expedition.State.WORKING, "nobody can: the party does not stop")
	assert_gt(e.x, x_before, "it walks on")
	assert_eq(_of_kind(events, SimEvent.Kind.QUEST_MISSED).size(), 1, "missed, once")
	assert_eq(e.quest_in(at.x, at.y), &"locked_chest", "the chest stays where it is")

	# Later passes in the same visit report nothing; once the rogue is level 2, the next does it.
	var missed: int = 0
	var started: int = 0
	var entries: int = 0
	var inside: bool = true
	for i: int in ticks_in(1800):
		if entries < 1:
			rogue.xp = 0  # the rogue stays level 1 for one more pass
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.QUEST_MISSED:
				missed += 1
			elif event.kind == SimEvent.Kind.QUEST_STARTED:
				started += 1
		var here: LabyrinthChamber = e.chamber()
		var now_inside: bool = e.depth == at.x and here != null and here.index == at.y
		if now_inside and not inside:
			entries += 1
			if entries == 1:
				assert_eq(e.state, Expedition.State.TRAVELLING, "a later pass does not stop")
				_set_level(rogue, 2)
		inside = now_inside
		if started > 0:
			break
	assert_eq(entries, 2, "passed again, then came back")
	assert_eq(missed, 0, "missed once per visit, not on every pass")
	assert_eq(started, 1, "done on a later pass once the rogue learned lockpicker")
	assert_eq(e.worker_id(), 2)

	# The tripwire springs, hurts every living hero and is cleared.
	sim = _before_quest(&"tripwire")
	if sim == null:
		return
	e = sim.expedition
	at = _quest_at
	sim.party.hero(3).health = 1
	sim.party.hero(4).health = 0
	var health_before: Dictionary[int, int] = {}
	for hero: Hero in sim.party.heroes:
		health_before[hero.id] = hero.health
	x_before = e.x
	sim.step()
	events = sim.drain_events()
	assert_eq(e.state, Expedition.State.TRAVELLING, "the party does not stop")
	assert_gt(e.x, x_before, "it walks on")
	var sprung: Array[SimEvent] = _of_kind(events, SimEvent.Kind.QUEST_MISSED)
	assert_eq(sprung.size(), 1)
	if sprung.size() == 1:
		assert_true(sprung[0].flag, "a hazard sprang")
	var knight: Hero = sim.party.hero(1)
	assert_eq(knight.health, health_before[1] - roundi(0.2 * knight.max_health()), "20% lost")
	var rogue_now: Hero = sim.party.hero(2)
	assert_eq(rogue_now.health, health_before[2] - roundi(0.2 * rogue_now.max_health()))
	assert_eq(sim.party.hero(3).health, 1, "never below 1")
	assert_eq(sim.party.hero(4).health, 0, "the dead are not hurt")
	assert_eq(e.quest_in(at.x, at.y), &"", "a sprung trap is cleared")
	assert_false(e.is_populated(at.x, at.y))


# --- R6 ------------------------------------------------------------------------


func test_r6_events() -> void:
	for kind: SimEvent.Kind in [
		SimEvent.Kind.MICROSKILL_LEARNED,
		SimEvent.Kind.QUEST_STARTED,
		SimEvent.Kind.QUEST_DONE,
		SimEvent.Kind.QUEST_MISSED,
	]:
		assert_lt(kind, SimEvent.Kind.ENCOUNTER_STARTED, "placed before ENCOUNTER_STARTED")
	var skills: Array[StringName] = Content.microskill_ids()
	var quests: Array[StringName] = Content.quest_ids()

	# A rune stone: started, done, XP to every living hero, and a microskill learned on the way.
	var sim: Simulation = _before_quest(&"rune_stone")
	if sim == null:
		return
	_set_level(sim.party.hero(3), 4)
	var knight: Hero = sim.party.hero(1)
	knight.level = 2
	knight.xp = Hero.xp_for_level(3) - 1
	sim.party.hero(4).health = 0
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	var started: Array[SimEvent] = _of_kind(events, SimEvent.Kind.QUEST_STARTED)
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0].source_id, 3, "the worker")
		assert_eq(started[0].target_id, quests.find(&"rune_stone"), "the quest's position")
		assert_eq(started[0].amount, ticks_in(Content.quest(&"rune_stone").work_seconds))
	var ticks: Array[int] = [0]
	events = _work_out(sim, ticks)
	var done: Array[SimEvent] = _of_kind(events, SimEvent.Kind.QUEST_DONE)
	assert_eq(done.size(), 1)
	var xp: Array[SimEvent] = _of_kind(events, SimEvent.Kind.XP_GAINED)
	assert_eq(xp.size(), 3, "XP for the three living heroes")
	if done.size() == 1:
		assert_eq(done[0].source_id, 3)
		assert_eq(done[0].target_id, quests.find(&"rune_stone"))
		assert_gt(done[0].amount, 0, "the XP given")
		for event: SimEvent in xp:
			assert_eq(event.amount, done[0].amount, "each living hero gets it")
	var targets: Array[int] = []
	for event: SimEvent in xp:
		targets.append(event.target_id)
	assert_eq(targets, [1, 2, 3] as Array[int])
	var learned: Array[SimEvent] = _of_kind(events, SimEvent.Kind.MICROSKILL_LEARNED)
	assert_eq(learned.size(), 1, "the knight crossed level 3")
	if learned.size() == 1:
		assert_eq(learned[0].source_id, 1, "the hero")
		assert_eq(learned[0].target_id, skills.find(&"strongarm"), "the microskill's position")
		assert_eq(learned[0].amount, 3, "the hero's level")
	assert_eq(_of_kind(events, SimEvent.Kind.LEVEL_UP).size(), 1, "with the usual level-up")

	# A locked chest: the gold comes with the usual GOLD_GAINED, from the worker.
	sim = _before_quest(&"locked_chest")
	_set_level(sim.party.hero(2), 2)
	sim.step()
	sim.drain_events()
	events = _work_out(sim, ticks)
	done = _of_kind(events, SimEvent.Kind.QUEST_DONE)
	var gold: Array[SimEvent] = _of_kind(events, SimEvent.Kind.GOLD_GAINED)
	assert_eq(done.size(), 1)
	assert_eq(gold.size(), 1)
	if done.size() == 1 and gold.size() == 1:
		assert_eq(done[0].amount, gold[0].amount, "the gold given")
		assert_eq(gold[0].source_id, 2, "coins from the worker")

	# A tripwire missed: its fields, and a HIT for each hero it hurts.
	sim = _before_quest(&"tripwire")
	sim.step()
	events = sim.drain_events()
	var missed: Array[SimEvent] = _of_kind(events, SimEvent.Kind.QUEST_MISSED)
	assert_eq(missed.size(), 1)
	if missed.size() == 1:
		assert_eq(missed[0].target_id, quests.find(&"tripwire"))
		assert_eq(missed[0].amount, skills.find(&"trapspotter"), "the needed microskill")
		assert_true(missed[0].flag)
	var hits: Array[SimEvent] = _of_kind(events, SimEvent.Kind.HIT)
	assert_eq(hits.size(), 4, "every hero is hit")
	for hit: SimEvent in hits:
		var hero: Hero = sim.party.hero(hit.target_id)
		assert_eq(hit.amount, roundi(0.2 * hero.max_health()), "hero %d's damage" % hit.target_id)

	# A locked chest missed: not a hazard.
	sim = _before_quest(&"locked_chest")
	sim.step()
	missed = _of_kind(sim.drain_events(), SimEvent.Kind.QUEST_MISSED)
	assert_eq(missed.size(), 1)
	if missed.size() == 1:
		assert_eq(missed[0].target_id, quests.find(&"locked_chest"))
		assert_eq(missed[0].amount, skills.find(&"lockpicker"))
		assert_false(missed[0].flag)

	# Learned in a fight: the rogue crosses level 2.
	sim = Simulation.new(1234)
	sim.set_auto_push(false)
	var rogue: Hero = sim.party.hero(2)
	rogue.xp = Hero.xp_for_level(2) - 1
	var found: Array[SimEvent] = []
	for i: int in ticks_in(600):
		sim.step()
		found = _of_kind(sim.drain_events(), SimEvent.Kind.MICROSKILL_LEARNED)
		if not found.is_empty():
			break
	assert_eq(found.size(), 1, "the rogue learned lockpicker")
	if found.size() == 1:
		assert_eq(found[0].source_id, 2)
		assert_eq(found[0].target_id, skills.find(&"lockpicker"))
		assert_eq(found[0].amount, 2)


# --- R7 ------------------------------------------------------------------------


func test_r7_still_the_game() -> void:
	# A sprung tripwire never takes a hero below 1, so it never wipes the party.
	var sim: Simulation = _before_quest(&"tripwire")
	if sim == null:
		return
	var lows: Array[int] = [1, 2, 3, 5]
	for i: int in sim.party.heroes.size():
		sim.party.heroes[i].health = lows[i]
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	assert_eq(_of_kind(events, SimEvent.Kind.QUEST_MISSED).size(), 1, "it sprang")
	for hero: Hero in sim.party.heroes:
		assert_gte(hero.health, 1, "hero %d still stands" % hero.id)
	assert_eq(_of_kind(events, SimEvent.Kind.PARTY_WIPED).size(), 0, "no wipe")

	var beaten_runs: int = 0
	# Since spec 036 refills quickly near the surface, a run may learn every microskill before it
	# meets a quest it cannot do: misses are counted over the five runs.
	var missing_runs: int = 0
	for seed_value: int in [1, 2, 3, 4, 5]:
		var run := Simulation.new(seed_value)
		run.expedition.stable_seconds = 120.0
		var where: String = "seed %d" % seed_value
		var learned: Dictionary[int, bool] = {}
		var done: int = 0
		var missed: int = 0
		var beat_first: bool = false
		for i: int in HOUR_TICKS:
			run.step()
			for event: SimEvent in run.drain_events():
				match event.kind:
					SimEvent.Kind.MICROSKILL_LEARNED:
						learned[event.source_id] = true
					SimEvent.Kind.QUEST_DONE:
						done += 1
					SimEvent.Kind.QUEST_MISSED:
						missed += 1
					SimEvent.Kind.GUARDIAN_SLAIN:
						if event.amount == 5:
							beat_first = true
		if beat_first:
			beaten_runs += 1
		var e: Expedition = run.expedition
		gut.p(
			(
				"%s: deepest %d, stable %d, first guardian %s, done %d, missed %d, levels %s"
				% [
					where,
					e.deepest_depth,
					e.last_stable_depth,
					beat_first,
					done,
					missed,
					run.party.heroes.map(func(h: Hero) -> int: return h.level)
				]
			)
		)
		assert_gte(e.last_stable_depth, 2, "stable on depth 2 or deeper, " + where)
		for hero: Hero in run.party.heroes:
			assert_true(learned.has(hero.id), "hero %d learned a microskill, %s" % [hero.id, where])
		assert_gte(done, 5, "at least five quests done, " + where)
		if missed >= 1:
			missing_runs += 1
	assert_gte(beaten_runs, 3, "at least three of five runs beat the first guardian")
	assert_gte(missing_runs, 4, "at least four of five runs miss a quest")

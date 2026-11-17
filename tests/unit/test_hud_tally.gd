extends GutTest
## Unit tests for [Tally], the counting behind spec 045's party tally, fed made-up events.

const KNIGHT: int = 1
const ROGUE: int = 2
const CLERIC: int = 4
const OGRE: int = Expedition.FIRST_MONSTER_ID + 7
const BAT: int = Expedition.FIRST_MONSTER_ID + 8

const DAMAGE: Tally.Measure = Tally.Measure.DAMAGE
const HEALING: Tally.Measure = Tally.Measure.HEALING
const TAKEN: Tally.Measure = Tally.Measure.TAKEN
const LAST: Tally.Span = Tally.Span.LAST_FIGHT
const SESSION: Tally.Span = Tally.Span.SESSION


func _event(kind: SimEvent.Kind, source: int = -1, target: int = -1, amount: int = 0) -> SimEvent:
	return SimEvent.new(kind, 0, source, target, amount)


func _feed(tally: Tally, events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		tally.observe(event)


func test_nothing_counted_at_first() -> void:
	var tally := Tally.new()
	for measure: Tally.Measure in [DAMAGE, HEALING, TAKEN]:
		for span: Tally.Span in [LAST, SESSION]:
			assert_eq(tally.value(KNIGHT, measure, span), 0)
			assert_eq(tally.share(KNIGHT, measure, span), 0.0, "no share of nothing")
	assert_eq(tally.side_quests(ROGUE), 0)
	assert_eq(tally.fights(), 0)


func test_each_measure_counts_its_own_events() -> void:
	var tally := Tally.new()
	_feed(
		tally,
		[
			_event(SimEvent.Kind.ENCOUNTER_STARTED, -1, -1, 3),
			_event(SimEvent.Kind.HIT, KNIGHT, OGRE, 12),
			_event(SimEvent.Kind.HIT, ROGUE, OGRE, 30),
			_event(SimEvent.Kind.HIT, OGRE, KNIGHT, 9),
			_event(SimEvent.Kind.HEALED, CLERIC, KNIGHT, 7),
			_event(SimEvent.Kind.HEALED, CLERIC, CLERIC, 0),
			_event(SimEvent.Kind.HIT, BAT, ROGUE, 2),
			_event(SimEvent.Kind.HIT, KNIGHT, BAT, 5),
			# Not damage, healing or harm: the wind-up's amount is ticks, a death has none.
			_event(SimEvent.Kind.ATTACK_STARTED, KNIGHT, OGRE, 40),
			_event(SimEvent.Kind.PROJECTILE_LAUNCHED, CLERIC, KNIGHT, 6),
			_event(SimEvent.Kind.DIED, OGRE),
		]
	)
	assert_eq(tally.value(KNIGHT, DAMAGE, LAST), 17)
	assert_eq(tally.value(ROGUE, DAMAGE, LAST), 30)
	assert_eq(tally.value(CLERIC, DAMAGE, LAST), 0)
	assert_eq(tally.value(CLERIC, HEALING, LAST), 7)
	assert_eq(tally.value(KNIGHT, TAKEN, LAST), 9)
	assert_eq(tally.value(ROGUE, TAKEN, LAST), 2)
	assert_eq(tally.value(OGRE, DAMAGE, LAST), 0, "a monster is never a hero of the tally")
	assert_almost_eq(tally.share(ROGUE, DAMAGE, LAST), 30.0 / 47.0, 0.0001)
	assert_almost_eq(tally.share(CLERIC, HEALING, LAST), 1.0, 0.0001)
	assert_eq(tally.fights(), 1)
	assert_true(tally.in_fight())


func test_a_new_fight_starts_the_last_fight_again() -> void:
	var tally := Tally.new()
	_feed(
		tally,
		[
			_event(SimEvent.Kind.ENCOUNTER_STARTED, -1, -1, 1),
			_event(SimEvent.Kind.HIT, KNIGHT, OGRE, 10),
			_event(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1, 1),
		]
	)
	assert_false(tally.in_fight())
	assert_eq(tally.value(KNIGHT, DAMAGE, LAST), 10, "kept after the fight ends")
	_feed(
		tally,
		[
			_event(SimEvent.Kind.ENCOUNTER_STARTED, -1, -1, 2),
			_event(SimEvent.Kind.HIT, ROGUE, BAT, 4),
		]
	)
	assert_eq(tally.value(KNIGHT, DAMAGE, LAST), 0, "the new fight starts empty")
	assert_eq(tally.value(ROGUE, DAMAGE, LAST), 4)
	assert_eq(tally.value(KNIGHT, DAMAGE, SESSION), 10)
	assert_eq(tally.value(ROGUE, DAMAGE, SESSION), 4)
	assert_eq(tally.fights(), 2)


func test_a_trap_hurts_in_the_session_only() -> void:
	var tally := Tally.new()
	_feed(
		tally,
		[
			_event(SimEvent.Kind.ENCOUNTER_STARTED, -1, -1, 1),
			_event(SimEvent.Kind.HIT, OGRE, KNIGHT, 5),
			_event(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1, 1),
			# A sprung hazard (spec 025) hits with no source, outside any fight.
			_event(SimEvent.Kind.HIT, -1, KNIGHT, 20),
		]
	)
	assert_eq(tally.value(KNIGHT, TAKEN, LAST), 5)
	assert_eq(tally.value(KNIGHT, TAKEN, SESSION), 25)


func test_side_quests_count_their_worker() -> void:
	var tally := Tally.new()
	_feed(
		tally,
		[
			_event(SimEvent.Kind.SIDE_QUEST_STARTED, ROGUE, 0, 30),
			_event(SimEvent.Kind.SIDE_QUEST_DONE, ROGUE, 0, 15),
			_event(SimEvent.Kind.GOLD_GAINED, ROGUE, -1, 15),
			_event(SimEvent.Kind.SIDE_QUEST_DONE, ROGUE, 0, 15),
			_event(SimEvent.Kind.SIDE_QUEST_MISSED, -1, 1, 2),
		]
	)
	assert_eq(tally.side_quests(ROGUE), 2)
	assert_eq(tally.side_quests(KNIGHT), 0)


func test_shares_sum_to_one() -> void:
	var tally := Tally.new()
	_feed(
		tally,
		[
			_event(SimEvent.Kind.HIT, KNIGHT, OGRE, 3),
			_event(SimEvent.Kind.HIT, ROGUE, OGRE, 3),
			_event(SimEvent.Kind.HIT, CLERIC, OGRE, 3),
		]
	)
	var total: float = 0.0
	for hero: int in [KNIGHT, ROGUE, CLERIC]:
		total += tally.share(hero, DAMAGE, SESSION)
	assert_almost_eq(total, 1.0, 0.0001)


func test_percents_round_to_a_whole_hundred() -> void:
	assert_eq(Tally.percents([1, 1, 1]), [34, 33, 33] as Array[int], "thirds")
	assert_eq(Tally.percents([0, 0, 0]), [0, 0, 0] as Array[int], "nothing")
	assert_eq(Tally.percents([5, 0, 995]), [1, 0, 99] as Array[int])
	var total: int = 0
	for percent: int in Tally.percents([7, 13, 29, 51]):
		total += percent
	assert_eq(total, 100)

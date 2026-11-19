extends "res://tests/unit/ability_kit_test_base.gd"
## The faults the review of pull request 50 found in spec 050's battle rules, each pinned here.


## Reapplied every half second, a bleed still bleeds once a second: reapplying moves its end
## and keeps the stronger amount, not its clock.
func test_a_reapplied_bleed_keeps_its_clock() -> void:
	var bleed: Array = [_st("BLEEDING", 2.0, 0.5, "TARGET", BY_DAMAGE)]
	var hero: Combatant = _hero(1, {"attack_interval": 0.4})
	_give(hero, [_action(&"bleed", bleed, {"cooldown": 0.4})])
	var events: Array[SimEvent] = _run(_battle([hero], [_dummy(10)]), 50)
	assert_eq(_ticks(_used(events, &"bleed")).slice(0, 3), _ints([2, 7, 12]), "every 5 ticks")
	var hits: Array[SimEvent] = _of(events, SimEvent.Kind.HIT, 1)
	assert_eq(_ticks(hits), _ints([12, 22, 32, 42]), "it bleeds each second")
	assert_eq(_amounts(hits), _ints([5, 5, 5, 5]))


## A passive set off by the first receiver kills the second: the action's own damage and status
## do not land on the dead, and it dies once.
func test_nothing_but_a_revive_lands_on_the_dead() -> void:
	var sweep: Array = [_fx("DAMAGE", "ENEMIES"), _st("MARKED", 5.0, 2.0, "ENEMIES")]
	var spark: AbilityDef = _passive(&"spark", "LANDS_HIT", [_fx("DAMAGE", "ENEMIES")])
	var hero: Combatant = _give(_hero(1), [_action(&"sweep", sweep), spark])
	var frail: Combatant = _dummy(11, {"max_health": 5})
	var events: Array[SimEvent] = _run(_battle([hero], [_dummy(10), frail]), 2)
	var died: Array[SimEvent] = _of(events, SimEvent.Kind.DIED)
	assert_eq(_ints(died.map(func(e: SimEvent) -> int: return e.source_id)), _ints([11]), "once")
	if died.is_empty():
		return
	for i: int in range(events.find(died[0]) + 1, events.size()):
		assert_ne(events[i].target_id, 11, "after its death: %s" % _line(events[i]))
	assert_eq(frail.statuses.size(), 0)


## Battle.end() ends every status with its event; the battle ending does the same through it.
func test_end_ends_every_status() -> void:
	var all_out: Array = [_st("BURNING", 100.0, 1.0, "TARGET", BY_DAMAGE)]
	all_out.append(_st("MIGHTY", 100.0, 2.0, "SELF"))
	var hero: Combatant = _give(_hero(1, STILL), [_action(&"all_out", all_out)])
	var foe: Combatant = _dummy(10)
	var battle: Battle = _battle([hero], [foe])
	_run(battle, 5)
	assert_eq(hero.statuses.size() + foe.statuses.size(), 2, "two statuses on")
	battle.end()
	var ended: Array[SimEvent] = _of(battle.drain_events(), SimEvent.Kind.STATUS_ENDED)
	assert_eq(_targets(ended), _ints([1, 10]), "each ends with its event")
	assert_eq(hero.statuses.size() + foe.statuses.size(), 0)


## A passive that lands on nobody is not used: not on a target its strike already killed, nor
## on a strike that was dodged.
func test_a_passive_on_nobody_is_not_used() -> void:
	var follow: Array = [_fx("DAMAGE", "TARGET")]
	for trigger: String in ["LANDS_HIT", "EVERY_NTH_STRIKE"]:
		var passive: AbilityDef = _passive(&"follow", trigger, follow, {"trigger_every": 1})
		var hero: Combatant = _give(_hero(1), [passive])
		var killed: Array[SimEvent] = _run(_battle([hero], [_dummy(10, {"max_health": 5})], 2.0))
		assert_eq(_of(killed, SimEvent.Kind.DIED).size(), 1, trigger)
		assert_eq(_used(killed, &"follow").size(), 0, "%s on the dead" % trigger)
	var dodge: Array = [_st("NIMBLE", 100.0, 1.0, "SELF")]
	var nimble: AbilityDef = _passive(&"nimble", "FIGHT_STARTS", dodge)
	var every: AbilityDef = _passive(&"every", "EVERY_NTH_STRIKE", follow, {"trigger_every": 1})
	var striker: Combatant = _give(_hero(1), [every])
	var events: Array[SimEvent] = _run(_battle([striker], [_give(_dummy(10), [nimble])], 2.0), 40)
	assert_gt(_of(events, SimEvent.Kind.MISSED, 1).size(), 1, "it was dodged")
	assert_eq(_used(events, &"every").size(), 0, "on a dodged strike")


## A shield or burn measured by a healing power of 0 is worth nothing: it is not put on, and
## no absorb is reported.
func test_a_status_worth_nothing() -> void:
	var shield: Array = [_st("SHIELDED", 100.0, 0.5, "SELF")]
	var hero: Combatant = _give(_hero(1, STILL), [_passive(&"shield", "FIGHT_STARTS", shield)])
	var events: Array[SimEvent] = _run(_battle([hero], [_shooter(10)]), 30)
	assert_eq(_of(events, SimEvent.Kind.STATUS_BEGAN).size(), 0, "no shield of 0")
	assert_eq(_of(events, SimEvent.Kind.MISSED).size(), 0, "no absorb of 0")
	assert_gt(_of(events, SimEvent.Kind.HIT, 10).size(), 0, "the shots land")
	var burn: Array = [_st("BURNING", 3.0, 0.5, "TARGET")]
	hero = _give(_hero(1, STILL), [_action(&"burn", burn)])
	events = _run(_battle([hero], [_dummy(10)]), 30)
	assert_eq(_of(events, SimEvent.Kind.STATUS_BEGAN).size(), 0, "no burn of 0")
	assert_eq(_of(events, SimEvent.Kind.HIT, 1).size(), 0)

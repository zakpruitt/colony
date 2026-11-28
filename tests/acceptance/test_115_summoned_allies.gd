extends "res://tests/unit/ability_kit_test_base.gd"
## Acceptance tests for specs/115-summoned-allies-in-the-simulation/spec.md, one per requirement.
## The fighters, abilities and helpers they build with are in tests/unit/ability_kit_test_base.gd;
## the summons are a hawk (moves, strikes from 4 tiles, 8 s), a turret (never moves, range 5,
## 12 s, cap 2) and a totem (never moves, heals, with Battle Hymn as its ability).

const T050: Script = preload("res://tests/acceptance/test_050_abilities_in_combat.gd")
const T100: Script = preload("res://tests/acceptance/test_100_rooms_shaped_like_caves.gd")
const FIRST: int = Battle.FIRST_SUMMON_ID

## Abilities a test put into Content for a while, taken out after it.
var _added: Array[StringName] = []


func after_each() -> void:
	for id: StringName in _added:
		Content._defs[Content.Kind.ABILITIES].erase(id)
	_added.clear()
	super()


# --- Helpers -------------------------------------------------------------------


## Puts [param ability] into Content until the test ends, so a summon can name it.
func _add_to_content(ability: AbilityDef) -> void:
	Content.ability(ability.id)
	Content._defs[Content.Kind.ABILITIES][ability.id] = ability
	_added.append(ability.id)


func _summon_def(id: StringName, props: Dictionary) -> SummonDef:
	var def := SummonDef.new()
	def.id = id
	def.display_name = String(id).capitalize()
	_set_all(def, props)
	return def


func _hawk(props: Dictionary = {}) -> SummonDef:
	var values: Dictionary = {"move_speed": 3.0, "attack_range": 4.0, "seconds": 8.0}
	values.merge({"health_share": 0.5, "ahead": 2.0})
	values.merge(props, true)
	return _summon_def(&"hawk", values)


func _turret(props: Dictionary = {}) -> SummonDef:
	var values: Dictionary = {"move_speed": 0.0, "attack_range": 5.0, "seconds": 12.0}
	values.merge(props, true)
	return _summon_def(&"turret", values)


func _totem() -> SummonDef:
	var values: Dictionary = {"move_speed": 0.0, "attack_range": 5.0, "seconds": 10.0}
	values.merge({"heal_share": 0.5, "abilities": [&"battle_hymn"] as Array[StringName]})
	return _summon_def(&"totem", values)


## An action aimed at the fighter itself that brings [param def]: ready at once, a one-tick
## wind-up, never round again unless [param props] says so.
func _summoning(id: StringName, def: SummonDef, effect := {}, props := {}) -> AbilityDef:
	var values: Dictionary = {"summon": def}
	values.merge(effect, true)
	var action: Dictionary = {"aim": "SELF"}
	action.merge(props, true)
	return _action(id, [_fx("SUMMON", "SELF", values)], action)


func _call_hawk(props: Dictionary = {}) -> AbilityDef:
	return _summoning(&"call_hawk", _hawk(props))


func _build_turret(count: int = 1, props: Dictionary = {}) -> AbilityDef:
	return _summoning(&"build_turret", _turret(props), {"count": count, "summon_cap": 2})


func _raise_totem() -> AbilityDef:
	return _summoning(&"raise_totem", _totem())


## A ranged hero that strikes from anywhere in the room and never walks.
func _archer(id: int, abilities: Array, props: Dictionary = {}) -> Combatant:
	var values: Dictionary = {"attack_range": 20.0}
	values.merge(props, true)
	return _give(_hero(id, values, HeroClassDef.Role.RANGED), abilities)


## Steps [param battle] [param ticks] times (or to its end), collecting the events.
func _more(battle: Battle, ticks: int) -> Array[SimEvent]:
	return _run(battle, ticks)


func _fighter_ids(list: Array[Combatant]) -> Array[int]:
	return _ints(list.map(func(c: Combatant) -> int: return c.id))


func _after(events: Array[SimEvent], tick: int) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.tick > tick:
			found.append(e)
	return found


func _refused_by_name(effect: AbilityEffect, words: String) -> void:
	var ability: AbilityDef = _action(&"bad", [effect], {"aim": "SELF"})
	var found: PackedStringArray = ability.validate()
	assert_eq(found.size(), 1, "%s: one problem, %s" % [words, found])
	assert_true("\n".join(found).contains(words), "%s is named: %s" % [words, found])


# --- R1 ------------------------------------------------------------------------


func test_r1_a_summon_is_data() -> void:
	var saved: AbilityDef = _build_turret(1, {"abilities": [&"battle_hymn"] as Array[StringName]})
	assert_eq(saved.validate(), PackedStringArray(), "a summoning ability is valid")
	assert_eq(ResourceSaver.save(saved, _save_path), OK)
	var loaded: AbilityDef = (
		ResourceLoader.load(_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AbilityDef
	)
	assert_not_null(loaded, "it loads as an AbilityDef")
	if loaded == null:
		return
	assert_eq(loaded.validate(), PackedStringArray(), "it validates")
	var effect: AbilityEffect = loaded.effects[0]
	assert_eq(effect.does, AbilityEffect.Does.SUMMON)
	assert_eq(effect.summon_cap, 2)
	assert_not_null(effect.summon, "its summon is in the one file")
	if effect.summon == null:
		return
	assert_eq(effect.summon.id, &"turret")
	assert_eq(effect.summon.seconds, 12.0)
	assert_eq(effect.summon.abilities, [&"battle_hymn"] as Array[StringName])
	assert_eq(AbilityEffect.Does.SUMMON, AbilityEffect.Does.size() - 1, "SUMMON comes last")

	var bare: AbilityEffect = _fx("SUMMON", "SELF")
	_refused_by_name(bare, "no summon")
	_refused_by_name(_fx("SUMMON", "SELF", {"summon": _turret(), "count": 0}), "count")
	_refused_by_name(_fx("SUMMON", "SELF", {"summon": _turret(), "summon_cap": 0}), "summon_cap")
	var elsewhere: AbilityDef = _action(&"bad", [_fx("SUMMON", "TARGET", {"summon": _turret()})])
	var found: PackedStringArray = elsewhere.validate()
	assert_eq(found.size(), 1, "landing on the target is refused: %s" % [found])
	assert_true("\n".join(found).contains("SELF"), "by name: %s" % [found])

	var summoner: AbilityDef = _summoning(&"test_115_summoner", _turret())
	_add_to_content(summoner)
	var bad_fields: Dictionary = {
		"id": {"id": &""},
		"display_name": {"display_name": ""},
		"health_share": {"health_share": 0.0},
		"damage_share": {"damage_share": -0.5},
		"heal_share": {"heal_share": -0.1},
		"seconds": {"seconds": 0.0},
		"move_speed": {"move_speed": -1.0},
		"armor": {"armor": -1},
		"ahead": {"ahead": -0.5},
		"attack_interval": {"attack_interval": 0.0},
		"windup": {"windup": 0.0},
		"attack_range": {"attack_range": 0.0},
		"no_such_ability": {"abilities": [&"no_such_ability"] as Array[StringName]},
		"test_115_summoner": {"abilities": [&"test_115_summoner"] as Array[StringName]},
	}
	for words: String in bad_fields:
		var bad: Dictionary = bad_fields[words]
		_refused_by_name(_fx("SUMMON", "SELF", {"summon": _turret(bad)}), words)


# --- R2 ------------------------------------------------------------------------


func test_r2_arrives_and_fights() -> void:
	# The hawk: its numbers from its level-3 summoner's, its place two tiles ahead of it.
	_add_to_content(_marker(&"test_115_mark", "LANDS_HIT"))
	var def: HeroClassDef = _hero_def(HeroClassDef.Role.MELEE, {"max_health": 120})
	_set_all(def, {"health_per_level": 0, "damage_per_level": 0, "armor": 3})
	var hero: Combatant = Combatant.from_hero(def, 3, 1)
	var mark: Array[StringName] = [&"test_115_mark"]
	_give(hero, [_call_hawk({"damage_share": 0.3, "abilities": mark})])
	var foe: Combatant = _dummy(101)
	var battle: Battle = _battle([hero], [foe])
	var events: Array[SimEvent] = _run(battle, 2)
	var summoned: Array[SimEvent] = _of(events, SimEvent.Kind.SUMMONED)
	assert_eq(summoned.size(), 1, "one hawk came")
	if summoned.is_empty():
		return
	assert_eq(_line(summoned[0]), "SUMMONED 2 1 %d 80 false" % FIRST, "summoner, id, 8 s")
	assert_eq(summoned[0].ability_id, &"call_hawk", "and the ability that called it")
	var hawk: Combatant = battle.combatant(FIRST)
	assert_not_null(hawk, "the battle knows it")
	if hawk == null:
		return
	assert_true(hawk.is_summon(), "a summon")
	assert_false(hero.is_summon(), "a hero is not")
	assert_eq(hawk.owner_id, 1, "its summoner")
	assert_eq(hawk.team, Combatant.Team.HEROES, "on the heroes' side")
	assert_eq(hawk.def_id, &"hawk")
	assert_eq(hawk.level, 3, "at its summoner's level")
	assert_eq([hawk.max_health, hawk.health], [60, 60], "half of 120")
	assert_eq(hawk.damage, 3, "0.3 of 10")
	assert_eq(hawk.heal_power, 0, "no healing with no share")
	assert_eq([hawk.armor, hawk.attack_range, hawk.move_speed], [0, 4.0, 3.0], "its own numbers")
	assert_eq(hawk.ends_tick, 2 + 80, "its time runs out 8 s on")
	assert_almost_eq(hawk.x, hero.x + 2.0, Battle.EPSILON, "two tiles ahead of its summoner")
	assert_eq(_fighter_ids(battle.summons), [FIRST] as Array[int])
	assert_eq(_fighter_ids(battle.fighters()), [1, FIRST, 101] as Array[int], "after the heroes")
	assert_eq(battle.allies_of(hero), battle.allies_of(hawk), "one side")
	assert_eq(_fighter_ids(battle.enemies_of(foe)), [1, FIRST] as Array[int], "heroes then summons")
	assert_eq(_fighter_ids(battle.heroes), [1] as Array[int], "heroes are still the party's")
	var arrived_at: float = hawk.x
	assert_eq(_of(events, SimEvent.Kind.ATTACK_STARTED, FIRST).size(), 0, "nothing yet")
	_more(battle, 1)
	assert_almost_eq(hawk.x, arrived_at + 0.3, Battle.EPSILON, "it walks from the next tick")
	events = _more(battle, 100)
	var hits: Array[SimEvent] = _of(events, SimEvent.Kind.HIT, FIRST)
	assert_gt(hits.size(), 0, "it strikes")
	var marks: Array[SimEvent] = _used(events, &"test_115_mark")
	assert_gt(marks.size(), 0, "its strikes set off its own passive")
	for e: SimEvent in marks:
		assert_eq(e.source_id, FIRST, "its own")

	# Inside the room, and ahead toward the enemy whichever side the heroes came in from.
	var far: Combatant = _give(_hero(1), [_call_hawk({"ahead": 30.0})])
	var walled: Battle = _battle([far], [_dummy(101)])
	_run(walled, 2)
	assert_eq(walled.combatant(FIRST).x, 16.0, "no further than the wall")
	var lefty: Combatant = _give(_hero(1), [_call_hawk()])
	var heroes: Array[Combatant] = [lefty]
	var foes: Array[Combatant] = [_dummy(101)]
	var mirrored := Battle.new(heroes, foes, 0.0, 16.0, false, SimRng.new(SEED))
	_run(mirrored, 2)
	assert_almost_eq(mirrored.combatant(FIRST).x, lefty.x - 2.0, Battle.EPSILON, "to the left")

	# Two turrets act in the order summoned; one that never moves strikes only in its range.
	var builder: Combatant = _give(_hero(1), [_build_turret(2)])
	var near: Battle = _battle([builder], [_dummy(101)], 6.0)
	events = _run(near, 3)
	var started: Array[SimEvent] = _of(events, SimEvent.Kind.ATTACK_STARTED)
	var by_turrets: Array[int] = []
	for e: SimEvent in started:
		if e.source_id >= FIRST and e.source_id <= Battle.LAST_SUMMON_ID:
			assert_eq(e.tick, 3, "from the tick after they came")
			by_turrets.append(e.source_id)
	assert_eq(by_turrets, [FIRST, FIRST + 1] as Array[int], "in the order summoned")

	var lone: Combatant = _give(_hero(1), [_build_turret()])
	var target: Combatant = _dummy(101)
	var wide: Battle = _battle([lone], [target])
	events = _run(wide, 40)
	var turret: Combatant = wide.combatant(FIRST)
	assert_eq(_of(events, SimEvent.Kind.ATTACK_STARTED, FIRST).size(), 0, "out of range: waits")
	assert_almost_eq(turret.x, 1.0, Battle.EPSILON, "and never moves")
	assert_ne(turret.state, Combatant.State.MOVING, "it waits, not walks")
	target.x = 4.0
	events = _more(wide, 20)
	assert_gt(_of(events, SimEvent.Kind.ATTACK_STARTED, FIRST).size(), 0, "in range: it strikes")
	assert_gt(_of(events, SimEvent.Kind.PROJECTILE_LAUNCHED, FIRST).size(), 0, "a shot")
	assert_almost_eq(turret.x, 1.0, Battle.EPSILON, "from where it stands")

	# The totem: healing half its summoner's, hasting the side with Battle Hymn as it comes.
	var healer: Combatant = _archer(1, [_raise_totem()], {"heal_power": 10})
	healer.role = HeroClassDef.Role.HEALER
	var hurt: Combatant = _hero(2, {}, HeroClassDef.Role.TANK)
	hurt.health = 30
	var hymn: Battle = _battle([healer, hurt], [_dummy(101)])
	events = _run(hymn, 60)
	var totem: Combatant = hymn.combatant(FIRST)
	assert_not_null(totem, "the totem came")
	if totem == null:
		return
	assert_eq(totem.heal_power, 5, "half of 10")
	assert_eq(totem.role, HeroClassDef.Role.HEALER, "a healer")
	var hymns: Array[SimEvent] = _used(events, &"battle_hymn")
	assert_eq(hymns.size(), 1, "its Battle Hymn, as it came")
	if not hymns.is_empty():
		assert_eq([hymns[0].source_id, hymns[0].tick], [FIRST, 2], "the totem's, on tick 2")
	var hasted: Array[int] = []
	for e: SimEvent in _of(events, SimEvent.Kind.STATUS_BEGAN, FIRST):
		if e.status == AbilityEffect.Status.HASTED:
			hasted.append(e.target_id)
	assert_eq(hasted, [1, 2, FIRST] as Array[int], "every ally hasted, the totem too")
	assert_true(totem.has_status(AbilityEffect.Status.HASTED), "statuses land on it")
	var heals: Array[SimEvent] = _of(events, SimEvent.Kind.HEALED, FIRST)
	assert_gt(heals.size(), 0, "it heals")
	for e: SimEvent in heals:
		assert_eq(e.target_id, 2, "the hurt hero")
		assert_between(e.amount, 4, 6, "about 5")
	assert_almost_eq(totem.x, healer.x + 1.0, Battle.EPSILON, "and never moves")


# --- R3 ------------------------------------------------------------------------


func test_r3_monsters_fight_it() -> void:
	var rally: AbilityDef = _passive(&"rally", "LANDS_HIT", [_st("MIGHTY", 5.0, 1.5, "ALLIES")])
	var hero: Combatant = _archer(1, [_build_turret(1, {"ahead": 3.0}), rally])
	var splash: Array = [_fx("DAMAGE", "AROUND_TARGET", {"radius": 5.0})]
	var props: Dictionary = {"ready_at_start": false, "cooldown": 1.0}
	var shooter: Combatant = _shooter(101, {"max_health": 100_000, "damage": 1})
	_give(shooter, [_action(&"splash", splash, props)])
	var battle: Battle = _battle([hero], [shooter])
	var events: Array[SimEvent] = _run(battle, 60)
	assert_eq(battle.summons.size(), 1, "the turret stands")
	var aimed: Array[int] = []
	for e: SimEvent in _after(_of(events, SimEvent.Kind.ATTACK_STARTED, 101), 2):
		aimed.append(e.target_id)
	assert_gt(aimed.size(), 0, "the monster attacked after the turret came")
	for id: int in aimed:
		assert_eq(id, FIRST, "the turret, nearer than the hero")
	var splashed: Array[SimEvent] = _landing(_after(events, 2), &"splash")
	assert_eq(_targets(_of(splashed, SimEvent.Kind.HIT, 101)), [1, FIRST] as Array[int], "both")
	var rallied: Array[int] = []
	for e: SimEvent in _of(events, SimEvent.Kind.STATUS_BEGAN, 1):
		if e.ability_id == &"rally":
			rallied.append(e.target_id)
	assert_has(rallied, FIRST, "a hero's status on its allies reaches the turret")

	# A taunting summon draws the monsters.
	var taunt: AbilityDef = _ability(&"test_115_taunt", AbilityDef.Kind.PASSIVE, [])
	taunt.effects.assign([_st("TAUNTING", NEVER, 0.0, "SELF")])
	_add_to_content(taunt)
	var bait: Array[StringName] = [&"test_115_taunt"]
	var lure: Combatant = _archer(1, [_build_turret(1, {"ahead": 7.0, "abilities": bait})])
	var near: Combatant = _hero(2, {}, HeroClassDef.Role.TANK)
	var brute: Combatant = _shooter(101, {"max_health": 100_000, "damage": 1, "attack_range": 6.0})
	var drawn: Battle = _battle([lure, near], [brute])
	events = _run(drawn, 80)
	var brute_aims: Array[SimEvent] = _after(_of(events, SimEvent.Kind.ATTACK_STARTED, 101), 2)
	assert_gt(brute_aims.size(), 0, "the brute attacked")
	for e: SimEvent in brute_aims:
		assert_eq(e.target_id, FIRST, "the taunting turret")
	var turret_gap: float = absf(drawn.combatant(FIRST).x - brute.x)
	assert_lt(absf(near.x - brute.x), turret_gap, "though the tank stands nearer")

	# A healer and an action at the weakest ally pass over a hurt turret.
	var mend: AbilityDef = _action(&"mend", [_fx("HEAL", "TARGET")], {"aim": "WEAKEST_ALLY"})
	var healer: Combatant = _archer(1, [_build_turret(), mend], {"heal_power": 10})
	healer.role = HeroClassDef.Role.HEALER
	var scratched: Combatant = _hero(2)
	scratched.health = 90
	var quiet: Battle = _battle([healer, scratched], [_dummy(101)])
	_run(quiet, 2)
	var turret: Combatant = quiet.combatant(FIRST)
	assert_not_null(turret, "the turret came")
	if turret == null:
		return
	turret.health = 1
	events = _more(quiet, 60)
	for e: SimEvent in _of(events, SimEvent.Kind.HEALED):
		assert_ne(e.target_id, FIRST, "no heal spent on the turret")
	for e: SimEvent in _of(events, SimEvent.Kind.PROJECTILE_LAUNCHED, 1):
		assert_ne(e.target_id, FIRST, "nor aimed at it")
	var mended: Array[SimEvent] = _used(events, &"mend")
	assert_eq(_targets(mended), [2] as Array[int], "the weakest hero, not the turret")
	assert_eq(turret.health, 1, "still hurt")


# --- R4 ------------------------------------------------------------------------


func test_r4_a_summon_ends() -> void:
	# Its time runs out: the totem's own statuses end with it.
	var healer: Combatant = _archer(1, [_raise_totem()], {"heal_power": 10})
	var timed: Battle = _battle([healer], [_dummy(101)])
	var events: Array[SimEvent] = _run(timed, 120)
	var ended: Array[SimEvent] = _of(events, SimEvent.Kind.SUMMON_ENDED)
	assert_eq(ended.size(), 1, "the totem ended")
	if ended.is_empty():
		return
	assert_eq(_line(ended[0]), "SUMMON_ENDED 102 %d 1 0 false" % FIRST, "10 s on: time")
	var its_own: Array[SimEvent] = []
	for e: SimEvent in _of(events, SimEvent.Kind.STATUS_ENDED):
		if e.target_id == FIRST:
			its_own.append(e)
	assert_eq(its_own.size(), 1, "its haste ended with it")
	for c: Combatant in timed.fighters():
		for status: CombatStatus in c.statuses.values():
			assert_ne(status.source_id, FIRST, "nothing left that it put on")
	assert_eq(_of(events, SimEvent.Kind.DIED).size(), 0, "no death")
	_none_left(timed)

	# It falls: no death, no Guardian Angel, no kill, never revived.
	var angel: Combatant = _give_twelve(_archer(1, []), ["guardian_angel"])
	angel.abilities.push_front(_build_turret(1, {"ahead": 3.0}))
	var gloat: AbilityDef = _marker(&"gloat", "KILLS")
	var shooter: Combatant = _give(_shooter(101, {"max_health": 100_000}), [gloat])
	var falling: Battle = _battle([angel], [shooter])
	_run(falling, 2)
	var turret: Combatant = falling.combatant(FIRST)
	assert_not_null(turret, "the turret came")
	if turret == null:
		return
	turret.health = 1
	events = _more(falling, 40)
	ended = _of(events, SimEvent.Kind.SUMMON_ENDED)
	assert_eq(ended.size(), 1, "it fell")
	if not ended.is_empty():
		assert_eq([ended[0].source_id, ended[0].target_id, ended[0].amount], [FIRST, 1, 1])
		var blows: Array[int] = _targets(_of(events, SimEvent.Kind.HIT, 101))
		assert_has(blows, FIRST, "struck down by the monster")
	assert_eq(_of(events, SimEvent.Kind.DIED).size(), 0, "no DIED")
	assert_eq(_used(events, &"guardian_angel").size(), 0, "no Guardian Angel")
	assert_eq(_of(events, SimEvent.Kind.REVIVED).size(), 0, "never revived")
	assert_eq(_used(events, &"gloat").size(), 0, "no kill for the monster's passive")
	assert_eq(falling.heroes.size(), 1, "the heroes are as they were")
	assert_true(angel.is_alive(), "its summoner stands")
	_none_left(falling)

	# A third turret over the cap of two replaces its summoner's oldest, not another's.
	var other: Combatant = _give(_hero(2), [_build_turret(1)])
	var builder: Combatant = _give(_hero(1), [_build_turret(3)])
	var capped: Battle = _battle([other, builder], [_dummy(101)])
	events = _run(capped, 2)
	var lines: Array[String] = []
	for e: SimEvent in events:
		if e.kind == SimEvent.Kind.SUMMONED or e.kind == SimEvent.Kind.SUMMON_ENDED:
			lines.append(
				"%s %d %d %d" % [SimEvent.Kind.keys()[e.kind], e.source_id, e.target_id, e.amount]
			)
	var expected: Array[String] = [
		"SUMMONED 2 %d 120" % FIRST,
		"SUMMONED 1 %d 120" % (FIRST + 1),
		"SUMMONED 1 %d 120" % (FIRST + 2),
		"SUMMON_ENDED %d 1 2" % (FIRST + 1),
		"SUMMONED 1 %d 120" % (FIRST + 3),
	]
	assert_eq(lines, expected, "the oldest of the builder's own goes, replaced")
	assert_eq(_fighter_ids(capped.summons), [FIRST, FIRST + 2, FIRST + 3] as Array[int])
	assert_null(capped.combatant(FIRST + 1), "the replaced one is gone")

	# The fight ends, won: every summon ends with it, and so when it is stopped early.
	var winner: Combatant = _give(_hero(1, {"damage": 40}), [_call_hawk()])
	var won: Battle = _battle([winner], [_shooter(101, {"max_health": 60})], 6.0)
	events = _run(won)
	assert_eq(won.result(), Battle.Result.HEROES_WON)
	ended = _of(events, SimEvent.Kind.SUMMON_ENDED)
	assert_eq(_amounts(ended), [3] as Array[int], "the fight ended")
	if not ended.is_empty():
		assert_eq(ended[0].tick, won.tick, "as it ended")
	_none_left(won)
	var stopped: Battle = _battle([_give(_hero(1), [_call_hawk()])], [_dummy(101)])
	_run(stopped, 5)
	stopped.end()
	assert_eq(_amounts(_of(stopped.drain_events(), SimEvent.Kind.SUMMON_ENDED)), [3] as Array[int])
	_none_left(stopped)

	# It outlives its summoner.
	var caller: Combatant = _give(_hero(1), [_call_hawk()])
	var tank: Combatant = _hero(2, {"max_health": 1000}, HeroClassDef.Role.TANK)
	var foe: Combatant = _dummy(101)
	var orphaned: Battle = _battle([caller, tank], [foe])
	_run(orphaned, 2)
	orphaned.deal(foe, caller, 10_000, false, Battle.Via.STRIKE)
	assert_false(caller.is_alive(), "the summoner fell")
	events = orphaned.drain_events()
	events.append_array(_more(orphaned, 60))
	assert_eq(_fighter_ids(orphaned.summons), [FIRST] as Array[int], "the hawk stays")
	assert_eq(_of(events, SimEvent.Kind.SUMMON_ENDED).size(), 0, "not ended")
	assert_gt(_of(events, SimEvent.Kind.ATTACK_STARTED, FIRST).size(), 0, "and fights on")


## No summon left in [param battle]: not in its lists, not found by id.
func _none_left(battle: Battle) -> void:
	assert_eq(battle.summons.size(), 0, "no summon left")
	for c: Combatant in battle.fighters():
		assert_false(c.is_summon(), "none among the fighters")
	for c: Combatant in battle.enemies_of(battle.monsters[0]):
		assert_false(c.is_summon(), "none on the heroes' side")
	for id: int in range(FIRST, Battle.LAST_SUMMON_ID + 1):
		assert_null(battle.combatant(id), "none found by id %d" % id)


# --- R5 ------------------------------------------------------------------------


func test_r5_who_wins_and_credit() -> void:
	# Lost with a turret standing.
	var hero: Combatant = _archer(1, [_build_turret(1, {"ahead": 3.0})])
	var shooter: Combatant = _shooter(101, {"max_health": 100_000})
	var lost: Battle = _battle([hero], [shooter])
	_run(lost, 2)
	lost.deal(shooter, hero, 10_000, false, Battle.Via.STRIKE)
	assert_eq(lost.summons.size(), 1, "the turret stands")
	assert_true(lost.combatant(FIRST).is_alive())
	_more(lost, 1)
	assert_eq(lost.result(), Battle.Result.MONSTERS_WON, "every hero fell: lost")
	_none_left(lost)

	# Sources and the summoner.
	var caller: Combatant = _give(_hero(1), [_call_hawk()])
	var healer: Combatant = _archer(2, [_raise_totem()], {"heal_power": 10})
	healer.role = HeroClassDef.Role.HEALER
	caller.health = 40
	var credited: Battle = _battle([caller, healer], [_dummy(101)])
	var events: Array[SimEvent] = _run(credited, 60)
	assert_eq(credited.combatant(FIRST).owner_id, 1, "the hawk is the caller's")
	assert_eq(credited.combatant(FIRST + 1).owner_id, 2, "the totem the healer's")
	assert_gt(_of(events, SimEvent.Kind.HIT, FIRST).size(), 0, "the hawk's hits are its own")
	assert_gt(_of(events, SimEvent.Kind.HEALED, FIRST + 1).size(), 0, "the totem's heals")
	assert_gt(_of(events, SimEvent.Kind.STATUS_BEGAN, FIRST + 1).size(), 0, "and statuses")
	assert_eq(caller.uses.keys(), [&"call_hawk"], "the summoning, counted")
	var called: int = caller.uses.get(&"call_hawk", 0)
	assert_eq(called, 1)
	assert_eq(healer.uses.keys(), [&"raise_totem"], "not the totem's hymn")
	var sung: int = credited.combatant(FIRST + 1).uses.get(&"battle_hymn", 0)
	assert_eq(sung, 1, "the totem's own")

	# Path XP: the cleric's summoning ability counts, its totem's Battle Hymn does not.
	var sim := Simulation.new(SEED)
	var cleric: Hero = sim.party.heroes[3]
	assert_eq(cleric.class_id, &"cleric")
	raise(cleric, 4)
	cleric.set_talents([&"battle_hymn"] as Array[StringName])
	var fighter: Combatant = cleric.combatant()
	fighter.abilities.assign([_summoning(&"prayer", _totem())])
	var monsters: Array[Combatant] = [_dummy(101)]
	var heroes: Array[Combatant] = [fighter]
	var fought := Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(SEED))
	events = _run(fought, 5)
	assert_eq(_used(events, &"battle_hymn").size(), 1, "the totem sang")
	PathTraining.after_win(sim.expedition, fought)
	var xp: Array[int] = []
	for path: int in TalentTreeDef.PATH_COUNT:
		xp.append(cleric.ranks.xp(path))
	assert_eq(xp, [1, 0, 1] as Array[int], "a use of the summoning; the hymn held, not used")

	# In an expedition: a monster the hawk kills rewards the party as a hero's kill would.
	var run := Simulation.new(SEED)
	assert_true(step_until(run, func() -> bool: return run.expedition.battle != null, 3000))
	var battle: Battle = run.expedition.battle
	run.drain_events()
	for each: Combatant in battle.heroes:
		each.ready_tick = 1 << 30
	var party: Array[int] = _fighter_ids(battle.heroes)
	var kinds: Dictionary[int, StringName] = {}
	for monster: Combatant in battle.monsters:
		kinds[monster.id] = monster.def_id
	var strong: AbilityDef = _summoning(&"call_hawk", _hawk({"damage_share": 50.0}))
	BattleSummons.summon(battle, battle.heroes[0], strong.effects[0], strong)
	assert_eq(_fighter_ids(battle.heroes), party, "the heroes are the party's fighters")
	events = []
	for i: int in ticks_in(120.0):
		run.step()
		var got: Array[SimEvent] = run.drain_events()
		events.append_array(got)
		if not _of(got, SimEvent.Kind.ENCOUNTER_ENDED).is_empty():
			break
	var fight_end: Array[SimEvent] = _of(events, SimEvent.Kind.ENCOUNTER_ENDED)
	assert_eq(fight_end.size(), 1, "the fight ended")
	if fight_end.is_empty():
		return
	assert_true(fight_end[0].flag, "won")
	var deaths: Array[SimEvent] = _of(events, SimEvent.Kind.DIED)
	assert_eq(deaths.size(), kinds.size(), "every monster fell")
	for death: SimEvent in deaths:
		var at: int = events.find(death)
		var blow: SimEvent = null
		for i: int in range(at - 1, -1, -1):
			if events[i].kind == SimEvent.Kind.HIT and events[i].target_id == death.source_id:
				blow = events[i]
				break
		assert_not_null(blow, "a blow felled %d" % death.source_id)
		if blow != null:
			assert_eq(blow.source_id, FIRST, "the hawk's")
		var xp_each: int = Content.monster(kinds[death.source_id]).xp
		var given: Array[SimEvent] = []
		var gold: int = 0
		for i: int in range(at + 1, events.size()):
			var e: SimEvent = events[i]
			if e.kind == SimEvent.Kind.DIED or e.kind == SimEvent.Kind.ENCOUNTER_ENDED:
				break
			if e.kind == SimEvent.Kind.XP_GAINED:
				given.append(e)
			if e.kind == SimEvent.Kind.GOLD_GAINED and e.source_id == death.source_id:
				gold += 1
		assert_eq(_targets(given), party, "XP for every hero standing")
		assert_eq(_amounts(given), _ints(party.map(func(_i: int) -> int: return xp_each)))
		assert_eq(gold, 1, "and gold")
	assert_eq(_amounts(_of(events, SimEvent.Kind.SUMMON_ENDED)), [3] as Array[int])


# --- R6 ------------------------------------------------------------------------


func test_r6_ids() -> void:
	# Fifty-one at once: ids 50 to 99, then the fifty-first replaces the oldest and takes 50.
	var crowd: AbilityDef = _summoning(&"crowd", _turret(), {"count": 51, "summon_cap": 100})
	var battle: Battle = _battle([_give(_hero(1), [crowd])], [_dummy(101)])
	var events: Array[SimEvent] = _run(battle, 2)
	var came: Array[int] = _targets(_of(events, SimEvent.Kind.SUMMONED))
	var expected: Array[int] = []
	for id: int in range(FIRST, Battle.LAST_SUMMON_ID + 1):
		expected.append(id)
	expected.append(FIRST)
	assert_eq(came, expected, "50 to 99, then 50 again")
	var ended: Array[SimEvent] = _of(events, SimEvent.Kind.SUMMON_ENDED)
	assert_eq(ended.size(), 1, "one replaced")
	var arrivals: Array[SimEvent] = _of(events, SimEvent.Kind.SUMMONED)
	if ended.is_empty() or arrivals.size() != 51:
		return
	assert_eq([ended[0].source_id, ended[0].amount], [FIRST, 2], "the oldest, replaced")
	assert_lt(events.find(ended[0]), events.find(arrivals[50]), "before the fifty-first came")
	assert_eq(battle.summons.size(), 50, "fifty at once")
	assert_eq(battle.summons[0].id, FIRST + 1, "the oldest now")
	assert_eq(battle.summons[49].id, FIRST, "the newest")
	assert_eq(battle.combatant(FIRST), battle.summons[49], "its id finds the new one")

	# Ten at a time, again and again: the ids go round, distinct while alive.
	var props: Dictionary = {"cooldown": 0.5}
	var waves: AbilityDef = _summoning(&"waves", _turret(), {"count": 10, "summon_cap": 10}, props)
	var long: Battle = _battle([_archer(1, [waves])], [_dummy(101)])
	var ids: Array[int] = []
	for i: int in ticks_in(60.0):
		long.step()
		ids.append_array(_targets(_of(long.drain_events(), SimEvent.Kind.SUMMONED)))
		var alive: Array[int] = _fighter_ids(long.summons)
		var seen: Dictionary[int, bool] = {}
		for id: int in alive:
			assert_false(seen.has(id), "id %d once among the living, tick %d" % [id, long.tick])
			seen[id] = true
		assert_lte(alive.size(), 10, "ten at most")
	assert_gt(ids.size(), 120, "more than twice round")
	for i: int in ids.size():
		assert_eq(ids[i], FIRST + i % 50, "summon %d in turn" % i)
		if ids[i] != FIRST + i % 50:
			return
	assert_lt(Battle.LAST_SUMMON_ID, Expedition.FIRST_MONSTER_ID, "under every monster id")

	# Round again, an id still held is passed over.
	var keeper: Combatant = _give(_hero(1), [_build_turret(1, {"seconds": 100.0})])
	var short: Dictionary = {"count": 49, "summon_cap": 100}
	var flock: AbilityDef = _summoning(&"flock", _hawk({"seconds": 1.0}), short, props)
	var skipping: Battle = _battle([keeper, _archer(2, [flock])], [_dummy(101)])
	events = _run(skipping, 40)
	var flown: Array[int] = []
	for e: SimEvent in _of(events, SimEvent.Kind.SUMMONED, 2):
		flown.append(e.target_id)
	assert_eq(flown.size(), 98, "two flocks")
	if flown.size() == 98:
		assert_eq([flown[0], flown[48]], [FIRST + 1, Battle.LAST_SUMMON_ID], "the first flock")
		assert_eq([flown[49], flown[97]], [FIRST + 1, Battle.LAST_SUMMON_ID], "50 passed over")
	assert_eq(skipping.combatant(FIRST).def_id, &"turret", "50 is still the turret")


# --- R7 ------------------------------------------------------------------------


func test_r7_nothing_changes() -> void:
	var recorded: Array[String] = []
	var text: String = (T050 as GDScript).get_script_constant_map().get("RECORDED", "")
	for line: String in text.replace("\n", " | ").split(" | ", false):
		recorded.append(line.strip_edges())
	assert_gt(recorded.size(), 50, "spec 050's recorded battle")
	var other: Node = (T050 as GDScript).new()
	var plain: Battle = other.call("_plain_battle", SEED)
	other.free()
	var lines: Array[String] = []
	for e: SimEvent in _run(plain):
		lines.append(_line(e))
	assert_eq(lines, recorded, "event for event")

	var hashes: Dictionary = (T100 as GDScript).get_script_constant_map().get("RECORDED_HASHES", {})
	assert_eq(hashes.size(), 3, "three recorded hashes")
	for seed_value: int in hashes:
		var sim: Simulation = winding_simulation(seed_value)
		run_ticks(sim, ticks_in(300.0))
		var recorded_hash: int = hashes[seed_value]
		assert_eq(sim.state_hash(), recorded_hash, "seed %d hashes as before" % seed_value)


# --- R8 ------------------------------------------------------------------------


func test_r8_deterministic() -> void:
	var runs: Array = []
	for i: int in 2:
		var caller: Combatant = _give(_hero(1), [_call_hawk()])
		var builder: Combatant = _archer(2, [_build_turret(3)])
		var healer: Combatant = _archer(3, [_raise_totem()], {"heal_power": 9})
		healer.role = HeroClassDef.Role.HEALER
		var foes: Array = [_shooter(101, {"max_health": 300}), _shooter(102, {"max_health": 300})]
		var battle: Battle = _battle([caller, builder, healer], foes)
		var lines: Array[String] = []
		for e: SimEvent in _run(battle):
			lines.append(_full_line(e))
		runs.append(lines)
	var first: Array = runs[0]
	var again: Array = runs[1]
	assert_eq(first, again, "the same seed, fighters and summons: the same battle")
	var summoned: int = 0
	for line: String in first:
		if line.begins_with("SUMMONED"):
			summoned += 1
	assert_gt(summoned, 3, "summons came")

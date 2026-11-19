extends "res://tests/unit/ability_kit_test_base.gd"
## Acceptance tests for specs/050-abilities-in-combat/spec.md, one per requirement. The
## fighters, abilities and helpers they build with are in tests/unit/ability_kit_test_base.gd.

## Every event of [method _plain_battle] with SEED, recorded on dev before this spec changed
## any battle code: kind, tick, source, target, amount, flag; " | " between events.
const RECORDED: String = """
ATTACK_STARTED 5 4 101 3 false | ATTACK_STARTED 6 1 101 3 false
PROJECTILE_LAUNCHED 8 4 101 5 false | PROJECTILE_LAUNCHED 9 1 101 5 false | HIT 13 4 101 22 true
HIT 14 1 101 4 false | ATTACK_STARTED 14 101 2 3 false | ATTACK_STARTED 15 2 101 3 false
ATTACK_STARTED 16 3 101 3 false | HIT 17 101 2 7 false | HIT 18 2 101 11 false
ATTACK_STARTED 19 1 101 3 false | HIT 19 3 101 11 false | ATTACK_STARTED 21 103 2 3 false
PROJECTILE_LAUNCHED 22 1 101 5 false | ATTACK_STARTED 22 4 101 3 false
PROJECTILE_LAUNCHED 24 103 2 4 false | PROJECTILE_LAUNCHED 25 4 101 4 false | HIT 27 1 101 5 false
ATTACK_STARTED 27 101 2 3 false | HIT 28 103 2 4 false | ATTACK_STARTED 28 2 101 3 false
HIT 29 4 101 9 false | ATTACK_STARTED 29 3 101 3 false | HIT 30 101 2 8 false
HIT 31 2 101 10 false | ATTACK_STARTED 31 102 2 3 false | ATTACK_STARTED 32 1 101 3 false
HIT 32 3 101 14 false | DIED 32 101 -1 0 false | ATTACK_STARTED 33 1 102 3 false
HIT 34 102 2 5 false | PROJECTILE_LAUNCHED 36 1 102 5 false | ATTACK_STARTED 39 4 102 3 false
ATTACK_STARTED 40 103 2 3 false | HIT 41 1 102 2 false | ATTACK_STARTED 41 2 102 3 false
ATTACK_STARTED 42 3 102 3 false | PROJECTILE_LAUNCHED 42 4 102 5 false
PROJECTILE_LAUNCHED 43 103 2 4 false | HIT 44 2 102 9 false | ATTACK_STARTED 44 102 2 3 false
HIT 45 3 102 11 false | ATTACK_STARTED 46 1 102 3 false | HIT 47 4 102 19 true
HIT 47 103 2 5 false | HIT 47 102 2 4 false | PROJECTILE_LAUNCHED 49 1 102 5 false
HIT 54 1 102 3 false | ATTACK_STARTED 54 2 102 3 false | ATTACK_STARTED 55 3 102 3 false
ATTACK_STARTED 56 4 102 3 false | HIT 57 2 102 8 false | ATTACK_STARTED 57 102 2 3 false
HIT 58 3 102 12 false | DIED 58 102 -1 0 false | ATTACK_STARTED 59 1 2 3 false
ATTACK_STARTED 59 103 2 3 false | PROJECTILE_LAUNCHED 62 1 2 4 true
PROJECTILE_LAUNCHED 62 103 2 3 false | HIT 65 103 2 4 false | HEALED 66 1 2 9 false
ATTACK_STARTED 72 4 103 3 false | PROJECTILE_LAUNCHED 75 4 103 5 false
ATTACK_STARTED 77 1 103 3 false | ATTACK_STARTED 78 2 103 3 false | ATTACK_STARTED 78 3 103 3 false
ATTACK_STARTED 78 103 2 3 false | HIT 80 4 103 11 false | PROJECTILE_LAUNCHED 80 1 103 6 false
HIT 81 2 103 11 false | HIT 81 3 103 13 false | PROJECTILE_LAUNCHED 81 103 2 1 false
HIT 82 103 2 4 false | HIT 86 1 103 4 false | ATTACK_STARTED 89 4 103 3 false
ATTACK_STARTED 90 1 103 3 false | ATTACK_STARTED 91 2 103 3 false | ATTACK_STARTED 91 3 103 3 false
PROJECTILE_LAUNCHED 92 4 103 5 false | PROJECTILE_LAUNCHED 93 1 103 6 false | HIT 94 2 103 9 false
HIT 94 3 103 12 false | DIED 94 103 -1 0 false
"""

# --- R1 ------------------------------------------------------------------------


func test_r1_abilities_are_content() -> void:
	for id: StringName in Content.ability_ids():
		assert_eq(Content.ability(id).validate(), PackedStringArray(), "%s is valid" % id)
	assert_null(Content.ability(&"no_such_ability"), "an unknown id finds nothing")

	var bash_effects: Array = [_fx("DAMAGE", "TARGET", {"multiplier": 1.5})]
	bash_effects.append(_st("STUNNED", 2.0, 0.0, "TARGET"))
	var bash_props: Dictionary = {"anywhere": false, "reach": 1.0, "cooldown": 6.0}
	assert_eq(ResourceSaver.save(_action(&"bash", bash_effects, bash_props), _save_path), OK)
	var loaded: AbilityDef = (
		ResourceLoader.load(_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AbilityDef
	)
	assert_not_null(loaded, "it loads as an AbilityDef")
	assert_eq(loaded.validate(), PackedStringArray(), "it validates")
	assert_eq(loaded.id, &"bash")
	assert_eq(loaded.effects.size(), 2, "its effects are in the one file")
	assert_eq(loaded.effects[1].status, AbilityEffect.Status.STUNNED)
	assert_eq(loaded.cooldown, 6.0)

	var problems: PackedStringArray = AbilityDef.new().validate()
	for expected: String in ["id is empty", "display_name is empty", "description is empty"]:
		assert_has(problems, expected)
	assert_has(problems, "it has no effects", "an empty ability is refused")
	var effectless: PackedStringArray = _action(&"nothing", []).validate()
	assert_eq(effectless, PackedStringArray(["it has no effects"]), "an effectless one too")

	var hit: AbilityEffect = _fx("DAMAGE", "TARGET")
	var contradictions: Dictionary = {
		"hurts its own side": _action(&"a", [hit], {"aim": "WEAKEST_ALLY"}),
		"heals the enemy": _action(&"b", [_fx("HEAL", "ENEMIES")]),
		"revives itself": _action(&"c", [_fx("REVIVE", "SELF", {"revive_share": 0.5})]),
		"hastes the enemy": _action(&"d", [_st("HASTED", 2.0, 0.5, "TARGET")]),
		"hits the dead": _passive(&"e", "KILLS", [hit]),
		"never lasts": _action(&"f", [_st("STUNNED", 0.0, 0.0, "TARGET")]),
		"a haste that slows": _action(&"g", [_st("HASTED", 2.0, 1.5, "SELF")]),
		"no damage": _action(&"h", [_fx("DAMAGE", "TARGET", {"multiplier": 0.0})]),
		"no chance": _marker(&"i", "LANDS_HIT", {"chance": 0.0}),
		"no reach": _action(&"j", [hit], {"anywhere": false, "reach": 0.0}),
		"every 0th strike": _marker(&"k", "EVERY_NTH_STRIKE", {"trigger_every": 0}),
	}
	for label: String in contradictions:
		var found: PackedStringArray = (contradictions[label] as AbilityDef).validate()
		assert_eq(found.size(), 1, "%s is refused: %s" % [label, found])


# --- R2 ------------------------------------------------------------------------


func test_r2_actions() -> void:
	var hit: Array = [_fx("DAMAGE", "TARGET")]
	# Ready at the start: in a 2-tile room the hero reaches the dummy on tick 3 and winds up for
	# 5 ticks. Its next strike is 10 ticks after the action lands, and the action comes round 30
	# ticks after it landed, at the hero's first free moment.
	var props: Dictionary = {"anywhere": false, "reach": 1.0, "cooldown": 3.0, "windup": 0.5}
	var hero: Combatant = _give(_hero(1), [_action(&"bash", hit, props)])
	var events: Array[SimEvent] = _run(_battle([hero], [_dummy(10)], 2.0), 50)
	var started: Array[SimEvent] = _of(events, SimEvent.Kind.ABILITY_STARTED)
	assert_eq(_ticks(started), _ints([3, 44]), "at once, then after its cooldown")
	assert_eq(started[0].amount, 5, "the wind-up in ticks")
	assert_eq(started[0].ability_id, &"bash")
	assert_eq(_ticks(_used(events, &"bash")), _ints([8, 49]), "it lands after its wind-up")
	var strikes: Array[int] = _ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 1))
	assert_eq(strikes, _ints([18, 31]), "ordinary strikes in between, none in its place")

	# Not ready at the start: the first comes at the first free moment after 20 ticks.
	props["ready_at_start"] = false
	props["cooldown"] = 2.0
	hero = _give(_hero(1), [_action(&"bash", hit, props)])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 30)
	assert_eq(_ticks(_of(events, SimEvent.Kind.ABILITY_STARTED)), _ints([29]), "not ready")
	assert_eq(_ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 1)), _ints([3, 16]))

	# Each aim. Monsters stand at 9.33 (10), 12 (11, the weakest) and 14.67 (12).
	var aims: Dictionary = {
		"NEAREST_ENEMY": 10, "WEAKEST_ENEMY": 11, "FURTHEST_ENEMY": 12, "SELF": 1
	}
	var mark: Array = [_st("MARKED", 2.0, 1.5, "ENEMIES")]
	for aim: String in aims:
		var monsters: Array[Combatant] = _typed([_dummy(10), _dummy(11), _dummy(12)])
		monsters[1].health = 300
		hero = _give(_hero(1), [_action(&"aimed", mark, {"aim": aim})])
		started = _of(_run(_battle([hero], monsters), 1), SimEvent.Kind.ABILITY_STARTED)
		assert_eq(_targets(started), _ints([aims[aim]]), aim)
	var mend: Array = [_fx("HEAL", "TARGET")]
	var healer: Combatant = _hero(1, {"heal_power": 10}, HeroClassDef.Role.HEALER)
	var hurt: Combatant = _hero(2, {}, HeroClassDef.Role.TANK)
	hurt.health = 40
	_give(healer, [_action(&"mend", mend, {"aim": "WEAKEST_ALLY"})])
	var others: Array = [hurt, _hero(3, {}, HeroClassDef.Role.RANGED)]
	events = _run(_battle([healer] + others, [_dummy(10)]), 1)
	assert_eq(_targets(_of(events, SimEvent.Kind.ABILITY_STARTED)), _ints([2]), "WEAKEST_ALLY")

	# Range: the hero walks until the dummy at 12 is 4 tiles away, then winds up. (Anywhere:
	# the aims above all started on tick 1, from where the hero stood.)
	var far: AbilityDef = _action(&"reach_4", hit, {"anywhere": false, "reach": 4.0})
	hero = _give(_hero(1), [far])
	var battle: Battle = _battle([hero], [_dummy(10)])
	var first_start: int = -1
	for i: int in 60:
		battle.step()
		if not _of(battle.drain_events(), SimEvent.Kind.ABILITY_STARTED).is_empty():
			first_start = battle.tick
			break
	assert_eq(first_start, 40, "it walked 8 tiles at 2 tiles a second")
	assert_almost_eq(hero.x, 8.0, 0.001, "it stopped at its reach, not at its strike's range")

	# An ally below half health.
	var ally_below: Dictionary = {
		"aim": "WEAKEST_ALLY", "condition": "ALLY_BELOW", "condition_share": 0.5
	}
	healer = _give(_hero(1, {"heal_power": 10}), [_action(&"mend", mend, ally_below)])
	hurt = _hero(2, {}, HeroClassDef.Role.TANK)
	hurt.health = 60
	battle = _battle([healer, hurt], [_dummy(10)])
	assert_eq(_of(_run(battle, 5), SimEvent.Kind.ABILITY_STARTED).size(), 0, "an ally at 60%")
	hurt.health = 40
	assert_eq(_of(_run(battle, 1), SimEvent.Kind.ABILITY_STARTED).size(), 1, "an ally at 40%")

	# The fighter itself below 30%.
	var self_below: Dictionary = {"aim": "SELF", "condition": "SELF_BELOW", "condition_share": 0.3}
	var heal_self: Array = [_fx("HEAL", "SELF", {"multiplier": 0.1, "scale": "FIGHTER_HEALING"})]
	hero = _give(_hero(1, {"heal_power": 10}), [_action(&"second_wind", heal_self, self_below)])
	hurt = _hero(2, {}, HeroClassDef.Role.TANK)
	hurt.health = 10
	battle = _battle([hero, hurt], [_dummy(10)])
	assert_eq(_of(_run(battle, 5), SimEvent.Kind.ABILITY_STARTED).size(), 0, "itself at 100%")
	hero.health = 29
	assert_eq(_of(_run(battle, 1), SimEvent.Kind.ABILITY_STARTED).size(), 1, "itself at 29%")

	# At least two enemies alive.
	var two_enemies: Dictionary = {"condition": "ENEMIES_AT_LEAST", "condition_count": 2}
	var sweep: Array = [_fx("DAMAGE", "ENEMIES")]
	hero = _give(_hero(1), [_action(&"sweep", sweep, two_enemies)])
	events = _run(_battle([hero], [_dummy(10)]), 5)
	assert_eq(_of(events, SimEvent.Kind.ABILITY_STARTED).size(), 0, "one enemy alive")
	hero = _give(_hero(1), [_action(&"sweep", sweep, two_enemies)])
	events = _run(_battle([hero], [_dummy(10), _dummy(11)]), 5)
	assert_eq(_of(events, SimEvent.Kind.ABILITY_STARTED).size(), 1, "two enemies alive")


# --- R3 ------------------------------------------------------------------------


func test_r3_passives() -> void:
	# The fight starts: on tick 1, aimed at the fighter.
	var hero: Combatant = _give(_hero(1), [_marker(&"start", "FIGHT_STARTS")])
	var events: Array[SimEvent] = _run(_battle([hero], [_dummy(10)]), 3)
	var used: Array[SimEvent] = _used(events, &"start")
	assert_eq(_ticks(used), _ints([1]), "the fight starts")
	assert_eq(_targets(used), _ints([1]))

	# Lands a hit: on each ordinary strike, aimed at the one struck, right after the hit.
	hero = _give(_hero(1), [_marker(&"on_hit", "LANDS_HIT")])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 35)
	assert_eq(_ticks(_used(events, &"on_hit")), _ints([6, 19, 32]), "each hit")
	assert_eq(_targets(_used(events, &"on_hit")), _ints([10, 10, 10]))
	var first_hit: int = events.find(_of(events, SimEvent.Kind.HIT)[0])
	assert_eq(events[first_hit + 1].kind, SimEvent.Kind.ABILITY_USED, "after the hit")

	# Lands a critical hit: only when the strike crits.
	hero = _give(_hero(1, {"crit_chance": 1.0}), [_marker(&"crit", "LANDS_CRIT")])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 35)
	assert_eq(_used(events, &"crit").size(), 3, "every strike crits")
	hero = _give(_hero(1), [_marker(&"crit", "LANDS_CRIT")])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 35)
	assert_eq(_used(events, &"crit").size(), 0, "no strike crits")

	# Kills: after the death, aimed at the dead.
	hero = _give(_hero(1), [_marker(&"kill", "KILLS")])
	events = _run(_battle([hero], [_dummy(10, {"max_health": 5})], 2.0))
	used = _used(events, &"kill")
	assert_eq(_targets(used), _ints([10]), "it kills")
	assert_gt(events.find(used[0]), events.find(_of(events, SimEvent.Kind.DIED)[0]))

	# Is hit: aimed at the striker.
	hero = _give(_hero(1, STILL), [_marker(&"hurt", "IS_HIT")])
	events = _run(_battle([hero], [_shooter(10)], 2.0), 25)
	used = _used(events, &"hurt")
	assert_gt(used.size(), 0, "it was hit")
	assert_eq(used.size(), _of(events, SimEvent.Kind.HIT).size(), "on every hit")
	assert_eq(used[0].target_id, 10)

	# Falls below half health: once, on the hit that crosses it.
	var below: Dictionary = {"trigger_share": 0.5}
	hero = _give(_hero(1, STILL), [_marker(&"low", "FALLS_BELOW", below)])
	events = _run(_battle([hero], [_shooter(10, {"damage": 20})], 2.0), 80)
	var health: int = 100
	var crossed: int = -1
	for e: SimEvent in _of(events, SimEvent.Kind.HIT):
		if health >= 50 and health - e.amount < 50:
			crossed = e.tick
		health -= e.amount
	assert_lt(health, 50, "it fell below half")
	assert_eq(_ticks(_used(events, &"low")), _ints([crossed]), "once, as it fell")

	# An ally dies: aimed at the fallen.
	var watcher: Combatant = _hero(1, STILL, HeroClassDef.Role.RANGED)
	_give(watcher, [_marker(&"grief", "ALLY_DIES")])
	var front: Combatant = _hero(2, STILL, HeroClassDef.Role.TANK)
	front.health = 1
	events = _run(_battle([watcher, front], [_shooter(10)], 3.0), 25)
	assert_eq(_targets(_used(events, &"grief")), _ints([2]), "its ally died")

	# Every third strike.
	hero = _give(_hero(1), [_marker(&"third", "EVERY_NTH_STRIKE", {"trigger_every": 3})])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 75)
	assert_eq(_ticks(_used(events, &"third")), _ints([32, 71]), "the 3rd and 6th strikes")

	# The chance, rolled on the battle's own stream: the same seed fires it on the same strikes,
	# another seed on others, and about half of 31 strikes fire it.
	var patterns: Array = []
	for seed_value: int in [SEED, SEED, SEED + 1]:
		hero = _give(_hero(1), [_marker(&"maybe", "LANDS_HIT", {"chance": 0.5})])
		events = _run(_battle([hero], [_dummy(10)], 2.0, seed_value), 400)
		patterns.append(_ticks(_used(events, &"maybe")))
	var first: Array = patterns[0]
	var again: Array = patterns[1]
	var other: Array = patterns[2]
	assert_eq(first, again, "the same seed, the same strikes")
	assert_ne(first, other, "another seed, other strikes")
	assert_between(first.size(), 8, 23, "about half")

	# Once per fight.
	hero = _give(_hero(1), [_marker(&"once", "LANDS_HIT", {"once_per_fight": true})])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 60)
	assert_eq(_ticks(_used(events, &"once")), _ints([6]), "once, though it hit 5 times")


# --- R4 ------------------------------------------------------------------------


func test_r4_effects() -> void:
	# Damage: a multiple of the fighter's 10, less the dummy's armor of 3.
	var low: Dictionary = {"low_health_below": 0.25, "low_multiplier": 3.0}
	var cases: Array = [
		[{"multiplier": 2.0}, 1000, 17],
		[{"multiplier": 2.0, "ignores_armor": true}, 1000, 20],
		[low, 200, 27],
		[low, 1000, 7],
	]
	for case: Array in cases:
		var props: Dictionary = case[0]
		var health: int = case[1]
		var dealt: int = case[2]
		var dummy: Combatant = _dummy(10, {"armor": 3})
		dummy.health = health
		var hit: Array = [_fx("DAMAGE", "TARGET", props)]
		var events: Array[SimEvent] = _use_once(_hero(1), _action(&"hit", hit), [], [dummy])
		assert_eq(_amounts(_of(events, SimEvent.Kind.HIT, 1)), _ints([dealt]), str(props))
		assert_eq(dummy.health, health - dealt)

	# Life steal: half of the 20 dealt.
	var thief: Combatant = _hero(1)
	thief.health = 50
	var steal_props: Dictionary = {"multiplier": 2.0, "ignores_armor": true, "life_steal": 0.5}
	var steal: AbilityDef = _action(&"steal", [_fx("DAMAGE", "TARGET", steal_props)])
	var stolen: Array[SimEvent] = _use_once(thief, steal, [], [_dummy(10, {"armor": 3})])
	assert_eq(_amounts(_of(stolen, SimEvent.Kind.HEALED, 1)), _ints([10]), "life steal")
	assert_eq(thief.health, 60)

	# Heal: 1.5 times a healing power of 10, or a fifth of the receiver's maximum of 200.
	for case: Array in [["FIGHTER_HEALING", 1.5, 15], ["RECEIVER_MAX_HEALTH", 0.2, 40]]:
		var healer: Combatant = _hero(1, {"heal_power": 10}, HeroClassDef.Role.HEALER)
		var patient: Combatant = _hero(2, {"max_health": 200}, HeroClassDef.Role.TANK)
		patient.health = 50
		var heal: Array = [_fx("HEAL", "TARGET", {"scale": case[0], "multiplier": case[1]})]
		var ability: AbilityDef = _action(&"heal", heal, {"aim": "WEAKEST_ALLY"})
		var healed: Array[SimEvent] = _use_once(healer, ability, [patient], [_dummy(10)])
		var amount: int = case[2]
		assert_eq(_amounts(_of(healed, SimEvent.Kind.HEALED, 1)), _ints([amount]), str(case))
		assert_eq(patient.health, 50 + amount)

	# Push: away from the fighter (at 0), inside the room (0 to 16).
	for case: Array in [[3.0, 15.0], [6.0, 16.0]]:
		var pushed: Combatant = _dummy(10)
		var shove: Array = [_fx("PUSH", "TARGET", {"push_tiles": case[0]})]
		_use_once(_hero(1), _action(&"shove", shove), [], [pushed])
		var to: float = case[1]
		assert_almost_eq(pushed.x, to, 0.001, "pushed %s tiles from 12" % case[0])

	# Revive: a fallen ally stands up with half its health.
	var fallen: Combatant = _hero(2, {}, HeroClassDef.Role.TANK)
	fallen.health = 0
	var raise_up: AbilityDef = _action(&"raise", [_fx("REVIVE", "ALLIES", {"revive_share": 0.5})])
	var revived: Array[SimEvent] = _use_once(_hero(1), raise_up, [fallen], [_dummy(10)])
	assert_eq(_amounts(_of(revived, SimEvent.Kind.REVIVED, 1)), _ints([50]), "revive")
	assert_true(fallen.is_alive(), "it stands")
	assert_eq(fallen.health, 50)

	# Status: on the receiver, for its seconds.
	var mark: AbilityDef = _action(&"mark", [_st("MARKED", 2.5, 1.5, "TARGET")])
	var marked: Array[SimEvent] = _use_once(_hero(1), mark, [], [_dummy(10)])
	var began: Array[SimEvent] = _of(marked, SimEvent.Kind.STATUS_BEGAN, 1)
	assert_eq(_amounts(began), _ints([25]), "2.5 seconds in ticks")
	assert_eq(began[0].status, AbilityEffect.Status.MARKED)
	assert_eq(began[0].target_id, 10)

	# Where it lands. Monsters at 9.33 (10), 12 (11) and 14.67 (12); the fighter (1) at 1 and
	# the archer behind it (2) at 0.
	var places: Array = [
		["TARGET", 0.0, [10]],
		["AROUND_TARGET", 3.0, [10, 11]],
		["SELF", 0.0, [1]],
		["ALLIES", 0.0, [1, 2]],
		["ALLIES", 0.5, [1]],
		["ENEMIES", 0.0, [10, 11, 12]],
		["ENEMIES", 12.5, [10, 11]],
	]
	for place: Array in places:
		var lands: String = place[0]
		var radius: Dictionary = {"radius": place[1]}
		var effect: AbilityEffect = _st("MARKED", 2.0, 1.5, lands, radius)
		if lands in ["SELF", "ALLIES"]:
			effect = _st("NIMBLE", 2.0, 0.5, lands, radius)
		var monsters: Array = [_dummy(10), _dummy(11), _dummy(12)]
		var archer: Combatant = _hero(2, {}, HeroClassDef.Role.RANGED)
		var land: AbilityDef = _action(&"land", [effect])
		var events: Array[SimEvent] = _use_once(_hero(1), land, [archer], monsters)
		var expected: Array = place[2]
		var label: String = "%s, radius %s" % [lands, place[1]]
		assert_eq(_targets(_of(events, SimEvent.Kind.STATUS_BEGAN)), _ints(expected), label)


# --- R5 ------------------------------------------------------------------------


func test_r5_statuses() -> void:
	# Stunned: the shooter's wind-up from tick 1 is lost, and it does nothing until tick 32.
	var stun: Array = [_st("STUNNED", 3.0, 0.0, "TARGET")]
	var hero: Combatant = _give(_hero(1, STILL), [_action(&"stun", stun)])
	var events: Array[SimEvent] = _run(_battle([hero], [_shooter(10)]), 40)
	assert_eq(_of(events, SimEvent.Kind.PROJECTILE_LAUNCHED).size(), 1, "one shot, after it")
	assert_eq(_ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 10)), _ints([1, 32]))
	assert_eq(_ticks(_of(events, SimEvent.Kind.STATUS_ENDED)), _ints([32]))

	# Taunting: the shooter aims at the taunter at the back, not at the tank in front.
	var taunt: AbilityDef = _passive(&"taunt", "FIGHT_STARTS", [_st("TAUNTING", 5.0, 0, "SELF")])
	for taunting: bool in [true, false]:
		var back: Combatant = _hero(1, STILL, HeroClassDef.Role.RANGED)
		if taunting:
			_give(back, [taunt])
		var tank: Combatant = _hero(2, STILL, HeroClassDef.Role.TANK)
		events = _run(_battle([back, tank], [_shooter(10)]), 1)
		var aimed: Array[int] = _targets(_of(events, SimEvent.Kind.ATTACK_STARTED, 10))
		assert_eq(aimed, _ints([1 if taunting else 2]), "taunting: %s" % taunting)

	# Shielded: 20 points absorbed, then the spent shield ends and hits land.
	var shield: Array = [_st("SHIELDED", 100.0, 0.2, "SELF", BY_HEALTH)]
	hero = _give(_hero(1, STILL), [_passive(&"shield", "FIGHT_STARTS", shield)])
	events = _run(_battle([hero], [_shooter(10, {"damage": 15})]), 50)
	var absorbed: int = 0
	for e: SimEvent in _of(events, SimEvent.Kind.MISSED, 10):
		assert_true(e.flag, "absorbed, not missed")
		absorbed += e.amount
	assert_eq(absorbed, 20, "the shield took 20")
	var taken: int = 0
	for e: SimEvent in _of(events, SimEvent.Kind.HIT, 10):
		taken += e.amount
	assert_gt(taken, 0, "then hits landed")
	assert_eq(hero.health, 100 - taken, "and only they hurt")
	assert_eq(_of(events, SimEvent.Kind.STATUS_ENDED).size(), 1, "the spent shield ended")
	assert_false(hero.has_status(AbilityEffect.Status.SHIELDED))

	# Burning and bleeding: half the fighter's 10 each second, through armor, for 3 seconds.
	for kind: String in ["BURNING", "BLEEDING"]:
		var dot: Array = [_st(kind, 3.0, 0.5, "TARGET", BY_DAMAGE)]
		hero = _give(_hero(1, STILL), [_action(&"dot", dot)])
		events = _run(_battle([hero], [_dummy(10, {"armor": 3})]), 40)
		var hits: Array[SimEvent] = _of(events, SimEvent.Kind.HIT, 1)
		assert_eq(_ticks(hits), _ints([12, 22, 32]), "%s each second" % kind)
		assert_eq(_amounts(hits), _ints([5, 5, 5]), kind)
		assert_eq(_ticks(_of(events, SimEvent.Kind.STATUS_ENDED)), _ints([32]), kind)

	# Mending: a twentieth of the maximum health each second.
	var mending: Array = [_st("MENDING", 2.0, 0.05, "SELF", BY_HEALTH)]
	hero = _give(_hero(1, STILL), [_passive(&"mending", "FIGHT_STARTS", mending)])
	hero.health = 50
	events = _run(_battle([hero], [_dummy(10)]), 30)
	assert_eq(_amounts(_of(events, SimEvent.Kind.HEALED, 1)), _ints([5, 5]), "mending")
	assert_eq(_ticks(_of(events, SimEvent.Kind.HEALED, 1)), _ints([11, 21]))
	assert_eq(hero.health, 60)

	# Hasted and slowed: from one wind-up to the next is 3 ticks plus the interval of 10 ticks
	# times 0.5 (the hero, hasted) or times 2 (the monster, slowed by the hero).
	var haste: Array = [_st("HASTED", 100.0, 0.5, "SELF")]
	hero = _give(_hero(1), [_passive(&"haste", "FIGHT_STARTS", haste)])
	events = _run(_battle([hero], [_dummy(10)], 2.0), 30)
	assert_eq(_ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 1)), _ints([3, 11, 19, 27]))
	var slow: Array = [_st("SLOWED", 100.0, 2.0, "ENEMIES")]
	hero = _give(_hero(1), [_passive(&"slow", "FIGHT_STARTS", slow)])
	var biter: Combatant = _dummy(10, {"attack_range": 1.0, "windup": 0.3, "damage": 1})
	events = _run(_battle([hero], [biter], 2.0), 60)
	assert_eq(_ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 10)), _ints([3, 26, 49]))

	# Mighty, weakened and marked: an action of once the fighter's 10, through armor.
	var punches: Array = [
		["MIGHTY", 2.0, "SELF", 20], ["WEAKENED", 0.5, "SELF", 5], ["MARKED", 1.5, "TARGET", 15]
	]
	for case: Array in punches:
		var kind: String = case[0]
		var amount: float = case[1]
		var lands: String = case[2]
		var punch: Array = [_st(kind, 5.0, amount, lands)]
		punch.append(_fx("DAMAGE", "TARGET", {"ignores_armor": true}))
		events = _use_once(_hero(1), _action(&"punch", punch), [], [_dummy(10)])
		assert_eq(_amounts(_of(events, SimEvent.Kind.HIT, 1)), _ints([case[3]]), kind)

	# Nimble: a sure dodge turns every ordinary strike into a miss.
	var dodge: Array = [_st("NIMBLE", 100.0, 1.0, "SELF")]
	hero = _give(_hero(1, STILL), [_passive(&"dodge", "FIGHT_STARTS", dodge)])
	events = _run(_battle([hero], [_shooter(10)]), 50)
	assert_eq(_of(events, SimEvent.Kind.HIT).size(), 0, "nothing lands")
	var misses: Array[SimEvent] = _of(events, SimEvent.Kind.MISSED, 10)
	assert_gt(misses.size(), 1, "it was shot at")
	assert_false(misses[0].flag, "a miss, not an absorb")
	assert_eq(hero.health, 100)

	# Applied again: the time restarts, the stronger amount stays, nothing stacks.
	var twice: Array = [
		_st("HASTED", 2.0, 0.5, "SELF"),
		_st("HASTED", 3.0, 0.8, "SELF"),
		_st("MIGHTY", 2.0, 1.2, "SELF"),
		_st("MIGHTY", 1.0, 1.5, "SELF"),
	]
	hero = _give(_hero(1, STILL), [_action(&"twice", twice, {"aim": "SELF"})])
	_run(_battle([hero], [_dummy(10)]), 2)
	var hasted: CombatStatus = hero.status(AbilityEffect.Status.HASTED)
	var mighty: CombatStatus = hero.status(AbilityEffect.Status.MIGHTY)
	assert_eq(hasted.amount, 0.5, "the stronger haste stays")
	assert_eq(hasted.end_tick, 32, "for the later time")
	assert_eq(mighty.amount, 1.5, "a stronger might replaces the weaker")
	assert_eq(mighty.end_tick, 12, "and its time starts again")
	assert_eq(hero.statuses.size(), 2, "no stacking")
	var burn: AbilityEffect = _st("BURNING", 3.0, 0.5, "TARGET", BY_DAMAGE)
	hero = _give(_hero(1, STILL), [_action(&"burn", [burn, burn])])
	events = _run(_battle([hero], [_dummy(10)]), 40)
	assert_eq(_of(events, SimEvent.Kind.HIT, 1).size(), 3, "one burn, not two")

	# None left after the fight.
	var all_out: Array = [
		_st("BURNING", 100.0, 1.0, "TARGET", BY_DAMAGE),
		_st("MIGHTY", 100.0, 2.0, "SELF"),
		_st("NIMBLE", 100.0, 0.5, "SELF"),
	]
	hero = _give(_hero(1), [_action(&"all_out", all_out)])
	var foe: Combatant = _dummy(10, {"max_health": 300})
	var battle: Battle = _battle([hero], [foe], 2.0)
	events = _run(battle)
	assert_eq(battle.result(), Battle.Result.HEROES_WON)
	assert_eq(hero.statuses.size(), 0, "the winner keeps none")
	assert_eq(foe.statuses.size(), 0, "the fallen keeps none")
	assert_eq(_of(events, SimEvent.Kind.STATUS_BEGAN).size(), 3)
	assert_eq(_of(events, SimEvent.Kind.STATUS_ENDED).size(), 3, "each that began ended")


# --- R6 ------------------------------------------------------------------------


func test_r6_events() -> void:
	var bash_effects: Array = [_fx("DAMAGE", "TARGET", {"ignores_armor": true})]
	bash_effects.append(_st("BURNING", 1.0, 0.3, "TARGET", BY_DAMAGE))
	var bash: AbilityDef = _action(&"bash", bash_effects, {"windup": 0.4})
	var echo_effects: Array = [_st("MIGHTY", 1.0, 1.1, "SELF")]
	var echo: AbilityDef = _passive(&"echo", "LANDS_HIT", echo_effects, {"once_per_fight": true})
	var hero: Combatant = _give(_hero(1, STILL), [bash, echo])
	var events: Array[SimEvent] = _run(_battle([hero], [_dummy(10)]), 20)
	var lines: Array[String] = []
	for e: SimEvent in events:
		if e.source_id != 10:
			lines.append(_full_line(e))
	var mighty: int = AbilityEffect.Status.MIGHTY
	var burning: int = AbilityEffect.Status.BURNING
	var expected: Array[String] = [
		"ABILITY_STARTED 1 1 10 4 false bash -1",
		"ABILITY_USED 5 1 10 0 false bash -1",
		"HIT 5 1 10 10 false  -1",
		"ABILITY_USED 5 1 10 0 false echo -1",
		"STATUS_BEGAN 5 1 1 10 false echo %d" % mighty,
		"STATUS_BEGAN 5 1 10 10 false bash %d" % burning,
		"STATUS_ENDED 15 1 1 0 false echo %d" % mighty,
		"HIT 15 1 10 3 false  -1",
		"STATUS_ENDED 15 1 10 0 false bash %d" % burning,
	]
	assert_eq(lines, expected, "an action, the passive its hit set off, a burn credited to 1")
	assert_eq(events.size(), lines.size() + 1, "besides the dummy's endless wind-up")


# --- R7 ------------------------------------------------------------------------


func _plain_battle(seed_value: int) -> Battle:
	var healer: Dictionary = {"heal_power": 9, "attack_range": 5.0, "damage": 4}
	var archer: Dictionary = {"attack_range": 6.0, "crit_chance": 0.2, "attack_interval": 1.4}
	var heroes: Array[Combatant] = [_hero(1, healer, HeroClassDef.Role.HEALER)]
	heroes.append(_hero(2, {"max_health": 160, "armor": 2}, HeroClassDef.Role.TANK))
	heroes.append(_hero(3, {"crit_chance": 0.3, "damage": 13}))
	heroes.append(_hero(4, archer, HeroClassDef.Role.RANGED))
	var brute: Dictionary = {"max_health": 70, "damage": 9, "crit_chance": 0.2}
	var shell: Dictionary = {"max_health": 60, "damage": 7, "armor": 1}
	var spitter: Dictionary = {"max_health": 50, "damage": 6, "attack_range": 5.0}
	spitter["attack_interval"] = 1.6
	var monsters: Array[Combatant] = [Combatant.from_monster(_monster_def(brute), 2, 101)]
	monsters.append(Combatant.from_monster(_monster_def(shell), 1, 102))
	monsters.append(Combatant.from_monster(_monster_def(spitter), 1, 103))
	return Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(seed_value))


func test_r7_nothing_changes() -> void:
	var recorded: Array[String] = []
	for line: String in RECORDED.replace("\n", " | ").split(" | ", false):
		recorded.append(line.strip_edges())
	var lines: Array[String] = []
	for e: SimEvent in _run(_plain_battle(SEED)):
		lines.append(_line(e))
	assert_eq(lines.size(), recorded.size(), "as many events as before")
	for i: int in mini(lines.size(), recorded.size()):
		if lines[i] != recorded[i]:
			assert_eq(lines[i], recorded[i], "the first event that differs, %d" % i)
			return
	assert_eq(lines, recorded, "event for event")


# --- R8 ------------------------------------------------------------------------


func test_r8_deterministic() -> void:
	var runs: Array = []
	for i: int in 2:
		var battle: Battle = _plain_battle(SEED + 7)
		_give_twelve(battle.combatant(1), ["prayer", "guardian_angel", "battle_hymn"])
		_give_twelve(battle.combatant(2), ["shield_bash", "taunt", "last_stand"])
		_give_twelve(battle.combatant(3), ["backstab", "finisher", "chain_spark", "whirlwind"])
		_give_twelve(battle.combatant(4), ["fireball", "frost_nova"])
		_give(battle.combatant(101), [_marker(&"maybe", "IS_HIT", {"chance": 0.5})])
		var lines: Array[String] = []
		for e: SimEvent in _run(battle):
			lines.append(_full_line(e))
		runs.append(lines)
	var first: Array = runs[0]
	var again: Array = runs[1]
	assert_eq(first, again, "the same seed, fighters and abilities: the same battle")
	var used: int = 0
	for line: String in first:
		if line.begins_with("ABILITY_USED"):
			used += 1
	assert_gt(used, 3, "abilities were used")


# --- R9 ------------------------------------------------------------------------


func test_r9_the_twelve() -> void:
	var twelve: Dictionary = _twelve()
	assert_eq(twelve.size(), 12)
	for id: String in twelve:
		var found: PackedStringArray = (twelve[id] as AbilityDef).validate()
		assert_eq(found, PackedStringArray(), "%s is valid" % id)

	# Shield Bash: 1.5 times 10 and a 2-second stun, in which the biter does nothing; its next
	# strike starts as the stun ends, 20 ticks later.
	var hero: Combatant = _give_twelve(_hero(1), ["shield_bash"])
	var biter: Combatant = _shooter(10, {"attack_range": 1.0, "damage": 1})
	var events: Array[SimEvent] = _run(_battle([hero], [biter], 2.0), 60)
	var landing: Array[SimEvent] = _landing(events, &"shield_bash")
	assert_eq(_amounts(_of(landing, SimEvent.Kind.HIT, 1)), _ints([15]), "Shield Bash")
	var began: Array[SimEvent] = _of(landing, SimEvent.Kind.STATUS_BEGAN, 1)
	assert_eq(began[0].status, AbilityEffect.Status.STUNNED, "and a stun")
	var stun_at: int = landing[0].tick
	for e: SimEvent in _of(events, SimEvent.Kind.ATTACK_STARTED, 10):
		assert_false(e.tick > stun_at and e.tick < stun_at + 20, "stunned at %d" % e.tick)
	var after: Array[int] = _ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 10)).filter(
		func(t: int) -> bool: return t > stun_at
	)
	assert_eq(after[0], stun_at + 20, "the next strike waits out the stun")

	# Taunt: the shooter turns from the tank to the archer at the back.
	var archer: Combatant = _give_twelve(_hero(1, STILL, HeroClassDef.Role.RANGED), ["taunt"])
	var tank: Combatant = _hero(2, STILL, HeroClassDef.Role.TANK)
	events = _run(_battle([archer, tank], [_shooter(10, {"damage": 1})]), 20)
	var aims: Array[int] = _targets(_of(events, SimEvent.Kind.ATTACK_STARTED, 10))
	assert_eq(aims[0], 2, "the tank, before the taunt")
	assert_eq(aims[aims.size() - 1], 1, "Taunt: the taunter after it")
	# A biter that has to walk up and strike the tank cannot reach the archer: it does not turn.
	archer = _give_twelve(_hero(1, STILL, HeroClassDef.Role.RANGED), ["taunt"])
	tank = _hero(2, STILL, HeroClassDef.Role.TANK)
	biter = _shooter(10, {"attack_range": 1.0, "move_speed": 4.0, "damage": 1})
	events = _run(_battle([archer, tank], [biter]), 40)
	assert_true(archer.has_status(AbilityEffect.Status.TAUNTING), "it is taunting")
	aims = _targets(_of(events, SimEvent.Kind.ATTACK_STARTED, 10))
	assert_gt(aims.size(), 0, "the biter struck while it taunted")
	assert_eq(aims, _ints(aims.map(func(_t: int) -> int: return 2)), "only the tank it reaches")

	# Whirlwind: in a 4-tile room monsters stand at 2.33, 3 and 3.67; from 1.33 it reaches two.
	hero = _give_twelve(_hero(1), ["whirlwind"])
	events = _run(_battle([hero], [_dummy(10), _dummy(11), _dummy(12)], 4.0), 20)
	landing = _landing(events, &"whirlwind")
	assert_eq(_targets(_of(landing, SimEvent.Kind.HIT, 1)), _ints([10, 11]), "Whirlwind")

	# Last Stand: below 30%, once: a shield of 30 and mending of 4 a second.
	hero = _give_twelve(_hero(1, STILL), ["last_stand"])
	events = _run(_battle([hero], [_shooter(10, {"damage": 20})]), 150)
	assert_eq(_used(events, &"last_stand").size(), 1, "Last Stand, once")
	landing = _landing(events, &"last_stand")
	assert_eq(_of(landing, SimEvent.Kind.STATUS_BEGAN).size(), 2, "a shield and mending")
	assert_gt(_of(events, SimEvent.Kind.MISSED).size(), 0, "the shield absorbs")
	var mended: Array[SimEvent] = _of(events, SimEvent.Kind.HEALED, 1)
	assert_gt(mended.size(), 0, "mending heals")
	assert_eq(_amounts(mended)[0], 4)

	# Backstab: past the nearest to the furthest, 3 times 10, then bleeding of 3 a second.
	hero = _give_twelve(_hero(1), ["backstab"])
	events = _run(_battle([hero], [_dummy(10), _dummy(11)]), 120)
	var stabs: Array[SimEvent] = _of(_landing(events, &"backstab"), SimEvent.Kind.HIT, 1)
	assert_eq(_targets(stabs), _ints([11]), "Backstab, the furthest")
	assert_eq(_amounts(stabs), _ints([30]))
	var bleeds: Array[SimEvent] = []
	for e: SimEvent in _of(events, SimEvent.Kind.HIT, 1):
		if not stabs.is_empty() and e.tick == stabs[0].tick + TPS:
			bleeds.append(e)
	assert_eq(_amounts(bleeds), _ints([3]), "it bleeds")

	# Finisher: twice the damage on the weakest, and only once it is under a quarter of its health.
	for case: Array in [[200, [20]], [500, []]]:
		hero = _give_twelve(_hero(1), ["finisher"])
		var low: Combatant = _dummy(10)
		low.health = case[0]
		events = _run(_battle([hero], [low], 2.0), 10)
		var finished: Array[SimEvent] = _of(_landing(events, &"finisher"), SimEvent.Kind.HIT, 1)
		var expected: Array = case[1]
		assert_eq(_amounts(finished), _ints(expected), "Finisher at %d of 1000" % case[0])

	# Fireball: 12 to the two within a tile of the nearest, and they burn; not the third.
	hero = _give_twelve(_hero(1), ["fireball"])
	events = _run(_battle([hero], [_dummy(10), _dummy(11), _dummy(12)], 4.0), 20)
	landing = _landing(events, &"fireball")
	assert_eq(_targets(_of(landing, SimEvent.Kind.HIT, 1)), _ints([10, 11]), "Fireball")
	assert_eq(_amounts(_of(landing, SimEvent.Kind.HIT, 1)), _ints([12, 12]))
	assert_eq(_targets(_of(landing, SimEvent.Kind.STATUS_BEGAN, 1)), _ints([10, 11]), "burns")

	# Frost Nova: the near ones slowed and pushed back 2 tiles (to the wall); not the far one.
	hero = _give_twelve(_hero(1), ["frost_nova"])
	var monsters: Array[Combatant] = _typed([_dummy(10), _dummy(11), _dummy(12)])
	events = _run(_battle([hero], monsters, 4.0), 20)
	landing = _landing(events, &"frost_nova")
	assert_eq(_targets(_of(landing, SimEvent.Kind.STATUS_BEGAN, 1)), _ints([10, 11]), "Frost Nova")
	assert_almost_eq(monsters[0].x, 4.0, 0.001, "and pushes")
	assert_almost_eq(monsters[1].x, 4.0, 0.001)
	assert_almost_eq(monsters[2].x, 11.0 / 3.0, 0.001, "the far one stays")

	# Chain spark: each crit strikes every enemy for 3.
	hero = _give_twelve(_hero(1, {"crit_chance": 1.0}), ["chain_spark"])
	events = _run(_battle([hero], [_dummy(10), _dummy(11)], 2.0), 10)
	var sparks: Array[SimEvent] = _of(_landing(events, &"chain_spark"), SimEvent.Kind.HIT, 1)
	assert_eq(_targets(sparks), _ints([10, 11]), "Chain spark")
	assert_eq(_amounts(sparks), _ints([3, 3]))

	# Prayer: once an ally is under 60%, every ally is healed by the healing power.
	var priest: Combatant = _hero(1, {"heal_power": 10}, HeroClassDef.Role.HEALER)
	var hurt: Combatant = _hero(2, {}, HeroClassDef.Role.TANK)
	var scratched: Combatant = _hero(3, {}, HeroClassDef.Role.RANGED)
	hurt.health = 50
	scratched.health = 95
	events = _run(_battle([_give_twelve(priest, ["prayer"]), hurt, scratched], [_dummy(10)]), 10)
	landing = _landing(events, &"prayer")
	assert_eq(_targets(_of(landing, SimEvent.Kind.HEALED, 1)), _ints([1, 2, 3]), "Prayer")
	assert_eq(hurt.health, 60)
	assert_eq(scratched.health, 100)

	# Guardian Angel: the first ally to die stands up again; the next time it stays down.
	var angel: Combatant = _hero(1, STILL, HeroClassDef.Role.HEALER)
	var front: Combatant = _hero(2, STILL, HeroClassDef.Role.TANK)
	front.health = 1
	var killer: Combatant = _shooter(10, {"damage": 40})
	events = _run(_battle([_give_twelve(angel, ["guardian_angel"]), front], [killer]), 100)
	assert_eq(_targets(_of(events, SimEvent.Kind.REVIVED, 1)), _ints([2]), "Guardian Angel")
	assert_eq(_of(events, SimEvent.Kind.DIED, 2).size(), 2, "once, not twice")

	# Battle Hymn: every ally hasted as the fight starts.
	var bard: Combatant = _give_twelve(_hero(1, {}, HeroClassDef.Role.RANGED), ["battle_hymn"])
	events = _run(_battle([bard, _hero(2, {}, HeroClassDef.Role.TANK)], [_dummy(10)]), 1)
	var hymn: Array[SimEvent] = _of(events, SimEvent.Kind.STATUS_BEGAN, 1)
	assert_eq(_targets(hymn), _ints([1, 2]), "Battle Hymn")
	assert_eq(hymn[0].status, AbilityEffect.Status.HASTED)
	assert_eq(hymn[0].tick, 1)


# --- The amendment after the review of pull request 50 --------------------------


## An action may wait for an enemy within some tiles, without walking to make it true; a
## healer with a hurt ally heals before it uses a damaging action.
func test_r2_amended_conditions() -> void:
	var nova: AbilityDef = _twelve()["frost_nova"]
	var far_sight: Dictionary = {"attack_range": 20.0}
	var archer: Combatant = _give(_hero(1, far_sight, HeroClassDef.Role.RANGED), [nova])
	var events: Array[SimEvent] = _run(_battle([archer], [_dummy(10)]), 60)
	assert_eq(_used(events, &"frost_nova").size(), 0, "nobody near, no Frost Nova")
	assert_eq(archer.x, 0.0, "and the mage did not walk to make one near")
	archer = _give(_hero(1, far_sight, HeroClassDef.Role.RANGED), [nova])
	var biter: Combatant = _dummy(10, {"attack_range": 1.0, "move_speed": 2.0})
	var battle: Battle = _battle([archer], [biter])
	var started: Array[SimEvent] = []
	while started.is_empty() and battle.tick < 100:
		battle.step()
		started = _of(battle.drain_events(), SimEvent.Kind.ABILITY_STARTED)
	assert_eq(started.size(), 1, "Frost Nova once a biter walks up")
	assert_lte(absf(biter.x - archer.x), 1.5 + Battle.EPSILON, "it was next to the mage")

	var smite: AbilityDef = _action(&"smite", [_fx("DAMAGE", "TARGET")])
	for health: int in [50, 100]:
		var priest: Dictionary = {"heal_power": 10, "attack_range": 5.0}
		var healer: Combatant = _give(_hero(1, priest, HeroClassDef.Role.HEALER), [smite])
		var tank: Combatant = _hero(2, STILL, HeroClassDef.Role.TANK)
		tank.health = health
		events = _run(_battle([healer, tank], [_dummy(10)]), 1)
		var smites: int = _of(events, SimEvent.Kind.ABILITY_STARTED).size()
		if health == 50:
			var aims: Array[int] = _targets(_of(events, SimEvent.Kind.ATTACK_STARTED, 1))
			assert_eq(aims, _ints([2]), "it heals the hurt tank first")
			assert_eq(smites, 0, "and does not smite")
		else:
			assert_eq(smites, 1, "nobody hurt: it smites")


## A passive may land on the nearest enemy (Ambush), and a passive on a strike may multiply the
## strike itself (Reckless Swing): life steal on the whole strike, and never on a miss.
func test_r3_amended_passives() -> void:
	var stun: Array = [_st("STUNNED", 2.0, 0.0, "NEAREST_ENEMY")]
	var ambush: AbilityDef = _passive(&"ambush", "FIGHT_STARTS", stun)
	assert_eq(ambush.validate(), PackedStringArray(), "Ambush is valid")
	var hero: Combatant = _give(_hero(1, STILL), [ambush])
	var events: Array[SimEvent] = _run(_battle([hero], [_shooter(10), _shooter(11)]), 25)
	var began: Array[SimEvent] = _of(events, SimEvent.Kind.STATUS_BEGAN, 1)
	assert_eq(_targets(began), _ints([10]), "Ambush stuns the nearest")
	assert_eq(_ticks(began), _ints([1]), "as the fight starts")
	assert_eq(_ticks(_of(events, SimEvent.Kind.ATTACK_STARTED, 10)), _ints([21]), "it waits")

	var swing: Dictionary = {"on_strike": true, "multiplier": 2.0, "life_steal": 0.5}
	var every: Dictionary = {"trigger_every": 2}
	var reckless: AbilityDef = _passive(
		&"reckless", "EVERY_NTH_STRIKE", [_fx("DAMAGE", "TARGET", swing)], every
	)
	assert_eq(reckless.validate(), PackedStringArray(), "Reckless Swing is valid")
	events = _run(_battle([_hero(1)], [_dummy(10)], 2.0), 60)
	var plain: Array[SimEvent] = _of(events, SimEvent.Kind.HIT, 1)
	hero = _give(_hero(1), [reckless])
	hero.health = 50
	events = _run(_battle([hero], [_dummy(10)], 2.0), 60)
	var hits: Array[SimEvent] = _of(events, SimEvent.Kind.HIT, 1)
	assert_eq(_ticks(hits), _ticks(plain), "it adds no hit of its own")
	assert_eq(hits.size(), 5, "five strikes")
	if hits.size() != 5 or plain.size() != 5:
		return
	assert_eq(_ticks(_used(events, &"reckless")), _ints([hits[1].tick, hits[3].tick]))
	for i: int in hits.size():
		var doubled: int = plain[i].amount * (2 if i % 2 == 1 else 1)
		assert_almost_eq(hits[i].amount, doubled, 1, "strike %d" % i)
	var stolen: Array[int] = _ints([roundi(hits[1].amount * 0.5), roundi(hits[3].amount * 0.5)])
	assert_eq(_amounts(_of(events, SimEvent.Kind.HEALED, 1)), stolen, "half the whole strike")
	var dodge: Array = [_st("NIMBLE", 100.0, 1.0, "SELF")]
	var nimble: AbilityDef = _passive(&"nimble", "FIGHT_STARTS", dodge)
	hero = _give(_hero(1), [reckless])
	events = _run(_battle([hero], [_give(_dummy(10), [nimble])], 2.0), 60)
	assert_gt(_of(events, SimEvent.Kind.MISSED, 1).size(), 3, "every strike missed")
	assert_eq(_used(events, &"reckless").size(), 0, "so it never fired")
	assert_eq(_of(events, SimEvent.Kind.HEALED).size(), 0)


## Untouchable (Vanish): nothing an enemy does lands on it, and enemies aim at someone else
## while anyone else stands. Chilled (Blizzard): damage each second, a status of its own.
func test_r5_amended_statuses() -> void:
	var vanish: AbilityDef = _action(&"vanish", [_st("UNTOUCHABLE", 100.0, 0.0, "SELF")])
	vanish.aim = AbilityDef.Aim.SELF
	assert_eq(vanish.validate(), PackedStringArray(), "Vanish is valid")
	var curse: Array = [_st("BLEEDING", 5.0, 1.0, "ENEMIES", BY_DAMAGE)]
	curse.append(_fx("DAMAGE", "NEAREST_ENEMY"))
	var foe_kit: Array = [
		_passive(&"curse", "FIGHT_STARTS", curse),
		_action(&"jab", [_fx("DAMAGE", "ENEMIES"), _st("WEAKENED", 5.0, 0.5, "ENEMIES")]),
		_passive(&"spite", "IS_HIT", [_fx("DAMAGE", "ENEMIES")]),
	]
	var rogue: Combatant = _give(_hero(1, STILL), [vanish])
	var archer: Combatant = _hero(2, {"attack_range": 20.0}, HeroClassDef.Role.RANGED)
	var foe: Combatant = _give(_shooter(10, {"max_health": 1000, "damage": 1}), foe_kit)
	var events: Array[SimEvent] = _run(_battle([rogue, archer], [foe]), 60)
	var on_rogue: Array[SimEvent] = []
	for e: SimEvent in events:
		var hostile: bool = e.kind in [SimEvent.Kind.HIT, SimEvent.Kind.STATUS_BEGAN]
		if hostile and e.target_id == 1 and e.source_id == 10 and e.tick > 2:
			on_rogue.append(e)
	assert_eq(on_rogue.size(), 0, "nothing of the foe's lands once it has vanished")
	assert_gt(_of(events, SimEvent.Kind.HIT, 10).size(), 4, "while the archer is struck")
	var aims: Array[int] = _targets(_of(events, SimEvent.Kind.ATTACK_STARTED, 10))
	assert_eq(aims, _ints(aims.map(func(_t: int) -> int: return 2)), "the foe aims at the archer")
	rogue = _give(_hero(1, STILL), [vanish])
	events = _run(_battle([rogue], [_shooter(10)]), 40)
	assert_gt(_of(events, SimEvent.Kind.MISSED, 10).size(), 1, "alone, it is shot at")
	assert_eq(rogue.health, 100, "and nothing lands")

	var blizzard: Array = [_st("CHILLED", 3.0, 0.5, "ENEMIES", BY_DAMAGE)]
	blizzard.append(_st("BURNING", 3.0, 0.5, "ENEMIES", BY_DAMAGE))
	var hero: Combatant = _give(_hero(1, STILL), [_action(&"blizzard", blizzard)])
	events = _run(_battle([hero], [_dummy(10)]), 40)
	var kinds: Array[int] = _ints(
		_of(events, SimEvent.Kind.STATUS_BEGAN).map(func(e: SimEvent) -> int: return e.status)
	)
	assert_eq(kinds, _ints([AbilityEffect.Status.CHILLED, AbilityEffect.Status.BURNING]))
	var hits: Array[SimEvent] = _of(events, SimEvent.Kind.HIT, 1)
	assert_eq(_ticks(hits), _ints([12, 12, 22, 22, 32, 32]), "chilled and burning each second")
	assert_eq(_amounts(hits), _ints([5, 5, 5, 5, 5, 5]))

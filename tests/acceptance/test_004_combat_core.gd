extends ColonyTest
## Acceptance tests for specs/004-combat-core/spec.md, one per requirement.
##
## Where exact numbers matter the tests build their own definitions, so
## retuning the shipped data cannot break them. Only R1 and R12 (and the
## determinism check of R11) read the files under res://data.

const SEED: int = 1234
const BALANCE_SEEDS: int = 200
## A chamber floor in the middle of the 12 to 24 tile range the labyrinth uses.
const SPAN_LEFT: float = 0.0
const SPAN_RIGHT: float = 16.0
## A duration long enough that it never comes round in a test.
const NEVER: float = 100_000.0

# --- Helpers -----------------------------------------------------------------


func _hero_def(role: HeroClassDef.Role, overrides: Dictionary = {}) -> HeroClassDef:
	var def := HeroClassDef.new()
	def.id = &"test_hero"
	def.display_name = "Test hero"
	def.role = role
	def.max_health = 100
	def.damage = 10
	def.armor = 0
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 2.0
	def.crit_chance = 0.0
	def.heal_power = 0
	def.health_per_level = 10
	def.damage_per_level = 1
	for key: String in overrides:
		def.set(key, overrides[key])
	return def


func _monster_def(overrides: Dictionary = {}) -> MonsterDef:
	var def := MonsterDef.new()
	def.id = &"test_monster"
	def.display_name = "Test monster"
	def.size = MonsterDef.Size.SMALL
	def.base_level = 1
	def.max_health = 100
	def.damage = 5
	def.armor = 0
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 1.0
	def.crit_chance = 0.0
	def.xp = 1
	def.gold_min = 1
	def.gold_max = 2
	for key: String in overrides:
		def.set(key, overrides[key])
	return def


## A monster that stands still and never finishes an attack.
func _dummy(health: int = 10_000, overrides: Dictionary = {}) -> MonsterDef:
	var values: Dictionary = {
		"max_health": health, "windup": NEVER, "attack_range": 1000.0, "move_speed": 0.0
	}
	values.merge(overrides, true)
	return _monster_def(values)


func _heroes(list: Array) -> Array[Combatant]:
	var typed: Array[Combatant] = []
	for c: Combatant in list:
		typed.append(c)
	return typed


func _battle(heroes: Array, monsters: Array, seed_value: int = SEED) -> Battle:
	return Battle.new(
		_heroes(heroes), _heroes(monsters), SPAN_LEFT, SPAN_RIGHT, true, SimRng.new(seed_value)
	)


## Steps until the battle is over (or max_ticks), collecting every event.
func _run(battle: Battle, max_ticks: int = Battle.MAX_TICKS + 10) -> Array[SimEvent]:
	var events: Array[SimEvent] = battle.drain_events()
	var ticks: int = 0
	while battle.result() == Battle.Result.ONGOING and ticks < max_ticks:
		battle.step()
		events.append_array(battle.drain_events())
		ticks += 1
	return events


func _of_kind(events: Array[SimEvent], kind: SimEvent.Kind, source: int = -2) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.kind == kind and (source == -2 or e.source_id == source):
			found.append(e)
	return found


func _ticks_of(events: Array[SimEvent]) -> Array[int]:
	var ticks: Array[int] = []
	for e: SimEvent in events:
		ticks.append(e.tick)
	return ticks


func _describe(e: SimEvent) -> Array:
	return [SimEvent.Kind.keys()[e.kind], e.tick, e.source_id, e.target_id, e.amount, e.flag]


func _shipped_party(fourth: StringName = &"cleric") -> Array[Combatant]:
	var party: Array[Combatant] = []
	var ids: Array[StringName] = [&"knight", &"rogue", &"mage", fourth]
	for i: int in ids.size():
		party.append(Combatant.from_hero(Content.hero_class(ids[i]), 1, i + 1))
	return party


func _shipped_monsters(groups: Array) -> Array[Combatant]:
	var monsters: Array[Combatant] = []
	var next_id: int = 101
	for group: Array in groups:
		var id: StringName = group[0]
		var count: int = group[1]
		var depth: int = group[2]
		var def: MonsterDef = Content.monster(id)
		for i: int in count:
			monsters.append(Combatant.from_monster(def, depth, next_id))
			next_id += 1
	return monsters


# --- R1 ------------------------------------------------------------------------


func test_r1_shipped_content_is_valid() -> void:
	var hero_roles: Dictionary = {
		&"knight": HeroClassDef.Role.TANK,
		&"rogue": HeroClassDef.Role.MELEE,
		&"mage": HeroClassDef.Role.RANGED,
		&"cleric": HeroClassDef.Role.HEALER,
	}
	var hero_ids: Array[StringName] = Content.hero_class_ids()
	assert_eq(hero_ids.size(), 4, "four hero classes: %s" % [hero_ids])
	for id: StringName in hero_roles:
		assert_has(hero_ids, id)
		var def: HeroClassDef = Content.hero_class(id)
		assert_not_null(def, "hero class %s loads" % id)
		if def == null:
			continue
		assert_eq(def.id, id)
		var role: HeroClassDef.Role = hero_roles[id]
		assert_eq(def.role, role, "%s role" % id)
		assert_eq(def.validate(), PackedStringArray(), "%s validates clean" % id)

	var monster_depths: Dictionary = {
		&"slime": 1, &"cave_bat": 1, &"skeleton": 2, &"spider": 3, &"ogre": 5
	}
	var monster_ids: Array[StringName] = Content.monster_ids()
	# Spec 013 adds deeper monsters; the original five are still checked by name below.
	assert_gte(monster_ids.size(), 5, "at least the five monsters: %s" % [monster_ids])
	for id: StringName in monster_depths:
		assert_has(monster_ids, id)
		var def: MonsterDef = Content.monster(id)
		assert_not_null(def, "monster %s loads" % id)
		if def == null:
			continue
		assert_eq(def.id, id)
		var depth: int = monster_depths[id]
		assert_eq(def.base_level, depth, "%s depth" % id)
		var size: MonsterDef.Size = (
			MonsterDef.Size.LARGE if id == &"ogre" else MonsterDef.Size.SMALL
		)
		assert_eq(def.size, size, "%s size" % id)
		assert_eq(def.validate(), PackedStringArray(), "%s validates clean" % id)
	var spider: MonsterDef = Content.monster(&"spider")
	if spider != null:
		assert_gt(spider.attack_range, Battle.MELEE_REACH, "the spider is ranged")
	assert_null(Content.hero_class(&"no_such_class"), "an unknown id gives null")
	assert_null(Content.monster(&"no_such_monster"), "an unknown id gives null")


func test_r1_validate_reports_each_problem() -> void:
	assert_eq(_hero_def(HeroClassDef.Role.TANK).validate().size(), 0, "the base hero is valid")
	assert_eq(_monster_def().validate().size(), 0, "the base monster is valid")
	var common: Array[Dictionary] = [
		{"id": &""},
		{"display_name": ""},
		{"max_health": 0},
		{"damage": 0},
		{"attack_interval": 0.0},
		{"attack_interval": -1.0},
		{"attack_range": 0.0},
		{"move_speed": 0.0},
		{"crit_chance": -0.1},
		{"crit_chance": 1.1},
	]
	for bad: Dictionary in common:
		var hero: PackedStringArray = _hero_def(HeroClassDef.Role.TANK, bad).validate()
		assert_eq(hero.size(), 1, "hero %s gives one problem: %s" % [bad, hero])
		var monster: PackedStringArray = _monster_def(bad).validate()
		assert_eq(monster.size(), 1, "monster %s gives one problem: %s" % [bad, monster])
	var monster_only: Array[Dictionary] = [
		{"gold_min": 5, "gold_max": 4},
		{"base_level": 0},
	]
	for bad: Dictionary in monster_only:
		var monster: PackedStringArray = _monster_def(bad).validate()
		assert_eq(monster.size(), 1, "monster %s gives one problem: %s" % [bad, monster])
	var healer_without_heal: PackedStringArray = (
		_hero_def(HeroClassDef.Role.HEALER, {"heal_power": 0}).validate()
	)
	assert_eq(
		healer_without_heal.size(), 1, "a healer with heal power below 1: %s" % healer_without_heal
	)
	assert_eq(
		_hero_def(HeroClassDef.Role.HEALER, {"heal_power": 1}).validate().size(),
		0,
		"heal power 1 is fine"
	)
	assert_eq(
		_hero_def(HeroClassDef.Role.TANK, {"heal_power": 0}).validate().size(),
		0,
		"only a healer needs heal power"
	)
	var many: PackedStringArray = _monster_def({"id": &"", "damage": 0, "base_level": 0}).validate()
	assert_eq(many.size(), 3, "each problem is its own line")


# --- R2 ------------------------------------------------------------------------


func test_r2_combatants_scale_with_level_and_depth() -> void:
	var hero_def := _hero_def(
		HeroClassDef.Role.MELEE,
		{
			"id": &"brawler",
			"max_health": 100,
			"health_per_level": 10,
			"damage": 10,
			"damage_per_level": 3
		}
	)
	var hero := Combatant.from_hero(hero_def, 3, 7)
	assert_eq(hero.id, 7)
	assert_eq(hero.team, Combatant.Team.HEROES)
	assert_eq(hero.def_id, &"brawler")
	assert_eq(hero.level, 3)
	assert_eq(hero.max_health, 120, "100 + 2 levels x 10")
	assert_eq(hero.health, 120, "starts at full health")
	assert_eq(hero.damage, 16, "10 + 2 levels x 3")
	assert_eq(hero.role, HeroClassDef.Role.MELEE)
	assert_true(hero.is_alive())
	assert_almost_eq(hero.health_fraction(), 1.0, 0.0001)

	var monster_def := _monster_def(
		{"id": &"brute", "base_level": 2, "max_health": 100, "damage": 10}
	)
	var monster := Combatant.from_monster(monster_def, 4, 9)
	assert_eq(monster.id, 9)
	assert_eq(monster.team, Combatant.Team.MONSTERS)
	assert_eq(monster.def_id, &"brute")
	assert_eq(monster.level, 4, "a monster's level is its depth")
	assert_eq(monster.max_health, roundi(100 * 1.12 * 1.12), "12% twice, compounding")
	assert_eq(monster.max_health, 125)
	assert_eq(monster.damage, 13, "10 x 1.2544, rounded")
	assert_eq(monster.role, HeroClassDef.Role.MELEE, "a short-ranged monster is melee")
	var at_home := Combatant.from_monster(monster_def, 2, 10)
	assert_eq(at_home.max_health, 100, "no growth at its own depth")
	var spitter := Combatant.from_monster(_monster_def({"attack_range": 5.0}), 1, 11)
	assert_eq(spitter.role, HeroClassDef.Role.RANGED, "a long-ranged monster is ranged")

	var twin_a := Combatant.from_hero(hero_def, 1, 1)
	var twin_b := Combatant.from_monster(monster_def, 2, 1)
	var battle := _battle([twin_a], [twin_b])
	assert_push_error("duplicate")
	assert_eq(battle.result(), Battle.Result.MONSTERS_WON, "a duplicated id is a monster win")
	battle.step()
	assert_eq(battle.tick, 0, "a finished battle does not step")


# --- R3 ------------------------------------------------------------------------


func test_r3_line_up() -> void:
	for from_left: bool in [true, false]:
		var healer := Combatant.from_hero(_hero_def(HeroClassDef.Role.HEALER), 1, 1)
		var ranged := Combatant.from_hero(_hero_def(HeroClassDef.Role.RANGED), 1, 2)
		var tank := Combatant.from_hero(_hero_def(HeroClassDef.Role.TANK), 1, 3)
		var melee := Combatant.from_hero(_hero_def(HeroClassDef.Role.MELEE), 1, 4)
		var monsters: Array[Combatant] = []
		for i: int in 3:
			monsters.append(Combatant.from_monster(_monster_def(), 1, 10 + i))
		var battle := Battle.new(
			_heroes([healer, ranged, tank, melee]), monsters, 2.0, 18.0, from_left, SimRng.new(SEED)
		)
		var side: String = "from the left" if from_left else "from the right"
		if from_left:
			assert_almost_eq(healer.x, 2.0, 0.0001, "healer at the entry edge, %s" % side)
			assert_almost_eq(ranged.x, 3.0, 0.0001, side)
			assert_almost_eq(melee.x, 4.0, 0.0001, side)
			assert_almost_eq(tank.x, 5.0, 0.0001, "tank nearest the monsters, %s" % side)
		else:
			assert_almost_eq(healer.x, 18.0, 0.0001, "healer at the entry edge, %s" % side)
			assert_almost_eq(ranged.x, 17.0, 0.0001, side)
			assert_almost_eq(melee.x, 16.0, 0.0001, side)
			assert_almost_eq(tank.x, 15.0, 0.0001, "tank nearest the monsters, %s" % side)
		for m: Combatant in monsters:
			if from_left:
				assert_between(m.x, 10.0, 18.0, "monster %d in the far half, %s" % [m.id, side])
			else:
				assert_between(m.x, 2.0, 10.0, "monster %d in the far half, %s" % [m.id, side])

		var left_the_span: bool = false
		var ticks: int = 0
		while battle.result() == Battle.Result.ONGOING and ticks < Battle.MAX_TICKS:
			battle.step()
			ticks += 1
			for c: Combatant in battle.heroes + battle.monsters:
				if c.x < 2.0 or c.x > 18.0:
					left_the_span = true
		assert_false(left_the_span, "nobody leaves the span, %s" % side)
		assert_ne(battle.result(), Battle.Result.ONGOING, "the fight finished, %s" % side)


# --- R4 ------------------------------------------------------------------------


func test_r4_targets_nearest_enemy_and_healer_prefers_hurt_ally() -> void:
	var fighter := Combatant.from_hero(_hero_def(HeroClassDef.Role.MELEE), 1, 1)
	var far := Combatant.from_monster(_dummy(), 1, 10)
	var near := Combatant.from_monster(_dummy(), 1, 11)
	var battle := _battle([fighter], [far, near])
	fighter.x = 4.0
	far.x = 12.0
	near.x = 7.0
	battle.step()
	assert_eq(fighter.target_id, near.id, "the hero picks the nearest monster")
	assert_eq(far.target_id, fighter.id, "a monster picks the nearest hero")
	near.x = 14.0
	far.x = 6.0
	battle.step()
	assert_eq(fighter.target_id, far.id, "the choice follows whoever is nearest now")

	var tank := Combatant.from_hero(_hero_def(HeroClassDef.Role.TANK), 1, 1)
	var cleric := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.HEALER, {"heal_power": 10, "attack_range": 50.0}), 1, 2
	)
	var enemy := Combatant.from_monster(_dummy(), 1, 10)
	battle = _battle([tank, cleric], [enemy])
	tank.health = tank.max_health / 2
	battle.step()
	assert_eq(cleric.target_id, tank.id, "the healer targets an ally at 50%")

	tank = Combatant.from_hero(_hero_def(HeroClassDef.Role.TANK), 1, 1)
	cleric = Combatant.from_hero(
		_hero_def(HeroClassDef.Role.HEALER, {"heal_power": 10, "attack_range": 50.0}), 1, 2
	)
	enemy = Combatant.from_monster(_dummy(), 1, 10)
	battle = _battle([tank, cleric], [enemy])
	tank.health = roundi(tank.max_health * 0.9)
	cleric.health = roundi(cleric.max_health * 0.85)
	battle.step()
	assert_eq(cleric.target_id, enemy.id, "all allies above 80%: the healer attacks the enemy")

	tank = Combatant.from_hero(_hero_def(HeroClassDef.Role.TANK), 1, 1)
	cleric = Combatant.from_hero(
		_hero_def(HeroClassDef.Role.HEALER, {"heal_power": 10, "attack_range": 50.0}), 1, 2
	)
	enemy = Combatant.from_monster(_dummy(), 1, 10)
	battle = _battle([tank, cleric], [enemy])
	tank.health = roundi(tank.max_health * 0.7)
	cleric.health = roundi(cleric.max_health * 0.4)
	battle.step()
	assert_eq(cleric.target_id, cleric.id, "the lowest fraction wins, the healer included")


# --- R5 ------------------------------------------------------------------------


func test_r5_walks_into_range_then_stops() -> void:
	# Range 1.0, 2 tiles per second: 0.2 tiles per tick.
	var walker := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.MELEE, {"attack_range": 1.0, "move_speed": 2.0}), 1, 1
	)
	var archer := Combatant.from_monster(
		_dummy(10_000, {"attack_range": 30.0, "move_speed": 3.0}), 1, 10
	)
	var battle := _battle([walker], [archer])
	assert_almost_eq(walker.x, SPAN_LEFT, 0.0001, "a lone hero starts at the entry edge")
	var archer_x: float = archer.x
	var stop_x: float = archer_x - 1.0
	for t: int in range(1, 121):
		battle.step()
		var expected: float = minf(SPAN_LEFT + 0.2 * t, stop_x)
		assert_almost_eq(walker.x, expected, 0.001, "tick %d" % t)
		assert_almost_eq(
			archer.x, archer_x, 0.0001, "a ranged combatant in range stays put (tick %d)" % t
		)
	assert_almost_eq(absf(archer.x - walker.x), 1.0, 0.001, "stopped exactly in range")


# --- R6 ------------------------------------------------------------------------


func test_r6_attack_rhythm() -> void:
	# windup 0.3 s = 3 ticks, attack_interval 0.5 s = 5 ticks.
	var hero := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.MELEE, {"windup": 0.3, "attack_interval": 0.5}), 1, 1
	)
	var target := Combatant.from_monster(_dummy(), 1, 10)
	var battle := _battle([hero], [target])
	hero.x = 5.0
	target.x = 6.0
	var events: Array[SimEvent] = _run(battle, 30)
	assert_eq(
		_ticks_of(_of_kind(events, SimEvent.Kind.ATTACK_STARTED, hero.id)),
		[1, 9, 17, 25] as Array[int],
		"an attack starts again windup + interval after the last one"
	)
	assert_eq(
		_ticks_of(_of_kind(events, SimEvent.Kind.HIT, hero.id)),
		[4, 12, 20, 28] as Array[int],
		"strikes land windup after starting, every windup + interval"
	)

	# A slow hero winds up for 1 s on a weak monster; a quick ally kills it first.
	var slow := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.RANGED, {"windup": 1.0, "attack_range": 100.0}), 1, 1
	)
	var quick := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.MELEE, {"windup": 0.1, "damage": 1000}), 1, 2
	)
	var weak := Combatant.from_monster(_dummy(1), 1, 10)
	var other := Combatant.from_monster(_dummy(), 1, 11)
	battle = _battle([slow, quick], [weak, other])
	slow.x = 4.0
	quick.x = 7.0
	weak.x = 8.0
	other.x = 15.0
	events = _run(battle, 20)
	assert_false(weak.is_alive(), "the quick hero killed the weak monster")
	var slow_starts: Array[SimEvent] = _of_kind(events, SimEvent.Kind.ATTACK_STARTED, slow.id)
	assert_gte(slow_starts.size(), 2, "the slow hero started again")
	if slow_starts.size() >= 2:
		assert_eq(slow_starts[0].target_id, weak.id)
		assert_eq(slow_starts[0].tick, 1)
		assert_eq(slow_starts[1].target_id, other.id, "the new attack is on a living target")
		assert_lte(slow_starts[1].tick, 3, "and starts at once, with no cooldown")
	for e: SimEvent in events:
		if (
			e.source_id == slow.id
			and e.target_id == weak.id
			and e.kind != SimEvent.Kind.ATTACK_STARTED
		):
			fail_test(
				"the slow hero's strike on the dead monster should be lost: %s" % [_describe(e)]
			)


# --- R7 ------------------------------------------------------------------------


func test_r7_melee_lands_at_once_projectiles_fly() -> void:
	# Melee at exactly MELEE_REACH: windup 0.2 s = 2 ticks, hit on the strike tick, no projectile.
	var knight := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.TANK, {"windup": 0.2, "attack_range": Battle.MELEE_REACH}), 1, 1
	)
	var dummy := Combatant.from_monster(_dummy(), 1, 10)
	var battle := _battle([knight], [dummy])
	knight.x = 5.0
	dummy.x = 6.5
	var events: Array[SimEvent] = _run(battle, 3)
	assert_eq(_ticks_of(_of_kind(events, SimEvent.Kind.HIT, knight.id)), [3] as Array[int])
	assert_eq(_of_kind(events, SimEvent.Kind.PROJECTILE_LAUNCHED, knight.id).size(), 0)

	# Ranged: distance 6 at 12 tiles per second is 0.5 s = 5 ticks of flight.
	var mage := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.RANGED, {"windup": 0.2, "attack_range": 6.0}), 1, 1
	)
	dummy = Combatant.from_monster(_dummy(), 1, 10)
	battle = _battle([mage], [dummy])
	mage.x = 2.0
	dummy.x = 8.0
	events = _run(battle, 9)
	var launches: Array[SimEvent] = _of_kind(events, SimEvent.Kind.PROJECTILE_LAUNCHED, mage.id)
	assert_eq(_ticks_of(launches), [3] as Array[int], "launched on the strike tick")
	if launches.size() == 1:
		assert_eq(launches[0].amount, 5, "5 ticks of flight")
		assert_false(launches[0].flag, "an attack, not a heal")
		assert_eq(launches[0].target_id, dummy.id)
	assert_eq(
		_ticks_of(_of_kind(events, SimEvent.Kind.HIT, mage.id)),
		[8] as Array[int],
		"lands 5 ticks later"
	)

	# A heal in flight lands although the healer is killed meanwhile.
	var healer := Combatant.from_hero(
		_hero_def(
			HeroClassDef.Role.HEALER, {"windup": 0.1, "attack_range": 10.0, "heal_power": 10}
		),
		1,
		1
	)
	var tank := Combatant.from_hero(_hero_def(HeroClassDef.Role.TANK, {"damage": 1}), 1, 2)
	var killer := Combatant.from_monster(
		_monster_def(
			{
				"max_health": 10_000,
				"damage": 1000,
				"windup": 0.3,
				"attack_range": 1.0,
				"move_speed": 0.0
			}
		),
		1,
		10
	)
	battle = _battle([healer, tank], [killer])
	healer.x = 3.0
	tank.x = 9.0
	killer.x = 2.0
	tank.health = tank.max_health / 2
	events = _run(battle, 10)
	assert_false(healer.is_alive(), "the healer was killed at tick 4")
	var heal_launch: Array[SimEvent] = _of_kind(
		events, SimEvent.Kind.PROJECTILE_LAUNCHED, healer.id
	)
	assert_eq(heal_launch.size(), 1)
	if heal_launch.size() == 1:
		assert_true(heal_launch[0].flag, "a heal projectile")
		assert_eq(heal_launch[0].amount, 5, "6 tiles of flight: 5 ticks")
		assert_eq(heal_launch[0].tick, 2)
	var heals: Array[SimEvent] = _of_kind(events, SimEvent.Kind.HEALED, healer.id)
	assert_eq(_ticks_of(heals), [7] as Array[int], "the heal still lands, after its healer died")
	var healer_death: Array[SimEvent] = _of_kind(events, SimEvent.Kind.DIED, healer.id)
	assert_eq(_ticks_of(healer_death), [4] as Array[int])

	# A projectile whose target died first does nothing.
	var archer := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.RANGED, {"windup": 0.1, "attack_range": 6.0}), 1, 1
	)
	var slayer := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.MELEE, {"windup": 0.2, "damage": 1000}), 1, 2
	)
	var victim := Combatant.from_monster(_dummy(50), 1, 10)
	var bystander := Combatant.from_monster(_dummy(), 1, 11)
	battle = _battle([archer, slayer], [victim, bystander])
	archer.x = 2.0
	slayer.x = 7.0
	victim.x = 8.0
	bystander.x = 16.0
	events = _run(battle, 10)
	assert_eq(
		_ticks_of(_of_kind(events, SimEvent.Kind.DIED)),
		[3] as Array[int],
		"the slayer kills at tick 3"
	)
	var shots: Array[SimEvent] = _of_kind(events, SimEvent.Kind.PROJECTILE_LAUNCHED, archer.id)
	assert_eq(shots.size(), 1, "one shot launched")
	if shots.size() == 1:
		assert_eq(shots[0].target_id, victim.id)
		assert_eq(shots[0].tick, 2)
	for e: SimEvent in events:
		if e.target_id == victim.id and e.tick > 3:
			fail_test("nothing happens to the dead victim: %s" % [_describe(e)])
	assert_eq(victim.health, 0, "health never goes below 0")


# --- R8 ------------------------------------------------------------------------


func test_r8_damage_and_healing_rules() -> void:
	var plain: int = 0
	var crits: int = 0
	for seed_value: int in range(1, 41):
		var striker := Combatant.from_hero(
			_hero_def(
				HeroClassDef.Role.MELEE,
				{"damage": 20, "crit_chance": 0.5, "windup": 0.1, "attack_interval": 0.1}
			),
			1,
			1
		)
		var armoured := Combatant.from_monster(_dummy(1_000_000, {"armor": 5}), 1, 10)
		var fight := _battle([striker], [armoured], seed_value)
		striker.x = 5.0
		armoured.x = 6.0
		var before: int = armoured.health
		var events: Array[SimEvent] = _run(fight, 100)
		var dealt: int = 0
		for hit: SimEvent in _of_kind(events, SimEvent.Kind.HIT, striker.id):
			dealt += hit.amount
			if hit.flag:
				crits += 1
				assert_between(
					hit.amount, 29, 41, "crit = round(2 x 20 x roll - 5), seed %d" % seed_value
				)
			else:
				plain += 1
				assert_between(hit.amount, 12, 18, "round(20 x roll - 5), seed %d" % seed_value)
		assert_eq(armoured.health, before - dealt, "hits take health, seed %d" % seed_value)
	assert_gt(plain, 100, "plenty of plain hits")
	assert_gt(crits, 100, "plenty of crits")

	# Armour above the damage still leaves 1.
	var feeble := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.MELEE, {"damage": 2, "windup": 0.1}), 1, 1
	)
	var wall := Combatant.from_monster(_dummy(10_000, {"armor": 10}), 1, 10)
	var battle := _battle([feeble], [wall])
	feeble.x = 5.0
	wall.x = 6.0
	var feeble_hits: Array[SimEvent] = _of_kind(_run(battle, 100), SimEvent.Kind.HIT, feeble.id)
	assert_gt(feeble_hits.size(), 5)
	for hit: SimEvent in feeble_hits:
		assert_eq(hit.amount, 1, "damage is never below 1")

	# Heals roll like damage: 1000-health patient at half health, heal power 20.
	var heals_seen: int = 0
	for seed_value: int in range(1, 21):
		var rolled: Array[SimEvent] = _patient_of_heals(seed_value, 1000, 500, 20)
		for e: SimEvent in rolled:
			heals_seen += 1
			assert_between(e.amount, 17, 23, "round(20 x roll), seed %d" % seed_value)
	assert_gt(heals_seen, 100, "plenty of heals")

	# A heal bigger than the missing health stops at the maximum.
	for seed_value: int in range(1, 21):
		var capped: Array[SimEvent] = _patient_of_heals(seed_value, 100, 75, 40)
		assert_gt(capped.size(), 0, "the patient was healed, seed %d" % seed_value)
		var restored: int = 0
		for e: SimEvent in capped:
			restored += e.amount
		if not capped.is_empty():
			assert_eq(capped[0].amount, 25, "only the missing 25 is restored, seed %d" % seed_value)
		assert_eq(restored, 25, "heals in flight behind it restore nothing, seed %d" % seed_value)


## One healer heals one patient (who starts at [param health] of
## [param max_health]) for 300 ticks. Checks the patient never passes its
## maximum and returns the HEALED events.
func _patient_of_heals(
	seed_value: int, max_health: int, health: int, power: int
) -> Array[SimEvent]:
	var healer := Combatant.from_hero(
		_hero_def(
			HeroClassDef.Role.HEALER,
			{"heal_power": power, "windup": 0.1, "attack_interval": 0.1, "attack_range": 10.0}
		),
		1,
		1
	)
	var patient := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.TANK, {"max_health": max_health, "health_per_level": 0}), 1, 2
	)
	var idle := Combatant.from_monster(_dummy(), 1, 10)
	var battle := _battle([healer, patient], [idle], seed_value)
	healer.x = 3.0
	patient.x = 5.0
	idle.x = 15.0
	patient.health = health
	var heals: Array[SimEvent] = []
	for i: int in 300:
		battle.step()
		assert_lte(patient.health, patient.max_health, "never above maximum, seed %d" % seed_value)
		for e: SimEvent in battle.drain_events():
			if e.kind == SimEvent.Kind.HEALED:
				assert_eq(e.target_id, patient.id)
				heals.append(e)
	if max_health - health < roundi(power * 0.85):
		assert_eq(patient.health, patient.max_health, "the heal filled the patient up")
	return heals


# --- R9 ------------------------------------------------------------------------


func test_r9_death_and_result() -> void:
	# A real fight: three strong heroes against five weak monsters.
	var heroes: Array[Combatant] = []
	for i: int in 3:
		var role: HeroClassDef.Role = [
			HeroClassDef.Role.TANK, HeroClassDef.Role.MELEE, HeroClassDef.Role.RANGED
		][i]
		var range_tiles: float = 6.0 if role == HeroClassDef.Role.RANGED else 1.0
		heroes.append(
			Combatant.from_hero(
				_hero_def(role, {"attack_range": range_tiles, "damage": 15}), 1, i + 1
			)
		)
	var monsters: Array[Combatant] = []
	for i: int in 5:
		monsters.append(
			Combatant.from_monster(_monster_def({"max_health": 30, "damage": 3}), 1, 10 + i)
		)
	var battle := _battle(heroes, monsters)
	var dead: Dictionary = {}
	var dead_x: Dictionary = {}
	while battle.result() == Battle.Result.ONGOING and battle.tick < Battle.MAX_TICKS:
		battle.step()
		for e: SimEvent in battle.drain_events():
			var acting: bool = (
				e.kind == SimEvent.Kind.ATTACK_STARTED
				or e.kind == SimEvent.Kind.PROJECTILE_LAUNCHED
			)
			if acting and dead.has(e.source_id):
				fail_test("the dead never act: %s" % [_describe(e)])
			if e.kind != SimEvent.Kind.DIED and dead.has(e.target_id):
				fail_test("the dead are never targeted: %s" % [_describe(e)])
			if e.kind == SimEvent.Kind.DIED:
				assert_false(dead.has(e.source_id), "a combatant dies once")
				var c: Combatant = battle.combatant(e.source_id)
				dead[e.source_id] = true
				dead_x[e.source_id] = c.x
				assert_eq(c.health, 0)
				assert_eq(c.state, Combatant.State.DEAD)
				assert_false(c.is_alive())
		for c: Combatant in battle.heroes + battle.monsters:
			if c.is_alive():
				assert_false(
					dead.has(c.target_id), "no one targets the dead (tick %d)" % battle.tick
				)
			else:
				var where: float = dead_x[c.id]
				assert_eq(c.x, where, "the dead do not move")
	assert_eq(battle.result(), Battle.Result.HEROES_WON)
	assert_eq(dead.size(), 5, "every monster died, no hero did")

	# The other way round.
	var lone := Combatant.from_hero(_hero_def(HeroClassDef.Role.MELEE, {"max_health": 20}), 1, 1)
	var brute := Combatant.from_monster(_monster_def({"max_health": 1000, "damage": 15}), 1, 10)
	battle = _battle([lone], [brute])
	_run(battle)
	assert_eq(battle.result(), Battle.Result.MONSTERS_WON)
	assert_false(lone.is_alive())
	assert_lt(battle.tick, Battle.MAX_TICKS)

	# Nobody can reach anybody: a stalemate ends at MAX_TICKS as a monster win.
	var stuck := Combatant.from_hero(_hero_def(HeroClassDef.Role.MELEE, {"move_speed": 0.0}), 1, 1)
	var rooted := Combatant.from_monster(_monster_def({"move_speed": 0.0}), 1, 10)
	battle = _battle([stuck], [rooted])
	for i: int in Battle.MAX_TICKS - 1:
		battle.step()
	assert_eq(battle.result(), Battle.Result.ONGOING, "still going at tick %d" % battle.tick)
	battle.step()
	assert_eq(battle.tick, Battle.MAX_TICKS)
	assert_eq(battle.result(), Battle.Result.MONSTERS_WON, "a stalemate is a monster win")
	battle.step()
	assert_eq(battle.tick, Battle.MAX_TICKS, "a finished battle does not step")


# --- R10 -----------------------------------------------------------------------


func test_r10_events_tell_the_whole_story() -> void:
	# Damage 1 rolls to exactly 1, so every amount is known.
	var hero := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.MELEE, {"damage": 1, "windup": 0.1, "attack_interval": 0.2}),
		1,
		1
	)
	var spitter := Combatant.from_monster(
		_monster_def(
			{
				"max_health": 3,
				"damage": 1,
				"windup": 0.2,
				"attack_interval": 1.0,
				"attack_range": 3.0,
				"move_speed": 0.0
			}
		),
		1,
		10
	)
	var battle := _battle([hero], [spitter])
	hero.x = 5.0
	spitter.x = 6.0
	assert_eq(battle.drain_events().size(), 0, "nothing has happened before the first step")
	var events: Array[SimEvent] = []
	while battle.result() == Battle.Result.ONGOING and battle.tick < 50:
		battle.step()
		var batch: Array[SimEvent] = battle.drain_events()
		for e: SimEvent in batch:
			assert_eq(e.tick, battle.tick, "drained events are from the step just taken")
		events.append_array(batch)
		assert_eq(battle.drain_events().size(), 0, "a second drain returns nothing")
	var h: int = hero.id
	var m: int = spitter.id
	# ATTACK_STARTED carries the wind-up in ticks: 1 for the hero, 2 for the spitter.
	var expected: Array = [
		["ATTACK_STARTED", 1, h, m, 1, false],
		["ATTACK_STARTED", 1, m, h, 2, false],
		["HIT", 2, h, m, 1, false],
		["PROJECTILE_LAUNCHED", 3, m, h, 1, false],
		["HIT", 4, m, h, 1, false],
		["ATTACK_STARTED", 4, h, m, 1, false],
		["HIT", 5, h, m, 1, false],
		["ATTACK_STARTED", 7, h, m, 1, false],
		["HIT", 8, h, m, 1, false],
		["DIED", 8, m, -1, 0, false],
	]
	var actual: Array = []
	for e: SimEvent in events:
		actual.append(_describe(e))
	assert_eq_deep(actual, expected)
	assert_eq(battle.result(), Battle.Result.HEROES_WON)
	assert_eq(battle.tick, 8)
	assert_eq(hero.health, hero.max_health - 1)


# --- R11 -----------------------------------------------------------------------


func _fight_story(seed_value: int) -> Array:
	var battle := Battle.new(
		_shipped_party(),
		_shipped_monsters([[&"skeleton", 2, 2], [&"cave_bat", 2, 1], [&"spider", 1, 3]]),
		SPAN_LEFT,
		SPAN_RIGHT,
		true,
		SimRng.new(seed_value)
	)
	var story: Array = []
	for e: SimEvent in _run(battle):
		story.append(_describe(e))
	story.append(battle.result())
	return story


func test_r11_same_seed_same_fight() -> void:
	var first: Array = _fight_story(SEED)
	var second: Array = _fight_story(SEED)
	assert_gt(first.size(), 20, "a real fight with many events")
	assert_eq_deep(second, first)
	var other: Array = _fight_story(SEED + 1)
	assert_ne(str(other), str(first), "a different seed gives a different fight")


# --- R12 -----------------------------------------------------------------------


## Fights the given monsters with the party BALANCE_SEEDS times. Returns
## [wins, wins with no hero dead, shortest won fight in ticks, longest].
func _balance(monster_groups: Array, fourth: StringName = &"cleric") -> Array[int]:
	var wins: int = 0
	var clean: int = 0
	var shortest: int = Battle.MAX_TICKS
	var longest: int = 0
	for seed_value: int in range(1, BALANCE_SEEDS + 1):
		var party: Array[Combatant] = _shipped_party(fourth)
		var battle := Battle.new(
			party,
			_shipped_monsters(monster_groups),
			SPAN_LEFT,
			SPAN_RIGHT,
			true,
			SimRng.new(seed_value)
		)
		while battle.result() == Battle.Result.ONGOING:
			battle.step()
		battle.drain_events()
		if battle.result() != Battle.Result.HEROES_WON:
			continue
		wins += 1
		shortest = mini(shortest, battle.tick)
		longest = maxi(longest, battle.tick)
		var all_alive: bool = true
		for hero: Combatant in party:
			all_alive = all_alive and hero.is_alive()
		if all_alive:
			clean += 1
	return [wins, clean, shortest, longest]


func test_r12_balance_targets() -> void:
	var slimes: Array[int] = _balance([[&"slime", 3, 1]])
	gut.p("three slimes: %s" % [slimes])
	assert_gte(
		slimes[1], ceili(BALANCE_SEEDS * 0.99), "the party beats three slimes with no hero dead"
	)
	var ticks_per_second: float = Simulation.TICKS_PER_SECOND
	assert_gte(slimes[2] / ticks_per_second, 5.0, "a slime fight lasts at least 5 s")
	assert_lte(slimes[3] / ticks_per_second, 40.0, "a slime fight lasts at most 40 s")

	var mixed: Array[int] = _balance([[&"skeleton", 2, 2], [&"cave_bat", 2, 1]])
	gut.p("two skeletons and two bats: %s" % [mixed])
	assert_gte(mixed[0], ceili(BALANCE_SEEDS * 0.9), "the party beats two skeletons and two bats")

	var ogres: Array[int] = _balance([[&"ogre", 6, 5]])
	gut.p("six ogres: %s" % [ogres])
	assert_lte(ogres[0], floori(BALANCE_SEEDS * 0.1), "the party loses to six depth-5 ogres")

	var with_cleric: Array[int] = _balance([[&"skeleton", 4, 3]], &"cleric")
	var two_rogues: Array[int] = _balance([[&"skeleton", 4, 3]], &"rogue")
	gut.p("four depth-3 skeletons: cleric %s, second rogue %s" % [with_cleric, two_rogues])
	var cleric_rate: float = 100.0 * with_cleric[0] / BALANCE_SEEDS
	var rogue_rate: float = 100.0 * two_rogues[0] / BALANCE_SEEDS
	assert_gte(cleric_rate - rogue_rate, 20.0, "the cleric is worth at least 20 points of win rate")

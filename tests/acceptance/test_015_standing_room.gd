extends GutTest
## Acceptance tests for specs/015-standing-room/spec.md, one per requirement.
##
## R5 is the existing suite: it passes with its numbers unchanged.

const SEED: int = 1234
const EPSILON: float = 0.0001
## A duration long enough that it never comes round in a test.
const NEVER: float = 100_000.0

# --- Helpers -----------------------------------------------------------------


func _monster_def(overrides: Dictionary = {}) -> MonsterDef:
	var def := MonsterDef.new()
	def.id = &"test_monster"
	def.display_name = "Test monster"
	def.size = MonsterDef.Size.SMALL
	def.min_depth = 1
	def.max_health = 100
	def.damage = 5
	def.armor = 0
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 2.0
	def.crit_chance = 0.0
	def.xp = 1
	def.gold_min = 1
	def.gold_max = 2
	for key: String in overrides:
		def.set(key, overrides[key])
	return def


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


func _typed(list: Array) -> Array[Combatant]:
	var typed: Array[Combatant] = []
	for c: Combatant in list:
		typed.append(c)
	return typed


func _starting_party() -> Array[Combatant]:
	var party: Array[Combatant] = []
	for i: int in Party.STARTING_CLASSES.size():
		var def: HeroClassDef = Content.hero_class(Party.STARTING_CLASSES[i])
		party.append(Combatant.from_hero(def, 1, i + 1))
	return party


## Pairs of living, standing combatants of one side closer than MIN_SPACING, described.
func _crowded(side: Array[Combatant]) -> Array[String]:
	var found: Array[String] = []
	for i: int in side.size():
		for j: int in range(i + 1, side.size()):
			var a: Combatant = side[i]
			var b: Combatant = side[j]
			if not a.is_alive() or not b.is_alive():
				continue
			if a.state == Combatant.State.MOVING or b.state == Combatant.State.MOVING:
				continue
			var gap: float = absf(a.x - b.x)
			if gap < Battle.MIN_SPACING - EPSILON:
				found.append("%d and %d %.3f apart" % [a.id, b.id, gap])
	return found


func _nearest_monster(battle: Battle, x: float) -> float:
	var best: float = INF
	for m: Combatant in battle.monsters:
		if m.is_alive():
			best = minf(best, absf(m.x - x))
	return best


# --- R1 ------------------------------------------------------------------------


func test_r1_same_side_keeps_spacing() -> void:
	var kinds: Array[StringName] = [&"slime", &"goblin", &"skeleton", &"cave_bat", &"spider"]
	var problems: Array[String] = []
	var battles: int = 0
	for seed_value: int in range(1, 51):
		var rng := SimRng.new(seed_value)
		var count: int = 3 + seed_value % 3
		var width: float = 10.0 + rng.next_int(0, 14)
		var monsters: Array[Combatant] = []
		for i: int in count:
			var def: MonsterDef = Content.monster(kinds[rng.next_int(0, kinds.size() - 1)])
			monsters.append(Combatant.from_monster(def, 1 + seed_value % 3, 100 + i))
		var battle := Battle.new(
			_starting_party(), monsters, 0.0, width, seed_value % 2 == 0, SimRng.new(seed_value)
		)
		battles += 1
		while battle.result() == Battle.Result.ONGOING:
			battle.step()
			battle.drain_events()
			for side: Array[Combatant] in [battle.heroes, battle.monsters]:
				for p: String in _crowded(side):
					problems.append("seed %d tick %d: %s" % [seed_value, battle.tick, p])
	assert_eq(battles, 50)
	assert_eq(problems.size(), 0, "standing allies too close: %s" % [problems.slice(0, 5)])


# --- R2 ------------------------------------------------------------------------


func test_r2_held_back_fighters_still_strike() -> void:
	# One hero that never finishes an attack, four melee monsters on it.
	var hero := Combatant.from_hero(
		_hero_def(HeroClassDef.Role.TANK, {"max_health": 100_000, "windup": NEVER}), 1, 1
	)
	var monsters: Array[Combatant] = []
	for i: int in 4:
		monsters.append(Combatant.from_monster(_monster_def({"damage": 1}), 1, 10 + i))
	var battle := Battle.new(_typed([hero]), monsters, 0.0, 16.0, true, SimRng.new(SEED))
	# The farthest monster walks at most the span, then winds up within one interval.
	var budget: int = Combatant.seconds_to_ticks(16.0 / 2.0 + 0.3 + 1.0)
	var hitters: Dictionary[int, bool] = {}
	for t: int in budget:
		battle.step()
		for e: SimEvent in battle.drain_events():
			if e.kind == SimEvent.Kind.HIT:
				hitters[e.source_id] = true
	for m: Combatant in monsters:
		assert_true(hitters.has(m.id), "monster %d landed a hit within %d ticks" % [m.id, budget])
	assert_gt(_spread_of(monsters), Battle.MIN_SPACING, "they do not all stand on one spot")

	var knight := Combatant.from_hero(Content.hero_class(&"knight"), 1, 1)
	var rogue := Combatant.from_hero(Content.hero_class(&"rogue"), 1, 2)
	var dummy := Combatant.from_monster(
		_monster_def({"max_health": 100_000, "windup": NEVER, "move_speed": 0.0}), 1, 10
	)
	battle = Battle.new(_typed([knight, rogue]), _typed([dummy]), 0.0, 16.0, true, SimRng.new(SEED))
	var struck: Dictionary[int, bool] = {}
	for t: int in Combatant.seconds_to_ticks(10.0):
		battle.step()
		for e: SimEvent in battle.drain_events():
			if e.kind == SimEvent.Kind.HIT:
				struck[e.source_id] = true
	assert_true(struck.has(knight.id), "the knight lands hits")
	assert_true(struck.has(rogue.id), "the rogue lands hits from behind the knight")
	assert_gte(absf(knight.x - rogue.x), Battle.MIN_SPACING - EPSILON, "on two spots, not one")


func _spread_of(side: Array[Combatant]) -> float:
	var low: float = INF
	var high: float = -INF
	for c: Combatant in side:
		low = minf(low, c.x)
		high = maxf(high, c.x)
	return high - low


# --- R3 ------------------------------------------------------------------------


func test_r3_front_line_order() -> void:
	for from_left: bool in [true, false]:
		var party: Array[Combatant] = _starting_party()
		var monsters: Array[Combatant] = []
		for i: int in 3:
			var def := _monster_def({"max_health": 100_000, "damage": 1})
			monsters.append(Combatant.from_monster(def, 1, 10 + i))
		var battle := Battle.new(party, monsters, 0.0, 16.0, from_left, SimRng.new(SEED))
		for t: int in Combatant.seconds_to_ticks(5.0):
			battle.step()
		battle.drain_events()
		var distances: Array[float] = []
		for hero: Combatant in party:
			distances.append(_nearest_monster(battle, hero.x))
		var side: String = "from the left" if from_left else "from the right"
		gut.p("distances %s: %s" % [side, distances])
		# The party is knight (tank), rogue (melee), mage (ranged), cleric (healer).
		assert_lt(distances[0], distances[1], "tank before melee, %s" % side)
		assert_lt(distances[1], distances[2], "melee before ranged, %s" % side)
		assert_lt(distances[2], distances[3], "ranged before healer, %s" % side)


# --- R4 ------------------------------------------------------------------------


func test_r4_stays_in_the_span() -> void:
	var left: float = 3.0
	var right: float = 7.0
	for from_left: bool in [true, false]:
		var monsters: Array[Combatant] = []
		for i: int in 5:
			monsters.append(Combatant.from_monster(_monster_def({"damage": 3}), 1, 10 + i))
		var battle := Battle.new(
			_starting_party(), monsters, left, right, from_left, SimRng.new(SEED)
		)
		var outside: Array[String] = []
		while battle.result() == Battle.Result.ONGOING:
			battle.step()
			battle.drain_events()
			for c: Combatant in battle.heroes + battle.monsters:
				if c.x < left - EPSILON or c.x > right + EPSILON:
					outside.append("tick %d: %d at %.3f" % [battle.tick, c.id, c.x])
		assert_eq(outside.size(), 0, "left the span: %s" % [outside.slice(0, 5)])
		assert_ne(battle.result(), Battle.Result.ONGOING, "the fight finished")


# --- R6 ------------------------------------------------------------------------


func test_r6_climbers_are_centred() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_push(false)
	var e: Expedition = sim.expedition
	var middle: float = sim.labyrinth.shaft_column(1) + Labyrinth.SHAFT_WIDTH / 2.0
	var climbing_ticks: Array[int] = [0, 0]
	var wrong: Array[String] = []
	for leg: int in 2:
		sim.set_target_depth(2 if leg == 0 else 1)
		var climbed: bool = false
		for i: int in Combatant.seconds_to_ticks(1800.0):
			sim.step()
			sim.drain_events()
			if e.state == Expedition.State.CLIMBING:
				climbed = true
				climbing_ticks[leg] += 1
				for hero: Hero in sim.party.heroes:
					var at: Vector2 = e.hero_position(hero.id)
					if absf(at.x - middle) > EPSILON:
						wrong.append(
							"leg %d tick %d hero %d x %.3f" % [leg, sim.tick, hero.id, at.x]
						)
			elif climbed:
				break
	assert_gt(climbing_ticks[0], 0, "climbed down")
	assert_gt(climbing_ticks[1], 0, "climbed up")
	assert_eq(e.depth, 1, "back on depth 1")
	assert_eq(wrong.size(), 0, "off the shaft's middle: %s" % [wrong.slice(0, 5)])

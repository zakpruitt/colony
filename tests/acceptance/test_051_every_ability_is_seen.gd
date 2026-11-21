extends ColonyTest
## Acceptance test for specs/051-talent-trees-and-paragon/spec.md, R14 (every ability is seen),
## added after the review of pull request 54. The other requirements are in
## test_051_talent_trees_and_paragon.gd.

## The Old Crypt's guardian, at its own level: Whirlwind must be used on it.
const GUARDIAN: StringName = &"bone_lord"
const GUARDIAN_LEVEL: int = 15
## R14: the play each seed and path is watched for, how long an ability must have been held to
## count, and how often an action must be used by then.
const SEEN_MINUTES: int = 30
const HELD_MINUTES: int = 10
const ACTION_USES: int = 5
## R14: abilities that answer a rescue, excused from the counts in play, and the fight built to
## need them.
const RESCUES: Array[StringName] = [
	&"last_stand", &"vanish", &"guardian_angel", &"miracle", &"sanctuary", &"rampage"
]
const RESCUE_FIGHT: Array[StringName] = [&"ogre", &"ogre", &"ogre"]
const RESCUE_LEVEL: int = 18


## [param class_id]'s trunk, then path [param path] (0 or 1), as nodes in order.
func _full(class_id: StringName, path: int) -> Array[StringName]:
	var tree: TalentTreeDef = Content.talent_tree(class_id)
	var nodes: Array[StringName] = []
	nodes.append_array(tree.trunk)
	nodes.append_array(tree.path_nodes(path))
	return nodes


# --- R14 -----------------------------------------------------------------------


## The uses of each hero ability over [constant SEEN_MINUTES] of play from level 1 on seed
## [param seed_value], each hero spending on path [param path]; one line per ability held for
## [constant HELD_MINUTES] that was not seen enough (an action fewer than [constant ACTION_USES]
## times, a passive never), rescues aside.
func _unseen(seed_value: int, path: int) -> PackedStringArray:
	var sim := Simulation.new(seed_value)
	var taken: Dictionary[String, int] = {}
	var uses: Dictionary[String, int] = {}
	var ticks: int = SEEN_MINUTES * 60 * Simulation.TICKS_PER_SECOND
	for i: int in ticks:
		TalentSpender.spend(sim, path)
		sim.step()
		for e: SimEvent in sim.drain_events():
			if e.kind == SimEvent.Kind.TALENT_TAKEN:
				taken["%d %s" % [e.source_id, e.ability_id]] = sim.tick
			elif e.kind == SimEvent.Kind.ABILITY_USED and e.source_id < Expedition.FIRST_MONSTER_ID:
				var key: String = "%d %s" % [e.source_id, e.ability_id]
				uses[key] = uses.get(key, 0) + 1
	var unseen := PackedStringArray()
	var held_ticks: int = HELD_MINUTES * 60 * Simulation.TICKS_PER_SECOND
	for key: String in taken:
		var ability: AbilityDef = Content.ability(StringName(key.get_slice(" ", 1)))
		if ticks - taken[key] < held_ticks or RESCUES.has(ability.id):
			continue
		var count: int = uses.get(key, 0)
		var wanted: int = ACTION_USES if ability.is_action() else 1
		if count < wanted:
			var minutes: float = float(ticks - taken[key]) / (60 * Simulation.TICKS_PER_SECOND)
			unseen.append(
				(
					"seed %d, path %d: %s used %d times in %.1f minutes"
					% [seed_value, path, ability.id, count, minutes]
				)
			)
	return unseen


## The ids of the abilities heroes used, with how often, in a fight of a level-14 party, its
## heroes on the paths in [param paths] (by class), against [param monster_ids] at
## [param monster_level].
func _used_in(
	paths: Dictionary, monster_ids: Array[StringName], monster_level: int, seed_value: int
) -> Dictionary[StringName, int]:
	var party := Party.new()
	var heroes: Array[Combatant] = []
	for hero: Hero in party.heroes:
		raise(hero, 14)
		var path: int = paths[hero.class_id]
		hero.set_talents(_full(hero.class_id, path))
		heroes.append(hero.combatant())
	var monsters: Array[Combatant] = []
	for i: int in monster_ids.size():
		var def: MonsterDef = Content.monster(monster_ids[i])
		monsters.append(Combatant.from_monster(def, monster_level, 100 + i))
	var battle := Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(seed_value))
	var used: Dictionary[StringName, int] = {}
	while battle.result() == Battle.Result.ONGOING and battle.tick < LIMIT_TICKS_90_S:
		battle.step()
		for e: SimEvent in battle.drain_events():
			if e.kind == SimEvent.Kind.ABILITY_USED and e.source_id < 100:
				used[e.ability_id] = used.get(e.ability_id, 0) + 1
	return used


func test_r14_every_ability_is_seen() -> void:
	# Every action is ready as a fight starts (the trees refuse one that is not).
	for id: StringName in Content.ability_ids():
		var ability: AbilityDef = Content.ability(id)
		if ability.is_action():
			assert_true(ability.ready_at_start, "%s is ready as a fight starts" % id)
	# In play: every action held ten minutes used five times, every passive once.
	for seed_value: int in [1, 2, 3]:
		for path: int in 2:
			var unseen: PackedStringArray = _unseen(seed_value, path)
			assert_eq(unseen, PackedStringArray(), "seen in play:\n" + "\n".join(unseen))

	# The rescues fire in fights built to need them: a level-14 party against more than it can
	# take, once with each knight path.
	var fired: Dictionary[StringName, int] = {}
	for knight_path: int in 2:
		var paths: Dictionary = {&"knight": knight_path, &"rogue": 1, &"mage": 0, &"cleric": 0}
		for seed_value: int in 3:
			var used: Dictionary[StringName, int] = _used_in(
				paths, RESCUE_FIGHT, RESCUE_LEVEL, seed_value
			)
			for id: StringName in used:
				fired[id] = fired.get(id, 0) + used[id]
	for id: StringName in RESCUES:
		var times: int = fired.get(id, 0)
		assert_gt(times, 0, "%s answers a rescue: %s" % [id, fired])

	# Whirlwind against a guardian: an enemy in reach is enough.
	var berserker: Dictionary = {&"knight": 1, &"rogue": 0, &"mage": 0, &"cleric": 0}
	var guardian: Array[StringName] = [GUARDIAN]
	var whirled: Dictionary[StringName, int] = _used_in(berserker, guardian, GUARDIAN_LEVEL, 1)
	var whirls: int = whirled.get(&"whirlwind", 0)
	assert_gt(whirls, 0, "whirlwind on the %s: %s" % [GUARDIAN, whirled])
	assert_eq(Content.ability(&"whirlwind").condition, AbilityDef.Condition.NONE, "no condition")

	# Frost Nova is a burst around the nearest enemy; the mage does not walk in to cast it.
	var nova: AbilityDef = Content.ability(&"frost_nova")
	assert_eq(nova.aim, AbilityDef.Aim.NEAREST_ENEMY)
	assert_true(nova.anywhere, "cast from where the mage stands")
	assert_almost_eq(nova.cooldown, 12.0, 0.001, "every 12 s")
	var pushes: bool = false
	var slows: bool = false
	for effect: AbilityEffect in nova.effects:
		assert_eq(effect.lands, AbilityEffect.Lands.AROUND_TARGET, "around the nearest enemy")
		pushes = pushes or effect.does == AbilityEffect.Does.PUSH
		slows = slows or effect.status == AbilityEffect.Status.SLOWED
	assert_true(pushes and slows, "pushed back and slowed")


## Bulwark answers another ally's danger: the knight's own wounds do not set it off.
func test_r14_bulwark_counts_other_allies() -> void:
	var party := Party.new()
	var heroes: Array[Combatant] = []
	for hero: Hero in party.heroes:
		raise(hero, 14)
		if hero.class_id == &"knight":
			hero.set_talents(_full(&"knight", 0))
		heroes.append(hero.combatant())
	var knight: Combatant = heroes[0]
	var monsters: Array[Combatant] = [Combatant.from_monster(Content.monster(&"slime"), 1, 100)]
	var battle := Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(1))
	var bulwark: AbilityDef = Content.ability(&"bulwark")
	var only: Array[AbilityDef] = [bulwark]
	knight.abilities = only
	knight.health = 1
	assert_null(
		BattleAbilities.ready_action(battle, knight), "the knight alone is hurt: no Bulwark"
	)
	heroes[2].health = roundi(heroes[2].max_health * 0.5)
	assert_eq(BattleAbilities.ready_action(battle, knight), bulwark, "the mage is hurt: Bulwark")

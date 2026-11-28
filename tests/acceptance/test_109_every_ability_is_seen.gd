extends ColonyTest
## Acceptance test for specs/109-skill-paths-three-paths-of-five/spec.md, R8 (every ability is
## seen). The other requirements are in test_109_three_paths_of_five.gd.

## The Old Crypt's guardian, at its own level: Whirlwind must be used on it.
const GUARDIAN: StringName = &"bone_lord"
const GUARDIAN_LEVEL: int = 15
## The play each seed and path is watched for, how long an ability must have been held to count,
## and how often an action must be used by then.
const SEEN_MINUTES: int = 60
const HELD_MINUTES: int = 10
const ACTION_USES: int = 5
const SEEDS: Array[int] = [1, 2, 3]
## Abilities that answer a rescue, excused from the counts in play (with every action that waits
## for a hurt ally: [method _rescues]), and the fight built to need them.
const NAMED_RESCUES: Array[StringName] = [
	&"last_stand",
	&"vanish",
	&"guardian_angel",
	&"miracle",
	&"sanctuary",
	&"rampage",
	&"resurrection"
]
const HURT_ALLY: Array[AbilityDef.Condition] = [
	AbilityDef.Condition.ALLY_BELOW, AbilityDef.Condition.OTHER_ALLY_BELOW
]
const RESCUE_FIGHT: Array[StringName] = [&"ogre", &"ogre", &"ogre"]
const RESCUE_PARTY_LEVEL: int = 14
## The ogres' levels: one fight the party can almost take (where an ally is hurt but alive long
## enough to be answered), and one it cannot.
const RESCUE_LEVELS: Array[int] = [14, 18]
const RESCUE_SEEDS: int = 3
## The paths the rescue fights are fought with, by class: between them every rescue is held.
const RESCUE_PATHS: Array[Dictionary] = [
	{&"knight": 0, &"rogue": 2, &"mage": 0, &"cleric": 0},
	{&"knight": 1, &"rogue": 2, &"mage": 1, &"cleric": 0},
	{&"knight": 2, &"rogue": 2, &"mage": 2, &"cleric": 2},
]
## The full party's play: level 30, every node, from Mossy Hollow stage 18, with the camp upgrades
## that `dev.py sim --seed=1 --minutes=120 --buy-upgrades --spend-talents --winding` bought.
const FULL_LEVEL: int = 30
const FULL_STAGE: int = 18
const FULL_MINUTES: int = 30
const FULL_UPGRADES: Dictionary = {
	"fat_purse": 3, "field_medicine": 10, "quick_march": 10, "sharp_blades": 3, "stout_armor": 3
}


## The rescues: those named, and every action whose condition waits for a hurt ally, read from
## the abilities.
func _rescues() -> Array[StringName]:
	var found: Array[StringName] = NAMED_RESCUES.duplicate()
	for id: StringName in Content.ability_ids():
		var ability: AbilityDef = Content.ability(id)
		if ability.is_action() and HURT_ALLY.has(ability.condition) and not found.has(id):
			found.append(id)
	return found


## Every node of [param class_id]'s tree, path by path, each in its order.
func _every_node(class_id: StringName) -> Array[StringName]:
	var all: Array[StringName] = []
	for path: SkillPathDef in _tree(class_id).paths:
		all.append_array(path.nodes)
	return all


## Counts what heroes did over [param ticks] of [param sim]'s play: the tick each node was taken
## (from [param taken], which holds the nodes held from the start at tick 0) and each ability's
## uses, keyed "<hero id> <ability id>". With [param path] >= 0 the heroes spend on that path.
func _play_and_count(
	sim: Simulation,
	ticks: int,
	path: int,
	taken: Dictionary[String, int],
	uses: Dictionary[String, int]
) -> void:
	for i: int in ticks:
		var cheapest: StringName = sim.upgrades.cheapest_affordable(sim.party)
		if cheapest != &"":
			sim.buy_upgrade(cheapest)
		if path >= 0:
			TalentSpender.spend(sim, path)
		sim.step()
		for e: SimEvent in sim.drain_events():
			if e.kind == SimEvent.Kind.TALENT_TAKEN:
				taken["%d %s" % [e.source_id, e.ability_id]] = sim.tick
			elif e.kind == SimEvent.Kind.ABILITY_USED and e.source_id < Expedition.FIRST_MONSTER_ID:
				var key: String = "%d %s" % [e.source_id, e.ability_id]
				uses[key] = uses.get(key, 0) + 1


## One line per ability held for [constant HELD_MINUTES] by the end of [param ticks] that was not
## seen enough (an action fewer than [constant ACTION_USES] times, a passive never), rescues aside.
func _unseen_of(
	what: String, ticks: int, taken: Dictionary[String, int], uses: Dictionary[String, int]
) -> PackedStringArray:
	var unseen := PackedStringArray()
	var held_ticks: int = HELD_MINUTES * 60 * Simulation.TICKS_PER_SECOND
	var rescues: Array[StringName] = _rescues()
	for key: String in taken:
		var ability: AbilityDef = Content.ability(StringName(key.get_slice(" ", 1)))
		if ticks - taken[key] < held_ticks or rescues.has(ability.id):
			continue
		var count: int = uses.get(key, 0)
		var wanted: int = ACTION_USES if ability.is_action() else 1
		if count < wanted:
			var minutes: float = float(ticks - taken[key]) / (60 * Simulation.TICKS_PER_SECOND)
			unseen.append(
				"%s: %s used %d times in %.1f minutes" % [what, ability.id, count, minutes]
			)
	return unseen


## What was not seen enough in [constant SEEN_MINUTES] of play from level 1 on seed
## [param seed_value], winding, buying upgrades, each hero putting path [param path] first.
func _unseen(seed_value: int, path: int) -> PackedStringArray:
	var sim: Simulation = winding_simulation(seed_value)
	var taken: Dictionary[String, int] = {}
	var uses: Dictionary[String, int] = {}
	var ticks: int = SEEN_MINUTES * 60 * Simulation.TICKS_PER_SECOND
	_play_and_count(sim, ticks, path, taken, uses)
	return _unseen_of("seed %d, path %d" % [seed_value, path], ticks, taken, uses)


## The party at [constant FULL_LEVEL] with every node, standing at Mossy Hollow stage
## [constant FULL_STAGE] with [constant FULL_UPGRADES].
func _full_party() -> Simulation:
	var data: Dictionary = winding_simulation(1).to_save()
	for saved: Dictionary in data["heroes"]:
		saved["level"] = FULL_LEVEL
		saved["xp"] = Hero.xp_for_level(FULL_LEVEL)
		var names: Array = []
		var class_text: String = saved["class"]
		for node: StringName in _every_node(StringName(class_text)):
			names.append(String(node))
		saved["talents"] = names
	data["upgrades"] = FULL_UPGRADES.duplicate()
	for field: String in ["last_stable_depth", "deepest_depth", "target_depth"]:
		data[field] = FULL_STAGE
	var parsed: Dictionary = _through_json(data)
	assert_eq(Simulation.save_problems(parsed), PackedStringArray(), "the full party loads")
	return Simulation.from_save(parsed, Labyrinth.Shape.WINDING)


## The ids of the abilities heroes used, with how often, in a fight of a party of
## [param party_level], its heroes holding the five nodes of the paths in [param paths] (by
## class), against [param monster_ids] at [param monster_level].
func _used_in(
	paths: Dictionary,
	party_level: int,
	monster_ids: Array[StringName],
	monster_level: int,
	seed_value: int
) -> Dictionary[StringName, int]:
	var party := Party.new()
	var heroes: Array[Combatant] = []
	for hero: Hero in party.heroes:
		raise(hero, party_level)
		var path: int = paths[hero.class_id]
		hero.set_talents(_tree(hero.class_id).path(path).nodes)
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


# --- R8 ------------------------------------------------------------------------


func test_r8_every_ability_is_seen() -> void:
	# Every action is ready as a fight starts (the trees refuse one that is not).
	for id: StringName in Content.ability_ids():
		var ability: AbilityDef = Content.ability(id)
		if ability.is_action():
			assert_true(ability.ready_at_start, "%s is ready as a fight starts" % id)
	# In play: every action held ten minutes used five times, every passive once.
	for seed_value: int in SEEDS:
		for path: int in 3:
			var missed: PackedStringArray = _unseen(seed_value, path)
			assert_eq(missed, PackedStringArray(), "seen in play:\n" + "\n".join(missed))

	# The rescues fire in fights built to need them: a party against more than it can take.
	var fired: Dictionary[StringName, int] = {}
	for paths: Dictionary in RESCUE_PATHS:
		for seed_value: int in RESCUE_SEEDS * RESCUE_LEVELS.size():
			var used: Dictionary[StringName, int] = _used_in(
				paths,
				RESCUE_PARTY_LEVEL,
				RESCUE_FIGHT,
				RESCUE_LEVELS[seed_value % 2],
				floori(seed_value / 2.0)
			)
			for id: StringName in used:
				fired[id] = fired.get(id, 0) + used[id]
	var rescues: Array[StringName] = _rescues()
	for id: StringName in [&"bulwark", &"prayer", &"rallying_cry"]:
		assert_has(rescues, id, "%s waits for a hurt ally" % id)
	for id: StringName in rescues:
		var times: int = fired.get(id, 0)
		assert_gt(times, 0, "%s answers a rescue: %s" % [id, fired])

	# Whirlwind against a guardian: an enemy in reach is enough.
	var berserker: Dictionary = {&"knight": 1, &"rogue": 0, &"mage": 0, &"cleric": 0}
	var guardian: Array[StringName] = [GUARDIAN]
	var whirled: Dictionary[StringName, int] = _used_in(
		berserker, GUARDIAN_LEVEL - 1, guardian, GUARDIAN_LEVEL, 1
	)
	var whirls: int = whirled.get(&"whirlwind", 0)
	assert_gt(whirls, 0, "whirlwind on the %s: %s" % [GUARDIAN, whirled])

	# A full tree starves no action: at level 30 with all fifteen nodes, deep in Mossy Hollow.
	var sim: Simulation = _full_party()
	assert_not_null(sim, "the full party")
	if sim == null:
		return
	assert_eq(sim.expedition.depth, FULL_STAGE, "at stage %d" % FULL_STAGE)
	var taken: Dictionary[String, int] = {}
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.talents().size(), 15, "%s holds all fifteen" % hero.class_id)
		for node: StringName in hero.talents():
			taken["%d %s" % [hero.id, node]] = 0
	var uses: Dictionary[String, int] = {}
	var ticks: int = FULL_MINUTES * 60 * Simulation.TICKS_PER_SECOND
	_play_and_count(sim, ticks, -1, taken, uses)
	var unseen: PackedStringArray = _unseen_of("the full party", ticks, taken, uses)
	assert_eq(unseen, PackedStringArray(), "seen with every node:\n" + "\n".join(unseen))

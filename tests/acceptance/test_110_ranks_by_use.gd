extends "res://tests/acceptance/talent_tree_test_base.gd"
## Acceptance tests for specs/110-skill-paths-ranks-by-use/spec.md, one per requirement. R7 and
## R10 are tools/tests/godot/test_110_capstone_in_fair_time.py.

const SEED: int = 110
## The knight's paths, in order.
const GUARDIAN: int = 0
const BERSERKER: int = 1
const WARLORD: int = 2

## The knight's rank table while a test runs with a small one, put back after it.
var _kept_table: Array[int] = []


func after_each() -> void:
	if not _kept_table.is_empty():
		_tree(&"knight").rank_xp = _kept_table
		_kept_table = []
	super()


# --- Helpers -------------------------------------------------------------------


## A battle of [param sim]'s party, each hero's fighter as its hero makes it, against one monster.
func _party_battle(sim: Simulation) -> Battle:
	var heroes: Array[Combatant] = []
	for hero: Hero in sim.party.heroes:
		heroes.append(hero.combatant())
	var monsters: Array[Combatant] = [Combatant.from_monster(make_monster_def(), 1, 100)]
	return Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(SEED))


## [param hero]'s XP in each of its three paths.
func _xp(hero: Hero) -> Array[int]:
	var all: Array[int] = []
	for path: int in TalentTreeDef.PATH_COUNT:
		all.append(hero.ranks.xp(path))
	return all


## The total XP the knight's tree asks for rank [param rank] (1 or more).
func _xp_for(rank: int) -> int:
	return _tree(&"knight").rank_xp[rank - 1]


## Steps [param sim] until its next fight ends; returns the events from now to then, or an empty
## list when none ended within five minutes.
func _to_fight_end(sim: Simulation) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in ticks_in(300.0):
		sim.step()
		var got: Array[SimEvent] = sim.drain_events()
		events.append_array(got)
		if not _of_kind(got, SimEvent.Kind.ENCOUNTER_ENDED).is_empty():
			return events
	return [] as Array[SimEvent]


func _refused(tree: TalentTreeDef, words: String) -> bool:
	return "\n".join(tree.validate()).contains(words)


## A copy of the knight's tree, to break without harm.
func _knight_copy() -> TalentTreeDef:
	return _tree(&"knight").duplicate()


## True if the save [param data] is refused with a problem naming [param field] first.
func _refused_at(data: Dictionary, field: String) -> bool:
	for problem: String in Simulation.save_problems(data):
		if problem.begins_with(field + ":"):
			return true
	return false


# --- R1 ------------------------------------------------------------------------


func test_r1_path_xp_from_won_fights() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	var rogue: Hero = sim.party.heroes[1]
	raise(knight, 8)
	knight.set_talents([&"taunt", &"whirlwind", &"bloodthirst"] as Array[StringName])
	var uses_counted: int = _tree(&"knight").uses_counted
	assert_eq(uses_counted, 3, "three uses of one ability counted a fight")
	var fought: Battle = _party_battle(sim)
	var fighter: Combatant = fought.combatant(knight.id)
	fighter.uses[&"taunt"] = 5
	fighter.uses[&"whirlwind"] = 2
	fighter.uses[&"bloodthirst"] = 1
	fighter.health = 0  # it fell in the fight, and gains all the same
	fighter.state = Combatant.State.DEAD
	PathTraining.after_win(sim.expedition, fought)
	assert_eq(_xp(knight), [1 + 3, 2 + 2 + 1, 0] as Array[int], "nodes held plus uses, capped")
	assert_eq(_xp(rogue), [0, 0, 0] as Array[int], "a hero with no nodes gains nothing")

	# In play: a won fight counts each ABILITY_USED the knight was the source of.
	var played := Simulation.new(SEED)
	var held: Hero = played.party.heroes[0]
	raise(held, 4)
	held.set_talents([&"taunt"] as Array[StringName])
	var events: Array[SimEvent] = _to_fight_end(played)
	var ended: Array[SimEvent] = _of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)
	assert_eq(ended.size(), 1, "a fight ended")
	if ended.size() != 1:
		return
	assert_true(ended[0].flag, "and the heroes won it")
	var used: int = 0
	for e: SimEvent in _of_kind(events, SimEvent.Kind.ABILITY_USED, held.id):
		if e.ability_id == &"taunt":
			used += 1
	assert_gt(used, 0, "the knight taunted")
	assert_eq(_xp(held), [1 + mini(used, uses_counted), 0, 0] as Array[int], "one won fight")
	for hero: Hero in played.party.heroes.slice(1):
		assert_false(hero.ranks.any(), "%s took nothing, so gains nothing" % hero.class_id)

	# A lost fight gives nothing.
	var losing := Simulation.new(SEED)
	var loser: Hero = losing.party.heroes[0]
	raise(loser, 4)
	loser.set_talents([&"taunt"] as Array[StringName])
	assert_true(step_until(losing, func() -> bool: return losing.expedition.battle != null, 3000))
	for each: Combatant in losing.expedition.battle.heroes:
		each.health = 0
	events = _to_fight_end(losing)
	ended = _of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)
	assert_eq(ended.size(), 1, "the fight ended")
	if ended.size() == 1:
		assert_false(ended[0].flag, "lost")
	assert_false(loser.ranks.any(), "a lost fight gives no path XP")

	# A fight the expedition ends at its limit gives nothing.
	var held_on := Simulation.new(SEED)
	var cleric: Hero = held_on.party.heroes[3]
	raise(cleric, 4)
	cleric.set_talents([&"prayer"] as Array[StringName])
	for id: int in [1, 2, 3]:
		held_on.party.hero(id).health = 0
	assert_true(step_until(held_on, func() -> bool: return held_on.expedition.battle != null, 3000))
	var long: Battle = held_on.expedition.battle
	for monster: Combatant in long.monsters:  # it can neither win nor lose
		monster.max_health = 1_000_000
		monster.health = monster.max_health
		monster.damage = 1
	events = _to_fight_end(held_on)
	assert_eq(long.tick, ticks_in(Expedition.BATTLE_LIMIT_SECONDS), "ended at the limit")
	ended = _of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)
	assert_eq(ended.size(), 1, "the fight ended")
	assert_gt(_of_kind(events, SimEvent.Kind.ABILITY_USED, cleric.id).size(), 0, "she prayed")
	assert_false(cleric.ranks.any(), "a fight ended at the limit gives no path XP")


# --- R2 ------------------------------------------------------------------------


func test_r2_ranks() -> void:
	var tree: TalentTreeDef = _tree(&"knight")
	var table: Array[int] = tree.rank_xp
	assert_eq(tree.rank_at(0), 0, "no XP, rank 0")
	assert_eq(tree.rank_at(table[0] - 1), 0, "just short of the first")
	assert_eq(tree.rank_at(table[0]), 1, "the first threshold")
	assert_eq(tree.rank_at(table[1] - 1), 1)
	assert_eq(tree.rank_at(table[1]), 2)
	assert_eq(tree.rank_at(table[table.size() - 1]), table.size(), "the top rank")
	assert_eq(tree.rank_at(table[table.size() - 1] * 10), table.size(), "and none above it")
	var sim := Simulation.new(SEED)
	for hero: Hero in sim.party.heroes:
		for path: int in 3:
			assert_eq(hero.ranks.rank(path, _tree(hero.class_id)), 0, "every path at rank 0")

	# A small table, to pass ranks in few fights: a knight holding Taunt gains 1 + 3 a fight.
	_kept_table = tree.rank_xp
	tree.rank_xp = [2, 4, 6] as Array[int]
	var knight: Hero = sim.party.heroes[0]
	knight.set_talents([&"taunt"] as Array[StringName])
	var seen: Array[Array] = []
	for fight: int in 3:
		var fought: Battle = _party_battle(sim)
		fought.combatant(knight.id).uses[&"taunt"] = 3
		sim.expedition.drain_events()
		PathTraining.after_win(sim.expedition, fought)
		var ranked: Array = []
		for e: SimEvent in _of_kind(sim.expedition.drain_events(), SimEvent.Kind.PATH_RANKED):
			ranked.append([e.source_id, e.target_id, e.amount])
		seen.append(ranked)
	var ranks: int = knight.ranks.rank(GUARDIAN, tree)
	var xp: int = knight.ranks.xp(GUARDIAN)
	knight.reset_talents()
	var after_reset: int = knight.ranks.rank(GUARDIAN, tree)
	assert_eq(seen[0], [[knight.id, GUARDIAN, 1], [knight.id, GUARDIAN, 2]], "two ranks, in order")
	assert_eq(seen[1], [[knight.id, GUARDIAN, 3]], "then the third")
	assert_eq(seen[2], [], "none above the top")
	assert_eq(xp, 12, "XP past the top still counts")
	assert_eq(ranks, 3, "the top rank")
	assert_eq(after_reset, 3, "a rank never goes down")


# --- R3 ------------------------------------------------------------------------


func test_r3_deeper_tiers_need_a_rank() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 30)
	var tree: TalentTreeDef = _tree(&"knight")
	assert_eq(tree.tier_ranks, [0, 2, 5, 9] as Array[int], "the ranks each tier needs")
	var berserker: Array[StringName] = tree.path(BERSERKER).nodes
	sim.take_talent(knight.id, berserker[0])
	sim.step()
	sim.drain_events()
	assert_eq(knight.talents(), [berserker[0]] as Array[StringName], "tier 1 at rank 0")
	for place: int in [1, 3, 4]:
		var node: StringName = berserker[place]
		var needed: int = tree.tier_ranks[TalentTreeDef.TIERS[place] - 1]
		assert_eq(tree.rank_needed(node), needed, "%s needs rank %d" % [node, needed])
		knight.ranks.set_xp(BERSERKER, _xp_for(needed - 1))
		var before: Array[StringName] = knight.talents()
		assert_false(knight.can_take(node), "%s shut at rank %d" % [node, needed - 1])
		sim.take_talent(knight.id, node)
		sim.step()
		var events: Array[SimEvent] = sim.drain_events()
		assert_eq(knight.talents(), before, "%s refused" % node)
		for kind: SimEvent.Kind in [SimEvent.Kind.TALENT_TAKEN, SimEvent.Kind.PATH_RANKED]:
			assert_eq(_of_kind(events, kind).size(), 0, "a refusal sends no event")
		knight.ranks.set_xp(BERSERKER, _xp_for(needed))
		assert_true(knight.can_take(node), "%s open at rank %d" % [node, needed])
		sim.take_talent(knight.id, node)
		sim.step()
		events = sim.drain_events()
		assert_true(knight.talents().has(node), "%s taken at rank %d" % [node, needed])
		assert_eq(_of_kind(events, SimEvent.Kind.TALENT_TAKEN).size(), 1, "with its event")
	assert_eq(tree.rank_needed(&"no_such_node"), 0, "a node not in the tree needs no rank")
	# A node already held stays held, whatever happens.
	knight.ranks.set_xp(BERSERKER, 0)
	sim.step()
	assert_eq(knight.talents().size(), 4, "held at rank 0")
	var handed: Array[StringName] = []
	for ability: AbilityDef in knight.combatant().abilities:
		handed.append(ability.id)
	assert_true(handed.has(berserker[4]), "and fought with")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_data_check() -> void:
	var bad: TalentTreeDef = _knight_copy()
	bad.rank_xp = [] as Array[int]
	assert_true(_refused(bad, "rank_xp is empty"), "no ranks: %s" % bad.validate())
	bad = _knight_copy()
	bad.rank_xp = [10, 25, 25, 90] as Array[int]
	assert_true(_refused(bad, "rank_xp[2]: 25 is not above 25"), "flat: %s" % bad.validate())
	bad = _knight_copy()
	bad.rank_xp = [10, 25, 20, 90] as Array[int]
	assert_true(_refused(bad, "rank_xp[2]"), "falling: %s" % bad.validate())
	bad = _knight_copy()
	bad.rank_xp = [0, 25, 50, 90, 150, 240, 350, 490, 650, 850] as Array[int]
	assert_true(_refused(bad, "rank_xp[0]: 0 is not above 0"), "first at 0: %s" % bad.validate())
	bad = _knight_copy()
	bad.tier_ranks = [0, 2, 5] as Array[int]
	assert_true(_refused(bad, "tier_ranks has 3 entries, not 4"), "three: %s" % bad.validate())
	bad = _knight_copy()
	bad.tier_ranks = [1, 2, 5, 9] as Array[int]
	assert_true(_refused(bad, "tier_ranks[0]"), "tier 1 shut: %s" % bad.validate())
	bad = _knight_copy()
	bad.tier_ranks = [0, 5, 2, 9] as Array[int]
	assert_true(_refused(bad, "tier_ranks[2]: 2 is below 5"), "falling: %s" % bad.validate())
	bad = _knight_copy()
	bad.tier_ranks = [0, 2, 5, 11] as Array[int]
	assert_true(_refused(bad, "tier_ranks[3]: rank 11"), "past the top: %s" % bad.validate())
	bad = _knight_copy()
	bad.uses_counted = -1
	assert_true(_refused(bad, "uses_counted: -1 is below 0"), "negative: %s" % bad.validate())
	bad = _knight_copy()
	bad.uses_counted = 0
	assert_false(_refused(bad, "uses_counted"), "0 uses counted is allowed")

	var first: TalentTreeDef = _tree(CLASSES[0])
	for class_id: StringName in CLASSES:
		var tree: TalentTreeDef = _tree(class_id)
		assert_eq(tree.validate(), PackedStringArray(), "%s's tree passes" % class_id)
		assert_eq(tree.rank_xp.size(), 10, "%s: ten ranks" % class_id)
		assert_eq(tree.rank_xp, first.rank_xp, "%s: the same table as every tree" % class_id)
		assert_eq(tree.tier_ranks, [0, 2, 5, 9] as Array[int], "%s's tier ranks" % class_id)
		assert_eq(tree.uses_counted, 3, "%s's uses counted" % class_id)


# --- R5 ------------------------------------------------------------------------


func test_r5_reset_keeps_ranks() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 33)
	knight.set_talents(_tree(&"knight").path(GUARDIAN).nodes)
	knight.ranks.set_xp(GUARDIAN, _xp_for(9) + 4)
	knight.ranks.set_xp(WARLORD, _xp_for(2))
	knight.set_paragon_rank(TrainingDef.Stat.POWER, 2)
	sim.party.gold = 100_000
	var ranks_before: Array[int] = []
	for path: int in 3:
		ranks_before.append(knight.ranks.rank(path, _tree(&"knight")))
	var xp_before: Array[int] = _xp(knight)
	sim.reset_talents(knight.id)
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	assert_eq(_of_kind(events, SimEvent.Kind.TALENTS_RESET).size(), 1, "the reset happened")
	assert_eq(knight.talents(), [] as Array[StringName], "every node given back")
	assert_eq(knight.talent_points(), Hero.TALENT_POINTS, "every point back")
	assert_eq(_xp(knight), xp_before, "every path keeps its XP")
	var ranks_after: Array[int] = []
	for path: int in 3:
		ranks_after.append(knight.ranks.rank(path, _tree(&"knight")))
	assert_eq(ranks_after, ranks_before, "and its rank")
	assert_eq(ranks_after, [9, 0, 2] as Array[int])
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 2, "paragon stays")
	assert_true(knight.can_take(_tree(&"knight").path(GUARDIAN).nodes[0]), "free to re-pick")


# --- R6 ------------------------------------------------------------------------


func test_r6_saves() -> void:
	assert_eq(Simulation.SAVE_VERSION, 11)
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 18)
	var guardian: Array[StringName] = _tree(&"knight").path(GUARDIAN).nodes
	knight.ranks.set_xp(GUARDIAN, _xp_for(5) + 3)
	knight.ranks.set_xp(BERSERKER, 2)
	for place: int in 4:
		sim.take_talent(knight.id, guardian[place])
	sim.step()
	assert_eq(knight.talents().size(), 4, "four Guardian nodes taken")
	var data: Dictionary = sim.to_save()
	var version: int = data["version"]
	assert_eq(version, 11, "saved at version 11")
	var saved_heroes: Array = data["heroes"]
	var knight_paths: Array = saved_heroes[0]["paths"]
	var rogue_paths: Array = saved_heroes[1]["paths"]
	assert_eq(knight_paths, [_xp_for(5) + 3, 2, 0], "the knight's path XP")
	assert_eq(rogue_paths, [0, 0, 0], "the rogue's")
	var back: Simulation = Simulation.from_save(_through_json(data))
	assert_not_null(back, "loads: %s" % Simulation.save_problems(_through_json(data)))
	if back == null:
		return
	assert_eq(_xp(back.party.heroes[0]), [_xp_for(5) + 3, 2, 0] as Array[int], "a round trip")
	assert_eq(back.party.heroes[0].talents(), knight.talents(), "with its nodes")
	var resaved: Array = back.to_save()["heroes"]
	assert_eq(resaved, saved_heroes, "the same again")

	# A version 10 save with deep nodes loads bare, every path at 0; version 9 the same.
	for old_version: int in [10, 9]:
		var old: Dictionary = data.duplicate(true)
		old["version"] = old_version
		for saved: Dictionary in old["heroes"]:
			saved.erase("paths")
		old["heroes"][0]["talents"] = ["taunt", "hold_the_line", "bottle_top_block", "bulwark"]
		old["heroes"][0]["used"] = ["taunt"]
		var loaded: Simulation = Simulation.from_save(_through_json(old))
		var why: PackedStringArray = Simulation.save_problems(old)
		assert_not_null(loaded, "version %d loads: %s" % [old_version, why])
		if loaded == null:
			continue
		for hero: Hero in loaded.party.heroes:
			assert_eq(hero.talents(), [] as Array[StringName], "v%d: no nodes" % old_version)
			assert_eq(hero.used, [] as Array[StringName], "v%d: nothing used" % old_version)
			assert_eq(_xp(hero), [0, 0, 0] as Array[int], "v%d: every path at 0" % old_version)
		assert_eq(loaded.party.heroes[0].talent_points(), 9, "v%d: points back" % old_version)

	# Each bad value is refused by name.
	var cases: Array = [
		["heroes[2].paths", 2, null],
		["heroes[2].paths", 2, [1, 2]],
		["heroes[2].paths", 2, "lots"],
		["heroes[2].paths", 2, [1, -1, 0]],
		["heroes[2].paths", 2, [1, 2.5, 0]],
		["heroes[2].paths", 2, [1, "two", 0]],
	]
	for case: Array in cases:
		var bad: Dictionary = data.duplicate(true)
		if case[2] == null:
			(bad["heroes"][case[1]] as Dictionary).erase("paths")
		else:
			bad["heroes"][case[1]]["paths"] = case[2]
		var field: String = case[0]
		var found: PackedStringArray = Simulation.save_problems(bad)
		assert_true(_refused_at(bad, field), "%s refused as %s: %s" % [case[2], field, found])
		assert_null(Simulation.from_save(bad))
	# A node held whose tier needs a higher rank than its path's saved XP gives: Bulwark needs 5.
	var shut: Dictionary = data.duplicate(true)
	shut["heroes"][0]["paths"] = [_xp_for(2), 0, 0]
	var problems: PackedStringArray = Simulation.save_problems(shut)
	assert_true(_refused_at(shut, "heroes[0].talents[3]"), "above its rank: %s" % problems)
	assert_eq(problems.size(), 1, "and only that node: %s" % problems)
	assert_null(Simulation.from_save(shut))


# --- R8 ------------------------------------------------------------------------


func test_r8_deterministic_and_hash_kept() -> void:
	var runs: Array[Simulation] = []
	for i: int in 2:
		var sim := Simulation.new(SEED)
		for tick: int in ticks_in(8 * 60.0):
			TalentSpender.spend(sim)
			sim.step()
			sim.drain_events()
		runs.append(sim)
	assert_eq(runs[0].state_hash(), runs[1].state_hash(), "two spending runs agree")
	var earned: bool = false
	for hero: Hero in runs[0].party.heroes:
		earned = earned or hero.ranks.any()
	assert_true(earned, "the run earned path XP")
	var held: Array = []
	for hero: Hero in runs[1].party.heroes:
		held.append(_xp(hero))
	var first: Array = []
	for hero: Hero in runs[0].party.heroes:
		first.append(_xp(hero))
	assert_eq(first, held, "the same path XP")

	# A hero with no path XP hashes as before; XP above 0 changes the hash.
	var fresh := Simulation.new(SEED)
	var knight: Hero = fresh.party.heroes[0]
	var bare: int = fresh.state_hash()
	var parts: Array = fresh.party.hash_parts()
	assert_eq((parts[1] as Array).size(), 5, "a bare hero's parts: id, class, level, XP, health")
	knight.ranks.set_xp(BERSERKER, 3)
	assert_ne(fresh.state_hash(), bare, "path XP is in the hash")
	knight.ranks.set_xp(BERSERKER, 0)
	assert_eq(fresh.state_hash(), bare, "with none, the hash as before")


# --- R9 ------------------------------------------------------------------------


func test_r9_the_tab_says_why() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 8)
	knight.set_talents([&"taunt", &"hold_the_line"] as Array[StringName])
	knight.ranks.set_xp(GUARDIAN, _xp_for(2))
	knight.ranks.set_xp(BERSERKER, _xp_for(1))
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	main.hud.advance(STEP)
	var banners: Array[String] = []
	for banner: PathBanner in view.banners:
		banners.append(banner.rank_label.text)
		assert_true(banner.rank_label.is_visible_in_tree(), "the rank shows")
		var name_rect: Rect2 = _text_rect(banner.name_label)
		var rank_rect: Rect2 = _text_rect(banner.rank_label)
		assert_false(name_rect.intersects(rank_rect), "the rank clear of the name")
		assert_true(banner.get_global_rect().encloses(rank_rect), "inside the banner")
	assert_eq(banners, ["Rank 2", "Rank 1", "Rank 0"] as Array[String], "each path's rank")

	# Bulwark: Hold the Line is taken, but Guardian is at rank 2 and tier 3 needs 5.
	assert_true(knight.talent_points() > 0, "a point to spend")
	assert_eq(view.state_of(&"bulwark"), TalentNode.State.LOCKED, "drawn locked")
	assert_eq(view.state_of(&"bottle_top_block"), TalentNode.State.AVAILABLE, "its neighbour open")
	assert_eq(view.state_of(&"bloodthirst"), TalentNode.State.LOCKED, "Whirlwind not taken")
	var slot: UiIcon = view.node(&"bulwark").slot
	_point(main, slot)
	main.hud.advance(STEP)
	assert_eq(main.ui.tip.card_stand.text, "Rank 5 in Guardian opens this", "the card says why")
	assert_eq(shown.talents.strip.ability_id, &"bulwark", "the strip shows it")
	assert_eq(shown.talents.strip.stand_label.text, "Rank 5 in Guardian opens this", "the strip")
	assert_false(shown.talents.strip.learn_button.visible, "with no Learn button")
	_point_away(main)
	assert_eq(_stands(main, view, &"bloodthirst"), "Take Whirlwind first", "the way first")

	# A click takes nothing.
	var before: Array[StringName] = knight.talents()
	_click(main, slot)
	_frame(main)
	_frame(main)
	assert_eq(knight.talents(), before, "a click takes nothing")

	# The rank rises: the node opens, and the banner says so.
	knight.ranks.set_xp(GUARDIAN, _xp_for(5))
	_frame(main)
	assert_eq(view.banners[GUARDIAN].rank_label.text, "Rank 5", "the banner's new rank")
	assert_eq(view.state_of(&"bulwark"), TalentNode.State.AVAILABLE, "open now")
	_click(main, view.node(&"bulwark").slot)
	_frame(main)
	assert_true(knight.talents().has(&"bulwark"), "and a click takes it")

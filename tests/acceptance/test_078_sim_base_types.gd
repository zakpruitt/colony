extends ColonyTest
## Acceptance tests for specs/078-sim-base-types-and-headroom/spec.md. R1 is the unedited suite
## and the `dev.py sim` runs; R5 is for the reviewer.

const ARCHITECTURE: String = "res://docs/architecture.md"
const EXPEDITION: String = "res://sim/expedition/expedition.gd"
## R3: how many fights are watched, and for how many ticks each at most.
const FIGHTS: int = 200
const FIGHT_TICKS: int = 120
## R2: the place of the talent trees, found by their class, in [method _kinds].
const TALENTS_ROW: int = 8
## R4: Expedition's public methods today.
const EXPEDITION_METHODS: Array[String] = [
	"step",
	"command_target_depth",
	"command_pace",
	"command_guardian_order",
	"level_at",
	"is_holding",
	"drain_events",
	"chamber",
	"hero_position",
	"is_populated",
	"monsters_in",
	"monster_id",
	"guardian_of",
	"seconds_to_stable",
	"revival_place",
	"seconds_to_push",
	"side_quest_in",
	"working_quest",
	"worker_id",
	"work_progress",
	"hash_parts",
]

# --- Helpers -------------------------------------------------------------------


## Each kind Content keeps: its ids, and the definition it gives for one of them.
func _kinds() -> Array[Array]:
	return [
		[Content.hero_class_ids(), Content.hero_class],
		[Content.monster_ids(), Content.monster],
		[Content.upgrade_ids(), Content.upgrade],
		[Content.training_ids(), Content.training],
		[Content.microskill_ids(), Content.microskill],
		[Content.side_quest_ids(), Content.side_quest],
		[Content.area_ids(), Content.area],
		[Content.ability_ids(), Content.ability],
		[Content.hero_class_ids(), Content.talent_tree],
		[Content.resource_ids(), Content.resource_def],
	]


## A copy of the first definition [param getter] gives from [param ids], changed by
## [param change].
func _broken(ids: Array[StringName], getter: Callable, change: Callable) -> Resource:
	var def: Resource = (getter.call(ids[0]) as Resource).duplicate(true)
	change.call(def)
	return def


## A fight of one to four heroes of any class, at any level and with any abilities, against one to
## five monsters of any kind and level, some of them standing on the same spot.
func _mixed_fight(rng: SimRng) -> Battle:
	var heroes: Array[Combatant] = []
	var classes: Array[StringName] = Content.hero_class_ids()
	var abilities: Array[StringName] = Content.ability_ids()
	for i: int in rng.next_int(1, 4):
		var def: HeroClassDef = Content.hero_class(classes[rng.next_int(0, classes.size() - 1)])
		var hero: Combatant = Combatant.from_hero(def, rng.next_int(1, 20), i + 1)
		for n: int in rng.next_int(0, 3):
			hero.abilities.append(Content.ability(abilities[rng.next_int(0, abilities.size() - 1)]))
		heroes.append(hero)
	var monsters: Array[Combatant] = []
	var kinds: Array[StringName] = Content.monster_ids()
	for i: int in rng.next_int(1, 5):
		var def: MonsterDef = Content.monster(kinds[rng.next_int(0, kinds.size() - 1)])
		monsters.append(Combatant.from_monster(def, rng.next_int(1, 10), 100 + i))
	var battle := Battle.new(heroes, monsters, 2.0, 14.0, rng.chance(0.5), rng.fork("battle"))
	# Ties: two monsters on one spot, so two enemies are as near and as far as each other.
	if monsters.size() > 2 and rng.chance(0.5):
		monsters[2].x = monsters[0].x
	return battle


## Puts taunts and untouchability on and off at random, now and then on a whole side at once.
func _shake_statuses(battle: Battle, rng: SimRng) -> void:
	var everyone: Array[Combatant] = battle.heroes + battle.monsters
	var whole_side: bool = battle.tick % 50 == 10
	var side: Array[Combatant] = battle.monsters if rng.chance(0.5) else battle.heroes
	for c: Combatant in everyone:
		for kind: AbilityEffect.Status in [
			AbilityEffect.Status.UNTOUCHABLE, AbilityEffect.Status.TAUNTING
		]:
			var put_on: bool = rng.chance(0.06)
			if whole_side and kind == AbilityEffect.Status.UNTOUCHABLE and side.has(c):
				put_on = true
			if put_on:
				c.statuses[kind] = CombatStatus.new(kind, c.id, &"probe", 1.0, battle.tick, 15)
			elif rng.chance(0.04):
				c.statuses.erase(kind)
		# Some wounds, so shares of health differ and sometimes match.
		if c.is_alive() and rng.chance(0.05):
			c.health = maxi(1, c.health - c.max_health / 4)


## The living enemies [param c] may aim at: those that are not untouchable, or if every one of
## them is, all of them.
func _aimable(battle: Battle, c: Combatant) -> Array[Combatant]:
	var open: Array[Combatant] = []
	var shut: Array[Combatant] = []
	var enemies: Array[Combatant] = battle.monsters
	if c.team == Combatant.Team.MONSTERS:
		enemies = battle.heroes
	for enemy: Combatant in enemies:
		if enemy.is_alive():
			if enemy.has_status(AbilityEffect.Status.UNTOUCHABLE):
				shut.append(enemy)
			else:
				open.append(enemy)
	return shut if open.is_empty() else open


## The nearest taunting enemy [param c] can reach, else the nearest it may aim at.
func _nearest(battle: Battle, c: Combatant) -> Combatant:
	var allies: Array[Combatant] = battle.heroes
	var enemies: Array[Combatant] = battle.monsters
	if c.team == Combatant.Team.MONSTERS:
		allies = battle.monsters
		enemies = battle.heroes
	var reach: float = c.attack_range + Battle.MIN_SPACING * (allies.size() - 1) + Battle.EPSILON
	var found: Combatant = null
	var best: float = INF
	for enemy: Combatant in enemies:
		if not enemy.is_alive() or not enemy.has_status(AbilityEffect.Status.TAUNTING):
			continue
		var distance: float = absf(enemy.x - c.x)
		if distance <= reach and distance < best:
			found = enemy
			best = distance
	if found != null:
		return found
	best = INF
	for enemy: Combatant in _aimable(battle, c):
		if absf(enemy.x - c.x) < best:
			found = enemy
			best = absf(enemy.x - c.x)
	return found


func _weakest(battle: Battle, c: Combatant) -> Combatant:
	var weakest: Combatant = null
	for enemy: Combatant in _aimable(battle, c):
		if weakest == null or enemy.health_fraction() < weakest.health_fraction():
			weakest = enemy
	return weakest


func _furthest(battle: Battle, c: Combatant) -> Combatant:
	var furthest: Combatant = null
	var best: float = -1.0
	for enemy: Combatant in _aimable(battle, c):
		if absf(enemy.x - c.x) > best:
			furthest = enemy
			best = absf(enemy.x - c.x)
	return furthest


## An action aimed at [param aim], for asking whom it would aim at.
func _probe(aim: AbilityDef.Aim) -> AbilityDef:
	var probe := AbilityDef.new()
	probe.id = &"probe_aim"
	probe.aim = aim
	return probe


func _who(c: Combatant) -> String:
	return "nobody" if c == null else str(c.id)


# --- Requirements --------------------------------------------------------------


func test_r2_every_definition_is_a_content_def() -> void:
	for row: Dictionary in Content.KINDS:
		assert_false(row.has("key"), "the %s row has no key column" % row["folder"])
	var kinds: Array[Array] = _kinds()
	for k: int in kinds.size():
		var ids: Array[StringName] = kinds[k][0]
		var getter: Callable = kinds[k][1]
		assert_false(ids.is_empty(), "a kind with definitions")
		for id: StringName in ids:
			var def: Resource = getter.call(id)
			assert_true(def is ContentDef, "%s is a ContentDef" % id)
			if def is ContentDef:
				assert_ne((def as ContentDef).key(), &"", "%s has a key" % id)
				assert_eq((def as ContentDef).key(), id, "%s is found by its key" % id)
			if k == TALENTS_ROW:
				assert_eq((def as TalentTreeDef).class_id, id, "a tree's key is its class")
			else:
				assert_eq(def.get(&"id") as StringName, id, "%s's key is its id" % id)


func test_r2_data_reports_what_it_did() -> void:
	var breaks: Array = [
		[func(d: HeroClassDef) -> void: d.max_health = 0, ["max_health 0 is below 1"]],
		[func(d: MonsterDef) -> void: d.base_level = 0, ["base_level 0 is below 1"]],
		[func(d: UpgradeDef) -> void: d.max_rank = 0, ["max_rank 0 is below 1"]],
		[func(d: TrainingDef) -> void: d.per_rank = -0.5, ["per_rank -0.5 is not above 0"]],
		[func(d: MicroskillDef) -> void: d.description = "", ["description is empty"]],
		[
			func(d: SideQuestDef) -> void: d.microskill = &"juggling",
			["microskill juggling does not exist"]
		],
		[func(d: AreaDef) -> void: d.order = 0, ["order 0 is below 1"]],
		[func(d: AbilityDef) -> void: d.move = &"", ["move is empty"]],
		[func(d: TalentTreeDef) -> void: d.class_id = &"", ["class_id is empty"]],
		[func(d: ResourceDef) -> void: d.plural = "", ["plural is empty"]],
	]
	var kinds: Array[Array] = _kinds()
	assert_eq(breaks.size(), kinds.size(), "one break a kind")
	for i: int in kinds.size():
		var ids: Array[StringName] = kinds[i][0]
		var getter: Callable = kinds[i][1]
		var sound: Resource = getter.call(ids[0])
		var sound_problems: PackedStringArray = sound.call(&"validate")
		assert_eq(sound_problems, PackedStringArray(), "%s is sound" % ids[0])
		var change: Callable = breaks[i][0]
		var broken: Resource = _broken(ids, getter, change)
		var problems: PackedStringArray = broken.call(&"validate")
		var expected: Array = breaks[i][1]
		assert_eq(problems, PackedStringArray(expected), "%s broken" % ids[0])


func test_r3_targets_are_chosen_as_before() -> void:
	var rng := SimRng.new(78)
	var weakest: AbilityDef = _probe(AbilityDef.Aim.WEAKEST_ENEMY)
	var furthest: AbilityDef = _probe(AbilityDef.Aim.FURTHEST_ENEMY)
	var asked: int = 0
	var wrong: PackedStringArray = []
	for fight: int in FIGHTS:
		var battle: Battle = _mixed_fight(rng.fork("fight/%d" % fight))
		var shaker: SimRng = rng.fork("shake/%d" % fight)
		for t: int in FIGHT_TICKS:
			if battle.result() != Battle.Result.ONGOING:
				break
			_shake_statuses(battle, shaker)
			for c: Combatant in battle.heroes + battle.monsters:
				if not c.is_alive():
					continue
				asked += 1
				var picks: Array[Combatant] = [
					battle.nearest_enemy(c),
					BattleAbilities.aim(battle, c, weakest),
					BattleAbilities.aim(battle, c, furthest),
				]
				var expected: Array[Combatant] = [
					_nearest(battle, c), _weakest(battle, c), _furthest(battle, c)
				]
				for p: int in picks.size():
					if picks[p] != expected[p] and wrong.size() < 5:
						wrong.append(
							(
								"fight %d tick %d fighter %d aim %d: %s, not %s"
								% [fight, battle.tick, c.id, p, _who(picks[p]), _who(expected[p])]
							)
						)
			battle.step()
	assert_gt(asked, FIGHTS * 50, "many choices were made")
	assert_eq(wrong, PackedStringArray(), "every choice as before")


func test_r3_nothing_joins_the_sides_on_the_tick() -> void:
	var scripts: Dictionary[String, String] = {}
	scripts_in("res://sim/combat", scripts)
	assert_gt(scripts.size(), 0, "the combat scripts")
	var joins: PackedStringArray = []
	for path: String in scripts:
		for line: String in scripts[path].split("\n"):
			if line.contains("heroes + ") or line.contains("+ monsters"):
				joins.append("%s: %s" % [path.get_file(), line.strip_edges()])
	assert_eq(joins, PackedStringArray(["battle.gd: _fighters = heroes + monsters"]), "one join")


func test_r4_expedition_has_room() -> void:
	var text: String = FileAccess.get_file_as_string(EXPEDITION)
	assert_lte(text.count("\n"), 900, "expedition.gd is at most 900 lines")
	var public := RegEx.create_from_string("(?m)^(?:static )?func ([a-z]\\w*)")
	var found: Array[String] = []
	for m: RegExMatch in public.search_all(text):
		found.append(m.get_string(1))
	var expected: Array[String] = EXPEDITION_METHODS.duplicate()
	found.sort()
	expected.sort()
	assert_eq(found, expected, "Expedition's public methods are today's")


func test_r6_no_private_constant_is_documented() -> void:
	var scripts: Dictionary[String, String] = {}
	scripts_in("res://sim", scripts)
	var class_names := RegEx.create_from_string("(?m)^class_name (\\w+)")
	var sim_classes: Dictionary[String, String] = {}
	for path: String in scripts:
		var named: RegExMatch = class_names.search(scripts[path])
		if named != null:
			sim_classes[named.get_string(1)] = path
	assert_true(sim_classes.has("Expedition"), "the sim's classes are found")
	var doc: String = FileAccess.get_file_as_string(ARCHITECTURE)
	# A name written with its underscore is caught too, and fails as private.
	var named_constant := RegEx.create_from_string(
		"\\b([A-Z][A-Za-z0-9]*)\\.(_?[A-Z][A-Z0-9_]*)\\b"
	)
	var checked: int = 0
	var missing: PackedStringArray = []
	for m: RegExMatch in named_constant.search_all(doc):
		var named_class: String = m.get_string(1)
		if not sim_classes.has(named_class):
			continue
		checked += 1
		var script: Script = load(sim_classes[named_class])
		var constant: String = m.get_string(2)
		if constant.begins_with("_") or not script.get_script_constant_map().has(constant):
			missing.append(m.get_string())
	assert_gt(checked, 5, "the document names the sim's constants")
	assert_eq(missing, PackedStringArray(), "every constant named is public")

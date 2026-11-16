extends GutTest
## Spec 013, monsters of the deeper bands: eight new monsters as data and sprites, met in
## the bands they live in, hard but fair at depth 12, and shown in the cast demo.

## The eight new monsters: first depth and size, as R1's table gives them.
const NEW_MONSTERS: Dictionary[StringName, Array] = {
	&"goblin": [4, MonsterDef.Size.SMALL],
	&"mud_golem": [6, MonsterDef.Size.LARGE],
	&"fire_imp": [7, MonsterDef.Size.SMALL],
	&"clay_hound": [8, MonsterDef.Size.SMALL],
	&"ghoul": [11, MonsterDef.Size.SMALL],
	&"crystal_beetle": [12, MonsterDef.Size.SMALL],
	&"wraith": [13, MonsterDef.Size.SMALL],
	&"deep_horror": [16, MonsterDef.Size.LARGE],
}
const OLD_MONSTERS: Array[StringName] = [&"slime", &"cave_bat", &"skeleton", &"spider", &"ogre"]
const RANGED: Array[StringName] = [&"fire_imp", &"wraith"]
const MONSTERS_DIR: String = "res://assets/sprites/monsters"
const DEMO: String = "res://game/entities/character_demo.tscn"
## Levels per depth band (loam 1-5, clay 6-10, stone 11-15, deep 16-20).
const BAND_LEVELS: int = 5
const STEP: float = 1.0 / 60.0
## R6: the stone-band fight.
const FIGHT_DEPTH: int = 12
const FIGHT_MONSTERS: int = 3
const FIGHT_SEEDS: int = 200
const STRONG_LEVEL: int = 12
const WEAK_LEVEL: int = 6
## A typical chamber floor, in tiles.
const FLOOR_LEFT: float = 0.0
const FLOOR_RIGHT: float = 17.0


func _band(depth: int) -> int:
	return (depth - 1) / BAND_LEVELS


# --- R1 ------------------------------------------------------------------------


func test_r1_eight_new_monsters_are_valid() -> void:
	for id: StringName in NEW_MONSTERS:
		var def: MonsterDef = Content.monster(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate(), PackedStringArray(), "%s validates clean" % id)
		assert_eq(def.id, id)
		var first: int = NEW_MONSTERS[id][0]
		var size: MonsterDef.Size = NEW_MONSTERS[id][1]
		assert_eq(def.min_depth, first, "%s's first depth" % id)
		assert_eq(def.size, size, "%s's size" % id)
		assert_ne(def.display_name, "", "%s has a name" % id)
	for id: StringName in NEW_MONSTERS:
		var def: MonsterDef = Content.monster(id)
		if def != null:
			assert_eq(
				def.attack_range > Battle.MELEE_REACH,
				RANGED.has(id),
				"%s is ranged only if the table says so" % id
			)

	# Thirteen monsters, and deeper ones are worth at least as much.
	var ids: Array[StringName] = Content.monster_ids()
	assert_eq(ids.size(), OLD_MONSTERS.size() + NEW_MONSTERS.size(), "thirteen monsters")
	for deeper: StringName in ids:
		for shallower: StringName in ids:
			var a: MonsterDef = Content.monster(deeper)
			var b: MonsterDef = Content.monster(shallower)
			if a.min_depth <= b.min_depth:
				continue
			var pair: String = (
				"%s (depth %d) vs %s (depth %d)" % [deeper, a.min_depth, shallower, b.min_depth]
			)
			assert_gte(a.xp, b.xp, "xp does not decrease: " + pair)
			assert_gte(a.gold_min, b.gold_min, "gold_min does not decrease: " + pair)
			assert_gte(a.gold_max, b.gold_max, "gold_max does not decrease: " + pair)
	# Clearly more: the deepest is worth several times the first band's best.
	assert_gt(Content.monster(&"deep_horror").xp, 4 * Content.monster(&"ogre").xp)


# --- R2, R3 --------------------------------------------------------------------


func _part(character: CharacterSprite, part_name: String) -> Sprite2D:
	return character.find_child(part_name, true, false) as Sprite2D


## Every part's transform and offset, which together say where it is drawn.
func _pose(character: CharacterSprite, sheet: PixelSheet) -> Array:
	var pose: Array = []
	for part_name: String in sheet.part_names:
		var part: Sprite2D = _part(character, part_name)
		pose.append([part.transform, part.offset])
	var rig: Node2D = _part(character, "body").get_parent() as Node2D
	pose.append(rig.transform)
	return pose


func _run(character: CharacterSprite, seconds: float) -> void:
	for _frame: int in roundi(seconds / STEP):
		character.advance(STEP)


func test_r3_each_new_monster_builds_and_animates() -> void:
	for id: StringName in NEW_MONSTERS:
		var sheet: PixelSheet = PixelSheet.load_sheet("%s/%s.png" % [MONSTERS_DIR, id])
		assert_not_null(sheet, "%s has a baked sheet" % id)
		var character: CharacterSprite = CharacterSprite.for_monster(id)
		assert_not_null(character, "%s builds through for_monster" % id)
		if sheet == null or character == null:
			continue
		add_child_autofree(character)
		character.set_process(false)
		var size: MonsterDef.Size = NEW_MONSTERS[id][1]
		var large: bool = size == MonsterDef.Size.LARGE
		assert_eq(sheet.category, "monster_large" if large else "monster_small", "%s" % id)
		assert_has(sheet.part_names, "body", "%s has a body" % id)
		assert_gt(sheet.part_names.size(), 1, "%s has parts that move" % id)
		for part_name: String in sheet.part_names:
			assert_not_null(_part(character, part_name), "%s shows its %s" % [id, part_name])
		var rest: Array = _pose(character, sheet)

		var strikes: Array[bool] = []
		character.struck.connect(func() -> void: strikes.append(true))
		character.play_idle()
		_run(character, 1.0)
		character.play_walk()
		_run(character, 1.0)
		var walked: bool = _pose(character, sheet) != rest
		character.play_idle()
		_run(character, 0.5)
		var moved_in_attack: bool = false
		character.play_attack(0.4, RANGED.has(id))
		for _frame: int in roundi(0.45 / STEP):
			character.advance(STEP)
			moved_in_attack = moved_in_attack or _pose(character, sheet) != rest
		_run(character, 1.0)
		character.play_hit()
		_run(character, 1.0)
		assert_true(walked, "%s moves while walking" % id)
		assert_true(moved_in_attack, "%s moves while attacking" % id)
		assert_eq(strikes.size(), 1, "%s strikes once" % id)

		# Settle on a whole breath so idle motion is back where it began.
		var deaths: Array[bool] = []
		character.died.connect(func() -> void: deaths.append(true))
		character.play_death()
		_run(character, 0.5)
		assert_eq(deaths.size(), 1, "%s dies" % id)
		assert_false(character.visible, "%s is hidden once dead" % id)
		character.revive()
		assert_eq(_pose(character, sheet), rest, "%s's parts are back at rest" % id)
	assert_push_error_count(0)
	assert_engine_error_count(0)


# --- R4 ------------------------------------------------------------------------


## Every monster waiting in every chamber of [param depth] for seeds 1 to [param seeds].
func _met_at(depth: int, seeds: int) -> Array[MonsterDef]:
	var met: Array[MonsterDef] = []
	for seed_value: int in range(1, seeds + 1):
		var sim := Simulation.new(seed_value)
		for room: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
			for m: Combatant in sim.expedition.monsters_in(depth, room.index):
				met.append(Content.monster(m.def_id))
	return met


func test_r4_bands_have_their_own_inhabitants() -> void:
	# Never above first depth, and met from the first depth on.
	for depth: int in range(1, 21):
		var seen: Dictionary[StringName, bool] = {}
		for def: MonsterDef in _met_at(depth, 12):
			seen[def.id] = true
			assert_lte(def.min_depth, depth, "%s is not met above depth %d" % [def.id, depth])
		for id: StringName in NEW_MONSTERS:
			var first: int = NEW_MONSTERS[id][0]
			if depth == first or depth == first + 3:
				assert_true(seen.has(id), "%s turns up at depth %d" % [id, depth])

	# Each band is dominated by its own inhabitants and the band before.
	for depth: int in [8, 13, 18]:
		var met: Array[MonsterDef] = _met_at(depth, 40)
		var local: int = 0
		for def: MonsterDef in met:
			if _band(depth) - _band(def.min_depth) <= 1:
				local += 1
		assert_gt(met.size(), 100, "many encounters at depth %d" % depth)
		assert_gte(
			float(local) / met.size(),
			0.5,
			"depth %d: %d of %d from this band or the one before" % [depth, local, met.size()]
		)


# --- R6 ------------------------------------------------------------------------


## The share of [constant FIGHT_SEEDS] stone-band fights a party at [param level] wins in time.
func _win_rate(level: int) -> float:
	var weighted: Array[MonsterDef] = []
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if def.min_depth <= FIGHT_DEPTH:
			# As the expedition rolls them: each as likely as its first depth.
			for _copy: int in def.min_depth:
				weighted.append(def)
	var limit: int = Combatant.seconds_to_ticks(Expedition.BATTLE_LIMIT_SECONDS)
	var wins: int = 0
	for seed_value: int in range(1, FIGHT_SEEDS + 1):
		var rng := SimRng.new(seed_value)
		var heroes: Array[Combatant] = []
		var hero_id: int = 1
		for class_id: StringName in Party.STARTING_CLASSES:
			heroes.append(Combatant.from_hero(Content.hero_class(class_id), level, hero_id))
			hero_id += 1
		var monsters: Array[Combatant] = []
		for i: int in FIGHT_MONSTERS:
			var def: MonsterDef = weighted[rng.next_int(0, weighted.size() - 1)]
			monsters.append(Combatant.from_monster(def, FIGHT_DEPTH, 100 + i))
		var fight := Battle.new(heroes, monsters, FLOOR_LEFT, FLOOR_RIGHT, true, rng.fork("battle"))
		while fight.result() == Battle.Result.ONGOING and fight.tick < limit:
			fight.step()
			fight.drain_events()
		if fight.result() == Battle.Result.HEROES_WON:
			wins += 1
	return float(wins) / FIGHT_SEEDS


func test_r6_stone_band_is_hard_but_fair() -> void:
	var strong: float = _win_rate(STRONG_LEVEL)
	assert_between(strong, 0.5, 0.95, "level-12 party wins more often than not, not always")
	var weak: float = _win_rate(WEAK_LEVEL)
	assert_lte(weak, 0.2, "level-6 party loses at least 80% of the time")
	gut.p("stone-band win rates: level 12 %.2f, level 6 %.2f" % [strong, weak])


# --- R7 ------------------------------------------------------------------------


func test_r7_demo_shows_all_thirteen() -> void:
	var scene: PackedScene = load(DEMO)
	assert_not_null(scene, "the demo scene loads")
	if scene == null:
		return
	var demo: CharacterDemo = scene.instantiate()
	add_child_autofree(demo)
	await wait_process_frames(30)
	for _step: int in roundi(CharacterDemo.CYCLE_SECONDS * 1.5 / 0.05):
		demo.advance(0.05)
	var bodies: Array[Texture2D] = []
	for character: CharacterSprite in demo.characters():
		bodies.append(_part(character, "body").texture)
	for id: StringName in Content.monster_ids():
		var sheet: PixelSheet = PixelSheet.load_sheet("%s/%s.png" % [MONSTERS_DIR, id])
		assert_not_null(sheet, "%s has a sheet" % id)
		if sheet != null:
			assert_has(bodies, sheet.part(&"body"), "the demo shows the %s" % id)
	for id: StringName in Content.monster_ids():
		var name_shown: bool = false
		for label: Label in demo.find_children("*", "Label", true, false):
			name_shown = name_shown or label.text == String(id).replace("_", " ")
		assert_true(name_shown, "the demo names the %s" % id)
	assert_push_error_count(0)
	assert_engine_error_count(0)

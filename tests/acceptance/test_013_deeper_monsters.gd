extends ColonyTest
## Spec 013, monsters of the deeper bands: eight new monsters as data and sprites, shown in the
## cast demo. Where each is met is test_049_areas.gd's R3.

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
const STEP: float = 1.0 / 60.0

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
		assert_eq(def.base_level, first, "%s's base level (its first depth before spec 049)" % id)
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

	# Thirteen ordinary monsters (spec 020's guardians aside), and deeper ones are worth at
	# least as much.
	var ids: Array[StringName] = []
	for id: StringName in Content.monster_ids():
		if not Content.monster(id).guardian:
			ids.append(id)
	assert_eq(ids.size(), OLD_MONSTERS.size() + NEW_MONSTERS.size(), "thirteen monsters")
	for deeper: StringName in ids:
		for shallower: StringName in ids:
			var a: MonsterDef = Content.monster(deeper)
			var b: MonsterDef = Content.monster(shallower)
			if a.base_level <= b.base_level:
				continue
			var pair: String = (
				"%s (depth %d) vs %s (depth %d)" % [deeper, a.base_level, shallower, b.base_level]
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

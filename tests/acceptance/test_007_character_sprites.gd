extends GutTest
## Spec 007, character sprites: the nine characters and how CharacterSprite animates them.
## R2's baker and lint side is tested in tools/tests/test_007_part_pivots.py.

const HEROES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
const SMALL_MONSTERS: Array[StringName] = [&"slime", &"cave_bat", &"skeleton", &"spider"]
const HUMANOID_PARTS: PackedStringArray = ["body", "head", "arm", "weapon"]
const HEROES_DIR: String = "res://assets/sprites/heroes"
const MONSTERS_DIR: String = "res://assets/sprites/monsters"
const DEMO: String = "res://game/entities/character_demo.tscn"
## One frame at 60 frames a second: the step the tests drive animation with.
const STEP: float = 1.0 / 60.0


func _hero(id: StringName) -> CharacterSprite:
	return _keep(CharacterSprite.for_hero(id))


func _monster(id: StringName) -> CharacterSprite:
	return _keep(CharacterSprite.for_monster(id))


## Adds the character to the tree with its own _process off, so only the test moves time.
func _keep(character: CharacterSprite) -> CharacterSprite:
	assert_not_null(character, "the character is created")
	if character != null:
		add_child_autofree(character)
		character.set_process(false)
	return character


func _sheet_of(id: StringName) -> PixelSheet:
	var dir: String = HEROES_DIR if HEROES.has(id) else MONSTERS_DIR
	return PixelSheet.load_sheet("%s/%s.png" % [dir, id])


func _part(character: CharacterSprite, part_name: String) -> Sprite2D:
	return character.find_child(part_name, true, false) as Sprite2D


## A part's transform from its own space to the character node's space.
func _to_character(character: CharacterSprite, part: Node2D) -> Transform2D:
	return character.get_global_transform().affine_inverse() * part.get_global_transform()


## Where a part's texture pixel [param pixel] is drawn, in the character node's space.
func _drawn_at(character: CharacterSprite, part: Sprite2D, pixel: Vector2) -> Vector2:
	return _to_character(character, part) * (part.offset + pixel)


## Everything that shows where the character's parts are: their drawn placement and visibility.
func _pose(character: CharacterSprite, sheet: PixelSheet) -> Array:
	var pose: Array = []
	for part_name: String in sheet.part_names:
		var part: Sprite2D = _part(character, part_name)
		pose.append(_to_character(character, part).translated_local(part.offset))
		pose.append(part.is_visible_in_tree())
	return pose


## How high the character's head (or its body, if it has no head) is drawn.
func _height_signal(character: CharacterSprite, sheet: PixelSheet) -> float:
	var part_name: String = "head" if sheet.part_names.has("head") else "body"
	return _drawn_at(character, _part(character, part_name), Vector2.ZERO).y


## How far apart two poses are: the largest difference in any part's placement, in pixels.
func _distance(first: Array, second: Array) -> float:
	var largest: float = 0.0
	for index: int in first.size():
		if first[index] is bool:
			largest = maxf(largest, 0.0 if first[index] == second[index] else 100.0)
			continue
		var a: Transform2D = first[index]
		var b: Transform2D = second[index]
		for column: int in 3:
			largest = maxf(
				largest, (a[column] - b[column]).length() * (1.0 if column == 2 else 32.0)
			)
	return largest


## How many times a sampled signal changes direction.
func _reversals(samples: PackedFloat32Array) -> int:
	var count: int = 0
	var last_direction: float = 0.0
	for index: int in range(1, samples.size()):
		var change: float = samples[index] - samples[index - 1]
		if absf(change) < 0.001:
			continue
		var direction: float = signf(change)
		if last_direction != 0.0 and direction != last_direction:
			count += 1
		last_direction = direction
	return count


func _rest(sheet: PixelSheet, part_name: String) -> Transform2D:
	return Transform2D(0.0, Vector2(sheet.part_pivot(StringName(part_name)) - sheet.pivot))


func _flash(character: CharacterSprite) -> float:
	var rig: CanvasItem = _part(character, "body").get_parent() as CanvasItem
	var material: ShaderMaterial = rig.material as ShaderMaterial
	assert_not_null(material, "the parts share a flash material")
	if material == null:
		return -1.0
	var value: float = material.get_shader_parameter("flash")
	return value


func _run(character: CharacterSprite, seconds: float) -> void:
	for _frame: int in roundi(seconds / STEP):
		character.advance(STEP)


func test_r1_nine_sheets_exist_with_parts() -> void:
	var expected: Dictionary[StringName, String] = {
		&"knight": "hero",
		&"rogue": "hero",
		&"mage": "hero",
		&"cleric": "hero",
		&"slime": "monster_small",
		&"cave_bat": "monster_small",
		&"skeleton": "monster_small",
		&"spider": "monster_small",
		&"ogre": "monster_large",
	}
	var humanoids: Array = HEROES + [&"skeleton", &"ogre"]
	for id: StringName in expected:
		var character: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		var sheet: PixelSheet = _sheet_of(id)
		assert_not_null(sheet, "%s has a baked sheet" % id)
		if character == null or sheet == null:
			continue
		assert_eq(sheet.category, expected[id], "%s's category" % id)
		assert_has(sheet.part_names, "body", "%s has a body" % id)
		if humanoids.has(id):
			for part_name: String in HUMANOID_PARTS:
				assert_has(sheet.part_names, part_name, "%s is humanoid: has %s" % [id, part_name])
		for part_name: String in sheet.part_names:
			var part: Sprite2D = _part(character, part_name)
			assert_not_null(part, "%s shows its %s" % [id, part_name])
			if part != null:
				assert_eq(
					part.texture, sheet.part(StringName(part_name)), "%s %s" % [id, part_name]
				)
	assert_null(CharacterSprite.for_monster(&"no_such_monster"), "an unknown id gives null")
	assert_push_error("no_such_monster")


func test_r2_sheet_returns_part_pivots() -> void:
	var knight: PixelSheet = _sheet_of(&"knight")
	assert_eq(knight.part_pivot(&"arm"), Vector2i(18, 16), "a declared pivot")
	assert_eq(knight.part_pivot(&"body"), knight.pivot, "no declared pivot: the sprite's pivot")
	var slime: PixelSheet = _sheet_of(&"slime")
	assert_eq(slime.part_pivot(&"body"), Vector2i(12, 23))


func test_r3_composed_at_pivot() -> void:
	for id: StringName in HEROES + SMALL_MONSTERS + [&"ogre"]:
		var character: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		var sheet: PixelSheet = _sheet_of(id)
		if character == null:
			continue
		character.position = Vector2(40, 70)
		for part_name: String in sheet.part_names:
			var part: Sprite2D = _part(character, part_name)
			assert_not_null(part, "%s has its %s as a child" % [id, part_name])
			if part == null:
				continue
			# Composed as drawn: each part's canvas sits unmoved, so its top-left is at -pivot.
			assert_eq(
				_drawn_at(character, part, Vector2.ZERO),
				-Vector2(sheet.pivot),
				"%s %s sits where it is drawn" % [id, part_name]
			)
			# The sprite's pivot pixel is at the node's origin.
			assert_eq(
				_drawn_at(character, part, Vector2(sheet.pivot)),
				Vector2.ZERO,
				"%s %s: the pivot is at the origin" % [id, part_name]
			)


func test_r4_idle_breathes_out_of_step() -> void:
	for id: StringName in [&"knight", &"slime", &"cave_bat", &"spider"]:
		var sheet: PixelSheet = _sheet_of(id)
		var first: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		var second: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		first.play_idle()
		second.play_idle()
		first.advance(STEP)
		second.advance(STEP)
		var start: Array = _pose(first, sheet)
		var changed: bool = false
		var returned: bool = false
		var out_of_step: bool = false
		for _frame: int in roundi(3.0 / STEP):
			first.advance(STEP)
			second.advance(STEP)
			var now: Array = _pose(first, sheet)
			if _distance(now, start) > 0.5:
				changed = true
			elif changed and _distance(now, start) < 0.1:
				returned = true
			if _distance(now, _pose(second, sheet)) > 0.5:
				out_of_step = true
		assert_true(changed, "%s moves while idle" % id)
		assert_true(returned, "%s returns to where it started (a cycle, not a drift)" % id)
		assert_true(out_of_step, "two %ss created together do not breathe in step" % id)


func test_r5_walk_is_livelier_than_idle() -> void:
	var swinging: Dictionary[StringName, String] = {
		&"knight": "arm",
		&"skeleton": "weapon",
		&"spider": "legs",
		&"cave_bat": "wing",
	}
	for id: StringName in swinging:
		var sheet: PixelSheet = _sheet_of(id)
		var idle: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		var walking: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		idle.play_idle()
		walking.play_walk()
		var idle_heights: PackedFloat32Array = []
		var walk_heights: PackedFloat32Array = []
		var turned: bool = false
		for _frame: int in roundi(3.0 / STEP):
			idle.advance(STEP)
			walking.advance(STEP)
			idle_heights.append(_height_signal(idle, sheet))
			walk_heights.append(_height_signal(walking, sheet))
			if absf(_part(walking, swinging[id]).rotation) > 0.1:
				turned = true
		var idle_bobs: int = _reversals(idle_heights)
		var walk_bobs: int = _reversals(walk_heights)
		assert_gt(walk_bobs, idle_bobs * 2, "%s bobs faster walking than idle" % id)
		assert_true(turned, "%s swings its %s while walking" % [id, swinging[id]])
		assert_eq(_part(idle, swinging[id]).rotation, 0.0, "%s does not swing while idle" % id)


func test_r5_walk_leans_toward_facing() -> void:
	var knight: CharacterSprite = _hero(&"knight")
	var body: Sprite2D = _part(knight, "body")
	knight.play_walk()
	_run(knight, 0.5)
	# The top of the body's centre column is drawn over the pivot pixel when upright.
	var top: Vector2 = Vector2(16.5, 13.0)
	assert_gt(_drawn_at(knight, body, top).x, 0.5 + 0.5, "facing right, the walk leans right")
	knight.set_facing(-1)
	_run(knight, 0.5)
	assert_lt(_drawn_at(knight, body, top).x, 0.5 - 0.5, "facing left, it leans left")


func test_r6_facing_mirrors_in_place() -> void:
	for id: StringName in [&"knight", &"spider"]:
		var character: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		var sheet: PixelSheet = _sheet_of(id)
		character.position = Vector2(120, 80)
		var body: Sprite2D = _part(character, "body")
		var pivot_centre: Vector2 = Vector2(sheet.pivot) + Vector2(0.5, 0.5)
		var right_edge: Vector2 = _drawn_at(character, body, Vector2(sheet.size.x, 0))

		character.set_facing(-1)
		assert_eq(character.position, Vector2(120, 80), "%s does not move" % id)
		assert_lt(_to_character(character, body).x.x, 0.0, "%s is mirrored" % id)
		assert_eq(
			_drawn_at(character, body, pivot_centre),
			Vector2(0.5, 0.5),
			"%s's pivot pixel stays in place" % id
		)
		var mirrored_edge: Vector2 = _drawn_at(character, body, Vector2(sheet.size.x, 0))
		assert_eq(mirrored_edge.x, 1.0 - right_edge.x, "%s mirrors about the pivot pixel" % id)

		character.set_facing(1)
		assert_gt(_to_character(character, body).x.x, 0.0, "%s faces right again" % id)
		assert_eq(_drawn_at(character, body, pivot_centre), Vector2(0.5, 0.5))


func test_r7_attack_has_windup_then_strike() -> void:
	for ranged: bool in [false, true]:
		var knight: CharacterSprite = _hero(&"knight")
		var weapon: Sprite2D = _part(knight, "weapon")
		var strikes: Array[float] = []
		var elapsed: Array[float] = [0.0]
		knight.struck.connect(func() -> void: strikes.append(elapsed[0]))
		knight.play_attack(0.5, ranged)
		var drew_back: bool = false
		var passed_rest: bool = false
		while elapsed[0] < 1.5:
			elapsed[0] += STEP
			knight.advance(STEP)
			if strikes.is_empty() and weapon.rotation < -0.3:
				drew_back = true
			if not strikes.is_empty() and weapon.rotation > 0.1:
				passed_rest = true
		assert_eq(strikes.size(), 1, "struck fires once (ranged %s)" % ranged)
		if strikes.size() == 1:
			assert_between(
				strikes[0], 0.5 - 0.0001, 0.5 + STEP + 0.0001, "struck at the wind-up end"
			)
		assert_true(drew_back, "the weapon draws back or rises before release (ranged %s)" % ranged)
		assert_true(passed_rest, "the strike passes the rest pose (ranged %s)" % ranged)

	var slime: CharacterSprite = _monster(&"slime")
	var slime_body: Sprite2D = _part(slime, "body")
	var slime_strikes: Array[int] = [0]
	slime.struck.connect(func() -> void: slime_strikes[0] += 1)
	slime.play_attack(0.3, false)
	var furthest_back: float = 0.0
	var furthest_forward: float = 0.0
	for _frame: int in roundi(1.2 / STEP):
		slime.advance(STEP)
		var x: float = _drawn_at(slime, slime_body, Vector2(12, 23)).x
		if slime_strikes[0] == 0:
			furthest_back = minf(furthest_back, x)
		else:
			furthest_forward = maxf(furthest_forward, x)
	assert_eq(slime_strikes[0], 1, "a part-less monster's attack fires struck too")
	assert_lt(furthest_back, -1.0, "the slime gathers itself backward")
	assert_gt(furthest_forward, 3.0, "then lunges forward with its whole body")


func test_r8_hit_flashes_and_recoils() -> void:
	for facing: int in [1, -1]:
		var knight: CharacterSprite = _hero(&"knight")
		var body: Sprite2D = _part(knight, "body")
		knight.set_facing(facing)
		knight.advance(STEP)
		assert_eq(_flash(knight), 0.0, "no flash before the hit")
		knight.play_hit()
		assert_eq(_flash(knight), 1.0, "the flash is on at once")
		var away: float = 0.0
		var elapsed: float = 0.0
		while elapsed < 0.12:
			knight.advance(STEP)
			elapsed += STEP
			var x: float = _drawn_at(knight, body, Vector2(16.5, 31.5)).x - 0.5
			away = minf(away, x * facing)
		assert_eq(_flash(knight), 0.0, "the flash is off by 0.12 s")
		assert_lt(away, -1.5, "knocked back away from its facing (%d)" % facing)
		_run(knight, 0.6)
		var rig: Node2D = _part(knight, "body").get_parent() as Node2D
		assert_eq(rig.position, Vector2.ZERO, "and back again")

	var walker: CharacterSprite = _hero(&"rogue")
	var arm: Sprite2D = _part(walker, "arm")
	walker.play_walk()
	_run(walker, 0.5)
	walker.play_hit()
	assert_eq(_flash(walker), 1.0)
	_run(walker, 0.6)
	var swings: PackedFloat32Array = []
	for _frame: int in roundi(1.0 / STEP):
		walker.advance(STEP)
		swings.append(arm.rotation)
	assert_gt(_reversals(swings), 1, "after the hit it is still walking")


func test_r9_death_hides_and_signals_once() -> void:
	for id: StringName in [&"knight", &"cave_bat"]:
		var character: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
		var deaths: Array[float] = []
		var elapsed: Array[float] = [0.0]
		character.died.connect(func() -> void: deaths.append(elapsed[0]))
		character.play_walk()
		character.advance(STEP)
		character.play_death()
		assert_true(character.is_dead(), "%s is dead from play_death() on" % id)
		while elapsed[0] < 0.4:
			elapsed[0] += STEP
			character.advance(STEP)
		assert_eq(deaths.size(), 1, "%s: died fires within 0.4 s" % id)
		assert_false(character.visible, "%s is hidden" % id)
		character.play_death()
		character.play_attack(0.2, false)
		character.play_hit()
		_run(character, 1.0)
		assert_eq(deaths.size(), 1, "%s: a second play_death() does nothing" % id)
		assert_false(character.visible, "%s stays hidden" % id)
		assert_true(character.is_dead())


func test_r10_parts_return_to_rest() -> void:
	for id: StringName in [&"knight", &"mage", &"slime", &"cave_bat", &"spider", &"ogre"]:
		var sheet: PixelSheet = _sheet_of(id)
		for sequence: int in 3:
			var character: CharacterSprite = _hero(id) if HEROES.has(id) else _monster(id)
			_play_sequence(character, sequence)
			for part_name: String in sheet.part_names:
				var part: Sprite2D = _part(character, part_name)
				assert_eq(
					part.transform, _rest(sheet, part_name), "%s %s at rest" % [id, part_name]
				)
			var rig: Node2D = _part(character, "body").get_parent() as Node2D
			assert_eq(rig.position.x, 0.0, "%s has not drifted sideways" % id)
			assert_eq(rig.rotation, 0.0, "%s stands upright" % id)
			assert_eq(_flash(character), 0.0, "%s is not left flashing" % id)


## Plays one of R10's sequences of animations to its end.
func _play_sequence(character: CharacterSprite, sequence: int) -> void:
	match sequence:
		0:
			character.play_attack(0.4, false)
			_run(character, 1.5)
		1:
			character.play_attack(0.25, true)
			_run(character, 0.1)
			character.play_hit()
			_run(character, 1.5)
		_:
			character.play_walk()
			_run(character, 1.3)
			character.play_hit()
			_run(character, 0.4)
			character.set_facing(-1)
			character.play_idle()
			_run(character, 1.5)


func test_r11_demo_runs() -> void:
	var scene: PackedScene = load(DEMO)
	assert_not_null(scene, "the demo scene loads")
	if scene == null:
		return
	var demo: CharacterDemo = scene.instantiate()
	add_child_autofree(demo)
	await wait_process_frames(300)
	# Then the rest of a cycle at full speed, so every phase has run at least once.
	for _step: int in roundi(CharacterDemo.CYCLE_SECONDS * 1.5 / 0.05):
		demo.advance(0.05)
	var cast: Array[CharacterSprite] = demo.characters()
	assert_eq(cast.size(), 9, "the demo shows the nine characters")
	var facing_right: int = 0
	for character: CharacterSprite in cast:
		var mirror: Node2D = _part(character, "body").get_parent().get_parent() as Node2D
		if mirror.scale.x > 0.0:
			facing_right += 1
	assert_eq(facing_right, 4, "the four heroes face right, the monsters left")
	assert_push_error_count(0)
	assert_engine_error_count(0)

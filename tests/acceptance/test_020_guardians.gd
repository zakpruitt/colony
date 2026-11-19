extends ColonyTest
## Acceptance tests for specs/020-guardians/spec.md, one per requirement: a guardian, one huge
## monster, holds the way down on every fifth level.

## R1's table: each guardian and the depth it first guards.
const GUARDIANS: Dictionary[StringName, int] = {
	&"slime_king": 5,
	&"clay_colossus": 10,
	&"bone_lord": 15,
	&"deep_maw": 20,
}
const GUARDIAN_DEPTHS: Array[int] = [5, 10, 15, 20, 25]
const SEEDS: Array[int] = [1, 2, 3]
const MONSTERS_DIR: String = "res://assets/sprites/monsters"
const DEMO: String = "res://game/entities/character_demo.tscn"
const STEP: float = 1.0 / 60.0
const TILE: float = 16.0
const HOUR_TICKS: int = 36_000
## A level high enough to beat any guardian at the depths these tests visit.
const STRONG_LEVEL: int = 40
## R5: fights per statement, and a typical chamber floor in tiles.
const FIGHT_SEEDS: int = 200
const FLOOR_LEFT: float = 0.0
const FLOOR_RIGHT: float = 17.0

# --- Helpers -------------------------------------------------------------------


func _ticks(seconds: float) -> int:
	return roundi(seconds * Simulation.TICKS_PER_SECOND)


func _ids(fighters: Array[Combatant]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for c: Combatant in fighters:
		ids.append(c.def_id)
	return ids


## Puts the party on [param depth] in the tunnel just outside its shaft chamber, walking in,
## with a target one deeper and no auto-push.
func _before_guardian(sim: Simulation, depth: int) -> LabyrinthChamber:
	var e: Expedition = sim.expedition
	var level: LabyrinthLevel = sim.labyrinth.level(depth)
	var shaft: LabyrinthChamber = level.shaft_chamber()
	sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1
	return shaft


## Steps until an ENCOUNTER_ENDED (inclusive), at most [param limit] ticks; every event seen.
func _run_until_end(sim: Simulation, limit: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in limit:
		sim.step()
		var drained: Array[SimEvent] = sim.drain_events()
		events.append_array(drained)
		for e: SimEvent in drained:
			if e.kind == SimEvent.Kind.ENCOUNTER_ENDED:
				return events
	return events


## The best XP and gold an ordinary (non-guardian) monster gives at [param depth].
func _best_ordinary(depth: int) -> Vector2i:
	var best := Vector2i.ZERO
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if not def.guardian and def.base_level <= depth:
			best = Vector2i(maxi(best.x, def.xp), maxi(best.y, def.gold_max))
	return best


## The share of FIGHT_SEEDS fights a party of four at [param level] wins in time against the
## guardian [param id] met at [param depth]. Spec 049: the Clay Colossus now stands at the
## Claypits' stage 5, which is level 10, the depth it held before.
func _win_rate(id: StringName, depth: int, level: int) -> float:
	var def: MonsterDef = Content.monster(id)
	var limit: int = Combatant.seconds_to_ticks(Expedition.BATTLE_LIMIT_SECONDS)
	var wins: int = 0
	for seed_value: int in range(1, FIGHT_SEEDS + 1):
		var heroes: Array[Combatant] = []
		var hero_id: int = 1
		for class_id: StringName in Party.STARTING_CLASSES:
			heroes.append(Combatant.from_hero(Content.hero_class(class_id), level, hero_id))
			hero_id += 1
		var boss: Array[Combatant] = [Combatant.from_monster(def, depth, 100)]
		boss[0].x = (FLOOR_LEFT + FLOOR_RIGHT) / 2.0
		var fight := Battle.new(
			heroes, boss, FLOOR_LEFT, FLOOR_RIGHT, true, SimRng.new(seed_value).fork("battle")
		)
		while fight.result() == Battle.Result.ONGOING and fight.tick < limit:
			fight.step()
			fight.drain_events()
		if fight.result() == Battle.Result.HEROES_WON:
			wins += 1
	return float(wins) / FIGHT_SEEDS


# --- R1 ------------------------------------------------------------------------


func test_r1_four_guardians_are_valid() -> void:
	for id: StringName in GUARDIANS:
		var def: MonsterDef = Content.monster(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate().size(), 0, "%s is valid: %s" % [id, def.validate()])
		assert_eq(def.size, MonsterDef.Size.BOSS, "%s is a boss" % id)
		assert_true(def.guardian, "%s is flagged a guardian" % id)
		assert_eq(def.base_level, GUARDIANS[id], "%s guards from depth %d" % [id, GUARDIANS[id]])
	var guardians: int = 0
	for id: StringName in Content.monster_ids():
		if Content.monster(id).guardian:
			guardians += 1
	assert_eq(guardians, GUARDIANS.size(), "exactly the four guardians")

	# Ordinary encounters, every chamber but the shaft chambers of guardian levels.
	var encounters: int = 0
	var seed_value: int = 1
	while encounters < 300 and seed_value < 20:
		var sim := Simulation.new(seed_value)
		for depth: int in range(1, 26):
			var level: LabyrinthLevel = sim.labyrinth.level(depth)
			for room: LabyrinthChamber in level.chambers:
				if depth % 5 == 0 and room == level.shaft_chamber():
					continue
				var monsters: Array[Combatant] = sim.expedition.monsters_in(depth, room.index)
				if monsters.is_empty():
					continue
				encounters += 1
				for monster: Combatant in monsters:
					assert_false(
						Content.monster(monster.def_id).guardian,
						(
							"no guardian in an ordinary encounter (%s, depth %d)"
							% [monster.def_id, depth]
						)
					)
		seed_value += 1
	assert_gte(encounters, 300, "at least 300 ordinary encounters looked at")


# --- R2 ------------------------------------------------------------------------


func test_r2_guardian_holds_the_way_down() -> void:
	for seed_value: int in SEEDS:
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for depth: int in GUARDIAN_DEPTHS:
			# Spec 049: every fifth stage of an area is held by that area's guardian.
			var expected: StringName = Content.area(e.area).guardian
			assert_eq(e.guardian_of(depth), expected, "depth %d's guardian" % depth)
			var shaft: LabyrinthChamber = sim.labyrinth.level(depth).shaft_chamber()
			var where: String = "seed %d, depth %d" % [seed_value, depth]
			assert_true(e.is_populated(depth, shaft.index), "shaft chamber held, " + where)
			assert_eq(e.monsters_in(depth, shaft.index).size(), 1, "one monster, " + where)
			assert_eq(_ids(e.monsters_in(depth, shaft.index)), [expected], "its guardian, " + where)
		for depth: int in [1, 4, 6, 9, 11]:
			assert_eq(e.guardian_of(depth), &"", "no guardian at depth %d" % depth)
		var plain: LabyrinthChamber = sim.labyrinth.level(6).shaft_chamber()
		assert_false(e.is_populated(6, plain.index), "depth 6's shaft chamber stays empty")

	# The party at depth 5 with a deeper target fights the guardian before it can climb.
	var walker := Simulation.new(SEEDS[0])
	raise_party(walker, STRONG_LEVEL)
	var shaft_room: LabyrinthChamber = _before_guardian(walker, 5)
	var climbed_first: bool = false
	var fought: bool = false
	for i: int in _ticks(120.0):
		walker.step()
		for event: SimEvent in walker.drain_events():
			if event.kind == SimEvent.Kind.DEPTH_CHANGED and not fought:
				climbed_first = true
			if event.kind == SimEvent.Kind.ENCOUNTER_STARTED and not fought:
				assert_eq(event.amount, shaft_room.index, "the fight is in the shaft chamber")
				assert_eq(
					_ids(walker.expedition.battle.monsters), [&"slime_king"], "against the guardian"
				)
				fought = true
		if walker.expedition.state == Expedition.State.CLIMBING and not fought:
			climbed_first = true
	assert_true(fought, "the party fought the guardian")
	assert_false(climbed_first, "and did not climb before it")


# --- R3 ------------------------------------------------------------------------


func test_r3_guardians_stay_beaten() -> void:
	assert_eq(Expedition.GUARDIAN_RESPAWN_SECONDS, 1800.0)
	var sim := Simulation.new(SEEDS[1])
	var e: Expedition = sim.expedition
	raise_party(sim, STRONG_LEVEL)
	var shaft: LabyrinthChamber = _before_guardian(sim, 5)
	var events: Array[SimEvent] = _run_until_end(sim, _ticks(120.0))
	var won: bool = false
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.ENCOUNTER_ENDED:
			won = event.flag
	assert_true(won, "the strong party beat the guardian")
	if not won:
		return
	var cleared: int = sim.tick
	var refill: int = cleared + _ticks(Expedition.GUARDIAN_RESPAWN_SECONDS)
	assert_false(e.is_populated(5, shaft.index), "empty once beaten")
	while sim.tick < refill - 1:
		sim.step()
		sim.drain_events()
		if e.is_populated(5, shaft.index):
			fail_test("the guardian came back early, at tick %d" % sim.tick)
			return
	sim.step()
	assert_true(e.is_populated(5, shaft.index), "back GUARDIAN_RESPAWN_SECONDS after the win")
	assert_eq(_ids(e.monsters_in(5, shaft.index)), [&"slime_king"], "the guardian again")


# --- R4 ------------------------------------------------------------------------


func test_r4_beating_one_pays() -> void:
	# Spec 049: each area's guardian pays at least ten of the best kills in its own area.
	for area: StringName in Content.area_ids():
		var place: AreaDef = Content.area(area)
		var def: MonsterDef = Content.monster(place.guardian)
		var best := Vector2i.ZERO
		for id: StringName in place.monsters:
			var monster: MonsterDef = Content.monster(id)
			best = Vector2i(maxi(best.x, monster.xp), maxi(best.y, monster.gold_max))
		assert_gte(def.xp, 10 * best.x, "%s's XP is ten ordinary kills in %s" % [def.id, area])
		assert_gte(
			def.gold_min, 10 * best.y, "%s's gold is ten ordinary kills in %s" % [def.id, area]
		)

	var sim := Simulation.new(SEEDS[2])
	raise_party(sim, STRONG_LEVEL)
	_before_guardian(sim, 5)
	var events: Array[SimEvent] = _run_until_end(sim, _ticks(120.0))
	var guardian_id: int = -1
	var died_at: int = -1
	var slain_at: int = -1
	var gold: int = 0
	for i: int in events.size():
		var event: SimEvent = events[i]
		if event.kind == SimEvent.Kind.ENCOUNTER_STARTED:
			guardian_id = sim.expedition.battle.monsters[0].id if sim.expedition.battle else -1
		if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
			died_at = i
			guardian_id = event.source_id
		if event.kind == SimEvent.Kind.GOLD_GAINED and event.source_id == guardian_id:
			gold = event.amount
		if event.kind == SimEvent.Kind.GUARDIAN_SLAIN:
			slain_at = i
			assert_eq(event.source_id, guardian_id, "source is the guardian's id")
			assert_eq(event.amount, 5, "amount is the depth")
	assert_gt(died_at, -1, "the guardian died")
	assert_gt(slain_at, died_at, "GUARDIAN_SLAIN follows its death")
	assert_gte(gold, 10 * _best_ordinary(5).y, "the gold paid out")


# --- R5 ------------------------------------------------------------------------


func test_r5_wall_then_milestone() -> void:
	var weak_5: float = _win_rate(&"slime_king", 5, 5)
	var strong_5: float = _win_rate(&"slime_king", 5, 9)
	var weak_10: float = _win_rate(&"clay_colossus", 10, 10)
	var strong_10: float = _win_rate(&"clay_colossus", 10, 15)
	gut.p(
		(
			"guardian win rates: depth 5 lv5 %.2f lv9 %.2f; depth 10 lv10 %.2f lv15 %.2f"
			% [weak_5, strong_5, weak_10, strong_10]
		)
	)
	assert_lte(weak_5, 0.3, "level 5 loses to the Slime King at least 70% of the time")
	assert_gte(strong_5, 0.7, "level 9 beats the Slime King at least 70% of the time")
	assert_lte(weak_10, 0.3, "level 10 loses to the Clay Colossus at least 70% of the time")
	assert_gte(strong_10, 0.7, "level 15 beats the Clay Colossus at least 70% of the time")


# --- R6 ------------------------------------------------------------------------


func test_r6_the_loop_still_runs() -> void:
	var beaten_runs: int = 0
	for seed_value: int in [1, 2, 3, 4, 5]:
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		e.stable_seconds = 120.0
		var where: String = "seed %d" % seed_value
		var beat_first: bool = false
		# Wipes at a guardian still waiting for the party to fight elsewhere, then come back.
		var stuck: Array[int] = []
		var fought_elsewhere: bool = false
		var guardian_battle: bool = false
		for i: int in HOUR_TICKS:
			sim.step()
			for event: SimEvent in sim.drain_events():
				match event.kind:
					SimEvent.Kind.ENCOUNTER_STARTED:
						var shaft: LabyrinthChamber = sim.labyrinth.level(e.depth).shaft_chamber()
						guardian_battle = (
							e.guardian_of(e.depth) != &"" and event.amount == shaft.index
						)
						if guardian_battle and not stuck.is_empty() and fought_elsewhere:
							stuck.clear()
						elif not guardian_battle and not stuck.is_empty():
							fought_elsewhere = true
					SimEvent.Kind.PARTY_WIPED:
						if guardian_battle and stuck.is_empty():
							stuck.append(sim.tick)
							fought_elsewhere = false
					SimEvent.Kind.GUARDIAN_SLAIN:
						if event.amount == 5:
							beat_first = true
		if beat_first:
			beaten_runs += 1
		assert_gte(e.last_stable_depth, 2, "stable on depth 2 or deeper, " + where)
		if not stuck.is_empty():
			# A wipe in the last ten minutes may not have had time to come back.
			assert_gt(stuck[0], HOUR_TICKS - _ticks(600.0), "no run is stuck, " + where)
		gut.p(
			(
				"%s: deepest %d, stable %d, beat the first guardian %s"
				% [where, e.deepest_depth, e.last_stable_depth, beat_first]
			)
		)
	assert_gte(beaten_runs, 3, "at least three of five runs beat the first guardian")


# --- R7, R8 --------------------------------------------------------------------


func test_r8_guardians_build_and_animate() -> void:
	for id: StringName in GUARDIANS:
		var sheet: PixelSheet = PixelSheet.load_sheet("%s/%s.png" % [MONSTERS_DIR, id])
		assert_not_null(sheet, "%s has a baked sheet" % id)
		if sheet == null:
			continue
		assert_eq(sheet.category, "boss", "%s is in the boss category" % id)
		assert_eq(sheet.size, Vector2i(64, 64), "%s is 64x64" % id)
		assert_true(sheet.has_part(&"body"), "%s has a body" % id)
		var moving: bool = false
		for part: StringName in [&"head", &"arm", &"weapon"]:
			moving = moving or sheet.has_part(part)
		for part_name: String in sheet.part_names:
			moving = moving or part_name.begins_with("leg") or part_name.begins_with("wing")
		assert_true(moving, "%s has a part that animates besides its body" % id)
		var character: CharacterSprite = CharacterSprite.for_monster(id)
		assert_not_null(character, "%s builds" % id)
		if character == null:
			continue
		add_child_autofree(character)
		character.play_idle()
		for i: int in 60:
			character.advance(STEP)
		character.play_attack(0.9, false)
		for i: int in 90:
			character.advance(STEP)
		character.play_hit()
		for i: int in 30:
			character.advance(STEP)
		character.play_death()
		for i: int in 60:
			character.advance(STEP)
		assert_true(character.is_dead(), "%s died" % id)

	var scene: PackedScene = load(DEMO)
	var demo: CharacterDemo = scene.instantiate()
	add_child_autofree(demo)
	await wait_process_frames(5)
	for id: StringName in GUARDIANS:
		var body: Texture2D = PixelSheet.load_sheet("%s/%s.png" % [MONSTERS_DIR, id]).part(&"body")
		var shown: bool = false
		for character: CharacterSprite in demo.characters():
			var part: Sprite2D = character.find_child("body", true, false) as Sprite2D
			shown = shown or (part != null and part.texture == body)
		assert_true(shown, "the demo shows the %s" % id)
	assert_push_error_count(0)
	assert_engine_error_count(0)


## The topmost (x) and lowest (y) rows any part of the sheet draws a pixel on.
func _drawn_rows(sheet: PixelSheet) -> Vector2i:
	var rows := Vector2i(sheet.size.y, -1)
	for part_name: String in sheet.part_names:
		var image: Image = sheet.part(StringName(part_name)).get_image()
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					rows = Vector2i(mini(rows.x, y), maxi(rows.y, y))
					break
	return rows


func test_r8_guardian_stands_in_its_chamber() -> void:
	for seed_value: int in SEEDS:
		var sim := Simulation.new(seed_value)
		_before_guardian(sim, 5)
		var world := World.new()
		world.simulation = sim
		add_child_autofree(world)
		for i: int in 3:
			sim.step()
			world.sync(STEP)
			world.sync(1.0)
		var level: LabyrinthLevel = sim.labyrinth.level(5)
		var shaft: LabyrinthChamber = level.shaft_chamber()
		var guardian: Combatant = null
		if sim.expedition.battle != null:
			guardian = sim.expedition.battle.monsters[0]
		elif not sim.expedition.monsters_in(5, shaft.index).is_empty():
			guardian = sim.expedition.monsters_in(5, shaft.index)[0]
		assert_not_null(guardian, "the guardian is there, seed %d" % seed_value)
		if guardian == null:
			continue
		var sprite: CharacterSprite = world.character(guardian.id)
		assert_not_null(sprite, "the guardian has a sprite, seed %d" % seed_value)
		if sprite == null:
			continue
		var floor_line: float = (level.floor_y + 1) * TILE
		var ceiling: float = shaft.rect.position.y * TILE
		# The pivot row is drawn just below the node (which the world lifts by FEET_LIFT).
		var sheet: PixelSheet = PixelSheet.load_sheet("%s/slime_king.png" % MONSTERS_DIR)
		var rows: Vector2i = _drawn_rows(sheet)
		assert_eq(rows.y, sheet.pivot.y, "the sprite's lowest drawn row is its feet")
		var feet_bottom: float = sprite.global_position.y - world.global_position.y + 1.0
		assert_eq(feet_bottom, floor_line, "feet on the floor line, seed %d" % seed_value)
		var top: float = feet_bottom - (sheet.pivot.y + 1 - rows.x)
		assert_gte(top, ceiling, "its top below the ceiling, seed %d" % seed_value)
		gut.p(
			(
				"seed %d: chamber %d tiles high, guardian top %.0f px below the ceiling"
				% [seed_value, shaft.rect.size.y, top - ceiling]
			)
		)
	assert_push_error_count(0)

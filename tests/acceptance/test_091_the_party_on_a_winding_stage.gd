extends "res://tests/support/play_fixture.gd"
## Spec 091: on a winding stage everything that stands in the world stands in its own room, and
## the heroes, the camera, the target arrow and the crossing follow the course.

const KNIGHT: int = 1
## Seeds searched for a stage with the room a test needs.
const SEEDS: int = 30
const SCREEN_SIZE: Vector2 = Vector2(640, 360)
const LEFT: Vector2i = Vector2i(-1, 0)
const RIGHT: Vector2i = Vector2i(1, 0)

## What a test found wrong, a line each: asserted empty at its end, so a fault in every frame is
## told once.
var _wrong: PackedStringArray = []


func before_each() -> void:
	_wrong = []


func _mark_wrong(problem: String) -> void:
	if _wrong.size() < 6:
		_wrong.append(problem)


func _assert_nothing_wrong(what: String) -> void:
	assert_eq(_wrong.size(), 0, "%s:\n%s" % [what, "\n".join(_wrong)])
	_wrong = []


## The feet pixel of a place in world tiles.
func _px(tiles: Vector2) -> Vector2:
	return Vector2(tiles.x * TILE, (tiles.y + 1.0) * TILE)


func _floor_line(room: LabyrinthChamber) -> float:
	return (room.floor_row() + 1) * TILE


## Puts [param simulation]'s party on [param stage] at [param distance] along its course, sent
## to [param target], the stage it would be revived on [param safe] (its own unless given), and
## shows a new world over it.
func _stand(
	simulation: Simulation, stage: int, distance: float, target: int, safe: int = 0
) -> void:
	var e: Expedition = simulation.expedition
	var held: int = safe if safe > 0 else stage
	Arrival.from_save(e, simulation.tick, held, maxi(stage, target), target, false)
	e.depth = stage
	e._place(distance)
	_show(simulation)


## Empties every cache of [param stage] as of now, so [param simulation]'s party passes its side
## paths and keeps to the route.
func _empty_caches(simulation: Simulation, stage: int) -> void:
	var e: Expedition = simulation.expedition
	var paths: Array[SidePath] = simulation.labyrinth.level(stage).side_paths
	assert_gt(paths.size(), 0, "stage %d has side paths to pass" % stage)
	for index: int in paths.size():
		e._side._opened[Vector2i(stage, index)] = simulation.tick
		assert_false(SidePathRules.is_full(e, stage, index), "cache %d is empty" % index)


## The way [param room] is walked in the world by a party going on: 1 right, -1 left.
func _heading_in(level: LabyrinthLevel, room: LabyrinthChamber) -> int:
	var stretch: Vector2 = level.course.stretch_of(room.index)
	return level.course.heading_at((stretch.x + stretch.y) / 2.0)


## The first room of [param level] between its first and its last that [param wanted] accepts,
## or null.
func _room(level: LabyrinthLevel, wanted: Callable) -> LabyrinthChamber:
	for index: int in range(1, level.chambers.size() - 1):
		if wanted.call(level.chambers[index]):
			return level.chambers[index]
	return null


## A distance on [param level]'s course just short of [param room], for a party going on: its
## next steps take it in.
func _short_of(level: LabyrinthLevel, room: LabyrinthChamber) -> float:
	var at: float = level.course.stretch_of(room.index).x
	while level.course.chamber_at(at) == room.index and at > level.course.start:
		at -= 0.25
	return at


## The distances at which ladder [param which] of [param line] begins (x) and ends (y) for a
## party going on: the corners it shares with the two floors.
func _ladder_ends(line: StageCourse, which: int = 0) -> Vector2:
	var found: int = -1
	var first: float = -1.0
	var at: float = line.start
	while at <= line.end:
		if line.on_ladder(at) and first < 0.0:
			first = at
			found += 1
		elif not line.on_ladder(at) and first >= 0.0:
			if found == which:
				return Vector2(first - 0.25, at)
			first = -1.0
		at += 0.25
	return Vector2(-1.0, -1.0)


## Which way [param sprite] is drawn facing: 1 right, -1 left.
func _faces(sprite: CharacterSprite) -> int:
	return -1 if (sprite.get_node("Mirror") as Node2D).scale.x < 0.0 else 1


## Where the camera rests on stage [param stage] when it is sent to [param target].
func _camera_rest(stage: int, target: Vector2) -> Vector2:
	var half: Vector2 = SCREEN_SIZE / 2.0
	var rows: Vector2 = WorldCamera.rows_of(_sim.labyrinth, stage)
	return Vector2(
		clampf(target.x, half.x, WorldCamera.BAND_WIDTH - half.x),
		clampf(target.y, rows.x + half.y, rows.y - half.y)
	)


## Plays frames until every hero's sprite stands on the floor line [param line_y] and
## [param settled] holds, [param seconds] at most, calling [param each] after every frame.
## False if it never came to that.
func _play_onto(line_y: float, seconds: float, settled: Callable, each: Callable) -> bool:
	for i: int in int(seconds * 60.0):
		_play_frame()
		each.call()
		var there: bool = settled.call()
		for hero: Hero in _sim.party.heroes:
			there = there and is_equal_approx(_world.character(hero.id).position.y, line_y)
		if there:
			return true
	return false


# --- R2 ------------------------------------------------------------------------


func test_r2_monsters_stand_on_their_rooms_floor() -> void:
	var off_the_first_floor: int = 0
	for seed_value: int in [1, 2, 3]:
		_show(winding_simulation(seed_value))
		for stage: int in range(1, 6):
			Arrival.from_save(_sim.expedition, _sim.tick, stage, stage, stage, false)
			_world.sync(STEP)
			var level: LabyrinthLevel = _sim.labyrinth.level(stage)
			var populated: int = 0
			for room: LabyrinthChamber in level.chambers:
				for monster: Combatant in _sim.expedition.monsters_in(stage, room.index):
					var what: String = "seed %d stage %d room %d" % [seed_value, stage, room.index]
					populated += 1
					var sprite: CharacterSprite = _world.character(monster.id)
					if sprite == null:
						_mark_wrong("%s: a monster with no sprite" % what)
						continue
					if _world.feet_position(monster.id).y != _floor_line(room):
						_mark_wrong("%s: feet at %s" % [what, sprite.position])
					if not room.rect.has_point(Vector2i(floori(monster.x), room.floor_row())):
						_mark_wrong("%s: outside its room at column %s" % [what, monster.x])
					if room.floor_row() != level.floor_y:
						off_the_first_floor += 1
			assert_gt(populated, 0, "seed %d stage %d has monsters waiting" % [seed_value, stage])
	_assert_nothing_wrong("every waiting monster's feet are on its room's floor line")
	assert_gt(off_the_first_floor, 20, "many of them off the first room's floor")

	# A fight in a room not on the first room's floor, lost, and the monsters walking back.
	var sim: Simulation = winding_simulation(1)
	var stage_1: LabyrinthLevel = sim.labyrinth.level(1)
	var lower: LabyrinthChamber = _room(
		stage_1,
		func(room: LabyrinthChamber) -> bool:
			return (
				room.floor_row() != stage_1.floor_y and sim.expedition.is_populated(1, room.index)
			)
	)
	assert_not_null(lower, "stage 1 has monsters off its first room's floor")
	if lower == null:
		return
	_stand(sim, 1, _short_of(stage_1, lower), 2)
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED, 30), "the party meets them")
	assert_eq(sim.expedition.chamber(), lower, "in that room")
	var line_y: float = _floor_line(lower)
	var fighters: Array[Combatant] = sim.expedition.battle.monsters.duplicate()
	var fought: int = 0
	for i: int in 90:
		_play_frame()
		if sim.expedition.battle == null:
			break
		for monster: Combatant in fighters:
			var sprite: CharacterSprite = _world.character(monster.id)
			if monster.is_alive() and sprite != null:
				fought += 1
				if sprite.position.y != line_y:
					_mark_wrong("frame %d: fighter %d at %s" % [i, monster.id, sprite.position])
	assert_gt(fought, 60, "the fight was watched")
	_assert_nothing_wrong("a fighter's feet are on its room's floor line")
	assert_not_null(sim.expedition.battle, "the fight is still on")
	if sim.expedition.battle == null:
		return
	for hero: Combatant in sim.expedition.battle.heroes:
		hero.health = 0
		hero.state = Combatant.State.DEAD
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED, 5), "the party falls")
	var walked: float = 0.0
	var back: int = 0
	for i: int in 120:
		var before: Dictionary[int, float] = {}
		for monster: Combatant in sim.expedition.monsters_in(1, lower.index):
			if _world.character(monster.id) != null:
				before[monster.id] = _world.character(monster.id).position.x
		_play_frame()
		for id: int in before:
			var sprite: CharacterSprite = _world.character(id)
			if sprite == null:
				continue
			back += 1
			walked += absf(sprite.position.x - before[id])
			if sprite.position.y != line_y:
				_mark_wrong("frame %d: survivor %d at %s" % [i, id, sprite.position])
	assert_gt(back, 0, "monsters survived")
	assert_gt(walked, TILE, "and walked back to their places")
	_assert_nothing_wrong("a monster walking back keeps to its room's floor line")


# --- R3 ------------------------------------------------------------------------


func test_r3_a_hero_climbs_the_ladder_in_its_column() -> void:
	var ways: Dictionary[int, bool] = {}
	for seed_value: int in [1, 2, 3, 4]:
		var sim: Simulation = winding_simulation(seed_value)
		raise_party(sim, 12)
		var level: LabyrinthLevel = sim.labyrinth.level(1)
		var line: StageCourse = level.course
		var ends: Vector2 = _ladder_ends(line)
		assert_gt(ends.x, line.start, "seed %d: stage 1 has a ladder on its course" % seed_value)
		_stand(sim, 1, ends.x - 3.0, 2)
		_empty_caches(sim, 1)
		var ladder: Rect2i = level.ladders[0]
		var rung: float = (ladder.position.x + ladder.size.x / 2.0) * TILE
		var top: float = ladder.position.y * TILE
		var bottom: float = ladder.end.y * TILE
		var far_line: float = _px(line.point_at(ends.y)).y
		ways[signi(roundi(far_line - _px(line.point_at(ends.x)).y))] = true
		var between: Dictionary[int, int] = {}
		var e: Expedition = sim.expedition
		var what: String = "seed %d" % seed_value
		var each: Callable = func() -> void:
			for hero: Hero in sim.party.heroes:
				var sprite: CharacterSprite = _world.character(hero.id)
				var at: Vector2 = sprite.position
				# A sprite settles on its place from within World.SETTLE of it: less than a pixel.
				var row: int = ceili((at.y - World.SETTLE) / TILE) - 1
				var tile := Vector2i(floori(at.x / TILE), row)
				if not _world.labyrinth_view.is_open(tile):
					_mark_wrong("%s: hero %d in the earth at %s" % [what, hero.id, at])
				if at.y > top + 0.5 and at.y < bottom - 0.5:
					var so_far: int = between.get(hero.id, 0)
					between[hero.id] = so_far + 1
					if absf(at.x - rung) > 0.5:
						_mark_wrong("%s: hero %d off the ladder at %s" % [what, hero.id, at])
					# Stopped on its way (the party rests, or works a quest), a hero waits on it.
					if e.state == Expedition.State.TRAVELLING and not sprite._walking:
						_mark_wrong("%s: hero %d not drawn climbing at %s" % [what, hero.id, at])
		var past: Callable = func() -> bool:
			return e.x >= ends.y + 4.0 or e.state != Expedition.State.TRAVELLING
		# Time for the walk, and for the longest quest worked on the way.
		assert_true(_play_onto(far_line, 30.0, past, each), "%s: all reach the far floor" % what)
		for hero: Hero in sim.party.heroes:
			var seen: int = between.get(hero.id, 0)
			assert_gt(seen, 60, "%s: hero %d was seen on the ladder" % [what, hero.id])
	_assert_nothing_wrong("every hero in the open, and in the ladder's column between the floors")
	assert_eq(ways.size(), 2, "a ladder was climbed down and one up")


func test_r3_heroes_face_left_in_a_room_walked_leftward() -> void:
	var sim: Simulation = winding_simulation(1)
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var room: LabyrinthChamber = _room(
		level, func(found: LabyrinthChamber) -> bool: return _heading_in(level, found) < 0
	)
	assert_not_null(room, "stage 1 has a room walked leftward")
	if room == null:
		return
	var e: Expedition = sim.expedition
	_stand(sim, 1, level.course.stretch_of(room.index).x + 5.0, 2)
	assert_eq(e.facing, 1, "the party travels on along the course")
	assert_eq(PartyPlaces.world_facing(e), -1, "which runs leftward here")
	var started: Dictionary[int, float] = {}
	for hero: Hero in sim.party.heroes:
		started[hero.id] = _world.character(hero.id).position.x
		assert_eq(_faces(_world.character(hero.id)), -1, "a new sprite faces left")
	for i: int in 60:
		_play_frame()
		for hero: Hero in sim.party.heroes:
			var sprite: CharacterSprite = _world.character(hero.id)
			if _faces(sprite) != -1 or not sprite._walking:
				_mark_wrong("frame %d: hero %d faces right or stands" % [i, hero.id])
	assert_eq(e.state, Expedition.State.TRAVELLING, "it walked all the while")
	assert_eq(e.chamber(), room, "in that room")
	for hero: Hero in sim.party.heroes:
		assert_lt(
			_world.character(hero.id).position.x,
			started[hero.id] - TILE,
			"hero %d walked left" % hero.id
		)
	_assert_nothing_wrong("walking, every hero faces left")
	assert_lt(
		_world.camera.target.x,
		_world.character(KNIGHT).position.x,
		"and the camera looks ahead of the leader: to its left"
	)

	# Resting where it stands (spec 102): every hero faces the camp's fire.
	for hero: Hero in sim.party.heroes:
		hero.health = 1
	e._start_rest()
	for i: int in 60:
		_play_frame()
		var fire: Vector2 = _world.camp.fire_feet()
		for hero: Hero in sim.party.heroes:
			var sprite: CharacterSprite = _world.character(hero.id)
			var toward: int = 1 if fire.x > sprite.position.x else -1
			if i > 30 and _faces(sprite) != toward:
				_mark_wrong("frame %d: hero %d rests facing away from the fire" % [i, hero.id])
	assert_eq(e.state, Expedition.State.RESTING, "it rested all the while")
	_assert_nothing_wrong("resting, every hero faces the fire")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_worker_and_the_guardians_side_follow_the_world() -> void:
	# A quest in a room walked leftward.
	var found: bool = false
	for seed_value: int in range(1, SEEDS + 1):
		var sim: Simulation = winding_simulation(seed_value)
		var level: LabyrinthLevel = sim.labyrinth.level(1)
		var room: LabyrinthChamber = _room(
			level,
			func(tried: LabyrinthChamber) -> bool:
				var quest: StringName = sim.expedition.quest_in(1, tried.index)
				return quest != &"" and _heading_in(level, tried) < 0
		)
		if room == null:
			continue
		found = true
		raise_party(sim, 30)
		_stand(sim, 1, _short_of(level, room), 2)
		assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 30), "the party finds it")
		var e: Expedition = sim.expedition
		var prop: Vector2 = _world.quest_props.spot(1, room.index)
		var sides: Dictionary[int, bool] = {}
		for i: int in 600:
			_play_frame()
			if e.state != Expedition.State.WORKING:
				break
			var worker: CharacterSprite = _world.character(e.worker_id())
			if absf(absf(worker.position.x - prop.x) - QuestProps.WORK_GAP) <= 0.5:
				sides[signi(roundi(worker.position.x - prop.x))] = true
		assert_true(sides.has(1), "seed %d: the worker stands right of the prop" % seed_value)
		assert_false(sides.has(-1), "seed %d: and never left of it" % seed_value)
		break
	assert_true(found, "a seed has a quest in a room walked leftward")

	# A guardian in a room walked leftward, and a hero standing on its middle.
	found = false
	for seed_value: int in range(1, SEEDS + 1):
		var sim: Simulation = winding_simulation(seed_value)
		var level: LabyrinthLevel = sim.labyrinth.level(5)
		var lair: LabyrinthChamber = level.chambers[level.chambers.size() - 1]
		if _heading_in(level, lair) > 0:
			continue
		found = true
		raise_party(sim, 40)
		_stand(sim, 5, _short_of(level, lair), 6)
		assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED, 30), "the party meets it")
		var guardian: Combatant = GuardianSpacing.fighting_guardian(sim)
		assert_not_null(guardian, "seed %d: a guardian fights" % seed_value)
		if guardian == null:
			break
		var body: CharacterSprite = _world.character(guardian.id)
		for i: int in 120:
			_play_frame(false)
		assert_eq(body.position.x, guardian.x * TILE, "its sprite is where it stands")
		sim.expedition.battle.combatant(KNIGHT).x = guardian.x
		for i: int in 60:
			_play_frame(false)
		var knight: CharacterSprite = _world.character(KNIGHT)
		assert_gt(
			knight.position.x,
			body.position.x + SpriteBounds.reach(body),
			(
				"seed %d: the hero on it steps back to the right, where the party came from"
				% seed_value
			)
		)
		break
	assert_true(found, "a seed has a guardian's room walked leftward")


# --- R5 ------------------------------------------------------------------------


func test_r5_props_and_the_fallen_are_in_their_room() -> void:
	var found: bool = false
	for seed_value: int in range(1, SEEDS + 1):
		var sim: Simulation = winding_simulation(seed_value)
		var level: LabyrinthLevel = sim.labyrinth.level(3)
		var line: StageCourse = level.course
		# A quest off the first room's floor, in a room the course enters along the floor.
		var room: LabyrinthChamber = _room(
			level,
			func(tried: LabyrinthChamber) -> bool:
				var before: Vector2 = line.point_at(line.stretch_of(tried.index).x - 4.0)
				return (
					sim.expedition.quest_in(3, tried.index) != &""
					and tried.floor_row() != level.floor_y
					and before.y == tried.floor_row()
				)
		)
		if room == null:
			continue
		found = true
		var what: String = "seed %d" % seed_value
		raise_party(sim, 30)
		_stand(sim, 3, _short_of(level, room), 4, 2)
		var line_y: float = _floor_line(room)
		# Spec 106: the prop stands at its spot, toward the far side of its room.
		var prop_x: float = QuestProps.spot_in(_world.labyrinth_view, 3, room.index).x
		var prop: Sprite2D = _world.quest_props.prop(3, room.index)
		assert_not_null(prop, "%s: the quest's prop shows" % what)
		if prop == null:
			break
		assert_eq(prop.position, Vector2(prop_x, line_y), "%s: on its room's floor" % what)
		assert_eq(_world.quest_props.spot(3, room.index), prop.position, "%s: its spot" % what)
		assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 30), "%s: work starts" % what)
		for i: int in 30:
			_play_frame()
		var props: QuestProps = _world.quest_props
		assert_gt(props.bar_fraction(), 0.0, "%s: the bar shows" % what)
		assert_ne(props.worker_label(), "", "%s: and the microskill's name" % what)
		assert_eq(props._bar_at.y, line_y - QuestProps.BAR_RAISE, "%s: over the prop" % what)
		assert_lt(props._name_at.y, props._bar_at.y, "%s: the name over the bar" % what)
		var bar_middle: float = props._bar_at.x + QuestProps.BAR_SIZE.x / 2.0
		assert_almost_eq(bar_middle, prop_x, 1.0, "%s: the bar over the prop" % what)

		# Wiped there: every hero lies where the simulation says it fell, on that floor.
		var worker: int = sim.expedition.worker_id()
		_wipe(sim)
		assert_true(_play_until(SimEvent.Kind.PARTY_WIPED, 5), "%s: the party falls" % what)
		var e: Expedition = sim.expedition
		assert_eq(e.revival_place().y, 2.0, "%s: it will be revived on stage 2" % what)
		for i: int in 60:
			_play_frame()
		for hero: Hero in sim.party.heroes:
			var fell: Vector2 = _px(e.hero_position(hero.id))
			assert_eq(fell.y, line_y, "%s: hero %d fell on that floor" % [what, hero.id])
			assert_true(_world.fallen_party.is_lying(hero.id), "%s: it lies" % what)
			var feet: Vector2 = _world.feet_position(hero.id)
			assert_eq(feet.y, line_y, "%s: hero %d lies on that floor" % [what, hero.id])
			# The worker lies at the prop, where it was seen to fall.
			if hero.id != worker:
				assert_almost_eq(feet.x, fell.x, 8.0, "%s: where it fell" % what)

		# The revival: the camera ends at the safe stage's entry, on its room's floor.
		var safe: StageCourse = sim.labyrinth.level(2).course
		var entry: Vector2 = safe.point_at(safe.entry)
		var home: LabyrinthChamber = sim.labyrinth.level(2).chambers[safe.chamber_at(safe.entry)]
		assert_eq(entry.y, float(home.floor_row()), "%s: the entry is on a floor" % what)
		var faces: int = safe.heading_at(safe.entry) * Arrival.facing(safe, safe.entry)
		var target: Vector2 = _world.camera_target(_px(entry), faces)
		assert_eq(_world.fallen_party.destination(), target, "%s: the story ends there" % what)
		assert_true(_play_until(SimEvent.Kind.PARTY_REVIVED, 80), "%s: it is revived" % what)
		assert_eq(_world.shown_stage(), 2, "%s: on stage 2" % what)
		assert_eq(_world.camera.position, _camera_rest(2, target), "%s: the camera is there" % what)
		for i: int in 90:
			_play_frame(false)
		assert_false(_world.fallen_party.is_telling(), "%s: the heroes have stood up" % what)
		assert_eq(PartyPlaces.world_facing(e), faces, "%s: facing as the camera looked" % what)
		assert_eq(_world.camera.position, _camera_rest(2, target), "%s: and it stays" % what)
		for hero: Hero in sim.party.heroes:
			assert_eq(_world.feet_position(hero.id).y, _px(entry).y, "%s: on its floor" % what)
		break
	assert_true(found, "a seed has a quest off stage 3's first floor")


# --- R6 ------------------------------------------------------------------------


## Plays [member _sim]'s party through a change of stage, from the doorway at [param from] to the
## one at [param to] (feet pixels), noting every hero drawn anywhere it should not be. Returns
## false if no crossing came.
func _cross(what: String, from: Vector2, to: Vector2) -> bool:
	var e: Expedition = _sim.expedition
	var crossed: bool = false
	var dark_frames: int = 0
	var out_frames: int = 0
	for i: int in 20 * 60:
		_play_frame()
		if e.state != Expedition.State.CLIMBING:
			if crossed:
				break
			continue
		crossed = true
		var share: float = ClimbProgress.share(e)
		var dark: bool = _world.crossing.darkness() >= 1.0
		dark_frames += 1 if dark else 0
		out_frames += 1 if share >= ZoneCrossing.OUT_SHARE else 0
		for hero: Hero in _sim.party.heroes:
			var sprite: CharacterSprite = _world.character(hero.id)
			var at: Vector2 = sprite.position
			var shown: float = sprite.modulate.a
			var who: String = "%s, share %.2f, hero %d at %s" % [what, share, hero.id, at]
			if dark and shown > 0.0:
				_mark_wrong("%s: visible in the dark" % who)
			if share >= ZoneCrossing.OUT_SHARE:
				if at != to or shown != 1.0:
					_mark_wrong("%s: not standing at the arrival doorway %s" % [who, to])
			elif share >= ZoneCrossing.SWITCH_SHARE:
				if shown != 0.0:
					_mark_wrong("%s: drawn while the stage changes" % who)
			else:
				var gap: float = absf(at.x - from.x)
				var want: float = clampf(
					(gap - ZoneCrossing.GONE_WITHIN) / (TILE - ZoneCrossing.GONE_WITHIN), 0.0, 1.0
				)
				if at.y != from.y or gap > 4.0 * TILE:
					_mark_wrong("%s: not by the leaving doorway %s" % [who, from])
				if not is_equal_approx(shown, want):
					_mark_wrong("%s: shown %.2f, not %.2f by its distance" % [who, shown, want])
	assert_gt(dark_frames, 30, "%s: the screen was dark a while" % what)
	assert_gt(out_frames, 30, "%s: and opened on the heroes" % what)
	return crossed


func test_r6_the_crossing_is_at_the_doorways() -> void:
	for seed_value: int in [1, 2, 5]:
		var sim: Simulation = winding_simulation(seed_value)
		var here: StageCourse = sim.labyrinth.level(2).course
		var there: StageCourse = sim.labyrinth.level(3).course
		var way_on: Vector2 = _px(here.point_at(here.exit))
		var way_in: Vector2 = _px(there.point_at(there.entry))
		_stand(sim, 2, here.exit - 4.0, 3)
		var what: String = "seed %d on" % seed_value
		assert_true(_cross(what, way_on, way_in), "%s: the party changes stage" % what)
		assert_eq(sim.expedition.depth, 3, "%s: it is on stage 3" % what)
		assert_eq(_world.shown_stage(), 3, "%s: which the world shows" % what)
		for hero: Hero in sim.party.heroes:
			var sprite: CharacterSprite = _world.character(hero.id)
			assert_eq(sprite.modulate.a, 1.0, "%s: hero %d shows" % [what, hero.id])
			assert_eq(sprite.position.y, way_in.y, "%s: on the doorway's floor" % what)
			assert_almost_eq(sprite.position.x, way_in.x, 4.0 * TILE, "%s: by it" % what)
		sim.set_target_depth(2)
		what = "seed %d back" % seed_value
		assert_true(_cross(what, way_in, way_on), "%s: the party changes stage" % what)
		assert_eq(sim.expedition.depth, 2, "%s: it is on stage 2" % what)
		assert_eq(_world.shown_stage(), 2, "%s: which the world shows" % what)
	_assert_nothing_wrong("through every crossing, heroes are drawn only at the doorways")


func test_r6_a_journey_begun_while_arriving_keeps_the_heroes_at_the_doorway() -> void:
	var sim: Simulation = winding_simulation(1)
	sim.expedition.travel.open[&"claypits"] = true
	var here: StageCourse = sim.labyrinth.level(2).course
	var there: StageCourse = sim.labyrinth.level(3).course
	var way_in: Vector2 = _px(there.point_at(there.entry))
	_stand(sim, 2, here.exit - 2.0, 3)
	var e: Expedition = sim.expedition
	var arriving: bool = false
	for i: int in 20 * 60:
		_play_frame()
		arriving = e.state == Expedition.State.CLIMBING and ClimbProgress.share(e) >= 0.6
		if arriving:
			break
	assert_true(arriving, "the party is in the second half of its change of stage")
	assert_eq(_world.shown_stage(), 3, "and the world shows the stage it arrives on")
	sim.set_destination(&"claypits", 1)
	var frames: int = 0
	for i: int in 20 * 60:
		_play_frame()
		if e.state == Expedition.State.CLIMBING:
			continue
		if e.state != Expedition.State.JOURNEYING:
			break
		frames += 1
		if _world.shown_stage() != 3:
			_mark_wrong("frame %d: the world shows stage %d" % [i, _world.shown_stage()])
		for hero: Hero in sim.party.heroes:
			var at: Vector2 = _world.character(hero.id).position
			if at.y != way_in.y or absf(at.x - way_in.x) > 4.0 * TILE:
				_mark_wrong("frame %d: hero %d at %s, not by %s" % [i, hero.id, at, way_in])
	assert_gt(frames, 30, "the party was on its way to the other area a while")
	_assert_nothing_wrong("on the way, every hero stays by the doorway it was arriving at")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_arrow_points_along_the_course() -> void:
	var sim: Simulation = winding_simulation(1)
	var level: LabyrinthLevel = sim.labyrinth.level(2)
	var line: StageCourse = level.course
	for heading: int in [1, -1]:
		var room: LabyrinthChamber = _room(
			level,
			func(found: LabyrinthChamber) -> bool: return _heading_in(level, found) == heading
		)
		assert_not_null(room, "stage 2 has a room walked %d" % heading)
		if room == null:
			continue
		_stand(sim, 2, line.stretch_of(room.index).x + 5.0, 3)
		var marker: TargetMarker = _world.target_marker
		assert_true(marker.visible, "the arrow shows on the way on")
		assert_eq(marker.pointing(), 1, "the way on")
		assert_eq(
			marker.heading(), Vector2i(heading, 0), "sideways as the course runs: %d" % heading
		)
		assert_eq(marker.side(), heading, "its side says the same")
		# Sent back, the other way.
		_stand(sim, 2, line.stretch_of(room.index).x + 5.0, 1)
		assert_eq(_world.target_marker.pointing(), -1, "the way back")
		assert_eq(_world.target_marker.heading(), Vector2i(-heading, 0), "back along the course")

	var ends: Vector2 = _ladder_ends(line)
	var down: int = signi(roundi(line.point_at(ends.y).y - line.point_at(ends.x).y))
	assert_ne(down, 0, "the ladder joins two floors")
	var after: int = line.heading_at(ends.y + 1.0)
	var before: int = line.heading_at(ends.x - 1.0)
	assert_eq(after, -before, "the course turns round at the ladder")
	_stand(sim, 2, ends.x - 1.0, 3)
	assert_eq(_world.target_marker.heading(), Vector2i(before, 0), "a tile short of it: sideways")
	_stand(sim, 2, ends.x, 3)
	assert_eq(_world.target_marker.heading(), Vector2i(0, down), "at its head: along the ladder")
	assert_eq(_world.target_marker.side(), 0, "not sideways")
	_stand(sim, 2, (ends.x + ends.y) / 2.0, 3)
	assert_eq(_world.target_marker.heading(), Vector2i(0, down), "on it: along the ladder")
	var highest: float = INF
	var lowest: float = -INF
	for hero: Hero in sim.party.heroes:
		highest = minf(highest, _world.character(hero.id).position.y)
		lowest = maxf(lowest, _world.character(hero.id).position.y)
	assert_gt(lowest - highest, TILE, "the heroes are one over another on it")
	assert_lte(
		_world.target_marker.position.y,
		highest - TargetMarker.HEIGHT,
		"and it hangs over the highest hero on the ladder"
	)
	_stand(sim, 2, ends.y, 3)
	assert_eq(_world.target_marker.heading(), Vector2i(after, 0), "at its foot: along the floor")
	# Sent back, the foot is where the climb begins.
	_stand(sim, 2, ends.y, 1)
	assert_eq(_world.target_marker.heading(), Vector2i(0, -down), "back: up the way it came")
	_stand(sim, 2, ends.x, 1)
	assert_eq(_world.target_marker.heading(), Vector2i(-before, 0), "and off its head")

	# A flat stage's arrow points sideways at its doorway, as it always did.
	var flat := Simulation.new(1)
	_stand(flat, 2, flat.labyrinth.level(2).course.entry, 3)
	var door: float = flat.labyrinth.level(2).course.exit * TILE
	var toward: int = signi(roundi(door - _world.feet_position(KNIGHT).x))
	assert_eq(_world.target_marker.heading(), Vector2i(toward, 0), "flat: at the doorway")


# --- R8 ------------------------------------------------------------------------


func test_r8_the_camera_follows_down_a_ladder() -> void:
	var sim: Simulation = winding_simulation(1)
	raise_party(sim, 12)
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var line: StageCourse = level.course
	var ends: Vector2 = _ladder_ends(line)
	_stand(sim, 1, ends.x - 3.0, 2)
	_empty_caches(sim, 1)
	var camera: WorldCamera = _world.camera
	var e: Expedition = sim.expedition
	var from_line: float = _px(line.point_at(ends.x)).y
	var far_line: float = _px(line.point_at(ends.y)).y
	var way: float = signf(far_line - from_line)
	var rest_from: float = _camera_rest(1, Vector2(0, from_line - World.LOOK_ABOVE)).y
	var rest_far: float = _camera_rest(1, Vector2(0, far_line - World.LOOK_ABOVE)).y
	assert_eq(camera.position.y, rest_from, "the camera rests over the party's floor")
	assert_gt(absf(rest_far - rest_from), 100.0, "the next floor's rest is far from it")
	# A lambda keeps its own copy of a local number, so the last place is held in an array.
	var last: Array[float] = [camera.position.y]
	var steps: Dictionary[float, bool] = {}
	var each: Callable = func() -> void:
		var moved: float = (camera.position.y - last[0]) * way
		if moved < 0.0 or moved > 6.0:
			_mark_wrong("the camera moved %s in a frame at %s" % [moved * way, camera.position])
		steps[camera.position.y] = true
		last[0] = camera.position.y
	var past: Callable = func() -> bool:
		return e.x >= ends.y + 4.0 or e.state != Expedition.State.TRAVELLING
	assert_true(_play_onto(far_line, 15.0, past, each), "the party reaches the far floor")
	for i: int in 120:
		_play_frame(false)
		each.call()
	_assert_nothing_wrong("the camera eases after the party, never back and never at a jump")
	assert_eq(camera.position.y, rest_far, "and rests over the far floor")
	assert_gt(steps.size(), 60, "having passed through many places between")

	# A fight on the lowest floor: every fighter is inside the view at zoom 1.
	var found: bool = false
	for seed_value: int in range(1, SEEDS + 1):
		var low_sim: Simulation = winding_simulation(seed_value)
		var stage_1: LabyrinthLevel = low_sim.labyrinth.level(1)
		var lowest: int = stage_1.floor_y
		var highest: int = stage_1.floor_y
		for tried: LabyrinthChamber in stage_1.chambers:
			lowest = maxi(lowest, tried.floor_row())
			highest = mini(highest, tried.floor_row())
		if lowest - highest < 2 * WindingStage.FLOOR_GAP:
			continue  # a stage of two floors
		var room: LabyrinthChamber = _room(
			stage_1,
			func(tried: LabyrinthChamber) -> bool:
				return (
					tried.floor_row() == lowest and low_sim.expedition.is_populated(1, tried.index)
				)
		)
		if room == null:
			continue
		found = true
		_stand(low_sim, 1, _short_of(stage_1, room), 2)
		assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED, 30), "the party meets them")
		var watched: int = 0
		for i: int in 240:
			_play_frame()
			var battle: Battle = low_sim.expedition.battle
			if battle == null:
				break
			if i < 45:
				continue  # the camera settles on the fight
			watched += 1
			var view := Rect2(_world.camera.position - SCREEN_SIZE / 2.0, SCREEN_SIZE)
			for fighter: Combatant in battle.fighters():
				var sprite: CharacterSprite = _world.character(fighter.id)
				if sprite == null or not fighter.is_alive():
					continue
				var body: Rect2 = SpriteBounds.body_rect(sprite, sprite.position)
				if not view.encloses(body):
					_mark_wrong(
						"seed %d frame %d: fighter %d at %s" % [seed_value, i, fighter.id, body]
					)
		assert_eq(_world.camera.zoom, Vector2.ONE, "at zoom 1")
		assert_gt(watched, 30, "seed %d: the fight was watched" % seed_value)
		break
	assert_true(found, "a seed has monsters on stage 1's lowest floor")
	_assert_nothing_wrong("the whole fight is on screen")

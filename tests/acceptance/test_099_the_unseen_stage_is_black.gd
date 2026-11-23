extends "res://tests/support/dark_stage_fixture.gd"
## Acceptance tests for specs/099-the-unseen-stage-is-black/spec.md, one per requirement:
## everything of a winding stage the party has not seen is black, with eyes and glints in it.
##
## Each test stands a party on a winding stage, shows the world over it and plays frames, the
## ambience moved on with each. The black is read as it is drawn: [method Ambience.brightness_at]
## is the darkness's light times what the veil over the unseen lets through.

## A stage whose way on a guardian holds.
const GUARDIAN_STAGE: int = 5

# --- Helpers -------------------------------------------------------------------


## How bright the world is drawn at the middle of [param rect] (world tiles).
func _bright(rect: Rect2i) -> float:
	return _ambience.brightness_at(_middle(rect))


## The middle of [param rect] (world tiles), in world pixels.
func _middle(rect: Rect2i) -> Vector2:
	return (Vector2(rect.position) + Vector2(rect.size) / 2.0) * TILE


## Every tunnel and ladder of [param level], its side paths' among them.
func _ways(level: LabyrinthLevel) -> Array[Rect2i]:
	var ways: Array[Rect2i] = level.tunnels + level.ladders
	for path: SidePath in level.side_paths:
		ways.append(path.tunnel if path.tunnel.has_area() else path.ladder)
	return ways


## The rectangles of the stage shown that are seen: its lit rooms and the ways touching one.
func _seen_rects() -> Array[Rect2i]:
	var level: LabyrinthLevel = _shown_level()
	var lit: Array[Rect2i] = []
	for room: LabyrinthChamber in level.chambers:
		if _ambience.rooms.is_lit(room.index):
			lit.append(_room_bounds(room))
	for place: int in level.side_paths.size():
		if _ambience.rooms.is_lit(AmbienceRooms.CACHE + place):
			lit.append(_room_bounds(level.side_paths[place].room))
	var seen: Array[Rect2i] = lit.duplicate()
	for way: Rect2i in _ways(level):
		if _touches(way, lit):
			seen.append(way)
	return seen


## The tiles [param room] of the stage shown reaches as drawn: its rectangle and what is opened
## over it.
func _room_bounds(room: LabyrinthChamber) -> Rect2i:
	var shapes: StageShapes = _world.labyrinth_view.shapes(_world.shown_stage())
	var shape: RoomShape = shapes.shape_of(room) if shapes != null else null
	return shape.bounds() if shape != null else room.rect


func _touches(way: Rect2i, rooms: Array[Rect2i]) -> bool:
	for room: Rect2i in rooms:
		if way.grow(1).intersects(room):
			return true
	return false


## How many tiles [param tile] is from the nearest of [param rects], 0 inside one.
func _tiles_from(tile: Vector2i, rects: Array[Rect2i]) -> int:
	var least: int = 1000
	for rect: Rect2i in rects:
		var across: int = maxi(maxi(rect.position.x - tile.x, tile.x - rect.end.x + 1), 0)
		var down: int = maxi(maxi(rect.position.y - tile.y, tile.y - rect.end.y + 1), 0)
		least = mini(least, maxi(across, down))
	return least


## The route room each waiting monster of the stage shown stands in, by its id.
func _waiting_rooms() -> Dictionary[int, int]:
	var rooms: Dictionary[int, int] = {}
	var stage: int = _world.shown_stage()
	for room: int in _shown_level().chambers.size():
		for monster: Combatant in _sim.expedition.monsters_in(stage, room):
			rooms[monster.id] = room
	return rooms


## Makes the cleared room [param room] of the stage shown due to refill now. True if it then
## holds monsters.
func _refill(room: int) -> bool:
	var e: Expedition = _sim.expedition
	var fill: ChamberState = e._chambers.get(Vector2i(_world.shown_stage(), room), null)
	if fill == null or fill.cleared_tick < 0:
		return false
	fill.cleared_tick = _sim.tick - LIMIT_TICKS
	return e.is_populated(_world.shown_stage(), room)


## The eyes showing inside route room [param room], as monster ids.
func _eyes_in(room: int) -> Array[int]:
	var found: Array[int] = []
	var rooms: Dictionary[int, int] = _waiting_rooms()
	for id: int in rooms:
		if rooms[id] == room and _world.eyes.part(id) != &"":
			found.append(id)
	return found


# --- R1 ------------------------------------------------------------------------


## R1: on 3 stages on arrival, the world is drawn black at the middle of every unlit room, of
## every tunnel and ladder touching no lit room, and of every tile 6 tiles or more from anything
## seen; and not black in the party's room, along a way leaving it and in earth a tile from it.
func test_r1_only_what_is_seen_is_not_black() -> void:
	for stage: int in [1, 2, 3]:
		_watch_rooms(_arrived(SEED, stage, stage + 1))
		var what: String = "stage %d" % stage
		var level: LabyrinthLevel = _shown_level()
		var room: int = _party_room()
		assert_eq(room, 0, "%s: the party arrives in the first room" % what)
		assert_true(_ambience.seen.is_on(), "%s: the unseen is black" % what)
		assert_eq(_ambience.seen.fading(), 0, "%s: shown at once" % what)
		var home: Rect2i = level.chambers[room].rect
		assert_gt(_bright(home), 0.0, "%s: the party's room is seen" % what)
		# Earth a tile over the room, at the corner furthest from the party's own light.
		var glow: Vector2 = _ambience.party_light_position
		var above := Rect2i(home.position.x, home.position.y - 1, 1, 1)
		var other_end := Rect2i(home.end.x - 1, home.position.y - 1, 1, 1)
		if _middle(other_end).distance_to(glow) > _middle(above).distance_to(glow):
			above = other_end
		assert_gt(
			_middle(above).distance_to(glow),
			Ambience.PARTY_RADIUS + TILE,
			"%s: a tile of earth by the room, beyond the party's light" % what
		)
		assert_eq(
			_ambience._unveiled(_middle(above)), 1.0, "%s: earth a tile from it is seen" % what
		)
		assert_false(_ambience.hides(_middle(above)), "%s: and not drawn black" % what)
		for other: LabyrinthChamber in level.chambers:
			if other.index != room:
				assert_eq(_bright(other.rect), 0.0, "%s: room %d is black" % [what, other.index])
		for path: SidePath in level.side_paths:
			assert_eq(_bright(path.room.rect), 0.0, "%s: a cache room is black" % what)
		var leaving: int = 0
		var beyond: int = 0
		for way: Rect2i in _ways(level):
			if _touches(way, [home]):
				leaving += 1
				assert_gt(
					_bright(way), 0.0, "%s: the way %s leaving the room is seen" % [what, way]
				)
			else:
				beyond += 1
				assert_eq(_bright(way), 0.0, "%s: the way %s beyond is black" % [what, way])
		assert_gt(leaving, 0, "%s: a way leaves the party's room" % what)
		assert_gt(beyond, 1, "%s: and others touch no lit room" % what)
		var seen: Array[Rect2i] = _seen_rects()
		var light: Vector2 = _ambience.party_light_position
		var far: int = 0
		var lit: int = 0
		for y: int in range(level.band.position.y - 4, level.band.end.y + 4):
			for x: int in range(level.band.position.x, level.band.end.x):
				var at: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
				if _tiles_from(Vector2i(x, y), seen) < 6:
					continue
				if at.distance_to(light) <= Ambience.PARTY_RADIUS + TILE:
					continue
				far += 1
				lit += int(_ambience.brightness_at(at) > 0.0)
		assert_gt(far, 1000, "%s: most of the stage is far from anything seen" % what)
		assert_eq(lit, 0, "%s: and every tile of it is black" % what)
		_world.free()
	_room_opened_upward()
	# A flat stage is as it is.
	var flat := Simulation.new(SEED)
	_watch_rooms(flat)
	assert_false(_ambience.seen.is_on(), "nothing of a flat stage is black")
	var last: LabyrinthChamber = flat.labyrinth.level(1).chambers[-1]
	assert_gt(_bright(last.rect), 0.0, "its far rooms are drawn as they were")


## R1, for a room drawn open above its rectangle: with the party in it, the earth a tile over
## its highest open row is seen as over any room, and the earth 6 tiles over it is black.
func _room_opened_upward() -> void:
	# A room opened 3 rows over its rectangle, and a column of its highest ceiling with no tunnel
	# or ladder near: Vector3i(stage, room, column).
	var found := Vector3i(-1, -1, -1)
	for stage: int in range(2, 9):
		var maze: Labyrinth = winding_labyrinth(SEED)
		var plan: LabyrinthLevel = maze.level(stage)
		var cut: StageShapes = StageShapes.of(
			maze, stage, ZoneLook.of(Content.area_ids()[0], stage)
		)
		for room: LabyrinthChamber in plan.chambers.slice(1, -1):
			var drawn: Rect2i = cut.shape_of(room).bounds()
			if room.rect.position.y - drawn.position.y < 3 or found.x >= 0:
				continue
			var ways: Array[Rect2i] = []
			for way: Rect2i in _ways(plan):
				if _touches(way, [drawn]):
					ways.append(way)
			for column: int in range(drawn.position.x, drawn.end.x):
				var high: bool = cut.shape_of(room).ceiling_row(column) == drawn.position.y
				var ends: int = maxi(column - drawn.position.x, drawn.end.x - 1 - column)
				var clear: bool = _tiles_from(Vector2i(column, drawn.position.y - 1), ways) >= 5
				if high and clear and ends >= 10 and found.x < 0:
					found = Vector3i(stage, room.index, column)
	assert_gt(found.x, 0, "a room opened 3 rows over its rectangle, wide enough to stand aside in")
	if found.x < 0:
		return
	var sim: Simulation = _arrived(SEED, found.x, found.x)
	var level: LabyrinthLevel = sim.labyrinth.level(found.x)
	var tall: LabyrinthChamber = level.chambers[found.y]
	var cleared := ChamberState.new(found.x)
	cleared.cleared_tick = sim.tick
	sim.expedition._chambers[Vector2i(found.x, found.y)] = cleared
	# The party stands at the end of the room furthest from that column.
	var stretch: Vector2 = level.course.stretch_of(found.y)
	var first: Vector2 = level.course.point_at(stretch.x)
	var last: Vector2 = level.course.point_at(stretch.y)
	var from_first: bool = absf(first.x - found.z) > absf(last.x - found.z)
	sim.expedition._place(stretch.x + 0.5 if from_first else stretch.y - 0.5)
	_watch_rooms(sim)
	assert_eq(_party_room(), found.y, "the party stands in it")
	var top: int = _room_bounds(tall).position.y
	assert_lt(top, tall.rect.position.y - 2, "it is drawn open 3 rows over its rectangle")
	var near: Vector2 = (Vector2(found.z, top - 1) + Vector2(0.5, 0.5)) * TILE
	var far: Vector2 = (Vector2(found.z, top - 6) + Vector2(0.5, 0.5)) * TILE
	var glow: Vector2 = _ambience.party_light_position
	assert_gt(near.distance_to(glow), Ambience.PARTY_RADIUS + TILE, "beyond the party's light")
	assert_eq(_ambience._unveiled(near), 1.0, "earth a tile over its highest open row is seen")
	assert_false(_ambience.hides(near), "and not drawn black")
	assert_true(_ambience.hides(far), "earth 6 tiles over it is black")
	assert_eq(_ambience.brightness_at(far), 0.0, "as it is drawn")
	_world.free()


# --- R2 ------------------------------------------------------------------------


## R2: a pair of eyes at each waiting monster of an unseen room, a guardian's of the larger
## part; none in the party's room; a pair shuts and opens within 6 seconds, the pairs not all
## at once.
func test_r2_waiting_monsters_show_eyes() -> void:
	_watch_rooms(_arrived(SEED, GUARDIAN_STAGE, GUARDIAN_STAGE + 1))
	_play_frame(false)
	var eyes: UnseenEyes = _world.eyes
	var rooms: Dictionary[int, int] = _waiting_rooms()
	assert_gt(rooms.size(), 3, "monsters wait on the stage")
	assert_eq(eyes.count(), rooms.size(), "a pair for each of them, and no more")
	assert_gt(eyes.z_index, AmbienceDarkness.VEIL_Z, "drawn over the black")
	assert_lt(eyes.z_index, World.EFFECTS_Z, "and under the effects")
	var large: int = 0
	for id: int in rooms:
		var what: String = "monster %d in room %d" % [id, rooms[id]]
		assert_ne(rooms[id], _party_room(), "%s: none waits in the party's room" % what)
		var guardian: bool = rooms[id] == _shown_level().chambers.size() - 1
		large += int(guardian)
		var part: StringName = UnseenEyes.LARGE if guardian else UnseenEyes.SMALL
		assert_eq(eyes.part(id), part, "%s: its eyes" % what)
		var body: Rect2 = SpriteBounds.body_rect(_world.character(id))
		var at: Vector2 = eyes.place(id)
		assert_true(body.grow(1.0).has_point(at), "%s: on its body" % what)
		assert_lt(at.y, body.get_center().y, "%s: at its head" % what)
		assert_true(_ambience.hides(at), "%s: where the world is black" % what)
	assert_eq(large, 1, "the guardian's are the larger pair")
	var sheet: PixelSheet = PixelSheet.load_sheet(UnseenEyes.SHEET)
	var small: Rect2i = SpriteBounds.opaque(sheet.part(UnseenEyes.SMALL))
	var big: Rect2i = SpriteBounds.opaque(sheet.part(UnseenEyes.LARGE))
	assert_gt(big.size.x * big.size.y, small.size.x * small.size.y, "the larger part is larger")
	# Blinking, each pair in its own time.
	var shut: Dictionary[int, int] = {}
	var opened: Dictionary[int, int] = {}
	var all_shut: int = 0
	for frame: int in roundi(6.0 / STEP):
		_play_frame(false)
		var shut_now: int = 0
		for id: int in rooms:
			if eyes.is_shut(id):
				shut_now += 1
				if not shut.has(id):
					shut[id] = frame
			elif shut.has(id) and not opened.has(id):
				opened[id] = frame
		all_shut += int(shut_now == rooms.size())
	assert_eq(shut.size(), rooms.size(), "every pair shut within 6 seconds")
	assert_eq(opened.size(), rooms.size(), "and opened again")
	assert_eq(all_shut, 0, "never all at once")
	for id: int in opened:
		var took: float = (opened[id] - shut[id]) * STEP
		assert_almost_eq(took, UnseenEyes.SHUT_SECONDS, 0.04, "shut for about 0.15 s")
	# The eyes go as the room is shown.
	_walk_until(func() -> bool: return _party_room() == 1, "the party walks into the next room")
	_play_frame(false)
	var entered: Rect2i = _shown_level().chambers[1].rect
	assert_gt(eyes.count(), 0, "eyes still show further on")
	for id: int in _world._waiting:
		if eyes.part(id) == &"":
			continue
		var at: Vector2 = eyes.place(id)
		assert_true(_ambience.hides(at), "eyes only where it is black")
		assert_false(entered.has_point(Vector2i((at / TILE).floor())), "none in the room entered")


# --- R3 ------------------------------------------------------------------------


## R3: a full cache's and a side quest's glint drawn in an unseen room, over the black; the
## world black at the cache, the quest's prop, a closed gate, an unlit torch and the doorway on
## in unseen places.
func test_r3_glints_show_and_nothing_else() -> void:
	var quest_room: int = -1
	var gated: int = -1
	for seed_value: int in range(1, 60):
		var sim: Simulation = _arrived(seed_value, STAGE, STAGE + 1)
		var level: LabyrinthLevel = sim.labyrinth.level(STAGE)
		quest_room = -1
		gated = -1
		for room: int in range(2, level.chambers.size()):
			if sim.expedition.side_quest_in(STAGE, room) != &"" and quest_room < 0:
				quest_room = room
		for place: int in level.side_paths.size():
			if _room_of(level, level.side_paths[place]) > 0:
				gated = place
		if quest_room >= 0 and gated >= 0:
			_watch_rooms(sim)
			break
	assert_true(quest_room > 0 and gated >= 0, "a stage with a quest and a gate past its start")
	if quest_room < 0 or gated < 0:
		return
	var quests: QuestProps = _world.quest_props
	var side: SideProps = _world.side_props
	var prop: Sprite2D = quests.prop(STAGE, quest_room)
	assert_not_null(prop, "the quest's prop stands in its room")
	assert_true(quests.is_glinting(STAGE, quest_room), "and glints")
	var seen: Dictionary[StringName, bool] = _glints_seen(quests.glint_part.bind(STAGE, quest_room))
	assert_true(seen.has(&"small") and seen.has(&"big"), "its glint swells: %s" % [seen.keys()])
	assert_true(side.is_glinting(STAGE, gated), "a full cache glints")
	seen = _glints_seen(side.glint_part.bind(STAGE, gated))
	assert_true(seen.has(&"small") and seen.has(&"big"), "its glint swells: %s" % [seen.keys()])
	for glints: Node in _world.find_children("Glints", "PropGlints", true, false):
		var drawn: PropGlints = glints as PropGlints
		assert_gt(drawn.z_index, AmbienceDarkness.VEIL_Z, "a glint is drawn over the black")
		assert_false(drawn.z_as_relative, "whatever it is a child of")
	# Nothing else shows there.
	assert_eq(_ambience.brightness_at(prop.position - Vector2(0, 6)), 0.0, "the prop is black")
	var cache: Vector2 = side.cache_spot(STAGE, gated) - Vector2(0, 6)
	assert_eq(_ambience.brightness_at(cache), 0.0, "the cache is black")
	var gate: Sprite2D = side.gate(STAGE, gated)
	assert_eq(SideProps.part_of(gate), &"closed", "the gate is closed")
	var gate_at: Vector2 = SideProps._rect_of(gate).get_center()
	assert_eq(_ambience.brightness_at(gate_at), 0.0, "a closed gate in an unseen place is black")
	var doors: Array[Rect2] = _world.labyrinth_view.doorways(STAGE)
	assert_gt(doors.size(), 1, "the doorway on among the stage's")
	var black_doors: int = 0
	for door: Rect2 in doors:
		black_doors += int(_ambience.brightness_at(door.get_center()) == 0.0)
	assert_eq(black_doors, doors.size() - 1, "every doorway but the party's is black")
	var torches: int = 0
	for torch: AmbienceProp in _ambience.level(STAGE).torches:
		if torch.chamber != 0:
			torches += 1
			assert_false(torch.lit, "a torch of an unseen room is out")
			assert_eq(_ambience.brightness_at(torch.rect.get_center()), 0.0, "and black")
	assert_gt(torches, 3, "torches in unseen rooms")
	# The marker over the party and the effects are drawn over the black.
	assert_gt(_world.target_marker.z_index, AmbienceDarkness.VEIL_Z, "the target arrow is over it")
	assert_gt(_world.effects_layer.z_index, AmbienceDarkness.VEIL_Z, "and so are the effects")


# --- R4 ------------------------------------------------------------------------


## R4: walking into the next room, its middle, a way beyond it and the earth a tile round it go
## from black to their rest within 0.5 s, through steps between; an arrival shows at once.
func test_r4_a_room_is_shown_as_the_party_enters() -> void:
	var found: Vector3i = _widest_room(20)
	var sim: Simulation = _arrived(found.x, STAGE, STAGE + 1)
	var level: LabyrinthLevel = sim.labyrinth.level(STAGE)
	var room: Rect2i = level.chambers[found.y].rect
	sim.expedition._place(level.course.stretch_of(found.y).x - 1.5)
	sim.expedition.facing = 1
	_watch_rooms(sim)
	assert_ne(_party_room(), found.y, "the party starts outside the room")
	assert_eq(_ambience.seen.fading(), 0, "an arrival fades nothing")
	var from: Vector2 = PartyPlaces.anchor(sim.expedition) * TILE
	var beyond := Rect2i()
	for way: Rect2i in _ways(level):
		if not _touches(way, [room]):
			continue
		if (
			not beyond.has_area()
			or _middle(way).distance_to(from) > _middle(beyond).distance_to(from)
		):
			beyond = way
	assert_true(beyond.has_area(), "a way leads on from the room")
	var earth := Rect2i(room.position.x + room.size.x / 2, room.position.y - 1, 1, 1)
	var spots: Array[Rect2i] = [room, beyond, earth]
	var names: Array[String] = ["the room's middle", "the way beyond", "the earth round it"]
	var entered: int = -1
	var steps: Dictionary[float, bool] = {}
	var rest: Array[int] = [-1, -1, -1]
	for frame: int in 1800:
		if entered < 0:
			for i: int in spots.size():
				assert_eq(_bright(spots[i]), 0.0, "%s is black before the party is in" % names[i])
		_play_frame()
		if entered < 0 and _party_room() == found.y:
			entered = frame
		if entered < 0:
			continue
		for i: int in spots.size():
			var kept: float = _ambience._unveiled(_middle(spots[i]))
			if i == 0:
				steps[snappedf(kept, 0.01)] = true
			if rest[i] < 0 and kept >= 1.0 and _bright(spots[i]) > 0.0:
				rest[i] = frame
		if frame > entered + 60:
			break
	assert_gt(entered, 0, "the party walked into the room")
	for i: int in spots.size():
		assert_gt(rest[i], -1, "%s comes out of the black" % names[i])
		var took: float = (rest[i] - entered) * STEP
		assert_between(took, 0.1, 0.5, "%s: within 0.5 s, and not at once" % names[i])
	assert_gt(steps.size(), 2, "the black leaves in steps: %s" % [steps.keys()])
	assert_eq(_ambience.seen.fading(), 0, "and nothing is fading after it")
	assert_true(_ambience.rooms.is_lit(found.y), "the room is lit")


# --- R5 ------------------------------------------------------------------------


## R5: a room cleared and left, then its refill tick passed: its torches go out in turn, its
## middle is black within 0.8 s, it shows eyes, and walking back in lights it again with a
## flare; the party's own room refilling under it does not go black, and the monsters waiting
## in it, a seen place, have no eyes; a cache room stays seen.
func test_r5_a_refilled_room_goes_black() -> void:
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1), 4)
	var level: LabyrinthLevel = _shown_level()
	var e: Expedition = _sim.expedition
	var here: int = 0
	var back: int = -1
	var refilled: int = -1
	var played: int = 0
	var torches: Array[AmbienceProp] = []
	var out: Dictionary[AmbienceProp, int] = {}
	var black: int = -1
	var forgotten: int = -1
	# The party fights on in each room in turn until the room behind it refills, and with monsters.
	for room: int in range(2, level.chambers.size() - 1):
		_walk_until(_settled_in.bind(room), "the party walks to room %d" % room)
		here = room
		if _torch_count(room - 1) < 2 or not _ambience.rooms.is_lit(room - 1):
			_walk_until(func() -> bool: return e.battle == null, "the fight in it ends")
			continue
		assert_not_null(e.battle, "the party fights in room %d" % room)
		var behind: Rect2i = level.chambers[room - 1].rect
		torches = _torches_of(room - 1)
		for wait: int in 900:
			if refilled < 0:
				assert_gt(_bright(behind), 0.0, "the room behind is seen until it refills")
				_held_frame()
			else:
				_play_frame()
			played += 1
			if refilled < 0 and e.side_quest_in(STAGE, room - 1) != &"":
				break
			if refilled < 0 and e.is_populated(STAGE, room - 1):
				refilled = played
				back = room - 1
			if refilled < 0:
				continue
			if forgotten < 0 and not _ambience.rooms.is_lit(back):
				forgotten = played
			for torch: AmbienceProp in torches:
				if not torch.lit and not out.has(torch):
					out[torch] = played
			if black < 0 and _bright(behind) == 0.0:
				black = played
			if played - refilled >= 90:
				break
		if back >= 0:
			break
		_walk_until(func() -> bool: return e.battle == null, "the fight in it ends")
	assert_gt(back, 0, "a room behind the party refills with monsters")
	if back < 0:
		return
	var rect: Rect2i = level.chambers[back].rect
	assert_false(_ambience.rooms.is_lit(back), "the room is forgotten")
	assert_gt(forgotten, 0, "while the test watched")
	assert_lt((forgotten - refilled) * STEP, 0.2, "as soon as it refills")
	assert_eq(out.size(), torches.size(), "every torch of it went out")
	var times: Array = out.values()
	times.sort()
	for i: int in range(1, times.size()):
		var gap: float = (times[i] - times[i - 1]) * STEP
		assert_almost_eq(gap, AmbienceRooms.GUTTER_GAP, 0.035, "one about 0.15 s after another")
	assert_lt((black - refilled) * STEP, 0.8, "its middle is black within 0.8 s of the refill")
	assert_gt((black - forgotten) * STEP, 0.3, "the black closes over it, not at once")
	assert_eq(_ambience.seen.fading(), 0, "the black has closed")
	assert_gt(_eyes_in(back).size(), 0, "it shows eyes")
	assert_eq(_party_room(), here, "the party is still in its room")
	assert_true(_ambience.rooms.is_lit(here), "which is still lit")
	# The party's own room refilling under it does not go black, and shows no eyes.
	_walk_until(func() -> bool: return e.battle == null, "the fight in the party's room ends")
	assert_eq(_party_room(), here, "the party is still in its room")
	assert_true(_refill(here), "the party's room holds monsters again too")
	for i: int in 60:
		_play_frame(false)
	assert_true(_ambience.rooms.is_lit(here), "the room the party stands in stays lit")
	assert_gt(_bright(level.chambers[here].rect), 0.0, "and seen")
	var under: int = 0
	var rooms: Dictionary[int, int] = _waiting_rooms()
	for id: int in rooms:
		if rooms[id] != here:
			continue
		under += 1
		assert_true(_world._waiting.has(id), "monster %d waits in the party's room" % id)
		assert_not_null(_world.character(id), "monster %d stands there" % id)
		assert_eq(_world.eyes.part(id), &"", "monster %d, in a seen place, has no eyes" % id)
	assert_gt(under, 0, "monsters wait in the party's room")
	assert_gt(_eyes_in(back).size(), 0, "while those in the black room keep theirs")
	# Walking back in lights it again, with a flare.
	_sim.set_target_depth(STAGE - 1)
	var flared: Array[int] = [0]
	_walk_until(
		func() -> bool:
			var there: bool = _party_room() == back
			flared[0] += _ambience.rooms.flares() if there else 0
			return there and _ambience.rooms.flares() == 0 and _ambience.seen.fading() == 0,
		"the party walks back into it"
	)
	assert_gt(flared[0], 0, "its torches catch again with a flare")
	assert_true(_ambience.rooms.is_lit(back), "it is lit again")
	assert_gt(_bright(rect), 0.0, "and seen")
	_world.free()
	# A cache room, which never holds monsters, stays seen once seen.
	var found: Vector2i = _find(STAGE, true)
	var sim: Simulation = winding_simulation(found.x)
	sim.set_auto_push(false)
	set_party_level(sim, 12)
	var path: SidePath = _stand_before(sim, STAGE, found.y, 1)
	_watch_rooms(sim, 4)
	var cache: int = AmbienceRooms.CACHE + found.y
	assert_eq(_bright(path.room.rect), 0.0, "a cache room not entered is black")
	_walk_until(
		func() -> bool: return _sim.expedition.side_path >= 0 and path.in_room(_sim.expedition.x),
		"the party walks into the cache room"
	)
	_walk_until(func() -> bool: return _sim.expedition.side_path < 0, "and out again")
	for frame: int in 120:
		_hurry()
		_play_frame()
	assert_true(_ambience.rooms.is_lit(cache), "the cache room stays lit")
	assert_gt(_bright(path.room.rect), 0.0, "and seen")


func _torches_of(room: int) -> Array[AmbienceProp]:
	var found: Array[AmbienceProp] = []
	for torch: AmbienceProp in _ambience.level(_world.shown_stage()).torches:
		if torch.chamber == room:
			found.append(torch)
	return found


func _torch_count(room: int) -> int:
	return _torches_of(room).size()


## A frame in which the fight the party is in does not end: everyone whole before each tick.
func _held_frame() -> void:
	if _frames_played % FRAMES_PER_TICK == 0:
		for i: int in maxi(_world.speed, 1):
			_hold_fight()
			_sim.step()
	_play_frame(false)


func _hold_fight() -> void:
	var e: Expedition = _sim.expedition
	if e.battle != null:
		for monster: Combatant in e.battle.monsters:
			if monster.is_alive():
				monster.health = monster.max_health
	for hero: Hero in _sim.party.heroes:
		if hero.is_alive():
			hero.health = hero.max_health()


# --- R6 ------------------------------------------------------------------------


## R6: the gate's tip shows for a gate in a seen place and not for one in an unseen place.
func test_r6_no_tip_for_an_unseen_gate() -> void:
	var gated := Vector2i(-1, -1)
	for seed_value: int in range(1, 60):
		var level: LabyrinthLevel = winding_labyrinth(seed_value).level(STAGE)
		for place: int in level.side_paths.size():
			if _room_of(level, level.side_paths[place]) > 0 and gated.x < 0:
				gated = Vector2i(seed_value, place)
	assert_gt(gated.x, 0, "a gate past the room the party arrives in")
	if gated.x < 0:
		return
	_watch_rooms(_arrived(gated.x, STAGE, STAGE + 1))
	var side: SideProps = _world.side_props
	side.follows_mouse = false
	var gate: Sprite2D = side.gate(STAGE, gated.y)
	assert_eq(SideProps.part_of(gate), &"closed", "the gate is closed")
	var at: Vector2 = SideProps._rect_of(gate).get_center()
	assert_true(_ambience.hides(at), "the gate stands in the black")
	side.point_at(at)
	assert_false(side.tip.visible, "no tip for a gate the party has not seen")
	for frame: int in 30:
		_play_frame(false)
		assert_false(side.tip.visible, "nor while the mouse stays on it")
	_world.free()
	# The same gate, the party standing in the room it leaves.
	var sim: Simulation = winding_simulation(gated.x)
	sim.set_auto_push(false)
	_keep_unskilled(sim)
	_stand_before(sim, STAGE, gated.y, 1)
	_watch_rooms(sim)
	side = _world.side_props
	side.follows_mouse = false
	gate = side.gate(STAGE, gated.y)
	assert_eq(SideProps.part_of(gate), &"closed", "the gate is closed")
	assert_false(_ambience.hides(at), "the gate stands in a seen place")
	side.point_at(at)
	assert_true(side.tip.visible, "its tip shows")
	assert_ne(side.tip.title, "", "with its words")


# --- R7 ------------------------------------------------------------------------


## R7: a stall in which a lit room refills and the party walks on: after it that room is black,
## the party's room and the rooms lit before are seen, the rooms passed are black, and nothing
## fades, flares or gutters.
func test_r7_nothing_fades_for_the_past() -> void:
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1), 4)
	var level: LabyrinthLevel = _shown_level()
	var behind: int = -1
	for room: int in range(1, level.chambers.size() - 3):
		_walk_until(_settled_in.bind(room + 1), "the party walks to room %d" % (room + 1))
		if _refill(room):
			behind = room
			break
	assert_gt(behind, 0, "a room behind the party is due to refill with monsters")
	if behind < 0:
		return
	# The stall begins before the world has seen the room refill.
	var lit_before: Array[int] = []
	for room: int in level.chambers.size():
		if _ambience.rooms.is_lit(room):
			lit_before.append(room)
	assert_true(lit_before.has(behind), "it was lit before the stall")
	var goal: int = behind + 3
	var before: int = _sim.tick
	for i: int in LIMIT_TICKS_10_MIN:
		if _party_room() == goal:
			break
		_hurry()
		_sim.step()
	assert_eq(_party_room(), goal, "the party walked on unseen")
	assert_gt(_sim.tick - before, World.STALL_TICKS * _world.speed, "a stall to the world")
	_refill(behind)
	assert_true(_sim.expedition.is_populated(STAGE, behind), "the room behind holds monsters")
	_world.sync(STEP)
	assert_true(_world.catching_up(), "the world catches up")
	_ambience.advance(STEP)
	var rooms: AmbienceRooms = _ambience.rooms
	var seen: AmbienceSeen = _ambience.seen
	assert_eq([seen.fading(), rooms.flares(), rooms.gutters()], [0, 0, 0], "nothing is running")
	assert_false(rooms.is_lit(behind), "the refilled room is forgotten")
	assert_eq(_bright(level.chambers[behind].rect), 0.0, "and black at once")
	for torch: AmbienceProp in _torches_of(behind):
		assert_false(torch.lit, "its torches are out at once")
	assert_true(rooms.is_lit(goal), "the party's room is lit")
	assert_gt(_bright(level.chambers[goal].rect), 0.0, "and seen at once")
	for room: int in level.chambers.size():
		if room == behind or room == goal:
			continue
		var what: String = "room %d" % room
		var kept: bool = lit_before.has(room) and not _sim.expedition.is_populated(STAGE, room)
		assert_eq(rooms.is_lit(room), kept, "%s: lit only if it was, and has not refilled" % what)
		assert_eq(_bright(level.chambers[room].rect) > 0.0, kept, "%s: seen only then" % what)
	assert_true(rooms.is_lit(0), "the room the party arrived in is still lit")
	for i: int in 30:
		_play_frame(false)
		assert_eq(
			[seen.fading(), rooms.flares(), rooms.gutters()],
			[0, 0, 0],
			"and nothing starts after it"
		)


# --- R8 ------------------------------------------------------------------------


## R8: over idle frames with eyes blinking, the darkness is not redrawn but for a light's own
## flicker, and what it is told of seen places is the same object, unchanged and never remade.
func test_r8_an_idle_frame_does_nothing() -> void:
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1))
	for i: int in 120:
		_play_frame(false)  # the camera comes to rest
	var darkness: AmbienceDarkness = _ambience._darkness
	var seen: AmbienceSeen = _ambience.seen
	var map: Texture2D = darkness.seen
	assert_not_null(map, "the darkness is told of the seen places")
	assert_true(is_same(map, seen.texture), "the memory's own map")
	var pixels: PackedByteArray = map.get_image().get_data()
	var composed: int = seen.changes
	var lights: Array[AmbienceLight] = _handed()
	var eyes: UnseenEyes = _world.eyes
	assert_gt(eyes.count(), 0, "eyes show in the black")
	var blinks: int = eyes.redraws
	var quiet: int = 0
	var quiet_blinks: int = 0
	for i: int in 360:
		var shapes: Array[Vector4] = _shapes(lights)
		var view: Rect2 = _ambience._visible_rect()
		var redraws: int = darkness.redraws
		var blinked: int = eyes.redraws
		_play_frame(false)
		assert_true(is_same(darkness.seen, map), "the darkness holds the same map")
		assert_eq(seen.changes, composed, "which is not remade")
		if _shapes(lights) == shapes and _ambience._visible_rect() == view:
			quiet += 1
			quiet_blinks += int(eyes.redraws != blinked)
			assert_eq(darkness.redraws, redraws, "frame %d: nothing moved, nothing redrawn" % i)
	assert_eq(map.get_image().get_data(), pixels, "the map's pixels are unchanged")
	assert_gt(quiet, 180, "most idle frames move nothing")
	assert_gt(eyes.redraws - blinks, 3, "the eyes blinked")
	assert_gt(quiet_blinks, 0, "and a blink redrew no darkness")
	assert_eq(seen.fading(), 0, "nothing was fading")
	_world.free()
	# A lit room behind the party whose side quest waits: the simulation is not asked about it.
	var quest := Vector2i(-1, -1)
	for seed_value: int in range(1, 60):
		var sim: Simulation = _arrived(seed_value, STAGE, STAGE + 1)
		for room: int in range(1, sim.labyrinth.level(STAGE).chambers.size() - 2):
			var id: StringName = sim.expedition.side_quest_in(STAGE, room)
			if id != &"" and Content.side_quest(id).miss_damage <= 0.0 and quest.x < 0:
				quest = Vector2i(seed_value, room)
	assert_gt(quest.x, 0, "a stage with a side quest that stays when nobody can do it")
	if quest.x < 0:
		return
	_watch_rooms(_arrived(quest.x, STAGE, STAGE + 1), 4)
	_walk_until(_settled_in.bind(quest.y + 1), "the party walks past the quest's room")
	var e: Expedition = _sim.expedition
	var rooms: AmbienceRooms = _ambience.rooms
	assert_true(rooms.is_lit(quest.y), "the quest's room is lit")
	assert_ne(e.side_quest_in(STAGE, quest.y), &"", "and its quest still waits")
	var asked: int = rooms.questions
	for i: int in 240:
		_play_frame(false)
	assert_eq(rooms.questions, asked, "idle frames ask the simulation nothing")
	# Nor in most of a minute of the game played on, but as a room is left or due to refill.
	for i: int in 600:
		_held_frame()
	assert_eq(_world.shown_stage(), STAGE, "the party is still on the stage")
	assert_true(rooms.is_lit(quest.y), "the quest's room is still lit")
	assert_ne(e.side_quest_in(STAGE, quest.y), &"", "its quest still waiting")
	var most: int = _shown_level().chambers.size() * 5
	assert_lt(rooms.questions - asked, most, "a room is asked about only as it can have refilled")

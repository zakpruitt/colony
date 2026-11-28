extends "res://tests/support/side_path_fixture.gd"
## Spec 093: side paths off a winding stage's main route, each closed by a gate one microskill
## opens and ending in a cache room; the party takes every one it can open.

const WINDING: Labyrinth.Shape = Labyrinth.Shape.WINDING
const SEEDS: int = 40
const STAGES: int = 12
const TICKS: int = Simulation.TICKS_PER_SECOND
## R4 and R5's numbers.
const GOLD_KILLS: float = 6.0
const XP_KILLS: float = 3.0
const DROPS: int = 3
const REFILL_SECONDS: float = 600.0
## The main route of 20 seeds and 6 stages, recorded on the code before this spec.
const ROUTE_HASH: String = "cacbae58e5bbc4fe8db95b903945d3e775fac9db988ffd8542cd50e789a3cd63"
## The state hash after ten minutes of a winding run whose heroes never learn a microskill, by
## seed, recorded on the code before this spec.
const QUIET_HASHES: Dictionary[int, int] = {3: 2935288348, 8: 1884139367}
const QUIET_TICKS: int = 6000
## The keys of a save before this spec, the side path order spec 096 added and the bench and
## artifacts spec 112 added.
const SAVE_KEYS: Array[String] = [
	"area",
	"areas",
	"artifacts",
	"auto_buy",
	"auto_push",
	"bench",
	"deepest_depth",
	"gold",
	"guardian_order",
	"guardians_beaten",
	"heroes",
	"last_stable_depth",
	"open_areas",
	"pace",
	"resources",
	"seed",
	"side_paths",
	"target_depth",
	"tick",
	"upgrades",
	"version",
]
## A level at which every hero has every microskill of its class.
const SKILLED: int = 12

# --- R1 ------------------------------------------------------------------------


## R1: every winding stage has 1 to 3 side paths, each from a room of its own between the first
## and the last, by a ladder or a tunnel of its own to a cache room nothing else joins.
func test_r1_every_winding_stage_has_side_paths_that_fit() -> void:
	var counts: Dictionary[int, int] = {}
	var tunnels: int = 0
	var ladders: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var maze: Labyrinth = winding_labyrinth(seed_value)
		var flat := Labyrinth.new(seed_value)
		for depth: int in range(1, STAGES + 1):
			var level: LabyrinthLevel = maze.level(depth)
			var where: String = "seed %d stage %d" % [seed_value, depth]
			var count: int = level.side_paths.size()
			counts[count] = counts.get(count, 0) + 1
			if count < 1 or count > MOST_PATHS:
				_wrong.append("%s: %d side paths" % [where, count])
			if not flat.level(depth).side_paths.is_empty():
				_wrong.append("%s: a flat level has a side path" % where)
			if not flat.level(depth).side_rects().is_empty():
				_wrong.append("%s: a flat level has side rectangles" % where)
			var rooms_used: Dictionary[int, bool] = {}
			var before: float = -INF
			for index: int in count:
				var path: SidePath = level.side_paths[index]
				var what: String = "%s path %d" % [where, index]
				tunnels += int(_is_tunnel(path))
				ladders += int(not _is_tunnel(path))
				var from: int = _room_of(level, path)
				if from < 1 or from > level.chambers.size() - 2:
					_wrong.append("%s: leaves room %d" % [what, from])
					continue
				if rooms_used.has(from):
					_wrong.append("%s: a second gate in room %d" % [what, from])
				rooms_used[from] = true
				if path.at <= before:
					_wrong.append("%s: not in the order the course passes them" % what)
				before = path.at
				_check_path(level, path, level.chambers[from], what)
			_check_earth(level, where)
			if level.side_rects().size() != 2 * count or level.side_ladders().size() > count:
				_wrong.append("%s: %d side rectangles" % [where, level.side_rects().size()])
	_nothing_wrong("every side path fits")
	assert_false(counts.has(0), "no stage of these is without a side path")
	assert_gt(tunnels, 100, "side paths by a tunnel are seen")
	assert_gt(ladders, 100, "and side paths by a ladder")

	# A level's side paths are its seed, its area and its stage.
	var forward: Labyrinth = winding_labyrinth(11)
	var backward: Labyrinth = winding_labyrinth(11)
	var label: String = AreaTravel.label(Content.area_ids()[1])
	var away: Labyrinth = winding_labyrinth(11, label)
	for depth: int in range(STAGES, 0, -1):
		backward.level(depth)
	for depth: int in range(1, STAGES + 1):
		var signature: Array = _side_signature(forward.level(depth))
		assert_eq(_side_signature(backward.level(depth)), signature, "asked backward: %d" % depth)
		assert_ne(_side_signature(away.level(depth)), signature, "another area's: %d" % depth)
		assert_ne(
			_side_signature(winding_labyrinth(12).level(depth)), signature, "a seed's: %d" % depth
		)
	var sim: Simulation = winding_simulation(11)
	assert_eq(
		_side_signature(sim.labyrinth.level(3)),
		_side_signature(forward.level(3)),
		"a simulation's stage has the seed's side paths"
	)


## R1: the main route of every level is what it was before this spec.
func test_r1_the_main_route_is_unchanged() -> void:
	var parts: Array = []
	for seed_value: int in range(1, 21):
		var maze: Labyrinth = winding_labyrinth(seed_value)
		for depth: int in range(1, 7):
			var level: LabyrinthLevel = maze.level(depth)
			parts.append([level.depth, level.band, level.floor_y, level.tunnels, level.ladders])
			parts.append(level.open_rects())
			for room: LabyrinthChamber in level.chambers:
				parts.append([room.index, int(room.kind), room.rect])
			var line: StageCourse = level.course
			parts.append([line.start, line.end, line.entry, line.exit])
			for half: int in range(roundi(line.start * 2.0), roundi(line.end * 2.0) + 1):
				parts.append([line.point_at(half / 2.0), line.chamber_at(half / 2.0)])
			assert_gt(level.side_paths.size(), 0, "the levels hashed have side paths")
	assert_eq(var_to_str(parts).sha256_text(), ROUTE_HASH, "the main routes are what they were")


## R1: the zoned view cuts the side paths out of the earth and draws their ladders, and a hero
## sent down one is in the open at every frame.
func test_r1_the_view_cuts_the_side_paths() -> void:
	var maze: Labyrinth = winding_labyrinth(5)
	var ladder_tiles: int = 0
	for stage: int in range(1, 6):
		var level: LabyrinthLevel = maze.level(stage)
		var view: LabyrinthView = zoned_view(maze, stage)
		var where: String = "stage %d" % stage
		assert_gt(level.side_rects().size(), 0, "%s has side paths" % where)
		# A cache room is cut to a shape (spec 100): its open tiles are its shape's, in the shape's
		# bounds, and so is its rectangle in open_rects_near.
		var cut: Dictionary[Rect2i, RoomShape] = {}
		for path: SidePath in level.side_paths:
			cut[path.room.rect] = view.shapes(stage).shape_of(path.room)
		for rect: Rect2i in level.side_rects():
			var shape: RoomShape = cut.get(rect)
			var reach: Rect2i = shape.bounds() if shape != null else rect
			for y: int in range(reach.position.y, reach.end.y):
				for x: int in range(reach.position.x, reach.end.x):
					var tile := Vector2i(x, y)
					if shape != null and not shape.is_open(tile):
						continue
					var drawn: PackedStringArray = view.visuals_at(tile)
					if not view.is_open(tile):
						_wrong.append("%s: %s is not open" % [where, tile])
					elif drawn.is_empty() or not drawn[0].contains("/back_"):
						_wrong.append("%s: %s is drawn as earth" % [where, tile])
		var near: Array[Rect2i] = view.open_rects_near(stage)
		for rect: Rect2i in level.side_rects():
			var shape: RoomShape = cut.get(rect)
			if not near.has(shape.bounds() if shape != null else rect):
				_wrong.append("%s: open_rects_near leaves %s out" % [where, rect])
		for ladder: Rect2i in level.side_ladders():
			for y: int in range(ladder.position.y - 1, ladder.end.y):
				for x: int in range(ladder.position.x, ladder.end.x):
					ladder_tiles += 1
					var side: String = "left" if x == ladder.position.x else "right"
					var want: String = ("top_" if y < ladder.position.y else "") + side
					var part: String = ""
					for visual: String in view.visuals_at(Vector2i(x, y)):
						if visual.begins_with("ladder/"):
							part = visual.get_slice("/", 1)
					if part != want:
						_wrong.append("%s: %s on the ladder at (%d, %d)" % [where, part, x, y])
		view.free()
	assert_gt(ladder_tiles, 0, "a side ladder was looked at")
	_nothing_wrong("the side paths are cut out and their ladders drawn")

	for tunnel: bool in [false, true]:
		var found: Vector2i = _find(1, tunnel)
		var sim: Simulation = winding_simulation(found.x)
		raise_party(sim, SKILLED)
		var level: LabyrinthLevel = sim.labyrinth.level(1)
		var path: SidePath = _stand_before(sim, 1, found.y, 1)
		_show(sim)
		var e: Expedition = sim.expedition
		var what: String = "seed %d, by a %s" % [found.x, "tunnel" if tunnel else "ladder"]
		var in_cache: Dictionary[int, bool] = {}
		var on_ladder: Dictionary[int, bool] = {}
		var went: bool = false
		var back_for: int = 0
		var cache_px := Rect2(path.room.rect.position * TILE, path.room.rect.size * TILE)
		for frame: int in 60 * 60:
			_play_frame()
			went = went or e.side_path == found.y
			back_for += int(went and e.side_path < 0)
			for hero: Hero in sim.party.heroes:
				var at: Vector2 = _world.character(hero.id).position
				var row: int = ceili((at.y - World.SETTLE) / TILE) - 1
				var tile := Vector2i(floori(at.x / TILE), row)
				if not _world.labyrinth_view.is_open(tile) and _wrong.size() < 6:
					_wrong.append("%s: hero %d in the earth at %s" % [what, hero.id, at])
				if cache_px.grow(0.5).has_point(at - Vector2(0.0, 1.0)):
					in_cache[hero.id] = true
				var top: float = path.ladder.position.y * TILE
				if at.y > top + 0.5 and at.y < path.ladder.end.y * TILE - 0.5:
					var rung: float = (path.ladder.position.x + 1.0) * TILE
					on_ladder[hero.id] = true
					if absf(at.x - rung) > 0.5 and _wrong.size() < 6:
						_wrong.append("%s: hero %d off the ladder at %s" % [what, hero.id, at])
			if back_for > 60 or e.state != Expedition.State.TRAVELLING and back_for > 0:
				break
		assert_true(went and back_for > 0, "%s: the party went down the side path and back" % what)
		assert_eq(in_cache.size(), 4, "%s: every hero was seen in the cache room" % what)
		if not tunnel:
			assert_eq(on_ladder.size(), 4, "%s: every hero was seen on its ladder" % what)
		assert_true(_in_the_open(level, e.hero_position(1)), "%s: and stands in the open" % what)
	_nothing_wrong("a hero on a side path is in the open, and in its ladder's column")


# --- R2 ------------------------------------------------------------------------


## R2: the four gates are data, each opened by a real microskill, and each closes its share of
## the side paths.
func test_r2_gates_are_data() -> void:
	var ids: Array[StringName] = Content.gate_ids()
	var expected: Array[StringName] = GATES.keys()
	expected.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(ids, expected, "the four gates, sorted")
	for id: StringName in GATES:
		var def: GateDef = Content.gate(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.key(), id, "%s is found by its id" % id)
		assert_eq(def.microskill, GATES[id], "%s is opened by %s" % [id, GATES[id]])
		assert_not_null(Content.microskill(def.microskill), "%s names a real microskill" % id)
		assert_ne(def.display_name, "", "%s has a name" % id)
		assert_ne(def.description, "", "%s has a description" % id)
		assert_between(def.work_seconds, 3.0, 6.0, "%s takes 3 to 6 seconds" % id)
		assert_eq(def.validate().size(), 0, "%s is valid" % id)
	assert_null(Content.gate(&"portcullis"), "an unknown gate is null")

	var broken := GateDef.new()
	broken.id = &"broken"
	broken.display_name = "Broken"
	broken.description = "A gate that cannot be"
	broken.microskill = &"juggling"
	broken.work_seconds = 9.0
	var problems: PackedStringArray = broken.validate()
	assert_has(problems, "microskill juggling does not exist")
	assert_has(problems, "work_seconds 9.0 is outside 3.0 to 6.0")
	broken.microskill = &""
	broken.display_name = ""
	problems = broken.validate()
	assert_has(problems, "microskill is empty")
	assert_has(problems, "display_name is empty")

	var seen: Dictionary[StringName, int] = {}
	var paths: int = 0
	var seed_value: int = 0
	while paths < 400 and seed_value < 100:
		seed_value += 1
		var maze: Labyrinth = winding_labyrinth(seed_value)
		for depth: int in range(1, 9):
			for path: SidePath in maze.level(depth).side_paths:
				paths += 1
				seen[path.gate] = seen.get(path.gate, 0) + 1
	assert_gte(paths, 400, "400 side paths were looked at")
	for id: StringName in GATES:
		var closed: int = seen.get(id, 0)
		var share: float = float(closed) / paths
		assert_between(share, 0.15, 0.35, "%s closes about a quarter of them" % id)


# --- R3 ------------------------------------------------------------------------


## R3: a party with the skill turns off, stops at the gate, the right hero works the right time,
## it walks in, opens the cache, comes back and goes on the way it was going; from both
## directions, by a ladder and by a tunnel.
func test_r3_the_party_opens_a_gate_and_comes_back() -> void:
	for tunnel: bool in [false, true]:
		for way: int in [1, -1]:
			var found: Vector2i = _find(1, tunnel)
			var sim: Simulation = winding_simulation(found.x)
			raise_party(sim, SKILLED)
			var kind: String = "tunnel" if tunnel else "ladder"
			_one_trip(sim, found.y, way, "seed %d by a %s going %d" % [found.x, kind, way])
	_nothing_wrong("the heroes stand in the open all along a side path")

	# On its way to another stage the party takes the side path it comes by, then goes on.
	var ahead: Vector2i = _find(1, false)
	var going: Simulation = winding_simulation(ahead.x)
	raise_party(going, SKILLED)
	_stand_before(going, 1, ahead.y, 1)
	going.set_target_depth(2)
	var run: Expedition = going.expedition
	var on_the_way: Array[SimEvent] = _events_until(
		going, func() -> bool: return run.depth == 2, 6000
	)
	assert_eq(run.target_depth, 2, "the party was sent to stage 2")
	var taken: bool = false
	for event: SimEvent in _of_kind(on_the_way, SimEvent.Kind.CACHE_OPENED):
		taken = taken or event.amount == ahead.y
	assert_true(taken, "and opened the cache it came by on stage 1 before it went on")
	assert_false(SidePathRules.is_full(run, 1, ahead.y), "which is empty behind it")


## R3: a party that is not moving along the course (stood at the doorway it leaves by, as a
## loaded game whose target is below its safe stage) turns onto no side path and is told of no
## gate, wherever on the stage they are.
func test_r3_a_party_standing_still_takes_no_side_path() -> void:
	for skilled: bool in [true, false]:
		var what: String = "skilled" if skilled else "unskilled"
		var sim: Simulation = winding_simulation(4)
		var e: Expedition = sim.expedition
		if skilled:
			raise_party(sim, SKILLED)
		Arrival.from_save(e, sim.tick, 3, 3, 1, false)
		var paths: Array[SidePath] = sim.labyrinth.level(3).side_paths
		assert_eq(e.depth, 3, "%s: the party stands on its safe stage" % what)
		assert_eq(PartyPlaces.walk_goal(e, false), e.x, "%s: where it is going from" % what)
		assert_gt(paths.size(), 0, "%s: the stage has side paths" % what)
		for index: int in paths.size():
			assert_true(SidePathRules.is_full(e, 3, index), "%s: cache %d is full" % [what, index])
			assert_gt(absf(paths[index].at - e.x), 3.0, "%s: and far from the party" % what)
			assert_eq(SidePathRules.opener(e, 3, index) != null, skilled, "%s: openable" % what)
		var events: Array[SimEvent] = []
		for i: int in 5:
			sim.step()
			events.append_array(sim.drain_events())
			assert_eq(e.side_path, -1, "%s: it is on no side path" % what)
		assert_eq(e.state, Expedition.State.CLIMBING, "%s: it leaves for the stage before" % what)
		for kind: SimEvent.Kind in [
			SimEvent.Kind.GATE_STARTED,
			SimEvent.Kind.GATE_OPENED,
			SimEvent.Kind.GATE_SEALED,
			SimEvent.Kind.CACHE_OPENED,
		]:
			assert_eq(_of_kind(events, kind).size(), 0, "%s: no gate event %d" % [what, kind])


## R3 and R8: a side path that leaves a room at the first step into it waits for that room: the
## monsters there are fought first, and the party turns off after.
func test_r3_the_room_is_fought_for_before_its_side_path() -> void:
	var tried: int = 0
	for seed_value: int in range(1, 40):
		var sim: Simulation = winding_simulation(seed_value)
		var e: Expedition = sim.expedition
		var level: LabyrinthLevel = sim.labyrinth.level(1)
		for index: int in level.side_paths.size():
			var path: SidePath = level.side_paths[index]
			var room: int = _room_of(level, path)
			var first: bool = level.course.chamber_at(path.at - 0.25) != room
			if not first or not e.is_populated(1, room) or tried >= 3:
				continue
			tried += 1
			var what: String = "seed %d path %d" % [seed_value, index]
			raise_party(sim, SKILLED)
			Arrival.from_save(e, sim.tick, 1, 1, 1, false)
			e._place(path.at - 1.5)
			e.facing = 1
			e._entered_key = e._key_here()
			assert_ne(e._entered_key.y, room, "%s: the party is not yet in the room" % what)
			var order: Array[SimEvent.Kind] = []
			var fought_in: int = -2
			var on_path_at_fight: int = -2
			var clear_at_gate: bool = false
			for i: int in 3000:
				sim.step()
				for event: SimEvent in sim.drain_events():
					if event.kind == SimEvent.Kind.ENCOUNTER_STARTED and fought_in == -2:
						fought_in = e.chamber().index if e.chamber() != null else -1
						on_path_at_fight = e.side_path
						order.append(event.kind)
					if event.kind in [SimEvent.Kind.GATE_STARTED, SimEvent.Kind.CACHE_OPENED]:
						order.append(event.kind)
					if event.kind == SimEvent.Kind.GATE_STARTED:
						clear_at_gate = not e.is_populated(1, room)
				if order.has(SimEvent.Kind.CACHE_OPENED):
					break
			assert_eq(
				order,
				(
					[
						SimEvent.Kind.ENCOUNTER_STARTED,
						SimEvent.Kind.GATE_STARTED,
						SimEvent.Kind.CACHE_OPENED,
					]
					as Array[SimEvent.Kind]
				),
				"%s: the fight, then the gate, then the cache" % what
			)
			assert_eq(fought_in, room, "%s: the fight is in the room the path leaves" % what)
			assert_eq(on_path_at_fight, -1, "%s: fought from the main course" % what)
			assert_true(clear_at_gate, "%s: the room is clear as the gate is worked" % what)
			break
	assert_eq(tried, 3, "three side paths that leave a room at its first step, monsters in it")


func _one_trip(sim: Simulation, index: int, way: int, what: String) -> void:
	var e: Expedition = sim.expedition
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var path: SidePath = _stand_before(sim, 1, index, way)
	var def: GateDef = Content.gate(path.gate)
	var gate: int = Content.gate_ids().find(path.gate)
	var worker: int = _lowest_with(sim, def.microskill)
	assert_gt(worker, 0, "%s: someone can open it" % what)
	assert_eq(SidePathRules.opener(e, 1, index).id, worker, "%s: the opener asked for" % what)
	assert_true(SidePathRules.is_full(e, 1, index), "%s: its cache is full" % what)

	var events: Array[SimEvent] = _events_until(
		sim, func() -> bool: return e.side_path == index, 20
	)
	assert_eq(e.x, 0.0, "%s: it turns onto the side path's course at its start" % what)
	assert_eq(PartyPlaces.course(e), path.course, "%s: the course asked for is the path's" % what)
	assert_true(
		PartyPlaces.anchor(e).is_equal_approx(level.course.point_at(path.at)),
		"%s: where it leaves the main course" % what
	)
	events.append_array(
		_events_until(sim, func() -> bool: return e.state == Expedition.State.WORKING, 100)
	)
	assert_almost_eq(e.x, path.gate_at, 0.001, "%s: it stops at the gate" % what)
	assert_eq(e.worker_id(), worker, "%s: the lowest hero with the skill works" % what)
	assert_eq(e.working_quest(), &"", "%s: no quest is being worked" % what)
	assert_null(e.chamber(), "%s: at the gate it is in no chamber" % what)
	var started: Array[SimEvent] = _of_kind(events, SimEvent.Kind.GATE_STARTED)
	var work_ticks: int = roundi(def.work_seconds * TICKS)
	assert_eq(started.size(), 1, "%s: GATE_STARTED once" % what)
	if started.size() == 1:
		assert_eq(
			[started[0].source_id, started[0].target_id, started[0].amount],
			[worker, gate, work_ticks],
			"%s: GATE_STARTED names the worker, the gate and the work" % what
		)
	assert_eq(_of_kind(events, SimEvent.Kind.GATE_OPENED).size(), 0, "%s: not yet open" % what)

	var worked: int = 0
	var progress: float = e.work_progress()
	events = []
	while e.state == Expedition.State.WORKING and worked < 200:
		sim.step()
		events.append_array(sim.drain_events())
		worked += 1
		if e.state == Expedition.State.WORKING:
			assert_gt(e.work_progress(), progress, "%s: the work goes on" % what)
			progress = e.work_progress()
			assert_almost_eq(e.x, path.gate_at, 0.001, "%s: it stands at the gate" % what)
	assert_eq(worked, work_ticks, "%s: the work takes the gate's seconds" % what)
	var opened: Array[SimEvent] = _of_kind(events, SimEvent.Kind.GATE_OPENED)
	assert_eq(opened.size(), 1, "%s: GATE_OPENED once" % what)
	if opened.size() == 1:
		assert_eq(
			[opened[0].source_id, opened[0].target_id, opened[0].amount],
			[worker, gate, index],
			"%s: GATE_OPENED names the worker, the gate and the side path" % what
		)
	assert_eq(e.worker_id(), -1, "%s: nobody works any more" % what)

	var paid_at: float = -1.0
	var furthest: float = 0.0
	var caches: int = 0
	var guard: int = 0
	while e.side_path == index and guard < 1200:
		guard += 1
		var was_in: bool = path.in_room(e.x)
		sim.step()
		furthest = maxf(furthest, e.x) if e.side_path == index else furthest
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.CACHE_OPENED:
				caches += 1
				paid_at = e.x
				assert_false(was_in, "%s: the cache opens as the party steps in" % what)
				assert_eq(e.chamber(), path.room, "%s: it is in the cache room" % what)
				assert_eq(event.amount, index, "%s: CACHE_OPENED names the side path" % what)
			if event.kind in [SimEvent.Kind.GATE_STARTED, SimEvent.Kind.GATE_OPENED]:
				fail_test("%s: the gate is worked a second time" % what)
		if e.side_path != index:
			break
		assert_eq(e.state, Expedition.State.TRAVELLING, "%s: it walks, in and back" % what)
		var room: LabyrinthChamber = path.room if path.in_room(e.x) else null
		assert_eq(e.chamber(), room, "%s: its chamber is the cache room only inside it" % what)
		for hero: Hero in sim.party.heroes:
			if not _in_the_open(level, e.hero_position(hero.id)) and _wrong.size() < 6:
				_wrong.append("%s: hero %d at %s" % [what, hero.id, e.hero_position(hero.id)])
	assert_eq(caches, 1, "%s: the cache is opened once" % what)
	assert_true(paid_at >= 0.0 and path.in_room(paid_at), "%s: on the cache room's floor" % what)
	assert_almost_eq(furthest, path.course.end, 0.001, "%s: it walks to the far wall" % what)
	assert_eq(e.side_path, -1, "%s: it is back on the main course" % what)
	assert_almost_eq(e.x, path.at, 0.001, "%s: where it left it" % what)
	assert_eq(e.facing, way, "%s: facing the way it was going" % what)
	assert_false(SidePathRules.is_full(e, 1, index), "%s: the cache is empty now" % what)
	run_ticks(sim, 1)
	assert_gt((e.x - path.at) * way, 0.2, "%s: and it goes on that way" % what)
	assert_eq(e.side_path, -1, "%s: past the open gate" % what)


# --- R4 ------------------------------------------------------------------------


## R4: a cache gives gold worth 6 kills of its stage (raised by the gold upgrade), XP worth 3 to
## every living hero and 3 large drops of the area's resource, told in that order.
func test_r4_a_cache_pays_gold_xp_and_the_areas_resource() -> void:
	assert_eq(SidePathRules.CACHE_GOLD_KILLS, GOLD_KILLS, "6 kills of gold")
	assert_eq(SidePathRules.CACHE_XP_KILLS, XP_KILLS, "3 kills of XP")
	assert_eq(SidePathRules.CACHE_DROPS, DROPS, "3 drops")
	var golds: Dictionary[int, int] = {}
	for area_id: StringName in Content.area_ids().slice(0, 2):
		for stage: int in [1, 6]:
			for rank: int in [0, 4]:
				var paid: int = _pay_once(area_id, stage, rank)
				if area_id == Content.area_ids()[0]:
					golds[stage * 10 + rank] = paid
	assert_gt(golds[60], golds[10], "a cache further in holds more")
	assert_gt(golds[14], golds[10], "and the gold upgrade raises it")


## Opens one cache on [param stage] of [param area_id] with the gold upgrade at [param rank] and
## checks what it pays; returns the gold.
func _pay_once(area_id: StringName, stage: int, rank: int) -> int:
	var what: String = "%s stage %d, gold rank %d" % [area_id, stage, rank]
	var sim: Simulation = winding_simulation(2)
	var e: Expedition = sim.expedition
	raise_party(sim, SKILLED)
	if area_id != e.area:
		e.travel.open[area_id] = true
		sim.set_destination(area_id, 1)
		_events_until(sim, func() -> bool: return e.place == area_id, 400)
		sim.drain_events()
	assert_eq(e.place, area_id, "%s: the party is there" % what)
	sim.upgrades.set_rank(&"fat_purse", rank)
	var path: SidePath = _stand_before(sim, stage, 0, 1)
	var worker: int = _lowest_with(sim, Content.gate(path.gate).microskill)
	# One hero who opens no gate lies dead: a cache gives the dead nothing.
	var dead: Hero = sim.party.heroes[3]
	dead.health = 0
	assert_ne(dead.id, worker, "%s: the dead hero is not the opener" % what)
	var area: AreaDef = Content.area(area_id)
	var value: Vector2 = QuestDef.kill_value(area.level_at(stage))
	var bonus: float = sim.upgrades.multiplier(UpgradeDef.Stat.GOLD)
	assert_eq(bonus > 1.0, rank > 0, "%s: the gold upgrade is at that rank" % what)
	var gold: int = roundi(maxi(roundi(GOLD_KILLS * value.x), 1) * bonus)
	var xp: int = maxi(roundi(XP_KILLS * value.y), 1)
	var drops: int = DROPS * ResourceDrops.amount_at(MonsterDef.Size.LARGE, stage)
	var resource: int = Content.resource_ids().find(area.resource)
	assert_gt(resource, -1, "%s: the area has a resource" % what)
	var gold_before: int = sim.party.gold
	var held_before: int = sim.party.resource(area.resource)
	var xp_before: Dictionary[int, int] = {}
	for hero: Hero in sim.party.heroes:
		xp_before[hero.id] = hero.xp

	var told: Array[SimEvent] = []
	var done: Callable = func() -> bool: return not SidePathRules.is_full(e, stage, 0)
	for event: SimEvent in _events_until(sim, done, 1200):
		var mine: bool = event.tick == sim.tick
		if mine and event.kind in [SimEvent.Kind.LEVEL_UP, SimEvent.Kind.TALENT_POINT_GAINED]:
			continue
		if mine and event.kind != SimEvent.Kind.MICROSKILL_LEARNED:
			told.append(event)
	var kinds: Array[SimEvent.Kind] = []
	for event: SimEvent in told:
		kinds.append(event.kind)
	var order: Array[SimEvent.Kind] = [
		SimEvent.Kind.CACHE_OPENED,
		SimEvent.Kind.GOLD_GAINED,
		SimEvent.Kind.XP_GAINED,
		SimEvent.Kind.XP_GAINED,
		SimEvent.Kind.XP_GAINED,
		SimEvent.Kind.RESOURCE_GAINED,
	]
	assert_eq(kinds, order, "%s: the cache, then its gold, XP and resource, on one tick" % what)
	if kinds != order:
		return 0
	assert_eq([told[0].source_id, told[0].amount], [worker, 0], "%s: CACHE_OPENED" % what)
	assert_eq(told[1].amount, gold, "%s: gold worth 6 kills, with the upgrade" % what)
	assert_eq(sim.party.gold - gold_before, gold, "%s: and the party holds it" % what)
	var gained: Array[int] = []
	for i: int in range(2, 5):
		gained.append(told[i].target_id)
		assert_eq(told[i].amount, xp, "%s: XP worth 3 kills" % what)
	assert_eq(gained, [1, 2, 3] as Array[int], "%s: for every living hero" % what)
	for hero: Hero in sim.party.heroes:
		var want: int = 0 if hero == dead else xp
		assert_eq(hero.xp - xp_before[hero.id], want, "%s: hero %d's XP" % [what, hero.id])
	assert_eq([told[5].target_id, told[5].amount], [resource, drops], "%s: 3 large drops" % what)
	assert_eq(sim.party.resource(area.resource) - held_before, drops, "%s: of its resource" % what)
	return gold


# --- R5 ------------------------------------------------------------------------


## R5: an opened cache is passed for 600 seconds, whatever happens meanwhile, and opened again
## after; a journey away and back finds it full.
func test_r5_an_open_cache_is_passed_until_it_refills() -> void:
	var found: Vector2i = _find(1, true)
	var index: int = found.y
	var sim: Simulation = winding_simulation(found.x)
	var e: Expedition = sim.expedition
	raise_party(sim, SKILLED)
	var path: SidePath = _stand_before(sim, 1, index, 1)
	var first: StringName = e.area
	var refill: int = roundi(REFILL_SECONDS * TICKS)
	assert_eq(SidePathRules.REFILL_SECONDS, REFILL_SECONDS, "a cache refills in 600 seconds")
	_events_until(sim, func() -> bool: return not SidePathRules.is_full(e, 1, index), 1200)
	var opened: int = sim.tick
	assert_false(SidePathRules.is_full(e, 1, index), "the cache is empty once opened")
	_events_until(sim, func() -> bool: return e.side_path < 0, 600)

	# Pacing the stage, it passes the gate again and again; a wipe and a change of stage between.
	var passes: int = 0
	var trips: int = 0
	var wiped: bool = false
	var left: bool = false
	var came_back: bool = false
	while sim.tick < opened + refill - 1:
		var before: float = e.x - path.at
		var on_route: bool = e.depth == 1 and e.side_path < 0
		if not wiped and sim.tick == opened + 600:
			_wipe(sim)
			wiped = true
		if not left and sim.tick == opened + 1200:
			sim.set_target_depth(2)
			left = true
		if left and not came_back and e.depth == 2 and e.state == Expedition.State.TRAVELLING:
			sim.set_target_depth(1)
			came_back = true
		sim.step()
		for event: SimEvent in sim.drain_events():
			var here: bool = e.depth == 1 and event.amount == index
			if here and event.kind in [SimEvent.Kind.GATE_OPENED, SimEvent.Kind.CACHE_OPENED]:
				trips += 1
		if e.depth == 1 and e.side_path == index:
			trips += 1
		var crossed: bool = before * (e.x - path.at) < 0.0
		if on_route and e.depth == 1 and e.side_path < 0 and crossed:
			passes += 1
		if sim.tick % 500 == 0:
			assert_false(SidePathRules.is_full(e, 1, index), "still empty at %d" % sim.tick)
	assert_true(
		wiped and left and came_back, "the party was wiped, and left the stage and came back"
	)
	assert_eq(e.depth, 1, "it is back on the stage")
	assert_gt(passes, 3, "it walked past the open gate")
	assert_eq(trips, 0, "and never stopped at it or went in")
	assert_false(SidePathRules.is_full(e, 1, index), "a tick before 600 seconds it is empty")
	sim.step()
	assert_true(SidePathRules.is_full(e, 1, index), "at 600 seconds it is full again")

	# The gate is closed again: it is worked again before the cache pays again.
	var again: Array[SimEvent] = []
	var gate_opened: bool = false
	for i: int in 6000:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if e.depth == 1 and event.amount == index:
				gate_opened = gate_opened or event.kind == SimEvent.Kind.GATE_OPENED
				if event.kind == SimEvent.Kind.CACHE_OPENED:
					again.append(event)
		if not again.is_empty():
			break
	assert_eq(again.size(), 1, "after it refills the party opens it again")
	assert_true(gate_opened, "through its gate, closed again")
	var second: int = sim.tick

	# A journey away and back finds every cache full.
	var other: StringName = Content.area_ids()[1]
	e.travel.open[other] = true
	assert_false(SidePathRules.is_full(e, 1, index), "empty as the party leaves the area")
	sim.set_destination(other, 1)
	_events_until(sim, func() -> bool: return e.place == other, 3000)
	sim.set_destination(first, 1)
	_events_until(sim, func() -> bool: return e.place == first, 3000)
	assert_lt(sim.tick, second + refill, "it is back within 600 seconds")
	for each: int in sim.labyrinth.level(1).side_paths.size():
		assert_true(SidePathRules.is_full(e, 1, each), "a journey back finds cache %d full" % each)


# --- R6 ------------------------------------------------------------------------


## R6: with nobody able the party walks past, GATE_SEALED is told once, and again only after
## the party has left the stage and come back.
func test_r6_a_gate_nobody_can_open_is_said_once() -> void:
	var found: Vector2i = _find(1, false)
	var index: int = found.y

	# Nobody has the skill.
	var sim: Simulation = winding_simulation(found.x)
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	var path: SidePath = sim.labyrinth.level(1).side_paths[index]
	var def: GateDef = Content.gate(path.gate)
	var gate: int = Content.gate_ids().find(path.gate)
	var skill: int = Content.microskill_ids().find(def.microskill)
	assert_null(SidePathRules.opener(e, 1, index), "nobody can open it")
	_pass_sealed(sim, index, 1, true, 1, "nobody with the skill")
	_pass_sealed(sim, index, -1, false, 0, "passing it again")
	_pass_sealed(sim, index, 1, false, 0, "and again")

	# Off to the next stage and back: the gate is said again, once.
	var line: StageCourse = sim.labyrinth.level(1).course
	e.x = line.exit - 0.5
	e.facing = 1
	sim.set_target_depth(2)
	_events_until(sim, func() -> bool: return e.depth == 2, 200)
	sim.set_target_depth(1)
	_events_until(sim, func() -> bool: return e.depth == 1, 200)
	sim.drain_events()
	_pass_sealed(sim, index, -1, false, 1, "after coming back to the stage")
	_pass_sealed(sim, index, 1, false, 0, "and passing it once more")

	# The one hero with the skill is dead.
	var grown: Simulation = winding_simulation(found.x)
	raise_party(grown, SKILLED)
	var able: Hero = SidePathRules.opener(grown.expedition, 1, index)
	assert_not_null(able, "a grown party has someone able")
	able.health = 0
	assert_null(SidePathRules.opener(grown.expedition, 1, index), "but not once it is dead")
	var told: Array[SimEvent] = _pass_sealed(grown, index, 1, true, 1, "the able hero dead")
	if told.size() == 1:
		assert_eq(
			[told[0].source_id, told[0].target_id, told[0].amount],
			[-1, gate, skill],
			"GATE_SEALED names the gate and the microskill it needs"
		)


## Walks [param sim]'s party past side path [param index] of stage 1 and checks it never stops,
## turns off or is hurt, and that GATE_SEALED is told [param said] times. Returns those events.
func _pass_sealed(
	sim: Simulation, index: int, way: int, fresh: bool, said: int, what: String
) -> Array[SimEvent]:
	var e: Expedition = sim.expedition
	var path: SidePath = _stand_before(sim, 1, index, way, 1.5, fresh)
	var health: Array[int] = []
	for hero: Hero in sim.party.heroes:
		health.append(hero.health)
	var events: Array[SimEvent] = []
	for i: int in 10:
		sim.step()
		events.append_array(sim.drain_events())
		assert_eq(e.side_path, -1, "%s: it does not turn off" % what)
		assert_eq(e.state, Expedition.State.TRAVELLING, "%s: it does not stop" % what)
	assert_gt((e.x - path.at) * way, 1.0, "%s: it walks past" % what)
	var sealed: Array[SimEvent] = _of_kind(events, SimEvent.Kind.GATE_SEALED)
	assert_eq(sealed.size(), said, "%s: GATE_SEALED %d times" % [what, said])
	assert_eq(_of_kind(events, SimEvent.Kind.GATE_STARTED).size(), 0, "%s: no work" % what)
	assert_eq(_of_kind(events, SimEvent.Kind.HIT).size(), 0, "%s: no harm" % what)
	for i: int in sim.party.heroes.size():
		assert_eq(sim.party.heroes[i].health, health[i], "%s: hero %d unhurt" % [what, i + 1])
	assert_true(SidePathRules.is_full(e, 1, index), "%s: its cache stays full" % what)
	return sealed


# --- R7 ------------------------------------------------------------------------


## R7: a run that opens no gate has the hash it had, and the save is what it was.
func test_r7_no_gate_opened_keeps_the_hash_and_the_save() -> void:
	for seed_value: int in QUIET_HASHES:
		var quiet: Simulation = winding_simulation(seed_value)
		_keep_unskilled(quiet)
		var sealed: int = 0
		var opened: int = 0
		for i: int in QUIET_TICKS:
			quiet.step()
			for event: SimEvent in quiet.drain_events():
				sealed += int(event.kind == SimEvent.Kind.GATE_SEALED)
				opened += int(event.kind == SimEvent.Kind.GATE_STARTED)
		assert_gt(sealed, 0, "seed %d: the party met gates it could not open" % seed_value)
		assert_eq(opened, 0, "seed %d: and opened none" % seed_value)
		assert_eq(
			quiet.state_hash(), QUIET_HASHES[seed_value], "seed %d: the hash it had" % seed_value
		)

	assert_eq(Simulation.SAVE_VERSION, 12, "the save's version is what the roster made it")
	var found: Vector2i = _find(1, false)
	var sim: Simulation = winding_simulation(found.x)
	var e: Expedition = sim.expedition
	raise_party(sim, SKILLED)
	var plain: int = sim.state_hash()
	_stand_before(sim, 1, found.y, 1)
	_events_until(sim, func() -> bool: return not SidePathRules.is_full(e, 1, found.y), 1200)
	assert_false(SidePathRules.is_full(e, 1, found.y), "a cache is empty as the game is saved")
	assert_ne(sim.state_hash(), plain, "and the state hash knows it")
	var data: Dictionary = sim.to_save()
	var keys: Array[String] = []
	keys.assign(data.keys())
	keys.sort()
	assert_eq(keys, SAVE_KEYS, "the save has the keys it had")
	assert_eq(Simulation.save_problems(data).size(), 0, "and is sound")
	var loaded: Simulation = Simulation.from_save(_through_json(data), WINDING)
	assert_not_null(loaded, "it loads")
	if loaded == null:
		return
	assert_eq(loaded.expedition.side_path, -1, "the loaded party is on the main course")
	var paths: Array[SidePath] = loaded.labyrinth.level(1).side_paths
	assert_eq(_side_signature(loaded.labyrinth.level(1)), _side_signature(sim.labyrinth.level(1)))
	for index: int in paths.size():
		assert_true(
			SidePathRules.is_full(loaded.expedition, 1, index), "loaded, cache %d is full" % index
		)


# --- R8 ------------------------------------------------------------------------


## R8: no monsters and no quest on a side path; a target asked for on one waits for the
## main course; the stage's timer runs on through one.
func test_r8_a_side_path_is_quiet() -> void:
	var levels: int = 0
	for seed_value: int in range(1, 21):
		var each: Simulation = winding_simulation(seed_value)
		var all: Expedition = each.expedition
		for depth: int in range(1, 11):
			var level: LabyrinthLevel = each.labyrinth.level(depth)
			var where: String = "seed %d stage %d" % [seed_value, depth]
			levels += 1
			var rooms: int = level.chambers.size()
			for index: int in [-1, rooms, rooms + 1, rooms + 2]:
				if all.is_populated(depth, index) or not all.monsters_in(depth, index).is_empty():
					_wrong.append("%s: monsters in chamber %d" % [where, index])
				if all.quest_in(depth, index) != &"":
					_wrong.append("%s: a quest in chamber %d" % [where, index])
			for index: int in rooms:
				var room: LabyrinthChamber = level.chambers[index]
				for monster: Combatant in all.monsters_in(depth, index):
					var feet := Vector2i(floori(monster.x), room.floor_row())
					if not room.rect.has_point(feet):
						_wrong.append("%s: a monster at %s, out of room %d" % [where, feet, index])
					for path: SidePath in level.side_paths:
						if path.room.rect.has_point(feet) or path.tunnel.has_point(feet):
							_wrong.append("%s: a monster at %s, on a side path" % [where, feet])
	assert_eq(levels, 200, "200 levels")
	_nothing_wrong("the side paths are empty")

	# A target asked for on a side path applies back on the main course.
	var found: Vector2i = _find(2, false)
	var sim: Simulation = winding_simulation(found.x)
	var e: Expedition = sim.expedition
	raise_party(sim, SKILLED)
	_stand_before(sim, 2, found.y, 1)
	# The stage is not yet safe: its timer has 12 seconds to run, less than the trip takes.
	e.last_stable_depth = 1
	e.stable_seconds = 12.0
	_events_until(sim, func() -> bool: return e.side_path == found.y, 20)
	var began: int = sim.tick
	var left_at_start: float = e.seconds_to_stable()
	assert_gt(left_at_start, 10.0, "the stage's timer is running as the party turns off")
	sim.set_target_depth(5)
	var safe_on_path: bool = false
	var changed_on_path: bool = false
	var guard: int = 0
	while e.side_path == found.y and guard < 1200:
		guard += 1
		sim.step()
		var on_path: bool = e.side_path == found.y
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED and event.amount == 2:
				safe_on_path = safe_on_path or on_path
			if event.kind == SimEvent.Kind.TARGET_DEPTH_CHANGED:
				changed_on_path = true
		if on_path:
			assert_eq(e.target_depth, 2, "on the side path the target waits")
			var ran: float = float(sim.tick - began) / TICKS
			assert_almost_eq(
				e.seconds_to_stable(), maxf(left_at_start - ran, 0.0), 0.001, "the timer runs on"
			)
	assert_false(changed_on_path, "no target is told while it is on the side path")
	assert_true(safe_on_path, "the stage became safe while the party was on the side path")
	assert_eq(e.last_stable_depth, 2, "and is the safe stage")
	assert_eq(e.depth, 2, "the party never left the stage")
	var told: Array[SimEvent] = run_ticks(sim, 1)
	assert_eq(e.target_depth, 5, "back on the main course the target applies")
	assert_eq(_of_kind(told, SimEvent.Kind.TARGET_DEPTH_CHANGED).size(), 1, "and is told")

	# A journey leaves from where the party stands, side path or not.
	var away: Simulation = winding_simulation(found.x)
	var run: Expedition = away.expedition
	raise_party(away, SKILLED)
	var path: SidePath = _stand_before(away, 2, found.y, 1)
	_events_until(away, func() -> bool: return not SidePathRules.is_full(run, 2, found.y), 1200)
	var other: StringName = Content.area_ids()[1]
	run.travel.open[other] = true
	away.set_destination(other, 1)
	away.step()
	assert_eq(run.state, Expedition.State.JOURNEYING, "a journey begins on the side path")
	assert_eq(run.side_path, found.y, "from where the party stands")
	assert_true(
		path.room.rect.has_point(Vector2i(run.hero_position(1).floor())), "in the cache room"
	)
	_events_until(away, func() -> bool: return run.place == other, 400)
	assert_eq(run.side_path, -1, "and it arrives on a main course")
	assert_eq(run.state, Expedition.State.TRAVELLING, "travelling")


# --- R9 ------------------------------------------------------------------------


## R9: a run that buys upgrades and spends talents, as the sim tool's does, opens a cache on
## every one of the five seeds.
func test_r9_exploring_opens_caches() -> void:
	for seed_value: int in range(1, 6):
		var sim: Simulation = winding_simulation(seed_value)
		var caches: int = 0
		var gold: int = 0
		var ticks: int = 0
		while ticks < 30 * 60 * TICKS and caches == 0:
			ticks += 1
			var cheapest: StringName = sim.upgrades.cheapest_affordable(sim.party)
			if cheapest != &"":
				sim.buy_upgrade(cheapest)
			TalentSpender.spend(sim)
			var before: int = sim.party.gold
			sim.step()
			for event: SimEvent in sim.drain_events():
				if event.kind == SimEvent.Kind.CACHE_OPENED:
					caches += 1
					gold = sim.party.gold - before
		assert_gt(caches, 0, "seed %d opens a cache within 30 minutes" % seed_value)
		assert_gt(gold, 0, "seed %d: and is the richer for it" % seed_value)

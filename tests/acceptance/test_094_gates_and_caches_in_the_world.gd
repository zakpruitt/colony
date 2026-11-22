extends "res://tests/support/side_path_fixture.gd"
## Acceptance tests for specs/094-gates-and-caches-in-the-world/spec.md, one per requirement:
## the gates and caches of a winding stage's side paths as the world draws them.
##
## Each test finds a side path over the seeds, stands a party before it (spec 093's fixture),
## shows the world over it and plays frames.

const DIR: String = "res://assets/sprites/props/"
const STAGES: int = 5
## A level at which every hero has every microskill of its class.
const SKILLED: int = 12
## Per gate: the microskill's name, the class that learns it and the level it does.
const WHO: Dictionary[StringName, Array] = {
	&"locked_gate": ["Lockpicker", "Rogue", 2],
	&"rubble": ["Strongarm", "Knight", 3],
	&"rune_seal": ["Runereader", "Mage", 4],
	&"hidden_crack": ["Trapspotter", "Rogue", 6],
}
const REFILL_TICKS: int = 6000

var _sound: SoundPlayer

# --- Helpers -------------------------------------------------------------------


## A winding simulation of [param seed_value] whose party stands before side path
## [param index] of [param stage] going [param way], every hero able (or, not [param skilled],
## none ever).
func _before(
	seed_value: int, stage: int, index: int, way: int = 1, skilled: bool = true
) -> SidePath:
	_sim = winding_simulation(seed_value)
	_sim.set_auto_push(false)
	if skilled:
		set_party_level(_sim, SKILLED)
	else:
		_keep_unskilled(_sim)
	return _stand_before(_sim, stage, index, way)


## The world, its effects and a sound player over [member _sim], the gate tip not following the
## real mouse.
func _watch_gates() -> void:
	_show(_sim, 1, true)
	_sound = SoundPlayer.new()
	add_child_autofree(_sound)
	_sound.set_process(false)
	_sound.setup(_world, _fx, _sim, null)
	_frame_parts.append(_sound._process)
	_world.side_props.follows_mouse = false


## The first side path closed by [param gate] over the seeds and [constant STAGES] stages, as
## Vector3i(seed, stage, place).
func _find_gate(gate: StringName) -> Vector3i:
	for seed_value: int in range(1, 40):
		var maze: Labyrinth = winding_labyrinth(seed_value)
		for stage: int in range(1, STAGES + 1):
			var paths: Array[SidePath] = maze.level(stage).side_paths
			for index: int in paths.size():
				if paths[index].gate == gate:
					return Vector3i(seed_value, stage, index)
	fail_test("no %s in 40 seeds" % gate)
	return Vector3i(1, 1, 0)


func _feet_of(tiles: Vector2) -> Vector2:
	return Vector2(tiles.x * TILE, (tiles.y + 1.0) * TILE)


func _cache_feet(path: SidePath) -> Vector2:
	var rect: Rect2i = path.room.rect
	var middle: float = floorf((rect.position.x + rect.end.x) / 2.0)
	return Vector2(middle * TILE, (path.room.floor_row() + 1) * TILE)


## True if [param shown] shows [param part] of the sheet named [param id].
func _shows(shown: Sprite2D, id: StringName, part: StringName) -> bool:
	var sheet: PixelSheet = PixelSheet.load_sheet(DIR + String(id) + ".png")
	if shown == null or sheet == null or not sheet.has_part(part):
		return false
	var want: AtlasTexture = sheet.part(part)
	var has: AtlasTexture = shown.texture as AtlasTexture
	return has != null and has.atlas == want.atlas and has.region == want.region


## Steps the simulation alone (the world sees nothing) until [param done].
func _unseen_until(done: Callable, limit: int = 3000) -> void:
	for i: int in limit:
		if done.call():
			return
		_sim.step()
	fail_test("not done within %d unseen ticks" % limit)


func _on_path() -> bool:
	return _sim.expedition.side_path >= 0


func _off_path() -> bool:
	return _sim.expedition.side_path < 0


# --- R1 ------------------------------------------------------------------------


## R1: every side path of 5 stages has its gate's sprite at its place on its room's floor; closed
## before, the open part after GATE_OPENED, closed again after the refill; each kind is seen.
func test_r1_each_gate_stands_closed_then_open() -> void:
	_sim = winding_simulation(1)
	var maze: Labyrinth = _sim.labyrinth
	for stage: int in range(1, STAGES + 1):
		Arrival.from_save(_sim.expedition, _sim.tick, stage, stage, stage, false)
		_show(_sim)
		var level: LabyrinthLevel = maze.level(stage)
		assert_gt(level.side_paths.size(), 0, "stage %d has side paths" % stage)
		for index: int in level.side_paths.size():
			var path: SidePath = level.side_paths[index]
			var what: String = "stage %d path %d (%s)" % [stage, index, path.gate]
			var gate: Sprite2D = _world.side_props.gate(stage, index)
			assert_not_null(gate, "%s: its gate is drawn" % what)
			if gate == null:
				continue
			var at: Vector2 = path.course.point_at(path.gate_at)
			assert_eq(gate.position, _feet_of(at), "%s: at the gate's place" % what)
			var room: LabyrinthChamber = level.chambers[_room_of(level, path)]
			assert_eq(int(at.y), room.floor_row(), "%s: on the floor of the room it leaves" % what)
			assert_true(_shows(gate, path.gate, &"closed"), "%s: its kind's sheet, closed" % what)
			assert_eq(gate.get_parent(), _world.side_props as Node, "%s: among the props" % what)
		_world.free()
	for kind: StringName in GATES:
		var found: Vector3i = _find_gate(kind)
		var path: SidePath = _before(found.x, found.y, found.z)
		_watch_gates()
		var props: SideProps = _world.side_props
		var gate: Sprite2D = props.gate(found.y, found.z)
		assert_true(_shows(gate, kind, &"closed"), "%s: closed while its cache is full" % kind)
		assert_eq(props.has_draught(found.y, found.z), kind == &"hidden_crack", "%s: motes" % kind)
		assert_true(_play_until(SimEvent.Kind.GATE_STARTED, 300), "%s: the work starts" % kind)
		assert_true(_shows(gate, kind, &"closed"), "%s: closed while it is worked" % kind)
		assert_true(_play_until(SimEvent.Kind.GATE_OPENED, 300), "%s: it is opened" % kind)
		assert_true(_shows(gate, kind, &"open"), "%s: the open part from GATE_OPENED" % kind)
		assert_false(props.has_draught(found.y, found.z), "%s: no motes once open" % kind)
		assert_true(_play_until(SimEvent.Kind.CACHE_OPENED, 600), "%s: the cache opens" % kind)
		for i: int in 2400:
			_play_frame()
			if _off_path():
				break
		assert_true(_off_path(), "%s: the party walks back through it" % kind)
		assert_true(_shows(gate, kind, &"open"), "%s: open while the cache is empty" % kind)
		var run: Expedition = _sim.expedition
		_unseen_until(func() -> bool: return SidePathRules.is_full(run, found.y, found.z), 7000)
		_world.sync(STEP)
		gate = props.gate(found.y, found.z)
		assert_true(_shows(gate, kind, &"closed"), "%s: closed again after the refill" % kind)
		assert_eq(gate.position, _feet_of(path.course.point_at(path.gate_at)), "%s: there" % kind)
		_world.free()
		_fx.free()
		_sound.free()


# --- R2 ------------------------------------------------------------------------


## R2: the worker's place and side, the bar's fraction against work_progress(), the name shown,
## in rooms walked both ways.
func test_r2_the_opener_works_at_the_gate() -> void:
	for tunnel: bool in [false, true]:
		for way: int in [1, -1]:
			var found: Vector2i = _find(2, tunnel)
			var path: SidePath = _before(found.x, 2, found.y, way)
			var what: String = "%s, walked %d" % ["tunnel" if tunnel else "ladder", way]
			_watch_gates()
			var run: Expedition = _sim.expedition
			var main: StageCourse = _sim.labyrinth.level(2).course
			assert_true(_play_until(SimEvent.Kind.GATE_STARTED, 300), "%s: work starts" % what)
			var worker_id: int = run.worker_id()
			assert_eq(worker_id, _lowest_with(_sim, GATES[path.gate]), "%s: the opener" % what)
			for i: int in 45:
				_play_frame()
			assert_eq(run.state, Expedition.State.WORKING, "%s: still working" % what)
			var gate: Vector2 = _feet_of(path.course.point_at(path.gate_at))
			var worker: CharacterSprite = _world.character(worker_id)
			# The side the party came from: back along the main course for a ladder's gate, the
			# room's side for a tunnel's.
			var from: float = main.point_at(path.at - way * 2.0).x * TILE
			if tunnel:
				from = path.course.point_at(0.0).x * TILE
			var side: float = signf(from - gate.x)
			assert_ne(side, 0.0, "%s: the party came from one side" % what)
			assert_almost_eq(
				worker.position.x,
				gate.x + side * QuestProps.WORK_GAP,
				0.6,
				"%s: beside the gate, on the side the party came from" % what
			)
			assert_almost_eq(worker.position.y, gate.y, 0.6, "%s: on the gate's floor" % what)
			var props: QuestProps = _world.quest_props
			assert_gt(run.work_progress(), 0.0, "%s: the work is under way" % what)
			assert_eq(props.bar_fraction(), run.work_progress(), "%s: the bar is the work" % what)
			var skill: MicroskillDef = Content.microskill(GATES[path.gate])
			assert_eq(props.worker_label(), skill.display_name, "%s: the microskill's name" % what)
			var shown: Sprite2D = _world.side_props.gate(2, found.y)
			assert_lte(
				props._bar_at.y, gate.y - shown.texture.get_height(), "%s: the bar over it" % what
			)
			assert_lt(props._name_at.y, props._bar_at.y, "%s: the name over the bar" % what)
			# The slow repeat a side quest uses: a swing every SWING_SECONDS.
			var swings: Array[int] = []
			props.worked.connect(func(id: int) -> void: swings.append(id))
			for i: int in roundi(QuestProps.SWING_SECONDS * 60.0) + 2:
				_play_frame()
			assert_eq(swings, [worker_id] as Array[int], "%s: one swing a repeat" % what)
			assert_true(_play_until(SimEvent.Kind.GATE_OPENED, 300), "%s: it opens" % what)
			_play_frame()
			assert_eq(props.bar_fraction(), -1.0, "%s: the bar goes with the work" % what)
			assert_eq(props.worker_label(), "", "%s: and the name" % what)
			_world.free()
			_fx.free()
			_sound.free()


# --- R3 ------------------------------------------------------------------------


## The first side path of stage 2 whose cache is far outside the light of a party standing
## before it, as Vector2i(seed, place).
func _far_cache() -> Vector2i:
	for seed_value: int in range(1, 40):
		var level: LabyrinthLevel = winding_labyrinth(seed_value).level(2)
		for index: int in level.side_paths.size():
			var path: SidePath = level.side_paths[index]
			var leaves: Vector2 = _feet_of(level.course.point_at(path.at))
			if leaves.distance_to(_cache_feet(path)) > 2.0 * Ambience.PARTY_RADIUS:
				return Vector2i(seed_value, index)
	fail_test("no cache far from its side path's start")
	return Vector2i(1, 0)


## The sparkle parts the cache's glint shows over [param seconds] of frames with no tick.
func _glints_seen(index: int, seconds: float) -> Dictionary[StringName, bool]:
	var seen: Dictionary[StringName, bool] = {}
	for i: int in roundi(seconds * 60.0):
		_play_frame(false)
		seen[_world.side_props.glint_part(2, index)] = true
	return seen


## R3: the prop on its floor, the glint outside the light and none inside, open and dark after,
## back after the refill.
func test_r3_a_cache_glints_until_it_is_opened() -> void:
	var found: Vector2i = _far_cache()
	var path: SidePath = _before(found.x, 2, found.y)
	_watch_gates()
	var props: SideProps = _world.side_props
	var cache: Sprite2D = props.cache(2, found.y)
	assert_not_null(cache, "the cache is drawn")
	assert_eq(cache.position, _cache_feet(path), "at the middle of its room's floor")
	assert_true(_shows(cache, &"cache", &"closed"), "full: the closed strongbox")
	assert_true(props.is_glinting(2, found.y), "full and out of the light: it glints")
	var seen: Dictionary[StringName, bool] = _glints_seen(found.y, QuestProps.GLINT_PERIOD * 1.5)
	assert_true(seen.has(&"small") and seen.has(&"big"), "the glint a side quest's prop has")
	assert_true(seen.has(&""), "pulsing")
	# In the party's light, still full, it has none.
	for i: int in roundi(QuestProps.GLINT_PERIOD * 60.0):
		_world.ambience.party_light_position = cache.position + Vector2(30, -12)
		props.animate(STEP)
		assert_false(props.is_glinting(2, found.y), "in the light: no glint")
		assert_eq(props.glint_part(2, found.y), &"", "none drawn")
	assert_true(_play_until(SimEvent.Kind.CACHE_OPENED, 600), "the party opens it")
	assert_true(_shows(cache, &"cache", &"open"), "opened: it stands open")
	for i: int in 900:
		_play_frame()
		if _off_path():
			break
	for i: int in 120:
		_play_frame()
	assert_gt(
		cache.position.distance_to(_world.ambience.party_light_position),
		Ambience.PARTY_RADIUS,
		"the party has left it in the dark"
	)
	assert_false(props.is_glinting(2, found.y), "empty: no glint in the dark either")
	seen = _glints_seen(found.y, QuestProps.GLINT_PERIOD * 1.5)
	assert_eq(seen.keys(), [&""] as Array, "none drawn while it is empty")
	assert_true(_shows(cache, &"cache", &"open"), "still open")
	var run: Expedition = _sim.expedition
	_unseen_until(func() -> bool: return SidePathRules.is_full(run, 2, found.y), 7000)
	_world.sync(STEP)
	cache = props.cache(2, found.y)
	assert_true(_shows(cache, &"cache", &"closed"), "refilled: closed again")
	var dark: bool = (
		cache.position.distance_to(_world.ambience.party_light_position)
		> Ambience.PARTY_RADIUS + 24.0
	)
	assert_eq(props.is_glinting(2, found.y), dark, "and glinting again out of the light")


# --- R4 ------------------------------------------------------------------------


## R4: effects under the quest budget start at the cache; coins, icons and motes leave from it;
## the two sounds are asked for once each.
func test_r4_a_cache_bursts_and_pays_from_where_it_stands() -> void:
	var found: Vector2i = _far_cache()
	var path: SidePath = _before(found.x, 2, found.y)
	_watch_gates()
	var at: Vector2 = _cache_feet(path)
	var started: Array[StringName] = []
	var opened: bool = false
	for i: int in 3000:
		opened = _has(_play_frame(), SimEvent.Kind.CACHE_OPENED)
		started.append_array(_sound.drain_started())
		if opened:
			break
	assert_true(opened, "the cache opens")
	assert_eq(_shows(_world.side_props.cache(2, found.y), &"cache", &"open"), true, "it opens")
	var sparks: Array[Node2D] = _world.fx.nodes(&"quest")
	assert_gt(sparks.size(), 8, "a burst of sparks")
	assert_lte(_world.fx.count(&"quest"), FxPool.QUEST, "under the quest budget")
	for spark: Node2D in sparks:
		assert_eq((spark as FxParticle).kind, &"cache_spark", "the cache's sparks")
		assert_lt(spark.position.distance_to(at), 24.0, "a spark starts at the cache")
	assert_gt(_fx.coins().size(), 0, "coins")
	for coin: FxCoin in _fx.coins():
		assert_lt(coin.position.distance_to(at), 24.0, "a coin leaves from the cache")
	assert_gt(_fx.motes().size(), 3, "motes for the heroes")
	var heroes: Dictionary[int, bool] = {}
	for mote: FxMote in _fx.motes():
		heroes[mote.hero_id] = true
		assert_lt(mote.position.distance_to(at), 24.0, "a mote leaves from the cache")
	assert_eq(heroes.size(), _sim.party.heroes.size(), "motes for each hero")
	var icons: Array[FxResource] = _fx.resource_effects.live_icons()
	assert_gt(icons.size(), 0, "the area's resource")
	for icon: FxResource in icons:
		assert_lt(icon.position.distance_to(at), 24.0, "an icon leaves from the cache")
	for hero: Hero in _sim.party.heroes:
		assert_gt(
			_world.feet_position(hero.id).distance_to(at), 24.0, "no hero stands on the cache"
		)
	for i: int in 600:
		_play_frame()
		started.append_array(_sound.drain_started())
		if _off_path():
			break
	assert_eq(started.count(&"gate_open"), 1, "one sound for the gate")
	assert_eq(started.count(&"cache_open"), 1, "one for the cache")


# --- R5 ------------------------------------------------------------------------


## R5: the rising line's words; the tip's three wordings with parties that can, will later, and
## never will.
func test_r5_a_sealed_gate_says_what_it_wants() -> void:
	for kind: StringName in GATES:
		var found: Vector3i = _find_gate(kind)
		var who: Array = WHO[kind]
		var def: GateDef = Content.gate(kind)
		# A party that will later: nobody has the microskill yet.
		var path: SidePath = _before(found.x, found.y, found.z, 1, false)
		_watch_gates()
		var props: SideProps = _world.side_props
		var gate: Sprite2D = props.gate(found.y, found.z)
		var rect := Rect2(gate.position + gate.offset, gate.texture.get_size())
		assert_true(_play_until(SimEvent.Kind.GATE_SEALED, 300), "%s: nobody can" % kind)
		var lines: Array[FxText] = []
		for node: Node2D in _world.fx.nodes(&"quest_text"):
			lines.append(node as FxText)
		assert_eq(lines.size(), 1, "%s: one line" % kind)
		if lines.size() == 1:
			var line: FxText = lines[0]
			assert_eq(line.text, "Needs a %s" % who[0], "%s: what it wants" % kind)
			assert_eq(line.life, 2.0, "%s: for about two seconds" % kind)
			assert_almost_eq(line.position.x, gate.position.x, 1.0, "%s: from the gate" % kind)
			assert_lt(line.position.y, rect.position.y, "%s: over it" % kind)
			var before: float = line.position.y
			for i: int in 30:
				_play_frame(false)
			assert_lt(line.position.y, before, "%s: it rises" % kind)
		assert_false(props.tip.visible, "%s: no tip with the mouse elsewhere" % kind)
		props.point_at(rect.get_center())
		assert_true(props.tip.visible, "%s: a tip under the mouse" % kind)
		assert_eq(props.tip.title, def.display_name, "%s: its name" % kind)
		assert_eq(props.tip.body, def.description, "%s: its description" % kind)
		var later: String = (
			"A %s could open this: the %s learns it at level %d" % [who[0], who[1], who[2]]
		)
		assert_eq(props.tip.who, later, "%s: who will later" % kind)
		_play_frame(false)
		assert_true(props.tip.visible, "%s: it stays while the mouse rests" % kind)
		props.point_at(rect.end + Vector2(40, 40))
		assert_false(props.tip.visible, "%s: gone with the mouse" % kind)
		assert_eq(props.tip.who, "", "%s: and its words" % kind)
		# A party that never will: no hero of a class that learns it.
		for hero: Hero in _sim.party.heroes.duplicate():
			if hero.def().display_name == who[1]:
				_sim.party.heroes.erase(hero)
		assert_eq(
			GateTip.who_line(_sim, found.y, found.z),
			"Nobody in the party learns this",
			"%s: nobody ever" % kind
		)
		_world.free()
		_fx.free()
		_sound.free()
		# A party that can.
		path = _before(found.x, found.y, found.z)
		_watch_gates()
		props = _world.side_props
		props.point_at(rect.get_center())
		assert_eq(props.tip.who, "The %s can open this" % who[1], "%s: who can" % kind)
		assert_true(_play_until(SimEvent.Kind.GATE_OPENED, 600), "%s: it opens" % kind)
		props.point_at(_feet_of(path.course.point_at(path.gate_at)) + Vector2(0, -6))
		assert_false(props.tip.visible, "%s: an open gate has no tip" % kind)
		_world.free()
		_fx.free()
		_sound.free()


# --- R6 ------------------------------------------------------------------------


## What stands in the cache rooms of [param stage] as the ambience of the world shown has it:
## each torch and prop, by name and place.
func _cache_dressing(stage: int) -> Array:
	var level: LabyrinthLevel = _sim.labyrinth.level(stage)
	var dressed: AmbienceLevel = _world.ambience.level(stage)
	var found: Array = []
	for path: SidePath in level.side_paths:
		var room := Rect2(path.room.rect.position * int(TILE), path.room.rect.size * int(TILE))
		for prop: AmbienceProp in dressed.cache_torches + dressed.cache_props:
			if room.encloses(prop.rect) or room.grow(2).encloses(prop.rect):
				found.append([prop.name, prop.rect])
	return found


## R6: a torch inside every cache room of 5 stages, the same on a second build, none in a
## ladder's columns; the arrow hidden from turning off to rejoining, shown after.
func test_r6_a_cache_room_is_lit_and_the_arrow_rests() -> void:
	var floor_props: int = 0
	for stage: int in range(1, STAGES + 1):
		_sim = winding_simulation(3)
		Arrival.from_save(_sim.expedition, _sim.tick, stage, stage, stage, false)
		_show(_sim)
		var first: Array = _cache_dressing(stage)
		_world.free()
		_sim = winding_simulation(3)
		Arrival.from_save(_sim.expedition, _sim.tick, stage, stage, stage, false)
		_show(_sim)
		var second: Array = _cache_dressing(stage)
		assert_eq(first, second, "stage %d: the same on a second build" % stage)
		var level: LabyrinthLevel = _sim.labyrinth.level(stage)
		var dressed: AmbienceLevel = _world.ambience.level(stage)
		for index: int in level.side_paths.size():
			var path: SidePath = level.side_paths[index]
			var what: String = "stage %d cache room %d" % [stage, index]
			var rect: Rect2i = path.room.rect
			var room := Rect2(rect.position * int(TILE), rect.size * int(TILE))
			var cache_x: float = _cache_feet(path).x
			var torches: int = 0
			for torch: AmbienceProp in dressed.cache_torches:
				if not room.encloses(torch.rect):
					continue
				torches += 1
				var column: int = floori(torch.rect.position.x / TILE)
				assert_eq(
					roundi(torch.rect.position.y / TILE), rect.end.y - 3, "%s: on its wall" % what
				)
				if path.ladder.has_area():
					var on_ladder: bool = (
						column >= path.ladder.position.x and column < path.ladder.end.x
					)
					assert_false(on_ladder, "%s: its torch is off the ladder's columns" % what)
				assert_gt(
					absf(torch.rect.get_center().x - cache_x), 12.0, "%s: off the cache" % what
				)
				assert_true(dressed.lights.has(torch.light), "%s: its torch gives light" % what)
			assert_eq(torches, 1, "%s: one torch" % what)
			for prop: AmbienceProp in dressed.cache_props:
				if prop.anchor != AmbienceProp.Anchor.FLOOR or not room.grow(2).encloses(prop.rect):
					continue
				floor_props += 1
				var cache := Rect2(cache_x - 10.0, room.position.y, 20.0, room.size.y)
				assert_false(
					cache.intersects(prop.rect), "%s: %s is off the cache" % [what, prop.name]
				)
				if path.ladder.has_area():
					var ladder := Rect2(
						path.ladder.position.x * TILE,
						room.position.y,
						path.ladder.size.x * TILE,
						room.size.y
					)
					assert_false(
						ladder.intersects(prop.rect), "%s: %s is off the ladder" % [what, prop.name]
					)
		_world.free()
	assert_gt(floor_props, 0, "cache rooms have the floor details a room has")

	# The arrow: shown on the way to the path, hidden on it, shown again on the main course.
	var found: Vector2i = _find(2, true)
	_before(found.x, 2, found.y)
	_sim.expedition.deepest_depth = 3
	_sim.expedition.target_depth = 3
	_watch_gates()
	var marker: TargetMarker = _world.target_marker
	_play_frame(false)
	assert_true(marker.visible, "the arrow shows on the main course")
	var hidden: int = 0
	for i: int in 3000:
		_play_frame()
		if _on_path():
			hidden += 1
			assert_false(marker.visible, "hidden on the side path (frame %d)" % i)
			assert_eq(marker.pointing(), 0, "pointing nowhere")
		elif hidden > 0:
			break
	assert_gt(hidden, 60, "the party was on the side path a while")
	assert_true(_off_path(), "and came back")
	assert_eq(_sim.expedition.state, Expedition.State.TRAVELLING, "travelling on")
	assert_true(marker.visible, "the arrow is back with the party on the main course")


# --- R7 ------------------------------------------------------------------------


func _nothing_plays(what: String) -> void:
	assert_eq(_world.fx.count(&"quest"), 0, "%s: no sparks" % what)
	assert_eq(_world.fx.count(&"quest_text"), 0, "%s: no words" % what)
	assert_eq(_fx.coins().size(), 0, "%s: no coins" % what)
	assert_eq(_fx.motes().size(), 0, "%s: no motes" % what)
	assert_eq(_fx.resource_effects.live_icons().size(), 0, "%s: no icons" % what)
	assert_eq(_sound.drain_started().size(), 0, "%s: no sound" % what)


## R7: after a stall and after time away: states true, no effect, no sound; the effects layer is
## empty a few seconds after a cache.
func test_r7_nothing_plays_for_old_events() -> void:
	var found: Vector2i = _far_cache()
	# A stall that holds the whole trip.
	_before(found.x, 2, found.y)
	_watch_gates()
	var props: SideProps = _world.side_props
	_play_frame(false)
	_sound.drain_started()
	_unseen_until(_on_path)
	_unseen_until(_off_path)
	for i: int in 20:
		_sim.step()
	_play_frame(false)
	assert_true(_has(_events, SimEvent.Kind.CACHE_OPENED), "the world heard of the cache late")
	_nothing_plays("after a stall")
	var gate_id: StringName = _sim.labyrinth.level(2).side_paths[found.y].gate
	assert_true(_shows(props.gate(2, found.y), gate_id, &"open"), "the gate open")
	assert_true(_shows(props.cache(2, found.y), &"cache", &"open"), "the cache empty")
	assert_false(props.is_glinting(2, found.y), "and dark")
	assert_eq(_world.quest_props.bar_fraction(), -1.0, "no bar")
	_world.free()
	_fx.free()
	_sound.free()

	# A stall that ends at a sealed gate.
	var sealed: Vector3i = _find_gate(&"rune_seal")
	_before(sealed.x, sealed.y, sealed.z, 1, false)
	_watch_gates()
	_play_frame(false)
	var told: Array[SimEvent] = _events_until(_sim, _passed.bind(sealed), 600)
	assert_eq(_of_kind(told, SimEvent.Kind.GATE_SEALED).size(), 1, "the gate was sealed, unseen")
	for i: int in 20:
		_sim.step()
	_play_frame(false)
	_nothing_plays("after a stall at a sealed gate")
	props = _world.side_props
	assert_true(_shows(props.gate(sealed.y, sealed.z), &"rune_seal", &"closed"), "still closed")
	_world.free()
	_fx.free()
	_sound.free()

	# Time away: a world made over a party already through the gate, its cache not yet opened.
	var path: SidePath = _before(found.x, 2, found.y)
	var run: Expedition = _sim.expedition
	_unseen_until(func() -> bool: return run.side_path >= 0 and run.x > path.gate_at + 1.0)
	_sim.drain_events()
	_watch_gates()
	props = _world.side_props
	_play_frame(false)
	_nothing_plays("after time away")
	assert_true(_shows(props.gate(2, found.y), path.gate, &"open"), "the gate stands open")
	assert_true(_shows(props.cache(2, found.y), &"cache", &"closed"), "its cache still full")

	# Seen as it happens, then a few quiet seconds: nothing stays on the effects layer.
	assert_true(_play_until(SimEvent.Kind.CACHE_OPENED, 600), "the cache opens")
	assert_gt(_world.effects_layer.get_child_count(), 0, "with its effects")
	var quiet: bool = true
	for i: int in 5 * 60:
		quiet = quiet and not _has(_play_frame(), SimEvent.Kind.ENCOUNTER_STARTED)
	assert_true(quiet, "no fight in those seconds")
	assert_eq(_world.effects_layer.get_child_count(), 0, "the effects layer is empty")

	# Another stage: the last one's gates and caches go, the new one's stand.
	Arrival.from_save(run, _sim.tick, 3, 3, 3, false)
	for i: int in 3:
		_play_frame()
	assert_null(props.gate(2, found.y), "the stage left has no gate drawn")
	assert_null(props.cache(2, found.y), "nor cache")
	var paths: Array[SidePath] = _sim.labyrinth.level(3).side_paths
	for index: int in paths.size():
		assert_true(_shows(props.gate(3, index), paths[index].gate, &"closed"), "the new stage's")
		assert_true(_shows(props.cache(3, index), &"cache", &"closed"), "and its caches, full")
	# Another area: the same.
	props.clear()
	assert_null(props.gate(3, 0), "cleared for another area")
	_play_frame(false)
	_world.sync(World.SCAN_SECONDS + STEP)
	assert_not_null(props.gate(3, 0), "and rebuilt by the next scan")


## True once [member _sim]'s party has walked past where side path [param at] (seed, stage,
## place) leaves.
func _passed(at: Vector3i) -> bool:
	var path: SidePath = _sim.labyrinth.level(at.y).side_paths[at.z]
	return _sim.expedition.x > path.at + 1.0

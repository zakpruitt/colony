extends "res://tests/support/play_fixture.gd"
## Acceptance tests for specs/038-rough-edges-on-screen/spec.md, one per requirement.
##
## Each test builds a World with CombatEffects on a seeded simulation, their clocks turned off,
## and plays frames by hand as the game would at 60 frames a second: the simulation steps once
## every FRAMES_PER_TICK frames (times the game's speed), and the world and the effects move on
## by FRAME. A fallen hero lies on its back: its sprite turned a quarter turn (its rotation).

const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const HERO_IDS: Array[int] = [1, 2, 3, 4]
const KNIGHT: int = 1
const ROGUE: int = 2
const GUARDIAN_DEPTH: int = 5
const STRONG_LEVEL: int = 40
## At its closest, in some pose, the front melee hero's pixels come within this many of the
## guardian's (a tile), and the one behind it within two tiles.
const CLOSE_PIXELS: float = 16.0
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
## Monster sprite positions through the first fight of seed 1, every 15 frames, recorded with the
## world as it was before this spec (R5).
const MONSTER_REFERENCE: Array[Vector2] = [
	Vector2(737.72, 192.0),
	Vector2(758.52, 192.0),
	Vector2(776.2266, 192.0),
	Vector2(800.12, 192.0),
	Vector2(817.8266, 192.0),
	Vector2(747.2176, 192.0),
	Vector2(768.0176, 192.0),
	Vector2(773.624, 192.0),
	Vector2(809.6176, 192.0),
	Vector2(815.2241, 192.0),
	Vector2(744.8651, 192.0),
	Vector2(765.6651, 192.0),
	Vector2(758.7202, 192.0),
	Vector2(807.2651, 192.0),
	Vector2(800.3201, 192.0),
	Vector2(741.2673, 192.0),
	Vector2(762.0673, 192.0),
	Vector2(743.5856, 192.0),
	Vector2(803.6673, 192.0),
	Vector2(785.1856, 192.0),
	Vector2(743.2006, 192.0),
	Vector2(757.9424, 192.0),
	Vector2(739.1018, 192.0),
	Vector2(799.5424, 192.0),
	Vector2(768.5857, 192.0),
	Vector2(746.7416, 192.0),
	Vector2(755.867, 192.0),
	Vector2(738.4, 192.0),
	Vector2(795.7048, 192.0),
	Vector2(758.5079, 192.0),
	Vector2(747.8297, 192.0),
	Vector2(759.011, 192.0),
	Vector2(738.4, 192.0),
	Vector2(791.5475, 192.0),
	Vector2(757.7229, 192.0),
	Vector2(748.0, 192.0),
	Vector2(762.716, 192.0),
	Vector2(738.4, 192.0),
	Vector2(787.7056, 192.0),
	Vector2(757.6, 192.0),
]

## The opaque pixels of each baked part, by its sheet and region (R3, spec 048 R7).
var _part_pixels: Dictionary[String, Array] = {}


func before_each() -> void:
	_events = []
	_frames_played = 0


# --- Helpers -------------------------------------------------------------------


## True for a sprite lying in its death pose: shown, dead, on its back (a quarter turn over).
func _lying(sprite: CharacterSprite) -> bool:
	var flat: bool = is_equal_approx(absf(sprite.rotation), PI / 2.0)
	return sprite.visible and sprite.is_dead() and flat


## The world pixels the camera shows.
func _view() -> Rect2:
	var size: Vector2 = _world.get_viewport_rect().size / _world.camera.zoom
	return Rect2(_world.camera.position - size / 2.0, size)


## True if any hero sprite is shown within the camera's view.
func _party_in_view() -> bool:
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = _world.character(id)
		if sprite.visible and _view().grow(-4.0).has_point(sprite.position):
			return true
	return false


## The party on depth 2, its depth 1 stable and depth 2 not, travelling: a wipe now revives it
## on depth 1, a level up and part of the band away.
func _travelling_on_depth_two(speed: int = 1) -> void:
	_show(Simulation.new(SEED), speed, true)
	_sim.set_target_depth(2)
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		_play_frame()
		var e: Expedition = _sim.expedition
		if e.depth == 2 and e.state == Expedition.State.TRAVELLING:
			break
	for i: int in 60:
		_play_frame()
	assert_eq(_sim.expedition.depth, 2, "the party is on depth 2")
	assert_eq(_sim.expedition.last_stable_depth, 1, "with depth 1 the last stable one")


## The party travelling on stage 1, 24 tiles or more from where it revives (the start chamber),
## with Auto off: a wipe now revives it on the same stage, part of the band away. The camera's
## travel is told on one stage; spec 054 R8 makes a revival on another a crossing (test_054).
func _away_on_stage_one(speed: int) -> void:
	_show(Simulation.new(SEED), speed, true)
	_sim.set_auto_push(false)
	var home: float = _sim.expedition.revival_place().x
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		_play_frame()
		var e: Expedition = _sim.expedition
		if absf(e.x - home) >= 24.0 and e.state == Expedition.State.TRAVELLING:
			break
	assert_eq(_sim.expedition.depth, 1, "the party is on stage 1")


## The leftmost and rightmost columns of [param pixels] (x, y).
static func _span(pixels: Dictionary[Vector2i, bool]) -> Vector2:
	var span := Vector2(INF, -INF)
	for pixel: Vector2i in pixels:
		span = Vector2(minf(span.x, pixel.x), maxf(span.y, pixel.x))
	return span


## The opaque pixels of a baked part, within its texture's region: read from the sheet's image
## here, not from the helper that places the heroes (spec 048 R7).
func _opaque_pixels(atlas: AtlasTexture) -> Array:
	var key: String = "%s %s" % [atlas.atlas.resource_path, atlas.region]
	if _part_pixels.has(key):
		return _part_pixels[key]
	var image: Image = atlas.atlas.get_image()
	if image == null or image.is_empty():
		var path: String = ProjectSettings.globalize_path(atlas.atlas.resource_path)
		image = Image.load_from_file(path)
	if image.is_compressed():
		image.decompress()
	var region := Rect2i(atlas.region)
	var found: Array = []
	for y: int in region.size.y:
		for x: int in region.size.x:
			if image.get_pixel(region.position.x + x, region.position.y + y).a >= 0.5:
				found.append(Vector2(x, y))
	_part_pixels[key] = found
	return found


## The world pixels [param sprite] covers as it is drawn now: each opaque pixel of each part shown,
## through the part's, the rig's and the mirror's transforms (every pose: a lunge, a swing, a
## knock back).
func _drawn(sprite: CharacterSprite) -> Dictionary[Vector2i, bool]:
	var covered: Dictionary[Vector2i, bool] = {}
	if not sprite.visible:
		return covered
	var to_world: Transform2D = _world.global_transform.affine_inverse()
	for node: Node in sprite.find_children("*", "Sprite2D", true, false):
		var part: Sprite2D = node as Sprite2D
		var atlas: AtlasTexture = part.texture as AtlasTexture
		if not part.is_visible_in_tree() or atlas == null or atlas.atlas == null:
			continue
		var drawn: Transform2D = to_world * part.global_transform
		for pixel: Vector2 in _opaque_pixels(atlas):
			var at: Vector2 = drawn * (part.offset + pixel + Vector2(0.5, 0.5))
			covered[Vector2i(floori(at.x), floori(at.y))] = true
	return covered


## Problems with the heroes against the guardian now: a hero's drawn pixels on the guardian's.
func _overlaps() -> Array[String]:
	var problems: Array[String] = []
	var guardian: Combatant = GuardianSpacing.fighting_guardian(_sim)
	if guardian == null or _world.character(guardian.id) == null:
		return problems
	var body: Dictionary[Vector2i, bool] = _drawn(_world.character(guardian.id))
	for id: int in HERO_IDS:
		var shared: int = 0
		for pixel: Vector2i in _drawn(_world.character(id)):
			if body.has(pixel):
				shared += 1
		if shared > 0:
			problems.append("hero %d covers %d of the guardian's pixels" % [id, shared])
	return problems


# --- R1 ------------------------------------------------------------------------


func test_r1_wipe_leaves_the_party() -> void:
	_show(Simulation.new(SEED), 1, true)
	for i: int in 120:
		_play_frame()
	_wipe(_sim)
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), "the party is wiped")
	# The collapse plays, then each hero lies where it fell, in its death pose.
	for i: int in roundi(0.5 / FRAME):
		_play_frame()
	var spots: Dictionary[int, Vector2] = {}
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = _world.character(id)
		assert_true(_lying(sprite), "hero %d lies in its death pose" % id)
		assert_lt(sprite.position.distance_to(_feet(id)), TILE, "hero %d where it fell" % id)
		spots[id] = sprite.position
	var moved: int = 0
	var unposed: int = 0
	var empty: int = 0
	var revived: bool = false
	var last_camera: Vector2 = _world.camera.position
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		if _has(events, SimEvent.Kind.PARTY_REVIVED):
			revived = true
			break
		for id: int in HERO_IDS:
			var sprite: CharacterSprite = _world.character(id)
			if sprite.position != spots[id]:
				moved += 1
			if not _lying(sprite):
				unposed += 1
		if not _party_in_view() and _world.camera.position == last_camera:
			empty += 1
		last_camera = _world.camera.position
	assert_true(revived, "the party is revived")
	assert_eq(moved, 0, "no fallen hero moves before the revival")
	assert_eq(unposed, 0, "and each stays in its death pose")
	assert_eq(empty, 0, "on every frame a hero is in view or the camera is on its way")

	# At the revival: at the simulation's place, under the revival light, still down.
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = _world.character(id)
		var feet: Vector2 = _feet(id)
		assert_eq(_world.feet_position(id), feet, "hero %d appears where it is revived" % id)
		assert_between(sprite.position.y, feet.y - TILE, feet.y, "lying on that floor")
		assert_true(sprite.visible and sprite.is_dead(), "hero %d is shown, not yet up" % id)
		assert_true(_world.fallen_party.is_standing(id), "hero %d stands up" % id)
		var lit: bool = false
		for particle: FxParticle in _fx.particles():
			var column: bool = particle.shape == FxParticle.Shape.COLUMN
			if column and particle.position.distance_to(feet) < 1.0:
				lit = true
		assert_true(lit, "hero %d is under the revival light" % id)
	assert_true(_party_in_view(), "the revived party is in view")

	# Rising: from its back, a little further up every frame, then on its feet.
	var tilts: Array[float] = []
	var standing: bool = true
	while standing:
		_play_frame()
		standing = _world.fallen_party.is_standing(KNIGHT)
		if standing:
			tilts.append(absf(_world.character(KNIGHT).rotation))
		assert_true(_party_in_view(), "the party stays in view as it stands")
	assert_gt(tilts.size(), 10, "standing up takes a moment")
	for i: int in range(1, tilts.size()):
		assert_lte(tilts[i], tilts[i - 1] + 0.0001, "the body rises (frame %d)" % i)
	assert_lt(tilts[-1], 0.05, "all the way")
	assert_eq(_world.character(KNIGHT).rotation, 0.0, "and upright")
	for i: int in 5:
		_play_frame()
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = _world.character(id)
		assert_true(sprite.visible and not sprite.is_dead(), "hero %d is on its feet" % id)
		assert_false(_world.fallen_party.is_standing(id))
		assert_lt(sprite.position.distance_to(_feet(id)), 2.0 * TILE, "and with the party")


# --- R2 ------------------------------------------------------------------------


## Plays a wipe on stage 1 at [param speed] through to the heroes on their feet, checking the
## camera's story; returns nothing, asserts as it goes.
func _camera_story(speed: int) -> void:
	_away_on_stage_one(speed)
	_wipe(_sim)
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), "the party is wiped")
	var fallen: FallenParty = _world.fallen_party
	assert_true(fallen.is_telling(), "the wipe is told")
	var destination: Vector2 = fallen.destination()
	# Where the camera rests there: kept inside the band, as it always is.
	var half: float = _world.get_viewport_rect().size.x * 0.5
	destination.x = clampf(destination.x, ceilf(half), floorf(WorldCamera.BAND_WIDTH - half))
	assert_eq(int(_sim.expedition.revival_place().y), 1, "on stage 1")
	var start: Vector2 = _world.camera.position
	var distance: float = start.distance_to(destination)
	assert_gt(distance, 200.0, "the revival is well away from the fall")
	var screen: Vector2 = _world.get_viewport_rect().size
	assert_lt(((destination - start) / screen).length(), FallenParty.CUT_SCREENS, "near enough")

	# Game seconds since the wipe, which may have come a tick or more before this frame.
	var seconds: float = 0.0
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.PARTY_WIPED:
			seconds = float(_sim.tick - event.tick) / Simulation.TICKS_PER_SECOND
	var hold_end: float = FallenParty.HOLD_SECONDS
	var off_the_fallen: float = 0.0
	var began: float = -1.0
	var arrived: float = -1.0
	var fastest: float = 0.0
	var last: Vector2 = start
	var revived: bool = false
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		seconds += FRAME * speed
		var now: Vector2 = _world.camera.position
		var step: float = now.distance_to(last)
		if began < 0.0 and _world.camera.is_travelling():
			began = seconds
		if seconds < hold_end - 0.05:
			var knight: CharacterSprite = _world.character(KNIGHT)
			var fallen_view: Vector2 = _world.camera_target(knight.position, _sim.expedition.facing)
			off_the_fallen = now.distance_to(fallen_view)
		fastest = maxf(fastest, step)
		if arrived < 0.0 and now.distance_to(destination) <= 1.0:
			arrived = seconds
		last = now
		if _has(events, SimEvent.Kind.PARTY_REVIVED):
			revived = true
			break
	assert_true(revived, "the party is revived")
	# At 4x the hold is a quarter of a second of real time: the camera is still settling on them.
	assert_lt(off_the_fallen, 12.0 * speed, "for about 1.5 s the camera stays on the fallen")
	assert_gte(began, hold_end - 0.05, "then it travels")
	assert_lt(began, hold_end + 0.3, "at once")
	assert_gt(arrived, 0.0, "it arrives at the revival's place")
	assert_lt(arrived, seconds - 0.2, "before the heroes stand up there")
	# Eased in and out at an average of TRAVEL_SPEED: never faster than 1.5 times that.
	var bound: float = 1.5 * FallenParty.TRAVEL_SPEED * FRAME * speed + 1.0
	assert_lte(fastest, bound, "never faster than its bound")
	assert_lt(fastest, distance / 4.0, "never a cut")
	# The revived party is where the camera went: it stays put as they stand up.
	assert_true(_party_in_view(), "the revived heroes are in view")
	for i: int in roundi(FallenParty.STAND_SECONDS / speed / FRAME):
		_play_frame()
		assert_lte(_world.camera.position.distance_to(destination), 2.0, "the camera stays")


func test_r2_camera_tells_the_story() -> void:
	_camera_story(1)


func test_r2_camera_tells_the_story_at_4x() -> void:
	_camera_story(4)


# --- R3 ------------------------------------------------------------------------


func test_r3_heroes_at_the_guardian() -> void:
	# The Slime King on depth 5 is on the party's right; the Clay Colossus on depth 10, its left.
	_guardian_fight(GUARDIAN_DEPTH, 1)
	_guardian_fight(2 * GUARDIAN_DEPTH, -1)


## Plays the fight with the guardian of [param depth], which stands on [param side] of the party,
## checking the heroes against its body on every frame, as drawn.
func _guardian_fight(depth: int, side: int) -> void:
	_frames_played = 0
	_events = []
	_sim = Simulation.new(SEED)
	raise_party(_sim, STRONG_LEVEL)
	before_guardian(_sim, depth)
	_show(_sim, 1, true)
	assert_eq(_sim.expedition.facing, side, "the guardian of depth %d is on that side" % depth)
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED), "the guardian's fight starts")
	var guardian: Combatant = GuardianSpacing.fighting_guardian(_sim)
	assert_not_null(guardian, "it is a guardian's fight")
	if guardian == null:
		return
	var body_sprite: CharacterSprite = _world.character(guardian.id)
	var problems: Array[String] = []
	var closest: Dictionary[int, float] = {KNIGHT: INF, ROGUE: INF}
	var numbers: Dictionary[FxText, bool] = {}
	var off_body: Array[String] = []
	var frames: int = 0
	while frames < LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		_play_frame()
		frames += 1
		if GuardianSpacing.fighting_guardian(_sim) == null:
			break
		problems.append_array(_overlaps())
		var body: Rect2 = SpriteBounds.body_rect(body_sprite)
		var drawn: Vector2 = _span(_drawn(body_sprite))
		for id: int in closest:
			var hero: Vector2 = _span(_drawn(_world.character(id)))
			var gap: float = drawn.x - hero.y - 1.0 if side > 0 else hero.x - drawn.y - 1.0
			closest[id] = minf(closest[id], gap)
		# Each damage number on the guardian (the only monster: not red, a hero's) starts over it.
		for text: FxText in _fx.texts():
			if text.kind != &"damage" or numbers.has(text):
				continue
			if text.color == Palette.color(&"red"):
				continue
			numbers[text] = true
			# A number starts at one of its spots around the place over the target (spec 018).
			var x: float = text.position_at(0.0).x
			var reach: float = 4.0 * CombatEffects.NUMBER_STEP
			if x < body.position.x - reach or x > body.end.x + reach:
				off_body.append("a number starts at x %.0f, off %s" % [x, body])
		# The guardian, which every effect on it is placed by, stays where the simulation has it.
		if absf(_world._goals[guardian.id].x - guardian.x * TILE) > 0.01:
			off_body.append("the guardian is not drawn where the simulation has it")
	var at: String = " (depth %d)" % depth
	assert_eq(problems.size(), 0, "no hero's pixels on the guardian's" + at)
	assert_eq(problems.slice(0, 5), [] as Array[String], "the first of them" + at)
	assert_gt(frames, 120, "through a fight of some length" + at)
	# The front melee hero stands at the guardian's edge, the other just behind it, as close as the
	# fight's own spacing lets it: in some pose, its pixels come within a few of the guardian's.
	var front: float = minf(closest[KNIGHT], closest[ROGUE])
	assert_lte(front, CLOSE_PIXELS, "a melee hero stands at the guardian's edge" + at)
	for id: int in closest:
		var near: float = 2.0 * CLOSE_PIXELS
		assert_lte(closest[id], near, "melee hero %d stands at the guardian" % id + at)
	assert_gt(numbers.size(), 0, "the guardian was hit")
	assert_eq(off_body, [] as Array[String], "every hit's number shows on the guardian")


func test_r3_ordinary_fights_are_unchanged() -> void:
	_show(Simulation.new(SEED), 1, true)
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED), "a fight starts")
	assert_null(GuardianSpacing.fighting_guardian(_sim), "an ordinary one")
	var moved: Array[String] = []
	for i: int in 600:
		var events: Array[SimEvent] = _play_frame()
		if _has(events, SimEvent.Kind.ENCOUNTER_ENDED):
			break
		for id: int in HERO_IDS:
			if _world._goals[id] != _feet(id):
				moved.append("hero %d's place is not the simulation's" % id)
	assert_eq(moved, [] as Array[String], "each hero is drawn where the simulation has it")


# --- R4 ------------------------------------------------------------------------


## A simulation of seed 1 or later whose depth 2 or 3 holds side quest [param quest] on its first
## visit two chambers or more along from the party's way in; the party, at [param level], stands at
## the start of that depth facing it, auto-push off. Returns Vector2i(depth, chamber).
func _quest_far_away(level: int, quest: StringName) -> Vector2i:
	for seed_value: int in range(1, 400):
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for depth: int in [2, 3]:
			var rooms: Array[LabyrinthChamber] = sim.labyrinth.level(depth).chambers
			for room: LabyrinthChamber in rooms:
				if room.index < 2 or e.side_quest_in(depth, room.index) != quest:
					continue
				sim.set_auto_push(false)
				e.depth = depth
				e.target_depth = depth
				e.deepest_depth = depth
				e.x = rooms[0].rect.position.x + 1.0
				e.facing = 1
				for hero: Hero in sim.party.heroes:
					hero.level = level
					hero.xp = Hero.xp_for_level(level)
					hero.health = hero.max_health()
				_show(sim, 1, true)
				_play_frame()
				return Vector2i(depth, room.index)
	fail_test("no seed has a %s far along depth 2 or 3" % quest)
	return Vector2i(0, -1)


## The sparkle parts the quest's glint shows over [param seconds] of frames.
func _glint_parts(at: Vector2i, seconds: float) -> Dictionary[StringName, bool]:
	var seen: Dictionary[StringName, bool] = {}
	for i: int in roundi(seconds / FRAME):
		_world.sync(FRAME)
		seen[_world.quest_props.glint_part(at.x, at.y)] = true
	return seen


func test_r4_side_quests_in_the_dark() -> void:
	# A rune stone: the mage reads runes only from level 4, out of reach of a level-1 party's walk
	# (a level-1 rogue can be level 2, a Lockpicker, by the time it reaches a chest).
	var at: Vector2i = _quest_far_away(1, &"rune_stone")
	var props: QuestProps = _world.quest_props
	var stone: Sprite2D = props.prop(at.x, at.y)
	assert_not_null(stone, "the rune stone's prop is shown")
	assert_gt(
		stone.position.distance_to(_world.ambience.party_light_position),
		3.0 * Ambience.PARTY_RADIUS,
		"far out of the party's light"
	)
	assert_true(props.is_glinting(at.x, at.y), "it glints in the dark")
	var seen: Dictionary[StringName, bool] = _glint_parts(at, QuestProps.GLINT_PERIOD * 1.5)
	assert_true(seen.has(&"small") and seen.has(&"big"), "the glint swells and shrinks")
	assert_true(seen.has(&""), "and fades between pulses: it pulses")
	var glints: Node2D = props.get_node("Glints")
	assert_false(glints.z_as_relative, "the glints are drawn")
	assert_gt(glints.z_index, Ambience.DARKNESS_Z, "above the darkness")

	# Walking in, nobody able: within the light it has no glint; it keeps one once passed.
	var lit: bool = false
	var missed: bool = false
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		var near: bool = (
			stone.position.distance_to(_world.ambience.party_light_position)
			< Ambience.PARTY_RADIUS - 8.0
		)
		if near:
			lit = true
			assert_false(props.is_glinting(at.x, at.y), "in the party's light: no glint")
			assert_eq(props.glint_part(at.x, at.y), &"", "none drawn")
		missed = missed or _has(events, SimEvent.Kind.SIDE_QUEST_MISSED)
		if missed and lit and props.is_glinting(at.x, at.y):
			break
	assert_true(lit, "the party came into the stone's chamber")
	assert_true(missed, "and passed the stone it could not read")
	assert_eq(props.prop(at.x, at.y), stone, "the stone is still there")
	assert_true(props.is_glinting(at.x, at.y), "out of the light again, it glints again")


func test_r4_a_done_quest_loses_its_glint() -> void:
	var at: Vector2i = _quest_far_away(6, &"locked_chest")
	var props: QuestProps = _world.quest_props
	assert_true(props.is_glinting(at.x, at.y), "the chest glints from afar")
	assert_true(_play_until(SimEvent.Kind.SIDE_QUEST_DONE), "the rogue opens it")
	_play_frame()
	assert_null(props.prop(at.x, at.y), "the chest is gone")
	assert_false(props.is_glinting(at.x, at.y), "and its glint with it")
	var seen: Dictionary[StringName, bool] = _glint_parts(at, QuestProps.GLINT_PERIOD)
	assert_eq(seen.keys(), [&""] as Array[StringName], "nothing glints there")


# --- R5 ------------------------------------------------------------------------


func test_r5_nothing_else_moves() -> void:
	var alone := Simulation.new(SEED)
	var watched := Simulation.new(SEED)
	_show(watched, 1, true)
	var ticks: int = 10 * 60 * Simulation.TICKS_PER_SECOND
	for i: int in ticks:
		alone.step()
		watched.step()
		_world.sync(1.0 / Simulation.TICKS_PER_SECOND)
		_fx.advance(1.0 / Simulation.TICKS_PER_SECOND)
	assert_eq(watched.state_hash(), alone.state_hash(), "watching changes nothing in ten minutes")

	_show(Simulation.new(SEED), 1, true)
	var trace: Array[Vector2] = []
	var since: int = 0
	var started: bool = false
	_frames_played = 0
	while (
		_frames_played < LIMIT_TICKS_5_MIN * FRAMES_PER_TICK
		and trace.size() < MONSTER_REFERENCE.size()
	):
		_play_frame()
		var battle: Battle = _sim.expedition.battle
		started = started or battle != null
		if not started:
			continue
		since += 1
		if since % 15 != 0 or battle == null:
			continue
		for monster: Combatant in battle.monsters:
			var sprite: CharacterSprite = _world.character(monster.id)
			trace.append(sprite.position if sprite != null else Vector2(-1, -1))
	assert_eq(trace.size(), MONSTER_REFERENCE.size(), "the same samples")
	for i: int in mini(trace.size(), MONSTER_REFERENCE.size()):
		assert_almost_eq(trace[i], MONSTER_REFERENCE[i], Vector2(0.01, 0.01), "sample %d" % i)


# --- R6 ------------------------------------------------------------------------


func _showcase() -> Showcase:
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	return showcase


func _saw(showcase: Showcase, moment: StringName) -> bool:
	return showcase.evidence.get(moment, false)


func test_r6_showcase() -> void:
	var showcase: Showcase = _showcase()
	_sim = showcase.main.simulation
	_world = showcase.main.world
	assert_has(Showcase.names(), &"guardian_fight", "the showcase has a guardian's moment")

	# The wipe: the fallen party lies in view, then is revived and stands up.
	showcase.skip_to(&"wipe")
	var lying: int = 0
	var up: int = 0
	var standing_seen: bool = false
	while showcase.moment() in [&"wipe", &"revival"] and showcase.elapsed < 120.0:
		showcase.advance(FRAME)
		var state: Expedition.State = _sim.expedition.state
		if state == Expedition.State.REVIVING and _saw(showcase, &"wipe"):
			for id: int in HERO_IDS:
				if _lying(_world.character(id)):
					lying += 1
		if _world.fallen_party.is_standing(KNIGHT):
			standing_seen = true
	assert_true(_saw(showcase, &"wipe"), "the wipe happened")
	assert_true(_saw(showcase, &"revival"), "and the revival")
	assert_gt(lying, 4 * 60, "the fallen party lies there through the wipe")
	assert_true(standing_seen, "the revived heroes stand up")
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = _world.character(id)
		if sprite.visible and not sprite.is_dead():
			up += 1
	assert_eq(up, 4, "and are on their feet when the moment ends")

	# The guardian: the heroes at its edge.
	showcase.skip_to(&"guardian_fight")
	var problems: Array[String] = []
	var fighting: int = 0
	while showcase.moment() == &"guardian_fight" and showcase.elapsed < 240.0:
		showcase.advance(FRAME)
		if GuardianSpacing.fighting_guardian(_sim) != null:
			fighting += 1
			problems.append_array(_overlaps())
	assert_true(_saw(showcase, &"guardian_fight"), "the guardian's fight happened")
	assert_gt(fighting, 3 * 60, "and was seen for a while")
	assert_eq(problems, [] as Array[String], "no hero overlaps the guardian")

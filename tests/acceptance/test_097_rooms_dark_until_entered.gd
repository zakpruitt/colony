extends "res://tests/support/dark_stage_fixture.gd"
## Acceptance tests for specs/097-rooms-dark-until-entered/spec.md, one per requirement: a
## winding stage's rooms dark until the party walks into them.
##
## Each test stands a party on a winding stage, shows the world over it and plays frames, the
## ambience moved on with each. A torch is read as it is drawn: the part under the darkness,
## the flame over it, and whether its light is among those the darkness was handed and draws.

const TORCH: String = "res://assets/sprites/ambience/torch.png"
## Seconds from one torch catching to the next, and those a flare lasts.
const CATCH_GAP: float = 0.15
const FLARE_SECONDS: float = 0.3

# --- Helpers -------------------------------------------------------------------


## The torches of the stage shown by room: a room of the route by its index, a cache room by
## [constant AmbienceRooms.CACHE] and its side path's place.
func _torches() -> Dictionary[int, Array]:
	var by_room: Dictionary[int, Array] = {}
	var level: LabyrinthLevel = _shown_level()
	var dressed: AmbienceLevel = _ambience.level(_world.shown_stage())
	for torch: AmbienceProp in dressed.torches:
		if not by_room.has(torch.chamber):
			by_room[torch.chamber] = []
		by_room[torch.chamber].append(torch)
	for torch: AmbienceProp in dressed.cache_torches:
		for place: int in level.side_paths.size():
			var rect: Rect2i = level.side_paths[place].room.rect
			if Rect2(rect.position * int(TILE), rect.size * int(TILE)).has_point(
				torch.rect.get_center()
			):
				by_room[AmbienceRooms.CACHE + place] = [torch]
	return by_room


func _shows_part(texture: Texture2D, part: StringName) -> bool:
	var sheet: PixelSheet = PixelSheet.load_sheet(TORCH)
	if texture == null or not sheet.has_part(part):
		return false
	var want: AtlasTexture = sheet.part(part)
	var has: AtlasTexture = texture as AtlasTexture
	return has != null and has.atlas == want.atlas and has.region == want.region


## True if [param torch] is drawn burning: its bracket, a flame over the darkness, and its light
## among those handed to the darkness.
func _burns(torch: AmbienceProp) -> bool:
	return (
		_shows_part(torch.base(), &"bracket")
		and torch.glowing() != null
		and _handed().has(torch.light)
		and _reaches_shaders(torch.light)
	)


## True if the darkness's shaders take [param light], or it reaches nowhere into the view.
func _reaches_shaders(light: AmbienceLight) -> bool:
	var darkness: AmbienceDarkness = _ambience._darkness
	var in_view: bool = darkness._view_rect.grow(light.radius).has_point(light.position)
	return darkness._near.has(light) or not in_view


## True if [param torch] is drawn out: the unlit part, no flame, and no light handed over.
func _is_out(torch: AmbienceProp) -> bool:
	return (
		_shows_part(torch.base(), &"unlit")
		and torch.glowing() == null
		and not _handed().has(torch.light)
	)


## The rooms of the stage shown whose torches all burn, ascending; a torch neither burning nor
## out, or a room with some of each, fails the test.
func _lit_rooms(what: String) -> Array[int]:
	var lit: Array[int] = []
	var torches: Dictionary[int, Array] = _torches()
	for room: int in torches:
		var burning: int = 0
		var out: int = 0
		for torch: AmbienceProp in torches[room]:
			burning += int(_burns(torch))
			out += int(_is_out(torch))
		var all: int = torches[room].size()
		assert_true(
			(burning == all and out == 0) or (out == all and burning == 0),
			(
				"%s: room %d's %d torches all burn or are all out (%d, %d)"
				% [what, room, all, burning, out]
			)
		)
		assert_eq(
			_ambience.rooms.is_lit(room), burning == all, "%s: room %d remembered" % [what, room]
		)
		if burning == all:
			lit.append(room)
	lit.sort()
	return lit


# --- R1 ------------------------------------------------------------------------


## R1: on 3 stages, every torch of the party's room shows its flame and gives light; every other
## room's torches show the unlit part and none is among the lights handed to the darkness; a
## cache room's torch the same, until the party walks into it.
func test_r1_only_the_partys_room_is_lit_on_arrival() -> void:
	var caches: int = 0
	for stage: int in [1, 2, 3]:
		_watch_rooms(_arrived(SEED, stage, stage + 1))
		var what: String = "stage %d" % stage
		var torches: Dictionary[int, Array] = _torches()
		var room: int = _party_room()
		assert_eq(room, 0, "%s: the party arrives in the first room" % what)
		assert_gt(torches.size(), 3, "%s: rooms with torches" % what)
		assert_true(torches.has(room), "%s: the party's room has a torch" % what)
		assert_eq(_lit_rooms(what), [room] as Array[int], "%s: only the party's room is lit" % what)
		assert_eq(_ambience.rooms.flares(), 0, "%s: lit at once, nothing catching" % what)
		for key: int in torches:
			caches += int(key >= AmbienceRooms.CACHE)
		assert_gt(_handed().size(), 1, "%s: the party's light and its room's" % what)
		for light: AmbienceLight in _handed():
			assert_true(
				light.kind == &"party" or _in_room(light, room),
				"%s: a %s outside the party's room gives light" % [what, light.kind]
			)
		_world.free()
	assert_gt(caches, 0, "cache rooms with a torch were among them")
	# A cache room lights as a room of the route does, once the party walks in.
	var found: Vector2i = _find(STAGE, true)
	var sim: Simulation = winding_simulation(found.x)
	sim.set_auto_push(false)
	set_party_level(sim, 12)
	var path: SidePath = _stand_before(sim, STAGE, found.y, 1)
	_watch_rooms(sim)
	var cache: int = AmbienceRooms.CACHE + found.y
	assert_true(_torches().has(cache), "the cache room has its torch")
	assert_false(_lit_rooms("before the path").has(cache), "a cache room not entered is dark")
	_walk_until(
		func() -> bool:
			var e: Expedition = _sim.expedition
			return e.side_path >= 0 and path.in_room(e.x) and _ambience.rooms.flares() == 0,
		"the party walks into the cache room"
	)
	assert_true(_lit_rooms("in the cache room").has(cache), "the cache room is lit once entered")


# --- R2 ------------------------------------------------------------------------


## R2: walking into the next room, its torches light in order of distance from the party, each
## about 0.15 s after the one before, each light past its rest size and back.
func test_r2_a_room_lights_torch_by_torch() -> void:
	var found: Vector3i = _widest_room(20)
	assert_gt(found.z, 2, "a room with three torches or more")
	var sim: Simulation = _arrived(found.x, STAGE, STAGE + 1)
	var line: StageCourse = sim.labyrinth.level(STAGE).course
	sim.expedition._place(line.stretch_of(found.y).x - 1.5)
	sim.expedition.facing = 1
	_watch_rooms(sim)
	var torches: Array = _torches().get(found.y, [])
	assert_eq(torches.size(), found.z, "the room's torches")
	assert_ne(_party_room(), found.y, "the party starts outside the room")
	var caught: Dictionary[AmbienceProp, int] = {}
	var peak: Dictionary[AmbienceProp, float] = {}
	var settled: Dictionary[AmbienceProp, int] = {}
	var entered: int = -1
	var early: int = 0
	var from: Vector2 = Vector2.ZERO
	var last: int = 0
	for frame: int in 1800:
		_play_frame()
		if entered < 0 and _party_room() == found.y:
			entered = frame
			from = PartyPlaces.anchor(_sim.expedition) * TILE
		for torch: AmbienceProp in torches:
			var rest: float = torch.light.base_radius * (1.0 + AmbienceLevel.TORCH_FLICKER * 0.5)
			if not caught.has(torch):
				if not _burns(torch):
					assert_true(_is_out(torch), "a torch not yet caught is out")
					continue
				caught[torch] = frame
				last = frame
				early += int(entered < 0)
			var most: float = peak.get(torch, 0.0)
			peak[torch] = maxf(most, torch.light.radius)
			if not settled.has(torch) and peak[torch] > rest + 1.0 and torch.light.radius <= rest:
				settled[torch] = frame
		if caught.size() == torches.size() and frame > last + 40:
			break
	assert_gt(entered, 0, "the party walked into the room")
	assert_eq(early, 0, "no torch caught before the party was in the room")
	assert_eq(caught.size(), torches.size(), "every torch caught")
	if caught.size() < torches.size() or entered < 0:
		return
	var order: Array = torches.duplicate()
	order.sort_custom(
		func(a: AmbienceProp, b: AmbienceProp) -> bool:
			return a.light.position.distance_to(from) < b.light.position.distance_to(from)
	)
	var first: AmbienceProp = order[0]
	assert_eq(caught[first], entered, "the nearest torch catches as the party steps in")
	for i: int in order.size():
		var torch: AmbienceProp = order[i]
		var what: String = "torch %d from the party" % i
		if i > 0:
			var before: AmbienceProp = order[i - 1]
			var gap: float = (caught[torch] - caught[before]) * STEP
			assert_almost_eq(gap, CATCH_GAP, 0.035, "%s: about 0.15 s after the one before" % what)
		var rest: float = torch.light.base_radius
		assert_gt(peak[torch], rest * 1.15, "%s: its light swells past its rest" % what)
		assert_true(settled.has(torch), "%s: and comes back to its rest" % what)
		if settled.has(torch):
			var took: float = (settled[torch] - caught[torch]) * STEP
			assert_between(took, 0.15, FLARE_SECONDS + 0.05, "%s: in about 0.3 s" % what)
	assert_eq(_ambience.rooms.flares(), 0, "nothing is flaring once they have settled")


# --- R3 ------------------------------------------------------------------------


## R3: rooms walked stay lit through a fight and a walk back; after a crossing back and on again
## the stage shows only the party's room lit; the same after a revival, a journey and a load,
## with no flare.
func test_r3_the_stage_is_remembered_until_left() -> void:
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1), 4)
	var walked: Array[int] = [0, 1, 2]
	var fights: Array[int] = [0]
	var in_room_two := func() -> bool:
		fights[0] += int(_sim.expedition.state == Expedition.State.FIGHTING)
		return _settled_in(2)
	_walk_until(in_room_two, "the party walks to the third room")
	assert_gt(fights[0], 0, "it fought on the way")
	assert_eq(_lit_rooms("three rooms walked"), walked, "the rooms walked are lit")
	_sim.set_target_depth(STAGE - 1)
	_walk_until(_settled_in.bind(1), "the party walks back")
	assert_eq(_lit_rooms("walking back"), walked, "and stay lit on the walk back")
	# A crossing back, then on again.
	var flared: Array[int] = [0]
	var crossed := func(stage: int) -> bool:
		var there: bool = _world.shown_stage() == stage
		flared[0] += _ambience.rooms.flares() if there else 0
		return there and _sim.expedition.state != Expedition.State.CLIMBING
	_walk_until(crossed.bind(STAGE - 1), "the party crosses back")
	var last: int = _shown_level().chambers.size() - 1
	assert_eq(_party_room(), last, "it arrives in the stage before's last room")
	assert_eq(
		_lit_rooms("a stage back"), [last] as Array[int], "only the party's room is lit there"
	)
	_sim.set_target_depth(STAGE + 1)
	_walk_until(crossed.bind(STAGE), "the party crosses on again")
	assert_eq(_lit_rooms("back on the stage"), [0] as Array[int], "the stage was forgotten")
	assert_eq(flared[0], 0, "no flare on arriving by a crossing")
	# A revival on the stage the party fell on.
	_world.free()
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1), 4)
	var fighting := func() -> bool: return _sim.expedition.battle != null and _party_room() > 0
	_walk_until(fighting, "the party walks into a fight")
	assert_gt(_lit_rooms("before the wipe").size(), 1, "more rooms than one are lit")
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	assert_true(_play_until(SimEvent.Kind.PARTY_REVIVED, 200), "the party is revived")
	assert_eq(_sim.expedition.depth, STAGE, "on the stage it fell on")
	assert_eq(_ambience.rooms.flares(), 0, "no flare at a revival")
	assert_eq(_lit_rooms("revived"), [_party_room()] as Array[int], "only the room it rises in")
	# A journey.
	_walk_until(_settled_in.bind(1), "the party walks on again")
	_sim.expedition.travel.open[&"claypits"] = true
	_sim.set_destination(&"claypits", 1)
	flared[0] = 0
	var arrived := func() -> bool:
		var there: bool = _world.labyrinth_view.labyrinth == _sim.labyrinth
		there = there and _sim.expedition.place == &"claypits"
		flared[0] += _ambience.rooms.flares() if there else 0
		return there and _sim.expedition.state == Expedition.State.TRAVELLING
	_walk_until(arrived, "the party journeys to the Claypits")
	_play_frame(false)
	assert_eq(flared[0], 0, "no flare on arriving from a journey")
	assert_eq(_lit_rooms("after a journey"), [_party_room()] as Array[int], "only its room is lit")
	# A loaded game.
	for hero: Hero in _sim.party.heroes:
		hero.xp = 0  # a save holds no hero kept from levelling
	var data: Dictionary = _through_json(_sim.to_save())
	_world.free()
	_watch_rooms(Simulation.from_save(data, Labyrinth.Shape.WINDING))
	assert_eq(_ambience.rooms.flares(), 0, "no flare in a loaded game")
	assert_eq(_lit_rooms("loaded"), [_party_room()] as Array[int], "only its room is lit")


# --- R4 ------------------------------------------------------------------------


## R4: a quest's and a full cache's glint in an unlit room; a closed gate's sprite and the
## doorways are there as they were, and the doorway on, in a room not entered, is under the
## black (spec 099), which is the ambience's and no change to the sprite.
func test_r4_glints_and_gates_show_in_the_dark() -> void:
	var quest_room: int = -1
	for seed_value: int in range(1, 30):
		var sim: Simulation = _arrived(seed_value, STAGE, STAGE + 1)
		var level: LabyrinthLevel = sim.labyrinth.level(STAGE)
		for room: int in range(2, level.chambers.size()):
			if sim.expedition.quest_in(STAGE, room) != &"" and quest_room < 0:
				quest_room = room
		if quest_room >= 0 and not level.side_paths.is_empty():
			_watch_rooms(sim)
			break
		quest_room = -1
	assert_gt(quest_room, 0, "a stage with a quest waiting past its second room")
	if quest_room < 0:
		return
	var lit: Array[int] = _lit_rooms("on arrival")
	assert_eq(lit, [0] as Array[int], "only the party's room is lit")
	assert_false(_ambience.rooms.is_lit(quest_room), "the quest's room is dark")
	var quests: QuestProps = _world.quest_props
	assert_not_null(quests.prop(STAGE, quest_room), "the quest's prop stands in the dark")
	assert_true(quests.is_glinting(STAGE, quest_room), "and glints")
	var seen: Dictionary[StringName, bool] = _glints_seen(quests.glint_part.bind(STAGE, quest_room))
	assert_true(seen.has(&"small") and seen.has(&"big"), "its glint swells: %s" % [seen.keys()])
	var side: SideProps = _world.side_props
	assert_false(_ambience.rooms.is_lit(AmbienceRooms.CACHE), "the cache room is dark")
	assert_true(side.is_glinting(STAGE, 0), "a full cache glints in the dark")
	seen = _glints_seen(side.glint_part.bind(STAGE, 0))
	assert_true(seen.has(&"small") and seen.has(&"big"), "its glint swells: %s" % [seen.keys()])
	var gate: Sprite2D = side.gate(STAGE, 0)
	assert_not_null(gate, "the gate is drawn")
	if gate != null:
		assert_true(gate.visible and gate.modulate.a == 1.0, "and shown whole")
		assert_eq(SideProps.part_of(gate), &"closed", "closed")
	var view: LabyrinthView = _world.labyrinth_view
	var doors: Array[Node] = view.find_children("Doorway*", "Sprite2D", true, false)
	assert_eq(doors.size(), view.doorways(STAGE).size(), "a sprite at each doorway")
	assert_gt(doors.size(), 1, "the doorway on among them")
	for door: Node in doors:
		var sprite: Sprite2D = door as Sprite2D
		assert_true(sprite.visible and sprite.modulate == Color.WHITE, "a doorway drawn as it is")
	var black: int = 0
	for door: Rect2 in view.doorways(STAGE):
		black += int(_ambience.brightness_at(door.get_center()) == 0.0)
	assert_eq(black, doors.size() - 1, "every doorway but the party's is under the black")


# --- R5 ------------------------------------------------------------------------


## R5: two rooms walked, then a stall in which the party walks three more: after it the first
## two and the one it stands in are lit, the two between are dark, and no flare is running; a
## stall that ends on another stage shows only the party's room.
func test_r5_nothing_lights_for_the_past() -> void:
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1), 4)
	_walk_until(_settled_in.bind(1), "the party walks into the second room")
	assert_eq(_lit_rooms("before the stall"), [0, 1] as Array[int], "two rooms walked and lit")
	var stall: int = World.STALL_TICKS * _world.speed
	var before: int = _sim.tick
	for i: int in LIMIT_TICKS_10_MIN:
		if _party_room() == 4:
			break
		_hurry()
		_sim.step()
	assert_eq(_party_room(), 4, "the party walked three more rooms unseen")
	assert_gt(_sim.tick - before, stall, "a stall to the world")
	# A lit room whose monsters came back in the stall is forgotten (spec 099): the second room
	# is kept empty, so what stays lit is what was lit.
	_sim.expedition._chambers[Vector2i(STAGE, 1)].cleared_tick = _sim.tick
	assert_false(_sim.expedition.is_populated(STAGE, 1), "the second room has not refilled")
	_world.sync(STEP)
	assert_true(_world.catching_up(), "the world catches up")
	_ambience.advance(STEP)
	assert_eq(_ambience.rooms.flares(), 0, "no flare while catching up")
	var kept: Array[int] = [0, 1, 4]
	assert_eq(_lit_rooms("after the stall"), kept, "the rooms lit before stay lit, and its own")
	for i: int in 30:
		_play_frame(false)
		assert_eq(_ambience.rooms.flares(), 0, "and none after it")
	assert_eq(_lit_rooms("a while after"), kept, "the rooms passed unseen stay dark")
	# A stall that ends on another stage is an arrival.
	before = _sim.tick
	for i: int in LIMIT_TICKS_10_MIN:
		var e: Expedition = _sim.expedition
		if e.depth == STAGE + 1 and e.state == Expedition.State.TRAVELLING:
			break
		_hurry()
		_sim.step()
	assert_eq(_sim.expedition.depth, STAGE + 1, "the party crossed on unseen")
	assert_gt(_sim.tick - before, stall, "a stall to the world again")
	_world.sync(STEP)
	assert_true(_world.catching_up(), "the world catches up")
	_ambience.advance(STEP)
	assert_eq(_world.shown_stage(), STAGE + 1, "the next stage is shown")
	assert_eq(_ambience.rooms.flares(), 0, "no flare on arriving in a stall")
	assert_true(_party_room() >= 0, "the party stands in a room there")
	assert_eq(_lit_rooms("a stage on"), [_party_room()] as Array[int], "only its room is lit")


# --- R6 ------------------------------------------------------------------------


## R6: over 60 idle frames the darkness is handed the same lights object unchanged and is not
## redrawn (its own redraw count) but for a handed light's own flicker.
func test_r6_an_idle_frame_does_nothing() -> void:
	_watch_rooms(_arrived(SEED, STAGE, STAGE + 1))
	for i: int in 120:
		_play_frame(false)  # the camera comes to rest
	var darkness: AmbienceDarkness = _ambience._darkness
	var lights: Array[AmbienceLight] = _handed()
	var held: Array[AmbienceLight] = lights.duplicate()
	assert_gt(held.size(), 1, "the party's light and its room's")
	var quiet: int = 0
	for i: int in 60:
		var shapes: Array[Vector4] = _shapes(lights)
		var view: Rect2 = _ambience._visible_rect()
		var redraws: int = darkness.redraws
		_play_frame(false)
		assert_true(is_same(_handed(), lights), "the darkness is handed the same list")
		assert_true(is_same(_ambience.lights(), lights), "which is the ambience's own")
		if _shapes(lights) == shapes and _ambience._visible_rect() == view:
			quiet += 1
			assert_eq(darkness.redraws, redraws, "frame %d: nothing moved, nothing redrawn" % i)
	assert_eq(lights, held, "the same lights, in the same order")
	assert_gt(quiet, 30, "most idle frames move nothing")
	for light: AmbienceLight in lights:
		assert_true(light.kind == &"party" or _in_room(light, 0), "a light of the lit room only")

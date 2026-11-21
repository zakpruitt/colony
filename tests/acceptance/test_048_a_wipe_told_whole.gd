extends "res://tests/support/play_fixture.gd"
## Acceptance tests for specs/048-a-wipe-told-whole/spec.md, one per requirement (R7 is in
## test_038_rough_edges.gd, test_r3_heroes_at_the_guardian).
##
## As in spec 038's tests, a World plays frames by hand as the game would at 60 frames a second:
## the simulation steps once every FRAMES_PER_TICK frames (times the game's speed), and the world
## moves on by FRAME. A stall is the simulation stepping several ticks before one long frame.

const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const HERO_IDS: Array[int] = [1, 2, 3, 4]
const KNIGHT: int = 1
const TICKS: int = Simulation.TICKS_PER_SECOND
## How far from where it revives, in tiles, the party is when it is wiped.
const AWAY: float = 24.0


func before_each() -> void:
	_events = []
	_frames_played = 0


# --- Helpers -------------------------------------------------------------------


func _make_world(simulation: Simulation, speed: int) -> World:
	var world := World.new()
	world.simulation = simulation
	world.speed = speed
	add_child_autofree(world)
	world.set_process(false)
	return world


func _wipe(simulation: Simulation = null) -> void:
	for hero: Hero in (simulation if simulation != null else _sim).party.heroes:
		hero.health = 0


## Steps the simulation alone until its party is down; returns how many ticks that took.
func _step_until_down(simulation: Simulation) -> int:
	for i: int in LIMIT_TICKS_5_MIN:
		simulation.step()
		if simulation.expedition.state == Expedition.State.REVIVING:
			return i + 1
	fail_test("the party never went down")
	return 0


## True for a sprite lying in its death pose: shown, dead, on its back (a quarter turn over).
func _lying(sprite: CharacterSprite) -> bool:
	var flat: bool = is_equal_approx(absf(sprite.rotation), PI / 2.0)
	return sprite.visible and sprite.is_dead() and flat


func _all_lying() -> bool:
	for id: int in HERO_IDS:
		if not _lying(_world.character(id)):
			return false
	return true


## Where the world frames the fallen party: on its front hero, lying.
func _on_the_fallen() -> Vector2:
	var knight: CharacterSprite = _world.character(KNIGHT)
	return _rest(_world.camera_target(knight.position, _sim.expedition.facing))


## The party walking on stage 1, at least AWAY tiles from where it revives there (the start
## chamber), with Auto off: a wipe now revives it on the same stage, part of the band away. Spec
## 054 R8 tells a revival on another stage as a crossing instead (test_054's R8), so the camera's
## travel, which this spec is about, is told on one stage. (It was a wipe on depth 2 reviving on
## depth 1.) Played with no world when [param world] is false.
func _away_on_stage_one(simulation: Simulation, world: bool, speed: int = 1) -> void:
	_sim = simulation
	_sim.set_auto_push(false)
	if world:
		_show(simulation, speed)
	var home: float = _sim.expedition.revival_place().x
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		if world:
			_play_frame()
		elif i % FRAMES_PER_TICK == 0:
			_sim.step()
		var e: Expedition = _sim.expedition
		if absf(e.x - home) >= AWAY and e.state == Expedition.State.TRAVELLING:
			break
	assert_eq(_sim.expedition.depth, 1, "the party is on stage 1")
	assert_eq(_sim.expedition.last_stable_depth, 1, "which is where it revives")
	assert_gte(absf(_sim.expedition.x - home), AWAY, "well away from where it revives")


## Plays on from a wipe being told to the heroes standing at the revival: no cut on the way, the
## camera there before they appear, and they stand up. [param distance] is how far the camera has
## to go.
func _told_to_the_end(distance: float, label: String) -> void:
	var destination: Vector2 = _rest(_world.fallen_party.destination())
	var last: Vector2 = _world.camera.position
	var fastest: float = 0.0
	var arrived: int = -1
	var revived: int = -1
	var moved: int = 0
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		if _has(events, SimEvent.Kind.PARTY_REVIVED):
			revived = i
			break
		fastest = maxf(fastest, _world.camera.position.distance_to(last))
		last = _world.camera.position
		if arrived < 0 and _world.camera.position.distance_to(destination) <= 1.0:
			arrived = i
		if not _all_lying():
			moved += 1
	assert_gt(revived, 0, label + ": the party is revived")
	assert_eq(moved, 0, label + ": the heroes lie where they fell until then")
	assert_lt(fastest, distance / 4.0, label + ": the camera travels, it does not cut")
	assert_between(arrived, 0, revived - 1, label + ": it arrives before the heroes appear")
	assert_true(_world.fallen_party.is_standing(KNIGHT), label + ": at the revival they stand up")
	var tilts: Array[float] = []
	while _world.fallen_party.is_standing(KNIGHT) and tilts.size() < 600:
		tilts.append(absf(_world.character(KNIGHT).rotation))
		_play_frame()
	assert_gt(tilts.size(), 10, label + ": standing up takes a moment")
	assert_gt(tilts[0], 1.4, label + ": from the floor")
	assert_eq(_world.character(KNIGHT).rotation, 0.0, label + ": to their feet")


# --- R1 ------------------------------------------------------------------------


func test_r1_starts_from_where_it_is() -> void:
	# A world made while the party is down, its wipe 1.8 s ago and drained unseen (time away).
	_away_on_stage_one(Simulation.new(SEED), false)
	_wipe()
	var down: int = _step_until_down(_sim)
	assert_gt(down, 0, "the party is down")
	for i: int in 18:
		_sim.step()
	_sim.drain_events()
	_show(_sim)
	var fallen: FallenParty = _world.fallen_party
	assert_true(fallen.is_telling(), "the wipe is told")
	assert_true(_all_lying(), "each hero lies on its back")
	for id: int in HERO_IDS:
		var at: Vector2 = _world.feet_position(id)
		assert_lt(at.distance_to(_feet(id)), 1.0, "hero %d lies where it fell" % id)
	# 1.8 s after the wipe: the hold (1.5 s) over, 0.3 s into the travel from the fallen.
	var from: Vector2 = _world.camera_target(
		_world.character(KNIGHT).position, _sim.expedition.facing
	)
	var to: Vector2 = fallen.destination()
	var length: float = clampf(
		from.distance_to(to) / FallenParty.TRAVEL_SPEED,
		FallenParty.TRAVEL_MIN,
		FallenParty.TRAVEL_MAX
	)
	var share: float = smoothstep(0.0, 1.0, (1.8 - FallenParty.HOLD_SECONDS) / length)
	var expected: Vector2 = _rest(from.lerp(_rest(to), share))
	assert_true(_world.camera.is_travelling(), "the camera is travelling")
	assert_lt(_world.camera.position.distance_to(expected), 2.0, "as far along as 1.8 s says")
	_told_to_the_end(from.distance_to(_rest(to)), "after time away")

	# A wipe heard as an old event, after a stall of 1.1 s: the camera holds on the fallen.
	_events = []
	_frames_played = 0
	_away_on_stage_one(Simulation.new(SEED), true)
	_wipe()
	var ticks: int = _step_until_down(_sim)
	for i: int in 11:
		_sim.step()
	_world.sync(float(ticks + 11) / TICKS)
	var heard: bool = false
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.PARTY_WIPED:
			heard = true
			assert_false(_world.is_recent(event), "heard as an old event")
	assert_true(heard, "the wipe is heard")
	assert_true(_world.fallen_party.is_telling(), "the wipe is told")
	assert_true(_all_lying(), "each hero lies on its back")
	assert_false(_world.camera.is_travelling(), "the camera holds")
	assert_lt(_world.camera.position.distance_to(_on_the_fallen()), 1.0, "on the fallen")
	var distance: float = _on_the_fallen().distance_to(_rest(_world.fallen_party.destination()))
	_told_to_the_end(distance, "heard late")


# --- R2 ------------------------------------------------------------------------


func test_r2_a_stall_keeps_the_camera() -> void:
	# Two worlds of the same game: one plays every frame, the other stalls now and then.
	var steady := Simulation.new(SEED)
	var steady_world: World = _make_world(steady, 1)
	steady.set_auto_push(false)
	_away_on_stage_one(Simulation.new(SEED), true)
	for i: int in _frames_played:
		if i % FRAMES_PER_TICK == 0:
			steady.step()
		steady_world.sync(FRAME)
	assert_eq(steady.state_hash(), _sim.state_hash(), "the two are the same game")
	_wipe(steady)
	_wipe()
	var frames: int = 0
	while _sim.expedition.state != Expedition.State.REVIVING and frames < LIMIT_TICKS_5_MIN:
		for sim: Simulation in [steady, _sim]:
			sim.step()
		for i: int in FRAMES_PER_TICK:
			steady_world.sync(FRAME)
			_world.sync(FRAME)
		frames += 1
	var down_at: int = _sim.tick
	# Game ticks since the wipe to stall at, and ticks the stall lasts; what the camera is doing.
	var stalls: Array[Vector2i] = [Vector2i(3, 8), Vector2i(15, 7), Vector2i(38, 8)]
	var doing: Array[String] = ["holding", "travelling", "arrived"]
	for n: int in stalls.size():
		var stall: Vector2i = stalls[n]
		while _sim.tick - down_at < stall.x:
			for sim: Simulation in [steady, _sim]:
				sim.step()
			for i: int in FRAMES_PER_TICK:
				steady_world.sync(FRAME)
				_world.sync(FRAME)
		var ticks: int = stall.y
		assert_gt(ticks, World.STALL_TICKS, "a stall long enough to snap the sprites")
		for i: int in ticks:
			steady.step()
			for j: int in FRAMES_PER_TICK:
				steady_world.sync(FRAME)
			_sim.step()
		_world.sync(ticks * FRAMES_PER_TICK * FRAME)
		var what: String = doing[n]
		var gap: float = _world.camera.position.distance_to(steady_world.camera.position)
		assert_lt(gap, 2.0, "a stall while %s leaves the camera where the story has it" % what)
		if what == "travelling":
			assert_true(_world.camera.is_travelling(), "the camera travels on")
		if what == "arrived":
			var destination: Vector2 = _rest(_world.fallen_party.destination())
			assert_lt(_world.camera.position.distance_to(destination), 1.0, "at the revival")
		# The story's clock counted the stall: a few frames on, the two still agree.
		for i: int in 2:
			for sim: Simulation in [steady, _sim]:
				sim.step()
			for j: int in FRAMES_PER_TICK:
				steady_world.sync(FRAME)
				_world.sync(FRAME)
		gap = _world.camera.position.distance_to(steady_world.camera.position)
		assert_lt(gap, 2.0, "and its clock went on through the stall (%s)" % what)
	assert_eq(_sim.expedition.state, Expedition.State.REVIVING, "all before the revival")
	assert_gt(
		_world.camera.position.distance_to(_on_the_fallen()), 100.0, "the camera left the fallen"
	)


# --- R3 ------------------------------------------------------------------------


func test_r3_camera_arrives_first() -> void:
	for speed: int in [1, 2, 4]:
		for late: bool in [false, true]:
			var label: String = "%dx, %s" % [speed, "seen 2 s late" if late else "seen at once"]
			_events = []
			_frames_played = 0
			_away_on_stage_one(Simulation.new(SEED), true, speed)
			_wipe()
			if late:
				var ticks: int = _step_until_down(_sim)
				for i: int in 2 * TICKS:
					_sim.step()
				_world.sync(float(ticks + 2 * TICKS) / TICKS / speed)
			else:
				assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), label + ": wiped")
			assert_true(_world.fallen_party.is_telling(), label + ": the wipe is told")
			var destination: Vector2 = _rest(_world.fallen_party.destination())
			var arrived: int = -1
			var revived: int = -1
			for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
				if _has(_play_frame(), SimEvent.Kind.PARTY_REVIVED):
					revived = i
					break
				if arrived < 0 and _world.camera.position.distance_to(destination) <= 1.0:
					arrived = i
			assert_gt(revived, 0, label + ": revived")
			assert_between(arrived, 0, revived - 1, label + ": the camera is there first")


# --- R4 ------------------------------------------------------------------------


func test_r4_second_wipe_starts_clean() -> void:
	_show(Simulation.new(SEED))
	for i: int in 120:
		_play_frame()
	_wipe()
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), "the party is wiped")
	assert_true(_play_until(SimEvent.Kind.PARTY_REVIVED), "and revived")
	for i: int in roundi(FallenParty.STAND_SECONDS / 2.0 / FRAME):
		_play_frame()
	var over: float = absf(_world.character(KNIGHT).rotation)
	assert_true(_world.fallen_party.is_standing(KNIGHT), "the heroes are standing up")
	assert_between(over, 0.2, PI / 2.0 - 0.2, "half way up")
	_wipe()
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), "wiped again as they stand")
	for i: int in roundi(0.5 / FRAME):
		_play_frame()
	var floor_y: float = (_sim.labyrinth.level(_sim.expedition.depth).floor_y + 1) * TILE
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = _world.character(id)
		assert_true(_lying(sprite), "hero %d lies on its back" % id)
		assert_eq(_world.feet_position(id).y, floor_y, "hero %d's feet on the floor" % id)
		assert_between(sprite.position.y, floor_y - TILE, floor_y, "its back on the floor")


# --- R5 ------------------------------------------------------------------------


func test_r5_revival_place() -> void:
	for seed_value: int in [1, 2, 3]:
		for stable: int in [1, 2, 4, 7]:
			var sim := Simulation.new(seed_value)
			var e: Expedition = sim.expedition
			e.last_stable_depth = stable
			e.deepest_depth = stable
			for i: int in 20:
				sim.step()
			var label: String = "seed %d, stable depth %d" % [seed_value, stable]
			var before: int = sim.state_hash()
			var place: Vector3 = e.revival_place()
			assert_eq(sim.state_hash(), before, label + ": reading it changes nothing")
			_wipe(sim)
			var down: int = _step_until_down(sim)
			assert_gt(down, 0, label + ": down")
			assert_eq(e.revival_place(), place, label + ": the same while the party is down")
			var hash_down: int = sim.state_hash()
			var revive_at: int = e.revive_tick
			assert_eq(sim.state_hash(), hash_down, label + ": reading when changes nothing")
			assert_eq(revive_at - sim.tick, roundi(Expedition.REVIVE_SECONDS * TICKS), label)
			while e.state == Expedition.State.REVIVING:
				sim.step()
			assert_eq(sim.tick, revive_at, label + ": revived on the tick it said")
			assert_eq(e.x, place.x, label + ": at the column it said")
			assert_eq(e.depth, int(place.y), label + ": on the depth it said")
			assert_eq(e.facing, int(place.z), label + ": facing the way it said")


# --- R6 ------------------------------------------------------------------------


func test_r6_far_cut_waits() -> void:
	_show(Simulation.new(SEED))
	_sim.expedition.last_stable_depth = 8
	_sim.expedition.deepest_depth = 8
	for i: int in 30:
		_play_frame()
	_wipe()
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), "the party is wiped")
	var wiped_at: int = _sim.tick
	var destination: Vector2 = _rest(_world.fallen_party.destination())
	var screen: float = _world.get_viewport_rect().size.y
	var away: Array[String] = []
	var cut_at: float = -1.0
	var built: bool = false
	var last: Vector2 = _world.camera.position
	var seconds: float = 0.0
	var revived: bool = false
	var dark: float = -1.0
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		seconds = float(_sim.tick - wiped_at) / TICKS
		var now: Vector2 = _world.camera.position
		if cut_at < 0.0 and now.distance_to(last) > 3.0 * screen:
			cut_at = seconds
			built = _world.labyrinth_view.built_depths().has(8)
			dark = _world.crossing.darkness()
		if _has(events, SimEvent.Kind.PARTY_REVIVED):
			revived = true
			break
		if cut_at < 0.0 and seconds > 1.0 and now.distance_to(_on_the_fallen()) > 2.0:
			away.append("at %.1f s the camera is off the fallen" % seconds)
		last = now
	assert_true(revived, "the party is revived")
	assert_eq(away.slice(0, 3), [] as Array[String], "until the cut the camera is on the fallen")
	# Spec 054 R8: stage 8 is another stage, so the cut is the crossing's, at the revival itself and
	# under a dark screen (it came shortly before the revival in spec 048).
	var revive_at: float = Expedition.REVIVE_SECONDS
	assert_between(cut_at, revive_at - 0.05, revive_at + 0.05, "it cuts by the revival")
	assert_eq(dark, 1.0, "while the screen is dark")
	assert_true(built, "to a labyrinth already built there")
	assert_lt(_world.camera.position.distance_to(destination), 1.0, "and is there when they rise")
	assert_true(_world.fallen_party.is_standing(KNIGHT), "where they stand up")

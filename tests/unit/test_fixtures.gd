extends "res://tests/support/play_fixture.gd"
## Acceptance tests for specs/081-shared-test-fixtures/spec.md R2 and R3: each shared fixture does
## what the copies it replaced did.

const SEED: int = 81
const STRONG_LEVEL: int = 40


func before_each() -> void:
	_sim = Simulation.new(SEED)


## R2, R3: the Hud fixture builds a HUD over the test's simulation that shows its party, on the UI
## layer, nothing processing by itself; [method HudFixture._make_hud] does the same for another.
func test_the_hud_fixture_builds_a_working_hud() -> void:
	_build_hud()
	_hud.advance(0.0)
	assert_eq(_world.simulation, _sim, "the world shows the test's simulation")
	assert_eq(_hud.frames.size(), _sim.party.heroes.size(), "a frame per hero")
	for i: int in _hud.frames.size():
		assert_eq(_hud.frames[i].hero_id, _sim.party.heroes[i].id, "frame %d is its hero's" % i)
	assert_not_null(_ui, "the UI layer is built")
	assert_not_null(_hud.hero_windows, "the hero windows came from the UI layer")
	for node: Node in [_world, _fx, _hud]:
		assert_false(node.is_processing(), "%s does not process by itself" % node.name)
	assert_eq(_frame_parts.size(), 1, "a frame moves the HUD on after the world")

	var other := Simulation.new(SEED + 1)
	var made: Hud = _make_hud(other, false)
	assert_eq(made, _hud, "the HUD made is the test's")
	assert_eq(_sim, other, "over the simulation it was given")
	assert_null(_ui, "and without the UI layer when asked")
	assert_eq(made.frames.size(), other.party.heroes.size(), "showing that party")


## R2: the ride to a guardian leaves the party walking into the guardian's chamber of the stage,
## auto-push off, one chamber short: the next steps start the guardian's fight.
func test_the_ride_to_a_guardian_arrives() -> void:
	raise_party(_sim, STRONG_LEVEL)
	var depth: int = Expedition.GUARDIAN_EVERY
	var lair: LabyrinthChamber = before_guardian(_sim, depth, 0.0, true, true)
	var e: Expedition = _sim.expedition
	assert_eq(lair, _sim.labyrinth.level(depth).shaft_chamber(), "the guardian's chamber")
	assert_eq(e.depth, depth, "on the guardian's stage")
	assert_false(e.auto_push, "auto-push off")
	assert_eq(e.target_depth, depth + 1, "bound past it")
	assert_eq(e.deepest_depth, depth, "the stage reached")
	assert_eq(e.last_stable_depth, depth - 1, "the stage above it held")
	assert_true(e.x < lair.rect.position.x or e.x >= lair.rect.end.x, "short of the chamber")
	assert_true(
		step_until(_sim, func() -> bool: return e.battle != null, 200), "a fight starts at once"
	)
	assert_eq(e.battle.monsters[0].def_id, e.guardian_of(depth), "the guardian's fight")

	var plain := Simulation.new(SEED)
	var back: float = 6.0
	var shaft: LabyrinthChamber = before_guardian(plain, depth, back)
	var walking_in: float = shaft.rect.position.x - 1.0 - back
	if shaft.index == 0:
		walking_in = shaft.rect.end.x + back
	assert_eq(plain.expedition.x, walking_in, "further back when asked")
	assert_eq(plain.expedition.deepest_depth, 1, "the stage not counted as reached unless asked")


## R2, R3: one frame steps the simulation a tick, the world syncs to it and hears its events, and
## each part of the frame moves on once by the frame's seconds.
func test_a_played_frame_moves_everything_once() -> void:
	_build_hud()
	var moved: Array[float] = []
	_frame_parts.append(func(seconds: float) -> void: moved.append(seconds))
	var tick: int = _sim.tick
	_frame()
	assert_eq(_sim.tick, tick + 1, "the simulation stepped a tick")
	assert_eq(_world._last_tick, _sim.tick, "the world synced to it")
	assert_true(_sim.drain_events().is_empty(), "and took its events")
	assert_eq(moved, [STEP] as Array[float], "each part moved on once by a frame")

	moved.clear()
	_frame(3, 0.1)
	assert_eq(_sim.tick, tick + 4, "three ticks in one frame")
	assert_eq(moved, [0.1] as Array[float], "the parts once, by the seconds given")

	moved.clear()
	_frame_ticks = 0
	_frame()
	assert_eq(_sim.tick, tick + 4, "a frame of the views alone steps nothing")
	assert_eq(moved.size(), 1, "but moves them on")

	_frame_ticks = 1
	_show(_sim, 1, true)
	assert_eq(_frame_parts, [_fx.advance] as Array[Callable], "the effects move on with play")
	var played: int = 0
	var told: Array[SimEvent] = []
	for i: int in FRAMES_PER_TICK * 20:
		told.append_array(_play_frame())
		played += 1
	assert_eq(_sim.tick, tick + 24, "a tick every %d frames of play" % FRAMES_PER_TICK)
	assert_eq(_frames_played, played, "every frame counted")
	assert_eq(told, _events, "each told the events it passed on")


## R2, R3: a wait gives up after its script's limit (fifty minutes unless the script says) or the
## call's; the world follows each tick, and the HUD each tick by the script's seconds, or once at
## the end when the script says.
func test_a_wait_stops_at_its_limit_and_shows_as_set() -> void:
	_build_hud(false)
	_hud.advance(0.0)
	assert_eq(_step_limit, LIMIT_TICKS, "a wait is fifty minutes long unless the script says")
	var never: Callable = func() -> bool: return false
	_step_limit = 40
	var tick: int = _sim.tick
	assert_false(_step_until(never), "a wait that never ends gives up")
	assert_eq(_sim.tick, tick + 40, "after the script's limit")
	assert_false(_step_until(never, 5), "and after the call's")
	assert_eq(_sim.tick, tick + 45, "when it gives one")
	assert_eq(_world._last_tick, _sim.tick, "the world followed")

	var count: Array[int] = [0]
	var fourth: Callable = func() -> bool:
		count[0] += 1
		return count[0] % 4 == 0
	_sim.party.gold += 1000
	_tick_seconds = 1.0
	assert_true(_step_until(fourth), "the wait ends when it comes true")
	assert_eq(_hud.shown_gold(), _sim.party.gold, "four ticks of a second each: the gold caught up")

	_sim.party.gold += 1000
	_tick_seconds = 0.5
	assert_true(_step_until(fourth), "the wait ends when it comes true")
	assert_lt(_hud.shown_gold(), _sim.party.gold, "four ticks of half a second: not yet")

	_hud.advance(Hud.GOLD_CATCH_UP_SECONDS)
	_sim.party.gold += 1000
	_tick_seconds = 1.0
	_hud_each_tick = false
	assert_true(_step_until(fourth), "the wait ends when it comes true")
	assert_lt(_hud.shown_gold(), _sim.party.gold, "the HUD moved on only once, at the end")
	assert_eq(_world._last_tick, _sim.tick, "while the world followed every tick")


## R2, R3: a frame of the main scene moves its parts on in the order named, the HUD alone unless
## the script names others.
func test_a_main_frame_moves_its_parts_in_order() -> void:
	var fixture := MainFixture.new()
	assert_eq(fixture._frame_parts, [&"hud"] as Array[StringName], "the HUD alone by default")
	fixture.free()
	var main: Main = make_main()
	add_child_autofree(main)
	var names: Array[StringName] = [&"moment", &"hud", &"effects", &"milestones", &"sound"]
	var owners: Array[Object] = [
		main.ui.moment, main.hud, main.effects, main.milestones, main.sound
	]
	var methods: Array[StringName] = [&"advance", &"advance", &"advance", &"advance", &"_process"]
	var calls: Array[Callable] = MainFixture.frame_calls(main, names)
	assert_eq(calls.size(), names.size(), "a call for each part named")
	for i: int in calls.size():
		assert_eq(calls[i].get_object(), owners[i], "part %d is %s's" % [i, names[i]])
		assert_eq(calls[i].get_method(), methods[i], "part %d moves %s on" % [i, names[i]])
	assert_false(MainFixture.frame_calls(main, [&"nothing"])[0].is_valid(), "no part by that name")

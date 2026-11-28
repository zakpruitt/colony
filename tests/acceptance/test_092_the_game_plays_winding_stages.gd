extends ColonyTest
## Spec 092: the game itself plays winding stages. A new game, a loaded save, the time away and
## the showcase are all on stages three floors tall, and the preview scene that used to show them
## is gone.

const WINDING: Labyrinth.Shape = Labyrinth.Shape.WINDING
const FLAT: Labyrinth.Shape = Labyrinth.Shape.FLAT
const FRAME: float = 1.0 / 30.0
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const SECOND_AREA: StringName = &"claypits"
## R3: the time away, in seconds.
const HOUR: float = 3600.0

var _path: String = save_path()

# --- Helpers -------------------------------------------------------------------


## A main scene in the tree, its own processing off, loading from [param store_path] if given.
func _started(store_path: String = "", away: float = -1.0) -> Main:
	var main: Main = make_main()
	if store_path != "":
		main.save_store = SaveStore.new(store_path)
	main.away_seconds_override = away
	add_child_autofree(main)
	if main.driver != null:
		main.driver.set_process(false)
		main.world.set_process(false)
		main.effects.set_process(false)
	return main


## True if [param view] draws a ladder part on every tile of every ladder of [param level],
## which has at least one.
func _draws_ladders(view: LabyrinthView, level: LabyrinthLevel) -> bool:
	if level.ladders.is_empty():
		return false
	for ladder: Rect2i in level.ladders:
		for y: int in range(ladder.position.y, ladder.end.y):
			for x: int in range(ladder.position.x, ladder.end.x):
				var drawn: bool = false
				for visual: String in view.visuals_at(Vector2i(x, y)):
					drawn = drawn or visual.begins_with("ladder/")
				if not drawn:
					return false
	return true


## A version 9 save with something in every part of the progress: gold, levels, talents, an
## upgrade, a resource, orders, and two areas with their safe and furthest stages.
func _full_save() -> Dictionary:
	var sim := Simulation.new(7)
	raise_party(sim, 9)
	for hero: Hero in sim.party.heroes:
		_spend_talents(hero)
	sim.party.gold = 4321
	sim.upgrades.set_rank(&"sharp_blades", 2)
	sim.party.set_resource(&"glowcaps", 5)
	sim.set_pace(Expedition.Pace.BOLD)
	sim.set_guardian_order(Expedition.GuardianOrder.HOLD)
	sim.set_auto_push(false)
	sim.expedition.last_stable_depth = 3
	sim.expedition.deepest_depth = 6
	sim.expedition.travel.open[SECOND_AREA] = true
	sim.set_destination(SECOND_AREA, 1)
	var arrived: Callable = func() -> bool:
		var e: Expedition = sim.expedition
		return e.place == SECOND_AREA and e.state != Expedition.State.JOURNEYING
	step_until(sim, arrived, LIMIT_TICKS_5_MIN)
	sim.expedition.last_stable_depth = 2
	sim.expedition.deepest_depth = 4
	sim.set_target_depth(3)
	sim.step()
	var data: Dictionary = sim.to_save()
	var version: int = data["version"]
	var safe: int = data["last_stable_depth"]
	assert_eq(version, 12, "the save is version 12")
	assert_eq(safe, 2, "the safe stage is one past the first")
	assert_false((data["areas"] as Dictionary).is_empty(), "it has been in two areas")
	return _through_json(data)


## A version 1 save, written by hand: two heroes, last stable depth 3.
func _first_save() -> Dictionary:
	return {
		"version": 1,
		"seed": 99,
		"tick": 5000,
		"gold": 321,
		"heroes":
		[
			{"class": "knight", "level": 4, "xp": 300},
			{"class": "mage", "level": 2, "xp": 60},
		],
		"last_stable_depth": 3,
		"deepest_depth": 4,
		"target_depth": 4,
		"auto_push": false,
	}


## The showcase in the tree, played by hand, cut to [param moment].
func _showcase_at(moment: StringName) -> Showcase:
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(moment)
	return showcase


## Asserts the party of [param sim] stands on the course of its stage: the anchor at the point of
## its distance, inside a room, a tunnel or a ladder of that stage, on a stage with ladders.
func _assert_on_course(sim: Simulation, what: String) -> void:
	var e: Expedition = sim.expedition
	var level: LabyrinthLevel = sim.labyrinth.level(e.depth)
	assert_eq(sim.labyrinth.shape, WINDING, "%s: the stage is winding" % what)
	assert_between(e.x, level.course.start, level.course.end, "%s: a distance on the course" % what)
	var feet: Vector2 = PartyPlaces.anchor(e)
	assert_eq(feet, level.course.point_at(e.x), "%s: the anchor is at its distance" % what)
	var tile := Vector2i(floori(feet.x), floori(feet.y))
	var open: bool = false
	for rect: Rect2i in level.open_rects():
		open = open or rect.has_point(tile)
	assert_true(open, "%s: the anchor at %s stands in open space" % [what, feet])


# --- R1 ------------------------------------------------------------------------


func test_r1_a_new_game_is_winding() -> void:
	var main: Main = _started()
	var sim: Simulation = main.simulation
	assert_eq(sim.labyrinth.shape, WINDING, "a new game's simulation is winding")
	assert_eq(sim.tick, 0, "and new")
	for id: StringName in Content.area_ids():
		assert_eq(sim.expedition.travel.labyrinth(id).shape, WINDING, "%s is winding" % id)
	main.world.sync(FRAME)
	var view: LabyrinthView = main.world.labyrinth_view
	assert_eq(view.labyrinth, sim.labyrinth, "the world shows the simulation's labyrinth")
	assert_true(_draws_ladders(view, sim.labyrinth.level(1)), "the stage on screen has a ladder")

	sim.expedition.travel.open[SECOND_AREA] = true
	sim.set_destination(SECOND_AREA, 1)
	var arrived: Callable = func() -> bool:
		var e: Expedition = sim.expedition
		return e.place == SECOND_AREA and e.state != Expedition.State.JOURNEYING
	assert_true(step_until(sim, arrived, LIMIT_TICKS_5_MIN), "the party reaches the second area")
	main.world.sync(FRAME)
	main.world.sync(FRAME)
	assert_eq(sim.labyrinth.shape, WINDING, "the second area's labyrinth is winding")
	assert_ne(sim.labyrinth, sim.expedition.travel.labyrinth(AreaTravel.first_area()))
	assert_eq(view.labyrinth, sim.labyrinth, "the world shows it")
	var stage: int = main.world.shown_stage()
	assert_true(_draws_ladders(view, sim.labyrinth.level(stage)), "and its stage has a ladder")


# --- R2 ------------------------------------------------------------------------


func test_r2_a_save_comes_back_winding_with_its_progress() -> void:
	var saves: Dictionary[String, Dictionary] = {
		"version 9": _full_save(), "version 1": _first_save()
	}
	for what: String in saves:
		var data: Dictionary = saves[what]
		assert_eq(Simulation.save_problems(data).size(), 0, "%s: the save is good" % what)
		var flat: Simulation = Simulation.from_save(data)
		assert_true(SaveStore.new(_path).write(data), "%s: written to the store" % what)
		var main: Main = _started(_path)
		var sim: Simulation = main.simulation
		assert_eq(sim.labyrinth.shape, WINDING, "%s: Main loads it winding" % what)
		assert_eq(sim.tick, flat.tick, "%s: loaded, not a new game" % what)
		var kept: Dictionary = sim.to_save()
		var wanted: Dictionary = flat.to_save()
		var version: int = kept["version"]
		assert_eq(version, 12, "%s: the save's version stays 12" % what)
		assert_eq(kept.keys(), wanted.keys(), "%s: nothing is added to the save" % what)
		for key: String in wanted:
			var loaded: String = JSON.stringify(kept[key])
			var as_flat: String = JSON.stringify(wanted[key])
			assert_eq(loaded, as_flat, "%s: %s is what it loads with flat" % [what, key])
		var e: Expedition = sim.expedition
		assert_eq(e.depth, e.last_stable_depth, "%s: the party is on its safe stage" % what)
		assert_eq(e.depth, flat.expedition.last_stable_depth, "%s: the same one" % what)
		var line: StageCourse = sim.labyrinth.level(e.depth).course
		assert_eq(e.x, line.entry, "%s: at the entry of its course" % what)
		assert_eq(e.facing, 1, "%s: facing the way on" % what)
		_assert_on_course(sim, what)
		main.free()


func test_r2_from_save_alone_is_flat() -> void:
	for data: Dictionary in [_full_save(), _first_save()]:
		var alone: Simulation = Simulation.from_save(data)
		assert_eq(alone.labyrinth.shape, FLAT, "with no shape a loaded simulation is flat")
		var winding: Simulation = Simulation.from_save(data, WINDING)
		assert_eq(winding.labyrinth.shape, WINDING, "with the shape it is winding")
		for id: StringName in Content.area_ids():
			var there: Labyrinth = winding.expedition.travel.labyrinth(id)
			assert_eq(there.shape, WINDING, "in %s too" % id)
		assert_eq(winding.to_save(), alone.to_save(), "and the progress is the same")
	assert_null(Simulation.from_save({"version": 8}, WINDING), "a bad save is still refused")


# --- R3 ------------------------------------------------------------------------


func test_r3_time_away_is_played_winding() -> void:
	var data: Dictionary = _first_save()
	data[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system() - HOUR
	assert_true(SaveStore.new(_path).write(data), "the stamped save is written")
	var saved: Dictionary = SaveStore.new(_path).read()
	var main: Main = _started(_path, HOUR)
	assert_true(main.is_catching_up(), "an hour away is replayed")
	if not main.is_catching_up():
		return
	var replayed: Simulation = main.replay.simulation
	assert_eq(replayed, main.simulation, "the replay steps the simulation Main loaded")
	assert_eq(replayed.labyrinth.shape, WINDING, "which is winding")
	await wait_until(func() -> bool: return not main.is_catching_up(), 120.0, "the replay ends")
	assert_eq(main.simulation, replayed, "the game goes on with it")
	assert_eq(replayed.tick, 5000 + ticks_in(HOUR), "an hour of ticks later")
	var report: AwayReport = main.away_report
	assert_not_null(report, "there is a report")
	if report == null:
		return
	assert_gt(report.kills, 0, "the report counts fights")

	# The same save loaded winding and played an hour by hand: the report tells of that game.
	var reference: Simulation = Simulation.from_save(saved, WINDING)
	var gold_before: int = reference.party.gold
	var kills: int = 0
	for i: int in ticks_in(HOUR):
		reference.step()
		for event: SimEvent in reference.drain_events():
			if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
				kills += 1
	assert_eq(report.kills, kills, "the kills of the winding game")
	assert_eq(report.gold_gained, reference.party.gold - gold_before, "and its gold")
	assert_eq(report.depth_after, reference.expedition.depth, "and where it ended")
	assert_eq(replayed.state_hash(), reference.state_hash(), "the replayed game is that game")
	assert_true(main.away_window.is_open(), "and the window tells of it")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_showcase_cuts_by_the_course() -> void:
	# To the way on: a few tiles of course short of the exit, walking to it.
	var showcase: Showcase = _showcase_at(&"climb_down")
	var sim: Simulation = showcase.main.simulation
	var e: Expedition = sim.expedition
	var line: StageCourse = sim.labyrinth.level(e.depth).course
	assert_eq(e.depth, ShowcaseMoments.CLIMB_DEPTH, "the way on: cut to the stage of the climb")
	assert_eq(e.state, Expedition.State.TRAVELLING, "the way on: still walking")
	_assert_on_course(sim, "the way on")
	assert_between(
		e.x,
		line.exit - ShowcaseMoments.WAY_ON_APPROACH,
		line.exit,
		"the way on: a few tiles of course short of the exit"
	)
	var last: int = ChamberRules.way_on_room(line)
	var last_stretch: Vector2 = line.stretch_of(last)
	assert_between(
		e.x, last_stretch.x - 1.0, last_stretch.y, "the way on: in or beside the last room"
	)
	assert_eq(e.facing, 1, "the way on: facing along the course toward the exit")
	for i: int in 300:
		if e.state == Expedition.State.CLIMBING:
			break
		showcase.advance(FRAME)
	assert_eq(e.state, Expedition.State.CLIMBING, "the way on: it walks out by the doorway")
	showcase.free()

	# To a guardian's room: one tile of course outside it, walking in.
	showcase = _showcase_at(&"guardian_fight")
	sim = showcase.main.simulation
	e = sim.expedition
	line = sim.labyrinth.level(e.depth).course
	assert_eq(e.depth, ShowcaseMoments.GUARDIAN_DEPTH, "the guardian: cut to its stage")
	var lair: int = ChamberRules.way_on_room(line)
	assert_true(
		ChamberRules.is_guardians(sim.labyrinth, Content.area(e.place), e.depth, lair),
		"the guardian: the last room is a guardian's"
	)
	var lair_stretch: Vector2 = line.stretch_of(lair)
	_assert_on_course(sim, "the guardian")
	assert_eq(line.chamber_at(e.x), -1, "the guardian: outside the room")
	assert_between(
		e.x,
		lair_stretch.x - 1.5,
		lair_stretch.x,
		"the guardian: beside it, where the course enters"
	)
	assert_eq(e.facing, 1, "the guardian: facing into it along the course")
	assert_eq(
		PartyPlaces.world_facing(e),
		line.heading_at(lair_stretch.x),
		"the guardian: entering from the side the course comes from"
	)
	for i: int in 150:
		if GuardianSpacing.fighting_guardian(sim) != null:
			break
		showcase.advance(FRAME)
	assert_not_null(GuardianSpacing.fighting_guardian(sim), "the guardian: the fight begins")
	showcase.free()

	# To a quest: a few tiles of course before its room, in no other room, walking in.
	showcase = _showcase_at(&"quest_chest")
	sim = showcase.main.simulation
	e = sim.expedition
	var level: LabyrinthLevel = sim.labyrinth.level(e.depth)
	line = level.course
	var quest: StringName = ShowcaseMoments.QUEST_OF[&"quest_chest"]
	_assert_on_course(sim, "the quest")
	assert_eq(line.chamber_at(e.x), -1, "the quest: in no room")
	assert_eq(e.facing, 1, "the quest: facing along the course")
	var meant: LabyrinthChamber = null
	for room: LabyrinthChamber in level.chambers:
		var stretch: Vector2 = line.stretch_of(room.index)
		var before: bool = (
			e.x < stretch.x and e.x >= stretch.x - ShowcaseMoments.QUEST_APPROACH - 1.0
		)
		if before and e.quest_in(e.depth, room.index) == quest:
			meant = room
	assert_not_null(meant, "the quest: a few tiles of course before a room that holds it")
	if meant == null:
		return
	assert_eq(
		PartyPlaces.world_facing(e) if not line.on_ladder(e.x) else 0,
		line.heading_at(e.x),
		"the quest: walking the way the course goes"
	)
	for i: int in 150:
		if e.working_quest() != &"":
			break
		showcase.advance(FRAME)
	assert_eq(e.working_quest(), quest, "the quest: the party walks in and sets to it")
	assert_eq(line.chamber_at(e.x), meant.index, "the quest: in the room meant")


# --- R5 ------------------------------------------------------------------------


func test_r5_the_preview_is_gone() -> void:
	assert_false(ResourceLoader.exists("res://game/dev/winding.tscn"), "the scene does not exist")
	assert_false(FileAccess.file_exists("res://game/dev/winding.tscn"), "nor its file")
	assert_false(FileAccess.file_exists("res://game/dev/winding_preview.gd"), "nor its script")
	var scripts: Dictionary[String, String] = {}
	scripts_in("res://game", scripts)
	for path: String in scripts:
		assert_false(scripts[path].contains("WindingPreview"), "%s does not name it" % path)

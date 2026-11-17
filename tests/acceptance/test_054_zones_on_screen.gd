extends GutTest
## Acceptance tests for specs/054-zones-on-screen/spec.md, one per requirement. R9 is also in
## test_018_seeing_the_loop.gd (test_r2_showcase_plays_every_moment), which plays every moment.
##
## As in spec 048's tests, a World plays frames by hand as the game would at 60 frames a second:
## the simulation steps once every FRAMES_PER_TICK frames (times the game's speed), and the world
## moves on by FRAME.

const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const FRAMES_PER_TICK: int = 6
const TILE: float = 16.0
const HERO_IDS: Array[int] = [1, 2, 3, 4]
const KNIGHT: int = 1
## The longest any wait here lasts, in simulation ticks (five minutes).
const LIMIT_TICKS: int = 3000
## A stage's band of world pixels, top to bottom.
const BAND_PIXELS: float = Labyrinth.LEVEL_HEIGHT * TILE
## The words nothing on screen may say (R6), as whole words or their start.
const DOWN_WORDS: String = "\\b(deeper|descend\\w*|climb\\w*|depths?|shafts?)\\b"
## Where the HUD's, the effects' and the world's texts are written.
const TEXT_DIRS: Array[String] = ["res://game/hud/", "res://game/effects/", "res://game/world/"]
## Texts the HUD shows from data/, outside spec 054's Paths: reported to the lead, not changed here.
## (The Quick March upgrade's description, data/upgrades/quick_march.tres.)
const OUTSIDE_PATHS: Array[String] = ["+4% travel and climb speed"]

var _sim: Simulation
var _world: World
var _events: Array[SimEvent] = []
var _frame: int = 0


func before_each() -> void:
	_events = []
	_frame = 0


# --- Helpers -------------------------------------------------------------------


func _show(simulation: Simulation, speed: int = 1) -> void:
	_sim = simulation
	_events = []
	_frame = 0
	_world = World.new()
	_world.simulation = simulation
	_world.speed = speed
	add_child_autofree(_world)
	_world.set_process(false)
	_world.sim_event.connect(func(event: SimEvent) -> void: _events.append(event))


## One frame: the simulation steps (speed times) every FRAMES_PER_TICK frames, then the world
## moves on by FRAME. Returns the events passed on in it.
func _play_frame() -> Array[SimEvent]:
	var before: int = _events.size()
	if _frame % FRAMES_PER_TICK == 0:
		for i: int in maxi(_world.speed, 1):
			_sim.step()
	_frame += 1
	_world.sync(FRAME)
	return _events.slice(before)


func _has(events: Array[SimEvent], kind: SimEvent.Kind) -> bool:
	for event: SimEvent in events:
		if event.kind == kind:
			return true
	return false


func _count(events: Array[SimEvent], kind: SimEvent.Kind) -> int:
	var found: int = 0
	for event: SimEvent in events:
		if event.kind == kind:
			found += 1
	return found


## The middle of the doorway where the shaft from [param stage] leaves, in world pixels.
func _door_x(simulation: Simulation, stage: int) -> float:
	return (simulation.labyrinth.shaft_column(stage) + Labyrinth.SHAFT_WIDTH / 2.0) * TILE


## True when [param rects] holds a doorway centred on [param x] standing on [param floor_px].
func _has_door(rects: Array[Rect2], x: float, floor_px: float) -> bool:
	for rect: Rect2 in rects:
		if is_equal_approx(rect.get_center().x, x) and is_equal_approx(rect.end.y, floor_px):
			return true
	return false


func _floor_px(simulation: Simulation, stage: int) -> float:
	return (simulation.labyrinth.level(stage).floor_y + 1) * TILE


## Stands the party on [param stage] of a new game as revival would, with no auto-push.
func _stand_on(simulation: Simulation, stage: int) -> void:
	Arrival.from_save(simulation.expedition, simulation.tick, stage, stage, stage, false)
	simulation.set_auto_push(false)


## Puts the party three tiles short of the way on from [param stage], walking to it, its target
## the next stage.
func _near_the_way_on(simulation: Simulation, stage: int) -> void:
	if stage > 1:
		_stand_on(simulation, stage)
	simulation.set_auto_push(false)
	var e: Expedition = simulation.expedition
	var door: float = simulation.labyrinth.shaft_column(stage) + Labyrinth.SHAFT_WIDTH / 2.0
	var side: float = -1.0 if door > Labyrinth.LEVEL_WIDTH / 2.0 else 1.0
	e.x = door + 3.0 * side
	e.facing = -int(side)
	simulation.set_target_depth(stage + 1)


func _all_gone() -> bool:
	for id: int in HERO_IDS:
		if _world.character(id).modulate.a > 0.0:
			return false
	return true


func _band_top(stage: int) -> float:
	return (stage - 1) * BAND_PIXELS


## The world pixels the camera rests on for [param target]: kept inside the band's columns.
func _rest(target: Vector2) -> Vector2:
	var half: float = _world.get_viewport_rect().size.x * 0.5 / _world.camera.zoom.x
	return Vector2(clampf(target.x, ceilf(half), floorf(WorldCamera.BAND_WIDTH - half)), target.y)


# --- R1 ------------------------------------------------------------------------


func test_r1_out_through_a_doorway() -> void:
	var sim := Simulation.new(SEED)
	_near_the_way_on(sim, 1)
	_show(sim)
	var view: LabyrinthView = _world.labyrinth_view
	var door: float = _door_x(sim, 1)
	assert_true(
		_has_door(view.doorways(1), door, _floor_px(sim, 1)),
		"stage 1 shows a doorway where its shaft was, standing on the floor"
	)
	var shaft: Rect2i = sim.labyrinth.level(1).shaft_down
	var bare: int = 0
	for y: int in range(shaft.position.y - 1, shaft.position.y + 2):
		for x: int in range(shaft.position.x, shaft.end.x):
			var tile := Vector2i(x, y)
			for visual: String in view.visuals_at(tile):
				assert_false(visual.begins_with("ladder/"), "no ladder at %s" % tile)
			if y >= shaft.position.y and not view.is_open(tile):
				bare += 1
	assert_eq(bare, 2 * shaft.size.x, "the floor runs on where the shaft was")
	assert_eq(view.doorways(1).size(), 1, "stage 1 has only its way on")

	var vertical_moves: int = 0
	var switches: int = 0
	var gone: bool = false
	var arrived: bool = false
	var last_shown: int = _world.shown_stage()
	var last_camera: float = _world.camera.position.y
	for i: int in LIMIT_TICKS * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		var shown: int = _world.shown_stage()
		var top: float = _band_top(shown)
		for id: int in HERO_IDS:
			var y: float = _world.character(id).position.y
			assert_between(y, top, top + BAND_PIXELS, "hero %d stays in the zone's band" % id)
		var camera: float = _world.camera.position.y
		assert_between(camera, top, top + BAND_PIXELS, "the camera stays in the zone's band")
		if shown != last_shown:
			switches += 1
			assert_eq(_world.crossing.darkness(), 1.0, "the zone changes in the dark")
		elif not is_equal_approx(camera, last_camera):
			vertical_moves += 1
		if shown == 1 and _sim.expedition.state == Expedition.State.CLIMBING and _all_gone():
			gone = true
		last_shown = shown
		last_camera = camera
		if _has(events, SimEvent.Kind.DEPTH_CHANGED):
			arrived = true
			break
	assert_true(arrived, "the party reached stage 2")
	assert_true(gone, "it walked into the doorway and was gone")
	assert_eq(switches, 1, "the world changed zone once")
	assert_eq(vertical_moves, 0, "the camera never travelled up or down")
	assert_eq(_world.shown_stage(), 2, "it shows stage 2")
	assert_true(
		_has_door(view.doorways(2), door, _floor_px(sim, 2)),
		"stage 2 has a doorway back where the party came out"
	)
	for id: int in HERO_IDS:
		assert_eq(_world.character(id).modulate.a, 1.0, "hero %d is out of the doorway" % id)


# --- R2 ------------------------------------------------------------------------


func test_r2_a_short_crossing() -> void:
	var climb_frames: Dictionary[int, int] = {}
	for speed: int in [1, 4]:
		var sim := Simulation.new(SEED)
		_near_the_way_on(sim, 1)
		_show(sim, speed)
		var veil := CrossingVeil.new()
		add_child_autofree(veil)
		veil.set_process(false)
		veil.setup(_world)
		var titles: Dictionary[String, bool] = {}
		var title_frames: int = 0
		var darkest: float = 0.0
		var climbing: int = 0
		var ended: bool = false
		for i: int in LIMIT_TICKS * FRAMES_PER_TICK:
			var events: Array[SimEvent] = _play_frame()
			veil.refresh()
			var crossing: ZoneCrossing = _world.crossing
			assert_eq(veil.darkness(), crossing.darkness(), "the veil is as dark as the crossing")
			assert_eq(veil.title_label.text, crossing.title(), "and shows its title")
			if _has(events, SimEvent.Kind.DEPTH_CHANGED):
				assert_eq(crossing.darkness(), 0.0, "%dx: open when the stage has changed" % speed)
				assert_eq(crossing.title(), "", "%dx: the title is gone with it" % speed)
				ended = true
				break
			if sim.expedition.state == Expedition.State.CLIMBING:
				climbing += 1
				darkest = maxf(darkest, crossing.darkness())
			else:
				assert_eq(crossing.darkness(), 0.0, "%dx: no dimming before it leaves" % speed)
			if crossing.title() != "":
				titles[crossing.title()] = true
				title_frames += 1
		assert_true(ended, "%dx: the party changed stage" % speed)
		assert_eq(darkest, 1.0, "%dx: the screen goes dark" % speed)
		assert_eq(titles.keys(), ["Mossy Hollow 2"], "%dx: the title names the arrival" % speed)
		assert_gte(title_frames, 20, "%dx: long enough to read" % speed)
		climb_frames[speed] = climbing
	assert_lt(climb_frames[4] * 3, climb_frames[1], "at 4x the crossing is shorter")


# --- R3 ------------------------------------------------------------------------


func test_r3_going_back() -> void:
	# A lower target: from stage 2 back to 1, out by the doorway it came in by.
	var sim := Simulation.new(SEED)
	_stand_on(sim, 2)
	_show(sim)
	var back_door: float = _door_x(sim, 1)
	assert_true(
		_has_door(_world.labyrinth_view.doorways(2), back_door, _floor_px(sim, 2)),
		"stage 2 shows the doorway back"
	)
	sim.set_target_depth(1)
	var left_by: float = -1.0
	var titles: Dictionary[String, bool] = {}
	var darkest: float = 0.0
	for i: int in LIMIT_TICKS * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		if sim.expedition.state == Expedition.State.CLIMBING and left_by < 0.0:
			left_by = sim.expedition.x * TILE
		darkest = maxf(darkest, _world.crossing.darkness())
		if _world.crossing.title() != "":
			titles[_world.crossing.title()] = true
		if _has(events, SimEvent.Kind.DEPTH_CHANGED):
			break
	assert_eq(left_by, back_door, "it left by the doorway it came in by")
	assert_eq(darkest, 1.0, "with the same dimming")
	assert_eq(titles.keys(), ["Mossy Hollow 1"], "and the title of where it arrives")
	assert_eq(_world.shown_stage(), 1, "it shows stage 1")
	assert_eq(sim.expedition.x * TILE, back_door, "out of stage 1's way on")

	# A revival: wiped on stage 3 with stage 2 safe, it stands up at stage 2's doorway back.
	var down := Simulation.new(SEED)
	_stand_on(down, 3)
	down.expedition.last_stable_depth = 2
	_show(down)
	for hero: Hero in down.party.heroes:
		hero.health = 0
	titles.clear()
	darkest = 0.0
	var revived: bool = false
	for i: int in LIMIT_TICKS * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		darkest = maxf(darkest, _world.crossing.darkness())
		if _world.crossing.title() != "":
			titles[_world.crossing.title()] = true
		if _has(events, SimEvent.Kind.PARTY_REVIVED):
			revived = true
			break
	assert_true(revived, "the party was revived")
	assert_eq(darkest, 1.0, "the revival elsewhere dims the same way")
	assert_eq(titles.keys(), ["Mossy Hollow 2"], "and names where it stands up")
	assert_eq(_world.shown_stage(), 2, "it shows stage 2")
	assert_eq(down.expedition.x * TILE, _door_x(down, 1), "at the doorway it came in by")
	assert_true(
		_has_door(_world.labyrinth_view.doorways(2), _door_x(down, 1), _floor_px(down, 2)),
		"a doorway is there"
	)


# --- R4 ------------------------------------------------------------------------


func test_r4_a_journey() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_push(false)
	_show(sim)
	sim.expedition.travel.open[&"claypits"] = true
	sim.set_destination(&"claypits", 1)
	var left_at: int = -1
	var seen: Array[String] = []
	var said: Dictionary[String, Vector2] = {}  # each title's first and last second
	var dark_from: float = -1.0
	var light_after: float = -1.0
	var arrived_at: int = -1
	for i: int in LIMIT_TICKS * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		var crossing: ZoneCrossing = _world.crossing
		if left_at < 0 and sim.expedition.state == Expedition.State.JOURNEYING:
			left_at = sim.tick
		if left_at < 0:
			continue
		var since: float = float(sim.tick - left_at) / Simulation.TICKS_PER_SECOND
		if arrived_at < 0:
			var title: String = crossing.title()
			if title != "":
				if seen.is_empty() or seen[-1] != title:
					seen.append(title)
				var span: Vector2 = said.get(title, Vector2(since, since))
				said[title] = Vector2(span.x, since)
			if dark_from < 0.0 and crossing.darkness() >= 1.0:
				dark_from = since
			if dark_from >= 0.0 and crossing.darkness() < 1.0 and light_after < 0.0:
				light_after = since
		if _has(events, SimEvent.Kind.AREA_CHANGED):
			arrived_at = sim.tick
		if arrived_at >= 0 and crossing.darkness() <= 0.0:
			break
	assert_gt(arrived_at, 0, "the party arrived")
	assert_eq(seen, ["Leaving Mossy Hollow", "The Claypits 1"], "the two titles, in order")
	assert_lte(said["Leaving Mossy Hollow"].x, 1.0, "leaving is named from the start")
	assert_gte(said["Leaving Mossy Hollow"].y, 4.0, "for the first half")
	assert_lte(said["The Claypits 1"].x, 5.5, "the arrival from the second half")
	assert_gte(said["The Claypits 1"].y, 9.5, "to the end of the ten seconds")
	assert_lte(dark_from, ZoneCrossing.FADE_SECONDS + 0.1, "it dims as the party leaves")
	assert_lt(light_after, 0.0, "and stays dark the whole way")
	var opened: float = float(sim.tick - arrived_at) / Simulation.TICKS_PER_SECOND
	assert_lte(opened, ZoneCrossing.OPEN_SECONDS + 0.2, "it opens on the new area at once")
	assert_eq(_world.labyrinth_view.area, &"claypits", "on the Claypits")


# --- R5 ------------------------------------------------------------------------


func test_r5_its_own_place() -> void:
	var ids: Array[StringName] = Content.area_ids()
	assert_eq(ids.size(), 4, "four areas")
	var palette: PackedColorArray = Palette.all()
	var faces: Dictionary[String, bool] = {}
	var rocks: Dictionary[StringName, bool] = {}
	var lights: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		var look: ZoneLook = ZoneLook.of(id, 1)
		for hue: StringName in [look.rock_hue(), look.floor_hue(), look.light_hue()]:
			assert_true(palette.has(Palette.color(hue)), "%s: %s is a palette colour" % [id, hue])
		rocks[look.rock_hue()] = true
		lights[look.light_hue()] = true
		faces["%s %s %s" % [look.rock_hue(), look.floor_hue(), look.light_hue()]] = true
	assert_eq(rocks.size(), 4, "every area's rock differs")
	assert_eq(lights.size(), 4, "every area's light differs")
	assert_eq(faces.size(), 4, "every area's colouring differs")
	for id: StringName in ids:
		var first: Color = ZoneLook.of(id, 1).ambient()
		var sixth: Color = ZoneLook.of(id, 6).ambient()
		var within: float = _distance(first, sixth)
		assert_gt(within, 0.0, "%s: stage 6 is a little different" % id)
		assert_lt(sixth.get_luminance(), first.get_luminance(), "%s: and darker" % id)
		for other: StringName in ids:
			if other == id:
				continue
			var between: float = _distance(first, ZoneLook.of(other, 1).ambient())
			assert_lt(within, between, "%s 1 and 6 are nearer than %s and %s" % [id, id, other])
	# Drawn so: each area's stage shows its own earth, and its darkness takes its look.
	var stratums: Dictionary[String, bool] = {}
	for id: StringName in ids:
		var view := LabyrinthView.new()
		view.labyrinth = Labyrinth.new(SEED, AreaTravel.label(id))
		view.zoned = true
		view.area = id
		add_child_autofree(view)
		view.set_focus(Vector2(60, view.labyrinth.level(1).floor_y))
		var earth: String = view.visuals_at(Vector2i(60, 1))[0]
		assert_string_starts_with(earth, String(ZoneLook.of(id, 1).stratum()) + "/", String(id))
		stratums[earth.get_slice("/", 0)] = true
		var lit: Color = AmbienceMood.light_at(
			Vector2(5, 5), [] as Array[AmbienceLight], 1.0, view.zone_look()
		)
		assert_eq(lit, view.zone_look().ambient(), "%s: the darkness takes the look" % id)
	assert_eq(stratums.size(), 4, "four different earths")


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# --- R6 ------------------------------------------------------------------------


func test_r6_nothing_says_down() -> void:
	var down := RegEx.create_from_string("(?i)" + DOWN_WORDS)
	var literal := RegEx.create_from_string('"([^"\\\\]|\\\\.)*"')
	var found: PackedStringArray = []
	var files: int = 0
	for dir: String in TEXT_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			files += 1
			var lines: PackedStringArray = FileAccess.get_file_as_string(dir + file).split("\n")
			for n: int in lines.size():
				var line: String = lines[n].strip_edges()
				if line.begins_with("#") or "name = " in line or "push_error" in line:
					continue
				for match: RegExMatch in literal.search_all(line):
					var text: String = match.get_string()
					if match.get_start() > 0 and line[match.get_start() - 1] in ["&", "^"]:
						continue  # a StringName or a NodePath, never shown
					if " " not in text and text.substr(1, 1) == text.substr(1, 1).to_lower():
						continue  # an id or a key, not words
					if down.search(text) != null:
						found.append("%s:%d %s" % [file, n + 1, text])
	assert_gt(files, 30, "the HUD's, effects' and world's scripts were read")
	assert_eq(found, PackedStringArray(), "texts the player can see that say down")

	# What the HUD shows as the party goes on, comes back and is wiped.
	var main: Main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main.driver.set_process(false)
	main.world.set_process(false)
	_sim = main.simulation
	_world = main.world
	_world.sim_event.connect(func(event: SimEvent) -> void: _events.append(event))
	_near_the_way_on(_sim, 1)
	var shown: Dictionary[String, bool] = {}
	var steps: Array[Callable] = [
		func() -> void: _sim.set_target_depth(2),
		func() -> void: _sim.set_target_depth(1),
		func() -> void:
			for hero: Hero in _sim.party.heroes:
				hero.health = 0,
	]
	for step: Callable in steps:
		step.call()
		for i: int in 120 * FRAMES_PER_TICK:
			_play_frame()
			main.hud.advance(FRAME)
			if i % 10 == 0:
				for label: Node in main.hud.find_children("*", "Label", true, false):
					shown[(label as Label).text] = true
	for text: String in shown:
		if text in OUTSIDE_PATHS:
			continue
		assert_null(down.search(text), "the HUD showed: " + text)
	assert_gt(shown.size(), 20, "many texts were seen")


# --- R7 ------------------------------------------------------------------------


func test_r7_true_in_a_crowded_frame() -> void:
	var sim := Simulation.new(SEED)
	_near_the_way_on(sim, 1)
	_show(sim)
	_play_frame()
	var asked_back: bool = false
	for i: int in 300:
		sim.step()
		var run: Expedition = sim.expedition
		if not asked_back and run.depth == 2 and run.state == Expedition.State.TRAVELLING:
			sim.set_target_depth(1)
			asked_back = true
	var events: Array[SimEvent] = _play_frame_without_stepping()
	assert_eq(_count(events, SimEvent.Kind.DEPTH_CHANGED), 2, "two changes of stage in the frame")
	var e: Expedition = sim.expedition
	assert_ne(e.state, Expedition.State.CLIMBING, "the party is between none")
	assert_eq(_world.shown_stage(), e.depth, "the world shows the stage the party is on")
	assert_eq(_world.crossing.darkness(), 0.0, "no crossing left half played")
	assert_eq(_world.crossing.title(), "", "and no title")
	var top: float = _band_top(e.depth)
	for id: int in HERO_IDS:
		var hero: CharacterSprite = _world.character(id)
		assert_eq(hero.modulate.a, 1.0, "hero %d shows" % id)
		assert_between(hero.position.y, top, top + BAND_PIXELS, "hero %d is on the stage" % id)
	var monsters: int = 0
	for node: Node in _world.get_node("Characters").get_children():
		var sprite: CharacterSprite = node as CharacterSprite
		assert_between(sprite.position.y, top, top + BAND_PIXELS, "no sprite from the zone before")
		monsters += 1
	assert_gt(monsters, 4, "the stage's monsters are there")
	assert_eq(_world.labyrinth_view.built_depths(), [e.depth] as Array[int], "only its stage")


## One world frame with no step first (the steps were taken before it).
func _play_frame_without_stepping() -> Array[SimEvent]:
	var before: int = _events.size()
	_world.sync(FRAME)
	return _events.slice(before)


# --- R8 ------------------------------------------------------------------------


func test_r8_the_wipe_still_reads() -> void:
	var sim := Simulation.new(SEED)
	_stand_on(sim, 2)
	sim.expedition.last_stable_depth = 1
	_show(sim)
	for i: int in 30:
		_play_frame()
	for hero: Hero in sim.party.heroes:
		hero.health = 0
	var order: Array[String] = []
	var fallen_at: Vector2 = Vector2.INF
	var revived: bool = false
	var last_dark: float = 1.0
	var opened_on_rising: bool = false
	for i: int in LIMIT_TICKS * FRAMES_PER_TICK:
		var events: Array[SimEvent] = _play_frame()
		if _has(events, SimEvent.Kind.PARTY_REVIVED):
			revived = true
		var dark: float = _world.crossing.darkness()
		var camera: Vector2 = _world.camera.position
		var step: String
		if not revived:
			if sim.expedition.state != Expedition.State.REVIVING:
				continue
			if fallen_at == Vector2.INF:
				fallen_at = camera
			assert_lte(
				camera.distance_to(fallen_at), TILE, "the camera holds on the fallen until then"
			)
			if dark <= 0.0:
				step = "hold"
			elif dark < 1.0:
				step = "dim"
			else:
				step = "title"
				assert_eq(_world.crossing.title(), "Mossy Hollow 1", "the title names the stage")
		else:
			if _world.fallen_party.is_telling():
				var there: Vector2 = _rest(_world.fallen_party.destination())
				assert_eq(camera, there, "then the camera is on the revival, cut not travelled")
			step = "open"
			assert_lte(dark, last_dark, "once revived, the screen only opens")
			if _world.fallen_party.is_standing(KNIGHT) and dark < 1.0:
				opened_on_rising = true
			if not _world.fallen_party.is_telling() and dark <= 0.0:
				break
		if order.is_empty() or order[-1] != step:
			order.append(step)
		last_dark = dark
	assert_true(revived, "the party was revived")
	assert_eq(order, ["hold", "dim", "title", "open"], "hold, dim, title, open")
	assert_true(opened_on_rising, "the screen opens on the heroes standing up")
	assert_eq(_world.shown_stage(), 1, "on the stage it revived on")


# --- R9 ------------------------------------------------------------------------


func test_r9_in_the_showcase() -> void:
	assert_has(Showcase.MOMENTS, &"four_areas", "a moment shows the four areas")
	for moment: StringName in Showcase.MOMENTS:
		var caption: String = Showcase.CAPTIONS[moment]
		assert_null(
			RegEx.create_from_string("(?i)" + DOWN_WORDS).search(caption), "caption: " + caption
		)
	var scene: PackedScene = load("res://game/dev/showcase.tscn")
	var showcase: Showcase = scene.instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	var areas: Dictionary[StringName, bool] = {}
	var dark_frames: int = 0
	for moment: StringName in [&"climb_down", &"four_areas"]:
		showcase.skip_to(moment)
		while showcase.moment() == moment and showcase.elapsed < 600.0:
			showcase.advance(FRAME)
			if moment == &"four_areas":
				areas[showcase.main.world.labyrinth_view.area] = true
			elif showcase.main.world.crossing.darkness() >= 1.0:
				dark_frames += 1
		var happened: bool = showcase.evidence.get(moment, false)
		assert_true(happened, "%s happened" % moment)
	assert_gt(dark_frames, 10, "the change of stage shows the crossing")
	assert_eq(areas.size(), 4, "the four areas were shown in turn")

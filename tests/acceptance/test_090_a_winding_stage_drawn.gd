extends "res://tests/support/play_fixture.gd"
## Spec 090: the zoned view, the ambience and the camera's limits draw a winding stage whole (its
## rooms on their floors, its ladders, a doorway where the party arrives and where it leaves,
## light and dark to its full height), and a preview scene plays a winding game.

const WINDING: Labyrinth.Shape = Labyrinth.Shape.WINDING
const SEEDS: int = 10
const STAGES: int = 4
const WIDTH: int = Labyrinth.LEVEL_WIDTH
const SURROUND: int = LabyrinthView.SURROUND_ROWS
## R6: rows of earth the camera may show above the band and below it.
const EARTH_ROWS: int = 4
const SCREEN_SIZE: Vector2 = Vector2(640, 360)
const PREVIEW: String = "res://game/dev/winding.tscn"
## R7: how long the preview is played.
const PREVIEW_SECONDS: float = 30.0
const N: int = LabyrinthTiles.N
const S: int = LabyrinthTiles.S


## Calls [param each] with (seed, stage, level, view) for every seed and stage under test, the
## view a zoned one with that stage built.
func _every_stage(each: Callable) -> void:
	for seed_value: int in range(1, SEEDS + 1):
		var labyrinth: Labyrinth = winding_labyrinth(seed_value)
		for stage: int in range(1, STAGES + 1):
			var view: LabyrinthView = zoned_view(labyrinth, stage)
			each.call("seed %d stage %d" % [seed_value, stage], labyrinth.level(stage), view)
			view.free()


## The open tiles of [param level]: those of its rooms, tunnels and ladders.
func _open_tiles(level: LabyrinthLevel) -> Dictionary[Vector2i, bool]:
	var open: Dictionary[Vector2i, bool] = {}
	var rects: Array[Rect2i] = []
	for room: LabyrinthChamber in level.chambers:
		rects.append(room.rect)
	rects.append_array(level.tunnels)
	rects.append_array(level.ladders)
	for rect: Rect2i in rects:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				open[Vector2i(x, y)] = true
	return open


## The sides (N, E, S, W bits) of the edge drawn at [param tile], or 0 for none.
func _edge_sides(view: LabyrinthView, tile: Vector2i) -> int:
	for visual: String in view.visuals_at(tile):
		var part: String = visual.get_slice("/", 1)
		if part.begins_with("edge_"):
			return int(part.get_slice("_", 1))
	return 0


## The sides the shade drawn at [param tile] falls from, or 0 for none.
func _shade_sides(view: LabyrinthView, tile: Vector2i) -> int:
	for visual: String in view.visuals_at(tile):
		var part: String = visual.get_slice("/", 1)
		if part.begins_with("shade_"):
			return int(part.get_slice("_", 1))
	return 0


## The ladder part drawn at [param tile] ("left", "top_right", ...), or "".
func _ladder_part(view: LabyrinthView, tile: Vector2i) -> String:
	for visual: String in view.visuals_at(tile):
		if visual.begins_with("ladder/"):
			return visual.get_slice("/", 1)
	return ""


func _floor_line(room: LabyrinthChamber) -> float:
	return (room.floor_row() + 1) * TILE


func _room_pixels(room: LabyrinthChamber) -> Rect2:
	return Rect2(Vector2(room.rect.position) * TILE, Vector2(room.rect.size) * TILE)


## The doorway sprites [param view] draws, in world pixels, in the order of their names.
func _drawn_doors(view: LabyrinthView) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node: Node in view.find_children("Doorway*", "Sprite2D", true, false):
		var sprite: Sprite2D = node as Sprite2D
		var at: Vector2 = view.to_local(sprite.global_position)
		rects.append(Rect2(at, sprite.texture.get_size()))
	return rects


## The ladders of [param level] that meet [param room]: through its floor or down to it.
func _ladders_of(level: LabyrinthLevel, room: LabyrinthChamber) -> Array[Rect2i]:
	var met: Array[Rect2i] = []
	for ladder: Rect2i in level.ladders:
		var in_columns: bool = (
			ladder.position.x >= room.rect.position.x and ladder.end.x <= room.rect.end.x
		)
		var leaves: bool = ladder.position.y - 1 == room.floor_row()
		var lands: bool = ladder.end.y - 1 == room.floor_row()
		if in_columns and (leaves or lands):
			met.append(ladder)
	return met


## An ambience over [param view], as the world makes it.
func _dress(view: LabyrinthView) -> Ambience:
	var ambience := Ambience.new()
	add_child_autofree(ambience)
	ambience.set_process(false)
	ambience.setup(view)
	return ambience


## Everything placed on [param dressed], as text, in order.
func _placed(dressed: AmbienceLevel) -> PackedStringArray:
	var all: PackedStringArray = []
	for torch: AmbienceProp in dressed.torches:
		all.append("torch %d %s" % [torch.chamber, torch.rect])
	for prop: AmbienceProp in dressed.props:
		all.append("%s %d %s %s" % [prop.name, prop.chamber, prop.rect, prop.flip])
	var tiles: Array[Vector2i] = dressed.details.keys()
	tiles.sort()
	for tile: Vector2i in tiles:
		all.append("%s %s" % [dressed.details[tile], tile])
	for light: AmbienceLight in dressed.lights:
		all.append("light %s %s" % [light.position, light.radius])
	return all


# --- R2 ------------------------------------------------------------------------


func test_r2_every_room_tunnel_and_ladder_is_open() -> void:
	_every_stage(
		func(what: String, level: LabyrinthLevel, view: LabyrinthView) -> void:
			var band: Rect2i = level.band
			assert_eq(band.size.y, view.labyrinth.band_height(), "%s: a band of 32 rows" % what)
			assert_eq(
				view.built_depths(), [level.depth] as Array[int], "%s: only it is built" % what
			)
			var open: Dictionary[Vector2i, bool] = _open_tiles(level)
			var wrong_open: int = 0
			var wrong_ground: int = 0
			for y: int in range(band.position.y - SURROUND, band.end.y + SURROUND):
				for x: int in range(-1, WIDTH + 1):
					var tile := Vector2i(x, y)
					if view.is_open(tile) != open.has(tile):
						wrong_open += 1
					if x < 0 or x >= WIDTH:
						continue
					var drawn: PackedStringArray = view.visuals_at(tile)
					var want: String = "/back_" if open.has(tile) else "/buried_"
					if drawn.is_empty() or not drawn[0].contains(want):
						wrong_ground += 1
			assert_eq(wrong_open, 0, "%s: is_open is true on exactly the level's open tiles" % what)
			assert_eq(wrong_ground, 0, "%s: back wall in the open, earth everywhere else" % what)
			var near: Dictionary[Vector2i, bool] = {}
			for rect: Rect2i in view.open_rects_near(level.depth):
				for y: int in range(rect.position.y, rect.end.y):
					for x: int in range(rect.position.x, rect.end.x):
						near[Vector2i(x, y)] = true
			assert_eq(near.size(), open.size(), "%s: open_rects_near covers the stage" % what)
			assert_true(near.has_all(open.keys()), "%s: open_rects_near covers the stage" % what)
			var floors: Dictionary[int, bool] = {}
			for room: LabyrinthChamber in level.chambers:
				floors[room.floor_row()] = true
				var bare_floor: int = 0
				var bare_ceiling: int = 0
				var unshaded: int = 0
				for x: int in range(room.rect.position.x, room.rect.end.x):
					var under := Vector2i(x, room.floor_row() + 1)
					if not open.has(under) and _edge_sides(view, under) & N == 0:
						bare_floor += 1
					var over := Vector2i(x, room.rect.position.y - 1)
					if not open.has(over) and _edge_sides(view, over) & S == 0:
						bare_ceiling += 1
					var top := Vector2i(x, room.rect.position.y)
					if not open.has(over) and _shade_sides(view, top) & N == 0:
						unshaded += 1
				var room_name: String = "%s room %d" % [what, room.index]
				assert_eq(bare_floor, 0, "%s: a floor edge under its whole floor" % room_name)
				assert_eq(bare_ceiling, 0, "%s: a ceiling edge over it" % room_name)
				assert_eq(unshaded, 0, "%s: shade under its ceiling" % room_name)
			assert_gt(floors.size(), 1, "%s: rooms on more than one floor" % what)
	)


# --- R3 ------------------------------------------------------------------------


func test_r3_a_ladder_stands_between_its_rooms() -> void:
	_every_stage(
		func(what: String, level: LabyrinthLevel, view: LabyrinthView) -> void:
			assert_gt(level.ladders.size(), 0, "%s: the stage has a ladder" % what)
			var want: Dictionary[Vector2i, String] = {}
			for ladder: Rect2i in level.ladders:
				for y: int in range(ladder.position.y - 1, ladder.end.y):
					for x: int in range(ladder.position.x, ladder.end.x):
						var side: String = "left" if x == ladder.position.x else "right"
						var top: bool = y < ladder.position.y
						want[Vector2i(x, y)] = ("top_" if top else "") + side
				var upper: bool = false
				var lower: bool = false
				for room: LabyrinthChamber in level.chambers:
					upper = upper or room.floor_row() == ladder.position.y - 1
					lower = lower or room.floor_row() == ladder.end.y - 1
				assert_true(upper and lower, "%s: %s joins two floors" % [what, ladder])
			var wrong: int = 0
			var band: Rect2i = level.band
			for y: int in range(band.position.y - SURROUND, band.end.y + SURROUND):
				for x: int in WIDTH:
					var tile := Vector2i(x, y)
					var part: String = want.get(tile, "")
					if _ladder_part(view, tile) != part:
						wrong += 1
			assert_eq(wrong, 0, "%s: ladder parts on every ladder tile and nowhere else" % what)
	)


# --- R4 ------------------------------------------------------------------------


func test_r4_doorways_stand_at_the_entry_and_the_exit() -> void:
	var size: Vector2 = Vector2(PixelSheet.load_sheet(LabyrinthView.DOORWAY).size)
	for seed_value: int in range(1, SEEDS + 1):
		var labyrinth: Labyrinth = winding_labyrinth(seed_value)
		for stage: int in [1, 3]:
			var what: String = "seed %d stage %d" % [seed_value, stage]
			var view: LabyrinthView = zoned_view(labyrinth, stage)
			var level: LabyrinthLevel = labyrinth.level(stage)
			var course: StageCourse = level.course
			var marks: Array[float] = [course.exit]
			if stage > 1:
				marks.append(course.entry)
			var doors: Array[Rect2] = view.doorways(stage)
			assert_eq(doors.size(), marks.size(), "%s: doorways" % what)
			assert_eq(_drawn_doors(view), doors, "%s: a sprite at each doorway" % what)
			for i: int in mini(doors.size(), marks.size()):
				var room: LabyrinthChamber = level.chambers[course.chamber_at(marks[i])]
				var feet: Vector2 = course.point_at(marks[i])
				var door: Rect2 = doors[i]
				assert_eq(door.size, size, "%s: doorway %d is the sprite's size" % [what, i])
				assert_eq(door.end.y, _floor_line(room), "%s: doorway %d on its floor" % [what, i])
				assert_eq(feet.y, float(room.floor_row()), "%s: mark %d is on a floor" % [what, i])
				assert_almost_eq(
					door.get_center().x, feet.x * TILE, 0.001, "%s: doorway %d centred" % [what, i]
				)
				assert_true(
					_room_pixels(room).encloses(door), "%s: doorway %d in its room" % [what, i]
				)
			view.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_every_room_is_dressed_on_its_own_floor() -> void:
	var lower_rooms_dressed: int = 0
	var chests: int = 0
	var beetles: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		for stage: int in range(1, STAGES + 1):
			var what: String = "seed %d stage %d" % [seed_value, stage]
			var labyrinth: Labyrinth = winding_labyrinth(seed_value)
			var view: LabyrinthView = zoned_view(labyrinth, stage)
			var ambience: Ambience = _dress(view)
			var level: LabyrinthLevel = labyrinth.level(stage)
			var dressed: AmbienceLevel = ambience.level(stage)
			assert_not_null(dressed, "%s is dressed" % what)
			if dressed == null:
				continue
			var doors: Array[Rect2] = view.doorways(stage)
			var open: Dictionary[Vector2i, bool] = _open_tiles(level)
			var torches: Dictionary[int, int] = {}
			var placed: Array[AmbienceProp] = dressed.torches.duplicate()
			placed.append_array(dressed.props)
			for prop: AmbienceProp in placed:
				var room: LabyrinthChamber = level.chambers[prop.chamber]
				var where: String = "%s: %s in room %d" % [what, prop.name, prop.chamber]
				var pixels: Rect2 = _room_pixels(room)
				assert_true(
					prop.rect.position.x >= pixels.position.x and prop.rect.end.x <= pixels.end.x,
					"%s is between its room's walls" % where
				)
				match prop.anchor:
					AmbienceProp.Anchor.FLOOR:
						var sunk: float = 2.0 if prop.name == &"puddle" else 0.0
						assert_eq(
							prop.rect.end.y - sunk, _floor_line(room), "%s: on its floor" % where
						)
						if room.floor_row() != level.floor_y:
							lower_rooms_dressed += 1
						if prop.name == &"chest":
							chests += 1
					AmbienceProp.Anchor.CEILING:
						assert_eq(
							prop.rect.position.y,
							room.rect.position.y * TILE - 2.0,
							"%s: on its ceiling" % where
						)
					AmbienceProp.Anchor.WALL:
						var so_far: int = torches.get(prop.chamber, 0)
						torches[prop.chamber] = so_far + 1
						assert_true(pixels.encloses(prop.rect), "%s: inside its room" % where)
						assert_true(
							pixels.has_point(prop.light.position), "%s: its light too" % where
						)
				for ladder: Rect2i in _ladders_of(level, room):
					var clear: bool = (
						prop.rect.end.x <= ladder.position.x * TILE
						or prop.rect.position.x >= ladder.end.x * TILE
					)
					assert_true(clear, "%s: clear of the ladder at %s" % [where, ladder])
				for door: Rect2 in doors:
					assert_false(door.intersects(prop.rect), "%s: clear of a doorway" % where)
			for room: LabyrinthChamber in level.chambers:
				var lit_by: int = torches.get(room.index, 0)
				assert_gt(lit_by, 0, "%s: room %d has a torch" % [what, room.index])
			var low_details: int = 0
			for tile: Vector2i in dressed.details:
				var buried: bool = level.band.has_point(tile)
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						buried = buried and not open.has(tile + Vector2i(dx, dy))
				assert_true(
					buried, "%s: the %s at %s is buried" % [what, dressed.details[tile], tile]
				)
				if tile.y >= level.band.position.y + Labyrinth.LEVEL_HEIGHT:
					low_details += 1
			assert_gt(low_details, 0, "%s: things are buried in the lower half of the band" % what)

			var again_view: LabyrinthView = zoned_view(winding_labyrinth(seed_value), stage)
			var again: AmbienceLevel = _dress(again_view).level(stage)
			assert_eq(
				_placed(again), _placed(dressed), "%s: two builds place the same things" % what
			)
			again_view.free()

			# Half a minute of motion: what walks a floor or falls to one keeps to its own room's.
			for i: int in 300:
				ambience.advance(0.1)
				for mote: AmbienceMote in dressed.motes:
					if mote.kind != &"beetle" and mote.kind != &"drip":
						continue
					var floor_y: float = mote.position.y + 1.0
					if mote.kind == &"drip":
						floor_y = mote.origin.y
					var home: bool = false
					for room: LabyrinthChamber in level.chambers:
						var pixels: Rect2 = _room_pixels(room)
						var in_columns: bool = (
							mote.position.x >= pixels.position.x and mote.position.x <= pixels.end.x
						)
						var under_ceiling: bool = mote.position.y >= pixels.position.y - 1.0
						if in_columns and under_ceiling and floor_y == _floor_line(room):
							home = true
					assert_true(
						home, "%s: a %s at %s is in a room" % [what, mote.kind, mote.position]
					)
					if mote.kind == &"beetle":
						beetles += 1
			view.free()
	assert_gt(lower_rooms_dressed, 0, "props stand on floors other than the first room's")
	assert_gt(chests, 0, "a hoard was placed")
	assert_gt(beetles, 0, "a beetle walked")


func test_r5_the_lowest_room_is_lit_as_the_highest() -> void:
	for seed_value: int in range(1, SEEDS + 1):
		for stage: int in range(1, STAGES + 1):
			var what: String = "seed %d stage %d" % [seed_value, stage]
			var labyrinth: Labyrinth = winding_labyrinth(seed_value)
			var view: LabyrinthView = zoned_view(labyrinth, stage)
			var ambience: Ambience = _dress(view)
			var level: LabyrinthLevel = labyrinth.level(stage)
			var dressed: AmbienceLevel = ambience.level(stage)
			var band: Rect2i = level.band
			assert_eq(dressed.exposure.get_size(), band.size, "%s: the map covers the band" % what)
			var open: Dictionary[Vector2i, bool] = _open_tiles(level)
			var wrong: int = 0
			var buried_seen: int = 0
			for y: int in range(band.position.y, band.end.y):
				for x: int in WIDTH:
					var tile := Vector2i(x, y)
					var buried: bool = true
					for dy: int in [-1, 0, 1]:
						for dx: int in [-1, 0, 1]:
							buried = buried and not open.has(tile + Vector2i(dx, dy))
					var want: float = AmbienceMood.EDGE_EXPOSURE
					if open.has(tile):
						want = 1.0
					elif buried:
						want = AmbienceMood.EARTH_EXPOSURE
						buried_seen += 1
					if absf(dressed.exposure_at(tile) - want) > 0.01:  # the map keeps 8 bits a tile
						wrong += 1
			assert_eq(wrong, 0, "%s: open in every room, buried in the earth between" % what)
			assert_gt(buried_seen, 0, "%s: there is earth between the floors" % what)

			# A torch on the highest floor and one on the lowest light their rooms alike, and the
			# earth between stays dark.
			var highest: AmbienceProp = dressed.torches[0]
			var lowest: AmbienceProp = dressed.torches[0]
			for torch: AmbienceProp in dressed.torches:
				if torch.rect.position.y < highest.rect.position.y:
					highest = torch
				if torch.rect.position.y > lowest.rect.position.y:
					lowest = torch
			assert_gt(
				lowest.rect.position.y - highest.rect.position.y,
				float(Labyrinth.LEVEL_HEIGHT),
				"%s: torches on floors far apart" % what
			)
			var high_light: float = ambience.brightness_at(highest.light.position)
			var low_light: float = ambience.brightness_at(lowest.light.position)
			var dark: float = AmbienceMood.brightness(view.zone_look().ambient())
			assert_almost_eq(low_light, high_light, 0.001, "%s: lit alike" % what)
			assert_gt(low_light, dark + 0.2, "%s: the lowest room's torch lights it" % what)
			view.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_the_camera_stays_in_the_stage() -> void:
	_show(winding_simulation(3))
	var band: Rect2i = _sim.labyrinth.level(1).band
	var limits := Vector2(band.position.y - EARTH_ROWS, band.end.y + EARTH_ROWS) * TILE
	assert_eq(_world.camera.rows, limits, "the world gives the camera the stage's rows")
	Arrival.from_save(_sim.expedition, _sim.tick, 3, 3, 3, false)
	_world.sync(STEP)
	assert_eq(_world.shown_stage(), 3, "the world shows stage 3")
	band = _sim.labyrinth.level(3).band
	limits = Vector2(band.position.y - EARTH_ROWS, band.end.y + EARTH_ROWS) * TILE
	assert_eq(_world.camera.rows, limits, "and gives the camera that stage's rows")

	# Outside the tree a camera's view is the game's 640x360.
	var camera: WorldCamera = autofree(WorldCamera.new())
	camera.rows = limits
	var middle := Vector2(WorldCamera.BAND_WIDTH / 2.0, (limits.x + limits.y) / 2.0)
	var far: float = 4000.0
	for level: int in [1, 2]:
		camera.set_zoom_level(level)
		camera._process(WorldCamera.ZOOM_TIME * 2.0)
		assert_eq(camera.zoom.x, float(level), "zoom %d" % level)
		for way: Vector2 in [
			Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, -1), Vector2(1, 1)
		]:
			for moved: StringName in [&"snap", &"follow", &"travel"]:
				camera.snap_to(middle)
				match moved:
					&"snap":
						camera.snap_to(middle + way * far)
					&"follow":
						camera.target = middle + way * far
						for i: int in 240:
							camera._process(STEP)
					&"travel":
						camera.travel(middle + way * far, 0.5)
						for i: int in 60:
							camera._process(STEP)
				var half: Vector2 = SCREEN_SIZE / (2.0 * level)
				var shown := Rect2(camera.position - half, half * 2.0)
				var what: String = "zoom %d, %s toward %s: %s" % [level, moved, way, shown]
				assert_gte(shown.position.x, 0.0, "%s: not past the left" % what)
				assert_lte(shown.end.x, WorldCamera.BAND_WIDTH, "%s: not past the right" % what)
				assert_gte(shown.position.y, limits.x, "%s: 4 rows of earth above at most" % what)
				assert_lte(shown.end.y, limits.y, "%s: 4 rows of earth below at most" % what)
				if way.y != 0.0:
					var edge: float = shown.position.y if way.y < 0.0 else shown.end.y
					assert_eq(edge, limits.x if way.y < 0.0 else limits.y, "%s: up to it" % what)

	# One floor down: the camera eases after its target and comes to rest on it.
	camera.set_zoom_level(1)
	camera._process(WorldCamera.ZOOM_TIME * 2.0)
	var top_floor: float = (band.position.y + WindingStage.FLOOR_GAP) * TILE
	var from := Vector2(middle.x, limits.x + SCREEN_SIZE.y / 2.0 + 8.0)
	var to: Vector2 = from + Vector2(0, WindingStage.FLOOR_GAP * TILE)
	assert_gt(to.y, top_floor, "the target moves a floor down")
	camera.snap_to(from)
	assert_eq(camera.position, from, "a target inside the limits is shown as it is")
	camera.target = to
	camera._process(STEP)
	assert_gt(camera.position.y, from.y, "the camera starts down after its target")
	assert_lt(camera.position.y, to.y, "eased, not at once")
	for i: int in 240:
		camera._process(STEP)
	assert_eq(camera.position, to, "and comes to rest on it")

	# A flat stage sets no limit: the camera goes up and down as it always did.
	_show(Simulation.new(3))
	assert_eq(_world.camera.rows, Vector2.ZERO, "a flat stage has no limit")
	var free_camera: WorldCamera = autofree(WorldCamera.new())
	free_camera.snap_to(middle + Vector2.DOWN * far)
	assert_eq(free_camera.position, middle + Vector2.DOWN * far, "no limit, no clamp")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_preview_plays_a_winding_game() -> void:
	var scene: PackedScene = load(PREVIEW) as PackedScene
	assert_not_null(scene, "the scene loads")
	if scene == null:
		return
	var preview: WindingPreview = scene.instantiate() as WindingPreview
	assert_not_null(preview, "it is a WindingPreview")
	if preview == null:
		return
	# A store it is handed is not kept, read or written.
	var path: String = save_path("preview")
	var store := SaveStore.new(path)
	store.write(Simulation.new(7).to_save())
	var kept: String = FileAccess.get_file_as_string(path)
	preview.save_store = SaveStore.new(path)
	add_child_autofree(preview)
	preview.driver.set_process(false)
	preview.world.set_process(false)
	assert_null(preview.save_store, "it has no save store")
	var sim: Simulation = preview.simulation
	assert_eq(sim.labyrinth.shape, WINDING, "its simulation is winding")
	assert_eq(sim.tick, 0, "a new game")
	assert_eq(preview.world.labyrinth_view.labyrinth, sim.labyrinth, "the world shows it")
	assert_gt(sim.labyrinth.level(1).ladders.size(), 0, "stage 1 has a ladder")
	var off_screen: int = 0
	for i: int in ticks_in(PREVIEW_SECONDS):
		sim.step()
		preview.world.sync(0.1)
		preview.hud.advance(0.1)
		var camera: WorldCamera = preview.world.camera
		var half: Vector2 = preview.world.get_viewport_rect().size / (2.0 * camera.zoom.x)
		var shown := Rect2(camera.position - half, half * 2.0)
		for hero: Hero in sim.party.heroes:
			var sprite: CharacterSprite = preview.world.character(hero.id)
			if sprite == null or not shown.has_point(sprite.position):
				off_screen += 1
	assert_eq(sim.tick, ticks_in(PREVIEW_SECONDS), "it steps for 30 game seconds")
	assert_eq(off_screen, 0, "with every hero on screen all the while")
	preview.save_now()
	assert_eq(FileAccess.get_file_as_string(path), kept, "and it never writes a save")

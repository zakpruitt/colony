extends GutTest
## Acceptance tests for specs/012-ambient-life.

const H: int = Labyrinth.LEVEL_HEIGHT
const TILE: int = LabyrinthView.TILE
const DEMO: String = "res://game/ambience/ambience_demo.tscn"
const STEP: float = 1.0 / 60.0
const PLAIN_PROPS: Array[String] = [
	"stalactite", "mushroom", "crate", "puddle", "glow_mushroom", "crystal"
]
const DEN_PROPS: Array[String] = ["bones", "skull", "web", "spider", "nest"]
const GLOWING: Array[String] = ["glow_mushroom", "crystal"]

var _view: LabyrinthView


## A view and its ambience with [param depth] as the focus level (it and its neighbours built).
func _world(seed_value: int, depth: int) -> Ambience:
	_view = LabyrinthView.new()
	_view.labyrinth = Labyrinth.new(seed_value)
	add_child_autofree(_view)
	var ambience := Ambience.new()
	add_child_autofree(ambience)
	ambience.setup(_view)
	_focus(ambience, depth)
	return ambience


func _focus(ambience: Ambience, depth: int) -> void:
	_view.set_focus(Vector2(60.5, _view.labyrinth.level(depth).floor_y + 1))
	ambience.advance(STEP)


func _run(ambience: Ambience, seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		ambience.advance(STEP)


func _tile_of(world_pixels: Vector2) -> Vector2i:
	return Vector2i(floori(world_pixels.x / TILE), floori(world_pixels.y / TILE))


## The chamber whose columns hold [param column] on [param level], or null in a tunnel.
func _chamber_rect_px(chamber: LabyrinthChamber) -> Rect2:
	return Rect2(chamber.rect.position * TILE, chamber.rect.size * TILE)


func _shafts_px(depth: int) -> Array[Rect2]:
	var shafts: Array[Rect2] = []
	var rects: Array[Rect2i] = [_view.labyrinth.level(depth).shaft_down]
	if depth > 1:
		rects.append(_view.labyrinth.level(depth - 1).shaft_down)
	for shaft: Rect2i in rects:
		shafts.append(Rect2(shaft.position.x * TILE, -100000, shaft.size.x * TILE, 200000))
	return shafts


func _luma(color: Color) -> float:
	return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b


## A point in open space at [param depth] further than every light's reach.
func _dark_point(ambience: Ambience, depth: int) -> Vector2:
	var level: LabyrinthLevel = _view.labyrinth.level(depth)
	for tunnel: Rect2i in level.tunnels:
		for x: int in range(tunnel.position.x, tunnel.end.x):
			var point := Vector2(x * TILE + 8, level.floor_y * TILE + 8)
			var lit: bool = false
			for light: AmbienceLight in ambience.lights():
				if light.position.distance_to(point) < light.radius * 1.2:
					lit = true
			if not lit:
				return point
	return Vector2.INF


func test_r1_dark_with_stepped_light() -> void:
	var found: int = 0
	for seed_value: int in [4, 17, 23]:
		var ambience: Ambience = _world(seed_value, 2)
		ambience.party_light_position = Vector2(-1000, -1000)
		ambience.advance(STEP)
		var torch: AmbienceProp = ambience.level(2).torches[0]
		var dark: Vector2 = _dark_point(ambience, 2)
		if dark == Vector2.INF:
			continue
		found += 1
		var lit: float = ambience.brightness_at(torch.light.position)
		var unlit: float = ambience.brightness_at(dark)
		assert_gt(lit, unlit + 0.25, "seed %d: a torch is much brighter than a tunnel" % seed_value)
		assert_lt(unlit, 0.6, "seed %d: away from light it is dark (%.2f)" % [seed_value, unlit])
		# Walk a pixel at a time from the torch into the dark: a smooth gradient would change at
		# almost every pixel, stepped light changes only at the edge of each ring.
		var changes: int = 0
		var samples: int = roundi(torch.light.position.distance_to(dark))
		var last: float = lit
		for i: int in samples + 1:
			var point: Vector2 = torch.light.position.lerp(dark, float(i) / samples)
			var value: float = ambience.brightness_at(point)
			if not is_equal_approx(value, last):
				changes += 1
			last = value
		assert_between(
			changes,
			2,
			samples / 8,
			"seed %d: light comes in bands over %d px" % [seed_value, samples]
		)
		var single: Array[AmbienceLight] = [torch.light]
		var rings: Dictionary[float, bool] = {}
		for i: int in roundi(torch.light.radius) + 20:
			var point: Vector2 = torch.light.position + Vector2(i, 0)
			rings[snappedf(AmbienceMood.brightness(AmbienceMood.light_at(point, single)), 0.0001)] = true
		assert_between(
			rings.size(), 2, AmbienceMood.STEPS + 1, "one light's rings: %s" % [rings.keys()]
		)
		assert_almost_eq(ambience.brightness_at(Vector2(300, -40)), 1.0, 0.0001, "daylight")
		assert_almost_eq(ambience.brightness_at(Vector2(1500, -200)), 1.0, 0.0001, "the sky")
		var darkness: CanvasItem = ambience.get_node(^"Darkness")
		assert_gt(darkness.z_index, 0, "the darkness is drawn over the characters")
		_check_light_stops_at_walls(ambience, seed_value)
	assert_gt(found, 0, "some seed has a tunnel out of every light")


## Earth more than a tile from open space gets no lamplight at all, however near a torch: the lit
## shape is the chambers' shape, not discs laid over the rock.
func _check_light_stops_at_walls(ambience: Ambience, seed_value: int) -> void:
	var lit_rock: Array[Vector2i] = []
	var checked: int = 0
	for torch: AmbienceProp in ambience.level(2).torches:
		var centre: Vector2i = _tile_of(torch.light.position)
		for dy: int in range(-6, 7):
			for dx: int in range(-6, 7):
				var tile: Vector2i = centre + Vector2i(dx, dy)
				if not _is_buried(tile):
					continue
				checked += 1
				for corner: Vector2 in [Vector2(1, 1), Vector2(8, 8), Vector2(15, 2)]:
					var point: Vector2 = Vector2(tile * TILE) + corner
					var unlit: Color = AmbienceMood.light_at(
						point, [] as Array[AmbienceLight], AmbienceMood.EARTH_EXPOSURE
					)
					if not ambience.light_at(point).is_equal_approx(unlit):
						lit_rock.append(tile)
	assert_gt(checked, 0, "seed %d: rock near torches was checked" % seed_value)
	assert_eq(lit_rock.size(), 0, "seed %d: lamplight on rock at %s" % [seed_value, lit_rock])


func test_r2_torches() -> void:
	for seed_value: int in [3, 8, 31]:
		var ambience: Ambience = _world(seed_value, 2)
		for depth: int in [1, 2, 3]:
			var level: LabyrinthLevel = _view.labyrinth.level(depth)
			var heights: Dictionary[float, bool] = {}
			for chamber: LabyrinthChamber in level.chambers:
				var inside: Rect2 = _chamber_rect_px(chamber)
				var count: int = 0
				for torch: AmbienceProp in ambience.level(depth).torches:
					if torch.chamber != chamber.index:
						continue
					count += 1
					var where: String = (
						"seed %d depth %d chamber %d" % [seed_value, depth, chamber.index]
					)
					assert_true(inside.encloses(torch.rect), "%s: torch inside" % where)
					assert_true(_view.is_open(_tile_of(torch.rect.get_center())), where)
					heights[(level.floor_y + 1) * TILE - torch.rect.end.y] = true
					for shaft: Rect2 in _shafts_px(depth):
						assert_false(shaft.intersects(torch.rect), "%s: off the ladder" % where)
				var width: int = chamber.rect.size.x
				var where_c: String = "seed %d depth %d width %d" % [seed_value, depth, width]
				assert_gte(count, maxi(1, floori(width / 8.0)), "%s: enough torches" % where_c)
				assert_lte(count, ceili(width / 6.0), "%s: not too many torches" % where_c)
			assert_eq(heights.size(), 1, "one torch height above the floor: %s" % [heights.keys()])
			for torch: AmbienceProp in ambience.level(depth).torches:
				assert_not_null(level.chamber_at(_tile_of(torch.rect.get_center()).x), "no tunnel")

	var ambience2: Ambience = _world(5, 1)
	var first: AmbienceProp = ambience2.level(1).torches[0]
	var frames: Dictionary[int, bool] = {}
	var energies: Dictionary[float, bool] = {}
	var ember_at: float = -1.0
	for i: int in 600:
		ambience2.advance(STEP)
		frames[first.frame] = true
		energies[snappedf(first.light.energy, 0.001)] = true
		if ember_at < 0.0 and _count_kind(ambience2.level(1), &"ember") > 0:
			ember_at = i * STEP
	assert_gte(frames.size(), 3, "the flame animates through frames: %s" % [frames.keys()])
	assert_gt(energies.size(), 1, "the light's strength varies")
	assert_between(ember_at, 0.0, 10.0, "an ember rises within 10 s")


func _count_kind(level: AmbienceLevel, kind: StringName) -> int:
	var count: int = 0
	for mote: AmbienceMote in level.motes:
		if mote.kind == kind:
			count += 1
	return count


func test_r3_party_light_follows() -> void:
	var ambience: Ambience = _world(4, 2)
	var dark: Vector2 = _dark_point(ambience, 2)
	if dark == Vector2.INF:
		dark = Vector2(_view.labyrinth.level(2).tunnels[0].position * TILE)
	var before: float = ambience.brightness_at(dark)
	for point: Vector2 in [dark, dark + Vector2(37, 0), Vector2(800, 400)]:
		ambience.party_light_position = point
		ambience.advance(STEP)
		var at_party: Array[AmbienceLight] = []
		for light: AmbienceLight in ambience.lights():
			if light.kind == &"party" and light.position == point:
				at_party.append(light)
		assert_eq(at_party.size(), 1, "one party light at %s" % point)
	ambience.party_light_position = dark
	ambience.advance(STEP)
	assert_gt(ambience.brightness_at(dark), before + 0.1, "the party lights up the tunnel")

	# The formation of four, 17 px apart, and a tile either side, from feet to head, is lit to its
	# true colours in a tunnel of every band, however dark the band.
	for depth: int in [2, 7, 12, 17]:
		_focus(ambience, depth)
		var tunnel: Rect2i = _view.labyrinth.level(depth).tunnels[0]
		var feet := Vector2((tunnel.position.x + tunnel.size.x * 0.5) * TILE, tunnel.end.y * TILE)
		ambience.party_light_position = feet + Vector2(0, -14)
		ambience.advance(STEP)
		var dim: Array[Vector2] = []
		for x: int in range(-26 - TILE, 27 + TILE, 3):
			for y: int in range(-32, 0, 4):
				var point: Vector2 = feet + Vector2(x, y)
				if not ambience.light_at(point).is_equal_approx(Color.WHITE):
					dim.append(point - feet)
		assert_eq(dim.size(), 0, "depth %d: the party is at full colour, not at %s" % [depth, dim])


func test_r4_buried_detail_density() -> void:
	for seed_value: int in [11, 12]:
		var ambience: Ambience = _world(seed_value, 2)
		var buried: int = 0
		var details: int = 0
		var kinds: Dictionary[StringName, bool] = {}
		for depth: int in [1, 2, 3]:
			var top: int = (depth - 1) * H
			for y: int in range(top, top + H):
				for x: int in Labyrinth.LEVEL_WIDTH:
					if _is_buried(Vector2i(x, y)):
						buried += 1
			var placed: Dictionary[Vector2i, StringName] = ambience.level(depth).details
			for tile: Vector2i in placed:
				details += 1
				kinds[placed[tile]] = true
				assert_true(_is_buried(tile), "seed %d: %s is buried" % [seed_value, tile])
				assert_between(tile.y, top, top + H - 1, "in its own band")
		var ratio: float = float(details) / buried
		assert_between(
			ratio,
			1.0 / 60.0,
			1.0 / 30.0,
			"seed %d: %d details, %d tiles" % [seed_value, details, buried]
		)
		assert_gte(kinds.size(), 4, "a mix of things: %s" % [kinds.keys()])


func _is_buried(tile: Vector2i) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if _view.is_open(tile + Vector2i(dx, dy)):
				return false
	return true


func test_r5_chambers_show_their_kind() -> void:
	var seen: Dictionary[LabyrinthChamber.Kind, int] = {}
	for seed_value: int in range(1, 9):
		var ambience: Ambience = _world(seed_value, 2)
		for depth: int in [1, 2, 3]:
			var level: LabyrinthLevel = _view.labyrinth.level(depth)
			for chamber: LabyrinthChamber in level.chambers:
				var so_far: int = seen.get(chamber.kind, 0)
				seen[chamber.kind] = so_far + 1
				var names: PackedStringArray = ambience.props_in(depth, chamber.index)
				var where: String = (
					"seed %d depth %d chamber %d %s" % [seed_value, depth, chamber.index, names]
				)
				match chamber.kind:
					LabyrinthChamber.Kind.START:
						assert_has(names, "campfire", where)
						assert_has(names, "bedroll", where)
					LabyrinthChamber.Kind.DEN:
						assert_gte(_count_in(names, DEN_PROPS), 3, "%s: infested" % where)
						assert_true(names.has("bones") or names.has("skull"), where)
						assert_true(names.has("web"), where)
					LabyrinthChamber.Kind.VAULT:
						assert_has(names, "chest", where)
						assert_has(names, "coins", where)
						assert_has(names, "gleam", where)
					LabyrinthChamber.Kind.PLAIN:
						assert_between(_count_in(names, PLAIN_PROPS), 1, 3, where)
						assert_eq(_count_in(names, PLAIN_PROPS), names.size(), where)
				_check_placement(ambience, depth, chamber, where)
	for kind: LabyrinthChamber.Kind in [
		LabyrinthChamber.Kind.START,
		LabyrinthChamber.Kind.PLAIN,
		LabyrinthChamber.Kind.DEN,
		LabyrinthChamber.Kind.VAULT
	]:
		var checked: int = seen.get(kind, 0)
		assert_gt(checked, 0, "chambers of kind %d were checked" % kind)


func _count_in(names: PackedStringArray, allowed: Array[String]) -> int:
	var count: int = 0
	for prop_name: String in names:
		if allowed.has(prop_name):
			count += 1
	return count


func _check_placement(
	ambience: Ambience, depth: int, chamber: LabyrinthChamber, where: String
) -> void:
	var inside: Rect2 = _chamber_rect_px(chamber)
	var floor_px: float = (_view.labyrinth.level(depth).floor_y + 1) * TILE
	var ceiling_px: float = chamber.rect.position.y * TILE
	for prop: AmbienceProp in ambience.level(depth).props:
		if prop.chamber != chamber.index:
			continue
		var what: String = "%s: %s at %s" % [where, prop.name, prop.rect]
		assert_true(
			prop.rect.position.x >= inside.position.x and prop.rect.end.x <= inside.end.x,
			"%s: inside the chamber's walls" % what
		)
		match prop.anchor:
			AmbienceProp.Anchor.FLOOR:
				assert_between(prop.rect.end.y, floor_px, floor_px + 2.0, "%s: on the floor" % what)
			AmbienceProp.Anchor.CEILING:
				assert_between(
					prop.rect.position.y, ceiling_px - 2.0, ceiling_px, "%s: hangs" % what
				)
			_:
				fail_test("%s: a prop is on the floor or the ceiling" % what)
		for shaft: Rect2 in _shafts_px(depth):
			assert_false(shaft.intersects(prop.rect), "%s: clear of the shaft" % what)


func test_r6_something_always_moves() -> void:
	for seed_value: int in [6, 19]:
		var ambience: Ambience = _world(seed_value, 2)
		var seen: Dictionary[StringName, bool] = {}
		var stray: Array[Vector2] = []
		var dust_near_torch: bool = false
		for i: int in roundi(20.0 / STEP):
			ambience.advance(STEP)
			for depth: int in [1, 2, 3]:
				for mote: AmbienceMote in ambience.level(depth).motes:
					seen[mote.kind] = true
					if (
						mote.kind in [&"beetle", &"moth"]
						and not _view.is_open(_tile_of(mote.position))
					):
						stray.append(mote.position)
			if i % 60 == 0:
				assert_gt(ambience.particle_count(), 0, "something moves at %.0f s" % (i * STEP))
		for torch: AmbienceProp in ambience.level(2).torches:
			for mote: AmbienceMote in ambience.level(2).motes:
				if mote.kind == &"dust" and mote.position.distance_to(torch.light.position) < 64:
					dust_near_torch = true
		var where: String = "seed %d saw %s" % [seed_value, seen.keys()]
		assert_true(dust_near_torch, "%s: dust drifts near torches" % where)
		assert_true(seen.has(&"drip"), "%s: a drip falls" % where)
		assert_true(seen.has(&"splash"), "%s: a drip splashes" % where)
		assert_true(seen.has(&"beetle") or seen.has(&"moth"), "%s: a critter" % where)
		assert_eq(stray.size(), 0, "critters stay in open space: %s" % [stray.slice(0, 5)])


func test_r7_depth_mood() -> void:
	var ambient: Array[Color] = []
	var tint: Array[Color] = []
	for depth: int in [3, 8, 13, 18]:
		ambient.append(AmbienceMood.ambient_color(depth))
		tint.append(AmbienceMood.light_tint(depth))
	for i: int in 4:
		for j: int in range(i + 1, 4):
			assert_ne(ambient[i], ambient[j], "ambient of bands %d and %d" % [i, j])
			assert_ne(tint[i], tint[j], "light tint of bands %d and %d" % [i, j])
	var loam: Color = ambient[0]
	var clay: Color = ambient[1]
	var stone: Color = ambient[2]
	var deep: Color = ambient[3]
	assert_gt(loam.r, loam.b, "loam is warm")
	assert_gt(clay.r - clay.b, loam.r - loam.b, "clay is warmer")
	assert_gt(stone.b, stone.r, "stone is cold")
	assert_lt(_luma(stone), _luma(loam), "stone is darker")
	assert_gt(deep.g, deep.r, "deep is teal")
	assert_gt(deep.b, deep.r, "deep is teal")
	assert_eq(AmbienceMood.ambient_color(21), loam, "the bands repeat like the earth")
	# Dark, never black: unlit earth stays readable in every band, the stone's included.
	var none: Array[AmbienceLight] = []
	for depth: int in [3, 8, 13, 18]:
		var rock: Color = AmbienceMood.light_at(
			Vector2(100, (depth - 1) * H * TILE + 100), none, AmbienceMood.EARTH_EXPOSURE
		)
		assert_gt(AmbienceMood.brightness(rock), 0.35, "depth %d earth is readable" % depth)

	var glowing_above: Array[String] = []
	var glowing_below: int = 0
	for seed_value: int in [2, 5, 9]:
		var ambience: Ambience = _world(seed_value, 2)
		for depth: int in [7, 12, 17]:
			_focus(ambience, depth)
			for near: int in [depth - 1, depth, depth + 1]:
				for prop: AmbienceProp in ambience.level(near).props:
					if GLOWING.has(String(prop.name)):
						if near < 11:
							glowing_above.append("seed %d depth %d" % [seed_value, near])
						else:
							glowing_below += 1
	assert_eq(glowing_above.size(), 0, "no glowing props above stone: %s" % [glowing_above])
	assert_gt(glowing_below, 0, "glowing props appear from the stone band down")


func test_r8_follows_the_view() -> void:
	var ambience: Ambience = _world(9, 1)
	var before: Dictionary = _snapshot(ambience, 1)
	assert_gt(before.size(), 0)
	_focus(ambience, 6)
	assert_null(ambience.level(1), "depth 1's decoration was freed")
	_focus(ambience, 1)
	assert_eq(_snapshot(ambience, 1), before, "the same decoration after a rebuild")
	var first_view: LabyrinthView = _view
	var other: Ambience = _world(9, 1)
	assert_eq(_snapshot(other, 1), before, "another ambience agrees")
	_view = first_view

	var most_nodes: int = 0
	var most_props: int = 0
	for depth: int in range(1, 32):
		_focus(ambience, depth)
		_run(ambience, 0.1)
		assert_eq(ambience.built_depths(), _view.built_depths(), "at depth %d" % depth)
		most_nodes = maxi(most_nodes, _count_nodes(ambience))
		var props: int = 0
		for built: int in ambience.built_depths():
			props += ambience.level(built).props.size() + ambience.level(built).torches.size()
		most_props = maxi(most_props, props)
	# The darkness and its glow, then five levels at most.
	assert_lte(most_nodes, 2 + 5 * AmbienceLevel.NODES, "nodes stay bounded")
	assert_lte(most_props, 5 * 40, "no more than five levels of decoration")
	assert_no_new_orphans()


func _snapshot(ambience: Ambience, depth: int) -> Dictionary:
	var level: AmbienceLevel = ambience.level(depth)
	var snapshot: Dictionary = {}
	for chamber: LabyrinthChamber in _view.labyrinth.level(depth).chambers:
		snapshot["props %d" % chamber.index] = ambience.props_in(depth, chamber.index)
	for prop: AmbienceProp in level.props + level.torches:
		snapshot["%s %s" % [prop.name, prop.rect]] = true
	snapshot["details"] = level.details.duplicate()
	return snapshot


func _count_nodes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		count += 1 + _count_nodes(child)
	return count


func test_r9_budget() -> void:
	for seed_value: int in [1, 13, 27, 40]:
		var ambience: Ambience = _world(seed_value, 2)
		assert_eq(_view.built_depths().size(), 3)
		var most_lights: int = 0
		var most_particles: int = 0
		for i: int in roundi(20.0 / STEP):
			ambience.advance(STEP)
			most_lights = maxi(most_lights, ambience.light_count())
			most_particles = maxi(most_particles, ambience.particle_count())
		assert_between(most_lights, 1, 60, "seed %d lights" % seed_value)
		assert_between(most_particles, 1, 600, "seed %d particles" % seed_value)


func test_r10_demo_runs() -> void:
	var scene: PackedScene = load(DEMO)
	assert_not_null(scene, "the demo scene loads")
	if scene == null:
		return
	var demo: AmbienceDemo = scene.instantiate()
	add_child_autofree(demo)
	var kinds: Dictionary[LabyrinthChamber.Kind, bool] = {}
	var bands: Dictionary[int, bool] = {}
	for stop: AmbienceDemo.Stop in demo.stops:
		var chamber: LabyrinthChamber = demo.labyrinth.level(stop.depth).chamber_at(
			floori(stop.start.x)
		)
		if chamber != null:
			kinds[chamber.kind] = true
		bands[(stop.depth - 1) / LabyrinthTiles.LEVELS_PER_STRATUM % 4] = true
	assert_eq(kinds.size(), 4, "the tour visits every chamber kind: %s" % [kinds.keys()])
	assert_eq(bands.size(), 4, "the tour visits every depth band: %s" % [bands.keys()])
	await wait_process_frames(300)
	assert_gt(demo.ambience.light_count(), 0, "the demo has lights")
	assert_gt(demo.ambience.particle_count(), 0, "the demo has motion")
	assert_push_error_count(0)
	assert_engine_error_count(0)

extends GutTest
## Acceptance tests for specs/006-labyrinth-view.

const H: int = Labyrinth.LEVEL_HEIGHT
const W: int = Labyrinth.LEVEL_WIDTH
const DEMO: String = "res://game/world/labyrinth_demo.tscn"
const TILES_DIR: String = "res://assets/sprites/tiles/"
const STEP: float = 1.0 / 60.0


func _view(seed_value: int) -> LabyrinthView:
	var view := LabyrinthView.new()
	view.labyrinth = Labyrinth.new(seed_value)
	add_child_autofree(view)
	return view


func _band_top(depth: int) -> int:
	return (depth - 1) * H


## A focus point standing on the floor of [param depth], in world tiles.
func _floor_focus(view: LabyrinthView, depth: int) -> Vector2:
	return Vector2(60.5, view.labyrinth.level(depth).floor_y + 1)


## The ground visual of a tile ("<sheet>/<part>"), or "" if nothing is drawn there.
func _ground(view: LabyrinthView, tile: Vector2i) -> String:
	var visuals: PackedStringArray = view.visuals_at(tile)
	return visuals[0] if not visuals.is_empty() else ""


func _part_image(visual: String) -> PackedByteArray:
	var sheet_name: String = visual.get_slice("/", 0)
	var part_name: String = visual.get_slice("/", 1)
	var sheet: PixelSheet = PixelSheet.load_sheet(TILES_DIR + sheet_name + ".png")
	if sheet == null:
		return PackedByteArray()
	return sheet.part(StringName(part_name)).get_image().get_data()


func test_r1_open_matches_the_labyrinth() -> void:
	for seed_value: int in [1, 42, 9001]:
		var view: LabyrinthView = _view(seed_value)
		var labyrinth: Labyrinth = view.labyrinth
		for depth: int in range(1, 5):
			var rects: Array[Rect2i] = labyrinth.level(depth).open_rects()
			if depth > 1:
				rects.append(labyrinth.level(depth - 1).shaft_down)
			var wrong: Array[Vector2i] = []
			var incoming_open: int = 0
			for y: int in range(_band_top(depth), _band_top(depth) + H):
				for x: int in W:
					var tile := Vector2i(x, y)
					var expected: bool = false
					for rect: Rect2i in rects:
						expected = expected or rect.has_point(tile)
					if view.is_open(tile) != expected:
						wrong.append(tile)
					if depth > 1 and labyrinth.level(depth - 1).shaft_down.has_point(tile):
						incoming_open += 1 if view.is_open(tile) else 0
			var where: String = "seed %d depth %d" % [seed_value, depth]
			assert_eq(wrong.size(), 0, "%s: tiles where is_open disagrees: %s" % [where, wrong])
			if depth > 1:
				assert_gt(incoming_open, 0, "%s: the shaft from above is open here" % where)


func test_r2_edges_and_variants() -> void:
	var view: LabyrinthView = _view(7)
	var level: LabyrinthLevel = view.labyrinth.level(1)
	view.set_focus(_floor_focus(view, 1))

	# Rows 0-3 of depth 1 are always earth; row 2 has earth all round.
	var buried := Vector2i(60, 2)
	var chamber: Rect2i = level.chambers[1].rect
	var floor_edge := Vector2i(chamber.position.x + 3, level.floor_y + 1)
	assert_false(view.is_open(floor_edge), "the tile under the floor is earth")
	assert_true(view.is_open(floor_edge + Vector2i.UP), "the tile above it is open")
	assert_ne(
		view.visuals_at(buried),
		view.visuals_at(floor_edge),
		"buried earth and the floor edge are drawn differently"
	)
	assert_string_starts_with(_ground(view, buried), "loam/buried_")

	var variants: Dictionary[String, bool] = {}
	var before: Dictionary[Vector2i, PackedStringArray] = {}
	for y: int in H:
		for x: int in W:
			var tile := Vector2i(x, y)
			before[tile] = view.visuals_at(tile)
			if _ground(view, tile).begins_with("loam/buried_"):
				variants[_ground(view, tile)] = true
	assert_gte(variants.size(), 3, "buried variants seen in one level: %s" % [variants.keys()])

	# Walk far enough that depth 1 is freed, come back, and compare.
	view.set_focus(_floor_focus(view, 6))
	assert_does_not_have(view.built_depths(), 1, "depth 1 was freed")
	view.set_focus(_floor_focus(view, 1))
	var changed: int = 0
	for tile: Vector2i in before:
		if view.visuals_at(tile) != before[tile]:
			changed += 1
	assert_eq(changed, 0, "rebuilding draws the same tile at the same place")
	var other: LabyrinthView = _view(7)
	other.set_focus(_floor_focus(other, 1))
	assert_eq(other.visuals_at(buried), view.visuals_at(buried), "another view agrees")


func test_r3_shaft_has_a_ladder() -> void:
	for seed_value: int in [3, 11]:
		var view: LabyrinthView = _view(seed_value)
		for depth: int in [1, 2, 3]:
			view.set_focus(_floor_focus(view, depth + 1))
			var shaft: Rect2i = view.labyrinth.level(depth).shaft_down
			var bare: Array[Vector2i] = []
			for y: int in range(shaft.position.y, shaft.end.y):
				for x: int in range(shaft.position.x, shaft.end.x):
					var side: String = "ladder/left" if x == shaft.position.x else "ladder/right"
					if not view.visuals_at(Vector2i(x, y)).has(side):
						bare.append(Vector2i(x, y))
			assert_eq(shaft.size, Vector2i(2, H), "the shaft is two wide and a level tall")
			assert_eq(
				bare.size(),
				0,
				"seed %d depth %d shaft tiles without ladder: %s" % [seed_value, depth, bare]
			)


func test_r4_depth_bands_differ() -> void:
	var view: LabyrinthView = _view(5)
	view.set_focus(_floor_focus(view, 3))
	var shallow: String = _ground(view, Vector2i(60, _band_top(3) + 1))
	view.set_focus(_floor_focus(view, 8))
	var deep: String = _ground(view, Vector2i(60, _band_top(8) + 1))
	assert_string_contains(shallow, "/buried_")
	assert_string_contains(deep, "/buried_")
	assert_ne(shallow.get_slice("/", 0), deep.get_slice("/", 0), "different earth art")
	var shallow_image: PackedByteArray = _part_image(shallow)
	var deep_image: PackedByteArray = _part_image(deep)
	assert_false(shallow_image.is_empty(), "the depth 3 tile image loads")
	assert_ne(shallow_image, deep_image, "the earth at depth 3 and depth 8 looks different")


func test_r5_builds_near_frees_far() -> void:
	var view: LabyrinthView = _view(21)
	view.set_focus(_floor_focus(view, 5))
	assert_eq(view.built_depths(), [4, 5, 6] as Array[int])
	view.set_focus(_floor_focus(view, 1))
	assert_eq(view.built_depths(), [1, 2] as Array[int], "far levels freed, none above 1")
	view.set_focus(Vector2(10, -3))
	assert_eq(view.built_depths(), [1, 2] as Array[int], "the surface counts as depth 1")

	for depth: int in range(1, 32):
		view.set_focus(_floor_focus(view, depth))
		var built: Array[int] = view.built_depths()
		assert_lte(built.size(), 5, "at depth %d built %s" % [depth, built])
		for near: int in range(maxi(1, depth - 1), depth + 2):
			assert_has(built, near, "at depth %d" % depth)
		for far: int in built:
			assert_lte(absi(far - depth), 2, "at depth %d still built: %d" % [depth, far])
	assert_no_new_orphans()


func test_r6_surface_above_depth_one() -> void:
	var view: LabyrinthView = _view(2)
	view.set_focus(_floor_focus(view, 1))
	assert_not_null(view.get_node_or_null(^"Surface"), "the surface node exists")
	for row: int in [-1, -2, -10]:
		for column: int in [0, 37, W - 1]:
			var visual: String = _ground(view, Vector2i(column, row))
			assert_string_starts_with(visual, "surface/", "row %d column %d" % [row, column])
	assert_ne(_ground(view, Vector2i(5, -1)), _ground(view, Vector2i(5, -2)), "a ground line")
	assert_string_starts_with(_ground(view, Vector2i(5, 0)), "loam/", "earth starts at row 0")


func test_r7_camera_follows_clamps_and_shakes() -> void:
	var camera := WorldCamera.new()
	add_child_autofree(camera)
	var half_width: float = camera.get_viewport_rect().size.x * 0.5 / camera.zoom.x
	var band: float = W * LabyrinthView.TILE

	camera.snap_to(Vector2(800, 200))
	assert_eq(camera.position, Vector2(800, 200), "snap_to lands exactly")

	camera.target = Vector2(1400, 900)
	camera._process(STEP)
	var start: float = Vector2(800, 200).distance_to(camera.target)
	var now: float = camera.position.distance_to(camera.target)
	assert_lt(now, start, "it moves toward the target")
	assert_gt(now, start * 0.5, "it eases, it does not snap")
	for i: int in 600:
		camera._process(STEP)
	assert_almost_eq(camera.position.distance_to(camera.target), 0.0, 1.0, "it gets there")

	for far: Vector2 in [Vector2(-900, 100), Vector2(band + 900, 100)]:
		camera.target = far
		for i: int in 600:
			camera._process(STEP)
			if i % 50 == 0:
				camera.shake(4.0)
			var center: Vector2 = camera.position + camera.offset
			assert_true(center.x - half_width >= 0.0, "left edge in the band at %s" % center)
			assert_true(center.x + half_width <= band, "right edge in the band at %s" % center)
			assert_eq(camera.position, camera.position.round(), "whole pixels")
			assert_eq(camera.offset, camera.offset.round(), "whole pixels")
		assert_true(is_equal_approx(camera.position.y, far.y), "followed vertically")

	camera.snap_to(Vector2(960, 300))
	for i: int in 120:
		camera._process(STEP)
	camera.shake(6.0)
	var moved: bool = false
	for i: int in 10:
		camera._process(STEP)
		moved = moved or camera.offset != Vector2.ZERO
		assert_eq(camera.position, Vector2(960, 300), "the followed position does not move")
	assert_true(moved, "shake offsets the view")
	for i: int in 120:
		camera._process(STEP)
	assert_eq(camera.offset, Vector2.ZERO, "the shake decays to nothing")
	assert_eq(camera.position, Vector2(960, 300))


func test_r8_demo_runs() -> void:
	var scene: PackedScene = load(DEMO)
	assert_not_null(scene, "the demo scene loads")
	if scene == null:
		return
	var demo: LabyrinthDemo = scene.instantiate()
	add_child_autofree(demo)
	await wait_process_frames(1)
	var start: Vector2 = demo.focus
	await wait_process_frames(120)
	assert_ne(demo.focus, start, "the focus moves")
	assert_gt(demo.view.built_depths().size(), 0, "the demo built levels")
	assert_push_error_count(0)
	assert_engine_error_count(0)

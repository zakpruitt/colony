extends ColonyTest
## Unit tests for LabyrinthView and LabyrinthTiles: which art goes where.


func _view(seed_value: int) -> LabyrinthView:
	var view := LabyrinthView.new()
	view.labyrinth = Labyrinth.new(seed_value)
	add_child_autofree(view)
	return view


func _has_prefix(visuals: PackedStringArray, prefix: String) -> bool:
	for visual: String in visuals:
		if visual.begins_with(prefix):
			return true
	return false


func test_strata_change_every_five_levels_then_repeat() -> void:
	var expected: Dictionary[int, StringName] = {
		1: &"loam",
		5: &"loam",
		6: &"clay",
		10: &"clay",
		11: &"stone",
		15: &"stone",
		16: &"deep",
		20: &"deep",
		21: &"loam",
		26: &"clay"
	}
	for depth: int in expected:
		assert_eq(LabyrinthTiles.stratum(depth), expected[depth], "depth %d" % depth)


func test_every_part_the_view_asks_for_exists() -> void:
	var sheets: Array[StringName] = LabyrinthTiles.STRATA.duplicate()
	for sheet: StringName in sheets:
		var wanted: PackedStringArray = []
		for variant: int in LabyrinthTiles.BURIED_VARIANTS:
			wanted.append("buried_%d" % variant)
		for variant: int in LabyrinthTiles.BACK_VARIANTS:
			wanted.append("back_%d" % variant)
		for mask: int in range(1, 16):
			wanted.append("corner_%d" % mask)
			wanted.append("shade_%d" % mask)
			for variant: int in LabyrinthTiles.EDGE_VARIANTS:
				wanted.append("edge_%d_%d" % [mask, variant])
		for part: String in wanted:
			assert_ne(LabyrinthTiles.coords(sheet, part), Vector2i(-1, -1), "%s/%s" % [sheet, part])
	for part: String in ["left", "right", "top_left", "top_right"]:
		assert_ne(LabyrinthTiles.coords(LabyrinthTiles.LADDER, part), Vector2i(-1, -1), part)
	for part: String in ["sky", "ground"]:
		assert_ne(LabyrinthTiles.coords(LabyrinthTiles.SURFACE, part), Vector2i(-1, -1), part)


func test_edges_follow_the_open_sides() -> void:
	var view: LabyrinthView = _view(17)
	var level: LabyrinthLevel = view.labyrinth.level(1)
	view.set_focus(Vector2(60, level.floor_y))
	var room: Rect2i = level.chambers[1].rect

	var floor_tile := Vector2i(room.position.x + 4, level.floor_y + 1)
	assert_true(_has_prefix(view.visuals_at(floor_tile), "loam/edge_1_"), "floor: open above")
	var left_wall := Vector2i(room.position.x - 1, room.position.y)
	var sides: int = LabyrinthTiles.E
	if view.is_open(left_wall + Vector2i.DOWN):  # a low room's wall can stand on a tunnel
		sides |= LabyrinthTiles.S
	var wall_edge: String = "loam/edge_%d_" % sides
	assert_true(_has_prefix(view.visuals_at(left_wall), wall_edge), "left wall: open east")
	var ceiling := Vector2i(room.position.x + 4, room.position.y - 1)
	assert_true(_has_prefix(view.visuals_at(ceiling), "loam/edge_4_"), "ceiling: open below")
	var under_ceiling := Vector2i(room.position.x + 4, room.position.y)
	assert_true(_has_prefix(view.visuals_at(under_ceiling), "loam/back_"), "back wall")
	assert_true(_has_prefix(view.visuals_at(under_ceiling), "loam/shade_1"), "shade under it")
	# The earth tile right of the floor's last tile and under the right wall: an inner corner.
	var corner := Vector2i(room.end.x, level.floor_y + 1)
	if not view.is_open(Vector2i(room.end.x, level.floor_y)):
		assert_has(view.visuals_at(corner), "loam/corner_8", "floor meets the right wall")


func test_ladder_top_stands_on_the_floor() -> void:
	var view: LabyrinthView = _view(17)
	var level: LabyrinthLevel = view.labyrinth.level(1)
	view.set_focus(Vector2(60, level.floor_y))
	var shaft: Rect2i = level.shaft_down
	var top := Vector2i(shaft.position.x, shaft.position.y - 1)
	assert_has(view.visuals_at(top), "ladder/top_left")
	assert_has(view.visuals_at(top + Vector2i.RIGHT), "ladder/top_right")
	assert_false(_has_prefix(view.visuals_at(top + Vector2i.UP), "ladder/"), "nothing above it")


func test_variants_depend_only_on_position() -> void:
	var seen: Dictionary[String, bool] = {}
	for x: int in 200:
		var tile := Vector2i(x, x * 7 % 31)
		seen[LabyrinthTiles.buried_part(tile)] = true
	assert_gt(seen.size(), 5, "many variants are used: %s" % [seen.keys()])


func test_to_pixels() -> void:
	assert_eq(LabyrinthView.to_pixels(Vector2(3, 2.5)), Vector2(48, 40))

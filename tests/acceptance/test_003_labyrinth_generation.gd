extends GutTest
## Acceptance tests for specs/003-labyrinth-generation.

const SEEDS: int = 50
const DEPTHS: int = 40
const SHAFT_MARGIN: int = 2


## Every (seed, level) pair the "many levels" tests walk through.
func _many_levels(callback: Callable) -> void:
	for seed_value: int in SEEDS:
		var labyrinth := Labyrinth.new(seed_value * 7919 + 13)
		for depth: int in range(1, DEPTHS + 1):
			callback.call(seed_value * 7919 + 13, labyrinth, labyrinth.level(depth))


func _band_top(depth: int) -> int:
	return (depth - 1) * Labyrinth.LEVEL_HEIGHT


func _where(seed_value: int, depth: int) -> String:
	return "seed %d depth %d" % [seed_value, depth]


func _inside_with_margin(shaft: Rect2i, chamber: LabyrinthChamber) -> bool:
	return (
		shaft.position.x - chamber.rect.position.x >= SHAFT_MARGIN
		and chamber.rect.end.x - shaft.end.x >= SHAFT_MARGIN
	)


func _describe(level: LabyrinthLevel) -> Array:
	var out: Array = [level.depth, level.floor_y, level.shaft_down]
	for chamber: LabyrinthChamber in level.chambers:
		out.append([chamber.index, chamber.kind, chamber.rect])
	for tunnel: Rect2i in level.tunnels:
		out.append(tunnel)
	return out


func test_r1_deep_level_generates_alone() -> void:
	var labyrinth := Labyrinth.new(1234)
	var level: LabyrinthLevel = labyrinth.level(500)
	assert_not_null(level)
	assert_eq(level.depth, 500)
	var top: int = _band_top(500)
	for rect: Rect2i in level.open_rects():
		if rect == level.shaft_down:
			continue
		assert_true(rect.position.y >= top, "rect %s below band top %d" % [rect, top])
		assert_true(rect.end.y <= top + Labyrinth.LEVEL_HEIGHT, "rect %s inside band" % rect)
	assert_eq(labyrinth._levels.keys(), [500], "only depth 500 was generated")
	assert_same(labyrinth.level(500), level, "the level is cached")


func test_r2_same_seed_same_levels_in_any_order() -> void:
	var forward := Labyrinth.new(99)
	var backward := Labyrinth.new(99)
	var forward_levels: Dictionary[int, Array] = {}
	for depth: int in range(1, 21):
		forward_levels[depth] = _describe(forward.level(depth))
	for depth: int in range(20, 0, -1):
		assert_eq(_describe(backward.level(depth)), forward_levels[depth], "depth %d" % depth)


func test_r2_different_seeds_differ() -> void:
	var first: Array = _describe(Labyrinth.new(1).level(1))
	var second: Array = _describe(Labyrinth.new(2).level(1))
	assert_ne(first, second)


func test_r3_level_stays_in_its_band() -> void:
	_many_levels(
		func(seed_value: int, _labyrinth: Labyrinth, level: LabyrinthLevel) -> void:
			var where: String = _where(seed_value, level.depth)
			var top: int = _band_top(level.depth)
			assert_eq(level.floor_y, top + 11, where)
			var band := Rect2i(0, top, Labyrinth.LEVEL_WIDTH, Labyrinth.LEVEL_HEIGHT)
			for rect: Rect2i in level.open_rects():
				if rect == level.shaft_down:
					continue
				assert_true(band.encloses(rect), "%s: %s outside band %s" % [where, rect, band])
				assert_eq(rect.end.y - 1, level.floor_y, "%s: %s floor row" % [where, rect])
	)


func test_r4_chambers_are_well_formed() -> void:
	_many_levels(
		func(seed_value: int, _labyrinth: Labyrinth, level: LabyrinthLevel) -> void:
			var where: String = _where(seed_value, level.depth)
			var count: int = level.chambers.size()
			assert_between(count, 4, 6, where)
			for i: int in count:
				var chamber: LabyrinthChamber = level.chambers[i]
				var rect: Rect2i = chamber.rect
				assert_eq(chamber.index, i, where)
				assert_between(rect.size.x, 12, 24, "%s chamber %d width" % [where, i])
				assert_between(rect.size.y, 4, 8, "%s chamber %d height" % [where, i])
				assert_eq(rect.end.y - 1, level.floor_y, "%s chamber %d bottom" % [where, i])
				if i > 0:
					var previous: Rect2i = level.chambers[i - 1].rect
					assert_true(
						previous.end.x <= rect.position.x, "%s chamber %d order" % [where, i]
					)
			assert_true(level.chambers[0].rect.position.x >= 1, "%s left margin" % where)
			assert_true(
				level.chambers[count - 1].rect.end.x <= Labyrinth.LEVEL_WIDTH - 1,
				"%s right margin" % where
			)
	)


func test_r5_floor_is_walkable_end_to_end() -> void:
	_many_levels(
		func(seed_value: int, _labyrinth: Labyrinth, level: LabyrinthLevel) -> void:
			var where: String = _where(seed_value, level.depth)
			var count: int = level.chambers.size()
			assert_eq(level.tunnels.size(), count - 1, "%s tunnel count" % where)
			for i: int in level.tunnels.size():
				var tunnel: Rect2i = level.tunnels[i]
				assert_eq(tunnel.size.y, 3, "%s tunnel %d height" % [where, i])
				assert_eq(tunnel.end.y - 1, level.floor_y, "%s tunnel %d bottom" % [where, i])
				assert_between(tunnel.size.x, 4, 10, "%s tunnel %d length" % [where, i])
				assert_eq(
					tunnel.position.x,
					level.chambers[i].rect.end.x,
					"%s tunnel %d start" % [where, i]
				)
				assert_eq(
					tunnel.end.x,
					level.chambers[i + 1].rect.position.x,
					"%s tunnel %d end" % [where, i]
				)
			var first: int = level.chambers[0].rect.position.x
			var last: int = level.chambers[count - 1].rect.end.x
			var open: Array[Rect2i] = level.open_rects()
			var solid: Array[int] = []
			for column: int in range(first, last):
				var cell := Vector2i(column, level.floor_y)
				var covered: bool = false
				for rect: Rect2i in open:
					if rect != level.shaft_down and rect.has_point(cell):
						covered = true
				if not covered:
					solid.append(column)
			assert_eq(solid, [] as Array[int], "%s solid floor columns" % where)
	)


func test_r6_shaft_connects_to_next_level() -> void:
	_many_levels(
		func(seed_value: int, labyrinth: Labyrinth, level: LabyrinthLevel) -> void:
			var where: String = _where(seed_value, level.depth)
			var shaft: Rect2i = level.shaft_down
			var below: LabyrinthLevel = labyrinth.level(level.depth + 1)
			assert_eq(shaft.size.x, 2, "%s shaft width" % where)
			assert_eq(shaft.position.y, level.floor_y + 1, "%s shaft top" % where)
			assert_eq(shaft.end.y - 1, below.floor_y, "%s shaft bottom" % where)
			assert_eq(
				shaft.position.x, labyrinth.shaft_column(level.depth), "%s shaft_column" % where
			)
			var here: LabyrinthChamber = level.shaft_chamber()
			assert_not_null(here, "%s shaft chamber" % where)
			if here != null:
				assert_true(_inside_with_margin(shaft, here), "%s margin here" % where)
			var landing: LabyrinthChamber = below.chamber_at(shaft.position.x)
			assert_not_null(landing, "%s landing chamber" % where)
			if landing != null:
				assert_true(_inside_with_margin(shaft, landing), "%s margin below" % where)
			var third: int = int(Labyrinth.LEVEL_WIDTH / 3.0)
			if level.depth % 2 == 1:
				assert_true(shaft.position.x >= 2 * third, "%s odd depth right third" % where)
				assert_true(
					shaft.end.x <= Labyrinth.LEVEL_WIDTH, "%s odd depth right third" % where
				)
			else:
				assert_true(shaft.end.x <= third, "%s even depth left third" % where)
				assert_true(shaft.position.x >= 0, "%s even depth left third" % where)
	)


func test_r7_chamber_kinds_follow_the_rules() -> void:
	var counts: Dictionary[LabyrinthChamber.Kind, int] = {
		LabyrinthChamber.Kind.PLAIN: 0,
		LabyrinthChamber.Kind.DEN: 0,
		LabyrinthChamber.Kind.VAULT: 0,
	}
	var chosen: Array[int] = [0]
	_many_levels(
		func(seed_value: int, _labyrinth: Labyrinth, level: LabyrinthLevel) -> void:
			var where: String = _where(seed_value, level.depth)
			var vaults: int = 0
			var shaft_chamber: LabyrinthChamber = level.shaft_chamber()
			for chamber: LabyrinthChamber in level.chambers:
				var is_start: bool = level.depth == 1 and chamber.index == 0
				assert_eq(
					chamber.kind == LabyrinthChamber.Kind.START,
					is_start,
					"%s chamber %d START" % [where, chamber.index]
				)
				if chamber.kind == LabyrinthChamber.Kind.VAULT:
					vaults += 1
				if chamber == shaft_chamber:
					assert_false(chamber.kind == LabyrinthChamber.Kind.DEN, "%s shaft DEN" % where)
					assert_false(
						chamber.kind == LabyrinthChamber.Kind.VAULT, "%s shaft VAULT" % where
					)
				elif not is_start:
					counts[chamber.kind] += 1
					chosen[0] += 1
			assert_true(vaults <= 1, "%s has %d vaults" % [where, vaults])
	)
	var total: float = float(chosen[0])
	var plain: float = 100.0 * counts[LabyrinthChamber.Kind.PLAIN] / total
	var den: float = 100.0 * counts[LabyrinthChamber.Kind.DEN] / total
	var vault: float = 100.0 * counts[LabyrinthChamber.Kind.VAULT] / total
	var mix: String = "plain %.1f den %.1f vault %.1f" % [plain, den, vault]
	assert_almost_eq(plain, 60.0, 10.0, mix)
	assert_almost_eq(den, 30.0, 10.0, mix)
	assert_almost_eq(vault, 10.0, 10.0, mix)
	assert_true(vault > 0.0, mix)


func test_r8_lookup() -> void:
	_many_levels(
		func(seed_value: int, _labyrinth: Labyrinth, level: LabyrinthLevel) -> void:
			var where: String = _where(seed_value, level.depth)
			var wrong: Array[int] = []
			for chamber: LabyrinthChamber in level.chambers:
				for column: int in range(chamber.rect.position.x, chamber.rect.end.x):
					if level.chamber_at(column) != chamber:
						wrong.append(column)
			for tunnel: Rect2i in level.tunnels:
				for column: int in range(tunnel.position.x, tunnel.end.x):
					if level.chamber_at(column) != null:
						wrong.append(column)
			assert_eq(wrong, [] as Array[int], "%s columns with the wrong chamber" % where)
			assert_null(level.chamber_at(0), "%s solid edge" % where)
			var expected: Array[Rect2i] = []
			for chamber: LabyrinthChamber in level.chambers:
				expected.append(chamber.rect)
			expected.append_array(level.tunnels)
			expected.append(level.shaft_down)
			assert_eq(level.open_rects(), expected, where)
	)

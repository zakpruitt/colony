extends "res://tests/support/cave_fixture.gd"
## Spec 101: the rooms of a winding, zoned stage are dressed from one table, each area with
## things of its own: stalagmites on the floors, stalactites gathered under the dips, columns
## where floor and ceiling come close, roots, urns, pillars and alcoves. Nothing stands in the
## way, each room is dressed to its size, and the simulation does not know.

const SEEDS: int = 10
const MOST_ROWS: int = RoomShape.MOST_ROWS
## R1: `Simulation.state_hash()` of a winding game after 5 game minutes, by seed, recorded on
## `dev` at db5fe0d.
## Re-recorded by spec 104, whose quests take longer and are worked by every able hero.
const RECORDED_HASHES: Dictionary[int, int] = {1: 2264431711, 2: 2383618878, 3: 2535858815}
## The props that say what kind a room is: no row of the table.
const OWN: Array[StringName] = [
	&"campfire",
	&"bedroll",
	&"web",
	&"spider",
	&"bones",
	&"skull",
	&"nest",
	&"coins",
	&"chest",
	&"gleam"
]
## The kinds the code chose between before there was a table.
const OLD_KINDS: Array[StringName] = [
	&"stalactite", &"mushroom", &"crate", &"puddle", &"glow_mushroom", &"crystal"
]
## The kinds drawn from this spec's sheets.
const NEW_KINDS: Array[StringName] = [
	&"stalagmite", &"column", &"roots", &"urn", &"pot", &"pillar", &"alcove"
]
## R4: what each area must show in 20 rooms, and what it must not.
const SHOWN: Dictionary[StringName, Array] = {
	MOSSY: [&"roots", &"mushroom", &"stalactite", &"stalagmite", &"puddle"],
	CLAY: [&"urn", &"pot", &"crate", &"puddle", &"stalagmite"],
	CRYPT: [&"pillar", &"alcove", &"web"],
	EMBER: [&"crystal", &"glow_mushroom", &"stalagmite", &"column", &"stalactite"],
}
const NEVER: Dictionary[StringName, Array] = {
	MOSSY: [],
	CLAY: [&"roots"],
	CRYPT: [&"stalagmite", &"stalactite", &"mushroom", &"glow_mushroom"],
	EMBER: [&"crate", &"urn", &"pot"],
}


## The count [param counts] holds for [param key], or [param none].
func _n(counts: Dictionary, key: Variant, none: int = 0) -> int:
	var count: int = counts.get(key, none)
	return count


## The runs of columns of [param room] under a dip of its ceiling, each as (first, last): a level
## run lower than the ceiling either side of it, between the walls' columns.
func _dips(view: LabyrinthView, room: LabyrinthChamber) -> Array[Vector2i]:
	var dips: Array[Vector2i] = []
	var from: int = room.rect.position.x + 1
	var to: int = room.rect.end.x - 2
	var first: int = from
	while first <= to:
		var row: int = open_top(view, room, first)
		var last: int = first
		while last < to and open_top(view, room, last + 1) == row:
			last += 1
		var left: int = open_top(view, room, first - 1)
		var right: int = open_top(view, room, last + 1)
		if left < row and right < row:
			dips.append(Vector2i(first, last))
		first = last + 1
	return dips


## A level of [param view] dressed from [param table].
func _dressed_from(view: LabyrinthView, stage: int, table: Array[Dictionary]) -> AmbienceLevel:
	var dressed := AmbienceLevel.new()
	dressed.table = table
	add_child_autofree(dressed)
	dressed.build(view, stage)
	return dressed


## Everything placed on [param dressed], as text, in order.
func _listing(dressed: AmbienceLevel) -> PackedStringArray:
	var all: PackedStringArray = []
	for prop: AmbienceProp in dressed.props + dressed.cache_props:
		all.append("%s %d %s %s %s" % [prop.name, prop.chamber, prop.rect, prop.flip, prop.decor])
	return all


## The rectangle a sprite of [param sheet] standing at [param feet] covers, as the world's props
## are stood.
func _stood(sheet: PixelSheet, feet: Vector2) -> Rect2:
	return Rect2(feet - Vector2(sheet.pivot) - Vector2(0, 1), Vector2(sheet.size))


## What stands in [param room] that no decoration may meet, by what it is, in world pixels.
func _in_the_way(
	level: LabyrinthLevel, view: LabyrinthView, dressed: AmbienceLevel, room: LabyrinthChamber
) -> Dictionary[String, Array]:
	var found: Dictionary[String, Array] = {
		"ladder": [],
		"doorway": [],
		"mouth": [],
		"gate": [],
		"cache": [],
		"quest": [],
		"prop": [],
		"flame": []
	}
	var rect: Rect2i = room.rect
	var pixels: Rect2 = room_pixels(room)
	var floor_px: float = rect.end.y * TILE
	var top: float = floor_px - MOST_ROWS * TILE
	for ladder: Rect2i in level.ladders + level.side_ladders():
		var in_columns: bool = ladder.position.x >= rect.position.x and ladder.end.x <= rect.end.x
		var leaves: bool = ladder.position.y - 1 == room.floor_row()
		var lands: bool = ladder.end.y - 1 == room.floor_row()
		if in_columns and (leaves or lands):
			found["ladder"].append(
				Rect2(ladder.position.x * TILE, top, ladder.size.x * TILE, floor_px - top)
			)
	for door: Rect2 in view.doorways(level.depth):
		if pixels.intersects(door):
			found["doorway"].append(Rect2(door.position.x, top, door.size.x, floor_px - top))
	var tunnels: Array[Rect2i] = level.tunnels.duplicate()
	for path: SidePath in level.side_paths:
		if path.tunnel.has_area():
			tunnels.append(path.tunnel)
		var gate: PixelSheet = SideProps.sheet_of(path.gate)
		if gate != null:
			var stood: Rect2 = _stood(gate, WorldPlaces.feet(path.course.point_at(path.gate_at)))
			if pixels.intersects(stood):
				found["gate"].append(stood)
		if path.room == room:
			var middle: float = floorf((rect.position.x + rect.end.x) / 2.0)
			found["cache"].append(
				_stood(SideProps.sheet_of(SideProps.CACHE), Vector2(middle * TILE, floor_px))
			)
	for tunnel: Rect2i in tunnels:
		var beside: int = -1
		if tunnel.end.y == rect.end.y and tunnel.position.x == rect.end.x:
			beside = rect.end.x - 1
		elif tunnel.end.y == rect.end.y and tunnel.end.x == rect.position.x:
			beside = rect.position.x
		if beside >= 0:
			var mouth_top: float = (tunnel.position.y - 1) * TILE
			found["mouth"].append(Rect2(beside * TILE, mouth_top, TILE, floor_px - mouth_top))
	if room.index >= 0:
		var middle: float = floorf((rect.position.x + rect.end.x) / 2.0)
		for path: String in QuestProps.SHEETS.values():
			found["quest"].append(
				_stood(PixelSheet.load_sheet(path), Vector2(middle * TILE, floor_px))
			)
	for prop: AmbienceProp in props_of(dressed, room, false):
		found["prop"].append(prop.rect)
	for torch: AmbienceProp in dressed.torches + dressed.cache_torches:
		if pixels.has_point(torch.light.position):
			var flame := Vector2i((torch.light.position / TILE).floor())
			found["flame"].append(Rect2((flame - Vector2i.ONE) * TILE, Vector2(3, 3) * TILE))
	return found


# --- R1 ------------------------------------------------------------------------


func test_r1_the_simulation_is_as_it_was() -> void:
	for seed_value: int in RECORDED_HASHES:
		var sim: Simulation = winding_simulation(seed_value)
		run_ticks(sim, ticks_in(300.0))
		assert_eq(
			sim.state_hash(),
			RECORDED_HASHES[seed_value],
			"seed %d: the state after 5 minutes hashes as it did" % seed_value
		)


# --- R2 ------------------------------------------------------------------------


func test_r2_every_decoration_is_a_row_of_the_table() -> void:
	var listed: Dictionary[StringName, bool] = {}
	for area: StringName in AREAS:
		var band: int = ZoneLook.of(area, 1).band
		var kinds: Array[StringName] = AmbienceDecor.kinds(band)
		assert_gt(kinds.size(), 2, "%s has a row of kinds" % area)
		var in_order: Array[StringName] = []
		for row: Array in AmbienceDecor.rows(AmbienceDecor.TABLE, band):
			var kind: StringName = row[AmbienceDecor.KIND]
			in_order.append(kind)
			listed[kind] = true
			var place: int = row[AmbienceDecor.PLACE]
			assert_between(place, 0, AmbienceDecor.Place.size() - 1, "%s goes somewhere" % kind)
			var often: int = row[AmbienceDecor.OFTEN]
			assert_gt(often, 0, "%s is chosen some of the time" % kind)
		assert_eq(kinds, in_order, "%s: kinds() is the table's rows, in order" % area)
		var placed: Array[int] = [0]
		each_room_of(
			area,
			20,
			func(
				what: String,
				_level: LabyrinthLevel,
				_view: LabyrinthView,
				dressed: AmbienceLevel,
				room: LabyrinthChamber
			) -> void:
				for prop: AmbienceProp in props_of(dressed, room, true):
					placed[0] += 1
					assert_has(kinds, prop.name, "%s: %s is a row of its area" % [what, prop.name])
				# And nothing else is there but what says the room's kind.
				for prop: AmbienceProp in props_of(dressed, room, false):
					assert_has(OWN, prop.name, "%s: %s says the room's kind" % [what, prop.name])
		)
		assert_gt(placed[0], 20, "%s: decorations were placed in 20 rooms" % area)
	for kind: StringName in OLD_KINDS:
		assert_true(listed.has(kind), "%s, once chosen in code, is a row" % kind)

	# A kind added to a copy of the table stands in rooms built from the copy, and only those.
	var table: Array[Dictionary] = AmbienceDecor.TABLE.duplicate(true)
	var rows: Array = table[0][AmbienceDecor.ROWS]
	rows.append([&"added_bones", AmbienceDecor.Place.FLOOR, 40, "bones", ["pile"]])
	var view: LabyrinthView = zoned_view(area_labyrinth(1, MOSSY), 1, MOSSY)
	var added: int = 0
	for prop: AmbienceProp in _dressed_from(view, 1, table).props:
		added += 1 if prop.name == &"added_bones" else 0
	assert_gt(added, 3, "the added kind stands in rooms built from the copy")
	for prop: AmbienceProp in _dressed_from(view, 1, AmbienceDecor.TABLE).props:
		assert_ne(prop.name, &"added_bones", "and in none built from the table")
	assert_does_not_have(AmbienceDecor.kinds(0), &"added_bones", "the table is as it was")


# --- R3 ------------------------------------------------------------------------


func test_r3_stalagmites_columns_and_groups() -> void:
	# The sheets: a part for each look of earth, as the stalactite has.
	var stalagmite: PixelSheet = PixelSheet.load_sheet(AmbienceLevel.DIR + "stalagmite.png")
	var column: PixelSheet = PixelSheet.load_sheet(AmbienceLevel.DIR + "column.png")
	for stratum: StringName in LabyrinthTiles.STRATA:
		for size: String in ["small", "mid", "tall"]:
			assert_true(stalagmite.has_part("%s_%s" % [stratum, size]), "%s %s" % [stratum, size])
		for rows: int in [4, 5]:
			for piece: String in ["top", "foot"]:
				var part: String = "%s_%d_%s" % [stratum, rows, piece]
				assert_true(column.has_part(part), "the column sheet has %s" % part)
	var heights: Dictionary[int, int] = {}
	var seen: Dictionary[String, int] = {"column": 0, "group": 0, "pair": 0, "alone": 0}
	var gaps: Dictionary[int, int] = {}
	each_dressed_stage(
		SEEDS,
		func(
			what: String,
			_area: StringName,
			level: LabyrinthLevel,
			view: LabyrinthView,
			dressed: AmbienceLevel
		) -> void:
			for room: LabyrinthChamber in stage_rooms(level):
				var floor_px: float = room.rect.end.y * TILE
				var hung: Dictionary[int, Array] = {}
				var stood: Dictionary[int, bool] = {}
				for prop: AmbienceProp in props_of(dressed, room, true):
					var at: int = column_of(prop)
					var where: String = "%s: the %s at %s" % [what, prop.name, prop.rect]
					match prop.name:
						&"stalagmite":
							assert_eq(prop.rect.end.y, floor_px, "%s stands on the floor" % where)
							var height: int = roundi(prop.rect.size.y)
							heights[height] = _n(heights, height) + 1
							stood[at] = true
						&"column":
							seen["column"] += 1
							var ceiling: int = open_top(view, room, at)
							var gap: int = room.rect.end.y - ceiling
							gaps[gap] = _n(gaps, gap) + 1
							assert_eq(
								prop.rect.position.y, ceiling * TILE - 2.0, "%s: its top" % where
							)
							assert_eq(prop.rect.end.y, floor_px, "%s: its bottom" % where)
							assert_between(gap, 4, 5, "%s: floor and ceiling are close" % where)
							assert_not_null(prop.foot, "%s has a foot" % where)
						&"stalactite":
							var ceiling: int = open_top(view, room, at)
							assert_eq(
								prop.rect.position.y, ceiling * TILE - 2.0, "%s hangs" % where
							)
							var lengths: Array = hung.get(at, [])
							lengths.append(roundi(prop.rect.size.y))
							hung[at] = lengths
				var under: Dictionary[int, bool] = {}
				for dip: Vector2i in _dips(view, room):
					var lengths: Dictionary[int, bool] = {}
					var count: int = 0
					for at: int in range(dip.x, dip.y + 1):
						under[at] = true
						var here: Array = hung.get(at, [])
						for length: int in here:
							lengths[length] = true
							count += 1
					if count == 0:
						continue
					seen["group"] += 1
					var where: String = "%s room %s dip %s" % [what, room.rect, dip]
					assert_between(count, 2, 4, "%s: stalactites in twos to fours" % where)
					assert_gt(lengths.size(), 1, "%s: of more than one length" % where)
				for at: int in hung:
					if under.has(at):
						continue
					seen["alone"] += 1
					seen["pair"] += 1 if stood.has(at) else 0
	)
	assert_eq(heights.keys().size(), 3, "stalagmites of three sizes: %s" % heights)
	for height: int in [8, 14, 22]:
		assert_gt(
			_n(heights, height), 0, "stalagmites %d pixels high stand: %s" % [height, heights]
		)
	assert_gt(seen["column"], 5, "columns stand")
	assert_gt(_n(gaps, 4), 0, "a column under a ceiling 4 rows over the floor")
	assert_gt(_n(gaps, 5), 0, "a column under a ceiling 5 rows over the floor")
	assert_gt(seen["group"], 10, "stalactites gather under dips")
	assert_gt(seen["alone"], 5, "and hang alone where there is none")
	assert_gt(seen["pair"], 2, "a stalactite and a stalagmite make a pair")


# --- R4 ------------------------------------------------------------------------


func test_r4_each_area_has_its_own() -> void:
	var shown: Dictionary[StringName, Dictionary] = {}
	var stalactites: Dictionary[StringName, int] = {}
	for area: StringName in AREAS:
		var kinds: Dictionary[StringName, int] = {}
		# What only one area is asked: sizes, spacing, clusters, what an alcove holds.
		var tally: Dictionary[String, int] = {}
		var alcoves: Dictionary[Texture2D, bool] = {}
		each_room_of(
			area,
			20,
			func(
				what: String,
				_level: LabyrinthLevel,
				view: LabyrinthView,
				dressed: AmbienceLevel,
				room: LabyrinthChamber
			) -> void:
				var pillars: Array[int] = []
				var crystals: Array[int] = []
				for prop: AmbienceProp in props_of(dressed, room, true):
					kinds[prop.name] = _n(kinds, prop.name) + 1
					var height: int = roundi(prop.rect.size.y)
					match prop.name:
						&"stalagmite":
							tally["tallest"] = maxi(_n(tally, "tallest"), height)
							tally["shortest"] = mini(_n(tally, "shortest", 99), height)
						&"pillar":
							pillars.append(column_of(prop))
							var top: float = open_top(view, room, column_of(prop)) * TILE - 2.0
							assert_eq(prop.rect.position.y, top, "%s: a pillar's top" % what)
							assert_eq(
								prop.rect.end.y,
								float(room.rect.end.y * TILE),
								"%s: its foot" % what
							)
						&"alcove":
							alcoves[prop.texture] = true
							assert_null(prop.light, "%s: an alcove gives no light" % what)
							assert_null(prop.glowing(), "%s: and does not glow" % what)
						&"crystal":
							crystals.append(column_of(prop))
				if not pillars.is_empty():
					tally["pillared"] = _n(tally, "pillared") + 1
					assert_gte(room.rect.size.x, 14, "%s: pillars in a room 14 wide or more" % what)
					assert_gt(pillars.size(), 1, "%s: pillars stand in a row" % what)
					pillars.sort()
					for i: int in range(2, pillars.size()):
						assert_eq(
							pillars[i] - pillars[i - 1],
							pillars[1] - pillars[0],
							"%s: pillars at even spacing %s" % [what, pillars]
						)
				crystals.sort()
				for i: int in crystals.size():
					var beside: bool = (
						crystals.has(crystals[i] - 1) or crystals.has(crystals[i] + 1)
					)
					var key: String = "clustered" if beside else "single"
					tally[key] = _n(tally, key) + 1
		)
		shown[area] = kinds
		stalactites[area] = _n(kinds, &"stalactite")
		gut.p("%s in 20 rooms: %s %s" % [area, kinds, tally])
		for kind: StringName in SHOWN[area]:
			assert_gt(_n(kinds, kind), 0, "%s shows %s" % [area, kind])
		for kind: StringName in NEVER[area]:
			assert_eq(_n(kinds, kind), 0, "%s shows no %s" % [area, kind])
		match area:
			CLAY:
				assert_lte(_n(tally, "tallest"), 8, "the Claypits' stalagmites are squat")
			CRYPT:
				assert_gt(_n(tally, "pillared"), 2, "the Old Crypt has pillared rooms")
				assert_eq(alcoves.size(), 2, "its alcoves hold a skull or a candle stub")
			EMBER:
				assert_gte(_n(tally, "shortest"), 14, "the Ember Deep's stalagmites are tall")
				assert_gt(_n(tally, "single"), 0, "its crystals stand singly")
				assert_gt(_n(tally, "clustered"), 1, "and in clusters")
	assert_lt(
		_n(shown[CLAY], &"stalagmite"),
		_n(shown[MOSSY], &"stalagmite"),
		"the Claypits have a few stalagmites, fewer than Mossy Hollow"
	)
	for area: StringName in AREAS:
		if area != EMBER:
			assert_gt(
				stalactites[EMBER],
				stalactites[area],
				"the Ember Deep has more stalactites than %s" % area
			)
		var own: Array[StringName] = []
		for kind: StringName in shown[area]:
			var elsewhere: bool = false
			for other: StringName in AREAS:
				elsewhere = elsewhere or (other != area and shown[other].has(kind))
			if not elsewhere:
				own.append(kind)
		assert_gte(own.size(), 2, "%s shows two kinds no other area shows: %s" % [area, own])


# --- R5 ------------------------------------------------------------------------


func test_r5_nothing_is_in_the_way() -> void:
	var checked: Dictionary[String, int] = {}
	var small: Dictionary[String, int] = {"rooms": 0, "tall": 0}
	each_dressed_stage(
		SEEDS,
		func(
			what: String,
			_area: StringName,
			level: LabyrinthLevel,
			view: LabyrinthView,
			dressed: AmbienceLevel
		) -> void:
			var wrong: Array[String] = []
			var glowing: int = 0
			var lit_own: int = 0
			for room: LabyrinthChamber in stage_rooms(level):
				var pixels: Rect2 = room_pixels(room)
				var in_the_way: Dictionary[String, Array] = _in_the_way(level, view, dressed, room)
				var third := Rect2(
					pixels.position.x + pixels.size.x / 3.0,
					pixels.end.y - MOST_ROWS * TILE,
					pixels.size.x / 3.0,
					MOST_ROWS * TILE
				)
				small["rooms"] += 1 if room.rect.size.x <= 12 else 0
				for prop: AmbienceProp in props_of(dressed, room, false):
					lit_own += 1 if prop.light != null else 0
				for prop: AmbienceProp in props_of(dressed, room, true):
					var where: String = "the %s at %s" % [prop.name, prop.rect]
					glowing += 1 if not prop.frames.is_empty() else 0
					if prop.rect.position.x < pixels.position.x or prop.rect.end.x > pixels.end.x:
						wrong.append("%s is outside its room's walls" % where)
					for kind: String in in_the_way:
						for kept: Rect2 in in_the_way[kind]:
							checked[kind] = _n(checked, kind) + 1
							if kept.intersects(prop.rect):
								wrong.append("%s meets a %s at %s" % [where, kind, kept])
					# What sinks into the ragged ceiling or the floor's crust is not counted.
					var body: Rect2 = prop.rect
					if prop.anchor == AmbienceProp.Anchor.CEILING:
						body = body.grow_side(SIDE_TOP, -2.0)
					elif prop.name == &"puddle":
						body = body.grow_side(SIDE_BOTTOM, -2.0)
					for y: int in range(floori(body.position.y / TILE), ceili(body.end.y / TILE)):
						for x: int in range(
							floori(body.position.x / TILE), ceili(body.end.x / TILE)
						):
							if not view.is_open(Vector2i(x, y)):
								wrong.append("%s has a part in earth at (%d, %d)" % [where, x, y])
					var on_floor: bool = prop.rect.end.y >= pixels.end.y
					if room.rect.size.x <= 12 and on_floor and prop.rect.size.y > 12.0:
						small["tall"] += 1
						if third.intersects(prop.rect):
							wrong.append("%s is tall, in the middle of a small room" % where)
					if NEW_KINDS.has(prop.name) and (prop.light != null or prop.glowing() != null):
						wrong.append("%s gives light" % where)
			assert_eq(wrong, [] as Array[String], "%s: nothing is in the way" % what)
			# The lights are the torches', the rooms' own, and at most two glowing things'.
			assert_eq(
				dressed.lights.size(),
				(
					dressed.torches.size()
					+ dressed.cache_torches.size()
					+ lit_own
					+ mini(glowing, AmbienceLevel.MAX_GLOW_LIGHTS)
				),
				"%s: as many lights as without the new kinds" % what
			)
	)
	for kind: String in ["ladder", "doorway", "mouth", "gate", "cache", "quest", "prop", "flame"]:
		assert_gt(_n(checked, kind), 20, "decorations were checked against a %s" % kind)
	assert_gt(small["rooms"], 20, "small rooms were looked at")
	assert_gt(small["tall"], 5, "tall things stand in small rooms, at their sides")


# --- R6 ------------------------------------------------------------------------


func test_r6_dressed_to_size_and_its_own() -> void:
	var pairs: Array[int] = [0, 0]
	# Decorations and columns: of the route's rooms, then of the cache rooms.
	var filled: Array[int] = [0, 0, 0, 0]
	each_dressed_stage(
		SEEDS,
		func(
			what: String,
			area: StringName,
			level: LabyrinthLevel,
			view: LabyrinthView,
			dressed: AmbienceLevel
		) -> void:
			var before: Array[StringName] = []
			for room: LabyrinthChamber in stage_rooms(level):
				var names: Array[StringName] = names_of(props_of(dressed, room, true))
				var where: String = "%s room %s %s" % [what, room.rect, names]
				assert_between(
					names.size(), 1, room.rect.size.x / 2, "%s: dressed to its size" % where
				)
				var cache: int = 2 if room.index < 0 else 0
				filled[cache] += names.size()
				filled[cache + 1] += room.rect.size.x
				if room.index > 0:
					pairs[0] += 1
					pairs[1] += 1 if names == before else 0
				before = names
			# Built again, by a second view of a second labyrinth of the same seed.
			var seed_value: int = int(what.get_slice(" ", 2))
			var again: LabyrinthView = zoned_view(
				area_labyrinth(seed_value, area), level.depth, area
			)
			assert_eq(
				_listing(dressed_stage(again, level.depth)),
				_listing(dressed),
				"%s: dressed the same every time it is built" % what
			)
			again.free()
			# The budgets hold through half a minute of motion.
			var cap: int = (
				AmbienceLevel.MAX_MOTES * view.labyrinth.band_height() / Labyrinth.LEVEL_HEIGHT
			)
			var most: int = 0
			for i: int in 300:
				dressed.advance(0.1)
				most = maxi(most, dressed.motes.size())
			assert_lte(most, cap, "%s: the motes keep to their budget" % what)
			var glows: int = 0
			for light: AmbienceLight in dressed.lights:
				glows += 1 if light.kind == &"glow" else 0
			assert_lte(glows, AmbienceLevel.MAX_GLOW_LIGHTS, "%s: the glowing lights too" % what)
	)
	gut.p("%d of %d neighbours are dressed alike; filled %s" % [pairs[1], pairs[0], filled])
	assert_gt(pairs[0], 100, "neighbouring rooms were compared")
	assert_lte(pairs[1] * 10, pairs[0], "neighbours are dressed alike at most 1 time in 10")
	assert_gt(filled[3], 0, "cache rooms were looked at")
	assert_lt(
		float(filled[2]) / filled[3],
		float(filled[0]) / filled[1],
		"cache rooms are dressed more sparsely than the route's rooms"
	)

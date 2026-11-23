class_name AmbienceDecor
extends RefCounted
## What each area's rooms are dressed with: the table, and a room's list drawn from it.
##
## [constant TABLE] has an entry for each look of earth, so for each area, in
## [constant LabyrinthTiles.STRATA] order: how full its rooms are, and a row for each kind of
## decoration it holds. A new kind in an area is a new row; [AmbienceDresser] stands whatever the
## rows say, and nothing else decides what a room holds beyond its torches and the props that
## say what kind of room it is ([AmbienceRoomProps]).

## Where a decoration goes: on the floor, hanging from the ceiling of its column, from the floor
## to the ceiling of its column, or set in the back wall at a torch's height.
enum Place { FLOOR, CEILING, SPAN, BACK }

## The fields of a row, in order: the kind's name; its [enum Place]; how often it is chosen,
## against the other rows of its area; the sheet it is drawn from; the parts it may be, one
## chosen for each (a [code]*[/code] stands for the area's stratum); and, for some, a dictionary
## of what more holds for it (see the names below).
const KIND: int = 0
const PLACE: int = 1
const OFTEN: int = 2
const SHEET: int = 3
const PARTS: int = 4
const MORE: int = 5

## A dictionary entry of an area: the least and the most of a room's columns, in a hundred, that
## hold a decoration; and its rows.
const FILL: StringName = &"fill"
const ROWS: StringName = &"rows"

## More about a row. SINK: pixels its foot sinks into the floor's crust. GLOW: it shines on its
## own, in these palette colours, one for each of its parts. GATHER: under a dip of the ceiling it
## hangs in a group of this many (least, most), each of another part. CLUSTER: this many (least,
## most) stand in neighbouring columns. PAIR: the kind that may stand in its column with it, one
## on the floor and one on the ceiling. GAP: it fits only where its column's ceiling is this many
## rows (least, most) over the floor, its parts one for each such height. COLONNADE: it stands
## in a row at even spacing, in rooms at least this many columns wide. CORNER: it hangs only in
## a wall's column, its first part at the left wall and its second at the right.
const SINK: StringName = &"sink"
const GLOW: StringName = &"glow"
const GATHER: StringName = &"gather"
const CLUSTER: StringName = &"cluster"
const PAIR: StringName = &"pair"
const GAP: StringName = &"gap"
const COLONNADE: StringName = &"colonnade"
const CORNER: StringName = &"corner"

## The share of an area's fill a side path's cache room has.
const CACHE_FILL: float = 0.5
## Columns of a room for each decoration it may hold at most.
const COLUMNS_EACH: int = 2
## The chance in a hundred that a kind with a PAIR gets its other half, and that where the
## ceiling allows a kind with a GAP stands there in place of the two.
const PAIR_PERCENT: int = 40
const JOIN_PERCENT: int = 60

const TABLE: Array[Dictionary] = [
	# Mossy Hollow: roots through the ceiling, mushrooms, dripstone and puddles.
	{
		FILL: Vector2i(25, 45),
		ROWS:
		[
			[&"roots", Place.CEILING, 5, "roots", ["long", "short", "fork"]],
			[&"mushroom", Place.FLOOR, 4, "mushroom", ["brown", "red"]],
			[
				&"stalactite",
				Place.CEILING,
				3,
				"stalactite",
				["*", "*_mid", "*_short"],
				{GATHER: Vector2i(2, 4), PAIR: &"stalagmite"}
			],
			[
				&"stalagmite",
				Place.FLOOR,
				3,
				"stalagmite",
				["*_small", "*_mid", "*_tall"],
				{PAIR: &"stalactite"}
			],
			[&"puddle", Place.FLOOR, 2, "puddle", ["water"], {SINK: 2}],
			[&"column", Place.SPAN, 1, "column", ["*_4", "*_5"], {GAP: Vector2i(4, 5)}],
		],
	},
	# Claypits: urns, pots and crates left by whoever dug here, a few squat stalagmites, and a
	# column under a ledge.
	{
		FILL: Vector2i(20, 40),
		ROWS:
		[
			[&"urn", Place.FLOOR, 4, "urn", ["urn"]],
			[&"pot", Place.FLOOR, 4, "urn", ["pot"]],
			[&"crate", Place.FLOOR, 3, "crate", ["broken"]],
			[&"puddle", Place.FLOOR, 2, "puddle", ["water"], {SINK: 2}],
			[&"stalagmite", Place.FLOOR, 1, "stalagmite", ["*_small"]],
			[&"column", Place.SPAN, 2, "column", ["*_4", "*_5"], {GAP: Vector2i(4, 5)}],
		],
	},
	# Old Crypt, built: pillars in rows, alcoves in the back wall, webs in the corners.
	{
		FILL: Vector2i(15, 35),
		ROWS:
		[
			[&"pillar", Place.SPAN, 6, "crypt", ["pillar"], {COLONNADE: 14}],
			[&"alcove", Place.BACK, 5, "crypt", ["alcove_skull", "alcove_candle"]],
			[&"web", Place.CEILING, 2, "web", ["left", "right"], {CORNER: true}],		],
	},
	# Ember Deep: crystals and glowing mushrooms, tall dripstone, the most stalactites.
	{
		FILL: Vector2i(30, 50),
		ROWS:
		[
			[
				&"stalactite",
				Place.CEILING,
				6,
				"stalactite",
				["*", "*_mid", "*_short"],
				{GATHER: Vector2i(2, 4), PAIR: &"stalagmite"}
			],
			[
				&"crystal",
				Place.FLOOR,
				4,
				"crystal",
				["cyan", "cyan", "orchid"],
				{GLOW: [&"cyan", &"cyan", &"orchid"], CLUSTER: Vector2i(1, 3)}
			],
			[
				&"glow_mushroom",
				Place.FLOOR,
				3,
				"mushroom",
				["glow_cyan", "glow_cyan", "glow_green"],
				{GLOW: [&"cyan", &"cyan", &"green"]}
			],
			[
				&"stalagmite",
				Place.FLOOR,
				3,
				"stalagmite",
				["*_mid", "*_tall"],
				{PAIR: &"stalactite"}
			],
			[&"column", Place.SPAN, 2, "column", ["*_4", "*_5"], {GAP: Vector2i(4, 5)}],
		],
	},
]


## The kinds of decoration of the look at [param band], in the table's order.
static func kinds(band: int) -> Array[StringName]:
	var found: Array[StringName] = []
	for row: Array in rows(TABLE, band):
		var kind: StringName = row[KIND]
		found.append(kind)
	return found


## The rows of the look at [param band] in [param table] (the table, or a copy of it).
static func rows(table: Array[Dictionary], band: int) -> Array:
	if band < 0 or band >= table.size():
		return []
	var found: Array = table[band].get(ROWS, [])
	return found


## The row of [param kind] among [param of_area] (an area's rows), or an empty one.
static func row_of(of_area: Array, kind: StringName) -> Array:
	for row: Array in of_area:
		var named: StringName = row[KIND]
		if named == kind:
			return row
	return []


## What more holds for [param row]: its dictionary, or an empty one.
static func more(row: Array) -> Dictionary:
	if row.size() <= MORE:
		return {}
	var found: Dictionary = row[MORE]
	return found


## The part of [param row] at place [param index] (wrapped) for the look at [param band].
static func part(row: Array, index: int, band: int) -> String:
	var parts: Array = row[PARTS]
	var named: String = parts[posmod(index, parts.size())]
	return named.replace("*", LabyrinthTiles.STRATA[band])


## The most decorations a room [param columns] wide may hold.
static func most(columns: int) -> int:
	return maxi(columns / COLUMNS_EACH, 1)


## How many decorations a room [param columns] wide of the look at [param band] holds, by
## [param roll] (a number of its own): at least one, at most [method most], fewer in a side
## path's cache room ([param sparse]).
static func amount(
	table: Array[Dictionary], band: int, columns: int, sparse: bool, roll: int
) -> int:
	var fill: Vector2i = Vector2i(25, 45)
	if band >= 0 and band < table.size():
		fill = table[band].get(FILL, fill)
	var share: float = fill.x + roll % (fill.y - fill.x + 1)
	if sparse:
		share *= CACHE_FILL
	return clampi(roundi(columns * share / 100.0), 1, most(columns))


## One of [param of_area] (an area's rows) by [param roll], each as often as its row says.
static func pick(of_area: Array, roll: int) -> Array:
	var total: int = 0
	for row: Array in of_area:
		var often: int = row[OFTEN]
		total += often
	if total <= 0:
		return []
	var at: int = roll % total
	for row: Array in of_area:
		var often: int = row[OFTEN]
		at -= often
		if at < 0:
			return row
	return []

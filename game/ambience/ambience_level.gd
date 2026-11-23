class_name AmbienceLevel
extends Node2D
## The decoration of one built level: torches on the chambers' back walls, props that
## say what kind each chamber is, things buried in the earth, and the small motion around them
## (dust, embers, drips, critters, glints).
##
## Everything is placed from the level's layout and tile positions, never from a clock, so
## rebuilding a level places the same things in the same places. Motion is stepped in
## [method advance] from a random stream seeded by the level. Each chamber is dressed on its own
## floor and ceiling, so the rooms of a winding stage are, floor by floor.
##
## This node draws what is lit like the world (under the darkness, see [Ambience]); its child
## Buried draws the things in the earth, behind it and only when the level is built, as they never
## move; its child Glow draws what shines on its own (flames, embers, glints, glowing props) over
## the darkness. A torch or a campfire that is not lit ([member AmbienceProp.lit], which
## [AmbienceRooms] sets) is drawn cold: no flame, no embers.

const DIR: String = "res://assets/sprites/ambience/"
const TILE: int = LabyrinthView.TILE
## Nodes a level adds to the tree: itself, its Buried and its Glow.
const NODES: int = 3
## Glow is drawn over the darkness, which is drawn at [constant Ambience.DARKNESS_Z].
const GLOW_Z: int = 101

# Torches.
## One torch per this many tiles of chamber width, so one per 6 to 8 tiles, and at least one.
const TORCH_SPACING: float = 7.0
## The torch's tile is this many rows above the floor row, so its bracket ends a tile above the
## floor and its flame is just over the heads of the party.
const TORCH_ROWS_ABOVE_FLOOR: int = 2
## Where the flame's centre is in the torch's 16x16 canvas.
const FLAME_CENTRE: Vector2 = Vector2(8, 5)
const TORCH_RADIUS: float = 76.0
const TORCH_ENERGY: float = 0.8
## How much a torch's strength wavers (a fraction of it).
const TORCH_FLICKER: float = 0.12
## Flame frames a second.
const FLAME_RATE: float = 8.0

# Lights of chamber props.
const CAMPFIRE_RADIUS: float = 120.0
const CAMPFIRE_ENERGY: float = 0.9
const CAMPFIRE_FLICKER: float = 0.2
const GLEAM_RADIUS: float = 44.0
const GLEAM_ENERGY: float = 0.55
const GLEAM_FLICKER: float = 0.25
const GLOW_RADIUS: float = 40.0
const GLOW_ENERGY: float = 0.5
## Glowing props past this many on a level still glow, but cast no light, to keep the
## lights in view few.
const MAX_GLOW_LIGHTS: int = 2
## What a cache room's rolls are salted with, by its side path's place: past any chamber's index.
const CACHE_SALT: int = 16

# Buried details.
## The earth is cut into cells this many tiles wide and tall, and each holds at most one buried
## thing, so they are spread evenly: about one per 40 buried tiles, and between one per 30 and
## one per 60.
const DETAIL_CELL: Vector2i = Vector2i(10, 8)
## Tries at finding a buried tile in a cell before leaving it empty.
const DETAIL_TRIES: int = 8
## At depth 1, roots grow in this many rows under the surface.
const ROOT_ROWS: int = 5
## What each stratum holds, in [constant LabyrinthTiles.STRATA] order; repeats weigh more.
const BURIED_KINDS: Array = [
	[&"stone_0", &"stone_1", &"stone_0", &"bone", &"worm", &"ore_copper", &"stone_1"],
	[&"stone_0", &"stone_1", &"bone", &"shell", &"skull", &"ore_copper", &"ore_iron"],
	[&"stone_0", &"stone_1", &"fish", &"shell", &"skull", &"ore_iron", &"ore_gold"],
	[&"stone_1", &"fish", &"skull", &"crystal_ore", &"gem", &"ore_gold", &"crystal_ore"],
]
const ROOTS: Array[StringName] = [&"root_0", &"root_1"]
## Buried things that glint now and then.
const ORES: Array[StringName] = [&"ore_copper", &"ore_iron", &"ore_gold", &"crystal_ore", &"gem"]

# Motion.
## Motes alive at most on one level of [constant Labyrinth.LEVEL_HEIGHT] rows, so five built
## levels keep under 600 motes; a taller stage, built alone, has as many more as it is taller.
const MAX_MOTES: int = 120
const DUST_PER_TORCH: int = 4
## How far from its torch a dust mote drifts, in pixels, and how fast.
const DUST_RANGE: Vector2 = Vector2(46, 28)
const DUST_SPEED: float = 3.0
const DUST_LIFE: Vector2 = Vector2(3.0, 7.0)
## Pixels a dust home keeps under a ceiling: more than a mote may stray from its home.
const DUST_CLEAR: float = 5.0
## Seconds between embers from one torch, how long one lives and how fast it rises.
const EMBER_EVERY: Vector2 = Vector2(0.8, 3.2)
const CAMPFIRE_EMBER_EVERY: Vector2 = Vector2(0.15, 0.6)
const EMBER_LIFE: Vector2 = Vector2(0.7, 1.4)
const EMBER_RISE: Vector2 = Vector2(14.0, 26.0)
## Seconds between drips from one spot, how long a drop swells before it falls, how fast things
## fall, and the splash.
const DRIP_EVERY: Vector2 = Vector2(2.5, 6.0)
const DRIP_SWELL: float = 0.8
const GRAVITY: float = 320.0
const SPLASH_DROPS: int = 3
const SPLASH_LIFE: float = 0.35
## Seconds before the first critter and between critters, and how many can be about at once.
const CRITTER_FIRST: Vector2 = Vector2(0.5, 3.0)
const CRITTER_EVERY: Vector2 = Vector2(4.0, 10.0)
const MAX_CRITTERS: int = 2
const BEETLE_SPEED: float = 9.0
const MOTH_LIFE: Vector2 = Vector2(6.0, 10.0)
## The moth's circle round its torch: half its width and height, in pixels, and its speed.
const MOTH_ORBIT: Vector2 = Vector2(11, 6)
const MOTH_SPEED: float = 2.8
## Seconds between glints on buried ore, and on a vault's gold.
const GLINT_EVERY: Vector2 = Vector2(0.6, 2.0)
const GLEAM_EVERY: Vector2 = Vector2(0.3, 0.9)
const GLINT_LIFE: float = 0.45

## The depth this level decorates.
var depth: int
## Torches, left to right.
var torches: Array[AmbienceProp] = []
## Chamber props (the campfire, webs, chests, stalactites...).
var props: Array[AmbienceProp] = []
## The same for the cache rooms of the level's side paths, which are no chamber of its route:
## each one's torch, and its props.
var cache_torches: Array[AmbienceProp] = []
var cache_props: Array[AmbienceProp] = []
## Buried things by world tile.
var details: Dictionary[Vector2i, StringName] = {}
## Everything small that moves.
var motes: Array[AmbienceMote] = []
## The lights of this level's torches and props.
var lights: Array[AmbienceLight] = []
## How much light reaches each tile of the band (one pixel per tile, red channel): all of it in
## open space, less in the earth (see [constant AmbienceMood.EDGE_EXPOSURE]).
var exposure: Image
## How many times the buried things have been drawn (for tests).
var buried_draws: int = 0

var _seed: int
## The band's open tiles, its first world row and how many rows it has.
var _map: AmbienceOpenMap
## The level's rooms as drawn, or null where each is drawn as its rectangle.
var _shapes: StageShapes
var _top: int
var _rows: int
var _band: int
## The floor line, in world pixels, of the chamber being dressed.
var _floor_px: float
var _mote_cap: int = MAX_MOTES
var _rng := RandomNumberGenerator.new()
var _glow: Node2D
var _buried: Node2D
var _time: float = 0.0
## Of the chamber being dressed: the columns kept clear for a ladder or a doorway, and those of
## them where its floor is whole (see [AmbienceClearings]).
var _shaft_columns: Dictionary[int, bool] = {}
var _incoming_columns: Dictionary[int, bool] = {}
## Dust homes: per torch, the open rectangle its chamber gives it.
var _rooms: Array[Rect2] = []
## Things that throw embers (torches and the campfire), and seconds to the next ember of each.
var _emitters: Array[AmbienceProp] = []
var _ember_timers: PackedFloat32Array = []
## Where drips fall from, the floor line each falls to and how often, and seconds to the next
## drip of each.
var _drip_from: PackedVector2Array = []
var _drip_floors: PackedFloat32Array = []
var _drip_every: PackedFloat32Array = []
var _drip_timers: PackedFloat32Array = []
## Floor spans a beetle can cross, as (from x, to x) in world pixels, and each one's floor line.
var _spans: PackedVector2Array = []
var _span_floors: PackedFloat32Array = []
var _ores: Array[Vector2i] = []
var _gleams: Array[AmbienceProp] = []
var _critter_timer: float
var _glint_timer: float
var _gleam_timer: float
## Every torch and every prop, the route's and the cache rooms': what is lit, moved and drawn.
var _all_torches: Array[AmbienceProp] = []
var _all_props: Array[AmbienceProp] = []


## Places the decoration of [param level_depth] as the [param view] draws it.
func build(view: LabyrinthView, level_depth: int) -> void:
	depth = level_depth
	name = "Depth%d" % depth
	var level: LabyrinthLevel = view.labyrinth.level(depth)
	_seed = level_seed(level)
	_rng.seed = _seed
	_band = view.band_of(depth)
	_map = AmbienceOpenMap.new(view, depth)
	_shapes = view.shapes(depth)
	exposure = _map.exposure
	_top = _map.top()
	_rows = _map.rows()
	_mote_cap = MAX_MOTES * _rows / Labyrinth.LEVEL_HEIGHT
	var clearings := AmbienceClearings.new(view, depth)
	var own := AmbienceRoomProps.new()
	for chamber: LabyrinthChamber in level.chambers:
		_floor_px = (chamber.floor_row() + 1) * TILE
		_shaft_columns = clearings.columns(chamber.index)
		_incoming_columns = clearings.closed_columns(chamber.index)
		_place_torches(chamber)
		own.place(_room(chamber))
		_place_drips(chamber)
		_place_span(chamber)
	var route_torches: Array[AmbienceProp] = torches
	var route_props: Array[AmbienceProp] = props
	torches = cache_torches
	props = cache_props
	for place: int in level.side_paths.size():
		# A cache room: one torch, and the floor details of a plain room.
		var room: LabyrinthChamber = level.side_paths[place].room
		_floor_px = (room.floor_row() + 1) * TILE
		_shaft_columns = clearings.cache_columns(place)
		_incoming_columns = clearings.cache_closed_columns(place)
		_place_torches(room, 1)
		own.place(_room(room), (CACHE_SALT + place) * 101)
	torches = route_torches
	props = route_props
	_all_torches = torches + cache_torches
	_all_props = props + cache_props
	_place_details()
	for torch: AmbienceProp in _all_torches:
		lights.append(torch.light)
	for prop: AmbienceProp in _all_props:
		if prop.light != null:
			lights.append(prop.light)
	for emitter: int in _emitters.size():
		_ember_timers.append(_rng.randf_range(0.0, EMBER_EVERY.y))
	for room: int in _rooms.size():
		for i: int in DUST_PER_TORCH:
			var dust: AmbienceMote = _new_dust(room)
			dust.age = _rng.randf_range(0.0, dust.life * 0.8)
	_critter_timer = _rng.randf_range(CRITTER_FIRST.x, CRITTER_FIRST.y)
	_glint_timer = _rng.randf_range(GLINT_EVERY.x, GLINT_EVERY.y)
	_gleam_timer = _rng.randf_range(GLEAM_EVERY.x, GLEAM_EVERY.y)

	_buried = Node2D.new()
	_buried.name = "Buried"
	_buried.show_behind_parent = true
	_buried.draw.connect(_draw_buried)
	add_child(_buried)
	_glow = Node2D.new()
	_glow.name = "Glow"
	_glow.z_index = GLOW_Z
	_glow.z_as_relative = false
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## Steps the flames, flicker and motion by [param delta] seconds.
func advance(delta: float) -> void:
	_time += delta
	for prop: AmbienceProp in _all_torches:
		prop.advance(_time)
	for prop: AmbienceProp in _all_props:
		prop.advance(_time)
	for light: AmbienceLight in lights:
		light.advance(_time)
	_move_motes(delta)
	_spawn_embers(delta)
	_spawn_drips(delta)
	_spawn_critters(delta)
	_spawn_glints(delta)
	queue_redraw()
	_glow.queue_redraw()


## A seed for a level, from its layout: the same labyrinth seed and depth always give the same.
static func level_seed(level: LabyrinthLevel) -> int:
	var h: int = mix(level.depth, level.floor_y)
	for chamber: LabyrinthChamber in level.chambers:
		h = mix(h, chamber.rect.position.x * 4099 + chamber.rect.size.x * 31 + chamber.rect.size.y)
		h = mix(h, chamber.kind)
	return mix(h, level.shaft_down.position.x)


## A well-mixed, non-negative hash of two numbers.
static func mix(a: int, b: int) -> int:
	var h: int = a * 0x2545F491 + b * 0x9E3779B1 + 0x632BE5AB
	h = (h ^ (h >> 15)) * 0x2C1B3C6D
	h = (h ^ (h >> 12)) * 0x297A2D39
	return (h ^ (h >> 15)) & 0x7FFFFFFF


static func _sheet(sheet_name: String) -> PixelSheet:
	return PixelSheet.load_sheet(DIR + sheet_name + ".png")


static func _part(sheet_name: String, part_name: String) -> AtlasTexture:
	return _sheet(sheet_name).part(StringName(part_name))


## Whether [param x] or a column next to it is in [param columns].
static func _near(columns: Dictionary[int, bool], x: int) -> bool:
	return columns.has(x - 1) or columns.has(x) or columns.has(x + 1)


## [param chamber] as its props see it: the room being dressed, with the lists they join.
func _room(chamber: LabyrinthChamber) -> AmbienceRoom:
	var room := AmbienceRoom.new(chamber, _band, _seed, _shapes, _map)
	room.clear = _shaft_columns
	room.closed = _incoming_columns
	room.torches = torches
	room.props = props
	room.emitters = _emitters
	room.gleams = _gleams
	return room


## A number from this level's seed, [param salt] and a position: the same every build.
func _roll(salt: int, a: int, b: int = 0) -> int:
	return mix(mix(mix(_seed, salt), a), b)


# -------------------------------------------------------------------- torches


## The torches of [param chamber]: one per TORCH_SPACING tiles, or [param most] if that is fewer
## (0: no limit).
func _place_torches(chamber: LabyrinthChamber, most: int = 0) -> void:
	var rect: Rect2i = chamber.rect
	var count: int = maxi(1, roundi(rect.size.x / TORCH_SPACING))
	if most > 0:
		count = mini(count, most)
	var row: int = rect.end.y - 1 - TORCH_ROWS_ABOVE_FLOOR
	var used: Dictionary[int, bool] = {}
	for i: int in count:
		var column: int = rect.position.x + floori((i + 0.5) * rect.size.x / count)
		column = _clear_of_ladder(column, rect, used)
		if column < 0:
			continue
		used[column] = true
		var torch := AmbienceProp.new(
			&"torch",
			chamber.index,
			Rect2(column * TILE, row * TILE, TILE, TILE),
			AmbienceProp.Anchor.WALL
		)
		torch.texture = _part("torch", "bracket")
		torch.unlit = _part("torch", "unlit")
		torch.flame = true
		for frame: int in 4:
			# The deep stratum's torches burn with an eerie teal flame.
			var flame: String = "teal_%d" if _band == 3 else "flame_%d"
			torch.frames.append(_part("torch", flame % frame))
		torch.frame_rate = FLAME_RATE
		torch.phase = (_roll(1, column) % 1000) / 1000.0
		torch.light = AmbienceLight.new(
			&"torch",
			torch.rect.position + FLAME_CENTRE,
			TORCH_RADIUS,
			TORCH_ENERGY,
			AmbienceMood.band_tint(_band),
			TORCH_FLICKER,
			_roll(2, column)
		)
		torches.append(torch)
		_emitters.append(torch)
		var room := Rect2(rect.position * TILE, rect.size * TILE).grow(-3)
		var home: Rect2 = room.intersection(
			Rect2(torch.light.position - DUST_RANGE, DUST_RANGE * 2)
		)
		_rooms.append(_under_ceiling(chamber, home))


## [param column] or the nearest column inside the chamber's walls that is not on or next to a
## ladder and not already taken; -1 if there is none.
func _clear_of_ladder(column: int, rect: Rect2i, used: Dictionary[int, bool]) -> int:
	for offset: int in rect.size.x:
		for candidate: int in [column + offset, column - offset]:
			if candidate < rect.position.x + 1 or candidate > rect.end.x - 2:
				continue
			if used.has(candidate):
				continue
			if _near(_shaft_columns, candidate):
				continue
			return candidate
	return -1


# ------------------------------------------------------------- buried things


func _place_details() -> void:
	var top: int = _top
	var kinds: Array = BURIED_KINDS[_band]
	for cell_y: int in range(0, _rows, DETAIL_CELL.y):
		for cell_x: int in range(0, Labyrinth.LEVEL_WIDTH, DETAIL_CELL.x):
			for attempt: int in DETAIL_TRIES:
				var roll: int = _roll(20 + attempt, cell_x, cell_y)
				var tile := Vector2i(
					cell_x + roll % DETAIL_CELL.x, top + cell_y + (roll >> 8) % DETAIL_CELL.y
				)
				if tile.x >= Labyrinth.LEVEL_WIDTH or not _map.is_buried(tile):
					continue
				var kind: StringName = kinds[(roll >> 16) % kinds.size()]
				if depth == 1 and tile.y < ROOT_ROWS and (roll >> 20) % 4 != 0:
					kind = ROOTS[(roll >> 24) % ROOTS.size()]
				details[tile] = kind
				if ORES.has(kind):
					_ores.append(tile)
				break


## How much light reaches a world tile of this band: 1 in open space, less in the earth.
func exposure_at(tile: Vector2i) -> float:
	return _map.exposure_at(tile)


## Where drips fall from, in world pixels.
func drip_points() -> PackedVector2Array:
	return _drip_from


## The ceiling line, in world pixels, over [param column] of [param chamber] as it is drawn.
func _ceiling_px(chamber: LabyrinthChamber, column: int) -> float:
	if _shapes == null:
		return chamber.rect.position.y * TILE
	return _shapes.shape_of(chamber).ceiling_row(column) * TILE


## [param home], a dust home in [param chamber], kept under the lowest ceiling over its columns.
func _under_ceiling(chamber: LabyrinthChamber, home: Rect2) -> Rect2:
	var lowest: float = home.position.y
	for column: int in range(floori(home.position.x / TILE), ceili(home.end.x / TILE)):
		lowest = maxf(lowest, _ceiling_px(chamber, column) + DUST_CLEAR)
	return home.grow_side(SIDE_TOP, home.position.y - lowest)


## True if a mote at [param at] has drifted into the earth of a room cut to a shape.
func _in_earth(at: Vector2) -> bool:
	return _shapes != null and not _map.is_open(Vector2i((at / TILE).floor()))


# --------------------------------------------------------------------- motion


func _place_drips(chamber: LabyrinthChamber) -> void:
	var rect: Rect2i = chamber.rect
	var from: Vector2 = Vector2.INF
	for prop: AmbienceProp in props:
		if prop.chamber == chamber.index and prop.name == &"stalactite":
			# The stalactite's tip: its lowest pixel, in the middle of its 8-pixel canvas.
			from = Vector2(prop.rect.position.x + 3, prop.rect.position.y + 14)
	if from == Vector2.INF:
		for attempt: int in 6:
			var x: int = (
				rect.position.x + 1 + _roll(30 + attempt, chamber.index) % (rect.size.x - 2)
			)
			if not _near(_shaft_columns, x):
				var inside: int = 3 + _roll(36, x) % 10
				from = Vector2(x * TILE + inside, _ceiling_px(chamber, x))
				break
	if from == Vector2.INF:
		return
	_drip_from.append(from)
	_drip_floors.append(_floor_px)
	var every: float = _rng.randf_range(DRIP_EVERY.x, DRIP_EVERY.y)
	_drip_every.append(every)
	_drip_timers.append(_rng.randf_range(0.2, every))


func _place_span(chamber: LabyrinthChamber) -> void:
	var rect: Rect2i = chamber.rect
	var from: float = rect.position.x * TILE + 6
	var to: float = rect.end.x * TILE - 6
	for x: int in _shaft_columns:
		if x >= rect.position.x and x < rect.end.x and not _incoming_columns.has(x):
			# The shaft down opens in this floor: keep to the wider side of the hole.
			var hole_from: float = (x - 0.25) * TILE
			var hole_to: float = (x + 1.25) * TILE
			if hole_from - from > to - hole_to:
				to = minf(to, hole_from)
			else:
				from = maxf(from, hole_to)
	if to - from > TILE * 3:
		_spans.append(Vector2(from, to))
		_span_floors.append(_floor_px)


func _add(mote: AmbienceMote) -> bool:
	if motes.size() >= _mote_cap:
		return false
	motes.append(mote)
	return true


func _new_dust(room: int) -> AmbienceMote:
	var area: Rect2 = _rooms[room]
	var at := Vector2(
		_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y)
	)
	var dust := AmbienceMote.new(&"dust", at, _rng.randf_range(DUST_LIFE.x, DUST_LIFE.y))
	dust.velocity = Vector2(
		_rng.randf_range(-DUST_SPEED, DUST_SPEED), _rng.randf_range(-DUST_SPEED, DUST_SPEED) * 0.5
	)
	dust.phase = _rng.randf_range(0.0, TAU)
	dust.source = room
	_add(dust)
	return dust


func _move_motes(delta: float) -> void:
	var landed: Array[AmbienceMote] = []
	var gone: Array[AmbienceMote] = []
	for mote: AmbienceMote in motes:
		mote.age += delta
		match mote.kind:
			&"dust":
				mote.position += mote.velocity * delta
				mote.position.x += sin(mote.age * 1.7 + mote.phase) * 2.0 * delta
				var strayed: bool = not _rooms[mote.source].grow(4).has_point(mote.position)
				if strayed or _in_earth(mote.position):
					mote.age = mote.life
			&"ember":
				mote.velocity.x += sin(mote.age * 9.0 + mote.phase) * 30.0 * delta
				mote.position += mote.velocity * delta
				if _in_earth(mote.position):
					mote.age = mote.life
			&"drip":
				if mote.age > DRIP_SWELL:
					mote.velocity.y += GRAVITY * delta
					mote.position += mote.velocity * delta
					if mote.position.y >= mote.origin.y - 1:
						mote.position.y = mote.origin.y - 1
						landed.append(mote)
			&"splash":
				mote.velocity.y += GRAVITY * delta
				mote.position += mote.velocity * delta
				mote.position.y = minf(mote.position.y, mote.origin.y - 1)
			&"beetle":
				mote.position.x = move_toward(mote.position.x, mote.origin.x, BEETLE_SPEED * delta)
				if is_equal_approx(mote.position.x, mote.origin.x):
					mote.age = mote.life
			&"moth":
				var angle: float = mote.phase + mote.age * MOTH_SPEED
				var wander: float = sin(mote.age * 1.3) * 2.0
				mote.position = (
					mote.origin
					+ Vector2(cos(angle) * (MOTH_ORBIT.x + wander), sin(angle) * MOTH_ORBIT.y)
				)
		if mote.age >= mote.life or landed.has(mote):
			gone.append(mote)
	for mote: AmbienceMote in gone:
		motes.erase(mote)
		if mote.kind == &"dust":
			_new_dust(mote.source)
	for drop: AmbienceMote in landed:
		for i: int in SPLASH_DROPS:
			var splash := AmbienceMote.new(&"splash", drop.position, SPLASH_LIFE)
			splash.origin = drop.origin
			splash.velocity = Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-45.0, -25.0))
			_add(splash)


func _spawn_embers(delta: float) -> void:
	for i: int in _emitters.size():
		_ember_timers[i] -= delta
		if _ember_timers[i] > 0.0 or not _emitters[i].lit:
			continue
		var emitter: AmbienceProp = _emitters[i]
		var every: Vector2 = CAMPFIRE_EMBER_EVERY if emitter.name == &"campfire" else EMBER_EVERY
		_ember_timers[i] = _rng.randf_range(every.x, every.y)
		var top: Vector2 = emitter.light.position + Vector2(_rng.randf_range(-2.0, 2.0), -3)
		if emitter.name == &"campfire":
			top = emitter.rect.position + Vector2(12 + _rng.randf_range(-5.0, 5.0), 8)
		var ember := AmbienceMote.new(&"ember", top, _rng.randf_range(EMBER_LIFE.x, EMBER_LIFE.y))
		ember.velocity = Vector2(
			_rng.randf_range(-5.0, 5.0), -_rng.randf_range(EMBER_RISE.x, EMBER_RISE.y)
		)
		ember.phase = _rng.randf_range(0.0, TAU)
		_add(ember)


func _spawn_drips(delta: float) -> void:
	for i: int in _drip_from.size():
		_drip_timers[i] -= delta
		if _drip_timers[i] > 0.0:
			continue
		_drip_timers[i] = _drip_every[i]
		var drip := AmbienceMote.new(&"drip", _drip_from[i], 10.0)
		drip.origin = Vector2(_drip_from[i].x, _drip_floors[i])
		_add(drip)


func _spawn_critters(delta: float) -> void:
	_critter_timer -= delta
	if _critter_timer > 0.0:
		return
	_critter_timer = _rng.randf_range(CRITTER_EVERY.x, CRITTER_EVERY.y)
	var about: int = 0
	for mote: AmbienceMote in motes:
		if mote.kind == &"beetle" or mote.kind == &"moth":
			about += 1
	if about >= MAX_CRITTERS:
		return
	var moth: bool = _rng.randf() < 0.5
	if moth and not torches.is_empty():
		var torch: AmbienceProp = torches[_rng.randi_range(0, torches.size() - 1)]
		var flutter := AmbienceMote.new(
			&"moth", torch.light.position, _rng.randf_range(MOTH_LIFE.x, MOTH_LIFE.y)
		)
		flutter.phase = _rng.randf_range(0.0, TAU)
		flutter.position = (
			flutter.origin + Vector2(cos(flutter.phase), sin(flutter.phase)) * MOTH_ORBIT
		)
		_add(flutter)
	elif not _spans.is_empty():
		var crossed: int = _rng.randi_range(0, _spans.size() - 1)
		var span: Vector2 = _spans[crossed]
		var floor_px: float = _span_floors[crossed]
		var rightward: bool = _rng.randf() < 0.5
		var start: float = span.x if rightward else span.y
		var end: float = span.y if rightward else span.x
		var beetle := AmbienceMote.new(
			&"beetle", Vector2(start, floor_px - 1), absf(end - start) / BEETLE_SPEED + 1.0
		)
		beetle.origin = Vector2(end, floor_px - 1)
		beetle.velocity = Vector2(signf(end - start) * BEETLE_SPEED, 0)
		_add(beetle)


func _spawn_glints(delta: float) -> void:
	_glint_timer -= delta
	if _glint_timer <= 0.0 and not _ores.is_empty():
		_glint_timer = _rng.randf_range(GLINT_EVERY.x, GLINT_EVERY.y)
		var tile: Vector2i = _ores[_rng.randi_range(0, _ores.size() - 1)]
		var at := Vector2(tile * TILE) + Vector2(_rng.randi_range(5, 10), _rng.randi_range(5, 10))
		_add(AmbienceMote.new(&"glint", at, GLINT_LIFE))
	_gleam_timer -= delta
	if _gleam_timer <= 0.0 and not _gleams.is_empty():
		_gleam_timer = _rng.randf_range(GLEAM_EVERY.x, GLEAM_EVERY.y)
		var gleam: AmbienceProp = _gleams[_rng.randi_range(0, _gleams.size() - 1)]
		var area: Rect2 = gleam.rect
		var spark := Vector2(
			_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.end.y - 12, area.end.y - 3)
		)
		_add(AmbienceMote.new(&"glint", spark.round(), GLINT_LIFE))


# -------------------------------------------------------------------- drawing


func _draw_buried() -> void:
	buried_draws += 1
	var buried: PixelSheet = _sheet("buried")
	for tile: Vector2i in details:
		_buried.draw_texture(buried.part(details[tile]), Vector2(tile * TILE))


func _draw() -> void:
	for prop: AmbienceProp in _all_torches:
		_draw_prop(self, prop, prop.base())
	for prop: AmbienceProp in _all_props:
		if prop.texture != null:
			_draw_prop(self, prop, prop.texture)
	AmbienceMoteDraw.lit(self, motes, _time)


func _draw_glow() -> void:
	for prop: AmbienceProp in _all_torches:
		if prop.glowing() != null:
			_draw_prop(_glow, prop, prop.glowing())
	for prop: AmbienceProp in _all_props:
		if prop.glowing() != null:
			_draw_prop(_glow, prop, prop.glowing())
	AmbienceMoteDraw.glow(_glow, motes)


static func _draw_prop(canvas: CanvasItem, prop: AmbienceProp, texture: Texture2D) -> void:
	AmbienceMoteDraw.flipped(canvas, texture, prop.rect.position, prop.flip)

class_name AmbienceLevel
extends Node2D
## The decoration of one built level: torches on the chambers' back walls, props that
## say what kind each chamber is, things buried in the earth, and the small motion around them
## (dust, embers, drips, critters, glints).
##
## Everything is placed from the level's layout and tile positions, never from a clock, so
## rebuilding a level places the same things in the same places. Motion is stepped in
## [method advance] from a random stream seeded by the level.
##
## This node draws what is lit like the world (under the darkness, see [Ambience]); its child
## Glow draws what shines on its own (flames, embers, glints, glowing props) over the darkness.

const DIR: String = "res://assets/sprites/ambience/"
const TILE: int = LabyrinthView.TILE
## Nodes a level adds to the tree: itself and its Glow.
const NODES: int = 2
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
## How many props a PLAIN chamber has at most (at least one).
const MAX_PLAIN_PROPS: int = 3

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
## Motes alive at most on one level, so five built levels keep under 600 motes.
const MAX_MOTES: int = 120
const DUST_PER_TORCH: int = 4
## How far from its torch a dust mote drifts, in pixels, and how fast.
const DUST_RANGE: Vector2 = Vector2(46, 28)
const DUST_SPEED: float = 3.0
const DUST_LIFE: Vector2 = Vector2(3.0, 7.0)
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
## Buried things by world tile.
var details: Dictionary[Vector2i, StringName] = {}
## Everything small that moves.
var motes: Array[AmbienceMote] = []
## The lights of this level's torches and props.
var lights: Array[AmbienceLight] = []
## How much light reaches each tile of the band (one pixel per tile, red channel): all of it in
## open space, less in the earth (see [constant AmbienceMood.EDGE_EXPOSURE]).
var exposure: Image

var _seed: int
## Open tiles of the band and a one-tile border round it: 1 open, 0 earth.
var _open: PackedByteArray = []
var _top: int
var _band: int
var _floor_px: float
var _rng := RandomNumberGenerator.new()
var _glow: Node2D
var _time: float = 0.0
## Columns a shaft runs through on this level, the one from above included.
var _shaft_columns: Dictionary[int, bool] = {}
var _incoming_columns: Dictionary[int, bool] = {}
## Dust homes: per torch, the open rectangle its chamber gives it.
var _rooms: Array[Rect2] = []
## Things that throw embers (torches and the campfire), and seconds to the next ember of each.
var _emitters: Array[AmbienceProp] = []
var _ember_timers: PackedFloat32Array = []
## Where drips fall from and how often, and seconds to the next drip of each.
var _drip_from: PackedVector2Array = []
var _drip_every: PackedFloat32Array = []
var _drip_timers: PackedFloat32Array = []
## Floor spans a beetle can cross, as (from x, to x) in world pixels.
var _spans: PackedVector2Array = []
var _ores: Array[Vector2i] = []
var _gleams: Array[AmbienceProp] = []
var _critter_timer: float
var _glint_timer: float
var _gleam_timer: float
var _glow_lights: int = 0


## Places the decoration of [param level_depth] as the [param view] draws it.
func build(view: LabyrinthView, level_depth: int) -> void:
	depth = level_depth
	name = "Depth%d" % depth
	var level: LabyrinthLevel = view.labyrinth.level(depth)
	_seed = level_seed(level)
	_rng.seed = _seed
	_band = view.band_of(depth)
	_floor_px = (level.floor_y + 1) * TILE
	_top = (depth - 1) * Labyrinth.LEVEL_HEIGHT
	_map_open(view)
	var shafts: Array[Rect2i] = [level.shaft_down]
	if depth > 1:
		shafts.append(view.labyrinth.level(depth - 1).shaft_down)
		for x: int in range(shafts[1].position.x, shafts[1].end.x):
			_incoming_columns[x] = true
	for shaft: Rect2i in shafts:
		for x: int in range(shaft.position.x, shaft.end.x):
			_shaft_columns[x] = true
	for chamber: LabyrinthChamber in level.chambers:
		_place_torches(chamber)
		_place_props(chamber)
		_place_drips(chamber)
		_place_span(chamber)
	_place_details()
	for torch: AmbienceProp in torches:
		lights.append(torch.light)
	for prop: AmbienceProp in props:
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

	_glow = Node2D.new()
	_glow.name = "Glow"
	_glow.z_index = GLOW_Z
	_glow.z_as_relative = false
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## Steps the flames, flicker and motion by [param delta] seconds.
func advance(delta: float) -> void:
	_time += delta
	for prop: AmbienceProp in torches:
		prop.advance(_time)
	for prop: AmbienceProp in props:
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


## A number from this level's seed, [param salt] and a position: the same every build.
func _roll(salt: int, a: int, b: int = 0) -> int:
	return mix(mix(mix(_seed, salt), a), b)


# -------------------------------------------------------------------- torches


func _place_torches(chamber: LabyrinthChamber) -> void:
	var rect: Rect2i = chamber.rect
	var count: int = maxi(1, roundi(rect.size.x / TORCH_SPACING))
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
		_rooms.append(room.intersection(Rect2(torch.light.position - DUST_RANGE, DUST_RANGE * 2)))


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


# ---------------------------------------------------------------------- props


func _place_props(chamber: LabyrinthChamber) -> void:
	var rect: Rect2i = chamber.rect
	var floor_free: Array[int] = []
	var ceiling_free: Array[int] = []
	for x: int in range(rect.position.x + 1, rect.end.x - 1):
		if _near(_shaft_columns, x):
			continue
		floor_free.append(x)
		var under_torch: bool = false
		for torch: AmbienceProp in torches:
			under_torch = under_torch or roundi(torch.rect.position.x / TILE) == x
		if not under_torch:
			ceiling_free.append(x)
	var centre: float = rect.position.x + rect.size.x * 0.5
	var salt: int = chamber.index * 101
	match chamber.kind:
		LabyrinthChamber.Kind.START:
			_light_campfire(
				_floor_prop(chamber, &"campfire", "campfire", "logs", 2, floor_free, centre)
			)
			_floor_prop(chamber, &"bedroll", "bedroll", "red", 2, floor_free, centre - 4)
			_floor_prop(chamber, &"bedroll", "bedroll", "green", 2, floor_free, centre + 4)
		LabyrinthChamber.Kind.DEN:
			_web_corner(chamber, "left", rect.position.x)
			_web_corner(chamber, "right", rect.end.x - 1)
			var spot: float = rect.position.x + (_roll(salt, 1) % rect.size.x)
			_ceiling_prop(chamber, &"spider", "web", "strand", ceiling_free, spot, 0)
			spot = rect.position.x + (_roll(salt, 2) % rect.size.x)
			_floor_prop(chamber, &"bones", "bones", "pile", 1, floor_free, spot)
			_floor_prop(chamber, &"skull", "bones", "skull", 1, floor_free, spot + 3)
			_floor_prop(chamber, &"nest", "nest", "eggs", 1, floor_free, spot - 4)
		LabyrinthChamber.Kind.VAULT:
			_place_hoard(chamber, floor_free, centre)
		LabyrinthChamber.Kind.PLAIN:
			_place_plain(chamber, floor_free, ceiling_free, salt)


## Whether [param x] or a column next to it is in [param columns].
static func _near(columns: Dictionary[int, bool], x: int) -> bool:
	return columns.has(x - 1) or columns.has(x) or columns.has(x + 1)


## Takes [param width] free neighbouring columns as close to [param target] as there are, and
## returns the leftmost, or -1.
static func _take(free: Array[int], width: int, target: float) -> int:
	var best: int = -1
	var best_distance: float = INF
	for start: int in free:
		var fits: bool = true
		for x: int in range(start, start + width):
			fits = fits and free.has(x)
		var distance: float = absf(start + width * 0.5 - target)
		if fits and distance < best_distance:
			best = start
			best_distance = distance
	if best >= 0:
		for x: int in range(best, best + width):
			free.erase(x)
	return best


func _floor_prop(
	chamber: LabyrinthChamber,
	prop_name: StringName,
	sheet_name: String,
	part_name: String,
	width: int,
	free: Array[int],
	target: float
) -> AmbienceProp:
	var column: int = _take(free, width, target)
	if column < 0:
		return null
	var sheet: PixelSheet = _sheet(sheet_name)
	var size := Vector2(sheet.size)
	# A puddle sinks into the floor's crust; everything else stands on it.
	var sink: float = 2.0 if prop_name == &"puddle" else 0.0
	var x: float = column * TILE + floorf((width * TILE - size.x) * 0.5)
	var prop := AmbienceProp.new(
		prop_name,
		chamber.index,
		Rect2(Vector2(x, _floor_px - size.y + sink), size),
		AmbienceProp.Anchor.FLOOR
	)
	prop.texture = sheet.part(StringName(part_name))
	prop.flip = _roll(7, column) % 2 == 0 and prop_name != &"bedroll"
	props.append(prop)
	return prop


func _ceiling_prop(
	chamber: LabyrinthChamber,
	prop_name: StringName,
	sheet_name: String,
	part_name: String,
	free: Array[int],
	target: float,
	offset_x: int
) -> AmbienceProp:
	var column: int = _take(free, 1, target)
	if column < 0:
		return null
	var sheet: PixelSheet = _sheet(sheet_name)
	var size := Vector2(sheet.size)
	var x: float = column * TILE + floorf((TILE - size.x) * 0.5) + offset_x
	# Two rows sink into the ragged ceiling, so nothing hangs in the air.
	var prop := AmbienceProp.new(
		prop_name,
		chamber.index,
		Rect2(Vector2(x, chamber.rect.position.y * TILE - 2), size),
		AmbienceProp.Anchor.CEILING
	)
	prop.texture = sheet.part(StringName(part_name))
	props.append(prop)
	return prop


func _web_corner(chamber: LabyrinthChamber, part_name: String, column: int) -> void:
	if _near(_incoming_columns, column):
		return
	var prop := AmbienceProp.new(
		&"web",
		chamber.index,
		Rect2(column * TILE, chamber.rect.position.y * TILE - 2, TILE, TILE),
		AmbienceProp.Anchor.CEILING
	)
	prop.texture = _part("web", part_name)
	props.append(prop)


## A VAULT's chest among piles of coins (four tiles of them where the floor allows, three
## otherwise), and the gleam over them.
func _place_hoard(chamber: LabyrinthChamber, floor_free: Array[int], centre: float) -> void:
	var parts: Array[Array] = [
		[&"coins", "coins", "big"],
		[&"chest", "chest", "closed"],
		[&"coins", "coins", "small"],
		[&"coins", "coins", "big"],
	]
	var width: int = parts.size()
	var column: int = _take(floor_free, width, centre)
	if column < 0:
		width = 3
		parts.resize(width)
		column = _take(floor_free, width, centre)
	if column < 0:
		push_error("AmbienceLevel: no room for a hoard at depth %d" % depth)
		return
	var flip: bool = _roll(8, column) % 2 == 0
	for i: int in width:
		var part: Array = parts[width - 1 - i] if flip else parts[i]
		var prop_name: StringName = part[0]
		var sheet_name: String = part[1]
		var part_name: String = part[2]
		var sheet: PixelSheet = _sheet(sheet_name)
		var size := Vector2(sheet.size)
		var prop := AmbienceProp.new(
			prop_name,
			chamber.index,
			Rect2(Vector2((column + i) * TILE, _floor_px - size.y), size),
			AmbienceProp.Anchor.FLOOR
		)
		prop.texture = sheet.part(StringName(part_name))
		props.append(prop)
	var gleam := AmbienceProp.new(
		&"gleam",
		chamber.index,
		Rect2(Vector2((column + 0.5) * TILE, _floor_px - 20), Vector2(TILE * (width - 1), 20)),
		AmbienceProp.Anchor.FLOOR
	)
	gleam.light = AmbienceLight.new(
		&"gleam",
		Vector2((column + width * 0.5) * TILE, _floor_px - 8),
		GLEAM_RADIUS,
		GLEAM_ENERGY,
		Palette.color(&"yellow"),
		GLEAM_FLICKER,
		_roll(9, column)
	)
	props.append(gleam)
	_gleams.append(gleam)


func _place_plain(
	chamber: LabyrinthChamber, floor_free: Array[int], ceiling_free: Array[int], salt: int
) -> void:
	var pool: Array[StringName] = [&"stalactite", &"stalactite", &"mushroom", &"crate", &"puddle"]
	# Glowing things grow from the stone stratum down.
	if _band >= 2:
		pool.append_array([&"glow_mushroom", &"glow_mushroom", &"glow_mushroom", &"glow_mushroom"])
	if _band == 3:
		pool.append_array([&"crystal", &"crystal", &"crystal", &"crystal"])
	var count: int = 1 + _roll(salt, 3) % MAX_PLAIN_PROPS
	var rect: Rect2i = chamber.rect
	for i: int in count * 3:
		if _props_in_chamber(chamber.index) >= count:
			return
		var kind: StringName = pool[_roll(salt, 10 + i) % pool.size()]
		var target: float = rect.position.x + 1 + (_roll(salt, 40 + i) % maxi(rect.size.x - 2, 1))
		var variant: int = _roll(salt, 70 + i)
		match kind:
			&"stalactite":
				var offset: int = variant % 5 - 2
				_ceiling_prop(
					chamber,
					kind,
					"stalactite",
					LabyrinthTiles.STRATA[_band],
					ceiling_free,
					target,
					offset
				)
			&"mushroom":
				var part: String = "brown" if variant % 2 == 0 else "red"
				_floor_prop(chamber, kind, "mushroom", part, 1, floor_free, target)
			&"crate":
				_floor_prop(chamber, kind, "crate", "broken", 1, floor_free, target)
			&"puddle":
				_floor_prop(chamber, kind, "puddle", "water", 1, floor_free, target)
			&"glow_mushroom":
				var green: bool = variant % 3 == 0
				_glowing(
					_floor_prop(
						chamber,
						kind,
						"mushroom",
						"glow_green" if green else "glow_cyan",
						1,
						floor_free,
						target
					),
					&"green" if green else &"cyan"
				)
			&"crystal":
				var orchid: bool = variant % 3 == 0
				_glowing(
					_floor_prop(
						chamber,
						kind,
						"crystal",
						"orchid" if orchid else "cyan",
						1,
						floor_free,
						target
					),
					&"orchid" if orchid else &"cyan"
				)


func _props_in_chamber(index: int) -> int:
	var count: int = 0
	for prop: AmbienceProp in props:
		if prop.chamber == index:
			count += 1
	return count


## Gives the START chamber's campfire its flames, its light and its embers.
func _light_campfire(prop: AmbienceProp) -> void:
	if prop == null:
		return
	for frame: int in 4:
		prop.frames.append(_part("campfire", "flame_%d" % frame))
	prop.frame_rate = FLAME_RATE
	prop.light = AmbienceLight.new(
		&"campfire",
		prop.rect.position + Vector2(12, 13),
		CAMPFIRE_RADIUS,
		CAMPFIRE_ENERGY,
		AmbienceMood.band_tint(_band).lerp(Palette.color(&"orange"), 0.3),
		CAMPFIRE_FLICKER,
		_roll(3, roundi(prop.rect.position.x))
	)
	_emitters.append(prop)


## Makes a placed prop shine on its own (drawn over the darkness) in [param tint], and light its
## corner while the level has light to spare.
func _glowing(prop: AmbienceProp, tint: StringName) -> void:
	if prop == null:
		return
	prop.frames.append(prop.texture)
	prop.texture = null
	if _glow_lights >= MAX_GLOW_LIGHTS:
		return
	_glow_lights += 1
	prop.light = AmbienceLight.new(
		&"glow", prop.rect.get_center(), GLOW_RADIUS, GLOW_ENERGY, Palette.color(tint), 0.0, 0
	)


# ------------------------------------------------------------- buried things


func _place_details() -> void:
	var top: int = _top
	var kinds: Array = BURIED_KINDS[_band]
	for cell_y: int in range(0, Labyrinth.LEVEL_HEIGHT, DETAIL_CELL.y):
		for cell_x: int in range(0, Labyrinth.LEVEL_WIDTH, DETAIL_CELL.x):
			for attempt: int in DETAIL_TRIES:
				var roll: int = _roll(20 + attempt, cell_x, cell_y)
				var tile := Vector2i(
					cell_x + roll % DETAIL_CELL.x, top + cell_y + (roll >> 8) % DETAIL_CELL.y
				)
				if tile.x >= Labyrinth.LEVEL_WIDTH or not _is_buried(tile):
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
	var local := Vector2i(tile.x, tile.y - _top)
	if local.x < 0 or local.y < 0 or local.x >= exposure.get_width():
		return AmbienceMood.EARTH_EXPOSURE
	if local.y >= exposure.get_height():
		return AmbienceMood.EARTH_EXPOSURE
	return exposure.get_pixelv(local).r


## Marks the open tiles of this band as the view draws them (chambers, tunnels and shafts,
## including the shaft from the level above and those of the levels either side reaching in; a
## stage shown as its own place has no shafts), and from them how much light reaches
## each tile.
func _map_open(view: LabyrinthView) -> void:
	var width: int = Labyrinth.LEVEL_WIDTH + 2
	_open.resize(width * (Labyrinth.LEVEL_HEIGHT + 2))
	var band := Rect2i(-1, _top - 1, width, Labyrinth.LEVEL_HEIGHT + 2)
	for rect: Rect2i in view.open_rects_near(depth):
		var overlap: Rect2i = rect.intersection(band)
		for y: int in range(overlap.position.y, overlap.end.y):
			for x: int in range(overlap.position.x, overlap.end.x):
				_open[(y - _top + 1) * width + x + 1] = 1
	exposure = Image.create_empty(
		Labyrinth.LEVEL_WIDTH, Labyrinth.LEVEL_HEIGHT, false, Image.FORMAT_R8
	)
	for y: int in Labyrinth.LEVEL_HEIGHT:
		for x: int in Labyrinth.LEVEL_WIDTH:
			var tile := Vector2i(x, _top + y)
			var value: float = AmbienceMood.EARTH_EXPOSURE
			if _is_open(tile):
				value = 1.0
			elif not _is_buried(tile):
				value = AmbienceMood.EDGE_EXPOSURE
			exposure.set_pixel(x, y, Color(value, 0.0, 0.0))


func _is_open(tile: Vector2i) -> bool:
	# Columns outside the band are earth, as is the sky.
	if tile.x < 0 or tile.x >= Labyrinth.LEVEL_WIDTH or tile.y < 0:
		return false
	var row: int = tile.y - _top + 1
	if row < 0 or row >= Labyrinth.LEVEL_HEIGHT + 2:
		return false
	return _open[row * (Labyrinth.LEVEL_WIDTH + 2) + tile.x + 1] == 1


## Earth all round: not open, and no open neighbour, diagonals included.
func _is_buried(tile: Vector2i) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if _is_open(tile + Vector2i(dx, dy)):
				return false
	return true


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
				from = Vector2(x * TILE + inside, rect.position.y * TILE)
				break
	if from == Vector2.INF:
		return
	_drip_from.append(from)
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


func _add(mote: AmbienceMote) -> bool:
	if motes.size() >= MAX_MOTES:
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
				if not _rooms[mote.source].grow(4).has_point(mote.position):
					mote.age = mote.life
			&"ember":
				mote.velocity.x += sin(mote.age * 9.0 + mote.phase) * 30.0 * delta
				mote.position += mote.velocity * delta
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
		if _ember_timers[i] > 0.0:
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
		drip.origin = Vector2(_drip_from[i].x, _floor_px)
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
		var span: Vector2 = _spans[_rng.randi_range(0, _spans.size() - 1)]
		var rightward: bool = _rng.randf() < 0.5
		var start: float = span.x if rightward else span.y
		var end: float = span.y if rightward else span.x
		var beetle := AmbienceMote.new(
			&"beetle", Vector2(start, _floor_px - 1), absf(end - start) / BEETLE_SPEED + 1.0
		)
		beetle.origin = Vector2(end, _floor_px - 1)
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


func _draw() -> void:
	var buried: PixelSheet = _sheet("buried")
	for tile: Vector2i in details:
		draw_texture(buried.part(details[tile]), Vector2(tile * TILE))
	for prop: AmbienceProp in torches:
		_draw_prop(self, prop, prop.texture)
	for prop: AmbienceProp in props:
		if prop.texture != null:
			_draw_prop(self, prop, prop.texture)
	var critters: PixelSheet = _sheet("critters")
	var step: int = floori(_time * 8.0)
	for mote: AmbienceMote in motes:
		var at: Vector2 = mote.position.round()
		match mote.kind:
			&"dust":
				draw_rect(Rect2(at, Vector2.ONE), Palette.color(&"sand"))
			&"drip":
				var swell: bool = mote.age < DRIP_SWELL * 0.5
				draw_rect(Rect2(at, Vector2(1, 1 if swell else 2)), Palette.color(&"cyan"))
			&"splash":
				draw_rect(Rect2(at, Vector2.ONE), Palette.color(&"cyan"))
			&"beetle":
				var beetle: Texture2D = critters.part(&"beetle_%d" % (step % 2))
				_draw_flipped(self, beetle, at + Vector2(-4, -7), mote.velocity.x < 0.0)
			&"moth":
				var moth: Texture2D = critters.part(&"moth_%d" % ((step + 1) % 2))
				draw_texture(moth, at - Vector2(4, 4))


func _draw_glow() -> void:
	for prop: AmbienceProp in torches:
		_draw_prop(_glow, prop, prop.frames[prop.frame])
	for prop: AmbienceProp in props:
		if not prop.frames.is_empty():
			_draw_prop(_glow, prop, prop.frames[prop.frame])
	var sparkle: PixelSheet = _sheet("sparkle")
	for mote: AmbienceMote in motes:
		match mote.kind:
			&"ember":
				var t: float = mote.progress()
				var color: Color = Palette.color(&"yellow")
				if t > 0.7:
					color = Palette.color(&"red")
				elif t > 0.35:
					color = Palette.color(&"orange")
				_glow.draw_rect(Rect2(mote.position.round(), Vector2.ONE), color)
			&"glint":
				var big: bool = mote.progress() > 0.3 and mote.progress() < 0.7
				var part: Texture2D = sparkle.part(&"big" if big else &"small")
				_glow.draw_texture(part, mote.position - Vector2(3, 3))


static func _draw_prop(canvas: CanvasItem, prop: AmbienceProp, texture: Texture2D) -> void:
	_draw_flipped(canvas, texture, prop.rect.position, prop.flip)


static func _draw_flipped(canvas: CanvasItem, texture: Texture2D, at: Vector2, flip: bool) -> void:
	if not flip:
		canvas.draw_texture(texture, at)
		return
	var size := Vector2(texture.get_size())
	canvas.draw_texture_rect(
		texture, Rect2(at + Vector2(size.x, 0), Vector2(-size.x, size.y)), false
	)

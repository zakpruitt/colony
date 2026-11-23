class_name AmbienceRoomProps
extends RefCounted
## The props that say what kind a room is, placed for [AmbienceLevel]: START a campfire between
## bedrolls; DEN corner webs, a hanging spider, bones, a skull and a nest; VAULT a chest among
## piles of coins under a gleam; and what a PLAIN room and a cache room hold. One is made for a
## level and places each of its rooms in turn.

const TILE: int = LabyrinthView.TILE
## How many props a PLAIN chamber has at most (at least one).
const MAX_PLAIN_PROPS: int = 3

## Glowing props lit so far on the level.
var _glow_lights: int = 0


## The props of [param room] by its kind, rolled with [param salt] (-1: its index's).
func place(room: AmbienceRoom, salt: int = -1) -> void:
	var chamber: LabyrinthChamber = room.chamber
	var rect: Rect2i = chamber.rect
	var floor_free: Array[int] = []
	var ceiling_free: Array[int] = []
	for x: int in range(rect.position.x + 1, rect.end.x - 1):
		if room.near_clear(x):
			continue
		floor_free.append(x)
		var under_torch: bool = false
		for torch: AmbienceProp in room.torches:
			under_torch = under_torch or roundi(torch.rect.position.x / TILE) == x
		if not under_torch:
			ceiling_free.append(x)
	var centre: float = rect.position.x + rect.size.x * 0.5
	if salt < 0:
		salt = chamber.index * 101
	match chamber.kind:
		LabyrinthChamber.Kind.START:
			_light_campfire(
				room, _floor_prop(room, &"campfire", "campfire", "logs", 2, floor_free, centre)
			)
			_floor_prop(room, &"bedroll", "bedroll", "red", 2, floor_free, centre - 4)
			_floor_prop(room, &"bedroll", "bedroll", "green", 2, floor_free, centre + 4)
		LabyrinthChamber.Kind.DEN:
			_web_corner(room, "left", rect.position.x)
			_web_corner(room, "right", rect.end.x - 1)
			var spot: float = rect.position.x + (room.roll(salt, 1) % rect.size.x)
			_ceiling_prop(room, &"spider", "web", "strand", ceiling_free, spot, 0)
			spot = rect.position.x + (room.roll(salt, 2) % rect.size.x)
			_floor_prop(room, &"bones", "bones", "pile", 1, floor_free, spot)
			_floor_prop(room, &"skull", "bones", "skull", 1, floor_free, spot + 3)
			_floor_prop(room, &"nest", "nest", "eggs", 1, floor_free, spot - 4)
		LabyrinthChamber.Kind.VAULT:
			_place_hoard(room, floor_free, centre)
		LabyrinthChamber.Kind.PLAIN:
			_place_plain(room, floor_free, ceiling_free, salt, 0)
		LabyrinthChamber.Kind.CACHE:
			# Cache rooms share an index: count from the props there were before this one's.
			_place_plain(room, floor_free, ceiling_free, salt, room.props_in(-1))


static func _sheet(sheet_name: String) -> PixelSheet:
	return PixelSheet.load_sheet(AmbienceLevel.DIR + sheet_name + ".png")


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
	room: AmbienceRoom,
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
		room.chamber.index,
		Rect2(Vector2(x, room.floor_px - size.y + sink), size),
		AmbienceProp.Anchor.FLOOR
	)
	prop.texture = sheet.part(StringName(part_name))
	prop.flip = room.roll(7, column) % 2 == 0 and prop_name != &"bedroll"
	room.props.append(prop)
	return prop


func _ceiling_prop(
	room: AmbienceRoom,
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
		room.chamber.index,
		Rect2(Vector2(x, room.ceiling_px(column) - 2), size),
		AmbienceProp.Anchor.CEILING
	)
	prop.texture = sheet.part(StringName(part_name))
	room.props.append(prop)
	return prop


func _web_corner(room: AmbienceRoom, part_name: String, column: int) -> void:
	if room.near_closed(column):
		return
	var prop := AmbienceProp.new(
		&"web",
		room.chamber.index,
		Rect2(column * TILE, room.ceiling_px(column) - 2, TILE, TILE),
		AmbienceProp.Anchor.CEILING
	)
	prop.texture = _sheet("web").part(StringName(part_name))
	room.props.append(prop)


## A VAULT's chest among piles of coins (four tiles of them where the floor allows, three
## otherwise), and the gleam over them.
func _place_hoard(room: AmbienceRoom, floor_free: Array[int], centre: float) -> void:
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
		push_error("AmbienceRoomProps: no room for a hoard in %s" % room.chamber.rect)
		return
	var flip: bool = room.roll(8, column) % 2 == 0
	for i: int in width:
		var part: Array = parts[width - 1 - i] if flip else parts[i]
		var prop_name: StringName = part[0]
		var sheet_name: String = part[1]
		var part_name: String = part[2]
		var sheet: PixelSheet = _sheet(sheet_name)
		var size := Vector2(sheet.size)
		var prop := AmbienceProp.new(
			prop_name,
			room.chamber.index,
			Rect2(Vector2((column + i) * TILE, room.floor_px - size.y), size),
			AmbienceProp.Anchor.FLOOR
		)
		prop.texture = sheet.part(StringName(part_name))
		room.props.append(prop)
	var gleam := AmbienceProp.new(
		&"gleam",
		room.chamber.index,
		Rect2(Vector2((column + 0.5) * TILE, room.floor_px - 20), Vector2(TILE * (width - 1), 20)),
		AmbienceProp.Anchor.FLOOR
	)
	gleam.light = AmbienceLight.new(
		&"gleam",
		Vector2((column + width * 0.5) * TILE, room.floor_px - 8),
		AmbienceLevel.GLEAM_RADIUS,
		AmbienceLevel.GLEAM_ENERGY,
		Palette.color(&"yellow"),
		AmbienceLevel.GLEAM_FLICKER,
		room.roll(9, column)
	)
	room.props.append(gleam)
	room.gleams.append(gleam)


func _place_plain(
	room: AmbienceRoom, floor_free: Array[int], ceiling_free: Array[int], salt: int, before: int
) -> void:
	var pool: Array[StringName] = [&"stalactite", &"stalactite", &"mushroom", &"crate", &"puddle"]
	# Glowing things grow from the stone stratum down.
	if room.band >= 2:
		pool.append_array([&"glow_mushroom", &"glow_mushroom", &"glow_mushroom", &"glow_mushroom"])
	if room.band == 3:
		pool.append_array([&"crystal", &"crystal", &"crystal", &"crystal"])
	var count: int = 1 + room.roll(salt, 3) % MAX_PLAIN_PROPS
	var rect: Rect2i = room.chamber.rect
	for i: int in count * 3:
		if room.props_in(room.chamber.index) - before >= count:
			return
		var kind: StringName = pool[room.roll(salt, 10 + i) % pool.size()]
		var target: float = (
			rect.position.x + 1 + (room.roll(salt, 40 + i) % maxi(rect.size.x - 2, 1))
		)
		var variant: int = room.roll(salt, 70 + i)
		match kind:
			&"stalactite":
				var offset: int = variant % 5 - 2
				var part: String = LabyrinthTiles.STRATA[room.band]
				_ceiling_prop(room, kind, "stalactite", part, ceiling_free, target, offset)
			&"mushroom":
				var part: String = "brown" if variant % 2 == 0 else "red"
				_floor_prop(room, kind, "mushroom", part, 1, floor_free, target)
			&"crate":
				_floor_prop(room, kind, "crate", "broken", 1, floor_free, target)
			&"puddle":
				_floor_prop(room, kind, "puddle", "water", 1, floor_free, target)
			&"glow_mushroom":
				var green: bool = variant % 3 == 0
				var part: String = "glow_green" if green else "glow_cyan"
				_glowing(
					_floor_prop(room, kind, "mushroom", part, 1, floor_free, target),
					&"green" if green else &"cyan"
				)
			&"crystal":
				var orchid: bool = variant % 3 == 0
				var part: String = "orchid" if orchid else "cyan"
				_glowing(
					_floor_prop(room, kind, "crystal", part, 1, floor_free, target),
					&"orchid" if orchid else &"cyan"
				)


## Gives the START chamber's campfire its flames, its light and its embers.
func _light_campfire(room: AmbienceRoom, prop: AmbienceProp) -> void:
	if prop == null:
		return
	for frame: int in 4:
		prop.frames.append(_sheet("campfire").part(StringName("flame_%d" % frame)))
	prop.flame = true
	prop.frame_rate = AmbienceLevel.FLAME_RATE
	prop.light = AmbienceLight.new(
		&"campfire",
		prop.rect.position + Vector2(12, 13),
		AmbienceLevel.CAMPFIRE_RADIUS,
		AmbienceLevel.CAMPFIRE_ENERGY,
		AmbienceMood.band_tint(room.band).lerp(Palette.color(&"orange"), 0.3),
		AmbienceLevel.CAMPFIRE_FLICKER,
		room.roll(3, roundi(prop.rect.position.x))
	)
	room.emitters.append(prop)


## Makes a placed prop shine on its own (drawn over the darkness) in [param tint], and light its
## corner while the level has light to spare.
func _glowing(prop: AmbienceProp, tint: StringName) -> void:
	if prop == null:
		return
	prop.frames.append(prop.texture)
	prop.texture = null
	if _glow_lights >= AmbienceLevel.MAX_GLOW_LIGHTS:
		return
	_glow_lights += 1
	prop.light = AmbienceLight.new(
		&"glow",
		prop.rect.get_center(),
		AmbienceLevel.GLOW_RADIUS,
		AmbienceLevel.GLOW_ENERGY,
		Palette.color(tint),
		0.0,
		0
	)

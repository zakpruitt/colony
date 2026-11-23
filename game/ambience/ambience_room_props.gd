class_name AmbienceRoomProps
extends RefCounted
## The props that say what kind a room is, placed for [AmbienceLevel]: START a campfire between
## bedrolls; DEN corner webs, a hanging spider, bones, a skull and a nest; VAULT a chest among
## piles of coins under a gleam. A PLAIN room and a cache room have none. What else a room holds
## is [AmbienceDresser]'s.

const TILE: int = LabyrinthView.TILE


## The props of [param room] by its kind.
static func place(room: AmbienceRoom) -> void:
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
	var salt: int = chamber.index * 101
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


static func _floor_prop(
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


static func _ceiling_prop(
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


static func _web_corner(room: AmbienceRoom, part_name: String, column: int) -> void:
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
static func _place_hoard(room: AmbienceRoom, floor_free: Array[int], centre: float) -> void:
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


## Gives the START chamber's campfire its flames, its light and its embers.
static func _light_campfire(room: AmbienceRoom, prop: AmbienceProp) -> void:
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

class_name AmbienceDresser
extends RefCounted
## Dresses the rooms of one level from [AmbienceDecor]'s table: draws each room's list of kinds
## and stands each where it fits. One is made for a level and dresses its rooms in turn.
##
## A decoration fits where its rectangle meets nothing that stands in the room (a ladder's
## columns, a doorway and what is over it, a tunnel's mouth, a gate, a cache, a side quest's
## prop, the room's own props, the tiles round a torch's flame, another decoration), lies in no
## earth, and, tall and on the floor of a small room, is out of the middle third, where the
## fight is. Everything comes from the level's seed, so a room is dressed the same every build.

const TILE: int = LabyrinthView.TILE
## Tries at standing a decoration, for each one a room is to hold.
const TRIES: int = 4
## A thing on the floor taller than this many pixels keeps out of the middle third of a room
## no wider than this many columns.
const TALL: float = 12.0
const SMALL_ROOM: int = 12
## The columns between the pillars of a colonnade, least and most.
const PITCH: Vector2i = Vector2i(3, 8)
## Pixels of a hanging thing sunk into the ragged ceiling.
const HUNG: float = 2.0

var _table: Array[Dictionary]
## Glowing decorations lit so far on the level.
var _glow_lights: int = 0
## Of the room being dressed: the room, its area's rows, what nothing may meet, how many more
## decorations it may hold, the dips that hold a group, and whether its colonnade stands.
var _room: AmbienceRoom
var _rows: Array = []
var _kept: Array[Rect2] = []
var _left: int = 0
var _gathered: Dictionary[int, bool] = {}
var _colonnaded: bool = false
## The palette colour each decoration that glows will shine in, until it is in the room.
var _tints: Dictionary[AmbienceProp, StringName] = {}


func _init(table: Array[Dictionary]) -> void:
	_table = table


## Dresses [param room], its rolls salted with [param salt]; more sparsely if [param sparse].
func dress(room: AmbienceRoom, salt: int, sparse: bool) -> void:
	_room = room
	_rows = AmbienceDecor.rows(_table, room.band)
	if _rows.is_empty():
		return
	_kept = room.kept.duplicate()
	for i: int in range(room.first_torch, room.torches.size()):
		# The flame's tile and the eight round it.
		var flame := Vector2i((room.torches[i].light.position / TILE).floor())
		_kept.append(Rect2((flame - Vector2i.ONE) * TILE, Vector2(3, 3) * TILE))
	for i: int in range(room.first_prop, room.props.size()):
		_kept.append(room.props[i].rect)
	_gathered.clear()
	_tints.clear()
	_colonnaded = false
	var columns: int = room.chamber.rect.size.x
	var count: int = AmbienceDecor.amount(_table, room.band, columns, sparse, room.roll(salt, 3))
	_left = count
	# What stands in a row has the first choice of columns; then the rest.
	for rowed: bool in [true, false]:
		for i: int in count * TRIES:
			if _left <= 0:
				break
			var row: Array = AmbienceDecor.pick(_rows, room.roll(salt, 100 + i))
			if AmbienceDecor.more(row).has(AmbienceDecor.COLONNADE) == rowed:
				_try(row, room.roll(salt, 300 + i), room.roll(salt, 500 + i))
	if _left == count:
		# A room where chance found no place still holds the first thing that fits anywhere.
		for row: Array in _rows:
			if _try(row, 0, room.roll(salt, 700)):
				break


## Stands one of [param row] (or its group, pair or colonnade) in the first column that takes
## it, looking from the column [param where] picks. False if none does.
func _try(row: Array, where: int, variant: int) -> bool:
	var more: Dictionary = AmbienceDecor.more(row)
	if more.has(AmbienceDecor.COLONNADE):
		return _colonnade(row, more, variant)
	var rect: Rect2i = _room.chamber.rect
	var columns: Array[int] = []
	if more.has(AmbienceDecor.CORNER):
		columns = [rect.position.x, rect.end.x - 1]
	else:
		columns.assign(range(rect.position.x + 1, rect.end.x - 1))
	for i: int in columns.size():
		if _stand(row, more, columns[(where + i) % columns.size()], variant):
			return true
	return false


func _stand(row: Array, more: Dictionary, column: int, variant: int) -> bool:
	if more.has(AmbienceDecor.CORNER):
		variant = 0 if column == _room.chamber.rect.position.x else 1
	if more.has(AmbienceDecor.GATHER) and _room.dip_at(column).x >= 0:
		return _gather(row, more, column, variant)
	var shift: int = 0
	if (
		row[AmbienceDecor.PLACE] == AmbienceDecor.Place.CEILING
		and not more.has(AmbienceDecor.CORNER)
	):
		shift = (variant >> 8) % 5 - 2
	var prop: AmbienceProp = _fit(row, more, column, variant, shift)
	if prop == null:
		return false
	var paired: bool = (
		more.has(AmbienceDecor.PAIR)
		and _left >= 2
		and (variant >> 12) % 100 < AmbienceDecor.PAIR_PERCENT
	)
	if paired and (variant >> 20) % 100 < AmbienceDecor.JOIN_PERCENT and _join(column, variant):
		return true
	_commit(prop)
	if paired:
		_pair(more, column, variant)
	if more.has(AmbienceDecor.CLUSTER):
		var size: Vector2i = more[AmbienceDecor.CLUSTER]
		var others: int = size.x + (variant >> 12) % (size.y - size.x + 1) - 1
		for way: int in [1, -1]:
			var at: int = column + way
			while others > 0 and _left > 0:
				var beside: AmbienceProp = _fit(row, more, at, (variant >> 3) + at, 0)
				if beside == null:
					break
				_commit(beside)
				others -= 1
				at += way
	return true


## Stands a kind that reaches from floor to ceiling in [param column], where the area has one
## and the ceiling is the height for it. False if none stands.
func _join(column: int, variant: int) -> bool:
	for row: Array in _rows:
		var more: Dictionary = AmbienceDecor.more(row)
		if row[AmbienceDecor.PLACE] != AmbienceDecor.Place.SPAN or not more.has(AmbienceDecor.GAP):
			continue
		var prop: AmbienceProp = _fit(row, more, column, variant, 0)
		if prop != null:
			_commit(prop)
			return true
	return false


## Stands the other half of a pair in [param column], if the area has it and it fits.
func _pair(more: Dictionary, column: int, variant: int) -> void:
	var kind: StringName = more[AmbienceDecor.PAIR]
	var other: Array = AmbienceDecor.row_of(_rows, kind)
	if other.is_empty() or _left <= 0:
		return
	var other_more: Dictionary = AmbienceDecor.more(other)
	if other_more.has(AmbienceDecor.GATHER) and _room.dip_at(column).x >= 0:
		return
	var prop: AmbienceProp = _fit(other, other_more, column, variant >> 5, 0)
	if prop != null:
		_commit(prop)


## Hangs a group of [param row] under the dip that holds [param column]: two or more, side by
## side from that column out, each of the next part. False if the dip has its group, or fewer
## than two fit.
func _gather(row: Array, more: Dictionary, column: int, variant: int) -> bool:
	var dip: Vector2i = _room.dip_at(column)
	var size: Vector2i = more[AmbienceDecor.GATHER]
	var count: int = mini(size.x + (variant >> 12) % (size.y - size.x + 1), _left)
	if _gathered.has(dip.x) or count < 2:
		return false
	var canvas: int = PixelSheet.load_sheet(_sheet_path(row)).size.x
	# Two hang in a column where two of them are no wider than it.
	var places: Array[Vector2i] = []
	for at: int in range(dip.x, dip.y + 1):
		if canvas * 2 <= TILE:
			places.append(Vector2i(at, -canvas / 2))
			places.append(Vector2i(at, canvas / 2))
		else:
			places.append(Vector2i(at, 0))
	places.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var near_a: int = absi((a.x - column) * TILE + a.y)
			var near_b: int = absi((b.x - column) * TILE + b.y)
			return near_a < near_b or (near_a == near_b and a < b)
	)
	var hung: Array[AmbienceProp] = []
	for place: Vector2i in places:
		if hung.size() >= count:
			break
		var prop: AmbienceProp = _fit(row, more, place.x, variant + hung.size(), place.y)
		if prop != null:
			hung.append(prop)
	if hung.size() < 2:
		return false
	for prop: AmbienceProp in hung:
		_commit(prop)
	_gathered[dip.x] = true
	return true


## Stands [param row] as a colonnade: the longest row of it at one spacing that fits the room,
## the same from both walls where it can be. False if the room is too narrow, has one, or no
## two fit.
func _colonnade(row: Array, more: Dictionary, variant: int) -> bool:
	var rect: Rect2i = _room.chamber.rect
	var least: int = more[AmbienceDecor.COLONNADE]
	if _colonnaded or rect.size.x < least or _left < 2:
		return false
	var free: Dictionary[int, bool] = {}
	for column: int in range(rect.position.x + 1, rect.end.x - 1):
		if _fit(row, more, column, variant, 0) != null:
			free[column] = true
	# The best row of columns: (first, spacing, how many), by how many, then evenness, then reach.
	var best := Vector3i(-1, 0, 0)
	var best_score: int = 0
	for pitch: int in range(PITCH.x, PITCH.y + 1):
		for first: int in free:
			var many: int = 1
			while many < _left and free.has(first + many * pitch):
				many += 1
			var last: int = first + (many - 1) * pitch
			var even: bool = first - rect.position.x == rect.end.x - 1 - last
			var score: int = many * 1000 + (500 if even else 0) + (last - first)
			if many >= 2 and score > best_score:
				best = Vector3i(first, pitch, many)
				best_score = score
	if best.x < 0:
		return false
	for i: int in best.z:
		_commit(_fit(row, more, best.x + i * best.y, variant, 0))
	_colonnaded = true
	return true


## One of [param row] as it would stand in [param column] ([param shift] pixels aside), or null
## if it does not fit there. It is not yet in the room.
func _fit(row: Array, more: Dictionary, column: int, variant: int, shift: int) -> AmbienceProp:
	var place: AmbienceDecor.Place = row[AmbienceDecor.PLACE]
	var sheet: PixelSheet = PixelSheet.load_sheet(_sheet_path(row))
	var size := Vector2(sheet.size)
	var ceiling_px: float = _room.ceiling_px(column)
	var part: String = AmbienceDecor.part(row, variant, _room.band)
	var at := Vector2(column * TILE + floorf((TILE - size.x) * 0.5) + shift, 0.0)
	var anchor: AmbienceProp.Anchor = AmbienceProp.Anchor.FLOOR
	var sink: float = more.get(AmbienceDecor.SINK, 0)
	match place:
		AmbienceDecor.Place.FLOOR:
			at.y = _room.floor_px - size.y + sink
		AmbienceDecor.Place.CEILING:
			anchor = AmbienceProp.Anchor.CEILING
			at.y = ceiling_px - HUNG
		AmbienceDecor.Place.SPAN:
			anchor = AmbienceProp.Anchor.CEILING
			at.y = ceiling_px - HUNG
			var rows: int = roundi((_room.floor_px - ceiling_px) / TILE)
			if more.has(AmbienceDecor.GAP):
				var gap: Vector2i = more[AmbienceDecor.GAP]
				if rows < gap.x or rows > gap.y:
					return null
				part = AmbienceDecor.part(row, rows - gap.x, _room.band)
		AmbienceDecor.Place.BACK:
			anchor = AmbienceProp.Anchor.BACK
			at.y = _room.floor_px - (AmbienceLevel.TORCH_ROWS_ABOVE_FLOOR + 1) * TILE
	var top: StringName = (
		StringName(part + "_top") if place == AmbienceDecor.Place.SPAN else StringName(part)
	)
	var texture: AtlasTexture = sheet.part(top)
	var flip: bool = place == AmbienceDecor.Place.FLOOR and _room.roll(7, column) % 2 == 0
	var box: Rect2i = SpriteBounds.opaque(texture)
	if flip:
		box.position.x = sheet.size.x - box.end.x
	var rect := Rect2(at + Vector2(box.position), Vector2(box.size))
	if place == AmbienceDecor.Place.SPAN:
		rect.size.y = _room.floor_px - rect.position.y
	if not _clear(rect, more.has(AmbienceDecor.CORNER)):
		return null
	var hung: float = HUNG if anchor == AmbienceProp.Anchor.CEILING else 0.0
	if not _open(rect.grow_individual(0.0, -hung, 0.0, -sink)):
		return null
	var kind: StringName = row[AmbienceDecor.KIND]
	var prop := AmbienceProp.new(kind, _room.chamber.index, rect, anchor)
	prop.decor = true
	prop.drawn_at = at
	prop.texture = texture
	prop.flip = flip
	if place == AmbienceDecor.Place.SPAN:
		prop.foot = sheet.part(StringName(part + "_foot"))
		if sheet.has_part(StringName(part + "_shaft")):
			prop.shaft = sheet.part(StringName(part + "_shaft"))
	if more.has(AmbienceDecor.GLOW):
		var tints: Array = more[AmbienceDecor.GLOW]
		_tints[prop] = tints[posmod(variant, tints.size())]
	return prop


static func _sheet_path(row: Array) -> String:
	var sheet: String = row[AmbienceDecor.SHEET]
	return AmbienceLevel.DIR + sheet + ".png"


## True if [param rect] is in nothing's way: between the walls (or, [param cornered], in a
## wall's column), meeting nothing kept, and, tall on the floor of a small room, out of its
## middle third.
func _clear(rect: Rect2, cornered: bool) -> bool:
	var room: Rect2i = _room.chamber.rect
	var inset: int = 0 if cornered else 1
	if rect.position.x < (room.position.x + inset) * TILE:
		return false
	if rect.end.x > (room.end.x - inset) * TILE:
		return false
	for kept: Rect2 in _kept:
		if kept.intersects(rect):
			return false
	if room.size.x > SMALL_ROOM or rect.size.y <= TALL or rect.end.y < _room.floor_px:
		return true
	var third: float = room.size.x * TILE / 3.0
	return (
		rect.end.x <= room.position.x * TILE + third or rect.position.x >= room.end.x * TILE - third
	)


## True if every tile [param body] reaches is open.
func _open(body: Rect2) -> bool:
	for y: int in range(floori(body.position.y / TILE), ceili(body.end.y / TILE)):
		for x: int in range(floori(body.position.x / TILE), ceili(body.end.x / TILE)):
			if not _room.is_open(Vector2i(x, y)):
				return false
	return true


## Puts [param prop] in the room: nothing later may meet it, and what glows is lit while the
## level has light to spare.
func _commit(prop: AmbienceProp) -> void:
	_room.props.append(prop)
	_kept.append(prop.rect)
	_left -= 1
	if not _tints.has(prop):
		return
	var tint: StringName = _tints[prop]
	# Drawn over the darkness, so it shines on its own.
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

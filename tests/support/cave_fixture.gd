extends ColonyTest
## For tests of what stands in the rooms of winding, zoned stages: the four areas, their stages
## as drawn and dressed, and the rooms and decorations of one.

const TILE: int = LabyrinthView.TILE
const MOSSY: StringName = &"mossy_hollow"
const CLAY: StringName = &"claypits"
const CRYPT: StringName = &"old_crypt"
const EMBER: StringName = &"ember_deep"
const AREAS: Array[StringName] = [MOSSY, CLAY, CRYPT, EMBER]
## The stages of a seed that are looked at.
const STAGES: int = 4


## The winding labyrinth of [param area] for [param seed_value], as the game makes it.
func area_labyrinth(seed_value: int, area: StringName) -> Labyrinth:
	return winding_labyrinth(seed_value, AreaTravel.label(area))


## The decoration of [param stage] as an ambience over [param view] places it.
func dressed_stage(view: LabyrinthView, stage: int) -> AmbienceLevel:
	var ambience := Ambience.new()
	add_child_autofree(ambience)
	ambience.set_process(false)
	ambience.setup(view)
	return ambience.level(stage)


## Calls [param each] with (what, area, level, view, dressed) for stages 1 to [constant STAGES]
## of [param seeds] seeds, each seed in one of the four areas in turn.
func each_dressed_stage(seeds: int, each: Callable) -> void:
	for seed_value: int in range(1, seeds + 1):
		var area: StringName = AREAS[seed_value % AREAS.size()]
		var labyrinth: Labyrinth = area_labyrinth(seed_value, area)
		for stage: int in range(1, STAGES + 1):
			var view: LabyrinthView = zoned_view(labyrinth, stage, area)
			var what: String = "%s seed %d stage %d" % [area, seed_value, stage]
			each.call(what, area, labyrinth.level(stage), view, dressed_stage(view, stage))
			view.free()


## Calls [param each] with (what, level, view, dressed, room) for the first [param count] rooms
## of [param area], from stage 1 of seed 1 on.
func each_room_of(area: StringName, count: int, each: Callable) -> void:
	var labyrinth: Labyrinth = area_labyrinth(1, area)
	var seen: int = 0
	var stage: int = 1
	while seen < count:
		var view: LabyrinthView = zoned_view(labyrinth, stage, area)
		var level: LabyrinthLevel = labyrinth.level(stage)
		var dressed: AmbienceLevel = dressed_stage(view, stage)
		for room: LabyrinthChamber in stage_rooms(level):
			if seen < count:
				var what: String = "%s stage %d room %s" % [area, stage, room.rect]
				each.call(what, level, view, dressed, room)
				seen += 1
		view.free()
		stage += 1


## The rooms of [param level]: those of its route, then its side paths' cache rooms.
static func stage_rooms(level: LabyrinthLevel) -> Array[LabyrinthChamber]:
	var rooms: Array[LabyrinthChamber] = level.chambers.duplicate()
	for path: SidePath in level.side_paths:
		rooms.append(path.room)
	return rooms


## [param room] in world pixels.
static func room_pixels(room: LabyrinthChamber) -> Rect2:
	return Rect2(room.rect.position * TILE, room.rect.size * TILE)


## The props of [param dressed] that stand in [param room], in the order they were placed: its
## decorations ([param decor]) or the props that say what kind of room it is.
static func props_of(
	dressed: AmbienceLevel, room: LabyrinthChamber, decor: bool
) -> Array[AmbienceProp]:
	var found: Array[AmbienceProp] = []
	if room.index >= 0:
		for prop: AmbienceProp in dressed.props:
			if prop.chamber == room.index and prop.decor == decor:
				found.append(prop)
		return found
	# Cache rooms share an index: theirs are told by where they stand.
	var pixels := Rect2(
		room.rect.position.x * TILE,
		(room.rect.end.y - RoomShape.MOST_ROWS) * TILE,
		room.rect.size.x * TILE,
		RoomShape.MOST_ROWS * TILE + 2.0
	)
	for prop: AmbienceProp in dressed.cache_props:
		if prop.decor == decor and pixels.intersects(prop.rect):
			found.append(prop)
	return found


## The names of [param props], in order.
static func names_of(props: Array[AmbienceProp]) -> Array[StringName]:
	var names: Array[StringName] = []
	for prop: AmbienceProp in props:
		names.append(prop.name)
	return names


## The world row of the highest open tile of [param column] over the floor of [param room], as
## [param view] answers.
static func open_top(view: LabyrinthView, room: LabyrinthChamber, column: int) -> int:
	var row: int = room.floor_row()
	while view.is_open(Vector2i(column, row - 1)) and row > room.floor_row() - 16:
		row -= 1
	return row


## The column the middle of [param prop] is in.
static func column_of(prop: AmbienceProp) -> int:
	return floori(prop.rect.get_center().x / TILE)

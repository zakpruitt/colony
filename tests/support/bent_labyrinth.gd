class_name BentLabyrinth
extends Labyrinth
## A hand-made labyrinth whose course bends, for tests: every depth holds the same two rooms, the
## second below the first, joined by a ladder down their right-hand columns. The course walks the
## first room from left to right, goes down the ladder and walks the second from right to left.
## Its distance starts at 0, so no distance on it is its own column.
##
## The caller says which room is which: the room the way on leaves from (the guardian's, on a
## guardian's stage) and the room a party arrives in. A room that is neither is a plain one.

## The rooms of depth 1; each depth below stands [constant BAND] rows lower.
const UPPER: Rect2i = Rect2i(4, 6, 20, 5)
const LOWER: Rect2i = Rect2i(8, 16, 16, 5)
const BAND: int = 32
const LADDER_COLUMN: int = 23
## Distances along the course: the ladder's top (the first room's last), its foot (the second
## room's first) and the end of the line.
const LADDER_TOP: float = 19.0
const LADDER_FOOT: float = 29.0
const END: float = 44.0
## Where the party arrives and where the way on leaves, by the room each is in.
const ENTRIES: Array[float] = [3.0, 41.0]
const EXITS: Array[float] = [15.0, 40.0]

var _exit_room: int
var _entry_room: int
var _made: Dictionary[int, LabyrinthLevel] = {}


## The way on leaves from room [param exit_room] and a party arrives in room [param entry_room]
## (0 the first room, 1 the second).
func _init(exit_room: int, entry_room: int = 0) -> void:
	super(1)
	_exit_room = exit_room
	_entry_room = entry_room


func level(depth: int) -> LabyrinthLevel:
	if not _made.has(depth):
		_made[depth] = _made_at(depth)
	return _made[depth]


## The floor row of room [param room] at [param depth].
static func floor_row(depth: int, room: int) -> int:
	var rect: Rect2i = UPPER if room == 0 else LOWER
	return rect.end.y - 1 + (depth - 1) * BAND


## True if [param feet] is on the course of [param depth]: on either floor or on the ladder.
static func on_course(depth: int, feet: Vector2) -> bool:
	var upper: float = floor_row(depth, 0)
	var lower: float = floor_row(depth, 1)
	var column: float = LADDER_COLUMN
	if is_equal_approx(feet.y, upper):
		return feet.x >= UPPER.position.x - 0.001 and feet.x <= column + 0.001
	if is_equal_approx(feet.y, lower):
		return feet.x >= LOWER.position.x - 0.001 and feet.x <= column + 0.001
	return is_equal_approx(feet.x, column) and feet.y > upper and feet.y < lower


func _made_at(depth: int) -> LabyrinthLevel:
	var made := LabyrinthLevel.new()
	made.depth = depth
	made.floor_y = floor_row(depth, 0)
	var drop := Vector2i(0, (depth - 1) * BAND)
	for rect: Rect2i in [UPPER, LOWER]:
		var room := LabyrinthChamber.new()
		room.index = made.chambers.size()
		room.kind = LabyrinthChamber.Kind.PLAIN
		room.rect = Rect2i(rect.position + drop, rect.size)
		made.chambers.append(room)
	var upper: float = floor_row(depth, 0)
	var lower: float = floor_row(depth, 1)
	var course := StageCourse.new()
	course.begin(Vector2(UPPER.position.x, upper), 0.0)
	course.line_to(Vector2(LADDER_COLUMN, upper), 0)
	course.line_to(Vector2(LADDER_COLUMN, lower))
	course.line_to(Vector2(LOWER.position.x, lower), 1)
	course.entry = ENTRIES[_entry_room]
	course.exit = EXITS[_exit_room]
	made.course = course
	return made

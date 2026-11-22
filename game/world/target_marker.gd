class_name TargetMarker
extends Node2D
## A small arrow bobbing above the party that points the way to its target stage: the way it must
## next travel along the stage's course to reach the doorway it will leave by (the way on for a
## further target, the way back for an earlier one). That is sideways along a floor, and up or
## down only at a ladder inside the stage; it never points at a stage above or below. It hides in
## a fight, while the party is down, during a crossing and once the party is at its target stage.
## Drawn in code, pixel by pixel, in [code]yellow[/code] (the HUD's colour for the target) with an
## [code]ink[/code] outline.
##
## The world places it over the party's heads each frame through [method follow]; it moves only
## there, so a test can step it exactly.

## How far above the party's feet the arrow's tip hangs, in pixels.
const HEIGHT: float = 38.0
## How far it bobs, in whole pixels, and how many times a second.
const BOB_PIXELS: float = 2.0
const BOB_PER_SECOND: float = 1.5
## How far along the course, in tiles, the arrow looks for the way the party travels next: at
## the head of a ladder it already points along the ladder.
const AHEAD: float = 0.5
## The arrow, row by row: F fill, O outline, . nothing, with its tip at the bottom centre. It is
## drawn as it is pointing down, upside down pointing up, and turned on its side, each row a
## column, pointing right or, mirrored, left.
const SHAPE: Array[String] = [
	"...OOO...",
	"...OFO...",
	"...OFO...",
	"...OFO...",
	"OOOOFOOOO",
	"OFFFFFFFO",
	".OFFFFFO.",
	"..OFFFO..",
	"...OFO...",
	"....O....",
]

var _pointing: int = 0
var _heading: Vector2i = Vector2i.ZERO
var _age: float = 0.0


func _init() -> void:
	name = "TargetMarker"
	visible = false


## Follows [param simulation]'s party: shown over [param party_feet] (the middle of the party,
## at its feet) while it heads for another depth, and moved on by [param delta] seconds.
func follow(simulation: Simulation, party_feet: Vector2, delta: float) -> void:
	var expedition: Expedition = simulation.expedition
	var way: int = signi(expedition.target_depth - expedition.depth)
	var busy: bool = (
		expedition.state == Expedition.State.FIGHTING
		or expedition.state == Expedition.State.REVIVING
		or expedition.state == Expedition.State.CLIMBING
		or expedition.state == Expedition.State.JOURNEYING
		or not party_feet.is_finite()
	)
	_pointing = 0 if busy else way
	var shown: Vector2i = Vector2i.ZERO
	if _pointing != 0:
		shown = _way_to_the_door(expedition, way, party_feet)
	if shown != _heading:
		_heading = shown
		queue_redraw()
	visible = _pointing != 0
	_age = _age + delta if visible else 0.0
	var bob: float = roundf(BOB_PIXELS * (0.5 + 0.5 * sin(_age * TAU * BOB_PER_SECOND)))
	if party_feet.is_finite():
		position = (party_feet + Vector2(0, -HEIGHT - bob)).round()


## 1 while showing the way on (a further target), -1 the way back, 0 while hidden.
func pointing() -> int:
	return _pointing


## Which way the arrow points across the screen: 1 right, -1 left, 0 while it points up or down
## a ladder or is hidden.
func side() -> int:
	return _heading.x


## The way the arrow points on screen, as a step in x and y (y down); zero while hidden.
func heading() -> Vector2i:
	return _heading


## The way [param run]'s party, drawn at [param party_feet], travels next along its stage's
## course toward the doorway it leaves by, [param way] 1 on or -1 back.
static func _way_to_the_door(run: Expedition, way: int, party_feet: Vector2) -> Vector2i:
	var line: StageCourse = PartyPlaces.course(run)
	var door: float = line.exit if way > 0 else line.entry
	var here: Vector2 = line.point_at(run.x)
	var next: Vector2 = line.point_at(move_toward(run.x, door, AHEAD))
	if absf(next.y - here.y) > absf(next.x - here.x):
		return Vector2i(0, 1 if next.y > here.y else -1)
	var aim: Vector2 = line.point_at(door)
	var across: int = signi(roundi((next.x - here.x) * LabyrinthView.TILE))
	if is_equal_approx(aim.y, here.y):
		# The doorway is on this floor: toward it from where the party is drawn.
		across = signi(roundi(aim.x * LabyrinthView.TILE - party_feet.x))
	return Vector2i(across if across != 0 else PartyPlaces.world_facing(run), 0)


func _draw() -> void:
	if _heading == Vector2i.ZERO:
		return
	var rows: int = SHAPE.size()
	var width: int = SHAPE[0].length()
	for row: int in rows:
		var line: String = SHAPE[row]
		for column: int in width:
			var cell: String = line[column]
			if cell == ".":
				continue
			var at := Vector2i(column - width / 2, row - rows)
			if _heading.y < 0:
				at.y = -1 - row
			elif _heading.x != 0:
				# Row r becomes a column: r - rows / 2 to the right (the tip rightmost), or mirrored.
				at = Vector2i(
					row - rows / 2 if _heading.x > 0 else rows / 2 - 1 - row, column - width
				)
			var colour: Color = Palette.color(&"yellow" if cell == "F" else &"ink")
			draw_rect(Rect2(at, Vector2i.ONE), colour)

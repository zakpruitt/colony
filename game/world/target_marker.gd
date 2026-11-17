class_name TargetMarker
extends Node2D
## A small arrow bobbing above the party that points the way to its target stage (spec 027 R5).
## Spec 054: it points sideways, toward the doorway the party will leave by (the way on for a
## further target, the way back for an earlier one), never up or down. It hides in a fight,
## while the party is down, during a crossing and once the party is at its target stage. Drawn in
## code, pixel by pixel, in [code]yellow[/code] (the HUD's colour for the target) with an
## [code]ink[/code] outline.
##
## The world places it over the party's heads each frame through [method follow]; it moves only
## there, so a test can step it exactly.

## How far above the party's feet the arrow's tip hangs, in pixels.
const HEIGHT: float = 38.0
## How far it bobs, in whole pixels, and how many times a second.
const BOB_PIXELS: float = 2.0
const BOB_PER_SECOND: float = 1.5
## The arrow, row by row: F fill, O outline, . nothing, with its tip at the bottom centre. It is
## drawn turned on its side, each row a column: pointing right, or mirrored, left.
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
var _side: int = 0
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
	_side = 0
	if _pointing != 0:
		var stage: int = expedition.depth if way > 0 else expedition.depth - 1
		var door: float = simulation.labyrinth.shaft_column(stage) + Labyrinth.SHAFT_WIDTH / 2.0
		_side = signi(roundi(door * LabyrinthView.TILE - party_feet.x))
		if _side == 0:
			_side = expedition.facing
	visible = _pointing != 0
	_age = _age + delta if visible else 0.0
	var bob: float = roundf(BOB_PIXELS * (0.5 + 0.5 * sin(_age * TAU * BOB_PER_SECOND)))
	if party_feet.is_finite():
		position = (party_feet + Vector2(0, -HEIGHT - bob)).round()
	queue_redraw()


## 1 while showing the way on (a further target), -1 the way back, 0 while hidden.
func pointing() -> int:
	return _pointing


## Which way the arrow points on screen: 1 right, -1 left (toward the doorway), 0 while hidden.
func side() -> int:
	return _side


func _draw() -> void:
	if _side == 0:
		return
	var rows: int = SHAPE.size()
	var width: int = SHAPE[0].length()
	for row: int in rows:
		var line: String = SHAPE[row]
		# Row r becomes a column: r - rows / 2 to the right (the tip rightmost), or mirrored.
		var x: int = row - rows / 2 if _side > 0 else rows / 2 - 1 - row
		for column: int in width:
			var cell: String = line[column]
			if cell == ".":
				continue
			var colour: Color = Palette.color(&"yellow" if cell == "F" else &"ink")
			draw_rect(Rect2(x, column - width, 1, 1), colour)

class_name TargetMarker
extends Node2D
## A small arrow bobbing above the party that points the way to its target depth (spec 027 R5):
## down for a deeper target, up for a shallower one. It hides in a fight, while the party is down
## and once the party is at its target depth. Drawn in code, pixel by pixel, in
## [code]yellow[/code] (the HUD's colour for the target) with an [code]ink[/code] outline.
##
## The world places it over the party's heads each frame through [method follow]; it moves only
## there, so a test can step it exactly.

## How far above the party's feet the arrow's tip hangs, in pixels.
const HEIGHT: float = 38.0
## How far it bobs, in whole pixels, and how many times a second.
const BOB_PIXELS: float = 2.0
const BOB_PER_SECOND: float = 1.5
## The arrow pointing down, row by row: F fill, O outline, . nothing. Pointing up is the same
## upside down. Its tip is the bottom centre.
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
		or not party_feet.is_finite()
	)
	_pointing = 0 if busy else way
	visible = _pointing != 0
	_age = _age + delta if visible else 0.0
	var bob: float = roundf(BOB_PIXELS * (0.5 + 0.5 * sin(_age * TAU * BOB_PER_SECOND)))
	if party_feet.is_finite():
		position = (party_feet + Vector2(0, -HEIGHT - bob)).round()
	queue_redraw()


## 1 while pointing down, -1 while pointing up, 0 while hidden.
func pointing() -> int:
	return _pointing


func _draw() -> void:
	if _pointing == 0:
		return
	var rows: int = SHAPE.size()
	var half: int = SHAPE[0].length() / 2
	for row: int in rows:
		var line: String = SHAPE[row if _pointing > 0 else rows - 1 - row]
		for column: int in line.length():
			var cell: String = line[column]
			if cell == ".":
				continue
			var colour: Color = Palette.color(&"yellow" if cell == "F" else &"ink")
			draw_rect(Rect2(column - half, row - rows, 1, 1), colour)

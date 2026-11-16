class_name LabyrinthLevel
extends RefCounted
## One depth of the labyrinth: chambers joined by tunnels along one floor row, and a shaft down.

var depth: int
## World row of the floor: the lowest open row of every chamber and tunnel.
var floor_y: int
## Left to right.
var chambers: Array[LabyrinthChamber] = []
## Left to right; tunnels[i] joins chambers[i] and chambers[i + 1].
var tunnels: Array[Rect2i] = []
var shaft_down: Rect2i


## The chamber whose columns include this one, or null inside a tunnel or solid earth.
func chamber_at(column: int) -> LabyrinthChamber:
	for chamber: LabyrinthChamber in chambers:
		if column >= chamber.rect.position.x and column < chamber.rect.end.x:
			return chamber
	return null


## The chamber the shaft down leaves from.
func shaft_chamber() -> LabyrinthChamber:
	return chamber_at(shaft_down.position.x)


## Every open rectangle of this level: chambers, tunnels, then the shaft down.
func open_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for chamber: LabyrinthChamber in chambers:
		rects.append(chamber.rect)
	rects.append_array(tunnels)
	rects.append(shaft_down)
	return rects

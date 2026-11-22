class_name LabyrinthLevel
extends RefCounted
## One depth of the labyrinth. A flat one is chambers joined by tunnels along one floor row, and
## a shaft down; a winding one is rooms on several floors, in the order its course walks them,
## joined by tunnels and ladders.

var depth: int
## World row of the floor: the lowest open row of every chamber and tunnel. On a winding level,
## the floor row of the first room.
var floor_y: int
## Left to right; on a winding level in route order, the room a party arrives in first.
var chambers: Array[LabyrinthChamber] = []
## Left to right; tunnels[i] joins chambers[i] and chambers[i + 1]. On a winding level in route
## order, one for each pair of neighbouring rooms on the same floor.
var tunnels: Array[Rect2i] = []
## The shaft to the next level; no rectangle at all on a winding level.
var shaft_down: Rect2i
## The world rows and columns the level lies in.
var band: Rect2i
## The ladders inside the stage, each from the row under the upper room's floor to the lower
## room's floor row. Empty on a flat level.
var ladders: Array[Rect2i] = []
## The line a party walks through this level; every question about place on it is asked here.
var course: StageCourse
## The ways off the main route, in the order the course passes where they leave. Their rooms,
## tunnels and ladders are their own: none is in [member chambers], [member tunnels],
## [member ladders] or [method open_rects]. Empty on a flat level.
var side_paths: Array[SidePath] = []


## The chamber whose columns include this one, or null inside a tunnel or solid earth: the
## first such in route order on a winding level, where rooms stand over one another.
func chamber_at(column: int) -> LabyrinthChamber:
	for chamber: LabyrinthChamber in chambers:
		if column >= chamber.rect.position.x and column < chamber.rect.end.x:
			return chamber
	return null


## The chamber the shaft down leaves from.
func shaft_chamber() -> LabyrinthChamber:
	return chamber_at(shaft_down.position.x)


## Every open rectangle of this level: chambers, tunnels, ladders, then the shaft down if it
## has one.
func open_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for chamber: LabyrinthChamber in chambers:
		rects.append(chamber.rect)
	rects.append_array(tunnels)
	rects.append_array(ladders)
	if shaft_down.has_area():
		rects.append(shaft_down)
	return rects


## The open rectangles of the side paths: every cache room, side tunnel and side ladder.
func side_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for path: SidePath in side_paths:
		rects.append(path.room.rect)
		if path.tunnel.has_area():
			rects.append(path.tunnel)
		if path.ladder.has_area():
			rects.append(path.ladder)
	return rects


## The side paths' ladders.
func side_ladders() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for path: SidePath in side_paths:
		if path.ladder.has_area():
			rects.append(path.ladder)
	return rects

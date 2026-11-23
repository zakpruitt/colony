class_name RoomCut
extends RefCounted
## The manner one area's rooms are cut in: the numbers [RoomShape] shapes a room by. The table
## of them is [constant ZoneLook.CUTS].

## Rows between the highest and the lowest the ceiling goes in one room, at most.
var reach: int
## Rows the ceiling moves from one level run to the next: the least (x) and the most (y).
var step: Vector2i
## Columns a level run of the ceiling is wide: the least (x) and the most (y).
var run: Vector2i
## Columns at each side over which the wall leans in toward the ceiling; 0 for an upright wall.
var lean: int
## True if the upper corners are cut round, false if they are left as the walls make them.
var round_corners: bool
## True for a built ceiling: a level run at each side and one raised run between them.
var raised_middle: bool
## The chance in a hundred that the ceiling, going up or down from run to run, turns back at a
## run before it has gone as far as its reach: 0 rolls like hills, more is ragged.
var turn: int
## Columns of the ledge each wall steps in by under the ceiling, a flat step a row or two
## lower than the ceiling beside it: the least (x) and the most (y); none at (0, 0).
var ledge: Vector2i


## From a row of [constant ZoneLook.CUTS].
func _init(row: Array) -> void:
	reach = row[0]
	var least_step: int = row[1]
	var most_step: int = row[2]
	var least_run: int = row[3]
	var most_run: int = row[4]
	step = Vector2i(least_step, most_step)
	run = Vector2i(least_run, most_run)
	lean = row[5]
	round_corners = row[6]
	raised_middle = row[7]
	turn = row[8]
	var least_ledge: int = row[9]
	var most_ledge: int = row[10]
	ledge = Vector2i(least_ledge, most_ledge)

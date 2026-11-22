class_name LabyrinthChamber
extends RefCounted
## One chamber of a labyrinth level: an open rectangle standing on a floor row of the level.

## CACHE: the room at the end of a side path ([SidePath]), never one of a level's chambers.
enum Kind { START, PLAIN, DEN, VAULT, CACHE }

## Position in the level: 0 at the left, or, on a winding level, where a party arrives; -1 for
## a side path's room, which is in no level's list.
var index: int
var kind: Kind
## Open space in world tiles. rect.end.y - 1 is the floor row.
var rect: Rect2i


## The chamber's floor row: the lowest open row of its rectangle.
func floor_row() -> int:
	return rect.end.y - 1


## The first (x) and last (y) open column of the chamber's floor.
func floor_columns() -> Vector2i:
	return Vector2i(rect.position.x, rect.end.x - 1)

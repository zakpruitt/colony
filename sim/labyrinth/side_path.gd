class_name SidePath
extends RefCounted
## A way off a winding stage's main route: from a point on the main course, by a ladder of its
## own to a neighbouring floor or along the room's floor to a free wall and a tunnel of its own,
## to a cache room nothing else joins. A gate closes it ([GateDef]). Made by [SidePathLayout].

## The [GateDef] id of its gate.
var gate: StringName
## The distance along the level's main course where the side path leaves.
var at: float
## The line a party walks on it, from that point (distance 0) to the cache room's far wall. No
## part of it is in one of the level's chambers.
var course: StageCourse
## The distance along [member course] where the gate stands: the head or foot of its ladder in
## the room it leaves (0), or the mouth of its tunnel.
var gate_at: float
## The cache room (kind CACHE, index -1); not in [member LabyrinthLevel.chambers].
var room: LabyrinthChamber
## Its tunnel, or an empty rectangle.
var tunnel: Rect2i
## Its ladder, as [member LabyrinthLevel.ladders] holds one, or an empty rectangle.
var ladder: Rect2i


## True if feet at [param distance] along [member course] stand on the cache room's floor.
func in_room(distance: float) -> bool:
	if course.on_ladder(distance):
		return false
	return room.rect.has_point(Vector2i(course.point_at(distance).floor()))

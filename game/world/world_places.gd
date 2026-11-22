class_name WorldPlaces
extends RefCounted
## Where things stand on a stage, in world pixels. Every place is asked of the room it is in or
## of the stage's course, never of "the level's floor": a stage can have rooms on several floors.


## The feet pixel of a place in world tiles: the bottom of the row it stands in.
static func feet(tiles: Vector2) -> Vector2:
	return Vector2(tiles.x * World.TILE, (tiles.y + 1.0) * World.TILE)


## The pixel row feet stand on in [param room].
static func floor_line(room: LabyrinthChamber) -> float:
	return (room.floor_row() + 1) * World.TILE


## The pixel row the fighters of [param run]'s fight stand on: its chamber's floor, or, for a
## battle with no chamber (one handed to the expedition), the anchor's row.
static func fight_line(run: Expedition) -> float:
	var room: LabyrinthChamber = run.chamber()
	return floor_line(room) if room != null else feet(PartyPlaces.anchor(run)).y


## The feet pixel at which [param run]'s party will be revived.
static func revival_feet(run: Expedition) -> Vector2:
	var place: Vector3 = run.revival_place()
	return feet(run.labyrinth.level(int(place.y)).course.point_at(place.x))


## The way [param run]'s party will face in the world as it is revived: 1 right, -1 left.
static func revival_facing(run: Expedition) -> int:
	var place: Vector3 = run.revival_place()
	var heading: int = run.labyrinth.level(int(place.y)).course.heading_at(place.x)
	return int(place.z) * heading if heading != 0 else int(place.z)

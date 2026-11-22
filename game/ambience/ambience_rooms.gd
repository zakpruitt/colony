class_name AmbienceRooms
extends RefCounted
## Which rooms of the stage shown are lit: the view's own memory of where the party has been on
## this visit. A room the party's anchor has not been in is dark: its lamps (torches, the
## campfire, a hoard's gleam, a glowing prop's light) give no light and its flames are out. A
## room it steps into is lit from then on, its torches catching one after another, nearest the
## party first, each with a flare; the room's other lamps catch with the torch nearest them.
##
## It follows where the party is, never events ([method follow], once a frame). Told the party
## has arrived, it forgets the stage and lights the room the party stands in at once, with no
## flare. Told the picture is catching up on a stall, it keeps what it has and lights the room the
## party stands in now at once: the rooms passed unseen stay dark. Until it is first told of a
## party every lamp is lit, so an [Ambience] with no party to follow shows every room.
##
## A room is named by a number: a room of the route by its index, a cache room by
## [constant CACHE] plus its side path's place in the level's list.

## No room: a tunnel, a ladder, or between places.
const NONE: int = -1
const CACHE: int = 100
## Seconds from one torch catching to the next.
const CATCH_GAP: float = 0.15
## A flare: the seconds it lasts, and the lamp's reach and strength as a share of their rest when
## it catches, at its peak, and the second the peak comes.
const FLARE_SECONDS: float = 0.3
const FLARE_FROM: float = 0.4
const FLARE_PEAK: float = 1.3
const FLARE_PEAK_AT: float = 0.1
const TILE: int = LabyrinthView.TILE


## The lamps of one built level, in the order the level lists its lights, and each one's room.
class Dressing:
	extends RefCounted
	var lamps: Array[AmbienceProp] = []
	var rooms: PackedInt32Array = []


## Goes up with every change to which lamps are lit; whoever lists the lit lamps compares it.
var changes: int = 0

var _following: bool = false
## The stage remembered, the room the party was in at the last look, and the rooms lit.
var _stage: int = 0
var _maze: Labyrinth
var _room: int = NONE
var _lit: Dictionary[int, bool] = {}
var _dressed: Dictionary[int, Dressing] = {}
## Lamps yet to catch and the seconds each has to wait; lights flaring and each flare's age.
var _waiting: Array[AmbienceProp] = []
var _waits: PackedFloat32Array = []
var _flaring: Array[AmbienceLight] = []
var _ages: PackedFloat32Array = []


## The room of [param stage], the stage shown, that [param run]'s anchor is in: while it changes
## stage, the room of the doorway it stands at; [constant NONE] in a tunnel, on a ladder and on
## a journey.
static func room_of(run: Expedition, stage: int) -> int:
	if run.state == Expedition.State.JOURNEYING:
		return NONE
	if run.state == Expedition.State.CLIMBING or run.depth != stage:
		return _room_at(run.labyrinth.level(stage), PartyPlaces.anchor(run))
	var room: LabyrinthChamber = run.chamber()
	if room == null:
		return NONE
	return room.index if room.index >= 0 else CACHE + run.side_path


## Takes note of a level just built: its lamps are lit as the memory has their rooms.
func dress(decoration: AmbienceLevel, level: LabyrinthLevel) -> void:
	var dressing := Dressing.new()
	for torch: AmbienceProp in decoration.torches:
		_note(dressing, torch, torch.chamber)
	for torch: AmbienceProp in decoration.cache_torches:
		_note(dressing, torch, _cache_of(level, torch))
	for prop: AmbienceProp in decoration.props:
		_note(dressing, prop, prop.chamber)
	for prop: AmbienceProp in decoration.cache_props:
		_note(dressing, prop, _cache_of(level, prop))
	_dressed[decoration.depth] = dressing
	_apply(decoration.depth)
	changes += 1


## Forgets a level about to be freed. Whatever was catching on a level that stays is lit whole.
func strip(depth: int) -> void:
	if _dressed.erase(depth):
		_settle()
		for kept: int in _dressed:
			_apply(kept)
		changes += 1


## Looks where [param run]'s party is on [param stage], the stage shown. A room its anchor has
## stepped into since the last look starts to light. With [param arrived] (the party has just
## come to the stage, or been revived) the stage is forgotten first and the room the party
## stands in is lit whole, with no flare; so is the first look, and one at another stage or
## another area's. With [param quiet] (the picture is catching up on a stall) what was lit stays
## lit and the room the party stands in now is lit whole, with no flare.
func follow(run: Expedition, stage: int, arrived: bool, quiet: bool) -> void:
	var room: int = room_of(run, stage)
	var fresh: bool = arrived or not _following or stage != _stage or run.labyrinth != _maze
	if fresh or quiet:
		if fresh:
			_lit.clear()
		_following = true
		_stage = stage
		_maze = run.labyrinth
		_room = room
		if room != NONE:
			_lit[room] = true
		_settle()
		for depth: int in _dressed:
			_apply(depth)
		changes += 1
		return
	if room == _room:
		return
	_room = room
	if room == NONE or _lit.has(room):
		return
	_lit[room] = true
	_kindle(room, PartyPlaces.anchor(run) * TILE)


## Moves the lamps catching and the flares on by [param delta] seconds. Nothing to do, and
## nothing done, while no room is lighting.
func advance(delta: float) -> void:
	if _waiting.is_empty() and _flaring.is_empty():
		return
	var at: int = 0
	while at < _flaring.size():
		_ages[at] += delta
		if _ages[at] >= FLARE_SECONDS:
			_flaring[at].swell = 1.0
			_flaring.remove_at(at)
			_ages.remove_at(at)
		else:
			_flaring[at].swell = flare_at(_ages[at])
			at += 1
	at = 0
	while at < _waiting.size():
		_waits[at] -= delta
		if _waits[at] > 0.0001:
			at += 1
			continue
		var lamp: AmbienceProp = _waiting[at]
		lamp.lit = true
		lamp.light.swell = FLARE_FROM
		_flaring.append(lamp.light)
		_ages.append(0.0)
		_waiting.remove_at(at)
		_waits.remove_at(at)
		changes += 1


## A flaring lamp's reach and strength [param age] seconds after it caught, as a share of their
## rest: up past it, then back down to it.
static func flare_at(age: float) -> float:
	if age < FLARE_PEAK_AT:
		return lerpf(FLARE_FROM, FLARE_PEAK, age / FLARE_PEAK_AT)
	var settling: float = (age - FLARE_PEAK_AT) / (FLARE_SECONDS - FLARE_PEAK_AT)
	return lerpf(FLARE_PEAK, 1.0, clampf(settling, 0.0, 1.0))


## True if [param room] of the stage shown is lit (its torches may still be catching).
func is_lit(room: int) -> bool:
	return not _following or _lit.has(room)


## How many lamps are waiting to catch or flaring.
func flares() -> int:
	return _waiting.size() + _flaring.size()


## Adds to [param into] the lights of the lit lamps of the level at [param depth], in the
## level's own order.
func lit_lights(depth: int, into: Array[AmbienceLight]) -> void:
	var dressing: Dressing = _dressed.get(depth, null)
	if dressing == null:
		return
	for lamp: AmbienceProp in dressing.lamps:
		if lamp.lit:
			into.append(lamp.light)


func _note(dressing: Dressing, prop: AmbienceProp, room: int) -> void:
	if prop.light != null:
		dressing.lamps.append(prop)
		dressing.rooms.append(room)


## Lights or darkens every lamp of the level at [param depth] as the memory has its room.
func _apply(depth: int) -> void:
	var dressing: Dressing = _dressed[depth]
	for i: int in dressing.lamps.size():
		dressing.lamps[i].lit = (
			not _following or (depth == _stage and _lit.has(dressing.rooms[i]))
		)


## Ends every flare and forgets the lamps yet to catch, which are left out: the caller lights
## every lamp as the memory has its room ([method _apply]).
func _settle() -> void:
	for light: AmbienceLight in _flaring:
		light.swell = 1.0
	_waiting.clear()
	_waits.clear()
	_flaring.clear()
	_ages.clear()


## Starts [param room]'s lamps catching: its torches by their distance from [param from] (world
## pixels), [constant CATCH_GAP] apart, the nearest now; its other lamps with the torch nearest
## each.
func _kindle(room: int, from: Vector2) -> void:
	var dressing: Dressing = _dressed.get(_stage, null)
	if dressing == null:
		return
	var torches: Array[AmbienceProp] = []
	for i: int in dressing.lamps.size():
		if dressing.rooms[i] == room and dressing.lamps[i].name == &"torch":
			torches.append(dressing.lamps[i])
	torches.sort_custom(
		func(a: AmbienceProp, b: AmbienceProp) -> bool:
			return (
				a.light.position.distance_squared_to(from)
				< b.light.position.distance_squared_to(from)
			)
	)
	for i: int in dressing.lamps.size():
		if dressing.rooms[i] != room:
			continue
		var lamp: AmbienceProp = dressing.lamps[i]
		var turn: int = torches.find(lamp)
		if turn < 0:
			turn = 0
			for t: int in torches.size():
				var gap: float = torches[t].light.position.distance_squared_to(lamp.light.position)
				if gap < torches[turn].light.position.distance_squared_to(lamp.light.position):
					turn = t
		_waiting.append(lamp)
		_waits.append(turn * CATCH_GAP)
	advance(0.0)


## The room of [param level] whose rectangle holds feet at [param feet] (world tiles).
static func _room_at(level: LabyrinthLevel, feet: Vector2) -> int:
	var tile := Vector2i(feet.floor())
	for room: LabyrinthChamber in level.chambers:
		if room.rect.has_point(tile):
			return room.index
	for place: int in level.side_paths.size():
		if level.side_paths[place].room.rect.has_point(tile):
			return CACHE + place
	return NONE


## The cache room of [param level] that [param prop] stands in.
static func _cache_of(level: LabyrinthLevel, prop: AmbienceProp) -> int:
	for place: int in level.side_paths.size():
		var rect: Rect2i = level.side_paths[place].room.rect
		if Rect2(rect.position * TILE, rect.size * TILE).intersects(prop.rect):
			return CACHE + place
	return NONE

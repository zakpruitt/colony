class_name FallenParty
extends Node
## The fallen on screen (spec 038 R1, R2). A hero who falls in a fight, or with the party when it
## is wiped, starts its collapse, topples over backwards and lies there on its back rather than
## vanishing, until the fight is won or the party is revived. A wipe is told as a story: the
## camera holds on the fallen party, then travels to where the simulation will revive it,
## arriving before the revival; there the heroes appear, still lying, under the revival light,
## and rise back onto their feet. However the world learns of the wipe (as it happens, late after a
## stall, or finding the party already down after time away), the story starts from where the
## time since the wipe has got to (spec 048).
##
## A revival on another stage (spec 054 R8) is a crossing instead: the camera holds on the fallen
## while the screen dims ([ZoneCrossing]) and cuts to the revival as it happens, so the view never
## travels up or down.
##
## A child of [World], which asks it each frame where a hero stands ([method goal_for]), lets it
## animate the heroes it holds ([method animate]), and lets it steer the camera
## ([method aims_camera]). The story's times are game time (real time times
## [member World.speed]), so it keeps its shape at 2x and 4x, only sooner; a pose plays in real
## time, as every pose does.
##
## Lying is the sprite itself turned a quarter turn about its feet, head away from the way it
## faced, and lifted so its back rests on the floor: a quarter turn keeps every pixel whole, so a
## fallen hero is its own sprite on its side, not a squashed one.

## How far into its collapse a fallen hero topples, in seconds: where the collapse has begun to
## sag (a fifth of the way down its eased fall) but has not yet squashed the body.
const FALL_AT: float = (
	CharacterSprite.DEATH_POP_TIME
	+ 0.447 * (CharacterSprite.DEATH_TIME - CharacterSprite.DEATH_POP_TIME)
)
## Seconds a falling hero takes to topple onto its back, falling faster as it goes.
const TOPPLE_SECONDS: float = 0.18
## Seconds the camera stays on the fallen party after a wipe before it travels.
const HOLD_SECONDS: float = 1.5
## Seconds before the revival the camera's travel ends, so the heroes are seen standing up.
const ARRIVE_BEFORE: float = 0.5
## The camera's travel: its average speed in pixels a second, and its shortest and longest time.
const TRAVEL_SPEED: float = 480.0
const TRAVEL_MIN: float = 0.6
const TRAVEL_MAX: float = Expedition.REVIVE_SECONDS - HOLD_SECONDS - ARRIVE_BEFORE
## Further than this many screens away, the camera cuts to the revival instead of travelling.
const CUT_SCREENS: float = 3.0
## Seconds a revived hero takes to rise from its back onto its feet.
const STAND_SECONDS: float = 0.8

var _world: World
## Per dead hero: real seconds since its collapse began, and the way it faced as it fell.
var _dying: Dictionary[int, float] = {}
var _facing: Dictionary[int, int] = {}
## Per held hero (fallen, until the fight is won or the party revived): where its feet were.
var _spots: Dictionary[int, Vector2] = {}
## Per hero standing up: game seconds since the revival, and where it stands (once known).
var _standing: Dictionary[int, float] = {}
var _stand_spots: Dictionary[int, Vector2] = {}
## Per fallen or rising hero: how far over it is, 0 upright to 1 on its back.
var _tilt: Dictionary[int, float] = {}
## Game seconds since the wipe being told, or -1 when none is; and the tick of that wipe, which the
## age never falls behind (so a stalled frame's time counts).
var _wipe_age: float = -1.0
var _wipe_tick: int = 0
## Where the camera ends its travel, and whether the camera has left the fallen (travelling, cut
## or arrived).
var _destination: Vector2 = Vector2.ZERO
var _travelling: bool = false
## The camera's way, planned on the story's first frame: the view it starts from, how long the
## travel takes in game seconds (it starts at HOLD_SECONDS), and whether it is a cut instead.
var _planned: bool = false
var _from: Vector2 = Vector2.ZERO
var _length: float = 0.0
var _cut: bool = false
## True when the revival is on another stage than the wipe (spec 054): the cut waits for it.
var _elsewhere: bool = false


## Call once, before the first sync.
func setup(world: World) -> void:
	_world = world


## True while hero [param id] lies fallen: toppling, or on its back.
func is_lying(id: int) -> bool:
	return _spots.has(id)


## True while hero [param id] rises after the revival.
func is_standing(id: int) -> bool:
	return _standing.has(id)


## True from a wipe until the revived party has stood up: the story is being told.
func is_telling() -> bool:
	return _wipe_age >= 0.0


## The camera target the travel ends on: where the simulation will revive the party, seen as the
## world frames the party (its look-ahead included). Valid while [method is_telling].
func destination() -> Vector2:
	return _destination


## The party was wiped [param age] game seconds ago, however the world learned of it (a live event,
## an old one after a stall, or finding it down): the story starts from where it has got to. Heroes
## still standing up from an earlier wipe are put back on their feet first, to fall again.
func wiped(age: float) -> void:
	for id: int in _standing:
		var sprite: CharacterSprite = _world.character(id)
		if sprite == null:
			continue
		if _stand_spots.has(id):
			sprite.position = _stand_spots[id]
		_forget(id, sprite)
		sprite.revive()
	_standing.clear()
	_stand_spots.clear()
	_travelling = false
	_planned = false
	_wipe_age = maxf(age, 0.0)
	_wipe_tick = _world.simulation.tick - roundi(_wipe_age * Simulation.TICKS_PER_SECOND)
	var place: Vector3 = _world.simulation.expedition.revival_place()
	var level: LabyrinthLevel = _world.simulation.labyrinth.level(int(place.y))
	var feet := Vector2(place.x * World.TILE, (level.floor_y + 1) * World.TILE)
	_destination = _world.camera_target(feet, int(place.z))
	_elsewhere = int(place.y) != _world.simulation.expedition.depth


## The party was revived [param age] game seconds ago. Returns true if the heroes rise, from where
## that age has them (the world must then leave the camera to [method aims_camera]); false if they
## are simply back on their feet (no wipe was being told, or they would have stood already).
func revived(age: float) -> bool:
	_dying.clear()
	_spots.clear()
	if _wipe_age < 0.0 or age >= STAND_SECONDS:
		_wipe_age = -1.0
		_tilt.clear()
		for hero: Hero in _world.simulation.party.heroes:
			var sprite: CharacterSprite = _world.character(hero.id)
			if sprite != null:
				sprite.rotation = 0.0
				sprite.revive()
		return false
	for hero: Hero in _world.simulation.party.heroes:
		_standing[hero.id] = maxf(age, 0.0)
		_tilt[hero.id] = 1.0
	return true


## Hero [param id], lying fallen in a fight, was revived there (spec 056 R2): it rises from its
## back onto its feet where it lies, as the party does after a wipe.
func stand(id: int) -> void:
	if not _spots.has(id):
		return
	_stand_spots[id] = _spots[id]
	_spots.erase(id)
	_dying.erase(id)
	_standing[id] = 0.0
	_tilt[id] = 1.0


## Where hero [param id] is heading this frame: where it lies or rises while it does (lifted as
## far as it is over), [param goal] (where the simulation has it) otherwise.
func goal_for(id: int, goal: Vector2) -> Vector2:
	if _spots.has(id):
		return _lifted(id, _spots[id])
	if _standing.has(id):
		if not _stand_spots.has(id):
			_stand_spots[id] = goal  # the revival's place, the first frame it is known
		return _lifted(id, _stand_spots[id])
	return goal


## Where the feet of hero [param id] are, drawn at [param at]: under a fallen hero lifted onto
## its back, the floor it lies on; [param at] for anyone else.
func feet_of(id: int, at: Vector2) -> Vector2:
	if not _tilt.has(id):
		return at
	if _spots.has(id):
		return Vector2(at.x, _spots[id].y)
	if _stand_spots.has(id):
		return Vector2(at.x, _stand_spots[id].y)
	return at


## Animates hero [param id]'s [param sprite] by [param delta] real seconds if it is fallen or
## rising, and returns true; returns false (the world animates it) otherwise.
func animate(id: int, sprite: CharacterSprite, delta: float) -> bool:
	if _standing.has(id):
		return _rise(id, sprite, delta)
	if not sprite.is_dead():
		_forget(id, sprite)
		return false
	if not _dying.has(id):
		var mirror: Node2D = sprite.get_node("Mirror")
		_facing[id] = -1 if mirror.scale.x < 0.0 else 1
		# Out of sight already (a death not acted out): it has fallen all the way.
		_dying[id] = 0.0 if sprite.visible else FALL_AT + TOPPLE_SECONDS
	var expedition: Expedition = _world.simulation.expedition
	var down: bool = expedition.state == Expedition.State.REVIVING
	down = down or (expedition.state == Expedition.State.FIGHTING and expedition.battle != null)
	if not down:
		if _spots.has(id):
			# The fight was won: the fallen hero's collapse ends as it would have, out of sight.
			_forget(id, sprite)
			sprite.advance(CharacterSprite.DEATH_TIME)
			return true
		_dying[id] += delta
		return false
	var played: float = _dying[id]
	if not _spots.has(id):
		_spots[id] = sprite.position
		if played > FALL_AT or not sprite.visible:
			_pose(sprite, FALL_AT)
	var step: float = minf(delta, maxf(FALL_AT - played, 0.0))
	if step > 0.0:
		sprite.advance(step)
	played += delta
	_dying[id] = played
	var falling: float = clampf((played - FALL_AT) / TOPPLE_SECONDS, 0.0, 1.0)
	_lay(id, sprite, falling * falling, _spots[id])
	return true


## Steers [param camera] while a wipe is told, moving the story on by [param delta] real seconds,
## and returns true; returns false (the world aims the camera at the fallen, as it would the party)
## while it holds on them, or when no wipe is told. [param snap] is true on a frame that puts every
## sprite in place: the camera is then put where the story has it, never pulled back to the party.
## The camera's place is worked out from the story's age, so it is the same however the story was
## come into: on the fallen, then (from HOLD_SECONDS) travelling, arrived by ARRIVE_BEFORE before
## the revival; or, for a revival too far away to travel to, on the fallen until that moment and
## then cut to the revival.
func aims_camera(camera: WorldCamera, delta: float, snap: bool) -> bool:
	if _wipe_age < 0.0:
		return false
	var speed: int = maxi(_world.speed, 1)
	if _planned:  # a story heard this frame is already as old as it is
		_wipe_age += delta * speed
	else:
		_plan(camera)
	var behind: float = float(_world.simulation.tick - _wipe_tick) / Simulation.TICKS_PER_SECOND
	_wipe_age = maxf(_wipe_age, behind)
	var rising: bool = not _standing.is_empty()
	var into: float = _wipe_age - HOLD_SECONDS
	if _cut:
		into = _wipe_age - (Expedition.REVIVE_SECONDS - ARRIVE_BEFORE)
	if (into < 0.0 or _elsewhere) and not rising:
		return false  # holding on the fallen (until the revival, when it is elsewhere)
	var away: bool = _travelling
	_travelling = true
	if not _cut and into < _length and not rising:
		if not away and not snap:
			_from = camera.position  # set off from where the hold has the camera
		camera.travel(_destination, _length / speed, maxf(into / speed - delta, 0.0), _from)
		camera._process(delta)
	elif (_cut and not away) or snap:
		camera.snap_to(_destination)
	else:
		if not camera.is_travelling():
			camera.target = _destination
		camera._process(delta)
	if not away or snap:
		# The labyrinth is built where the camera now is, not a frame later.
		_world.labyrinth_view.set_focus(camera.position / World.TILE)
	return true


## The world tile to build the labyrinth around: [param party] (the party's own), or once the
## camera has left the fallen for a revival, the camera's.
func focus(party: Vector2) -> Vector2:
	if _travelling and _wipe_age >= 0.0 and _standing.is_empty():
		return _world.camera.position / World.TILE
	return party


## Plans the camera's way from the view it holds on the fallen ([member WorldCamera.target], set by
## the world this frame) to the revival.
func _plan(camera: WorldCamera) -> void:
	_planned = true
	_from = camera.target
	var gap: Vector2 = _destination - _from
	var screen: Vector2 = camera.get_viewport_rect().size / camera.zoom
	_cut = _elsewhere or (gap / screen).length() > CUT_SCREENS
	_length = clampf(gap.length() / TRAVEL_SPEED, TRAVEL_MIN, TRAVEL_MAX)


## One frame of hero [param id] rising after the revival; true while it is still rising.
func _rise(id: int, sprite: CharacterSprite, delta: float) -> bool:
	_standing[id] += delta * maxi(_world.speed, 1)
	if _standing[id] >= STAND_SECONDS:
		_standing.erase(id)
		_stand_spots.erase(id)
		_forget(id, sprite)
		sprite.revive()
		if _standing.is_empty():
			_wipe_age = -1.0
		return false
	var over: float = 1.0 - smoothstep(0.0, 1.0, _standing[id] / STAND_SECONDS)
	# The fall played back as it rises: the sag, then the stretch of the pop that began it.
	_pose(sprite, lerpf(CharacterSprite.DEATH_POP_TIME + 0.001, FALL_AT, over))
	if _stand_spots.has(id):
		_lay(id, sprite, over, _stand_spots[id])
	return true


## Turns hero [param id]'s sprite [param over] of the way onto its back about its feet at
## [param feet], lifted so its back stays on the floor.
func _lay(id: int, sprite: CharacterSprite, over: float, feet: Vector2) -> void:
	_tilt[id] = over
	sprite.rotation = -_facing.get(id, 1) * over * PI / 2.0
	sprite.position = _lifted(id, feet)


## [param feet] raised by how far hero [param id]'s back reaches below them as it lies over.
func _lifted(id: int, feet: Vector2) -> Vector2:
	var sprite: CharacterSprite = _world.character(id)
	var over: float = _tilt.get(id, 0.0)
	if sprite == null or over <= 0.0:
		return feet
	# Facing right it turns back over its left side, its back (the box's left) going under; a
	# mirrored sprite's back is its box's right, shifted a pixel by the mirror.
	var box: Rect2i = SpriteBounds.box_of(sprite)
	var back: float = -box.position.x + (1.0 if _facing.get(id, 1) < 0 else 0.0)
	return feet - Vector2(0.0, roundf(back * sin(over * PI / 2.0)))


func _forget(id: int, sprite: CharacterSprite) -> void:
	_dying.erase(id)
	_facing.erase(id)
	_spots.erase(id)
	_tilt.erase(id)
	sprite.rotation = 0.0


## Shows [param sprite] [param seconds] into its collapse, whatever it was doing.
static func _pose(sprite: CharacterSprite, seconds: float) -> void:
	sprite.revive()
	sprite.play_death()
	sprite.advance(seconds)

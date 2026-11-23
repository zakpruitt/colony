class_name UnseenEyes
extends Node2D
## The eyes of the monsters waiting where the world is drawn black ([method Ambience.hides]):
## a pair at each one's head, over the black, blinking in its own time. A guardian's are the
## larger pair of the sheet. A monster the party can see has none.
##
## A child of [World], which calls [method watch] once a frame with the monsters waiting. It
## redraws itself only when a pair comes, goes, moves, shuts or opens, and nothing else.

const SHEET: String = "res://assets/sprites/ambience/eyes.png"
const SMALL: StringName = &"small"
const LARGE: StringName = &"large"
## Seconds a pair stays shut, and the least and most it stays open between two blinks.
const SHUT_SECONDS: float = 0.15
const OPEN_SECONDS: Vector2 = Vector2(2.0, 5.0)
## How far down a monster's body its eyes are, as a share of its height, and at most, in pixels.
const HEAD_SHARE: float = 0.3
const HEAD_MOST: float = 6.0

## How many times it has asked to be drawn again, for tests.
var redraws: int = 0

var _world: World
## Each waiting monster's head, from its sprite's position, and the sprite it was measured on:
## an id comes round again, on another monster.
var _heads: Dictionary[int, Vector2] = {}
var _bodies: Dictionary[int, int] = {}
## Each pair showing: where its middle is, the seconds until it shuts (shut at 0 and under) and
## its part of the sheet.
var _at: Dictionary[int, Vector2] = {}
var _clock: Dictionary[int, float] = {}
var _parts: Dictionary[int, StringName] = {}
var _rolls: int = 0


## Call once, in the tree, before the first watch.
func setup(world: World) -> void:
	_world = world
	name = "UnseenEyes"
	z_index = AmbienceDarkness.HINTS_Z
	z_as_relative = false


## The part of the sheet showing for monster [param id]: [constant SMALL], [constant LARGE] for
## a guardian, or [code]&""[/code] when it has no eyes in the black.
func part(id: int) -> StringName:
	return _parts.get(id, &"") if _clock.has(id) else &""


## True while monster [param id]'s pair is shut in a blink.
func is_shut(id: int) -> bool:
	return _clock.get(id, 1.0) <= 0.0


## Where the middle of monster [param id]'s pair is, in world pixels.
func place(id: int) -> Vector2:
	return _at.get(id, Vector2.INF)


## How many pairs there are.
func count() -> int:
	return _clock.size()


## Gives a pair to each of [param waiting] (monster ids, true for a guardian) standing in the
## black and takes it from the rest, and moves the blinks on by [param delta] seconds.
func watch(waiting: Dictionary[int, bool], delta: float) -> void:
	var changed: bool = false
	var unseen: int = 0
	for id: int in waiting:
		var sprite: CharacterSprite = _world.character(id)
		if sprite == null or sprite.is_dead():
			changed = _clock.erase(id) or changed
			continue
		if _bodies.get(id, 0) != sprite.get_instance_id():
			_bodies[id] = sprite.get_instance_id()
			_heads[id] = _head_of(sprite)
		var at: Vector2 = (sprite.position + _heads[id]).round()
		if not _world.ambience.hides(at):
			changed = _clock.erase(id) or changed
			continue
		unseen += 1
		if not _clock.has(id):
			_clock[id] = _open_for(id)
			_parts[id] = LARGE if waiting[id] else SMALL
			changed = true
		elif _at[id] != at:
			changed = true
		_at[id] = at
	if _heads.size() > waiting.size() or _clock.size() > unseen:
		changed = _forget(waiting) or changed
	for id: int in _clock:
		var before: float = _clock[id]
		var left: float = before - delta
		if left <= -SHUT_SECONDS:
			left = _open_for(id)
		_clock[id] = left
		changed = changed or (left <= 0.0) != (before <= 0.0)
	if changed:
		redraws += 1
		queue_redraw()


## Forgets every monster not in [param waiting]. True if a pair went with one.
func _forget(waiting: Dictionary[int, bool]) -> bool:
	var went: bool = false
	for id: int in _heads.keys():
		if not waiting.has(id):
			_heads.erase(id)
			_bodies.erase(id)
			_at.erase(id)
			_parts.erase(id)
			went = _clock.erase(id) or went
	return went


## Seconds monster [param id]'s pair stays open now: its own each time.
func _open_for(id: int) -> float:
	_rolls += 1
	var share: float = AmbienceLevel.mix(id, _rolls) % 1000 / 999.0
	return lerpf(OPEN_SECONDS.x, OPEN_SECONDS.y, share)


## Where [param sprite]'s eyes are from its position: the middle of its head.
static func _head_of(sprite: CharacterSprite) -> Vector2:
	var body: Rect2 = SpriteBounds.body_rect(sprite, Vector2.ZERO)
	return Vector2(0.0, body.position.y + minf(body.size.y * HEAD_SHARE, HEAD_MOST))


func _draw() -> void:
	var sheet: PixelSheet = PixelSheet.load_sheet(SHEET)
	if sheet == null:
		return
	var half: Vector2 = (Vector2(sheet.size) / 2.0).floor()
	for id: int in _clock:
		if _clock[id] > 0.0:
			draw_texture(sheet.part(part(id)), _at[id] - half)

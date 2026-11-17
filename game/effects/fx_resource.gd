class_name FxResource
extends Node2D
## One icon of a resource drop (spec 052 R8): it rises a little from where the monster fell,
## hangs a moment, then flies to the resource's place beside the gold. [ResourceEffects] creates
## it, advances it with where its target is now, and counts its share in when it arrives.

enum Phase { RISE, FLY }

## Pixels it rises, and the seconds it takes and then hangs.
const RISE_PIXELS: float = 14.0
const RISE_SECONDS: float = 0.45
const HANG_SECONDS: float = 0.25
## Flying to the target: starting speed, and how much faster each second, in pixels per second.
const FLY_SPEED: float = 40.0
const FLY_ACCELERATION: float = 1200.0
## Closer than this many pixels, it has arrived.
const ARRIVE: float = 5.0
## Seconds after which it arrives wherever it is, so none is ever lost.
const MAX_LIFE: float = 4.0

## The resource's position in [method Content.resource_ids], and its share of the drop.
var index: int = 0
var share: int = 1
var phase: Phase = Phase.RISE
var age: float = 0.0
## Where it started, in world pixels.
var start_position: Vector2

var _texture: Texture2D
var _exact: Vector2
var _speed: float = FLY_SPEED


## An icon of the resource at [param resource_index] carrying [param amount] of it.
func _init(resource_index: int, amount: int) -> void:
	index = resource_index
	share = amount
	var ids: Array[StringName] = Content.resource_ids()
	if resource_index >= 0 and resource_index < ids.size():
		_texture = ResourceIcon.texture(ids[resource_index])


## Places the icon at [param at] before its first advance.
func start(at: Vector2) -> void:
	start_position = at
	_exact = at
	position = at.round()
	queue_redraw()


## Moves it on by [param delta] seconds toward [param target] (world pixels). True on arrival.
func advance(delta: float, target: Vector2) -> bool:
	age += delta
	match phase:
		Phase.RISE:
			var risen: float = clampf(age / RISE_SECONDS, 0.0, 1.0)
			# Eases out: quick at first, slowing to a hang.
			_exact = start_position - Vector2(0, RISE_PIXELS * (1.0 - pow(1.0 - risen, 2.0)))
			if age >= RISE_SECONDS + HANG_SECONDS:
				phase = Phase.FLY
		Phase.FLY:
			_speed += FLY_ACCELERATION * delta
			var gap: Vector2 = target - _exact
			var step: float = _speed * delta
			if gap.length() <= maxf(step, ARRIVE):
				_exact = target
				position = target.round()
				return true
			_exact += gap / gap.length() * step
	position = _exact.round()
	return age >= MAX_LIFE


func _draw() -> void:
	if _texture != null:
		draw_texture(_texture, -(ResourceIcon.SIZE / 2.0).round())

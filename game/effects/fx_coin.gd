class_name FxCoin
extends Node2D
## One coin of a gold gain: it spills out of a fallen monster in an arc, bounces on
## the chamber floor, rests a moment, then flies to the gold target. [CombatEffects] creates it,
## advances it with where the target is now, and emits the coin's share when it arrives.

enum Phase { SPILL, REST, FLY }

const SHEET_PATH: String = "res://assets/sprites/fx/coin.png"
## The spin, one frame at a time, and seconds per frame.
const SPIN: Array[StringName] = [&"face", &"turn", &"edge", &"turn"]
const SPIN_FRAME: float = 0.08
## Pixels per second per second downward while spilling.
const GRAVITY: float = 520.0
## What a bounce keeps of the fall, and of the speed across.
const BOUNCE: float = 0.45
const GRIP: float = 0.6
## A bounce slower than this many pixels per second settles the coin on the floor.
const SETTLE_SPEED: float = 70.0
## Flying to the target: starting speed, and how much faster each second, in pixels per second.
const FLY_SPEED: float = 60.0
const FLY_ACCELERATION: float = 1400.0
## Closer than this many pixels, it has arrived.
const ARRIVE: float = 6.0
## Seconds after which a coin arrives wherever it is, so none is ever lost.
const MAX_LIFE: float = 4.0

## Its share of the gain, in gold.
var share: int = 1
var phase: Phase = Phase.SPILL
var velocity: Vector2 = Vector2.ZERO
## The floor it bounces on, in world pixels, and whether it has touched it.
var floor_y: float = 0.0
var landed: bool = false
## Seconds it rests on the floor before it flies.
var rest_time: float = 0.4
var age: float = 0.0

var _exact: Vector2
var _resting: float = 0.0
var _speed: float = FLY_SPEED
var _sheet: PixelSheet


func _init() -> void:
	_sheet = PixelSheet.load_sheet(SHEET_PATH)


## Places the coin at [param at] before its first advance.
func start(at: Vector2) -> void:
	_exact = at
	position = at.round()
	queue_redraw()


## Moves it on by [param delta] seconds toward [param target] (world pixels). True on arrival.
func advance(delta: float, target: Vector2) -> bool:
	age += delta
	match phase:
		Phase.SPILL:
			velocity.y += GRAVITY * delta
			_exact += velocity * delta
			if _exact.y >= floor_y:
				_exact.y = floor_y
				landed = true
				if absf(velocity.y) < SETTLE_SPEED:
					phase = Phase.REST
					velocity = Vector2.ZERO
				else:
					velocity = Vector2(velocity.x * GRIP, -absf(velocity.y) * BOUNCE)
		Phase.REST:
			_resting += delta
			if _resting >= rest_time:
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
	queue_redraw()
	return age >= MAX_LIFE


func _draw() -> void:
	if _sheet == null:
		return
	var frame: StringName = SPIN[int(age / SPIN_FRAME) % SPIN.size()]
	if phase == Phase.REST:
		frame = &"face"
	var texture: AtlasTexture = _sheet.part(frame)
	var pivot: Vector2i = _sheet.part_pivot(frame)
	draw_texture(texture, -Vector2(pivot))

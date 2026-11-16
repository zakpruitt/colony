class_name FxMote
extends Node2D
## A mote of XP (spec 010 R7): it leaps out of a fallen monster, then homes in on the hero who
## gained the XP. [CombatEffects] creates it, advances it with where the hero is now, and frees it
## (with a tiny flash) when it arrives.

const SHEET_PATH: String = "res://assets/sprites/fx/mote.png"
## How fast it turns toward the hero (each second keeps e^-rate of its old heading).
const STEER: float = 7.0
## Its homing speed at first, and how much faster each second, in pixels per second.
const SPEED: float = 90.0
const ACCELERATION: float = 500.0
## Closer than this many pixels, it has arrived.
const ARRIVE: float = 5.0
## Seconds after which it arrives wherever it is.
const MAX_LIFE: float = 2.0

## The hero it flies to.
var hero_id: int = -1
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0

var _exact: Vector2
var _sheet: PixelSheet


func _init() -> void:
	_sheet = PixelSheet.load_sheet(SHEET_PATH)


## Places the mote at [param at] before its first advance.
func start(at: Vector2) -> void:
	_exact = at
	position = at.round()


## Moves it on by [param delta] seconds toward [param target] (world pixels). True on arrival.
func advance(delta: float, target: Vector2) -> bool:
	age += delta
	var gap: Vector2 = target - _exact
	var speed: float = SPEED + ACCELERATION * age
	if gap.length() <= maxf(ARRIVE, speed * delta) or age >= MAX_LIFE:
		_exact = target
		position = target.round()
		return true
	var wanted: Vector2 = gap / gap.length() * speed
	velocity = velocity.lerp(wanted, 1.0 - exp(-STEER * delta))
	_exact += velocity * delta
	position = _exact.round()
	return false


func _draw() -> void:
	if _sheet == null:
		return
	draw_texture(_sheet.part(&"mote"), -Vector2(_sheet.part_pivot(&"mote")))

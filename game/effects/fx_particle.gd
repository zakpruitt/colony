class_name FxParticle
extends FxNode
## One particle of an effect: a square of one palette colour, or a small tinted fx
## sprite, that flies, falls under gravity, may bounce on a floor, and shrinks away. It sits on
## whole pixels and never fades. An effect class makes it; the [FxPool] advances it.

enum Shape {
	SQUARE,  ## A square, or the sprite in [member texture] while young.
	PUFF,  ## A square with its corners cut, for the puff of a death.
	COLUMN,  ## A column of light standing on its position, thinning away.
}

## Of a square with a sprite, the share of its life the sprite shows before it becomes a square.
const SPRITE_SHARE: float = 0.5
## The share of its life a particle keeps its full size before it starts to shrink.
const HOLD_SHARE: float = 0.4
## What a bounce keeps of the speed across the floor.
const FLOOR_GRIP: float = 0.7

## What the particle is for (&"spark", &"burst", &"puff", ...), so tests and caps can tell.
var kind: StringName = &""
var shape: Shape = Shape.SQUARE
var color: Color = Color.WHITE
## Drawn instead of a square while young, tinted by [member color]. Optional.
var texture: Texture2D
## Pixels per second, and pixels per second per second downward (negative rises).
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 0.0
## How much speed is lost each second (each second keeps e^-drag of it).
var drag: float = 0.0
## Starting size in pixels (a column's width), and a column's height.
var size: int = 1
var height: int = 0
## Seconds it lives, and seconds it has lived.
var life: float = 0.5
var age: float = 0.0
## The floor it bounces on, in world pixels, and what a bounce keeps of its fall.
var floor_y: float = INF
var bounce: float = 0.4

var _exact: Vector2


## Places the particle at [param at] (world pixels) before its first advance.
func start(at: Vector2) -> void:
	_exact = at
	position = at.round()
	queue_redraw()


## Moves it on by [param delta] seconds. False once its life is over.
func advance(delta: float) -> bool:
	age += delta
	if age >= life:
		return false
	velocity.y += gravity * delta
	if drag > 0.0:
		velocity *= exp(-drag * delta)
	_exact += velocity * delta
	if _exact.y > floor_y:
		_exact.y = floor_y
		velocity.y = -absf(velocity.y) * bounce
		velocity.x *= FLOOR_GRIP
	position = _exact.round()
	queue_redraw()
	return true


## The rectangle it covers now, in its parent's pixels, as [method _draw] draws it.
func rect() -> Rect2:
	var s: int = current_size()
	var half: int = floori(s / 2.0)
	if shape == Shape.COLUMN:
		return Rect2(position + Vector2(-half, -height), Vector2(s, height))
	if shape == Shape.SQUARE and texture != null and age < life * SPRITE_SHARE:
		var box: Vector2 = texture.get_size()
		return Rect2(position - (box / 2.0).floor(), box)
	return Rect2(position - Vector2(half, half), Vector2(s, s))


## Its size now, in whole pixels: full, then shrinking toward 1 over the rest of its life.
func current_size() -> int:
	var t: float = age / life
	if t <= HOLD_SHARE:
		return size
	var left: float = 1.0 - (t - HOLD_SHARE) / (1.0 - HOLD_SHARE)
	return maxi(1, ceili(size * left))


func _draw() -> void:
	var s: int = current_size()
	var half: int = floori(s / 2.0)
	match shape:
		Shape.SQUARE:
			if texture != null and age < life * SPRITE_SHARE:
				var corner := Vector2(
					-floori(texture.get_width() / 2.0), -floori(texture.get_height() / 2.0)
				)
				draw_texture(texture, corner, color)
			else:
				draw_rect(Rect2(-half, -half, s, s), color)
		Shape.PUFF:
			if s <= 2:
				draw_rect(Rect2(-half, -half, s, s), color)
			elif s >= 8:
				draw_rect(Rect2(-half + 2, -half, s - 4, s), color)
				draw_rect(Rect2(-half + 1, -half + 1, s - 2, s - 2), color)
				draw_rect(Rect2(-half, -half + 2, s, s - 4), color)
			else:
				draw_rect(Rect2(-half + 1, -half, s - 2, s), color)
				draw_rect(Rect2(-half, -half + 1, s, s - 2), color)
		Shape.COLUMN:
			draw_rect(Rect2(-half, -height, s, height), color)

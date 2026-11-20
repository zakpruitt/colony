class_name FxRing
extends Node2D
## A ring of an action that strikes many: squares of one palette colour on a flat
## ellipse round its position (a fighter's or target's feet), widening from a few pixels to
## [member reach] and blinking out. Nothing is smooth or faded. [AbilityEffects] creates it;
## the [FxPool] advances it.

## How flat the ellipse is: its height over its width, so it lies on the floor.
const FLAT: float = 0.35
## Pixels between two squares round the ring, and the last seconds of its life it blinks.
const SPACING: float = 4.0
const BLINK_TIME: float = 0.1

var color: Color = Color.WHITE
## The ring's widest, in pixels, and its seconds.
var reach: float = 32.0
var life: float = 0.35
var age: float = 0.0


## Moves it on by [param delta] seconds. False once its life is over.
func advance(delta: float) -> bool:
	age += delta
	if age >= life:
		return false
	var left: float = life - age
	visible = left > BLINK_TIME or int(left / 0.05) % 2 == 0
	queue_redraw()
	return true


## Its radius across now, in pixels: quickly out, then slowing.
func radius() -> float:
	var t: float = clampf(age / life, 0.0, 1.0)
	return lerpf(4.0, reach, 1.0 - (1.0 - t) * (1.0 - t))


func _draw() -> void:
	var across: float = radius()
	var count: int = maxi(8, ceili(TAU * across / SPACING))
	var size: float = 2.0 if age < life * 0.6 else 1.0
	for i: int in count:
		var angle: float = TAU * i / count
		var at := Vector2(cos(angle) * across, sin(angle) * across * FLAT).round()
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(size, size)), color)

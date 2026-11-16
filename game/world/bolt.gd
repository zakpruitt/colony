class_name Bolt
extends Node2D
## A small shot or heal in flight, drawn as a short streak of one palette colour with a bright
## head. It travels from where it was launched to its target over its flight time; the world
## keeps [member to] on the target as it moves, and frees the bolt once it has arrived.

## How long the streak is, and how thick, in pixels.
const LENGTH: float = 5.0
const THICKNESS: float = 2.0

## The colour of the streak, and of its head.
var color: Color
var head_color: Color
## Where it set off from and where it is going, in world pixels.
var from: Vector2
var to: Vector2
## The hero or monster it flies at.
var target_id: int = -1
## Seconds of flight in all, and so far.
var duration: float = 0.1
var elapsed: float = 0.0


## A bolt from [param start] to [param goal] taking [param seconds], already [param age] seconds
## into its flight. A heal is green; an attack is amber.
static func launch(
	start: Vector2, goal: Vector2, seconds: float, age: float, is_heal: bool, target: int
) -> Bolt:
	var bolt := Bolt.new()
	bolt.from = start
	bolt.to = goal
	bolt.duration = maxf(seconds, 0.001)
	bolt.elapsed = clampf(age, 0.0, bolt.duration)
	bolt.target_id = target
	bolt.color = Palette.color(&"green" if is_heal else &"orange")
	bolt.head_color = Palette.color(&"white" if is_heal else &"yellow")
	bolt.name = "Bolt"
	bolt._place()
	return bolt


## Moves the bolt on by [param delta] seconds. True once it has reached its target.
func advance(delta: float) -> bool:
	elapsed = minf(elapsed + delta, duration)
	_place()
	return arrived()


## True when the flight time is over and the bolt is at its target.
func arrived() -> bool:
	return elapsed >= duration


func _place() -> void:
	position = from.lerp(to, elapsed / duration)
	var heading: Vector2 = to - from
	rotation = heading.angle() if heading.length_squared() > 0.0 else 0.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-LENGTH, -THICKNESS / 2.0, LENGTH, THICKNESS), color)
	draw_rect(Rect2(-THICKNESS, -THICKNESS / 2.0, THICKNESS, THICKNESS), head_color)

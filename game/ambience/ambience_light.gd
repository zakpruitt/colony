class_name AmbienceLight
extends RefCounted
## One light of the ambience: a torch, the campfire, a vault's gleam, a glowing prop or
## the party's own light. It flickers in small steps, a few times a second, so the pool's rings
## jump by a pixel rather than swim.

## How many times a second a flickering light changes.
const FLICKER_RATE: float = 9.0

## What it is: &"torch", &"campfire", &"gleam", &"glow" or &"party".
var kind: StringName
## Where it is, in world pixels.
var position: Vector2
## How far it reaches now, in pixels, and how strong it is now (1 is its full colour).
var radius: float
var energy: float
## Its colour at full strength.
var color: Color
## Within this many pixels it is at full strength; its rings lie between here and [member radius].
## A light with a core (the party's) lights open space only and adds no glow.
var core: float = 0.0
## Its steady reach and strength, and how much of each a flicker can take away or add.
var base_radius: float
var base_energy: float
var flicker: float
## Seeds its flicker, so neighbouring torches do not flicker together.
var seed_value: int


func _init(
	light_kind: StringName,
	at: Vector2,
	reach: float,
	strength: float,
	tint: Color,
	flicker_amount: float = 0.0,
	seed_from: int = 0
) -> void:
	kind = light_kind
	position = at
	base_radius = reach
	base_energy = strength
	radius = reach
	energy = strength
	color = tint
	flicker = flicker_amount
	seed_value = seed_from


## Sets the flicker for [param time] seconds into the run.
func advance(time: float) -> void:
	if flicker <= 0.0:
		return
	var tick: int = floori(time * FLICKER_RATE)
	var wobble: float = _noise(tick) * 0.6 + _noise(tick >> 2) * 0.4
	energy = base_energy * (1.0 + flicker * wobble)
	radius = roundf(base_radius * (1.0 + flicker * 0.5 * _noise(tick + 7919)))


## A value from -1 to 1 for this light and [param tick], the same every time.
func _noise(tick: int) -> float:
	return AmbienceLevel.mix(seed_value, tick) % 2001 / 1000.0 - 1.0

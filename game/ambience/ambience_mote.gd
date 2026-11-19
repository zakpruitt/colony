class_name AmbienceMote
extends RefCounted
## One small moving thing of the ambience: a dust mote, an ember, a water drip or its
## splash, a glint, or a critter. It is data; [AmbienceLevel] moves and draws it. Nothing in
## the game reads it: critters are decoration, not monsters.

## &"dust", &"ember", &"drip", &"splash", &"glint", &"beetle" or &"moth".
var kind: StringName
## Where it is, in world pixels (a critter's: where its feet or its body's centre is).
var position: Vector2
var velocity: Vector2
## Seconds it has lived, and will live.
var age: float = 0.0
var life: float = 1.0
## What it moves around: a dust mote's home, a moth's torch, a drip's floor (as y).
var origin: Vector2
## Where in its wobble or circle it starts.
var phase: float = 0.0
## Which torch's dust it is, or -1.
var source: int = -1


func _init(mote_kind: StringName, at: Vector2, lifetime: float) -> void:
	kind = mote_kind
	position = at
	origin = at
	life = lifetime


## How far through its life it is, 0 to 1.
func progress() -> float:
	return clampf(age / life, 0.0, 1.0)

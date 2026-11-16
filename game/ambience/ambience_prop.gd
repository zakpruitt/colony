class_name AmbienceProp
extends RefCounted
## One placed piece of decoration (spec 012): a torch on a back wall or a prop on a chamber's
## floor or ceiling. It is data; [AmbienceLevel] draws it.

enum Anchor { FLOOR, CEILING, WALL }

## What it is, as [method Ambience.props_in] reports it (&"campfire", &"web", &"torch", ...).
var name: StringName
## The index of the chamber it is in.
var chamber: int
var anchor: Anchor = Anchor.FLOOR
## Where it is drawn, in world pixels.
var rect: Rect2
## Drawn under the darkness, so it is lit like the world. May be null.
var texture: Texture2D
## Drawn over the darkness, so it glows: flame frames or a glowing prop. May be empty.
var frames: Array[Texture2D] = []
## The glowing frame showing now, and how many frames a second they step through.
var frame: int = 0
var frame_rate: float = 0.0
## Where its frames start in their cycle, so props side by side do not move together.
var phase: float = 0.0
## Drawn mirrored.
var flip: bool = false
## The light it gives off, or null.
var light: AmbienceLight


func _init(prop_name: StringName, chamber_index: int, at: Rect2, prop_anchor: Anchor) -> void:
	name = prop_name
	chamber = chamber_index
	rect = at
	anchor = prop_anchor


## Steps its glowing frames to [param time] seconds into the run.
func advance(time: float) -> void:
	if frames.size() > 1 and frame_rate > 0.0:
		frame = floori(time * frame_rate + phase * frames.size()) % frames.size()

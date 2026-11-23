class_name AmbienceProp
extends RefCounted
## One placed piece of decoration: a torch on a back wall, or a prop on a chamber's floor, hanging
## from its ceiling or set in its back wall. It is data; [AmbienceLevel] draws it.

## What it is fixed to. FLOOR: it stands on the floor line. CEILING: it hangs from the ceiling of
## its column, two pixels sunk into it, and may reach the floor. WALL: a torch's bracket on the
## back wall. BACK: a thing set in the back wall that gives no light.
enum Anchor { FLOOR, CEILING, WALL, BACK }

## What it is, as [method Ambience.props_in] reports it (&"campfire", &"web", &"torch", ...).
var name: StringName
## The index of the chamber it is in.
var chamber: int
var anchor: Anchor = Anchor.FLOOR
## Where it is, in world pixels: the canvas it is drawn on or, for a decoration, the box of its
## own pixels.
var rect: Rect2
## Where the top left of its canvas is drawn, in world pixels.
var drawn_at: Vector2
## True for a decoration of [AmbienceDecor]'s table; false for a torch and for a prop that says
## what kind of room it is.
var decor: bool = false
## Drawn under the darkness, so it is lit like the world. May be null.
var texture: Texture2D
## For a thing taller than a sheet's canvas, floor to ceiling: [member foot] is drawn with its
## canvas's bottom on the bottom of [member rect], and [member shaft] repeated between
## [member texture] and it. Either may be null.
var shaft: Texture2D
var foot: Texture2D
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
## True for a thing that burns (a torch, the campfire): out of the light it has no flame.
var flame: bool = false
## What is drawn under the darkness in place of [member texture] while it is not [member lit].
## May be null.
var unlit: Texture2D
## False while its room is dark: it gives no light and, burning, shows no flame.
var lit: bool = true


func _init(prop_name: StringName, chamber_index: int, at: Rect2, prop_anchor: Anchor) -> void:
	name = prop_name
	chamber = chamber_index
	rect = at
	drawn_at = at.position
	anchor = prop_anchor


## What is drawn of it under the darkness now, or null.
func base() -> Texture2D:
	return texture if lit or unlit == null else unlit


## What is drawn of it over the darkness now, or null: its flame while it burns, or its own glow.
func glowing() -> Texture2D:
	if frames.is_empty() or (flame and not lit):
		return null
	return frames[frame]


## Steps its glowing frames to [param time] seconds into the run.
func advance(time: float) -> void:
	if frames.size() > 1 and frame_rate > 0.0:
		frame = floori(time * frame_rate + phase * frames.size()) % frames.size()

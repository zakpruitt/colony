class_name HudFrame
extends RefCounted
## The frame of the screen's measures and the sentences its pieces say: the screen and its two
## bands, where the frame's pieces stand, the sheet of its icons, the word for each expedition
## state, and the tooltips that name a key. The [Hud] lays the frame out by them; the windows, the
## moment and the effects keep clear of it by them.

## The screen the HUD is laid out on, in pixels.
const SCREEN: Vector2 = Vector2(640, 360)
## The HUD's two bands: everything lies within the top or bottom this many pixels.
const TOP_BAND: float = 28.0
const BOTTOM_BAND: float = 40.0
## The frame of the screen, in UI pixels: its top, the space from the room's sides and bottom,
## and between two pieces.
const FRAME_TOP: float = 1.0
const FRAME_EDGE: float = 6.0
const FRAME_GAP: float = 6.0
## The sheet of HUD icons: a portrait per hero class, a skull and a coin.
const ICONS_PATH: String = "res://assets/sprites/ui/hud_icons.png"
## The word for each expedition state. A state with no line of its own in
## [method Hud.status_text] shows its word.
const STATE_WORDS: Dictionary[Expedition.State, String] = {
	Expedition.State.TRAVELLING: "Travelling",
	Expedition.State.FIGHTING: "Fighting",
	Expedition.State.RESTING: "Resting",
	Expedition.State.CLIMBING: "Moving on",
	Expedition.State.REVIVING: "Reviving",
	Expedition.State.WORKING: "Working",
	Expedition.State.JOURNEYING: "On the way",
}


## The top of the hero frames on the UI layer in a room of [param room] UI pixels: where the [Hud]
## puts them, scaled as [method fit] has the frame drawn.
static func frames_line(room: Vector2i) -> float:
	var scale: float = fit(room)
	return (float(room.y) / scale - FRAME_EDGE - HeroFrameView.SIZE.y) * scale


## The fraction the frame is drawn at in a room of [param room] UI pixels: 1, or less in a room
## smaller than [constant UiRoot.MIN_ROOM].
static func fit(room: Vector2i) -> float:
	return minf(1.0, minf(float(room.x) / UiRoot.MIN_ROOM.x, float(room.y) / UiRoot.MIN_ROOM.y))


## The speed button's tooltip.
static func speed_tip() -> String:
	return "How fast the game runs: click (or press %s) for 1x, 2x or 4x." % KeyBook.label(&"speed")


## The area's name's tooltip.
static func area_tip() -> String:
	return (
		"The area the party is in: click (or press %s) to open the Map."
		% KeyBook.label(AreaMapWindow.ID)
	)


## The countdown's tooltip while the Hold order keeps the party from a guardian.
static func holding_tip() -> String:
	return (
		"The Hold order keeps the party from the guardian: Orders (%s) sends it in."
		% KeyBook.label(UiRoot.ORDERS)
	)


## What the countdown says comes next while the party holds.
static func holding_next() -> String:
	return "Orders (%s) to go in" % KeyBook.label(UiRoot.ORDERS)

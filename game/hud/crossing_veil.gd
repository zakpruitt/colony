class_name CrossingVeil
extends Control
## The dark between places (spec 054 R2, R4, R8): it covers the world, under the rest of the HUD,
## as dark as [method ZoneCrossing.darkness] says, with the crossing's title in the middle.
## It follows the world's crossing by itself each frame; tests call [method refresh].

## The veil's colour, at full darkness.
const INK: StringName = &"ink"
## The title's colour and how many times the font's size it is drawn.
const TITLE_COLOUR: StringName = &"sand"
const TITLE_SCALE: int = 2
## How far above the middle of the screen the title sits, in pixels.
const TITLE_RAISE: float = 12.0

## The title as shown.
var title_label: Label

var _world: World


func _init() -> void:
	name = "CrossingVeil"
	process_priority = 3  # after the world (1) has synced, so it shows this frame's crossing
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Hud.SCREEN
	title_label = PixelText.label("", TITLE_COLOUR)
	title_label.name = "Title"
	title_label.scale = Vector2.ONE * TITLE_SCALE
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)


func _process(_delta: float) -> void:
	refresh()


## Call once: the veil follows [param world]'s crossing.
func setup(world: World) -> void:
	_world = world
	refresh()


## How dark the veil is, 0 to 1.
func darkness() -> float:
	return _darkness_now()


## Brings the veil and its title up to date with the world's crossing.
func refresh() -> void:
	var dark: float = _darkness_now()
	visible = dark > 0.0
	var text: String = _world.crossing.title() if _world != null and visible else ""
	if title_label.text != text:
		title_label.text = text
		title_label.reset_size()
	var width: float = PixelText.width(text) * TITLE_SCALE
	var height: float = PixelText.SIZE * TITLE_SCALE
	title_label.position = ((size - Vector2(width, height)) / 2.0 - Vector2(0, TITLE_RAISE)).round()
	queue_redraw()


func _darkness_now() -> float:
	if _world == null or _world.crossing == null:
		return 0.0
	return _world.crossing.darkness()


func _draw() -> void:
	var ink: Color = Palette.color(INK)
	ink.a = _darkness_now()
	draw_rect(Rect2(Vector2.ZERO, size), ink)

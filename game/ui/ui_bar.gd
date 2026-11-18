class_name UiBar
extends Control
## A thin bar on the UI layer (spec 059): a share of its length filled in a palette colour, the
## fill's bottom row a darker shade, on an [code]ink[/code] track with a one-pixel
## [code]dusk[/code] edge. The shop shows each upgrade's rank on one, the tally each hero's number
## and each of its abilities'. Its length is what its container gives it; its height
## [member custom_minimum_size].

## How much of the bar is filled, from 0 to 1.
var fraction: float = 0.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 1.0)
		if fraction != clamped:
			fraction = clamped
			queue_redraw()
## The fill's colour and its bottom row's, palette names.
var fill: StringName = &"green":
	set(value):
		if fill != value:
			fill = value
			queue_redraw()
var shade: StringName = &"forest":
	set(value):
		if shade != value:
			shade = value
			queue_redraw()


func _init(
	fill_colour: StringName = &"green", shade_colour: StringName = &"forest", height: int = 6
) -> void:
	name = "Bar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill = fill_colour
	shade = shade_colour
	custom_minimum_size.y = height


## Draws a bar on [param canvas] (spec 062: the old HUD's bar, kept for the frame's pieces): an
## [code]ink[/code] border around [param rect], filled from the left to [param fraction] in
## [param color] with a [param shade_color] bottom row, the rest [param empty]. The filled width is
## rounded to whole pixels.
static func draw_bar(
	canvas: CanvasItem,
	rect: Rect2,
	fraction_in: float,
	color: Color,
	shade_color: Color,
	empty: Color
) -> void:
	canvas.draw_rect(rect, Palette.color(&"ink"))
	var inner: Rect2 = rect.grow(-1.0)
	canvas.draw_rect(inner, empty)
	var filled: float = roundf(inner.size.x * clampf(fraction_in, 0.0, 1.0))
	if fraction_in > 0.0:
		filled = maxf(filled, 1.0)
	if filled <= 0.0:
		return
	canvas.draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), color)
	if inner.size.y >= 3.0:
		var bottom: Vector2 = inner.position + Vector2(0, inner.size.y - 1)
		canvas.draw_rect(Rect2(bottom, Vector2(filled, 1)), shade_color)


func _draw() -> void:
	var track := Rect2(Vector2.ZERO, size.floor())
	draw_rect(track, Palette.color(&"dusk"))
	var inner: Rect2 = track.grow(-1.0)
	draw_rect(inner, Palette.color(&"ink"))
	var width: float = roundf(inner.size.x * fraction)
	if width <= 0.0:
		return
	draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), Palette.color(fill))
	if inner.size.y >= 3.0:
		var bottom := Rect2(inner.position.x, inner.end.y - 1.0, width, 1.0)
		draw_rect(bottom, Palette.color(shade))

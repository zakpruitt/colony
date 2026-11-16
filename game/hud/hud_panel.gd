class_name HudPanel
extends Control
## A dark backing panel for HUD text and bars (spec 011, R8): a 1-pixel [code]ink[/code] border
## around a [code]night[/code] fill, lit by a [code]dusk[/code] bevel along the top and left
## inside the border (light comes from the top-left). Square corners, whole pixels.
## Everything a HUD label or bar shows sits on one of these, so it reads over sky and stone alike.

## The fill; a subclass may change it (a frame flashing, a dead hero dimmed).
var fill: Color = Palette.color(&"night")
## The bevel along the top and left edges, inside the border.
var bevel: Color = Palette.color(&"dusk")
## The border.
var border: Color = Palette.color(&"ink")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_panel(self, Rect2(Vector2.ZERO, size), fill, bevel, border)


## Draws a panel on [param canvas] in [param rect] (whole pixels): border, fill, top-left bevel.
static func draw_panel(
	canvas: CanvasItem, rect: Rect2, fill_color: Color, bevel_color: Color, border_color: Color
) -> void:
	canvas.draw_rect(rect, border_color)
	var inner: Rect2 = rect.grow(-1.0)
	canvas.draw_rect(inner, fill_color)
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), bevel_color)
	canvas.draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), bevel_color)


## Draws a bar on [param canvas]: an [code]ink[/code] border around [param rect], filled from the
## left to [param fraction] in [param color] with a [param shade] bottom row, the rest
## [param empty]. The filled width is rounded to whole pixels.
static func draw_bar(
	canvas: CanvasItem, rect: Rect2, fraction: float, color: Color, shade: Color, empty: Color
) -> void:
	canvas.draw_rect(rect, Palette.color(&"ink"))
	var inner: Rect2 = rect.grow(-1.0)
	canvas.draw_rect(inner, empty)
	var filled: float = roundf(inner.size.x * clampf(fraction, 0.0, 1.0))
	if fraction > 0.0:
		filled = maxf(filled, 1.0)
	if filled <= 0.0:
		return
	canvas.draw_rect(Rect2(inner.position, Vector2(filled, inner.size.y)), color)
	if inner.size.y >= 3.0:
		var bottom: Vector2 = inner.position + Vector2(0, inner.size.y - 1)
		canvas.draw_rect(Rect2(bottom, Vector2(filled, 1)), shade)

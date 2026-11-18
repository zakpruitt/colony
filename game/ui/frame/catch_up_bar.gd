class_name CatchUpBar
extends Control
## What the screen shows while the time away is replayed (spec 019 R3), on the sharp layer since
## spec 062 (R6): the whole room in [code]ink[/code], and in its middle a panel saying
## [code]Catching up...[/code] in the UI font over a bar that fills as the replay goes.

## The panel's size and the bar's, in UI pixels; the bar's top-left corner inside the panel.
const PANEL_SIZE: Vector2 = Vector2(220, 52)
const BAR_SIZE: Vector2 = Vector2(196, 10)
const BAR_AT: Vector2 = Vector2(12, 30)
## The caption's top inside the panel.
const CAPTION_Y: float = 9.0

## How full the bar is, from 0 to 1.
var fraction: float = 0.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()

var _label: Label


func _init() -> void:
	name = "CatchUpBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = UiText.label("Catching up...", &"white", true)
	_label.name = "Caption"
	add_child(_label)
	fit(Vector2(UiRoot.MIN_ROOM))


## The caption.
func text() -> String:
	return _label.text


## Covers a room of [param room] UI pixels, the panel in its middle.
func fit(room: Vector2) -> void:
	position = Vector2.ZERO
	size = room
	var width: float = UiText.width(_label.text, true) - UiText.SPACING
	_label.position = (
		panel_rect().position + Vector2(floorf((PANEL_SIZE.x - width) / 2.0), CAPTION_Y)
	)
	queue_redraw()


## The panel, in the bar's own UI pixels.
func panel_rect() -> Rect2:
	return Rect2(((size - PANEL_SIZE) / 2.0).floor(), PANEL_SIZE)


## The bar inside the panel, in the bar's own UI pixels.
func bar_rect() -> Rect2:
	return Rect2(panel_rect().position + BAR_AT, BAR_SIZE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"ink"))
	var panel: Rect2 = panel_rect()
	draw_rect(panel, Palette.color(&"steel"))
	draw_rect(panel.grow(-1.0), Palette.color(&"night"))
	UiBar.draw_bar(
		self,
		bar_rect(),
		fraction,
		Palette.color(&"yellow"),
		Palette.color(&"orange"),
		Palette.color(&"dusk")
	)

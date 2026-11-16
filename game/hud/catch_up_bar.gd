class_name CatchUpBar
extends Control
## What the screen shows while the time away is replayed (spec 019, R3): the whole screen in
## [code]ink[/code], and in its middle a HUD panel saying [code]Catching up...[/code] over a bar
## that fills as the replay goes.

## The panel's size, in pixels.
const PANEL_SIZE: Vector2 = Vector2(120, 32)
## The bar's size inside the panel, and its top-left corner relative to the panel.
const BAR_SIZE: Vector2 = Vector2(108, 7)
const BAR_AT: Vector2 = Vector2(6, 18)

## How full the bar is, from 0 to 1.
var fraction: float = 0.0:
	set(value):
		fraction = clampf(value, 0.0, 1.0)
		queue_redraw()

var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Hud.SCREEN
	_label = PixelText.label("Catching up...", &"white")
	_label.name = "Caption"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.reset_size()
	var width: float = PixelText.width(_label.text)
	_label.position = _panel_rect().position + Vector2(floorf((PANEL_SIZE.x - width) / 2.0), 5)


## The caption.
func text() -> String:
	return _label.text


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"ink"))
	var panel: Rect2 = _panel_rect()
	HudPanel.draw_panel(
		self, panel, Palette.color(&"night"), Palette.color(&"dusk"), Palette.color(&"ink")
	)
	HudPanel.draw_bar(
		self,
		Rect2(panel.position + BAR_AT, BAR_SIZE),
		fraction,
		Palette.color(&"yellow"),
		Palette.color(&"orange"),
		Palette.color(&"ink")
	)


func _panel_rect() -> Rect2:
	return Rect2(((Hud.SCREEN - PANEL_SIZE) / 2.0).floor(), PANEL_SIZE)

class_name ShopMarker
extends Control
## The badge on the HUD's Shop button saying something has become affordable (spec 017, R2): the
## number of affordable upgrades in [code]ink[/code] on a small [code]yellow[/code] tag that pulses
## to [code]orange[/code] and back, lifting a pixel on the beat. The HUD shows it only while the
## shop is closed and [member count] is above 0.

## Seconds of one pulse, bright half then dim half.
const PULSE_SECONDS: float = 0.8
## The tag's height in pixels.
const HEIGHT: float = 9.0

## How many upgrades the party can afford.
var count: int = 0:
	set(value):
		if count != value:
			count = value
			size = Vector2(PixelText.width(text()) + 3.0, HEIGHT)
			queue_redraw()

var _time: float = 0.0


func _init() -> void:
	name = "ShopMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(PixelText.width(text()) + 3.0, HEIGHT)


func _draw() -> void:
	var bright: bool = pulse() < 0.5
	var lift: float = 1.0 if bright else 0.0
	var rect := Rect2(Vector2(0, 1.0 - lift), Vector2(size.x, HEIGHT - 1.0))
	var fill: Color = Palette.color(&"yellow" if bright else &"orange")
	var shine: Color = Palette.color(&"white" if bright else &"amber")
	HudPanel.draw_panel(self, rect, fill, shine, Palette.color(&"ink"))
	draw_string(
		PixelText.font(),
		Vector2(2.0, rect.position.y + 7.0),
		text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PixelText.SIZE,
		Palette.color(&"ink")
	)


## Runs the pulse on by [param delta] seconds.
func advance(delta: float) -> void:
	var was_bright: bool = pulse() < 0.5
	_time = fmod(_time + delta, PULSE_SECONDS)
	if was_bright != (pulse() < 0.5):
		queue_redraw()


## Where the pulse is, from 0 to 1: bright for the first half, dim for the second.
func pulse() -> float:
	return _time / PULSE_SECONDS


## The number the tag shows.
func text() -> String:
	return str(count)

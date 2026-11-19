class_name UiBadge
extends Control
## The amber tag on a button of the bar: a number in [code]ink[/code] on a small
## [code]amber[/code] tag that pulses to
## [code]orange[/code] and back, lifting a pixel on the beat. [UiButtonBar] shows it at its
## button's top-right corner while its window's [member UiWindow.badge] is above 0, on a layer of
## its own over the bar's buttons and under the windows.

## Seconds of one pulse, bright half then dim half.
const PULSE_SECONDS: float = 0.8
## The tag's height, and the space either side of its number, in UI pixels.
const HEIGHT: float = 13.0
const PAD: float = 3.0

## The number the tag shows.
var count: int = 0:
	set(value):
		if count != value:
			count = value
			_fit()
			queue_redraw()

var _time: float = 0.0


func _init() -> void:
	name = "Badge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_fit()


func _draw() -> void:
	var bright: bool = pulse() < 0.5
	var rect := Rect2(Vector2(0, 0.0 if bright else 1.0), Vector2(size.x, HEIGHT))
	draw_rect(rect, Palette.color(&"ink"))
	var face: Rect2 = rect.grow(-1.0)
	draw_rect(face, Palette.color(&"amber" if bright else &"orange"))
	draw_rect(
		Rect2(face.position, Vector2(face.size.x, 1)),
		Palette.color(&"yellow" if bright else &"amber")
	)
	draw_string(
		UiText.font(true),
		Vector2(PAD + 1.0, rect.position.y + 11.0),
		text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiText.SIZE,
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


## The number the tag shows, as text.
func text() -> String:
	return str(count)


func _fit() -> void:
	size = Vector2(UiText.width(text(), true) - UiText.SPACING + 2.0 * (PAD + 1.0), HEIGHT + 1.0)

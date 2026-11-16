class_name HudButton
extends BaseButton
## A small pixel button for the HUD (spec 011): an [code]ink[/code] border, a flat fill lit by a
## one-pixel bevel along the top and left, and its text in the pixel font, all on whole pixels.
## Drawn by hand rather than with a theme so it is exactly [constant HEIGHT] pixels tall.
## [member lit] shows a toggle that is on.

## Every HUD button's height in pixels.
const HEIGHT: float = 11.0
## Pixels between the text and the border on either side.
const PADDING: float = 3.0
## The text's baseline, from the top of the button: capitals fill the five rows above it.
const BASELINE: float = 8.0

## The button's label.
var text: String = "":
	set(value):
		text = value
		_fit()
## True for a toggle that is on: it is drawn green.
var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()


func _init(label_text: String = "") -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = label_text


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var fill: StringName = &"dusk"
	var bevel: StringName = &"slate"
	var ink: StringName = &"silver"
	if lit:
		fill = &"forest"
		bevel = &"green"
		ink = &"white"
	match get_draw_mode():
		DRAW_HOVER:
			fill = &"green" if lit else &"slate"
			bevel = &"yellow" if lit else &"steel"
			ink = &"white"
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			fill = &"pine" if lit else &"night"
			bevel = fill
			ink = &"yellow"
	var rect := Rect2(Vector2.ZERO, size)
	HudPanel.draw_panel(
		self, rect, Palette.color(fill), Palette.color(bevel), Palette.color(&"ink")
	)
	var down: float = 1.0 if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 0.0
	var x: float = floorf((size.x - PixelText.width(text) + 1.0) / 2.0)
	draw_string(
		PixelText.font(),
		Vector2(x, BASELINE + down),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PixelText.SIZE,
		Palette.color(ink)
	)


func _get_minimum_size() -> Vector2:
	return Vector2(PixelText.width(text) - 1.0 + 2.0 * PADDING, HEIGHT)


func _fit() -> void:
	update_minimum_size()
	size = get_combined_minimum_size()
	queue_redraw()

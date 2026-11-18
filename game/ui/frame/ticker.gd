class_name Ticker
extends Panel
## The journal's newest line on the sharp layer (spec 062 R3, spec 027 R3): a one-line panel just
## above the hero frames, centred, in the UI font, while [method Journal.ticker_text] has a line;
## its text steps down through the journal's fade colours at the end. A left click on it emits
## [signal clicked] (the HUD opens the Journal window); it stops every click on it.

## A left click on the ticker.
signal clicked

## Space inside the panel's edge around the text, in UI pixels.
const PAD: Vector2 = Vector2(6, 3)
## The panel's height: a line of text and the padding.
const HEIGHT: float = UiText.LINE_HEIGHT + PAD.y * 2.0
## UI pixels between the ticker and the top of the hero frames.
const GAP: float = 4.0

var label: Label


func _init() -> void:
	name = "Ticker"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false
	label = UiText.label("", &"white")
	label.name = "Text"
	label.position = PAD
	add_child(label)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	accept_event()
	if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


## Shows [param text] in [param colour] (none for ""), centred across [param room_width] UI pixels
## with its bottom [constant GAP] above [param frames_top].
func show_line(text: String, colour: StringName, room_width: float, frames_top: float) -> void:
	visible = not text.is_empty()
	if not visible:
		return
	if label.text != text:
		label.text = text
		label.reset_size()
	label.add_theme_color_override(&"font_color", Palette.color(colour))
	var width: float = maxf(UiText.width(text) - UiText.SPACING, 0.0) + PAD.x * 2.0 + 1.0
	size = Vector2(width, HEIGHT)
	position = Vector2(floorf((room_width - width) / 2.0), frames_top - GAP - HEIGHT)

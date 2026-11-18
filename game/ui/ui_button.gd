class_name UiButton
extends Button
## A button on the UI layer (spec 058 R4), drawn by the theme ([UiTheme]): bold text, four states
## told apart, never smaller than [constant UiTheme.BUTTON_HEIGHT] UI pixels tall. A button that
## has a key shows it after its text in a dimmer colour ([code]Shop  U[/code]); [member lit] shows a
## toggle that is on, drawn as pressed.

## The gap between the text and the key hint, in UI pixels.
const HINT_GAP: int = 8

## The key that does what the button does, shown after its text; "" for none.
var key_hint: String = "":
	set(value):
		key_hint = value
		_fit()
## True for a toggle that is on: it is drawn lit (pressed) until switched off.
var lit: bool = false:
	set(value):
		if lit != value:
			lit = value
			set_pressed_no_signal(value)


func _init(label_text: String = "", key: String = "") -> void:
	text = label_text
	# A toggle, so a lit button can be drawn pressed; a click never changes that by itself.
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = UiTheme.BUTTON_HEIGHT
	key_hint = key


func _ready() -> void:
	toggled.connect(func(_on: bool) -> void: set_pressed_no_signal(lit))
	_fit()


func _draw() -> void:
	if key_hint.is_empty():
		return
	var mode: DrawMode = get_draw_mode()
	var colour: StringName = &"steel"
	if mode == DRAW_DISABLED:
		colour = &"dusk"
	elif mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED:
		colour = &"silver"
	var x: float = size.x - UiTheme.BUTTON_PAD_X - 1 - UiText.width(key_hint) + UiText.SPACING
	var baseline: float = floorf((size.y - UiText.LINE_HEIGHT) / 2.0) + UiText.ASCENT
	draw_string(
		UiText.font(),
		Vector2(x, baseline),
		key_hint,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiText.SIZE,
		Palette.color(colour)
	)


## The icon's, the text's and the hint's widths plus the padding: the least width that shows all.
func hinted_width() -> int:
	var inner: int = UiText.width(text, true) - UiText.SPACING if not text.is_empty() else 0
	if icon != null:
		inner += (
			icon.get_width() + (get_theme_constant(&"h_separation") if not text.is_empty() else 0)
		)
	if not key_hint.is_empty():
		inner += HINT_GAP + UiText.width(key_hint) - UiText.SPACING
	return inner + 2 * (UiTheme.BUTTON_PAD_X + 1)


func _fit() -> void:
	alignment = HORIZONTAL_ALIGNMENT_CENTER if key_hint.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size.x = hinted_width() if not key_hint.is_empty() else 0
	queue_redraw()

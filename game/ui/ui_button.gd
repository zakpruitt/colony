class_name UiButton
extends Button
## A button on the UI layer (spec 058 R4), drawn by the theme ([UiTheme]): bold text, four states
## told apart, never smaller than [constant UiTheme.BUTTON_HEIGHT] UI pixels tall. A button that
## has a key shows it after its text in a dimmer colour ([code]Shop  U[/code]), or set apart in a
## small key cap when [member key_cap] is set (spec 068: the button bar's); [member lit] shows a
## toggle that is on, drawn as pressed.

## The gap between the text and the key hint, in UI pixels.
const HINT_GAP: int = 8
## Space inside a key cap's edge, either side of its letter, in UI pixels.
const CAP_PAD: int = 2
## The gap between the text and a key cap.
const CAP_GAP: int = 5

## The key that does what the button does, shown after its text; "" for none.
var key_hint: String = "":
	set(value):
		key_hint = value
		_fit()
## Spec 068 R1: true to set the key apart in a small key cap, a dark box with a light edge round
## the letter.
var key_cap: bool = false:
	set(value):
		key_cap = value
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
	var colour: StringName = &"silver" if key_cap else &"steel"
	var edge: StringName = &"steel"
	if mode == DRAW_DISABLED:
		colour = &"slate" if key_cap else &"dusk"
		edge = &"dusk"
	elif mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED:
		colour = &"white" if key_cap else &"silver"
		edge = &"silver"
	var at: Rect2 = key_rect()
	var x: float = at.position.x
	if key_cap:
		# The cap: an edge all round, two pixels of it below, as a key stands off its board.
		draw_rect(at, Palette.color(edge))
		draw_rect(Rect2(at.position + Vector2.ONE, at.size - Vector2(2, 3)), Palette.color(&"ink"))
		x += CAP_PAD + 1
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


## Where the key is drawn, in the button's own pixels: its cap when [member key_cap] is set, else
## the letter's line; no area with no key.
func key_rect() -> Rect2:
	if key_hint.is_empty():
		return Rect2()
	var letter: float = UiText.width(key_hint) - UiText.SPACING
	var top: float = floorf((size.y - UiText.LINE_HEIGHT) / 2.0)
	var right: float = size.x - get_theme_stylebox(&"normal").get_margin(SIDE_RIGHT)
	if not key_cap:
		return Rect2(right - letter, top, letter, UiText.LINE_HEIGHT)
	var wide: float = letter + 2.0 * (CAP_PAD + 1)
	return Rect2(right - wide, top - 2.0, wide, UiText.LINE_HEIGHT + 2.0)


## The icon's, the text's and the hint's widths plus the padding: the least width that shows all.
func hinted_width() -> int:
	var bold: bool = get_theme_font(&"font") == UiText.font(true)
	var inner: int = UiText.width(text, bold) - UiText.SPACING if not text.is_empty() else 0
	if icon != null:
		inner += (
			icon.get_width() + (get_theme_constant(&"h_separation") if not text.is_empty() else 0)
		)
	if not key_hint.is_empty():
		inner += UiText.width(key_hint) - UiText.SPACING
		inner += CAP_GAP + 2 * (CAP_PAD + 1) if key_cap else HINT_GAP
	var box: StyleBox = get_theme_stylebox(&"normal")
	return inner + int(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT))


func _fit() -> void:
	alignment = HORIZONTAL_ALIGNMENT_CENTER if key_hint.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size.x = hinted_width() if not key_hint.is_empty() else 0
	queue_redraw()

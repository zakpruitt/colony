class_name UiButton
extends Button
## A button on the UI layer, drawn by the theme ([UiTheme]): bold text, four states
## told apart, never smaller than [constant UiTheme.BUTTON_HEIGHT] UI pixels tall. A button that
## has a key shows it after its text in a dimmer colour ([code]Shop  U[/code]), or set apart in a
## small key cap when [member key_cap] is set (as the button bar's are), which [member
## key_corner] makes smaller and puts at the button's top right corner; [member lit] shows a
## toggle that is on, drawn as pressed.

## The gap between the text and the key hint, in UI pixels.
const HINT_GAP: int = 8
## Space inside a key cap's edge, either side of its letter, in UI pixels.
const CAP_PAD: int = 2
## The gap between the text and a key cap.
const CAP_GAP: int = 5
## Space inside the edge of a key cap at the button's corner ([member key_corner]), either side of
## its letter and above it; its height, the edge two pixels thick below; and the least gap between
## it and the icon beside it.
const CORNER_PAD: int = 1
const CORNER_HEIGHT: int = UiText.CAP_HEIGHT + 2 * CORNER_PAD + 3
const CORNER_GAP: int = 1

## The key that does what the button does, shown after its text; "" for none.
var key_hint: String = "":
	set(value):
		key_hint = value
		_fit()
## True to set the key apart in a small key cap, a dark box with a light edge round
## the letter.
var key_cap: bool = false:
	set(value):
		key_cap = value
		_fit()
## True to make the key cap small and put it at the button's top right corner, over
## the button's own edge, for a button that is its icon over its name: the button is made wide
## enough that the icon in its middle stays clear of the cap.
var key_corner: bool = false:
	set(value):
		key_corner = value
		_fit()
## What the last draw put on the button for its key: the cap's box (no area with no cap) and the
## letter. Tests read them; a button that draws no key has neither.
var cap_drawn: Rect2 = Rect2()
var key_drawn: String = ""
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
	cap_drawn = Rect2()
	key_drawn = ""
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
	var letter := Vector2(at.position.x, at.position.y + UiText.ASCENT)
	if key_cap:
		# The cap: an edge all round, two pixels of it below, as a key stands off its board.
		var pad: int = CORNER_PAD if key_corner else CAP_PAD
		draw_rect(at, Palette.color(edge))
		draw_rect(Rect2(at.position + Vector2.ONE, at.size - Vector2(2, 3)), Palette.color(&"ink"))
		cap_drawn = at
		letter = at.position + Vector2(pad + 1, at.size.y - 3)
	draw_string(
		UiText.font(),
		letter,
		key_hint,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiText.SIZE,
		Palette.color(colour)
	)
	key_drawn = key_hint


## Where the key is drawn, in the button's own pixels: its cap when [member key_cap] is set (at
## the top right corner when [member key_corner] is), else the letter's line; no area with no key.
func key_rect() -> Rect2:
	if key_hint.is_empty():
		return Rect2()
	var letter: float = UiText.width(key_hint) - UiText.SPACING
	var top: float = floorf((size.y - UiText.LINE_HEIGHT) / 2.0)
	var right: float = size.x - get_theme_stylebox(&"normal").get_margin(SIDE_RIGHT)
	if not key_cap:
		return Rect2(right - letter, top, letter, UiText.LINE_HEIGHT)
	if key_corner:
		var small: float = letter + 2.0 * (CORNER_PAD + 1)
		return Rect2(size.x - small, 0.0, small, CORNER_HEIGHT)
	var wide: float = letter + 2.0 * (CAP_PAD + 1)
	return Rect2(right - wide, top - 2.0, wide, UiText.LINE_HEIGHT + 2.0)


## Where the icon is drawn, in the button's own pixels: at the left or in the middle, at the top
## or half way down, as its alignments say; no area with no icon.
func icon_rect() -> Rect2:
	if icon == null:
		return Rect2()
	var box: StyleBox = get_theme_stylebox(&"normal")
	var drawn: Vector2 = icon.get_size()
	var at := Vector2(box.get_margin(SIDE_LEFT), box.get_margin(SIDE_TOP))
	if icon_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		at.x = floorf((size.x - drawn.x) / 2.0)
	if vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER:
		at.y = floorf((size.y - drawn.y) / 2.0)
	return Rect2(at, drawn)


## Where the text's line is drawn, in the button's own pixels: under an icon at the top, else
## beside the icon; no area with no text.
func name_rect() -> Rect2:
	if text.is_empty():
		return Rect2()
	var box: StyleBox = get_theme_stylebox(&"normal")
	var wide: float = _text_width()
	var left: float = box.get_margin(SIDE_LEFT)
	var top: float = box.get_margin(SIDE_TOP)
	var room := Vector2(size.x - box.get_margin(SIDE_RIGHT), size.y - box.get_margin(SIDE_BOTTOM))
	var pictured: Rect2 = icon_rect()
	if pictured.has_area() and vertical_icon_alignment == VERTICAL_ALIGNMENT_TOP:
		top = pictured.end.y + get_theme_constant(&"h_separation")
	elif pictured.has_area() and icon_alignment == HORIZONTAL_ALIGNMENT_LEFT:
		left = pictured.end.x + get_theme_constant(&"h_separation")
	var at := Vector2(left, top + floorf((room.y - top - UiText.LINE_HEIGHT) / 2.0))
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		at.x = left + floorf((room.x - left - wide) / 2.0)
	return Rect2(at, Vector2(wide, UiText.LINE_HEIGHT))


## The icon's, the text's and the hint's widths plus the padding: the least width that shows all.
## With the cap at the corner ([member key_corner]) the icon stands over the text, so it is the
## wider of the text and the icon with a cap's width clear at both its sides.
func hinted_width() -> int:
	var box: StyleBox = get_theme_stylebox(&"normal")
	var sides: int = int(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT))
	var inner: int = int(_text_width())
	if _cornered():
		var cap: int = UiText.width(key_hint) - UiText.SPACING + 2 * (CORNER_PAD + 1)
		var pictured: int = icon.get_width() if icon != null else 0
		return maxi(inner + sides, pictured + 2 * (cap + CORNER_GAP))
	if icon != null:
		inner += (
			icon.get_width() + (get_theme_constant(&"h_separation") if not text.is_empty() else 0)
		)
	if not key_hint.is_empty():
		inner += UiText.width(key_hint) - UiText.SPACING
		inner += CAP_GAP + 2 * (CAP_PAD + 1) if key_cap else HINT_GAP
	return inner + sides


## True when the key is shown in a cap at the corner.
func _cornered() -> bool:
	return key_cap and key_corner and not key_hint.is_empty()


## The text's width in the button's font, without the space after its last letter.
func _text_width() -> float:
	if text.is_empty():
		return 0.0
	return UiText.width(text, get_theme_font(&"font") == UiText.font(true)) - UiText.SPACING


func _fit() -> void:
	var beside: bool = not key_hint.is_empty() and not _cornered()
	alignment = HORIZONTAL_ALIGNMENT_LEFT if beside else HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size.x = hinted_width() if not key_hint.is_empty() else 0
	queue_redraw()

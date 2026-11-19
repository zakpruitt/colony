class_name UiTheme
extends RefCounted
## The one look of the UI layer (spec 058 R4), defined here and nowhere else: windows, title bars,
## buttons, tabs, tooltips and scroll areas, all in palette colours and the UI font ([UiText]).
## [UiRoot] gives the theme to its frame, so every [Control] on the layer inherits it.
##
## A window is a dark [code]night[/code] panel with a one-pixel [code]steel[/code] edge and a
## slightly lighter [code]dusk[/code] title bar. A button shows four states apart: at rest
## [code]dusk[/code] with [code]silver[/code] text, under the mouse [code]slate[/code] with white
## text and a light edge, pressed (or lit, for a toggle that is on) [code]pine[/code] with a
## [code]green[/code] edge, disabled sunk into the panel with [code]slate[/code] text. Its text has
## [constant BUTTON_PAD_X] by [constant BUTTON_PAD_Y] UI pixels of padding inside the edge, so a
## button is at least [constant BUTTON_HEIGHT] tall.

## Theme type variations for the window's panel, its title bar, its title and the tooltip.
const WINDOW: StringName = &"UiWindow"
const TITLE_BAR: StringName = &"UiTitleBar"
const TITLE: StringName = &"UiTitle"
const TIP: StringName = &"UiTip"
## The panel every piece of the frame of the screen sits on (spec 061): the window's dark
## [code]night[/code] with a [code]slate[/code] edge, a step quieter than a window's.
const FRAME: StringName = &"UiFrame"
## Padding between a button's edge and its text, in UI pixels (the edge itself is one more), the
## same in every state: at least 4 all round (R4).
const BUTTON_PAD_X: int = 6
const BUTTON_PAD_Y: int = 4
## A button's least height: its text line, the padding above and below and the edge.
const BUTTON_HEIGHT: int = UiText.LINE_HEIGHT + 2 * (BUTTON_PAD_Y + 1)
## A button of the button bar (spec 068): [constant BAR_PAD_X] by [constant BAR_PAD_Y] of padding
## and its name in the plain weight, so six names and their keys fit the row, and [constant
## BAR_ICON_GAP] between its icon and its name. The colours are every button's.
const BAR_BUTTON: StringName = &"UiBarButton"
const BAR_PAD_X: int = 4
const BAR_PAD_Y: int = 3
const BAR_ICON_GAP: int = 4
## Space inside a window's edge around its content, and inside its title bar.
const WINDOW_PAD: int = 6
const TITLE_PAD: int = 4
## A button's box in each state: the state, its fill and its edge.
const BUTTON_BOXES: Array[Array] = [
	[&"normal", &"dusk", &"slate"],
	[&"hover", &"slate", &"silver"],
	[&"pressed", &"pine", &"green"],
	[&"hover_pressed", &"forest", &"yellow"],
	[&"disabled", &"night", &"dusk"],
]

static var _theme: Theme


## The UI layer's theme, made once.
static func theme() -> Theme:
	if _theme == null:
		_theme = _make()
	return _theme


## A flat box in the palette colours [param fill] and [param edge] (one pixel), with
## [param pad_x] and [param pad_y] pixels between the edge and the content.
static func box(fill: StringName, edge: StringName, pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var made := StyleBoxFlat.new()
	made.anti_aliasing = false
	made.bg_color = Palette.color(fill)
	made.border_color = Palette.color(edge)
	made.set_border_width_all(0 if edge == fill else 1)
	var edge_width: int = 0 if edge == fill else 1
	made.content_margin_left = pad_x + edge_width
	made.content_margin_right = pad_x + edge_width
	made.content_margin_top = pad_y + edge_width
	made.content_margin_bottom = pad_y + edge_width
	return made


static func _make() -> Theme:
	var made := Theme.new()
	made.default_font = UiText.font()
	made.default_font_size = UiText.SIZE
	made.set_color(&"font_color", &"Label", Palette.color(&"silver"))
	_buttons(made)
	_windows(made)
	_tooltips(made)
	_scrolling(made)
	_tabs(made)
	return made


static func _buttons(made: Theme) -> void:
	made.set_font(&"font", &"Button", UiText.font(true))
	made.set_font_size(&"font_size", &"Button", UiText.SIZE)
	made.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	made.set_color(&"font_color", &"Button", Palette.color(&"silver"))
	made.set_color(&"font_hover_color", &"Button", Palette.color(&"white"))
	made.set_color(&"font_pressed_color", &"Button", Palette.color(&"white"))
	made.set_color(&"font_hover_pressed_color", &"Button", Palette.color(&"yellow"))
	made.set_color(&"font_focus_color", &"Button", Palette.color(&"silver"))
	made.set_color(&"font_disabled_color", &"Button", Palette.color(&"slate"))
	made.set_constant(&"h_separation", &"Button", 4)
	made.set_type_variation(BAR_BUTTON, &"Button")
	for state: Array in BUTTON_BOXES:
		var look: StringName = state[0]
		var fill: StringName = state[1]
		var edge: StringName = state[2]
		made.set_stylebox(look, &"Button", box(fill, edge, BUTTON_PAD_X, BUTTON_PAD_Y))
		made.set_stylebox(look, BAR_BUTTON, box(fill, edge, BAR_PAD_X, BAR_PAD_Y))
	made.set_constant(&"h_separation", BAR_BUTTON, BAR_ICON_GAP)
	made.set_constant(&"icon_max_width", BAR_BUTTON, 16)
	made.set_font(&"font", BAR_BUTTON, UiText.font())


static func _windows(made: Theme) -> void:
	made.set_type_variation(WINDOW, &"PanelContainer")
	made.set_stylebox(&"panel", WINDOW, box(&"night", &"steel"))
	made.set_type_variation(TITLE_BAR, &"PanelContainer")
	made.set_stylebox(&"panel", TITLE_BAR, box(&"dusk", &"dusk", TITLE_PAD, 1))
	made.set_type_variation(TITLE, &"Label")
	made.set_font(&"font", TITLE, UiText.font(true))
	made.set_color(&"font_color", TITLE, Palette.color(&"yellow"))
	made.set_stylebox(&"panel", &"PanelContainer", StyleBoxEmpty.new())
	made.set_type_variation(FRAME, &"Panel")
	made.set_stylebox(&"panel", FRAME, box(&"night", &"slate"))


static func _tooltips(made: Theme) -> void:
	made.set_type_variation(TIP, &"PanelContainer")
	made.set_stylebox(&"panel", TIP, box(&"ink", &"steel", 5, 3))
	made.set_stylebox(&"panel", &"TooltipPanel", box(&"ink", &"steel", 5, 3))
	made.set_color(&"font_color", &"TooltipLabel", Palette.color(&"white"))


static func _scrolling(made: Theme) -> void:
	made.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	var track: StyleBoxFlat = box(&"ink", &"ink")
	track.content_margin_left = 3
	track.content_margin_right = 3
	made.set_stylebox(&"scroll", &"VScrollBar", track)
	made.set_stylebox(&"scroll_focus", &"VScrollBar", track)
	made.set_stylebox(&"grabber", &"VScrollBar", box(&"slate", &"slate"))
	made.set_stylebox(&"grabber_highlight", &"VScrollBar", box(&"steel", &"steel"))
	made.set_stylebox(&"grabber_pressed", &"VScrollBar", box(&"silver", &"silver"))


static func _tabs(made: Theme) -> void:
	for type: StringName in [&"TabBar", &"TabContainer"]:
		made.set_font(&"font", type, UiText.font(true))
		made.set_stylebox(&"tab_selected", type, box(&"night", &"steel", 6, 3))
		made.set_stylebox(&"tab_unselected", type, box(&"dusk", &"slate", 6, 3))
		made.set_stylebox(&"tab_hovered", type, box(&"slate", &"silver", 6, 3))
		made.set_stylebox(&"tab_disabled", type, box(&"night", &"dusk", 6, 3))
		made.set_color(&"font_selected_color", type, Palette.color(&"yellow"))
		made.set_color(&"font_unselected_color", type, Palette.color(&"silver"))
		made.set_color(&"font_hovered_color", type, Palette.color(&"white"))
		made.set_color(&"font_disabled_color", type, Palette.color(&"slate"))
	made.set_stylebox(&"panel", &"TabContainer", box(&"night", &"steel", 6, 6))

class_name UiButtonBar
extends HBoxContainer
## The row of window buttons, at the bottom right of the UI layer just
## above the line of the hero frames: one button per window on the layer, in the order the windows
## were made. Each says what it opens: its window's icon, the window's short name
## ([member UiWindow.short_name]) and its key in a small key cap. A click opens or closes the
## window; a button
## is lit while its window is open; resting on one gives the window's title, its key and what it
## is for in one sentence ([code]Journal (J): what has happened to the party, newest first.[/code]),
## all from the window's [WindowEntry].
## The last button, [member reset_button], puts every window back in its default place.
##
## The row has two forms ([method fit_room]). With room for it, each button is its
## icon, its name and its key side by side, [constant ROW_HEIGHT] tall. Where that would reach
## into the [constant LEFT_ROOM] the bar leaves at its left (960x540), each button is its icon
## over its name, [constant NARROW_HEIGHT] tall, with its key in a smaller cap at its top right
## corner ([member UiButton.key_corner]), so every name stays whole in one row. Only in a room
## where that too would reach into what the bar must leave ([constant NARROW_LEFT_ROOM]) are the
## keys dropped from the buttons ([member shows_keys] is false; the tooltips still name them).
## The buttons are [constant UiTheme.BAR_BUTTON]s, padded a little less than other buttons.
##
## A window's amber tag stands on the top left corner of its button's icon, no more than
## [constant TAG_OUTSIDE] outside the button, so a window beside the bar never cuts it, and clear
## of the name and the key.

## UI pixels between the bar and the room's right edge, and above the hero frames' line.
const MARGIN: float = 8.0
const ABOVE_FRAMES: float = 4.0
## A button's height, around its 16x16 icon, when the icon, the name and the key stand side by
## side.
const ROW_HEIGHT: float = 28.0
## A button's height in the narrower form: its icon over a line of text and the padding, with a
## pixel more so the name stands clear of the icon (a button lays the line out two pixels under
## the icon at this height, touching it at any less).
const NARROW_HEIGHT: float = 16.0 + 1.0 + UiText.LINE_HEIGHT + 2.0 * (UiTheme.BAR_PAD_Y + 1)
## UI pixels between two buttons.
const GAP: int = 2
## UI pixels the bar leaves free at its left with its buttons side by side: what the fourth hero
## window, cascaded from the left, needs beside it at 1280x720.
const LEFT_ROOM: float = 754.0
## UI pixels the bar leaves free at its left in its narrower form: what a hero window's default
## place and the ticker's longest line need at 960x540, which leaves the bar 317.
const NARROW_LEFT_ROOM: float = 635.0
## How far a tag lies over its button's icon, from the icon's top left corner, and
## the most it reaches outside the button (no more than [constant GAP], so never onto the next).
const TAG_ON_ICON: float = 6.0
const TAG_OUTSIDE: float = 2.0
## The reset button's word and tooltip.
const RESET_NAME: String = "Reset"
const RESET_TIP: String = "Put every window back in its place"

## True while the buttons show their keys; false in a room too narrow for that.
var shows_keys: bool = true
## True while each button is its icon over its name, its key at its corner.
var stacked: bool = false
## A button per window id.
var buttons: Dictionary[StringName, UiButton] = {}
## Each button's amber tag, shown while its window's [member UiWindow.badge] is
## above 0: told by its content's [signal WindowContent.badge_changed], never looked for.
var badges: Dictionary[StringName, UiBadge] = {}
## The tags' own layer, just after the bar on the UI layer: drawn over every button,
## and under every window, which come later.
var tag_layer: Control
## Puts every window back where a new game has it.
var reset_button: UiButton
## The tooltip the buttons share.
var tip: UiTip

var _ui: UiRoot
## The room the bar was last laid out for.
var _fitted: Vector2i = Vector2i.ZERO
var _windows: UiWindows


func _init() -> void:
	name = "ButtonBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", GAP)


## Runs the pulse of each tag shown on by [param delta] seconds. Called every frame by [UiRoot];
## tests call it.
func advance(delta: float) -> void:
	for id: StringName in badges:
		var tag: UiBadge = badges[id]
		if tag.visible:
			tag.advance(delta)


## Call once, after the windows are registered with [param windows].
func setup(ui: UiRoot, windows: UiWindows) -> void:
	_ui = ui
	_windows = windows
	tip = UiTip.new()
	ui.frame.add_child(tip)
	tag_layer = Control.new()
	tag_layer.name = "Tags"
	tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.frame.add_child(tag_layer)
	ui.frame.move_child(tag_layer, get_index() + 1)
	windows.changed.connect(refresh)
	item_rect_changed.connect(refresh)  # the tags stand on the buttons wherever they go
	reset_button = UiButton.new(RESET_NAME)
	reset_button.name = "Reset"
	reset_button.icon = _icon(&"reset")
	reset_button.theme_type_variation = UiTheme.BAR_BUTTON
	reset_button.pressed.connect(windows.reset_places)
	add_child(reset_button)
	tip.attach(reset_button, RESET_TIP)
	rebuild()


## Makes a button for each window of the layer's [member UiRoot.entries], in their order, its
## name, key and tooltip theirs; then lays the bar out.
func rebuild() -> void:
	for entry: WindowEntry in _ui.entries:
		var id: StringName = entry.id
		var shown: UiWindow = _windows.window(id)
		if buttons.has(id) or shown == null or not shown.on_bar:
			continue
		var button := UiButton.new(entry.short_name)
		button.name = "Button_%s" % id
		button.icon = shown.icon
		button.theme_type_variation = UiTheme.BAR_BUTTON
		button.key_cap = true
		button.pressed.connect(_windows.toggle.bind(id))
		add_child(button)
		move_child(button, reset_button.get_index())
		buttons[id] = button
		tip.attach(button, entry.tip())
		button.item_rect_changed.connect(refresh)
		var tag := UiBadge.new()
		tag.name = "Badge_%s" % id
		tag_layer.add_child(tag)
		badges[id] = tag
		var told: WindowContent = shown.content as WindowContent
		if told != null:
			told.badge_changed.connect(_on_badge_changed.unbind(1))
	fit_room(_ui.room())
	refresh()


## Lights each button whose window is open, and shows each window's tag on the top left corner of
## its button's icon.
func refresh() -> void:
	for id: StringName in buttons:
		buttons[id].lit = _windows.is_open(id)
		var tag: UiBadge = badges.get(id, null)
		if tag == null:
			continue
		tag.count = _windows.window(id).badge
		tag.visible = tag.count > 0
		tag.position = position + buttons[id].position + tag_place(buttons[id], tag.size)


## A window's content said its tag changed: [UiWindow] has taken the count in already.
func _on_badge_changed() -> void:
	refresh()


## Where a tag of [param tag_size] stands on [param button], in the button's own pixels: over the
## top left corner of its icon by [constant TAG_ON_ICON], and no more than [constant TAG_OUTSIDE]
## outside the button.
static func tag_place(button: UiButton, tag_size: Vector2) -> Vector2:
	var corner: Vector2 = button.icon_rect().position + Vector2(TAG_ON_ICON, TAG_ON_ICON)
	return (corner - tag_size).max(Vector2(-TAG_OUTSIDE, -TAG_OUTSIDE))


## Puts the bar at the bottom right of a room of [param room] UI pixels, above the frames' line,
## in the first form that fits it: icon, name and key side by side; each icon over
## its name with the key at the button's corner; the same without the keys.
func fit_room(room: Vector2i) -> void:
	if _ui == null:
		return
	_fitted = room
	_shape(false, true)
	if get_combined_minimum_size().x > room.x - MARGIN - LEFT_ROOM:
		_shape(true, true)
		if get_combined_minimum_size().x > room.x - MARGIN - NARROW_LEFT_ROOM:
			_shape(true, false)
	reset_size()
	size = get_combined_minimum_size()
	position = rect_in(room).position


## Where the bar stands in a room of [param room] UI pixels: at the right, just above the hero
## frames' line (the hero windows keep clear of it). The bar's size goes by the room, so a room
## it is not yet laid out for is fitted first: whoever asks before the layer has told the bar of
## a new room still gets that room's answer.
func rect_in(room: Vector2i) -> Rect2:
	if _ui == null:
		return Rect2()
	if room != _fitted:
		fit_room(room)
	var line: float = floorf(HudFrame.frames_line(room))
	return Rect2(Vector2(room.x - MARGIN - size.x, line - ABOVE_FRAMES - size.y).round(), size)


## Gives every button its form: its icon, name and key side by side, or ([param over]) its icon
## over its name; [param keys] for the key on the button, at its corner when the icon is over the
## name, else it is left to the tooltip.
func _shape(over: bool, keys: bool) -> void:
	stacked = over
	shows_keys = keys
	var row: Array[UiButton] = [reset_button]
	row.append_array(buttons.values())
	for button: UiButton in row:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if over else HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = (
			VERTICAL_ALIGNMENT_TOP if over else VERTICAL_ALIGNMENT_CENTER
		)
		# Icon over name, a button's own layout counts the name's height twice: the icon is
		# left out of its sums (expand_icon; the theme holds it at its 16 pixels) and the
		# height given here.
		button.expand_icon = over
		button.custom_minimum_size.y = NARROW_HEIGHT if over else ROW_HEIGHT
	for id: StringName in buttons:
		buttons[id].key_corner = over
		buttons[id].key_hint = _windows.window(id).key_hint if keys else ""


func _icon(part: StringName) -> Texture2D:
	var sheet: PixelSheet = PixelSheet.load_sheet(UiRoot.ICONS_PATH)
	return sheet.part(part) if sheet != null and sheet.has_part(part) else null

class_name UiTip
extends PanelContainer
## The UI layer's tooltip (spec 058 R4, R7): a title in bold where there is one, then one or two
## plain sentences wrapped to [constant WIDTH], in a small dark box, shown once the mouse has
## rested [constant DELAY] seconds on a control it was attached to, above the control (below it if
## there is no room above), always inside the room and never over the control. Drawn by the theme's
## [constant UiTheme.TIP] look and never in the way of a click.
##
## A tip hears the mouse through each control's own entering and leaving, or, with
## [member follows_mouse] (spec 061: the frame of the screen, whose labels take no mouse), by
## finding which of its controls is under each move of the mouse, as [method point_at] does for
## tests. [member covered] says where the mouse is on something in front (a window), which is
## nowhere for a tip that follows the mouse.
##
## Spec 063 R3: a control may be given a card instead ([method attach_card]): the picture of what it
## stands for, a bold title, a grey line saying what kind of thing it is, the body wrapped to
## [constant CARD_WIDTH], and a last line in a colour of the caller's choice saying how it stands.

## Seconds the mouse rests on a control before its tip shows.
const DELAY: float = 0.4
## UI pixels between the tip and its control.
const GAP: float = 4.0
## The widest a tip's text runs before it wraps, in UI pixels.
const WIDTH: float = 240.0
## Where the mouse is when it is nowhere.
const NOWHERE: Vector2 = Vector2(-10000, -10000)
## The widest a card's words run, in UI pixels, and the gap between its picture and its words.
const CARD_WIDTH: float = 240.0
const CARD_GAP: float = 6.0
## A card's picture: the 16x16 picture at twice its size.
const CARD_PICTURE: Vector2 = Vector2(32, 32)

## The sentences, and the bold title over them (hidden when there is none).
var label: Label
var title_label: Label
## True for a tip that finds its control under the mouse itself (see the class description).
var follows_mouse: bool = false
## Given a point in the viewport's coordinates (where input events are), true while something in
## front covers it; unset, nothing does.
var covered: Callable
## A card's parts (spec 063 R3), shown instead of [member label] while a card shows.
var card_picture: TextureRect
var card_title: Label
var card_kind: Label
var card_body: Label
var card_stand: Label
## The room the tip stays inside, in its parent's pixels from the parent's top left; zero for the
## parent's own size.
var room: Vector2 = Vector2.ZERO

## Each control's text and title: a String, or a Callable that returns one.
var _texts: Dictionary[Control, Variant] = {}
var _titles: Dictionary[Control, Variant] = {}
## The order controls were attached in: the first under a point wins.
var _order: Array[Control] = []
var _hovered: Control
var _rested: float = 0.0
var _box: VBoxContainer
## Each carded control's card: a Callable returning a [UiTip.Card].
var _cards: Dictionary[Control, Callable] = {}
var _card_box: Control
## What the card showing was made from, to tell when it changes.
var _card_key: String = ""


func _init() -> void:
	name = "Tip"
	theme_type_variation = UiTheme.TIP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override(&"separation", 1)
	add_child(_box)
	title_label = UiText.label("", &"yellow", true)
	title_label.name = "Title"
	title_label.visible = false
	_box.add_child(title_label)
	label = Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", Palette.color(&"white"))
	_box.add_child(label)
	_make_card()


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not follows_mouse:
		return
	if covered.is_valid() and covered.call(motion.position):
		point_at(NOWHERE)
		return
	# Through the layer's transform, never a camera's.
	var layer: CanvasLayer = get_canvas_layer_node()
	var to_canvas: Transform2D = (
		layer.get_final_transform() if layer != null else Transform2D.IDENTITY
	)
	point_at(to_canvas.affine_inverse() * motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and follows_mouse:
		point_at(NOWHERE)


## Gives [param control] the tip [param text] (a String, or a Callable returning one, read as the
## tip shows) under the bold [param title] ("" for none); a second call changes them, and replaces
## a card it was given. A control freed since it was given a tip is forgotten.
func attach(control: Control, text: Variant, title: Variant = "") -> void:
	_forget_freed()
	_cards.erase(control)
	if not _texts.has(control):
		_order.append(control)
		if not follows_mouse:
			control.mouse_entered.connect(_on_entered.bind(control))
			control.mouse_exited.connect(_on_exited.bind(control))
	_texts[control] = text
	_titles[control] = title


## Gives [param control] a card: [param card] is called as the tip shows and returns the
## [UiTip.Card] to show. A second call changes it; a later [method attach] replaces it.
func attach_card(control: Control, card: Callable) -> void:
	attach(control, "")
	_cards[control] = card


## The card [param control] was given (spec 065), made now; null when it has none.
func card_for(control: Control) -> Card:
	if not _cards.has(control):
		return null
	return _cards[control].call() as Card


## True while the tip showing is a card.
func card_shown() -> bool:
	return visible and _card_box.visible


## How many controls have a tip or a card (those freed since not counted).
func attached_count() -> int:
	_forget_freed()
	return _order.size()


## The tip [param control] was given, or "".
func text_for(control: Control) -> String:
	return _read(_texts.get(control, ""))


## The title [param control] was given, or "".
func title_for(control: Control) -> String:
	return _read(_titles.get(control, ""))


## The sentences showing now, or "" while hidden or showing a card.
func shown_text() -> String:
	return label.text if visible and _box.visible else ""


## The title showing now, or "" while hidden or untitled.
func shown_title() -> String:
	return title_label.text if visible and _box.visible and title_label.visible else ""


## The control whose tip is showing or waiting to, or null.
func hovered() -> Control:
	return _hovered


## Puts the mouse at [param at] (global coordinates of this tip's canvas, [constant NOWHERE] for
## none): the first visible control attached under it is hovered. A move onto another control
## starts the delay again; a move off every control hides the tip at once.
func point_at(at: Vector2) -> void:
	_forget_freed()
	var found: Control = null
	for control: Control in _order:
		if (
			is_instance_valid(control)
			and control.is_visible_in_tree()
			and control.get_global_rect().has_point(at)
		):
			found = control
			break
	if found == _hovered:
		return
	if found == null:
		_on_exited(_hovered)
	else:
		_on_entered(found)


## Counts the mouse's rest on by [param delta] seconds, and shows the tip once it is long enough.
## Called every frame; tests call it.
func advance(delta: float) -> void:
	if _hovered == null or not is_instance_valid(_hovered) or not _hovered.is_visible_in_tree():
		_hovered = null
		visible = false
		return
	_rested += delta
	if _rested >= DELAY:
		_show()


## Drops every control freed since it was given a tip, so none is kept for good.
func _forget_freed() -> void:
	var kept: Array[Control] = []
	for control: Variant in _order:
		if is_instance_valid(control):
			kept.append(control as Control)
	if kept.size() == _order.size():
		return
	var texts: Dictionary[Control, Variant] = {}
	var titles: Dictionary[Control, Variant] = {}
	var cards: Dictionary[Control, Callable] = {}
	for control: Control in kept:
		texts[control] = _texts[control]
		titles[control] = _titles[control]
		if _cards.has(control):
			cards[control] = _cards[control]
	_order = kept
	_texts = texts
	_titles = titles
	_cards = cards
	if not is_instance_valid(_hovered):
		_hovered = null


func _show() -> void:
	if _cards.has(_hovered):
		_show_card(_cards[_hovered].call() as Card)
		return
	_card_box.visible = false
	_box.visible = true
	_card_key = ""
	var text: String = _read(_texts.get(_hovered, ""))
	var title: String = _read(_titles.get(_hovered, ""))
	if visible and text == label.text and title == title_label.text:
		_place()
		return
	title_label.text = title
	title_label.visible = not title.is_empty()
	label.text = text
	# Wrapped at WIDTH: a short tip is as wide as its text, a long one runs onto more lines.
	var widest: float = UiText.width(title, true) - UiText.SPACING
	for line: String in text.split("\n"):
		widest = maxf(widest, UiText.width(line) - UiText.SPACING)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var width: float = minf(widest + 1.0, WIDTH)
	label.custom_minimum_size.x = width
	# A wrapping label's height is its lines at its width now: give it that width before asking,
	# or it wraps at whatever width it had. The cached minimum sizes (which clamp every size set
	# here) catch up only on the next frame, so they are cleared, and the box is sized by hand:
	# the title, the wrapped lines and the panel's padding.
	label.size = Vector2(width, label.size.y)
	for control: Control in [label, title_label, _box, self]:
		control.update_minimum_size()
	var inner := Vector2(width, label.get_minimum_size().y)
	label.size = inner
	var text_y: float = 0.0
	if title_label.visible:
		var title_size: Vector2 = title_label.get_combined_minimum_size()
		inner.x = maxf(inner.x, title_size.x)
		text_y = title_size.y + float(_box.get_theme_constant(&"separation"))
		inner.y += text_y
		title_label.position = Vector2.ZERO
		title_label.size = title_size
	label.position = Vector2(0.0, text_y)
	var panel: StyleBox = get_theme_stylebox(&"panel")
	reset_size()
	size = (inner + panel.get_minimum_size()).ceil()
	_box.position = Vector2(panel.get_margin(SIDE_LEFT), panel.get_margin(SIDE_TOP))
	_box.size = inner
	_place()
	visible = true


## Puts the box above its control, or below it with no room above, inside the room.
func _place() -> void:
	var parent: Control = get_parent() as Control
	var inside: Vector2 = room
	if inside == Vector2.ZERO:
		inside = parent.size if parent != null else size
	var to_local: Transform2D = (
		parent.get_global_transform().affine_inverse() if parent != null else Transform2D.IDENTITY
	)
	var over: Rect2 = to_local * _hovered.get_global_rect()
	var at := Vector2(over.get_center().x - size.x / 2.0, over.position.y - GAP - size.y)
	if at.y < 0.0:
		at.y = over.end.y + GAP
	at.x = clampf(at.x, 0.0, maxf(inside.x - size.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(inside.y - size.y, 0.0))
	position = at.round()


func _on_entered(control: Control) -> void:
	_hovered = control
	_rested = 0.0
	visible = false


func _on_exited(control: Control) -> void:
	if _hovered == control:
		_hovered = null
		visible = false


static func _read(source: Variant) -> String:
	if source is Callable:
		return str((source as Callable).call())
	return str(source)


## A card (spec 063 R3): what to show in a tooltip that is a card.
class Card:
	extends RefCounted
	## The id of the thing whose picture shows ([method UiIcon.picture]).
	var picture_id: StringName
	## The bold title, and the grey line under it saying what kind of thing it is.
	var title: String
	var kind: String
	## The words, wrapped to the card's width.
	var body: String
	## The last line, how the thing stands ("Click to learn"), in the palette colour
	## [member stand_colour]; "" for none.
	var stand: String
	var stand_colour: StringName = &"yellow"


func _make_card() -> void:
	_card_box = Control.new()
	_card_box.name = "Card"
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.visible = false
	add_child(_card_box)
	card_picture = TextureRect.new()
	card_picture.name = "Picture"
	card_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_picture.stretch_mode = TextureRect.STRETCH_SCALE
	card_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_picture.size = CARD_PICTURE
	_card_box.add_child(card_picture)
	card_title = WindowText.label("CardTitle", "", &"white", true)
	card_kind = WindowText.label("CardKind", "", &"steel")
	card_body = WindowText.label("CardBody", "", &"silver")
	card_stand = WindowText.label("CardStand", "", &"yellow")
	for part: Label in [card_title, card_kind, card_body, card_stand]:
		_card_box.add_child(part)


## Shows [param card]: the picture at the left, and beside it the title, the kind, the body wrapped
## and the stand, each line [constant UiText.LINE_HEIGHT] under the last.
func _show_card(card: Card) -> void:
	if card == null:
		visible = false
		return
	var key: String = (
		"%s|%s|%s|%s|%s|%s"
		% [card.picture_id, card.title, card.kind, card.body, card.stand, card.stand_colour]
	)
	if visible and _card_box.visible and key == _card_key:
		_place()
		return
	_card_key = key
	_box.visible = false
	_card_box.visible = true
	card_picture.texture = UiIcon.picture(card.picture_id)
	card_picture.visible = card_picture.texture != null
	var words_x: float = CARD_PICTURE.x + CARD_GAP if card_picture.visible else 0.0
	var widest: float = maxf(
		UiText.width(card.title, true), maxf(UiText.width(card.kind), UiText.width(card.stand))
	)
	widest = maxf(widest, UiText.width(card.body)) - UiText.SPACING
	var width: float = ceilf(minf(widest, CARD_WIDTH))
	WindowText.set_text(card_title, card.title)
	WindowText.set_text(card_kind, card.kind)
	var lines: Array[String] = WindowText.wrap(card.body, width)
	WindowText.set_text(card_body, "\n".join(PackedStringArray(lines)))
	WindowText.set_text(card_stand, card.stand)
	card_stand.add_theme_color_override(&"font_color", Palette.color(card.stand_colour))
	var y: float = 0.0
	var inner_width: float = 0.0
	for part: Label in [card_title, card_kind, card_body, card_stand]:
		part.visible = not part.text.is_empty()
		if not part.visible:
			continue
		part.position = Vector2(words_x, y)
		y += part.size.y
		inner_width = maxf(inner_width, words_x + part.size.x)
	var inner := Vector2(inner_width, maxf(y, CARD_PICTURE.y if card_picture.visible else 0.0))
	var panel: StyleBox = get_theme_stylebox(&"panel")
	for control: Control in [_box, _card_box, self]:
		control.update_minimum_size()
	_card_box.custom_minimum_size = inner
	reset_size()
	size = (inner + panel.get_minimum_size()).ceil()
	_card_box.position = Vector2(panel.get_margin(SIDE_LEFT), panel.get_margin(SIDE_TOP))
	_card_box.size = inner
	_place()
	visible = true

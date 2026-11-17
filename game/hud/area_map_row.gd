class_name AreaMapRow
extends Control
## One area's row on the area map (spec 053): its name with [code]Here[/code] or
## [code]On the way, 7 s[/code] after it, the level of its first stage, the party's safe and
## furthest stage there, and at the right the monsters that live there and, after a gap, its
## guardian (ticked once beaten). A closed area's row is dimmed and says which guardian opens it.
## Spec 052: at the end of the text column, on the last line, the area's resource: its icon and
## how many the party holds ([code]12 glowcaps[/code]), or for a closed area what opening it
## gives ([code]Gives clay[/code]).
##
## The row is a button: an open area's row is lit under the mouse as a [HudButton] is, and a left
## click emits [signal clicked]; a closed area's row takes the click and does nothing. The chosen
## row has a [code]yellow[/code] outline.

## A left click on an open area's row.
signal clicked

## The row's height: a guardian's thumb and a pixel either side.
const HEIGHT: float = 34.0
## A line of text's height.
const LINE: float = 9.0
## Where the text starts, and the thumbs after the text column.
const TEXT_X: float = 4.0
const TEXT_Y: float = 3.0
const THUMBS_GAP: float = 8.0
## Pixels between the monsters and the guardian.
const GUARDIAN_GAP: float = 8.0
## Pixels between the resource and the stages before it, and between its icon and its text.
const RESOURCE_GAP: float = 8.0
const RESOURCE_ICON_GAP: float = 2.0

## The area shown.
var area_id: StringName
## The area's name, the tag after it, and the two lines under it.
var name_label: Label
var tag_label: Label
var level_label: Label
var stages_label: Label
## The monsters that live there, in the area's order, and its guardian.
var thumbs: Array[MonsterThumb] = []
var guardian_thumb: MonsterThumb
## The area's resource (spec 052): its icon and the count held, or what opening the area gives.
var resource_icon: TextureRect
var resource_label: Label
## True while the area is open, and while it is the one chosen.
var is_open: bool = false
var chosen: bool = false:
	set(value):
		if chosen != value:
			chosen = value
			queue_redraw()

var _hovered: bool = false
## Where the text column ends: the resource ends there.
var _text_end: float = 0.0


func _init(id: StringName) -> void:
	area_id = id
	name = "Row_%s" % id
	mouse_filter = Control.MOUSE_FILTER_STOP
	var def: AreaDef = Content.area(id)
	name_label = _add(PlaceText.area_name(id), &"white", Vector2(TEXT_X, TEXT_Y))
	tag_label = _add("", &"green", Vector2(0, TEXT_Y))
	level_label = _add("", &"silver", Vector2(TEXT_X, TEXT_Y + LINE + 1))
	stages_label = _add("", &"steel", Vector2(TEXT_X, TEXT_Y + (LINE + 1) * 2))
	if def == null:
		return
	resource_icon = ResourceIcon.rect(def.resource)
	resource_icon.name = "ResourceIcon"
	add_child(resource_icon)
	resource_label = _add("", &"white", Vector2.ZERO)
	resource_label.name = "Resource"
	for monster: StringName in def.monsters:
		var thumb := MonsterThumb.new(monster)
		add_child(thumb)
		thumbs.append(thumb)
	guardian_thumb = MonsterThumb.new(def.guardian)
	add_child(guardian_thumb)


## The width the row's text needs, its widest line.
func text_width() -> float:
	var widest: float = PixelText.width(name_label.text) + 4.0 + PixelText.width("On the way, 10 s")
	for label: Label in [level_label, stages_label]:
		widest = maxf(widest, PixelText.width(label.text))
	if resource_icon != null:
		# Room for the stages, then the resource: the longest count it is likely to show.
		var plural: String = ResourceIcon.plural(Content.area(area_id).resource)
		var resource: float = maxf(
			PixelText.width("9,999 " + plural), PixelText.width("Gives " + plural)
		)
		widest = maxf(
			widest,
			(
				PixelText.width("Safe 99, furthest 99")
				+ RESOURCE_GAP
				+ ResourceIcon.SIZE.x
				+ RESOURCE_ICON_GAP
				+ resource
			)
		)
	return TEXT_X + widest


## The width the thumbs need.
func thumbs_width() -> float:
	var width: float = 0.0
	for thumb: MonsterThumb in thumbs:
		width += thumb.size.x + MonsterThumb.GAP
	if guardian_thumb != null:
		width += GUARDIAN_GAP - MonsterThumb.GAP + guardian_thumb.size.x
	return width + 3.0


## Lays the row out [param width] pixels wide, its thumbs starting at [param thumbs_x].
func lay_out(width: float, thumbs_x: float) -> void:
	size = Vector2(width, HEIGHT)
	_text_end = thumbs_x - THUMBS_GAP
	_place_resource()
	var x: float = thumbs_x
	for thumb: MonsterThumb in thumbs:
		thumb.position = Vector2(x, HEIGHT - 1.0 - thumb.size.y)
		x += thumb.size.x + MonsterThumb.GAP
	if guardian_thumb != null:
		x += GUARDIAN_GAP - MonsterThumb.GAP
		guardian_thumb.position = Vector2(x, HEIGHT - 1.0 - guardian_thumb.size.y)
	queue_redraw()


## Shows the area: [param open] or not, the tag ("" for none, in [param tag_colour]), the level
## line and the stages line; [param beaten] ticks the guardian.
func show_area(
	open: bool, tag: String, tag_colour: StringName, level: String, stages: String, beaten: bool
) -> void:
	if is_open != open:
		is_open = open
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
		)
		queue_redraw()
	_show_text(name_label, name_label.text, &"white" if open else &"slate")
	_show_text(tag_label, tag, tag_colour)
	tag_label.position.x = name_label.position.x + PixelText.width(name_label.text) + 4.0
	_show_text(level_label, level, &"silver" if open else &"steel")
	_show_text(stages_label, stages, &"steel" if open else &"slate")
	for thumb: MonsterThumb in thumbs:
		thumb.dim = not open
	if guardian_thumb != null:
		guardian_thumb.dim = not open
		guardian_thumb.beaten = beaten


## Shows the area's resource (spec 052 R7): [param held] of it while the area is open, what
## opening it gives while it is closed.
func show_resource(held: int) -> void:
	if resource_label == null:
		return
	var plural: String = ResourceIcon.plural(Content.area(area_id).resource)
	var text: String = "%s %s" % [Hud.group_thousands(held), plural]
	if not is_open:
		text = "Gives " + plural
	_show_text(resource_label, text, &"white" if is_open else &"steel")
	_place_resource()


## True while the row is lit under the mouse: an open area's, shown.
func is_highlighted() -> bool:
	return _hovered and is_open and is_visible_in_tree()


## The monsters' ids shown, in order, then the guardian's.
func monster_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for thumb: MonsterThumb in thumbs:
		ids.append(thumb.monster_id)
	if guardian_thumb != null:
		ids.append(guardian_thumb.monster_id)
	return ids


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	accept_event()
	if is_open:
		clicked.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_hovered = false


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if is_highlighted():
		HudPanel.draw_panel(
			self, rect, Palette.color(&"slate"), Palette.color(&"steel"), Palette.color(&"ink")
		)
	elif is_open:
		HudPanel.draw_panel(
			self, rect, Palette.color(&"night"), Palette.color(&"dusk"), Palette.color(&"ink")
		)
	if chosen:
		draw_rect(rect.grow(-0.5), Palette.color(&"yellow"), false, 1.0)
		draw_rect(rect.grow(-1.5), Palette.color(&"amber"), false, 1.0)
	if guardian_thumb != null and not thumbs.is_empty():
		var x: float = guardian_thumb.position.x - GUARDIAN_GAP / 2.0
		draw_rect(Rect2(x, 4.0, 1.0, HEIGHT - 8.0), Palette.color(&"dusk"))


func _place_resource() -> void:
	if resource_label == null:
		return
	var y: float = TEXT_Y + (LINE + 1) * 2
	resource_label.position = Vector2(_text_end - resource_label.size.x, y)
	resource_icon.position = Vector2(
		resource_label.position.x - RESOURCE_ICON_GAP - ResourceIcon.SIZE.x, y
	)


func _add(text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _show_text(label: Label, text: String, colour: StringName) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()
	label.add_theme_color_override(&"font_color", Palette.color(colour))

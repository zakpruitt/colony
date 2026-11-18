class_name AreaMapRow
extends PanelContainer
## One area's card on the Area map window (spec 053, laid out afresh by spec 059 R3): its name in
## bold with [code]Here[/code] or [code]On the way, 7 s[/code] at the right, the level of its
## first stage, then the party's safe and furthest stage there and its resource (spec 052) with
## the count held, beside its monsters and, past a line, its guardian, as sprites (ticked once
## beaten). A closed area's card is dimmed and says which guardian opens it and what it gives.
##
## The card is a button: an open area's card lights under the mouse and a left click emits
## [signal clicked]; a closed area's card takes the click and does nothing. The chosen card has a
## yellow edge.

## A left click on an open area's card.
signal clicked

## UI pixels: the space inside the card's edge, between the text and the sprites, and between two
## sprites.
const PAD: int = 5
const GAP: int = 10
const THUMB_GAP: int = 2
## The tags after an area's name.
const HERE: String = "Here"
const ON_THE_WAY: String = "On the way, %d s"

## The area shown.
var area_id: StringName
## The area's name, the tag at the right of its line, and the two lines under it.
var name_label: Label
var tag_label: Label
var level_label: Label
var stages_label: Label
## The area's resource (spec 052): its icon and the count held, or what opening the area gives.
var resource_icon: TextureRect
var resource_label: Label
## The monsters that live there, in the area's order, and its guardian.
var thumbs: Array[MonsterThumb] = []
var guardian_thumb: MonsterThumb
## True while the area is open, and while it is the one chosen.
var is_open: bool = false
var chosen: bool = false:
	set(value):
		if chosen != value:
			chosen = value
			_restyle()

var _hovered: bool = false


func _init(id: StringName) -> void:
	area_id = id
	name = "Row_%s" % id
	mouse_filter = Control.MOUSE_FILTER_STOP
	var def: AreaDef = Content.area(id)
	var whole := VBoxContainer.new()
	whole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whole.add_theme_constant_override(&"separation", 1)
	add_child(whole)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whole.add_child(head)
	name_label = _add(head, "Name", PlaceText.area_name(id), &"white", true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_label = _add(head, "Tag", "", &"green", true)
	level_label = _add(whole, "Level", "", &"silver")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", GAP)
	whole.add_child(row)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override(&"separation", 1)
	text.alignment = BoxContainer.ALIGNMENT_END
	text.custom_minimum_size.x = text_width()
	row.add_child(text)
	stages_label = _add(text, "Stages", "", &"steel")
	var held := HBoxContainer.new()
	held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held.add_theme_constant_override(&"separation", 3)
	text.add_child(held)
	resource_icon = ResourceIcon.rect(def.resource if def != null else &"")
	resource_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	held.add_child(resource_icon)
	resource_label = _add(held, "Resource", "", &"white")
	var sprites := HBoxContainer.new()
	sprites.name = "Sprites"
	sprites.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprites.add_theme_constant_override(&"separation", THUMB_GAP)
	sprites.custom_minimum_size.x = thumbs_width()
	row.add_child(sprites)
	if def == null:
		return
	for monster: StringName in def.monsters:
		var thumb := MonsterThumb.new(monster)
		_hold(thumb)
		sprites.add_child(thumb)
		thumbs.append(thumb)
	var line := ColorRect.new()
	line.color = Palette.color(&"dusk")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(1, 0)
	sprites.add_child(line)
	guardian_thumb = MonsterThumb.new(def.guardian)
	_hold(guardian_thumb)
	sprites.add_child(guardian_thumb)
	whole.custom_minimum_size.x = line_width()
	_restyle()


## The text column's width: room for the stages and the resource lines any area's card can show.
## The name with its tag and the level line run across the whole card, which the sprites make
## wider than any of them.
static func text_width() -> int:
	var widest: int = UiText.width("Safe 999, furthest 999")
	for id: StringName in Content.area_ids():
		var def: AreaDef = Content.area(id)
		widest = maxi(widest, UiText.width("Stage 1 is level %d" % def.level_at(1)))
		var plural: String = ResourceIcon.plural(def.resource)
		var held: int = maxi(UiText.width("99,999 " + plural), UiText.width("Gives " + plural))
		widest = maxi(widest, int(ResourceIcon.SIZE.x) + 3 + held)
	return widest


## The card's inner width at least: room for the longest name with the longest tag, and the
## longest line saying how a closed area opens.
static func line_width() -> int:
	var widest: int = 0
	var tag: int = UiText.width(ON_THE_WAY % AreaTravel.JOURNEY_SECONDS, true)
	for id: StringName in Content.area_ids():
		var def: AreaDef = Content.area(id)
		widest = maxi(widest, UiText.width(PlaceText.area_name(id), true) + 8 + tag)
		var opener: AreaDef = Content.area(def.opened_by)
		if opener != null:
			var guardian: MonsterDef = Content.monster(opener.guardian)
			if guardian != null:
				widest = maxi(widest, UiText.width(opens_by(guardian, opener)))
	return widest


## How a closed area opens: "Beat the Clay Colossus in The Claypits".
static func opens_by(guardian: MonsterDef, opener: AreaDef) -> String:
	return "Beat the %s in %s" % [guardian.display_name, opener.display_name]


## The sprites' column width: room for the most crowded area's monsters and guardian.
static func thumbs_width() -> int:
	var widest: float = 0.0
	for id: StringName in Content.area_ids():
		var def: AreaDef = Content.area(id)
		var width: float = 0.0
		for monster: StringName in def.monsters + [def.guardian]:
			var thumb := MonsterThumb.new(monster)
			width += thumb.size.x + THUMB_GAP
			thumb.free()
		widest = maxf(widest, width + 1.0 + THUMB_GAP)
	return ceili(widest)


## Shows the area: [param open] or not, the tag ("" for none, in [param tag_colour]), the level
## line and the stages line; [param beaten] ticks the guardian.
func show_area(
	open: bool, tag: String, tag_colour: StringName, level: String, stages: String, beaten: bool
) -> void:
	if is_open != open:
		is_open = open
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
		_restyle()
	_show_text(name_label, name_label.text, &"white" if open else &"slate")
	_show_text(tag_label, tag, tag_colour)
	_show_text(level_label, level, &"silver" if open else &"steel")
	_show_text(stages_label, stages, &"steel" if open else &"slate")
	resource_icon.modulate = Color.WHITE if open else MonsterThumb.DIM
	for thumb: MonsterThumb in thumbs:
		thumb.dim = not open
	if guardian_thumb != null:
		guardian_thumb.dim = not open
		guardian_thumb.beaten = beaten


## Shows the area's resource (spec 052 R7): [param held] of it while the area is open, what
## opening it gives while it is closed.
func show_resource(held: int) -> void:
	var plural: String = ResourceIcon.plural(Content.area(area_id).resource)
	var text: String = "%s %s" % [Hud.group_thousands(held), plural]
	if not is_open:
		text = "Gives " + plural
	_show_text(resource_label, text, &"white" if is_open else &"steel")


## True while the card is lit under the mouse: an open area's, shown.
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
		_restyle()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_hovered = false


## The card's box: dark at rest, lighter under the mouse, a yellow edge when chosen, and sunk into
## the window when closed. The padding is the same in every state.
func _restyle() -> void:
	var fill: StringName = &"night"
	var edge: StringName = &"dusk"
	if not is_open:
		edge = &"night"
	elif is_highlighted():
		fill = &"dusk"
		edge = &"steel"
	if chosen:
		edge = &"yellow"
	var box: StyleBoxFlat = UiTheme.box(fill, edge, PAD, PAD)
	if fill == edge:
		box.set_border_width_all(1)
		box.border_color = Palette.color(edge)
		box.set_content_margin_all(PAD + 1)
	add_theme_stylebox_override(&"panel", box)


## A thumb keeps its own size inside the row, standing on the bottom.
func _hold(thumb: MonsterThumb) -> void:
	thumb.custom_minimum_size = thumb.size
	thumb.size_flags_vertical = Control.SIZE_SHRINK_END


func _add(
	parent: Control, label_name: String, text: String, colour: StringName, bold: bool = false
) -> Label:
	var made: Label = UiText.label(text, colour, bold)
	made.name = label_name
	parent.add_child(made)
	return made


func _show_text(label: Label, text: String, colour: StringName) -> void:
	if label.text != text:
		label.text = text
	label.add_theme_color_override(&"font_color", Palette.color(colour))

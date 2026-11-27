class_name PictureSpecimen
extends Node
## A sheet to look at every picture: grouped by class (each class's talent tree,
## path by path), then the camp upgrades, the paragon stats and the microskills. Each
## picture shows large in its owned state with its ready, locked and closed states small beside it,
## and its name under it. Under the groups, one slot bursts every
## [constant BURST_EVERY] seconds and a banner drops in again whenever the last has gone.
##
## [code]python tools/dev.py shot --scene=res://game/ui/picture_specimen.tscn --name=pictures[/code]
## shows it whole at 1280x720.

## UI pixels round the sheet, between cells, between groups and under a group's heading.
const MARGIN: float = 12.0
const CELL_GAP: float = 8.0
const GROUP_GAP: float = 20.0
const ROW_GAP: float = 8.0
## Seconds between two bursts on the sample slot.
const BURST_EVERY: float = 1.5
## The small states shown beside the large owned one.
const SMALL_STATES: Array[UiIcon.State] = [
	UiIcon.State.READY, UiIcon.State.LOCKED, UiIcon.State.CLOSED
]

## The UI layer the sheet is drawn on.
var ui: UiRoot
## The burst and the banner.
var moment: UiMoment

var _groups: Array[String] = []
var _icons: Dictionary[StringName, Array] = {}
var _names: Dictionary[StringName, Label] = {}
var _sheet: Control
var _sample: UiIcon
var _since_burst: float = 0.0


func _ready() -> void:
	ui = UiRoot.new()
	add_child(ui)
	lay_out()


func _process(delta: float) -> void:
	advance(delta)


## Lays the sheet out afresh for the layer's room.
func lay_out() -> void:
	if _sheet != null:
		_sheet.free()
	_groups.clear()
	_icons.clear()
	_names.clear()
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room := Vector2(ui.room())
	_sheet.size = room
	ui.frame.add_child(_sheet)
	var back := ColorRect.new()
	back.color = Palette.color(&"dusk")
	back.size = room
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(back)
	var title: Label = WindowText.label("Title", "Pictures (spec 063)", &"yellow", true)
	title.position = Vector2(MARGIN, MARGIN / 2.0)
	_sheet.add_child(title)
	var at := Vector2(MARGIN, title.position.y + UiText.LINE_HEIGHT + ROW_GAP)
	var line_height: float = 0.0
	for group: Array in _group_list():
		var heading: String = group[0]
		var ids: Array[StringName] = []
		var listed: Array = group[1]
		ids.assign(listed)
		var block: Control = _block(heading, ids, room.x - 2.0 * MARGIN)
		if at.x > MARGIN and at.x + block.size.x > room.x - MARGIN:
			at = Vector2(MARGIN, at.y + line_height + ROW_GAP)
			line_height = 0.0
		block.position = at
		_sheet.add_child(block)
		_groups.append(heading)
		at.x += block.size.x + GROUP_GAP
		line_height = maxf(line_height, block.size.y)
	var bottom: float = at.y + line_height + ROW_GAP
	_sample = UiIcon.new(&"fireball")
	_sample.position = Vector2(MARGIN + 20.0, bottom + 24.0)
	_sheet.add_child(_sample)
	var caption: Label = WindowText.label("Caption", "A burst, then a banner", &"steel")
	caption.position = Vector2(MARGIN, bottom)
	_sheet.add_child(caption)
	moment = UiMoment.new()
	_sheet.add_child(moment)
	# The moment's own room is the strip under the groups: its banner drops in at that strip's top.
	moment.position = Vector2(0, bottom - UiMoment.BANNER_TOP)
	moment.size = Vector2(room.x, room.y - moment.position.y)
	_since_burst = BURST_EVERY


## Runs the pulses, the burst and the banner on by [param delta] seconds.
func advance(delta: float) -> void:
	for id: StringName in _icons:
		for icon: UiIcon in _icons[id]:
			icon.advance(delta)
	_since_burst += delta
	if _since_burst >= BURST_EVERY:
		_since_burst = 0.0
		moment.burst(_sample)
	if moment.shown_headline().is_empty() and moment.waiting() == 0:
		moment.announce(
			&"miracle", "Cleric learned Miracle", "Heals every ally for 40% of its health"
		)
	moment.advance(delta)


## The groups' headings, in order.
func group_names() -> Array[String]:
	return _groups.duplicate()


## Every slot showing [param id]'s picture.
func icons_of(id: StringName) -> Array[UiIcon]:
	var shown: Array[UiIcon] = []
	var found: Array = _icons.get(id, [])
	shown.assign(found)
	return shown


## The name under [param id]'s picture, or null.
func name_of(id: StringName) -> Label:
	return _names.get(id, null)


## Each group: its heading and its ids.
func _group_list() -> Array[Array]:
	var made: Array[Array] = []
	for class_id: StringName in Content.hero_class_ids():
		var tree: TalentTreeDef = Content.talent_tree(class_id)
		if tree == null:
			continue
		var ids: Array[StringName] = []
		for each: SkillPathDef in tree.paths:
			ids.append_array(each.nodes)
		made.append([Content.hero_class(class_id).display_name, ids])
	made.append(["Upgrades", Content.upgrade_ids()])
	made.append(["Paragon", Content.training_ids()])
	made.append(["Skills", Content.microskill_ids()])
	return made


## A group's block: its heading over its cells, wrapped to [param width].
func _block(heading: String, ids: Array[StringName], width: float) -> Control:
	var block := Control.new()
	block.name = "Group_%s" % heading
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = WindowText.label("Heading", heading, &"white", true)
	block.add_child(label)
	var top: float = UiText.LINE_HEIGHT + 2.0
	var at := Vector2(0, top)
	var widest: float = 0.0
	var cell_size := Vector2.ZERO
	for id: StringName in ids:
		var cell: Control = _cell(id)
		cell_size = cell.size
		if at.x > 0.0 and at.x + cell.size.x > width:
			at = Vector2(0, at.y + cell.size.y + CELL_GAP)
		cell.position = at
		block.add_child(cell)
		widest = maxf(widest, at.x + cell.size.x)
		at.x += cell.size.x + CELL_GAP
	block.size = Vector2(maxf(widest, label.size.x), at.y + cell_size.y)
	return block


## One picture: large and owned, its three other states small beside it, its name under them.
func _cell(id: StringName) -> Control:
	var cell := Control.new()
	cell.name = "Cell_%s" % id
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shown: Array[UiIcon] = []
	var large := UiIcon.new(id)
	cell.add_child(large)
	shown.append(large)
	var x: float = large.size.x + 3.0
	for state: UiIcon.State in SMALL_STATES:
		var small := UiIcon.new(id, false)
		small.show_state(state)
		small.position = Vector2(x, floorf((large.size.y - small.size.y) / 2.0))
		cell.add_child(small)
		shown.append(small)
		x += small.size.x + 2.0
	_icons[id] = shown
	var label: Label = WindowText.label("Name", _display_name(id), &"silver")
	label.position = Vector2(0, large.size.y + 1.0)
	cell.add_child(label)
	_names[id] = label
	cell.size = Vector2(maxf(x - 2.0, label.size.x), label.position.y + label.size.y)
	return cell


static func _display_name(id: StringName) -> String:
	if Content.ability(id) != null:
		return Content.ability(id).display_name
	if Content.upgrade(id) != null:
		return Content.upgrade(id).display_name
	if Content.training(id) != null:
		return Content.training(id).display_name
	if Content.microskill(id) != null:
		return Content.microskill(id).display_name
	return String(id)

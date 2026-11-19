class_name NextStrip
extends Control
## The strip at the foot of a hero's talent tree (spec 064 R6): one node in full, without pointing.
## Its picture in a large [UiIcon], then its name in bold and its kind, how it stands at the right
## of that line, and its whole description wrapped under them; a [code]Learn[/code] button at the
## right when the node can be taken now. [HeroTalentsTab] chooses the node: the one under the mouse;
## with none, the first the hero can take now; with none of those, the first not yet taken on the
## hero's way.

## UI pixels between the picture and the words, and between the words and the button.
const GAP: float = 6.0

## The node shown, or &"" for none.
var ability_id: StringName = &""
var slot: UiIcon
var name_label: Label
var kind_label: Label
var stand_label: Label
var description_label: Label
var learn_button: UiButton

var _width: float = 0.0
var _slots: Dictionary[StringName, UiIcon] = {}


## A strip [param width] UI pixels wide for the nodes [param ids]: as tall as the picture, or as
## the name's line and the longest of their descriptions wrapped, whichever is taller.
func _init(width: float, ids: Array[StringName]) -> void:
	name = "Strip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_width = width
	name_label = WindowText.label("Name", "", &"white", true)
	kind_label = WindowText.label("Kind", "", &"steel")
	stand_label = WindowText.label("Stand", "", &"yellow")
	description_label = WindowText.label("Description", "", &"silver")
	for label: Label in [name_label, kind_label, stand_label, description_label]:
		add_child(label)
	learn_button = WindowText.button("Learn", "Learn")
	add_child(learn_button)
	var lines: int = 1
	for id: StringName in ids:
		var ability: AbilityDef = Content.ability(id)
		if ability != null:
			lines = maxi(lines, WindowText.wrap(ability.description, _words_width(true)).size())
	size = Vector2(width, maxf(TalentNode.SLOT.y, UiText.LINE_HEIGHT * (1 + lines)))
	custom_minimum_size = size


## Shows node [param id] standing as [param stand] in the palette colour [param stand_colour], with
## the [code]Learn[/code] button when [param learnable]; &"" shows nothing.
func show_node(id: StringName, stand: String, stand_colour: StringName, learnable: bool) -> void:
	ability_id = id
	var ability: AbilityDef = Content.ability(id) if id != &"" else null
	for each: StringName in _slots:
		_slots[each].visible = each == id
	if ability == null:
		for label: Label in [name_label, kind_label, stand_label, description_label]:
			WindowText.set_text(label, "")
		learn_button.visible = false
		slot = null
		return
	slot = _slot_of(id, ability)
	slot.show_state(UiIcon.State.READY if learnable else UiIcon.State.LOCKED)
	var words_x: float = TalentNode.SLOT.x + GAP
	WindowText.set_text(name_label, ability.display_name)
	WindowText.set_text(kind_label, HeroTalentsTab.kind_text(id))
	WindowText.set_text(stand_label, stand)
	stand_label.add_theme_color_override(&"font_color", Palette.color(stand_colour))
	learn_button.visible = learnable
	var right: float = words_x + _words_width(learnable)
	if learnable:
		learn_button.position = Vector2(
			_width - learn_button.size.x, floorf((size.y - learn_button.size.y) / 2.0)
		)
	name_label.position = Vector2(words_x, 0)
	kind_label.position = Vector2(words_x + name_label.size.x + GAP, 0)
	stand_label.position = Vector2(right - stand_label.size.x, 0)
	var lines: Array[String] = WindowText.wrap(ability.description, _words_width(learnable))
	WindowText.set_text(description_label, "\n".join(PackedStringArray(lines)))
	description_label.position = Vector2(words_x, UiText.LINE_HEIGHT)


## Runs the shown picture's pulse on by [param delta] seconds.
func advance(delta: float) -> void:
	if slot != null:
		slot.advance(delta)


## How wide the words may run: from right of the picture to the edge, or to the button.
func _words_width(learnable: bool) -> float:
	var right: float = _width - (learn_button.size.x + GAP if learnable else 0.0)
	return right - TalentNode.SLOT.x - GAP


## The node's slot, made once per node and kept (a slot's picture is fixed when it is made).
func _slot_of(id: StringName, ability: AbilityDef) -> UiIcon:
	if _slots.has(id):
		return _slots[id]
	var shape: UiIcon.Shape = UiIcon.Shape.SQUARE if ability.is_action() else UiIcon.Shape.CUT
	var made := UiIcon.new(id, true, shape)
	made.name = "Slot_%s" % id
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	_slots[id] = made
	return made

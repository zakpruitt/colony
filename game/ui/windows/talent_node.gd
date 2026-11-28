class_name TalentNode
extends Control
## One node of a hero's talent tree on a hero window's Talents tab: its ability's picture in a
## large [UiIcon] ([member slot]), square for an action and with cut corners for a
## passive, and the ability's name under it, centred, on one or two lines and never cut. No
## description is written here: pointing at the node shows its card ([HeroTalentsTab]).
##
## [method show_state] says how it stands for the hero, and the slot shows it: taken is owned (a
## gold frame), one that can be taken now is ready (a yellow frame that pulses), and one not yet
## reachable is locked. A node has a thin ring of its path's colour round its slot
## ([method tint]). The node is the size of its slot; its name hangs under it.
##
## It reads nothing itself: [HeroTalentsTab] sets its state and runs its pulse. A left click on the
## slot emits [signal clicked]; the mouse entering and leaving it, [signal hovered].

## A left click on the node.
signal clicked(ability_id: StringName)
## The mouse came onto the node ([param inside] true) or left it.
signal hovered(ability_id: StringName, inside: bool)

## How a node stands for the hero.
enum State { TAKEN, AVAILABLE, LOCKED }

## The slot's size: the 16x16 picture at twice its size in a large frame.
const SLOT: Vector2 = Vector2(36, 36)
## The widest a name runs before it takes a second line (unless told narrower), and the gap
## between the slot and it.
const NAME_WIDTH: float = 116.0
const NAME_GAP: float = 0.0
## The colour of anything dimmed on a hero window: readable, but plainly not in play.
const DIM: StringName = &"steel"
## The slot's look for each state.
const LOOKS: Dictionary[State, UiIcon.State] = {
	State.TAKEN: UiIcon.State.OWNED,
	State.AVAILABLE: UiIcon.State.READY,
	State.LOCKED: UiIcon.State.LOCKED,
}

## The ability this node stands for.
var ability_id: StringName
## The path it is on (0 to 2), or -1 for none.
var path: int = -1
## The framed picture, and the picture in it.
var slot: UiIcon
var icon: TextureRect
var name_label: Label
## The palette name of the path's colour (&"" for none).
var path_colour: StringName = &""

var _state: State = State.LOCKED


## A node for [param id], on [param on_path] of a path coloured [param colour], its name wrapped to
## [param name_width] UI pixels.
func _init(
	id: StringName, on_path: int, colour: StringName = &"", name_width: float = NAME_WIDTH
) -> void:
	ability_id = id
	path = on_path
	path_colour = colour
	name = "Node_%s" % id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SLOT
	custom_minimum_size = SLOT
	var ability: AbilityDef = Content.ability(id)
	var action: bool = ability != null and ability.is_action()
	slot = UiIcon.new(id, true, UiIcon.Shape.SQUARE if action else UiIcon.Shape.CUT)
	slot.name = "Slot"
	slot.mouse_filter = Control.MOUSE_FILTER_PASS  # the wheel goes on to the window's scroll
	slot.clicked.connect(func() -> void: clicked.emit(ability_id))
	slot.mouse_entered.connect(func() -> void: hovered.emit(ability_id, true))
	slot.mouse_exited.connect(func() -> void: hovered.emit(ability_id, false))
	add_child(slot)
	icon = slot.picture_rect
	var title: String = ability.display_name if ability != null else String(id)
	name_label = WindowText.label("Name", "", &"silver", true)
	var lines: Array[String] = WindowText.wrap(title, name_width, true)
	WindowText.set_text(name_label, "\n".join(PackedStringArray(lines)))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(floorf((SLOT.x - name_label.size.x) / 2.0), SLOT.y + NAME_GAP)
	add_child(name_label)
	_apply()


## How tall the node is with its name: the slot, the gap and the name's lines.
func full_height() -> float:
	return SLOT.y + NAME_GAP + name_label.size.y


## Sets how the node stands. [param _pulsing] is ignored, kept so existing callers still fit: a
## node that can be taken now pulses by its state alone.
func show_state(shown: State, _pulsing: bool = true) -> void:
	if shown == _state:
		return
	_state = shown
	_apply()


## How the node stands now.
func state() -> State:
	return _state


## True while the node can be taken now: its slot pulses.
func is_pulsing() -> bool:
	return slot.state() == UiIcon.State.READY


## Runs the pulse on by [param delta] seconds.
func advance(delta: float) -> void:
	slot.advance(delta)


## The palette colour of the slot's edge now.
func frame_colour() -> StringName:
	return slot.frame_colour()


## True when the node is taken (its slot shows owned).
func is_ticked() -> bool:
	return _state == State.TAKEN


## The palette name of the ring round the slot: the path's colour, or &"" for none.
func tint() -> StringName:
	return path_colour


func _draw() -> void:
	var ring: StringName = tint()
	if ring == &"":
		return
	var colour: Color = Palette.color(ring)
	for edge: Rect2 in [
		Rect2(-1, -1, SLOT.x + 2, 1),
		Rect2(-1, SLOT.y, SLOT.x + 2, 1),
		Rect2(-1, 0, 1, SLOT.y),
		Rect2(SLOT.x, 0, 1, SLOT.y),
	]:
		draw_rect(edge, colour)


## Shows the state: the slot's look and the name's colour.
func _apply() -> void:
	slot.show_state(LOOKS[_state])
	var colour: StringName = &"silver"
	match _state:
		State.TAKEN:
			colour = &"white"
		State.AVAILABLE:
			colour = &"yellow"
	WindowText.set_colour(name_label, colour)
	queue_redraw()

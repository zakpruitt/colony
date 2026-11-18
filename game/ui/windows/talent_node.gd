class_name TalentNode
extends Control
## One node of a hero's talent tree on a hero window's Talents tab (spec 055, moved onto the UI
## layer by spec 060): its ability's picture (its [member AbilityDef.picture]) in a small box, and
## beside it the ability's name, whether it is an action or a passive, and its whole one-line
## description, wrapped to the node's width and never cut, so the tree reads without pointing.
## [method show_state] says how it stands for the hero, and the node draws it: taken is bright with
## a green tick; one that can be taken now is framed in yellow and pulses gently; one not yet
## reachable is plain; one on the path the hero did not choose is dark, with no picture, its words
## dimmed but still readable.
##
## It reads nothing itself: [HeroTalentsTab] sets its state and runs its pulse. A left click
## anywhere on it emits [signal clicked].

## A left click on the node.
signal clicked(ability_id: StringName)

## How a node stands for the hero.
enum State { TAKEN, AVAILABLE, LOCKED, CLOSED }

## The picture's box: the 12x12 picture at twice its size inside a 1-pixel border.
const BOX: Vector2 = Vector2(26, 26)
const PICTURE_SCALE: float = 2.0
## Where the words start, right of the box, and the gap between the name and its kind.
const TEXT_X: float = 32.0
const KIND_GAP: float = 8.0
## Seconds of one pulse of a node that can be taken, bright half then dim half.
const PULSE_SECONDS: float = 1.0
## The sheet of pictures, one 12x12 part per [constant AbilityDef.PICTURES] entry.
const ICONS_PATH: String = "res://assets/sprites/ui/talent_icons.png"
## The colour of a closed node's words, and of anything else dimmed on a hero window: readable,
## but plainly not in play.
const DIM: StringName = &"steel"
## A tick in 5x4 cells, each 2x2 pixels, drawn in code at the box's bottom right.
const TICK: Array[String] = ["....#", "...#.", "#.#..", ".#..."]

static var _sheet: PixelSheet

## The ability this node stands for.
var ability_id: StringName
## The path it is on (0 or 1), or -1 for the trunk.
var path: int = -1
var icon: TextureRect
var name_label: Label
## "Action, every 8 s" or "Passive".
var kind_label: Label
## The ability's description, wrapped into lines.
var description_label: Label

var _state: State = State.LOCKED
## True while the node can be taken and the hero has a point: it pulses.
var _pulsing: bool = false
var _time: float = 0.0


## A node for [param id], on [param on_path] (-1 for the trunk), [param width] UI pixels wide.
func _init(id: StringName, on_path: int, width: float) -> void:
	ability_id = id
	path = on_path
	name = "Node_%s" % id
	mouse_filter = Control.MOUSE_FILTER_PASS  # the wheel goes on to the window's scroll
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(1, 1)
	icon.size = BOX - Vector2(2, 2)
	icon.texture = TalentNode.picture(id)
	add_child(icon)
	var ability: AbilityDef = Content.ability(id)
	var title: String = ability.display_name if ability != null else String(id)
	name_label = WindowText.label("Name", title, &"steel", true)
	add_child(name_label)
	kind_label = WindowText.label("Kind", HeroTalentsTab.kind_text(id), &"slate")
	add_child(kind_label)
	description_label = WindowText.label("Description", "", &"silver")
	add_child(description_label)
	_lay_out(width, ability.description if ability != null else "")
	_apply()


## The picture of ability [param id]'s kind, as its data names it.
static func picture(id: StringName) -> Texture2D:
	if _sheet == null:
		_sheet = PixelSheet.load_sheet(ICONS_PATH)
	var ability: AbilityDef = Content.ability(id)
	var kind: StringName = ability.picture if ability != null else AbilityDef.PICTURES[0]
	return _sheet.part(kind) if _sheet.has_part(kind) else null


## Sets how the node stands, and whether it pulses (it can be taken now and the hero has a point).
func show_state(shown: State, pulsing: bool) -> void:
	if shown == _state and pulsing == _pulsing:
		return
	_state = shown
	_pulsing = pulsing
	if not pulsing:
		_time = 0.0
	_apply()


## How the node stands now.
func state() -> State:
	return _state


## True while the node pulses.
func is_pulsing() -> bool:
	return _pulsing


## Runs the pulse on by [param delta] seconds.
func advance(delta: float) -> void:
	if not _pulsing:
		return
	var was_bright: bool = is_bright()
	_time = fmod(_time + delta, PULSE_SECONDS)
	if was_bright != is_bright():
		queue_redraw()


## True in the bright half of the pulse (always, for a node that does not pulse).
func is_bright() -> bool:
	return not _pulsing or _time < PULSE_SECONDS / 2.0


## The palette colour of the box's border: yellow (amber on the pulse's dim half) for a node that
## can be taken now, green for a taken one, dusk for a plain one, ink for a closed one.
func frame_colour() -> StringName:
	match _state:
		State.TAKEN:
			return &"green"
		State.AVAILABLE:
			return &"yellow" if is_bright() else &"amber"
		State.CLOSED:
			return &"ink"
	return &"dusk"


## True when the node draws its tick (it is taken).
func is_ticked() -> bool:
	return _state == State.TAKEN


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(ability_id)


func _draw() -> void:
	var fill: StringName = &"night"
	var bevel: StringName = &"dusk"
	match _state:
		State.TAKEN:
			fill = &"pine"
			bevel = &"forest"
		State.AVAILABLE:
			bevel = &"slate"
		State.CLOSED:
			fill = &"ink"
			bevel = &"ink"
	var box := Rect2(Vector2.ZERO, BOX)
	draw_rect(box, Palette.color(frame_colour()))
	draw_rect(box.grow(-1.0), Palette.color(fill))
	draw_rect(Rect2(1, 1, BOX.x - 2.0, 1), Palette.color(bevel))
	draw_rect(Rect2(1, 1, 1, BOX.y - 2.0), Palette.color(bevel))
	if _state == State.CLOSED:
		draw_rect(Rect2(8, 12, 10, 2), Palette.color(&"night"))  # a dash where the picture was
	if is_ticked():
		var at := Vector2(BOX.x - 11.0, BOX.y - 10.0)
		for y: int in TICK.size():
			for x: int in TICK[y].length():
				if TICK[y][x] == "#":
					var cell := Vector2(x * 2, y * 2)
					draw_rect(
						Rect2(at + cell + Vector2(0, 2), Vector2(2, 2)), Palette.color(&"ink")
					)
					draw_rect(Rect2(at + cell, Vector2(2, 2)), Palette.color(&"green"))


## Places the words beside the box in [param width] UI pixels: the name, its kind after it (or
## under it, when both do not fit on one line) and the description wrapped under them.
func _lay_out(width: float, description: String) -> void:
	var words: float = width - TEXT_X
	name_label.position = Vector2(TEXT_X, 0)
	var name_width: float = UiText.width(name_label.text, true)
	var kind_width: float = UiText.width(kind_label.text)
	var below: float = UiText.LINE_HEIGHT
	if name_width + KIND_GAP + kind_width <= words:
		kind_label.position = Vector2(TEXT_X + name_width + KIND_GAP, 0)
	else:
		kind_label.position = Vector2(TEXT_X, UiText.LINE_HEIGHT)
		below += UiText.LINE_HEIGHT
	var lines: Array[String] = WindowText.wrap(description, words)
	description_label.text = "\n".join(PackedStringArray(lines))
	description_label.position = Vector2(TEXT_X, below)
	description_label.size = Vector2(words, lines.size() * UiText.LINE_HEIGHT)
	for label: Label in [name_label, kind_label]:
		label.size = Vector2(UiText.width(label.text, label == name_label), UiText.LINE_HEIGHT)
	size = Vector2(width, maxf(BOX.y, below + lines.size() * UiText.LINE_HEIGHT))
	custom_minimum_size = size


## Shows the state: the picture (none when closed) and the words' colours.
func _apply() -> void:
	icon.visible = _state != State.CLOSED
	var colour: StringName = &"silver"
	var words: StringName = &"silver"
	var kind: StringName = &"steel"
	match _state:
		State.TAKEN:
			colour = &"white"
		State.AVAILABLE:
			colour = &"yellow"
		State.CLOSED:
			colour = DIM
			words = DIM
			kind = &"slate"
	name_label.add_theme_color_override(&"font_color", Palette.color(colour))
	description_label.add_theme_color_override(&"font_color", Palette.color(words))
	kind_label.add_theme_color_override(&"font_color", Palette.color(kind))
	queue_redraw()

class_name TalentNode
extends Control
## One node of a hero's talent tree on the sheet's Talents tab (spec 055): a 12x12 picture of its
## ability's kind in a small box, and the ability's name beside it. [method show_state] says how
## it stands for the shown hero, and the node draws it (R2): taken is bright with a green tick;
## one that can be taken now is framed in yellow and pulses gently; one not yet reachable is
## plain; one on the path the hero did not choose is dark, with no picture.
##
## It reads nothing itself: [TalentTab] sets its state and runs its pulse. A left click emits
## [signal clicked].

## A left click on the node.
signal clicked(ability_id: StringName)

## How a node stands for the shown hero.
enum State { TAKEN, AVAILABLE, LOCKED, CLOSED }

## The picture's box: the 12x12 icon inside a 1-pixel border.
const BOX: Vector2 = Vector2(14, 14)
## Pixels between the box and the name.
const NAME_GAP: float = 3.0
## The name's top, so its capitals sit in the middle of the box.
const NAME_Y: float = 3.0
## Seconds of one pulse of a node that can be taken, bright half then dim half.
const PULSE_SECONDS: float = 1.0
## The sheet of pictures, one 12x12 part per kind.
const ICONS_PATH: String = "res://assets/sprites/ui/talent_icons.png"
## The picture each ability shows: one of the eight kinds, by ability id. An ability not listed
## shows [constant DEFAULT_KIND].
const KINDS: Dictionary[StringName, StringName] = {
	# Knight
	&"shield_bash": &"strike",
	&"taunt": &"rally",
	&"bottle_top_block": &"guard",
	&"hold_the_line": &"guard",
	&"last_stand": &"guard",
	&"bulwark": &"guard",
	&"rallying_cry": &"rally",
	&"whirlwind": &"strike",
	&"bloodthirst": &"rally",
	&"reckless_swing": &"strike",
	&"rampage": &"rally",
	# Rogue
	&"backstab": &"strike",
	&"smoke_step": &"shadow",
	&"finisher": &"strike",
	&"poisoned_blades": &"shadow",
	&"mark_for_death": &"shadow",
	&"ambush": &"shadow",
	&"killing_spree": &"strike",
	&"fan_of_knives": &"strike",
	&"caltrops": &"shadow",
	&"dizzying_feint": &"shadow",
	&"vanish": &"shadow",
	# Mage
	&"fireball": &"fire",
	&"frost_nova": &"frost",
	&"chain_spark": &"light",
	&"ignite": &"fire",
	&"meteor": &"fire",
	&"wildfire": &"fire",
	&"inferno": &"fire",
	&"ice_lance": &"frost",
	&"frost_armor": &"frost",
	&"deep_freeze": &"frost",
	&"blizzard": &"frost",
	# Cleric
	&"prayer": &"heal",
	&"blessing": &"heal",
	&"smite": &"light",
	&"renewal": &"heal",
	&"sanctuary": &"guard",
	&"guardian_angel": &"heal",
	&"miracle": &"heal",
	&"holy_fire": &"light",
	&"battle_hymn": &"rally",
	&"judgement": &"light",
	&"wrath": &"light",
}
const DEFAULT_KIND: StringName = &"strike"
## A tick in 5x4 pixels, drawn in code at the box's bottom right: [code]#[/code] is green.
const TICK: Array[String] = ["....#", "...#.", "#.#..", ".#..."]

static var _sheet: PixelSheet

## The ability this node stands for.
var ability_id: StringName
## The path it is on (0 or 1), or -1 for the trunk.
var path: int = -1
var icon: TextureRect
var name_label: Label

var _state: State = State.LOCKED
## True while the node can be taken and the hero has a point: it pulses.
var _pulsing: bool = false
var _time: float = 0.0


## A node for [param id], on [param on_path] (-1 for the trunk).
func _init(id: StringName, on_path: int) -> void:
	ability_id = id
	path = on_path
	name = "Node_%s" % id
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(1, 1)
	icon.size = Vector2(12, 12)
	icon.texture = TalentNode.picture(id)
	add_child(icon)
	var ability: AbilityDef = Content.ability(id)
	name_label = PixelText.label(ability.display_name if ability != null else String(id), &"steel")
	name_label.name = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(BOX.x + NAME_GAP, NAME_Y)
	add_child(name_label)
	size = needed_size()
	_apply()


## The picture of ability [param id]'s kind.
static func picture(id: StringName) -> Texture2D:
	if _sheet == null:
		_sheet = PixelSheet.load_sheet(ICONS_PATH)
	return _sheet.part(kind_of(id))


## The kind of picture ability [param id] shows.
static func kind_of(id: StringName) -> StringName:
	return KINDS.get(id, DEFAULT_KIND)


## The node's whole size: the box, the gap and the name.
func needed_size() -> Vector2:
	return Vector2(BOX.x + NAME_GAP + PixelText.width(name_label.text), BOX.y)


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
	HudPanel.draw_panel(
		self,
		Rect2(Vector2.ZERO, BOX),
		Palette.color(fill),
		Palette.color(bevel),
		Palette.color(frame_colour())
	)
	if _state == State.CLOSED:
		draw_rect(Rect2(4, 6, 6, 1), Palette.color(&"night"))  # a dash where the picture was
	if is_ticked():
		var at := Vector2(BOX.x - 5.0, BOX.y - 5.0)
		for y: int in TICK.size():
			for x: int in TICK[y].length():
				if TICK[y][x] == "#":
					draw_rect(Rect2(at + Vector2(x, y + 1), Vector2.ONE), Palette.color(&"ink"))
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Palette.color(&"green"))


## Shows the state: the picture (none when closed) and the name's colour.
func _apply() -> void:
	icon.visible = _state != State.CLOSED
	var colour: StringName = &"steel"
	match _state:
		State.TAKEN:
			colour = &"white"
		State.AVAILABLE:
			colour = &"yellow"
		State.CLOSED:
			colour = &"slate"
	name_label.add_theme_color_override(&"font_color", Palette.color(colour))
	queue_redraw()

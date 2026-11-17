class_name OrdersPanel
extends Control
## The party's orders (spec 035): a small panel below the HUD's top band with one row per order,
## its name, a button per choice with the current one lit, and the current choice explained in one
## plain line. The HUD's Orders button and the [kbd]O[/kbd] key open and close it; [kbd]Esc[/kbd]
## closes it. It opens over the running game and never pauses it.
##
## It reads the orders from the simulation every frame, so a loaded save shows the saved orders;
## a click sends [method Simulation.set_pace] or [method Simulation.set_guardian_order], and the
## choice is lit at once, before the simulation applies it on its next step. It never shares the
## screen with the shop, the hero sheet, the journal or help: opening it closes them, and
## [method advance] closes it should one of them open. Drawn as a [HudPanel] is.

## The rows, in order: [constant PartyOrders.PACE] then [constant PartyOrders.GUARDIANS].
const ORDER_NAMES: Array[String] = ["Pace", "Guardians"]
## Each choice's explanation, by order then value.
const LINES: Array[Array] = [
	[
		"Cautious: rest below 80% health",
		"Steady: rest below 60% health",
		"Bold: rest only below 40% health",
	],
	["Challenge: fight guardians to go deeper", "Hold: do not fight guardians until told"],
]
## Each choice's tooltip, by order then value: one plain sentence.
const TIPS: Array[Array] = [
	[
		"Safest: the party rests when any hero drops below 80% health.",
		"The usual: the party rests when any hero drops below 60% health.",
		"Fastest but riskier: the party rests only when a hero drops below 40% health.",
	],
	[
		"The party fights each guardian that blocks its way down.",
		"The party stays away from living guardians and keeps hunting until told.",
	],
]
const TITLE: String = "Party orders"
const HINT: String = "O close"
## Space inside the border; the title row's height; one order's row height.
const PADDING: float = 4.0
const TITLE_HEIGHT: float = 13.0
const ROW_HEIGHT: float = 25.0
## The column where the choices and their explanation start, after the order's name.
const CHOICES_X: float = 52.0
## Pixels between two choices.
const CHOICE_GAP: float = 3.0
## Pixels between the panel and the top band above it.
const DROP: float = 2.0

## A button per choice, by order then value, as [enum Expedition.Pace] and
## [enum Expedition.GuardianOrder] number them.
var choice_buttons: Array[Array] = []
## Each row's name ("Pace", "Guardians") and the line explaining its current choice.
var name_labels: Array[Label] = []
var line_labels: Array[Label] = []
var title_label: Label

var _simulation: Simulation
var _world: World
## A choice asked for that the simulation has not applied yet (it applies on its next step), by
## order; -1 when none.
var _asked: Array[int] = [-1, -1]


func _init() -> void:
	name = "OrdersPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _draw() -> void:
	HudPanel.draw_panel(
		self,
		Rect2(Vector2.ZERO, size),
		Palette.color(&"night"),
		Palette.color(&"dusk"),
		Palette.color(&"ink")
	)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_O:
			toggle()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			# Not marked handled, so the HUD and the other panels close what they have open too.
			close()


## Call once, before the first advance. [param world] may be null.
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	title_label = _add(TITLE, &"yellow", Vector2(PADDING + 2.0, PADDING))
	var width: float = title_label.position.x + PixelText.width(TITLE) + 60.0
	var y: float = PADDING + TITLE_HEIGHT + 2.0
	for order: int in ORDER_NAMES.size():
		name_labels.append(_add(ORDER_NAMES[order], &"steel", Vector2(PADDING + 2.0, y + 2.0)))
		var names: Array[String] = PartyOrders.PACE_NAMES
		if order == PartyOrders.GUARDIANS:
			names = PartyOrders.GUARDIAN_NAMES
		var buttons: Array[HudButton] = []
		var x: float = CHOICES_X
		for value: int in names.size():
			var button := HudButton.new(names[value])
			button.name = names[value]
			button.position = Vector2(x, y)
			button.pressed.connect(choose.bind(order, value))
			add_child(button)
			buttons.append(button)
			x += button.size.x + CHOICE_GAP
		choice_buttons.append(buttons)
		width = maxf(width, x - CHOICE_GAP)
		for explained: String in LINES[order]:
			width = maxf(width, CHOICES_X + PixelText.width(explained))
		line_labels.append(_add("", &"white", Vector2(CHOICES_X, y + HudButton.HEIGHT + 2.0)))
		y += ROW_HEIGHT
	size = Vector2(ceilf(width + PADDING + 2.0), y + PADDING - 4.0)
	var hint: Label = _add(HINT, &"slate", Vector2.ZERO)
	hint.position = Vector2(size.x - PADDING - 2.0 - PixelText.width(HINT), PADDING)
	var divider := ColorRect.new()
	divider.color = Palette.color(&"dusk")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2(PADDING, PADDING + TITLE_HEIGHT - 1.0)
	divider.size = Vector2(size.x - PADDING * 2.0, 1.0)
	add_child(divider)
	position = Vector2(Hud.SCREEN.x - Hud.MARGIN - size.x, Hud.TOP_BAND + DROP)
	advance(0.0)


## Brings the rows up to date with the simulation, and closes the panel if the shop, the hero sheet,
## the journal or help has opened. Called every frame by the HUD; tests call it.
func advance(_delta: float) -> void:
	if _simulation == null:
		return
	for order: int in choice_buttons.size():
		if _asked[order] >= 0 and _asked[order] == _current(order):
			_asked[order] = -1
		var shown: int = _shown(order)
		var buttons: Array = choice_buttons[order]
		for value: int in buttons.size():
			(buttons[value] as HudButton).lit = value == shown
		var text: String = line(order)
		if line_labels[order].text != text:
			line_labels[order].text = text
			line_labels[order].reset_size()
	if is_open() and _another_is_open():
		close()


## True while the panel is shown.
func is_open() -> bool:
	return visible


## Shows the panel, closing the shop, the hero sheet, the journal, help and the "While you were
## away" panel if any is up.
func open() -> void:
	var hud: Hud = get_parent() as Hud
	if hud != null:
		if hud.shop != null:
			hud.shop.close()
		if hud.hero_sheet != null:
			hud.hero_sheet.close()
		if hud.journal != null:
			hud.journal.close()
		if hud.help != null:
			hud.help.close()
		var layer: Node = hud.get_parent()
		if layer != null:
			for child: Node in layer.get_children():
				if child is AwayPanel:
					(child as AwayPanel).close()
	visible = true
	advance(0.0)


## Hides the panel.
func close() -> void:
	visible = false


## Opens the panel if it is closed, closes it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## The line explaining [param order]'s current choice ([constant PartyOrders.PACE] 0 or
## [constant PartyOrders.GUARDIANS] 1), as the panel shows it.
func line(order: int) -> String:
	if order < 0 or order >= LINES.size():
		return ""
	var lines: Array = LINES[order]
	var shown: int = _shown(order)
	if shown < 0 or shown >= lines.size():
		return ""
	var text: String = lines[shown]
	return text


## Sends [param value] for [param order] to the simulation, and lights it at once.
func choose(order: int, value: int) -> void:
	if _simulation == null or order < 0 or order >= LINES.size():
		return
	if value < 0 or value >= (LINES[order] as Array).size():
		return
	_asked[order] = value
	if order == PartyOrders.PACE:
		_simulation.set_pace(value as Expedition.Pace)
	else:
		_simulation.set_guardian_order(value as Expedition.GuardianOrder)
	advance(0.0)


## The tooltip sentence of one choice.
static func tip(order: int, value: int) -> String:
	var text: String = TIPS[order][value]
	return text


## The simulation's own value of [param order].
func _current(order: int) -> int:
	if order == PartyOrders.PACE:
		return _simulation.expedition.pace
	return _simulation.expedition.guardian_order


## The value lit for [param order]: the one asked for until the simulation applies it, then its own.
func _shown(order: int) -> int:
	if _simulation == null:
		return -1
	return _asked[order] if _asked[order] >= 0 else _current(order)


func _another_is_open() -> bool:
	var hud: Hud = get_parent() as Hud
	if hud == null:
		return false
	var shop: bool = hud.shop != null and hud.shop.is_open()
	var sheet: bool = hud.hero_sheet != null and hud.hero_sheet.is_open()
	var journal: bool = hud.journal != null and hud.journal.is_open()
	var help: bool = hud.help != null and hud.help.is_open()
	return shop or sheet or journal or help


func _add(text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made

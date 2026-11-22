class_name OrdersPanel
extends WindowContent
## The party's orders: one row per order, its name and a button per choice with the current one
## lit, and the current choice explained in a full sentence under it. It is the content of the
## Orders window ([kbd]O[/kbd], its button on the button bar, or a click on a held guardian's
## goal); it never pauses the game.
##
## It reads the orders from the simulation each time it is advanced, so a loaded save shows the
## saved orders; a click sends [method Simulation.set_pace],
## [method Simulation.set_guardian_order] or [method Simulation.set_side_paths], and the choice
## is lit at once, before the simulation applies it on its next step. From that step on each row
## lights the simulation's own value again, whatever it holds.

## The rows, in order: [constant PartyOrders.PACE], [constant PartyOrders.GUARDIANS], then
## [constant PartyOrders.SIDE_PATHS].
const ORDER_NAMES: Array[String] = ["Pace", "Guardians", "Side paths"]
## The name of each pace, guardian order and side path order, by value: [enum Expedition.Pace],
## [enum Expedition.GuardianOrder] and [enum Expedition.SidePaths].
const PACE_NAMES: Array[String] = ["Cautious", "Steady", "Bold"]
const GUARDIAN_NAMES: Array[String] = ["Challenge", "Hold"]
const SIDE_PATH_NAMES: Array[String] = ["Explore", "Press on"]
## Each order's choices, by order.
const CHOICE_NAMES: Array[Array] = [PACE_NAMES, GUARDIAN_NAMES, SIDE_PATH_NAMES]
## Each choice explained, by order then value: the line under its row.
const LINES: Array[Array] = [
	[
		"Cautious: the party rests when any hero drops below 80% health.",
		"Steady: the party rests when any hero drops below 60% health.",
		"Bold: the party rests only when a hero drops below 40% health.",
	],
	[
		"Challenge: the party fights each guardian that blocks its way.",
		"Hold: the party keeps away from living guardians until told.",
	],
	["Take every side path the party can open", "Walk past every gate"],
]
## Each choice's tooltip, by order then value: one plain sentence.
const TIPS: Array[Array] = [
	[
		"Safest: the party rests when any hero drops below 80% health.",
		"The usual: the party rests when any hero drops below 60% health.",
		"Fastest but riskier: the party rests only when a hero drops below 40% health.",
	],
	[
		"The party fights each guardian that blocks its way on.",
		"The party stays away from living guardians and keeps hunting until told.",
	],
	[
		"The party turns onto each side path whose gate one of its heroes can open.",
		"The party keeps to the main course and leaves every gate closed.",
	],
]
const TITLE: String = "Party orders"
## The width of an order's name column, and of the line explaining its choice, in UI pixels.
const NAME_WIDTH: int = 72
const LINE_WIDTH: int = 360

## A button per choice, by order then value, as [enum Expedition.Pace],
## [enum Expedition.GuardianOrder] and [enum Expedition.SidePaths] number them.
var choice_buttons: Array[Array] = []
## Each row's name ("Pace", "Guardians", "Side paths") and the line explaining its current
## choice.
var name_labels: Array[Label] = []
var line_labels: Array[Label] = []

var _simulation: Simulation
## A choice asked for that the simulation has not applied yet (it applies on its next step), by
## order; -1 when none.
var _asked: Array[int] = [-1, -1, -1]
## The simulation's tick when the last choice was asked for: once it has stepped past it, the
## simulation's own values are shown, whatever they are.
var _asked_tick: int = 0


func _init() -> void:
	name = "OrdersPanel"
	closes_away = false
	add_theme_constant_override(&"separation", 10)


## Call once, before the first advance. [param tips] gives each choice its sentence as a tooltip
## (may be null).
func setup(simulation: Simulation, tips: UiTip) -> void:
	_simulation = simulation
	for order: int in ORDER_NAMES.size():
		var block := VBoxContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_constant_override(&"separation", 3)
		add_child(block)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 4)
		block.add_child(row)
		var title: Label = UiText.label(ORDER_NAMES[order], &"steel", true)
		title.custom_minimum_size.x = NAME_WIDTH
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(title)
		name_labels.append(title)
		var names: Array[String] = []
		names.assign(CHOICE_NAMES[order])
		var buttons: Array[UiButton] = []
		for value: int in names.size():
			var button := UiButton.new(names[value])
			button.name = names[value]
			button.pressed.connect(choose.bind(order, value))
			row.add_child(button)
			buttons.append(button)
			if tips != null:
				tips.attach(button, OrdersPanel.tip(order, value))
		choice_buttons.append(buttons)
		var explained: Label = UiText.label("", &"white")
		explained.autowrap_mode = TextServer.AUTOWRAP_WORD
		explained.custom_minimum_size.x = LINE_WIDTH
		block.add_child(explained)
		line_labels.append(explained)
	advance(0.0)


## Brings the rows up to date with the simulation. Called every frame by [UiRoot]; tests call it.
func advance(_delta: float) -> void:
	if _simulation == null:
		return
	var stepped: bool = _simulation.tick != _asked_tick
	for order: int in choice_buttons.size():
		if _asked[order] >= 0 and (stepped or _asked[order] == _current(order)):
			_asked[order] = -1
		var shown: int = _lit(order)
		var buttons: Array = choice_buttons[order]
		for value: int in buttons.size():
			(buttons[value] as UiButton).lit = value == shown
		var text: String = line(order)
		if line_labels[order].text != text:
			line_labels[order].text = text


## The line explaining [param order]'s current choice ([constant PartyOrders.PACE] 0,
## [constant PartyOrders.GUARDIANS] 1 or [constant PartyOrders.SIDE_PATHS] 2), as the panel
## shows it.
func line(order: int) -> String:
	if order < 0 or order >= LINES.size():
		return ""
	var lines: Array = LINES[order]
	var shown: int = _lit(order)
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
	_asked_tick = _simulation.tick
	match order:
		PartyOrders.PACE:
			_simulation.set_pace(value as Expedition.Pace)
		PartyOrders.GUARDIANS:
			_simulation.set_guardian_order(value as Expedition.GuardianOrder)
		PartyOrders.SIDE_PATHS:
			_simulation.set_side_paths(value as Expedition.SidePaths)
	advance(0.0)


## The tooltip sentence of one choice.
static func tip(order: int, value: int) -> String:
	var text: String = TIPS[order][value]
	return text


## The simulation's own value of [param order].
func _current(order: int) -> int:
	match order:
		PartyOrders.PACE:
			return _simulation.expedition.pace
		PartyOrders.SIDE_PATHS:
			return _simulation.expedition.side_paths
	return _simulation.expedition.guardian_order


## The value lit for [param order]: the one asked for until the simulation applies it, then its own.
func _lit(order: int) -> int:
	if _simulation == null:
		return -1
	return _asked[order] if _asked[order] >= 0 else _current(order)

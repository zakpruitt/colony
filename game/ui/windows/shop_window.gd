class_name ShopWindow
extends WindowContent
## The upgrade shop (spec 017) as a window on the UI layer (spec 059 R2): one [ShopRow] per camp
## upgrade in shop order, then at its foot the Auto-buy switch (spec 022) over a sentence saying
## what it does. It opens over the running game and never pauses it.
##
## Every frame ([method advance], called by the HUD) it reads ranks, prices, gold and resources
## from the simulation, so it cannot drift; a buy goes through [method Simulation.buy_upgrade] and
## the switch through [method Simulation.set_auto_buy], and a row flashes on
## [constant SimEvent.Kind.UPGRADE_BOUGHT], whether the player or auto-buy bought it. [kbd]1[/kbd]
## to [kbd]5[/kbd] buy and [kbd]B[/kbd] switches auto-buy while the shop is the front window (the
## HUD hears them). While it is closed, its window's [member UiWindow.badge] counts the upgrades
## the party can pay for: the amber tag on the bar's Shop button (R6).

## The window's id, title and key.
const ID: StringName = &"shop"
const TITLE: String = "Camp upgrades"
const HOTKEY: String = "U"
## The Auto-buy switch's sentence.
const AUTO_BUY_LINE: String = "Buys the cheapest upgrade the party can pay for, once a second."
## UI pixels between rows (their own padding is the space; a rule divides them), and between the
## rows and the foot.
const ROW_GAP: int = 0
const FOOT_GAP: int = 6

## One row per upgrade, in [method Content.upgrade_ids] order.
var rows: Array[ShopRow] = []
## The Auto-buy switch (spec 022), lit while auto-buy is on, and the sentence beside it.
var auto_buy_button: UiButton
var auto_buy_caption: Label
## The tooltips of the rows, given by [method add_tips]; null until then.
var tip: UiTip

var _simulation: Simulation
## A switch asked for that the simulation has not applied yet (it applies on the next tick):
## 1 on, 0 off, -1 none.
var _asked_auto_buy: int = -1


func _init() -> void:
	super()
	name = "ShopWindow"
	add_theme_constant_override(&"separation", ROW_GAP)


## Call once, before the first advance. [param world] may be null (no flashes then).
func setup(simulation: Simulation, world: World, hud: Hud) -> void:
	_simulation = simulation
	_hud = hud
	var ids: Array[StringName] = Content.upgrade_ids()
	for i: int in ids.size():
		if i > 0:
			add_child(_rule())
		var row := ShopRow.new(ids[i], i)
		row.buy_button.pressed.connect(buy_row.bind(i))
		add_child(row)
		rows.append(row)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size.y = FOOT_GAP - ROW_GAP
	add_child(spacer)
	add_child(_rule())
	var foot := VBoxContainer.new()
	foot.name = "Foot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override(&"separation", 2)
	add_child(foot)
	auto_buy_button = UiButton.new("Auto-buy off", "B")
	auto_buy_button.name = "AutoBuy"
	auto_buy_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	auto_buy_button.pressed.connect(toggle_auto_buy)
	foot.add_child(auto_buy_button)
	auto_buy_caption = UiText.label(AUTO_BUY_LINE, &"steel")
	auto_buy_caption.name = "AutoBuyCaption"
	foot.add_child(auto_buy_caption)
	if world != null:
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Gives each row its tooltip (spec 052 R5): both prices, and where the resource comes from. Call
## once, after the shop is in its window.
func add_tips(tips: UiTip) -> void:
	tip = tips
	_tip_rows()


## Brings every row up to date with the simulation, runs the flashes, and sets the tag on the bar.
## Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	for row: ShopRow in rows:
		row.refresh(_simulation.upgrades, _simulation.party, delta)
	if _asked_auto_buy >= 0 and (_asked_auto_buy == 1) == _simulation.auto_buy:
		_asked_auto_buy = -1
	var on: bool = auto_buy_on()
	var text: String = "Auto-buy on" if on else "Auto-buy off"
	if auto_buy_button.text != text:
		auto_buy_button.text = text
	auto_buy_button.lit = on
	var holder: UiWindow = window()
	if holder != null:
		holder.badge = 0 if is_open() else affordable_count()
	if is_open():
		_tip_rows()


## True when the switch shows auto-buy as on: the switch asked for, until the simulation applies
## it, then the simulation's own.
func auto_buy_on() -> bool:
	if _asked_auto_buy >= 0:
		return _asked_auto_buy == 1
	return _simulation != null and _simulation.auto_buy


## Asks the simulation to switch auto-buy over, if the shop is open; otherwise does nothing.
func toggle_auto_buy() -> void:
	if not is_open() or _simulation == null:
		return
	var enabled: bool = not auto_buy_on()
	_asked_auto_buy = 1 if enabled else 0
	_simulation.set_auto_buy(enabled)
	advance(0.0)


## How many upgrades the party can pay both prices of the next rank of (spec 052).
func affordable_count() -> int:
	if _simulation == null:
		return 0
	var count: int = 0
	for id: StringName in Content.upgrade_ids():
		if _simulation.upgrades.can_pay(id, _simulation.party):
			count += 1
	return count


## Asks the simulation to buy the next rank of row [param index] (0-based), if the shop is open
## and the party can pay for it; otherwise does nothing.
func buy_row(index: int) -> void:
	if not is_open() or index < 0 or index >= rows.size():
		return
	var row: ShopRow = rows[index]
	row.refresh(_simulation.upgrades, _simulation.party, 0.0)
	if row.affordable():
		_simulation.buy_upgrade(row.id)


func _shown() -> void:
	advance(0.0)


func _tip_rows() -> void:
	if tip == null or _simulation == null:
		return
	for row: ShopRow in rows:
		tip.attach(row, row.tip_text(_simulation))


## A one-pixel line across the window, in dusk.
func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Palette.color(&"dusk")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size.y = 1
	return line


func _on_sim_event(event: SimEvent) -> void:
	if event.kind != SimEvent.Kind.UPGRADE_BOUGHT:
		return
	if event.source_id >= 0 and event.source_id < rows.size():
		rows[event.source_id].start_flash()

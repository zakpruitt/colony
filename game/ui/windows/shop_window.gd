class_name ShopWindow
extends WindowContent
## The upgrade shop (spec 017) as a window on the UI layer (spec 059 R2): one card ([ShopRow],
## spec 065) per camp upgrade in shop order, then at its foot the Auto-buy switch (spec 022) over a
## sentence saying what it does. It opens over the running game and never pauses it.
##
## Every frame ([method advance], called by the HUD) it reads ranks, prices, gold and resources
## from the simulation, so it cannot drift; a buy goes through [method Simulation.buy_upgrade] and
## the switch through [method Simulation.set_auto_buy].
##
## Spec 065: on [constant SimEvent.Kind.UPGRADE_BOUGHT] heard fresh (recent, and not while the
## world catches up) the card's new pip flashes, whoever bought it; a purchase the player asked for
## (the shop remembers each ask and its tick, and the simulation applies it on the next) also
## bursts the card's icon through [member moment] and steps its numbers. Every fifth rank and the
## top one get a banner with the upgrade's picture. A stale purchase starts none of it. [kbd]1[/kbd]
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
## Ticks an ask of the player's is remembered once made if its purchase is never heard (a shop
## with no world hears nothing): far longer than any purchase stays recent.
const ASK_TICKS: int = 100

## One card per upgrade, in [method Content.upgrade_ids] order.
var rows: Array[ShopRow] = []
## The Auto-buy switch (spec 022), lit while auto-buy is on, and the sentence beside it.
var auto_buy_button: UiButton
var auto_buy_caption: Label
## The tooltips of the cards, given by [method add_tips]; null until then.
var tip: UiTip
## Marks a purchase: the burst and the banner (spec 065). Given by [Main]; null for none.
var moment: UiMoment

var _simulation: Simulation
var _world: World
## The purchases the player asked for that have not been heard yet: each upgrade, and the tick it
## was asked on.
var _asked_ids: Array[StringName] = []
var _asked_ticks: Array[int] = []
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
	_world = world
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


## Gives each card its tooltip, a card itself (spec 065 R4): the picture, both prices of the next
## rank and where the resource comes from (spec 052 R5). Call once, after the shop is in its
## window.
func add_tips(tips: UiTip) -> void:
	tip = tips
	for row: ShopRow in rows:
		tip.attach_card(row, func() -> UiTip.Card: return row.card(_simulation))


## Brings every row up to date with the simulation, runs the flashes, and sets the tag on the bar.
## Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	var catching_up: bool = _world != null and _world.catching_up()
	for row: ShopRow in rows:
		if catching_up:
			row.stop()
		row.refresh(_simulation.upgrades, _simulation.party, delta)
	_forget_asks(_simulation.tick - ASK_TICKS)
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
		_asked_ids.append(row.id)
		_asked_ticks.append(_simulation.tick)


func _shown() -> void:
	advance(0.0)


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
	if event.source_id < 0 or event.source_id >= rows.size():
		return
	var row: ShopRow = rows[event.source_id]
	var players: bool = _take_ask(row.id, event.tick)
	if _world != null and (_world.catching_up() or not _world.is_recent(event)):
		return  # a stale purchase: the card simply shows the truth
	row.start_flash(event.amount)
	if players:
		row.start_step(event.amount - 1)
		if moment != null and row.icon.is_visible_in_tree():
			moment.burst(row.icon, event)
	var def: UpgradeDef = Content.upgrade(row.id)
	if moment != null and ShopRow.is_milestone(def, event.amount):
		moment.announce(
			row.id,
			ShopRow.milestone_headline(def, event.amount),
			ShopRow.milestone_line(def, event.amount),
			event
		)


## True when the purchase of [param upgrade] heard at [param tick] is one the player asked for (an
## ask the simulation applied on the tick after it was made); that ask is then forgotten.
func _take_ask(upgrade: StringName, tick: int) -> bool:
	_forget_asks(tick - 1)
	for i: int in _asked_ids.size():
		if _asked_ids[i] == upgrade and _asked_ticks[i] + 1 == tick:
			_asked_ids.remove_at(i)
			_asked_ticks.remove_at(i)
			return true
	return false


## Forgets every ask made before tick [param before]: the simulation has applied it, bought or not.
func _forget_asks(before: int) -> void:
	while not _asked_ticks.is_empty() and _asked_ticks[0] < before:
		_asked_ids.remove_at(0)
		_asked_ticks.remove_at(0)

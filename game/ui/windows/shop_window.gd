class_name ShopWindow
extends WindowContent
## The Camp window on the UI layer, in two tabs under a row of tab buttons, as the tally has its
## row. The Upgrades tab is the upgrade shop: one card ([ShopRow]) per camp upgrade in shop order,
## then at its foot a sentence saying what Auto-buy does; the Auto-buy switch stands at the right
## of the tab row while this tab shows. The Heroes tab ([RosterTab], in [member heroes_scroll], as
## tall as the Upgrades tab and scrolling inside it when it must) is where heroes are recruited
## and the four going down are chosen. It opens over
## the running game, never pauses it, and opens on the tab it last showed.
##
## Every frame ([method advance], called by the HUD) it reads ranks, prices, gold and resources
## from the simulation, so it cannot drift; a buy goes through [method Simulation.buy_upgrade] and
## the switch through [method Simulation.set_auto_buy].
##
## On [constant SimEvent.Kind.UPGRADE_BOUGHT] heard fresh (recent, and not while the
## world catches up) the card's new pip flashes, whoever bought it; a purchase the player asked for
## (the shop remembers each ask and its tick, and the simulation applies it on the next) also
## bursts the card's icon through [member moment] and steps its numbers. Every fifth rank and the
## top one get a banner with the upgrade's picture. A stale purchase starts none of it. [kbd]1[/kbd]
## to [kbd]5[/kbd] buy and [kbd]B[/kbd] switches auto-buy while the Camp is the front window on
## its Upgrades tab (the window keys hear them); [kbd]Q[/kbd] and [kbd]E[/kbd] change tab, and
## [kbd]Esc[/kbd] drops a choice of swap on the Heroes tab (else it closes the window), while the
## Camp is in front. While it is closed, it words nothing: its cards only run their flashes on,
## and are brought up to date as it opens; its tag on the bar's Camp button counts the upgrades
## the party can pay for and the classes it can recruit ([method WindowContent._show_badge]).

## Its two tabs, in the order of their buttons.
enum Page { UPGRADES, HEROES }

## The window's id and title (its key is its entry's, in [WindowBook]).
const ID: StringName = &"shop"
const TITLE: String = "Camp"
## The tab buttons' words and tooltips, in [enum Page] order.
const TAB_NAMES: Array[String] = ["Upgrades", "Heroes"]
const TAB_TIPS: Array[String] = [
	"Spend gold on upgrades for the whole party.",
	"Recruit heroes, and choose the four who go down.",
]
## UI pixels between the tab row and the tab under it, and the room a scroll bar takes at the
## right of the Heroes tab.
const TABS_GAP: int = 4
const SCROLL_ROOM: float = 12.0
## The Auto-buy switch's sentence.
const AUTO_BUY_LINE: String = "Auto-buy: the cheapest upgrade the party can pay for, each second."
## UI pixels between rows (their own padding is the space; a rule divides them), and between the
## rows and the foot.
const ROW_GAP: int = 0
const FOOT_GAP: int = 6
## Ticks an ask of the player's is remembered once made if its purchase is never heard (a shop
## with no world hears nothing): far longer than any purchase stays recent.
const ASK_TICKS: int = 100

## The tab buttons, in [enum Page] order; the open one is lit.
var tab_buttons: Array[UiButton] = []
## The Heroes tab, and what it scrolls in.
var heroes: RosterTab
var heroes_scroll: ScrollContainer
## One card per upgrade, in [method Content.upgrade_ids] order.
var rows: Array[ShopRow] = []
## The Auto-buy switch (in the tab row), lit while auto-buy is on, and the sentence at the foot.
var auto_buy_button: UiButton
var auto_buy_caption: Label
## The tooltips of the cards, given by [method add_tips]; null until then.
var tip: UiTip
## Marks a purchase, a find, a recruit and a swap: the bursts and the banners. Given by [Main];
## null for none.
var moment: UiMoment:
	set(value):
		moment = value
		if heroes != null:
			heroes.moment = value

var _simulation: Simulation
var _world: World
var _page: Page = Page.UPGRADES
## The Upgrades tab.
var _upgrades: VBoxContainer
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
	add_theme_constant_override(&"separation", TABS_GAP)


## Call once, before the first advance. [param world] may be null (no flashes then).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override(&"separation", 2)
	add_child(tabs)
	for i: int in TAB_NAMES.size():
		var tab := UiButton.new(TAB_NAMES[i])
		tab.name = "%sTab" % TAB_NAMES[i]
		tab.pressed.connect(set_page.bind(i as Page))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	var between := Control.new()
	between.mouse_filter = Control.MOUSE_FILTER_IGNORE
	between.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(between)
	# The switch stands at the tab row's right, shown with the Upgrades tab: under the cards it
	# would push the window down over the button bar in the smallest room.
	auto_buy_button = UiButton.new("Auto-buy off", "B")
	auto_buy_button.name = "AutoBuy"
	auto_buy_button.pressed.connect(toggle_auto_buy)
	tabs.add_child(auto_buy_button)
	_upgrades = VBoxContainer.new()
	_upgrades.name = "Upgrades"
	_upgrades.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrades.add_theme_constant_override(&"separation", ROW_GAP)
	add_child(_upgrades)
	var ids: Array[StringName] = Content.upgrade_ids()
	for i: int in ids.size():
		if i > 0:
			_upgrades.add_child(_rule())
		var row := ShopRow.new(ids[i], i)
		row.buy_button.pressed.connect(buy_row.bind(i))
		_upgrades.add_child(row)
		rows.append(row)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size.y = FOOT_GAP - ROW_GAP
	_upgrades.add_child(spacer)
	_upgrades.add_child(_rule())
	var foot := VBoxContainer.new()
	foot.name = "Foot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override(&"separation", 2)
	_upgrades.add_child(foot)
	auto_buy_caption = UiText.label(AUTO_BUY_LINE, &"steel")
	auto_buy_caption.name = "AutoBuyCaption"
	foot.add_child(auto_buy_caption)
	if world != null:
		world.sim_event.connect(_on_sim_event)
	_build_heroes(simulation, world)
	for row: ShopRow in rows:
		row.refresh(simulation.upgrades, simulation.party, 0.0)  # right before it is ever open
	advance(0.0)


## Gives each card its tooltip, a card itself: the picture, both prices of the next rank and where
## the resource comes from. Call once, after the shop is in its
## window.
func add_tips(tips: UiTip) -> void:
	tip = tips
	for row: ShopRow in rows:
		tip.attach_card(row, func() -> UiTip.Card: return row.card(_simulation))
	for i: int in tab_buttons.size():
		tip.attach(tab_buttons[i], TAB_TIPS[i])
	heroes.add_tips(tips)


## Brings every row up to date with the simulation while the shop is open, runs the flashes, and
## tells the bar its tag. Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	var catching_up: bool = _world != null and _world.catching_up()
	var open_now: bool = is_open()
	for row: ShopRow in rows:
		if catching_up:
			row.stop()
		if open_now:
			row.refresh(_simulation.upgrades, _simulation.party, delta)
		else:
			row.run_on(delta)
	_forget_asks(_simulation.tick - ASK_TICKS)
	if _asked_auto_buy >= 0 and (_asked_auto_buy == 1) == _simulation.auto_buy:
		_asked_auto_buy = -1
	var on: bool = auto_buy_on()
	var text: String = "Auto-buy on" if on else "Auto-buy off"
	if auto_buy_button.text != text:
		auto_buy_button.text = text
	auto_buy_button.lit = on
	if open_now and _page == Page.HEROES:
		heroes.refresh()
	_show_badge(0 if open_now else affordable_count() + RosterTab.recruitable(_simulation))


## True when the switch shows auto-buy as on: the switch asked for, until the simulation applies
## it, then the simulation's own.
func auto_buy_on() -> bool:
	if _asked_auto_buy >= 0:
		return _asked_auto_buy == 1
	return _simulation != null and _simulation.auto_buy


## Asks the simulation to switch auto-buy over, if the shop is open on its Upgrades tab;
## otherwise does nothing.
func toggle_auto_buy() -> void:
	if not is_open() or _simulation == null or _page != Page.UPGRADES:
		return
	var enabled: bool = not auto_buy_on()
	_asked_auto_buy = 1 if enabled else 0
	_simulation.set_auto_buy(enabled)
	advance(0.0)


## How many upgrades the party can pay both prices of the next rank of.
func affordable_count() -> int:
	if _simulation == null:
		return 0
	var count: int = 0
	for row: ShopRow in rows:
		if _simulation.upgrades.can_pay(row.id, _simulation.party):
			count += 1
	return count


## Asks the simulation to buy the next rank of row [param index] (0-based), if the shop is open
## on its Upgrades tab and the party can pay for it; otherwise does nothing.
func buy_row(index: int) -> void:
	if not is_open() or index < 0 or index >= rows.size() or _page != Page.UPGRADES:
		return
	var row: ShopRow = rows[index]
	row.refresh(_simulation.upgrades, _simulation.party, 0.0)
	if row.affordable():
		_simulation.buy_upgrade(row.id)
		_asked_ids.append(row.id)
		_asked_ticks.append(_simulation.tick)


## The tab showing (or the one that will show when the window next opens).
func page() -> Page:
	return _page


## Shows tab [param which]: its button is lit and only its content shows. A choice of swap is
## dropped.
func set_page(which: Page) -> void:
	_page = which
	heroes.drop_choice()
	_show_page()
	if is_open():
		advance(0.0)


func _shown() -> void:
	_fit_heroes()
	advance(0.0)


func _hidden() -> void:
	heroes.drop_choice()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = KeyBook.fresh_key(event)
	if key == null or (key.keycode != KEY_Q and key.keycode != KEY_E) or not _in_front():
		return
	var step: int = 1 if key.keycode == KEY_E else TAB_NAMES.size() - 1
	set_page(((_page + step) % TAB_NAMES.size()) as Page)
	get_viewport().set_input_as_handled()


## Esc with a choice of swap made drops it; the window stays open (a second Esc closes it). Heard
## before the windows hear it.
func _input(event: InputEvent) -> void:
	if not KeyBook.pressed(event, KEY_ESCAPE) or heroes.chosen() < 0 or not _in_front():
		return
	heroes.drop_choice()
	get_viewport().set_input_as_handled()


## True while the Camp is open and the front window of all.
func _in_front() -> bool:
	var holder: UiWindow = window()
	if holder == null or not holder.is_open():
		return false
	var windows: UiWindows = holder.get_parent() as UiWindows
	return windows == null or windows.front() == holder


func _build_heroes(simulation: Simulation, world: World) -> void:
	heroes_scroll = ScrollContainer.new()
	heroes_scroll.name = "HeroesScroll"
	heroes_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	heroes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	heroes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(heroes_scroll)
	heroes = RosterTab.new()
	heroes.moment = moment
	heroes_scroll.add_child(heroes)
	heroes.setup(simulation, world, _upgrades.get_combined_minimum_size().x - SCROLL_ROOM)
	_fit_heroes()
	_show_page()


## The Heroes tab takes the Upgrades tab's room, so the window keeps its size on either. Its
## room is known only once the window is themed, in the tree: it is worked out again as it opens.
func _fit_heroes() -> void:
	var room: Vector2 = _upgrades.get_combined_minimum_size()
	if heroes_scroll.custom_minimum_size != room:
		heroes_scroll.custom_minimum_size = room
	heroes.fit_width(room.x - SCROLL_ROOM)


func _show_page() -> void:
	_upgrades.visible = _page == Page.UPGRADES
	auto_buy_button.visible = _page == Page.UPGRADES
	heroes_scroll.visible = _page == Page.HEROES
	for i: int in tab_buttons.size():
		tab_buttons[i].lit = i == _page


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
	if _world != null and not _world.may_animate(event):
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

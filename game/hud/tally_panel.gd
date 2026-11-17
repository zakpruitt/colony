class_name TallyPanel
extends Control
## The party tally (spec 045), in the manner of a damage meter: each hero's damage dealt, healing
## done or damage taken as a bar beside the hero's portrait, scaled to the largest, with the number
## and the hero's share of the party's whole. It drops from under the HUD's top band at the left,
## where the hero sheet and the journal open, and is never larger than the sheet.
##
## Three tabs choose the [enum Tally.Measure] ([kbd]Q[/kbd] and [kbd]E[/kbd], passed on by the HUD,
## move between them, wrapping) and a two-way switch the [enum Tally.Span]: the last fight (the one
## under way while fighting) or the session. A line over the bars says which fight, and under them
## the session span lists the side quests of each hero who has done any.
##
## The counting is a [Tally] fed every event the world tells of, open or not, from the moment the
## HUD is made: after time away the HUD is made only once the replay is over (spec 019), so the
## time away adds nothing. [kbd]T[/kbd] or the HUD's button opens and closes it, [kbd]Esc[/kbd]
## closes it; opening it closes the shop, the hero sheet, the journal, help, the orders and the
## away report, and it closes itself when one of those opens ([method advance]). It never pauses
## the game and changes nothing in the simulation. Drawn as a [HudPanel] is.

## The panel's size in pixels (spec 045 R7: no larger than the hero sheet).
const SIZE: Vector2 = HeroSheet.SIZE
## Space inside the border.
const PADDING: float = 4.0
## The left and right edges of the content.
const BODY_LEFT: float = 6.0
const BODY_RIGHT: float = SIZE.x - 6.0
## The title row's top, the tab row's top, and the line under the tabs.
const TITLE_Y: float = 4.0
const TABS_Y: float = 17.0
const TAB_LINE_Y: float = TABS_Y + HudButton.HEIGHT + 1.0
## The fight's line, under the tabs.
const FIGHT_Y: float = TAB_LINE_Y + 3.0
## The first hero's row and a row's height; in a row, the portrait's box, where the name and the
## bar start, and the bar's top and height.
const ROWS_Y: float = FIGHT_Y + 12.0
const ROW_HEIGHT: float = 21.0
const PORTRAIT_BOX: Vector2 = Vector2(20, 20)
const TEXT_X: float = BODY_LEFT + PORTRAIT_BOX.x + 4.0
const BAR_Y: float = 10.0
const BAR_HEIGHT: float = 8.0
## Pixels between a hero's number and its share.
const SHARE_GAP: float = 5.0
## The side-quest lines: two to a row, this far apart, this tall.
const QUEST_COLUMN: float = 116.0
const QUEST_ROW: float = 9.0
## Pixels between tab buttons.
const TAB_GAP: float = 3.0
const TITLE: String = "Party tally"
## The dim line of keys at the right of the tab row.
const KEYS_HINT: String = "Q E tabs   T close"
## The tab names, in [enum Tally.Measure] order, and the switch's, in [enum Tally.Span] order.
const TAB_NAMES: Array[String] = ["Damage", "Healing", "Taken"]
const SPAN_NAMES: Array[String] = ["Last fight", "Session"]
## The tooltip of each tab and of each side of the switch (spec 045 R6), in the same orders.
const TAB_TIPS: Array[String] = [
	"Damage each hero dealt to monsters.",
	"Health each hero gave back to the party, not counting healing past full health.",
	"Damage each hero took, from monsters and from sprung traps.",
]
const SPAN_TIPS: Array[String] = [
	"Count only the last fight, or the one under way.",
	"Count everything since the game was opened or loaded.",
]
## Each class's bar: its colour and the darker bottom row, from the hero's own main colour
## ([code]docs/style-bible.md[/code], The cast).
const CLASS_BARS: Dictionary[StringName, Array] = {
	&"knight": [&"red", &"crimson"],
	&"rogue": [&"orchid", &"plum"],
	&"mage": [&"blue", &"navy"],
	&"cleric": [&"amber", &"copper"],
}
const OTHER_BAR: Array[StringName] = [&"silver", &"steel"]

## The tally's counting.
var tally: Tally = Tally.new()
## The close button at the top right.
var close_button: HudButton
## The tab buttons, in [enum Tally.Measure] order; the open one is lit.
var tab_buttons: Array[HudButton] = []
## The span switch's two buttons, in [enum Tally.Span] order; the chosen one is lit.
var span_buttons: Array[HudButton] = []
## Each hero's portrait, in party order.
var portraits: Array[TextureRect] = []

var _simulation: Simulation
var _world: World
var _measure: Tally.Measure = Tally.Measure.DAMAGE
var _span: Tally.Span = Tally.Span.LAST_FIGHT
## The tick the HUD started counting at: the session's start.
var _start_tick: int = 0
## What is known of the last fight: its start and end ticks (-1 for none, or while it lasts), its
## depth, its monsters' kinds when the battle could be read, and every monster seen in its hits.
var _fight_start: int = -1
var _fight_end: int = -1
var _fight_depth: int = 0
var _fight_kinds: Array[StringName] = []
var _fight_monsters: Dictionary[int, bool] = {}
var _fight_label: Label
var _names: Array[Label] = []
var _values: Array[Label] = []
var _shares: Array[Label] = []
var _quest_labels: Array[Label] = []
var _bars: Array[EasedValue] = []
var _goals: Array[float] = []


func _init() -> void:
	name = "TallyPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	size = SIZE
	position = Vector2(Hud.MARGIN, Hud.TOP_BAND + HeroSheet.DROP)


func _draw() -> void:
	var dusk: Color = Palette.color(&"dusk")
	var ink: Color = Palette.color(&"ink")
	HudPanel.draw_panel(self, Rect2(Vector2.ZERO, size), Palette.color(&"night"), dusk, ink)
	draw_rect(Rect2(PADDING, TAB_LINE_Y, SIZE.x - 2.0 * PADDING, 1), dusk)
	var heroes: Array[Hero] = _heroes()
	for i: int in heroes.size():
		var top: float = ROWS_Y + i * ROW_HEIGHT
		HudPanel.draw_panel(
			self, Rect2(Vector2(BODY_LEFT, top - 1.0), PORTRAIT_BOX), ink, ink, dusk
		)
		var colours: Array = CLASS_BARS.get(heroes[i].class_id, OTHER_BAR)
		var bar := Rect2(TEXT_X, top + BAR_Y, BODY_RIGHT - TEXT_X, BAR_HEIGHT)
		var fill: StringName = colours[0]
		var shade: StringName = colours[1]
		var fraction: float = _bars[i].value if i < _bars.size() else 0.0
		HudPanel.draw_bar(self, bar, fraction, Palette.color(fill), Palette.color(shade), ink)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_T:
			toggle()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			# Not marked handled, so the HUD and the other panels close what they have open too.
			close()


## Call once, before the first advance. [param world] may be null (nothing is counted then).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	_start_tick = simulation.tick
	_build()
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Closes the panel if another panel has opened, brings its lines up to date and eases the bars.
## Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	if is_open() and _another_is_open():
		close()
	if not is_open():
		return
	_refresh()
	for i: int in _bars.size():
		_bars[i].advance(_goals[i], delta)
	queue_redraw()


## Shows the panel, closing the shop, the hero sheet, the journal, help, the orders and the "While
## you were away" panel if any is up.
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
		if hud.orders != null:
			hud.orders.close()
		var layer: Node = hud.get_parent()
		if layer != null:
			for child: Node in layer.get_children():
				if child is AwayPanel:
					(child as AwayPanel).close()
	var was_open: bool = visible
	visible = true
	if _simulation != null and not was_open:
		_refresh()
		for i: int in _bars.size():
			_bars[i].snap(_goals[i])
		queue_redraw()


## Hides the panel.
func close() -> void:
	visible = false


## True while the panel is shown.
func is_open() -> bool:
	return visible


## Opens the panel if it is closed, closes it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## The lines showing, top first: the fight's line, a row per hero as "<class> <number> <share>%"
## ("Knight 1,234 45%"), then the side-quest lines ("Rogue: 4 side quests"). Empty while closed.
func rows() -> Array[String]:
	var lines: Array[String] = []
	if not is_open():
		return lines
	lines.append(_fight_label.text)
	for i: int in _names.size():
		lines.append("%s %s %s" % [_names[i].text, _values[i].text, _shares[i].text])
	for label: Label in _quest_labels:
		if label.visible:
			lines.append(label.text)
	return lines


## The measure shown.
func measure() -> Tally.Measure:
	return _measure


## Shows [param which]: its tab is lit and the bars ease to it.
func set_measure(which: Tally.Measure) -> void:
	_measure = which
	_light()
	if is_open():
		_refresh()


## Shows the next measure, wrapping from the last to the first.
func next_measure() -> void:
	set_measure(((_measure + 1) % TAB_NAMES.size()) as Tally.Measure)


## Shows the previous measure, wrapping from the first to the last.
func previous_measure() -> void:
	set_measure(((_measure + TAB_NAMES.size() - 1) % TAB_NAMES.size()) as Tally.Measure)


## The span shown.
func span() -> Tally.Span:
	return _span


## Shows [param which]: its side of the switch is lit.
func set_span(which: Tally.Span) -> void:
	_span = which
	_light()
	if is_open():
		_refresh()


## The fraction of its row the hero's bar is easing toward: its number over the largest number.
func bar_goal(hero_id: int) -> float:
	var index: int = _index(hero_id)
	return _goals[index] if index >= 0 else 0.0


## The fraction of its row the hero's bar shows this frame.
func bar_fraction(hero_id: int) -> float:
	var index: int = _index(hero_id)
	return _bars[index].value if index >= 0 else 0.0


## What the fight was, for the line over the bars: "3 ogres", "2 goblins, 1 cave bat", "the Slime
## King", or "5 monsters" when the kinds were not seen or would not fit in [param room] pixels.
func monsters_text(room: float) -> String:
	var counts: Dictionary[StringName, int] = {}
	for kind: StringName in _fight_kinds:
		var def: MonsterDef = Content.monster(kind)
		if def != null and def.guardian:
			return "the %s" % def.display_name
		counts[kind] = counts.get(kind, 0) + 1
	var total: int = _fight_kinds.size() if not _fight_kinds.is_empty() else _fight_monsters.size()
	var fallback: String = "%d monster%s" % [total, "" if total == 1 else "s"]
	if counts.is_empty():
		return fallback
	var kinds: Array[StringName] = []
	kinds.assign(counts.keys())
	# The most numerous first; a stable sort keeps the order they stood in on a tie.
	var ordered: Array[StringName] = []
	for most: int in range(_fight_kinds.size(), 0, -1):
		for kind: StringName in kinds:
			if counts[kind] == most:
				ordered.append(kind)
	var parts: PackedStringArray = []
	for kind: StringName in ordered:
		var count: int = counts[kind]
		var named: String = Content.monster(kind).display_name.to_lower()
		parts.append("%d %s%s" % [count, named, "s" if count > 1 else ""])
	var text: String = ", ".join(parts)
	return text if PixelText.width(text) <= room else fallback


# --- Counting ------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	tally.observe(event)
	match event.kind:
		SimEvent.Kind.ENCOUNTER_STARTED:
			_fight_start = event.tick
			_fight_end = -1
			_fight_depth = _simulation.expedition.depth
			_fight_kinds = _battle_kinds(event.amount)
			_fight_monsters.clear()
		SimEvent.Kind.ENCOUNTER_ENDED:
			_fight_end = event.tick
		SimEvent.Kind.HIT, SimEvent.Kind.HEALED:
			for id: int in [event.source_id, event.target_id]:
				if id >= Expedition.FIRST_MONSTER_ID:
					_fight_monsters[id] = true


## The kinds of monster in the battle in chamber [param chamber_index], if the expedition is still
## fighting there; empty if it is not (the fight was over before the HUD heard it began).
func _battle_kinds(chamber_index: int) -> Array[StringName]:
	var kinds: Array[StringName] = []
	var e: Expedition = _simulation.expedition
	var room: LabyrinthChamber = e.chamber()
	if e.state != Expedition.State.FIGHTING or e.battle == null or room == null:
		return kinds
	if room.index != chamber_index:
		return kinds
	for monster: Combatant in e.battle.monsters:
		kinds.append(monster.def_id)
	return kinds


# --- Showing -------------------------------------------------------------------


func _build() -> void:
	var title: Label = _label(TITLE, &"yellow", Vector2(BODY_LEFT, TITLE_Y + 1.0))
	title.name = "Title"
	close_button = HudButton.new("x")
	close_button.name = "Close"
	close_button.custom_minimum_size = Vector2(HudButton.HEIGHT, HudButton.HEIGHT)
	close_button.size = close_button.get_combined_minimum_size()
	close_button.position = Vector2(SIZE.x - PADDING - close_button.size.x, TITLE_Y)
	close_button.pressed.connect(close)
	add_child(close_button)
	var right: float = close_button.position.x - 6.0
	for i: int in range(SPAN_NAMES.size() - 1, -1, -1):
		var button := HudButton.new(SPAN_NAMES[i])
		button.name = "%sSpan" % SPAN_NAMES[i].replace(" ", "")
		button.position = Vector2(right - button.size.x, TITLE_Y)
		button.pressed.connect(set_span.bind(i as Tally.Span))
		add_child(button)
		span_buttons.push_front(button)
		right = button.position.x - 2.0
	var x: float = BODY_LEFT
	for i: int in TAB_NAMES.size():
		var tab := HudButton.new(TAB_NAMES[i])
		tab.name = "%sTab" % TAB_NAMES[i]
		tab.position = Vector2(x, TABS_Y)
		tab.pressed.connect(set_measure.bind(i as Tally.Measure))
		add_child(tab)
		tab_buttons.append(tab)
		x += tab.size.x + TAB_GAP
	var hint: Label = _label(KEYS_HINT, &"slate", Vector2.ZERO)
	hint.name = "KeysHint"
	hint.position = Vector2(BODY_RIGHT - PixelText.width(KEYS_HINT), TABS_Y + 2.0)
	_fight_label = _label("", &"silver", Vector2(BODY_LEFT, FIGHT_Y))
	_fight_label.name = "Fight"
	var icons: PixelSheet = PixelSheet.load_sheet(Hud.ICONS_PATH)
	var heroes: Array[Hero] = _heroes()
	for i: int in heroes.size():
		var hero: Hero = heroes[i]
		var top: float = ROWS_Y + i * ROW_HEIGHT
		var portrait := TextureRect.new()
		portrait.name = "Portrait%d" % hero.id
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP
		portrait.position = Vector2(BODY_LEFT + 2.0, top + 1.0)
		portrait.size = Vector2(16, 16)
		if icons != null and icons.has_part(hero.class_id):
			portrait.texture = icons.part(hero.class_id)
		add_child(portrait)
		portraits.append(portrait)
		_names.append(_label(hero.def().display_name, &"white", Vector2(TEXT_X, top)))
		_values.append(_label("0", &"white", Vector2(0, top)))
		_shares.append(_label("0%", &"steel", Vector2(0, top)))
		_bars.append(EasedValue.new(HeroFrame.EASE_SECONDS))
		_goals.append(0.0)
	var quests_top: float = ROWS_Y + heroes.size() * ROW_HEIGHT + 1.0
	for i: int in heroes.size():
		var at := Vector2(
			BODY_LEFT + (i % 2) * QUEST_COLUMN, quests_top + floorf(i / 2.0) * QUEST_ROW
		)
		var line: Label = _label("", &"green", at)
		line.name = "Quests%d" % i
		line.visible = false
		_quest_labels.append(line)
	_light()


## Lights the open tab and the chosen side of the switch.
func _light() -> void:
	for i: int in tab_buttons.size():
		tab_buttons[i].lit = i == _measure
	for i: int in span_buttons.size():
		span_buttons[i].lit = i == _span


## Brings every line and bar goal up to date with the tally.
func _refresh() -> void:
	var heroes: Array[Hero] = _heroes()
	var amounts: Array[int] = []
	var largest: int = 0
	for hero: Hero in heroes:
		var amount: int = tally.value(hero.id, _measure, _span)
		amounts.append(amount)
		largest = maxi(largest, amount)
	var percents: Array[int] = Tally.percents(amounts)
	for i: int in mini(heroes.size(), _names.size()):
		_goals[i] = float(amounts[i]) / largest if largest > 0 else 0.0
		_set_text(_values[i], Hud.group_thousands(amounts[i]))
		_set_text(_shares[i], "%d%%" % percents[i])
		_shares[i].position.x = BODY_RIGHT - _shares[i].size.x
		_values[i].position.x = _shares[i].position.x - SHARE_GAP - _values[i].size.x
	_set_text(_fight_label, _fight_text())
	# The side quests: the session's, a line for each hero who has done any.
	var shown: int = 0
	for hero: Hero in heroes:
		var count: int = tally.side_quests(hero.id)
		if count <= 0 or _span != Tally.Span.SESSION or shown >= _quest_labels.size():
			continue
		var noun: String = "side quest" if count == 1 else "side quests"
		_set_text(_quest_labels[shown], "%s: %d %s" % [hero.def().display_name, count, noun])
		shown += 1
	for i: int in _quest_labels.size():
		_quest_labels[i].visible = i < shown


## The line over the bars: which fight, or the session.
func _fight_text() -> String:
	if _span == Tally.Span.SESSION:
		var fights: int = tally.fights()
		var played: String = Journal.clock(_simulation.tick - _start_tick)
		return "Session: %d fight%s in %s" % [fights, "" if fights == 1 else "s", played]
	if _fight_start < 0:
		return "No fight yet"
	var ongoing: bool = _fight_end < 0
	var end: int = _simulation.tick if ongoing else _fight_end
	var seconds: int = roundi(float(end - _fight_start) / Simulation.TICKS_PER_SECOND)
	var head: String = "This fight: " if ongoing else "Last fight: "
	var tail: String = ", depth %d, %d s" % [_fight_depth, seconds]
	var room: float = BODY_RIGHT - BODY_LEFT - PixelText.width(head + tail)
	return head + monsters_text(room) + tail


func _heroes() -> Array[Hero]:
	if _simulation == null:
		return []
	return _simulation.party.heroes


func _index(hero_id: int) -> int:
	var heroes: Array[Hero] = _heroes()
	for i: int in mini(heroes.size(), _goals.size()):
		if heroes[i].id == hero_id:
			return i
	return -1


## True while a panel the tally never shares the screen with is open.
func _another_is_open() -> bool:
	var hud: Hud = get_parent() as Hud
	if hud == null:
		return false
	var shop: bool = hud.shop != null and hud.shop.is_open()
	var sheet: bool = hud.hero_sheet != null and hud.hero_sheet.is_open()
	var journal: bool = hud.journal != null and hud.journal.is_open()
	var help: bool = hud.help != null and hud.help.is_open()
	var orders: bool = hud.orders != null and hud.orders.is_open()
	return shop or sheet or journal or help or orders


func _label(text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()

class_name TallyWindow
extends WindowContent
## The party tally as a window on the UI layer, in the manner of a damage
## meter: tabs for Damage, Healing and Taken, the Last fight / Session switch, a line saying which
## fight, then one line per hero: its portrait, its name in bold, its number right-aligned in a
## column of equal-width digits and its share, over a bar in the hero's class colour scaled to the
## largest. Under them the session span lists the side quests of each hero who has done any.
##
## Clicking a hero's line opens its abilities under it, indented, each with a thin
## bar: the open tab's measure by what dealt or gave it ("Whirlwind 412", "Strikes 950"), largest
## first. A second click closes it. [kbd]Q[/kbd] and [kbd]E[/kbd] change tab while the tally is the
## front window (the HUD hears them).
##
## The counting is a [Tally] fed every event the world tells of, open or not, from the moment the
## HUD is made: after time away the HUD is made only once the replay is over, so the time
## away adds nothing. It changes nothing in the simulation. Its [StatusBook] also gives the hero
## frames their statuses ([method status_line]).

## The window's id and title (its key is its entry's, in [WindowBook]).
const ID: StringName = &"tally"
const TITLE: String = "Party tally"
## The tab names, in [enum Tally.Measure] order, and the switch's, in [enum Tally.Span] order.
const TAB_NAMES: Array[String] = ["Damage", "Healing", "Taken"]
const SPAN_NAMES: Array[String] = ["Last fight", "Session"]
## The tooltip of each tab and of each side of the switch, in the same orders.
## A blow's whole size is what the events carry, so Damage and Taken include overkill.
const TAB_TIPS: Array[String] = [
	"Damage each hero dealt to monsters, overkill on a killing blow included.",
	"Health each hero gave back to the party, not counting healing past full health.",
	"Damage each hero took from monsters and sprung traps, overkill on a last blow included.",
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
## The most ability lines an open hero shows; past it, the smallest are summed as "Others".
const BY_ABILITY_LINES: int = 6
## What an open line shows on the Taken tab, which is not counted by ability.
const TAKEN_NOTE: String = "Not counted by ability."
const ROW_TIP: String = "Click to see this hero's numbers by ability."
## UI pixels: the portrait's box, the heroes' bars' height, the abilities' bars' height, how far
## the abilities are indented, and the widest number the tally shows.
const PORTRAIT: Vector2 = Vector2(18, 18)
const BAR_HEIGHT: int = 6
const ABILITY_BAR_HEIGHT: int = 3
const INDENT: int = 12
const LONGEST_NUMBER: String = "99,999,999"
## UI pixels: the width of the fight's line, which wraps.
const WIDTH: int = 200
## The dim note of the keys, beside the switch.
const KEYS_HINT: String = "Q E tabs"

## The tally's counting.
var tally: Tally = Tally.new()
## The tab buttons, in [enum Tally.Measure] order; the open one is lit.
var tab_buttons: Array[UiButton] = []
## The span switch's two buttons, in [enum Tally.Span] order; the chosen one is lit.
var span_buttons: Array[UiButton] = []
## Each hero's portrait, line, bar, number and share, in party order.
var portraits: Array[TextureRect] = []
var hero_lines: Array[Control] = []
var bars: Array[UiBar] = []
var value_labels: Array[Label] = []
var share_labels: Array[Label] = []
## The open hero's ability lines as shown, top first; each holds its name, its number and a bar.
var ability_lines: Array[Control] = []
## The tooltips, given by [method add_tips]; null until then.
var tip: UiTip

var _simulation: Simulation
var _measure: Tally.Measure = Tally.Measure.DAMAGE
var _span: Tally.Span = Tally.Span.LAST_FIGHT
## The tick the HUD started counting at: the session's start.
var _start_tick: int = 0
## What is known of the last fight: its start and end ticks (-1 for none, or while it lasts), its
## place, its monsters' kinds when the battle could be read, and every monster seen in its hits.
var _fight_start: int = -1
var _fight_end: int = -1
var _fight_place: String = ""
## The area and stage the events are in, kept in event order.
var _area: StringName = &""
var _depth: int = 1
var _fight_kinds: Array[StringName] = []
var _fight_monsters: Dictionary[int, bool] = {}
var _fight_label: Label
var _names: Array[Label] = []
var _eased: Array[EasedValue] = []
var _goals: Array[float] = []
var _quest_labels: Array[Label] = []
## The hero whose line is open, or -1; the box under each hero's line its abilities go in, the
## caption over them and the note shown on the Taken tab.
var _opened: int = -1
var _ability_boxes: Array[VBoxContainer] = []
## Whose the ability lines are: their box and the class colouring their bars.
var _lines_of: String = ""
var _caption: Label
var _note: Label


func _init() -> void:
	super()
	name = "TallyWindow"
	add_theme_constant_override(&"separation", 3)


## Call once, before the first advance. [param world] may be null (nothing is counted then).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_start_tick = simulation.tick
	_area = simulation.expedition.place
	_depth = simulation.expedition.depth
	_build()
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
		_join_fight()
	advance(0.0)


## Gives the tabs, the switch and each hero's line their tooltips. Call once, after the tally is in
## its window.
func add_tips(tips: UiTip) -> void:
	tip = tips
	for i: int in tab_buttons.size():
		tip.attach(tab_buttons[i], TAB_TIPS[i])
	for i: int in span_buttons.size():
		tip.attach(span_buttons[i], SPAN_TIPS[i])
	for line: Control in hero_lines:
		tip.attach(line, ROW_TIP)


## Brings its lines up to date and eases the bars. Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	# After this frame's events: the next frame's are heard from here on.
	_area = _simulation.expedition.place
	_depth = _simulation.expedition.depth
	if not is_open():
		return
	_refresh()
	for i: int in _eased.size():
		_eased[i].advance(_goals[i], delta)
		bars[i].fraction = _eased[i].value


## The lines showing, top first: the fight's line, a line per hero as "<class> <number>
## <share>%" ("Knight 1,234 45%"), then the side-quest lines ("Rogue: 4 side quests"), then
## [method breakdown]. Empty while closed.
func rows() -> Array[String]:
	var lines: Array[String] = []
	if not is_open():
		return lines
	lines.append(_fight_label.text)
	for i: int in _names.size():
		lines.append("%s %s %s" % [_names[i].text, value_labels[i].text, share_labels[i].text])
	for label: Label in _quest_labels:
		if label.visible:
			lines.append(label.text)
	lines.append_array(breakdown())
	return lines


## Opens the line of the hero with id [param hero_id], or closes it if it is open.
func open_hero(hero_id: int) -> void:
	_opened = -1 if _opened == hero_id else hero_id
	if is_open():
		_refresh()


## The hero whose line is open, or -1.
func opened_hero() -> int:
	return _opened


## The open line as shown: the measure's name ("Damage"), then its lines ("Whirlwind 412"), or the
## note on the Taken tab; empty while no line is open.
func breakdown() -> Array[String]:
	var lines: Array[String] = []
	if _opened < 0 or not is_open():
		return lines
	lines.append(_caption.text)
	if _note.visible:
		lines.append(_note.text)
	for line: Control in ability_lines:
		var labels: Array[Node] = line.find_children("*", "Label", true, false)
		lines.append("%s %s" % [(labels[0] as Label).text, (labels[1] as Label).text])
	return lines


## Every status on fighter [param id] with the whole seconds it has left: "Shielded 6 s, Hasted
## 9 s"; empty for none.
func status_line(id: int) -> String:
	if _simulation == null:
		return ""
	return StatusIcons.describe(tally.credit.statuses.statuses_of(id), _simulation.tick)


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


## The fraction of its line the hero's bar is easing toward: its number over the largest number.
func bar_goal(hero_id: int) -> float:
	var index: int = _index(hero_id)
	return _goals[index] if index >= 0 else 0.0


## The fraction of its line the hero's bar shows this frame.
func bar_fraction(hero_id: int) -> float:
	var index: int = _index(hero_id)
	return bars[index].fraction if index >= 0 else 0.0


## The width of the abilities' name column: the longest ability name in the data, or the longest
## of the other names a line can have, whichever is wider.
func ability_name_width() -> int:
	var widest: int = UiText.width("Others")
	for id: StringName in Content.ability_ids():
		widest = maxi(widest, UiText.width(Content.ability(id).display_name))
	for named: String in [AbilityCredit.STRIKES, AbilityCredit.HEALS]:
		widest = maxi(widest, UiText.width(named))
	for kind: int in AbilityEffect.Status.size():
		widest = maxi(widest, UiText.width(ShownStatus.status_name(kind)))
	return widest


## What the fight was, for the line over the bars: "3 ogres", "2 goblins, 1 cave bat", "the Slime
## King", or "5 monsters" when the kinds were not seen or would not fit in [param room] UI pixels.
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
	return text if UiText.width(text) <= room else fallback


## A bar [param height] UI pixels tall in the colours of class [param class_id].
static func class_bar(class_id: StringName, height: int) -> UiBar:
	var colours: Array = CLASS_BARS.get(class_id, OTHER_BAR)
	var fill: StringName = colours[0]
	var shade: StringName = colours[1]
	return UiBar.new(fill, shade, height)


func _shown() -> void:
	if _simulation == null:
		return
	_refresh()
	for i: int in _eased.size():
		_eased[i].snap(_goals[i])
		bars[i].fraction = _goals[i]


# --- Counting ------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	tally.observe(event)
	match event.kind:
		SimEvent.Kind.DEPTH_CHANGED, SimEvent.Kind.PARTY_REVIVED:
			_depth = event.amount
		SimEvent.Kind.AREA_CHANGED:
			var ids: Array[StringName] = Content.area_ids()
			if event.amount >= 0 and event.amount < ids.size():
				_area = ids[event.amount]
		SimEvent.Kind.ENCOUNTER_STARTED:
			_fight_start = event.tick
			_fight_end = -1
			# The fight under way is where the party is; one heard late (the party may have gone
			# on, even to another area) is where the events had it then.
			var battle: Battle = _simulation.expedition.battle
			var current: bool = battle != null and battle.tick == event.tick
			var stage: int = _simulation.expedition.depth if current else _depth
			_fight_place = PlaceText.of(
				_area if not current else _simulation.expedition.place, stage
			)
			_fight_kinds = _battle_kinds(event.amount)
			_fight_monsters.clear()
		SimEvent.Kind.ENCOUNTER_ENDED:
			_fight_end = event.tick
		SimEvent.Kind.HIT, SimEvent.Kind.HEALED:
			for id: int in [event.source_id, event.target_id]:
				if id >= Expedition.FIRST_MONSTER_ID:
					_fight_monsters[id] = true


## Made while the party is fighting (the game opened or returned to mid-fight), the tally takes the
## fight under way as begun, from the tick it began, as if it had heard it start.
func _join_fight() -> void:
	var e: Expedition = _simulation.expedition
	var room: LabyrinthChamber = e.chamber()
	if e.state != Expedition.State.FIGHTING or e.battle == null or room == null:
		return
	var began: int = maxi(0, _simulation.tick - e.battle.tick)
	_on_sim_event(SimEvent.new(SimEvent.Kind.ENCOUNTER_STARTED, began, -1, -1, room.index))


## The kinds of monster in the battle in chamber [param chamber_index], if the expedition is still
## fighting there; empty if it is not.
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


# --- Building ------------------------------------------------------------------


func _build() -> void:
	var tabs: HBoxContainer = _button_row("Tabs")
	for i: int in TAB_NAMES.size():
		var tab := UiButton.new(TAB_NAMES[i])
		tab.name = "%sTab" % TAB_NAMES[i]
		tab.toggle_mode = false
		tab.pressed.connect(set_measure.bind(i as Tally.Measure))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	var spans: HBoxContainer = _button_row("Spans")
	for i: int in SPAN_NAMES.size():
		var button := UiButton.new(SPAN_NAMES[i])
		button.name = "%sSpan" % SPAN_NAMES[i].replace(" ", "")
		button.toggle_mode = false
		button.pressed.connect(set_span.bind(i as Tally.Span))
		spans.add_child(button)
		span_buttons.append(button)
	var keys: Label = UiText.label(KEYS_HINT, &"slate")
	keys.name = "KeysHint"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.size_flags_vertical = Control.SIZE_FILL
	spans.add_child(keys)
	_fight_label = UiText.label("", &"silver")
	_fight_label.name = "Fight"
	_fight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fight_label.custom_minimum_size = Vector2(WIDTH, 2 * UiText.LINE_HEIGHT)
	add_child(_fight_label)
	var icons: PixelSheet = PixelSheet.load_sheet(Hud.ICONS_PATH)
	for hero: Hero in _simulation.party.heroes:
		_build_hero(hero, icons)
	for hero: Hero in _simulation.party.heroes:
		var line: Label = UiText.label("", &"green")
		line.name = "Quests%d" % hero.id
		line.visible = false
		add_child(line)
		_quest_labels.append(line)
	_caption = UiText.label("", &"steel")
	_caption.name = "ByAbility"
	_note = UiText.label(TAKEN_NOTE, &"steel")
	_note.name = "TakenNote"
	if not _ability_boxes.is_empty():
		_ability_boxes[0].add_child(_caption)
		_ability_boxes[0].add_child(_note)
	_light()


func _button_row(row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 2)
	add_child(row)
	return row


## Hero [param hero]'s line, clickable, and the box its abilities open in under it.
func _build_hero(hero: Hero, icons: PixelSheet) -> void:
	var line := HeroLine.new()
	line.name = "Hero%d" % hero.id
	line.pressed.connect(open_hero.bind(hero.id))
	add_child(line)
	hero_lines.append(line)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 5)
	line.add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "Portrait%d" % hero.id
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	portrait.custom_minimum_size = PORTRAIT
	if icons != null and icons.has_part(hero.class_id):
		portrait.texture = icons.part(hero.class_id)
	row.add_child(portrait)
	portraits.append(portrait)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 1)
	row.add_child(column)
	var text := HBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override(&"separation", 6)
	column.add_child(text)
	var hero_name: Label = UiText.label(hero.def().display_name, &"white", true)
	hero_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(hero_name)
	_names.append(hero_name)
	var value: Label = UiText.label("0", &"white")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = UiText.width(LONGEST_NUMBER)
	text.add_child(value)
	value_labels.append(value)
	var share: Label = UiText.label("0%", &"steel")
	share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	share.custom_minimum_size.x = UiText.width("100%")
	text.add_child(share)
	share_labels.append(share)
	var bar: UiBar = class_bar(hero.class_id, BAR_HEIGHT)
	column.add_child(bar)
	bars.append(bar)
	_eased.append(EasedValue.new(HeroFrameView.EASE_SECONDS))
	_goals.append(0.0)
	var indent := MarginContainer.new()
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.add_theme_constant_override(&"margin_left", INDENT)
	indent.add_theme_constant_override(&"margin_bottom", 3)
	indent.visible = false
	add_child(indent)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 1)
	indent.add_child(box)
	_ability_boxes.append(box)


## One ability's line: its name, its number right-aligned, and a thin bar of [param fraction].
func _ability_line(named: String, amount: int, fraction: float, class_id: StringName) -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 6)
	var label: Label = UiText.label(named, &"silver")
	label.custom_minimum_size.x = ability_name_width()
	line.add_child(label)
	var value: Label = UiText.label(Hud.group_thousands(amount), &"white")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = UiText.width(LONGEST_NUMBER)
	line.add_child(value)
	var bar: UiBar = class_bar(class_id, ABILITY_BAR_HEIGHT)
	bar.fraction = fraction
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	return line


# --- Showing -------------------------------------------------------------------


## Lights the open tab and the chosen side of the switch.
func _light() -> void:
	for i: int in tab_buttons.size():
		tab_buttons[i].lit = i == _measure
	for i: int in span_buttons.size():
		span_buttons[i].lit = i == _span


## Brings every line and bar goal up to date with the tally.
func _refresh() -> void:
	var heroes: Array[Hero] = _simulation.party.heroes
	var amounts: Array[int] = []
	var largest: int = 0
	for hero: Hero in heroes:
		var amount: int = tally.value(hero.id, _measure, _span)
		amounts.append(amount)
		largest = maxi(largest, amount)
	var percents: Array[int] = Tally.percents(amounts)
	for i: int in mini(heroes.size(), _names.size()):
		_goals[i] = float(amounts[i]) / largest if largest > 0 else 0.0
		value_labels[i].text = Hud.group_thousands(amounts[i])
		share_labels[i].text = "%d%%" % percents[i]
		(hero_lines[i] as HeroLine).opened = heroes[i].id == _opened
	_fight_label.text = _fight_text()
	# The side quests: the session's, a line for each hero who has done any.
	var shown: int = 0
	for hero: Hero in heroes:
		var count: int = tally.side_quests(hero.id)
		if count <= 0 or _span != Tally.Span.SESSION or shown >= _quest_labels.size():
			continue
		var noun: String = "side quest" if count == 1 else "side quests"
		_quest_labels[shown].text = "%s: %d %s" % [hero.def().display_name, count, noun]
		shown += 1
	for i: int in _quest_labels.size():
		_quest_labels[i].visible = i < shown
	_refresh_abilities()


## Shows the open hero's abilities under its line for the open tab, or hides them.
func _refresh_abilities() -> void:
	var heroes: Array[Hero] = _simulation.party.heroes
	var at: int = _index(_opened)
	for i: int in _ability_boxes.size():
		(_ability_boxes[i].get_parent() as Control).visible = i == at
	if at < 0:
		return
	# The caption and the note are kept in a box always (they are never orphaned), moved to the
	# open hero's.
	var box: VBoxContainer = _ability_boxes[at]
	if _caption.get_parent() != box:
		_caption.reparent(box)
		_note.reparent(box)
	box.move_child(_caption, 0)
	box.move_child(_note, 1)
	_caption.text = "%s by ability" % TAB_NAMES[_measure]
	_note.visible = _measure == Tally.Measure.TAKEN
	_note.text = TAKEN_NOTE
	var shown: Array[String] = []
	var amounts: Dictionary[String, int] = {}
	if not _note.visible:
		amounts = tally.by_ability(_opened, _measure, _span)
		shown = _ability_names(amounts)
	if shown.is_empty() and not _note.visible:
		_note.text = "None yet"
		_note.visible = true
	# The lines stay from frame to frame and are only filled in again; they are made afresh only
	# when how many there are, or whose they are, changes (so the window does not refit every
	# frame).
	var class_id: StringName = heroes[at].class_id
	var whose: String = "%s %s" % [box.get_instance_id(), class_id]
	if shown.size() != ability_lines.size() or whose != _lines_of:
		_make_ability_lines(box, shown.size(), class_id)
		_lines_of = whose
	var largest: int = 0
	for named: String in shown:
		largest = maxi(largest, amounts[named])
	for i: int in shown.size():
		var labels: Array[Node] = ability_lines[i].find_children("*", "Label", true, false)
		(labels[0] as Label).text = shown[i]
		(labels[1] as Label).text = Hud.group_thousands(amounts[shown[i]])
		var bar: UiBar = ability_lines[i].find_children("*", "UiBar", true, false)[0] as UiBar
		bar.fraction = float(amounts[shown[i]]) / largest if largest > 0 else 0.0


## The lines of [param amounts] in order, largest first: the first [constant BY_ABILITY_LINES]
## names, or one fewer and "Others" for the rest, whose amount is added to [param amounts].
func _ability_names(amounts: Dictionary[String, int]) -> Array[String]:
	var names: Array[String] = []
	names.assign(amounts.keys())
	if names.size() <= BY_ABILITY_LINES:
		return names
	var others: int = 0
	for i: int in range(BY_ABILITY_LINES - 1, names.size()):
		others += amounts[names[i]]
	names.resize(BY_ABILITY_LINES - 1)
	names.append("Others")
	amounts["Others"] = others
	return names


## Replaces the ability lines with [param count] new ones in [param box], with bars in the colours
## of [param class_id].
func _make_ability_lines(box: VBoxContainer, count: int, class_id: StringName) -> void:
	for line: Control in ability_lines:
		line.get_parent().remove_child(line)
		line.queue_free()
	ability_lines.clear()
	for i: int in count:
		var line: Control = _ability_line("", 0, 0.0, class_id)
		box.add_child(line)
		ability_lines.append(line)


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
	var tail: String = ", %s, %d s" % [_fight_place, seconds]
	var room: float = 2 * WIDTH - UiText.width(head + tail) - 40
	return head + monsters_text(room) + tail


func _index(hero_id: int) -> int:
	if _simulation == null or hero_id < 0:
		return -1
	var heroes: Array[Hero] = _simulation.party.heroes
	for i: int in mini(heroes.size(), _goals.size()):
		if heroes[i].id == hero_id:
			return i
	return -1


## A hero's line: a click opens or closes its abilities. It lights under the mouse and while open.
class HeroLine:
	extends PanelContainer

	## A left click.
	signal pressed

	## True while its abilities are open.
	var opened: bool = false:
		set(value):
			if opened != value:
				opened = value
				_restyle()

	var _hovered: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_restyle()

	func _gui_input(event: InputEvent) -> void:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		accept_event()
		pressed.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			_hovered = what == NOTIFICATION_MOUSE_ENTER
			_restyle()

	func _restyle() -> void:
		var fill: StringName = &"dusk" if _hovered or opened else &"night"
		var edge: StringName = &"steel" if opened else fill
		var box: StyleBoxFlat = UiTheme.box(fill, edge, 2, 2)
		add_theme_stylebox_override(&"panel", box)

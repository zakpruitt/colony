class_name RosterTab
extends VBoxContainer
## The Camp window's Heroes tab: who goes down, who waits at camp, and who could join.
##
## Two groups of hero cards ([RosterCard]), [code]Going down[/code] (the four, in formation
## order) and [code]At Camp[/code] (the bench, by id), two cards to a row; under them the line a
## choice of swap shows, then [code]Waiting at Camp[/code]: a card per class whose artifact was
## found, and a line telling how many heroes are still out there (or that every class has joined).
##
## A swap is two clicks: a card's [code]Swap[/code] lights it ([method chosen]), and a
## [code]Swap[/code] in the other group asks the simulation for the swap
## ([method Roster.swap]). The lit card's own button, any card of its own group, or
## [kbd]Esc[/kbd] with the Camp in front ([ShopWindow]) drops the choice and asks for nothing. A
## swap asked for marks both cards [code]At the next Camp[/code] until it is made or dropped. A
## click on a hero's picture opens its window ([method HeroWindows.open_hero]).
##
## The cards are made again the moment the colony changes (a find, a recruit, a swap), in the
## frame the event is heard in, open or not; their words are brought up to date only while the
## tab shows ([method refresh]), and only when what they are made from changed. A find heard fresh
## gets a banner, a recruit a burst of its card and a banner, a swap a burst of both cards; a stale
## event, or one heard while the world catches up, only moves the cards.

const GOING_WORDS: String = "Going down"
const BENCH_WORDS: String = "At Camp"
const WAITING_WORDS: String = "Waiting at Camp"
const EMPTY_WORDS: String = "No one at Camp. Recruit below."
const ALL_JOINED: String = "Every class has joined the colony."
## UI pixels: the gap between cards, and above each heading.
const CARD_GAP: int = 4
const SECTION_GAP: int = 6
## Hero cards to a row.
const COLUMNS: int = 2

## The hero cards going down (formation order) and at camp (id order), and the waiting classes'
## cards ([method Roster.waiting_at_camp] order).
var field_cards: Array[RosterCard] = []
var bench_cards: Array[RosterCard] = []
var recruit_cards: Array[RosterCard] = []
## Under the waiting cards: how many heroes are still out there, or that every class has joined;
## hidden while classes wait and none is hidden.
var hidden_line: Label
## Under the groups while a card is lit: whom to choose ("" while none is).
var choosing_line: Label
## In the At Camp group while no hero is benched.
var empty_line: Label
var going_heading: Label
var bench_heading: Label
var waiting_heading: Label
## Opens a hero's window from its picture; given by [UiRoot], null without one.
var hero_windows: HeroWindows
## Marks the colony's changes: bursts and banners. Given through [ShopWindow]; null for none.
var moment: UiMoment

var _simulation: Simulation
var _world: World
var _tip: UiTip
## UI pixels the tab is laid out across.
var _width: float = 0.0
var _going: GridContainer
var _bench: GridContainer
var _waiting: VBoxContainer
## The hero id of the lit card, or -1.
var _chosen: int = -1
## What the cards were last made from, and what their words were.
var _made_from: ShownValues = ShownValues.new()
var _worded_from: ShownValues = ShownValues.new()


func _init() -> void:
	name = "RosterTab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 2)


## Call once: the tab shows [param simulation]'s colony across [param width] UI pixels, and hears
## [param world]'s events (null: none).
func setup(simulation: Simulation, world: World, width: float) -> void:
	_simulation = simulation
	_world = world
	_width = width
	going_heading = _heading("GoingDown", GOING_WORDS, 0)
	_going = _grid("Going")
	bench_heading = _heading("AtCamp", BENCH_WORDS, SECTION_GAP)
	_bench = _grid("Bench")
	empty_line = WindowText.label("Empty", EMPTY_WORDS, &"steel")
	add_child(empty_line)
	choosing_line = WindowText.label("Choosing", "", &"yellow")
	choosing_line.custom_minimum_size.y = UiText.LINE_HEIGHT  # kept, so the tab never jumps
	add_child(choosing_line)
	waiting_heading = _heading("Waiting", WAITING_WORDS, SECTION_GAP)
	_waiting = VBoxContainer.new()
	_waiting.name = "Recruits"
	_waiting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting.add_theme_constant_override(&"separation", CARD_GAP)
	add_child(_waiting)
	hidden_line = WindowText.label("Hidden", "", &"steel")
	add_child(hidden_line)
	if world != null:
		world.sim_event.connect(_on_sim_event)
	_make_cards()


## Gives the cards their tooltips, and those made later too.
func add_tips(tips: UiTip) -> void:
	_tip = tips
	_tip_cards()


## Brings the cards and their words up to date with the simulation. Called every frame the tab
## shows; it words only what changed.
func refresh() -> void:
	if _simulation == null:
		return
	_follow_colony()
	_word()


## The hero id of the lit card, or -1.
func chosen() -> int:
	return _chosen


## Unlights the lit card, asking for nothing.
func drop_choice() -> void:
	_light(-1)


## Lays the tab out across [param width] UI pixels, making the cards again if that is new.
func fit_width(width: float) -> void:
	if absf(width - _width) < 0.5:
		return
	_width = width
	_make_cards()


## The line telling of [param count] classes whose artifacts are not found yet.
static func hidden_text(count: int) -> String:
	if count == 1:
		return "1 more hero is out there. Its artifact lies in caches down the side paths."
	return (
		"%d more heroes are out there. Their artifacts lie in caches down the side paths." % count
	)


## How many classes [param simulation]'s party can recruit now.
static func recruitable(simulation: Simulation) -> int:
	var count: int = 0
	for class_id: StringName in simulation.party.artifacts:
		if simulation.roster.can_recruit(class_id):
			count += 1
	return count


# --- Cards ---------------------------------------------------------------------


## Makes the cards again if who is in the colony, or who waits, changed; true if they were.
func _follow_colony() -> bool:
	var party: Party = _simulation.party
	_made_from.begin()
	for hero: Hero in party.heroes:
		_made_from.see(hero.id)
	_made_from.see(-1)
	for hero: Hero in party.bench:
		_made_from.see(hero.id)
	_made_from.see(-1)
	for class_id: StringName in party.artifacts:
		_made_from.see(_simulation.roster.is_waiting(class_id))
	_made_from.see(_simulation.roster.still_hidden())
	if not _made_from.changed():
		return false
	_make_cards()
	return true


func _make_cards() -> void:
	_chosen = -1
	for card: RosterCard in field_cards + bench_cards + recruit_cards:
		card.get_parent().remove_child(card)
		card.queue_free()
	field_cards.clear()
	bench_cards.clear()
	recruit_cards.clear()
	var hero_width: float = floorf((_width - CARD_GAP * (COLUMNS - 1)) / COLUMNS)
	var party: Party = _simulation.party
	for hero: Hero in party.heroes:
		field_cards.append(_hero_card(hero, false, hero_width, _going))
	for hero: Hero in party.bench:
		bench_cards.append(_hero_card(hero, true, hero_width, _bench))
	for class_id: StringName in _simulation.roster.waiting_at_camp():
		var card: RosterCard = RosterCard.for_recruit(class_id, _width)
		card.recruit_button.pressed.connect(_recruit.bind(class_id))
		_waiting.add_child(card)
		recruit_cards.append(card)
	empty_line.visible = bench_cards.is_empty()
	_bench.visible = not bench_cards.is_empty()
	_waiting.visible = not recruit_cards.is_empty()
	var unfound: int = _simulation.roster.still_hidden()
	if unfound > 0:
		var lines: Array[String] = WindowText.wrap(hidden_text(unfound), _width)
		WindowText.set_text(hidden_line, "\n".join(PackedStringArray(lines)))
	else:
		WindowText.set_text(hidden_line, ALL_JOINED)
	hidden_line.visible = unfound > 0 or recruit_cards.is_empty()
	_worded_from = ShownValues.new()
	_tip_cards()
	_word()


func _hero_card(hero: Hero, at_camp: bool, width: float, group: Control) -> RosterCard:
	var card: RosterCard = RosterCard.for_hero(hero, at_camp, width)
	card.swap_button.pressed.connect(_on_swap.bind(card))
	card.picture.pressed.connect(_open_window.bind(hero.id))
	card.pressed.connect(_on_card_pressed.bind(card))
	group.add_child(card)
	return card


func _tip_cards() -> void:
	if _tip == null:
		return
	for card: RosterCard in field_cards + bench_cards:
		var id: int = card.hero_id
		_tip.attach(card, func() -> String: return _hero_tip(id))
	for card: RosterCard in recruit_cards:
		var class_id: StringName = card.class_id
		_tip.attach(card.recruit_button, func() -> String: return _recruit_tip(class_id))


func _hero_tip(hero_id: int) -> String:
	var hero: Hero = _simulation.party.hero(hero_id)
	return RosterCard.tip_text(hero) if hero != null else ""


func _recruit_tip(class_id: StringName) -> String:
	var def: HeroClassDef = Content.hero_class(class_id)
	if def == null:
		return ""
	var short: String = RosterCard.short_text(def, _simulation.roster.lacks(class_id))
	if not short.is_empty():
		return short
	return "%s: the %s joins the colony at Camp." % [RosterCard.request_text(def), def.display_name]


## Words every card and the choosing line, when what they are made from changed.
func _word() -> void:
	var party: Party = _simulation.party
	var roster: Roster = _simulation.roster
	_worded_from.begin()
	for card: RosterCard in field_cards:
		_see_hero(party.hero(card.hero_id))
	for card: RosterCard in bench_cards:
		_see_hero(party.hero(card.hero_id))
	_worded_from.see(_chosen)
	for card: RosterCard in recruit_cards:
		_worded_from.see(roster.can_recruit(card.class_id))
	_worded_from.see(roster.recruit_level())
	if not _worded_from.changed():
		return
	for card: RosterCard in field_cards:
		_show_hero(card)
	for card: RosterCard in bench_cards:
		_show_hero(card)
	var level: int = roster.recruit_level()
	for card: RosterCard in recruit_cards:
		card.show_recruit(level, roster.can_recruit(card.class_id))
	WindowText.set_text(choosing_line, _choosing_text())


func _see_hero(hero: Hero) -> void:
	_worded_from.see(hero.level if hero != null else 0)
	_worded_from.see(hero.talents_changed if hero != null else 0)
	_worded_from.see(hero.talent_points() if hero != null else 0)
	_worded_from.see(_simulation.roster.swap_waits(hero.id) if hero != null else false)


func _show_hero(card: RosterCard) -> void:
	var hero: Hero = _simulation.party.hero(card.hero_id)
	if hero != null:
		card.show_hero(hero, _simulation.roster.swap_waits(hero.id))
	card.lit = card.hero_id == _chosen


func _choosing_text() -> String:
	var lit: RosterCard = _card_of(_chosen)
	if lit == null:
		return ""
	var named: String = Content.hero_class(lit.class_id).display_name
	if lit.benched:
		return "Choose who the %s replaces" % named
	return "Choose who replaces the %s" % named


func _card_of(hero_id: int) -> RosterCard:
	if hero_id < 0:
		return null
	for card: RosterCard in field_cards:
		if card.hero_id == hero_id:
			return card
	for card: RosterCard in bench_cards:
		if card.hero_id == hero_id:
			return card
	return null


# --- Clicks --------------------------------------------------------------------


## A Swap: lights [param card], drops the choice, or asks for the swap.
func _on_swap(card: RosterCard) -> void:
	var lit: RosterCard = _card_of(_chosen)
	if lit == null:
		_light(card.hero_id)
		return
	if card == lit or card.benched == lit.benched:
		_light(-1)
		return
	var coming: RosterCard = card if card.benched else lit
	var leaving: RosterCard = lit if card.benched else card
	_simulation.roster.swap(coming.hero_id, leaving.hero_id)
	_light(-1)


## A click on [param card] itself drops a choice made in its own group.
func _on_card_pressed(card: RosterCard) -> void:
	var lit: RosterCard = _card_of(_chosen)
	if lit != null and lit.benched == card.benched:
		_light(-1)


func _light(hero_id: int) -> void:
	_chosen = hero_id
	_word()


func _open_window(hero_id: int) -> void:
	if hero_windows != null:
		hero_windows.open_hero(hero_id)


func _recruit(class_id: StringName) -> void:
	if _simulation.roster.can_recruit(class_id):
		_simulation.roster.recruit(class_id)


# --- Moments -------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.ARTIFACT_FOUND, SimEvent.Kind.HERO_RECRUITED, SimEvent.Kind.HERO_FIELDED:
			pass
		_:
			return
	_follow_colony()
	_word()
	if moment == null or (_world != null and not _world.may_animate(event)):
		return  # a stale change: the cards simply show the truth
	var ids: Array[StringName] = Content.hero_class_ids()
	match event.kind:
		SimEvent.Kind.ARTIFACT_FOUND:
			if event.target_id < 0 or event.target_id >= ids.size():
				return
			var def: HeroClassDef = Content.hero_class(ids[event.target_id])
			moment.announce_picture(
				RosterCard.artifact_of(def),
				"Found a %s" % def.artifact_name,
				"A %s waits at Camp" % def.display_name,
				event
			)
		SimEvent.Kind.HERO_RECRUITED:
			var hero: Hero = _simulation.party.hero(event.source_id)
			if hero == null:
				return
			_burst(_card_of(hero.id), event)
			moment.announce_picture(
				RosterCard.portrait(hero.def()),
				"The %s joins the colony" % hero.def().display_name,
				"",
				event
			)
		SimEvent.Kind.HERO_FIELDED:
			_burst(_card_of(event.source_id), event)
			_burst(_card_of(event.target_id), event)


func _burst(card: RosterCard, event: SimEvent) -> void:
	if card != null and card.is_visible_in_tree():
		moment.burst(card, event)


# --- Building ------------------------------------------------------------------


func _heading(heading_name: String, text: String, gap: int) -> Label:
	if gap > 0:
		var space := Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.custom_minimum_size.y = gap
		add_child(space)
	var made: Label = WindowText.label(heading_name, text, &"steel", true)
	add_child(made)
	return made


func _grid(grid_name: String) -> GridContainer:
	var made := GridContainer.new()
	made.name = grid_name
	made.columns = COLUMNS
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_constant_override(&"h_separation", CARD_GAP)
	made.add_theme_constant_override(&"v_separation", CARD_GAP)
	add_child(made)
	return made

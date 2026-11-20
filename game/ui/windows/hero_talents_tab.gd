class_name HeroTalentsTab
extends Control
## A hero window's Talents tab: the hero's talent tree as a [TalentTreeView], the strip at its foot
## that shows one node in full ([NextStrip]), and the paragon medallions ([ParagonCell]) once the
## hero has paragon points or ranks.
##
## From the top: the unspent talent points in large letters ([code]2 points to spend[/code]), or the
## level that brings the next ([code]Next point at level 6[/code]), with the [code]Reset[/code]
## button at the right (its price on it, and why it cannot be used beside it when it cannot); while
## a question is asked (before a path is chosen, before a reset) it takes the place of the points
## and the button, with its two answers, and the question before a path hangs that path's banner and
## its four pictures under it ([member question_card]). The top row is its own control
## ([member top_row]): a hero window stands it above the part that scrolls, so the question and its
## answers show however far the tree is scrolled.
##
## Pointing at a node shows its card ([method UiTip.attach_card]): picture, name, kind,
## the whole description and how it stands in words ([method standing]). A click on a node that can
## be taken takes it ([method Simulation.take_talent]), as does the strip's [code]Learn[/code]; the
## first node of a path asks first, and only [code]Choose[/code] sends the command. A reset asks
## first, at its price, and the question goes when the price changes, a fight starts or the tab is
## hidden, so a reset is never charged at a price the player did not read. Every value is read from
## the simulation at a [method refresh] after anything it reads changed, so nothing goes stale
## across level-ups, commands or a crowded frame, and a still tab formats nothing.

## What the top row is asking, if anything.
enum Asking { NOTHING, PATH, RESET }

## The top row's height: the points in letters twice the UI font's size.
const TOP_HEIGHT: float = UiText.LINE_HEIGHT * 2.0
## The points' letters, as a multiple of the UI font's size.
const POINTS_SCALE: int = 2
## UI pixels between the top row and the tree, the tree and the strip, the strip and the paragon
## medallions.
const TREE_GAP: float = 0.0
const STRIP_GAP: float = 3.0
const PARAGON_GAP: float = 9.0
## UI pixels between two things on a row, and between two medallions.
const ROW_GAP: float = 8.0
const PARAGON_CELL_GAP: float = 8.0
## How far down the tree starts: the top row and the gap under it.
const ROW_HEIGHT: float = TOP_HEIGHT + TREE_GAP
## Where a line of words stands in the top row: in its middle.
const LINE_Y: float = floorf((TOP_HEIGHT - UiText.LINE_HEIGHT) / 2.0)
## The question card's padding, and the gap between its pictures.
const CARD_PAD: float = 4.0
const CARD_ICON_GAP: float = 6.0

## The tree shown: the hero's class's.
var tree: TalentTreeView
## The strip at the foot of the tree.
var strip: NextStrip
## The top row (the points and the reset, or the question and its answers), at the tab's top until
## a hero window moves it above what scrolls.
var top_row: Control
## The line of unspent talent points, or the level of the next, in large letters.
var points_label: Label
## The fresh start's button, its price on it, and why it cannot be used.
var reset_button: UiButton
var reset_reason_label: Label
## The question asked, its path names in their colours, and its two answers.
var ask_label: Label
var ask_tint: WordTint
var choose_button: UiButton
var not_yet_button: UiButton
## Under the question before a path: the path's banner and its four pictures.
var question_card: Control
var question_banner: PathBanner
var question_icons: Array[UiIcon] = []
## The paragon points waiting ([code]3 paragon points[/code], or when they come), and one
## medallion per stat.
var paragon_label: Label
var paragon_cells: Array[ParagonCell] = []
## How many times the tab has worded what it shows from the hero, ever: a frame where nothing it
## reads changed adds nothing.
var worded: int = 0

var _simulation: Simulation
var _hero_id: int = -1
var _asking: Asking = Asking.NOTHING
## The node a path question is about.
var _asked_node: StringName = &""
## The price a reset question named: if it changes, the question goes.
var _asked_price: int = 0
var _width: float = 0.0
var _paragon_y: float = 0.0
var _base_height: float = 0.0
var _middle: float = 0.0
var _tip: UiTip
## Each path's banner and pictures for the question before it.
var _question_banners: Array[PathBanner] = []
var _question_pictures: Array[Array] = [[], []]
## What the tab last worded itself from.
var _read_from: ShownValues = ShownValues.new()


## The tab of hero [param hero_id], [param width] UI pixels wide; [param tip] gives its controls
## their tooltips and its nodes their cards (may be null).
func _init(simulation: Simulation, hero_id: int, width: float, tip: UiTip) -> void:
	name = "TalentsPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_simulation = simulation
	_hero_id = hero_id
	_width = width
	_middle = floorf((TOP_HEIGHT - UiTheme.BUTTON_HEIGHT) / 2.0)
	_build_top_row()
	var hero: Hero = _hero()
	var tree_def: TalentTreeDef = Content.talent_tree(hero.class_id) if hero != null else null
	var top: float = ROW_HEIGHT
	if tree_def != null:
		tree = TalentTreeView.new(tree_def, width)
		tree.position = Vector2(0, top)
		for each: TalentNode in tree.nodes():
			each.clicked.connect(press_node)
		add_child(tree)
		top += tree.size.y
		_build_question(tree_def)
	var ids: Array[StringName] = []
	if tree != null:
		for each: TalentNode in tree.nodes():
			ids.append(each.ability_id)
	strip = NextStrip.new(width, ids)
	strip.position = Vector2(0, top + STRIP_GAP)
	strip.learn_button.pressed.connect(press_learn)
	add_child(strip)
	_base_height = strip.position.y + strip.size.y
	_paragon_y = _base_height + PARAGON_GAP
	paragon_label = WindowText.label("Paragon", "", &"steel")
	paragon_label.mouse_filter = Control.MOUSE_FILTER_PASS
	paragon_label.position = Vector2(
		0, _paragon_y + floorf((TalentNode.SLOT.y - UiText.LINE_HEIGHT) / 2.0)
	)
	add_child(paragon_label)
	var stats: Array[StringName] = Content.training_ids()
	for i: int in stats.size():
		var cell := ParagonCell.new(stats[i], i)
		cell.position = Vector2(0, _paragon_y)
		cell.medallion.clicked.connect(spend_paragon.bind(i))
		add_child(cell)
		paragon_cells.append(cell)
	size = Vector2(width, _base_height)
	custom_minimum_size = size
	_tip = tip
	if tip != null:
		add_tips(tip)


func _draw() -> void:
	if paragon_label.visible:
		var line_y: float = _paragon_y - ceilf(PARAGON_GAP / 2.0)
		draw_rect(Rect2(0, line_y, _width, 1), Palette.color(&"dusk"))


func _notification(what: int) -> void:
	# The tab or its window was hidden: a question asked on it is forgotten, never answered later
	# at a price or a choice the player cannot see.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_asking = Asking.NOTHING
		if question_card != null:
			question_card.visible = false


## The tab's height without the paragon medallions: the top row, the tree and the strip. A hero
## window is made this tall; once medallions show, the tab scrolls in a room too short for them.
func base_height() -> float:
	return _base_height


## Brings everything up to date with the hero, when anything it reads changed, and runs the
## pulses and flashes on by [param delta] seconds. The window calls it on every advance.
func refresh(delta: float) -> void:
	var hero: Hero = _hero()
	if hero == null or tree == null:
		return
	if _hero_changed(hero):
		worded += 1
		tree.show_hero(hero)
		if _asking == Asking.PATH and tree.state_of(_asked_node) != TalentNode.State.AVAILABLE:
			_asking = Asking.NOTHING  # the node was taken, or cannot be: nothing to ask
		if _asking == Asking.RESET:
			if not reset_reason(hero).is_empty() or Simulation.reset_price(hero) != _asked_price:
				_asking = Asking.NOTHING  # in a fight, too poor, or the price is not the one asked
		if not is_visible_in_tree():
			_asking = Asking.NOTHING
		_refresh_top(hero)
		_refresh_strip(hero)
		_refresh_paragon(hero)
	tree.advance(delta)
	strip.advance(delta)
	for cell: ParagonCell in paragon_cells:
		cell.advance(delta)


## What a click on node [param ability_id] does: one the hero can take now is taken, except the
## first node of a path, which asks first; any other does nothing (its card says why).
func press_node(ability_id: StringName) -> void:
	var hero: Hero = _hero()
	if hero == null or tree == null or not tree.has_ability(ability_id) or not is_visible_in_tree():
		return
	tree.refresh(hero, 0.0)  # what the simulation says now, not at the last frame
	_asking = Asking.NOTHING
	if tree.state_of(ability_id) == TalentNode.State.AVAILABLE:
		if tree.node(ability_id).path >= 0 and hero.path() < 0:
			_asking = Asking.PATH
			_asked_node = ability_id
		else:
			_simulation.take_talent(hero.id, ability_id)
	refresh(0.0)


## The strip's [code]Learn[/code]: as a click on the node it shows.
func press_learn() -> void:
	if strip.ability_id != &"":
		press_node(strip.ability_id)


## The question's [code]Choose[/code] (or [code]Reset[/code]) answer: sends the command asked
## about.
func confirm() -> void:
	var hero: Hero = _hero()
	if hero == null or not is_visible_in_tree():
		_asking = Asking.NOTHING
		return
	match _asking:
		Asking.PATH:
			_simulation.take_talent(hero.id, _asked_node)
		Asking.RESET:
			if Simulation.reset_price(hero) == _asked_price and reset_reason(hero).is_empty():
				_simulation.reset_talents(hero.id)
	_asking = Asking.NOTHING
	refresh(0.0)


## The question's [code]Not yet[/code] answer: nothing is sent.
func cancel() -> void:
	_asking = Asking.NOTHING
	refresh(0.0)


## The Reset button: asks before a fresh start, if one can be had now.
func press_reset() -> void:
	var hero: Hero = _hero()
	if hero == null or not is_visible_in_tree() or not reset_reason(hero).is_empty():
		return
	_asking = Asking.RESET
	_asked_price = Simulation.reset_price(hero)
	refresh(0.0)


## Puts one of the hero's paragon points into the stat of cell [param index] (0-based), if it has
## one and the tab shows. A click on the medallion and the number keys call it.
func spend_paragon(index: int) -> void:
	var hero: Hero = _hero()
	if hero == null or index < 0 or index >= paragon_cells.size():
		return
	# A press reaching a cell while the tab is hidden does nothing.
	if hero.paragon_points() <= 0 or not is_visible_in_tree():
		return
	_simulation.spend_paragon(hero.id, Content.training(paragon_cells[index].id).stat)


## Starts the flash of the cell of stat position [param index] (a point just went in).
func flash_paragon(index: int) -> void:
	if index >= 0 and index < paragon_cells.size():
		paragon_cells[index].start_flash()


## What the top row is asking.
func asking() -> Asking:
	return _asking


## The node of [param ability_id], or null.
func node(ability_id: StringName) -> TalentNode:
	return tree.node(ability_id) if tree != null else null


## The tree's view.
func tree_view() -> TalentTreeView:
	return tree


## Why the hero cannot have a fresh start now ([code]Nothing to reset[/code],
## [code]In a fight[/code], [code]Not enough gold[/code]), or "" when it can.
func reset_reason(hero: Hero) -> String:
	if hero.talents().is_empty():
		return "Nothing to reset"
	if _simulation.expedition.battle != null:
		return "In a fight"
	if _simulation.party.gold < Simulation.reset_price(hero):
		return "Not enough gold"
	return ""


## Why [param hero] cannot take node [param ability_id] now, or "" when it can (or has).
static func reason(hero: Hero, ability_id: StringName) -> String:
	var tree_def: TalentTreeDef = Content.talent_tree(hero.class_id)
	if tree_def == null or not tree_def.has_node(ability_id):
		return ""
	var taken: Array[StringName] = hero.talents()
	if taken.has(ability_id) or hero.can_take(ability_id):
		return ""
	var on: int = tree_def.path_of(ability_id)
	if on >= 0 and hero.path() >= 0 and hero.path() != on:
		return "The %s path is closed" % tree_def.path_names[on]
	var missing: StringName = _missing_before(hero, tree_def, ability_id)
	if missing != &"":
		return "Take %s first" % Content.ability(missing).display_name
	# Next in order, and not open to it: the only thing missing is a point.
	return "No talent point"


## How node [param ability_id] stands for [param hero], in words:
## [code]Learned[/code], [code]Click to learn[/code], [code]Take Whirlwind first[/code],
## [code]No points: the next comes at level 9[/code] or [code]Guardian was not chosen[/code].
static func standing(hero: Hero, ability_id: StringName) -> String:
	var tree_def: TalentTreeDef = Content.talent_tree(hero.class_id)
	if tree_def == null or not tree_def.has_node(ability_id):
		return ""
	if hero.talents().has(ability_id):
		return "Learned"
	var on: int = tree_def.path_of(ability_id)
	if on >= 0 and hero.path() >= 0 and hero.path() != on:
		return "%s was not chosen" % tree_def.path_names[on]
	if hero.can_take(ability_id):
		return "Click to learn"
	if _missing_before(hero, tree_def, ability_id) != &"":
		# The node just before it, the one that opens it.
		var before: Array[StringName] = tree_def.trunk.duplicate()
		if on >= 0:
			var path: Array[StringName] = tree_def.path_nodes(on)
			before.append_array(path.slice(0, path.find(ability_id)))
		else:
			before = before.slice(0, tree_def.trunk.find(ability_id))
		var opener: StringName = before.back()
		return "Take %s first" % Content.ability(opener).display_name
	var earned: int = TalentRules.talent_points_at(hero.level)
	if earned >= Hero.TALENT_POINTS:
		return "No points left"
	return "No points: the next comes at level %d" % ((earned + 1) * Hero.TALENT_EVERY)


## The palette colour [method standing] is shown in for [param hero]'s node [param ability_id]: the
## closed path's own colour when it names it.
static func standing_colour(hero: Hero, ability_id: StringName) -> StringName:
	var tree_def: TalentTreeDef = Content.talent_tree(hero.class_id)
	if tree_def == null:
		return &"silver"
	var on: int = tree_def.path_of(ability_id)
	if hero.talents().has(ability_id):
		return &"green"
	if on >= 0 and hero.path() >= 0 and hero.path() != on:
		return PathColours.of(hero.class_id, on)
	if hero.can_take(ability_id):
		return &"yellow"
	return &"steel"


## Ability [param ability_id]'s kind in words: [code]Action, every 8 s[/code] or
## [code]Passive[/code].
static func kind_text(ability_id: StringName) -> String:
	var ability: AbilityDef = Content.ability(ability_id)
	if ability == null:
		return ""
	if ability.is_action():
		return "Action, every %s s" % HeroWindow.tiles(ability.cooldown)
	return "Passive"


## The name of the path [param hero] walks, or "" before it chooses one.
static func path_name(hero: Hero) -> String:
	var tree_def: TalentTreeDef = Content.talent_tree(hero.class_id)
	var on: int = hero.path()
	if tree_def == null or on < 0 or on >= tree_def.path_names.size():
		return ""
	return tree_def.path_names[on]


## [param hero]'s class, and its path once chosen ([code]Knight, Berserker[/code]).
static func title(hero: Hero) -> String:
	var walked: String = path_name(hero)
	var name_text: String = hero.def().display_name
	return name_text if walked.is_empty() else "%s, %s" % [name_text, walked]


## Gives every control of the tab its tooltip, one plain sentence each, and every node its card.
func add_tips(tip: UiTip) -> void:
	if tree != null:
		for each: TalentNode in tree.nodes():
			tip.attach_card(each.slot, _card.bind(each.ability_id))
		for i: int in tree.banners.size():
			var text: String = (
				"The %s path: a hero walks one path, and the other closes."
				% tree.tree.path_names[i]
			)
			tip.attach(tree.banners[i], text)
			tip.attach(tree.path_labels[i], text)
	tip.attach(reset_button, "A fresh start gives every talent point back, for gold.")
	tip.attach(choose_button, "Send it: no going back without a reset.")
	tip.attach(not_yet_button, "Keep both choices open for now.")
	tip.attach(strip.learn_button, "Learn it now.")
	tip.attach(points_label, "Talent points come with every second level: spend them here.")
	tip.attach(paragon_label, "Paragon points come with every level once the tree is earned.")
	for cell: ParagonCell in paragon_cells:
		var def: TrainingDef = Content.training(cell.id)
		var text: String = (
			"Put a paragon point into %s: %s."
			% [def.display_name, UiFormat.lower_first(def.description)]
		)
		for control: Control in [cell.medallion, cell.name_label, cell.total_label]:
			tip.attach(control, text)


# --- Reading and showing -------------------------------------------------------


func _hero() -> Hero:
	return _simulation.party.hero(_hero_id) if _simulation != null else null


## True when anything the tab words itself from has changed since it last did: the hero's level,
## points, path and ranks, the gold and a fight (a reset's price and reason), the question asked,
## the node under the mouse and whether the tab shows.
func _hero_changed(hero: Hero) -> bool:
	_read_from.begin()
	_read_from.see(hero.level)
	_read_from.see(hero.talent_points())
	_read_from.see(hero.path())
	_read_from.see(hero.paragon_points())
	for cell: ParagonCell in paragon_cells:
		_read_from.see(hero.paragon_rank(Content.training(cell.id).stat))
	_read_from.see(_simulation.party.gold)
	_read_from.see(_simulation.expedition.battle != null)
	_read_from.see(_asking)
	_read_from.see(_asked_node)
	_read_from.see(_asked_price)
	_read_from.see(tree.hovered())
	_read_from.see(is_visible_in_tree())
	return _read_from.changed()


## The first node before [param ability_id] in its order that [param hero] has not taken, or &"".
static func _missing_before(
	hero: Hero, tree_def: TalentTreeDef, ability_id: StringName
) -> StringName:
	var on: int = tree_def.path_of(ability_id)
	var before: Array[StringName] = tree_def.trunk.duplicate()
	if on >= 0:
		before.append_array(
			tree_def.path_nodes(on).slice(0, tree_def.path_nodes(on).find(ability_id))
		)
	else:
		before = before.slice(0, tree_def.trunk.find(ability_id))
	for earlier: StringName in before:
		if not hero.talents().has(earlier):
			return earlier
	return &""


## Node [param ability_id]'s card: its picture, name, kind, description and standing.
func _card(ability_id: StringName) -> UiTip.Card:
	var made := UiTip.Card.new()
	var ability: AbilityDef = Content.ability(ability_id)
	var hero: Hero = _hero()
	if ability == null or hero == null:
		return null
	made.picture_id = ability_id
	made.title = ability.display_name
	made.kind = kind_text(ability_id)
	made.body = ability.description
	made.stand = standing(hero, ability_id)
	made.stand_colour = standing_colour(hero, ability_id)
	return made


func _build_top_row() -> void:
	top_row = Control.new()
	top_row.name = "TopRow"
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.size = Vector2(_width, TOP_HEIGHT)
	add_child(top_row)
	points_label = WindowText.label("Points", "", &"yellow", true)
	points_label.add_theme_font_size_override(&"font_size", UiText.SIZE * POINTS_SCALE)
	points_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top_row.add_child(points_label)
	reset_button = WindowText.button("Reset", "Reset")
	reset_button.pressed.connect(press_reset)
	top_row.add_child(reset_button)
	reset_reason_label = _label("ResetReason", &"slate", top_row)
	ask_label = _label("Ask", &"yellow", top_row)
	ask_tint = WordTint.over(ask_label)
	choose_button = WindowText.button("Choose", "Choose")
	choose_button.pressed.connect(confirm)
	top_row.add_child(choose_button)
	not_yet_button = WindowText.button("NotYet", "Not yet")
	not_yet_button.pressed.connect(cancel)
	top_row.add_child(not_yet_button)


## The card under the question before a path: the path's banner and its four pictures, one set per
## path, the one asked about shown.
func _build_question(tree_def: TalentTreeDef) -> void:
	question_card = Control.new()
	question_card.name = "QuestionCard"
	question_card.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing under it takes a click
	question_card.visible = false
	question_card.draw.connect(_draw_question_card)
	top_row.add_child(question_card)
	var inner: float = TalentTreeView.BANNER_WIDTH
	var tall: float = 0.0
	for index: int in 2:
		var banner := PathBanner.new(tree_def, index, inner)
		banner.position = Vector2(CARD_PAD, CARD_PAD)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		question_card.add_child(banner)
		_question_banners.append(banner)
		var y: float = CARD_PAD + banner.size.y + CARD_PAD
		var x: float = CARD_PAD
		for id: StringName in tree_def.path_nodes(index):
			var ability: AbilityDef = Content.ability(id)
			var action: bool = ability != null and ability.is_action()
			var icon := UiIcon.new(id, true, UiIcon.Shape.SQUARE if action else UiIcon.Shape.CUT)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.show_state(
				UiIcon.State.READY if id == tree_def.path_nodes(index)[0] else UiIcon.State.LOCKED
			)
			icon.position = Vector2(x, y)
			question_card.add_child(icon)
			_question_pictures[index].append(icon)
			x += icon.size.x + CARD_ICON_GAP
		tall = maxf(tall, y + TalentNode.SLOT.y + CARD_PAD)
	question_card.size = Vector2(inner + CARD_PAD * 2.0, tall)


func _draw_question_card() -> void:
	var box := Rect2(Vector2.ZERO, question_card.size)
	var on: int = question_banner.index if question_banner != null else 0
	question_card.draw_rect(box, Palette.color(PathColours.of(tree.tree.class_id, on)))
	question_card.draw_rect(box.grow(-1.0), Palette.color(&"ink"))


## The top row: the points and the reset, or the question and its answers.
func _refresh_top(hero: Hero) -> void:
	var points: int = hero.talent_points()
	var text: String = "%d point%s to spend" % [points, "" if points == 1 else "s"]
	var colour: StringName = &"yellow"
	if points == 0:
		colour = &"steel"
		var earned: int = TalentRules.talent_points_at(hero.level)
		if earned >= Hero.TALENT_POINTS:
			text = "The tree is full"
		else:
			text = "Next point at level %d" % ((earned + 1) * Hero.TALENT_EVERY)
	if points_label.text != text:
		points_label.text = text
	points_label.size = Vector2(
		UiText.width(text, true) * POINTS_SCALE, UiText.LINE_HEIGHT * POINTS_SCALE
	)
	WindowText.set_colour(points_label, colour)
	var price: String = "Reset %s" % UiFormat.group_thousands(Simulation.reset_price(hero))
	if reset_button.text != price:
		reset_button.text = price
		WindowText.fit_button(reset_button)
	var why: String = reset_reason(hero)
	reset_button.disabled = not why.is_empty()
	_show(reset_reason_label, why, &"slate")
	var asking_now: bool = _asking != Asking.NOTHING
	for control: Control in [ask_label, choose_button, not_yet_button]:
		control.visible = asking_now
	for control: Control in [reset_button, reset_reason_label, points_label]:
		control.visible = not asking_now
	reset_button.position = Vector2(_width - reset_button.size.x, _middle)
	reset_reason_label.position = Vector2(
		reset_button.position.x - ROW_GAP - reset_reason_label.size.x, LINE_Y
	)
	question_card.visible = asking_now and _asking == Asking.PATH
	if not asking_now:
		return
	var question: String = ""
	var tree_def: TalentTreeDef = tree.tree
	var tints: Dictionary[String, StringName] = {}
	if _asking == Asking.PATH:
		var on: int = tree.node(_asked_node).path
		question = (
			"Choose %s? This closes %s." % [tree_def.path_names[on], tree_def.path_names[1 - on]]
		)
		choose_button.text = "Choose"
		for index: int in 2:
			tints[tree_def.path_names[index]] = tree.path_colour(index)
		_show_question_card(on)
	else:
		var gold: String = UiFormat.group_thousands(Simulation.reset_price(hero))
		question = "Reset the %s's tree for %s gold?" % [hero.def().display_name, gold]
		choose_button.text = "Reset"
	WindowText.fit_button(choose_button)
	_show(ask_label, question, &"yellow")
	ask_tint.show_words(tints)
	not_yet_button.position = Vector2(_width - not_yet_button.size.x, _middle)
	choose_button.position = Vector2(
		not_yet_button.position.x - ROW_GAP - choose_button.size.x, _middle
	)
	ask_label.position = Vector2(choose_button.position.x - ROW_GAP - ask_label.size.x, LINE_Y)


## Shows path [param on]'s banner and pictures under the question, on that path's side.
func _show_question_card(on: int) -> void:
	question_banner = _question_banners[on]
	question_icons.assign(_question_pictures[on])
	for index: int in 2:
		_question_banners[index].visible = index == on
		for icon: UiIcon in _question_pictures[index]:
			icon.visible = index == on
	var x: float = 0.0 if on == 0 else _width - question_card.size.x
	question_card.position = Vector2(x, ROW_HEIGHT)
	question_card.queue_redraw()


## The strip: the node under the mouse; with none, the first the hero can take now; with none of
## those, the first not yet taken on the hero's way.
func _refresh_strip(hero: Hero) -> void:
	var shown: StringName = tree.hovered()
	if shown == &"":
		for each: TalentNode in tree.nodes():
			if hero.can_take(each.ability_id):
				shown = each.ability_id
				break
	if shown == &"":
		shown = _next_on_the_way(hero)
	var showing: TalentNode = tree.node(shown)
	strip.show_node(
		shown,
		standing(hero, shown),
		standing_colour(hero, shown),
		showing.slot.state() if showing != null else UiIcon.State.LOCKED,
		hero.can_take(shown) and is_visible_in_tree()
	)


## The first node [param hero] has not taken on its way through the tree (the trunk, then its path,
## or the first path before it chooses), or the last it took when the tree is full.
func _next_on_the_way(hero: Hero) -> StringName:
	var tree_def: TalentTreeDef = tree.tree
	var way: Array[StringName] = tree_def.trunk.duplicate()
	way.append_array(tree_def.path_nodes(maxi(hero.path(), 0)))
	for id: StringName in way:
		if not hero.talents().has(id):
			return id
	return way[way.size() - 1] if not way.is_empty() else &""


func _refresh_paragon(hero: Hero) -> void:
	var earned_all: bool = TalentRules.talent_points_at(hero.level) >= Hero.TALENT_POINTS
	var text: String = (
		"Paragon points come after level %d" % (Hero.TALENT_POINTS * Hero.TALENT_EVERY)
	)
	var colour: StringName = &"steel"
	var ranks: int = 0
	for cell: ParagonCell in paragon_cells:
		ranks += hero.paragon_rank(Content.training(cell.id).stat)
	if earned_all:
		var points: int = hero.paragon_points()
		text = "%d paragon point%s" % [points, "" if points == 1 else "s"]
		colour = &"yellow" if points > 0 else &"steel"
	_show(paragon_label, text, colour)
	var shown: bool = hero.paragon_points() > 0 or ranks > 0
	paragon_label.visible = shown
	var x: float = paragon_label.size.x + PARAGON_CELL_GAP * 2.0
	for cell: ParagonCell in paragon_cells:
		cell.visible = shown
		cell.show_hero(hero)
		cell.position.x = x
		x += cell.size.x + PARAGON_CELL_GAP
	var tall: float = _base_height
	if shown:
		tall = _paragon_y + paragon_cells[0].size.y if not paragon_cells.is_empty() else _paragon_y
	if size.y != tall:
		size = Vector2(_width, tall)
		custom_minimum_size = size
		queue_redraw()


func _label(label_name: String, colour: StringName, parent: Control) -> Label:
	var made: Label = WindowText.label(label_name, "", colour)
	parent.add_child(made)
	return made


func _show(label: Label, text: String, colour: StringName) -> void:
	WindowText.set_text(label, text)
	WindowText.set_colour(label, colour)

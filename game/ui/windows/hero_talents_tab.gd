class_name HeroTalentsTab
extends Control
## A hero window's Talents tab (spec 055, on the UI layer and readable without pointing by spec
## 060): the hero's whole talent tree, every node with its picture, name, kind and description
## ([TalentTreeView]), and its paragon points.
##
## From the top: the unspent talent points ([code]2 talent points[/code]), or the level that brings
## the next ([code]Next point at level 6[/code]), with the [code]Reset[/code] button at the right
## (its price on it, and why it cannot be used beside it when it cannot); while a question is asked
## (before a path is chosen, before a reset) it takes the place of the button, with its two answers.
## Then the tree, and under it the paragon points: the caption and a [ParagonCell] per stat. The
## top row is its own control ([member top_row]): a hero window stands it above the part that
## scrolls, so the question and its answers show however far the tree is scrolled.
##
## A click on a node that can be taken takes it ([method Simulation.take_talent]); the first node
## of a path asks first, and only [code]Choose[/code] sends the command. A reset asks first, at its
## price, and the question goes when the price changes, a fight starts or the tab is hidden, so a
## reset is never charged at a price the player did not read. Every value is read from the
## simulation at each [method refresh], so nothing goes stale across level-ups, commands or a
## crowded frame.

## What the top row is asking, if anything.
enum Asking { NOTHING, PATH, RESET }

## UI pixels between the top row and the tree, and between the tree and the paragon row.
const TREE_GAP: float = 8.0
const PARAGON_GAP: float = 9.0
## UI pixels between two things on a row.
const ROW_GAP: float = 8.0
const PARAGON_CELL_GAP: float = 12.0
## How far down the tree starts: the top row and the gap under it.
const ROW_HEIGHT: float = UiTheme.BUTTON_HEIGHT + TREE_GAP

## The tree shown: the hero's class's.
var tree: TalentTreeView
## The top row (the points and the reset, or the question and its answers), at the tab's top until
## a hero window moves it above what scrolls.
var top_row: Control
## The line of unspent talent points, or the level of the next.
var points_label: Label
## The fresh start's button, its price on it, and why it cannot be used.
var reset_button: UiButton
var reset_reason_label: Label
## The question asked, and its two answers.
var ask_label: Label
var choose_button: UiButton
var not_yet_button: UiButton
## The paragon caption ([code]3 paragon points[/code], or when they come), and one cell per stat.
var paragon_label: Label
var paragon_cells: Array[ParagonCell] = []

var _simulation: Simulation
var _hero_id: int = -1
var _asking: Asking = Asking.NOTHING
## The node a path question is about.
var _asked_node: StringName = &""
## The price a reset question named: if it changes, the question goes (spec 055 R6).
var _asked_price: int = 0
var _width: float = 0.0
var _paragon_y: float = 0.0
var _middle: float = 0.0
var _tip: UiTip


## The tab of hero [param hero_id], [param width] UI pixels wide; [param tip] gives its controls
## their tooltips (may be null).
func _init(simulation: Simulation, hero_id: int, width: float, tip: UiTip) -> void:
	name = "TalentsPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_simulation = simulation
	_hero_id = hero_id
	_width = width
	_middle = floorf((UiTheme.BUTTON_HEIGHT - UiText.LINE_HEIGHT) / 2.0)
	top_row = Control.new()
	top_row.name = "TopRow"
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.size = Vector2(width, UiTheme.BUTTON_HEIGHT)
	add_child(top_row)
	points_label = _label("Points", &"yellow", Vector2(0, _middle), top_row)
	points_label.mouse_filter = Control.MOUSE_FILTER_PASS
	reset_button = WindowText.button("Reset", "Reset")
	reset_button.pressed.connect(press_reset)
	top_row.add_child(reset_button)
	reset_reason_label = _label("ResetReason", &"slate", Vector2(0, _middle), top_row)
	ask_label = _label("Ask", &"yellow", Vector2(0, _middle), top_row)
	choose_button = WindowText.button("Choose", "Choose")
	choose_button.pressed.connect(confirm)
	top_row.add_child(choose_button)
	not_yet_button = WindowText.button("NotYet", "Not yet")
	not_yet_button.pressed.connect(cancel)
	top_row.add_child(not_yet_button)
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
	_paragon_y = top + PARAGON_GAP
	paragon_label = _label("Paragon", &"steel", Vector2(0, _paragon_y + _middle))
	paragon_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var ids: Array[StringName] = Content.training_ids()
	for i: int in ids.size():
		var cell := ParagonCell.new(ids[i], i)
		cell.position = Vector2(0, _paragon_y)
		cell.buy_button.pressed.connect(spend_paragon.bind(i))
		add_child(cell)
		paragon_cells.append(cell)
	size = Vector2(width, _paragon_y + UiTheme.BUTTON_HEIGHT)
	custom_minimum_size = size
	_tip = tip
	if tip != null:
		add_tips(tip)


func _draw() -> void:
	var line_y: float = _paragon_y - ceilf(PARAGON_GAP / 2.0)
	draw_rect(Rect2(0, line_y, _width, 1), Palette.color(&"dusk"))


func _notification(what: int) -> void:
	# The tab or its window was hidden: a question asked on it is forgotten, never answered later
	# at a price or a choice the player no longer sees.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_asking = Asking.NOTHING


## Brings everything up to date with the hero and runs the pulses and flashes on by
## [param delta] seconds. The window calls it on every advance.
func refresh(delta: float) -> void:
	var hero: Hero = _hero()
	if hero == null or tree == null:
		return
	tree.refresh(hero, delta)
	if _asking == Asking.PATH and tree.state_of(_asked_node) != TalentNode.State.AVAILABLE:
		_asking = Asking.NOTHING  # the node was taken, or can no longer be: nothing to ask
	if _asking == Asking.RESET:
		if not reset_reason(hero).is_empty() or Simulation.reset_price(hero) != _asked_price:
			_asking = Asking.NOTHING  # in a fight, too poor, or the price is no longer the one asked
	if not is_visible_in_tree():
		_asking = Asking.NOTHING
	_refresh_top(hero)
	_refresh_paragon(hero, delta)
	if _tip != null:
		for each: TalentNode in tree.nodes():
			_tip.attach(each, _node_tip(each))


## What a click on node [param ability_id] does: one the hero can take now is taken, except the
## first node of a path, which asks first; any other does nothing (its words already say why).
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
## one and the tab shows. The cell's [code]+1[/code] and the number keys call it.
func spend_paragon(index: int) -> void:
	var hero: Hero = _hero()
	if hero == null or index < 0 or index >= paragon_cells.size():
		return
	# A press reaching a cell while the tab is hidden does nothing (spec 034 R3).
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
	var before: Array[StringName] = tree_def.trunk.duplicate()
	if on >= 0:
		before.append_array(
			tree_def.path_nodes(on).slice(0, tree_def.path_nodes(on).find(ability_id))
		)
	else:
		before = before.slice(0, tree_def.trunk.find(ability_id))
	for earlier: StringName in before:
		if not taken.has(earlier):
			return "Take %s first" % Content.ability(earlier).display_name
	# Next in order, and not open to it: the only thing missing is a point.
	return "No talent point"


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


## Gives every control of the tab its tooltip, one plain sentence each.
func add_tips(tip: UiTip) -> void:
	if tree != null:
		for each: TalentNode in tree.nodes():
			tip.attach(each, _node_tip(each))
		for i: int in tree.path_labels.size():
			tip.attach(
				tree.path_labels[i],
				(
					"The %s path: a hero walks one path, and the other closes."
					% tree.tree.path_names[i]
				)
			)
	tip.attach(reset_button, "A fresh start gives every talent point back, for gold.")
	tip.attach(choose_button, "Send it: no going back without a reset.")
	tip.attach(not_yet_button, "Keep both choices open for now.")
	tip.attach(points_label, "Talent points come with every second level: spend them here.")
	tip.attach(paragon_label, "Paragon points come with every level once the tree is earned.")
	for cell: ParagonCell in paragon_cells:
		var def: TrainingDef = Content.training(cell.id)
		var text: String = (
			"Put a paragon point into %s: %s." % [def.display_name, _lower(def.description)]
		)
		for control: Control in [cell.buy_button, cell.name_label, cell.rank_label]:
			tip.attach(control, text)


# --- Reading and showing -------------------------------------------------------


func _hero() -> Hero:
	return _simulation.party.hero(_hero_id) if _simulation != null else null


## The top row: the points and the reset, or the question and its answers.
func _refresh_top(hero: Hero) -> void:
	var points: int = hero.talent_points()
	var text: String = "%d talent point%s" % [points, "" if points == 1 else "s"]
	var colour: StringName = &"yellow"
	if points == 0:
		colour = &"steel"
		var earned: int = TalentRules.talent_points_at(hero.level)
		if earned >= Hero.TALENT_POINTS:
			text = "The tree is full"
		else:
			text = "Next point at level %d" % ((earned + 1) * Hero.TALENT_EVERY)
	_show(points_label, text, colour)
	var price: String = "Reset %s" % Hud.group_thousands(Simulation.reset_price(hero))
	if reset_button.text != price:
		reset_button.text = price
		WindowText.fit_button(reset_button)
	var why: String = reset_reason(hero)
	reset_button.disabled = not why.is_empty()
	_show(reset_reason_label, why, &"slate")
	var asking_now: bool = _asking != Asking.NOTHING
	for control: Control in [ask_label, choose_button, not_yet_button]:
		control.visible = asking_now
	for control: Control in [reset_button, reset_reason_label]:
		control.visible = not asking_now
	reset_button.position = Vector2(_width - reset_button.size.x, 0)
	reset_reason_label.position.x = reset_button.position.x - ROW_GAP - reset_reason_label.size.x
	if not asking_now:
		return
	var question: String = ""
	var tree_def: TalentTreeDef = tree.tree
	if _asking == Asking.PATH:
		var on: int = tree.node(_asked_node).path
		question = (
			"Choose %s? This closes %s." % [tree_def.path_names[on], tree_def.path_names[1 - on]]
		)
		choose_button.text = "Choose"
	else:
		var gold: String = Hud.group_thousands(Simulation.reset_price(hero))
		question = "Reset the %s's tree for %s gold?" % [hero.def().display_name, gold]
		choose_button.text = "Reset"
	WindowText.fit_button(choose_button)
	_show(ask_label, question, &"yellow")
	not_yet_button.position = Vector2(_width - not_yet_button.size.x, 0)
	choose_button.position = Vector2(not_yet_button.position.x - ROW_GAP - choose_button.size.x, 0)
	ask_label.position.x = choose_button.position.x - ROW_GAP - ask_label.size.x


func _refresh_paragon(hero: Hero, delta: float) -> void:
	var earned_all: bool = TalentRules.talent_points_at(hero.level) >= Hero.TALENT_POINTS
	var text: String = (
		"Paragon points come after level %d" % (Hero.TALENT_POINTS * Hero.TALENT_EVERY)
	)
	var colour: StringName = &"steel"
	if earned_all:
		var points: int = hero.paragon_points()
		text = "%d paragon point%s" % [points, "" if points == 1 else "s"]
		colour = &"yellow" if points > 0 else &"steel"
	_show(paragon_label, text, colour)
	# Huge bonuses (thousands of percent) would push the row past the edge: then the names
	# shorten (Tough, Quick), the full ones staying in the tooltips.
	for short: bool in [false, true]:
		var x: float = paragon_label.size.x + PARAGON_CELL_GAP * 2.0
		for cell: ParagonCell in paragon_cells:
			cell.visible = earned_all
			cell.refresh(hero, delta if not short else 0.0, short)
			cell.position.x = x
			x += cell.size.x + PARAGON_CELL_GAP
		if x - PARAGON_CELL_GAP <= _width:
			break


func _label(label_name: String, colour: StringName, at: Vector2, parent: Control = null) -> Label:
	var made: Label = WindowText.label(label_name, "", colour)
	made.position = at
	(parent if parent != null else self).add_child(made)
	return made


func _show(label: Label, text: String, colour: StringName) -> void:
	WindowText.set_text(label, text)
	label.add_theme_color_override(&"font_color", Palette.color(colour))


## A node's tooltip: what a click does, or why it cannot be taken now.
func _node_tip(each: TalentNode) -> String:
	var hero: Hero = _hero()
	var ability: AbilityDef = Content.ability(each.ability_id)
	if hero == null or ability == null:
		return "A talent."
	match each.state():
		TalentNode.State.TAKEN:
			return "%s is taken." % ability.display_name
		TalentNode.State.AVAILABLE:
			if each.path >= 0 and hero.path() < 0:
				return "Click to choose the %s path." % tree.tree.path_names[each.path]
			return "Click to take %s." % ability.display_name
	return "%s: %s." % [ability.display_name, _lower(reason(hero, each.ability_id))]


static func _lower(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1).trim_suffix(".") if not text.is_empty() else ""

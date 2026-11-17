class_name TalentTab
extends Control
## The hero sheet's Talents tab (spec 055): the shown hero's whole talent tree, what each node does,
## and its paragon points, with nothing to scroll. [HeroSheet] hosts it as the page of
## [constant HeroSheet.Page.TALENTS], and grows to [constant HeroSheet.TALENTS_SIZE] while it is
## open.
##
## From the top: the unspent talent points ([code]2 talent points[/code]), or the level that brings
## the next ([code]Next point at level 6[/code]), with the [code]Reset[/code] button at the right
## (its price, and why it cannot be used beside it when it cannot); the three trunk nodes in a row;
## the two paths side by side under their names, four nodes each, joined by lines; a fixed place
## that tells the node pointed at or selected (its name, whether it is an action with its cooldown
## or a passive, its description, and why it cannot be taken), or asks before a path is chosen or
## the tree reset; and the paragon points under it all.
##
## A click on a node that can be taken takes it ([method Simulation.take_talent]); the first node
## of a path asks first, and only [code]Choose[/code] sends the command. Every value is read from
## the simulation at each [method refresh], so nothing goes stale across level-ups, commands or a
## crowded frame. One [TalentTab.TreeView] is made per class at [method setup], and only the shown
## hero's class's is visible, so every control can be given its tooltip once ([method add_tips]).

## What the fixed place is asking, if anything.
enum Asking { NOTHING, PATH, RESET }

## The tab's size: the sheet's while the tab is open.
const SIZE: Vector2 = Vector2(240, 278)
## The left and right edges of the content, and its width.
const LEFT: float = 8.0
const RIGHT: float = SIZE.x - 8.0
const WIDTH: float = RIGHT - LEFT
## The line of unspent points and the Reset button.
const POINTS_Y: float = 92.0
## The trunk's row, the line the paths fork from, the paths' names and their first nodes.
const TRUNK_Y: float = 105.0
const FORK_Y: float = 122.0
const PATH_NAME_Y: float = 124.0
const PATH_Y: float = 134.0
## Pixels from one node of a path to the next.
const PATH_STEP: float = 17.0
## The left of each path's column (its nodes' boxes).
const COLUMN_X: Array[float] = [12.0, 128.0]
## The fixed place: the line above it, its first line, a line's height and how many lines the
## description may take.
const INFO_LINE_Y: float = 201.0
const INFO_Y: float = 203.0
const LINE: float = 9.0
const DESCRIPTION_LINES: int = 3
## The paragon points: the line above them, their caption and their row.
const PARAGON_LINE_Y: float = 250.0
const PARAGON_Y: float = 253.0
const PARAGON_ROW_Y: float = 263.0
## Pixels between two paragon stats.
const PARAGON_GAP: float = 6.0
## Pixels between the reason Reset cannot be used and the button.
const REASON_GAP: float = 4.0
## Seconds a paragon stat's bonus shows in yellow after a point goes in.
const FLASH_SECONDS: float = 0.5

## The tree of each class, by class id; only the shown hero's is visible.
var trees: Dictionary[StringName, TreeView] = {}
## The line of unspent talent points, or the level of the next.
var points_label: Label
## The fresh start's button, its price on it, and why it cannot be used.
var reset_button: HudButton
var reset_reason_label: Label
## The fixed place's lines: the name and kind, the description, and the reason.
var info_name: Label
var info_kind: Label
var info_description: Array[Label] = []
var info_reason: Label
## The question the fixed place asks, and its two answers.
var ask_label: Label
var choose_button: HudButton
var not_yet_button: HudButton
## The paragon caption ([code]3 paragon points[/code], or when they come), and one cell per stat.
var paragon_label: Label
var paragon_cells: Array[ParagonCell] = []

var _simulation: Simulation
var _hero_id: int = -1
## The node the mouse is over, and the one last clicked, or &"".
var _pointed: StringName = &""
var _selected: StringName = &""
var _mouse: Vector2 = HudTooltip.NOWHERE
var _asking: Asking = Asking.NOTHING
## The node a path question is about.
var _asked_node: StringName = &""
## The price a reset question named: if it changes, the question goes (spec 055 R6).
var _asked_price: int = 0


func _init() -> void:
	name = "TalentsPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE


## Call once, before the first refresh.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	points_label = _label("Points", &"yellow", Vector2(LEFT, POINTS_Y))
	reset_button = HudButton.new("Reset")
	reset_button.name = "Reset"
	reset_button.position = Vector2(RIGHT - reset_button.size.x, POINTS_Y - 1.0)
	reset_button.pressed.connect(press_reset)
	add_child(reset_button)
	reset_reason_label = _label("ResetReason", &"slate", Vector2(0, POINTS_Y))
	for class_id: StringName in Content.hero_class_ids():
		var tree: TalentTreeDef = Content.talent_tree(class_id)
		if tree == null:
			continue
		var view := TreeView.new(tree)
		view.visible = false
		for each: TalentNode in view.nodes():
			each.clicked.connect(press_node)
		add_child(view)
		trees[class_id] = view
	info_name = _label("InfoName", &"white", Vector2(LEFT, INFO_Y))
	info_kind = _label("InfoKind", &"steel", Vector2(LEFT, INFO_Y))
	for i: int in DESCRIPTION_LINES:
		var line_label: Label = _label("InfoLine%d" % i, &"silver", Vector2(LEFT, INFO_Y + LINE))
		line_label.position.y += i * LINE
		info_description.append(line_label)
	info_reason = _label("InfoReason", &"steel", Vector2(LEFT, INFO_Y + LINE * 4.0 + 1.0))
	ask_label = _label("Ask", &"yellow", Vector2(LEFT, INFO_Y + LINE))
	choose_button = HudButton.new("Choose")
	choose_button.name = "Choose"
	choose_button.position = Vector2(LEFT, INFO_Y + LINE * 2.0 + 4.0)
	choose_button.pressed.connect(confirm)
	add_child(choose_button)
	not_yet_button = HudButton.new("Not yet")
	not_yet_button.name = "NotYet"
	not_yet_button.pressed.connect(cancel)
	add_child(not_yet_button)
	paragon_label = _label("Paragon", &"steel", Vector2(LEFT, PARAGON_Y))
	var ids: Array[StringName] = Content.training_ids()
	for i: int in ids.size():
		var cell := ParagonCell.new(ids[i], i)
		cell.position = Vector2(LEFT, PARAGON_ROW_Y)
		cell.buy_button.pressed.connect(spend_paragon.bind(i))
		add_child(cell)
		paragon_cells.append(cell)


func _draw() -> void:
	var dusk: Color = Palette.color(&"dusk")
	draw_rect(Rect2(HeroSheet.PADDING, INFO_LINE_Y, SIZE.x - 2.0 * HeroSheet.PADDING, 1), dusk)
	draw_rect(Rect2(HeroSheet.PADDING, PARAGON_LINE_Y, SIZE.x - 2.0 * HeroSheet.PADDING, 1), dusk)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		point_at(motion.position)


func _notification(what: int) -> void:
	# The mouse left the window: nothing is pointed at any more.
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		point_at(HudTooltip.NOWHERE)
	# The page or the sheet was hidden: a question asked on it is forgotten, never answered
	# later at a price or a choice the player no longer sees.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_asking = Asking.NOTHING


## Shows hero [param hero_id]'s tree from now on; a new hero starts with nothing selected and no
## question asked.
func show_hero(hero_id: int) -> void:
	if hero_id == _hero_id:
		return
	_hero_id = hero_id
	_selected = &""
	_asking = Asking.NOTHING
	for cell: ParagonCell in paragon_cells:
		cell.stop_flash()


## Moves the mouse to [param at], in screen pixels: the node under it is the one the fixed place
## tells.
func point_at(at: Vector2) -> void:
	_mouse = at
	_pointed = &""
	var view: TreeView = _view()
	if view == null or not is_visible_in_tree():
		return
	for each: TalentNode in view.nodes():
		if each.get_global_rect().has_point(at):
			_pointed = each.ability_id


## Brings everything up to date with the shown hero and runs the pulses and flashes on by
## [param delta] seconds. Called by the sheet on every advance.
func refresh(delta: float) -> void:
	var hero: Hero = _hero()
	if hero == null:
		return
	var shown: TreeView = _view()
	for class_id: StringName in trees:
		trees[class_id].visible = trees[class_id] == shown
	if shown == null:
		return
	if _mouse != HudTooltip.NOWHERE:
		point_at(_mouse)
	shown.refresh(hero, delta)
	_refresh_points(hero)
	if _asking == Asking.PATH and shown.state_of(_asked_node) != TalentNode.State.AVAILABLE:
		_asking = Asking.NOTHING  # the node was taken, or can no longer be: nothing to ask
	if _asking == Asking.RESET:
		if not reset_reason(hero).is_empty() or Simulation.reset_price(hero) != _asked_price:
			_asking = Asking.NOTHING  # in a fight, too poor, or the price is no longer the one asked
	if not is_visible_in_tree():
		_asking = Asking.NOTHING
	_refresh_info(hero, shown)
	_refresh_paragon(hero, delta)


## What a click on node [param ability_id] does: one the shown hero can take now is taken, except
## the first node of a path, which asks first; any other is selected, so the fixed place tells it.
func press_node(ability_id: StringName) -> void:
	var hero: Hero = _hero()
	var view: TreeView = _view()
	if hero == null or view == null or not view.has_ability(ability_id) or not is_visible_in_tree():
		return
	view.refresh(hero, 0.0)  # what the simulation says now, not at the last frame
	_selected = ability_id
	_asking = Asking.NOTHING
	if view.state_of(ability_id) != TalentNode.State.AVAILABLE:
		refresh(0.0)
		return
	if view.node(ability_id).path >= 0 and hero.path() < 0:
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
			if Simulation.reset_price(hero) == _asked_price:
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


## Puts one of the shown hero's paragon points into the stat of cell [param index] (0-based), if
## it has one. The cell's [code]+1[/code] and the number keys call it.
func spend_paragon(index: int) -> void:
	var hero: Hero = _hero()
	if hero == null or index < 0 or index >= paragon_cells.size():
		return
	# A press reaching a cell while the page is hidden does nothing (spec 034 R3).
	if hero.paragon_points() <= 0 or not is_visible_in_tree():
		return
	_simulation.spend_paragon(hero.id, Content.training(paragon_cells[index].id).stat)


## Starts the flash of the cell of stat position [param index] (a point just went in).
func flash_paragon(index: int) -> void:
	if index >= 0 and index < paragon_cells.size():
		paragon_cells[index].start_flash()


## What the fixed place is asking.
func asking() -> Asking:
	return _asking


## The shown tree's node of [param ability_id], or null.
func node(ability_id: StringName) -> TalentNode:
	var view: TreeView = _view()
	return view.node(ability_id) if view != null else null


## The shown tree's view, or null.
func tree_view() -> TreeView:
	return _view()


## The fixed place's lines, top to bottom, as shown: the name and kind, the description and the
## reason, or the question and its answers ([code][Choose][/code]).
func info_lines() -> Array[String]:
	var lines: Array[String] = []
	if _asking != Asking.NOTHING:
		lines.append(ask_label.text)
		lines.append("[%s] [%s]" % [choose_button.text, not_yet_button.text])
		return lines
	if not info_name.visible:
		return lines
	lines.append("%s %s" % [info_name.text, info_kind.text])
	for line_label: Label in info_description:
		if line_label.visible and not line_label.text.is_empty():
			lines.append(line_label.text)
	if not info_reason.text.is_empty():
		lines.append(info_reason.text)
	return lines


## Why the shown hero cannot have a fresh start now ([code]Nothing to reset[/code],
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
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	if tree == null or not tree.has_node(ability_id):
		return ""
	var taken: Array[StringName] = hero.talents()
	if taken.has(ability_id) or hero.can_take(ability_id):
		return ""
	var on: int = tree.path_of(ability_id)
	if on >= 0 and hero.path() >= 0 and hero.path() != on:
		return "The %s path is closed" % tree.path_names[on]
	var before: Array[StringName] = tree.trunk.duplicate()
	if on >= 0:
		before.append_array(tree.path_nodes(on).slice(0, tree.path_nodes(on).find(ability_id)))
	else:
		before = before.slice(0, tree.trunk.find(ability_id))
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
		return "Action, every %s s" % HeroSheet.tiles(ability.cooldown)
	return "Passive"


## The name of the path [param hero] walks, or "" before it chooses one.
static func path_name(hero: Hero) -> String:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var on: int = hero.path()
	if tree == null or on < 0 or on >= tree.path_names.size():
		return ""
	return tree.path_names[on]


## [param hero]'s class, and its path once chosen ([code]Knight, Berserker[/code]).
static func title(hero: Hero) -> String:
	var walked: String = path_name(hero)
	var name_text: String = hero.def().display_name
	return name_text if walked.is_empty() else "%s, %s" % [name_text, walked]


## [param text] broken at spaces into lines no wider than [param width] pixels.
static func wrap_words(text: String, width: float) -> Array[String]:
	var lines: Array[String] = []
	var current: String = ""
	for word: String in text.split(" ", false):
		var longer: String = word if current.is_empty() else current + " " + word
		if current.is_empty() or PixelText.width(longer) <= width:
			current = longer
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines


## The tooltip of hero [param hero_id]'s frame (R9): [code]Click for details[/code], with the class
## and its path before it once a path is chosen ([code]Knight, Berserker: click for details[/code]).
func frame_tip(hero_id: int) -> String:
	var hero: Hero = _simulation.party.hero(hero_id) if _simulation != null else null
	if hero == null or hero.path() < 0:
		return "Click for details"
	return "%s: click for details" % title(hero)


## Gives every control of the tab its tooltip. Call once, after [method setup].
func add_tips(tooltip: HudTooltip) -> void:
	for class_id: StringName in trees:
		for each: TalentNode in trees[class_id].nodes():
			tooltip.tip([each], _node_tip.bind(each))
		for i: int in 2:
			tooltip.tip([trees[class_id].path_labels[i]], _path_tip.bind(class_id, i))
	tooltip.tip([reset_button], _reset_tip)
	tooltip.tip([choose_button], _choose_tip)
	tooltip.tip([not_yet_button], "Keep both choices open for now.")
	tooltip.tip([points_label], "Talent points come with every second level: spend them here.")
	tooltip.tip([paragon_label], "Paragon points come with every level once the tree is earned.")
	for cell: ParagonCell in paragon_cells:
		var def: TrainingDef = Content.training(cell.id)
		tooltip.tip(
			[cell.buy_button, cell.name_label, cell.rank_label],
			"Put a paragon point into %s: %s." % [def.display_name, _lower(def.description)]
		)


# --- Reading and showing -------------------------------------------------------


func _hero() -> Hero:
	if _simulation == null or _hero_id < 0:
		return null
	return _simulation.party.hero(_hero_id)


func _view() -> TreeView:
	var hero: Hero = _hero()
	return trees.get(hero.class_id, null) if hero != null else null


func _refresh_points(hero: Hero) -> void:
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
	_set_text(points_label, text, colour)
	var price: String = "Reset %s" % Hud.group_thousands(Simulation.reset_price(hero))
	if reset_button.text != price:
		reset_button.text = price
	reset_button.position.x = RIGHT - reset_button.size.x
	var why: String = reset_reason(hero)
	reset_button.disabled = not why.is_empty()
	reset_button.lit = _asking == Asking.RESET
	_set_text(reset_reason_label, why, &"slate")
	reset_reason_label.position.x = reset_button.position.x - REASON_GAP - reset_reason_label.size.x


func _refresh_info(hero: Hero, view: TreeView) -> void:
	var asking_now: bool = _asking != Asking.NOTHING
	ask_label.visible = asking_now
	choose_button.visible = asking_now
	not_yet_button.visible = asking_now
	if asking_now:
		_show_question(hero, view)
	var shown: StringName = _pointed if not _pointed.is_empty() else _selected
	if shown.is_empty() or not view.has_ability(shown):
		shown = view.default_node(hero)
	var ability: AbilityDef = Content.ability(shown) if not shown.is_empty() else null
	var telling: bool = ability != null and not asking_now
	for label: Label in [info_name, info_kind, info_reason]:
		label.visible = telling
	for label: Label in info_description:
		label.visible = telling
	if not telling:
		return
	_set_text(info_name, ability.display_name, &"white")
	_set_text(info_kind, kind_text(shown), &"steel")
	info_kind.position.x = RIGHT - info_kind.size.x
	var lines: Array[String] = wrap_words(ability.description, WIDTH)
	for i: int in info_description.size():
		var text: String = lines[i] if i < lines.size() else ""
		if i == info_description.size() - 1 and lines.size() > info_description.size():
			text = " ".join(PackedStringArray(lines.slice(i)))
		_set_text(info_description[i], text, &"silver")
	var why: String = reason(hero, shown)
	var colour: StringName = &"red"
	match view.state_of(shown):
		TalentNode.State.TAKEN:
			why = "Taken"
			colour = &"green"
		TalentNode.State.AVAILABLE:
			why = "Click to take it"
			colour = &"yellow"
			if view.node(shown).path >= 0 and hero.path() < 0:
				why = "Click to choose the %s path" % view.tree.path_names[view.node(shown).path]
		TalentNode.State.CLOSED:
			colour = &"steel"
	_set_text(info_reason, why, colour)


func _show_question(hero: Hero, view: TreeView) -> void:
	var question: String = ""
	if _asking == Asking.PATH:
		var on: int = view.node(_asked_node).path
		question = (
			"Choose %s? This closes %s." % [view.tree.path_names[on], view.tree.path_names[1 - on]]
		)
		choose_button.text = "Choose"
	else:
		var price: String = Hud.group_thousands(Simulation.reset_price(hero))
		question = "Reset the %s's tree for %s gold?" % [hero.def().display_name, price]
		choose_button.text = "Reset"
	_set_text(ask_label, question, &"yellow")
	not_yet_button.position = Vector2(
		choose_button.position.x + choose_button.size.x + PARAGON_GAP, choose_button.position.y
	)


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
	_set_text(paragon_label, text, colour)
	# Huge bonuses (thousands of percent) would push the row past the sheet's edge: then the
	# names shorten (Tough, Quick), the full ones staying in the tooltips.
	for short: bool in [false, true]:
		var x: float = LEFT
		for cell: ParagonCell in paragon_cells:
			cell.visible = earned_all
			cell.refresh(hero, delta if not short else 0.0, short)
			cell.position.x = x
			x += cell.size.x + PARAGON_GAP
		if x - PARAGON_GAP <= RIGHT:
			break


func _label(label_name: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label("", colour)
	made.name = label_name
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _set_text(label: Label, text: String, colour: StringName) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()
	label.add_theme_color_override(&"font_color", Palette.color(colour))


func _node_tip(each: TalentNode) -> String:
	var hero: Hero = _hero()
	var ability: AbilityDef = Content.ability(each.ability_id)
	if hero == null or ability == null:
		return "A talent."
	var view: TreeView = _view()
	if view != null and view.state_of(each.ability_id) == TalentNode.State.AVAILABLE:
		if each.path >= 0 and hero.path() < 0:
			return "Click to choose the %s path." % view.tree.path_names[each.path]
		return "Click to take %s." % ability.display_name
	return "%s: read about it below." % ability.display_name


func _path_tip(class_id: StringName, index: int) -> String:
	var tree: TalentTreeDef = trees[class_id].tree
	return "The %s path: a hero walks one path, and the other closes." % tree.path_names[index]


func _reset_tip() -> String:
	var hero: Hero = _hero()
	var why: String = reset_reason(hero) if hero != null else ""
	if not why.is_empty():
		return "A fresh start gives every talent point back: %s now." % why.to_lower()
	return "A fresh start gives every talent point back, for gold; paragon points stay."


func _choose_tip() -> String:
	if _asking == Asking.RESET:
		return "Pay the gold and give every talent point back."
	return "Take this node and walk its path for good."


static func _lower(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1).trim_suffix(".") if not text.is_empty() else ""


## One class's tree as the tab draws it: the trunk's three nodes in a row, each path's name over
## its four nodes in a column, and the lines that join them, drawn in [method _draw].
class TreeView:
	extends Control

	## The tree shown.
	var tree: TalentTreeDef
	## The trunk's nodes, left to right.
	var trunk_nodes: Array[TalentNode] = []
	## Each path's nodes, top to bottom.
	var path_nodes: Array[Array] = [[], []]
	## Each path's name.
	var path_labels: Array[Label] = []

	## The hero's path, or -1: a closed path's name is struck through.
	var _walked: int = -1
	var _by_id: Dictionary[StringName, TalentNode] = {}

	func _init(tree_def: TalentTreeDef) -> void:
		tree = tree_def
		name = "Tree_%s" % tree.class_id
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = TalentTab.SIZE
		var widths: float = 0.0
		for id: StringName in tree.trunk:
			var made: TalentNode = _add(id, -1)
			trunk_nodes.append(made)
			widths += made.size.x
		var gap: float = floorf((TalentTab.WIDTH - widths) / (trunk_nodes.size() + 1))
		var x: float = TalentTab.LEFT + gap
		for made: TalentNode in trunk_nodes:
			made.position = Vector2(x, TalentTab.TRUNK_Y)
			x += made.size.x + gap
		for index: int in 2:
			var column: float = TalentTab.COLUMN_X[index]
			var label_text: String = (
				tree.path_names[index] if index < tree.path_names.size() else ""
			)
			var label: Label = PixelText.label(label_text, &"steel")
			label.name = "Path%d" % index
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.position = Vector2(
				column + TalentNode.BOX.x + TalentNode.NAME_GAP, TalentTab.PATH_NAME_Y
			)
			add_child(label)
			path_labels.append(label)
			# The line through a closed path's name, over the text.
			var strike := ColorRect.new()
			strike.name = "Strike"
			strike.color = Palette.color(&"silver")
			strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strike.position = Vector2(-1, 3)
			strike.size = Vector2(PixelText.width(label_text) + 1.0, 1)
			strike.visible = false
			label.add_child(strike)
			var step: int = 0
			for id: StringName in tree.path_nodes(index):
				var made: TalentNode = _add(id, index)
				made.position = Vector2(column, TalentTab.PATH_Y + step * TalentTab.PATH_STEP)
				path_nodes[index].append(made)
				step += 1

	## Every node, the trunk first.
	func nodes() -> Array[TalentNode]:
		var all: Array[TalentNode] = trunk_nodes.duplicate()
		for index: int in 2:
			for made: TalentNode in path_nodes[index]:
				all.append(made)
		return all

	## The node of [param ability_id], or null.
	func node(ability_id: StringName) -> TalentNode:
		return _by_id.get(ability_id, null)

	## True if [param ability_id] is a node of this tree.
	func has_ability(ability_id: StringName) -> bool:
		return _by_id.has(ability_id)

	## How the node of [param ability_id] stands, as last refreshed.
	func state_of(ability_id: StringName) -> TalentNode.State:
		var found: TalentNode = node(ability_id)
		return found.state() if found != null else TalentNode.State.LOCKED

	## True while path [param index]'s name is struck through: the hero walks the other.
	func is_closed(index: int) -> bool:
		return _walked >= 0 and _walked != index

	## The node the fixed place tells when nothing is pointed at or selected: the first that can
	## be taken next, else the last taken, else the first.
	func default_node(hero: Hero) -> StringName:
		var next: Array[StringName] = tree.next_nodes(hero.talents())
		if not next.is_empty():
			return next[0]
		var taken: Array[StringName] = hero.talents()
		if not taken.is_empty():
			return taken[taken.size() - 1]
		return tree.trunk[0] if not tree.trunk.is_empty() else &""

	## Sets every node's state from [param hero] and runs the pulses on by [param delta] seconds.
	func refresh(hero: Hero, delta: float) -> void:
		var taken: Array[StringName] = hero.talents()
		var walked: int = hero.path()
		for made: TalentNode in nodes():
			var stands: TalentNode.State = TalentNode.State.LOCKED
			if taken.has(made.ability_id):
				stands = TalentNode.State.TAKEN
			elif walked >= 0 and made.path >= 0 and made.path != walked:
				stands = TalentNode.State.CLOSED
			elif hero.can_take(made.ability_id):
				stands = TalentNode.State.AVAILABLE
			made.show_state(stands, stands == TalentNode.State.AVAILABLE)
			made.advance(delta)
		for index: int in path_labels.size():
			var colour: StringName = &"steel"
			if walked == index:
				colour = &"white"
			elif walked >= 0:
				colour = &"slate"
			path_labels[index].add_theme_color_override(&"font_color", Palette.color(colour))
		_walked = walked
		for index: int in path_labels.size():
			(path_labels[index].get_node("Strike") as ColorRect).visible = is_closed(index)
		queue_redraw()

	func _add(id: StringName, on_path: int) -> TalentNode:
		var made := TalentNode.new(id, on_path)
		add_child(made)
		_by_id[id] = made
		return made

	## The lines that join the nodes, each [Rect2, the nodes it joins]: the trunk left to right,
	## then the fork down from the last trunk node, across to both paths and down each.
	func joins() -> Array[Array]:
		var all: Array[Array] = []
		for i: int in range(1, trunk_nodes.size()):
			var from: TalentNode = trunk_nodes[i - 1]
			var to: TalentNode = trunk_nodes[i]
			var y: float = from.position.y + TalentNode.BOX.y / 2.0
			var start: float = from.position.x + from.size.x + 2.0
			all.append([Rect2(start, y, to.position.x - 2.0 - start, 1), [from, to]])
		if trunk_nodes.is_empty():
			return all
		var last: TalentNode = trunk_nodes[trunk_nodes.size() - 1]
		var drop_x: float = last.position.x + TalentNode.BOX.x / 2.0
		var under: float = last.position.y + TalentNode.BOX.y + 1.0
		all.append([Rect2(drop_x, under, 1, TalentTab.FORK_Y - under), [last]])
		var spines: Array[float] = []
		for index: int in 2:
			spines.append(TalentTab.COLUMN_X[index] + TalentNode.BOX.x / 2.0)
		var left: float = minf(spines[0], drop_x)
		var right: float = maxf(spines[1], drop_x)
		all.append([Rect2(left, TalentTab.FORK_Y, right - left + 1.0, 1), [last]])
		for index: int in 2:
			var column: Array = path_nodes[index]
			if column.is_empty():
				continue
			var first: TalentNode = column[0]
			var top: float = TalentTab.FORK_Y + 1.0
			all.append([Rect2(spines[index], top, 1, first.position.y - 1.0 - top), [last, first]])
			for step: int in range(1, column.size()):
				var above: TalentNode = column[step - 1]
				var below: TalentNode = column[step]
				var from_y: float = above.position.y + TalentNode.BOX.y
				var gap: float = below.position.y - from_y
				all.append([Rect2(spines[index], from_y, 1, gap), [above, below]])
		return all

	func _draw() -> void:
		for join: Array in joins():
			var rect: Rect2 = join[0]
			var ends: Array = join[1]
			_line(rect, ends)

	## Draws one joining line: silver when every node it joins is taken, dusk when any is
	## closed, slate otherwise.
	func _line(rect: Rect2, ends: Array) -> void:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var colour: StringName = &"silver"
		for end: TalentNode in ends:
			if end.state() == TalentNode.State.CLOSED:
				colour = &"dusk"
				break
			if end.state() != TalentNode.State.TAKEN:
				colour = &"slate"
		draw_rect(rect, Palette.color(colour))


## One paragon stat under the tree (spec 055 R7): a [code]+1[/code] button, the stat's name and
## the bonus its points give so far. [method refresh] reads the hero each frame.
class ParagonCell:
	extends Control

	## Letters a stat's name keeps when the row is too wide for the full names.
	const SHORT_NAME: int = 5

	## The stat this cell shows: a [TrainingDef] id.
	var id: StringName
	var buy_button: HudButton
	var name_label: Label
	var rank_label: Label

	var _flash: float = 0.0
	var _rank: int = 0

	## A cell for stat [param training_id], the [param index]th (0-based).
	func _init(training_id: StringName, index: int) -> void:
		id = training_id
		name = "Paragon%d" % (index + 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy_button = HudButton.new("+1")
		buy_button.name = "Spend"
		add_child(buy_button)
		var def: TrainingDef = Content.training(training_id)
		name_label = PixelText.label(def.display_name, &"white")
		name_label.name = "Name"
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(buy_button.size.x + 3.0, 2.0)
		add_child(name_label)
		rank_label = PixelText.label("", &"green")
		rank_label.name = "Rank"
		rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rank_label)

	## Brings the cell up to date with [param hero] and runs its flash down by [param delta];
	## [param short] shows the stat's name cut to [constant SHORT_NAME] letters.
	func refresh(hero: Hero, delta: float, short: bool = false) -> void:
		var def: TrainingDef = Content.training(id)
		var shown_name: String = def.display_name.left(SHORT_NAME) if short else def.display_name
		if name_label.text != shown_name:
			name_label.text = shown_name
		var rank: int = hero.paragon_rank(def.stat)
		_rank = rank
		var text_in: String = "+%d%%" % roundi(rank * def.per_rank * 100.0)
		if rank_label.text != text_in:
			rank_label.text = text_in
			rank_label.reset_size()
		name_label.reset_size()
		rank_label.position = Vector2(name_label.position.x + name_label.size.x + 3.0, 2.0)
		size = Vector2(rank_label.position.x + PixelText.width(text_in), HudButton.HEIGHT)
		var spendable: bool = hero.paragon_points() > 0
		buy_button.disabled = not spendable
		buy_button.text_colour = ShopRow.PRICE_AFFORDABLE if spendable else ShopRow.PRICE_TOO_DEAR
		_flash = maxf(_flash - delta, 0.0)
		var colour: StringName = &"green" if rank > 0 else &"steel"
		if _flash > 0.0:
			colour = &"yellow"
		rank_label.add_theme_color_override(&"font_color", Palette.color(colour))

	## The cell as one line: "<name> <points> <bonus>" ([code]Power 2 +6%[/code]); the cell shows
	## the name and the bonus.
	func text() -> String:
		return "%s %d %s" % [Content.training(id).display_name, _rank, rank_label.text]

	## Starts the flash: a point just went in.
	func start_flash() -> void:
		_flash = TalentTab.FLASH_SECONDS

	## Stops the flash at once.
	func stop_flash() -> void:
		_flash = 0.0

	## Seconds of flash left.
	func flash() -> float:
		return _flash

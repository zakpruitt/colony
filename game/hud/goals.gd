class_name Goals
extends Control
## The goals tracker (spec 037): a small panel under the depth panel on the left showing the next
## few things within reach, each a one-line sentence with a thin progress bar or a count. It is a
## signpost only: it gives no rewards and changes no rules.
##
## At each [method advance] it reads the simulation and lists the first [constant MOST] goals that
## apply, in this order: beating the next guardian (when its depth is within
## [constant GUARDIAN_WITHIN] of the deepest depth and it has never been beaten), reaching the next
## depth, the microskill nearest to being learned, training a hero, and buying an upgrade. A shown
## goal that is achieved (the guardian slain, the depth reached, the microskill learned) flashes,
## shows a tick for [constant CELEBRATE_SECONDS], writes a line in the journal and emits
## [signal goal_finished]; then the next goal takes its place. A goal achieved in a frame that
## brought old events ([method World.is_recent]: after a stall or time away) is replaced quietly.
##
## [kbd]G[/kbd] hides and shows it; it starts shown. It also hides while the hero sheet or the
## journal, which drop into the same place, is open. Each line has a tooltip ([method hint], then
## what a click does, [method action]), and since spec 042 a click on a line takes the player where
## the goal is managed ([method press]): the shop, a hero's sheet on a tab, the orders, or the
## depth ladder with the goal's rung flashing. A click opens what the HUD's own buttons open and
## changes nothing in the simulation. It moves only in [method advance], so a test can step it
## exactly.

## A shown goal was achieved, in a recent frame: [param sentence] is its journal line.
signal goal_finished(sentence: String)

## The kinds of goal, in the order the tracker prefers them, but a visit to a new area (spec 053)
## comes first.
enum Kind { GUARDIAN, DEPTH, MICROSKILL, TRAINING, UPGRADE, VISIT }

## The most goals shown at once.
const MOST: int = 3
## A guardian's goal shows once its depth is at most this many levels below the deepest depth.
const GUARDIAN_WITHIN: int = 3
## The level a guardian is balanced for is not in the data: it is taken as the guardian's depth
## plus this many levels, which matches the tests of spec 020 (a level-9 party beats the depth-5
## guardian).
const GUARDIAN_LEVEL_OVER_DEPTH: int = 4
## What a click on a goal of each kind does, for the kinds that open the same place every time.
const CLICKS: Dictionary[Kind, String] = {
	Kind.UPGRADE: "Click to open the shop.",
	Kind.GUARDIAN: "Click to open the orders.",
	Kind.DEPTH: "Click to see it on the ladder.",
	Kind.VISIT: "Click to open the area map.",
}
## Seconds a finished goal shows its tick before the next takes its place.
const CELEBRATE_SECONDS: float = 3.0
## Seconds a finished goal's row flashes, bright half then dim half (as a shop row does).
const FLASH_SECONDS: float = 0.5
## Pixels between the panel and the depth panel above it (the top band's bottom edge).
const DROP: float = 2.0
## Space inside the border; the title row's height.
const PADDING: float = 4.0
const TITLE_HEIGHT: float = 12.0
## The panel's least width; it grows to hold its longest line.
const MIN_WIDTH: float = 150.0
## The title and the key hint.
const TITLE: String = "Goals"
const HIDE_HINT: String = "G hide"

## The tracker's panel; its rows are children of it.
var panel: HudPanel
## One row per goal shown, top to bottom; a row with no goal is hidden.
var rows: Array[Row] = []

var _simulation: Simulation
var _world: World
## The goals showing, top first (some may be celebrating).
var _shown: Array[Goal] = []
## Whether the player wants the tracker ([kbd]G[/kbd]); the sheet or journal can still hide it.
var _wanted: bool = true
## True once an old event arrives, until the next advance: nothing achieved then is celebrated.
var _stale: bool = false


func _init() -> void:
	name = "Goals"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO
	position = Vector2(Hud.MARGIN, Hud.TOP_BAND + DROP)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_G:
		return
	_wanted = not _wanted
	advance(0.0)
	get_viewport().set_input_as_handled()


## Call once, before the first advance. [param world] may be null (nothing is then old).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	panel = HudPanel.new()
	panel.name = "GoalsPanel"
	add_child(panel)
	var title: Label = PixelText.label(TITLE, &"steel")
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(PADDING + 2.0, PADDING - 1.0)
	panel.add_child(title)
	var hint_label: Label = PixelText.label(HIDE_HINT, &"slate")
	hint_label.name = "Hint"
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint_label)
	for i: int in MOST:
		var row := Row.new()
		row.name = "Goal%d" % i
		row.visible = false
		row.clicked.connect(press.bind(i))
		panel.add_child(row)
		rows.append(row)
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Reads the goals from the simulation, celebrates a shown goal just achieved, runs the
## celebrations on by [param delta] seconds and lays the panel out. Called every frame by the HUD;
## tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	var current: Array[Goal] = applicable()
	var quiet: bool = _stale
	_stale = false
	var keys: Dictionary[String, Goal] = {}
	for goal: Goal in current:
		keys[goal.key] = goal
	# What became of each goal showing: still there, celebrating, just achieved, or gone.
	var celebrating: Dictionary[int, Goal] = {}
	for i: int in _shown.size():
		var goal: Goal = _shown[i]
		if goal.celebrate > 0.0:
			goal.celebrate -= delta
			goal.flash = maxf(goal.flash - delta, 0.0)
			if goal.celebrate > 0.0:
				celebrating[i] = goal
			continue
		if keys.has(goal.key) or quiet or not _achieved(goal):
			continue
		goal.celebrate = CELEBRATE_SECONDS
		goal.flash = FLASH_SECONDS
		goal.progress = 1.0 if goal.progress >= 0.0 else -1.0
		goal.detail = ""
		celebrating[i] = goal
		_finish(goal)
	var shown: Array[Goal] = []
	for goal: Goal in current:
		var taken: bool = false
		for index: int in celebrating:
			taken = taken or celebrating[index].key == goal.key
		if not taken:
			shown.append(goal)
	for index: int in celebrating:
		shown.insert(mini(index, shown.size()), celebrating[index])
	_shown = shown.slice(0, MOST)
	_show()


## True while the tracker is on screen: wanted ([kbd]G[/kbd]) and not under the hero sheet or the
## journal.
func is_shown() -> bool:
	return visible


## The goal sentences showing, top first.
func lines() -> Array[String]:
	var all: Array[String] = []
	for goal: Goal in _shown:
		all.append(goal.sentence)
	return all


## The progress of the goal at [param index], from 0 to 1, or -1.0 for a goal with no bar (or no
## goal there).
func progress(index: int) -> float:
	if index < 0 or index >= _shown.size():
		return -1.0
	return _shown[index].progress


## The count or detail beside the goal at [param index] ([code]level 6 of about 9[/code], a
## price), or "".
func detail(index: int) -> String:
	if index < 0 or index >= _shown.size():
		return ""
	return _shown[index].detail


## How to get there, in one sentence, for the goal at [param index]; "" for no goal.
func hint(index: int) -> String:
	if index < 0 or index >= _shown.size():
		return ""
	return _shown[index].hint


## True while the goal at [param index] shows its tick (it was just achieved).
func is_finished(index: int) -> bool:
	return index >= 0 and index < _shown.size() and _shown[index].celebrate > 0.0


## Seconds of the goal at [param index]'s flash left; 0 when still.
func flash(index: int) -> float:
	if index < 0 or index >= _shown.size():
		return 0.0
	return _shown[index].flash


## What clicking the line at [param index] does (spec 042 R1): an upgrade opens the shop, training
## opens the sheet of the hero with the cheapest affordable training on its Training tab, a
## microskill opens its hero's sheet on the Skills tab, a guardian opens the orders, and a depth
## shows the depth ladder (closing the shop, which hides it) with that depth's rung flashing. Each
## panel opens as its own button opens it. A finished goal, or no goal, does nothing.
func press(index: int) -> void:
	var hud: Hud = get_parent() as Hud
	if hud == null or index < 0 or index >= _shown.size() or _shown[index].celebrate > 0.0:
		return
	var goal: Goal = _shown[index]
	match goal.kind:
		Kind.UPGRADE:
			hud.shop.open()
		Kind.TRAINING:
			var trainee: Hero = _cheapest_trainee()
			if trainee != null:
				_open_sheet(hud, trainee.id, HeroSheet.Page.TRAINING)
		Kind.MICROSKILL:
			_open_sheet(hud, goal.hero_id, HeroSheet.Page.SKILLS)
		Kind.GUARDIAN:
			hud.orders.open()
		Kind.DEPTH:
			hud.shop.close()
			hud.ladder.flash(goal.target)
		Kind.VISIT:
			hud.area_map.open()  # spec 053 R6
	advance(0.0)


## What a click on the line at [param index] does, as the tooltip's second sentence
## ([code]Click to open the shop.[/code]); "" for a finished goal or no goal.
func action(index: int) -> String:
	if index < 0 or index >= _shown.size() or _shown[index].celebrate > 0.0:
		return ""
	var goal: Goal = _shown[index]
	if CLICKS.has(goal.kind):
		return CLICKS[goal.kind]
	var hero: Hero = null
	match goal.kind:
		Kind.TRAINING:
			hero = _cheapest_trainee()
		Kind.MICROSKILL:
			hero = _simulation.party.hero(goal.hero_id)
	if hero == null:
		return ""
	var page: String = "training" if goal.kind == Kind.TRAINING else "skills"
	return "Click to open the %s's %s." % [hero.def().display_name, page]


## Every goal that applies now, in the tracker's order, read from the simulation.
func applicable() -> Array[Goal]:
	var found: Array[Goal] = []
	var hud: Hud = get_parent() as Hud
	if hud != null and hud.area_map != null and hud.area_map.news != null:
		found.append_array(hud.area_map.news.visit_goals())  # spec 053 R6: a new area first
	var guardian: Goal = _guardian_goal()
	if guardian != null:
		found.append(guardian)
	# Held back from a guardian (spec 035), the way on is the guardian's goal (spec 039 R3).
	if not _simulation.expedition.is_holding():
		found.append(_depth_goal())
	var skill: Goal = _microskill_goal()
	if skill != null:
		found.append(skill)
	var gold: int = _simulation.party.gold
	var training: int = _cheapest_training()
	if training > 0 and gold >= training:
		found.append(
			Goal.new(
				"train",
				Kind.TRAINING,
				"Train a hero",
				-1.0,
				"%s gold" % Hud.group_thousands(training),
				"Click a hero's frame and spend gold on its Training tab."
			)
		)
	var upgrade: int = _cheapest_upgrade()
	if upgrade > 0 and gold >= upgrade:
		found.append(
			Goal.new(
				"upgrade",
				Kind.UPGRADE,
				"Buy an upgrade",
				-1.0,
				"%s gold" % Hud.group_thousands(upgrade),
				"Open the Shop (U) and spend gold on the whole party."
			)
		)
	return found


## The level a guardian at level [param depth] is balanced for (spec 049: a stage's level, see
## [method Expedition.level_at]): see [constant GUARDIAN_LEVEL_OVER_DEPTH].
static func guardian_level(depth: int) -> int:
	return depth + GUARDIAN_LEVEL_OVER_DEPTH


# --- Reading the simulation ------------------------------------------------------


## The next guardian not yet beaten, when its depth is close enough to the deepest depth.
func _guardian_goal() -> Goal:
	var e: Expedition = _simulation.expedition
	var depth: int = _next_guardian_depth()
	if depth <= 0 or depth - e.deepest_depth > GUARDIAN_WITHIN:
		return null
	var def: MonsterDef = Content.monster(e.guardian_of(depth))
	var who: String = def.display_name if def != null else "guardian"
	var lowest: int = _lowest_level()
	var wanted: int = guardian_level(e.level_at(depth))
	var goal := Goal.new(
		"guardian/%s/%d" % [e.place, depth],
		Kind.GUARDIAN,
		"Beat the %s" % who,
		clampf(float(lowest) / float(maxi(wanted, 1)), 0.0, 1.0),
		"level %d of about %d" % [lowest, wanted],
		"Heroes near level %d can win: fights, training and upgrades get them there." % wanted
	)
	# Spec 035's Hold order keeps the party from the guardian on its depth (or the one above).
	if e.is_holding() and (depth == e.depth or depth == e.depth - 1):
		goal.hint = "The party is holding back on the Hold order: Orders (O) sends it in."
	goal.target = depth
	goal.area = e.place
	goal.done = "Goal: beat the %s" % who
	return goal


## The depth of the first guardian at or below the deepest depth that has never been beaten, or
## 0 if there is none within reach of the tracker.
func _next_guardian_depth() -> int:
	var e: Expedition = _simulation.expedition
	var first: int = maxi(e.deepest_depth, Expedition.GUARDIAN_EVERY)
	first = ceili(float(first) / Expedition.GUARDIAN_EVERY) * Expedition.GUARDIAN_EVERY
	for depth: int in range(
		first, e.deepest_depth + GUARDIAN_WITHIN + 1, Expedition.GUARDIAN_EVERY
	):
		if e.guardian_of(depth) != &"" and not _guardian_beaten(depth):
			return depth
	return 0


## True once the guardian of [param depth] is beaten: the party has been below it, or its chamber
## holds nobody and no fight with it is going on.
func _guardian_beaten(depth: int) -> bool:
	var e: Expedition = _simulation.expedition
	if e.deepest_depth > depth:
		return true
	if e.deepest_depth < depth:
		return false
	var shaft: LabyrinthChamber = _simulation.labyrinth.level(depth).shaft_chamber()
	if shaft == null:
		return false
	if e.battle != null and e.depth == depth and e.chamber() == shaft:
		return false
	return not e.is_populated(depth, shaft.index)


## Reaching the depth below the deepest yet. At the deepest depth its bar counts down to
## auto-push's next push, reads "on the way" once the target is below, and "Auto is off" when
## nothing will take the party deeper.
func _depth_goal() -> Goal:
	var e: Expedition = _simulation.expedition
	var next: int = e.deepest_depth + 1
	var fraction: float = clampf(float(e.depth) / float(next), 0.0, 1.0)
	var detail_text: String = "stage %d of %d" % [e.depth, next]
	var how: String = "The party works its way back down, a stable depth at a time."
	# Spec 039 R3: at the deepest depth the bar follows the timer that decides what comes next.
	if e.depth >= e.deepest_depth and e.target_depth > e.depth:
		fraction = 1.0
		detail_text = "on the way"
		how = "The party is heading down to its target."
	elif e.depth >= e.deepest_depth and e.auto_push and e.depth == e.target_depth:
		var left: float = e.seconds_to_push()
		if e.stable_seconds > 0.0:
			fraction = clampf(1.0 - left / e.stable_seconds, 0.0, 1.0)
		detail_text = "in " + Hud.clock(left)
		how = "Hold this depth until it is stable, and the party moves on by itself."
	elif e.depth >= e.deepest_depth and not e.auto_push:
		fraction = 0.0
		detail_text = "Auto is off"
	if not e.auto_push and e.target_depth < next:
		how = "Raise the target or turn Auto on, and the party heads down."
	var place: String = PlaceText.here(_simulation, next)
	var goal := Goal.new(
		"depth/%s/%d" % [e.place, next], Kind.DEPTH, "Reach " + place, fraction, detail_text, how
	)
	goal.target = next
	goal.area = e.place
	goal.done = "Goal: reached " + place
	return goal


## The microskill nearest to being learned by any hero: the least XP still to earn, the first hero
## in formation order on a tie; null when every hero has all of theirs.
func _microskill_goal() -> Goal:
	var best: Hero = null
	var best_level: int = 0
	var best_skill: MicroskillDef = null
	var best_left: int = 0
	for hero: Hero in _simulation.party.heroes:
		var def: HeroClassDef = hero.def()
		for i: int in mini(def.microskills.size(), def.microskill_levels.size()):
			var level: int = def.microskill_levels[i]
			var skill: MicroskillDef = Content.microskill(def.microskills[i])
			if level <= hero.level or skill == null:
				continue
			var left: int = Hero.xp_for_level(level) - hero.xp
			if best == null or left < best_left:
				best = hero
				best_level = level
				best_skill = skill
				best_left = left
	if best == null:
		return null
	var who: String = best.def().display_name
	var needed: int = maxi(Hero.xp_for_level(best_level), 1)
	var goal := Goal.new(
		"skill/%d/%s" % [best.id, best_skill.id],
		Kind.MICROSKILL,
		"%s learns %s at level %d" % [who, best_skill.display_name, best_level],
		clampf(float(best.xp) / float(needed), 0.0, 1.0),
		"%s XP to go" % Hud.group_thousands(maxi(best_left, 0)),
		"%s: %s, learned with XP from fights." % [best_skill.display_name, _lower(best_skill)]
	)
	goal.target = best_level
	goal.hero_id = best.id
	goal.done = "Goal: %s learned %s" % [who, best_skill.display_name]
	return goal


## The cheapest price of any hero's next training rank, or 0 if none can be bought.
func _cheapest_training() -> int:
	var cheapest: int = 0
	for hero: Hero in _simulation.party.heroes:
		for id: StringName in Content.training_ids():
			var price: int = hero.training_cost(id)
			if price > 0 and (cheapest == 0 or price < cheapest):
				cheapest = price
	return cheapest


## The hero whose next training rank is the cheapest the party can pay for, the first in formation
## on a tie; null when none is affordable.
func _cheapest_trainee() -> Hero:
	var gold: int = _simulation.party.gold
	var best: Hero = null
	var best_price: int = 0
	for hero: Hero in _simulation.party.heroes:
		for id: StringName in Content.training_ids():
			var price: int = hero.training_cost(id)
			if price > 0 and price <= gold and (best == null or price < best_price):
				best = hero
				best_price = price
	return best


## Opens [param hero_id]'s sheet on [param page], as a click on the hero's frame and then its tab
## would.
static func _open_sheet(hud: Hud, hero_id: int, page: HeroSheet.Page) -> void:
	hud.hero_sheet.open(hero_id)
	hud.hero_sheet.open_page(page)


## The cheapest price of any camp upgrade's next rank, or 0 if none can be bought.
func _cheapest_upgrade() -> int:
	var cheapest: int = 0
	for id: StringName in Content.upgrade_ids():
		var price: int = _simulation.upgrades.cost(id)
		if price > 0 and (cheapest == 0 or price < cheapest):
			cheapest = price
	return cheapest


func _lowest_level() -> int:
	return PartyLevels.lowest(_simulation.party)


## True when [param goal], no longer listed, was achieved rather than merely dropped.
func _achieved(goal: Goal) -> bool:
	match goal.kind:
		Kind.GUARDIAN:
			return goal.area == _simulation.expedition.place and _guardian_beaten(goal.target)
		Kind.DEPTH:
			return _simulation.area_progress(goal.area).y >= goal.target
		Kind.MICROSKILL:
			var hero: Hero = _simulation.party.hero(goal.hero_id)
			return hero != null and hero.level >= goal.target
		Kind.VISIT:
			var hud: Hud = get_parent() as Hud
			return hud != null and hud.area_map.news.visited.has(goal.area)
	return false


static func _lower(skill: MicroskillDef) -> String:
	var text: String = skill.description
	return text.left(1).to_lower() + text.substr(1) if not text.is_empty() else text


# --- Reacting and showing --------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	if _world != null and not _world.is_recent(event):
		_stale = true


## Writes [param goal]'s line in the journal and tells the listeners.
func _finish(goal: Goal) -> void:
	var hud: Hud = get_parent() as Hud
	if hud != null and hud.journal != null:
		hud.journal.write(goal.done)
	goal_finished.emit(goal.done)


## Shows the rows for the goals showing and sizes the panel to hold them.
func _show() -> void:
	var hud: Hud = get_parent() as Hud
	var covered: bool = false
	if hud != null:
		covered = hud.hero_sheet != null and hud.hero_sheet.is_open()
		covered = covered or (hud.journal != null and hud.journal.is_open())
		covered = covered or (hud.tally != null and hud.tally.is_open())  # spec 045
	visible = _wanted and not covered
	var width: float = MIN_WIDTH
	var detail_column: float = 0.0
	for goal: Goal in _shown:
		width = maxf(width, Row.needed_width(goal))
		if goal.progress >= 0.0:
			detail_column = maxf(detail_column, PixelText.width(goal.detail))
	var y: float = PADDING + TITLE_HEIGHT
	for i: int in rows.size():
		var row: Row = rows[i]
		row.visible = i < _shown.size()
		if not row.visible:
			continue
		row.position = Vector2(PADDING, y)
		row.show_goal(_shown[i], width - PADDING * 2.0, detail_column)
		y += row.size.y
	if _shown.is_empty():
		y += Row.LINE
	panel.size = Vector2(width, y + PADDING - 1.0)
	var hint_label: Label = panel.get_node("Hint") as Label
	hint_label.position = Vector2(width - PADDING - 2.0 - PixelText.width(HIDE_HINT), PADDING - 1.0)
	panel.queue_redraw()


## One goal as the tracker shows it: what it says, how far along it is, and how to get there.
class Goal:
	extends RefCounted

	## What makes the goal the same goal from frame to frame.
	var key: String
	var kind: Goals.Kind
	var sentence: String
	## 0 to 1, or -1.0 for a goal with no bar.
	var progress: float
	## The count beside it, or "".
	var detail: String
	## How to get there, in one sentence (its tooltip).
	var hint: String
	## The journal's line once achieved.
	var done: String = ""
	## The depth (a guardian's or the one to reach) or the level (a microskill's) it is about.
	var target: int = 0
	## The area a guardian's or depth's goal is in (spec 049).
	var area: StringName = &""
	## The hero a microskill goal is about, or -1.
	var hero_id: int = -1
	## Seconds of its tick left once achieved; 0 before.
	var celebrate: float = 0.0
	## Seconds of its flash left once achieved.
	var flash: float = 0.0

	func _init(
		key_in: String,
		kind_in: Goals.Kind,
		sentence_in: String,
		progress_in: float,
		detail_in: String,
		hint_in: String
	) -> void:
		key = key_in
		kind = kind_in
		sentence = sentence_in
		progress = progress_in
		detail = detail_in
		hint = hint_in


## One goal's row: a dot (a tick once achieved), the sentence, and under it a thin bar with the
## count at its right; a goal with no bar shows its count (a price) at the sentence's right, and a
## gold goal a small [code]>[/code] at the row's right edge (spec 042 R2). The row is a button: lit
## under the mouse as a [HudButton] is, and a left click emits [signal clicked]. A finished goal is
## neither lit nor clicked.
class Row:
	extends Control

	## A left click on the row while its goal is not finished.
	signal clicked

	## A line of text's height, and the bar's height under it.
	const LINE: float = 10.0
	const BAR_HEIGHT: float = 4.0
	## Where the sentence and the bar start, after the dot.
	const TEXT_X: float = 11.0
	## Pixels between the bar and the count after it, and between the sentence and a price.
	const DETAIL_GAP: float = 4.0
	## The bar's least width.
	const MIN_BAR: float = 60.0
	## The bar's colours for each kind of goal: XP and levels in cyan, depth in yellow.
	const BAR_COLOURS: Dictionary[Goals.Kind, Array] = {
		Goals.Kind.GUARDIAN: [&"cyan", &"blue"],
		Goals.Kind.DEPTH: [&"yellow", &"amber"],
		Goals.Kind.MICROSKILL: [&"cyan", &"blue"],
	}
	## A tick in 7x5 pixels, drawn in code: [code]#[/code] is green.
	const TICK: Array[String] = ["......#", ".....#.", "#...#..", ".#.#...", "..#...."]
	## The gold goals' [code]>[/code] in 3x5 pixels, drawn in code: [code]#[/code] is yellow.
	const ARROW: Array[String] = ["#..", ".#.", "..#", ".#.", "#.."]
	## Pixels the arrow takes at a gold goal's right, with the gap before it.
	const ARROW_ROOM: float = 6.0

	var sentence_label: Label
	var detail_label: Label

	var _goal: Goal
	var _bar: Rect2 = Rect2()
	var _arrow: Rect2 = Rect2()
	## True while the mouse is over the row.
	var _hovered: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sentence_label = PixelText.label("", &"white")
		sentence_label.name = "Sentence"
		sentence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sentence_label.position = Vector2(TEXT_X, 0)
		add_child(sentence_label)
		detail_label = PixelText.label("", &"steel")
		detail_label.name = "Detail"
		detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(detail_label)

	## The panel width [param goal] needs to show on one line.
	static func needed_width(goal: Goal) -> float:
		var text: float = TEXT_X + PixelText.width(goal.sentence)
		if goal.progress < 0.0:
			text += DETAIL_GAP + PixelText.width(goal.detail)
			if Row.is_gold(goal):
				text += ARROW_ROOM
		else:
			text = maxf(text, TEXT_X + MIN_BAR + DETAIL_GAP + PixelText.width(goal.detail))
		return text + Goals.PADDING * 2.0 + 2.0

	## Shows [param goal] across [param width] pixels, a bar ending [param detail_column] pixels
	## (and a gap) before the right edge, so every bar in the panel ends in the same place.
	func show_goal(goal: Goal, width: float, detail_column: float) -> void:
		_goal = goal
		var finished: bool = goal.celebrate > 0.0
		# White over the flash's bright fill, then green with the tick.
		var green: bool = finished and goal.flash <= Goals.FLASH_SECONDS / 2.0
		_set_text(sentence_label, goal.sentence, &"green" if green else &"white")
		var price: bool = Row.is_gold(goal)
		_set_text(detail_label, goal.detail, &"yellow" if price else &"steel")
		var right: float = width - 2.0
		_arrow = Rect2()
		if price:
			_arrow = Rect2(right - 3.0, 1.0, 3.0, 5.0)
			right -= ARROW_ROOM
		if goal.progress >= 0.0:
			size = Vector2(width, LINE + BAR_HEIGHT + 5.0)
			detail_label.position = Vector2(right - detail_label.size.x, LINE - 2.0)
			var bar_right: float = right
			if detail_column > 0.0:
				bar_right -= detail_column + DETAIL_GAP
			_bar = Rect2(TEXT_X, LINE + 1.0, maxf(bar_right - TEXT_X, MIN_BAR), BAR_HEIGHT)
		else:
			size = Vector2(width, LINE + 2.0)
			detail_label.position = Vector2(right - detail_label.size.x, 0)
			_bar = Rect2()
		queue_redraw()

	## True for a goal the player can act on with gold now: training and upgrades.
	static func is_gold(goal: Goal) -> bool:
		return goal.kind == Goals.Kind.TRAINING or goal.kind == Goals.Kind.UPGRADE

	## True while the row is lit under the mouse: shown, not finished.
	func is_highlighted() -> bool:
		return _hovered and is_visible_in_tree() and _goal != null and _goal.celebrate <= 0.0

	## Where the gold goals' [code]>[/code] is drawn, in the row's own pixels; empty for others.
	func arrow_rect() -> Rect2:
		return _arrow

	func _gui_input(event: InputEvent) -> void:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
			return
		accept_event()
		if _goal != null and _goal.celebrate <= 0.0:
			clicked.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			_hovered = what == NOTIFICATION_MOUSE_ENTER
			queue_redraw()
		elif what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
			_hovered = false

	func _draw() -> void:
		if _goal == null:
			return
		mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if _goal.celebrate > 0.0 else Control.CURSOR_POINTING_HAND
		)
		if is_highlighted():
			# As a HudButton under the mouse: a slate fill with a steel bevel.
			HudPanel.draw_panel(
				self,
				Rect2(Vector2(-1, -1), size + Vector2(1, -1)),
				Palette.color(&"slate"),
				Palette.color(&"steel"),
				Palette.color(&"ink")
			)
		if _arrow.has_area():
			_draw_pixels(ARROW, _arrow.position, Palette.color(&"yellow"))
		if _goal.flash > 0.0:
			var bright: bool = _goal.flash > Goals.FLASH_SECONDS / 2.0
			var fill: Color = Palette.color(&"forest" if bright else &"dusk")
			var edge: Color = Palette.color(&"green" if bright else &"slate")
			HudPanel.draw_panel(
				self, Rect2(Vector2(-1, -1), size + Vector2(1, -1)), fill, edge, edge
			)
		if _goal.celebrate > 0.0:
			_draw_tick(Vector2(1, 2))
		else:
			draw_rect(Rect2(3, 3, 3, 3), Palette.color(&"steel"))
			draw_rect(Rect2(3, 3, 3, 1), Palette.color(&"silver"))
		if _bar.size.x <= 0.0:
			return
		var colours: Array = BAR_COLOURS.get(_goal.kind, [&"yellow", &"amber"])
		if _goal.celebrate > 0.0:
			colours = [&"green", &"forest"]
		var colour: StringName = colours[0]
		var shade: StringName = colours[1]
		HudPanel.draw_bar(
			self,
			_bar,
			_goal.progress,
			Palette.color(colour),
			Palette.color(shade),
			Palette.color(&"ink")
		)

	func _draw_tick(at: Vector2) -> void:
		_draw_pixels(TICK, at, Palette.color(&"green"))

	## Draws [param pixels] ([code]#[/code] in [param colour]) at [param at], with an ink shadow
	## a pixel below.
	func _draw_pixels(pixels: Array[String], at: Vector2, colour: Color) -> void:
		for y: int in pixels.size():
			for x: int in pixels[y].length():
				if pixels[y][x] == "#":
					draw_rect(Rect2(at + Vector2(x, y + 1), Vector2.ONE), Palette.color(&"ink"))
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), colour)

	func _set_text(label: Label, text: String, colour: StringName) -> void:
		if label.text != text:
			label.text = text
			label.reset_size()
		label.add_theme_color_override(&"font_color", Palette.color(colour))

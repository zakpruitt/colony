class_name Goals
extends Node
## The goals tracker (spec 037): the next few things within reach, each a one-line sentence with a
## thin progress bar or a count. It is a signpost only: it gives no rewards and changes no rules.
## Since spec 062 this node only decides what the goals say; [GoalsView] draws them on the sharp
## layer, under the place panel.
##
## At each [method advance] it reads the simulation and lists the first [constant MOST] goals that
## apply, in this order: beating the next guardian (when its depth is within
## [constant GUARDIAN_WITHIN] of the deepest depth and it has never been beaten), reaching the next
## depth, spending a hero's talent points (spec 055), the microskill nearest to being learned,
## training a hero (spending its paragon points, spec 051), and buying an upgrade. A shown
## goal that is achieved (the guardian slain, the depth reached, the microskill learned) flashes,
## shows a tick for [constant CELEBRATE_SECONDS], writes a line in the journal and emits
## [signal goal_finished]; then the next goal takes its place. A goal achieved in a frame that
## brought old events ([method World.is_recent]: after a stall or time away) is replaced quietly.
##
## [kbd]G[/kbd] hides and shows it; it starts shown. Windows are drawn over it (spec 062 R2), and
## none hides it. Each line has a tooltip ([method hint], then
## what a click does, [method action]), and since spec 042 a click on a line takes the player where
## the goal is managed ([method press]): the shop, a hero's sheet on a tab, the orders, or the
## depth ladder with the goal's rung flashing. A click opens what the HUD's own buttons open and
## changes nothing in the simulation. It moves only in [method advance], so a test can step it
## exactly.

## A shown goal was achieved, in a recent frame: [param sentence] is its journal line.
signal goal_finished(sentence: String)
## The goals were read again (every [method advance]): the view lays itself out (spec 062).
signal refreshed

## The kinds of goal, in the order the tracker prefers them, but a visit to a new area (spec 053)
## comes first and a talent point to spend (spec 055) comes after the depth.
enum Kind { GUARDIAN, DEPTH, MICROSKILL, TRAINING, UPGRADE, VISIT, TALENT }

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
## The title and the key hint the view shows.
const TITLE: String = "Goals"
const HIDE_HINT: String = "G hide"

var _simulation: Simulation
var _world: World
## The goals showing, top first (some may be celebrating).
var _shown: Array[Goal] = []
## Whether the player wants the tracker ([kbd]G[/kbd]).
var _wanted: bool = true
## True once an old event arrives, until the next advance: nothing achieved then is celebrated.
var _stale: bool = false
## True while the tracker is shown (see [method is_shown]).
var _on_screen: bool = true


func _init() -> void:
	name = "Goals"


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
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Reads the goals from the simulation, celebrates a shown goal just achieved, runs the
## celebrations on by [param delta] seconds. Called every frame by the HUD;
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


## True while the tracker is on screen: while it is wanted ([kbd]G[/kbd]).
func is_shown() -> bool:
	return _on_screen


## How many goals are showing.
func count() -> int:
	return _shown.size()


## The goal showing at [param index], top first, or null.
func goal_at(index: int) -> Goal:
	return _shown[index] if index >= 0 and index < _shown.size() else null


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
## opens the sheet of the first hero with paragon points to spend on its Talents tab, a talent
## point opens its hero's sheet on the Talents tab (spec 055), a
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
			var trainee: Hero = _trainee()
			if trainee != null:
				_open_sheet(hud, trainee.id, HeroWindow.Page.TALENTS)
		Kind.MICROSKILL:
			_open_sheet(hud, goal.hero_id, HeroWindow.Page.SKILLS)
		Kind.TALENT:
			_open_sheet(hud, goal.hero_id, HeroWindow.Page.TALENTS)
		Kind.GUARDIAN:
			if hud.windows != null:  # spec 058: the orders are a window on the UI layer
				hud.windows.open_window(UiRoot.ORDERS)
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
			hero = _trainee()
		Kind.MICROSKILL, Kind.TALENT:
			hero = _simulation.party.hero(goal.hero_id)
	if hero == null:
		return ""
	var page: String = "skills"
	if goal.kind == Kind.TRAINING or goal.kind == Kind.TALENT:
		page = "talents"
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
	var talent: Goal = _talent_goal()
	if talent != null:
		found.append(talent)
	var skill: Goal = _microskill_goal()
	if skill != null:
		found.append(skill)
	var gold: int = _simulation.party.gold
	var trainee: Hero = _trainee()
	if trainee != null:
		var points: int = trainee.paragon_points()
		found.append(
			Goal.new(
				"train",
				Kind.TRAINING,
				"Train a hero",
				-1.0,
				"%d point%s" % [points, "" if points == 1 else "s"],
				"Click a hero's frame and spend its paragon points on its Talents tab."
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
	var how: String = "The party works its way back on, a stable stage at a time."
	# Spec 039 R3: at the deepest depth the bar follows the timer that decides what comes next.
	if e.depth >= e.deepest_depth and e.target_depth > e.depth:
		fraction = 1.0
		detail_text = "on the way"
		how = "The party is heading on to its target."
	elif e.depth >= e.deepest_depth and e.auto_push and e.depth == e.target_depth:
		var left: float = e.seconds_to_push()
		if e.stable_seconds > 0.0:
			fraction = clampf(1.0 - left / e.stable_seconds, 0.0, 1.0)
		detail_text = "in " + Hud.clock(left)
		how = "Hold this stage until it is stable, and the party moves on by itself."
	elif e.depth >= e.deepest_depth and not e.auto_push:
		fraction = 0.0
		detail_text = "Auto is off"
	if not e.auto_push and e.target_depth < next:
		how = "Raise the target or turn Auto on, and the party heads on."
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


## Spending the talent points of the first hero in formation with any (spec 055 R8):
## [code]Spend the Knight's talent point[/code]; null when no hero has one.
func _talent_goal() -> Goal:
	for hero: Hero in _simulation.party.heroes:
		var points: int = hero.talent_points()
		if points <= 0:
			continue
		var who: String = hero.def().display_name
		var plural: String = "" if points == 1 else "s"
		var goal := Goal.new(
			"talent/%d" % hero.id,
			Kind.TALENT,
			"Spend the %s's talent point%s" % [who, plural],
			-1.0,
			"%d point%s" % [points, plural],
			"Click the %s's frame and take a node on its Talents tab." % who
		)
		goal.hero_id = hero.id
		return goal
	return null


## The first hero in formation with a paragon point to spend (spec 051), or null.
func _trainee() -> Hero:
	for hero: Hero in _simulation.party.heroes:
		if hero.paragon_points() > 0:
			return hero
	return null


## Opens [param hero_id]'s window on [param page] (spec 060), as a click on the hero's frame and
## then its tab would.
static func _open_sheet(hud: Hud, hero_id: int, page: HeroWindow.Page) -> void:
	if hud.hero_windows != null:
		hud.hero_windows.open(hero_id, page)


## The cheapest price of any camp upgrade's next rank, or 0 if none can be bought. One whose
## resource the party lacks cannot (spec 052).
func _cheapest_upgrade() -> int:
	var cheapest: int = 0
	for id: StringName in Content.upgrade_ids():
		var price: int = _simulation.upgrades.cost(id)
		if not _simulation.upgrades.has_resource_for(id, _simulation.party):
			continue
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


## Works out whether the tracker shows: whenever it is wanted. Windows, the tally's too, are drawn
## over it (spec 062 R2).
func _show() -> void:
	_on_screen = _wanted
	refreshed.emit()


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

extends ColonyTest
## Acceptance tests for specs/037-goals/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, puts the simulation in a situation by hand or by stepping it, and reads the
## HUD's goals tracker. Nothing here assumes how long a depth takes to turn stable (spec 036 retunes
## it): the countdown is read from the expedition.

const SEED: int = 37
const STEP: float = 1.0 / 60.0
const STRONG_LEVEL: int = 40
const TOP_BAND: float = 28.0
const SCREEN: Vector2 = Vector2(640, 360)
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 6000

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()


func after_each() -> void:
	super()
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


# --- Helpers -------------------------------------------------------------------


func _build_hud() -> void:
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	var ui := UiRoot.new()  # spec 060: the hero windows live on the UI layer
	add_child_autofree(ui)
	ui.setup(_sim, _hud, null)


func _goals() -> Goals:
	return _hud.goals


## Raises every hero to [param level], at full health.
func _raise(level: int) -> void:
	for hero: Hero in _sim.party.heroes:
		_level(hero, level)


## Raises [param hero] to [param level]. Unless [param keep_points], the paragon points the levels
## bring (spec 051) are spent at once, so they ask nothing of the player; the talent points
## always are (spec 055).
func _level(hero: Hero, level: int, keep_points: bool = false) -> void:
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
	_spend_talents(hero)
	if not keep_points:
		var quickness: TrainingDef.Stat = TrainingDef.Stat.QUICKNESS
		hero.set_paragon_rank(quickness, hero.paragon_rank(quickness) + hero.paragon_points())
	hero.health = hero.max_health()


## Puts the expedition in a situation: the party on [param depth], the deepest ever
## [param deepest], the last stable depth [param stable], auto-push on.
func _situation(depth: int, deepest: int, stable: int) -> void:
	var e: Expedition = _sim.expedition
	e.depth = depth
	e.x = _sim.labyrinth.level(depth).chambers[0].rect.position.x
	e.deepest_depth = deepest
	e.last_stable_depth = stable
	e.target_depth = depth
	e.auto_push = true
	_hud.advance(STEP)
	_settle()


## Lets any goal finished by jumping from one situation to the next have its moment and go.
func _settle() -> void:
	_hud.advance(STEP)
	_hud.advance(Goals.CELEBRATE_SECONDS + 0.1)


## Puts the party on [param depth] in the tunnel just outside its shaft chamber, walking in,
## with a target one deeper and no auto-push.
func _before_guardian(depth: int) -> void:
	var e: Expedition = _sim.expedition
	var shaft: LabyrinthChamber = _sim.labyrinth.level(depth).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = depth
	e.deepest_depth = maxi(e.deepest_depth, depth)
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


## Steps the simulation until [param done] returns true (true), or the limit (false). The world
## is brought up to date after each tick and the HUD after the last, as a frame would.
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(0.1)
		if done.call():
			_hud.advance(STEP)
			return true
	_hud.advance(STEP)
	return false


func _emit(kind: SimEvent.Kind, amount: int, age: int = 0) -> void:
	_world.sim_event.emit(SimEvent.new(kind, _sim.tick - age, -1, -1, amount))


## The first hero whose class learns a microskill above level 1, and that microskill's level.
func _learner() -> Array:
	for hero: Hero in _sim.party.heroes:
		var def: HeroClassDef = hero.def()
		var lowest: int = 0
		for level: int in def.microskill_levels:
			if level > 1 and (lowest == 0 or level < lowest):
				lowest = level
		if lowest > 0:
			return [hero, lowest]
	return []


func _microskill_at(hero: Hero, level: int) -> MicroskillDef:
	var def: HeroClassDef = hero.def()
	return Content.microskill(def.microskills[def.microskill_levels.find(level)])


func _cheapest_upgrade() -> int:
	var cheapest: int = 0
	for id: StringName in Content.upgrade_ids():
		var price: int = _sim.upgrades.cost(id)
		if price > 0 and (cheapest == 0 or price < cheapest):
			cheapest = price
	return cheapest


func _guardian_name(depth: int) -> String:
	return Content.monster(_sim.expedition.guardian_of(depth)).display_name


func _sentences(goals: Array[Goals.Goal]) -> Array[String]:
	var all: Array[String] = []
	for goal: Goals.Goal in goals:
		all.append(goal.sentence)
	return all


func _rect() -> Rect2:
	return Hud.on_screen(_hud.goals_view)


func _frame(hero: Hero) -> HeroFrameView:
	for frame: HeroFrameView in _hud.frames:
		if frame.hero_id == hero.id:
			return frame
	return null


# --- R1 ------------------------------------------------------------------------


func test_r1_tracker() -> void:
	var goals: Goals = _goals()
	assert_not_null(goals, "the HUD has a goals tracker")
	if goals == null:
		return
	assert_true(goals.is_shown(), "shown at start")
	assert_true(_hud.goals_view.is_visible_in_tree(), "and drawn")
	assert_between(goals.lines().size(), 1, 3, "a new game has goals: %s" % [goals.lines()])

	# Three goals at most, each a line with a bar or a count.
	_sim.party.gold = 1_000_000
	_situation(3, 3, 2)
	assert_eq(goals.lines().size(), 3, "three lines: %s" % [goals.lines()])
	var bars: int = 0
	for i: int in goals.lines().size():
		var row: GoalRow = _hud.goals_view.rows[i]
		assert_true(row.is_visible_in_tree(), "row %d shows" % i)
		assert_eq(row.sentence_label.text, goals.lines()[i], "row %d says its sentence" % i)
		var fraction: float = goals.progress(i)
		if fraction >= 0.0:
			bars += 1
			assert_between(fraction, 0.0, 1.0, "row %d's bar" % i)
		else:
			assert_eq(fraction, -1.0, "no bar is -1")
			assert_ne(goals.detail(i), "", "a goal with no bar shows a count")
	assert_gt(bars, 0, "goals with bars")
	assert_false(_hud.goals_view.rows.size() > 3, "never more than three rows")

	# The panel: under the depth panel, on the left.
	var rect: Rect2 = _rect()
	var depth: Rect2 = Hud.on_screen(_hud.place_panel)
	assert_gte(rect.position.y, depth.end.y, "under the depth panel")
	assert_lte(rect.position.y, depth.end.y + 6.0, "just under it")
	assert_eq(rect.position.x, depth.position.x, "lined up with it on the left")
	assert_lt(rect.end.x, SCREEN.x / 2.0, "on the left")
	for i: int in goals.lines().size():
		assert_true(
			rect.encloses(Hud.on_screen(_hud.goals_view.rows[i])), "row %d is on the panel" % i
		)

	# G hides and shows it.
	press(KEY_G)
	_hud.advance(STEP)
	assert_false(goals.is_shown(), "G hides it")
	assert_false(_hud.goals_view.is_visible_in_tree(), "not drawn")
	press(KEY_G)
	_hud.advance(STEP)
	assert_true(goals.is_shown(), "G shows it again")
	assert_true(_hud.goals_view.is_visible_in_tree(), "drawn")


# --- R2 ------------------------------------------------------------------------


func test_r2_goals_come_from_the_game() -> void:
	var goals: Goals = _goals()
	if goals == null:
		fail_test("no goals tracker")
		return
	var e: Expedition = _sim.expedition
	var learner: Array = _learner()
	assert_false(learner.is_empty(), "a class learns a microskill above level 1")
	if learner.is_empty():
		return
	var hero: Hero = learner[0]
	var skill_level: int = learner[1]
	var skill: MicroskillDef = _microskill_at(hero, skill_level)
	# Every other hero has all their microskills: the learner's is the nearest.
	for other: Hero in _sim.party.heroes:
		if other != hero:
			_level(other, STRONG_LEVEL)
	hero.xp = 10
	var skill_line: String = (
		"%s learns %s at level %d" % [hero.def().display_name, skill.display_name, skill_level]
	)

	# A new game, no gold: the next depth and the microskill.
	_situation(1, 1, 1)
	assert_eq(goals.lines(), ["Reach Mossy Hollow 2", skill_line] as Array[String], "a new game")
	assert_almost_eq(
		goals.progress(1), 10.0 / Hero.xp_for_level(skill_level), 0.001, "the hero's XP"
	)

	# Reach depth N: at the deepest depth, the countdown to stable.
	_situation(3, 3, 2)
	var line: int = goals.lines().find("Reach Mossy Hollow 4")
	assert_ne(line, -1, "the next depth below the deepest: %s" % [goals.lines()])
	var expected: float = 1.0 - e.seconds_to_stable() / e.stable_seconds
	assert_almost_eq(goals.progress(line), expected, 0.001, "the countdown to stable")
	var before: float = goals.progress(line)
	for i: int in Simulation.TICKS_PER_SECOND * 2:
		_sim.step()
	_hud.advance(STEP)
	if e.depth == 3 and e.deepest_depth == 3:
		line = goals.lines().find("Reach Mossy Hollow 4")
		assert_gt(goals.progress(line), before, "it fills as the depth is held")
		expected = 1.0 - e.seconds_to_stable() / e.stable_seconds
		assert_almost_eq(goals.progress(line), expected, 0.001, "still the countdown")
	# Away from the deepest depth: the party's depth against it.
	_situation(2, 4, 2)
	line = goals.lines().find("Reach Mossy Hollow 5")
	assert_ne(line, -1, "the next depth below the deepest: %s" % [goals.lines()])
	assert_almost_eq(goals.progress(line), 2.0 / 5.0, 0.001, "stage 2 of 5")

	# Beat the guardian: within 3 levels of the deepest depth, never beaten.
	_situation(1, 1, 1)
	assert_false(goals.lines()[0].begins_with("Beat"), "depth 5 is 4 below depth 1: no guardian")
	_situation(2, 2, 2)
	var beat: String = "Beat the %s" % _guardian_name(5)
	assert_eq(goals.lines()[0], beat, "the guardian of depth 5, first")
	var lowest: int = hero.level
	assert_almost_eq(goals.progress(0), float(lowest) / 9.0, 0.001, "lowest level against 9")
	assert_eq(goals.detail(0), "level %d of about 9" % lowest, "shown as a count")
	_situation(5, 5, 4)
	assert_eq(goals.lines()[0], beat, "on its depth, still to beat")
	_situation(6, 6, 6)
	assert_false(goals.lines()[0].begins_with("Beat"), "depth 10 is 4 below depth 6")
	_situation(7, 7, 7)
	assert_eq(goals.lines()[0], "Beat the %s" % _guardian_name(10), "the next guardian")
	assert_almost_eq(goals.progress(0), float(lowest) / 14.0, 0.001, "balanced for level 14")

	# The order, and at most three: guardian, depth, microskill before any gold goal.
	_sim.party.gold = 1_000_000
	var strong: Hero = (
		_sim.party.heroes[0] if hero != _sim.party.heroes[0] else _sim.party.heroes[1]
	)
	_level(strong, STRONG_LEVEL + 1, true)
	_situation(2, 2, 2)
	assert_eq(
		goals.lines(),
		[beat, "Reach Mossy Hollow 3", skill_line] as Array[String],
		"the first three"
	)
	var all: Array[String] = _sentences(goals.applicable())
	assert_eq(all, [beat, "Reach Mossy Hollow 3", skill_line, "Train a hero", "Buy an upgrade"])

	# Train a hero once one has paragon points (spec 051), with how many; buy an upgrade once the
	# gold is there, with the price.
	_level(hero, STRONG_LEVEL)
	_level(strong, STRONG_LEVEL + 1)
	_sim.party.gold = 0
	_situation(1, 1, 1)
	assert_eq(goals.lines(), ["Reach Mossy Hollow 2"] as Array[String], "no gold, no gold goals")
	var upgrade: int = _cheapest_upgrade()
	_level(hero, STRONG_LEVEL + 2, true)
	_sim.party.gold = upgrade
	_hud.advance(STEP)
	assert_eq(
		goals.lines(), ["Reach Mossy Hollow 2", "Train a hero", "Buy an upgrade"] as Array[String]
	)
	assert_eq(goals.progress(1), -1.0, "training has no bar")
	assert_eq(goals.detail(1), "2 points", "the points to spend")
	assert_eq(goals.progress(2), -1.0, "an upgrade has no bar")
	assert_eq(goals.detail(2), "%s gold" % Hud.group_thousands(upgrade), "its price")
	_sim.party.gold = upgrade - 1
	_hud.advance(STEP)
	assert_eq(
		goals.lines(), ["Reach Mossy Hollow 2", "Train a hero"] as Array[String], "too poor to buy"
	)

	# The microskill nearest to being learned, by XP still to earn.
	_sim = Simulation.new(SEED)
	_build_hud()
	goals = _goals()
	var nearest: Hero = null
	var nearest_left: int = 0
	var nearest_line: String = ""
	for each: Hero in _sim.party.heroes:
		var def: HeroClassDef = each.def()
		for i: int in def.microskills.size():
			var level: int = def.microskill_levels[i]
			if level <= each.level:
				continue
			var left: int = Hero.xp_for_level(level) - each.xp
			if nearest == null or left < nearest_left:
				nearest = each
				nearest_left = left
				nearest_line = (
					"%s learns %s at level %d"
					% [def.display_name, Content.microskill(def.microskills[i]).display_name, level]
				)
	# Bring the last hero in formation one XP short of its next microskill: it is now nearest.
	var last: Hero = _sim.party.heroes[_sim.party.heroes.size() - 1]
	var last_def: HeroClassDef = last.def()
	var last_level: int = last_def.microskill_levels.max()
	if last_level > 1:
		last.gain_xp(Hero.xp_for_level(last_level) - 1 - last.xp)
		var next_skill: MicroskillDef = _microskill_at(last, last_level)
		_hud.advance(STEP)
		var want: String = (
			"%s learns %s at level %d"
			% [last_def.display_name, next_skill.display_name, last_level]
		)
		assert_true(goals.lines().has(want), "the nearest: %s in %s" % [want, goals.lines()])
	else:
		assert_true(goals.lines().has(nearest_line), "the nearest microskill")


# --- R3 ------------------------------------------------------------------------


func test_r3_finished_goal() -> void:
	var goals: Goals = _goals()
	if goals == null:
		fail_test("no goals tracker")
		return
	watch_signals(goals)
	var e: Expedition = _sim.expedition

	# A depth reached.
	_situation(1, 1, 1)
	assert_eq(goals.lines()[0], "Reach Mossy Hollow 2", "the depth goal shows")
	e.depth = 2
	e.deepest_depth = 2
	_hud.advance(STEP)
	assert_eq(goals.lines()[0], "Reach Mossy Hollow 2", "the finished goal stays a moment")
	assert_true(goals.is_finished(0), "with its tick")
	assert_gt(goals.flash(0), 0.0, "flashing")
	assert_eq(goals.progress(0), 1.0, "its bar full")
	assert_true(goals.lines().has("Reach Mossy Hollow 3"), "the next depth goal shows too")
	assert_true(
		_hud.journal.lines()[0].ends_with("  Goal: reached Mossy Hollow 2"), "a journal line"
	)
	assert_signal_emitted_with_parameters(goals, "goal_finished", ["Goal: reached Mossy Hollow 2"])
	_hud.advance(Goals.FLASH_SECONDS)
	assert_eq(goals.flash(0), 0.0, "the flash is short")
	assert_true(goals.is_finished(0), "the tick stays")
	_hud.advance(Goals.CELEBRATE_SECONDS - Goals.FLASH_SECONDS - 0.1)
	assert_true(goals.is_finished(0), "for 3 seconds")
	_hud.advance(0.2)
	assert_false(goals.lines().has("Reach Mossy Hollow 2"), "then it goes")
	assert_eq(goals.lines(), _sentences(goals.applicable()).slice(0, 3), "the next takes its place")
	for i: int in goals.lines().size():
		assert_false(goals.is_finished(i), "nothing ticked")
	var journal_lines: int = _hud.journal.lines().size()
	_hud.advance(STEP)
	assert_eq(_hud.journal.lines().size(), journal_lines, "written once")

	# A microskill learned.
	var learner: Array = _learner()
	var hero: Hero = learner[0]
	var skill_level: int = learner[1]
	var skill: MicroskillDef = _microskill_at(hero, skill_level)
	for other: Hero in _sim.party.heroes:
		if other != hero:
			_level(other, STRONG_LEVEL)
	_settle()
	var who: String = hero.def().display_name
	var skill_line: String = "%s learns %s at level %d" % [who, skill.display_name, skill_level]
	var index: int = goals.lines().find(skill_line)
	assert_ne(index, -1, "the microskill goal shows: %s" % [goals.lines()])
	_level(hero, skill_level)
	_hud.advance(STEP)
	assert_eq(goals.lines().find(skill_line), index, "it stays in its place")
	assert_true(goals.is_finished(index), "with its tick")
	assert_gt(goals.flash(index), 0.0, "flashing")
	var learned: String = "Goal: %s learned %s" % [who, skill.display_name]
	assert_true(_hud.journal.lines()[0].ends_with("  " + learned), "a journal line")
	_hud.advance(Goals.CELEBRATE_SECONDS + 0.1)
	assert_false(goals.lines().has(skill_line), "then it goes")

	# A guardian slain.
	_raise(STRONG_LEVEL)
	_situation(5, 5, 4)
	var beat: String = "Beat the %s" % _guardian_name(5)
	assert_eq(goals.lines()[0], beat, "the guardian goal shows")
	_before_guardian(5)
	var shaft: LabyrinthChamber = _sim.labyrinth.level(5).shaft_chamber()
	var slain: Callable = func() -> bool:
		return e.battle == null and not e.is_populated(5, shaft.index)
	assert_true(_step_until(slain), "the guardian is slain")
	assert_eq(goals.lines()[0], beat, "the finished goal stays a moment")
	assert_true(goals.is_finished(0), "with its tick")
	assert_gt(goals.flash(0), 0.0, "flashing")
	var found: bool = false
	for written: String in _hud.journal.lines().slice(0, 5):
		found = found or written.ends_with("  Goal: beat the %s" % _guardian_name(5))
	assert_true(found, "a journal line: %s" % [_hud.journal.lines().slice(0, 5)])
	_hud.advance(Goals.CELEBRATE_SECONDS + 0.1)
	assert_false(goals.lines().has(beat), "then it goes")
	assert_eq(goals.lines(), _sentences(goals.applicable()).slice(0, 3), "the next takes its place")


# --- R4 ------------------------------------------------------------------------


func test_r4_frames_point_at_themselves() -> void:
	var windows: HeroWindows = _hud.hero_windows
	for frame: HeroFrameView in _hud.frames:
		assert_not_null(frame.marker, "frame %d has a marker" % frame.hero_id)
		if frame.marker == null:
			return
		assert_false(frame.marker.visible, "frame %d: nothing to do at start" % frame.hero_id)

	# Training: each hero with a paragon point to spend (spec 051).
	# Not the hero whose new microskill is marked below.
	var hero: Hero = _sim.party.heroes[3]
	if hero == _learner()[0]:
		hero = _sim.party.heroes[2]
	var frame: HeroFrameView = _frame(hero)
	_level(hero, Hero.TALENT_POINTS * Hero.TALENT_EVERY + 1, true)
	# The microskills learned on the way are seen first, so the marker is the point alone.
	var sheet: HeroWindow = windows.window_of(hero.id)
	windows.open(hero.id, HeroWindow.Page.SKILLS)
	_hud.advance(STEP)
	sheet.open_page(HeroWindow.Page.STATS)
	sheet.close()
	_hud.advance(STEP)
	assert_true(frame.marker.is_visible_in_tree(), "a paragon point to spend")
	assert_eq(frame.marker.count, 1, "it counts")
	var rect: Rect2 = frame.get_global_rect()
	assert_true(rect.encloses(frame.marker.get_global_rect()), "on the frame, clear of the ticker")
	assert_false(
		frame.marker.get_global_rect().intersects(frame.level_label.get_global_rect()),
		"not over the level"
	)
	# The same rule as the window's Talents tab.
	windows.open(hero.id)
	_hud.advance(STEP)
	assert_eq(frame.marker.visible, sheet.page_marked(HeroWindow.Page.TALENTS), "as the tab")
	sheet.close()
	hero.set_paragon_rank(TrainingDef.Stat.POWER, 1)
	_hud.advance(STEP)
	assert_false(frame.marker.visible, "gone when the point is spent")

	# A newly learned microskill: marked until the hero's Skills page has been open.
	var learner: Array = _learner()
	hero = learner[0]
	frame = _frame(hero)
	var skill_level: int = learner[1]
	_level(hero, skill_level)
	_hud.advance(STEP)
	assert_true(frame.marker.visible, "a new microskill")
	sheet = windows.window_of(hero.id)
	windows.open(hero.id, HeroWindow.Page.STATS)
	_hud.advance(STEP)
	assert_true(sheet.page_marked(HeroWindow.Page.SKILLS), "the Skills tab is marked")
	assert_true(frame.marker.visible, "the frame too, until the Skills page is seen")
	sheet.open_page(HeroWindow.Page.SKILLS)
	_hud.advance(STEP)
	assert_false(sheet.page_marked(HeroWindow.Page.SKILLS), "seen on the window")
	assert_false(frame.marker.visible, "and so cleared on the frame")
	sheet.close()
	_hud.advance(STEP)
	assert_false(frame.marker.visible, "it stays cleared")
	for other: HeroFrameView in _hud.frames:
		assert_false(other.marker.visible, "frame %d: nothing to do" % other.hero_id)


# --- R5 ------------------------------------------------------------------------


func test_r5_explains_itself() -> void:
	var goals: Goals = _goals()
	if goals == null:
		fail_test("no goals tracker")
		return
	var tooltip: UiTip = _hud.frame_tip
	var learner: Array = _learner()
	var hero: Hero = learner[0]
	for other: Hero in _sim.party.heroes:
		if other != hero:
			_level(other, STRONG_LEVEL, true)
	_sim.party.gold = 1_000_000
	var seen: Dictionary[String, String] = {}
	for deepest: int in [2, 1]:
		_situation(deepest, deepest, deepest - 1)
		if deepest == 1:
			_level(hero, STRONG_LEVEL)
			_settle()
		for i: int in goals.lines().size():
			var line: String = goals.lines()[i]
			tooltip.point_at(UiTip.NOWHERE)
			_hud.advance(1.0)
			tooltip.point_at(_hud.goals_view.rows[i].get_global_rect().get_center())
			_hud.advance(UiTip.DELAY + 0.01)
			var text: String = tooltip.shown_text()
			var how: String = goals.hint(i)
			# Spec 042 R3: the tooltip is the hint, then what a click does.
			assert_eq(text, how + " " + goals.action(i), "%s: its tooltip" % line)
			assert_true(how.ends_with("."), "%s: one sentence: %s" % [line, how])
			assert_false(how.trim_suffix(".").contains(". "), "%s: only one: %s" % [line, how])
			assert_false(
				tooltip.get_global_rect().intersects(_hud.goals_view.rows[i].get_global_rect()),
				"%s: clear of its line" % line
			)
			seen[line.get_slice(" ", 0)] = text
	tooltip.point_at(UiTip.NOWHERE)
	for kind: String in ["Beat", "Reach", hero.def().display_name, "Train", "Buy"]:
		assert_true(seen.has(kind), "a tooltip for the %s goal: %s" % [kind, seen.keys()])
	_situation(1, 1, 0)
	var depth_line: int = goals.lines().find("Reach Mossy Hollow 2")
	assert_eq(
		goals.hint(depth_line),
		"Hold this stage until it is stable, and the party moves on by itself.",
		"the depth goal at the deepest depth"
	)

	# Under spec 035's Hold order, the guardian's tooltip says the party is holding.
	_situation(5, 5, 4)
	_sim.expedition.guardian_order = Expedition.GuardianOrder.HOLD
	_sim.expedition.target_depth = 6
	_hud.advance(STEP)
	assert_true(_sim.expedition.is_holding(), "the party holds at the guardian")
	var holding: String = goals.hint(0)
	assert_eq(goals.lines()[0], "Beat the %s" % _guardian_name(5), "the guardian goal")
	assert_true(holding.contains("Hold") and holding.contains("(O)"), "says so: %s" % holding)
	assert_true(holding.ends_with(".") and not holding.trim_suffix(".").contains(". "), holding)
	_sim.expedition.guardian_order = Expedition.GuardianOrder.CHALLENGE
	_hud.advance(STEP)
	assert_false(goals.hint(0).contains("Hold"), "not under Challenge: %s" % goals.hint(0))

	# G in the help panel's key list, and its case in spec 030's test.
	var listed: bool = false
	for entry: Array in KeyBook.entries():
		listed = listed or KeyBook.keycodes(str(entry[0])).has(KEY_G)
	assert_true(listed, "G is in the help panel's keys")
	var source: String = FileAccess.get_file_as_string(
		"res://tests/acceptance/test_030_help_and_hints.gd"
	)
	assert_true(source.contains('"G":'), "spec 030's test checks what G does")


# --- R6 ------------------------------------------------------------------------


func test_r6_out_of_the_way() -> void:
	var goals: Goals = _goals()
	if goals == null:
		fail_test("no goals tracker")
		return
	# The widest goals: a long guardian name, a long microskill line, a long price.
	_sim.party.gold = 9_876_543
	var learner: Array = _learner()
	var hero: Hero = learner[0]
	_situation(122, 122, 121)
	assert_eq(goals.lines().size(), 3, "three lines")
	var rect: Rect2 = _rect()
	assert_gte(rect.position.y, TOP_BAND, "below the top band")
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(rect), "on the screen")
	var others: Array[Control] = [_hud.place_panel, _hud.purse, _hud.ladder, _hud.boss_bar]
	for frame: HeroFrameView in _hud.frames:
		others.append(frame)
	for control: Control in others:
		var each: Rect2 = Hud.on_screen(control)
		assert_false(rect.intersects(each), "clear of %s %s" % [control.name, each])

	# The journal's ticker, with a long line.
	_emit(SimEvent.Kind.STABLE_DEPTH_REACHED, 123_456)
	_hud.advance(STEP)
	assert_ne(_hud.journal.ticker_text(), "", "the ticker shows")
	var ticker_box: Rect2 = Hud.on_screen(_hud.ticker)
	var strip := Rect2(0, ticker_box.position.y, SCREEN.x, ticker_box.size.y)
	assert_false(rect.intersects(strip), "clear of the ticker's whole strip")

	# The shop, open.
	_hud.shop.open()
	_hud.advance(STEP)
	assert_true(goals.is_shown(), "the shop does not hide it")
	assert_false(rect.intersects(_hud.shop.get_global_rect()), "clear of the shop")
	_hud.shop.close()

	# (Spec 035's orders panel is a window on the UI layer since spec 058, floating over the HUD.)

	# The boss bar, during a guardian fight.
	_raise(STRONG_LEVEL)
	_situation(5, 5, 4)
	_before_guardian(5)
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a guardian fight")
	assert_true(_hud.boss_bar.is_showing(), "the boss bar shows")
	assert_false(_rect().intersects(_hud.boss_bar.get_global_rect()), "clear of the boss bar")

	# Hidden while the tally is open, back when it closes. (Spec 058: the journal is a window on
	# the UI layer now, and spec 060 the hero sheet, which float over the goals and do not hide
	# them.)
	_hud.hero_windows.open(hero.id)
	_hud.advance(STEP)
	assert_true(goals.is_shown(), "a hero window floats over the goals")
	_hud.hero_windows.close_all()
	# Spec 062 R2: the goals stay under the tally too, which is drawn over them.
	_hud.tally.open()
	_hud.advance(STEP)
	assert_true(goals.is_shown(), "shown with the tally open")
	assert_true(_hud.goals_view.is_visible_in_tree(), "and drawn")
	_hud.tally.close()
	_hud.advance(STEP)
	assert_true(goals.is_shown(), "and when the tally closes")
	# Hidden by G, it stays hidden after the tally.
	press(KEY_G)
	_hud.tally.open()
	_hud.advance(STEP)
	_hud.tally.close()
	_hud.advance(STEP)
	assert_false(goals.is_shown(), "hidden by G stays hidden after the tally closes")
	press(KEY_G)
	_hud.advance(STEP)


# --- R7 ------------------------------------------------------------------------


func test_r7_follows_the_simulation() -> void:
	var goals: Goals = _goals()
	if goals == null:
		fail_test("no goals tracker")
		return
	var e: Expedition = _sim.expedition

	# Each frame: gold arriving shows a gold goal at once.
	_raise(STRONG_LEVEL)
	_situation(1, 1, 1)
	assert_eq(goals.lines(), ["Reach Mossy Hollow 2"] as Array[String], "one goal")
	_sim.party.gold = 1_000_000
	_hud.advance(STEP)
	# Only the shop is gold now: training is paragon points (spec 051).
	assert_eq(goals.lines().size(), 2, "the gold goal at once: %s" % [goals.lines()])

	# Old events (after time away or a stall) flash nothing.
	_sim.party.gold = 0
	_situation(1, 1, 1)
	for i: int in World.ANIMATE_TICKS * 2:
		_sim.step()
	_hud.advance(STEP)
	var journal_lines: int = _hud.journal.lines().size()
	assert_true(goals.lines().has("Reach Mossy Hollow 2"), "the depth goal shows")
	e.depth = 2
	e.deepest_depth = 2
	_emit(SimEvent.Kind.DEPTH_CHANGED, 2, World.ANIMATE_TICKS + 1)
	_hud.advance(STEP)
	assert_false(goals.lines().has("Reach Mossy Hollow 2"), "the reached goal is replaced")
	assert_true(goals.lines().has("Reach Mossy Hollow 3"), "by the next")
	for i: int in goals.lines().size():
		assert_false(goals.is_finished(i), "nothing ticked")
		assert_eq(goals.flash(i), 0.0, "nothing flashing")
	for written: String in _hud.journal.lines().slice(
		0, _hud.journal.lines().size() - journal_lines
	):
		assert_false(written.contains("Goal:"), "no goal line: %s" % written)

	# A loaded save shows the right goals at once.
	var data: Dictionary = _sim.to_save()
	data["deepest_depth"] = 8
	data["last_stable_depth"] = 8
	data["target_depth"] = 8
	data["gold"] = 0
	_sim = Simulation.from_save(JSON.parse_string(JSON.stringify(data)) as Dictionary)
	assert_not_null(_sim, "the save loads")
	if _sim == null:
		return
	_build_hud()
	goals = _goals()
	var wanted: Array[String] = ["Beat the %s" % _guardian_name(10), "Reach Mossy Hollow 9"]
	assert_eq(goals.lines(), wanted, "the loaded game's goals, at once")
	for i: int in goals.lines().size():
		assert_false(goals.is_finished(i), "nothing ticked")
		assert_eq(goals.flash(i), 0.0, "nothing flashing")


## Spends every talent point [param hero]'s level has earned (the trunk, then the first path),
## so spec 055's talent goal and defeat-note button do not crowd out what this test is about.
func _spend_talents(hero: Hero) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var order: Array[StringName] = tree.trunk.duplicate()
	order.append_array(tree.path_a)
	hero.set_talents(order.slice(0, TalentRules.talent_points_at(hero.level)))

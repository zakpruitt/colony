extends GutTest
## Acceptance tests for specs/042-goals-you-can-click/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, and
## the UI layer whose windows hold the orders (spec 058), every _process turned off, puts the
## simulation in a situation by hand (as spec 037's tests do), and
## clicks the goals tracker's lines: through [method Goals.press] and through a mouse click pushed
## into the viewport at the line, as the window would send it.

const SEED: int = 42
const STEP: float = 1.0 / 60.0
const STRONG_LEVEL: int = 40
const RICH: int = 1_000_000
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(320, 200)

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## The UI layer, as Main has it: help, the journal and the orders are windows on it (spec 058).
var _ui: UiRoot


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()


func after_each() -> void:
	_mouse(Vector2(-1000, -1000))
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
	# On a layer of its own, as Main has it, so the world's camera does not move it; above GUT's
	# runner (layer 128), whose window would take the mouse.
	var layer := CanvasLayer.new()
	layer.layer = 129
	add_child_autofree(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_ui = UiRoot.new()
	add_child_autofree(_ui)
	_ui.setup(_sim, _hud, null)


func _level(hero: Hero, level: int) -> void:
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
	_spend_talents(hero)
	hero.health = hero.max_health()


## Puts the expedition in a situation (as spec 037's tests do) and lets any goal finished by the
## jump have its moment and go.
func _situation(depth: int, deepest: int, stable: int) -> void:
	var e: Expedition = _sim.expedition
	e.depth = depth
	e.x = _sim.labyrinth.level(depth).chambers[0].rect.position.x
	e.deepest_depth = deepest
	e.last_stable_depth = stable
	e.target_depth = depth
	e.auto_push = true
	_hud.advance(STEP)
	_hud.advance(STEP)
	_hud.advance(Goals.CELEBRATE_SECONDS + 0.1)


## The first hero whose class learns a microskill above level 1, and that microskill's level.
func _learner() -> Array:
	for hero: Hero in _sim.party.heroes:
		var def: HeroClassDef = hero.def()
		for level: int in def.microskill_levels:
			if level > 1:
				return [hero, level]
	return []


## A situation with one microskill goal: every hero but the learner has all of theirs.
func _microskill_situation() -> Hero:
	var learner: Array = _learner()
	var hero: Hero = learner[0]
	for other: Hero in _sim.party.heroes:
		if other != hero:
			_level(other, STRONG_LEVEL)
	hero.xp = 10
	return hero


## The two gold goals, with no microskill left to learn: [Reach Mossy Hollow 2, Train a hero, Buy an
## upgrade].
func _gold_situation() -> void:
	for hero: Hero in _sim.party.heroes:
		_level(hero, STRONG_LEVEL)
	_sim.party.gold = RICH
	_situation(1, 1, 1)


## The first hero in formation with a paragon point to spend (spec 051), or null.
func _trainee() -> Hero:
	for hero: Hero in _sim.party.heroes:
		if hero.paragon_points() > 0:
			return hero
	return null


func _line(sentence: String) -> int:
	return _hud.goals.lines().find(sentence)


func _line_starting(start: String) -> int:
	var lines: Array[String] = _hud.goals.lines()
	for i: int in lines.size():
		if lines[i].begins_with(start):
			return i
	return -1


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## Moves the mouse to [param at], in screen pixels, as the window would.
func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


## Clicks the left button at [param at], in screen pixels, as the window would.
func _click_at(at: Vector2) -> void:
	_mouse(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
	_mouse(AWAY)


## Clicks the middle of goal line [param index].
func _click(index: int) -> void:
	_click_at(_hud.goals.rows[index].get_global_rect().get_center())


## Closes every panel the HUD has, and shows the ladder if L hid it.
func _close_all() -> void:
	_hud.shop.close()
	for id: StringName in _ui.windows.ids():  # the hero windows too (spec 060)
		_ui.windows.close_window(id)
	if not _hud.ladder.is_shown():
		_key(KEY_L)
	_hud.advance(STEP)


## Which of the HUD's panels are open, by name.
func _open_panels() -> Array[String]:
	var open: Array[String] = []
	if _hud.shop.is_open():
		open.append("shop")
	for hero_id: int in _hud.hero_windows.open_ids():  # spec 060: a window per hero
		open.append("sheet %d" % hero_id)
	if _ui.windows.is_open(UiRoot.ORDERS):
		open.append("orders")
	if _ui.windows.is_open(UiRoot.HELP):
		open.append("help")
	if _ui.windows.is_open(UiRoot.JOURNAL):
		open.append("journal")
	return open


## Opens [param hero]'s window on its Talents tab as the player would: a click on its frame
## (unless its window is open already: a click would close it), then on the tab.
func _open_training(hero: Hero) -> void:
	if not _hud.hero_windows.is_open(hero.id):
		_hud.hero_windows.toggle(hero.id)
	_hud.hero_windows.window_of(hero.id).open_page(HeroWindow.Page.TALENTS)


## Clicks goal line [param index] by [param how] ("press" or "mouse").
func _do(how: String, index: int) -> void:
	if how == "press":
		_hud.goals.press(index)
	else:
		_click(index)
	_hud.advance(STEP)


# --- R1 ------------------------------------------------------------------------


func test_r1_click_a_goal() -> void:
	var goals: Goals = _hud.goals
	var sheet: HeroWindows = _hud.hero_windows

	# The gold goals. Two heroes have spent their paragon points (spec 051), so another is next.
	_gold_situation()
	for i: int in 2:
		var spender: Hero = _sim.party.heroes[i]
		for point: int in spender.paragon_points():
			_sim.spend_paragon(spender.id, TrainingDef.Stat.POWER)
	_sim.step()
	_hud.advance(STEP)
	var trainee: Hero = _trainee()
	assert_not_null(trainee, "a hero has a paragon point")
	assert_ne(trainee, _sim.party.heroes[0], "not simply the first hero")
	assert_eq(
		goals.lines(),
		["Reach Mossy Hollow 2", "Train a hero", "Buy an upgrade"] as Array[String],
		"setup"
	)
	for how: String in ["press", "mouse"]:
		# Buy an upgrade: the shop.
		_close_all()
		_do(how, _line("Buy an upgrade"))
		assert_true(_hud.shop.is_open(), "%s on Buy an upgrade opens the shop" % how)
		assert_eq(_open_panels(), ["shop"] as Array[String], "%s: the shop only" % how)
		# Train a hero: the trainee's sheet, on the Talents tab.
		_close_all()
		sheet.window_of(trainee.id).open_page(HeroWindow.Page.STATS)
		_do(how, _line("Train a hero"))
		assert_true(sheet.is_open(), "%s on Train a hero opens a hero window" % how)
		assert_eq(sheet.front().hero_id, trainee.id, "%s: the first with a point's" % how)
		assert_eq(sheet.front().page(), HeroWindow.Page.TALENTS, "%s: on the Talents tab" % how)

	# A microskill: that hero's sheet, on the Skills tab.
	_sim = Simulation.new(SEED)
	_build_hud()
	goals = _hud.goals
	sheet = _hud.hero_windows
	var learner: Hero = _microskill_situation()
	_situation(1, 1, 1)
	var skill: int = _line_starting(learner.def().display_name + " learns")
	assert_ne(skill, -1, "the microskill goal shows: %s" % [goals.lines()])
	for how: String in ["press", "mouse"]:
		_close_all()
		sheet.window_of(learner.id).open_page(HeroWindow.Page.TALENTS)
		_do(how, skill)
		assert_eq(sheet.front().hero_id, learner.id, "%s on the microskill: its window" % how)
		assert_eq(sheet.front().page(), HeroWindow.Page.SKILLS, "%s: on the Skills tab" % how)

	# Beat the guardian: the orders panel.
	_situation(2, 2, 2)
	var guardian: int = _line_starting("Beat the ")
	assert_eq(guardian, 0, "the guardian goal shows: %s" % [goals.lines()])
	for how: String in ["press", "mouse"]:
		_close_all()
		_do(how, guardian)
		assert_true(_ui.windows.is_open(UiRoot.ORDERS), "%s on the guardian opens the orders" % how)
		assert_eq(_open_panels(), ["orders"] as Array[String], "%s: the orders only" % how)

	# Reach depth N: the ladder shows if hidden, and rung N flashes for about a second.
	var ladder: DepthLadder = _hud.ladder
	var depth: int = _line("Reach Mossy Hollow 3")
	assert_ne(depth, -1, "the depth goal shows: %s" % [goals.lines()])
	for how: String in ["press", "mouse"]:
		_close_all()
		_hud.advance(2.0)
		assert_false(ladder.is_flashing(3), "no flash before")
		_key(KEY_L)
		_hud.advance(STEP)
		assert_false(ladder.is_shown(), "L hid the ladder")
		_do(how, depth)
		assert_true(ladder.is_shown(), "%s on Reach Mossy Hollow 3 shows the ladder" % how)
		assert_true(ladder.is_flashing(3), "%s: rung 3 flashes" % how)
		assert_false(ladder.is_flashing(4), "%s: only rung 3" % how)
		assert_false(ladder.is_flashing(2), "%s: only rung 3" % how)
		_hud.advance(0.7)
		assert_true(ladder.is_flashing(3), "%s: still flashing at 0.7 s" % how)
		_hud.advance(0.6)
		assert_false(ladder.is_flashing(3), "%s: done after about a second" % how)
		assert_eq(_open_panels(), [] as Array[String], "%s: no panel" % how)
	# With the shop open (it hides the ladder), the ladder still shows.
	_close_all()
	_hud.shop.open()
	_hud.advance(STEP)
	assert_false(ladder.is_shown(), "the shop hides the ladder")
	goals.press(depth)
	_hud.advance(STEP)
	assert_true(ladder.is_shown(), "shown from under the shop")
	assert_true(ladder.is_flashing(3), "and flashing")

	# A finished goal, showing its tick, does nothing.
	_close_all()
	_hud.advance(2.0)
	_sim.expedition.depth = 3
	_sim.expedition.deepest_depth = 3
	_hud.advance(STEP)
	var done: int = _line("Reach Mossy Hollow 3")
	assert_true(goals.is_finished(done), "the depth goal shows its tick")
	_key(KEY_L)
	_hud.advance(STEP)
	for how: String in ["press", "mouse"]:
		_do(how, done)
		assert_eq(_open_panels(), [] as Array[String], "%s on a finished goal: no panel" % how)
		assert_false(ladder.is_shown(), "%s: the ladder stays hidden" % how)
		assert_false(ladder.is_flashing(3), "%s: no flash" % how)
	assert_true(goals.is_finished(done), "still finished")


# --- R2 ------------------------------------------------------------------------


func test_r2_looks_clickable() -> void:
	var goals: Goals = _hud.goals
	_gold_situation()
	var lines: Array[String] = goals.lines()
	assert_eq(
		lines, ["Reach Mossy Hollow 2", "Train a hero", "Buy an upgrade"] as Array[String], "setup"
	)

	# The highlight under the mouse, on that line only.
	for i: int in lines.size():
		_mouse(goals.rows[i].get_global_rect().get_center())
		_hud.advance(STEP)
		for j: int in lines.size():
			assert_eq(
				goals.rows[j].is_highlighted(), i == j, "mouse on %s: %s lit" % [lines[i], lines[j]]
			)
	_mouse(AWAY)
	_hud.advance(STEP)
	for j: int in lines.size():
		assert_false(goals.rows[j].is_highlighted(), "mouse away: %s not lit" % lines[j])

	# The > on the gold goals, at their right edge, at all times.
	for i: int in lines.size():
		var row: Goals.Row = goals.rows[i]
		var arrow: Rect2 = row.arrow_rect()
		var gold: bool = lines[i] in ["Train a hero", "Buy an upgrade"]
		assert_eq(arrow.has_area(), gold, "%s: a > only on a gold goal" % lines[i])
		if not gold:
			continue
		var whole := Rect2(Vector2.ZERO, row.size)
		assert_true(whole.encloses(arrow), "%s: on its line" % lines[i])
		assert_gte(arrow.position.x, row.size.x - 8.0, "%s: at the right edge" % lines[i])
		var price: Rect2 = Rect2(row.detail_label.position, row.detail_label.size)
		assert_lte(price.end.x, arrow.position.x, "%s: after the price" % lines[i])
	# The other kinds have none.
	_sim = Simulation.new(SEED)
	_build_hud()
	goals = _hud.goals
	_microskill_situation()
	_situation(2, 2, 2)
	assert_eq(goals.lines().size(), 3, "guardian, depth, microskill: %s" % [goals.lines()])
	for i: int in goals.lines().size():
		assert_false(goals.rows[i].arrow_rect().has_area(), "%s: no >" % goals.lines()[i])

	# A finished goal is not lit: it does nothing.
	_sim.expedition.depth = 3
	_sim.expedition.deepest_depth = 3
	_hud.advance(STEP)
	var done: int = _line("Reach Mossy Hollow 3")
	assert_true(goals.is_finished(done), "a finished goal")
	_mouse(goals.rows[done].get_global_rect().get_center())
	_hud.advance(STEP)
	assert_false(goals.rows[done].is_highlighted(), "a finished goal is not lit")


# --- R3 ------------------------------------------------------------------------


func test_r3_tooltip_says_so() -> void:
	var goals: Goals = _hud.goals
	var tooltip: HudTooltip = _hud.tooltip
	var seen: Dictionary[String, String] = {}
	# The lambda reads the HUD of the moment: a local would keep the first one.
	var check: Callable = func() -> void:
		var goals_now: Goals = _hud.goals
		var tip: HudTooltip = _hud.tooltip
		for i: int in goals_now.lines().size():
			var line: String = goals_now.lines()[i]
			tip.point_at(AWAY)
			_hud.advance(1.0)
			tip.point_at(goals_now.rows[i].get_global_rect().get_center())
			_hud.advance(HudTooltip.DELAY + 0.01)
			var text: String = tip.shown_text()
			var action: String = goals_now.action(i)
			assert_true(
				action.begins_with("Click "), "%s: says what a click does: %s" % [line, action]
			)
			assert_true(action.ends_with("."), "%s: a sentence" % line)
			assert_false(action.trim_suffix(".").contains(". "), "%s: one short one" % line)
			assert_lt(action.length(), 40, "%s: short: %s" % [line, action])
			assert_eq(text, goals_now.hint(i) + " " + action, "%s: the hint, then the click" % line)
			assert_true(
				Rect2(Vector2.ZERO, Hud.SCREEN).encloses(tip.box.get_global_rect()),
				"%s: the tooltip fits on the screen" % line
			)
			seen[line.get_slice(" ", 0)] = action
		tip.point_at(AWAY)
		_hud.advance(STEP)

	_gold_situation()
	check.call()
	var shop_action: String = seen.get("Buy", "")
	assert_eq(shop_action, "Click to open the shop.", "the shop's")
	assert_true(str(seen.get("Train", "")).contains("talents"), "the training's: %s" % [seen])
	assert_true(str(seen.get("Reach", "")).contains("ladder"), "the depth's: %s" % [seen])

	_sim = Simulation.new(SEED)
	_build_hud()
	goals = _hud.goals
	tooltip = _hud.tooltip
	var hero: Hero = _microskill_situation()
	_situation(2, 2, 2)
	check.call()
	assert_true(str(seen.get("Beat", "")).contains("orders"), "the guardian's: %s" % [seen])
	var who: String = hero.def().display_name
	assert_true(str(seen.get(who, "")).contains("skills"), "the microskill's: %s" % [seen])
	for kind: String in ["Beat", "Reach", who, "Train", "Buy"]:
		assert_true(seen.has(kind), "a click sentence for the %s goal: %s" % [kind, seen.keys()])

	# A finished goal: no click sentence, the hint alone.
	_sim.expedition.depth = 3
	_sim.expedition.deepest_depth = 3
	_hud.advance(STEP)
	var done: int = _line("Reach Mossy Hollow 3")
	assert_true(goals.is_finished(done), "a finished goal")
	assert_eq(goals.action(done), "", "no click sentence")
	tooltip.point_at(goals.rows[done].get_global_rect().get_center())
	_hud.advance(HudTooltip.DELAY + 0.01)
	assert_eq(tooltip.shown_text(), goals.hint(done), "its tooltip is the hint alone")
	tooltip.point_at(AWAY)


# --- R4 ------------------------------------------------------------------------


func test_r4_nothing_else_changes() -> void:
	var goals: Goals = _hud.goals
	var sheet: HeroWindows = _hud.hero_windows
	_gold_situation()
	var trainee: Hero = _trainee()
	var upgrade: int = _line("Buy an upgrade")
	var train: int = _line("Train a hero")

	# Opening from a goal leaves the same panels open as opening by its own button, from every
	# panel that might be open before.
	var openers: Dictionary[String, Callable] = {
		"help": func() -> void: _ui.windows.open_window(UiRoot.HELP),
		"journal": func() -> void: _ui.windows.open_window(UiRoot.JOURNAL),
		"orders": func() -> void: _ui.bar.buttons[UiRoot.ORDERS].pressed.emit(),
		"shop": func() -> void: _hud.shop_button.pressed.emit(),
		"sheet": func() -> void: sheet.toggle(_sim.party.heroes[0].id),
		"nothing": func() -> void: pass,
	}
	var by_button: Dictionary[String, Callable] = {
		"shop": func() -> void: _hud.shop_button.pressed.emit(),
		"training": func() -> void: _open_training(trainee),
	}
	var by_goal: Dictionary[String, int] = {"shop": upgrade, "training": train}
	for before: String in openers:
		for what: String in by_button:
			if before == what:
				continue  # the Shop button closes an open shop; the goal opens it, as R1 says
			_close_all()
			(openers[before] as Callable).call()
			_hud.advance(STEP)
			(by_button[what] as Callable).call()
			_hud.advance(STEP)
			var expected: Array[String] = _open_panels()
			_close_all()
			(openers[before] as Callable).call()
			_hud.advance(STEP)
			# The goal is clicked with its line on show.
			if _hud.goals.is_shown():
				goals.press(by_goal[what])
				_hud.advance(STEP)
				assert_eq(
					_open_panels(), expected, "%s over %s: as its own button" % [what, before]
				)

	# The orders panel and its button.
	_sim = Simulation.new(SEED)
	_build_hud()
	goals = _hud.goals
	sheet = _hud.hero_windows
	_situation(2, 2, 2)
	for before: String in ["help", "journal", "shop", "nothing"]:
		_close_all()
		match before:
			"help":
				_ui.windows.open_window(UiRoot.HELP)
			"journal":
				_ui.windows.open_window(UiRoot.JOURNAL)
			"shop":
				_hud.shop.open()
		_hud.advance(STEP)
		_ui.bar.buttons[UiRoot.ORDERS].pressed.emit()
		_hud.advance(STEP)
		_ui.bar.refresh()
		var expected: Array[String] = _open_panels()
		var lit: bool = _ui.bar.buttons[UiRoot.ORDERS].lit
		_close_all()
		match before:
			"help":
				_ui.windows.open_window(UiRoot.HELP)
			"journal":
				_ui.windows.open_window(UiRoot.JOURNAL)
			"shop":
				_hud.shop.open()
		_hud.advance(STEP)
		if goals.is_shown():
			goals.press(0)
			_hud.advance(STEP)
			_ui.bar.refresh()
			assert_eq(_open_panels(), expected, "orders over %s: as its own button" % before)
			assert_eq(
				_ui.bar.buttons[UiRoot.ORDERS].lit, lit, "orders over %s: its button lit" % before
			)

	# A hero window floats over the tracker (spec 060: the sheet is windows now); the tracker
	# hides behind the tally, a left-side panel, as before, and comes back.
	_close_all()
	var learner: int = -1
	for i: int in goals.lines().size():
		if goals.lines()[i].contains(" learns "):
			learner = i
	assert_ne(learner, -1, "a microskill goal: %s" % [goals.lines()])
	goals.press(learner)
	_hud.advance(STEP)
	assert_true(sheet.is_open(), "the hero window is open")
	assert_true(goals.is_shown(), "the tracker stays, under the window")
	sheet.close_all()
	_hud.tally.open()
	_hud.advance(STEP)
	assert_false(goals.is_shown(), "the tracker hides under the tally")
	_hud.tally.close()
	_hud.advance(STEP)
	assert_true(goals.is_shown(), "and comes back")

	# Clicks that only open panels leave the simulation as it was: the state hash, the target.
	_close_all()
	var hash_before: int = _sim.state_hash()
	var target: int = _sim.expedition.target_depth
	for i: int in goals.lines().size():
		_close_all()
		goals.press(i)
		_hud.advance(STEP)
		_close_all()
		_click(i)
		_hud.advance(STEP)
	_close_all()
	assert_eq(_sim.state_hash(), hash_before, "no click changed the simulation")
	assert_eq(_sim.expedition.target_depth, target, "the target is as it was")
	assert_eq(_sim.expedition.auto_push, true, "auto-push is as it was")

	# No new key: the tracker still answers only G.
	var source: String = FileAccess.get_file_as_string("res://game/hud/goals.gd")
	var regex := RegEx.create_from_string("KEY_[A-Z0-9_]+")
	var keys: Dictionary[String, bool] = {}
	for found: RegExMatch in regex.search_all(source):
		keys[found.get_string()] = true
	var named: Array[String] = keys.keys()
	assert_eq(named, ["KEY_G"] as Array[String], "the tracker's only key is G")


## Spends every talent point [param hero]'s level has earned (the trunk, then the first path),
## so spec 055's talent goal and defeat-note button do not crowd out what this test is about.
func _spend_talents(hero: Hero) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var order: Array[StringName] = tree.trunk.duplicate()
	order.append_array(tree.path_a)
	hero.set_talents(order.slice(0, TalentRules.talent_points_at(hero.level)))

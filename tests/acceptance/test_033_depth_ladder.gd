extends GutTest
## Acceptance tests for specs/033-depth-ladder/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, puts the simulation in a situation by hand or by stepping it, and reads the
## HUD's depth ladder.

const SEED: int = 1
const STEP: float = 1.0 / 60.0
const STRONG_LEVEL: int = 40
const TOP_BAND: float = 28.0
const SCREEN: Vector2 = Vector2(640, 360)
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 6000
const CLICK_HINT: String = "Click to send the party here"
const STATES: Array[StringName] = [&"held", &"visited", &"unreached"]

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()


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
	# Spec 059: the shop is a window on the UI layer, so the HUD needs one for it to open.
	var ui := UiRoot.new()
	add_child_autofree(ui)
	ui.setup(_sim, _hud, null)
	ui.bar.set_process(false)


# --- Helpers -------------------------------------------------------------------


func _ladder() -> DepthLadder:
	return _hud.ladder


## Raises every hero to [param level], at full health.
func _raise(level: int) -> void:
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


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


## Puts the expedition in a situation: the party on [param depth], the last stable depth
## [param stable], the deepest ever [param deepest] and the target [param target].
func _situation(depth: int, stable: int, deepest: int, target: int) -> void:
	var e: Expedition = _sim.expedition
	_sim.set_auto_push(false)
	e.depth = depth
	e.x = _sim.labyrinth.level(depth).chambers[0].rect.position.x
	e.last_stable_depth = stable
	e.deepest_depth = deepest
	e.target_depth = target
	_hud.advance(STEP)


func _has(depth: int, mark: StringName) -> bool:
	return _ladder().marks(depth).has(mark)


## The one of held, visited and unreached the rung at [param depth] shows.
func _state(depth: int) -> StringName:
	var found: Array[StringName] = []
	for mark: StringName in _ladder().marks(depth):
		if STATES.has(mark):
			found.append(mark)
	assert_eq(found.size(), 1, "depth %d is exactly one of %s: %s" % [depth, STATES, found])
	return found[0] if found.size() == 1 else &""


## A left click at [param at] in the ladder's own coordinates, delivered as the GUI delivers one.
func _click_at(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		_ladder()._gui_input(event)


func _hover_at(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	_ladder()._gui_input(event)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _frames_top() -> float:
	var top: float = SCREEN.y
	for frame: HeroFrame in _hud.frames:
		top = minf(top, frame.get_global_rect().position.y)
	return top


# --- R1 ------------------------------------------------------------------------


func test_r1_ladder_of_depths() -> void:
	var ladder: DepthLadder = _ladder()
	assert_not_null(ladder, "the HUD has a depth ladder")
	if ladder == null:
		return
	assert_eq(DepthLadder.RUNGS, 12, "twelve rungs")
	for depth: int in [1, 5, 13, 40]:
		_situation(depth, 1, depth, depth)
		var first: int = ladder.first_depth()
		var what: String = "at depth %d (rungs %d to %d)" % [depth, first, first + 11]
		assert_gte(first, 1, "%s: the top rung is a real depth" % what)
		assert_between(
			depth, first, first + DepthLadder.RUNGS - 1, "%s: the party is on one" % what
		)
		for rung: int in range(first, first + DepthLadder.RUNGS):
			assert_false(
				ladder.marks(rung).is_empty(), "%s: rung %d shows something" % [what, rung]
			)
			if rung > first:
				var above: Rect2 = ladder.rung_rect(rung - 1)
				assert_lt(above.position.y, ladder.rung_rect(rung).position.y, "shallow at the top")
	_situation(1, 1, 1, 1)
	assert_eq(ladder.first_depth(), 1, "a new game starts at the top")

	var rect: Rect2 = ladder.get_global_rect()
	assert_true(ladder.is_shown(), "it is on screen")
	assert_lte(rect.end.x, SCREEN.x, "on the screen's right edge %s" % rect)
	assert_gte(rect.end.x, SCREEN.x - Hud.MARGIN - 2.0, "against the right edge %s" % rect)
	assert_lte(rect.size.x, 64.0, "narrow %s" % rect)
	assert_gte(rect.position.y, TOP_BAND, "below the top band %s" % rect)
	assert_lte(rect.end.y, _frames_top(), "above the party frames %s" % rect)
	for rung: int in range(ladder.first_depth(), ladder.first_depth() + DepthLadder.RUNGS):
		var row: Rect2 = Rect2(
			rect.position + ladder.rung_rect(rung).position, ladder.rung_rect(rung).size
		)
		assert_true(rect.encloses(row), "rung %d lies inside the panel" % rung)

	# Climbing a depth deeper scrolls the ladder a rung over a few frames, not in one jump.
	_situation(12, 1, 12, 12)
	for i: int in 120:
		_hud.advance(STEP)
	var before: float = ladder.rung_rect(13).position.y
	_situation(13, 1, 13, 13)
	var moved: float = before - ladder.rung_rect(13).position.y
	assert_lt(moved, DepthLadder.PITCH, "the ladder does not jump a whole rung in one frame")
	for i: int in 120:
		_hud.advance(STEP)
	assert_almost_eq(
		before - ladder.rung_rect(13).position.y, DepthLadder.PITCH, 0.5, "it settles a rung on"
	)


# --- R2 ------------------------------------------------------------------------


func test_r2_rungs_say_what_they_are() -> void:
	var ladder: DepthLadder = _ladder()
	if ladder == null:
		fail_test("no ladder")
		return
	_situation(7, 3, 9, 8)
	assert_true(_has(7, &"party"), "the party's depth")
	for depth: int in [1, 2, 3, 4, 5, 6, 8, 9, 10, 11]:
		assert_false(_has(depth, &"party"), "only the party's depth has the party: %d" % depth)
	assert_true(_has(3, &"safe"), "the safe depth")
	assert_eq(_state(3), &"held", "the safe depth is held")
	for depth: int in [1, 2]:
		assert_eq(_state(depth), &"held", "depth %d, above the safe depth, is held" % depth)
		assert_false(_has(depth, &"safe"), "and not the safe depth")
	for depth: int in [4, 5, 6, 7, 8, 9]:
		assert_eq(_state(depth), &"visited", "depth %d, reached but below safe, is visited" % depth)
	for depth: int in [10, 11]:
		assert_eq(_state(depth), &"unreached", "depth %d, never reached, is dim" % depth)
	assert_true(_has(8, &"target"), "the target depth")
	assert_false(_has(7, &"target"), "only the target")
	assert_true(_has(5, &"guardian"), "depth 5 has a guardian")
	assert_true(_has(10, &"guardian"), "depth 10 has a guardian")
	assert_false(_has(5, &"guardian_beaten"), "not beaten yet")
	for depth: int in [1, 2, 3, 4, 6, 7, 8, 9, 11]:
		assert_false(_has(depth, &"guardian"), "no guardian at depth %d" % depth)

	# A guardian before, during and after the fight that beats it.
	_raise(STRONG_LEVEL)
	_before_guardian(5)
	var hash_before: int = _sim.state_hash()
	_hud.advance(STEP)
	assert_eq(_sim.state_hash(), hash_before, "reading the ladder changes nothing in the game")
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "the party meets the guardian")
	assert_true(_has(5, &"guardian"), "during the fight, a guardian")
	assert_false(_has(5, &"guardian_beaten"), "during the fight, not beaten")
	var over: Callable = func() -> bool: return _sim.expedition.battle == null
	assert_true(_step_until(over), "the fight ends")
	assert_true(_sim.party.any_alive(), "the strong party won")
	assert_true(_has(5, &"guardian"), "after the fight, still a guardian depth")
	assert_true(_has(5, &"guardian_beaten"), "crossed out once beaten")
	assert_false(_has(10, &"guardian_beaten"), "the next guardian is not")


# --- R3 ------------------------------------------------------------------------


func test_r3_click_to_steer() -> void:
	var ladder: DepthLadder = _ladder()
	if ladder == null:
		fail_test("no ladder")
		return
	_situation(3, 3, 3, 3)
	ladder.click_depth(6)
	assert_eq(_hud.target_label.text, "6", "the HUD's target shows the asked depth at once")
	assert_true(_has(6, &"target"), "and so does the ladder's arrow")
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 6, "the target after the next step")
	assert_eq(_hud.target_label.text, "6", "the HUD agrees")

	# The - button then steps from there, as if the + button had been pressed three times.
	_hud.minus_button.pressed.emit()
	_sim.step()
	assert_eq(_sim.expedition.target_depth, 5, "- steps on from the clicked target")

	# A click on a rung, delivered through the GUI.
	_hud.advance(STEP)
	var row: Rect2 = ladder.rung_rect(2)
	_click_at(row.get_center())
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 2, "a click on rung 2 sends the party to depth 2")

	# A depth the simulation cannot take as a target is not clickable and changes nothing.
	for depth: int in [0, -4]:
		var hash_before: int = _sim.state_hash()
		ladder.click_depth(depth)
		assert_false(
			ladder.hover_text(depth).contains(CLICK_HINT), "depth %d: no click hint" % depth
		)
		_sim.step()
		assert_eq(
			_sim.expedition.target_depth, 2, "a click on Mossy Hollow %d changes nothing" % depth
		)
		assert_ne(_sim.state_hash(), hash_before, "(the step ran)")
	assert_eq(_hud.target_label.text, "2", "and the HUD's target is unchanged")


# --- R4 ------------------------------------------------------------------------


func test_r4_hover_says_it() -> void:
	var ladder: DepthLadder = _ladder()
	if ladder == null:
		fail_test("no ladder")
		return
	_situation(7, 3, 9, 8)
	var lines: Dictionary[int, String] = {
		2: "Mossy Hollow 2: held",
		3: "Mossy Hollow 3: safe, the party falls back here",
		5: "Mossy Hollow 5: Slime King",
		6: "Mossy Hollow 6: visited",
		7: "Mossy Hollow 7: the party is here",
		10: "Mossy Hollow 10: Slime King",  # spec 049: each area has its own guardian
		12: "Mossy Hollow 12: not reached yet",
	}
	# Spec 043 adds a second line for how the depth looks; the first line is as it was.
	for depth: int in lines:
		var text: String = ladder.hover_text(depth).get_slice("\n", 0)
		assert_eq(text, "%s. %s" % [lines[depth], CLICK_HINT], "depth %d's line" % depth)
	assert_eq(
		ladder.hover_text(8).get_slice("\n", 0),
		"Mossy Hollow 8: visited, the party is heading here",
		"the target, no click"
	)

	# The guardian beaten.
	_raise(STRONG_LEVEL)
	_before_guardian(5)
	var won: bool = false
	for i: int in LIMIT_TICKS:
		_sim.step()
		_hud.advance(STEP)
		won = _has(5, &"guardian_beaten")
		if won:
			break
	assert_true(won, "the guardian is beaten")
	assert_true(
		ladder.hover_text(5).begins_with("Mossy Hollow 5: Slime King (beaten)"),
		ladder.hover_text(5)
	)

	# Resting the mouse on a rung shows the line beside the ladder.
	_situation(7, 3, 9, 8)
	# Spec 047 R1: the hover is the rung under the mouse as the rungs move, so the ladder comes to
	# rest on the new depth before the mouse is put on rung 6.
	for i: int in 120:
		_hud.advance(STEP)
	assert_false(ladder.hint.visible, "no line before the mouse rests on a rung")
	_hover_at(ladder.rung_rect(6).get_center())
	_hud.advance(STEP)
	assert_false(ladder.hint.visible, "not at once: the mouse must rest, as for a HUD tooltip")
	_hud.advance(HudTooltip.DELAY)
	assert_true(ladder.hint.is_visible_in_tree(), "a line shows")
	assert_eq(ladder.hint_text(), ladder.hover_text(6), "the rung's line")
	var hint: Rect2 = ladder.hint.get_global_rect()
	var rect: Rect2 = ladder.get_global_rect()
	assert_lte(hint.end.x, rect.position.x, "beside the ladder, to its left")
	assert_gte(hint.position.x, 0.0, "on screen")
	assert_between(
		hint.get_center().y,
		rect.position.y + ladder.rung_rect(6).position.y - 8.0,
		rect.position.y + ladder.rung_rect(6).end.y + 8.0,
		"level with the rung"
	)
	ladder._notification(Control.NOTIFICATION_MOUSE_EXIT)
	_hud.advance(STEP)
	assert_false(ladder.hint.visible, "it goes when the mouse leaves")


# --- R5 ------------------------------------------------------------------------


func test_r5_it_can_be_hidden() -> void:
	var ladder: DepthLadder = _ladder()
	if ladder == null:
		fail_test("no ladder")
		return
	assert_true(ladder.is_shown(), "shown at start")
	_situation(3, 3, 3, 3)
	_key(KEY_L)
	_hud.advance(STEP)
	assert_false(ladder.is_shown(), "L hides it")
	assert_false(ladder.is_visible_in_tree(), "it is not drawn")
	ladder.click_depth(6)
	_click_at(ladder.rung_rect(6).get_center())
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 3, "hidden, it takes no clicks")
	_key(KEY_L)
	_hud.advance(STEP)
	assert_true(ladder.is_shown(), "L shows it again")
	ladder.click_depth(6)
	_sim.step()
	assert_eq(_sim.expedition.target_depth, 6, "shown, it takes clicks again")


# --- R6 ------------------------------------------------------------------------


func test_r6_stays_out_of_the_way() -> void:
	var ladder: DepthLadder = _ladder()
	if ladder == null:
		fail_test("no ladder")
		return
	_sim.party.gold = 9_876_543
	_situation(120, 119, 120, 123)
	var rect: Rect2 = ladder.get_global_rect()
	assert_gte(rect.position.y, TOP_BAND, "below the top band")
	for control: Control in [_hud.depth_panel, _hud.gold_panel, _hud.shop_tab]:
		assert_false(rect.intersects(control.get_global_rect()), "clear of %s" % control.name)
	for frame: HeroFrame in _hud.frames:
		assert_false(rect.intersects(frame.get_global_rect()), "clear of %s" % frame.name)

	# The journal's ticker, with the longest kind of line it writes.
	var event := SimEvent.new()
	event.kind = SimEvent.Kind.STABLE_DEPTH_REACHED
	event.tick = _sim.tick
	event.amount = 123_456
	_world.sim_event.emit(event)
	_hud.advance(STEP)
	assert_ne(_hud.journal.ticker_text(), "", "the ticker shows")
	var strip := Rect2(
		0, _hud.journal.ticker.get_global_rect().position.y, SCREEN.x, Journal.TICKER_HEIGHT
	)
	assert_false(rect.intersects(strip), "clear of the ticker's whole strip")

	# The boss bar, during a guardian fight.
	_raise(STRONG_LEVEL)
	_before_guardian(5)
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a guardian fight")
	assert_true(_hud.boss_bar.is_showing(), "the boss bar shows")
	assert_false(
		ladder.get_global_rect().intersects(_hud.boss_bar.get_global_rect()), "clear of it"
	)

	# The shop: the ladder hides while it is open.
	_hud.shop.open()
	_hud.advance(STEP)
	assert_false(ladder.is_shown(), "hidden while the shop is open")
	ladder.click_depth(9)
	_sim.step()
	assert_ne(_sim.expedition.target_depth, 9, "and takes no clicks")
	_hud.shop.close()
	_hud.advance(STEP)
	assert_true(ladder.is_shown(), "back when it closes")
	# Hidden by L, it stays hidden after the shop.
	_key(KEY_L)
	_hud.shop.open()
	_hud.advance(STEP)
	_hud.shop.close()
	_hud.advance(STEP)
	assert_false(ladder.is_shown(), "hidden by L stays hidden after the shop closes")


# --- R7 ------------------------------------------------------------------------


func test_r7_follows_the_simulation() -> void:
	var ladder: DepthLadder = _ladder()
	if ladder == null:
		fail_test("no ladder")
		return
	var e: Expedition = _sim.expedition
	# A wipe: the party is on Mossy Hollow 7 with depth 3 safe.
	_situation(7, 3, 7, 7)
	for hero: Hero in _sim.party.heroes:
		hero.health = 0
	var wiped: Callable = func() -> bool: return e.state == Expedition.State.REVIVING
	assert_true(_step_until(wiped), "the party wipes")
	assert_true(_has(7, &"party"), "where it fell, on the frame of the wipe")
	var back: Callable = func() -> bool: return e.state == Expedition.State.TRAVELLING
	assert_true(_step_until(back), "the party revives")
	assert_true(_has(3, &"party"), "back on the safe depth on the next frame")
	assert_true(_has(3, &"safe"), "which is still safe")
	assert_true(_has(3, &"target"), "and the target")
	assert_false(_has(7, &"party"), "no longer on Mossy Hollow 7")
	assert_eq(_state(7), &"visited", "depth 7 stays visited")

	# A new stable depth.
	e.stable_seconds = 2.0
	_sim.set_target_depth(4)
	var stable: Callable = func() -> bool: return e.last_stable_depth == 4
	assert_true(_step_until(stable), "depth 4 becomes stable")
	assert_true(_has(4, &"safe"), "the safe mark moves to depth 4 on the next frame")
	assert_eq(_state(4), &"held", "held")
	assert_false(_has(3, &"safe"), "and leaves depth 3")

	# A loaded save: a new simulation and a new HUD, as Main makes them.
	var data: Dictionary = _sim.to_save()
	data["deepest_depth"] = 11
	data["last_stable_depth"] = 9
	data["target_depth"] = 10
	_sim = Simulation.from_save(JSON.parse_string(JSON.stringify(data)) as Dictionary)
	assert_not_null(_sim, "the save loads")
	if _sim == null:
		return
	_build_hud()
	ladder = _ladder()
	assert_true(_has(9, &"party"), "the loaded party is on its safe depth")
	assert_true(_has(9, &"safe"), "safe")
	assert_true(_has(10, &"target"), "the loaded target")
	assert_eq(_state(11), &"visited", "the deepest depth, visited")
	assert_eq(_state(12), &"unreached", "below it, not reached")
	assert_between(9, ladder.first_depth(), ladder.first_depth() + DepthLadder.RUNGS - 1)

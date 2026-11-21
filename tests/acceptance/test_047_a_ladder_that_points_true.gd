extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/047-a-ladder-that-points-true/spec.md, one per requirement (R7 is in
## test_043_a_ladder_that_warns.gd, test_r3_dangerous_click).
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, puts the simulation in a situation by hand (as spec 033's and 043's tests
## do), and moves the mouse, the wheel and the clicks through the ladder's _gui_input and its
## mouse notifications, as the GUI delivers them.

const SEED: int = 1
## Seconds without the mouse over the ladder before it follows the party again.
const RETURN_SECONDS: float = 5.0
const STRONG_LEVEL: int = 40


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud(false)


# --- Helpers -------------------------------------------------------------------


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
	_settle()


## The top of the ladder as drawn, a depth (fractional while it scrolls), read from a rung's place.
func _scroll() -> float:
	return (StageList.RUNGS_TOP - _ladder().rung_rect(0).position.y) / StageList.PITCH


func _enters() -> void:
	_ladder()._notification(Control.NOTIFICATION_MOUSE_ENTER)


func _leaves() -> void:
	_ladder()._notification(Control.NOTIFICATION_MOUSE_EXIT)


func _move_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	_ladder()._gui_input(event)


## One notch of the mouse wheel over the ladder at [param at]: down is deeper.
func _wheel(down: bool, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.position = at
		_ladder()._gui_input(event)


## Checks that the outline and, while it shows, the hint are those of the rung under the mouse at
## [param at] now; returns false (once) when they are not.
func _points_true(at: Vector2, what: String) -> bool:
	var ladder: StageList = _ladder()
	var under: int = ladder.depth_at(at)
	if ladder.hovered != under:
		assert_eq(ladder.hovered, under, "%s: the outline is on the rung under it" % what)
		return false
	if ladder.hint.visible and ladder.hint_text() != ladder.hover_text(under):
		assert_eq(ladder.hint_text(), ladder.hover_text(under), "%s: the hint is its line" % what)
		return false
	return true


## Advances the HUD [param frames] frames with the mouse still at [param at], checking on each that
## the outline and hint are on the rung under it.
func _watch(at: Vector2, frames: int, what: String) -> void:
	for i: int in frames:
		_hud.advance(STEP)
		if not _points_true(at, "%s, frame %d" % [what, i]):
			return


# --- R1 ------------------------------------------------------------------------


func test_r1_hover_follows_the_rungs() -> void:
	var ladder: StageList = _ladder()
	_situation(8, 3, 20, 8)
	var at: Vector2 = ladder.rung_rect(9).get_center()
	_enters()
	_move_to(at)
	_hud.advance(UiTip.DELAY + STEP)
	assert_eq(ladder.hovered, 9, "setup: the mouse rests on rung 9")
	assert_true(ladder.hint.visible, "setup: its hint shows")
	assert_true(ladder.hint_text().begins_with("Mossy Hollow 9:"), "setup: " + ladder.hint_text())

	# A wheel notch under the still mouse: the rungs move up by one, the mouse is now over 10.
	_wheel(true, at)
	assert_true(_points_true(at, "the notch's own frame"), "on the notch's own frame")
	_watch(at, 120, "a notch down")
	assert_eq(ladder.hovered, 10, "the rung now under the mouse is outlined")
	_hud.advance(UiTip.DELAY)
	assert_true(ladder.hint.visible, "a hint shows")
	assert_eq(ladder.hint_text(), ladder.hover_text(10), "the hint is rung 10's")

	# A notch back up.
	_wheel(false, at)
	_watch(at, 120, "a notch up")
	assert_eq(ladder.hovered, 9, "back on rung 9")

	# The ladder following the party: back to following, then the party goes a depth deeper.
	ladder.follow()
	_watch(at, 120, "following again")
	_sim.expedition.depth = 9
	_sim.expedition.deepest_depth = 20
	_watch(at, 120, "the party a depth deeper")
	assert_eq(ladder.hovered, 10, "the rungs moved a rung: the mouse is over 10")
	assert_eq(ladder.depth_at(at), 10, "(rung 10 is under it)")

	# A flash that scrolls a far rung into view.
	ladder.flash(30)
	assert_true(_points_true(at, "the flash's own frame"), "on the flash's own frame")
	_watch(at, 60, "a flash")
	assert_ne(ladder.hovered, 10, "the rungs jumped to the flash: no longer 10")

	# The mouse leaves: no outline, even as the rungs move.
	_leaves()
	ladder.follow()
	_hud.advance(STEP)
	assert_eq(ladder.hovered, 0, "no outline once the mouse has left")
	assert_false(ladder.hint.visible, "and no hint")


# --- R2 ------------------------------------------------------------------------


func test_r2_goes_back_to_following() -> void:
	var ladder: StageList = _ladder()
	_situation(8, 3, 20, 8)
	var inside: Vector2 = ladder.rung_rect(9).get_center()
	_enters()
	_move_to(inside)
	_wheel(true, inside)
	_settle()
	assert_false(ladder.is_following(), "setup: scrolled away")

	# A press on the ladder dragged off it: the GUI keeps sending it the motion, from outside.
	var button_press := InputEventMouseButton.new()
	button_press.button_index = MOUSE_BUTTON_LEFT
	button_press.pressed = true
	button_press.position = Vector2(-1.0, -1.0)  # off any rung, so the press sets no target
	ladder._gui_input(button_press)
	_leaves()
	var outside: Array[Vector2] = [
		Vector2(-30.0, 40.0), Vector2(-120.0, 60.0), Vector2(200.0, -50.0), Vector2(-5.0, 500.0)
	]
	var seconds: float = 0.0
	var i: int = 0
	while seconds < RETURN_SECONDS - 0.1:
		_move_to(outside[i % outside.size()])
		_hud.advance(0.1)
		seconds += 0.1
		i += 1
	assert_false(ladder.is_following(), "not before 5 seconds")
	_move_to(outside[0])
	_hud.advance(0.2)
	assert_true(ladder.is_following(), "after 5 seconds it follows the party again")

	# The mouse leaving the window: an exit, then nothing more.
	ladder.scroll_by(2)
	_settle()
	_enters()
	_move_to(inside)
	_leaves()
	_hud.advance(RETURN_SECONDS - 0.1)
	assert_false(ladder.is_following(), "not before 5 seconds (window)")
	_hud.advance(0.2)
	assert_true(ladder.is_following(), "after 5 seconds (window)")

	# While the mouse is truly over the ladder, it stays put.
	ladder.scroll_by(2)
	_enters()
	_move_to(inside)
	_hud.advance(RETURN_SECONDS + 1.0)
	assert_false(ladder.is_following(), "the mouse over the ladder keeps it where it is")


# --- R3 ------------------------------------------------------------------------


func test_r3_stays_where_put() -> void:
	var ladder: StageList = _ladder()
	_situation(8, 8, 20, 8)
	var top: int = ladder.first_depth()
	var at: Vector2 = ladder.rung_rect(10).get_center()
	_enters()
	_move_to(at)
	_wheel(true, at)
	_settle()
	assert_false(ladder.is_following(), "setup: one notch ahead")
	assert_eq(ladder.first_depth(), top + 1, "setup: one rung deeper")

	# The party descends a depth: its own view is now the rungs the ladder was scrolled to.
	_sim.expedition.depth = 9
	for frame: int in 60:
		_hud.advance(STEP)
		if ladder.is_following():
			break
	assert_false(ladder.is_following(), "the party reaching the view does not make it follow")
	_sim.expedition.depth = 10
	_settle()
	assert_false(ladder.is_following(), "nor its going on past it")
	assert_eq(ladder.first_depth(), top + 1, "the ladder stays where it was put")

	# The arrow's click.
	_click_ladder(ladder.arrow_rect().get_center())
	assert_true(ladder.is_following(), "the arrow's click brings it back")

	# The timer: one notch ahead again, the mouse gone, the party descends onto the view.
	_settle()
	_wheel(true, at)
	_settle()
	assert_false(ladder.is_following(), "setup: one notch ahead again")
	_leaves()
	_sim.expedition.depth = 11
	var waited: float = 0.0
	while waited < RETURN_SECONDS - 0.2:
		_hud.advance(0.1)
		waited += 0.1
		if ladder.is_following():
			break
	assert_false(ladder.is_following(), "not following before the 5 seconds")
	_hud.advance(0.3)
	assert_true(ladder.is_following(), "the timer brings it back")


# --- R4 ------------------------------------------------------------------------


## Steps the party from depth 8 toward depth 9 until the ladder, following it, has its top part
## way between two rungs; false if it never is. (Spec 054: the party's marker moves a whole rung
## when the shown stage changes, so the ladder is part way while it eases after it.)
func _part_way() -> bool:
	_hud.ladder.follow()
	for p: int in _sim.party.heroes.size():
		var hero: Hero = _sim.party.heroes[p]
		hero.gain_xp(Hero.xp_for_level(STRONG_LEVEL) - hero.xp)
		hero.health = hero.max_health()
	# Deepest 20, so the ladder has room to scroll below the party.
	_situation(8, 8, 20, 9)
	for i: int in LIMIT_TICKS_10_MIN:
		_sim.step()
		for frame: int in 6:  # in frames, so the short ease is caught on its way
			_hud.advance(STEP / 6.0)
			if ZoneCrossing.stage_shown(_sim) != 9:
				continue
			var part: float = _scroll() - floorf(_scroll())
			if part > 0.25 and part < 0.75:
				return true
	return false


## Scrolls the ladder a rung away and has it follow the party again, stopping part way back.
func _easing_back(ladder: StageList) -> bool:
	ladder.scroll_by(1)
	_settle()
	ladder.follow()
	for i: int in 600:
		_hud.advance(STEP / 6.0)
		var part: float = _scroll() - floorf(_scroll())
		if part > 0.25 and part < 0.75:
			return true
	return false


func test_r4_a_notch_is_a_rung() -> void:
	var ladder: StageList = _ladder()
	# Spec 054: the party never stands part way between stages, so the ladder is caught part way
	# through easing to the next one, afresh for each way.
	for down: bool in [true, false]:
		var way: String = "down" if down else "up"
		var caught: bool = _part_way() if down else _easing_back(ladder)
		assert_true(caught, "%s: setup, the ladder part way" % way)
		var before: float = _scroll()
		assert_between(
			before - floorf(before), 0.05, 0.95, "%s: setup, part way (%.2f)" % [way, before]
		)
		var expected: int = floori(before) + 1 if down else floori(before)
		var at: Vector2 = ladder.rung_rect(10).get_center()
		_enters()
		_wheel(down, at)
		assert_eq(ladder.first_depth(), expected, "%s: to the next whole rung" % way)
		_settle()
		var moved: float = absf(_scroll() - before)
		assert_almost_eq(_scroll(), float(expected), 0.01, "%s: it comes to rest there" % way)
		assert_lte(moved, 1.0, "%s: never more than a rung (%.2f from %.2f)" % [way, moved, before])
		_leaves()


# --- R5 ------------------------------------------------------------------------


func test_r5_target_is_easy_to_find() -> void:
	var ladder: StageList = _ladder()
	_situation(7, 3, 9, 10)
	var colours: Dictionary[StringName, StringName] = StageList.MARK_COLOURS
	assert_eq(colours[&"target"], &"yellow", "the target's mark is yellow")
	assert_eq(colours[&"party"], &"white", "the party's mark is white")
	for risk: DepthLadder.Risk in DepthLadder.RISK_COLOURS:
		var risk_colour: StringName = DepthLadder.RISK_COLOURS[risk]
		for mark: StringName in [&"target", &"party"]:
			assert_ne(colours[mark], risk_colour, "the %s's mark is not a risk colour" % mark)

	for mark_depth: Array in [[&"target", 10], [&"party", 7]]:
		var mark: StringName = mark_depth[0]
		var depth: int = mark_depth[1]
		var frame: Rect2 = ladder.mark_rect(depth, mark)
		var row: Rect2 = ladder.rung_rect(depth)
		assert_true(frame.has_area(), "the %s's rung has its mark" % mark)
		assert_true(row.encloses(frame), "inside its row: %s in %s" % [frame, row])
		# Round the number: from left of its widest (three digits) to right of its last column.
		assert_lte(frame.position.x, StageList.NUMBER_RIGHT - PixelText.width("999") - 1.0)
		assert_gte(frame.end.x, StageList.NUMBER_RIGHT + 1.0, "right of the number")
		assert_lte(frame.end.x, StageList.RAIL_LEFT, "clear of the rails")
		assert_gte(frame.size.y, 10.0, "tall enough to frame the number")
		assert_lte(frame.position.y, row.position.y + 5.0, "above the number")
		assert_gte(frame.end.y, row.position.y + 15.0, "below it")
		for other: int in [3, 8, 9]:
			assert_false(
				ladder.mark_rect(other, mark).has_area(), "no %s mark on %d" % [mark, other]
			)

	# The party on its target: both marks, one inside the other.
	_situation(9, 3, 9, 9)
	var outer: Rect2 = ladder.mark_rect(9, &"target")
	var inner: Rect2 = ladder.mark_rect(9, &"party")
	assert_true(outer.has_area() and inner.has_area(), "both marks on one rung")
	assert_true(outer.encloses(inner) and outer != inner, "the party's inside the target's")

	# The arrow back to the party never covers its diamond: the party in the top row...
	ladder.follow()
	_situation(2, 2, 20, 2)
	ladder.scroll_by(1)
	_settle()
	assert_eq(ladder.first_depth(), 2, "setup: the party's rung at the top")
	assert_true(ladder.arrow_points_up(), "setup: the arrow points up")
	var diamond: Rect2 = ladder.mark_rect(2, &"diamond")
	assert_true(diamond.has_area(), "the diamond is drawn")
	assert_false(
		ladder.arrow_rect().intersects(diamond),
		"top: %s clear of the diamond %s" % [ladder.arrow_rect(), diamond]
	)
	# ... and in the bottom row.
	ladder.follow()
	_situation(14, 14, 20, 14)
	ladder.scroll_by(-7)
	_settle()
	assert_eq(ladder.first_depth() + StageList.RUNGS - 1, 14, "setup: the party's at the bottom")
	assert_false(ladder.arrow_points_up(), "setup: the arrow points down")
	diamond = ladder.mark_rect(14, &"diamond")
	assert_false(
		ladder.arrow_rect().intersects(diamond),
		"bottom: %s clear of the diamond %s" % [ladder.arrow_rect(), diamond]
	)
	var panel := Rect2(Vector2.ZERO, ladder.size)
	assert_true(panel.encloses(ladder.arrow_rect()), "the arrow on the ladder")


# --- R6 ------------------------------------------------------------------------


func test_r6_one_rule() -> void:
	var levels: Array[int] = [5, 2, 7, 4]
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _sim.party.heroes[i]
		hero.level = levels[i % levels.size()]
		hero.xp = Hero.xp_for_level(hero.level)
		hero.health = hero.max_health()
	# The lowest hero is dead.
	_sim.party.heroes[1].health = 0
	_hud.advance(STEP)
	assert_eq(PartyLevels.lowest(_sim.party), 2, "the shared rule counts a dead hero")
	_agree("a party with a dead hero")

	# An empty party.
	_sim.party.heroes.clear()
	_agree("an empty party")


func _agree(what: String) -> void:
	var shared: int = PartyLevels.lowest(_sim.party)
	# The ladder says it in the line for a depth far below: dangerous for heroes of that level.
	var line: String = _hud.ladder.hover_text(90).get_slice("\n", 1)
	assert_eq(line, "Dangerous: heroes are level %d" % shared, "%s: the ladder" % what)

extends GutTest
## Acceptance tests for specs/043-a-ladder-that-warns/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, puts the simulation in a situation by hand (as spec 033's tests do), and
## reads, hovers, clicks and scrolls the HUD's depth ladder through its _gui_input, as the GUI
## delivers events to it.

const SEED: int = 1
const STEP: float = 1.0 / 60.0
const CLICK_HINT: String = "Click to send the party here"
## Seconds without the mouse over the ladder before it follows the party again.
const RETURN_SECONDS: float = 5.0

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud


func before_each() -> void:
	_sim = Simulation.new(SEED)
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


# --- Helpers -------------------------------------------------------------------


func _ladder() -> DepthLadder:
	return _hud.ladder


## Makes the party's lowest hero level [param lowest]: the first hero at it, the rest higher.
func _levels(lowest: int) -> void:
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _sim.party.heroes[i]
		hero.level = lowest if i == 0 else lowest + 4
		hero.xp = Hero.xp_for_level(hero.level)
		hero.health = hero.max_health()
	assert_eq(_sim.party.heroes[0].level, lowest, "setup: the lowest hero is level %d" % lowest)


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


## Lets the ladder's scroll come to rest.
func _settle() -> void:
	for i: int in 120:
		_hud.advance(STEP)


## The label showing [param depth]'s number, or null.
func _number(depth: int) -> Label:
	for child: Node in _ladder().get_node("Rungs").get_children():
		var label: Label = child as Label
		if label != null and label.text == str(depth):
			return label
	return null


func _number_colour(depth: int) -> Color:
	var label: Label = _number(depth)
	assert_not_null(label, "rung %d's number is on show" % depth)
	return label.get_theme_color(&"font_color") if label != null else Color.TRANSPARENT


func _risk_colour(risk: DepthLadder.Risk) -> Color:
	return Palette.color(DepthLadder.RISK_COLOURS[risk])


func _click_at(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		_ladder()._gui_input(event)


## The mouse moved onto the ladder at [param at]: the GUI tells it the mouse entered (spec 047
## R2: only that makes the ladder count the mouse as over it), then sends the motion.
func _hover_at(at: Vector2) -> void:
	_ladder()._notification(Control.NOTIFICATION_MOUSE_ENTER)
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


func _mouse_leaves() -> void:
	_ladder()._notification(Control.NOTIFICATION_MOUSE_EXIT)


## True when the rung of [param depth] lies wholly inside the rungs on show.
func _on_show(depth: int) -> bool:
	var row: Rect2 = _ladder().rung_rect(depth)
	var top: float = DepthLadder.RUNGS_TOP
	var bottom: float = top + DepthLadder.RUNGS * DepthLadder.PITCH
	return row.position.y >= top - 0.01 and row.end.y <= bottom + 0.01


## The deepest rung wholly on show.
func _last_on_show() -> int:
	var depth: int = _ladder().first_depth()
	while _on_show(depth + 1):
		depth += 1
	return depth


## Lines in the journal reading [param sentence].
func _count(sentence: String) -> int:
	var found: int = 0
	for line: String in _hud.journal.lines():
		if line.ends_with("  " + sentence):
			found += 1
	return found


# --- R1 ------------------------------------------------------------------------


func test_r1_rungs_show_risk() -> void:
	var ladder: DepthLadder = _ladder()
	var colours: Array[Color] = []
	for risk: DepthLadder.Risk in [
		DepthLadder.Risk.SAFE, DepthLadder.Risk.REACHABLE, DepthLadder.Risk.DANGEROUS
	]:
		var colour: Color = _risk_colour(risk)
		assert_false(colours.has(colour), "each risk has its own colour")
		colours.append(colour)
		for mark: StringName in [&"white", &"yellow", &"green"]:
			assert_ne(colour, Palette.color(mark), "%s is not the %s of a mark" % [risk, mark])

	# [lowest level, safe depth, then each depth with the risk it shows]
	var held: DepthLadder.Risk = DepthLadder.Risk.SAFE
	var near: DepthLadder.Risk = DepthLadder.Risk.REACHABLE
	var far: DepthLadder.Risk = DepthLadder.Risk.DANGEROUS
	var cases: Array = [
		[3, 2, {1: held, 2: held, 3: near, 4: near, 5: far}],
		[6, 4, {4: held, 5: near, 7: near, 8: far, 12: far}],
		[1, 5, {5: held, 6: far}],
	]
	for case: Array in cases:
		var lowest: int = case[0]
		var safe: int = case[1]
		_levels(lowest)
		_situation(safe, safe, safe, safe)
		var expected: Dictionary = case[2]
		for depth: int in expected:
			var risk: DepthLadder.Risk = expected[depth]
			var what: String = "level %d, safe %d, depth %d" % [lowest, safe, depth]
			assert_eq(ladder.risk(depth), risk, "%s: %s" % [what, DepthLadder.Risk.keys()[risk]])
			assert_eq(_number_colour(depth), _risk_colour(risk), "%s: its number's colour" % what)

	# The party's own rung and the target's are coloured by risk too.
	_levels(1)
	_situation(4, 2, 4, 6)
	assert_eq(_number_colour(4), _risk_colour(DepthLadder.Risk.DANGEROUS), "the party's rung")
	assert_eq(_number_colour(6), _risk_colour(DepthLadder.Risk.DANGEROUS), "the target's rung")
	assert_eq(_number_colour(2), _risk_colour(DepthLadder.Risk.SAFE), "the safe rung")

	# The rule says it is a rough guide.
	var source: String = FileAccess.get_file_as_string("res://game/hud/depth_ladder.gd")
	var at: int = source.find("func risk(")
	assert_ne(at, -1, "risk is a function of the ladder")
	var comment: String = source.substr(maxi(at - 600, 0), mini(at, 600))
	assert_true(comment.contains("rough guide"), "its doc comment calls it a rough guide")


# --- R2 ------------------------------------------------------------------------


func test_r2_hover_says_it() -> void:
	var ladder: DepthLadder = _ladder()
	_levels(3)
	_situation(2, 2, 2, 2)
	var lines: Dictionary[int, String] = {
		1: "Mossy Hollow 1: held. %s" % CLICK_HINT,
		3: "Mossy Hollow 3: not reached yet. %s\nWithin reach" % CLICK_HINT,
		4: "Mossy Hollow 4: not reached yet. %s\nWithin reach" % CLICK_HINT,
		5: "Mossy Hollow 5: Slime King. %s\nDangerous: heroes are level 3" % CLICK_HINT,
		6: "Mossy Hollow 6: not reached yet. %s\nDangerous: heroes are level 3" % CLICK_HINT,
	}
	for depth: int in lines:
		assert_eq(ladder.hover_text(depth), lines[depth], "depth %d's hint" % depth)

	# Resting the mouse on each kind of rung shows that hint beside the ladder.
	for depth: int in [1, 4, 6]:
		_hover_at(ladder.rung_rect(depth).get_center())
		_hud.advance(HudTooltip.DELAY + STEP)
		assert_true(ladder.hint.is_visible_in_tree(), "depth %d: a hint shows" % depth)
		assert_eq(ladder.hint_text(), lines[depth], "depth %d: the hint as shown" % depth)
		var hint: Rect2 = ladder.hint.get_global_rect()
		assert_lte(hint.end.x, ladder.get_global_rect().position.x, "left of the ladder")
		var rows: int = 2 if lines[depth].contains("\n") else 1
		assert_gte(hint.size.y, 4.0 + rows * 9.0, "depth %d: room for %d lines" % [depth, rows])
		_mouse_leaves()
		_hud.advance(STEP)


# --- R3 ------------------------------------------------------------------------


func test_r3_dangerous_click() -> void:
	var ladder: DepthLadder = _ladder()
	_levels(3)
	_situation(2, 2, 2, 2)
	var line: String = "Target set to Mossy Hollow 6: dangerous for level 3 heroes"
	_click_at(ladder.rung_rect(6).get_center())
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 6, "a dangerous click still sets the target")
	assert_eq(_hud.place_panel.target_label.text, "6", "and the HUD shows it")
	assert_eq(_hud.journal.ticker_text(), line, "the ticker says so")
	for i: int in 30:
		_sim.step()
		_hud.advance(STEP)
	assert_eq(_count(line), 1, "once")

	# Spec 047 R7: a second click on the same dangerous target writes nothing...
	var lines_before: int = _hud.journal.lines().size()
	_click_at(ladder.rung_rect(6).get_center())
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 6, "the second click keeps the target")
	assert_eq(_hud.journal.lines().size(), lines_before, "the second click writes nothing")
	assert_eq(_count(line), 1, "still once")
	# ... and a change away and back writes it again.
	_click_at(ladder.rung_rect(4).get_center())
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 4, "changed away")
	_click_at(ladder.rung_rect(6).get_center())
	_sim.step()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.target_depth, 6, "and back")
	assert_eq(_count(line), 2, "the change back says it again")

	# A safe or a reachable click: no line.
	_hud.advance(Journal.TICKER_SECONDS + 1.0)
	assert_eq(_hud.journal.ticker_text(), "", "the ticker has gone")
	var written: int = _hud.journal.lines().size()
	for depth: int in [1, 4]:
		_click_at(ladder.rung_rect(depth).get_center())
		_sim.step()
		_hud.advance(STEP)
		assert_eq(
			_sim.expedition.target_depth, depth, "the click on Mossy Hollow %d sets it" % depth
		)
		assert_eq(_hud.journal.ticker_text(), "", "no line for depth %d" % depth)
	assert_eq(_hud.journal.lines().size(), written, "nothing written")


# --- R4 ------------------------------------------------------------------------


func test_r4_scrolls() -> void:
	var ladder: DepthLadder = _ladder()
	_situation(3, 3, 20, 3)
	var middle: Vector2 = ladder.rung_rect(5).get_center()
	assert_true(ladder.is_following(), "it follows the party at first")
	assert_eq(ladder.arrow_rect(), Rect2(), "no arrow while it follows")
	var first: int = ladder.first_depth()
	var before: float = ladder.rung_rect(10).position.y

	# A notch down moves one rung, smoothly.
	_wheel(true, middle)
	_hud.advance(STEP)
	assert_false(ladder.is_following(), "scrolled away")
	assert_lt(before - ladder.rung_rect(10).position.y, DepthLadder.PITCH, "not in one jump")
	_settle()
	assert_eq(ladder.first_depth(), first + 1, "one rung deeper")
	assert_almost_eq(before - ladder.rung_rect(10).position.y, DepthLadder.PITCH, 0.5, "a rung")
	# A notch up comes back.
	_wheel(false, middle)
	_settle()
	assert_eq(ladder.first_depth(), first, "one rung back")

	# The limits: depth 1 at the top, 6 rungs below the deepest depth at the bottom.
	ladder.scroll_by(-50)
	_settle()
	assert_eq(ladder.first_depth(), 1, "no higher than depth 1")
	assert_true(_on_show(1), "depth 1 on show")
	ladder.scroll_by(500)
	_settle()
	assert_eq(_last_on_show(), 26, "no deeper than 6 below the deepest, 20")
	for i: int in 3:
		_wheel(true, middle)
	_settle()
	assert_eq(_last_on_show(), 26, "the wheel stops there too")

	# The arrow points up to the party, at the top edge; a click on it brings the ladder back.
	assert_false(_on_show(3), "the party's rung is off the ladder")
	var arrow: Rect2 = ladder.arrow_rect()
	assert_true(arrow.has_area(), "an arrow shows")
	var panel := Rect2(Vector2.ZERO, ladder.size)
	assert_true(panel.encloses(arrow), "on the ladder")
	assert_lte(arrow.size.x, 16.0, "small")
	assert_lte(arrow.size.y, 10.0, "small")
	assert_lte(arrow.position.y, DepthLadder.RUNGS_TOP + 2.0, "at the top edge, toward the party")
	assert_true(ladder.arrow_points_up(), "pointing up")
	var hash_before: int = _sim.state_hash()
	_click_at(arrow.get_center())
	assert_eq(_sim.state_hash(), hash_before, "a click on the arrow sets no target")
	assert_eq(_sim.expedition.target_depth, 3, "the target is unchanged")
	assert_true(ladder.is_following(), "following again")
	_settle()
	assert_eq(ladder.first_depth(), first, "back on the party")
	assert_true(_on_show(3), "the party's rung on show")
	assert_eq(ladder.arrow_rect(), Rect2(), "the arrow has gone")

	# The party below the view: the arrow at the bottom edge, pointing down.
	_situation(18, 3, 20, 18)
	ladder.scroll_by(-50)
	_settle()
	arrow = ladder.arrow_rect()
	assert_false(ladder.arrow_points_up(), "pointing down")
	assert_gte(
		arrow.end.y,
		DepthLadder.RUNGS_TOP + DepthLadder.RUNGS * DepthLadder.PITCH - 2.0,
		"at the bottom edge"
	)

	# 5 seconds without the mouse over the ladder bring it back; not while the mouse is on it.
	_hover_at(middle)
	_hud.advance(RETURN_SECONDS + 1.0)
	assert_false(ladder.is_following(), "the mouse on the ladder keeps it where it is")
	_mouse_leaves()
	_hud.advance(RETURN_SECONDS - 0.1)
	assert_false(ladder.is_following(), "not before 5 seconds")
	_hud.advance(0.2)
	assert_true(ladder.is_following(), "after 5 seconds it follows the party again")
	_settle()
	assert_true(_on_show(18), "the party's rung on show")


# --- R5 ------------------------------------------------------------------------


func test_r5_flash_is_seen() -> void:
	var ladder: DepthLadder = _ladder()
	_situation(3, 3, 30, 3)
	assert_false(_on_show(20), "setup: rung 20 is off the ladder")
	ladder.flash(20)
	assert_true(ladder.is_flashing(20), "it flashes")
	assert_true(_on_show(20), "on show at once")
	for i: int in 50:
		_hud.advance(STEP)
		if ladder.is_flashing(20):
			assert_true(_on_show(20), "on show while it blinks (frame %d)" % i)
	# A rung already on show: the ladder stays where it is, following the party.
	_situation(3, 3, 30, 3)
	ladder.scroll_by(-50)
	_settle()
	var first: int = ladder.first_depth()
	ladder.flash(5)
	assert_true(_on_show(5), "rung 5 on show")
	assert_eq(ladder.first_depth(), first, "no scroll needed")
	assert_true(ladder.is_following(), "still following")

	# Above the view.
	_situation(25, 25, 30, 25)
	ladder.flash(2)
	for i: int in 50:
		_hud.advance(STEP)
		if ladder.is_flashing(2):
			assert_true(_on_show(2), "rung 2 on show while it blinks (frame %d)" % i)


# --- R6 ------------------------------------------------------------------------


func test_r6_nothing_else_changes() -> void:
	var ladder: DepthLadder = _ladder()
	_situation(3, 3, 20, 3)
	var rect: Rect2 = ladder.get_global_rect()
	# Spec 049 widened it by 8 pixels, from 52, to hold an area's name in its heading.
	assert_eq(rect.size, Vector2(60, 258), "the ladder's size as before")
	assert_eq(
		rect.position,
		Vector2(Hud.SCREEN.x - Hud.MARGIN - 60, Hud.TOP_BAND + DepthLadder.DROP),
		"place"
	)
	var hash_before: int = _sim.state_hash()
	var target: int = _sim.expedition.target_depth
	for i: int in 4:
		_wheel(true, ladder.rung_rect(5).get_center())
		_hover_at(ladder.rung_rect(6 + i).get_center())
		_hud.advance(HudTooltip.DELAY + STEP)
	ladder.scroll_by(3)
	ladder.scroll_by(-2)
	_settle()
	_mouse_leaves()
	_hud.advance(RETURN_SECONDS + 1.0)
	assert_eq(_sim.state_hash(), hash_before, "scrolling and hovering change nothing in the game")
	assert_eq(_sim.expedition.target_depth, target, "the target is as it was")
	assert_eq(ladder.get_global_rect(), rect, "the ladder's rectangle is as it was")

	# Marks are as before.
	_situation(7, 3, 9, 8)
	assert_true(ladder.marks(7).has(&"party"), "the party's mark")
	assert_true(ladder.marks(3).has(&"safe"), "the safe mark")
	assert_true(ladder.marks(8).has(&"target"), "the target's mark")
	assert_true(ladder.marks(5).has(&"guardian"), "the guardian's mark")

	# No new key: the ladder still answers only L.
	var source: String = FileAccess.get_file_as_string("res://game/hud/depth_ladder.gd")
	var regex := RegEx.create_from_string("KEY_[A-Z0-9_]+")
	var keys: Dictionary[String, bool] = {}
	for found: RegExMatch in regex.search_all(source):
		keys[found.get_string()] = true
	assert_eq(keys.keys(), ["KEY_L"], "the ladder's only key is L")

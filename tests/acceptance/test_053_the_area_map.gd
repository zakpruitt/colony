extends GutTest
## Acceptance tests for specs/053-the-area-map/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, on a canvas layer above GUT's (as Main has it), puts the simulation in a
## known place by hand, and drives the map through its methods, the keys and the mouse.

const SEED: int = 42
const STEP: float = 1.0 / 60.0
const STRONG_LEVEL: int = 60
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(320, 200)
const CLAYPITS: StringName = &"claypits"
const MOSSY: StringName = &"mossy_hollow"
const CRYPT: StringName = &"old_crypt"
const EMBER: StringName = &"ember_deep"

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## Spec 059: the map is a window on the UI layer, over the HUD's layer.
var _ui: UiRoot


func after_each() -> void:
	_mouse(AWAY)


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
	var layer := CanvasLayer.new()
	layer.layer = 129
	add_child_autofree(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_ui = UiRoot.new()
	_ui.layer = 130
	add_child_autofree(_ui)
	_ui.setup(_sim, _hud, null)


func _level(level: int) -> void:
	for hero: Hero in _sim.party.heroes:
		hero.level = level
		hero.xp = Hero.xp_for_level(level)
		hero.health = hero.max_health()


## A simulation in Mossy Hollow, safe at [param safe] and furthest at [param furthest].
func _mossy(safe: int, furthest: int) -> void:
	_sim = Simulation.new(SEED)
	_sim.expedition.last_stable_depth = safe
	_sim.expedition.deepest_depth = furthest


func _map() -> AreaMapWindow:
	return _hud.area_map


func _colour(label: Label) -> Color:
	return label.get_theme_color(&"font_color")


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


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


## Clicks [param control]; one on the UI layer (spec 059) once its window has laid out, through
## the UI's scale.
func _click(control: Control) -> void:
	if not _ui.frame.is_ancestor_of(control):
		_click_at(control.get_global_rect().get_center())
		return
	await get_tree().process_frame  # the window refits to what it shows, then lays out
	await get_tree().process_frame
	_click_at(_ui.ui_to_world(control.get_global_rect().get_center()))


## The tooltip shown after resting the mouse on [param control], a piece of the frame of the
## screen (spec 061: its own tooltip).
func _frame_tip(control: Control) -> String:
	_hud.frame_tip.point_at(control.get_global_rect().get_center())
	_hud.frame_tip.advance(UiTip.DELAY + 0.01)
	var text: String = _hud.frame_tip.shown_text()
	_hud.frame_tip.point_at(UiTip.NOWHERE)
	_hud.frame_tip.advance(0.0)
	return text


## The tooltip shown after resting the mouse on [param control]: the UI layer's for a control in
## the map's window (spec 059), the HUD's otherwise.
func _tip(control: Control) -> String:
	if _ui.frame.is_ancestor_of(control):
		return _map().tip.text_for(control)
	_hud.tooltip.point_at(control.get_global_rect().get_center())
	_hud.tooltip.advance(HudTooltip.DELAY + 0.01)
	var text: String = _hud.tooltip.shown_text()
	_hud.tooltip.point_at(HudTooltip.NOWHERE)
	_hud.tooltip.advance(0.0)
	return text


func _journal_count(sentence: String) -> int:
	var count: int = 0
	for line: String in _hud.journal.lines():
		if line.ends_with(sentence):
			count += 1
	return count


## The index of [param sentence] in the journal (newest first), or -1.
func _journal_at(sentence: String) -> int:
	var lines: Array[String] = _hud.journal.lines()
	for i: int in lines.size():
		if lines[i].ends_with(sentence):
			return i
	return -1


## Puts the party on [param depth] just outside its guardian's chamber, walking in, no auto-push.
func _before_guardian(depth: int) -> void:
	var e: Expedition = _sim.expedition
	var shaft: LabyrinthChamber = _sim.labyrinth.level(depth).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = depth
	e.deepest_depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


## One frame: a tick of the simulation, then the world and the HUD.
func _frame() -> void:
	_sim.step()
	_world.sync(0.1)
	_hud.advance(0.1)


# --- R1 ------------------------------------------------------------------------


func test_r1_a_map_of_every_area() -> void:
	_mossy(6, 7)
	_sim.expedition.travel.open[CLAYPITS] = true
	_sim.expedition.travel.stages[CLAYPITS] = Vector2i(2, 4)
	# Spec 052 R12: the map reads the beaten guardians from the simulation, which a game that got
	# here by playing would hold.
	_sim.expedition.travel.guardians_beaten[MOSSY] = true
	_build_hud()
	_map().open()
	_hud.advance(STEP)
	assert_true(_map().is_open(), "the map opens")

	var ids: Array[StringName] = Content.area_ids()
	assert_eq(_map().rows.size(), ids.size(), "a row per area")
	for i: int in ids.size():
		var row: AreaMapRow = _map().rows[i]
		var def: AreaDef = Content.area(ids[i])
		assert_eq(row.area_id, ids[i], "in area order")
		assert_eq(row.name_label.text, def.display_name, "its name")
		var wanted: Array[StringName] = def.monsters.duplicate()
		wanted.append(def.guardian)
		assert_eq(row.monster_ids(), wanted, "%s: its monsters, then its guardian" % ids[i])
		for thumb: MonsterThumb in row.thumbs + [row.guardian_thumb]:
			assert_gt(thumb.size.x, 0.0, "%s is drawn" % thumb.monster_id)
			assert_lte(thumb.size.y, float(MonsterThumb.MOST), "small enough for the row")
		if ids[i] in [MOSSY, CLAYPITS]:
			var level: String = "Stage 1 is level %d" % def.level_at(1)
			assert_eq(row.level_label.text, level, "%s: its first stage's level" % ids[i])

	var mossy: AreaMapRow = _map().row(MOSSY)
	var clay: AreaMapRow = _map().row(CLAYPITS)
	assert_eq(mossy.tag_label.text, "Here", "the area the party is in")
	assert_eq(clay.tag_label.text, "", "and no other")
	assert_eq(mossy.stages_label.text, "Safe 6, furthest 7", "safe and furthest here")
	assert_eq(clay.stages_label.text, "Safe 2, furthest 4", "and in another area")
	assert_true(mossy.guardian_thumb.beaten, "the Slime King is beaten")
	assert_false(clay.guardian_thumb.beaten, "the Clay Colossus is not")
	assert_eq(_map().row(CRYPT).stages_label.text, "Stage 1 is level 11", "a closed area's level")

	# Names on hover.
	assert_eq(_tip(clay.thumbs[0]), "Mud golem", "a monster's name on hover")
	assert_eq(_tip(mossy.guardian_thumb), "Slime King, the guardian: beaten", "the guardian's")
	assert_eq(_tip(clay.guardian_thumb), "Clay Colossus, the guardian: not beaten yet", "unbeaten")


# --- R2 ------------------------------------------------------------------------


func test_r2_closed_areas() -> void:
	_mossy(1, 1)
	_build_hud()
	_map().open()
	_hud.advance(STEP)
	var clay: AreaMapRow = _map().row(CLAYPITS)
	var crypt: AreaMapRow = _map().row(CRYPT)
	var mossy: AreaMapRow = _map().row(MOSSY)
	assert_false(clay.is_open, "the Claypits are closed in a new game")
	assert_eq(
		clay.level_label.text, "Beat the Slime King in Mossy Hollow", "which guardian opens it"
	)
	assert_eq(crypt.level_label.text, "Beat the Clay Colossus in The Claypits", "and this one")
	assert_eq(
		_map().row(EMBER).level_label.text, "Beat the Bone Lord in The Old Crypt", "and the last"
	)
	assert_eq(_colour(clay.name_label), Palette.color(&"slate"), "a closed name is dimmed")
	assert_eq(_colour(mossy.name_label), Palette.color(&"white"), "an open one is not")
	for thumb: MonsterThumb in clay.thumbs + [clay.guardian_thumb]:
		assert_true(thumb.dim, "%s is dimmed" % thumb.monster_id)
		assert_eq(thumb.self_modulate.a, 1.0, "darkened, not faded")
	for thumb: MonsterThumb in mossy.thumbs:
		assert_false(thumb.dim, "an open area's monsters are not")

	await _click(clay)
	_hud.advance(STEP)
	assert_eq(_map().chosen(), &"", "a click on a closed area chooses nothing")
	assert_eq(_map().stage_shown(), 0, "and shows no stage")
	assert_false(_map().go_button.visible, "nor a Go")
	_map().choose(CLAYPITS)
	assert_eq(_map().chosen(), &"", "nor does choose()")
	assert_true(clay.mouse_default_cursor_shape == Control.CURSOR_ARROW, "no hand over it")

	await _click(mossy)
	_hud.advance(STEP)
	assert_eq(_map().chosen(), MOSSY, "a click on an open area chooses it")


# --- R3 ------------------------------------------------------------------------


func test_r3_sending_the_party() -> void:
	_mossy(3, 5)
	_sim.expedition.travel.open[CLAYPITS] = true
	_sim.expedition.travel.stages[CLAYPITS] = Vector2i(2, 4)
	_level(STRONG_LEVEL)
	_build_hud()
	_map().open()
	_map().choose(CLAYPITS)
	_hud.advance(STEP)
	assert_eq(_map().stage_shown(), 2, "starts at the area's safe stage")
	assert_true(_map().go_button.visible, "with Go")
	# Spec 059: the window is taller than this test's 640x360 room, so its foot's buttons are
	# pressed by their signals here; spec 059 R3's test clicks them in a real room.
	_map().minus_button.pressed.emit()
	_map().minus_button.pressed.emit()
	_map().minus_button.pressed.emit()
	assert_eq(_map().stage_shown(), 1, "- goes no higher than stage 1")
	for i: int in 8:
		_map().plus_button.pressed.emit()
	assert_eq(_map().stage_shown(), 5, "+ goes no deeper than one past the furthest")
	_map().step_stage(-2)
	assert_eq(_map().stage_shown(), 3, "set to 3")

	_map().go_button.pressed.emit()
	assert_false(_map().is_open(), "Go closes the map")
	_sim.step()
	var e: Expedition = _sim.expedition
	assert_eq(e.state, Expedition.State.JOURNEYING, "the party is on its way")
	assert_eq(e.area, CLAYPITS, "to the Claypits")
	assert_eq(e.travel.stage, 3, "stage 3")

	# Within the area the party is in, Go sets the target as the ladder does.
	_mossy(3, 5)
	_build_hud()
	_map().open()
	_map().choose(MOSSY)
	assert_eq(_map().stage_shown(), 3, "starts at the safe stage here too")
	_map().step_stage(1)
	_map().go()
	_hud.advance(STEP)
	assert_eq(_hud.place_panel.target_label.text, "4", "the HUD's target shows it at once")
	_sim.step()
	assert_eq(_sim.expedition.target_depth, 4, "the simulation's target")
	assert_ne(_sim.expedition.state, Expedition.State.JOURNEYING, "and no journey")
	assert_eq(_sim.expedition.area, MOSSY, "it stays")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_warning_travels() -> void:
	# Heroes of level 5, safe at Mossy Hollow 3, furthest 6.
	_mossy(3, 6)
	_level(5)
	_sim.expedition.travel.open[CLAYPITS] = true
	_build_hud()
	_map().open()
	_map().choose(MOSSY)
	_hud.advance(STEP)
	var colours: Dictionary[DepthLadder.Risk, Color] = {}
	for risk: DepthLadder.Risk in DepthLadder.RISK_COLOURS:
		colours[risk] = Palette.color(DepthLadder.RISK_COLOURS[risk])
	assert_eq(_colour(_map().stage_label), colours[DepthLadder.Risk.SAFE], "stage 3: safe")
	_map().step_stage(3)
	assert_eq(_map().stage_shown(), 6, "setup: stage 6, level 6")
	assert_eq(_colour(_map().stage_label), colours[DepthLadder.Risk.REACHABLE], "within reach")
	_map().step_stage(1)
	assert_eq(_colour(_map().stage_label), colours[DepthLadder.Risk.DANGEROUS], "7: dangerous")
	# Spec 059 R3: the word beside the stage, and the heroes' level in its tooltip.
	assert_eq(_map().risk_label.text, "Dangerous", "in words too")
	assert_string_contains(_tip(_map().risk_label), "the heroes are level 5", "and why")

	# Judged by the other area's levels: the Claypits start at level 6.
	_map().choose(CLAYPITS)
	assert_eq(_map().stage_shown(), 1, "setup: Claypits 1")
	assert_eq(
		_colour(_map().stage_label), colours[DepthLadder.Risk.REACHABLE], "level 6: within reach"
	)
	_level(2)
	_hud.advance(STEP)
	assert_eq(_colour(_map().stage_label), colours[DepthLadder.Risk.DANGEROUS], "for level 2")

	# A safe Go writes nothing; a dangerous one the ladder's warning, once.
	var warning: String = "Target set to The Claypits 1: dangerous for level 2 heroes"
	_map().choose(MOSSY)
	_map().go()
	assert_eq(_journal_count(": dangerous for level"), 0, "a safe Go writes no warning")
	_map().open()
	_map().choose(CLAYPITS)
	_map().go()
	assert_eq(_journal_count(warning), 1, "a dangerous Go writes the warning once")
	assert_eq(_hud.journal.ticker_text(), warning, "in the ticker as the ladder's does")


func test_r4_warned_once_per_destination() -> void:
	# Another area: a level-2 party sent to Claypits 2 (level 7) is warned once per change.
	_mossy(1, 1)
	_level(2)
	_sim.expedition.travel.open[CLAYPITS] = true
	_sim.expedition.travel.stages[CLAYPITS] = Vector2i(1, 3)
	_build_hud()
	var first: String = "Target set to The Claypits 2: dangerous for level 2 heroes"
	var second: String = "Target set to The Claypits 3: dangerous for level 2 heroes"
	_send(CLAYPITS, 2)
	_send(CLAYPITS, 2)
	assert_eq(_journal_count(first), 1, "twice before a step: once")
	for i: int in 50:
		if _sim.expedition.state == Expedition.State.JOURNEYING:
			break
		_sim.step()
	assert_eq(_sim.expedition.state, Expedition.State.JOURNEYING, "setup: on the way")
	_send(CLAYPITS, 2)
	_sim.step()
	assert_eq(_journal_count(first), 1, "the same destination on the way: no new warning")
	_send(CLAYPITS, 3)
	_sim.step()
	assert_eq(_journal_count(second), 1, "a new destination: warned")
	_send(CLAYPITS, 3)
	assert_eq(_journal_count(second), 1, "and not again")

	# The area the party is in: Mossy Hollow 4 is level 4, dangerous for level-1 heroes.
	_mossy(1, 5)
	_level(1)
	_build_hud()
	var here: String = "Target set to Mossy Hollow 4: dangerous for level 1 heroes"
	_send(MOSSY, 4)
	assert_eq(_journal_count(here), 1, "a dangerous Go here is warned")
	_sim.step()
	_send(MOSSY, 4)
	assert_eq(_journal_count(here), 1, "the same target again is not")


## Chooses [param area] on the map, sets [param stage] and presses Go.
func _send(area: StringName, stage: int) -> void:
	_map().open()
	_map().choose(area)
	_map().step_stage(stage - _map().stage_shown())
	assert_eq(_map().stage_shown(), stage, "setup: stage %d of %s" % [stage, area])
	_map().go()


# --- R5 ------------------------------------------------------------------------


func test_r5_on_the_way() -> void:
	_mossy(1, 1)
	_level(STRONG_LEVEL)
	_sim.expedition.travel.open[CLAYPITS] = true
	_sim.expedition.travel.open[CRYPT] = true
	_build_hud()
	_map().open()
	_map().choose(CLAYPITS)
	_map().go()
	for i: int in 50:
		if _sim.expedition.state == Expedition.State.JOURNEYING:
			break
		_sim.step()
	assert_eq(_sim.expedition.state, Expedition.State.JOURNEYING, "setup: on the way")
	_map().open()
	_hud.advance(STEP)
	var left: float = float(_sim.expedition.travel.arrive_tick - _sim.tick)
	var seconds: int = ceili(left / Simulation.TICKS_PER_SECOND)
	assert_eq(seconds, 10, "setup: ten seconds to go")
	assert_eq(_map().row(CLAYPITS).tag_label.text, "On the way, 10 s", "the destination")
	assert_eq(_map().row(MOSSY).tag_label.text, "", "no Here while on the way")
	for i: int in 31:
		_sim.step()
	_hud.advance(STEP)
	assert_eq(_map().row(CLAYPITS).tag_label.text, "On the way, 7 s", "counting down")

	# A new choice during the journey redirects it.
	_map().choose(CRYPT)
	_map().go()
	_sim.step()
	_map().open()
	_hud.advance(STEP)
	assert_eq(_sim.expedition.area, CRYPT, "turned to the Old Crypt")
	assert_eq(_sim.expedition.state, Expedition.State.JOURNEYING, "still on the way")
	assert_eq(_map().row(CRYPT).tag_label.text, "On the way, 10 s", "the new destination")
	assert_eq(_map().row(CLAYPITS).tag_label.text, "", "the old one is not marked")


# --- R6 ------------------------------------------------------------------------


func test_r6_somewhere_new() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()
	_level(STRONG_LEVEL)
	_before_guardian(5)
	_hud.advance(STEP)
	assert_false(_map().has_mark(), "no mark in a new game")
	assert_eq(_hud.goals.lines().find("Visit The Claypits"), -1, "no goal yet")
	for i: int in 3000:
		if _sim.is_area_open(CLAYPITS):
			break
		_frame()
	assert_true(_sim.is_area_open(CLAYPITS), "setup: the Slime King is beaten")
	_hud.advance(STEP)
	assert_gte(_journal_at("The Claypits is open"), 0, "the journal says so")
	assert_true(_map().has_mark(), "the map's button shows a mark")
	var index: int = _hud.goals.lines().find("Visit The Claypits")
	assert_gte(index, 0, "a goal appears: %s" % [_hud.goals.lines()])
	assert_string_contains(_tip_goal(index), "map", "its tooltip says a click opens the map")

	_hud.goals.press(index)
	assert_true(_map().is_open(), "a click on the goal opens the map")
	assert_false(_map().has_mark(), "and the mark goes once the map is opened")
	_map().close()
	_hud.advance(STEP)
	assert_false(_map().has_mark(), "and stays gone")
	assert_gte(_hud.goals.lines().find("Visit The Claypits"), 0, "the goal stays until the visit")

	_sim.set_destination(CLAYPITS, 1)
	for i: int in 400:
		if _sim.expedition.place == CLAYPITS:
			break
		_frame()
	assert_eq(_sim.expedition.place, CLAYPITS, "setup: arrived")
	_hud.advance(STEP)
	assert_gte(_journal_at("Goal: visited The Claypits"), 0, "the goal is done")
	_hud.advance(Goals.CELEBRATE_SECONDS + 0.1)
	_hud.advance(STEP)
	assert_eq(_hud.goals.lines().find("Visit The Claypits"), -1, "and goes")


func _tip_goal(index: int) -> String:
	return _tip(_hud.goals.rows[index])


func test_r6_opened_before_this_session() -> void:
	# An area opened during time away or before a reload: its events are gone, so the start counts
	# it as unseen until the map is opened.
	_mossy(6, 7)
	_sim.expedition.travel.open[CLAYPITS] = true
	_build_hud()
	_hud.advance(STEP)
	assert_gte(_hud.goals.lines().find("Visit The Claypits"), 0, "the goal")
	assert_true(_map().has_mark(), "and the mark")
	_map().open()
	_map().close()
	_hud.advance(STEP)
	assert_false(_map().has_mark(), "gone once the map has been opened")
	assert_gte(_hud.goals.lines().find("Visit The Claypits"), 0, "the goal stays until the visit")


func test_r6_opened_while_the_map_is_open() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()
	_level(STRONG_LEVEL)
	_before_guardian(5)
	_map().open()
	_hud.advance(STEP)
	for i: int in 3000:
		if _sim.is_area_open(CLAYPITS):
			break
		_frame()
	assert_true(_sim.is_area_open(CLAYPITS), "setup: opened with the map open")
	assert_true(_map().is_open(), "setup: the map stayed open")
	_map().close()
	_hud.advance(STEP)
	assert_false(_map().has_mark(), "it was seen as it opened: no mark")


# --- R7 ------------------------------------------------------------------------


func test_r7_true_in_a_crowded_frame() -> void:
	# The Slime King's death, the journey and the arrival, all stepped before a single frame.
	_sim = Simulation.new(SEED)
	_build_hud()
	_level(STRONG_LEVEL)
	_before_guardian(5)
	_world.sync(0.1)
	_hud.advance(STEP)
	var sent: bool = false
	for i: int in 4000:
		if _sim.expedition.place == CLAYPITS:
			break
		if not sent and _sim.is_area_open(CLAYPITS):
			_sim.set_destination(CLAYPITS, 1)
			sent = true
		_sim.step()
	assert_true(sent, "setup: the Claypits opened")
	assert_eq(_sim.expedition.place, CLAYPITS, "setup: arrived, with no frame between")
	_world.sync(0.1)
	_hud.advance(0.1)

	assert_true(_map().has_mark(), "the mark shows: an area opened")
	assert_eq(_hud.goals.lines().find("Visit The Claypits"), -1, "the visit is already done")
	var opened: int = _journal_at("The Claypits is open")
	var arrived: int = _journal_at("Arrived in The Claypits")
	assert_gte(opened, 0, "the journal has the opening")
	assert_gte(arrived, 0, "and the arrival")
	assert_gt(opened, arrived, "the opening is written before the arrival (newest first)")
	assert_true(_map().news.beaten.has(MOSSY), "the Slime King is heard as Mossy Hollow's")
	assert_false(_map().news.beaten.has(CLAYPITS), "not the Claypits', where the party is now")
	_map().open()
	_hud.advance(STEP)
	assert_eq(_map().row(CLAYPITS).tag_label.text, "Here", "the party is in the Claypits")
	assert_eq(_map().row(MOSSY).tag_label.text, "", "not in Mossy Hollow")
	assert_true(_map().row(MOSSY).guardian_thumb.beaten, "its guardian beaten")
	assert_false(_map().row(CLAYPITS).guardian_thumb.beaten, "the Claypits' not")
	assert_true(_map().row(CLAYPITS).is_open, "the Claypits open")


func test_r7_a_frame_that_ends_on_the_road() -> void:
	# The Slime King's death and the departure in one batch, the frame ending on the road: the
	# live state already names the Claypits (Expedition.area), the events still have the party
	# in Mossy Hollow, where the guardian fell.
	_sim = Simulation.new(SEED)
	_build_hud()
	_level(STRONG_LEVEL)
	_before_guardian(5)
	_world.sync(0.1)
	_hud.advance(STEP)
	for i: int in 4000:
		if _sim.expedition.state == Expedition.State.JOURNEYING:
			break
		if _sim.is_area_open(CLAYPITS) and _sim.expedition.travel.pending_area == &"":
			_sim.set_destination(CLAYPITS, 1)
		_sim.step()
	assert_eq(_sim.expedition.state, Expedition.State.JOURNEYING, "setup: on the road")
	assert_eq(_sim.expedition.area, CLAYPITS, "setup: the live state names the destination")
	_world.sync(0.1)
	_hud.advance(0.1)
	assert_eq(_map().news.here, MOSSY, "the events are still in Mossy Hollow")
	assert_true(_map().news.beaten.has(MOSSY), "the guardian heard as Mossy Hollow's")
	assert_false(_map().news.beaten.has(CLAYPITS), "not the destination's")
	assert_true(_map().has_mark(), "the mark")
	assert_gte(_hud.goals.lines().find("Visit The Claypits"), 0, "the goal, not yet done")
	_map().open()
	_hud.advance(STEP)
	assert_string_starts_with(
		_map().row(CLAYPITS).tag_label.text, "On the way", "the destination is on the way"
	)
	assert_eq(_map().row(MOSSY).tag_label.text, "", "and nowhere is Here")


# --- R8 ------------------------------------------------------------------------


func test_r8_found_and_explained() -> void:
	_mossy(2, 3)
	_sim.expedition.travel.open[CLAYPITS] = true
	_build_hud()
	_hud.advance(STEP)
	var listed: bool = false
	for entry: Array in HelpPanel.KEYS:
		listed = listed or str(entry[0]) == "W"
	assert_true(listed, "W is in the help list")
	_key(KEY_W)
	assert_true(_map().is_open(), "W opens the map")
	_key(KEY_W)
	assert_false(_map().is_open(), "W closes it")
	_key(KEY_W)
	_key(KEY_ESCAPE)
	assert_false(_map().is_open(), "Esc closes it")
	await _click(_hud.place_panel.area_button)
	assert_true(_map().is_open(), "a click on the area's name opens it")
	_hud.advance(STEP)

	_map().choose(CLAYPITS)
	_hud.advance(STEP)
	var controls: Array[Control] = [
		_map().minus_button,
		_map().plus_button,
		_map().go_button,
		_map().stage_label,
		_map().risk_label,
	]
	for row: AreaMapRow in _map().rows:
		controls.append(row)
		controls.append(row.guardian_thumb)
		controls.append_array(row.thumbs)
	for control: Control in controls:
		assert_ne(_tip(control), "", "%s has a tooltip" % control.name)
	_map().close()
	_hud.advance(STEP)
	assert_string_contains(
		_frame_tip(_hud.place_panel.area_button), "map", "the area's name says it opens the map"
	)

	# Spec 059: a window on the UI layer, with a close button of its own (spec 058's test); where
	# it stands, clear of the top band and the hero frames at both rooms, is spec 059 R8's test.
	assert_not_null(_map().window().close_button, "the map's window can be closed")

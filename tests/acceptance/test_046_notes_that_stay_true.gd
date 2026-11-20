extends ColonyTest
## Acceptance tests for specs/046-notes-that-stay-true/spec.md, one per requirement (R10 is the
## amended tests of specs 041 and 045).
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, and steps it by hand: a tick per frame, unless the test means to bring many
## ticks in one frame (a stall, or 4x). As in spec 041's tests, a fight is lost by putting every
## hero's fighter at 0 health once it starts.

const SEED: int = 41
const STEP: float = 1.0 / 60.0
const GUARDIAN_DEPTH: int = 5
const DEEP: int = 7
const SAFE: int = 4
const RICH: int = 1_000_000
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 3000

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## Every event the world has told of since the HUD was made, oldest first.
var _events: Array[SimEvent] = []


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()


func after_each() -> void:
	super()
	if _hud != null and is_instance_valid(_hud) and _hud.defeat_note != null:
		_hud.defeat_note.point_at(UiTip.NOWHERE)


# --- Helpers -------------------------------------------------------------------


func _build_hud() -> void:
	_events.clear()
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
	var ui := UiRoot.new()  # spec 059: the tally is a window on the UI layer
	add_child_autofree(ui)
	ui.setup(_sim, _hud, null)
	_world.sim_event.connect(_on_event)


func _on_event(event: SimEvent) -> void:
	_events.append(event)


func _note() -> DefeatNote:
	return _hud.defeat_note


## One frame of one tick: the simulation, the world, the HUD.
func _frame() -> void:
	_sim.step()
	_world.sync(STEP)
	_hud.advance(STEP)


## Steps a tick per frame until [param done] returns true (true), or the limit (false).
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(0.1)
		_hud.advance(0.1)
		if done.call():
			return true
	return false


## Puts the party just outside the guardian's chamber on Mossy Hollow 5, walking in, no auto-push.
func _before_guardian() -> void:
	var e: Expedition = _sim.expedition
	var lair: LabyrinthChamber = _sim.labyrinth.level(GUARDIAN_DEPTH).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = GUARDIAN_DEPTH
	e.deepest_depth = maxi(e.deepest_depth, GUARDIAN_DEPTH)
	e.last_stable_depth = SAFE
	e.target_depth = GUARDIAN_DEPTH + 1
	if lair.index > 0:
		e.x = lair.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = lair.rect.end.x
		e.facing = -1


## Puts the party at the start of [param depth], hunting there, with [param stable] its safe depth.
func _hunting_on(depth: int, stable: int) -> void:
	var e: Expedition = _sim.expedition
	_sim.set_auto_push(false)
	e.depth = depth
	e.x = _sim.labyrinth.level(depth).chambers[0].rect.position.x
	e.deepest_depth = maxi(e.deepest_depth, depth)
	e.last_stable_depth = stable
	e.target_depth = depth


func _fighting() -> bool:
	return _sim.expedition.battle != null


func _reviving() -> bool:
	return _sim.expedition.state == Expedition.State.REVIVING


## Plays until the next fight starts, then puts every hero at 0 health.
func _doom_next_fight() -> bool:
	if not _step_until(_fighting):
		return false
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	return true


## Plays until the next fight starts, then loses it: the party is wiped. True once it is.
func _lose_next_fight() -> bool:
	return _doom_next_fight() and _step_until(_reviving)


func _guardian_wipe() -> bool:
	_before_guardian()
	return _lose_next_fight()


## Plays on until the revived heroes have stood up.
func _until_standing() -> bool:
	var standing: Callable = func() -> bool:
		return not _reviving() and not _world.fallen_party.is_telling()
	return _step_until(standing)


func _guardian_name() -> String:
	return Content.monster(_sim.expedition.guardian_of(GUARDIAN_DEPTH)).display_name


func _journal_sentence() -> String:
	for line: String in _hud.journal.lines():
		var sentence: String = line.substr(line.find("  ") + 2)
		if sentence.begins_with("Beaten"):
			return sentence
	return ""


func _first_line() -> String:
	var lines: Array[String] = _note().lines()
	return lines[0] if not lines.is_empty() else ""


## Runs the HUD on by [param seconds] in frames, the simulation standing still.
func _linger(seconds: float) -> void:
	for i: int in roundi(seconds / 0.1):
		_hud.advance(0.1)


## The sentence the tooltip shows after the mouse rests on [param control].
func _tip_of(control: Control) -> String:
	_hud.frame_tip.point_at(UiTip.NOWHERE)
	_hud.frame_tip.advance(1.0)
	_hud.frame_tip.point_at(control.get_global_rect().get_center())
	_hud.frame_tip.advance(UiTip.DELAY + 0.1)
	var text: String = _hud.frame_tip.shown_text()
	_hud.frame_tip.point_at(UiTip.NOWHERE)
	_hud.frame_tip.advance(STEP)
	return text


func _is_hero(id: int) -> bool:
	return id >= 0 and id < Expedition.FIRST_MONSTER_ID


# --- R1 ------------------------------------------------------------------------


func test_r1_one_frame_defeat() -> void:
	var beaten: String = "Beaten by the %s on Mossy Hollow %d" % [_guardian_name(), GUARDIAN_DEPTH]
	_before_guardian()
	assert_true(_doom_next_fight(), "a guardian fight starts, and is lost")
	# The defeat, the wipe and the revival stepped with no frame between, as a stall or 4x
	# brings them: the HUD hears of all three after the party is back on its safe depth.
	var wiped: bool = false
	for i: int in LIMIT_TICKS:
		_sim.step()
		wiped = wiped or _reviving()
		if wiped and not _reviving():
			break
	assert_true(wiped and not _reviving(), "wiped and revived in the one frame")
	assert_eq(_sim.expedition.depth, SAFE, "the party is back on its safe depth")
	_world.sync(STEP)
	_hud.advance(STEP)
	var wipe: SimEvent = null
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.PARTY_WIPED:
			wipe = event
	assert_not_null(wipe, "the wipe was heard")
	if wipe == null:
		return
	assert_eq(
		_journal_sentence(),
		"%s; falling back to Mossy Hollow %d" % [beaten, SAFE],
		"the journal names the guardian and the depth of the lost fight"
	)
	assert_eq(_note().wipe_line(wipe), beaten, "the note remembers the depth of the lost fight")
	# Then a defeat watched frame by frame: the second by the same guardian.
	assert_true(_until_standing(), "the heroes stand")
	assert_true(_guardian_wipe(), "beaten by the guardian again")
	assert_eq(_first_line(), beaten + " (2 times)", "counted as the second in a row")


# --- R2 ------------------------------------------------------------------------


func test_r2_holding_is_true() -> void:
	_sim.party.gold = 0
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	assert_eq(_note().suggestions(), ["Hold here"] as Array[String], "only Hold, with no gold")
	var hold: UiButton = _note().buttons[0]
	assert_eq(_tip_of(hold), DefeatNote.TIPS[DefeatNote.Help.HOLD], "the Hold tooltip")
	_note().press(0)
	assert_eq(_note().suggestions(), ["Holding"] as Array[String], "Holding once pressed")
	_frame()
	assert_eq(_sim.expedition.guardian_order, Expedition.GuardianOrder.HOLD, "the order is Hold")
	assert_eq(_note().suggestions(), ["Holding"] as Array[String], "and it reads Holding")
	assert_true(hold.lit, "lit while holding")
	assert_eq(_tip_of(hold), DefeatNote.holding_tip(), "the Holding tooltip")

	# The order goes back to Challenge through the orders panel while the note shows. (Spec 058
	# moved the panel into a window on the UI layer; one made on its own sends the same command.)
	var orders := OrdersPanel.new()
	add_child_autofree(orders)
	orders.setup(_sim, null)
	orders.choose(PartyOrders.GUARDIANS, Expedition.GuardianOrder.CHALLENGE)
	_frame()
	assert_eq(
		_sim.expedition.guardian_order, Expedition.GuardianOrder.CHALLENGE, "challenging again"
	)
	assert_true(_note().is_shown(), "the note still shows")
	assert_eq(_note().suggestions(), ["Hold here"] as Array[String], "Hold here again")
	assert_false(hold.lit, "not lit")
	assert_eq(_tip_of(hold), DefeatNote.TIPS[DefeatNote.Help.HOLD], "the Hold tooltip again")
	_note().press(0)
	_frame()
	assert_eq(_sim.expedition.guardian_order, Expedition.GuardianOrder.HOLD, "and it works")
	assert_eq(_note().suggestions(), ["Holding"] as Array[String], "Holding again")


# --- R3 ------------------------------------------------------------------------


func test_r3_click_does_what_was_aimed() -> void:
	_sim.party.gold = RICH
	# Spec 051: training spends a paragon point, which a level past 14 brings.
	var rogue: Hero = _sim.party.heroes[1]
	rogue.gain_xp(Hero.xp_for_level(Hero.TALENT_POINTS * Hero.TALENT_EVERY + 1) - rogue.xp)
	_spend_talents(rogue)
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	var shown: Array[String] = _note().suggestions()
	assert_eq(shown.size(), 3, "train, buy, hold")
	assert_eq(shown[1], "Buy an upgrade", "the second is the shop")
	# The mouse comes to rest on the note; meanwhile the gold is spent.
	_note().point_at(_note().buttons[1].get_global_rect().get_center())
	_hud.advance(STEP)
	_sim.party.gold = 0
	for i: int in 5:
		_frame()
	assert_eq(_note().suggestions(), shown, "the row does not change under the mouse")
	assert_eq(_note().buttons[1].text, "Buy an upgrade", "the button still says so")
	_note().press(1)
	assert_true(_hud.shop.is_open(), "the click opens the shop, as the button said")
	_hud.shop.close()
	_note().point_at(UiTip.NOWHERE)
	_hud.advance(STEP)
	assert_eq(
		_note().suggestions(),
		["Train Rogue", "Hold here"] as Array[String],
		"then it follows the gold (the rogue's point is not gold)"
	)


# --- R4 ------------------------------------------------------------------------


func test_r4_panel_does_not_use_time() -> void:
	_sim.party.gold = RICH
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	assert_true(_until_standing(), "the heroes stand")
	_linger(1.0)
	assert_true(_note().is_shown(), "the note lingers")
	_note().press(_note().suggestions().find("Buy an upgrade"))
	assert_true(_hud.shop.is_open(), "Buy an upgrade opens the shop")
	# Spec 062 R4: drawn over every window, the note no longer hides while the shop is open; it
	# keeps its time there as anywhere.
	_hud.advance(STEP)
	assert_true(_note().is_shown(), "shown while the shop is open")
	_linger(DefeatNote.LINGER_SECONDS - 2.5)
	assert_true(_note().is_shown(), "with the rest of its time")
	_hud.shop.close()
	_linger(DefeatNote.LINGER_SECONDS + 2.0)
	assert_false(_note().is_shown(), "which then runs out")


# --- R5 ------------------------------------------------------------------------


func test_r5_old_defeat_leaves_the_note() -> void:
	_sim.party.gold = 0
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	var lines: Array[String] = _note().lines()
	var helps: Array[String] = _note().suggestions()
	assert_eq(lines.size(), 2, "a line and a reason")
	assert_eq(helps, ["Hold here"] as Array[String], "Hold, with no gold")
	assert_true(_until_standing(), "the heroes stand")
	# The mouse holds the note while the party walks into an ordinary fight on Mossy Hollow 7.
	_note().point_at(_note().panel.get_global_rect().get_center())
	_hunting_on(DEEP, SAFE)
	assert_true(_doom_next_fight(), "an ordinary fight, lost")
	assert_true(_note().is_shown(), "the note still shows")
	# A stall: the wipe is heard only long after.
	for i: int in 30:
		_sim.step()
	assert_true(_reviving(), "wiped during the stall")
	_note().point_at(UiTip.NOWHERE)
	_world.sync(STEP)
	_hud.advance(STEP)
	assert_true(_note().is_shown(), "the note still shows")
	assert_eq(_note().lines(), lines, "its lines are the guardian's")
	assert_eq(_note().suggestions(), helps, "and so are its suggestions")


# --- R6 ------------------------------------------------------------------------


func test_r6_journal_keeps_what_it_said() -> void:
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	assert_eq(
		_journal_sentence(),
		(
			"Beaten by the %s on Mossy Hollow %d; falling back to Mossy Hollow %d"
			% [_guardian_name(), GUARDIAN_DEPTH, SAFE]
		),
		"the note's line and where the party falls back to"
	)
	assert_eq(_journal_sentence(), _first_line() + "; falling back to Mossy Hollow %d" % SAFE)
	assert_true(_until_standing(), "the heroes stand")
	_hunting_on(SAFE, SAFE)
	assert_true(_lose_next_fight(), "the party loses on its safe depth")
	assert_eq(_journal_sentence(), _first_line() + "; regrouping there", "no fall back there")


# --- R7 ------------------------------------------------------------------------


func test_r7_started_mid_fight() -> void:
	# The game opened in the middle of a fight: the simulation runs into one with nothing
	# watching, blows are struck, and only then is the HUD made.
	var running := Simulation.new(SEED)
	var struck: int = 0
	for i: int in LIMIT_TICKS:
		running.step()
		for event: SimEvent in running.drain_events():
			if event.kind == SimEvent.Kind.HIT and running.expedition.battle != null:
				struck += 1
		if running.expedition.battle != null and struck >= 3:
			break
	assert_not_null(running.expedition.battle, "fighting when the HUD is made")
	_sim = running
	_build_hud()
	var depth: int = _sim.expedition.depth
	var tally: TallyWindow = _hud.tally
	tally.open()
	tally.set_span(Tally.Span.LAST_FIGHT)
	tally.set_measure(Tally.Measure.DAMAGE)
	_hud.advance(STEP)
	assert_true(tally.rows()[0].begins_with("This fight: "), tally.rows()[0])
	assert_true(tally.rows()[0].contains(", Mossy Hollow %d, " % depth), tally.rows()[0])
	assert_eq(tally.tally.fights(), 1, "the fight under way is counted")
	# Blows struck from here are this fight's.
	var hit: Callable = func() -> bool:
		for event: SimEvent in _events:
			if event.kind == SimEvent.Kind.HIT and _is_hero(event.source_id):
				return true
		return false
	assert_true(_step_until(hit), "a hero strikes")
	if _fighting():
		assert_true(tally.rows()[0].begins_with("This fight: "), tally.rows()[0])
	else:
		assert_true(tally.rows()[0].begins_with("Last fight: "), tally.rows()[0])
	var sums: Dictionary[int, int] = {}
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.ENCOUNTER_STARTED:
			sums.clear()
		if event.kind == SimEvent.Kind.HIT and _is_hero(event.source_id):
			sums[event.source_id] = sums.get(event.source_id, 0) + event.amount
	for hero: Hero in _sim.party.heroes:
		var want: int = sums.get(hero.id, 0)
		assert_eq(
			tally.tally.value(hero.id, Tally.Measure.DAMAGE, Tally.Span.LAST_FIGHT),
			want,
			"%s's damage this fight" % hero.class_id
		)
	var started: int = 0
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.ENCOUNTER_STARTED:
			started += 1
	tally.set_span(Tally.Span.SESSION)
	_hud.advance(STEP)
	var fights: int = started + 1
	var noun: String = "fight" if fights == 1 else "fights"
	assert_true(
		tally.rows()[0].begins_with("Session: %d %s" % [fights, noun]),
		"the session counts it: %s" % tally.rows()[0]
	)


# --- R8 ------------------------------------------------------------------------


func test_r8_measures_say_what_they_count() -> void:
	var tally: Tally = _hud.tally.tally
	# A killing blow on a monster with 1 health left.
	_hunting_on(SAFE, SAFE)
	assert_true(_step_until(_fighting), "a fight")
	var monster: Combatant = _sim.expedition.battle.monsters[0]
	monster.health = 1
	var killed: Callable = func() -> bool: return not monster.is_alive()
	var before: Dictionary[int, int] = {}
	for hero: Hero in _sim.party.heroes:
		before[hero.id] = tally.value(hero.id, Tally.Measure.DAMAGE, Tally.Span.SESSION)
	var seen: int = _events.size()
	assert_true(_step_until(killed, 600), "the monster falls")
	var blow: SimEvent = null
	for event: SimEvent in _events.slice(seen):
		if event.kind == SimEvent.Kind.HIT and event.target_id == monster.id:
			blow = event
	assert_not_null(blow, "the killing blow was heard")
	if blow == null:
		return
	assert_gt(blow.amount, 1, "the blow is larger than the health left")
	var dealt: int = (
		tally.value(blow.source_id, Tally.Measure.DAMAGE, Tally.Span.SESSION)
		- before[blow.source_id]
	)
	# The events carry the whole blow, not the health lost: the tally counts the blow, and the
	# tooltips of Damage and Taken say that overkill is in it.
	assert_eq(dealt, blow.amount, "the whole blow is counted")
	var damage_tip: String = TallyWindow.TAB_TIPS[Tally.Measure.DAMAGE]
	var taken_tip: String = TallyWindow.TAB_TIPS[Tally.Measure.TAKEN]
	assert_true(damage_tip.contains("overkill"), "the Damage tooltip says so: %s" % damage_tip)
	assert_true(taken_tip.contains("overkill"), "the Taken tooltip says so: %s" % taken_tip)
	_hud.tally.open()
	_hud.advance(STEP)
	for measure: int in [Tally.Measure.DAMAGE, Tally.Measure.TAKEN]:
		var tip: String = _hud.tally.tip.text_for(_hud.tally.tab_buttons[measure])  # spec 059
		assert_eq(tip, TallyWindow.TAB_TIPS[measure], "shown on the tab")
	_hud.tally.close()

	# A heal on a hero one short of full: only the one point restored is counted. When a heal
	# sets off, its hero is put one short of full until it lands.
	var mended: Dictionary[int, int] = {}
	for hero: Hero in _sim.party.heroes:
		mended[hero.id] = tally.value(hero.id, Tally.Measure.HEALING, Tally.Span.SESSION)
	var first: int = _events.size()
	# Where to look from, and the hero the heal is for (-1 until one sets off).
	var from: Array[int] = [first]
	var target: Array[int] = [-1]
	var healed: Callable = func() -> bool:
		for event: SimEvent in _events.slice(from[0]):
			if event.kind == SimEvent.Kind.HEALED and event.target_id == target[0]:
				return true
			if event.kind == SimEvent.Kind.PROJECTILE_LAUNCHED and event.flag and target[0] < 0:
				target[0] = event.target_id
		var battle: Battle = _sim.expedition.battle
		var patient: Combatant = battle.combatant(target[0]) if battle != null else null
		if patient != null and patient.is_alive():
			patient.health = patient.max_health - 1
		elif target[0] >= 0:
			target[0] = -1  # the fight ended first: wait for the next heal
			from[0] = _events.size()
		return false
	assert_true(_step_until(healed, 20000), "a heal lands on the nearly full hero")
	seen = from[0]
	var heal: SimEvent = null
	for event: SimEvent in _events.slice(seen):
		if event.kind == SimEvent.Kind.HEALED and event.target_id == target[0] and heal == null:
			heal = event
	if heal == null:
		return
	assert_eq(heal.amount, 1, "one point restored")
	var counted: int = (
		tally.value(heal.source_id, Tally.Measure.HEALING, Tally.Span.SESSION)
		- mended[heal.source_id]
	)
	var others: int = 0
	for event: SimEvent in _events.slice(first):
		if event.kind == SimEvent.Kind.HEALED and event.source_id == heal.source_id:
			others += event.amount
	assert_eq(counted, others, "healing counts what was restored, the 1 among it")


# --- R9 ------------------------------------------------------------------------


func test_r9_help_row() -> void:
	var text: String = ""
	for entry: Array in KeyBook.entries():
		if str(entry[0]) == "Q E":
			text = str(entry[1])
	# Spec 058 shortened the row to fit the help window's column on one line, and spec 060 again
	# (the sheet became hero windows, and Shift+Tab widened the key column); it still names both.
	assert_eq(text, "Hero window or Tally: change tab", "the Q E row")  # spec 068 R2: Tally


## Spends every talent point [param hero]'s level has earned (the trunk, then the first path),
## so spec 055's talent goal and defeat-note button do not crowd out what this test is about.
func _spend_talents(hero: Hero) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var order: Array[StringName] = tree.trunk.duplicate()
	order.append_array(tree.path_a)
	hero.set_talents(order.slice(0, TalentRules.talent_points_at(hero.level)))

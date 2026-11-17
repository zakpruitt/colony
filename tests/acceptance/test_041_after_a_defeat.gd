extends GutTest
## Acceptance tests for specs/041-after-a-defeat/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, and puts the party in the fight it is to lose by hand: just outside the
## Slime King's chamber on depth 5, or on a depth with ordinary monsters. Once the fight starts,
## every hero's fighter is put at 0 health, so the next tick loses it; nothing waits for a real
## defeat.

const SEED: int = 41
const STEP: float = 1.0 / 60.0
const GUARDIAN_DEPTH: int = 5
const DEEP: int = 7
const SAFE: int = 4
const STRONG_LEVEL: int = 40
const RICH: int = 1_000_000
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 3000

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()


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


func _note() -> DefeatNote:
	return _hud.defeat_note


## Steps the simulation a tick at a time, the world after each and the HUD every tick (as frames
## would), until [param done] returns true (true), or the limit (false).
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(0.1)
		_hud.advance(0.1)
		if done.call():
			return true
	return false


## Puts the party just outside the guardian's chamber on depth 5, walking in, no auto-push.
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


## Plays until the next fight starts, then loses it: the party is wiped. True once it is.
func _lose_next_fight() -> bool:
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	if not _step_until(fighting):
		return false
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	var down: Callable = func() -> bool: return _sim.expedition.state == Expedition.State.REVIVING
	return _step_until(down)


## Plays on until the revived heroes have stood up.
func _until_standing() -> bool:
	var standing: Callable = func() -> bool:
		var e: Expedition = _sim.expedition
		return e.state != Expedition.State.REVIVING and not _world.fallen_party.is_telling()
	return _step_until(standing)


func _guardian_wipe() -> bool:
	_before_guardian()
	return _lose_next_fight()


## The Slime King's name, as the data has it.
func _guardian_name() -> String:
	return Content.monster(_sim.expedition.guardian_of(GUARDIAN_DEPTH)).display_name


func _lowest_level() -> int:
	var lowest: int = 0
	for hero: Hero in _sim.party.heroes:
		if lowest == 0 or hero.level < lowest:
			lowest = hero.level
	return lowest


## The hero with the cheapest affordable training (the first on a tie), or null.
func _cheapest_trainee() -> Hero:
	var best: Hero = null
	var best_price: int = 0
	for hero: Hero in _sim.party.heroes:
		for id: StringName in Content.training_ids():
			var price: int = hero.training_cost(id)
			if price <= 0 or price > _sim.party.gold:
				continue
			if best == null or price < best_price:
				best = hero
				best_price = price
	return best


func _journal_sentence() -> String:
	var lines: Array[String] = _hud.journal.lines()
	for line: String in lines:
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


func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


# --- R1 ------------------------------------------------------------------------


func test_r1_defeat_note() -> void:
	assert_not_null(_note(), "the HUD has a defeat note")
	assert_false(_note().is_shown(), "nothing shows before a defeat")
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	assert_true(_note().is_shown(), "the note shows after the wipe")
	assert_eq(
		_first_line(),
		"Beaten by the %s on depth %d" % [_guardian_name(), GUARDIAN_DEPTH],
		"it says the guardian beat the party, and where"
	)
	var revived: Callable = func() -> bool:
		return _sim.expedition.state != Expedition.State.REVIVING
	assert_true(_step_until(revived), "the party is revived")
	assert_true(_world.fallen_party.is_telling(), "the heroes are still standing up")
	assert_true(_note().is_shown(), "the note stays until they stand")
	assert_true(_until_standing(), "the heroes stand")
	_linger(DefeatNote.LINGER_SECONDS - 0.5)
	assert_true(_note().is_shown(), "it stays a while after they stand")
	# The mouse over it holds it, for as long as it rests there.
	_note().point_at(_rect(_note().panel).get_center())
	_linger(20.0)
	assert_true(_note().is_shown(), "it waits while the mouse is over it")
	_note().point_at(HudTooltip.NOWHERE)
	_linger(0.4)
	assert_true(_note().is_shown(), "a moment after the mouse leaves it is still there")
	_linger(1.0)
	assert_false(_note().is_shown(), "then it fades and goes")

	# An ordinary fight on depth 7: the monsters alive when the last hero fell, by name.
	_hunting_on(DEEP, SAFE)
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a fight starts on depth 7")
	var battle: Battle = _sim.expedition.battle
	var names: Array[String] = []
	for monster: Combatant in battle.monsters:
		var def: MonsterDef = Content.monster(monster.def_id)
		assert_false(def.guardian, "an ordinary monster")
		names.append(def.display_name)
	for fighter: Combatant in battle.heroes:
		fighter.health = 0
	var down: Callable = func() -> bool: return _sim.expedition.state == Expedition.State.REVIVING
	assert_true(_step_until(down), "the party is wiped")
	assert_true(_note().is_shown(), "the note shows again")
	assert_eq(
		_first_line(),
		"Beaten on depth %d by %s" % [DEEP, DefeatNote.crowd(names)],
		"it says where, and which monsters"
	)
	assert_true(_first_line().begins_with("Beaten on depth 7 by "), "in that order")


# --- R2 ------------------------------------------------------------------------


func test_r2_says_why() -> void:
	# 1. A guardian, the heroes below its balanced level.
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	var lines: Array[String] = _note().lines()
	assert_eq(lines.size(), 2, "a second line")
	assert_eq(
		lines[1],
		(
			"Heroes are level %d; it is balanced for about %d"
			% [_lowest_level(), Goals.guardian_level(GUARDIAN_DEPTH)]
		),
		"the lowest level against the goals tracker's rule"
	)
	assert_true(_until_standing(), "the heroes stand")

	# A guardian beats heroes at its level: the reason is not their level. Two below the safe
	# depth it says that instead.
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(Goals.guardian_level(GUARDIAN_DEPTH)) - hero.xp)
		hero.health = hero.max_health()
	_before_guardian()
	_sim.expedition.last_stable_depth = GUARDIAN_DEPTH - 3
	assert_true(_lose_next_fight(), "the party loses to the guardian again")
	lines = _note().lines()
	assert_eq(lines.size(), 2, "a second line")
	assert_eq(lines[1], "Depth 5 is 3 below the safe depth", "the depth, not the level")
	assert_true(_until_standing(), "the heroes stand")

	# 2. Ordinary monsters, two or more below the safe depth.
	_hunting_on(DEEP, SAFE)
	assert_true(_lose_next_fight(), "the party loses on depth 7")
	lines = _note().lines()
	assert_eq(lines.size(), 2, "a second line")
	assert_eq(lines[1], "Depth 7 is 3 below the safe depth", "how far below the safe depth")
	assert_true(_until_standing(), "the heroes stand")

	# 3. Otherwise none: one below the safe depth, or on it.
	_hunting_on(DEEP, DEEP - 1)
	assert_true(_lose_next_fight(), "the party loses one below its safe depth")
	assert_eq(_note().lines().size(), 1, "no second line one below")
	assert_true(_until_standing(), "the heroes stand")
	_hunting_on(DEEP - 1, DEEP - 1)
	assert_true(_lose_next_fight(), "the party loses on its safe depth")
	assert_eq(_note().lines().size(), 1, "no second line on it")


# --- R3 ------------------------------------------------------------------------


func test_r3_offers_help() -> void:
	# A guardian, gold to spend: train, buy, hold, in that order, at most three.
	_sim.party.gold = RICH
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	var trainee: Hero = _cheapest_trainee()
	assert_not_null(trainee, "a hero can be trained")
	var expected: Array[String] = [
		"Train %s" % trainee.def().display_name, "Buy an upgrade", "Hold here"
	]
	assert_eq(_note().suggestions(), expected, "train, buy, hold")
	assert_eq(_note().buttons.size(), DefeatNote.MOST, "never more than three buttons")

	_note().press(0)
	assert_true(_hud.hero_sheet.is_open(), "Train opens a hero sheet")
	assert_eq(_hud.hero_sheet.shown_hero_id(), trainee.id, "the cheapest hero's to train")
	assert_eq(_hud.hero_sheet.page(), HeroSheet.Page.TRAINING, "on the Training tab")
	_hud.hero_sheet.close()
	_hud.advance(STEP)

	_note().press(1)
	assert_true(_hud.shop.is_open(), "Buy an upgrade opens the shop")
	_hud.shop.close()
	_hud.advance(STEP)

	assert_eq(_sim.expedition.guardian_order, Expedition.GuardianOrder.CHALLENGE, "challenging")
	_note().press(2)
	assert_eq(_note().suggestions()[2], "Holding", "Hold here then reads Holding")
	_sim.step()
	_world.sync(STEP)
	_hud.advance(STEP)
	assert_eq(
		_sim.expedition.guardian_order,
		Expedition.GuardianOrder.HOLD,
		"through the simulation's command"
	)
	assert_eq(_note().suggestions()[2], "Holding", "and goes on reading Holding")
	assert_true(_until_standing(), "the heroes stand")
	_sim.set_guardian_order(Expedition.GuardianOrder.CHALLENGE)

	# Ordinary monsters below the safe depth, with gold: train and buy, nothing more.
	_sim.party.gold = RICH
	_hunting_on(DEEP, SAFE)
	assert_true(_lose_next_fight(), "the party loses on depth 7")
	var trained: Hero = _cheapest_trainee()
	expected = ["Train %s" % trained.def().display_name, "Buy an upgrade"]
	assert_eq(_note().suggestions(), expected, "train, buy")
	assert_true(_until_standing(), "the heroes stand")

	# Ordinary monsters, no gold: nothing to suggest, below the safe depth or on it.
	_sim.party.gold = 0
	_hunting_on(DEEP, SAFE)
	assert_true(_lose_next_fight(), "the party loses below its safe depth")
	assert_eq(_note().suggestions(), [] as Array[String], "nothing below the safe depth")
	assert_true(_until_standing(), "the heroes stand")
	_hunting_on(SAFE, SAFE)
	assert_true(_lose_next_fight(), "the party loses on its safe depth")
	assert_eq(_note().suggestions(), [] as Array[String], "nothing to suggest")
	assert_true(_note().is_shown(), "the note shows only its lines")
	for button: HudButton in _note().buttons:
		assert_false(button.is_visible_in_tree(), "and no button")


# --- R4 ------------------------------------------------------------------------


func test_r4_repeats_are_counted() -> void:
	var beaten: String = "Beaten by the %s on depth %d" % [_guardian_name(), GUARDIAN_DEPTH]
	assert_true(_guardian_wipe(), "the first defeat")
	assert_eq(_first_line(), beaten, "no count the first time")
	assert_true(_until_standing(), "the heroes stand")
	assert_true(_guardian_wipe(), "the second")
	assert_eq(_first_line(), beaten + " (2 times)", "counted from the second")
	assert_true(_until_standing(), "the heroes stand")
	assert_true(_guardian_wipe(), "the third")
	assert_eq(_first_line(), beaten + " (3 times)", "and the third")
	assert_true(_until_standing(), "the heroes stand")

	# A victory over it starts the count again.
	var slain := SimEvent.new(
		SimEvent.Kind.GUARDIAN_SLAIN, _sim.tick, Expedition.FIRST_MONSTER_ID, -1, GUARDIAN_DEPTH
	)
	_world.sim_event.emit(slain)
	assert_true(_guardian_wipe(), "beaten again after a victory")
	assert_eq(_first_line(), beaten, "the count starts again")
	assert_true(_until_standing(), "the heroes stand")
	assert_true(_guardian_wipe(), "and again")
	assert_eq(_first_line(), beaten + " (2 times)", "counted from there")


# --- R5 ------------------------------------------------------------------------


func test_r5_out_of_the_way() -> void:
	_sim.party.gold = RICH
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	var note: DefeatNote = _note()
	assert_eq(note.suggestions().size(), 3, "three buttons, the widest note")

	# Tooltips: one sentence each.
	for i: int in note.suggestions().size():
		var button: HudButton = note.buttons[i]
		_hud.tooltip.point_at(_rect(button).get_center())
		_hud.tooltip.advance(HudTooltip.DELAY + 0.1)
		var text: String = _hud.tooltip.shown_text()
		assert_ne(text, "", "button %d has a tooltip" % i)
		assert_true(text.ends_with("."), "a sentence: %s" % text)
		assert_eq(text.count(". "), 0, "one sentence: %s" % text)
		_hud.tooltip.point_at(HudTooltip.NOWHERE)
		_hud.tooltip.advance(STEP)

	_assert_out_of_the_way("after the wipe")

	# Hidden while each panel is open.
	var panels: Dictionary[String, Callable] = {
		"shop": _hud.shop.open,
		"hero sheet": _hud.hero_sheet.open.bind(_sim.party.heroes[0].id),
		"journal": _hud.journal.open,
		"help": _hud.help.open,
		"orders": _hud.orders.open,
	}
	var closes: Dictionary[String, Callable] = {
		"shop": _hud.shop.close,
		"hero sheet": _hud.hero_sheet.close,
		"journal": _hud.journal.close,
		"help": _hud.help.close,
		"orders": _hud.orders.close,
	}
	for panel: String in panels:
		panels[panel].call()
		_hud.advance(STEP)
		assert_false(note.is_shown(), "hidden while the %s is open" % panel)
		closes[panel].call()
		_hud.advance(STEP)
		assert_true(note.is_shown(), "back when the %s closes" % panel)
	var away := AwayPanel.new(AwayReport.new(), _sim.party)
	_hud.get_parent().add_child(away)
	_hud.advance(STEP)
	assert_false(note.is_shown(), "hidden while the away report is up")
	away.free()
	_hud.advance(STEP)
	assert_true(note.is_shown(), "back when it goes")

	# The heroes stand and walk straight into the guardian again while the note lingers: a new
	# fight does not hide it, and it keeps off the boss bar too.
	assert_true(_until_standing(), "the heroes stand")
	_before_guardian()
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a new guardian fight starts")
	assert_true(note.is_shown(), "the note is still up in the new fight")
	assert_true(_hud.boss_bar.is_visible_in_tree(), "the boss bar is up")
	_assert_out_of_the_way("during the new fight")


## The note's panel clear of every listed HUD part (the boss bar too), of WIPED and the centre
## line, below the top band, in the upper half and in the middle.
func _assert_out_of_the_way(when: String) -> void:
	var area: Rect2 = _rect(_note().panel)
	var parts: Dictionary[String, Rect2] = {
		"depth panel": _rect(_hud.depth_panel),
		"goals": _rect(_hud.goals.panel),
		"shop tab": _rect(_hud.shop_tab),
		"gold": _rect(_hud.gold_panel),
		"ladder": _rect(_hud.ladder),
		"boss bar": _rect(_hud.boss_bar),
	}
	for i: int in _hud.frames.size():
		parts["frame %d" % i] = _rect(_hud.frames[i])
	var wiped: Rect2 = FxText.box("WIPED", PixelText.SIZE * (DefeatNote.WIPED_SCALE + 1))
	wiped.position += Hud.SCREEN / 2.0
	parts["WIPED"] = wiped
	parts["the centre line"] = Rect2(0.0, Hud.SCREEN.y / 2.0, Hud.SCREEN.x, 1.0)
	assert_true(_hud.goals.is_shown(), "the goals are up %s" % when)
	for part: String in parts:
		assert_false(area.intersects(parts[part]), "the note keeps off the %s %s" % [part, when])
	assert_gt(area.position.y, Hud.TOP_BAND, "below the top band %s" % when)
	assert_lt(area.end.y, Hud.SCREEN.y / 2.0, "in the upper half %s" % when)
	assert_almost_eq(area.get_center().x, Hud.SCREEN.x / 2.0, 1.0, "in the middle %s" % when)


func test_r5_nothing_after_time_away() -> void:
	# A wipe while the game was away: stepped with nothing watching, its events drained (as the
	# replay does), then the world and HUD made on the party still down.
	var away := Simulation.new(SEED)
	_sim = away
	_before_guardian()
	for i: int in LIMIT_TICKS:
		away.step()
		if away.expedition.battle != null:
			break
	for fighter: Combatant in away.expedition.battle.heroes:
		fighter.health = 0
	for i: int in 3:
		away.step()
	assert_eq(away.expedition.state, Expedition.State.REVIVING, "wiped while away")
	away.drain_events()
	_build_hud()
	_hud.advance(STEP)
	assert_false(_note().is_shown(), "no note for a wipe while away")
	var revived: Callable = func() -> bool:
		return _sim.expedition.state != Expedition.State.REVIVING
	assert_true(_step_until(revived), "the party is revived")
	assert_false(_note().is_shown(), "nor after the revival")

	# A wipe seen only after a stall, as old events, is not told either.
	_before_guardian()
	for i: int in LIMIT_TICKS:
		_sim.step()
		if _sim.expedition.battle != null:
			break
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	for i: int in 30:
		_sim.step()
	assert_eq(_sim.expedition.state, Expedition.State.REVIVING, "wiped during a stall")
	_world.sync(STEP)
	_hud.advance(STEP)
	assert_false(_note().is_shown(), "no note for an old wipe")


# --- R6 ------------------------------------------------------------------------


func test_r6_journal() -> void:
	assert_true(_guardian_wipe(), "the party loses to the guardian")
	assert_eq(_journal_sentence(), _first_line(), "the journal's line is the note's first line")
	assert_true(_until_standing(), "the heroes stand")
	assert_true(_guardian_wipe(), "and again")
	assert_eq(_journal_sentence(), _first_line(), "with the count")
	assert_true(_journal_sentence().ends_with("(2 times)"), "counted")
	assert_true(_until_standing(), "the heroes stand")
	_hunting_on(DEEP, SAFE)
	assert_true(_lose_next_fight(), "the party loses on depth 7")
	assert_eq(_journal_sentence(), _first_line(), "an ordinary defeat's line too")


# --- R7 ------------------------------------------------------------------------


func test_r7_nothing_else_changes() -> void:
	var watched: Simulation = _sim
	var plain := Simulation.new(SEED)
	for sim: Simulation in [watched, plain]:
		_sim = sim
		_before_guardian()
	_sim = watched
	var shown: bool = false
	var wipes: int = 0
	for i: int in LIMIT_TICKS:
		watched.step()
		plain.step()
		_world.sync(0.1)
		_hud.advance(0.1)
		shown = shown or _note().is_shown()
		if plain.expedition.state == Expedition.State.REVIVING and wipes == 0:
			wipes += 1
		if i % 100 == 0:
			assert_eq(watched.state_hash(), plain.state_hash(), "equal at tick %d" % i)
	assert_eq(wipes, 1, "the party lost to the guardian on its own")
	assert_true(shown, "and the note was shown")
	assert_eq(watched.state_hash(), plain.state_hash(), "equal at the end")

extends GutTest
## Acceptance tests for specs/035-party-orders/spec.md, one per requirement.
##
## The HUD tests build a World on a seeded simulation with the CombatEffects and the Hud on it,
## every _process turned off, and step it by hand; the key tests run the main scene. Nothing here
## reads or writes the real save or settings file: saves are dictionaries passed through JSON in
## memory, and the main scene run here has neither.

## State hashes of an untouched simulation every 600 ticks up to 20 minutes, recorded on dev at
## 3f48247, before this spec changed any sim code.
## Re-recorded by spec 036, whose opening (stability, respawn and XP) is quicker.
const RECORDED_HASHES: Dictionary = {
	7:
	[
		2840655281,
		2075673128,
		1475654766,
		2875557886,
		2784050463,
		3856899135,
		2838792657,
		1321820002,
		2680065727,
		363122329,
		1518956812,
		1963694730,
		3242618005,
		4032510544,
		1473335814,
		2555808367,
		2104573394,
		4011715026,
		831463122,
		2254641605,
	],
	29:
	[
		611997602,
		4245644670,
		2143765798,
		2671802714,
		1395746236,
		3338831802,
		4129929813,
		2159254304,
		1759025754,
		3469722866,
		360968830,
		3156032218,
		2805583006,
		4216963523,
		1449751589,
		1586222788,
		1444904605,
		1703910579,
		370663900,
		2733464942,
	],
}
const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 1
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
const STRONG_LEVEL: int = 40
const GUARDIAN_DEPTH: int = 5
const TICKS_PER_SECOND: int = 10
const HOUR_TICKS: int = 36_000
const R6_SEEDS: Array[int] = [1, 2, 3]
## The heroes' level from which a party switched to Challenge should beat the first guardian.
const SWITCH_LEVEL: int = 9
const EPSILON: float = 0.0001
const CAUTIOUS: Expedition.Pace = Expedition.Pace.CAUTIOUS
const STEADY: Expedition.Pace = Expedition.Pace.STEADY
const BOLD: Expedition.Pace = Expedition.Pace.BOLD
const CHALLENGE: Expedition.GuardianOrder = Expedition.GuardianOrder.CHALLENGE
const HOLD: Expedition.GuardianOrder = Expedition.GuardianOrder.HOLD

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud

# --- Helpers -------------------------------------------------------------------


func after_each() -> void:
	_sim = null
	_world = null
	_fx = null
	_hud = null


func _make_hud(sim: Simulation) -> void:
	_sim = sim
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
	_hud.advance(0.0)


## One tick, with the world and the HUD brought up to date as a frame would.
func _tick() -> void:
	_sim.step()
	_world.sync(0.0)
	_hud.advance(0.0)


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


func _of_kind(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(parsed is Dictionary, "the save survives JSON")
	return parsed as Dictionary


func _any_names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.contains(field):
			return true
	return false


func _raise(sim: Simulation, level: int) -> void:
	for hero: Hero in sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


func _populated(sim: Simulation, depth: int) -> int:
	for room: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
		if sim.expedition.is_populated(depth, room.index):
			return room.index
	return -1


## Puts the party on [param depth], just outside chamber [param index], walking into it.
func _approach(sim: Simulation, depth: int, index: int) -> void:
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth
	var room: LabyrinthChamber = sim.labyrinth.level(depth).chambers[index]
	e.x = room.rect.position.x - 0.1
	e.facing = 1


## The guardian's chamber at [param depth], and the column just outside it the party turns at.
func _mouth(sim: Simulation, depth: int) -> float:
	var shaft: LabyrinthChamber = sim.labyrinth.level(depth).shaft_chamber()
	return shaft.rect.position.x - 1.0 if shaft.index > 0 else float(shaft.rect.end.x)


## Puts the party on [param depth], [param back] tiles short of its guardian's chamber, walking
## toward it with a deeper target and auto-push off.
func _before_guardian(sim: Simulation, depth: int, back: float = 0.0) -> void:
	var e: Expedition = sim.expedition
	var shaft: LabyrinthChamber = sim.labyrinth.level(depth).shaft_chamber()
	sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0 - back
		e.facing = 1
	else:
		e.x = shaft.rect.end.x + back
		e.facing = -1


func _in_guardian_chamber(sim: Simulation, depth: int) -> bool:
	var e: Expedition = sim.expedition
	if e.depth != depth:
		return false
	var shaft: LabyrinthChamber = sim.labyrinth.level(depth).shaft_chamber()
	return floori(e.x) >= shaft.rect.position.x and floori(e.x) < shaft.rect.end.x


func _fighting_guardian(sim: Simulation) -> bool:
	var battle: Battle = sim.expedition.battle
	if battle == null:
		return false
	for monster: Combatant in battle.monsters:
		var def: MonsterDef = Content.monster(monster.def_id)
		if def != null and def.guardian:
			return true
	return false


## Every event of [param sim] over [param ticks] ticks.
func _run(sim: Simulation, ticks: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events


## The party fights a chamber on stage 1 at [param pace], every hero at [param share] of its health
## and nobody hurt or healed in the fight; true if it rests afterwards.
func _rests_after_fight_at(pace: Expedition.Pace, share: float) -> bool:
	var sim := Simulation.new(SEED)
	sim.set_pace(pace)
	sim.step()
	assert_eq(sim.expedition.pace, pace, "the pace is set")
	_approach(sim, 1, _populated(sim, 1))
	for i: int in 50:
		sim.step()
		if sim.expedition.state == Expedition.State.FIGHTING:
			break
	var battle: Battle = sim.expedition.battle
	assert_not_null(battle, "a fight starts")
	if battle == null:
		return false
	for fighter: Combatant in battle.heroes:
		fighter.health = roundi(share * fighter.max_health)
		fighter.heal_power = 0
	for monster: Combatant in battle.monsters:
		monster.health = 0  # beaten before anyone strikes
	sim.step()
	assert_eq(battle.result(), Battle.Result.HEROES_WON, "the heroes win at once")
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.health, roundi(share * hero.max_health()), "nobody hurt or healed")
	return sim.expedition.state == Expedition.State.RESTING


# --- R1 ------------------------------------------------------------------------


func test_r1_pace() -> void:
	assert_eq(Simulation.new(SEED).expedition.pace, STEADY, "Steady by default")
	var cases: Array = [[CAUTIOUS, 0.8], [STEADY, 0.6], [BOLD, 0.4]]
	for entry: Array in cases:
		var pace: Expedition.Pace = entry[0]
		var share: float = entry[1]
		var pace_name: String = Expedition.Pace.keys()[pace]
		assert_true(_rests_after_fight_at(pace, share - 0.05), "%s rests just below" % pace_name)
		assert_false(_rests_after_fight_at(pace, share + 0.05), "%s goes on above" % pace_name)
	# Steady is the rule from before orders.
	assert_eq(Expedition.REST_BELOW, 0.6, "Steady is today's rule")


# --- R2 ------------------------------------------------------------------------


func test_r2_guardians() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	assert_eq(e.guardian_order, CHALLENGE, "Challenge by default")
	_raise(sim, STRONG_LEVEL)
	e.stable_seconds = 60.0
	sim.set_guardian_order(HOLD)
	sim.step()
	_before_guardian(sim, GUARDIAN_DEPTH, 6.0)
	var mouth: float = _mouth(sim, GUARDIAN_DEPTH)
	var turned_at_mouth: bool = false
	var stable: bool = false
	var holding_seen: bool = false
	for i: int in 3000:
		var facing: int = e.facing
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED and event.amount == GUARDIAN_DEPTH:
				stable = true
		holding_seen = holding_seen or e.is_holding()
		if e.facing != facing and absf(e.x - mouth) < EPSILON:
			turned_at_mouth = true
		assert_false(_fighting_guardian(sim), "no battle with a living guardian under Hold")
		assert_false(_in_guardian_chamber(sim, GUARDIAN_DEPTH), "never in its chamber")
		if _fighting_guardian(sim) or _in_guardian_chamber(sim, GUARDIAN_DEPTH):
			return
	assert_eq(e.depth, GUARDIAN_DEPTH, "it keeps hunting on the guardian's level")
	assert_true(turned_at_mouth, "it turns back at the chamber's mouth")
	assert_true(holding_seen, "it is holding")
	assert_true(stable, "the level still becomes stable")
	assert_eq(e.last_stable_depth, GUARDIAN_DEPTH, "stable as any other level")

	# Challenge sends it in on its next pass: no more turning at the mouth.
	sim.set_guardian_order(CHALLENGE)
	var met: bool = false
	var turned_again: bool = false
	var pass_ticks: int = roundi(Labyrinth.LEVEL_WIDTH / Expedition.PARTY_SPEED * TICKS_PER_SECOND)
	for i: int in pass_ticks * 4:
		var facing: int = e.facing
		sim.step()
		sim.drain_events()
		if e.facing != facing and absf(e.x - mouth) < EPSILON:
			turned_again = true
		if _fighting_guardian(sim):
			met = true
			break
	assert_true(met, "Challenge sends it in")
	assert_false(e.is_holding(), "no longer holding")
	assert_false(turned_again, "on its next pass")
	var slain: bool = false
	for i: int in 3000:
		sim.step()
		if not _of_kind(sim.drain_events(), SimEvent.Kind.GUARDIAN_SLAIN).is_empty():
			slain = true
			break
	assert_true(slain, "the strong party beats it")

	# A beaten guardian's chamber is crossed under Hold.
	sim.set_guardian_order(HOLD)
	sim.step()
	_before_guardian(sim, GUARDIAN_DEPTH, 6.0)
	var crossed: bool = false
	for i: int in 3000:
		sim.step()
		sim.drain_events()
		if e.depth == GUARDIAN_DEPTH + 1:
			crossed = true
			break
	assert_true(crossed, "the empty chamber is crossed under Hold")


# --- R3 ------------------------------------------------------------------------


func test_r3_commands() -> void:
	assert_lt(
		SimEvent.Kind.ORDER_CHANGED, SimEvent.Kind.ENCOUNTER_STARTED, "before ENCOUNTER_STARTED"
	)
	var sim := Simulation.new(SEED)
	sim.step()
	sim.drain_events()
	sim.set_pace(BOLD)
	sim.set_guardian_order(HOLD)
	assert_eq(sim.expedition.pace, STEADY, "the pace waits for the next step")
	assert_eq(sim.expedition.guardian_order, CHALLENGE, "and so does the guardian order")
	sim.step()
	assert_eq(sim.expedition.pace, BOLD, "the pace from the next step")
	assert_eq(sim.expedition.guardian_order, HOLD, "and the guardian order")
	var changed: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.ORDER_CHANGED)
	assert_eq(changed.size(), 2, "an event for each")
	if changed.size() == 2:
		assert_eq(changed[0].target_id, 0, "0 for the pace")
		assert_eq(changed[0].amount, BOLD, "the new pace")
		assert_eq(changed[1].target_id, 1, "1 for the guardian order")
		assert_eq(changed[1].amount, HOLD, "the new order")
		assert_eq(changed[0].tick, sim.tick, "stamped with the step")
	# Asking for what is already so changes nothing.
	sim.set_pace(BOLD)
	sim.step()
	assert_true(_of_kind(sim.drain_events(), SimEvent.Kind.ORDER_CHANGED).is_empty(), "no event")
	# A value that is no order is ignored.
	var no_pace: int = 7
	var no_order: int = -3
	sim.set_pace(no_pace as Expedition.Pace)
	sim.set_guardian_order(no_order as Expedition.GuardianOrder)
	sim.step()
	assert_eq(sim.expedition.pace, BOLD, "an unknown pace is ignored")
	assert_eq(sim.expedition.guardian_order, HOLD, "an unknown order is ignored")
	assert_true(_of_kind(sim.drain_events(), SimEvent.Kind.ORDER_CHANGED).is_empty(), "no event")


# --- R4 ------------------------------------------------------------------------


func test_r4_saved() -> void:
	var sim := Simulation.new(SEED)
	sim.set_pace(CAUTIOUS)
	sim.set_guardian_order(HOLD)
	_run(sim, 20)
	var data: Dictionary = _through_json(sim.to_save())
	var version: int = data["version"]
	assert_eq(version, 6, "the version rose by one (and by one more for spec 049)")
	assert_eq(Simulation.SAVE_VERSION, 6)
	var saved_pace: String = str(data.get("pace"))
	var saved_order: String = str(data.get("guardian_order"))
	assert_eq(saved_pace, "cautious", "the pace by name")
	assert_eq(saved_order, "hold", "the guardian order by name")
	var loaded: Simulation = Simulation.from_save(data)
	assert_not_null(loaded, "it loads")
	if loaded != null:
		assert_eq(loaded.expedition.pace, CAUTIOUS, "the pace comes back")
		assert_eq(loaded.expedition.guardian_order, HOLD, "and the guardian order")
	var bold: Simulation = Simulation.new(SEED)
	bold.set_pace(BOLD)
	bold.step()
	var bold_loaded: Simulation = Simulation.from_save(_through_json(bold.to_save()))
	assert_eq(bold_loaded.expedition.pace, BOLD, "Bold comes back")
	assert_eq(bold_loaded.expedition.guardian_order, CHALLENGE, "with Challenge")

	# The previous version loads with the defaults.
	var old: Dictionary = data.duplicate(true)
	old["version"] = 4
	old.erase("pace")
	old.erase("guardian_order")
	assert_eq(Simulation.save_problems(old).size(), 0, "version 4 is fine: %s" % [old])
	var upgraded: Dictionary = Simulation.upgrade_save(old)
	var upgraded_version: int = upgraded["version"]
	assert_eq(upgraded_version, 6, "through the upgrade steps")
	var old_loaded: Simulation = Simulation.from_save(old)
	assert_not_null(old_loaded, "version 4 loads")
	if old_loaded != null:
		assert_eq(old_loaded.expedition.pace, STEADY, "with Steady")
		assert_eq(old_loaded.expedition.guardian_order, CHALLENGE, "and Challenge")

	# Bad values are refused by name.
	for field: String in ["pace", "guardian_order"]:
		for bad_value: Variant in [null, 1, "fast", "Steady", true, [], {}]:
			var bad: Dictionary = data.duplicate(true)
			if bad_value == null:
				bad.erase(field)
			else:
				bad[field] = bad_value
			var problems: PackedStringArray = Simulation.save_problems(bad)
			assert_true(
				_any_names(problems, field),
				"%s %s refused by name: %s" % [field, bad_value, problems]
			)
			assert_null(Simulation.from_save(bad), "%s %s not loaded" % [field, bad_value])
	assert_push_error_count(0)
	assert_engine_error_count(0)


# --- R5 ------------------------------------------------------------------------


func test_r5_defaults_change_nothing() -> void:
	for seed_value: int in RECORDED_HASHES:
		var sim := Simulation.new(seed_value)
		var hashes: Array = []
		for i: int in 12_000:
			sim.step()
			sim.drain_events()
			if sim.tick % 600 == 0:
				hashes.append(sim.state_hash())
		var recorded: Array = RECORDED_HASHES[seed_value]
		assert_eq(hashes, recorded, "seed %d hashes as before" % seed_value)
	# An order away from its default is part of the state.
	var plain := Simulation.new(7)
	var bold := Simulation.new(7)
	var holding := Simulation.new(7)
	bold.set_pace(BOLD)
	holding.set_guardian_order(HOLD)
	for sim: Simulation in [plain, bold, holding]:
		sim.step()
	assert_ne(bold.state_hash(), plain.state_hash(), "the pace changes the hash")
	assert_ne(holding.state_hash(), plain.state_hash(), "the guardian order changes the hash")


# --- R6 ------------------------------------------------------------------------


## One hour of [param sim] at stable_seconds 120: [rests, wipes].
func _hour_counts(sim: Simulation) -> Array[int]:
	sim.expedition.stable_seconds = 120.0
	var events: Array[SimEvent] = _run(sim, HOUR_TICKS)
	var rests: int = _of_kind(events, SimEvent.Kind.REST_STARTED).size()
	var wipes: int = _of_kind(events, SimEvent.Kind.PARTY_WIPED).size()
	return [rests, wipes]


func _lowest_level(sim: Simulation) -> int:
	var lowest: int = 1_000_000
	for hero: Hero in sim.party.heroes:
		lowest = mini(lowest, hero.level)
	return lowest


func test_r6_they_do_what_they_say() -> void:
	var cautious_rests: int = 0
	var bold_rests: int = 0
	var cautious_wipes: int = 0
	var bold_wipes: int = 0
	var beaten: int = 0
	for seed_value: int in R6_SEEDS:
		var cautious := Simulation.new(seed_value)
		cautious.set_pace(CAUTIOUS)
		var bold := Simulation.new(seed_value)
		bold.set_pace(BOLD)
		var c: Array[int] = _hour_counts(cautious)
		var b: Array[int] = _hour_counts(bold)
		gut.p(
			(
				"seed %d: cautious rests %d wipes %d, bold rests %d wipes %d"
				% [seed_value, c[0], c[1], b[0], b[1]]
			)
		)
		cautious_rests += c[0]
		cautious_wipes += c[1]
		bold_rests += b[0]
		bold_wipes += b[1]

		# Hold: never a guardian, never past depth 5, and still fighting and earning there.
		var held := Simulation.new(seed_value)
		held.set_guardian_order(HOLD)
		held.expedition.stable_seconds = 120.0
		var deepest: int = 1
		var guardian_fights: int = 0
		var late_fights: int = 0
		var late_gold: int = 0
		for i: int in HOUR_TICKS:
			held.step()
			deepest = maxi(deepest, held.expedition.depth)
			for event: SimEvent in held.drain_events():
				if event.kind == SimEvent.Kind.ENCOUNTER_STARTED and _fighting_guardian(held):
					guardian_fights += 1
				if i < HOUR_TICKS - 6000 or held.expedition.depth != GUARDIAN_DEPTH:
					continue
				if event.kind == SimEvent.Kind.ENCOUNTER_STARTED:
					late_fights += 1
				elif event.kind == SimEvent.Kind.GOLD_GAINED:
					late_gold += event.amount
		assert_eq(guardian_fights, 0, "seed %d: Hold never fights a guardian" % seed_value)
		assert_eq(deepest, GUARDIAN_DEPTH, "seed %d: Hold reaches depth 5, never past" % seed_value)
		assert_gt(
			late_fights,
			0,
			"seed %d: fighting on Mossy Hollow 5 in the last ten minutes" % seed_value
		)
		assert_gt(late_gold, 0, "seed %d: and earning" % seed_value)

		# Switched to Challenge as soon as every hero is level 9: the first guardian falls within
		# ten minutes.
		var switched := Simulation.new(seed_value)
		switched.set_guardian_order(HOLD)
		switched.expedition.stable_seconds = 120.0
		for i: int in HOUR_TICKS * 2:
			if _lowest_level(switched) >= SWITCH_LEVEL:
				break
			switched.step()
			switched.drain_events()
		var level: int = _lowest_level(switched)
		assert_gte(level, SWITCH_LEVEL, "seed %d: the heroes reach level 9" % seed_value)
		switched.set_guardian_order(CHALLENGE)
		var slain_at: int = -1
		for event: SimEvent in _run(switched, 6000):
			if event.kind == SimEvent.Kind.GUARDIAN_SLAIN and slain_at < 0:
				slain_at = event.tick
				beaten += 1
		gut.p("seed %d: switched at level %d, slain at tick %d" % [seed_value, level, slain_at])
	gut.p(
		(
			"cautious rests %d wipes %d, bold rests %d wipes %d, beaten %d"
			% [cautious_rests, cautious_wipes, bold_rests, bold_wipes, beaten]
		)
	)
	assert_gt(cautious_rests, bold_rests, "a Cautious party rests more often than a Bold one")
	assert_lte(cautious_wipes, bold_wipes, "and wipes no more often")
	assert_gte(beaten, 2, "the guardian falls within ten minutes on two of three seeds")


# --- R7 ------------------------------------------------------------------------


func _lit_choice(order: int) -> int:
	var lit: int = -1
	var buttons: Array = _hud.orders.choice_buttons[order]
	for i: int in buttons.size():
		var button: HudButton = buttons[i]
		if button.lit:
			assert_eq(lit, -1, "one choice lit in row %d" % order)
			lit = i
	return lit


func test_r7_orders_panel() -> void:
	_make_hud(Simulation.new(SEED))
	var orders: OrdersPanel = _hud.orders
	assert_not_null(orders, "the HUD has an orders panel")
	assert_not_null(_hud.orders_button, "and an Orders button")
	if orders == null or _hud.orders_button == null:
		return
	assert_eq(_hud.orders_button.text, "Orders")
	assert_true(_hud.orders_button.is_visible_in_tree(), "on screen")
	assert_lte(_hud.orders_button.get_global_rect().end.y, TOP_BAND, "in the top band")
	assert_false(orders.is_open(), "closed at first")
	_hud.orders_button.pressed.emit()
	assert_true(orders.is_open(), "the button opens it")
	assert_true(orders.is_visible_in_tree(), "and it shows")
	assert_true(_hud.orders_button.lit, "the button is lit while open")
	_hud.orders_button.pressed.emit()
	assert_false(orders.is_open(), "and closes it")
	_key(KEY_O)
	assert_true(orders.is_open(), "O opens it")
	_key(KEY_O)
	assert_false(orders.is_open(), "O closes it")
	_key(KEY_O)
	_key(KEY_ESCAPE)
	assert_false(orders.is_open(), "Esc closes it")
	_key(KEY_ESCAPE)
	assert_false(orders.is_open(), "and does not open it")

	# A row per order: its name, the current choice explained, a button per choice.
	orders.open()
	_hud.advance(0.0)
	assert_eq(orders.choice_buttons.size(), 2, "two rows")
	assert_eq(orders.name_labels[0].text, "Pace", "the pace row")
	assert_eq(orders.name_labels[1].text, "Guardians", "the guardian row")
	var pace_texts: Array[String] = []
	for button: HudButton in orders.choice_buttons[0]:
		pace_texts.append(button.text)
	assert_eq(pace_texts, ["Cautious", "Steady", "Bold"] as Array[String], "the paces")
	var guardian_texts: Array[String] = []
	for button: HudButton in orders.choice_buttons[1]:
		guardian_texts.append(button.text)
	assert_eq(guardian_texts, ["Challenge", "Hold"] as Array[String], "the guardian orders")
	assert_eq(orders.line(0), "Steady: rest below 60% health", "Steady explained")
	assert_eq(orders.line(1), "Challenge: fight guardians to go deeper", "Challenge explained")
	assert_eq(orders.line_labels[0].text, orders.line(0), "the line is shown")
	assert_eq(_lit_choice(0), STEADY, "Steady lit")
	assert_eq(_lit_choice(1), CHALLENGE, "Challenge lit")

	# A click sends the command; the choice lights at once and the simulation follows.
	(orders.choice_buttons[0][BOLD] as HudButton).pressed.emit()
	assert_eq(_lit_choice(0), BOLD, "Bold lit at once")
	assert_eq(orders.line(0), "Bold: rest only below 40% health", "Bold explained")
	_tick()
	assert_eq(_sim.expedition.pace, BOLD, "the command reached the simulation")
	(orders.choice_buttons[1][HOLD] as HudButton).pressed.emit()
	_tick()
	assert_eq(_sim.expedition.guardian_order, HOLD, "Hold reached the simulation")
	assert_eq(_lit_choice(1), HOLD, "Hold lit")
	assert_eq(orders.line(1), "Hold: do not fight guardians until told", "Hold explained")
	orders.choose(0, CAUTIOUS)
	_tick()
	assert_eq(_sim.expedition.pace, CAUTIOUS, "choose sends it too")
	assert_eq(orders.line(0), "Cautious: rest below 80% health", "Cautious explained")
	# It follows the simulation, not its own memory.
	_sim.set_pace(STEADY)
	_tick()
	assert_eq(_lit_choice(0), STEADY, "follows the simulation")

	# A loaded save shows the saved orders.
	_sim.set_pace(BOLD)
	_tick()
	var loaded: Simulation = Simulation.from_save(_through_json(_sim.to_save()))
	_make_hud(loaded)
	_hud.orders.open()
	_hud.advance(0.0)
	assert_eq(_lit_choice(0), BOLD, "a loaded save: Bold lit")
	assert_eq(_lit_choice(1), HOLD, "and Hold")
	assert_eq(_hud.orders.line(0), "Bold: rest only below 40% health")

	# The panels exclude one another.
	orders = _hud.orders
	var others: Dictionary = {
		"the shop": [KEY_U, _hud.shop.is_open],
		"the hero sheet": [KEY_TAB, _hud.hero_sheet.is_open],
		"the journal": [KEY_J, _hud.journal.is_open],
		"help": [KEY_H, _hud.help.is_open],
	}
	for what: String in others:
		var keycode: Key = others[what][0]
		var other_open: Callable = others[what][1]
		orders.close()
		_key(keycode)
		_hud.advance(0.0)
		var was_open: bool = other_open.call()
		assert_true(was_open, "%s is open" % what)
		_key(KEY_O)
		_hud.advance(0.0)
		assert_true(orders.is_open(), "orders open over %s" % what)
		var still_open: bool = other_open.call()
		assert_false(still_open, "and close %s" % what)
		_key(keycode)
		_hud.advance(0.0)
		var reopened: bool = other_open.call()
		assert_true(reopened, "%s opens" % what)
		assert_false(orders.is_open(), "and orders close for %s" % what)
	_hud.hero_sheet.close()
	_hud.help.close()
	_hud.shop.close()
	_hud.journal.close()

	# The game goes on behind it.
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.hud.orders.open()
	main.driver.advance(1_000_000)
	var tick: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(main.hud.orders.is_open(), "orders are open")
	assert_gt(main.simulation.tick, tick, "and the game runs behind them")


# --- R8 ------------------------------------------------------------------------


func test_r8_status_and_journal() -> void:
	_make_hud(Simulation.new(SEED))
	_raise(_sim, STRONG_LEVEL)
	_sim.set_guardian_order(HOLD)
	_tick()
	_before_guardian(_sim, GUARDIAN_DEPTH, 3.0)
	var guardian: MonsterDef = Content.monster(_sim.expedition.guardian_of(GUARDIAN_DEPTH))
	var wanted: String = "Holding at the %s" % guardian.display_name
	assert_eq(wanted, "Holding at the Slime King", "the first guardian")
	_hud.advance(0.0)
	assert_eq(_hud.status_text(), wanted, "walking toward its chamber under Hold")
	assert_eq(_hud.state_label.text, wanted, "shown in the status line")
	var turned: bool = false
	var hunting_seen: bool = false
	var facing: int = _sim.expedition.facing
	for i: int in 600:
		_tick()
		if _sim.expedition.state != Expedition.State.TRAVELLING:
			continue
		assert_eq(_hud.status_text(), wanted, "holding while travelling, tick %d" % i)
		if _sim.expedition.facing != facing:
			turned = true
		elif turned:
			hunting_seen = true
		if hunting_seen:
			break
	assert_true(turned, "it turned back")
	assert_true(hunting_seen, "and hunts on, still holding")
	# Challenge: no longer holding. (Spec 040 R4: the party is certainly travelling here.)
	_sim.set_guardian_order(CHALLENGE)
	_tick()
	assert_eq(_sim.expedition.state, Expedition.State.TRAVELLING, "travelling under Challenge")
	assert_eq(_hud.status_text(), "Heading down to stage 6", "heading down again")
	# With the target here, it only hunts.
	_sim.set_guardian_order(HOLD)
	_sim.set_target_depth(GUARDIAN_DEPTH)
	_tick()
	assert_eq(_sim.expedition.state, Expedition.State.TRAVELLING, "travelling with the target here")
	assert_eq(_hud.status_text(), "Hunting on stage 5", "not holding with the target here")

	# The journal writes a line for an order change.
	_sim.set_pace(BOLD)
	_tick()
	assert_eq(_hud.journal.lines()[0].get_slice("  ", 1), "Ordered a Bold pace", "the pace line")
	_sim.set_guardian_order(CHALLENGE)
	_tick()
	assert_eq(
		_hud.journal.lines()[0].get_slice("  ", 1),
		"Ordered to challenge guardians",
		"the guardian line"
	)
	_sim.set_guardian_order(HOLD)
	_tick()
	assert_eq(
		_hud.journal.lines()[0].get_slice("  ", 1), "Ordered to hold at guardians", "Hold's line"
	)


# --- R9 ------------------------------------------------------------------------


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func _frames_top() -> float:
	var top: float = SCREEN.y
	for frame: HeroFrame in _hud.frames:
		top = minf(top, frame.get_global_rect().position.y)
	return top


## Rests the mouse on [param control] and returns the tooltip's sentence, checking it is one plain
## sentence in a box on the screen, clear of the control.
func _check_tip(what: String, control: Control) -> String:
	var tooltip: HudTooltip = _hud.tooltip
	var rect: Rect2 = control.get_global_rect()
	_mouse(Vector2(SCREEN.x / 2.0, 300))
	_hud.advance(1.0)
	_mouse(rect.get_center())
	_hud.advance(0.2)
	_hud.advance(0.15)
	assert_eq(tooltip.shown_text(), "", "%s: nothing before 0.4 s" % what)
	_hud.advance(0.06)
	var text: String = tooltip.shown_text()
	assert_ne(text, "", "%s: a sentence after 0.4 s" % what)
	assert_true(text.ends_with("."), "%s: one sentence: %s" % [what, text])
	assert_false(text.trim_suffix(".").contains(". "), "%s: only one: %s" % [what, text])
	var box: Rect2 = tooltip.box.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(box), "%s: on the screen %s" % [what, box])
	assert_false(box.intersects(rect), "%s: clear of the element %s %s" % [what, box, rect])
	_mouse(Vector2(SCREEN.x / 2.0, 300))
	_hud.advance(0.016)
	return text


func test_r9_explains_itself() -> void:
	_make_hud(Simulation.new(SEED))
	var seen: Dictionary[String, String] = {}
	var button_text: String = _check_tip("the Orders button", _hud.orders_button)
	assert_string_contains(button_text.to_lower(), "orders", "the button's tip names orders")
	seen[button_text] = "the Orders button"
	_hud.orders.open()
	_hud.advance(0.0)
	for order: int in _hud.orders.choice_buttons.size():
		for button: HudButton in _hud.orders.choice_buttons[order]:
			var what: String = "the %s choice" % button.text
			var text: String = _check_tip(what, button)
			assert_false(seen.has(text), "%s says what %s says" % [what, seen.get(text, "")])
			seen[text] = what
	_hud.orders.close()

	# O is in the help panel's key list, and the panel still fits.
	var listed: bool = false
	for entry: Array in HelpPanel.KEYS:
		if HelpPanel.keycodes(str(entry[0])).has(KEY_O):
			listed = true
			assert_has(_hud.help.lines(), "%s  %s" % [entry[0], entry[1]], "the panel lists O")
	assert_true(listed, "O is in the key list")
	_hud.help.open()
	_hud.advance(0.0)
	var rect: Rect2 = _hud.help.get_global_rect()
	assert_gte(rect.position.y, TOP_BAND, "help below the top band %s" % rect)
	assert_lte(rect.end.y, _frames_top(), "help above the party frames %s" % rect)
	var labels: Array[Label] = []
	_collect_labels(_hud.help, labels)
	for label: Label in labels:
		if label.is_visible_in_tree():
			assert_true(rect.encloses(label.get_global_rect()), "%s inside help" % label.text)


# --- R10 -----------------------------------------------------------------------


## Checks the Orders button and the open panel against everything they must stay clear of.
func _check_fits(what: String) -> void:
	_hud.advance(0.0)
	var screen := Rect2(Vector2.ZERO, SCREEN)
	var button: Rect2 = _hud.orders_button.get_global_rect()
	assert_true(screen.encloses(button), "%s: the button on screen %s" % [what, button])
	assert_lte(button.end.y, TOP_BAND, "%s: the button in the top band" % what)
	var band: Dictionary = {
		"the depth panel": _hud.depth_panel,
		"the gold": _hud.gold_panel,
		"the Shop button": _hud.shop_button,
		"the speed button": _hud.speed_button,
		"the ? button": _hud.help_button,
		"the shop marker": _hud.shop_marker,
	}
	for part: String in band:
		var control: Control = band[part]
		if control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			assert_false(button.intersects(rect), "%s: button clear of %s %s" % [what, part, rect])
	if _hud.boss_bar.is_showing():
		var bar: Rect2 = _hud.boss_bar.get_global_rect()
		assert_false(button.intersects(bar), "%s: button clear of the boss bar %s" % [what, bar])
	assert_true(
		(
			_hud.shop_tab.get_global_rect().encloses(button)
			or _hud.depth_panel.get_global_rect().encloses(button)
		),
		"%s: the button sits on a top panel" % what
	)
	_hud.orders.open()
	_hud.advance(0.0)
	var panel: Rect2 = _hud.orders.get_global_rect()
	assert_true(screen.encloses(panel), "%s: the panel on screen %s" % [what, panel])
	assert_gte(panel.position.y, TOP_BAND, "%s: the panel below the top band %s" % [what, panel])
	assert_lte(panel.end.y, _frames_top(), "%s: the panel above the frames %s" % [what, panel])
	for frame: HeroFrame in _hud.frames:
		assert_false(panel.intersects(frame.get_global_rect()), "%s: off the frames" % what)
	if _hud.boss_bar.is_showing():
		assert_false(
			panel.intersects(_hud.boss_bar.get_global_rect()), "%s: off the boss bar" % what
		)
	if _hud.ladder.is_visible_in_tree():
		var ladder: Rect2 = _hud.ladder.get_global_rect()
		assert_false(panel.intersects(ladder), "%s: off the depth ladder %s" % [what, ladder])
	var labels: Array[Label] = []
	_collect_labels(_hud.orders, labels)
	var shown: Array[Control] = []
	for label: Label in labels:
		if label.is_visible_in_tree() and not label.text.is_empty():
			shown.append(label)
	for row: Array in _hud.orders.choice_buttons:
		for choice: HudButton in row:
			shown.append(choice)
	for control: Control in shown:
		var rect: Rect2 = control.get_global_rect()
		assert_true(panel.encloses(rect), "%s: %s inside the panel" % [what, control.name])
		for other: Control in shown:
			if other != control and other.get_global_rect().intersects(rect):
				fail_test("%s: %s overlaps %s" % [what, control.name, other.name])
	_hud.orders.close()


func test_r10_it_fits() -> void:
	_make_hud(Simulation.new(SEED))
	_check_fits("at the start")
	_sim.party.gold = 9_999_999
	_hud.advance(Hud.GOLD_CATCH_UP_SECONDS + 0.1)
	_check_fits("with a lot of gold")
	_hud.orders.choose(0, BOLD)
	_hud.orders.choose(1, HOLD)
	_tick()
	_check_fits("with the longest lines")
	_hud.orders.choose(1, CHALLENGE)
	_raise(_sim, STRONG_LEVEL)
	_before_guardian(_sim, GUARDIAN_DEPTH)
	var fighting: bool = false
	for i: int in 600:
		_tick()
		if _hud.boss_bar.is_showing():
			fighting = true
			break
	assert_true(fighting, "a guardian fight")
	_check_fits("in a guardian fight")

extends GutTest
## Acceptance tests for specs/040-orders-that-hold/spec.md, one per requirement. R4 lives in
## test_035_party_orders.gd (test_r8_status_and_journal) and R6 is the recorded-hash tests.

const SEED: int = 1
const STRONG_LEVEL: int = 40
const GUARDIAN_DEPTH: int = 5
const CHALLENGE: Expedition.GuardianOrder = Expedition.GuardianOrder.CHALLENGE
const HOLD: Expedition.GuardianOrder = Expedition.GuardianOrder.HOLD
## Ticks a party is given to walk to the ladder and to finish what follows.
const WALK_TICKS: int = 3000
## Ticks of the climb before the order changes: partway up or down the ladder.
const INTO_CLIMB: int = 5
## The orders' names as the panel shows them, before this spec moved them.
const PACE_TEXTS: Array[String] = ["Cautious", "Steady", "Bold"]
const GUARDIAN_TEXTS: Array[String] = ["Challenge", "Hold"]

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## An orders panel on [member _sim], made on its own: spec 058 moved it from the HUD into a window
## on the UI layer.
var _orders: OrdersPanel

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
	_orders = OrdersPanel.new()
	add_child_autofree(_orders)
	_orders.set_process(false)
	_orders.setup(_sim, null)


func _raise(sim: Simulation, level: int) -> void:
	for hero: Hero in sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


func _fighting_guardian(sim: Simulation) -> bool:
	var battle: Battle = sim.expedition.battle
	if battle == null:
		return false
	for monster: Combatant in battle.monsters:
		var def: MonsterDef = Content.monster(monster.def_id)
		if def != null and def.guardian:
			return true
	return false


## A strong party on [param from] in the middle of the level with [param to] as its target,
## auto-push off, under [param order]; stepped until it is [constant INTO_CLIMB] ticks into the
## climb toward [param to]. Null if it never starts climbing.
func _partway_up_the_ladder(from: int, to: int, order: Expedition.GuardianOrder) -> Simulation:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	_raise(sim, STRONG_LEVEL)
	sim.set_auto_push(false)
	sim.set_guardian_order(order)
	sim.step()
	e.depth = from
	e.target_depth = to
	e.x = Labyrinth.LEVEL_WIDTH / 2.0
	for i: int in WALK_TICKS:
		sim.step()
		sim.drain_events()
		if e.state == Expedition.State.CLIMBING:
			break
	assert_eq(e.state, Expedition.State.CLIMBING, "the party starts climbing from %d" % from)
	if e.state != Expedition.State.CLIMBING:
		return null
	for i: int in INTO_CLIMB:
		sim.step()
		sim.drain_events()
	assert_eq(e.state, Expedition.State.CLIMBING, "still on the ladder")
	return sim


## What a climb from [param from] toward [param to] leads to, with the guardian order set to
## [param switch_to] partway up: [the depth it next stands on, the tick it gets there, its column,
## whether it fought the guardian, whether it ever stood on [constant GUARDIAN_DEPTH]].
func _climb_with_switch(from: int, to: int, switch_to: Expedition.GuardianOrder) -> Array:
	var sim: Simulation = _partway_up_the_ladder(from, to, CHALLENGE)
	if sim == null:
		return []
	var e: Expedition = sim.expedition
	sim.set_guardian_order(switch_to)
	var fought: bool = false
	var stood_on_guardian_level: bool = false
	var arrived: Array = []
	for i: int in WALK_TICKS:
		sim.step()
		sim.drain_events()
		fought = fought or _fighting_guardian(sim)
		if e.state != Expedition.State.CLIMBING:
			stood_on_guardian_level = stood_on_guardian_level or e.depth == GUARDIAN_DEPTH
			if arrived.is_empty():
				arrived = [e.depth, sim.tick, e.x]
	if arrived.is_empty():
		return []
	return [arrived[0], arrived[1], arrived[2], fought, stood_on_guardian_level, e.is_holding()]


## The party fights a chamber on depth 1 at [param pace], its last hero at [param last] of its
## health and the others at [param others], nobody hurt or healed in the fight; true if it rests.
func _rests_after_fight(pace: Expedition.Pace, others: float, last: float) -> bool:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	sim.set_pace(pace)
	sim.set_auto_push(false)
	sim.step()
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var room: LabyrinthChamber = null
	for chamber: LabyrinthChamber in level.chambers:
		if room == null and e.is_populated(1, chamber.index):
			room = chamber
	assert_not_null(room, "a populated chamber on depth 1")
	if room == null:
		return false
	e.target_depth = 1
	e.x = room.rect.position.x - 0.1
	e.facing = 1
	for i: int in 50:
		sim.step()
		if e.state == Expedition.State.FIGHTING:
			break
	var battle: Battle = e.battle
	assert_not_null(battle, "a fight starts")
	if battle == null:
		return false
	assert_gt(sim.party.heroes.size(), 1, "a party of more than one")
	var shares: Array[float] = []
	for i: int in sim.party.heroes.size():
		shares.append(last if i == sim.party.heroes.size() - 1 else others)
	var total: int = 0
	var full: int = 0
	for i: int in sim.party.heroes.size():
		var fighter: Combatant = battle.combatant(sim.party.heroes[i].id)
		fighter.health = roundi(shares[i] * fighter.max_health)
		fighter.heal_power = 0
		total += fighter.health
		full += fighter.max_health
	for monster: Combatant in battle.monsters:
		monster.health = 0  # beaten before anyone strikes
	sim.step()
	assert_eq(battle.result(), Battle.Result.HEROES_WON, "the heroes win at once")
	for i: int in sim.party.heroes.size():
		var hero: Hero = sim.party.heroes[i]
		assert_eq(hero.health, roundi(shares[i] * hero.max_health()), "nobody hurt or healed")
	var share: float = PartyOrders.rest_below(pace)
	assert_gt(float(total) / full, share, "the party's total is above the share")
	return e.state == Expedition.State.RESTING


func _lit_choice(order: int) -> int:
	var lit: int = -1
	_orders.advance(0.0)
	var buttons: Array = _orders.choice_buttons[order]
	for i: int in buttons.size():
		var button: UiButton = buttons[i]
		if button.lit:
			assert_eq(lit, -1, "one choice lit in row %d" % order)
			lit = i
	return lit


func _scripts_under(folder: String, into: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			into.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		_scripts_under(folder.path_join(sub), into)


# --- R1 ------------------------------------------------------------------------


func test_r1_hold_on_the_ladder() -> void:
	# Climbing up from below a living guardian, Hold set partway up: back to the level it left.
	var held: Array = _climb_with_switch(GUARDIAN_DEPTH + 1, GUARDIAN_DEPTH - 1, HOLD)
	assert_false(held.is_empty(), "Hold: the party comes off the ladder")
	if not held.is_empty():
		var landed: int = held[0]
		var fought: bool = held[3]
		var stood: bool = held[4]
		var holding: bool = held[5]
		assert_eq(landed, GUARDIAN_DEPTH + 1, "Hold: back on the level it left")
		assert_false(fought, "Hold: no battle with the guardian")
		assert_false(stood, "Hold: never on the guardian's level")
		assert_true(holding, "Hold: and from there it holds")

	# Under Challenge the climb is unchanged: up into the guardian's chamber, and the fight.
	var challenged: Array = _climb_with_switch(GUARDIAN_DEPTH + 1, GUARDIAN_DEPTH - 1, CHALLENGE)
	assert_false(challenged.is_empty(), "Challenge: the party comes off the ladder")
	if not challenged.is_empty():
		var landed: int = challenged[0]
		var fought: bool = challenged[3]
		assert_eq(landed, GUARDIAN_DEPTH, "Challenge: up on the guardian's level")
		assert_true(fought, "Challenge: it fights the guardian")

	# A climb down is unaffected by Hold: same depth, tick and column as without the change.
	var down_held: Array = _climb_with_switch(GUARDIAN_DEPTH - 2, GUARDIAN_DEPTH - 1, HOLD)
	var down: Array = _climb_with_switch(GUARDIAN_DEPTH - 2, GUARDIAN_DEPTH - 1, CHALLENGE)
	assert_false(down.is_empty(), "the climb down ends")
	if not down.is_empty() and not down_held.is_empty():
		var landed: int = down_held[0]
		assert_eq(landed, GUARDIAN_DEPTH - 1, "down under Hold: it arrives below")
		assert_eq(down_held.slice(0, 3), down.slice(0, 3), "down: arrival as without Hold")


# --- R2 ------------------------------------------------------------------------


func test_r2_panel_shows_the_simulation() -> void:
	_make_hud(Simulation.new(SEED))
	var orders: OrdersPanel = _orders
	# A click, then a different command before the step: the simulation ends on the command.
	orders.choose(PartyOrders.PACE, Expedition.Pace.BOLD)
	assert_eq(_lit_choice(PartyOrders.PACE), Expedition.Pace.BOLD, "Bold lit at once")
	_sim.set_pace(Expedition.Pace.CAUTIOUS)
	_sim.step()
	_hud.advance(0.0)
	assert_eq(_sim.expedition.pace, Expedition.Pace.CAUTIOUS, "the simulation holds Cautious")
	assert_eq(_lit_choice(PartyOrders.PACE), Expedition.Pace.CAUTIOUS, "the panel lights it")
	assert_eq(
		orders.line(PartyOrders.PACE),
		OrdersPanel.LINES[PartyOrders.PACE][Expedition.Pace.CAUTIOUS],
		"and explains it"
	)

	orders.choose(PartyOrders.GUARDIANS, HOLD)
	_sim.set_guardian_order(CHALLENGE)
	_sim.step()
	_hud.advance(0.0)
	assert_eq(_sim.expedition.guardian_order, CHALLENGE, "the simulation holds Challenge")
	assert_eq(_lit_choice(PartyOrders.GUARDIANS), CHALLENGE, "the panel lights it")

	# A click the simulation takes still lights at once and stays lit.
	orders.choose(PartyOrders.PACE, Expedition.Pace.STEADY)
	assert_eq(_lit_choice(PartyOrders.PACE), Expedition.Pace.STEADY, "Steady lit at once")
	_sim.step()
	_hud.advance(0.0)
	assert_eq(_lit_choice(PartyOrders.PACE), Expedition.Pace.STEADY, "and after the step")


# --- R3 ------------------------------------------------------------------------


func test_r3_rest_rule_is_per_hero() -> void:
	for pace: Expedition.Pace in Expedition.Pace.values():
		var share: float = PartyOrders.rest_below(pace)
		var pace_name: String = Expedition.Pace.keys()[pace]
		var one_low: bool = _rests_after_fight(pace, 1.0, share - 0.05)
		assert_true(one_low, "%s: one hero below their share rests" % pace_name)
		var all_above: bool = _rests_after_fight(pace, share + 0.05, share + 0.05)
		assert_false(all_above, "%s: every hero above goes on" % pace_name)


# --- R5 ------------------------------------------------------------------------


func test_r5_names_live_in_the_view() -> void:
	var scripts: Array[String] = []
	_scripts_under("res://sim", scripts)
	assert_gt(scripts.size(), 0, "the simulation's scripts are found")
	var quoted: Array[String] = []
	for text: String in PACE_TEXTS + GUARDIAN_TEXTS:
		quoted.append('"%s"' % text)
	for path: String in scripts:
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.contains("PACE_NAMES"), "%s defines no pace names" % path)
		assert_false(source.contains("GUARDIAN_NAMES"), "%s defines no guardian names" % path)
		for text: String in quoted:
			assert_false(source.contains(text), "%s does not name %s" % [path, text])
	assert_eq(OrdersPanel.PACE_NAMES, PACE_TEXTS, "the panel holds the pace names")
	assert_eq(OrdersPanel.GUARDIAN_NAMES, GUARDIAN_TEXTS, "and the guardian orders' names")

	_make_hud(Simulation.new(SEED))
	var shown: Array[String] = []
	for row: Array in _orders.choice_buttons:
		for button: UiButton in row:
			shown.append(button.text)
	assert_eq(shown, PACE_TEXTS + GUARDIAN_TEXTS, "the panel's text is unchanged")

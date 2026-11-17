extends GutTest
## Unit tests for the party's orders (spec 035) below the acceptance tests: the plain rules in
## PartyOrders, and the Hold order on the way up, which the acceptance tests do not reach.

const SEED: int = 1
const STRONG_LEVEL: int = 40


func _room(first: int, last: int) -> LabyrinthChamber:
	var room := LabyrinthChamber.new()
	room.rect = Rect2i(first, 0, last - first + 1, 4)
	return room


func _raise(sim: Simulation, level: int) -> void:
	for hero: Hero in sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


func test_rest_below_each_pace() -> void:
	assert_eq(PartyOrders.rest_below(Expedition.Pace.CAUTIOUS), 0.8)
	assert_eq(PartyOrders.rest_below(Expedition.Pace.STEADY), Expedition.REST_BELOW)
	assert_eq(PartyOrders.rest_below(Expedition.Pace.BOLD), 0.4)


## Spec 040 R3: the rule reads each hero against their own maximum, not the party's total.
func test_needs_rest_is_per_hero() -> void:
	var sim := Simulation.new(SEED)
	var heroes: Array[Hero] = sim.party.heroes
	for pace: Expedition.Pace in Expedition.Pace.values():
		var share: float = PartyOrders.rest_below(pace)
		for hero: Hero in heroes:
			hero.health = ceili((share + 0.05) * hero.max_health())
		assert_false(PartyOrders.needs_rest(heroes, pace), "every hero above: no rest")
		var last: Hero = heroes[heroes.size() - 1]
		last.health = floori((share - 0.05) * last.max_health())
		assert_true(PartyOrders.needs_rest(heroes, pace), "one hero below: rest")
		last.health = 0
		assert_true(PartyOrders.needs_rest(heroes, pace), "one hero down: rest")


func test_short_of_stops_at_the_mouth() -> void:
	var room: LabyrinthChamber = _room(40, 55)
	assert_eq(PartyOrders.short_of(room, 10.0, 60.0), 39.0, "walking right: the column before it")
	assert_eq(PartyOrders.short_of(room, 70.0, 5.0), 56.0, "walking left: the column after it")
	assert_eq(PartyOrders.short_of(room, 10.0, 30.0), 30.0, "a goal short of it is kept")
	assert_eq(PartyOrders.short_of(room, 70.0, 60.0), 60.0, "on either side")
	assert_eq(PartyOrders.short_of(room, 39.5, 47.0), 39.0, "just outside, it steps back out")
	assert_eq(PartyOrders.short_of(room, 45.0, 60.0), 60.0, "already inside: nothing to stop")
	assert_eq(PartyOrders.short_of(null, 10.0, 60.0), 60.0, "no chamber")


func test_names_line_up_with_the_enums() -> void:
	assert_eq(OrdersPanel.PACE_NAMES.size(), Expedition.Pace.size())
	assert_eq(PartyOrders.PACE_SAVED.size(), Expedition.Pace.size())
	assert_eq(OrdersPanel.GUARDIAN_NAMES.size(), Expedition.GuardianOrder.size())
	assert_eq(PartyOrders.GUARDIAN_SAVED.size(), Expedition.GuardianOrder.size())
	assert_eq(OrdersPanel.PACE_NAMES[Expedition.Pace.BOLD], "Bold")
	assert_eq(OrdersPanel.GUARDIAN_NAMES[Expedition.GuardianOrder.HOLD], "Hold")


## Below a living guardian with a shallower target, Hold keeps the party from climbing up into its
## chamber (the ladder ends there); Challenge lets it climb and meet the guardian.
func test_hold_on_the_way_up() -> void:
	for order: Expedition.GuardianOrder in Expedition.GuardianOrder.values():
		var sim := Simulation.new(SEED)
		var e: Expedition = sim.expedition
		_raise(sim, STRONG_LEVEL)
		sim.set_auto_push(false)
		sim.set_guardian_order(order)
		sim.step()
		e.depth = 6
		e.target_depth = 4
		e.x = Labyrinth.LEVEL_WIDTH / 2.0
		var reached_five: bool = false
		var met_guardian: bool = false
		for i: int in 3000:
			sim.step()
			sim.drain_events()
			reached_five = reached_five or e.depth == 5
			if e.battle != null and e.depth == 5:
				met_guardian = true
				break
		if order == Expedition.GuardianOrder.HOLD:
			assert_false(reached_five, "Hold: the party stays below the guardian")
			assert_true(e.is_holding(), "and is holding")
			assert_eq(e.depth, 6, "hunting on depth 6")
		else:
			assert_true(met_guardian, "Challenge: it climbs up into the guardian")
			assert_false(e.is_holding(), "and never holds")

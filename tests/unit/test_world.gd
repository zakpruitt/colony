extends ColonyTest
## Unit tests for World and Bolt details the acceptance tests reach only indirectly.

const FRAME: float = 1.0 / 60.0
const TILE: float = 16.0


func _world(sim: Simulation) -> World:
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	return world


func test_easing_is_capped_at_three_times_walking_speed() -> void:
	var moved: Vector2 = World._eased(Vector2.ZERO, Vector2(1000, 0), FRAME, false)
	assert_almost_eq(moved.x, World.RUN_SPEED * FRAME, 0.001, "a long way: full running speed")
	assert_almost_eq(World.RUN_SPEED, 3.0 * Expedition.PARTY_SPEED * TILE, 0.001)


func test_easing_settles_exactly() -> void:
	var goal := Vector2(10.05, 0)
	assert_eq(World._eased(Vector2(10, 0), goal, FRAME, false), goal, "close enough: on it")


func test_easing_climbs_and_walks_one_way_at_a_time() -> void:
	var on_floor := Vector2(0, 100)
	var on_ladder := Vector2(32, 160)
	var to_ladder: Vector2 = World._eased(on_floor, on_ladder, FRAME, true)
	assert_eq(to_ladder.y, on_floor.y, "while climbing: across to the ladder first")
	assert_gt(to_ladder.x, on_floor.x)
	var off_ladder: Vector2 = World._eased(on_ladder, on_floor, FRAME, false)
	assert_eq(off_ladder.x, on_ladder.x, "after the climb: off the ladder first")
	assert_lt(off_ladder.y, on_ladder.y)


func test_a_fallen_hero_stands_again_when_healed() -> void:
	var sim := Simulation.new(1)
	var world: World = _world(sim)
	var cleric: Hero = sim.party.hero(4)
	cleric.health = 0
	for i: int in 30:
		world.sync(FRAME)
	assert_false(world.character(4).visible, "a hero at 0 health is down")
	cleric.health = 10
	world.sync(FRAME)
	assert_true(world.character(4).visible, "and up again once healed (a rest heals the fallen)")
	assert_false(world.character(4).is_dead())


func test_a_stall_removes_dead_monsters_without_animating() -> void:
	var sim := Simulation.new(1)
	var world: World = _world(sim)
	var monster: Combatant = null
	for chamber_index: int in sim.labyrinth.level(1).chambers.size():
		for waiting: Combatant in sim.expedition.monsters_in(1, chamber_index):
			monster = waiting
	assert_not_null(world.character(monster.id))
	var old: SimEvent = SimEvent.new(SimEvent.Kind.DIED, sim.tick, monster.id)
	for i: int in World.STALL_TICKS + 1:
		sim.step()
	# The event is old by the time the world sees it.
	sim._events.push_front(old)
	world.sync(FRAME)
	assert_null(world.character(monster.id), "an old death removes the sprite at once")


func test_a_late_bolt_starts_part_way() -> void:
	var bolt: Bolt = Bolt.launch(Vector2.ZERO, Vector2(100, 0), 1.0, 0.25, false, 1)
	assert_almost_eq(bolt.position.x, 25.0, 0.001, "a quarter of the way after a quarter")
	assert_false(bolt.arrived())
	assert_true(bolt.advance(0.75), "arrives at the flight time")
	assert_almost_eq(bolt.position.x, 100.0, 0.001)
	bolt.free()


func test_heal_and_attack_bolts_differ() -> void:
	var attack: Bolt = Bolt.launch(Vector2.ZERO, Vector2.ONE, 1.0, 0.0, false, 1)
	var heal: Bolt = Bolt.launch(Vector2.ZERO, Vector2.ONE, 1.0, 0.0, true, 1)
	assert_ne(attack.color, heal.color)
	assert_eq(heal.color, Palette.color(&"green"))
	attack.free()
	heal.free()

extends ColonyTest
## Unit tests for Expedition details the acceptance tests reach only indirectly.

const SEED: int = 1234
const EPSILON: float = 0.001


func test_followers_retrace_a_turn() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var room: LabyrinthChamber = level.chambers[0]
	# Walking left toward the far end of the first chamber, close to it.
	e.x = room.rect.position.x + 1.0
	e.facing = -1
	var turned: bool = false
	for i: int in 20:
		sim.step()
		if e.facing == 1:
			turned = true
			break
	assert_true(turned, "turned at the left end")
	var left: float = room.rect.position.x
	for rank: int in 4:
		var x: float = sim.expedition.hero_position(rank + 1).x
		assert_gte(x, left - EPSILON, "rank %d stays on the floor" % rank)
	# Right at the turn the last hero is still walking toward the end, not behind a wall.
	sim.step()
	var rear: float = e.hero_position(4).x
	assert_almost_eq(rear, left + 3.0 - 0.3, EPSILON, "the rear hero has not reached the end yet")


func test_unknown_hero_has_no_position() -> void:
	var sim := Simulation.new(SEED)
	assert_eq(sim.expedition.hero_position(42), Vector2.ZERO)


func test_out_of_range_chambers_are_never_populated() -> void:
	var sim := Simulation.new(SEED)
	assert_false(sim.expedition.is_populated(0, 1))
	assert_false(sim.expedition.is_populated(1, -1))
	assert_false(sim.expedition.is_populated(1, 99))
	assert_eq(sim.expedition.monsters_in(1, 99).size(), 0)


func test_asking_about_a_chamber_twice_gives_the_same_monsters() -> void:
	var sim := Simulation.new(SEED)
	var level: LabyrinthLevel = sim.labyrinth.level(2)
	for room: LabyrinthChamber in level.chambers:
		if not sim.expedition.is_populated(2, room.index):
			continue
		var first: Array[Combatant] = sim.expedition.monsters_in(2, room.index)
		var second: Array[Combatant] = sim.expedition.monsters_in(2, room.index)
		assert_eq(first.size(), second.size())
		for i: int in first.size():
			assert_same(first[i], second[i])

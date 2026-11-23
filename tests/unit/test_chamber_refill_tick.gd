extends ColonyTest
## Spec 099's one question of the simulation: ChamberRules.refill_tick, the tick a cleared chamber
## refills on, read without changing anything.

const SEED: int = 1234


## The first chamber of depth 1 the party clears, as Vector2i(depth, chamber); (-1, -1) if none.
func _first_cleared(sim: Simulation) -> Vector2i:
	for key: Vector2i in sim.expedition._chambers:
		if sim.expedition._chambers[key].cleared_tick >= 0:
			return key
	return Vector2i(-1, -1)


func test_refill_tick_of_a_cleared_chamber() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_push(false)
	raise_party(sim, 10)
	var e: Expedition = sim.expedition
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var far: int = level.chambers.size() - 1
	assert_eq(ChamberRules.refill_tick(e, 1, far), -1, "a chamber never entered: -1")
	var cleared: bool = step_until(
		sim, func() -> bool: return _first_cleared(sim).x >= 0, LIMIT_TICKS
	)
	assert_true(cleared, "the party clears a chamber")
	if not cleared:
		return
	var key: Vector2i = _first_cleared(sim)
	var fill: ChamberState = e._chambers[key]
	var before: int = sim.state_hash()
	var due: int = ChamberRules.refill_tick(e, key.x, key.y)
	assert_eq(due, fill.refill_tick(), "the tick its record refills on")
	assert_gt(due, sim.tick, "still to come")
	assert_eq(sim.state_hash(), before, "asking changes nothing")
	assert_gt(fill.cleared_tick, -1, "the record is still cleared")
	assert_false(e.is_populated(key.x, key.y), "it is empty until then")
	# Once that tick has passed the chamber is no longer cleared, though its record is not moved on.
	step_until(sim, func() -> bool: return sim.tick >= due, LIMIT_TICKS)
	assert_eq(ChamberRules.refill_tick(e, key.x, key.y), -1, "refilled: -1")
	var waiting: bool = e.is_populated(key.x, key.y) or e.side_quest_in(key.x, key.y) != &""
	assert_true(waiting, "and it holds monsters or a quest again")


func test_refill_tick_of_a_chamber_holding_monsters() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	for room: LabyrinthChamber in sim.labyrinth.level(1).chambers:
		if e.is_populated(1, room.index):
			var fill: ChamberState = e._record(1, room.index)
			assert_eq(fill.cleared_tick, -1, "a record of monsters not yet beaten")
			assert_eq(ChamberRules.refill_tick(e, 1, room.index), -1, "holding monsters: -1")
			return
	fail_test("no populated chamber on depth 1")

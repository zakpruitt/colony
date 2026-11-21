extends ColonyTest
## AwayReplay steps the real simulation for the time away and counts what happened; AwayStory
## words its report.


func _saved() -> Dictionary:
	var sim := Simulation.new(Main.SIMULATION_SEED)
	for i: int in 2000:
		sim.step()
	return JSON.parse_string(JSON.stringify(sim.to_save()))


func test_a_slice_stops_at_its_budget() -> void:
	var replay := AwayReplay.new(Simulation.from_save(_saved()), 8.0 * 3600.0)
	assert_false(replay.run(2_000), "eight hours do not fit in 2 ms")
	assert_gt(replay.done_ticks, 0)
	assert_lt(replay.fraction(), 1.0)


func test_no_time_is_done_at_once() -> void:
	var replay := AwayReplay.new(Simulation.from_save(_saved()), 0.0)
	assert_true(replay.is_done())
	assert_true(replay.run(1_000))


func test_durations_read_as_hours_and_minutes() -> void:
	assert_eq(AwayStory.duration(30.0 * 60.0), "30m")
	assert_eq(AwayStory.duration(65.0 * 60.0), "1h 5m")
	assert_eq(AwayStory.duration(8.0 * 3600.0), "8h 0m")


func test_the_most_needed_microskill_was_missed_most_ties_to_the_first() -> void:
	var replay := AwayReplay.new(Simulation.from_save(_saved()), 0.0)
	var ids: Array[StringName] = Content.microskill_ids()
	assert_eq(replay.report.most_needed_microskill, &"", "nothing missed, nothing needed")
	replay._missed_by_skill = {3: 1, 1: 2, 4: 2}
	replay.run(1_000)
	assert_eq(replay.report.most_needed_microskill, ids[1], "the most missed; a tie to the first")
	replay._missed_by_skill = {3: 1, 1: 2, 4: 3}
	replay.run(1_000)
	assert_eq(replay.report.most_needed_microskill, ids[4])

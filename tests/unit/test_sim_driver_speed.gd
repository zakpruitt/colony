extends ColonyTest
## SimDriver above 1x (spec 032): the extra ticks a speed adds are best effort and never kept.

const MS: int = 1_000
const SECOND: int = 1_000_000


func _driver(speed: int) -> SimDriver:
	var driver := SimDriver.new()
	driver.simulation = Simulation.new(1)
	driver.speed = speed
	driver.step_budget_usec = 10 * SECOND
	autofree(driver)
	return driver


func test_part_ticks_carry_over_between_frames() -> void:
	# Real time and the extra time keep their own part ticks: 50 ms at 2x is half a tick of each.
	var driver := _driver(2)
	assert_eq(driver.advance(50 * MS), 0, "two half ticks are not yet a tick")
	assert_eq(driver.advance(50 * MS), 2, "50 ms more completes both")
	assert_eq(driver.advance(30 * MS), 0)
	assert_eq(driver.advance(20 * MS), 0)
	assert_eq(driver.advance(50 * MS), 2, "nothing was lost along the way")
	assert_eq(driver.simulation.tick, 4, "200 ms at 2x is four ticks")


func test_ticked_reports_every_tick_stepped() -> void:
	var driver := _driver(4)
	watch_signals(driver)
	driver.advance(SECOND)
	assert_signal_emitted_with_parameters(driver, "ticked", [40])


func test_a_stall_at_4x_steps_at_most_four_times_the_cap_and_keeps_only_real_time() -> void:
	var driver := _driver(4)
	var ticks: int = driver.advance(20 * SECOND)
	assert_eq(ticks, 4 * SimDriver.MAX_TICKS_PER_FRAME, "50 real-time ticks and 150 extra")
	assert_eq(driver.backlog_usec(), 15 * SECOND, "the real-time backlog is kept, as at 1x")
	var next: int = driver.advance(0)
	assert_eq(next, SimDriver.MAX_TICKS_PER_FRAME, "the next frame catches up only real time")


func test_without_budget_only_real_time_ticks_run() -> void:
	var driver := _driver(4)
	driver.step_budget_usec = 0
	assert_eq(driver.advance(SECOND), 10, "a second at 1x")
	driver.step_budget_usec = 10 * SECOND
	assert_eq(driver.advance(100 * MS), 4, "the extra time was let go, not kept")


func test_going_back_to_1x_forgets_part_ticks() -> void:
	var driver := _driver(4)
	driver.advance(20 * MS)  # 60 ms of extra time owed
	driver.speed = 1
	driver.advance(80 * MS)
	driver.speed = 4
	assert_eq(driver.advance(0), 0, "nothing owed from before")
	assert_eq(driver.simulation.tick, 1, "only the real 100 ms became a tick")

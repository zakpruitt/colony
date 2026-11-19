extends ColonyTest
## Acceptance tests for specs/001-sim-clock/spec.md, one per requirement.

const SEED: int = 1234
const MS: int = 1_000
const SECOND: int = 1_000_000

var _saved_max_fps: int


func before_each() -> void:
	_saved_max_fps = Engine.max_fps


func after_each() -> void:
	super()
	Engine.max_fps = _saved_max_fps


func _driver_for(sim: Simulation) -> SimDriver:
	var driver := SimDriver.new()
	driver.simulation = sim
	autofree(driver)
	return driver


## Calls advance with zero elapsed time until the backlog is worked off.
## Returns how many such frames it took.
func _drain(driver: SimDriver) -> int:
	var frames: int = 0
	while driver.backlog_usec() >= Simulation.TICK_USEC:
		driver.advance(0)
		frames += 1
		assert_lt(frames, 10_000, "backlog never drained")
		if frames >= 10_000:
			break
	return frames


func test_r1_step_advances_one_tick() -> void:
	var sim := Simulation.new(SEED)
	assert_eq(sim.tick, 0, "a new simulation starts at tick 0")
	sim.step()
	assert_eq(sim.tick, 1, "one step is one tick")
	sim.step()
	sim.step()
	assert_eq(sim.tick, 3)
	assert_almost_eq(sim.seconds(), 0.3, 0.000001)


func test_r2_elapsed_time_becomes_ticks_with_remainder() -> void:
	var sim := Simulation.new(SEED)
	var driver := _driver_for(sim)
	assert_eq(driver.advance(250 * MS), 2, "250 ms is two ticks")
	assert_eq(sim.tick, 2)
	assert_eq(driver.backlog_usec(), 50 * MS, "50 ms is kept")
	assert_eq(driver.advance(50 * MS), 1, "the kept 50 ms plus 50 ms more is one tick")
	assert_eq(sim.tick, 3)
	assert_eq(driver.backlog_usec(), 0)


func test_r3_tick_count_ignores_frame_split() -> void:
	var total: int = 10 * SECOND
	var frames: int = 600

	var one_frame := Simulation.new(SEED)
	var one_driver := _driver_for(one_frame)
	one_driver.advance(total)
	_drain(one_driver)

	var even := Simulation.new(SEED)
	var even_driver := _driver_for(even)
	var even_sent: int = 0
	for i: int in frames:
		# 10 s / 600 is not a whole number of microseconds; cut at exact
		# boundaries so the parts still add up to exactly 10 s.
		var cut: int = total * (i + 1) / frames
		even_driver.advance(cut - even_sent)
		even_sent = cut
	_drain(even_driver)

	var uneven := Simulation.new(SEED)
	var uneven_driver := _driver_for(uneven)
	var rng := SimRng.new(SEED)
	var weights: Array[int] = []
	var weight_sum: int = 0
	for i: int in frames:
		var weight: int = rng.next_int(1, 1000)
		weights.append(weight)
		weight_sum += weight
	var cumulative: int = 0
	var uneven_sent: int = 0
	for weight: int in weights:
		cumulative += weight
		var cut: int = total * cumulative / weight_sum
		uneven_driver.advance(cut - uneven_sent)
		uneven_sent = cut
	_drain(uneven_driver)

	assert_eq(even_sent, total)
	assert_eq(uneven_sent, total)
	assert_eq(one_frame.tick, 100, "one 10 s frame")
	assert_eq(even.tick, 100, "600 even frames")
	assert_eq(uneven.tick, 100, "600 uneven frames (seed %d)" % SEED)
	for driver: SimDriver in [one_driver, even_driver, uneven_driver]:
		assert_eq(driver.backlog_usec(), 0, "no drift left over")
	assert_eq(even.state_hash(), one_frame.state_hash())
	assert_eq(uneven.state_hash(), one_frame.state_hash())


func test_r4_stall_is_capped_per_frame_and_caught_up() -> void:
	var sim := Simulation.new(SEED)
	var driver := _driver_for(sim)
	assert_eq(driver.advance(20 * SECOND), SimDriver.MAX_TICKS_PER_FRAME, "50 ticks at once")
	assert_eq(sim.tick, 50)
	assert_eq(driver.backlog_usec(), 15 * SECOND, "the rest is kept as backlog")
	var frames: int = _drain(driver)
	assert_eq(sim.tick, 200, "the whole stall is caught up")
	assert_eq(frames, 3, "50 ticks per following frame")
	assert_eq(driver.backlog_usec(), 0)


func test_r5_backlog_over_cap_is_dropped_and_reported() -> void:
	var sim := Simulation.new(SEED)
	var driver := _driver_for(sim)
	watch_signals(driver)
	driver.advance(300 * SECOND)
	assert_lte(driver.backlog_usec(), SimDriver.MAX_BACKLOG_USEC, "at most 60 s of backlog")
	assert_signal_emit_count(driver, "time_dropped", 1)
	assert_signal_emitted_with_parameters(driver, "time_dropped", [240 * SECOND])
	_drain(driver)
	assert_eq(sim.tick, 600, "the 60 s that were kept are stepped")


func test_r6_focus_loss_throttles_rendering_only() -> void:
	Engine.max_fps = 144
	var sim := Simulation.new(SEED)
	var driver := _driver_for(sim)

	var focused_ticks: int = driver.advance(SECOND)

	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(Engine.max_fps, SimDriver.BACKGROUND_MAX_FPS, "background rendering is throttled")
	var background_ticks: int = driver.advance(SECOND)

	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 144, "the earlier limit is restored")

	assert_eq(focused_ticks, 10)
	assert_eq(background_ticks, focused_ticks, "the tick rate does not change")


func test_r7_main_scene_shows_the_clock() -> void:
	var main: Main = make_main()
	add_child_autofree(main)
	var label: Label = main.get_node("HUD/ClockLabel")
	assert_not_null(main.driver, "the main scene has a driver")
	assert_not_null(main.simulation, "the main scene has a simulation")
	if main.driver == null or main.simulation == null:
		return

	# 12.3 s more than whatever real frames have stepped so far.
	main.driver.advance(12_300 * MS)
	_drain(main.driver)
	var tick: int = main.simulation.tick
	assert_gte(tick, 123)
	assert_string_contains(label.text, str(tick))
	assert_string_contains(label.text, "%.1f" % main.simulation.seconds())

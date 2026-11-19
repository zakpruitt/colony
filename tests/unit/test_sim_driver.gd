extends ColonyTest

const SECOND: int = 1_000_000

var _saved_max_fps: int


func before_each() -> void:
	_saved_max_fps = Engine.max_fps


func after_each() -> void:
	super()
	Engine.max_fps = _saved_max_fps


func _new_driver() -> SimDriver:
	var driver := SimDriver.new()
	driver.simulation = Simulation.new(1)
	autofree(driver)
	return driver


func test_ticked_reports_the_count_and_only_when_ticks_ran() -> void:
	var driver := _new_driver()
	watch_signals(driver)
	driver.advance(60_000)
	assert_signal_not_emitted(driver, "ticked", "less than a tick steps nothing")
	driver.advance(290_000)
	assert_signal_emitted_with_parameters(driver, "ticked", [3])


func test_backlog_exactly_at_the_cap_drops_nothing() -> void:
	var driver := _new_driver()
	watch_signals(driver)
	driver.advance(SimDriver.MAX_BACKLOG_USEC)
	assert_signal_not_emitted(driver, "time_dropped")
	driver.advance(SimDriver.MAX_BACKLOG_USEC)
	assert_signal_emitted_with_parameters(
		driver, "time_dropped", [SimDriver.MAX_BACKLOG_USEC - 5 * SECOND]
	)


func test_negative_elapsed_time_is_ignored() -> void:
	var driver := _new_driver()
	driver.advance(150_000)
	assert_eq(driver.advance(-SECOND), 0)
	assert_eq(driver.backlog_usec(), 50_000)


func test_repeated_focus_out_still_restores_the_first_limit() -> void:
	Engine.max_fps = 90
	var driver := _new_driver()
	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 90)


func test_focus_in_without_focus_out_changes_nothing() -> void:
	Engine.max_fps = 90
	var driver := _new_driver()
	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 90)


func test_leaving_the_tree_unfocused_restores_the_limit() -> void:
	Engine.max_fps = 90
	var driver := SimDriver.new()
	driver.simulation = Simulation.new(1)
	add_child(driver)
	driver.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	remove_child(driver)
	driver.free()
	assert_eq(Engine.max_fps, 90)

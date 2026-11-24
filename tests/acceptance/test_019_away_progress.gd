extends ColonyTest
## Spec 019: progress while you were away. Every test gives Main a SaveStore on a per-process
## path (never the real save) and sets away_seconds_override, so none depends on the real clock.

## Ticks the saved game has already played before it was saved.
const PLAYED_TICKS: int = 3000

## Deleted with its backup after each test and after the last one (ColonyTest): a Main freed by
## GUT after after_each saves once more as it leaves the tree.
var _path: String = save_path()


## Writes a stamped save of a game that has played [constant PLAYED_TICKS] ticks.
func _write_save(stamped: bool = true) -> Dictionary:
	var sim := Simulation.new(Main.SIMULATION_SEED)
	for i: int in PLAYED_TICKS:
		sim.step()
	sim.drain_events()
	var data: Dictionary = sim.to_save()
	if stamped:
		data["saved_at"] = Time.get_unix_time_from_system()
	assert_true(SaveStore.new(_path).write(data), "the test's save was written")
	return SaveStore.new(_path).read()


func _main(away: float, store: bool = true) -> Main:
	var main: Main = make_main()
	if store:
		main.save_store = SaveStore.new(_path)
	main.away_seconds_override = away
	add_child_autofree(main)
	return main


func _wait_for_replay(main: Main) -> void:
	await wait_until(func() -> bool: return not main.is_catching_up(), 60.0, "replay ends")


## A simulation loaded from [param saved] in the shape Main plays and stepped [param ticks],
## counting what happened.
func _reference(saved: Dictionary, ticks: int) -> Dictionary:
	var sim: Simulation = Simulation.from_save(saved, Main.STAGE_SHAPE)
	var kills: int = 0
	var wipes: int = 0
	for i: int in ticks:
		sim.step()
		for event: SimEvent in sim.drain_events():
			# A kill is a monster's death (spec 031), not a gain of gold: quests pay gold.
			if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
				kills += 1
			elif event.kind == SimEvent.Kind.PARTY_WIPED:
				wipes += 1
	return {"sim": sim, "kills": kills, "wipes": wipes}


func test_r1_saves_are_stamped() -> void:
	var main: Main = _main(-1.0)
	assert_false(main.is_catching_up(), "a new game has nothing to replay")
	main.save_now()
	var saved: Dictionary = SaveStore.new(_path).read()
	assert_true(saved.has("saved_at"), "the save carries a stamp")
	var stamp: float = saved.get("saved_at", 0.0)
	assert_almost_eq(stamp, Time.get_unix_time_from_system(), 5.0, "stamped with now")
	main.free()
	# A save written before stamps existed loads as before, with no time away.
	_write_save(false)
	var later: Main = _main(600.0)
	assert_false(later.is_catching_up(), "no stamp, no replay")
	assert_null(later.away_report, "no report")
	assert_eq(later.simulation.tick, PLAYED_TICKS, "the save loaded")
	assert_not_null(later.world, "the world is made at once")


func test_r2_time_away_is_bounded() -> void:
	_write_save()
	var short: Main = _main(30.0)
	assert_false(short.is_catching_up(), "30 s is too short to replay")
	assert_not_null(short.world, "normal play at once")
	short.free()

	_write_save()
	var ten_minutes: Main = _main(600.0)
	assert_true(ten_minutes.is_catching_up(), "600 s is replayed")
	await _wait_for_replay(ten_minutes)
	assert_eq(ten_minutes.away_report.seconds, 600.0)
	assert_eq(ten_minutes.simulation.tick, PLAYED_TICKS + 6000, "6,000 ticks replayed")
	ten_minutes.free()

	_write_save()
	var days: Main = _main(100.0 * 3600.0)
	assert_true(days.is_catching_up(), "a long absence is replayed")
	assert_eq(days.replay.total_ticks, 8 * 3600 * Simulation.TICKS_PER_SECOND, "capped at 8 hours")
	assert_eq(days.replay.report.seconds, Main.MAX_AWAY_SECONDS, "the report says 8 hours")
	days.free()

	# A stamp in the future (the clock went backwards), read from the real clock.
	var saved: Dictionary = _write_save()
	saved["saved_at"] = Time.get_unix_time_from_system() + 3600.0
	SaveStore.new(_path).write(saved)
	var future: Main = _main(-1.0)
	assert_false(future.is_catching_up(), "a clock that went backwards is no time away")
	assert_eq(future.simulation.tick, PLAYED_TICKS)
	assert_almost_eq(Main.time_away(saved, Time.get_unix_time_from_system()), 0.0, 0.001)
	assert_almost_eq(
		Main.time_away({"saved_at": 1000.0}, 1000.0 + 50.0 * 3600.0),
		Main.MAX_AWAY_SECONDS,
		0.001,
		"the real clock is capped too"
	)
	assert_almost_eq(Main.time_away({"saved_at": 1000.0}, 1600.0), 600.0, 0.001)


func test_r3_replay_is_sliced() -> void:
	_write_save()
	var main: Main = _main(Main.MAX_AWAY_SECONDS)
	var fractions: Array[float] = []
	for frame: int in 4:
		assert_true(main.is_catching_up(), "still catching up on frame %d" % frame)
		assert_null(main.world, "the world is not made during the replay")
		assert_null(main.hud, "nor the HUD")
		assert_not_null(main.catch_up_bar, "the bar shows")
		assert_true(main.catch_up_bar.visible)
		fractions.append(main.catch_up_bar.fraction)
		await wait_process_frames(1)
	for i: int in range(1, fractions.size()):
		assert_gt(fractions[i], fractions[i - 1], "the bar rises")
	assert_lt(fractions[-1], 1.0, "eight hours do not fit in a few frames")


func test_r4_same_as_playing() -> void:
	var saved: Dictionary = _write_save()
	var main: Main = _main(900.0)
	var replay: AwayReplay = main.replay
	assert_not_null(replay, "the time away is replayed")
	if replay == null:
		return
	assert_eq(replay.total_ticks, 9000, "900 s away are 9,000 ticks")
	# Taken when the replay ends, before the world is made: the world fills the chambers it
	# looks at, which changes the hash whether or not there was a replay.
	var ended: Array[int] = []
	main.caught_up.connect(
		func(_report: AwayReport) -> void:
			ended.append(main.simulation.tick)
			ended.append(main.simulation.state_hash())
	)
	await _wait_for_replay(main)
	var reference: Simulation = _reference(saved, 9000)["sim"]
	assert_eq(ended.size(), 2, "the replay ended once")
	assert_eq(ended[0], reference.tick, "same ticks")
	assert_eq(ended[1], reference.state_hash(), "same state")
	assert_almost_eq(replay.fraction(), 1.0, 0.0001, "the replay is whole")


func test_r5_report() -> void:
	var saved: Dictionary = _write_save()
	var main: Main = _main(1800.0)
	assert_null(main.away_window, "no panel during the replay")
	await _wait_for_replay(main)
	var reference: Dictionary = _reference(saved, 18000)
	var played: Simulation = reference["sim"]
	var before: Simulation = Simulation.from_save(saved)
	var report: AwayReport = main.away_report
	assert_not_null(report)
	assert_eq(report.seconds, 1800.0)
	assert_eq(report.gold_gained, played.party.gold - before.party.gold, "gold")
	assert_gt(report.gold_gained, 0, "half an hour earns something")
	for i: int in before.party.heroes.size():
		var hero: Hero = before.party.heroes[i]
		var gained: int = played.party.heroes[i].level - hero.level
		var reported: int = report.levels_gained.get(hero.id, -1)
		assert_eq(reported, gained, "levels of hero %d" % hero.id)
	assert_eq(report.depth_before, before.expedition.depth, "depth before")
	assert_eq(report.depth_after, played.expedition.depth, "depth after")
	var kills: int = reference["kills"]
	var wipes: int = reference["wipes"]
	assert_eq(report.kills, kills, "kills")
	assert_gt(report.kills, 0)
	assert_eq(report.wipes, wipes, "wipes")
	var panel: AwayWindow = main.away_window
	assert_not_null(panel, "the panel shows")
	assert_true(panel.visible)
	assert_not_null(main.world, "the game runs behind it")
	var text: String = panel.text()
	assert_string_contains(text, "30m")
	assert_string_contains(text, UiFormat.group_thousands(report.gold_gained))
	assert_string_contains(text, "%d" % report.kills)
	# No replay, no panel.
	_write_save()
	var quick: Main = _main(10.0)
	await wait_process_frames(2)
	assert_null(quick.away_window, "no panel without a replay")
	assert_null(quick.away_report)


func test_r6_clean_start() -> void:
	_write_save()
	var main: Main = _main(1200.0)
	main._save_in = 1.0  # time spent waiting must not carry over
	await wait_until(func() -> bool: return main.world != null, 60.0, "replay ends")
	var end_tick: int = main.simulation.tick
	assert_eq(main.effects.live_numbers(), 0, "no numbers left over")
	assert_eq(main.effects.live_particles(), 0, "no particles left over")
	assert_eq(main.hud.shown_gold(), main.simulation.party.gold, "gold shown at once")
	assert_almost_eq(main._save_in, Main.SAVE_SECONDS, 0.5, "the save timer starts fresh")
	for event: SimEvent in main.simulation.drain_events():
		assert_gt(event.tick, end_tick, "no event from the time away is pending")
	await wait_process_frames(2)
	assert_eq(main.hud.shown_gold(), main.simulation.party.gold, "and stays right")


func test_r7_no_store_no_replay() -> void:
	_write_save()
	var main: Main = _main(Main.MAX_AWAY_SECONDS, false)
	assert_null(main.save_store, "a test run has no store")
	assert_false(main.is_catching_up(), "nothing is replayed")
	assert_null(main.replay)
	assert_eq(main.simulation.tick, 0, "a new game, not the save")
	assert_not_null(main.world)
	await wait_process_frames(2)
	assert_null(main.away_window)

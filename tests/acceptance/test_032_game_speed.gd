extends GutTest
## Acceptance tests for specs/032-game-speed/spec.md, one per requirement.
##
## Driver tests step a SimDriver by hand with SimDriver.advance, the way a frame does. Tests on
## the main scene never await a frame, so nothing moves unless the test moves it. Tests that save
## use a per-process file under user://, deleted after each test and after the last one: never
## the real save.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 1
const SECOND: int = 1_000_000
## A 60 fps frame, in microseconds and in seconds.
const FRAME_USEC: int = 16_667
const FRAME: float = 1.0 / 60.0
## A budget no stepping ever runs out of, for tests that count ticks.
const AMPLE_BUDGET: int = 10 * SECOND
const GUARDIAN_DEPTH: int = 5
const STRONG_LEVEL: int = 40
## Real time the R6 replays are away for, in seconds.
const AWAY_SECONDS: float = 120.0

var _path: String = "user://test_032_speed_%d.save" % OS.get_process_id()


func after_each() -> void:
	_delete_saves()


## Also after the last test: a Main freed by GUT after `after_each` saves once more as it
## leaves the tree.
func after_all() -> void:
	_delete_saves()


func _delete_saves() -> void:
	for base: String in [_path, _path + ".b"]:
		for path: String in [base, base + SaveStore.BACKUP_SUFFIX, base + SaveStore.TEMP_SUFFIX]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


# --- Helpers -------------------------------------------------------------------


func _driver(speed: int) -> SimDriver:
	var driver := SimDriver.new()
	driver.simulation = Simulation.new(SEED)
	driver.speed = speed
	driver.step_budget_usec = AMPLE_BUDGET
	autofree(driver)
	return driver


func _main() -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	return main


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## One event as plain values, to compare two runs.
static func _describe(event: SimEvent) -> String:
	return (
		"%d %d %d %d %d %s"
		% [event.kind, event.tick, event.source_id, event.target_id, event.amount, event.flag]
	)


## Raises every hero to [param level] at full health and puts the party just outside the
## guardian's chamber on depth 5, walking in (as the spec 024 tests do).
func _before_guardian(sim: Simulation) -> void:
	for hero: Hero in sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(STRONG_LEVEL) - hero.xp)
		hero.health = hero.max_health()
	var e: Expedition = sim.expedition
	var shaft: LabyrinthChamber = sim.labyrinth.level(GUARDIAN_DEPTH).shaft_chamber()
	sim.set_auto_push(false)
	e.depth = GUARDIAN_DEPTH
	e.target_depth = GUARDIAN_DEPTH + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


# --- R1 ------------------------------------------------------------------------


func test_r1_three_speeds() -> void:
	assert_eq(Main.SPEEDS, [1, 2, 4] as Array[int], "three speeds")
	for speed: int in Main.SPEEDS:
		var driver := _driver(speed)
		for i: int in 600:  # 10 s of 60 fps frames
			driver.advance(FRAME_USEC)
		var ticks: int = driver.simulation.tick
		var expected: float = 10.0 * Simulation.TICKS_PER_SECOND * speed
		assert_almost_eq(float(ticks), expected, expected * 0.05, "%dx over 10 s" % speed)

	var main := _main()
	assert_eq(main.speed, 1, "a new Main starts at 1x")
	assert_eq(main.driver.speed, 1, "and so does its driver")
	main.driver.step_budget_usec = AMPLE_BUDGET
	for speed: int in Main.SPEEDS:
		main.set_speed(speed)
		assert_eq(main.speed, speed, "set to %dx" % speed)
		var before: int = main.simulation.tick
		for i: int in 600:
			main.driver.advance(FRAME_USEC)
		var ticks: float = main.simulation.tick - before
		var expected: float = 10.0 * Simulation.TICKS_PER_SECOND * speed
		assert_almost_eq(ticks, expected, expected * 0.05, "Main at %dx over 10 s" % speed)
	main.set_speed(3)
	assert_eq(main.speed, 4, "a speed not in SPEEDS is ignored")

	# The speed is not saved: a save written at 4x is the one written at 1x, and a Main made
	# from it starts at 1x.
	var fast: Main = MAIN_SCENE.instantiate()
	fast.save_store = SaveStore.new(_path)
	add_child_autofree(fast)
	fast.set_speed(4)
	fast.save_now()
	var slow: Main = MAIN_SCENE.instantiate()
	slow.save_store = SaveStore.new(_path + ".b")
	add_child_autofree(slow)
	slow.save_now()
	var fast_saved: Dictionary = SaveStore.new(_path).read()
	var slow_saved: Dictionary = SaveStore.new(_path + ".b").read()
	assert_false(fast_saved.is_empty(), "the fast game saved")
	fast_saved.erase(Main.SAVED_AT_KEY)
	slow_saved.erase(Main.SAVED_AT_KEY)
	assert_eq(fast_saved, slow_saved, "the save holds no speed")
	for key: Variant in fast_saved:
		assert_false(str(key).contains("speed"), "no key %s" % key)
	fast.free()
	var again: Main = MAIN_SCENE.instantiate()
	again.save_store = SaveStore.new(_path)
	add_child_autofree(again)
	assert_eq(again.speed, 1, "a loaded game starts at 1x")


# --- R2 ------------------------------------------------------------------------


func test_r2_button_and_key() -> void:
	var main := _main()
	var hud: Hud = main.hud
	var button: HudButton = hud.speed_button
	assert_not_null(button, "the HUD has a speed button")
	if button == null:
		return
	assert_eq(button.text, "1x", "it shows 1x")
	assert_false(button.lit, "unlit at 1x")

	var labels: Array[String] = ["2x", "4x", "1x"]
	var speeds: Array[int] = [2, 4, 1]
	for i: int in 3:
		button.pressed.emit()
		assert_eq(main.speed, speeds[i], "a click cycles to %dx" % speeds[i])
		assert_eq(button.text, labels[i], "and shows it")
		assert_eq(button.lit, speeds[i] > 1, "lit only above 1x (%s)" % labels[i])
	for i: int in 3:
		_key(KEY_F)
		assert_eq(main.speed, speeds[i], "F cycles to %dx" % speeds[i])
		assert_eq(button.text, labels[i], "and the button shows it")
		assert_eq(button.lit, speeds[i] > 1, "lit only above 1x (%s)" % labels[i])

	for speed: int in Main.SPEEDS:
		main.set_speed(speed)
		hud.advance(0.0)
		_check_placement(hud, "%dx without the boss bar" % speed)

	# A guardian's fight, so the boss bar shows.
	var sim: Simulation = main.simulation
	_before_guardian(sim)
	var showing: bool = false
	for i: int in 3000:
		sim.step()
		main.world.sync(0.1)
		hud.advance(0.1)
		if hud.boss_bar.is_showing():
			showing = true
			break
	assert_true(showing, "the boss bar shows")
	for speed: int in Main.SPEEDS:
		main.set_speed(speed)
		hud.advance(0.0)
		_check_placement(hud, "%dx with the boss bar" % speed)


func _check_placement(hud: Hud, what: String) -> void:
	var rect: Rect2 = hud.speed_button.get_global_rect()
	assert_true(hud.speed_button.is_visible_in_tree(), "%s: the button shows" % what)
	assert_gte(rect.position.y, 0.0, "%s: in the top band" % what)
	assert_lte(rect.end.y, Hud.TOP_BAND, "%s: in the top band" % what)
	assert_gte(rect.position.x, 0.0, "%s: on screen" % what)
	assert_lte(rect.end.x, Hud.SCREEN.x, "%s: on screen" % what)
	var others: Dictionary[String, Control] = {
		"depth panel": hud.depth_panel,
		"gold": hud.gold_panel,
	}  # spec 059: the Shop button moved to the UI layer's bar
	if hud.boss_bar.is_showing():
		others["boss bar"] = hud.boss_bar
	for part: String in others:
		var other: Rect2 = others[part].get_global_rect()
		assert_false(rect.intersects(other), "%s: clear of the %s" % [what, part])


# --- R3 ------------------------------------------------------------------------


func test_r3_same_game_sooner() -> void:
	var fast := _driver(4)
	var fast_events: Array[String] = []
	while fast.simulation.tick < 3000:
		fast.advance(FRAME_USEC)
		for event: SimEvent in fast.simulation.drain_events():
			fast_events.append(_describe(event))
	var ticks: int = fast.simulation.tick

	var slow := _driver(1)
	var slow_events: Array[String] = []
	while slow.simulation.tick < ticks:
		slow.advance(FRAME_USEC)
		for event: SimEvent in slow.simulation.drain_events():
			slow_events.append(_describe(event))
	assert_eq(slow.simulation.tick, ticks, "the same number of ticks")
	assert_eq(slow.simulation.state_hash(), fast.simulation.state_hash(), "the same state")
	assert_gt(fast_events.size(), 100, "plenty happened")
	assert_eq(fast_events, slow_events, "the same events, in the same order")


# --- R4 ------------------------------------------------------------------------


func test_r4_looks_and_sounds_right() -> void:
	var sim := Simulation.new(SEED)
	var driver := SimDriver.new()
	driver.simulation = sim
	driver.speed = 4
	driver.step_budget_usec = AMPLE_BUDGET
	autofree(driver)
	var world := World.new()
	world.simulation = sim
	world.speed = 4
	add_child_autofree(world)
	world.set_process(false)
	var fx := CombatEffects.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.setup(world, sim)
	var sound := SoundPlayer.new()
	add_child_autofree(sound)
	sound.set_process(false)
	sound.setup(world, fx, sim)
	var events: Array[SimEvent] = []
	world.sim_event.connect(func(event: SimEvent) -> void: events.append(event))

	var most_numbers: int = 0
	var fights_ended: int = 0
	var hits: int = 0
	var old: int = 0
	var worst_step: float = 0.0
	var worst_lag: float = 0.0
	var started_at: Dictionary[StringName, float] = {}
	var now: float = 0.0
	var too_soon: int = 0
	var too_many: int = 0
	# 60 fps frames, and every fourth frame a slow one of 0.2 s: eight ticks at once at 4x.
	for frame: int in 60 * 90:
		if fights_ended >= 3:
			break
		var delta: float = 0.2 if frame % 4 == 3 else FRAME
		var before: Dictionary[int, Vector2] = {}
		for hero: Hero in sim.party.heroes:
			if world.character(hero.id) != null:
				before[hero.id] = world.feet_position(hero.id)
		events.clear()
		driver.advance(roundi(delta * SECOND))
		world.sync(delta)
		fx.advance(delta)
		sound._process(delta)

		for event: SimEvent in events:
			if not world.is_recent(event):
				old += 1
			if event.kind == SimEvent.Kind.ENCOUNTER_ENDED:
				fights_ended += 1
			if event.kind == SimEvent.Kind.HIT:
				hits += 1
		# The most a sprite may move in a frame: what 1x allows for the same game time.
		var bound: float = World.RUN_SPEED * 4.0 * delta + 0.5
		for id: int in before:
			var step: float = before[id].distance_to(world.feet_position(id))
			worst_step = maxf(worst_step, step / bound)
		var leader: Hero = sim.party.heroes[0]
		var tiles: Vector2 = sim.expedition.hero_position(leader.id)
		var goal := Vector2(tiles.x * World.TILE, (tiles.y + 1.0) * World.TILE)
		# Walking, the leader trails the party by what 1x shows; lining up for a fight is a run.
		if leader.is_alive() and sim.expedition.state == Expedition.State.TRAVELLING:
			worst_lag = maxf(worst_lag, goal.distance_to(world.feet_position(leader.id)))
		most_numbers = maxi(most_numbers, fx.live_numbers())
		assert_lte(fx.live_numbers(), CombatEffects.MAX_NUMBERS, "numbers under their cap")
		assert_lte(
			fx.live_particles(),
			CombatEffects.MAX_PARTICLES + CombatEffects.GUARDIAN_ALLOWANCE,
			"particles under their cap"
		)
		if sound.playing_count() > SoundPlayer.MAX_VOICES:
			too_many += 1
		for started: StringName in sound.drain_started():
			if now - started_at.get(started, -INF) < SoundPlayer.REPEAT_SECONDS - 0.001:
				too_soon += 1
			started_at[started] = now
		now += delta

	assert_gte(fights_ended, 3, "three fights were fought at 4x")
	assert_gt(hits, 0, "with hits")
	assert_gt(most_numbers, 0, "the effects showed numbers")
	assert_gt(started_at.size(), 0, "and sounds played")
	assert_eq(too_many, 0, "never more than the voice limit")
	assert_eq(too_soon, 0, "never the same sound twice too soon")
	assert_eq(old, 0, "no event of a frame is old merely because several ticks ran in it")
	assert_lte(worst_step, 1.0, "no sprite moved further in a frame than 1x allows")
	# At 1x a walking sprite trails by about WALK_SPEED / FOLLOW_RATE (6 px); at 4x it should too.
	var trail: float = World.WALK_SPEED / World.FOLLOW_RATE
	assert_lt(worst_lag, 1.5 * trail, "walking, the leader trails the party as at 1x")


# --- R5 ------------------------------------------------------------------------


func test_r5_keeps_up() -> void:
	var driver := _driver(4)
	driver.step_budget_usec = 0  # no frame can afford its extra ticks
	var most: int = 0
	var total: int = 0
	for i: int in 600:
		var ticks: int = driver.advance(FRAME_USEC)
		most = maxi(most, ticks)
		total += ticks
	assert_lte(most, 2, "a starved frame runs few ticks")
	assert_gte(total, 95, "the game carries on at least at 1x")
	assert_lte(total, 150, "it does not pretend to run at 4x")
	assert_lt(driver.backlog_usec(), Simulation.TICK_USEC, "no backlog is kept")

	driver.step_budget_usec = AMPLE_BUDGET
	most = 0
	var after: int = 0
	for i: int in 120:
		var ticks: int = driver.advance(FRAME_USEC)
		most = maxi(most, ticks)
		after += ticks
	assert_lte(most, 2, "no burst once frames can afford the ticks again")
	assert_almost_eq(float(after), 80.0, 4.0, "and it runs at 4x from then on")


# --- R6 ------------------------------------------------------------------------


func test_r6_time_away_unaffected() -> void:
	var totals: Array[int] = []
	var summaries: Array[String] = []
	for speed: int in [1, 4]:
		var path: String = _path if speed == 1 else _path + ".b"
		# Saved while at this speed (the stamp is ignored in favour of the override).
		var played: Main = MAIN_SCENE.instantiate()
		played.save_store = SaveStore.new(path)
		add_child_autofree(played)
		played.set_speed(speed)
		played.save_now()
		played.free()

		var back: Main = MAIN_SCENE.instantiate()
		back.save_store = SaveStore.new(path)
		back.away_seconds_override = AWAY_SECONDS
		add_child_autofree(back)
		assert_true(back.is_catching_up(), "%dx: the time away is replayed" % speed)
		if not back.is_catching_up():
			return
		back.set_speed(4)  # pressing F during the replay changes nothing about it
		var total: int = back.replay.total_ticks
		while back.is_catching_up():
			back._process(FRAME)
		totals.append(total)
		var summary: String = (
			"tick %d, hash %s, gold %d, kills %d"
			% [
				back.simulation.tick,
				back.simulation.state_hash(),
				back.away_report.gold_gained,
				back.away_report.kills,
			]
		)
		summaries.append(summary)
		assert_eq(back.speed, 4, "%dx: the speed chosen during the replay holds after it" % speed)
		assert_eq(back.driver.speed, 4, "%dx: and reaches the driver" % speed)
		back.save_store = null
	if totals.size() != 2:
		return
	var expected: int = roundi(AWAY_SECONDS * Simulation.TICKS_PER_SECOND)
	assert_eq(totals[0], expected, "time away is counted at 1x")
	assert_eq(totals[1], totals[0], "the replay's length is the same")
	assert_eq(summaries[1], summaries[0], "and where it ends and what it reports")


# --- R7 ------------------------------------------------------------------------


func test_r7_keys() -> void:
	var main := _main()
	var hud: Hud = main.hud
	var sim: Simulation = main.simulation
	sim.set_auto_push(false)
	sim.step()
	var windows: UiWindows = main.ui.windows
	var panels: Array[String] = ["nothing", "shop", "hero sheet", "journal"]
	for panel: String in panels:
		hud.shop.close()
		hud.hero_sheet.close()
		windows.close_window(UiRoot.JOURNAL)
		match panel:
			"shop":
				hud.shop.open()
			"hero sheet":
				hud.hero_sheet.open_next()
			"journal":
				windows.open_window(UiRoot.JOURNAL)
		hud.advance(0.0)
		var speed: int = main.speed
		var target: int = sim.expedition.target_depth
		var auto: bool = sim.expedition.auto_push
		var zoom: int = main.world.camera.zoom_level()
		var shop_open: bool = hud.shop.is_open()
		var sheet_open: bool = hud.hero_sheet.is_open()
		var journal_open: bool = windows.is_open(UiRoot.JOURNAL)
		_key(KEY_F)
		sim.step()
		assert_ne(main.speed, speed, "F works with %s open" % panel)
		assert_eq(sim.expedition.target_depth, target, "F leaves the target (%s)" % panel)
		assert_eq(sim.expedition.auto_push, auto, "and auto-push (%s)" % panel)
		assert_eq(main.world.camera.zoom_level(), zoom, "and the zoom (%s)" % panel)
		assert_eq(hud.shop.is_open(), shop_open, "and the shop (%s)" % panel)
		assert_eq(hud.hero_sheet.is_open(), sheet_open, "and the hero sheet (%s)" % panel)
		assert_eq(windows.is_open(UiRoot.JOURNAL), journal_open, "and the journal (%s)" % panel)

		# The other keys do what they did, and leave the speed alone.
		speed = main.speed
		_key(KEY_EQUAL)
		sim.step()
		assert_eq(sim.expedition.target_depth, target + 1, "= still works (%s)" % panel)
		_key(KEY_MINUS)
		sim.step()
		assert_eq(sim.expedition.target_depth, target, "- still works (%s)" % panel)
		_key(KEY_A)
		assert_ne(sim.expedition.auto_push, auto, "A still works (%s)" % panel)
		_key(KEY_A)
		_key(KEY_Z)
		assert_ne(main.world.camera.zoom_level(), zoom, "Z still works (%s)" % panel)
		_key(KEY_Z)
		assert_eq(main.speed, speed, "none of them changes the speed (%s)" % panel)

	hud.shop.close()
	hud.hero_sheet.close()
	windows.close_window(UiRoot.JOURNAL)
	_key(KEY_U)
	assert_true(hud.shop.is_open(), "U still opens the shop")
	_key(KEY_ESCAPE)
	assert_false(hud.shop.is_open(), "Esc still closes it")
	_key(KEY_J)
	assert_true(windows.is_open(UiRoot.JOURNAL), "J still opens the journal")
	_key(KEY_J)
	_key(KEY_TAB)
	assert_true(hud.hero_sheet.is_open(), "Tab still opens a hero sheet")
	_key(KEY_ESCAPE)

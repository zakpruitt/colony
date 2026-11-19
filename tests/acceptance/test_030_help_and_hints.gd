extends ColonyTest
## Acceptance tests for specs/030-help-and-hints/spec.md, one per requirement.
##
## Most tests build a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, and step it by hand. R2, R3 and R5 also run the main scene. Nothing here
## reads or writes the real save or settings file: R5 gives Main files of its own, under user://,
## named for this process, and deletes them.

const SEED: int = 30
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 6000
const STRONG_LEVEL: int = 40
## Every key code the help panel's list must account for is one of these words in game/ code.
const KEY_PATTERN: String = "\\bKEY_[A-Z0-9_]+\\b"

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
var _was_muted: bool = false
var _settings_path: String = save_path("", "settings")
var _save_path: String = save_path()


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_hud.advance(0.0)
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	_was_muted = bus >= 0 and AudioServer.is_bus_mute(bus)


func after_each() -> void:
	super()
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, _was_muted)


# --- Helpers -------------------------------------------------------------------


## Steps the simulation until [param done] returns true (true), or the limit (false). The world
## and the HUD are brought up to date after each tick, as a frame would.
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(0.0)
		_hud.advance(0.0)
		if done.call():
			return true
	return false


func _fighting() -> bool:
	return _sim.expedition.state == Expedition.State.FIGHTING and _sim.expedition.battle != null


## Sets the party up just before the guardian of [param depth].
func _before_guardian(depth: int) -> void:
	var e: Expedition = _sim.expedition
	var shaft: LabyrinthChamber = _sim.labyrinth.level(depth).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func _frames_top(hud: Hud) -> float:
	var top: float = SCREEN.y
	for frame: HeroFrameView in hud.frames:
		top = minf(top, frame.get_global_rect().position.y)
	return top


# --- R1 ------------------------------------------------------------------------


func test_r1_frames_show_live_health() -> void:
	var frame: HeroFrameView = _hud.frames[0]
	var hero: Hero = _sim.party.heroes[0]
	assert_true(_step_until(_fighting), "the party meets a fight")
	var fighter: Combatant = _sim.expedition.battle.combatant(hero.id)
	assert_not_null(fighter, "the knight fights")
	if fighter == null:
		return
	_hud.advance(1.0)
	var start: float = frame.shown_health()
	fighter.health = roundi(fighter.max_health * 0.4)
	var live: float = float(fighter.health) / fighter.max_health
	_hud.advance(0.05)
	assert_lt(frame.shown_health(), start - 0.01, "the frame moves during the fight")
	assert_gt(frame.shown_health(), live + 0.01, "easing, not jumping")
	_hud.advance(0.5)
	assert_almost_eq(frame.shown_health(), live, 0.001, "and arrives at the battle's health")
	assert_ne(hero.health, fighter.health, "which is not yet the hero's own")
	assert_eq(frame.health_color(), Palette.color(&"yellow"), "coloured by the battle's health")

	_world.sim_event.emit(SimEvent.new(SimEvent.Kind.HIT, _sim.tick, -1, hero.id, 5))
	_hud.advance(0.016)
	assert_gt(frame.flash(), 0.0, "a hit in the fight flashes the frame")

	# A real death in the fight: the knight is kept at 1 health until a blow kills it.
	var died: Array[bool] = [false]
	var dimmed_at_death: Array[bool] = [false]
	var on_event: Callable = func(event: SimEvent) -> void:
		if event.kind == SimEvent.Kind.DIED and event.source_id == hero.id:
			died[0] = true
	_world.sim_event.connect(on_event)
	for i: int in LIMIT_TICKS:
		if fighter.is_alive():
			fighter.health = 1
		_sim.step()
		_world.sync(0.0)
		if died[0]:
			_hud.advance(0.016)
			dimmed_at_death[0] = frame.is_dimmed()
			break
	_world.sim_event.disconnect(on_event)
	assert_true(died[0], "the knight dies in the fight")
	assert_true(dimmed_at_death[0], "its frame is dimmed at the death event")
	assert_eq(_sim.expedition.state, Expedition.State.FIGHTING, "while the fight goes on")
	assert_gt(hero.health, 0, "though the hero's own health is untouched until the fight ends")
	assert_false(_hud.frames[1].is_dimmed(), "the living are not dimmed")

	# Outside a fight, the frame shows the hero's own health.
	_sim.expedition.battle = null
	_sim.expedition.state = Expedition.State.TRAVELLING
	hero.health = roundi(hero.max_health() * 0.8)
	_hud.advance(1.0)
	assert_false(frame.is_dimmed(), "alive again outside the fight")
	var own: float = float(hero.health) / hero.max_health()
	assert_almost_eq(frame.shown_health(), own, 0.001, "the hero's own health")


# --- R2 ------------------------------------------------------------------------


func test_r2_help_panel() -> void:
	# Spec 058 moved help to a window on the UI layer, opened by H or its button on the button bar
	# (where the ? button was); it no longer closes the other panels, nor they it.
	var main: Main = make_main()
	add_child_autofree(main)
	var windows: UiWindows = main.ui.windows
	var help: HelpPanel = windows.window(UiRoot.HELP).content as HelpPanel
	assert_not_null(help, "the game has a help window")
	if help == null:
		return
	assert_false(windows.is_open(UiRoot.HELP), "closed at first")
	var button: UiButton = main.ui.bar.buttons[UiRoot.HELP]
	assert_true(button.is_visible_in_tree(), "a help button on the bar")
	button.pressed.emit()
	assert_true(windows.is_open(UiRoot.HELP), "the button opens help")
	assert_true(help.is_visible_in_tree(), "and it shows")
	button.pressed.emit()
	assert_false(windows.is_open(UiRoot.HELP), "and closes it")
	press(KEY_H)
	assert_true(windows.is_open(UiRoot.HELP), "H opens help")
	press(KEY_H)
	assert_false(windows.is_open(UiRoot.HELP), "H closes it")
	press(KEY_H)
	press(KEY_ESCAPE)
	assert_false(windows.is_open(UiRoot.HELP), "Esc closes it")
	press(KEY_ESCAPE)
	assert_false(windows.is_open(UiRoot.HELP), "and does not open it")

	# The idea, then the keys.
	var lines: Array[String] = help.lines()
	var idea_at: int = lines.find("The idea")
	var keys_at: int = lines.find("Keys")
	assert_gte(idea_at, 0, "a part called The idea")
	assert_gt(keys_at, idea_at, "then a part called Keys")
	var idea: Array[String] = lines.slice(idea_at + 1, keys_at)
	assert_between(idea.size(), 3, 5, "the idea in at most five lines")
	var told: String = " ".join(idea).to_lower()
	for words: String in ["on its own", "stable", "wipe", "last safe stage", "gold", "upgrades"]:
		assert_string_contains(told, words, "the idea says: %s" % words)
	assert_string_contains(told, "while the game is closed", "and that it goes on while closed")
	assert_gt(HelpPanel.KEYS.size(), 8, "the keys list")
	for entry: Array in HelpPanel.KEYS:
		assert_eq(entry.size(), 2, "%s: a key and what it does" % [entry])
		var row: String = "%s  %s" % [entry[0], entry[1]]
		assert_has(lines, row, "the panel lists %s" % row)

	# Help stays open beside the shop, a hero window (spec 060) and the journal.
	press(KEY_H)
	press(KEY_U)
	assert_true(main.hud.shop.is_open(), "the shop opens")
	assert_true(windows.is_open(UiRoot.HELP), "beside help")
	main.hud.shop.close()
	press(KEY_TAB)
	assert_true(main.hud.hero_windows.is_open(), "a hero window opens")
	assert_true(windows.is_open(UiRoot.HELP), "beside help")
	main.hud.hero_windows.close_all()
	press(KEY_J)
	assert_true(windows.is_open(UiRoot.JOURNAL), "the journal opens")
	assert_true(windows.is_open(UiRoot.HELP), "beside help")

	# The game goes on behind it.
	main.driver.advance(1_000_000)
	var tick: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(windows.is_open(UiRoot.HELP), "help is open")
	assert_gt(main.simulation.tick, tick, "and the game runs behind it")
	assert_false(get_tree().paused, "unpaused")


# --- R3 ------------------------------------------------------------------------


## Every KEY_ constant written in a script under [param dir].
func _key_names_in(dir: String, into: Dictionary[String, String]) -> void:
	var pattern := RegEx.new()
	pattern.compile(KEY_PATTERN)
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var path: String = dir.path_join(file)
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			into[found.get_string()] = path
	for sub: String in DirAccess.get_directories_at(dir):
		_key_names_in(dir.path_join(sub), into)


## Presses each key of the help list's [param label] in [param main] and checks that each one
## changes what the entry says it does.
func _check_entry(main: Main, label: String) -> void:
	var hud: Hud = main.hud
	var windows: UiWindows = main.ui.windows
	var sim: Simulation = main.simulation
	var codes: Array[int] = HelpPanel.keycodes(label)
	assert_false(codes.is_empty(), "%s: names keys" % label)
	for code: int in codes:
		var what: String = "%s (%s)" % [label, OS.get_keycode_string(code)]
		match label:
			"H":
				var was: bool = windows.is_open(UiRoot.HELP)
				press(code)
				assert_ne(windows.is_open(UiRoot.HELP), was, "%s opens or closes help" % what)
				press(code)
			"Esc":
				hud.shop.open()
				press(code)
				assert_false(hud.shop.is_open(), "%s closes the shop" % what)
				windows.open_window(UiRoot.HELP)
				press(code)
				assert_false(windows.is_open(UiRoot.HELP), "%s closes help" % what)
				press(KEY_J)
				press(code)
				assert_false(windows.is_open(UiRoot.JOURNAL), "%s closes the journal" % what)
			"- +":
				sim.set_target_depth(4)
				sim.step()
				hud.advance(0.0)
				var target: String = hud.place_panel.target_label.text
				press(code)
				assert_ne(hud.place_panel.target_label.text, target, "%s changes the target" % what)
			"A":
				var auto: bool = sim.expedition.auto_push
				press(code)
				assert_ne(sim.expedition.auto_push, auto, "%s switches auto" % what)
				press(code)
			"U":
				var shop: bool = hud.shop.is_open()
				press(code)
				assert_ne(hud.shop.is_open(), shop, "%s opens or closes the shop" % what)
				hud.shop.close()
			"B":
				hud.shop.open()
				var buying: bool = hud.shop.auto_buy_on()
				press(code)
				assert_ne(hud.shop.auto_buy_on(), buying, "%s switches auto-buy" % what)
				press(code)
				hud.shop.close()
			"1-5":
				hud.shop.open()
				sim.party.gold = 10_000_000
				var id: StringName = hud.shop.rows[code - KEY_1].id
				var rank: int = sim.upgrades.rank(id)
				press(code)
				sim.step()
				assert_gt(sim.upgrades.rank(id), rank, "%s buys upgrade %s" % [what, id])
				hud.shop.close()
			"1-3":
				var hero: Hero = sim.party.heroes[0]
				hud.hero_windows.open(hero.id, HeroWindow.Page.TALENTS)  # spec 034, spec 060
				# Spec 051: a row spends a paragon point, which levels past 14 bring.
				hero.gain_xp(Hero.xp_for_level(40) - hero.xp)
				var tab: HeroTalentsTab = hud.hero_windows.window_of(hero.id).talents
				var cells: Array[ParagonCell] = tab.paragon_cells
				var training: StringName = cells[code - KEY_1].id
				var stat: TrainingDef.Stat = Content.training(training).stat
				var trained: int = hero.paragon_rank(stat)
				press(code)
				sim.step()
				assert_gt(hero.paragon_rank(stat), trained, "%s trains %s" % [what, training])
				hud.hero_windows.close_all()
			"Q E":
				hud.hero_windows.open(sim.party.heroes[0].id)
				var page: HeroWindow.Page = hud.hero_windows.front().page()
				press(code)
				assert_ne(hud.hero_windows.front().page(), page, "%s changes the front tab" % what)
				hud.hero_windows.close_all()
			"Tab":
				var front: HeroWindow = hud.hero_windows.front()
				press(code)
				assert_ne(hud.hero_windows.front(), front, "%s opens the next hero window" % what)
				hud.hero_windows.close_all()
			"Shift+Tab":
				hud.hero_windows.open(sim.party.heroes[0].id)
				press(code, true)
				assert_false(hud.hero_windows.is_open(), "%s closes the front hero window" % what)
			"J":
				var open: bool = windows.is_open(UiRoot.JOURNAL)
				press(code)
				assert_ne(
					windows.is_open(UiRoot.JOURNAL), open, "%s opens or closes the journal" % what
				)
				windows.close_window(UiRoot.JOURNAL)
			"O":
				var orders: bool = windows.is_open(UiRoot.ORDERS)
				press(code)
				assert_ne(
					windows.is_open(UiRoot.ORDERS), orders, "%s opens or closes the orders" % what
				)
				windows.close_window(UiRoot.ORDERS)
			"T":
				var tally: bool = hud.tally.is_open()
				press(code)
				assert_ne(hud.tally.is_open(), tally, "%s opens or closes the tally" % what)
				hud.tally.close()
			"L":
				var shown: bool = hud.ladder.is_shown()
				press(code)
				hud.advance(0.0)
				assert_ne(hud.ladder.is_shown(), shown, "%s shows or hides the depth ladder" % what)
				press(code)
				hud.advance(0.0)
			"W":
				var map: bool = hud.area_map.is_open()
				press(code)
				assert_ne(hud.area_map.is_open(), map, "%s opens or closes the area map" % what)
				hud.area_map.close()
			"G":
				var goals: bool = hud.goals.is_shown()
				press(code)
				hud.advance(0.0)
				assert_ne(hud.goals.is_shown(), goals, "%s shows or hides the goals" % what)
				press(code)
				hud.advance(0.0)
			"Z":
				var zoom: int = main.world.camera.zoom_level()
				press(code)
				assert_ne(main.world.camera.zoom_level(), zoom, "%s zooms" % what)
				press(code)
			"M":
				var muted: bool = main.sound.is_muted()
				press(code)
				assert_ne(main.sound.is_muted(), muted, "%s mutes or unmutes" % what)
				press(code)
			"F":
				var speed: int = main.speed
				press(code)
				assert_ne(main.speed, speed, "%s changes the game speed" % what)
				main.set_speed(speed)
			"F11":
				# Spec 067: a played game has window settings; here a file of this test's own, and
				# no window to change.
				var path: String = save_path("window", "window")
				var kept := WindowSettings.new(path)
				main.window_settings = kept
				main.add_child(kept)
				var mode: WindowSettings.Mode = kept.mode
				press(code)
				assert_ne(kept.mode, mode, "%s goes full screen" % what)
				press(code)
				assert_eq(kept.mode, mode, "%s and back" % what)
				kept.queue_free()
				main.window_settings = null
				DirAccess.remove_absolute(path)
			"F3":
				var shown_clock: bool = hud.clock_label.visible
				press(code)
				assert_ne(hud.clock_label.visible, shown_clock, "%s shows the clock" % what)
				press(code)
			_:
				fail_test("%s: this test does not know what the key should do" % what)


func test_r3_every_key_is_listed() -> void:
	# Each key the game's input code names is in the list.
	var listed: Dictionary[int, bool] = {}
	for entry: Array in HelpPanel.KEYS:
		for code: int in HelpPanel.keycodes(str(entry[0])):
			listed[code] = true
	var handled: Dictionary[String, String] = {}
	_key_names_in("res://game", handled)
	assert_gt(handled.size(), 10, "the game's key handling was found")
	for key_name: String in handled:
		var code: int = OS.find_keycode_from_string(key_name.trim_prefix("KEY_").replace("_", " "))
		assert_ne(code, KEY_NONE, "%s is a key" % key_name)
		assert_true(
			listed.has(code), "%s (in %s) is in the help list" % [key_name, handled[key_name]]
		)

	# Each listed key does something in a real game.
	var main: Main = make_main()
	add_child_autofree(main)
	main.hud.advance(0.0)
	for entry: Array in HelpPanel.KEYS:
		_check_entry(main, str(entry[0]))


# --- R4 ------------------------------------------------------------------------


## The elements that must have a tooltip, each its controls (shown or not, the first is where the
## mouse rests) and the sentence's required text ("" for any one plain sentence).
func _tipped(hud: Hud) -> Array[Array]:
	var tipped: Array[Array] = [
		["the depth number", hud.place_panel.stage_label, ""],
		["the status line", hud.place_panel.status_label, ""],
		["the stable countdown", hud.countdown.note_label, ""],
		["the target -", hud.place_panel.minus_button, ""],
		["the target +", hud.place_panel.plus_button, ""],
		["the Auto button", hud.place_panel.auto_button, ""],
		# Spec 059: the Shop button is on the UI layer's bar, with the bar's tooltips.
		["the gold", hud.purse.gold_label, ""],
		["the speed button", hud.purse.speed_button, ""],
	]
	for frame: HeroFrameView in hud.frames:
		tipped.append(["frame %d" % frame.hero_id, frame, "Click for details"])
	return tipped


func _check_tip(hud: Hud, what: String, control: Control, wanted: String) -> String:
	# Spec 061: the frame of the screen has its own tooltip, on the UI layer (spec 062: the only
	# tooltip the HUD has).
	var tip_box: Control = hud.frame_tip
	var shown: Callable = hud.frame_tip.shown_text
	var rect: Rect2 = control.get_global_rect()
	mouse_move(SCREEN / 2.0)
	hud.advance(1.0)
	assert_eq(str(shown.call()), "", "%s: nothing before resting on it" % what)
	mouse_move(rect.get_center())
	hud.advance(0.2)
	hud.advance(0.15)
	assert_eq(str(shown.call()), "", "%s: nothing before 0.4 s" % what)
	hud.advance(0.06)
	var text: String = str(shown.call())
	assert_ne(text, "", "%s: a sentence after 0.4 s" % what)
	if not wanted.is_empty():
		assert_eq(text, wanted, what)
	else:
		assert_true(text.ends_with("."), "%s: one sentence: %s" % [what, text])
		var inside: String = text.trim_suffix(".")
		assert_false(inside.contains(". "), "%s: only one: %s" % [what, text])
	var box: Rect2 = tip_box.get_global_rect()
	assert_true(tip_box.is_visible_in_tree(), "%s: the box shows" % what)
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(box), "%s: on the screen %s" % [what, box])
	assert_false(box.intersects(rect), "%s: clear of the element %s %s" % [what, box, rect])
	var labels: Array[Label] = []
	_collect_labels(tip_box, labels)
	for label: Label in labels:
		if label.is_visible_in_tree():
			assert_true(box.encloses(label.get_global_rect()), "%s: the text is in the box" % what)
	mouse_move(SCREEN / 2.0)
	hud.advance(0.016)
	assert_eq(str(shown.call()), "", "%s: hidden on leaving" % what)
	return text


func test_r4_tooltips() -> void:
	var tooltip: UiTip = _hud.frame_tip
	assert_not_null(tooltip, "the HUD has a tooltip")
	if tooltip == null:
		return
	assert_eq(tooltip.shown_text(), "", "hidden at first")
	var seen: Dictionary[String, String] = {}
	for tip: Array in _tipped(_hud):
		var what: String = tip[0]
		var control: Control = tip[1]
		assert_not_null(control, "%s exists" % what)
		if control == null:
			continue
		var text: String = _check_tip(_hud, what, control, str(tip[2]))
		if not text.is_empty() and text != "Click for details":
			assert_false(seen.has(text), "%s says what %s says" % [what, seen.get(text, "")])
			seen[text] = what

	# The boss bar, in a guardian fight.
	_before_guardian(5)
	raise_party(_sim, STRONG_LEVEL)
	assert_true(_step_until(_hud.boss_bar.is_showing), "a guardian fight")
	_check_tip(_hud, "the boss bar", _hud.boss_bar, "")


# --- R5 ------------------------------------------------------------------------


func _main_with(settings: SoundSettings, store: SaveStore) -> Main:
	var main: Main = make_main()
	main.settings = settings
	main.save_store = store
	add_child_autofree(main)
	return main


func test_r5_welcome_on_first_run() -> void:
	assert_false(SoundSettings.new(_settings_path).help_seen(), "a new settings file: not seen")
	var first: Main = _main_with(SoundSettings.new(_settings_path), null)
	assert_true(first.ui.windows.is_open(UiRoot.HELP), "a new game opens help by itself")
	assert_true(SoundSettings.new(_settings_path).help_seen(), "and remembers it was seen")
	assert_false(SoundSettings.new(_settings_path).muted(), "leaving the mute choice alone")
	first.ui.windows.close_window(UiRoot.HELP)
	first.free()

	var second: Main = _main_with(SoundSettings.new(_settings_path), null)
	assert_false(second.ui.windows.is_open(UiRoot.HELP), "not again")
	second.free()

	# Mute is kept beside it in the same file.
	var kept := SoundSettings.new(_settings_path)
	kept.set_muted(true)
	assert_true(kept.help_seen(), "muting keeps the help seen")
	kept.set_muted(false)

	DirAccess.remove_absolute(_settings_path)
	var store := SaveStore.new(_save_path)
	var saved: Simulation = Simulation.new(SEED)
	saved.party.gold = 5
	store.write(saved.to_save())
	var loaded: Main = _main_with(SoundSettings.new(_settings_path), SaveStore.new(_save_path))
	assert_eq(loaded.simulation.party.gold, 5, "a save was loaded")
	assert_false(loaded.ui.windows.is_open(UiRoot.HELP), "help does not open over a loaded save")
	assert_false(SoundSettings.new(_settings_path).help_seen(), "and is not marked seen")
	loaded.save_store = null
	loaded.free()

	var test_run: Main = make_main()
	add_child_autofree(test_run)
	assert_null(test_run.settings, "a test run has no settings file")
	assert_null(test_run.sound.settings, "nor does its sound")
	assert_false(test_run.ui.windows.is_open(UiRoot.HELP), "and never opens help by itself")


# --- R6 ------------------------------------------------------------------------


func test_r6_it_fits() -> void:
	# Spec 058: help is a window on the UI layer, in UI pixels and the UI font, placed inside the
	# smallest room (960x540) above the hero frames' line.
	var main: Main = make_main()
	add_child_autofree(main)
	main.ui.set_room_for_test(Vector2i(960, 540))
	main.ui.windows.open_window(UiRoot.HELP)
	await get_tree().process_frame
	var window: UiWindow = main.ui.windows.window(UiRoot.HELP)
	var help: HelpPanel = window.content as HelpPanel
	var rect: Rect2 = window.get_global_rect()
	var frames_top: float = main.ui.world_to_ui(Vector2(0, _frames_top(main.hud))).y
	var top_band: float = main.ui.world_to_ui(Vector2(0, TOP_BAND)).y
	assert_gte(rect.position.y, top_band, "below the top band %s" % rect)
	assert_lte(rect.end.y, frames_top, "above the party frames %s" % rect)
	assert_gte(rect.position.x, 0.0, "on screen %s" % rect)
	assert_lte(rect.end.x, 960.0, "on screen %s" % rect)
	var labels: Array[Label] = []
	_collect_labels(help, labels)
	var shown: Array[Label] = []
	for label: Label in labels:
		if label.is_visible_in_tree() and not label.text.is_empty():
			shown.append(label)
	assert_gte(shown.size(), help.lines().size(), "every line is a label")
	var texts: Array[String] = []
	for label: Label in shown:
		texts.append(label.text)
	for line: String in help.lines():
		var found: bool = false
		for text: String in texts:
			if line.begins_with(text) or line.ends_with(text) or line == text:
				found = true
		assert_true(found, "%s is shown" % line)
	for label: Label in shown:
		var where: String = "%s %s" % [label.text, label.get_global_rect()]
		assert_true(rect.encloses(label.get_global_rect()), "%s inside the window" % where)
		var font: Font = label.get_theme_font(&"font")
		assert_true(font == UiText.font() or font == UiText.font(true), "%s: the UI font" % where)
		for other: Label in shown:
			if other != label and other.get_global_rect().intersects(label.get_global_rect()):
				fail_test("%s overlaps %s" % [where, other.text])

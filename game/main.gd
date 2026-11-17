class_name Main
extends Node
## The main scene: one simulation, the driver that runs it, the world that shows it, and the HUD
## layer above, which holds a small clock readout.

## Emitted when the replay of the time away has ended, before the world is made: the
## simulation is then exactly where the replay left it.
signal caught_up(report: AwayReport)

## The seed of a new game.
const SIMULATION_SEED: int = 1
## Real seconds between automatic saves.
const SAVE_SECONDS: float = 30.0
## The most time away replayed on starting with a save (8 hours), in seconds.
const MAX_AWAY_SECONDS: float = 8.0 * 3600.0
## Less time away than this (in seconds) is not replayed.
const MIN_AWAY_SECONDS: float = 60.0
## The key of the save's stamp: the real time it was written, in seconds since 1970.
const SAVED_AT_KEY: String = "saved_at"
## Real time spent replaying per frame, at most, in microseconds.
const SLICE_USEC: int = 10_000

## The simulation this scene runs.
var simulation: Simulation
## Steps [member simulation] in real time.
var driver: SimDriver
## The labyrinth, the party and the monsters, drawn from [member simulation].
var world: World
## Where progress is kept. Null means this run does not load or save: tests, screenshots and
## headless runs. Set it before the scene enters the tree to choose the file.
var save_store: SaveStore
## Screen-space layer for the HUD, above the world.
var hud_layer: CanvasLayer
## Numbers, sparks, coins and the other effects of what happens in [member world].
var effects: CombatEffects
## The party frames, the purse and the depth readout, on [member hud_layer].
var hud: Hud
## If set to 0 or more before the scene enters the tree, used as the time away instead of the
## real clock (for a save that has a stamp; a save without one has no time away).
var away_seconds_override: float = -1.0
## The replay of the time away while it runs, then null. Null from the start without one.
var replay: AwayReplay
## Shown while [member replay] runs.
var catch_up_bar: CatchUpBar
## What happened while away, once a replay has ended; null if there was none.
var away_report: AwayReport
## The panel telling of [member away_report], until it closes.
var away_panel: AwayPanel
## Plays the sound effects; made with the world, so null during a replay (spec 021).
var sound: SoundPlayer
## The player's settings (mute, and whether help has welcomed them: spec 030 R5). Null means none:
## tests, screenshots and headless runs, which then never open help by themselves. Set it before
## the scene enters the tree to choose the file; a played game uses the default one.
var settings: SoundSettings

var _save_in: float = SAVE_SECONDS
## True when a saved game was loaded rather than a new one started.
var _loaded_save: bool = false

@onready var _clock_label: Label = $HUD/ClockLabel


func _ready() -> void:
	hud_layer = $HUD
	if save_store == null and _is_played():
		save_store = SaveStore.new()
	if settings == null and _is_played():
		settings = SoundSettings.new()
	simulation = _load_or_new()
	if replay != null:
		catch_up_bar = CatchUpBar.new()
		catch_up_bar.name = "CatchUpBar"
		hud_layer.add_child(catch_up_bar)
		return
	_start_play()


func _process(delta: float) -> void:
	if replay != null:
		_catch_up()
		return
	_save_in -= delta
	if _save_in <= 0.0:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_now()


## True while the replay is running.
func is_catching_up() -> bool:
	return replay != null


## Writes the party's progress now, stamped with the real time, if this run saves. Also happens
## every [constant SAVE_SECONDS] and when the game closes. Not during a replay: the save on
## disk, with its old stamp, still says what is left to catch up.
func save_now() -> void:
	_save_in = SAVE_SECONDS
	if save_store != null and simulation != null and replay == null:
		var data: Dictionary = simulation.to_save()
		data[SAVED_AT_KEY] = Time.get_unix_time_from_system()
		save_store.write(data)


## Seconds of time away for a save [param saved] read at [param now] (seconds since 1970): 0 if
## it has no stamp or the stamp is later than now, at most [constant MAX_AWAY_SECONDS].
static func time_away(saved: Dictionary, now: float) -> float:
	var stamp: Variant = saved.get(SAVED_AT_KEY)
	if not (stamp is float or stamp is int):
		return 0.0
	var stamp_seconds: float = stamp
	return clampf(now - stamp_seconds, 0.0, MAX_AWAY_SECONDS)


## Makes the driver, the world, the effects and the HUD, and starts normal play.
func _start_play() -> void:
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.simulation = simulation
	driver.ticked.connect(_on_ticked)
	add_child(driver)
	world = World.new()
	world.name = "World"
	world.simulation = simulation
	add_child(world)
	effects = CombatEffects.new()
	effects.name = "CombatEffects"
	add_child(effects)
	effects.setup(world, simulation)
	hud = Hud.new()
	hud.name = "Hud"
	hud_layer.add_child(hud)
	hud.setup(simulation, world, effects)
	sound = SoundPlayer.new()
	sound.name = "SoundPlayer"
	sound.settings = settings
	add_child(sound)
	sound.setup(world, effects, simulation)
	_show_clock()
	_save_in = SAVE_SECONDS
	_welcome()


## Opens the help panel by itself the first time a new game is played (spec 030 R5), and notes in
## [member settings] that it has, so it never does again. Not over a loaded save, and never
## without settings (tests and screenshot runs).
func _welcome() -> void:
	if settings == null or _loaded_save or settings.help_seen():
		return
	hud.help.open()
	settings.set_help_seen(true)


## Runs one slice of the replay; when it is done, shows the report and starts normal play.
func _catch_up() -> void:
	var done: bool = replay.run(SLICE_USEC)
	catch_up_bar.fraction = replay.fraction()
	if not done:
		return
	away_report = replay.report
	replay = null
	simulation.drain_events()
	catch_up_bar.queue_free()
	catch_up_bar = null
	caught_up.emit(away_report)
	_start_play()
	away_panel = AwayPanel.new(away_report, simulation.party)
	hud_layer.add_child(away_panel)


## The saved game if there is a good one, otherwise a new game. A saved game that was away
## long enough gets a [member replay] of that time.
func _load_or_new() -> Simulation:
	if save_store != null:
		var saved: Dictionary = save_store.read()
		if not saved.is_empty():
			var loaded: Simulation = Simulation.from_save(saved)
			if loaded != null:
				var away: float = time_away(saved, Time.get_unix_time_from_system())
				if away_seconds_override >= 0.0 and saved.has(SAVED_AT_KEY):
					away = minf(away_seconds_override, MAX_AWAY_SECONDS)
				if away >= MIN_AWAY_SECONDS:
					replay = AwayReplay.new(loaded, away)
				_loaded_save = true
				return loaded
	return Simulation.new(SIMULATION_SEED)


## True when a person is playing: in a window, and not run by a script (tests and
## the screenshot tool run through `-s`). Only then is the real save file used.
static func _is_played() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg: String in OS.get_cmdline_args():
		if arg == "-s" or arg == "--script":
			return false
	return true


func _on_ticked(_count: int) -> void:
	_show_clock()


func _show_clock() -> void:
	_clock_label.text = "Tick %d\n%.1f s" % [simulation.tick, simulation.seconds()]

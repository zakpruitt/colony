class_name Main
extends Node
## The main scene: one simulation, the driver that runs it, the world that shows it, and the HUD
## layer above, which holds a small clock readout.

## The seed of a new game.
const SIMULATION_SEED: int = 1
## Real seconds between automatic saves.
const SAVE_SECONDS: float = 30.0

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

var _save_in: float = SAVE_SECONDS

@onready var _clock_label: Label = $HUD/ClockLabel


func _ready() -> void:
	hud_layer = $HUD
	if save_store == null and _is_played():
		save_store = SaveStore.new()
	simulation = _load_or_new()
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
	_show_clock()


func _process(delta: float) -> void:
	_save_in -= delta
	if _save_in <= 0.0:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_now()


## Writes the party's progress now, if this run saves. Also happens every
## [constant SAVE_SECONDS] and when the game closes.
func save_now() -> void:
	_save_in = SAVE_SECONDS
	if save_store != null and simulation != null:
		save_store.write(simulation.to_save())


## The saved game if there is a good one, otherwise a new game.
func _load_or_new() -> Simulation:
	if save_store != null:
		var saved: Dictionary = save_store.read()
		if not saved.is_empty():
			var loaded: Simulation = Simulation.from_save(saved)
			if loaded != null:
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

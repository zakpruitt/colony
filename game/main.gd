class_name Main
extends Node
## The main scene: one simulation, the driver that runs it, the world that shows it, and the HUD
## layer above, which holds a small clock readout.

## The seed of the one simulation, until the save-system spec chooses and saves it.
const SIMULATION_SEED: int = 1

## The simulation this scene runs.
var simulation: Simulation
## Steps [member simulation] in real time.
var driver: SimDriver
## The labyrinth, the party and the monsters, drawn from [member simulation].
var world: World
## Screen-space layer for the HUD, above the world.
var hud_layer: CanvasLayer

@onready var _clock_label: Label = $HUD/ClockLabel


func _ready() -> void:
	hud_layer = $HUD
	simulation = Simulation.new(SIMULATION_SEED)
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.simulation = simulation
	driver.ticked.connect(_on_ticked)
	add_child(driver)
	world = World.new()
	world.name = "World"
	world.simulation = simulation
	add_child(world)
	_show_clock()


func _on_ticked(_count: int) -> void:
	_show_clock()


func _show_clock() -> void:
	_clock_label.text = "Tick %d\n%.1f s" % [simulation.tick, simulation.seconds()]

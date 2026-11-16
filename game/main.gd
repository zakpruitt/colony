class_name Main
extends Node
## The main scene: one simulation, the driver that runs it, and a clock readout.

## The seed of the one simulation, until the save-system spec chooses and saves it.
const SIMULATION_SEED: int = 1

## The simulation this scene runs.
var simulation: Simulation
## Steps [member simulation] in real time.
var driver: SimDriver

@onready var _clock_label: Label = $ClockLabel


func _ready() -> void:
	simulation = Simulation.new(SIMULATION_SEED)
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.simulation = simulation
	driver.ticked.connect(_on_ticked)
	add_child(driver)
	_show_clock()


func _on_ticked(_count: int) -> void:
	_show_clock()


func _show_clock() -> void:
	_clock_label.text = "Tick %d\n%.1f s" % [simulation.tick, simulation.seconds()]

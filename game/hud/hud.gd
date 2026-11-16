class_name Hud
extends Control
## The party frames, the purse, the depth and the target-depth control.
## A stub until spec 011 fills it in.

var _simulation: Simulation
var _world: World
var _effects: CombatEffects


func _ready() -> void:
	process_priority = 3  # after the world and the effects
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	advance(delta)


## Call once, before the first advance.
func setup(simulation: Simulation, world: World, effects: CombatEffects) -> void:
	_simulation = simulation
	_world = world
	_effects = effects


## Brings the HUD up to date and advances its animations. Called every frame; tests call it.
func advance(_delta: float) -> void:
	pass


## The gold count currently displayed.
func shown_gold() -> int:
	return 0

class_name CombatEffects
extends Node2D
## Turns simulation events into impact: numbers, sparks, bursts, coins.
## A stub until spec 010 fills it in.

## One coin of a gold gain has reached the gold target; amount is that coin's share.
@warning_ignore("unused_signal")  # remove when spec 010 emits it
signal coin_collected(amount: int)

## Where coins fly to, in screen pixels. The HUD sets it.
var gold_screen_target: Vector2 = Vector2(600, 12)

var _world: World
var _simulation: Simulation


func _ready() -> void:
	process_priority = 2  # after the world has synced


func _process(delta: float) -> void:
	advance(delta)


## Call once, before the first advance.
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation


## Advances every effect. Called every frame; tests call it.
func advance(_delta: float) -> void:
	pass


## How many numbers are on screen.
func live_numbers() -> int:
	return 0


## How many particles exist.
func live_particles() -> int:
	return 0

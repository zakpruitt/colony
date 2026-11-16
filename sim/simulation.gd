class_name Simulation
extends RefCounted
## The whole game state, advanced one fixed tick at a time.
##
## Every later system lives in here. The simulation never asks what time it
## is: something outside calls [method step], and each call is one tick.

## How many ticks make one second of game time.
const TICKS_PER_SECOND: int = 10
## The length of one tick in microseconds of game time.
const TICK_USEC: int = 1_000_000 / TICKS_PER_SECOND

## Ticks stepped since the simulation was created. Read-only outside this class.
var tick: int:
	get:
		return _tick
	set(_value):
		push_error("Simulation.tick is read-only; call step() to advance it")

var _seed: int
var _tick: int = 0


func _init(seed_value: int) -> void:
	_seed = seed_value


## Advances the simulation by exactly one tick.
func step() -> void:
	_tick += 1


## Game time elapsed, in seconds.
func seconds() -> float:
	return float(_tick) / TICKS_PER_SECOND


## A number that is equal for two simulations in the same state. Covers the
## seed and the tick for now; later specs add their state to it.
func state_hash() -> int:
	return hash([_seed, _tick])

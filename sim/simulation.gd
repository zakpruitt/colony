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

## The endless levels, made from the seed.
var labyrinth: Labyrinth
## The heroes and their gold.
var party: Party
## Where the party is and what it is doing.
var expedition: Expedition

var _seed: int
var _tick: int = 0
var _events: Array[SimEvent] = []


func _init(seed_value: int) -> void:
	_seed = seed_value
	labyrinth = Labyrinth.new(seed_value)
	party = Party.new()
	expedition = Expedition.new(labyrinth, party, SimRng.new(seed_value).fork("expedition"))


## Advances the simulation by exactly one tick.
func step() -> void:
	_tick += 1
	expedition.step(_tick)
	_events.append_array(expedition.drain_events())


## Sets the depth the party heads for (1 or more), from the next tick.
func set_target_depth(depth: int) -> void:
	expedition.command_target_depth(depth)


## Turns auto-push (going one level deeper once the target depth is stable) on or off.
func set_auto_push(enabled: bool) -> void:
	expedition.auto_push = enabled


## Every event since the last call, oldest first, each stamped with its tick.
func drain_events() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


## Game time elapsed, in seconds.
func seconds() -> float:
	return float(_tick) / TICKS_PER_SECOND


## A number that is equal for two simulations in the same state: the seed, the
## tick, the party, the expedition and the battle in progress.
func state_hash() -> int:
	return hash([_seed, _tick, party.hash_parts(), expedition.hash_parts()])

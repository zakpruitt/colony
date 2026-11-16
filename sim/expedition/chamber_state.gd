class_name ChamberState
extends RefCounted
## What the expedition remembers about one chamber that can hold monsters.

## How many times the chamber has refilled: 0 for its first monsters.
var visit: int = 0
## The tick the party last cleared it, or -1 while it holds monsters.
var cleared_tick: int = -1
## The monsters waiting in it, made the first time anyone needs them for this visit.
var monsters: Array[Combatant] = []

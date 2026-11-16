class_name ChamberState
extends RefCounted
## What the expedition remembers about one chamber the party has fought in.

## How many times the chamber has refilled: 0 for its first monsters.
var visit: int = 0
## True for a guardian's chamber, which stays empty longer once beaten.
var guardian: bool = false
## The tick the party last cleared it, or -1 while it holds monsters.
var cleared_tick: int = -1
## The monsters the party met in it on this visit: the fight's own, then any survivors of a wipe.
## Empty until the party meets them (reading a chamber never fills it) and once it is cleared.
var monsters: Array[Combatant] = []

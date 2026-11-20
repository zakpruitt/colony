class_name FxNode
extends Node2D
## A passing effect the world's [FxPool] holds: a particle, a word, a coin, a mote, a ring, a
## resource icon. The pool advances it once a frame and frees it once it has finished. A new
## effect extends this and overrides [method advance].


## Moves the effect on by [param delta] seconds; false once it has finished and may be freed.
func advance(_delta: float) -> bool:
	return false

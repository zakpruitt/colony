class_name GateDef
extends JobDef
## A gate: a job ([JobDef]) that closes a side path ([SidePath]). A living hero with
## [member microskill] opens it in [member work_seconds]; with nobody able, the party walks past.
## One .tres file per gate under res://data/gates.

const _WORK_SECONDS_RANGE: Vector2 = Vector2(3.0, 6.0)


## The shortest and longest a gate may take to open, in seconds.
func work_range() -> Vector2:
	return _WORK_SECONDS_RANGE

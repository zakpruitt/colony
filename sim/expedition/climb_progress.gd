class_name ClimbProgress
extends RefCounted
## Reads of a party changing stage (spec 054), for the view's crossing: where it is going and how
## far it has come. Reading changes nothing, and nothing here is in the state hash. Kept apart
## from [Expedition] so it stays under gdlint's limits.


## While [param run] is CLIMBING, the stage it is on its way to; otherwise its depth.
static func stage_to(run: Expedition) -> int:
	if run.state != Expedition.State.CLIMBING:
		return run.depth
	return run.depth + run._climb_direction


## While [param run] is CLIMBING, how far it has come, from 0 to 1; otherwise 0.0.
static func share(run: Expedition) -> float:
	if run.state != Expedition.State.CLIMBING:
		return 0.0
	var span: float = run._climb_to_y - run._climb_from_y
	if is_zero_approx(span):
		return 0.0
	return clampf((run._climb_y - run._climb_from_y) / span, 0.0, 1.0)

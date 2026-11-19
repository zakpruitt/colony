class_name StageRisk
extends RefCounted
## How a stage looks for the party: one rule for the depth ladder and the area map, so the two
## never drift.


## The risk of [param stage]: safe at or above [param safe_stage], within reach while
## [param level] (the stage's) is at most [param lowest] (the party's lowest hero level) plus one,
## dangerous beyond. With [param furthest] given (the map, judging another area), a stage counts as
## safe only once the party has reached it; -1 leaves that out (the ladder, where every stage at or
## above the safe one has been reached). A rough guide, not a promise: it changes no rule.
static func judge(
	stage: int, safe_stage: int, level: int, lowest: int, furthest: int = -1
) -> DepthLadder.Risk:
	var reached: bool = furthest < 0 or stage <= furthest
	if stage <= safe_stage and reached:
		return DepthLadder.Risk.SAFE
	# A stage is as hard as its level.
	if level <= lowest + 1:
		return DepthLadder.Risk.REACHABLE
	return DepthLadder.Risk.DANGEROUS

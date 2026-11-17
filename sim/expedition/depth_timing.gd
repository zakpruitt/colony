class_name DepthTiming
extends RefCounted
## How long things take on a depth (spec 036): quick near the surface, so a new game is busy, and
## the deep game's slow pace from [constant DEEP_DEPTH] down.

## From this depth down every time here is the deep game's, unchanged.
const DEEP_DEPTH: int = 10
## Seconds to hold depth 1 before it is stable, and every depth from DEEP_DEPTH down.
const SURFACE_STABLE_SECONDS: float = 60.0
const DEEP_STABLE_SECONDS: float = 600.0
## Seconds a cleared chamber stays empty at depth 1; from DEEP_DEPTH down it is
## [constant Expedition.RESPAWN_SECONDS].
const SURFACE_RESPAWN_SECONDS: float = 5.0


## Seconds a depth must be held to become stable, when [member Expedition.stable_seconds] has not
## been set by hand: [code]60 * 10^((depth - 1) / 9)[/code], growing by the same factor at each
## depth from 60 at depth 1 to 600 at depth 10, then 600 at every depth below.
static func stable_seconds_at(level_depth: int) -> float:
	var step: float = clampf(float(level_depth - 1) / (DEEP_DEPTH - 1), 0.0, 1.0)
	return SURFACE_STABLE_SECONDS * pow(DEEP_STABLE_SECONDS / SURFACE_STABLE_SECONDS, step)


## Seconds a cleared chamber at [param level_depth] stays empty before monsters (or a side quest)
## come back: from SURFACE_RESPAWN_SECONDS at depth 1, rising evenly to
## [constant Expedition.RESPAWN_SECONDS] at DEEP_DEPTH and staying there.
static func respawn_seconds_at(level_depth: int) -> float:
	var step: float = clampf(float(level_depth - 1) / (DEEP_DEPTH - 1), 0.0, 1.0)
	return lerpf(SURFACE_RESPAWN_SECONDS, Expedition.RESPAWN_SECONDS, step)


## Seconds before the chamber with record [param fill] refills once cleared: a beaten guardian's
## stays empty for [constant Expedition.GUARDIAN_RESPAWN_SECONDS].
static func refill_seconds(fill: ChamberState) -> float:
	if fill.guardian:
		return Expedition.GUARDIAN_RESPAWN_SECONDS
	return respawn_seconds_at(fill.depth)

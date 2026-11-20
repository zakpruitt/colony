class_name DepthTiming
extends RefCounted
## How long things take on a depth: quick near the surface, so a new game is busy, and
## the deep game's slow pace from [constant DEEP_DEPTH] down.

## From this depth down every time here is the deep game's.
const DEEP_DEPTH: int = 10
## Seconds to hold depth 1 before it is stable, and every depth from DEEP_DEPTH down.
const _SURFACE_STABLE_SECONDS: float = 60.0
const _DEEP_STABLE_SECONDS: float = 600.0
## Seconds a cleared chamber stays empty at depth 1; from DEEP_DEPTH down it is
## [constant Expedition.RESPAWN_SECONDS].
const _SURFACE_RESPAWN_SECONDS: float = 5.0


## Seconds a depth must be held to become stable, when [member Expedition.stable_seconds] has not
## been set by hand: growing by the same factor at each depth from
## [constant _SURFACE_STABLE_SECONDS] at depth 1 to [constant _DEEP_STABLE_SECONDS] at
## [constant DEEP_DEPTH], then that at every depth below.
static func stable_seconds_at(level_depth: int) -> float:
	var step: float = clampf(float(level_depth - 1) / (DEEP_DEPTH - 1), 0.0, 1.0)
	return _SURFACE_STABLE_SECONDS * pow(_DEEP_STABLE_SECONDS / _SURFACE_STABLE_SECONDS, step)


## [method Expedition.seconds_to_stable] for [param run] at tick [param now]: its depth has been
## held since tick [param since] if it is still [param timer_depth], and from [param now] if the
## depth was set from outside, as the expedition's own count does on its next step.
static func stable_left(run: Expedition, now: int, since: int, timer_depth: int) -> float:
	if run.depth <= run.last_stable_depth:
		return 0.0
	return _left(run.stable_seconds, now, since if run.depth == timer_depth else now)


## [method Expedition.seconds_to_push] for [param run] at tick [param now]. The push
## comes once the party has held its target for the stable time, counted from the later of its
## arrival and the target being set. [param timers] is the expedition's two counts: the tick the
## depth has been held since, that depth, the tick the target was set and that target. A depth or
## target set from outside counts from [param now], as the expedition's next step does.
static func push_left(run: Expedition, now: int, timers: Array[int]) -> float:
	if not run.auto_push or run.depth != run.target_depth:
		return 0.0
	var held: int = timers[0] if run.depth == timers[1] else now
	var set_at: int = timers[2] if run.target_depth == timers[3] else now
	return _left(run.stable_seconds, now, maxi(held, set_at))


## Seconds a cleared chamber at [param level_depth] stays empty before monsters (or a side quest)
## come back: from [constant _SURFACE_RESPAWN_SECONDS] at depth 1, rising evenly to
## [constant Expedition.RESPAWN_SECONDS] at DEEP_DEPTH and staying there.
static func respawn_seconds_at(level_depth: int) -> float:
	var step: float = clampf(float(level_depth - 1) / (DEEP_DEPTH - 1), 0.0, 1.0)
	return lerpf(_SURFACE_RESPAWN_SECONDS, Expedition.RESPAWN_SECONDS, step)


## Seconds before the chamber with record [param fill] refills once cleared: a beaten guardian's
## stays empty for [constant Expedition.GUARDIAN_RESPAWN_SECONDS].
static func refill_seconds(fill: ChamberState) -> float:
	if fill.guardian:
		return Expedition.GUARDIAN_RESPAWN_SECONDS
	return respawn_seconds_at(fill.depth)


## Seconds left at tick [param now] of [param seconds] counted from tick [param since], in whole
## ticks as the expedition counts them; never below 0.
static func _left(seconds: float, now: int, since: int) -> float:
	var needed: int = Combatant.seconds_to_ticks(seconds, 0)
	return float(maxi(needed - (now - since), 0)) / Simulation.TICKS_PER_SECOND

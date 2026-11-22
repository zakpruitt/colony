class_name SidePathRules
extends RefCounted
## The questions anyone may ask about an [Expedition]'s side paths, and what a cache is worth.
## Reading changes nothing.

## A cache's gold, in average kills of its stage (before the gold upgrade).
const CACHE_GOLD_KILLS: float = 6.0
## A cache's XP for each living hero, in average kills of its stage.
const CACHE_XP_KILLS: float = 3.0
## How many large monsters' drops of the area's resource a cache holds.
const CACHE_DROPS: int = 3
## How long an opened cache stays empty, its gate standing open.
const REFILL_SECONDS: float = 600.0


## True if the cache of side path [param index] on [param stage] is full at the run's tick.
static func is_full(run: Expedition, stage: int, index: int) -> bool:
	var opened: int = run._side.opened_tick(stage, index)
	return opened < 0 or run._tick >= opened + Combatant.seconds_to_ticks(REFILL_SECONDS)


## The hero who would open side path [param index]'s gate now, or null.
static func opener(run: Expedition, stage: int, index: int) -> Hero:
	var paths: Array[SidePath] = run.labyrinth.level(stage).side_paths
	if index < 0 or index >= paths.size():
		return null
	var def: GateDef = Content.gate(paths[index].gate)
	return run._party.hero_with_microskill(def.microskill) if def != null else null


## The gold a cache on [param stage] of the area [param run] is in holds, before the gold
## upgrade: [constant CACHE_GOLD_KILLS] average kills there, at least 1.
static func gold_at(run: Expedition, stage: int) -> int:
	var value: Vector2 = SideQuestDef.kill_value(run.level_at(stage))
	return maxi(roundi(CACHE_GOLD_KILLS * value.x), 1)


## The XP a cache on [param stage] gives each living hero: [constant CACHE_XP_KILLS] average
## kills there, at least 1.
static func xp_at(run: Expedition, stage: int) -> int:
	var value: Vector2 = SideQuestDef.kill_value(run.level_at(stage))
	return maxi(roundi(CACHE_XP_KILLS * value.y), 1)

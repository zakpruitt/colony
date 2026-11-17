class_name AwayReplay
extends RefCounted
## Plays the time the game was closed through the real simulation, a slice at a time, and
## counts what happened in an [AwayReport] (spec 019). Only the number of ticks differs from
## watching: every tick is [method Simulation.step], and its events are drained and counted
## rather than shown.

## The simulation being replayed.
var simulation: Simulation
## Ticks the time away comes to, and ticks stepped so far.
var total_ticks: int
var done_ticks: int = 0
## What happened; complete once [method is_done].
var report: AwayReport

var _levels_before: Dictionary[int, int] = {}
var _gold_before: int
## The depth of the deepest guardian slain so far, or -1.
var _deepest_guardian_depth: int = -1
## Side quests missed for want of each microskill (by its position in
## [method Content.microskill_ids]), in the order each was first missed.
var _missed_by_skill: Dictionary[int, int] = {}


## A replay of [param seconds] of game time on [param sim], from its current state.
func _init(sim: Simulation, seconds: float) -> void:
	simulation = sim
	total_ticks = roundi(seconds * Simulation.TICKS_PER_SECOND)
	report = AwayReport.new()
	report.seconds = seconds
	report.depth_before = sim.expedition.depth
	report.depth_after = sim.expedition.depth
	report.area_before = sim.expedition.place
	report.area_after = sim.expedition.place
	_gold_before = sim.party.gold
	for hero: Hero in sim.party.heroes:
		_levels_before[hero.id] = hero.level
		report.levels_gained[hero.id] = 0
	sim.drain_events()


## Steps the simulation until [param budget_usec] of real time is spent or the replay is
## done, then brings the report up to date. Returns true when the replay is done.
func run(budget_usec: int) -> bool:
	var start: int = Time.get_ticks_usec()
	while done_ticks < total_ticks and Time.get_ticks_usec() - start < budget_usec:
		simulation.step()
		done_ticks += 1
		for event: SimEvent in simulation.drain_events():
			match event.kind:
				SimEvent.Kind.DIED:
					if event.source_id >= Expedition.FIRST_MONSTER_ID:
						report.kills += 1
				SimEvent.Kind.GUARDIAN_SLAIN:
					report.guardians_slain += 1
					_deepest_guardian_depth = maxi(_deepest_guardian_depth, event.amount)
				SimEvent.Kind.SIDE_QUEST_DONE:
					report.side_quests_done += 1
				SimEvent.Kind.SIDE_QUEST_MISSED:
					report.side_quests_missed += 1
					var missed: int = _missed_by_skill.get(event.amount, 0)
					_missed_by_skill[event.amount] = missed + 1
				SimEvent.Kind.MICROSKILL_LEARNED:
					report.microskills_learned.append(Vector2i(event.source_id, event.target_id))
				SimEvent.Kind.PARTY_WIPED:
					report.wipes += 1
				SimEvent.Kind.UPGRADE_BOUGHT:
					report.upgrades_bought += 1
				SimEvent.Kind.RESOURCE_GAINED:
					var ids: Array[StringName] = Content.resource_ids()
					if event.target_id >= 0 and event.target_id < ids.size():
						var id: StringName = ids[event.target_id]
						report.resources_gained[id] = (
							report.resources_gained.get(id, 0) + event.amount
						)
	_update_report()
	return is_done()


## True once every tick of the time away has been stepped.
func is_done() -> bool:
	return done_ticks >= total_ticks


## How far through the replay is, from 0 to 1.
func fraction() -> float:
	if total_ticks <= 0:
		return 1.0
	return float(done_ticks) / float(total_ticks)


func _update_report() -> void:
	report.gold_gained = simulation.party.gold - _gold_before
	report.depth_after = simulation.expedition.depth
	report.area_after = simulation.expedition.place
	for hero: Hero in simulation.party.heroes:
		report.levels_gained[hero.id] = hero.level - _levels_before.get(hero.id, hero.level)
	if _deepest_guardian_depth >= 0:
		report.deepest_guardian = simulation.expedition.guardian_of(_deepest_guardian_depth)
	report.most_needed_microskill = _most_needed()


## The microskill the missed side quests needed most often, or &"" if none was missed. A tie goes
## to the one missed first.
func _most_needed() -> StringName:
	var best: int = -1
	var best_count: int = 0
	for skill: int in _missed_by_skill:
		if _missed_by_skill[skill] > best_count:
			best = skill
			best_count = _missed_by_skill[skill]
	var ids: Array[StringName] = Content.microskill_ids()
	if best < 0 or best >= ids.size():
		return &""
	return ids[best]

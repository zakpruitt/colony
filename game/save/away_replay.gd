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


## A replay of [param seconds] of game time on [param sim], from its current state.
func _init(sim: Simulation, seconds: float) -> void:
	simulation = sim
	total_ticks = roundi(seconds * Simulation.TICKS_PER_SECOND)
	report = AwayReport.new()
	report.seconds = seconds
	report.depth_before = sim.expedition.depth
	report.depth_after = sim.expedition.depth
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
				SimEvent.Kind.GOLD_GAINED:
					report.kills += 1
				SimEvent.Kind.PARTY_WIPED:
					report.wipes += 1
				SimEvent.Kind.UPGRADE_BOUGHT:
					report.upgrades_bought += 1
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
	for hero: Hero in simulation.party.heroes:
		report.levels_gained[hero.id] = hero.level - _levels_before.get(hero.id, hero.level)

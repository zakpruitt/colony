extends GutTest
## Acceptance tests for specs/036-a-livelier-start/spec.md, one per requirement: a new game is busy
## in its first half hour, and the deep game keeps its pace.
##
## Every statement about a new game is measured on the same runs, made once in before_all: for each
## of seeds 1 to 5, a default run of PLAIN_MINUTES and a run with auto-buy on of LONG_MINUTES.

const SEEDS: Array[int] = [1, 2, 3, 4, 5]
const PLAIN_MINUTES: int = 35
const LONG_MINUTES: int = 180
## Average gold and XP of one kill at depths 10 and 20 (SideQuestDef.kill_value) before this spec.
const KILL_VALUE_10: Vector2 = Vector2(15.851352, 39.81081)
const KILL_VALUE_20: Vector2 = Vector2(35.685394, 96.77528)
const STEP: float = 1.0 / 60.0

## What one run measured, by seed. Keys: see [method _measure].
var _plain: Dictionary[int, Dictionary] = {}
var _bought: Dictionary[int, Dictionary] = {}

# --- Helpers -------------------------------------------------------------------


func before_all() -> void:
	for seed_value: int in SEEDS:
		_plain[seed_value] = _measure(seed_value, false, PLAIN_MINUTES)
		_bought[seed_value] = _measure(seed_value, true, LONG_MINUTES)


func _ticks(seconds: float) -> int:
	return roundi(seconds * Simulation.TICKS_PER_SECOND)


## Runs a new game for [param minutes], with auto-buy on if [param buying], and returns what the
## requirements ask about, in game seconds where it is a time (absent when it did not happen).
func _measure(seed_value: int, buying: bool, minutes: int) -> Dictionary:
	var sim := Simulation.new(seed_value)
	sim.set_auto_buy(buying)
	var e: Expedition = sim.expedition
	var found: Dictionary = {}
	var battles_2: int = 0
	var busy_10: int = 0
	var dead: int = 0
	var levelled: Dictionary[int, Dictionary] = {2: {}, 5: {}}
	var guardian_fight: bool = false
	var guardian_losses: int = 0
	var cheapest_upgrade: int = _cheapest_upgrade(sim)
	var cheapest_training: int = _cheapest_training(sim)
	for i: int in _ticks(minutes * 60.0):
		sim.step()
		var now: float = sim.seconds()
		if sim.party.gold >= cheapest_upgrade and not found.has("upgrade"):
			found["upgrade"] = now
		if sim.party.gold >= cheapest_training and not found.has("training"):
			found["training"] = now
		if sim.tick == _ticks(600.0):
			found["ranks_10"] = _ranks(sim)
		if sim.tick <= _ticks(1200.0) and e.state == Expedition.State.TRAVELLING and _dead(sim):
			dead += 1
		for event: SimEvent in sim.drain_events():
			match event.kind:
				SimEvent.Kind.ENCOUNTER_STARTED:
					battles_2 += 1 if now <= 120.0 else 0
					busy_10 += 1 if now <= 600.0 else 0
					guardian_fight = _holds_guardian(e)
					if guardian_fight and not found.has("guardian_met"):
						found["guardian_met"] = now
				SimEvent.Kind.SIDE_QUEST_STARTED:
					busy_10 += 1 if now <= 600.0 else 0
				SimEvent.Kind.ENCOUNTER_ENDED:
					if guardian_fight and not event.flag and not found.has("guardian_beaten"):
						guardian_losses += 1
					guardian_fight = false
				SimEvent.Kind.GUARDIAN_SLAIN:
					if not found.has("guardian_beaten"):
						found["guardian_beaten"] = now
				SimEvent.Kind.DEPTH_CHANGED:
					if not found.has("depth_%d" % event.amount):
						found["depth_%d" % event.amount] = now
				SimEvent.Kind.LEVEL_UP:
					if levelled.has(event.amount):
						levelled[event.amount][event.target_id] = now
	for level: int in levelled:
		if levelled[level].size() == sim.party.heroes.size():
			found["level_%d" % level] = levelled[level].values().max()
	found["battles_2"] = battles_2
	found["busy_10"] = busy_10
	found["dead_share"] = float(dead) / _ticks(1200.0)
	found["losses_before_win"] = guardian_losses
	found["deepest"] = e.deepest_depth
	return found


func _cheapest_upgrade(sim: Simulation) -> int:
	var cheapest: int = -1
	for id: StringName in Content.upgrade_ids():
		var price: int = sim.upgrades.cost(id)
		cheapest = price if cheapest < 0 else mini(cheapest, price)
	return cheapest


func _cheapest_training(sim: Simulation) -> int:
	var cheapest: int = -1
	for hero: Hero in sim.party.heroes:
		for id: StringName in Content.training_ids():
			var price: int = hero.training_cost(id)
			cheapest = price if cheapest < 0 else mini(cheapest, price)
	return cheapest


func _ranks(sim: Simulation) -> int:
	var ranks: int = 0
	for id: StringName in Content.upgrade_ids():
		ranks += sim.upgrades.rank(id)
	return ranks


func _holds_guardian(e: Expedition) -> bool:
	if e.battle == null:
		return false
	for monster: Combatant in e.battle.monsters:
		if Content.monster(monster.def_id).guardian:
			return true
	return false


## True when no chamber on the party's level holds monsters or a side quest a living hero can do.
func _dead(sim: Simulation) -> bool:
	var e: Expedition = sim.expedition
	for room: LabyrinthChamber in sim.labyrinth.level(e.depth).chambers:
		if e.is_populated(e.depth, room.index):
			return false
		var quest: StringName = e.side_quest_in(e.depth, room.index)
		if quest != &"":
			var def: SideQuestDef = Content.side_quest(quest)
			if sim.party.hero_with_microskill(def.microskill) != null:
				return false
	return true


func _time(run: Dictionary, key: String) -> float:
	var seconds: float = run.get(key, INF)
	return seconds


func _report(runs: Dictionary[int, Dictionary], keys: Array[String]) -> String:
	var lines: PackedStringArray = []
	for seed_value: int in SEEDS:
		var parts: PackedStringArray = []
		for key: String in keys:
			parts.append("%s %s" % [key, runs[seed_value].get(key, "-")])
		lines.append("seed %d: %s" % [seed_value, ", ".join(parts)])
	var text: String = "\n".join(lines)
	gut.p(text)
	return text


func _step_until(sim: Simulation, done: Callable, limit: int = 20_000) -> bool:
	for i: int in limit:
		if done.call():
			return true
		sim.step()
		sim.drain_events()
	return done.call()


# --- R1 ------------------------------------------------------------------------


func test_r1_stability_scales() -> void:
	assert_almost_eq(DepthTiming.stable_seconds_at(1), 60.0, 0.001, "depth 1: at most 60 s")
	assert_almost_eq(DepthTiming.stable_seconds_at(5), 60.0 * pow(10.0, 4.0 / 9.0), 0.001)
	assert_almost_eq(DepthTiming.stable_seconds_at(10), 600.0, 0.001, "depth 10: today's 600 s")
	assert_almost_eq(DepthTiming.stable_seconds_at(30), 600.0, 0.001, "and 600 s below")
	for depth: int in range(1, 10):
		assert_lt(
			DepthTiming.stable_seconds_at(depth),
			DepthTiming.stable_seconds_at(depth + 1),
			"grows from depth %d" % depth
		)

	# The countdown follows the curve: in the simulation and on the HUD.
	var sim := Simulation.new(1)
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	var fx := CombatEffects.new()
	add_child_autofree(fx)
	fx.set_process(false)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(sim, world, fx)
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	sim.set_target_depth(2)
	assert_true(_step_until(sim, func() -> bool: return e.depth == 2), "the party reaches depth 2")
	var curve: float = DepthTiming.stable_seconds_at(2)
	assert_almost_eq(e.stable_seconds, curve, 0.001, "stable_seconds is the curve at depth 2")
	assert_almost_eq(e.seconds_to_stable(), curve, 0.1, "the whole time is still to hold")
	var left: int = ceili(e.seconds_to_stable())
	hud.advance(0.0)
	assert_eq(hud.stable_text().get_slice(",", 0), "Stable in %d:%02d" % [left / 60, left % 60])
	var predicted: int = roundi(e.seconds_to_stable() * Simulation.TICKS_PER_SECOND)
	var started: int = sim.tick
	var stable_at: int = -1
	for i: int in _ticks(curve) + 10:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED and stable_at < 0:
				stable_at = event.tick
	assert_eq(stable_at - started, predicted, "stable on the tick the count runs out")

	# A value set by hand holds at every depth.
	var flat := Simulation.new(1)
	flat.expedition.stable_seconds = 30.0
	flat.set_auto_push(false)
	flat.set_target_depth(2)
	var f: Expedition = flat.expedition
	assert_true(_step_until(flat, func() -> bool: return f.depth == 2), "the party reaches depth 2")
	assert_almost_eq(f.seconds_to_stable(), 30.0, 0.1, "30 s at depth 2")
	f.depth = 7
	assert_eq(f.stable_seconds, 30.0, "and at depth 7")


# --- R2 ------------------------------------------------------------------------


func test_r2_opening_is_busy() -> void:
	var text: String = _report(_plain, ["battles_2", "busy_10"] as Array[String])
	for seed_value: int in SEEDS:
		var run: Dictionary = _plain[seed_value]
		assert_gte(
			run["battles_2"] as int, 5, "5 battles in 2 minutes, seed %d\n%s" % [seed_value, text]
		)
		assert_gte(run["busy_10"] as int, 24, "24 in 10 minutes, seed %d\n%s" % [seed_value, text])


# --- R3 ------------------------------------------------------------------------


func test_r3_little_dead_time() -> void:
	var text: String = _report(_plain, ["dead_share"] as Array[String])
	for seed_value: int in SEEDS:
		var share: float = _plain[seed_value]["dead_share"]
		assert_lte(share, 0.35, "at most 35%% dead time, seed %d\n%s" % [seed_value, text])


# --- R4 ------------------------------------------------------------------------


func test_r4_progress_comes_early() -> void:
	var keys: Array[String] = ["level_2", "level_5", "depth_2", "depth_5"]
	var text: String = _report(_plain, keys)
	var limits: Array[float] = [90.0, 720.0, 180.0, 1200.0]
	for seed_value: int in SEEDS:
		for i: int in keys.size():
			var when: float = _time(_plain[seed_value], keys[i])
			assert_lte(
				when, limits[i], "%s by %d s, seed %d\n%s" % [keys[i], limits[i], seed_value, text]
			)


# --- R5 ------------------------------------------------------------------------


func test_r5_decisions_come_early() -> void:
	var text: String = _report(_plain, ["upgrade", "training"] as Array[String])
	text += "\n" + _report(_bought, ["ranks_10"] as Array[String])
	for seed_value: int in SEEDS:
		var where: String = "seed %d\n%s" % [seed_value, text]
		assert_lte(_time(_plain[seed_value], "upgrade"), 90.0, "an upgrade affordable, " + where)
		assert_gte(
			_bought[seed_value]["ranks_10"] as int, 6, "6 ranks bought by minute 10, " + where
		)
		assert_lte(_time(_plain[seed_value], "training"), 240.0, "a training rank, " + where)


# --- R6 ------------------------------------------------------------------------


func test_r6_first_guardian() -> void:
	var keys: Array[String] = ["guardian_met", "losses_before_win", "guardian_beaten"]
	var text: String = _report(_plain, keys) + "\nauto-buy:\n" + _report(_bought, keys)
	var lost_first: int = 0
	var beaten_in_hour: int = 0
	for seed_value: int in SEEDS:
		var plain: Dictionary = _plain[seed_value]
		assert_lte(_time(plain, "guardian_met"), 1500.0, "met by minute 25, seed %d" % seed_value)
		if plain.has("guardian_beaten") and (plain["losses_before_win"] as int) >= 1:
			lost_first += 1
		if _time(_bought[seed_value], "guardian_beaten") <= 3600.0:
			beaten_in_hour += 1
	assert_gte(lost_first, 3, "lost before beating it on 3 of 5 seeds\n" + text)
	assert_gte(beaten_in_hour, 4, "beaten within the hour with auto-buy on 4 of 5\n" + text)


# --- R7 ------------------------------------------------------------------------


func test_r7_deep_game_keeps_pace() -> void:
	for depth: int in [10, 20]:
		assert_eq(DepthTiming.stable_seconds_at(depth), 600.0, "stable time at depth %d" % depth)
		assert_eq(DepthTiming.respawn_seconds_at(depth), 90.0, "respawn at depth %d" % depth)
		var fill := ChamberState.new()
		fill.depth = depth
		assert_eq(DepthTiming.refill_seconds(fill), 90.0, "a chamber refills as before")
	assert_eq(Expedition.RESPAWN_SECONDS, 90.0)
	assert_eq(Expedition.GUARDIAN_RESPAWN_SECONDS, 1800.0)
	assert_almost_eq(
		SideQuestDef.kill_value(10),
		KILL_VALUE_10,
		Vector2(0.001, 0.001),
		"a kill at depth 10 is worth the same"
	)
	assert_almost_eq(
		SideQuestDef.kill_value(20),
		KILL_VALUE_20,
		Vector2(0.001, 0.001),
		"a kill at depth 20 is worth the same"
	)
	var text: String = _report(_bought, ["deepest"] as Array[String])
	for seed_value: int in SEEDS:
		assert_lte(
			_bought[seed_value]["deepest"] as int, 22, "3 hours, seed %d\n%s" % [seed_value, text]
		)

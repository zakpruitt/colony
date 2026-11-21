extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/039-the-countdown-tells-the-truth/spec.md, one per requirement.
##
## The HUD tests build a World on a seeded simulation with the CombatEffects and the Hud on it,
## every _process turned off, put the simulation in a situation by hand or by stepping it, and read
## the depth panel's note and the goals tracker. Nothing here assumes a stable time: it is read
## from the expedition or from [DepthTiming].

const SEED: int = 39
const STRONG_LEVEL: int = 40
const GUARDIAN_DEPTH: int = 5
## State hashes every 600 ticks over the first 10 minutes of a default game, recorded on dev before
## this spec (R5).
## Re-recorded by spec 052, whose hash includes the resources the party holds; the game is
## otherwise the same (test_052 R11 checks it against spec 016's hashes from before).
const RECORDED_HASHES: Dictionary = {
	7:
	[
		2894827325,
		1945528636,
		1128693549,
		1276362820,
		2139888516,
		1167871002,
		1988223463,
		625401331,
		455972621,
		3181058316,
	],
	39:
	[
		3699167120,
		2491842055,
		2065065973,
		2243162567,
		1931022560,
		444176140,
		3351257073,
		3374559654,
		2868346502,
		3505079905,
	],
}


func before_each() -> void:
	_build(SEED)


# --- Helpers -------------------------------------------------------------------


func _build(seed_value: int) -> void:
	_sim = Simulation.new(seed_value)
	_build_hud(false)


## "m:ss" for [param seconds], rounded up, as the HUD writes a countdown.
func _clock(seconds: float) -> String:
	var whole: int = ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## Steps the simulation once, then brings the world and the HUD up to date as a frame would.
func _tick() -> void:
	_sim.step()
	_sim.drain_events()
	_world.sync(0.1)
	_hud.advance(STEP)


## Puts the expedition by hand on [param depth], deepest [param deepest], last stable depth
## [param stable], target [param target], auto-push [param push], then steps once.
func _situation(depth: int, deepest: int, stable: int, target: int, push: bool) -> void:
	var e: Expedition = _sim.expedition
	raise_party(_sim, STRONG_LEVEL)
	e.depth = depth
	e.x = _sim.labyrinth.level(depth).chambers[0].rect.position.x
	e.deepest_depth = deepest
	e.last_stable_depth = stable
	e.target_depth = target
	e.auto_push = push
	_tick()


## Puts the party on the guardian's depth, the deepest yet, under the Hold order with a target
## below it: it holds at the guardian.
func _holding() -> void:
	_situation(GUARDIAN_DEPTH, GUARDIAN_DEPTH, GUARDIAN_DEPTH - 1, GUARDIAN_DEPTH + 1, true)
	_sim.expedition.guardian_order = Expedition.GuardianOrder.HOLD
	_hud.advance(STEP)
	# A depth goal finished by the jump has its moment and goes.
	_hud.advance(Goals.CELEBRATE_SECONDS + 0.1)


## Steps [param sim] until its target depth rises above [param from]; the tick it rose, or -1.
func _tick_target_rises(sim: Simulation, from: int) -> int:
	for i: int in LIMIT_TICKS_10_MIN:
		sim.step()
		sim.drain_events()
		if sim.expedition.target_depth > from:
			return sim.tick
	return -1


# --- R1 ------------------------------------------------------------------------


func test_r1_seconds_to_push() -> void:
	for seed_value: int in [1, 2, 3]:
		var sim := Simulation.new(seed_value)
		raise_party(sim, STRONG_LEVEL)
		var e: Expedition = sim.expedition
		# At depth 1 from the start, then at depth 2 once the party has arrived there.
		for depth: int in [1, 2]:
			var where: String = "seed %d, depth %d" % [seed_value, depth]
			for i: int in LIMIT_TICKS_10_MIN:
				if e.depth == depth and e.target_depth == depth:
					if e.state == Expedition.State.TRAVELLING:
						break
				sim.step()
				sim.drain_events()
			assert_eq(e.depth, depth, "%s: the party is there" % where)
			assert_eq(e.target_depth, depth, "%s: and it is the target" % where)
			sim.step()
			sim.drain_events()
			var left: float = e.seconds_to_push()
			assert_gt(left, 0.0, "%s: time still to hold" % where)
			assert_lte(left, e.stable_seconds, "%s: no more than the stable time" % where)
			var predicted: int = roundi(left * Simulation.TICKS_PER_SECOND)
			var started: int = sim.tick
			var risen: int = _tick_target_rises(sim, depth)
			assert_eq(risen - started, predicted, "%s: the target rises when it runs out" % where)
			assert_eq(e.target_depth, depth + 1, "%s: by one" % where)
			assert_eq(e.seconds_to_push(), 0.0, "%s: 0 on the tick the target rises" % where)

	# It counts down one tick at a time to the push.
	var counted := Simulation.new(SEED)
	counted.step()
	var before: float = counted.expedition.seconds_to_push()
	counted.step()
	assert_almost_eq(
		counted.expedition.seconds_to_push(),
		before - 1.0 / Simulation.TICKS_PER_SECOND,
		0.0001,
		"a tick later, a tick less"
	)

	# Off, and away from the target.
	var off := Simulation.new(SEED)
	off.set_auto_push(false)
	off.step()
	assert_eq(off.expedition.target_depth, 1, "at the target")
	assert_eq(off.expedition.seconds_to_push(), 0.0, "0.0 with auto-push off")
	var away := Simulation.new(SEED)
	away.set_target_depth(3)
	away.step()
	assert_ne(away.expedition.depth, away.expedition.target_depth, "away from the target")
	assert_eq(away.expedition.seconds_to_push(), 0.0, "0.0 away from the target")

	# Reading changes nothing.
	var read := Simulation.new(SEED)
	for i: int in 50:
		read.step()
	var hash_before: int = read.state_hash()
	for i: int in 3:
		read.expedition.seconds_to_push()
	assert_eq(read.state_hash(), hash_before, "reading leaves the state hash unchanged")


# --- R2 ------------------------------------------------------------------------


func test_r2_stable_note() -> void:
	var e: Expedition = _sim.expedition

	# Stable here, auto-push on, at the target: the countdown to the push.
	_build(SEED)
	e = _sim.expedition
	for i: int in 30:
		_tick()
	assert_eq(e.depth, 1, "on Mossy Hollow 1")
	assert_eq(e.seconds_to_stable(), 0.0, "which is stable")
	assert_gt(e.seconds_to_push(), 0.0, "and the push still to come")
	var deeper: String = "Further in %s" % _clock(e.seconds_to_push())
	assert_eq(_hud.countdown.note_label.text, deeper, "the note counts to the push")
	assert_eq(_hud.countdown.next_label.text, "then stage 2", "and says what comes")
	assert_eq(_hud.stable_text(), deeper + ", then stage 2", "the whole note")
	assert_true(_hud.countdown.bar.visible, "with its bar")
	assert_almost_eq(
		_hud.stable_progress(),
		1.0 - e.seconds_to_push() / e.stable_seconds,
		0.001,
		"filling toward the push"
	)
	assert_lt(_hud.stable_progress(), 1.0, "not full")

	# Heading to another depth: the note is this depth's, with no then line.
	_sim.set_auto_push(true)
	_sim.set_target_depth(3)
	_tick()
	assert_ne(e.depth, e.target_depth, "heading down")
	assert_eq(_hud.stable_text(), "Stable", "a stable depth, no then line")
	assert_false(_hud.countdown.bar.visible, "no bar")
	_situation(2, 2, 1, 4, true)
	assert_eq(_hud.stable_text(), "Stable in %s" % _clock(e.seconds_to_stable()), "not yet stable")
	assert_true(_hud.countdown.bar.visible, "with its bar")

	# Holding at a guardian.
	_holding()
	assert_true(e.is_holding(), "the party holds at the guardian")
	assert_false(_hud.countdown.bar.visible, "no bar")


# --- R3 ------------------------------------------------------------------------


func test_r3_goal_agrees() -> void:
	var e: Expedition = _sim.expedition
	var goals: Goals = _hud.goals

	# At the deepest depth, auto-push on: the bar fills toward the push and reads the time left.
	for i: int in 30:
		_tick()
	var line: int = _line("Reach Mossy Hollow 2")
	assert_ne(line, -1, "the depth goal: %s" % [goals.lines()])
	assert_eq(e.seconds_to_stable(), 0.0, "depth 1 is already stable")
	assert_almost_eq(
		goals.progress(line), 1.0 - e.seconds_to_push() / e.stable_seconds, 0.001, "the push"
	)
	assert_lt(goals.progress(line), 1.0, "not full")
	assert_eq(goals.detail(line), "in %s" % _clock(e.seconds_to_push()), "the time left")
	for i: int in 20:
		_tick()
	assert_eq(goals.detail(line), "in %s" % _clock(e.seconds_to_push()), "counting down")

	# Auto-push off.
	_sim.set_auto_push(false)
	_tick()
	line = _line("Reach Mossy Hollow 2")
	assert_eq(goals.detail(line), "Auto is off", "says auto is off")
	assert_lt(goals.progress(line), 1.0, "not full")
	var how: String = goals.hint(line)
	assert_true(how.contains("Auto") and how.contains("target"), "how to go deeper: %s" % how)
	assert_true(how.ends_with(".") and not how.trim_suffix(".").contains(". "), "one sentence")

	# Holding at a guardian: the guardian's goal, not the depth's.
	_holding()
	assert_true(e.is_holding(), "the party holds at the guardian")
	var guardian: String = Content.monster(e.guardian_of(GUARDIAN_DEPTH)).display_name
	assert_eq(goals.lines()[0], "Beat the %s" % guardian, "the guardian's goal")
	assert_eq(_line("Reach Mossy Hollow %d" % (GUARDIAN_DEPTH + 1)), -1, "not the depth's")


# --- R4 ------------------------------------------------------------------------


func test_r4_new_game() -> void:
	var e: Expedition = _sim.expedition
	var goals: Goals = _hud.goals
	_hud.advance(STEP)
	for i: int in Simulation.TICKS_PER_SECOND:
		_tick()
		var note: String = _hud.countdown.note_label.text
		assert_true(note.begins_with("Further in "), "tick %d: %s" % [_sim.tick, note])
		assert_lte(e.seconds_to_push(), DepthTiming.stable_seconds_at(1), "within the stable time")
		var line: int = _line("Reach Mossy Hollow 2")
		assert_ne(line, -1, "the depth goal")
		assert_lt(goals.progress(line), 1.0, "its bar is not full")
	# Step to the push, reading both on every tick.
	var last_note: String = ""
	var last_progress: float = -1.0
	var last_target: int = e.target_depth
	for i: int in LIMIT_TICKS_10_MIN:
		last_note = _hud.countdown.note_label.text
		last_progress = goals.progress(_line("Reach Mossy Hollow 2"))
		last_target = e.target_depth
		_tick()
		if e.target_depth != last_target:
			break
	assert_eq(e.target_depth, 2, "the target becomes 2")
	assert_eq(last_note, "Further in 0:01", "the tick before, the last second")
	assert_lt(last_progress, 1.0, "and the bar short of full")
	assert_false(
		_hud.countdown.note_label.text.begins_with("Further"), "on the tick: no more countdown"
	)
	assert_eq(e.seconds_to_push(), 0.0, "the push has come")
	assert_eq(goals.progress(_line("Reach Mossy Hollow 2")), 1.0, "and the goal's bar is full")


# --- R5 ------------------------------------------------------------------------


func test_r5_nothing_else_changes() -> void:
	assert_eq(RECORDED_HASHES.size(), 2, "two seeds recorded")
	for seed_value: int in RECORDED_HASHES:
		var sim := Simulation.new(seed_value)
		var hashes: Array = []
		for i: int in 6000:
			sim.step()
			sim.drain_events()
			sim.expedition.seconds_to_push()
			if sim.tick % 600 == 0:
				hashes.append(sim.state_hash())
		var recorded: Array = RECORDED_HASHES[seed_value]
		assert_eq(hashes, recorded, "seed %d hashes as before" % seed_value)

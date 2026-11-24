class_name Expedition
extends RefCounted
## The party's journey through the labyrinth, one tick at a time: travel,
## climbing between levels, fights, rewards, rest, and falling back after a wipe.
##
## The party's place is a distance along its stage's [StageCourse], the line it walks; every
## question about place is asked of that course ([PartyPlaces] turns it into world tiles, x right
## and y down). A fight is in world columns on its chamber's own floor
## ([method LabyrinthChamber.floor_columns], [method LabyrinthChamber.floor_row]).
##
## Some plain chambers hold a quest instead of monsters: a hero with its
## microskill does it while the party stands WORKING, and without one the party walks past.
##
## Every change worth showing is reported as a [SimEvent] stamped with the
## simulation tick; [method drain_events] hands them over once.

## JOURNEYING: on the way to another area, standing where it left until it arrives.
enum State { TRAVELLING, FIGHTING, RESTING, CLIMBING, REVIVING, WORKING, JOURNEYING }
## The party's orders: how hurt it may be before it rests after a fight (see
## [method PartyOrders.rest_below]), whether it goes into a living guardian's chamber, and
## whether it turns onto the side paths it can open or walks past every gate.
enum Pace { CAUTIOUS, STEADY, BOLD }
enum GuardianOrder { CHALLENGE, HOLD }
enum SidePaths { EXPLORE, PRESS_ON }

const PARTY_SPEED: float = 3.0  # tiles per second
const CLIMB_SPEED: float = 4.0  # tiles per second
const REST_BELOW: float = 0.6
const REST_HEAL_PER_SECOND: float = 0.04
const RESPAWN_SECONDS: float = 90.0  # from DepthTiming.DEEP_DEPTH down; less nearer the surface
const REVIVE_SECONDS: float = 5.0
## A fight that lasts this long overwhelms the party (it is wiped).
const BATTLE_LIMIT_SECONDS: float = 90.0
const FIRST_MONSTER_ID: int = 100
## Monster ids are built from where the monster waits (see [method monster_id]): room for this many
## chambers on a level, visits to a chamber before its ids come round again, and monsters in one
## encounter.
const _CHAMBER_SPAN: int = 8
const VISIT_SPAN: int = 64
const _SLOT_SPAN: int = 8
## Every level whose depth is a multiple of this has a guardian holding its way on.
const GUARDIAN_EVERY: int = 5
## How long a beaten guardian's chamber stays empty, instead of RESPAWN_SECONDS.
const GUARDIAN_RESPAWN_SECONDS: float = 1800.0

## How many monsters wait in a chamber of each kind, both ends included.
const PLAIN_MONSTERS: Vector2i = Vector2i(2, 3)
const DEN_MONSTERS: Vector2i = Vector2i(4, 5)
const VAULT_MONSTERS: Vector2i = Vector2i(2, 3)
## Gold from a monster killed in a VAULT is multiplied by this.
const _VAULT_GOLD_FACTOR: int = 2
## Slack for comparing positions reached by adding up float steps.
const _EPSILON: float = 0.0001

var state: State = State.TRAVELLING
## The area the party is in, or heading to while JOURNEYING. The depths below are
## stages of the area it is in.
var area: StringName
var depth: int = 1
## The party anchor: its distance along the stage's course, and the way it travels along it
## (1 toward the course's end, -1 toward its start).
var x: float
var facing: int = 1
var target_depth: int = 1
var auto_push: bool = true
var last_stable_depth: int = 1
var deepest_depth: int = 1
## Seconds on a depth without a wipe before it is stable: [method DepthTiming.stable_seconds_at],
## or, once set by hand (a test or tool), that value at every depth.
var stable_seconds: float:
	get:
		if _stable_set >= 0.0:
			return _stable_set
		# By the stage number, not its level, so every area's first stage is safe in a minute.
		return DepthTiming.stable_seconds_at(depth)
	set(value):
		_stable_set = value
## The fight in progress, or null.
var battle: Battle
## The side path the party is on (its place in the level's side_paths), or -1 on the main route.
var side_path: int = -1
## The orders. Read-only outside the class: see [method command_order].
var pace: Pace = Pace.STEADY
var guardian_order: GuardianOrder = GuardianOrder.CHALLENGE
var side_paths: SidePaths = SidePaths.EXPLORE
## While the party is down, the tick it revives on. Read-only outside the class.
var revive_tick: int:
	get:
		return _revive_tick
## The levels of the area the party is in. Read-only outside the class.
var labyrinth: Labyrinth:
	get:
		return _labyrinth

## The area whose labyrinth the party stands in: [member area], except while JOURNEYING, when it
## is the area being left. Read-only.
var place: StringName:
	get:
		return _here.id
## The areas' state. Read-only outside the class.
var travel: AreaTravel:
	get:
		return _areas

var _labyrinth: Labyrinth
## The area of [member _labyrinth], where the party is, and the areas' other state.
var _here: AreaDef
var _areas: AreaTravel
var _party: Party
var _rng: SimRng
var _loot_rng: SimRng
var _tick: int = 0
var _stable_set: float = -1.0
var _events: Array[SimEvent] = []

## Chambers the party has fought in, by Vector2i(depth, index). Only stepping changes them:
## reading a chamber never makes or touches a record.
var _chambers: Dictionary[Vector2i, ChamberState] = {}
## Monsters rolled for a visit no one has fought yet, by Vector3i(depth, index, visit). Not state:
## a roll depends only on the seed and those three numbers, so this only saves rolling twice, and
## hands the view and the battle the same objects. Not in the hash.
var _rolled: Dictionary[Vector3i, Array] = {}
## The caches opened, and the party's trip down a side path.
var _side: SidePathWalk = SidePathWalk.new()
## The quest being done while WORKING: its chamber as Vector2i(depth, index), its id, the
## lead worker's hero id, every worker's (lead first), the tick the work began and how many
## ticks it takes. A gate being opened has the last four and no quest.
var _work_key: Vector2i = Vector2i(0, -1)
var _work_quest: StringName = &""
var _worker: int = -1
var _workers: Array[int] = []
var _work_start: int = 0
var _work_ticks: int = 0
var _battle_count: int = 0
var _battle_key: Vector2i = Vector2i(0, -1)
## The chamber the anchor stood in after the last tick, as Vector2i(depth, index);
## index -1 in a tunnel.
var _entered_key: Vector2i = Vector2i(0, -1)
## A target depth asked for by a command, applied on the next tick; 0 when none.
var _pending_target: int = 0
## Orders asked for by a command, applied on the next tick.
var _orders: PendingOrders = PendingOrders.new()

## Distance walked, and the last turn, so followers retrace the anchor's path.
var _odometer: float = 0.0
var _turn_x: float = 0.0
var _turn_odometer: float = 0.0
var _turn_facing: int = 0  # facing before the last turn; 0 when there is none to retrace

var _climb_direction: int = 1  # 1 down, -1 up
var _climb_y: float = 0.0
var _climb_from_y: float = 0.0
var _climb_to_y: float = 0.0

var _rest_ticks: int = 0
var _rest_start: Dictionary[int, int] = {}
var _revive_tick: int = 0
## Where each hero fell in the last wipe, in world tiles.
var _fallen: Dictionary[int, Vector2] = {}

## The tick from which the party has been on [member _timer_depth] without a wipe.
var _depth_since: int = 0
var _timer_depth: int = 1
## The tick [member _timer_target] became the target.
var _target_since: int = 0
var _timer_target: int = 1


## An expedition for [param party] standing where a party arrives on the first
## area's stage 1; [param first_labyrinth] is that area's labyrinth. [param rng] is the
## expedition's own stream; encounters and battles fork from it.
func _init(first_labyrinth: Labyrinth, party: Party, rng: SimRng) -> void:
	_labyrinth = first_labyrinth
	_party = party
	_rng = rng
	_loot_rng = rng.fork("loot")
	_here = Content.area(AreaTravel.first_area())
	area = _here.id
	_areas = AreaTravel.new(first_labyrinth)
	# By Arrival's rule, so revival and loading agree with it.
	_place(Arrival.column(_labyrinth, 1))


## Advances the expedition to simulation tick [param tick].
func step(tick: int) -> void:
	_tick = tick
	_apply_commands()
	match state:
		State.TRAVELLING:
			_travel()
		State.FIGHTING:
			_fight()
		State.RESTING:
			_rest()
		State.CLIMBING:
			_climb()
		State.REVIVING:
			if _tick >= _revive_tick:
				_revive()
		State.WORKING:
			QuestWork.work(self)
		State.JOURNEYING:
			_areas.journey(self)
	if state != State.FIGHTING and state != State.REVIVING and not _party.any_alive():
		_wipe()
	_count_time()


## Asks for a new target depth (1 or more); it applies from the next tick.
func command_target_depth(new_depth: int) -> void:
	_pending_target = maxi(new_depth, 1)


## Asks for a new value of one order (PartyOrders.PACE, GUARDIANS or SIDE_PATHS); it applies from
## the next tick, even while the party is down, and a value the order does not have is ignored.
func command_order(which: int, value: int) -> void:
	_orders.ask(which, value)


## The level of [param stage] in the area the party is in: base level + stage - 1.
func level_at(stage: int) -> int:
	return _here.level_at(stage)


## True while the party is being kept from a living guardian by the Hold order: its way to the
## target depth leads through the guardian's chamber on this depth (down) or the one above (up).
func is_holding() -> bool:
	if guardian_order != GuardianOrder.HOLD or _is_away():
		return false
	if depth < target_depth:
		return _guardian_alive(depth)
	return depth > target_depth and _guardian_alive(depth - 1)


## The events recorded since the last call, oldest first.
func drain_events() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


## The chamber the party is in or fighting in, or null in a tunnel or on a ladder.
func chamber() -> LabyrinthChamber:
	var level: LabyrinthLevel = _labyrinth.level(depth)
	match state:
		State.CLIMBING, State.JOURNEYING:
			return null
		State.FIGHTING:
			if _battle_key.x == depth and _battle_key.y >= 0:
				return level.chambers[_battle_key.y]
	if side_path >= 0:
		return _side.chamber(self)
	var index: int = level.course.chamber_at(x)
	return level.chambers[index] if index >= 0 else null


## Feet position of a hero in world tiles (see [method PartyPlaces.of]).
func hero_position(hero_id: int) -> Vector2:
	var rank: int = _rank_of(hero_id)
	return Vector2.ZERO if rank < 0 else PartyPlaces.of(self, hero_id, rank)


## True if this chamber currently holds monsters waiting for the party.
func is_populated(level_depth: int, chamber_index: int) -> bool:
	if not _exists(level_depth, chamber_index):
		return false
	var level: LabyrinthLevel = _labyrinth.level(level_depth)
	if ChamberRules.always_empty(_labyrinth, _here, level, chamber_index):
		return false
	var key := Vector2i(level_depth, chamber_index)
	if battle != null and _battle_key == key:
		return false
	var fill: ChamberState = _chambers.get(key, null)
	if fill != null and fill.cleared_tick >= 0 and _tick < fill.refill_tick():
		return false
	return _quest_on_visit(level_depth, chamber_index, ChamberRules.visit_now(fill, _tick)) == &""


## The monsters waiting in this chamber (empty if it is not populated).
## They stand on the chamber's floor row. Asking changes nothing in the game.
func monsters_in(level_depth: int, chamber_index: int) -> Array[Combatant]:
	if not is_populated(level_depth, chamber_index):
		return []
	var fill: ChamberState = _chambers.get(Vector2i(level_depth, chamber_index), null)
	if fill != null and fill.cleared_tick < 0 and not fill.monsters.is_empty():
		return fill.monsters.duplicate()  # survivors of a wipe
	var waiting: Array[Combatant] = []
	waiting.assign(_rolled_for(level_depth, chamber_index, ChamberRules.visit_now(fill, _tick)))
	return waiting


## The id of the monster in place [param slot] of the encounter on visit [param visit] to chamber
## [param chamber_index] at [param level_depth]: [code]FIRST_MONSTER_ID + ((depth * _CHAMBER_SPAN
## + chamber) * VISIT_SPAN + visit % VISIT_SPAN) * _SLOT_SPAN + slot[/code]. Only one visit to a
## chamber has monsters at a time, so ids are unique among the monsters that exist together; a
## chamber's ids come round again after VISIT_SPAN refills. Ids stay below 2^31 while that sum
## does.
static func monster_id(level_depth: int, chamber_index: int, visit: int, slot: int) -> int:
	var spot: int = level_depth * _CHAMBER_SPAN + chamber_index
	return FIRST_MONSTER_ID + (spot * VISIT_SPAN + visit % VISIT_SPAN) * _SLOT_SPAN + slot


## The id of the guardian that holds that stage's way down in the area the party is in, or &"" if
## the stage has none (see [method EncounterRoll.guardian_at]).
func guardian_of(level_depth: int) -> StringName:
	return EncounterRoll.guardian_at(_here, level_depth)


## Seconds the party must still hold this depth before it becomes stable; 0.0 when it already is.
## Reading it changes nothing.
func seconds_to_stable() -> float:
	if state == State.JOURNEYING:
		return 0.0
	return DepthTiming.stable_left(self, _tick, _depth_since, _timer_depth)


## Where the party arrives when revived: course distance (x), depth (y), facing (z). Changes
## nothing.
func revival_place() -> Vector3:
	var line: StageCourse = _labyrinth.level(last_stable_depth).course
	return Vector3(line.entry, last_stable_depth, Arrival.facing(line, line.entry))


## Seconds until auto-push raises the target depth; 0.0 when it is off or the party is
## not at its target. Reading it changes nothing.
func seconds_to_push() -> float:
	if state == State.JOURNEYING:
		return 0.0
	var timers: Array[int] = [_depth_since, _timer_depth, _target_since, _timer_target]
	return DepthTiming.push_left(self, _tick, timers)


## The id of the quest that chamber holds on its current visit, or &"". Like the monsters,
## it depends only on the seed, depth, chamber and visit, and asking changes nothing in the game.
func quest_in(level_depth: int, chamber_index: int) -> StringName:
	if not _exists(level_depth, chamber_index):
		return &""
	var fill: ChamberState = _chambers.get(Vector2i(level_depth, chamber_index), null)
	if fill != null and fill.cleared_tick >= 0 and _tick < fill.refill_tick():
		return &""
	return _quest_on_visit(level_depth, chamber_index, ChamberRules.visit_now(fill, _tick))


## While WORKING: the quest being done. Otherwise &"".
func working_quest() -> StringName:
	return _work_quest if state == State.WORKING else &""


## While WORKING: the worker's hero id. Otherwise -1.
func worker_id() -> int:
	return _worker if state == State.WORKING else -1


## While WORKING: how far the work has gone, from 0 to 1. Otherwise 0.0.
func work_progress() -> float:
	if state != State.WORKING or _work_ticks <= 0:
		return 0.0
	return clampf(float(_tick - _work_start) / _work_ticks, 0.0, 1.0)


## The expedition's state as plain values, for the simulation's state hash.
func hash_parts() -> Array:
	var parts: Array = [
		state,
		depth,
		x,
		facing,
		target_depth,
		auto_push,
		last_stable_depth,
		deepest_depth,
		stable_seconds,
		_battle_count,
		_battle_key,
		_entered_key,
		_pending_target,
		_odometer,
		_turn_x,
		_turn_odometer,
		_turn_facing,
		_climb_direction,
		_climb_y,
		_rest_ticks,
		_revive_tick,
		_depth_since,
		_timer_depth,
		_target_since,
		_timer_target,
		_loot_rng.save_state(),
		_work_key,
		_work_quest,
		_worker,
		_workers,
		_work_start,
		_work_ticks,
		["areas", area, _here.id, _areas.hash_parts()],
	]
	parts.append_array(_side.hash_parts(self))
	var keys: Array[Vector2i] = []
	keys.assign(_chambers.keys())
	keys.sort()
	for key: Vector2i in keys:
		var fill: ChamberState = _chambers[key]
		var held: Array = EncounterRoll.hash_parts(fill.monsters)
		parts.append([key, fill.visit, fill.cleared_tick, fill.missed, held])
	if battle != null:
		parts.append([battle.tick, battle.result(), EncounterRoll.hash_parts(battle.fighters())])
	parts.append_array(_orders.hash_parts(self))
	return parts


# --- Commands and time ---------------------------------------------------------


func _apply_commands() -> void:
	_orders.apply(self)
	# A destination waits for the fight or quest to end and the party to stand.
	var busy: bool = state == State.FIGHTING or state == State.REVIVING or state == State.WORKING
	if _areas.pending_area != &"" and not busy:
		_areas.depart(self)
	# While the party is down a command waits, so it wins over the fallback target on revival;
	# on a side path it waits for the main course.
	if _pending_target <= 0 or state == State.REVIVING or side_path >= 0:
		return
	var wanted: int = _pending_target
	_pending_target = 0
	_set_target(wanted)
	# Chosen on the way to another area: the target there.
	_areas.target_chosen = _areas.target_chosen or state == State.JOURNEYING


func _set_target(new_target: int) -> void:
	if new_target == target_depth:
		return
	target_depth = new_target
	_timer_target = target_depth
	_target_since = _tick
	_emit(SimEvent.Kind.TARGET_DEPTH_CHANGED, -1, -1, target_depth)


## Checks time on this depth (for the last stable depth) and at the target (for auto-push).
func _count_time() -> void:
	deepest_depth = maxi(deepest_depth, depth)
	if _is_away():
		return
	# A depth or target set from outside counts from the tick before this one.
	if depth != _timer_depth:
		_restart_depth_count(_tick - 1)
	if target_depth != _timer_target:
		_timer_target = target_depth
		_target_since = _tick - 1
	var needed: int = Combatant.seconds_to_ticks(stable_seconds, 0)
	if _tick - _depth_since >= needed and depth > last_stable_depth:
		last_stable_depth = depth
		_emit(SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, depth)
	if not auto_push or depth != target_depth:
		return
	if _tick - maxi(_depth_since, _target_since) >= needed:
		_set_target(target_depth + 1)


## Starts counting time on the current depth from [param since].
func _restart_depth_count(since: int) -> void:
	_timer_depth = depth
	_depth_since = since


# --- Travel --------------------------------------------------------------------


func _travel() -> void:
	var level: LabyrinthLevel = _labyrinth.level(depth)
	var holding: bool = is_holding()
	var goal: float = PartyPlaces.walk_goal(self, holding)
	if _side.travel(self, goal):
		return
	_walk_toward(goal)
	var key: Vector2i = _key_here()
	if key != _entered_key:
		_entered_key = key
		var here: LabyrinthChamber = level.chambers[key.y] if key.y >= 0 else null
		if here != null and is_populated(depth, here.index):
			_start_battle(here)
			return
		var quest: StringName = quest_in(depth, here.index) if here != null else &""
		if quest != &"":
			QuestWork.meet(self, here, quest)
			if state != State.TRAVELLING:
				return

	if absf(x - goal) > _EPSILON:
		return
	if holding:
		_turn(-facing)
	elif depth < target_depth:
		_start_climb(1)
	elif depth > target_depth:
		_start_climb(-1)
	else:
		_turn(-facing)


func _walk_toward(goal: float) -> void:
	var direction: float = signf(goal - x)
	if direction == 0.0:
		return
	if int(direction) != facing:
		_turn(int(direction))
	var stride: float = PartyPlaces.stride(self, goal)
	x += direction * stride
	_odometer += stride


func _turn(new_facing: int) -> void:
	_turn_x = x
	_turn_odometer = _odometer
	_turn_facing = facing
	facing = new_facing


## Forgets the path walked, so followers line up straight behind the anchor.
func _reset_trail() -> void:
	_turn_facing = 0


## Puts the anchor at distance [param at] of the current depth's course, facing the way on.
func _place(at: float) -> void:
	_side.arrived(self)
	x = at
	facing = Arrival.facing(PartyPlaces.course(self), x)
	_reset_trail()
	_entered_key = _key_here()


## The chamber the anchor stands in, as Vector2i(depth, index); index -1 in a tunnel.
func _key_here() -> Vector2i:
	return Vector2i(depth, PartyPlaces.course(self).chamber_at(x))


# --- Climbing ------------------------------------------------------------------


func _start_climb(direction: int) -> void:
	state = State.CLIMBING
	_climb_direction = direction
	var rows: Vector2 = StageCrossing.rows(self, direction)
	_climb_from_y = rows.x
	_climb_y = rows.x
	_climb_to_y = rows.y


func _climb() -> void:
	# Hold set on the way up to a living guardian: back down to the level it left.
	if _climb_direction < 0 and guardian_order == GuardianOrder.HOLD and _guardian_alive(depth - 1):
		StageCrossing.turn_back(self)
	var speed: float = CLIMB_SPEED * _upgrade(UpgradeDef.Stat.TRAVEL_SPEED)
	var stride: float = speed / Simulation.TICKS_PER_SECOND
	if absf(_climb_to_y - _climb_y) > stride:
		_climb_y += _climb_direction * stride
		return
	_climb_y = _climb_to_y
	var landing: float = StageCrossing.landing(self)
	depth += _climb_direction
	state = State.TRAVELLING
	_place(landing)
	_restart_depth_count(_tick)
	_emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, depth)
	# Back up into a guardian's chamber: the guardian is met where the party lands.
	if _entered_key.y >= 0 and is_populated(depth, _entered_key.y):
		_start_battle(_labyrinth.level(depth).chambers[_entered_key.y])


# --- Encounters ----------------------------------------------------------------


## True if that chamber is on the map of the area the party is in.
func _exists(level_depth: int, chamber_index: int) -> bool:
	if level_depth < 1 or chamber_index < 0:
		return false
	return chamber_index < _labyrinth.level(level_depth).chambers.size()


## True if the guardian of that depth waits in its chamber (not beaten, not being fought).
func _guardian_alive(level_depth: int) -> bool:
	if level_depth < 1 or guardian_of(level_depth) == &"":
		return false
	var room: int = ChamberRules.way_on_room(_labyrinth.level(level_depth).course)
	return room >= 0 and is_populated(level_depth, room)


## The monsters of that visit, rolled once and kept until the party meets them.
func _rolled_for(level_depth: int, chamber_index: int, visit: int) -> Array:
	var key := Vector3i(level_depth, chamber_index, visit)
	if not _rolled.has(key):
		_rolled[key] = ChamberRules.monsters_of(
			_labyrinth, _here, _rng, level_depth, chamber_index, visit
		)
	return _rolled[key]


## The chamber's record, made or refilled if its time has come, with its monsters made.
## Called only when the party meets them, never by a read.
func _fill(level_depth: int, chamber_index: int) -> ChamberState:
	var fill: ChamberState = _record(level_depth, chamber_index)
	if fill.cleared_tick < 0 and fill.monsters.is_empty():
		fill.monsters.assign(_rolled_for(level_depth, chamber_index, fill.visit))
	# From here the record holds them; a later visit rolls its own.
	_rolled.erase(Vector3i(level_depth, chamber_index, fill.visit))
	return fill


## The chamber's record, made if there is none and moved on to its next visit if its time to
## refill has come. Called only by stepping, never by a read.
func _record(level_depth: int, chamber_index: int) -> ChamberState:
	var key := Vector2i(level_depth, chamber_index)
	var fill: ChamberState = _chambers.get(key, null)
	if fill == null:
		fill = ChamberState.new(level_depth)  # refills by the stage number
		fill.guardian = ChamberRules.is_guardians(_labyrinth, _here, level_depth, chamber_index)
		_chambers[key] = fill
	if fill.cleared_tick >= 0 and _tick >= fill.refill_tick():
		fill.visit += 1
		fill.cleared_tick = -1
		fill.monsters = []
		fill.missed = false
	return fill


## The quest that chamber holds on [param visit] (see [method ChamberRules.quest_on_visit]).
func _quest_on_visit(level_depth: int, chamber_index: int, visit: int) -> StringName:
	return ChamberRules.quest_on_visit(_labyrinth, _here, _rng, level_depth, chamber_index, visit)


func _start_battle(room: LabyrinthChamber) -> void:
	var fill: ChamberState = _fill(depth, room.index)
	var heroes: Array[Combatant] = []
	for hero: Hero in _party.heroes:
		heroes.append(hero.combatant())
	_battle_count += 1
	_battle_key = Vector2i(depth, room.index)
	battle = Battle.new(
		heroes,
		fill.monsters,
		room.floor_columns().x,
		room.floor_columns().y,
		PartyPlaces.world_facing(self) > 0,
		_rng.fork("battle/%d" % _battle_count)
	)
	state = State.FIGHTING
	_emit(SimEvent.Kind.ENCOUNTER_STARTED, -1, -1, room.index)


func _fight() -> void:
	# Bit i: the party's hero i stood as the tick began and has not been seen to fall in it.
	var standing: int = 0
	for i: int in _party.heroes.size():
		var fighter: Combatant = battle.combatant(_party.heroes[i].id)
		if fighter != null and fighter.is_alive():
			standing |= 1 << i
	battle.step()
	standing = _take_battle_events(standing)
	var overwhelmed: bool = battle.tick >= Combatant.seconds_to_ticks(BATTLE_LIMIT_SECONDS)
	if battle.result() == Battle.Result.MONSTERS_WON and standing != 0:
		overwhelmed = true
	if overwhelmed and battle.result() != Battle.Result.HEROES_WON:
		# Every status ends with its event before the heroes fall.
		battle.end()
		_take_battle_events(standing)
		_overwhelm()
		_end_battle(false)
	elif battle.result() != Battle.Result.ONGOING:
		_end_battle(battle.result() == Battle.Result.HEROES_WON)


## Every hero still standing falls: the fight ran too long, or was lost with heroes up.
func _overwhelm() -> void:
	for fighter: Combatant in battle.heroes:
		if fighter.is_alive():
			fighter.health = 0
			fighter.state = Combatant.State.DEAD
			fighter.target_id = -1
			_emit(SimEvent.Kind.DIED, fighter.id)


## Passes the battle's events on, stamped with this tick, and answers each death in its place
## among them: a hero's clears its bit of [param standing] (see [method _fight]), a monster's
## rewards the heroes still standing. Returns what is left standing.
func _take_battle_events(standing: int) -> int:
	for event: SimEvent in battle.drain_events():
		event.tick = _tick
		_events.append(event)
		if event.kind != SimEvent.Kind.DIED:
			continue
		var dead: Combatant = battle.combatant(event.source_id)
		if dead.team == Combatant.Team.HEROES:
			standing &= ~(1 << _rank_of(dead.id))
		else:
			_reward(dead, standing)
	return standing


## XP for every hero standing (by its bit of [param standing]) when [param dead] fell, and gold
## for the party.
func _reward(dead: Combatant, standing: int) -> void:
	var def: MonsterDef = Content.monster(dead.def_id)
	for i: int in _party.heroes.size():
		if (standing & (1 << i)) == 0:
			continue
		var hero: Hero = _party.heroes[i]
		if _give_xp(hero, def.xp) == 0:
			continue
		# The hero fights on with its new numbers, healed by the health it gained.
		var fighter: Combatant = battle.combatant(hero.id)
		var grown: Combatant = hero.combatant()
		fighter.health += grown.max_health - fighter.max_health
		fighter.max_health = grown.max_health
		fighter.damage = grown.damage
		fighter.level = hero.level
	var gold: int = _loot_rng.next_int(def.gold_min, def.gold_max)
	if _labyrinth.level(_battle_key.x).chambers[_battle_key.y].kind == LabyrinthChamber.Kind.VAULT:
		gold *= _VAULT_GOLD_FACTOR
	gold = roundi(gold * _upgrade(UpgradeDef.Stat.GOLD))
	_party.gold += gold
	_emit(SimEvent.Kind.GOLD_GAINED, dead.id, -1, gold)
	ResourceDrops.on_kill(self, dead, def)
	if def.guardian:
		_areas.guardians_beaten[_here.id] = true
		_emit(SimEvent.Kind.GUARDIAN_SLAIN, dead.id, -1, _battle_key.x)
		if _battle_key.x == _here.guardian_stage:
			for opened: StringName in _areas.open_after(_here.id):
				_emit(SimEvent.Kind.AREA_OPENED, -1, -1, Content.area_ids().find(opened))


## Gives [param hero] [param amount] XP, reporting it, each level it pays for and each
## microskill a level brings. Returns how many levels were gained.
func _give_xp(hero: Hero, amount: int) -> int:
	_emit(SimEvent.Kind.XP_GAINED, -1, hero.id, amount)
	var before: int = hero.level
	var gained: int = hero.gain_xp(amount)
	var def: HeroClassDef = hero.def()
	for new_level: int in range(before + 1, hero.level + 1):
		_emit(SimEvent.Kind.LEVEL_UP, -1, hero.id, new_level)
		if TalentRules.talent_points_at(new_level) > TalentRules.talent_points_at(new_level - 1):
			_emit(SimEvent.Kind.TALENT_POINT_GAINED, hero.id, -1, new_level)
		for i: int in mini(def.microskills.size(), def.microskill_levels.size()):
			if def.microskill_levels[i] == new_level:
				var skill: int = Content.microskill_ids().find(def.microskills[i])
				_emit(SimEvent.Kind.MICROSKILL_LEARNED, hero.id, skill, new_level)
	return gained


func _end_battle(won: bool) -> void:
	for hero: Hero in _party.heroes:
		var fighter: Combatant = battle.combatant(hero.id)
		hero.health = clampi(fighter.health, 0, hero.max_health()) if won else 0
	var fill: ChamberState = _chambers[_battle_key]
	_emit(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1, _battle_key.y, won)
	var level: LabyrinthLevel = _labyrinth.level(_battle_key.x)
	var room: LabyrinthChamber = level.chambers[_battle_key.y]
	var fought: Battle = battle
	battle = null
	_battle_key = Vector2i(0, -1)
	if won:
		fill.cleared_tick = _tick
		fill.monsters = []
		# The party gathers where its front hero stands.
		x = level.course.distance_in(room.index, fought.combatant(_party.heroes[0].id).x)
		_reset_trail()
		if PartyOrders.needs_rest(_party.heroes, pace):
			_start_rest()
		else:
			state = State.TRAVELLING
		return
	# Lost (every hero down): the surviving monsters stay, healed.
	var survivors: Array[Combatant] = []
	for monster: Combatant in fought.monsters:
		if monster.is_alive():
			monster.health = monster.max_health
			monster.state = Combatant.State.IDLE
			monster.target_id = -1
			survivors.append(monster)
	EncounterRoll.spread(survivors, room)
	fill.monsters = survivors
	_fallen.clear()
	for fighter: Combatant in fought.heroes:
		_fallen[fighter.id] = Vector2(fighter.x, room.floor_row())
	_wipe()


# --- Rest, wipe and revival ----------------------------------------------------


func _start_rest() -> void:
	state = State.RESTING
	_rest_ticks = 0
	_rest_start.clear()
	for hero: Hero in _party.heroes:
		_rest_start[hero.id] = hero.health
	_emit(SimEvent.Kind.REST_STARTED)


func _rest() -> void:
	_rest_ticks += 1
	if _heal_resting():
		_emit(SimEvent.Kind.REST_ENDED)
		state = State.TRAVELLING


## Heals every hero as [member _rest_ticks] of resting from [member _rest_start] does; true once all
## are full.
func _heal_resting() -> bool:
	var seconds: float = float(_rest_ticks) / Simulation.TICKS_PER_SECOND
	var all_full: bool = true
	var rate: float = REST_HEAL_PER_SECOND * _upgrade(UpgradeDef.Stat.REST_HEALING)
	for hero: Hero in _party.heroes:
		var full: int = hero.max_health()
		var healed: int = floori(rate * full * seconds + _EPSILON)
		var start: int = _rest_start.get(hero.id, hero.health)
		hero.health = mini(full, maxi(hero.health, start + healed))
		if hero.health < full:
			all_full = false
	return all_full


func _wipe() -> void:
	if state != State.REVIVING and _fallen.is_empty():
		for rank: int in _party.heroes.size():
			var id: int = _party.heroes[rank].id
			_fallen[id] = PartyPlaces.fallen(self, id, rank)
	for hero: Hero in _party.heroes:
		hero.health = 0
	state = State.REVIVING
	_revive_tick = _tick + Combatant.seconds_to_ticks(REVIVE_SECONDS)
	_emit(SimEvent.Kind.PARTY_WIPED)


func _revive() -> void:
	_fallen.clear()
	for hero: Hero in _party.heroes:
		hero.health = hero.max_health()
	var back_to: int = last_stable_depth
	_emit(SimEvent.Kind.PARTY_REVIVED, -1, -1, back_to)
	if depth != back_to:
		depth = back_to
		_emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, depth)
	_place(Arrival.column(_labyrinth, depth))
	_restart_depth_count(_tick)
	_set_target(back_to)
	# A target asked for while the party was down comes after the fallback, so it wins.
	if _pending_target > 0:
		_set_target(_pending_target)
		_pending_target = 0
	state = State.TRAVELLING


# --- Helpers -------------------------------------------------------------------


## True while the party is off the floor of a depth: climbing, down or on its way to another area.
func _is_away() -> bool:
	return state == State.CLIMBING or state == State.REVIVING or state == State.JOURNEYING


## The place of hero [param hero_id] in the party, or -1.
func _rank_of(hero_id: int) -> int:
	for i: int in _party.heroes.size():
		if _party.heroes[i].id == hero_id:
			return i
	return -1


## The party's upgrade multiplier for [param stat].
func _upgrade(stat: UpgradeDef.Stat) -> float:
	return _party.upgrades.multiplier(stat)


func _emit(
	kind: SimEvent.Kind, source: int = -1, target: int = -1, amount: int = 0, flag: bool = false
) -> void:
	_events.append(SimEvent.new(kind, _tick, source, target, amount, flag))

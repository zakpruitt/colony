class_name Expedition
extends RefCounted
## The party's journey through the labyrinth, one tick at a time: travel,
## climbing between levels, fights, rewards, rest, and falling back after a wipe.
##
## Positions are world tiles, x right and y down. A column [code]c[/code] is the
## position [code]x = c[/code]; a chamber's floor runs from its first open column
## ([code]rect.position.x[/code]) to its last ([code]rect.end.x - 1[/code]). Feet
## stand on the level's floor row ([member LabyrinthLevel.floor_y]).
##
## Every change worth showing is reported as a [SimEvent] stamped with the
## simulation tick; [method drain_events] hands them over once.

enum State { TRAVELLING, FIGHTING, RESTING, CLIMBING, REVIVING }

const PARTY_SPEED: float = 3.0  # tiles per second
const CLIMB_SPEED: float = 4.0  # tiles per second
const REST_BELOW: float = 0.6
const REST_HEAL_PER_SECOND: float = 0.04
const RESPAWN_SECONDS: float = 90.0
const REVIVE_SECONDS: float = 5.0
## A fight that lasts this long overwhelms the party (it is wiped).
const BATTLE_LIMIT_SECONDS: float = 90.0
const FIRST_MONSTER_ID: int = 100

## Tiles between heroes walking in column.
const HERO_SPACING: float = 1.0
## How many monsters wait in a chamber of each kind, both ends included.
const PLAIN_MONSTERS: Vector2i = Vector2i(2, 3)
const DEN_MONSTERS: Vector2i = Vector2i(4, 5)
const VAULT_MONSTERS: Vector2i = Vector2i(2, 3)
## Gold from a monster killed in a VAULT is multiplied by this.
const VAULT_GOLD_FACTOR: int = 2
## Slack for comparing positions reached by adding up float steps.
const EPSILON: float = 0.0001

var state: State = State.TRAVELLING
var depth: int = 1
## The party anchor: column on the floor, and which way it faces (1 right, -1 left).
var x: float
var facing: int = 1
var target_depth: int = 1
var auto_push: bool = true
var last_stable_depth: int = 1
var deepest_depth: int = 1
## Seconds on one depth without a wipe before it counts as stable. Tunable.
var stable_seconds: float = 600.0
## The fight in progress, or null.
var battle: Battle

var _labyrinth: Labyrinth
var _party: Party
var _rng: SimRng
var _loot_rng: SimRng
var _tick: int = 0
var _events: Array[SimEvent] = []

## Chambers that have been asked about or fought in, by Vector2i(depth, index).
var _chambers: Dictionary[Vector2i, ChamberState] = {}
var _next_monster_id: int = FIRST_MONSTER_ID
var _battle_count: int = 0
var _battle_key: Vector2i = Vector2i(0, -1)
## The chamber the anchor stood in after the last tick, as Vector2i(depth, index);
## index -1 in a tunnel.
var _entered_key: Vector2i = Vector2i(0, -1)
## A target depth asked for by a command, applied on the next tick; 0 when none.
var _pending_target: int = 0

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
## Where each hero fell in the last wipe.
var _fallen: Dictionary[int, float] = {}

## The tick from which the party has been on [member _timer_depth] without a wipe.
var _depth_since: int = 0
var _timer_depth: int = 1
## The tick [member _timer_target] became the target.
var _target_since: int = 0
var _timer_target: int = 1


## An expedition for [param party] standing in the middle of depth 1's START chamber.
## [param rng] is the expedition's own stream; encounters and battles fork from it.
func _init(labyrinth: Labyrinth, party: Party, rng: SimRng) -> void:
	_labyrinth = labyrinth
	_party = party
	_rng = rng
	_loot_rng = rng.fork("loot")
	var level: LabyrinthLevel = _labyrinth.level(1)
	var start: LabyrinthChamber = level.chambers[0]
	for room: LabyrinthChamber in level.chambers:
		if room.kind == LabyrinthChamber.Kind.START:
			start = room
	x = (start.rect.position.x + start.rect.end.x - 1) / 2.0
	facing = 1 if level.shaft_down.position.x >= x else -1
	_entered_key = Vector2i(1, start.index)


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
	if state != State.FIGHTING and state != State.REVIVING and not _party.any_alive():
		_wipe()
	_count_time()


## Asks for a new target depth (1 or more); it applies from the next tick.
func command_target_depth(new_depth: int) -> void:
	_pending_target = maxi(new_depth, 1)


## The events recorded since the last call, oldest first.
func drain_events() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


## The chamber the party is in or fighting in, or null in a tunnel or shaft.
func chamber() -> LabyrinthChamber:
	var level: LabyrinthLevel = _labyrinth.level(depth)
	match state:
		State.CLIMBING:
			return null
		State.FIGHTING:
			if _battle_key.x == depth and _battle_key.y >= 0:
				return level.chambers[_battle_key.y]
	return level.chamber_at(floori(x))


## Feet position of a hero in world tiles.
func hero_position(hero_id: int) -> Vector2:
	var rank: int = -1
	for i: int in _party.heroes.size():
		if _party.heroes[i].id == hero_id:
			rank = i
	if rank < 0:
		return Vector2.ZERO
	var floor_y: float = _labyrinth.level(depth).floor_y
	match state:
		State.FIGHTING:
			var fighter: Combatant = battle.combatant(hero_id) if battle != null else null
			if fighter != null:
				return Vector2(fighter.x, floor_y)
		State.CLIMBING:
			var lag: float = HERO_SPACING * rank * _climb_direction
			var y: float = _climb_y - lag
			if _climb_direction > 0:
				y = maxf(y, _climb_from_y)
			else:
				y = minf(y, _climb_from_y)
			return Vector2(x, y)
		State.REVIVING:
			if _fallen.has(hero_id):
				return Vector2(_fallen[hero_id], floor_y)
	return Vector2(_formation_x(rank), floor_y)


## True if this chamber currently holds monsters waiting for the party.
func is_populated(level_depth: int, chamber_index: int) -> bool:
	if level_depth < 1:
		return false
	var level: LabyrinthLevel = _labyrinth.level(level_depth)
	if chamber_index < 0 or chamber_index >= level.chambers.size():
		return false
	if _is_always_empty(level, chamber_index):
		return false
	var key := Vector2i(level_depth, chamber_index)
	if battle != null and _battle_key == key:
		return false
	var fill: ChamberState = _chambers.get(key, null)
	return fill == null or fill.cleared_tick < 0 or _tick >= _refill_tick(fill)


## The monsters waiting in this chamber (empty if it is not populated).
## Their y is the level's floor.
func monsters_in(level_depth: int, chamber_index: int) -> Array[Combatant]:
	if not is_populated(level_depth, chamber_index):
		return []
	var fill: ChamberState = _fill(level_depth, chamber_index)
	return fill.monsters.duplicate()


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
		_next_monster_id,
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
	]
	var keys: Array[Vector2i] = []
	keys.assign(_chambers.keys())
	keys.sort()
	for key: Vector2i in keys:
		var fill: ChamberState = _chambers[key]
		parts.append([key, fill.visit, fill.cleared_tick, _combatant_parts(fill.monsters)])
	if battle != null:
		parts.append(
			[battle.tick, battle.result(), _combatant_parts(battle.heroes + battle.monsters)]
		)
	return parts


# --- Commands and time ---------------------------------------------------------


func _apply_commands() -> void:
	# While the party is down a command waits, so it wins over the fallback target on revival.
	if _pending_target <= 0 or state == State.REVIVING:
		return
	var wanted: int = _pending_target
	_pending_target = 0
	_set_target(wanted)


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
	if state == State.CLIMBING or state == State.REVIVING:
		return
	# A depth or target set from outside counts from the tick before this one.
	if depth != _timer_depth:
		_restart_depth_count(_tick - 1)
	if target_depth != _timer_target:
		_timer_target = target_depth
		_target_since = _tick - 1
	var needed: int = roundi(stable_seconds * Simulation.TICKS_PER_SECOND)
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
	var goal: float
	if depth < target_depth:
		goal = _shaft_middle(depth)
	elif depth > target_depth:
		goal = _landing_column(depth)
	elif facing > 0:
		goal = level.chambers[level.chambers.size() - 1].rect.end.x - 1
	else:
		goal = level.chambers[0].rect.position.x
	_walk_toward(goal)

	var here: LabyrinthChamber = level.chamber_at(floori(x))
	var key := Vector2i(depth, here.index if here != null else -1)
	if key != _entered_key:
		_entered_key = key
		if here != null and is_populated(depth, here.index):
			_start_battle(here)
			return

	if absf(x - goal) > EPSILON:
		return
	if depth < target_depth:
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
	var speed: float = PARTY_SPEED * _upgrade(UpgradeDef.Stat.TRAVEL_SPEED)
	var stride: float = minf(speed / Simulation.TICKS_PER_SECOND, absf(goal - x))
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


## The column of the hero [param rank] places behind the anchor, retracing the anchor's last turn.
func _formation_x(rank: int) -> float:
	var lag: float = HERO_SPACING * rank
	var since_turn: float = _odometer - _turn_odometer
	var hero_x: float = x - facing * lag
	if _turn_facing != 0 and lag > since_turn:
		hero_x = _turn_x - _turn_facing * (lag - since_turn)
	var level: LabyrinthLevel = _labyrinth.level(depth)
	var first: float = level.chambers[0].rect.position.x
	var last: float = level.chambers[level.chambers.size() - 1].rect.end.x - 1
	return clampf(hero_x, first, last)


## Where the shaft from the level above lands on this depth: the middle of the shaft.
func _landing_column(level_depth: int) -> float:
	return _shaft_middle(level_depth - 1)


## The middle of the shaft down from [param level_depth], where a climber stands on the ladder.
func _shaft_middle(level_depth: int) -> float:
	return _labyrinth.shaft_column(level_depth) + Labyrinth.SHAFT_WIDTH / 2.0


## Where the party stands when it arrives on this depth without climbing:
## the middle of the START chamber at depth 1, otherwise where the shaft from above lands.
func _arrival_x(level_depth: int) -> float:
	if level_depth > 1:
		return _landing_column(level_depth)
	var level: LabyrinthLevel = _labyrinth.level(1)
	for room: LabyrinthChamber in level.chambers:
		if room.kind == LabyrinthChamber.Kind.START:
			return (room.rect.position.x + room.rect.end.x - 1) / 2.0
	return level.chambers[0].rect.position.x


## Puts the anchor at [param column] on the current depth, facing into the level.
func _place(column: float) -> void:
	x = column
	facing = 1 if x < Labyrinth.LEVEL_WIDTH / 2.0 else -1
	_reset_trail()
	var here: LabyrinthChamber = _labyrinth.level(depth).chamber_at(floori(x))
	_entered_key = Vector2i(depth, here.index if here != null else -1)


# --- Climbing ------------------------------------------------------------------


func _start_climb(direction: int) -> void:
	state = State.CLIMBING
	_climb_direction = direction
	_climb_from_y = _labyrinth.level(depth).floor_y
	_climb_y = _climb_from_y
	_climb_to_y = _labyrinth.level(depth + direction).floor_y


func _climb() -> void:
	var speed: float = CLIMB_SPEED * _upgrade(UpgradeDef.Stat.TRAVEL_SPEED)
	var stride: float = speed / Simulation.TICKS_PER_SECOND
	if absf(_climb_to_y - _climb_y) > stride:
		_climb_y += _climb_direction * stride
		return
	_climb_y = _climb_to_y
	depth += _climb_direction
	state = State.TRAVELLING
	_place(x)
	_restart_depth_count(_tick)
	_emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, depth)


# --- Encounters ----------------------------------------------------------------


func _is_always_empty(level: LabyrinthLevel, chamber_index: int) -> bool:
	if level.chambers[chamber_index].kind == LabyrinthChamber.Kind.START:
		return true
	var shaft: LabyrinthChamber = level.shaft_chamber()
	if shaft != null and shaft.index == chamber_index:
		return true
	if level.depth > 1:
		var landing: LabyrinthChamber = level.chamber_at(_labyrinth.shaft_column(level.depth - 1))
		if landing != null and landing.index == chamber_index:
			return true
	return false


func _refill_tick(fill: ChamberState) -> int:
	return fill.cleared_tick + Combatant.seconds_to_ticks(RESPAWN_SECONDS)


## The chamber's record, refilled if its time has come, with its monsters made.
func _fill(level_depth: int, chamber_index: int) -> ChamberState:
	var key := Vector2i(level_depth, chamber_index)
	var fill: ChamberState = _chambers.get(key, null)
	if fill == null:
		fill = ChamberState.new()
		_chambers[key] = fill
	if fill.cleared_tick >= 0 and _tick >= _refill_tick(fill):
		fill.visit += 1
		fill.cleared_tick = -1
		fill.monsters = []
	if fill.cleared_tick < 0 and fill.monsters.is_empty():
		fill.monsters = _roll_monsters(level_depth, chamber_index, fill.visit)
	return fill


## The monsters of one visit to a chamber. Which monsters depends only on the
## seed, depth, chamber and visit; their ids are the next unused ones.
func _roll_monsters(level_depth: int, chamber_index: int, visit: int) -> Array[Combatant]:
	var room: LabyrinthChamber = _labyrinth.level(level_depth).chambers[chamber_index]
	var rng: SimRng = _rng.fork("encounter/%d/%d/%d" % [level_depth, chamber_index, visit])
	var count_range: Vector2i = PLAIN_MONSTERS
	if room.kind == LabyrinthChamber.Kind.DEN:
		count_range = DEN_MONSTERS
	elif room.kind == LabyrinthChamber.Kind.VAULT:
		count_range = VAULT_MONSTERS
	var count: int = rng.next_int(count_range.x, count_range.y)

	# Eligible monsters, each as likely as its min_depth: deeper dwellers are favoured.
	var eligible: Array[MonsterDef] = []
	var total_weight: int = 0
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if def.min_depth <= level_depth:
			eligible.append(def)
			total_weight += def.min_depth
	var monsters: Array[Combatant] = []
	if eligible.is_empty():
		return monsters
	for i: int in count:
		var roll: int = rng.next_int(1, total_weight)
		var picked: MonsterDef = eligible[eligible.size() - 1]
		for def: MonsterDef in eligible:
			roll -= def.min_depth
			if roll <= 0:
				picked = def
				break
		monsters.append(Combatant.from_monster(picked, level_depth, _next_monster_id))
		_next_monster_id += 1
	_spread(monsters, room)
	return monsters


## Stands waiting monsters evenly over the middle half of the chamber's floor.
func _spread(monsters: Array[Combatant], room: LabyrinthChamber) -> void:
	var left: float = room.rect.position.x
	var right: float = room.rect.end.x - 1
	var quarter: float = (right - left) / 4.0
	for i: int in monsters.size():
		var share: float = (i + 0.5) / monsters.size()
		monsters[i].x = left + quarter + (right - left - 2.0 * quarter) * share


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
		room.rect.position.x,
		room.rect.end.x - 1,
		facing > 0,
		_rng.fork("battle/%d" % _battle_count)
	)
	state = State.FIGHTING
	_emit(SimEvent.Kind.ENCOUNTER_STARTED, -1, -1, room.index)


func _fight() -> void:
	var alive: Dictionary[int, bool] = {}
	for fighter: Combatant in battle.heroes:
		if fighter.is_alive():
			alive[fighter.id] = true
	battle.step()
	for event: SimEvent in battle.drain_events():
		event.tick = _tick
		_events.append(event)
		if event.kind != SimEvent.Kind.DIED:
			continue
		var dead: Combatant = battle.combatant(event.source_id)
		if dead.team == Combatant.Team.HEROES:
			alive.erase(dead.id)
		else:
			_reward(dead, alive)
	var overwhelmed: bool = battle.tick >= Combatant.seconds_to_ticks(BATTLE_LIMIT_SECONDS)
	if battle.result() == Battle.Result.MONSTERS_WON and not alive.is_empty():
		overwhelmed = true
	if overwhelmed and battle.result() != Battle.Result.HEROES_WON:
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


## XP for every hero alive when [param dead] fell, and gold for the party.
func _reward(dead: Combatant, alive: Dictionary[int, bool]) -> void:
	var def: MonsterDef = Content.monster(dead.def_id)
	for hero: Hero in _party.heroes:
		if not alive.has(hero.id):
			continue
		_emit(SimEvent.Kind.XP_GAINED, -1, hero.id, def.xp)
		var before: int = hero.level
		if hero.gain_xp(def.xp) == 0:
			continue
		for new_level: int in range(before + 1, hero.level + 1):
			_emit(SimEvent.Kind.LEVEL_UP, -1, hero.id, new_level)
		# The hero fights on with its new numbers, healed by the health it gained.
		var fighter: Combatant = battle.combatant(hero.id)
		var grown: Combatant = hero.combatant()
		fighter.health += grown.max_health - fighter.max_health
		fighter.max_health = grown.max_health
		fighter.damage = grown.damage
		fighter.level = hero.level
	var gold: int = _loot_rng.next_int(def.gold_min, def.gold_max)
	if _labyrinth.level(_battle_key.x).chambers[_battle_key.y].kind == LabyrinthChamber.Kind.VAULT:
		gold *= VAULT_GOLD_FACTOR
	gold = roundi(gold * _upgrade(UpgradeDef.Stat.GOLD))
	_party.gold += gold
	_emit(SimEvent.Kind.GOLD_GAINED, dead.id, -1, gold)


func _end_battle(won: bool) -> void:
	for hero: Hero in _party.heroes:
		var fighter: Combatant = battle.combatant(hero.id)
		hero.health = clampi(fighter.health, 0, hero.max_health()) if won else 0
	var fill: ChamberState = _chambers[_battle_key]
	_emit(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1, _battle_key.y, won)
	var room: LabyrinthChamber = _labyrinth.level(_battle_key.x).chambers[_battle_key.y]
	if won:
		fill.cleared_tick = _tick
		fill.monsters = []
		# The party gathers where its front hero stands.
		x = battle.combatant(_party.heroes[0].id).x
		_reset_trail()
		battle = null
		_battle_key = Vector2i(0, -1)
		if _needs_rest():
			_start_rest()
		else:
			state = State.TRAVELLING
		return
	# Lost (every hero down): the surviving monsters stay, healed.
	var survivors: Array[Combatant] = []
	for monster: Combatant in battle.monsters:
		if monster.is_alive():
			monster.health = monster.max_health
			monster.state = Combatant.State.IDLE
			monster.target_id = -1
			survivors.append(monster)
	_spread(survivors, room)
	fill.monsters = survivors
	_fallen.clear()
	for fighter: Combatant in battle.heroes:
		_fallen[fighter.id] = fighter.x
	battle = null
	_battle_key = Vector2i(0, -1)
	_wipe()


# --- Rest, wipe and revival ----------------------------------------------------


func _needs_rest() -> bool:
	for hero: Hero in _party.heroes:
		if not hero.is_alive() or hero.health < REST_BELOW * hero.max_health():
			return true
	return false


func _start_rest() -> void:
	state = State.RESTING
	_rest_ticks = 0
	_rest_start.clear()
	for hero: Hero in _party.heroes:
		_rest_start[hero.id] = hero.health
	_emit(SimEvent.Kind.REST_STARTED)


func _rest() -> void:
	_rest_ticks += 1
	var seconds: float = float(_rest_ticks) / Simulation.TICKS_PER_SECOND
	var all_full: bool = true
	var rate: float = REST_HEAL_PER_SECOND * _upgrade(UpgradeDef.Stat.REST_HEALING)
	for hero: Hero in _party.heroes:
		var full: int = hero.max_health()
		var healed: int = floori(rate * full * seconds + EPSILON)
		var start: int = _rest_start.get(hero.id, hero.health)
		hero.health = mini(full, maxi(hero.health, start + healed))
		if hero.health < full:
			all_full = false
	if all_full:
		_emit(SimEvent.Kind.REST_ENDED)
		state = State.TRAVELLING


func _wipe() -> void:
	if state != State.REVIVING and _fallen.is_empty():
		for hero: Hero in _party.heroes:
			_fallen[hero.id] = hero_position(hero.id).x
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
	_place(_arrival_x(depth))
	_restart_depth_count(_tick)
	_set_target(back_to)
	# A target asked for while the party was down comes after the fallback, so it wins.
	if _pending_target > 0:
		_set_target(_pending_target)
		_pending_target = 0
	state = State.TRAVELLING


## Stands a new expedition up from saved progress at simulation tick [param tick]:
## where revival puts the party (the arrival point of [param stable], its last
## stable depth), travelling, with no events. Called once, before the first step.
func arrive_from_save(tick: int, stable: int, deepest: int, target: int, push: bool) -> void:
	_tick = tick
	last_stable_depth = stable
	deepest_depth = maxi(deepest, stable)
	auto_push = push
	depth = stable
	_timer_depth = depth
	_place(_arrival_x(depth))
	_restart_depth_count(_tick)
	target_depth = maxi(target, 1)
	_timer_target = target_depth
	_target_since = _tick
	state = State.TRAVELLING


# --- Helpers -------------------------------------------------------------------


## The party's upgrade multiplier for [param stat].
func _upgrade(stat: UpgradeDef.Stat) -> float:
	return _party.upgrades.multiplier(stat)


func _emit(
	kind: SimEvent.Kind, source: int = -1, target: int = -1, amount: int = 0, flag: bool = false
) -> void:
	_events.append(SimEvent.new(kind, _tick, source, target, amount, flag))


func _combatant_parts(fighters: Array) -> Array:
	var parts: Array = []
	for c: Combatant in fighters:
		(
			parts
			. append(
				[
					c.id,
					c.def_id,
					c.x,
					c.health,
					c.max_health,
					c.damage,
					c.state,
					c.target_id,
					c.strike_tick,
					c.ready_tick,
				]
			)
		)
	return parts

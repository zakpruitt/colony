class_name Battle
extends RefCounted
## One fight on a chamber floor, played tick by tick.
##
## Each [method step] is one tick: projectiles due this tick land first, then
## every living combatant acts once, heroes first, each side in the order it
## was given. Everything that happens is recorded as a [SimEvent] stamped with
## the battle tick (the first step is tick 1).
##
## Two things happen without an event, and the view must not wait for one:
## [br]- When the battle ends, wind-ups still pending and projectiles still in
## flight are dropped.
## [br]- When a target dies, every wind-up aimed at it is cancelled at once.

enum Result { ONGOING, HEROES_WON, MONSTERS_WON }

const MAX_TICKS: int = 3000
const PROJECTILE_SPEED: float = 12.0  # tiles per second
const MELEE_REACH: float = 1.5  # strikes at or under this range land at once
const HEAL_THRESHOLD: float = 0.8
## A damage or heal roll is the base value times a number in this range.
const ROLL_MIN: float = 0.85
const ROLL_MAX: float = 1.15
## Slack for comparing positions that were reached by adding up float steps.
const EPSILON: float = 0.0001
const MIN_SPACING: float = 0.6  # tiles between two standing combatants of one side

var tick: int = 0
var heroes: Array[Combatant]
var monsters: Array[Combatant]

var _left: float
var _right: float
var _rng: SimRng
## 1.0 if the heroes face right (toward larger x), -1.0 if they face left.
var _hero_forward: float = 1.0
## Set by [method _station]: true if the place it found is short of the combatant's usual
## striking distance only because standing allies are in the way, so it may strike from there.
var _held_back: bool = false
var _result: Result = Result.ONGOING
var _by_id: Dictionary[int, Combatant] = {}
var _events: Array[SimEvent] = []
var _projectiles: Array[BattleProjectile] = []


## heroes_from_left: true if the heroes enter at `left` and face right.
func _init(
	heroes_in: Array[Combatant],
	monsters_in: Array[Combatant],
	left: float,
	right: float,
	heroes_from_left: bool,
	rng: SimRng
) -> void:
	heroes = heroes_in.duplicate()
	monsters = monsters_in.duplicate()
	_left = minf(left, right)
	_right = maxf(left, right)
	_rng = rng
	for c: Combatant in heroes + monsters:
		if _by_id.has(c.id):
			push_error("Battle: duplicate combatant id %d; the battle is over" % c.id)
			_result = Result.MONSTERS_WON
			return
		_by_id[c.id] = c
	for c: Combatant in heroes + monsters:
		c.target_id = -1
		c.strike_tick = -1
		c.ready_tick = 0
		c.state = Combatant.State.IDLE if c.health > 0 else Combatant.State.DEAD
	_line_up(heroes_from_left)
	_check_end()


## Advances the fight by one tick. Does nothing once the battle is over.
func step() -> void:
	if _result != Result.ONGOING:
		return
	tick += 1
	_land_projectiles()
	for c: Combatant in heroes + monsters:
		if c.is_alive():
			_act(c)
	_check_end()
	if _result == Result.ONGOING and tick >= MAX_TICKS:
		_result = Result.MONSTERS_WON


## Who has won, or ONGOING.
func result() -> Result:
	return _result


## The combatant with this id, or null.
func combatant(id: int) -> Combatant:
	return _by_id.get(id, null)


## The events recorded since the last call, oldest first.
func drain_events() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


func _line_up(heroes_from_left: bool) -> void:
	var toward_monsters: float = 1.0 if heroes_from_left else -1.0
	_hero_forward = toward_monsters
	var entry: float = _left if heroes_from_left else _right
	var far: float = _right if heroes_from_left else _left
	var middle: float = (_left + _right) / 2.0

	# Front of the formation first: TANK, MELEE, RANGED, HEALER, keeping the
	# given order within a role. sort_custom is not stable, so the index breaks ties.
	var order: Array[int] = []
	for i: int in heroes.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			if heroes[a].role != heroes[b].role:
				return heroes[a].role < heroes[b].role
			return a < b
	)
	var count: int = order.size()
	for rank: int in count:
		var hero: Combatant = heroes[order[rank]]
		hero.x = clampf(entry + toward_monsters * (count - 1 - rank), _left, _right)

	for i: int in monsters.size():
		var share: float = (i + 0.5) / monsters.size()
		monsters[i].x = clampf(middle + (far - middle) * share, _left, _right)


func _land_projectiles() -> void:
	var waiting: Array[BattleProjectile] = []
	for shot: BattleProjectile in _projectiles:
		if shot.land_tick > tick:
			waiting.append(shot)
			continue
		var target: Combatant = combatant(shot.target_id)
		if target != null and target.is_alive():
			_apply(shot.source, target, shot.is_heal)
	_projectiles = waiting


func _act(c: Combatant) -> void:
	if c.state == Combatant.State.WINDUP:
		var aimed: Combatant = combatant(c.target_id)
		if aimed != null and aimed.is_alive():
			if tick >= c.strike_tick:
				_strike(c, aimed)
			return
		# The target died during the wind-up: the strike is lost.
		c.state = Combatant.State.IDLE

	var target: Combatant = _pick_target(c)
	if target == null:
		c.state = Combatant.State.IDLE
		c.target_id = -1
		return
	c.target_id = target.id
	if not _strikes_from_here(c, target) and not _take_place(c, target):
		c.state = Combatant.State.MOVING
		return
	if tick < c.ready_tick:
		c.state = Combatant.State.IDLE
		return
	c.state = Combatant.State.WINDUP
	c.strike_tick = tick + c.windup_ticks
	_record(SimEvent.Kind.ATTACK_STARTED, c.id, target.id, c.windup_ticks)


func _pick_target(c: Combatant) -> Combatant:
	var allies: Array[Combatant] = heroes if c.team == Combatant.Team.HEROES else monsters
	var enemies: Array[Combatant] = monsters if c.team == Combatant.Team.HEROES else heroes
	if c.role == HeroClassDef.Role.HEALER:
		var hurt: Combatant = null
		var lowest: float = HEAL_THRESHOLD
		for ally: Combatant in allies:
			if ally.is_alive() and ally.health_fraction() < lowest:
				hurt = ally
				lowest = ally.health_fraction()
		if hurt != null:
			return hurt
	var nearest: Combatant = null
	var best: float = INF
	for enemy: Combatant in enemies:
		var distance: float = absf(enemy.x - c.x)
		if enemy.is_alive() and distance < best:
			nearest = enemy
			best = distance
	return nearest


## True if [param c], a melee fighter already in the fight and standing with room around it,
## can reach [param target] over the shoulders of its side: it strikes from where it stands
## rather than stepping into a gap, so standing room never costs it a blow.
func _strikes_from_here(c: Combatant, target: Combatant) -> bool:
	if c.attack_range > MELEE_REACH or c.state == Combatant.State.MOVING or c.ready_tick == 0:
		return false
	var allies: Array[Combatant] = heroes if c.team == Combatant.Team.HEROES else monsters
	var spacing: float = _spacing(allies)
	for ally: Combatant in allies:
		var standing: bool = ally != c and ally.is_alive() and ally.state != Combatant.State.MOVING
		if standing and absf(ally.x - c.x) < spacing - EPSILON:
			return false
	# The deepest a line of this side could ever hold it back, the fallen included.
	var reach: float = c.attack_range + MIN_SPACING * (allies.size() - 1)
	return absf(target.x - c.x) <= reach + EPSILON


## Walks [param c] toward its place against [param target] and returns true once it stands
## where it may strike from: in range, or held back there by standing allies.
func _take_place(c: Combatant, target: Combatant) -> bool:
	var forward: float = signf(target.x - c.x)
	if forward == 0.0:
		forward = _hero_forward if c.team == Combatant.Team.HEROES else -_hero_forward
	var in_range: bool = absf(target.x - c.x) <= c.attack_range + EPSILON
	var goal: float = c.x if in_range else target.x - forward * c.attack_range
	var station: float = _station(c, goal, forward)
	if absf(station - c.x) > EPSILON:
		_walk_to(c, station)
		if absf(station - c.x) > EPSILON:
			return false
	in_range = absf(target.x - c.x) <= c.attack_range + EPSILON
	return in_range or _held_back


## Where [param c] should stand this tick: [param goal], or behind it if allies are in the way.
##
## Positions are measured as progress [param forward] (toward the target). A standing ally
## within the spacing of the place pushes it back behind that ally; a hero never gets in front of
## a hero of a more forward role (then earlier in the party) attacking the same target. Sets
## [member _held_back]: true when standing allies alone kept [param c] short of [param goal].
func _station(c: Combatant, goal: float, forward: float) -> float:
	var allies: Array[Combatant] = heroes if c.team == Combatant.Team.HEROES else monsters
	var spacing: float = _spacing(allies)
	var place: float = goal * forward
	var bound_by_mover: bool = false
	var pushed: bool = true
	while pushed:
		pushed = false
		for ally: Combatant in allies:
			if ally == c or not ally.is_alive():
				continue
			var at: float = ally.x * forward
			var standing: bool = ally.state != Combatant.State.MOVING
			var blocks: bool = standing and absf(at - place) < spacing - EPSILON
			var leads: bool = _leads(ally, c) and at - spacing < place - EPSILON
			if blocks or leads:
				place = at - spacing
				bound_by_mover = not standing
				pushed = true
	var low: float = minf(_left * forward, _right * forward)
	var high: float = maxf(_left * forward, _right * forward)
	if place < low - EPSILON:
		# Against the back wall: take the first free place from the wall forward.
		place = low
		pushed = true
		while pushed:
			pushed = false
			for ally: Combatant in allies:
				if ally == c or not ally.is_alive() or ally.state == Combatant.State.MOVING:
					continue
				var at_wall: float = ally.x * forward
				if absf(at_wall - place) < spacing - EPSILON:
					place = at_wall + spacing
					pushed = true
	place = clampf(place, low, high)
	_held_back = place < goal * forward - EPSILON and not bound_by_mover
	return place * forward


## The spacing one side keeps: MIN_SPACING, or less if its living members cannot fit the span.
func _spacing(side: Array[Combatant]) -> float:
	var alive: int = 0
	for c: Combatant in side:
		if c.is_alive():
			alive += 1
	if alive > 1 and MIN_SPACING * (alive - 1) > _right - _left:
		return (_right - _left) / (alive - 1)
	return MIN_SPACING


## True if hero [param ally] stands in front of hero [param c]: both attack the same enemy
## and the ally's role is further forward (tank, melee, ranged, healer), or the same and earlier.
func _leads(ally: Combatant, c: Combatant) -> bool:
	if c.team != Combatant.Team.HEROES or ally.target_id != c.target_id:
		return false
	var target: Combatant = combatant(c.target_id)
	if target == null or target.team == c.team:
		return false
	if ally.role != c.role:
		return ally.role < c.role
	return heroes.find(ally) < heroes.find(c)


## Walks toward [param place] at the combatant's speed, stopping exactly on it.
func _walk_to(c: Combatant, place: float) -> void:
	var stride: float = c.move_speed / Simulation.TICKS_PER_SECOND
	if absf(place - c.x) <= stride:
		c.x = place
	else:
		c.x += signf(place - c.x) * stride
	c.x = clampf(c.x, _left, _right)


func _strike(c: Combatant, target: Combatant) -> void:
	c.state = Combatant.State.IDLE
	c.ready_tick = tick + c.attack_interval_ticks
	var is_heal: bool = c.team == target.team
	if not is_heal and c.attack_range <= MELEE_REACH:
		_apply(c, target, false)
		return
	var seconds: float = absf(target.x - c.x) / PROJECTILE_SPEED
	var flight: int = maxi(1, roundi(seconds * Simulation.TICKS_PER_SECOND))
	_projectiles.append(BattleProjectile.new(c, target.id, tick + flight, is_heal))
	_record(SimEvent.Kind.PROJECTILE_LAUNCHED, c.id, target.id, flight, is_heal)


func _apply(source: Combatant, target: Combatant, is_heal: bool) -> void:
	var roll: float = ROLL_MIN + _rng.next_float() * (ROLL_MAX - ROLL_MIN)
	if is_heal:
		var healed: int = mini(roundi(source.heal_power * roll), target.max_health - target.health)
		healed = maxi(healed, 0)
		target.health += healed
		_record(SimEvent.Kind.HEALED, source.id, target.id, healed)
		return
	var crit: bool = _rng.chance(source.crit_chance)
	var raw: float = source.damage * roll * (2.0 if crit else 1.0) - target.armor
	var dealt: int = maxi(1, roundi(raw))
	target.health = maxi(0, target.health - dealt)
	_record(SimEvent.Kind.HIT, source.id, target.id, dealt, crit)
	if target.health == 0:
		_die(target)


func _die(dead: Combatant) -> void:
	dead.state = Combatant.State.DEAD
	dead.target_id = -1
	_record(SimEvent.Kind.DIED, dead.id)
	# Nobody keeps aiming at the dead: a wind-up on them is lost at once.
	for c: Combatant in heroes + monsters:
		if c.is_alive() and c.target_id == dead.id:
			c.target_id = -1
			if c.state == Combatant.State.WINDUP:
				c.state = Combatant.State.IDLE


func _check_end() -> void:
	if not _any_alive(heroes):
		_result = Result.MONSTERS_WON
	elif not _any_alive(monsters):
		_result = Result.HEROES_WON


func _any_alive(side: Array[Combatant]) -> bool:
	for c: Combatant in side:
		if c.is_alive():
			return true
	return false


func _record(
	kind: SimEvent.Kind, source: int, target: int = -1, amount: int = 0, flag: bool = false
) -> void:
	_events.append(SimEvent.new(kind, tick, source, target, amount, flag))

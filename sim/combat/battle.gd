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
##
## Abilities follow [BattleAbilities] and statuses [BattleStatuses].

enum Result { ONGOING, HEROES_WON, MONSTERS_WON }
## What dealt some damage: an ordinary strike, an action, a passive or a status.
enum Via { STRIKE, ACTION, PASSIVE, STATUS }

const MAX_TICKS: int = 3000
const _PROJECTILE_SPEED: float = 12.0  # tiles per second
const MELEE_REACH: float = 1.5  # strikes at or under this range land at once
const _HEAL_THRESHOLD: float = 0.8
## A damage or heal roll is the base value times a number in this range.
const _ROLL_MIN: float = 0.85
const _ROLL_MAX: float = 1.15
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
## The heroes, then the monsters: the order everyone acts in. The sides never change after the
## battle is made.
var _fighters: Array[Combatant] = []


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
	_fighters = heroes + monsters
	for c: Combatant in _fighters:
		if _by_id.has(c.id):
			push_error("Battle: duplicate combatant id %d; the battle is over" % c.id)
			_result = Result.MONSTERS_WON
			return
		_by_id[c.id] = c
	for c: Combatant in _fighters:
		c.target_id = -1
		c.strike_tick = -1
		c.ready_tick = 0
		c.state = Combatant.State.IDLE if c.health > 0 else Combatant.State.DEAD
		c.reset_abilities()
	_line_up(heroes_from_left)
	_check_end()


## Advances the fight by one tick. Does nothing once the battle is over.
func step() -> void:
	if _result != Result.ONGOING:
		return
	tick += 1
	if tick == 1:
		BattleAbilities.fight_starts(self)
	BattleStatuses.pulse(self)
	_land_projectiles()
	for c: Combatant in _fighters:
		if c.is_alive():
			_act(c)
	_check_end()
	if _result == Result.ONGOING and tick >= MAX_TICKS:
		_result = Result.MONSTERS_WON
	if _result != Result.ONGOING:
		end()


## Ends every status in the fight, each with its STATUS_ENDED event. The battle does this as it
## ends; whatever stops a fight early (the expedition's time limit) calls it too.
func end() -> void:
	for c: Combatant in _fighters:
		BattleStatuses.clear(self, c)


## Who has won, or ONGOING.
func result() -> Result:
	return _result


## The combatant with this id, or null.
func combatant(id: int) -> Combatant:
	return _by_id.get(id, null)


## Everyone in the fight, the heroes then the monsters: the order they act in. The battle's own
## list, made once; read it, never change it.
func fighters() -> Array[Combatant]:
	return _fighters


## The events recorded since the last call, oldest first.
func drain_events() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


## Records an event stamped with this tick and returns it, for the combat rules.
func record(
	kind: SimEvent.Kind, source: int, target: int = -1, amount: int = 0, flag: bool = false
) -> SimEvent:
	var event := SimEvent.new(kind, tick, source, target, amount, flag)
	_events.append(event)
	return event


## True with [param probability], rolled on the battle's own stream.
func roll_chance(probability: float) -> bool:
	return _rng.chance(probability)


## [param c]'s side, [param c] included.
func allies_of(c: Combatant) -> Array[Combatant]:
	return heroes if c.team == Combatant.Team.HEROES else monsters


## The side [param c] fights.
func enemies_of(c: Combatant) -> Array[Combatant]:
	return monsters if c.team == Combatant.Team.HEROES else heroes


## True if nothing hostile [param source] does lands on [param target]: an enemy of it that is
## untouchable.
func untouchable(source: Combatant, target: Combatant) -> bool:
	if target.statuses.is_empty() or source.team == target.team:
		return false
	return target.has_status(AbilityEffect.Status.UNTOUCHABLE)


## The enemy [param c] strikes at: a taunting one it can reach, else the nearest it may aim at
## (see [method best_enemy]); or null.
func nearest_enemy(c: Combatant) -> Combatant:
	var taunter: Combatant = _taunter(c)
	if taunter != null:
		return taunter
	return best_enemy(c, AbilityDef.Aim.NEAREST_ENEMY)


## The living enemy [param c] may aim at that is nearest, weakest (the lowest share of health) or
## furthest, by [param aim], or null. It may aim at those that are not untouchable, or if every one
## of them is, at all of them; on a tie, at the first in its side's order. One pass, keeping the
## best of each kind, so the choice makes no list.
func best_enemy(c: Combatant, aim: AbilityDef.Aim) -> Combatant:
	var open: Combatant = null
	var open_score: float = 0.0
	var shut: Combatant = null
	var shut_score: float = 0.0
	for enemy: Combatant in enemies_of(c):
		if not enemy.is_alive():
			continue
		# Larger is better, and only a strictly better one replaces the first found.
		var score: float = absf(enemy.x - c.x)
		if aim == AbilityDef.Aim.NEAREST_ENEMY:
			score = -score
		elif aim == AbilityDef.Aim.WEAKEST_ENEMY:
			score = -enemy.health_fraction()
		if untouchable(c, enemy):
			if shut == null or score > shut_score:
				shut = enemy
				shut_score = score
		elif open == null or score > open_score:
			open = enemy
			open_score = score
	return open if open != null else shut


## The ally a healer [param c] would heal now: the living one with the lowest share of health,
## if it is below [constant _HEAL_THRESHOLD]; or null.
func hurt_ally(c: Combatant) -> Combatant:
	var hurt: Combatant = null
	var lowest: float = _HEAL_THRESHOLD
	for ally: Combatant in allies_of(c):
		if ally.is_alive() and ally.health_fraction() < lowest:
			hurt = ally
			lowest = ally.health_fraction()
	return hurt


## [param source] deals [param dealt] damage to [param target]: a shield absorbs what it can
## (a MISSED event, flagged), the rest is a HIT, and the passives it sets off answer.
## Returns the damage that got through. Nothing lands on the dead, or on the untouchable.
## [param chain] is how many passives deep the damage is (see [method BattleAbilities.fire]).
func deal(
	source: Combatant, target: Combatant, dealt: int, crit: bool, via: Via, chain: int = 0
) -> int:
	if not target.is_alive() or untouchable(source, target):
		return 0
	var shield: CombatStatus = target.status(AbilityEffect.Status.SHIELDED)
	if shield != null and roundi(shield.amount) > 0:
		var absorbed: int = mini(dealt, roundi(shield.amount))
		shield.amount -= absorbed
		dealt -= absorbed
		record(SimEvent.Kind.MISSED, source.id, target.id, absorbed, true)
		if shield.amount < 0.5:
			BattleStatuses.end(self, target, AbilityEffect.Status.SHIELDED)
		if dealt <= 0:
			return 0
	var before: float = target.health_fraction()
	target.health = maxi(0, target.health - dealt)
	record(SimEvent.Kind.HIT, source.id, target.id, dealt, crit)
	if target.health == 0:
		_die(target)
	BattleAbilities.after_damage(self, source, target, before, crit, via, chain)
	return dealt


## [param source] heals [param target] by up to [param amount], never past its maximum; the
## dead are not healed.
func heal(source: Combatant, target: Combatant, amount: int) -> void:
	if not target.is_alive():
		return
	var healed: int = maxi(mini(amount, target.max_health - target.health), 0)
	target.health += healed
	record(SimEvent.Kind.HEALED, source.id, target.id, healed)


## Moves [param target] [param tiles] away from [param source], inside the room.
func push(source: Combatant, target: Combatant, tiles: float) -> void:
	var away: float = signf(target.x - source.x)
	if away == 0.0:
		away = _hero_forward if source.team == Combatant.Team.HEROES else -_hero_forward
	target.x = clampf(target.x + away * tiles, _left, _right)


## [param source] stands the fallen [param target] up with [param share] of its health.
func revive(source: Combatant, target: Combatant, share: float) -> void:
	if target.is_alive():
		return
	target.health = clampi(roundi(target.max_health * share), 1, target.max_health)
	target.state = Combatant.State.IDLE
	target.target_id = -1
	target.strike_tick = -1
	target.ready_tick = tick
	target.pending_action = null
	record(SimEvent.Kind.REVIVED, source.id, target.id, target.health)


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


## Lands every projectile due this tick, in the order they were launched, and keeps the rest in
## that order.
func _land_projectiles() -> void:
	var count: int = _projectiles.size()
	var kept: int = 0
	for i: int in count:
		var shot: BattleProjectile = _projectiles[i]
		if shot.land_tick > tick:
			_projectiles[kept] = shot
			kept += 1
			continue
		var target: Combatant = combatant(shot.target_id)
		if target != null and target.is_alive():
			_apply(shot.source, target, shot.is_heal)
	# Nothing launches while projectiles land, so the list still holds only those counted.
	_projectiles.resize(kept)


func _act(c: Combatant) -> void:
	if c.has_status(AbilityEffect.Status.STUNNED):
		# A stunned fighter does nothing, and loses the wind-up it was in.
		c.state = Combatant.State.IDLE
		c.pending_action = null
		return
	if c.state == Combatant.State.WINDUP:
		var aimed: Combatant = combatant(c.target_id)
		if aimed != null and aimed.is_alive():
			if tick >= c.strike_tick:
				if c.pending_action != null:
					_use(c, aimed)
				else:
					_strike(c, aimed)
			return
		# The target died during the wind-up: the strike is lost.
		c.state = Combatant.State.IDLE
		c.pending_action = null

	# Asked once a tick: a healer with an ally to heal uses no action aimed at an enemy, and
	# strikes at that ally.
	var hurt: Combatant = hurt_ally(c) if c.role == HeroClassDef.Role.HEALER else null
	if not c.abilities.is_empty() and _try_action(c, hurt != null):
		return
	var target: Combatant = hurt if hurt != null else nearest_enemy(c)
	if target == null:
		c.state = Combatant.State.IDLE
		c.target_id = -1
		return
	c.target_id = target.id
	if not _strikes_from_here(c, target, c.attack_range):
		if not _take_place(c, target, c.attack_range):
			c.state = Combatant.State.MOVING
			return
	if tick < c.ready_tick:
		c.state = Combatant.State.IDLE
		return
	c.state = Combatant.State.WINDUP
	c.pending_action = null
	c.strike_tick = tick + c.windup_ticks
	record(SimEvent.Kind.ATTACK_STARTED, c.id, target.id, c.windup_ticks)


## Starts, or walks toward, the first action [param c] is ready to use (none aimed at an enemy
## when [param heal_first]). False if it has none ready, and then it strikes as usual.
func _try_action(c: Combatant, heal_first: bool) -> bool:
	var action: AbilityDef = null
	var target: Combatant = null
	for ability: AbilityDef in c.abilities:
		target = BattleAbilities.ready_target(self, c, ability, heal_first)
		if target != null:
			action = ability
			break
	if action == null:
		c.chasing = &""
		return false
	c.target_id = target.id
	# It keeps to this target until the action starts, so a choice that changes as it walks
	# (the furthest enemy, say) does not turn it back and forth.
	c.chasing = action.id
	if not action.anywhere and action.aim != AbilityDef.Aim.SELF:
		if not _strikes_from_here(c, target, action.reach):
			if not _take_place(c, target, action.reach):
				c.state = Combatant.State.MOVING
				return true
	if tick < c.ready_tick:
		c.state = Combatant.State.IDLE
		return true
	c.chasing = &""
	c.state = Combatant.State.WINDUP
	c.pending_action = action
	var windup: int = Combatant.seconds_to_ticks(action.windup)
	c.strike_tick = tick + windup
	record(SimEvent.Kind.ABILITY_STARTED, c.id, target.id, windup).ability_id = action.id
	return true


## The action [param c] wound up lands on [param target]; it is ready again after its cooldown.
func _use(c: Combatant, target: Combatant) -> void:
	var action: AbilityDef = c.pending_action
	c.pending_action = null
	c.state = Combatant.State.IDLE
	c.ready_tick = tick + c.strike_interval_ticks()
	c.action_ready_tick[action.id] = tick + Combatant.seconds_to_ticks(action.cooldown, 0)
	BattleAbilities.use(self, c, action, target)


## The nearest living enemy with a taunt that [param c] can reach (as [method _strikes_from_here]
## counts its reach), or null.
func _taunter(c: Combatant) -> Combatant:
	var found: Combatant = null
	var best: float = INF
	var reach: float = c.attack_range + MIN_SPACING * (allies_of(c).size() - 1) + EPSILON
	for enemy: Combatant in enemies_of(c):
		if not enemy.is_alive() or not enemy.has_status(AbilityEffect.Status.TAUNTING):
			continue
		var distance: float = absf(enemy.x - c.x)
		if distance <= reach and distance < best:
			found = enemy
			best = distance
	return found


## True if [param c], a melee fighter already in the fight and standing with room around it,
## can reach [param target] (within [param reach]) over the shoulders of its side: it strikes
## from where it stands rather than stepping into a gap, so standing room never costs it a blow.
func _strikes_from_here(c: Combatant, target: Combatant, reach: float) -> bool:
	if reach > MELEE_REACH or c.state == Combatant.State.MOVING or c.ready_tick == 0:
		return false
	var allies: Array[Combatant] = allies_of(c)
	var spacing: float = _spacing(allies)
	for ally: Combatant in allies:
		var standing: bool = ally != c and ally.is_alive() and ally.state != Combatant.State.MOVING
		if standing and absf(ally.x - c.x) < spacing - EPSILON:
			return false
	# The deepest a line of this side could ever hold it back, the fallen included.
	var deepest: float = reach + MIN_SPACING * (allies.size() - 1)
	return absf(target.x - c.x) <= deepest + EPSILON


## Walks [param c] toward its place within [param reach] of [param target] and returns true
## once it stands where it may strike from: in range, or held back there by standing allies.
func _take_place(c: Combatant, target: Combatant, reach: float) -> bool:
	var forward: float = signf(target.x - c.x)
	if forward == 0.0:
		forward = _hero_forward if c.team == Combatant.Team.HEROES else -_hero_forward
	var in_range: bool = absf(target.x - c.x) <= reach + EPSILON
	var goal: float = c.x if in_range else target.x - forward * reach
	var station: float = _station(c, goal, forward)
	if absf(station - c.x) > EPSILON:
		_walk_to(c, station)
		if absf(station - c.x) > EPSILON:
			return false
	in_range = absf(target.x - c.x) <= reach + EPSILON
	return in_range or _held_back


## Where [param c] should stand this tick: [param goal], or behind it if allies are in the way.
##
## Positions are measured as progress [param forward] (toward the target). A standing ally
## within the spacing of the place pushes it back behind that ally; a hero never gets in front of
## a hero of a more forward role (then earlier in the party) attacking the same target. Sets
## [member _held_back]: true when standing allies alone kept [param c] short of [param goal].
func _station(c: Combatant, goal: float, forward: float) -> float:
	var allies: Array[Combatant] = allies_of(c)
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
	c.ready_tick = tick + c.strike_interval_ticks()
	var is_heal: bool = c.team == target.team
	if not is_heal and c.attack_range <= MELEE_REACH:
		_apply(c, target, false)
		return
	var flight: int = Combatant.seconds_to_ticks(absf(target.x - c.x) / _PROJECTILE_SPEED)
	_projectiles.append(BattleProjectile.new(c, target.id, tick + flight, is_heal))
	record(SimEvent.Kind.PROJECTILE_LAUNCHED, c.id, target.id, flight, is_heal)


func _apply(source: Combatant, target: Combatant, is_heal: bool) -> void:
	if not is_heal:
		source.strikes += 1
		# A strike that does not land (on the untouchable, or dodged) sets nothing off.
		var dodge: CombatStatus = target.status(AbilityEffect.Status.NIMBLE)
		if untouchable(source, target) or (dodge != null and _rng.chance(dodge.amount)):
			record(SimEvent.Kind.MISSED, source.id, target.id)
			return
	var roll: float = _ROLL_MIN + _rng.next_float() * (_ROLL_MAX - _ROLL_MIN)
	if is_heal:
		heal(source, target, roundi(source.heal_power * roll))
		return
	var crit: bool = _rng.chance(source.crit_chance)
	# Passives that multiply this strike, rather than add a hit of their own.
	var boosts: Array[AbilityDef] = BattleAbilities.strike_boosts(self, source, target)
	var boost: float = 1.0
	var steal: float = 0.0
	for ability: AbilityDef in boosts:
		record(SimEvent.Kind.ABILITY_USED, source.id, target.id).ability_id = ability.id
		for effect: AbilityEffect in ability.effects:
			if effect.on_strike:
				boost *= effect.multiplier
				steal += effect.life_steal
	var raw: float = source.damage * roll * (2.0 if crit else 1.0) * source.dealt_multiplier()
	raw = (raw * boost - target.armor) * target.taken_multiplier()
	var dealt: int = deal(source, target, maxi(1, roundi(raw)), crit, Via.STRIKE)
	if steal > 0.0 and dealt > 0 and source.is_alive():
		heal(source, source, roundi(dealt * steal))
	for ability: AbilityDef in boosts:
		BattleAbilities.use(self, source, ability, target, false)
	BattleAbilities.fire(self, source, AbilityDef.Trigger.EVERY_NTH_STRIKE, target)


func _die(dead: Combatant) -> void:
	dead.state = Combatant.State.DEAD
	dead.target_id = -1
	dead.pending_action = null
	record(SimEvent.Kind.DIED, dead.id)
	BattleStatuses.clear(self, dead)
	# Nobody keeps aiming at the dead: a wind-up on them is lost at once.
	for c: Combatant in _fighters:
		if c.is_alive() and c.target_id == dead.id:
			c.target_id = -1
			if c.state == Combatant.State.WINDUP:
				c.state = Combatant.State.IDLE
				c.pending_action = null


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

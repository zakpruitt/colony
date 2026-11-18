class_name FightMoves
extends RefCounted
## Starts and ends the heroes' moves from the simulation's events (spec 057). The [World] hands it
## every event as it acts it out, before anything else hears it.
##
## - An action's move starts on its ABILITY_STARTED, its blow timed to fall when the wind-up ends,
##   so it lands on screen on the tick the simulation lands it ([member AbilityDef.move]). A
##   passive's move plays over what the hero is doing when it fires.
## - A hero hops on a crit and on a kill; when a fight is won each living hero cheers, one after
##   another.
## - A stun, a death, the end of a fight, a wipe and a change of stage or area end moves at once.
## - Only fresh events start anything: none in a frame that catches up on a stall, none for an
##   action whose blow has already fallen.
##
## A move is view only: it never moves a sprite's place (its [member Node2D.position]), only the
## body inside it, so a sprite is where the simulation has it whenever its move ends.

## Seconds before the first hero's cheer, and between one hero's cheer and the next.
const CHEER_FIRST: float = 0.05
const CHEER_STAGGER: float = 0.12
## Pixels kept clear between a leaping or dashing body and its target's.
const GAP: float = 2.0

## Per hero: the action whose move is playing, and whom it is aimed at, until its blow falls.
var _started: Dictionary[int, StringName] = {}
var _aims: Dictionary[int, int] = {}
## Per monster: the hero that struck it last, who hops if it dies.
var _striker: Dictionary[int, int] = {}


## Acts on [param event] in [param world]; [param fresh] is false for an event too old (or in a
## frame catching up on a stall) to start a move.
func heard(world: World, event: SimEvent, fresh: bool) -> void:
	match event.kind:
		SimEvent.Kind.ABILITY_STARTED:
			_started_action(world, event, fresh)
		SimEvent.Kind.ABILITY_USED:
			_used(world, event, fresh)
		SimEvent.Kind.HIT:
			if _is_hero(event.source_id):
				_striker[event.target_id] = event.source_id
				if event.flag and fresh:
					_play(world, event.source_id, CharacterMoves.HOP, 0.0)
		SimEvent.Kind.DIED:
			_died(world, event.source_id, fresh)
		SimEvent.Kind.STATUS_BEGAN:
			if event.status == AbilityEffect.Status.STUNNED:
				_end(world, event.target_id)
		SimEvent.Kind.ENCOUNTER_ENDED:
			stop_all(world)
			if event.flag and fresh:
				_cheer(world)
		SimEvent.Kind.PARTY_WIPED, SimEvent.Kind.AREA_CHANGED, SimEvent.Kind.DEPTH_CHANGED:
			stop_all(world)


## Ends every character's moves at once and forgets the fight.
func stop_all(world: World) -> void:
	for id: int in world._sprites:
		world._sprites[id].play_move(&"", 0.0)
	_started.clear()
	_aims.clear()
	_striker.clear()


func _started_action(world: World, event: SimEvent, fresh: bool) -> void:
	var ability: AbilityDef = Content.ability(event.ability_id)
	var sprite: CharacterSprite = world.character(event.source_id)
	if ability == null or sprite == null or not fresh:
		return
	var speed: int = maxi(world.speed, 1)
	var age: int = world.simulation.tick - event.tick
	var lead: float = float(event.amount - age) / Simulation.TICKS_PER_SECOND / speed
	if lead <= 0.0:
		return  # its blow has fallen already: the move would be for an event past
	var room: float = _room(sprite, world.character(event.target_id), ability)
	sprite.play_move(ability.move, lead, room, speed)
	_started[event.source_id] = ability.id
	_aims[event.source_id] = event.target_id


func _used(world: World, event: SimEvent, fresh: bool) -> void:
	var ability: AbilityDef = Content.ability(event.ability_id)
	if ability == null:
		return
	if _started.get(event.source_id, &"") == ability.id:
		_started.erase(event.source_id)  # its move is playing: its blow falls now
		_aims.erase(event.source_id)
		var sprite: CharacterSprite = world.character(event.source_id)
		if sprite != null:
			sprite.moves.land()
		return
	# An action whose start was too old to move for: its blow has fallen, its move would come after.
	if fresh and not ability.is_action():
		_play(world, event.source_id, ability.move, 0.0)


func _died(world: World, id: int, fresh: bool) -> void:
	_end(world, id)
	for attacker: int in _aims.keys():
		if _aims[attacker] == id:
			_end(world, attacker)  # the simulation drops a wind-up whose target died
	var killer: int = _striker.get(id, -1)
	_striker.erase(id)
	if fresh and killer >= 0:
		_play(world, killer, CharacterMoves.HOP, 0.0)


## Every living hero cheers, the front one first, each a moment after the one before.
func _cheer(world: World) -> void:
	var turn: int = 0
	for hero: Hero in world.simulation.party.heroes:
		var sprite: CharacterSprite = world.character(hero.id)
		if sprite == null or sprite.is_dead() or not sprite.visible or not hero.is_alive():
			continue
		var speed: float = maxf(world.speed, 1)
		sprite.play_move(CharacterMoves.CHEER, (CHEER_FIRST + turn * CHEER_STAGGER) / speed)
		turn += 1


func _play(world: World, id: int, move: StringName, lead: float) -> void:
	var sprite: CharacterSprite = world.character(id)
	if sprite != null and not sprite.is_dead() and not String(move).is_empty():
		sprite.play_move(move, lead, 0.0, maxi(world.speed, 1))


func _end(world: World, id: int) -> void:
	var sprite: CharacterSprite = world.character(id)
	if sprite != null:
		sprite.play_move(&"", 0.0)
	_started.erase(id)
	_aims.erase(id)


## How far [param sprite] may go toward [param target] before its pixels, through a strike's
## poses, would reach the target's: nothing for an ability aimed at its own side.
static func _room(sprite: CharacterSprite, target: CharacterSprite, ability: AbilityDef) -> float:
	if target == null or target == sprite or ability.aims_at_ally():
		return 0.0
	var apart: float = absf(target.position.x - sprite.position.x)
	return maxf(apart - SpriteBounds.reach(target) - SpriteBounds.reach(sprite) - GAP, 0.0)


static func _is_hero(id: int) -> bool:
	return id >= 0 and id < Expedition.FIRST_MONSTER_ID

class_name GuardianSpacing
extends RefCounted
## Keeps the heroes out of a guardian's body (spec 038 R3). The simulation measures a fight to
## each fighter's middle, so a melee hero in reach of a 64-pixel guardian would be drawn inside
## it. While a guardian fights, the world asks this where its heroes may stand: on their side of
## the guardian, no nearer than its body's edge, and each no nearer than [constant ROOM] to the
## hero in front of it on that side. Only the heroes' sprites move; the guardian, the monsters and
## everything aimed at the guardian stay where they were.

## Pixels kept clear between a hero's body and the guardian's.
const GAP: float = 2.0
## The least room between two heroes pushed back on one side, in pixels: the fight's own spacing.
const ROOM: float = Battle.MIN_SPACING * LabyrinthView.TILE

## This frame's limits: per hero id, the side it stands on (-1 left, 1 right) and the furthest
## toward the guardian its feet may be, in world pixels.
var _side: Dictionary[int, int] = {}
var _edge: Dictionary[int, float] = {}


## The living guardian in [param simulation]'s fight, or null when none fights.
static func fighting_guardian(simulation: Simulation) -> Combatant:
	var battle: Battle = simulation.expedition.battle
	if battle == null or simulation.expedition.state != Expedition.State.FIGHTING:
		return null
	for monster: Combatant in battle.monsters:
		var def: MonsterDef = Content.monster(monster.def_id)
		if def != null and def.guardian and monster.is_alive():
			return monster
	return null


## Moves the goals of [param world]'s heroes in [param goals] (world pixels, by id) out of the
## fighting guardian's body; does nothing when no guardian fights.
func space(world: World, goals: Dictionary[int, Vector2]) -> void:
	_side.clear()
	_edge.clear()
	var guardian: Combatant = fighting_guardian(world.simulation)
	var body_sprite: CharacterSprite = world.character(guardian.id) if guardian != null else null
	if body_sprite == null:
		return
	var body: Rect2 = SpriteBounds.body_rect(body_sprite)
	var middle: float = body.get_center().x
	var behind: int = -world.simulation.expedition.facing
	var sides: Dictionary[int, Array] = {-1: [], 1: []}
	for hero: Hero in world.simulation.party.heroes:
		if world.character(hero.id) == null or not goals.has(hero.id):
			continue
		var offset: float = goals[hero.id].x - middle
		var side: int = behind if is_zero_approx(offset) else (1 if offset > 0.0 else -1)
		_side[hero.id] = side
		sides[side].append(hero.id)
	for side: int in sides:
		var ids: Array = sides[side]
		ids.sort_custom(
			func(a: int, b: int) -> bool:
				return absf(goals[a].x - middle) < absf(goals[b].x - middle)
		)
		var face: float = body.position.x - GAP if side < 0 else body.end.x + GAP
		var front: float = INF
		for id: int in ids:
			var reach: float = SpriteBounds.half_width(world.character(id))
			_edge[id] = face + side * reach
			# Measured as distance out from the guardian on this side: larger is further away.
			var out: float = (goals[id].x - middle) * side
			out = maxf(out, (_edge[id] - middle) * side)
			if front < INF:
				out = maxf(out, front + ROOM)
			front = out
			goals[id] = Vector2(middle + out * side, goals[id].y)


## Puts back any hero sprite of [param world] that has eased into the guardian's body this frame
## (after [method space]).
func hold_back(world: World) -> void:
	for id: int in _edge:
		var sprite: CharacterSprite = world.character(id)
		if sprite == null:
			continue
		var side: int = _side[id]
		if (sprite.position.x - _edge[id]) * side < 0.0:
			sprite.position.x = _edge[id]

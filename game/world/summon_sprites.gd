class_name SummonSprites
extends Node
## The summons on screen: a sprite for each summon standing in the fight, made, moved and removed
## through the [World], which acts out its fighting as any fighter's.
##
## - A summon heard coming as it happens ([method World.may_animate]) appears at its place with a
##   puff. One heard late, or seen in a battle with no word of its coming (after a stall), appears
##   with no puff if it still stands, and not at all once it has ended.
## - Its place is the simulation's, on the fight's floor, each frame ([method goal_of]); the world
##   eases it there and has it walk as a monster's sprite does.
## - Its end, for whatever reason, is no death: the sprite fades over [constant FADE_SECONDS]
##   with a puff and goes. One heard late goes at once.
##
## It also knows, for every view, whose a summon is and what it is called
## ([method owner_of], [method name_of]). The world makes it and advances it each sync.

## Seconds a summon's sprite takes to fade when it ends.
const FADE_SECONDS: float = 0.3
## The pool's budget its puffs are counted in, and the puff's kind, colour, size and life.
const BUDGET: StringName = &"combat"
const PUFF_KIND: StringName = &"summon_puff"
const PUFF_COLOUR: StringName = &"silver"
const PUFF_SIZE: int = 10
const PUFF_LIFE: float = CombatEffects.PUFF_LIFE
## How many pixels above its feet a puff starts: the middle of a small creature, as a summon is.
const PUFF_LIFT: float = 6.0

## How many summon sprites it has made, and how many of its puffs the pool refused.
var made: int = 0
var refused: int = 0

var _world: World
## Per summon shown: its fighter (the battle's own, never changed here), its summoner's id, its
## name, and where it stands.
var _fighters: Dictionary[int, Combatant] = {}
var _owners: Dictionary[int, int] = {}
var _names: Dictionary[int, String] = {}
var _places: Dictionary[int, Vector2] = {}
## Per summon id: the name its latest SUMMONED gave, for a sprite made after it.
var _called: Dictionary[int, String] = {}
## Per summon fading: seconds into its fade.
var _fading: Dictionary[int, float] = {}


## True for an id summons take ([constant Battle.FIRST_SUMMON_ID] to
## [constant Battle.LAST_SUMMON_ID]): never a hero's or a monster's.
static func is_summon_id(id: int) -> bool:
	return id >= Battle.FIRST_SUMMON_ID and id <= Battle.LAST_SUMMON_ID


## Call once, before the world syncs: it hears [param world]'s events from then on.
func setup(world: World) -> void:
	_world = world
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)


## True for a summon whose sprite it holds, fading or not.
func has(id: int) -> bool:
	return _fighters.has(id)


## The id of the hero that summoned fighter [param id], or -1 for a fighter that is no summon.
func owner_of(id: int) -> int:
	if _owners.has(id):
		return _owners[id]
	var fighter: Combatant = _in_battle(id)
	return fighter.owner_id if fighter != null else -1


## The name of summon [param id] ([member SummonDef.display_name]), or "" for no summon.
func name_of(id: int) -> String:
	if _names.has(id):
		return _names[id]
	var fighter: Combatant = _in_battle(id)
	return _name_for(id, fighter) if fighter != null else ""


## The class bar colour of summon [param id]'s summoner (its damage numbers' and its names'), or
## [code]&""[/code] for a fighter that is no summon.
func colour_of(id: int) -> StringName:
	var summoner: Hero = _world.simulation.party.hero(owner_of(id)) if owner_of(id) >= 0 else null
	if summoner == null:
		return &""
	var colours: Array = TallyWindow.CLASS_BARS.get(summoner.class_id, TallyWindow.OTHER_BAR)
	return colours[0]


## Where summon [param id]'s sprite is heading: the simulation's place while it stands, else
## where it stood last.
func goal_of(id: int) -> Vector2:
	var fighter: Combatant = _fighters[id]
	if not _fading.has(id) and _in_battle(id) == fighter:
		_places[id] = Vector2(fighter.x * World.TILE, _places[id].y)
	return _places[id]


## The name of the summon [param def_id] as its [SummonDef] has it, from any ability in
## [Content] that summons it; the id made readable if none does. For a view that has only the
## fighter: it searches the abilities, so it is not for a loop.
static func def_name(def_id: StringName) -> String:
	for ability_id: StringName in Content.ability_ids():
		for effect: AbilityEffect in Content.ability(ability_id).effects:
			if effect.summon != null and effect.summon.id == def_id:
				return effect.summon.display_name
	return String(def_id).capitalize()


## Gives a sprite to every summon standing with none, and moves the fades on by [param delta]
## real seconds, removing each that has faded. The world calls it each sync, after the events.
func advance(delta: float) -> void:
	var battle: Battle = _world.simulation.expedition.battle
	if battle != null:
		for fighter: Combatant in battle.summons:
			if _fighters.get(fighter.id, null) != fighter and _world.character(fighter.id) == null:
				_show(fighter, false)
	for id: int in _fading.keys():
		var t: float = _fading[id] + delta
		if t >= FADE_SECONDS:
			_remove(id)
			continue
		_fading[id] = t
		var sprite: CharacterSprite = _world.character(id)
		if sprite != null:
			sprite.modulate.a = 1.0 - t / FADE_SECONDS


func _on_sim_event(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.SUMMONED:
			var def: SummonDef = summoned(event)
			if def != null:
				_called[event.target_id] = def.display_name
			if _world.may_animate(event):
				var fighter: Combatant = _in_battle(event.target_id)
				if fighter != null and _fighters.get(fighter.id, null) != fighter:
					_show(fighter, true)
		SimEvent.Kind.SUMMON_ENDED:
			_called.erase(event.source_id)
			if not has(event.source_id) or _fading.has(event.source_id):
				return
			if _world.may_animate(event):
				_fade(event.source_id)
			else:
				_remove(event.source_id)
		SimEvent.Kind.AREA_CHANGED, SimEvent.Kind.DEPTH_CHANGED:
			for id: int in _fighters.keys():
				_remove(id)


## Fighter [param id] in the battle under way if it is a summon there, else null.
func _in_battle(id: int) -> Combatant:
	var battle: Battle = _world.simulation.expedition.battle
	var fighter: Combatant = battle.combatant(id) if battle != null else null
	return fighter if fighter != null and fighter.is_summon() else null


## A sprite for [param fighter] at its place, with a puff if [param puffed].
func _show(fighter: Combatant, puffed: bool) -> void:
	var id: int = fighter.id
	if has(id) or _world.character(id) != null:
		_remove(id)  # an earlier summon of that id, still fading
	if _world.character(id) != null:
		return
	var sprite: CharacterSprite = CharacterSprite.for_summon(fighter.def_id)
	if sprite == null:
		return
	made += 1
	var floor_y: float = WorldPlaces.fight_line(_world.simulation.expedition)
	var at := Vector2(fighter.x * World.TILE, floor_y)
	_fighters[id] = fighter
	_owners[id] = fighter.owner_id
	_names[id] = _name_for(id, fighter)
	_places[id] = at
	_world.add_summon(id, sprite, at, fighter.attack_range)
	sprite.set_facing(PartyPlaces.world_facing(_world.simulation.expedition))
	if puffed:
		_puff(sprite)


func _name_for(id: int, fighter: Combatant) -> String:
	return _called[id] if _called.has(id) else def_name(fighter.def_id)


## Starts summon [param id]'s fade, with a puff.
func _fade(id: int) -> void:
	_fading[id] = 0.0
	var sprite: CharacterSprite = _world.character(id)
	if sprite != null:
		sprite.cancel_attack()
		_puff(sprite)


func _remove(id: int) -> void:
	_fighters.erase(id)
	_owners.erase(id)
	_names.erase(id)
	_places.erase(id)
	_fading.erase(id)
	_world.remove_summon(id)


func _puff(sprite: CharacterSprite) -> void:
	var puff := FxParticle.new()
	puff.name = "Puff"
	puff.kind = PUFF_KIND
	puff.shape = FxParticle.Shape.PUFF
	puff.color = Palette.color(PUFF_COLOUR)
	puff.size = PUFF_SIZE
	puff.life = PUFF_LIFE
	puff.velocity = Vector2(0, -12)
	puff.start(sprite.position - Vector2(0, PUFF_LIFT))
	if not _world.fx.add(puff, BUDGET):
		refused += 1


## The [SummonDef] a SUMMONED [param event] brought: its summoning ability's, or null.
static func summoned(event: SimEvent) -> SummonDef:
	var ability: AbilityDef = Content.ability(event.ability_id)
	if ability != null:
		for effect: AbilityEffect in ability.effects:
			if effect.summon != null:
				return effect.summon
	return null

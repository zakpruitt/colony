class_name QuestStage
extends RefCounted
## Who stands where while the party works a quest: every worker
## ([method QuestWork.workers]) at its own spot by the prop, facing it, and every other living
## hero where the simulation has it, sat down and facing the prop once it has stopped.
##
## The lead stands [constant QuestProps.WORK_GAP] short of the prop on the side the party came
## from, the second as far past it on the far side, a third and a fourth [constant BEHIND]
## pixels further out behind the lead and the second. A gate is not a quest: its one opener is
## [QuestProps]' to place.
##
## Made by [World], which calls [method update] each frame before it moves the heroes, chains
## [method goal_for] in its [code]_follow[/code] as it chains [method CampView.goal_for], and
## reads [method sits] and [method facing_of] as it poses them. Everything is read from the
## simulation's state each frame, so a catch-up needs nothing more.

## Pixels a third or a fourth worker stands behind the lead or the second.
const BEHIND: float = 7.0

var _world: World
var _simulation: Simulation
## True while the party works a quest in a chamber (not a gate).
var _working: bool = false
## The prop's foot, while working.
var _prop: Vector2 = Vector2.ZERO
## The workers, lead first, and each one's spot.
var _workers: Array[int] = []
var _spots: Dictionary[int, Vector2] = {}
## The living heroes who watch.
var _watching: Dictionary[int, bool] = {}


func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation


## Reads the simulation's state for this frame: who works, where each stands, who watches.
func update() -> void:
	_spots.clear()
	_watching.clear()
	_workers.clear()
	var run: Expedition = _simulation.expedition
	_working = run.working_quest() != &""
	if not _working:
		return
	var key: Vector2i = _world.quest_props.party_chamber()
	if key.y < 0:
		_working = false
		return
	_prop = _world.quest_props.spot(key.x, key.y)
	_workers.assign(QuestWork.workers(run))
	var back: int = -PartyPlaces.world_facing(run)
	for i: int in _workers.size():
		var side: int = back if i % 2 == 0 else -back
		var gap: float = QuestProps.WORK_GAP + (BEHIND if i >= 2 else 0.0)
		_spots[_workers[i]] = Vector2(_prop.x + side * gap, _prop.y)
	for hero: Hero in _simulation.party.heroes:
		if hero.is_alive() and not _spots.has(hero.id):
			_watching[hero.id] = true


## Where hero [param id] stands this frame: its work spot while it works a quest, [param goal]
## otherwise.
func goal_for(id: int, goal: Vector2) -> Vector2:
	if _spots.has(id):
		return _spots[id]
	return goal


## True for a living hero who watches the work: it sits once it has stopped.
func sits(id: int) -> bool:
	return _watching.has(id)


## The way hero [param id] faces while the party works a quest (toward the prop: 1 right, -1
## left), or [param otherwise].
func facing_of(id: int, otherwise: int) -> int:
	if _spots.has(id):
		return 1 if _prop.x > _spots[id].x else -1
	if _watching.has(id):
		var sprite: CharacterSprite = _world.character(id)
		if sprite != null:
			return 1 if _prop.x >= sprite.position.x else -1
	return otherwise


## The workers of the quest being worked, lead first; empty when none is.
func workers() -> Array[int]:
	return _workers


## True while the party works a quest (not a gate).
func is_working() -> bool:
	return _working

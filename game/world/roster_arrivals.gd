class_name RosterArrivals
extends Node
## A change of the four going down, on screen ([constant SimEvent.Kind.HERO_FIELDED]): a child of
## [World], made in its [code]_ready[/code], hearing the world's events itself.
##
## - Heard as it happens ([method World.may_animate]), the hero who left fades out over
##   [constant FADE_SECONDS] in a puff and is then freed, and the one who came in stands at its
##   place in the line (by the fire while the party rests, where [CampView] hands it the place of
##   the one it replaced), fades in over the same time in a puff, and says one of [constant LINES].
## - Heard late, or while the world catches up, the sprites change at once, with nothing else.
##
## The world takes its sprite away from every hero not going down and hands it here
## ([method take_leaving]), draws each hero at [method shown] of its opacity, and calls
## [method advance] each sync before it moves the heroes, and [method catch_up] in a stalled one.

## Seconds a hero takes to fade in or out.
const FADE_SECONDS: float = 0.4
## The pool's budget its puffs are counted in, and the puff's kind, colour, size, life and how far
## above the feet it starts (a hero's middle).
const BUDGET: StringName = &"combat"
const PUFF_KIND: StringName = &"roster_puff"
const PUFF_COLOUR: StringName = &"silver"
const PUFF_SIZE: int = 10
const PUFF_LIFE: float = CombatEffects.PUFF_LIFE
const PUFF_LIFT: float = 10.0
## What a hero coming in says, one of them.
const LINES: Array[String] = [
	"Reporting in!",
	"My turn.",
	"Point me at them.",
	"Fresh boots, ready.",
]

var _world: World
## Heroes come in, by id, not yet stood at their place.
var _to_place: Dictionary[int, bool] = {}
## Heroes come in on a change heard as it happens: seconds into their fade in.
var _arriving: Dictionary[int, float] = {}
## The line each of those says once it stands at its place.
var _lines: Dictionary[int, String] = {}
## Heroes gone out on a change heard as it happens, whose sprites the world has yet to hand over.
var _departing: Dictionary[int, bool] = {}
## The sprites of heroes gone out, each with the seconds into its fade.
var _leaving: Dictionary[CharacterSprite, float] = {}


## Call once, before the world syncs: it hears [param world]'s events from then on.
func setup(world: World) -> void:
	_world = world
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## How much of hero [param id]'s opacity shows: below 1 while it fades in, else 1.
func shown(id: int) -> float:
	if _arriving.is_empty() or not _arriving.has(id):
		return 1.0
	return clampf(_arriving[id] / FADE_SECONDS, 0.0, 1.0)


## Takes [param sprite], the sprite of hero [param id] who is no longer going down, when its
## going out is to be seen: it fades and is freed here. False when it is not; the world frees it.
func take_leaving(id: int, sprite: CharacterSprite) -> bool:
	if not _departing.has(id):
		return false
	_departing.erase(id)
	_leaving[sprite] = 0.0
	_puff(sprite.position)
	return true


## Stands each hero come in at its place, puffing and speaking for one seen as it happens, and
## runs the fades on by [param delta] real seconds.
func advance(delta: float) -> void:
	for id: int in _to_place.keys():
		var sprite: CharacterSprite = _world.character(id)
		if sprite == null:
			continue
		_to_place.erase(id)
		_stand(id, sprite)
	for id: int in _arriving.keys():
		var t: float = _arriving[id] + delta
		if t >= FADE_SECONDS:
			_arriving.erase(id)
		else:
			_arriving[id] = t
	for sprite: CharacterSprite in _leaving.keys():
		var t: float = _leaving[sprite] + delta
		if t >= FADE_SECONDS:
			_leaving.erase(sprite)
			sprite.get_parent().remove_child(sprite)
			sprite.free()
			continue
		_leaving[sprite] = t
		sprite.modulate.a = 1.0 - t / FADE_SECONDS


## The world caught up on a stall: whoever was fading in is whole and whoever was fading out is
## gone, at once.
func catch_up() -> void:
	_arriving.clear()
	_lines.clear()
	_departing.clear()
	for sprite: CharacterSprite in _leaving:
		sprite.get_parent().remove_child(sprite)
		sprite.free()
	_leaving.clear()


func _on_sim_event(event: SimEvent) -> void:
	if event.kind != SimEvent.Kind.HERO_FIELDED:
		return
	var coming: int = event.source_id
	var leaving: int = event.target_id
	_to_place[coming] = true
	_to_place.erase(leaving)
	_arriving.erase(leaving)
	_lines.erase(leaving)
	_departing.erase(coming)
	if not _world.may_animate(event):
		return
	_arriving[coming] = 0.0
	_lines[coming] = LINES[(event.tick + coming) % LINES.size()]
	_departing[leaving] = true


## Hero [param id], come in, at its place now: by the fire, sat, while the party rests.
func _stand(id: int, sprite: CharacterSprite) -> void:
	var camp: CampView = _world.camp
	sprite.position = camp.goal_for(id, sprite.position)
	if camp.sits(id):
		sprite.sitting = true
		sprite.snap_sit()
	if not _arriving.has(id):
		return
	_puff(sprite.position)
	if _lines.has(id):
		_world.say(id, _lines[id])
		_lines.erase(id)


func _puff(feet: Vector2) -> void:
	var puff := FxParticle.new()
	puff.name = "Puff"
	puff.kind = PUFF_KIND
	puff.shape = FxParticle.Shape.PUFF
	puff.color = Palette.color(PUFF_COLOUR)
	puff.size = PUFF_SIZE
	puff.life = PUFF_LIFE
	puff.velocity = Vector2(0, -12)
	puff.start(feet - Vector2(0, PUFF_LIFT))
	_world.fx.add(puff, BUDGET)

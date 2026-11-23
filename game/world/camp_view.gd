class_name CampView
extends Node2D
## The party's camp while it rests: a child of [World], made once in its setup beside QuestProps.
##
## While [member Expedition.state] is RESTING the world shows, on the floor the party rests on, a
## lit campfire at the middle of its line and a bedroll just past each end, drawn under the
## characters. The heroes on the fire's left face right and those on its right face left, each
## moved from where the simulation has it to stand clear of the fire, but never more than
## CAMP_REACH ([method goal_for], [method facing_of]); the world sits them down there. A hero
## off the camp's floor stays put, faces the fire and stands ([method sits]).
##
## A rest heard as it starts ([constant SimEvent.Kind.REST_STARTED], allowed by
## [method World.may_animate]) sets the camp up over CAMP_SETUP: the bedrolls unroll, the logs set
## down in a puff of dust, then the flames catch. A rest the world first sees any other way (late,
## catching up, after time away) is shown whole at once. When the rest ends the fire goes out in a
## puff of smoke and the bedrolls roll up over CAMP_PACK. Its four sprites are made once and
## reused; each frame it only moves them and shows them.

## Nothing shown; setting up; whole; being packed away.
enum Phase { NONE, SETTING, WHOLE, PACKING }

## No hero's feet stand nearer the fire's middle than this many pixels.
const CAMP_CLEARANCE: float = 10.0
## No hero is moved further than this from where the simulation has it, clear of the fire or not.
const CAMP_REACH: float = 12.0
## Seconds the camp takes to set up, and to pack.
const CAMP_SETUP: float = 0.5
const CAMP_PACK: float = 0.5
const SHEETS: String = "res://assets/sprites/ambience/"
## Pixels between a bedroll's end and the outermost hero's feet: clear of the hero's back.
const BED_GAP: float = 10.0
## Within the setting-up (shares of it): the bedrolls unroll until UNROLLED, the logs drop from
## LOGS_FALL pixels up between LOGS_FROM and LOGS_DOWN, landing in their dust, and the flames
## catch at FLAMES_AT, growing to full over FLAMES_GROW.
const UNROLLED: float = 0.7
const LOGS_FROM: float = 0.2
const LOGS_DOWN: float = 0.45
const LOGS_FALL: float = 6.0
const FLAMES_AT: float = 0.6
const FLAMES_GROW: float = 0.25
## How far above the fire's feet its light sits, as the start room's campfire's does.
const LIGHT_RAISE: float = 11.0
## How many puffs the logs' dust and the fire's smoke throw.
const DUST_PUFFS: int = 5
const SMOKE_PUFFS: int = 6

var _world: World
var _simulation: Simulation
var _logs: Sprite2D
var _flame: Sprite2D
var _red: Sprite2D
var _green: Sprite2D
var _flames: Array[Texture2D] = []
var _phase: Phase = Phase.NONE
var _share: float = 0.0
## True while the camp knows the party rests; set when it lays the camp out.
var _resting: bool = false
## True once a REST_STARTED that may be animated has been heard, and a REST_ENDED, until the
## frame's animate.
var _fresh: bool = false
var _smoke: bool = false
var _fire: Vector2 = Vector2.ZERO
## Each hero's place by the fire and the way it faces there, for the rest laid out.
var _places: Dictionary[int, Vector2] = {}
var _facings: Dictionary[int, int] = {}
var _time: float = 0.0
var _flame_frame: int = -1
var _lit: bool = false


func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	var fire: PixelSheet = PixelSheet.load_sheet(SHEETS + "campfire.png")
	var beds: PixelSheet = PixelSheet.load_sheet(SHEETS + "bedroll.png")
	_red = _part(beds, &"red", "BedrollRed")
	_green = _part(beds, &"green", "BedrollGreen")
	_red.region_enabled = true
	_green.region_enabled = true
	_logs = _part(fire, &"logs", "Logs")
	for frame: int in 4:
		_flames.append(fire.part(StringName("flame_%d" % frame)))
	_flame = _part(fire, &"flame_0", "Flame")
	_show_parts()
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## Where hero [param id] stands this frame: its camp place while the party rests, [param goal]
## otherwise. World chains it as it chains QuestProps.goal_for.
func goal_for(id: int, goal: Vector2) -> Vector2:
	if _resting and _places.has(id):
		return _places[id]
	return goal


## True if hero [param id] has a place at the camp (its feet on the camp's floor): it sits there.
func sits(id: int) -> bool:
	return _resting and _places.has(id)


## The way hero [param id] faces while it rests (1 right, -1 left), or [param otherwise].
func facing_of(id: int, otherwise: int) -> int:
	if _resting and _facings.has(id):
		return _facings[id]
	return otherwise


## True while any part of the camp is shown (set up, burning or being packed).
func is_shown() -> bool:
	return _phase != Phase.NONE


## Where the fire's middle is on the floor, in world pixels. Valid while is_shown().
func fire_feet() -> Vector2:
	return _fire


## How far the camp is set up: 0 (nothing) to 1 (whole), rising while it sets up, falling while
## it packs.
func setup_share() -> float:
	return _share


## Follows the party's rest by [param delta] real seconds: lays the camp out as a rest begins,
## sets it up, burns its fire and packs it away. The world calls it each frame before it places
## the heroes.
func animate(delta: float) -> void:
	_time += delta
	var resting: bool = _simulation.expedition.state == Expedition.State.RESTING
	if resting and not _resting:
		_lay_out()
		_phase = Phase.SETTING if _fresh else Phase.WHOLE
		_share = 0.0 if _phase == Phase.SETTING else 1.0
	elif _resting and not resting:
		_pack()
	_resting = resting
	_fresh = false
	_smoke = false
	match _phase:
		Phase.SETTING:
			var was: float = _share
			_share = minf(_share + delta / CAMP_SETUP, 1.0)
			if was < LOGS_DOWN and _share >= LOGS_DOWN:
				_puffs(DUST_PUFFS, &"tan", 3, 0.35, Vector2(14.0, -6.0))
			if _share >= 1.0:
				_phase = Phase.WHOLE
		Phase.PACKING:
			_share = maxf(_share - delta / CAMP_PACK, 0.0)
			if _share <= 0.0:
				_phase = Phase.NONE
	_show_parts()


## The world caught up on a stall: whatever was setting up is whole and whatever was being packed
## is gone, at once, with no puff. The world calls it after [method animate] in such a frame.
func catch_up() -> void:
	match _phase:
		Phase.SETTING:
			_share = 1.0
			_phase = Phase.WHOLE
		Phase.PACKING:
			_share = 0.0
			_phase = Phase.NONE
	_show_parts()


func _on_sim_event(event: SimEvent) -> void:
	if event.kind == SimEvent.Kind.REST_STARTED:
		_fresh = _world.may_animate(event)
	elif event.kind == SimEvent.Kind.REST_ENDED:
		_smoke = _world.may_animate(event)


## Works out the fire's place and each hero's place and facing by it, from where the simulation
## has the heroes standing as the rest begins. The camp stands on the front hero's floor; a hero
## off it (up a ladder, round a turn) keeps its place and only faces the fire.
func _lay_out() -> void:
	var run: Expedition = _simulation.expedition
	var heroes: Array[Hero] = _simulation.party.heroes
	_places.clear()
	_facings.clear()
	if heroes.is_empty():
		return
	var ahead: int = PartyPlaces.world_facing(run)
	var feet: Dictionary[int, Vector2] = {}
	var rank: Dictionary[int, int] = {}
	for i: int in heroes.size():
		feet[heroes[i].id] = WorldPlaces.feet(run.hero_position(heroes[i].id))
		rank[heroes[i].id] = i
	var floor_y: float = feet[heroes[0].id].y
	var order: Array[int] = []
	for hero: Hero in heroes:
		if absf(feet[hero.id].y - floor_y) < 1.0:
			order.append(hero.id)
	# Level in x, the hero nearer the front stands nearer the way ahead.
	order.sort_custom(
		func(a: int, b: int) -> bool:
			if feet[a].x != feet[b].x:
				return feet[a].x < feet[b].x
			return rank[a] > rank[b] if ahead > 0 else rank[a] < rank[b]
	)
	var low: float = feet[order[0]].x
	var high: float = feet[order[-1]].x
	_fire = Vector2(roundf((low + high) / 2.0), floor_y)
	# With an odd number, the middle hero goes to the side away from the way ahead.
	var left_count: int = order.size() / 2
	if order.size() % 2 == 1 and ahead > 0:
		left_count += 1
	for i: int in order.size():
		var at: Vector2 = feet[order[i]]
		var left: bool = i < left_count
		if left:
			at.x = maxf(minf(at.x, _fire.x - CAMP_CLEARANCE), at.x - CAMP_REACH)
		else:
			at.x = minf(maxf(at.x, _fire.x + CAMP_CLEARANCE), at.x + CAMP_REACH)
		_places[order[i]] = at
		_facings[order[i]] = 1 if left else -1
	for hero: Hero in heroes:
		if not _facings.has(hero.id):
			_facings[hero.id] = 1 if feet[hero.id].x < _fire.x else -1
	low = minf(low, _places[order[0]].x)
	high = maxf(high, _places[order[-1]].x)
	var bed: Vector2 = Vector2(_red.texture.get_size())
	_red.position = Vector2(low - BED_GAP - bed.x, _fire.y - bed.y)
	_green.position = Vector2(high + BED_GAP, _fire.y - bed.y)
	var logs: Vector2 = Vector2(_logs.texture.get_size())
	_logs.position = Vector2(_fire.x - logs.x / 2.0, _fire.y - logs.y)
	_flame.position = _logs.position


## The rest is over: the fire goes out (in a puff of smoke for an end heard as it happens) and the
## bedrolls roll up from where they had got to.
func _pack() -> void:
	if _phase == Phase.NONE:
		return
	if _smoke and _share >= LOGS_DOWN:
		_puffs(SMOKE_PUFFS, &"silver", 5, 0.6, Vector2(8.0, -20.0))
	_phase = Phase.PACKING


## Shows the camp's parts as far as it is set up, the flames' frame of the moment, and its light.
func _show_parts() -> void:
	var setting: bool = _phase == Phase.SETTING or _phase == Phase.WHOLE
	var unrolled: float = clampf(_share / UNROLLED, 0.0, 1.0) if setting else _share
	_bed_width(_red, unrolled)
	_bed_width(_green, unrolled)
	var logs_in: float = clampf((_share - LOGS_FROM) / (LOGS_DOWN - LOGS_FROM), 0.0, 1.0)
	_logs.visible = setting and _share >= LOGS_FROM
	_logs.offset = Vector2(0.0, -roundf(LOGS_FALL * (1.0 - logs_in * logs_in)))
	var burning: bool = setting and _share >= FLAMES_AT
	_flame.visible = burning
	if burning:
		var grown: float = clampf((_share - FLAMES_AT) / FLAMES_GROW, 0.0, 1.0)
		_flame.modulate.a = grown
		var frame: int = floori(_time * AmbienceLevel.FLAME_RATE) % _flames.size()
		if frame != _flame_frame:
			_flame_frame = frame
			_flame.texture = _flames[frame]
	if burning != _lit:
		_lit = burning
		_world.ambience.set_camp_light(_fire - Vector2(0.0, LIGHT_RAISE), burning)


## Shows [param bed] unrolled to [param share] of its width, from its pillow end.
static func _bed_width(bed: Sprite2D, share: float) -> void:
	var size: Vector2 = Vector2(bed.texture.get_size())
	var width: float = roundf(size.x * share)
	bed.visible = width > 0.0
	var region := Rect2(Vector2.ZERO, Vector2(width, size.y))
	if bed.region_rect != region:
		bed.region_rect = region


## [param count] puffs of [param colour] from the fire's middle, of size [param size] and life up
## to [param life], thrown out up to [param spread] (x either way, y up): passing effects.
func _puffs(count: int, colour: StringName, size: int, life: float, spread: Vector2) -> void:
	for i: int in count:
		var puff := FxParticle.new()
		puff.name = "Particle"
		puff.kind = &"camp_puff"
		puff.shape = FxParticle.Shape.PUFF
		puff.color = Palette.color(colour)
		puff.size = size + i % 2
		var side: float = (float(i) / maxf(count - 1, 1) - 0.5) * 2.0
		puff.velocity = Vector2(side * spread.x, spread.y * (0.6 + 0.4 * float(i % 3) / 2.0))
		puff.life = life * (0.7 + 0.3 * float(i % 2))
		if not _world.fx.add(puff, &"combat"):
			return
		puff.start(_fire + Vector2(side * 4.0, -2.0).round())


func _part(sheet: PixelSheet, part: StringName, node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = sheet.part(part)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = false
	add_child(sprite)
	return sprite

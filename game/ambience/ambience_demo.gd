class_name AmbienceDemo
extends Node2D
## Tours the labyrinth with ambience on: a party of four walks through a chamber
## of every kind, a dark tunnel, and a level of every earth stratum, one stop every
## [constant STOP_SECONDS], with monsters standing in the dens. The caption names the stop; the
## corner shows the frame rate.
## Run: python tools/dev.py shot --scene=res://game/ambience/ambience_demo.tscn --name=amb
##      --seconds=3 --count=10
## The first stop lasts [constant LEAD_IN] longer, so shots every 3 s land in the middle of a stop.


## One place the tour shows.
class Stop:
	extends RefCounted
	## The level, and where the party's leader walks from and to, in world tiles (feet).
	var depth: int
	var start: Vector2
	var end: Vector2
	## What the caption says.
	var caption: String
	## Monsters stand at these world tiles (feet) while the party is here.
	var monsters: PackedVector2Array = []


## The labyrinth the tour walks.
const SEED: int = 6
const STOP_SECONDS: float = 3.0
const LEAD_IN: float = 1.5
## How many tiles the leader walks during a stop.
const WALK_TILES: float = 3.5
const PARTY: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
const MONSTERS: Array[StringName] = [&"spider", &"slime", &"skeleton"]
## Pixels between the heroes' feet.
const SPACING: float = 17.0
## How far above the leader's feet the party's light sits, in pixels.
const LIGHT_HEIGHT: float = 14.0
## How far ahead of the leader, and above the floor, the camera looks, in tiles.
const LOOK_AHEAD: float = 6.0
const LOOK_ABOVE: float = 2.5
const FPS_EVERY: float = 0.5

## The labyrinth, view and ambience this demo shows.
var labyrinth: Labyrinth
var view: LabyrinthView
var ambience: Ambience
## The tour, in order.
var stops: Array[Stop] = []

var _camera: WorldCamera
var _party: Array[CharacterSprite] = []
var _monsters: Array[CharacterSprite] = []
var _time: float = 0.0
var _stop: int = -1
var _caption: Label
var _fps: Label
var _fps_timer: float = 0.0


func _ready() -> void:
	labyrinth = Labyrinth.new(SEED)
	view = LabyrinthView.new()
	view.name = "LabyrinthView"
	view.labyrinth = labyrinth
	add_child(view)
	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup(view)
	for monster_id: StringName in MONSTERS:
		var monster: CharacterSprite = CharacterSprite.for_monster(monster_id)
		monster.set_facing(-1)
		add_child(monster)
		_monsters.append(monster)
	for hero_id: StringName in PARTY:
		var hero: CharacterSprite = CharacterSprite.for_hero(hero_id)
		hero.play_walk()
		add_child(hero)
		_party.append(hero)
	_camera = WorldCamera.new()
	_camera.name = "WorldCamera"
	add_child(_camera)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_caption = PixelText.label("", &"sand")
	_caption.position = Vector2(8, 6)
	overlay.add_child(_caption)
	_fps = PixelText.label("", &"steel")
	_fps.position = Vector2(8, 18)
	overlay.add_child(_fps)
	stops = _plan()
	_show(0)


func _process(delta: float) -> void:
	_time += delta
	var index: int = 0
	if _time >= STOP_SECONDS + LEAD_IN:
		index = 1 + floori((_time - STOP_SECONDS - LEAD_IN) / STOP_SECONDS)
	index %= stops.size()
	if index != _stop:
		_show(index)
	var started: float = 0.0 if index == 0 else STOP_SECONDS + LEAD_IN + (index - 1) * STOP_SECONDS
	var length: float = STOP_SECONDS + (LEAD_IN if index == 0 else 0.0)
	var progress: float = clampf(fmod(_time - started, length * stops.size()) / length, 0.0, 1.0)
	_place_party(stops[index].start.lerp(stops[index].end, progress))
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = FPS_EVERY
		_fps.text = (
			"fps %d   lights %d   particles %d"
			% [Engine.get_frames_per_second(), ambience.light_count(), ambience.particle_count()]
		)


func _show(index: int) -> void:
	_stop = index
	var stop: Stop = stops[index]
	view.set_focus(stop.start)
	_place_party(stop.start)
	_camera.snap_to(_camera_point(stop.start))
	_caption.text = stop.caption
	for i: int in _monsters.size():
		var monster: CharacterSprite = _monsters[i]
		monster.visible = i < stop.monsters.size()
		if monster.visible:
			monster.position = LabyrinthView.to_pixels(stop.monsters[i])


func _place_party(leader: Vector2) -> void:
	var feet: Vector2 = LabyrinthView.to_pixels(leader).round()
	for i: int in _party.size():
		_party[i].position = feet - Vector2(i * SPACING, 0)
	ambience.party_light_position = (
		feet - Vector2((_party.size() - 1) * SPACING * 0.5, LIGHT_HEIGHT)
	)
	_camera.target = _camera_point(leader)


func _camera_point(leader: Vector2) -> Vector2:
	return LabyrinthView.to_pixels(leader + Vector2(LOOK_AHEAD, -LOOK_ABOVE))


## The tour: the START chamber, a tunnel, then a den, a vault and a plain chamber, and a den or
## vault and a plain chamber in each deeper stratum.
func _plan() -> Array[Stop]:
	var plan: Array[Stop] = []
	plan.append(_chamber_stop(1, labyrinth.level(1).chambers[0]))
	plan.append(_tunnel_stop(1))
	for wanted: LabyrinthChamber.Kind in [
		LabyrinthChamber.Kind.DEN, LabyrinthChamber.Kind.VAULT, LabyrinthChamber.Kind.PLAIN
	]:
		plan.append(_find(wanted, 2, 5))
	for first: int in [6, 11, 16]:
		var special: Stop = _find(LabyrinthChamber.Kind.VAULT, first, first + 4)
		if special == null:
			special = _find(LabyrinthChamber.Kind.DEN, first, first + 4)
		plan.append(special)
		plan.append(_find(LabyrinthChamber.Kind.PLAIN, first + 1, first + 4))
	var found: Array[Stop] = []
	for stop: Stop in plan:
		if stop != null:
			found.append(stop)
	return found


## The first chamber of [param kind] from [param from_depth] to [param to_depth], or null.
func _find(kind: LabyrinthChamber.Kind, from_depth: int, to_depth: int) -> Stop:
	for depth: int in range(from_depth, to_depth + 1):
		for chamber: LabyrinthChamber in labyrinth.level(depth).chambers:
			if chamber.kind == kind:
				return _chamber_stop(depth, chamber)
	return null


func _chamber_stop(depth: int, chamber: LabyrinthChamber) -> Stop:
	var level: LabyrinthLevel = labyrinth.level(depth)
	var span: Vector2 = _walkable(level, chamber)
	var stop := Stop.new()
	stop.depth = depth
	var feet: float = level.floor_y + 1
	# The party walks in from the tunnel on the left, so the chamber's props stay in view; in the
	# first chamber, which has none, it starts against the wall.
	var start: float = chamber.rect.position.x + 0.5
	if chamber.index == 0:
		start = span.x + _party.size() * SPACING / LabyrinthView.TILE
	start = minf(start, span.y - WALK_TILES)
	stop.start = Vector2(start, feet)
	stop.end = Vector2(minf(start + WALK_TILES, span.y), feet)
	var kind_name: String = LabyrinthChamber.Kind.keys()[chamber.kind]
	stop.caption = "depth %d  %s  %s" % [depth, LabyrinthTiles.stratum(depth), kind_name.to_lower()]
	if chamber.kind == LabyrinthChamber.Kind.DEN:
		for i: int in MONSTERS.size():
			stop.monsters.append(Vector2(span.y - 0.5 - i * 1.6, feet))
	return stop


func _tunnel_stop(depth: int) -> Stop:
	var level: LabyrinthLevel = labyrinth.level(depth)
	var longest: Rect2i = level.tunnels[0]
	for tunnel: Rect2i in level.tunnels:
		if tunnel.size.x > longest.size.x:
			longest = tunnel
	var stop := Stop.new()
	stop.depth = depth
	var feet: float = level.floor_y + 1
	stop.start = Vector2(longest.position.x + longest.size.x * 0.5, feet)
	stop.end = stop.start + Vector2(WALK_TILES * 0.6, 0)
	stop.caption = "depth %d  %s  tunnel" % [depth, LabyrinthTiles.stratum(depth)]
	return stop


## The widest stretch of [param chamber]'s floor clear of the shaft, as (from, to) in tiles.
func _walkable(level: LabyrinthLevel, chamber: LabyrinthChamber) -> Vector2:
	var from: float = chamber.rect.position.x + 1.0
	var to: float = chamber.rect.end.x - 1.0
	var shaft: Rect2i = level.shaft_down
	if shaft.position.x >= chamber.rect.position.x and shaft.position.x < chamber.rect.end.x:
		if shaft.position.x - from > to - shaft.end.x:
			to = shaft.position.x - 0.5
		else:
			from = shaft.end.x + 0.5
	return Vector2(from, to)

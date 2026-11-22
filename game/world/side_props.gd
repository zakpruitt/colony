class_name SideProps
extends Node2D
## The gates and caches of the side paths of every built stage. Each side path
## ([member LabyrinthLevel.side_paths]) shows its gate on the floor where it stands
## ([member SidePath.gate_at] along the path's course), by the gate's kind, and a strongbox at
## the middle of its cache room's floor. Each sheet has a [code]closed[/code] and an
## [code]open[/code] part: a gate is closed while its cache is full and open from the moment the
## party opens it until the cache refills; a cache is closed while full and open while empty.
## What is shown is read from the simulation's state, so it is true after a stall or time away.
##
## A child of [World], beside [QuestProps] and drawn under the darkness like it. The world calls
## [method scan] whenever it looks for waiting monsters and [method animate] once a frame.
## A full cache out of the party's light carries a glint ([PropGlints]); a closed hidden crack
## breathes a few motes; a closed gate under the mouse shows its [GateTip].
## [QuestProps] asks which gate is being worked ([method worked_spot]) to stand the worker by it.

## Where the sheets are, each named for its gate's id; and the cache's.
const DIR: String = "res://assets/sprites/props/"
const CACHE: StringName = &"cache"
## The two parts of every sheet.
const CLOSED: StringName = &"closed"
const OPEN: StringName = &"open"
## The gate whose closed part breathes motes, how many, and how many times a second they move.
const DRAUGHTY: StringName = &"hidden_crack"
const MOTES: int = 4
const MOTE_STEPS: float = 8.0
## No side path.
const NONE: Vector2i = Vector2i(0, -1)
## How far past its gate, in tiles of the path's course, a party must be for the gate to have
## been opened.
const PAST: float = 0.01

## The tip of the gate under the mouse.
var tip: GateTip
## The folder the sheets are looked for in. A gate whose id has no sheet there is drawn as
## nothing; everything else about it goes on.
var sheets: String = DIR
## Whether the tip follows the real mouse; a test turns it off and calls [method point_at].
var follows_mouse: bool = true

var _world: World
var _simulation: Simulation
## Each side path's gate and cache, by Vector2i(stage, place in the level's side paths).
var _gates: Dictionary[Vector2i, Sprite2D] = {}
var _caches: Dictionary[Vector2i, Sprite2D] = {}
## The full caches: those that may glint.
var _full: Dictionary[Vector2i, Sprite2D] = {}
var _glints: PropGlints
## The side path whose gate was heard to open on the trip the party is on.
var _passed: Vector2i = NONE
## The tick of the last cache heard to open, and where that cache stands.
var _paid_tick: int = -1
var _paid_at: Vector2 = Vector2.ZERO
## The closed gate under the mouse; the gate the tip's words are for, and whether the party
## may have changed since they were written.
var _hovered: Vector2i = NONE
var _worded: Vector2i = NONE
var _words_stale: bool = false
## The motes of the draughty gates, drawn over the props; their clock and the step last drawn.
var _draught: Node2D
var _time: float = 0.0
var _mote_step: int = -1


## Call once, before the first scan.
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	_draught = Node2D.new()
	_draught.name = "Draught"
	_draught.draw.connect(_draw_draught)
	add_child(_draught)
	_glints = PropGlints.new()
	add_child(_glints)
	_glints.setup(world)
	tip = GateTip.new()
	add_child(tip)
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## The gate of side path [param index] on [param stage], or null when that stage is not shown.
func gate(stage: int, index: int) -> Sprite2D:
	return _gates.get(Vector2i(stage, index), null)


## The cache of side path [param index] on [param stage], or null.
func cache(stage: int, index: int) -> Sprite2D:
	return _caches.get(Vector2i(stage, index), null)


## The part [param shown] (a gate or a cache) shows: [constant CLOSED], [constant OPEN], or
## [code]&""[/code] for null.
static func part_of(shown: Sprite2D) -> StringName:
	if shown == null:
		return &""
	var part: StringName = shown.get_meta(&"part", &"")
	return part


## Where the gate of side path [param index] on [param stage] stands, in world pixels: on the
## floor of the room it leaves, at the head or foot of its ladder or the mouth of its tunnel.
func gate_spot(stage: int, index: int) -> Vector2:
	var path: SidePath = _simulation.labyrinth.level(stage).side_paths[index]
	return WorldPlaces.feet(path.course.point_at(path.gate_at))


## Where the cache of side path [param index] on [param stage] stands: the middle of its room's
## floor.
func cache_spot(stage: int, index: int) -> Vector2:
	var room: LabyrinthChamber = _simulation.labyrinth.level(stage).side_paths[index].room
	var middle: float = floorf((room.rect.position.x + room.rect.end.x) / 2.0)
	return Vector2(middle * World.TILE, WorldPlaces.floor_line(room))


## True if the gate of side path [param index] on [param stage] stands open: its cache is
## empty, or the party is on that path and has opened it.
func is_open(stage: int, index: int) -> bool:
	var run: Expedition = _simulation.expedition
	if not SidePathRules.is_full(run, stage, index):
		return true
	if run.depth != stage or run.side_path != index:
		return false
	var path: SidePath = _simulation.labyrinth.level(stage).side_paths[index]
	return _passed == Vector2i(stage, index) or run.x > path.gate_at + PAST


## The sparkle part glinting on that side path's cache now, or [code]&""[/code]
## ([method PropGlints.part]).
func glint_part(stage: int, index: int) -> StringName:
	return _glints.part(Vector2i(stage, index))


## True when that side path's cache is full and out of the party's light, so it carries a glint.
func is_glinting(stage: int, index: int) -> bool:
	var full: Sprite2D = _full.get(Vector2i(stage, index), null)
	return _glints.in_the_dark(full)


## True while the gate of side path [param index] on [param stage] breathes motes: a closed
## [constant DRAUGHTY] one.
func has_draught(stage: int, index: int) -> bool:
	var shown: Sprite2D = gate(stage, index)
	return shown != null and _sheet_id(shown) == DRAUGHTY and part_of(shown) == CLOSED


## Where the gate the party is working at stands, or [constant Vector2.INF] while it works at
## none.
func worked_spot() -> Vector2:
	var run: Expedition = _simulation.expedition
	if run.side_path < 0 or run.worker_id() < 0:
		return Vector2.INF
	return gate_spot(run.depth, run.side_path)


## The way from the worker to the gate it works at, 1 right or -1 left: it stands on the side
## the party came from, where the heroes behind it still are.
func worked_side() -> int:
	var run: Expedition = _simulation.expedition
	var heroes: Array[Hero] = _simulation.party.heroes
	if run.side_path < 0 or heroes.is_empty():
		return PartyPlaces.world_facing(run)
	var path: SidePath = _simulation.labyrinth.level(run.depth).side_paths[run.side_path]
	var gate_x: float = path.course.point_at(path.gate_at).x
	var behind: float = run.hero_position(heroes[heroes.size() - 1].id).x
	if is_equal_approx(behind, gate_x):
		return PartyPlaces.world_facing(run)
	return 1 if behind < gate_x else -1


## How tall the gate the party is working at is, in pixels; 0 with none.
func worked_height() -> float:
	var run: Expedition = _simulation.expedition
	var shown: Sprite2D = gate(run.depth, run.side_path)
	return height_of(shown)


## How tall [param shown] is, in pixels; 0 for none, or for a gate with no sheet.
static func height_of(shown: Sprite2D) -> float:
	if shown == null or shown.texture == null:
		return 0.0
	return float(shown.texture.get_height())


## The name of the microskill that opens the gate the party is working at; "" with none.
func worked_name() -> String:
	var run: Expedition = _simulation.expedition
	if run.side_path < 0:
		return ""
	var path: SidePath = _simulation.labyrinth.level(run.depth).side_paths[run.side_path]
	var def: GateDef = Content.gate(path.gate)
	var skill: MicroskillDef = Content.microskill(def.microskill) if def != null else null
	return skill.display_name if skill != null else ""


## Where the gains of [param event] leave from when a cache paid them (they come on the tick it
## opened): that cache's place on its floor. [constant Vector2.INF] for any other gain.
func gains_from(event: SimEvent) -> Vector2:
	return _paid_at if event.tick == _paid_tick else Vector2.INF


## [method gains_from] of [param world]'s side props; [constant Vector2.INF] when it has none.
static func origin(world: World, event: SimEvent) -> Vector2:
	return world.side_props.gains_from(event) if world.side_props != null else Vector2.INF


## The side path of the party's stage with the gate at [param gate_index] in
## [method Content.gate_ids] that leaves nearest the party, or -1: the one a GATE_SEALED tells
## of.
func nearest(gate_index: int) -> int:
	var ids: Array[StringName] = Content.gate_ids()
	if gate_index < 0 or gate_index >= ids.size():
		return -1
	var run: Expedition = _simulation.expedition
	var paths: Array[SidePath] = _simulation.labyrinth.level(run.depth).side_paths
	var found: int = -1
	for index: int in paths.size():
		if paths[index].gate != ids[gate_index]:
			continue
		if found < 0 or absf(paths[index].at - run.x) < absf(paths[found].at - run.x):
			found = index
	return found


## The sheet of the gate [param id], or of the [constant CACHE]; null when there is none.
static func sheet_of(id: StringName, dir: String = DIR) -> PixelSheet:
	var path: String = dir + String(id) + ".png"
	return PixelSheet.load_sheet(path) if ResourceLoader.exists(path) else null


## Takes every gate and cache away when the party arrives in another area; [method scan] gives
## the new area's stages theirs.
func clear() -> void:
	for shown: Sprite2D in _gates.values() + _caches.values():
		shown.free()
	_gates.clear()
	_caches.clear()
	_full.clear()
	_passed = NONE
	_hovered = NONE
	tip.hide_tip()
	_draught.queue_redraw()


## Gives every side path of the stages in [param built] its gate and cache, takes away those of
## stages no longer built, and shows each as the simulation has it now.
func scan(built: Array[int]) -> void:
	if _simulation.expedition.side_path < 0:
		_passed = NONE
	_words_stale = true
	for key: Vector2i in _gates.keys():
		if not built.has(key.x):
			_gates[key].free()
			_caches[key].free()
			_gates.erase(key)
			_caches.erase(key)
			_full.erase(key)
	for stage: int in built:
		var paths: Array[SidePath] = _simulation.labyrinth.level(stage).side_paths
		for index: int in paths.size():
			var key := Vector2i(stage, index)
			if not _gates.has(key):
				_gates[key] = _add(paths[index].gate, gate_spot(stage, index))
				_caches[key] = _add(CACHE, cache_spot(stage, index))
			_refresh(key)


## Pulses the glints, moves the motes and brings the tip up to date.
func animate(delta: float) -> void:
	_glints.pulse(delta, _full)
	if _gates.is_empty():
		return
	_time = fposmod(_time + delta, 4096.0)
	var step: int = int(_time * MOTE_STEPS)
	if step != _mote_step:
		_mote_step = step
		_draught.queue_redraw()
	if follows_mouse:
		point_at(get_global_mouse_position())
	elif _hovered != NONE:
		_show_tip()


## Puts the mouse at [param at], in world pixels: a closed gate standing there shows its tip,
## and anywhere else hides it.
func point_at(at: Vector2) -> void:
	_hovered = NONE
	for key: Vector2i in _gates:
		var shown: Sprite2D = _gates[key]
		if part_of(shown) == CLOSED and _rect_of(shown).has_point(at):
			_hovered = key
			break
	_show_tip()


func _show_tip() -> void:
	var shown: Sprite2D = _gates.get(_hovered, null)
	if shown == null or part_of(shown) != CLOSED:
		_hovered = NONE
		tip.hide_tip()
		return
	var screen: Rect2 = (
		get_viewport().get_canvas_transform().affine_inverse()
		* Rect2(Vector2.ZERO, get_viewport_rect().size)
	)
	if _worded != _hovered or _words_stale or not tip.visible:
		if not tip.write(_simulation, _hovered.x, _hovered.y):
			tip.hide_tip()
			return
		_worded = _hovered
		_words_stale = false
	tip.place(_rect_of(shown), screen)


## The id of the sheet [param shown] was made from.
static func _sheet_id(shown: Sprite2D) -> StringName:
	var id: StringName = shown.get_meta(&"sheet", &"")
	return id


static func _rect_of(shown: Sprite2D) -> Rect2:
	if shown.texture == null:
		return Rect2(shown.position, Vector2.ZERO)
	return Rect2(shown.position + shown.offset, shown.texture.get_size())


func _on_sim_event(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.LEVEL_UP, SimEvent.Kind.MICROSKILL_LEARNED:
			_words_stale = true
		SimEvent.Kind.GATE_OPENED, SimEvent.Kind.CACHE_OPENED:
			# An old event may be of a stage the party has left: only what the simulation says
			# now is shown, and nothing is kept from it.
			var stage: int = _simulation.expedition.depth
			var key := Vector2i(stage, event.amount)
			if not _world.may_animate(event) or not _gates.has(key):
				for shown: Vector2i in _gates:
					_refresh(shown)
			elif event.kind == SimEvent.Kind.GATE_OPENED:
				_passed = key
				_refresh(key)
			else:
				_paid_tick = event.tick
				_paid_at = cache_spot(stage, event.amount)
				_refresh(key)


## Shows the gate and the cache of side path [param key] as the simulation has them now.
func _refresh(key: Vector2i) -> void:
	if not _gates.has(key):
		return
	var full: bool = SidePathRules.is_full(_simulation.expedition, key.x, key.y)
	if _show(_gates[key], OPEN if is_open(key.x, key.y) else CLOSED):
		_draught.queue_redraw()
	_show(_caches[key], CLOSED if full else OPEN)
	if full:
		_full[key] = _caches[key]
	else:
		_full.erase(key)


## A sprite of the sheet [param id] standing at [param feet], no part shown yet.
func _add(id: StringName, feet: Vector2) -> Sprite2D:
	var made := Sprite2D.new()
	made.set_meta(&"sheet", id)
	made.centered = false
	made.position = feet
	add_child(made)
	# Under the motes and the glints, which were added first.
	move_child(made, 0)
	return made


## Shows [param part] of [param shown]'s sheet. True if that changed what it shows.
func _show(shown: Sprite2D, part: StringName) -> bool:
	if part_of(shown) == part:
		return false
	var sheet: PixelSheet = sheet_of(_sheet_id(shown), sheets)
	if sheet == null or not sheet.has_part(part):
		return false
	shown.texture = sheet.part(part)
	# The pivot pixel (the bottom centre) sits just above the floor line, as a character's feet do.
	shown.offset = -Vector2(sheet.part_pivot(part)) - Vector2(0, 1)
	shown.set_meta(&"part", part)
	return true


## A few pale motes drifting out of each closed crack, toward the room it is in.
func _draw_draught() -> void:
	var pale: Color = Palette.color(&"sand")
	for key: Vector2i in _gates:
		if not has_draught(key.x, key.y):
			continue
		var shown: Sprite2D = _gates[key]
		var height: float = height_of(shown)
		for i: int in MOTES:
			var along: float = fposmod(_mote_step / (MOTE_STEPS * 2.5) + float(i) / MOTES, 1.0)
			if along > 0.85:
				continue
			var side: float = -1.0 if (i + key.y) % 2 == 0 else 1.0
			var at := Vector2(
				side * (2.0 + along * 14.0),
				-height * (0.25 + 0.17 * i) - sin(along * TAU + i) * 2.0 - along * 4.0
			)
			_draught.draw_rect(Rect2((shown.position + at).round(), Vector2.ONE), pale)

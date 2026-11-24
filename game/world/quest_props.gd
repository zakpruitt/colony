class_name QuestProps
extends Node2D
## The quests waiting in the labyrinth, and the work on one. Each chamber of a
## built level that holds a quest ([method Expedition.quest_in]) shows its prop on the
## floor toward the far side of the room ([method spot_in]), in the look, tint and facing that
## chamber gives it ([QuestLooks]) and with its dressing lying round it, as far away as monsters
## are shown. While the party works a quest, each worker swings at the prop on a slow repeat once
## it stands at its spot ([QuestStage]; emitting [signal worked] each time), and a small bar over
## the prop fills with [method Expedition.work_progress] under the microskill's name. A rune
## stone lights a rune for each quarter of the work.
##
## A done quest's prop shows its done part (an open chest, a lit stone) until its room holds
## something again or the world shows another stage; a mended wanderer stands, then walks off
## the way the party came and goes once out of its room. A done prop seen late is done at once,
## and a late wanderer is gone at once. [method prop] and [method prop_count] are the props of
## waiting quests only; a done one is read through [method part_of] and [method is_done].
##
## A child of [World], which calls [method scan] whenever it looks for waiting monsters,
## [method goal_for] as it moves each hero, and [method animate] once a frame. Props are drawn
## under the darkness, like the monsters; the bar and the name over it, like the effects.
##
## A waiting prop out of the party's light carries a glint ([PropGlints]), so a quest waiting in
## the dark reads from across the level. In the party's light, or done, it has none.
##
## A side path's gate is worked the same way: while the party opens one
## ([method SideProps.worked_spot]) the worker stands beside it on the side the party came from,
## and the bar and the name show between it and the gate.

## A worker swung at the prop: a strike of the slow repeat.
signal worked(hero_id: int)

## Each quest's prop sheet.
const SHEETS: Dictionary[StringName, String] = {
	&"locked_chest": "res://assets/sprites/props/chest.png",
	&"stuck_door": "res://assets/sprites/props/door.png",
	&"hurt_wanderer": "res://assets/sprites/props/wanderer.png",
	&"rune_stone": "res://assets/sprites/props/stone.png",
	&"tripwire": "res://assets/sprites/props/wire.png",
}
## What happened, in a few words, when each quest is done.
const DONE_WORDS: Dictionary[StringName, String] = {
	&"locked_chest": "Chest opened",
	&"stuck_door": "Door forced",
	&"hurt_wanderer": "Wanderer mended",
	&"rune_stone": "Runes read",
	&"tripwire": "Trap disarmed",
}
## The quest that walks off once done, and the one whose runes light as it is worked.
const WANDERER: StringName = &"hurt_wanderer"
const STONE: StringName = &"rune_stone"
## Pixels between a worker's feet and the prop's middle: the lead stands just short of it.
const WORK_GAP: float = 11.0
## Seconds between a worker's swings, and each swing's wind-up.
const SWING_SECONDS: float = 0.8
const SWING_WINDUP: float = 0.2
## Seconds between one worker's swings and the next worker's, so they do not strike together.
const SWING_OFFSET: float = 0.27
## Closer than this many pixels to its place, a worker has arrived and starts to swing.
const ARRIVED: float = 2.0
## The progress bar: its size, and how far above the floor its top sits, in pixels (over the
## heads of the workers and of the tallest prop).
const BAR_SIZE: Vector2 = Vector2(20, 4)
const BAR_RAISE: float = 36.0
## Pixels between the microskill's name (its baseline) and the bar under it.
const NAME_GAP: float = 4.0
## Pixels between the top of a gate being worked and the bar over it.
const OVER_GATE: float = 4.0
## Seconds for one swell of a prop's glint.
const GLINT_PERIOD: float = PropGlints.PERIOD
## A room whose open floor is narrower than this many tiles keeps its prop at the middle; a
## prop stands at least WALL_TILES from either wall of a wider one.
const NARROW_TILES: int = 6
const WALL_TILES: int = 2
## How far across its floor a prop stands, the way the course runs through the room.
const ACROSS: float = 2.0 / 3.0
## Seconds a mended wanderer stands before it walks off, and between its steps.
const STAND_SECONDS: float = 0.6
const STEP_SECONDS: float = 0.15
## The rune overlays of a stone, one more lit for each quarter of the work.
const RUNES: int = 4
## The pixel size of the times sign drawn after the name when several work.
## The times sign in [method worker_label]'s text. It is never drawn with the font, which has
## no glyph for it: [method _draw_overlay] draws a cross.
const TIMES: String = "\u00d7"
const TIMES_SIZE: int = 3

var _world: World
var _simulation: Simulation
## The props of waiting quests, and of done ones, by Vector2i(depth, chamber index).
var _props: Dictionary[Vector2i, Shown] = {}
var _done: Dictionary[Vector2i, Shown] = {}
## The sprites of [member _props], for the glints.
var _waiting: Dictionary[Vector2i, Sprite2D] = {}
## Props a scan took away this frame: kept until [method animate] in case a QUEST_DONE heard in
## the same frame makes one done.
var _dropped: Dictionary[Vector2i, Shown] = {}
## Each chamber's prop's place, worked out once.
var _spots: Dictionary[Vector2i, Vector2] = {}
## The bar and the name, over the darkness.
var _overlay: Node2D
## Seconds to the gate opener's next swing.
var _swing_in: float = 0.0
## Seconds the quest being worked has been worked, and each worker's last swing (its place in
## the slow repeat), by hero id.
var _work_clock: float = 0.0
var _swung: Dictionary[int, int] = {}
## The bar's fraction (-1 when none shows), where it is, and the name, where it is and how many
## work under it.
var _bar: float = -1.0
var _bar_at: Vector2 = Vector2.ZERO
var _name: String = ""
var _name_at: Vector2 = Vector2.ZERO
var _skill: String = ""
var _skill_width: int = 0
var _count: int = 0
## The glints of the props out of the party's light.
var _glints: PropGlints


## Call once, before the first scan.
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	_overlay = Node2D.new()
	_overlay.name = "WorkOverlay"
	_overlay.z_index = World.EFFECTS_Z
	_overlay.z_as_relative = false
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_glints = PropGlints.new()
	add_child(_glints)
	_glints.setup(world)
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## The prop of the quest waiting in that chamber, or null.
func prop(depth: int, chamber_index: int) -> Sprite2D:
	var shown: Shown = _props.get(Vector2i(depth, chamber_index), null)
	return shown.sprite if shown != null else null


## How many props of waiting quests are shown.
func prop_count() -> int:
	return _props.size()


## The part a chamber's prop shows now (&"locked", &"open", &"hurt", ...), or &"" with none.
func part_of(depth: int, chamber_index: int) -> StringName:
	var shown: Shown = _shown_at(Vector2i(depth, chamber_index))
	return shown.part if shown != null else &""


## True while that chamber shows a done prop; the wanderer while it walks off.
func is_done(depth: int, chamber_index: int) -> bool:
	return _done.has(Vector2i(depth, chamber_index))


## How that chamber's prop looks ([QuestLooks]), or null with none.
func looks_of(depth: int, chamber_index: int) -> QuestLooks:
	var shown: Shown = _shown_at(Vector2i(depth, chamber_index))
	return shown.looks if shown != null else null


## The rune overlay lit over that chamber's stone (&"rune_1" to &"rune_4"), or &"" with none.
func overlay_of(depth: int, chamber_index: int) -> StringName:
	var shown: Shown = _shown_at(Vector2i(depth, chamber_index))
	if shown == null or shown.runes == null or not shown.runes.visible:
		return &""
	return StringName(shown.runes.name.to_lower())


## The sprites of the dressing round that chamber's prop.
func dressing_of(depth: int, chamber_index: int) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	var shown: Shown = _shown_at(Vector2i(depth, chamber_index))
	if shown != null and shown.dressing != null:
		for child: Node in shown.dressing.get_children():
			found.append(child as Sprite2D)
	return found


## The sparkle part glinting on that chamber's prop now ([code]&"small"[/code] or
## [code]&"big"[/code]), or [code]&""[/code] when it has none: in the party's light, between two
## pulses, or with no prop at all.
func glint_part(depth: int, chamber_index: int) -> StringName:
	return _glints.part(Vector2i(depth, chamber_index))


## True when that chamber's prop is out of the party's light, so it carries a glint (which may be
## between two pulses).
func is_glinting(depth: int, chamber_index: int) -> bool:
	return _glints.in_the_dark(prop(depth, chamber_index))


## The bar's fraction while the party works (the work's progress), or -1 when no bar shows.
func bar_fraction() -> float:
	return _bar


## The microskill's name over the work, with a times sign and N after it when N work, or "" when nobody works.
func worker_label() -> String:
	return _name


## Where a quest's prop stands in that chamber, in world pixels ([method spot_in]).
func spot(depth: int, chamber_index: int) -> Vector2:
	var key := Vector2i(depth, chamber_index)
	if not _spots.has(key):
		_spots[key] = spot_in(_world.labyrinth_view, depth, chamber_index)
	return _spots[key]


## Where a quest's prop stands in chamber [param chamber_index] of stage [param depth] as
## [param view] draws it, in world pixels: on the room's floor line, two-thirds of the way
## across its open floor the way the stage's course runs through the room, and at least
## WALL_TILES from either wall; at the middle of a floor narrower than NARROW_TILES. The props and
## the ambience's clearings both ask this, so they cannot disagree.
static func spot_in(view: LabyrinthView, depth: int, chamber_index: int) -> Vector2:
	var level: LabyrinthLevel = view.labyrinth.level(depth)
	var room: LabyrinthChamber = level.chambers[chamber_index]
	var walls: Vector2i = _open_floor(view, depth, room)
	var floor_y: float = WorldPlaces.floor_line(room)
	var width: int = walls.y - walls.x
	if width < NARROW_TILES:
		return Vector2(floorf((walls.x + walls.y) / 2.0) * World.TILE, floor_y)
	var middle: float = (walls.x + walls.y) / 2.0
	var heading: int = level.course.heading_at(level.course.distance_in(room.index, middle))
	var left: float = walls.x * World.TILE
	var right: float = walls.y * World.TILE
	var x: float = left + (right - left) * ACROSS
	if heading < 0:
		x = right - (right - left) * ACROSS
	x = clampf(roundf(x), left + WALL_TILES * World.TILE, right - WALL_TILES * World.TILE)
	return Vector2(x, floor_y)


## The left and right walls of that chamber's open floor, in world pixels.
static func floor_span(view: LabyrinthView, depth: int, chamber_index: int) -> Vector2:
	var room: LabyrinthChamber = view.labyrinth.level(depth).chambers[chamber_index]
	var walls: Vector2i = _open_floor(view, depth, room)
	return Vector2(walls) * World.TILE


## How the prop of [param quest] looks in that chamber as [param view] draws it.
static func looks_in(
	view: LabyrinthView, depth: int, chamber_index: int, quest: StringName
) -> QuestLooks:
	return QuestLooks.choose(
		view.area,
		depth,
		chamber_index,
		quest,
		spot_in(view, depth, chamber_index),
		floor_span(view, depth, chamber_index)
	)


## The chamber the party is in, as Vector2i(depth, index); index -1 in a tunnel.
func party_chamber() -> Vector2i:
	var expedition: Expedition = _simulation.expedition
	var here: LabyrinthChamber = expedition.chamber()
	return Vector2i(expedition.depth, here.index if here != null else -1)


## The sheet of [param quest]'s prop, or null for a quest with none.
static func sheet_of(quest: StringName) -> PixelSheet:
	if not SHEETS.has(quest):
		return null
	return PixelSheet.load_sheet(SHEETS[quest])


## Takes every prop away when the party arrives in another area; [method scan] gives the new
## area's chambers theirs.
func clear() -> void:
	for table: Dictionary[Vector2i, Shown] in [_props, _done, _dropped]:
		for key: Vector2i in table.keys():
			_free(table[key])
		table.clear()
	_waiting.clear()
	_spots.clear()


## Gives every chamber of [param built] that holds a quest its prop, and takes away the
## props of those that do not. A done prop goes once its room holds something again.
func scan(built: Array[int]) -> void:
	var wanted: Dictionary[Vector2i, StringName] = {}
	var expedition: Expedition = _simulation.expedition
	for depth: int in built:
		var level: LabyrinthLevel = _simulation.labyrinth.level(depth)
		for chamber_index: int in level.chambers.size():
			var quest: StringName = expedition.quest_in(depth, chamber_index)
			if quest != &"":
				wanted[Vector2i(depth, chamber_index)] = quest
	for key: Vector2i in _done.keys():
		if wanted.has(key) or expedition.is_populated(key.x, key.y):
			_free(_done[key])
			_done.erase(key)
	for key: Vector2i in _props.keys():
		if not wanted.has(key) or _props[key].sprite.name != String(wanted[key]):
			if _dropped.has(key):
				_free(_dropped[key])
			_dropped[key] = _props[key]
			_props.erase(key)
			_waiting.erase(key)
	for key: Vector2i in wanted:
		if not _props.has(key):
			_add(key, wanted[key])


## Where hero [param id] is heading this frame: beside the gate for its opener (on the side the
## party came from), [param goal] (where the simulation has it) for everyone else. The workers of
## a quest are [QuestStage]'s.
func goal_for(id: int, goal: Vector2) -> Vector2:
	var gate: Vector2 = _gate_worked()
	if not gate.is_finite() or id != _simulation.expedition.worker_id():
		return goal
	return Vector2(gate.x - _world.side_props.worked_side() * WORK_GAP, gate.y)


## Lets go of the props taken away this frame, moves the done ones on, swings the workers once
## they are at their spots, and brings the runes, the bar and the name up to date.
func animate(delta: float) -> void:
	for key: Vector2i in _dropped:
		_free(_dropped[key])
	_dropped.clear()
	_glints.pulse(delta, _waiting)
	_advance_done(delta)
	var gate: Vector2 = _gate_worked()
	if gate.is_finite():
		_work_clock = 0.0
		_swung.clear()
		_open_gate(delta, gate)
		return
	_swing_in = 0.0
	var key: Vector2i = party_chamber()
	var working: Shown = _props.get(key, null) if _world.quest_stage.is_working() else null
	if working == null:
		_work_clock = 0.0
		_swung.clear()
		_set_overlay(-1.0, "")
		return
	_work_clock += delta
	var workers: Array[int] = _world.quest_stage.workers()
	for rank: int in workers.size():
		_swing(workers[rank], rank)
	var progress: float = _simulation.expedition.work_progress()
	_light_runes(working, progress)
	var at: Vector2 = working.sprite.position
	_bar_at = Vector2(at.x - floorf(BAR_SIZE.x / 2.0), at.y - BAR_RAISE)
	_name_at = Vector2(at.x, _bar_at.y - NAME_GAP)
	_set_overlay(progress, _work_name(false), workers.size())


## The worker of rank [param rank] swings on the slow repeat, offset by its rank, once it has
## arrived at its spot. A worker still walking lets its turns pass.
func _swing(id: int, rank: int) -> void:
	var worker: CharacterSprite = _world.character(id)
	var from: float = _work_clock - rank * SWING_OFFSET
	if worker == null or worker.is_dead() or from < 0.0:
		return
	var turn: int = floori(from / SWING_SECONDS)
	if _swung.get(id, -1) >= turn:
		return
	_swung[id] = turn
	var place: Vector2 = _world.quest_stage.goal_for(id, worker.position)
	if worker.position.distance_to(place) > ARRIVED:
		return
	var hero: Hero = _simulation.party.hero(id)
	var ranged: bool = hero != null and hero.def().attack_range > Battle.MELEE_REACH
	worker.play_attack(SWING_WINDUP, ranged)
	worked.emit(id)


## The opener swings at the gate once beside it, and the bar and the name show between them.
func _open_gate(delta: float, gate: Vector2) -> void:
	var opener_id: int = _simulation.expedition.worker_id()
	var opener: CharacterSprite = _world.character(opener_id) if opener_id >= 0 else null
	if opener == null or opener.is_dead():
		_swing_in = 0.0
		_set_overlay(-1.0, "")
		return
	var place: Vector2 = goal_for(opener_id, opener.position)
	if opener.position.distance_to(place) <= ARRIVED:
		_swing_in -= delta
		if _swing_in <= 0.0:
			_swing_in = SWING_SECONDS
			var hero: Hero = _simulation.party.hero(opener_id)
			var ranged: bool = hero != null and hero.def().attack_range > Battle.MELEE_REACH
			opener.play_attack(SWING_WINDUP, ranged)
			worked.emit(opener_id)
	var raise: float = maxf(BAR_RAISE, _world.side_props.worked_height() + OVER_GATE)
	var middle: float = floorf((gate.x + place.x) / 2.0)
	_bar_at = Vector2(middle - floorf(BAR_SIZE.x / 2.0), gate.y - raise)
	_name_at = Vector2(middle, _bar_at.y - NAME_GAP)
	_set_overlay(_simulation.expedition.work_progress(), _work_name(true), 1)


## A stone being read lights one more rune for each quarter of the work.
func _light_runes(working: Shown, progress: float) -> void:
	if working.runes == null:
		return
	var lit: int = mini(floori(progress * RUNES), RUNES)
	working.runes.visible = lit > 0
	if lit > 0:
		var part := StringName("rune_%d" % lit)
		if working.runes.name != String(part):
			working.runes.name = String(part)
			var sheet: PixelSheet = sheet_of(STONE)
			working.runes.texture = sheet.part(working.looks.part_name(part))


## Moves the done props on: a mended wanderer stands, then walks off the way the party came and
## goes once out of its room. A done prop on a stage the world no longer shows goes.
func _advance_done(delta: float) -> void:
	for key: Vector2i in _done.keys():
		var shown: Shown = _done[key]
		if key.x != _world.shown_stage():
			_free(shown)
			_done.erase(key)
			continue
		if shown.way == 0:
			continue
		shown.since += delta
		if shown.since < STAND_SECONDS:
			continue
		var walked: float = shown.since - STAND_SECONDS
		var step: int = floori(walked / STEP_SECONDS) % 2
		_show_part(shown, StringName("walk_%d" % step))
		shown.sprite.flip_h = shown.way < 0
		shown.sprite.position.x += shown.way * World.WALK_SPEED * delta * maxi(_world.speed, 1)
		var x: float = shown.sprite.position.x
		if x < shown.room.x or x > shown.room.y:
			_free(shown)
			_done.erase(key)


func _on_sim_event(event: SimEvent) -> void:
	if event.kind != SimEvent.Kind.QUEST_DONE:
		return
	var ids: Array[StringName] = Content.quest_ids()
	if event.target_id < 0 or event.target_id >= ids.size():
		return
	var quest: StringName = ids[event.target_id]
	var key: Vector2i = _done_key(quest)
	if key.y < 0:
		return
	var shown: Shown = _props.get(key, null)
	if shown != null:
		_props.erase(key)
		_waiting.erase(key)
	else:
		shown = _dropped[key]
		_dropped.erase(key)
	if _done.has(key):
		_free(_done[key])
	if shown.runes != null:
		shown.runes.visible = false
	_show_part(shown, QuestLooks.DONE[quest])
	if quest == WANDERER:
		if not _world.may_animate(event):
			_free(shown)  # a late mending: the wanderer has long gone
			return
		shown.way = -PartyPlaces.world_facing(_simulation.expedition)
		shown.since = 0.0
	_done[key] = shown


## The chamber whose prop of [param quest] was just done: the party's, else one whose quest has
## been cleared; Vector2i(0, -1) with none.
func _done_key(quest: StringName) -> Vector2i:
	var here: Vector2i = party_chamber()
	for table: Dictionary[Vector2i, Shown] in [_props, _dropped]:
		if table.has(here) and table[here].looks.quest == quest:
			return here
	var expedition: Expedition = _simulation.expedition
	for table: Dictionary[Vector2i, Shown] in [_props, _dropped]:
		for key: Vector2i in table:
			if table[key].looks.quest == quest and expedition.quest_in(key.x, key.y) == &"":
				return key
	return Vector2i(0, -1)


## Where the gate the party is working at stands, or [constant Vector2.INF] with none.
func _gate_worked() -> Vector2:
	return _world.side_props.worked_spot() if _world.side_props != null else Vector2.INF


## The name of the microskill at work: the gate's ([param at_gate]) or the quest's.
func _work_name(at_gate: bool) -> String:
	if at_gate:
		return _world.side_props.worked_name()
	var quest: QuestDef = Content.quest(_simulation.expedition.working_quest())
	var skill: MicroskillDef = Content.microskill(quest.microskill) if quest != null else null
	return skill.display_name if skill != null else ""


func _shown_at(key: Vector2i) -> Shown:
	var shown: Shown = _props.get(key, null)
	return shown if shown != null else _done.get(key, null)


func _add(key: Vector2i, quest: StringName) -> void:
	var sheet: PixelSheet = sheet_of(quest)
	if sheet == null:
		return
	var view: LabyrinthView = _world.labyrinth_view
	var at: Vector2 = spot(key.x, key.y)
	var shown := Shown.new()
	shown.looks = QuestLooks.choose(
		view.area, key.x, key.y, quest, at, floor_span(view, key.x, key.y)
	)
	var room: LabyrinthChamber = _simulation.labyrinth.level(key.x).chambers[key.y]
	shown.room = Vector2(room.rect.position.x, room.rect.end.x) * World.TILE
	var made := Sprite2D.new()
	made.name = String(quest)
	made.centered = false
	# The pivot pixel (the bottom centre) sits just above the floor line, as a character's feet do.
	made.offset = -Vector2(sheet.pivot) - Vector2(0, 1)
	made.position = at
	made.flip_h = shown.looks.mirrored
	made.material = shown.looks.material()
	shown.sprite = made
	var waiting: StringName = QuestLooks.WAITING.get(quest, &"")
	_show_part(shown, waiting)
	if quest == STONE:
		var runes := Sprite2D.new()
		runes.name = "rune_0"
		runes.centered = false
		runes.offset = made.offset
		runes.flip_h = made.flip_h
		runes.visible = false
		made.add_child(runes)
		shown.runes = runes
	shown.dressing = _dress(shown.looks, at)
	add_child(shown.dressing)
	add_child(made)
	_props[key] = shown
	_waiting[key] = made


## The pieces of dressing [param looks] lays round a prop standing at [param at].
func _dress(looks: QuestLooks, at: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.name = "Dressing"
	holder.position = at
	var sheet: PixelSheet = PixelSheet.load_sheet(QuestLooks.DRESSING_SHEET)
	if sheet == null:
		return holder
	for i: int in looks.dressing.size():
		var piece := Sprite2D.new()
		piece.name = "%s_%d" % [looks.dressing[i], i]
		piece.texture = sheet.part(looks.dressing[i])
		piece.centered = false
		piece.offset = -Vector2(sheet.pivot) - Vector2(0, 1)
		piece.position = Vector2(looks.dressing_at[i], 0.0)
		holder.add_child(piece)
	return holder


## Shows [param state]'s part of the prop's look.
func _show_part(shown: Shown, state: StringName) -> void:
	if shown.part == state:
		return
	shown.part = state
	var sheet: PixelSheet = sheet_of(shown.looks.quest)
	shown.sprite.texture = sheet.part(shown.looks.part_name(state))


func _free(shown: Shown) -> void:
	if is_instance_valid(shown.dressing):
		shown.dressing.free()
	if is_instance_valid(shown.sprite):
		shown.sprite.free()


## The left and right walls of [param room]'s floor as drawn, in world columns: the run of open
## tiles along its floor row through its middle.
static func _open_floor(view: LabyrinthView, depth: int, room: LabyrinthChamber) -> Vector2i:
	var rect: Rect2i = room.rect
	var stage: StageShapes = view.shapes(depth) if view != null else null
	var shape: RoomShape = stage.shape_of(room) if stage != null else null
	if shape == null:
		return Vector2i(rect.position.x, rect.end.x)
	var row: int = room.floor_row()
	var middle: int = (rect.position.x + rect.end.x) / 2
	var left: int = middle
	var right: int = middle
	while left > rect.position.x and shape.is_open(Vector2i(left - 1, row)):
		left -= 1
	while right < rect.end.x and shape.is_open(Vector2i(right, row)):
		right += 1
	return Vector2i(left, right)


func _set_overlay(fraction: float, words: String, count: int = 0) -> void:
	if fraction < 0.0 and _bar < 0.0:
		return
	_bar = fraction
	if words != _skill or count != _count:
		_skill = words
		_count = count
		_skill_width = PixelText.width(words)
		_name = words if count < 2 or words.is_empty() else "%s %s%d" % [words, TIMES, count]
	if fraction < 0.0:
		_name = ""
		_skill = ""
		_count = 0
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if _bar < 0.0:
		return
	var ink: Color = Palette.color(&"ink")
	var box := Rect2(_bar_at, BAR_SIZE)
	_overlay.draw_rect(box, ink)
	var inside: Rect2 = box.grow(-1.0)
	_overlay.draw_rect(inside, Palette.color(&"dark_brown"))
	var filled: float = roundf(inside.size.x * clampf(_bar, 0.0, 1.0))
	if filled > 0.0:
		_overlay.draw_rect(
			Rect2(inside.position, Vector2(filled, inside.size.y)), Palette.color(&"amber")
		)
	if _skill.is_empty():
		return
	# The pixel font has no times sign: it is a small drawn cross before the number.
	var count: String = str(_count) if _count >= 2 else ""
	var space: int = PixelText.width(" ") if _count >= 2 else 0
	var tail: int = space + TIMES_SIZE + 1 + PixelText.width(count) if _count >= 2 else 0
	var width: int = _skill_width + tail
	var left := Vector2(_name_at.x - floorf(width / 2.0), _name_at.y)
	var shadow := Vector2(PixelText.SHADOW_OFFSET, PixelText.SHADOW_OFFSET)
	var amber: Color = Palette.color(&"amber")
	for layer: int in 2:
		var at: Vector2 = left + (shadow if layer == 0 else Vector2.ZERO)
		var colour: Color = ink if layer == 0 else amber
		_overlay.draw_string(
			PixelText.font(), at, _skill, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelText.SIZE, colour
		)
		if count.is_empty():
			continue
		var cross := Vector2(at.x + _skill_width + space, at.y - TIMES_SIZE - 1)
		for i: int in TIMES_SIZE:
			_overlay.draw_rect(Rect2(cross + Vector2(i, i), Vector2.ONE), colour)
			_overlay.draw_rect(Rect2(cross + Vector2(TIMES_SIZE - 1 - i, i), Vector2.ONE), colour)
		var number := Vector2(cross.x + TIMES_SIZE + 1, at.y)
		_overlay.draw_string(
			PixelText.font(), number, count, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelText.SIZE, colour
		)


## One prop on show, waiting or done.
class Shown:
	extends RefCounted
	var sprite: Sprite2D
	## The dressing round it, and the runes lit over a stone.
	var dressing: Node2D
	var runes: Sprite2D
	var looks: QuestLooks
	## The state it shows (&"locked", &"open", ...).
	var part: StringName = &""
	## For a mended wanderer: seconds since it was mended, and the way it walks off (0: it
	## does not).
	var since: float = 0.0
	var way: int = 0
	## The room's left and right walls, in world pixels.
	var room: Vector2 = Vector2.ZERO

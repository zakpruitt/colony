class_name QuestProps
extends Node2D
## The quests waiting in the labyrinth, and the work on one. Each chamber of a
## built level that holds a quest ([method Expedition.quest_in]) shows its prop on the
## floor near its middle, as far away as monsters are shown; a cleared quest's prop goes until the
## chamber refills. While the party works a quest, the worker stands at the prop and swings on a
## slow repeat (emitting [signal worked] each time), a small bar over the prop fills with
## [method Expedition.work_progress], and the microskill's name shows over the worker.
##
## A child of [World], which calls [method scan] whenever it looks for waiting monsters,
## [method goal_for] as it moves each hero, and [method animate] once a frame. Props are drawn
## under the darkness, like the monsters; the bar and the name over it, like the effects.
##
## A prop out of the party's light carries a glint ([PropGlints]), so a quest waiting in the
## dark reads from across the level. In the party's light it has none.
##
## A side path's gate is worked the same way: while the party opens one
## ([method SideProps.worked_spot]) the worker stands beside it on the side the party came from,
## and the bar and the name show over it.

## The worker swung at the prop: a strike of the slow repeat.
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
## Pixels between the worker's feet and the prop's middle: the worker stands just short of it.
const WORK_GAP: float = 11.0
## Seconds between the worker's swings, and each swing's wind-up.
const SWING_SECONDS: float = 0.8
const SWING_WINDUP: float = 0.2
## Closer than this many pixels to its place, the worker has arrived and starts to swing.
const ARRIVED: float = 2.0
## The progress bar: its size, and how far above the floor its top sits, in pixels (over the
## heads of the worker and of the tallest prop).
const BAR_SIZE: Vector2 = Vector2(20, 4)
const BAR_RAISE: float = 36.0
## Pixels between the microskill's name (its baseline) and the bar under it.
const NAME_GAP: float = 4.0
## Pixels between the top of a gate being worked and the bar over it.
const OVER_GATE: float = 4.0
## Seconds for one swell of a prop's glint.
const GLINT_PERIOD: float = PropGlints.PERIOD

var _world: World
var _simulation: Simulation
## The prop of each chamber holding a quest, by Vector2i(depth, chamber index).
var _props: Dictionary[Vector2i, Sprite2D] = {}
## The bar and the name, over the darkness.
var _overlay: Node2D
## Seconds to the worker's next swing.
var _swing_in: float = 0.0
## The bar's fraction (-1 when none shows), where it is, and the name and where it is.
var _bar: float = -1.0
var _bar_at: Vector2 = Vector2.ZERO
var _name: String = ""
var _name_at: Vector2 = Vector2.ZERO
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


## The prop waiting in that chamber, or null.
func prop(depth: int, chamber_index: int) -> Sprite2D:
	return _props.get(Vector2i(depth, chamber_index), null)


## How many props are shown.
func prop_count() -> int:
	return _props.size()


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


## The microskill's name over the worker, or "" when nobody works.
func worker_label() -> String:
	return _name


## Where a quest's prop stands in that chamber: the middle of its own floor, in world
## pixels.
func spot(depth: int, chamber_index: int) -> Vector2:
	var level: LabyrinthLevel = _simulation.labyrinth.level(depth)
	var room: LabyrinthChamber = level.chambers[chamber_index]
	var middle: float = floorf((room.rect.position.x + room.rect.end.x) / 2.0)
	return Vector2(middle * World.TILE, WorldPlaces.floor_line(room))


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
	for key: Vector2i in _props.keys():
		_props[key].free()
		_props.erase(key)


## Gives every chamber of [param built] that holds a quest its prop, and takes away the
## props of those that do not.
func scan(built: Array[int]) -> void:
	var wanted: Dictionary[Vector2i, StringName] = {}
	var expedition: Expedition = _simulation.expedition
	for depth: int in built:
		var level: LabyrinthLevel = _simulation.labyrinth.level(depth)
		for chamber_index: int in level.chambers.size():
			var quest: StringName = expedition.quest_in(depth, chamber_index)
			if quest != &"":
				wanted[Vector2i(depth, chamber_index)] = quest
	for key: Vector2i in _props.keys():
		if not wanted.has(key) or _props[key].name != String(wanted[key]):
			_props[key].free()
			_props.erase(key)
	for key: Vector2i in wanted:
		if not _props.has(key):
			_add(key, wanted[key])


## Where hero [param id] is heading this frame: the work spot for the worker (short of the prop
## or the gate, on the side the party came from), [param goal] (where the simulation has it) for
## everyone else.
func goal_for(id: int, goal: Vector2) -> Vector2:
	var expedition: Expedition = _simulation.expedition
	if id != expedition.worker_id():
		return goal
	var gate: Vector2 = _gate_worked()
	if gate.is_finite():
		return Vector2(gate.x - _world.side_props.worked_side() * WORK_GAP, gate.y)
	var key: Vector2i = party_chamber()
	if key.y < 0:
		return goal
	var at: Vector2 = spot(key.x, key.y)
	return Vector2(at.x - PartyPlaces.world_facing(expedition) * WORK_GAP, at.y)


## Swings the worker once it is at the prop or the gate, and brings the bar and the name up to
## date.
func animate(delta: float) -> void:
	_glints.pulse(delta, _props)
	var expedition: Expedition = _simulation.expedition
	var worker_id: int = expedition.worker_id()
	var worker: CharacterSprite = _world.character(worker_id) if worker_id >= 0 else null
	var gate: Vector2 = _gate_worked()
	var key: Vector2i = party_chamber()
	var waiting: Sprite2D = prop(key.x, key.y)
	if worker == null or worker.is_dead() or (waiting == null and not gate.is_finite()):
		_swing_in = 0.0
		_set_overlay(-1.0, "")
		return
	var place: Vector2 = goal_for(worker_id, worker.position)
	if worker.position.distance_to(place) <= ARRIVED:
		_swing_in -= delta
		if _swing_in <= 0.0:
			_swing_in = SWING_SECONDS
			var hero: Hero = _simulation.party.hero(worker_id)
			var ranged: bool = hero != null and hero.def().attack_range > Battle.MELEE_REACH
			worker.play_attack(SWING_WINDUP, ranged)
			worked.emit(worker_id)
	# Over the heads, between the worker and what it works at: the name, and the bar under it.
	var at: Vector2 = gate if gate.is_finite() else waiting.position
	var raise: float = BAR_RAISE
	if gate.is_finite():
		raise = maxf(raise, _world.side_props.worked_height() + OVER_GATE)
	var middle: float = floorf((at.x + place.x) / 2.0)
	_bar_at = Vector2(middle - floorf(BAR_SIZE.x / 2.0), at.y - raise)
	_name_at = Vector2(middle, _bar_at.y - NAME_GAP)
	_set_overlay(expedition.work_progress(), _work_name(gate.is_finite()))


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


func _add(key: Vector2i, quest: StringName) -> void:
	var sheet: PixelSheet = sheet_of(quest)
	if sheet == null:
		return
	var part: StringName = StringName(sheet.part_names[0])
	var made := Sprite2D.new()
	made.name = String(quest)
	made.texture = sheet.part(part)
	made.centered = false
	# The pivot pixel (the bottom centre) sits just above the floor line, as a character's feet do.
	made.offset = -Vector2(sheet.part_pivot(part)) - Vector2(0, 1)
	made.position = spot(key.x, key.y)
	add_child(made)
	_props[key] = made


func _set_overlay(fraction: float, words: String) -> void:
	if fraction < 0.0 and _bar < 0.0:
		return
	_bar = fraction
	_name = words
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
	if _name.is_empty():
		return
	var font: Font = PixelText.font()
	var width: int = PixelText.width(_name)
	var left := Vector2(_name_at.x - floorf(width / 2.0), _name_at.y)
	var shadow := Vector2(PixelText.SHADOW_OFFSET, PixelText.SHADOW_OFFSET)
	_overlay.draw_string(
		font, left + shadow, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelText.SIZE, ink
	)
	var colour: Color = Palette.color(&"amber")
	_overlay.draw_string(font, left, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelText.SIZE, colour)

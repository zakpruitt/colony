class_name ResourceEffects
extends Node
## Resource drops on screen (spec 052 R8), as gold's coins are: each
## [constant SimEvent.Kind.RESOURCE_GAINED] still recent puts a few [FxResource] icons where the
## monster fell (or over the hero who finished a side quest), which rise, hang and fly to the
## resource's place beside the gold, and each one's share is counted in as it arrives
## ([signal resource_collected]). A drop too old to animate is counted in at once.
##
## [CombatEffects] makes it and advances it; it draws on [member World.effects_layer].

## One icon has reached its place: [param index] is the resource's position in
## [method Content.resource_ids], [param amount] the icon's share.
signal resource_collected(index: int, amount: int)

## A drop of this many or more shows this many icons; fewer, one icon each.
const ICONS_MAX: int = 5
## Pixels above a fallen monster's feet the icons start, and between them across.
const START_RAISE: float = 10.0
const SPREAD: float = 5.0

## Where each resource's icons fly to, in screen pixels, by its position in
## [method Content.resource_ids]; the HUD sets it. One with no place flies to
## [member fallback_target].
var targets: Dictionary[int, Vector2] = {}
var fallback_target: Vector2 = Vector2(600, 12)

var _world: World
## Turns a screen pixel into the world pixel under it, through the world's camera.
var _to_world: Callable
var _icons: Array[FxResource] = []
## Where each character that fell lately stood, by id: a monster's sprite may be gone by the time
## its drop is heard.
var _fallen_at: Dictionary[int, Vector2] = {}


func _init() -> void:
	name = "ResourceEffects"


## Call once, before the first advance. [param to_world] turns a screen pixel into the world
## pixel under it ([CombatEffects] gives its own).
func setup(world: World, to_world: Callable) -> void:
	_world = world
	_to_world = to_world
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)


## Moves every icon on by [param delta] seconds. Called by [CombatEffects]; tests call it.
func advance(delta: float) -> void:
	if _world == null:
		return
	_fallen_at.clear()
	for icon: FxResource in _icons.duplicate():
		var screen: Vector2 = targets.get(icon.index, fallback_target)
		var target: Vector2 = _to_world.call(screen) if _to_world.is_valid() else screen
		if icon.advance(delta, target):
			_icons.erase(icon)
			icon.queue_free()
			resource_collected.emit(icon.index, icon.share)


## The icons on their way.
func live_icons() -> Array[FxResource]:
	return _icons.duplicate()


## How many icons a drop of [param amount] shows: one each, at most [constant ICONS_MAX].
static func icon_count(amount: int) -> int:
	return clampi(amount, 1, ICONS_MAX)


func _on_sim_event(event: SimEvent) -> void:
	if event.kind == SimEvent.Kind.DIED:
		_fallen_at[event.source_id] = _world.feet_position(event.source_id)
		return
	if event.kind != SimEvent.Kind.RESOURCE_GAINED:
		return
	if not _world.is_recent(event) or _world.effects_layer == null:
		resource_collected.emit(event.target_id, event.amount)
		return
	var feet: Vector2 = _world.feet_position(event.source_id)
	if feet == Vector2.ZERO:
		feet = _fallen_at.get(event.source_id, Vector2.ZERO)
	if feet == Vector2.ZERO:
		resource_collected.emit(event.target_id, event.amount)
		return
	var count: int = icon_count(event.amount)
	for i: int in count:
		var icon := FxResource.new(
			event.target_id, CombatEffects.coin_share(event.amount, count, i)
		)
		icon.name = "Resource"
		var across: float = (i - (count - 1) / 2.0) * SPREAD
		icon.start(feet + Vector2(across, -START_RAISE).round())
		_world.effects_layer.add_child(icon)
		_icons.append(icon)

class_name ResourcePurse
extends Control
## The party's resources beside its gold (spec 052 R3): an icon and a count for each resource it
## holds, in [method Content.resource_ids] order; one it has none of is not shown. It sits in the
## HUD's gold panel, after the gold, and the panel widens to hold it.
##
## The counts tick up as gold's does (R8): a drop's icons ([ResourceEffects]) count in as they
## arrive, a count still behind catches up [constant CATCH_UP_SECONDS] after the last arrival,
## and a count above the party's (an upgrade paid for) drops to it at once. Resting the mouse on a
## count says what it is and where it comes from. It moves only in [method advance], so a test can
## step it.

## Seconds after the last icon before a count that is still behind catches up.
const CATCH_UP_SECONDS: float = 3.0
## Pixels between the icon and its count, and between one resource and the next.
const ICON_GAP: float = 2.0
const ENTRY_GAP: float = 5.0
## Where the icons' tops sit, and the counts', in the panel.
const ICON_Y: float = 8.0
const COUNT_Y: float = 8.0

## Each resource's icon and count, by id, whether shown or not.
var icons: Dictionary[StringName, TextureRect] = {}
var labels: Dictionary[StringName, Label] = {}

var _simulation: Simulation
var _effects: ResourceEffects
var _shown: Dictionary[StringName, int] = {}
var _since_icon: float = 0.0


func _init() -> void:
	name = "ResourcePurse"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: StringName in Content.resource_ids():
		var icon: TextureRect = ResourceIcon.rect(id)
		icon.name = "Icon_%s" % id
		add_child(icon)
		icons[id] = icon
		var label: Label = PixelText.label("", &"white")
		label.name = "Count_%s" % id
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		labels[id] = label


## Call once, before the first advance. [param effects] may be null (no icons fly then).
func setup(simulation: Simulation, effects: ResourceEffects) -> void:
	_simulation = simulation
	_effects = effects
	for id: StringName in Content.resource_ids():
		_shown[id] = simulation.party.resource(id)
	if effects != null and not effects.resource_collected.is_connected(_on_collected):
		effects.resource_collected.connect(_on_collected)
	advance(0.0)


## Gives each count its tooltip. Call once the HUD's tooltips exist.
func add_tips(tooltip: HudTooltip) -> void:
	for id: StringName in Content.resource_ids():
		# First: the counts lie inside the gold panel, which has its own tooltip.
		tooltip.tip_first([icons[id], labels[id]], tip_text.bind(id))


## Brings the counts up to date and lays them out. Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	var behind: bool = false
	for id: StringName in Content.resource_ids():
		var held: int = _simulation.party.resource(id)
		if shown(id) > held:
			_shown[id] = held
		if shown(id) < held:
			behind = true
	if behind:
		_since_icon += delta
		if _since_icon >= CATCH_UP_SECONDS:
			for id: StringName in Content.resource_ids():
				_shown[id] = _simulation.party.resource(id)
	if not behind or _since_icon >= CATCH_UP_SECONDS:
		_since_icon = 0.0
	_lay_out()


## The count of resource [param id] on show.
func shown(id: StringName) -> int:
	return _shown.get(id, 0)


## The resources shown, in order: those the party holds.
func shown_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in Content.resource_ids():
		if icons[id].visible:
			ids.append(id)
	return ids


## Resource [param id]'s tooltip: [code]Clay: 3. Clay comes from the Claypits.[/code]
func tip_text(id: StringName) -> String:
	var held: int = _simulation.party.resource(id) if _simulation != null else 0
	return (
		"%s: %s. %s"
		% [
			ResourceIcon.title(id),
			Hud.group_thousands(held),
			ResourceIcon.where_from(_simulation, id)
		]
	)


## Where resource [param id]'s icon is on the screen, the middle of it: where drops fly to.
func target(id: StringName) -> Vector2:
	return icons[id].get_global_rect().get_center()


func _lay_out() -> void:
	var x: float = 0.0
	var ids: Array[StringName] = Content.resource_ids()
	for i: int in ids.size():
		var id: StringName = ids[i]
		var held: bool = _simulation.party.resource(id) > 0 or shown(id) > 0
		var icon: TextureRect = icons[id]
		var label: Label = labels[id]
		icon.visible = held
		label.visible = held
		if not held:
			continue
		var text: String = Hud.short_count(shown(id))
		if label.text != text:
			label.text = text
			label.reset_size()
		icon.position = Vector2(x, ICON_Y)
		label.position = Vector2(x + ResourceIcon.SIZE.x + ICON_GAP, COUNT_Y)
		x = label.position.x + label.size.x + ENTRY_GAP
		if _effects != null:
			_effects.targets[i] = target(id)
	size = Vector2(maxf(x - ENTRY_GAP, 0.0), Hud.TOP_HEIGHT)


func _on_collected(index: int, amount: int) -> void:
	var ids: Array[StringName] = Content.resource_ids()
	if index < 0 or index >= ids.size() or _simulation == null:
		return
	var id: StringName = ids[index]
	_shown[id] = mini(shown(id) + maxi(amount, 0), _simulation.party.resource(id))
	_since_icon = 0.0
	_lay_out()

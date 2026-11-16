class_name ShopPanel
extends Control
## The upgrade shop (spec 017): a panel below the HUD's top band, at the right under the gold, with
## one [ShopRow] per camp upgrade in shop order. It opens over the running game and never pauses
## it. Every frame it reads ranks, prices and gold from the simulation, so it cannot drift; buying
## goes through [method Simulation.buy_upgrade], and a row flashes on
## [constant SimEvent.Kind.UPGRADE_BOUGHT]. Opening it closes the "While you were away" panel
## ([AwayPanel]) if that is still up, so the two never overlap. Drawn as a [HudPanel] is.

## Space inside the border; the title's row height.
const PADDING: float = 4.0
const TITLE_HEIGHT: float = 13.0
## Pixels between the panel and the top band above it.
const DROP: float = 2.0

## One row per upgrade, in [method Content.upgrade_ids] order.
var rows: Array[ShopRow] = []
var title_label: Label
var hint_label: Label

var _simulation: Simulation
var _divider: ColorRect


func _init() -> void:
	name = "ShopPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _draw() -> void:
	HudPanel.draw_panel(
		self,
		Rect2(Vector2.ZERO, size),
		Palette.color(&"night"),
		Palette.color(&"dusk"),
		Palette.color(&"ink")
	)


## Call once, before the first advance. [param world] may be null (no flashes then).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	title_label = PixelText.label("Camp upgrades", &"yellow")
	title_label.name = "Title"
	title_label.position = Vector2(PADDING + 2.0, PADDING)
	add_child(title_label)
	hint_label = PixelText.label("1-5 buy   U close", &"slate")
	hint_label.name = "Hint"
	add_child(hint_label)
	_divider = ColorRect.new()
	_divider.name = "Divider"
	_divider.color = Palette.color(&"dusk")
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)
	var ids: Array[StringName] = Content.upgrade_ids()
	var y: float = PADDING + TITLE_HEIGHT + 2.0
	for i: int in ids.size():
		var row := ShopRow.new(ids[i], i)
		row.position = Vector2(PADDING, y)
		row.buy_button.pressed.connect(buy_row.bind(i))
		add_child(row)
		rows.append(row)
		y += ShopRow.SIZE.y
	size = Vector2(ShopRow.SIZE.x + PADDING * 2.0, y + PADDING - 1.0)
	position = Vector2(Hud.SCREEN.x - Hud.MARGIN - size.x, Hud.TOP_BAND + DROP)
	hint_label.position = Vector2(
		size.x - PADDING - 2.0 - PixelText.width(hint_label.text), PADDING
	)
	_divider.position = Vector2(PADDING, PADDING + TITLE_HEIGHT - 1.0)
	_divider.size = Vector2(ShopRow.SIZE.x, 1.0)
	if world != null:
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Brings every row up to date with the simulation and runs the flashes. Called every frame by the
## HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	var gold: int = _simulation.party.gold
	for row: ShopRow in rows:
		row.refresh(_simulation.upgrades, gold, delta)


## True while the shop is shown.
func is_open() -> bool:
	return visible


## Shows the shop, closing the away panel if it is still up.
func open() -> void:
	var hud: Node = get_parent()
	var layer: Node = hud.get_parent() if hud != null else null
	if layer != null:
		for child: Node in layer.get_children():
			if child is AwayPanel:
				(child as AwayPanel).close()
	visible = true
	advance(0.0)


## Hides the shop.
func close() -> void:
	visible = false


## How many upgrades the party's gold can pay for the next rank of.
func affordable_count() -> int:
	if _simulation == null:
		return 0
	var count: int = 0
	for id: StringName in Content.upgrade_ids():
		var price: int = _simulation.upgrades.cost(id)
		if price >= 0 and price <= _simulation.party.gold:
			count += 1
	return count


## Asks the simulation to buy the next rank of row [param index] (0-based), if the shop is open
## and the party can pay for it; otherwise does nothing.
func buy_row(index: int) -> void:
	if not is_open() or index < 0 or index >= rows.size():
		return
	var row: ShopRow = rows[index]
	row.refresh(_simulation.upgrades, _simulation.party.gold, 0.0)
	if row.affordable():
		_simulation.buy_upgrade(row.id)


func _on_sim_event(event: SimEvent) -> void:
	if event.kind != SimEvent.Kind.UPGRADE_BOUGHT:
		return
	if event.source_id >= 0 and event.source_id < rows.size():
		rows[event.source_id].start_flash()

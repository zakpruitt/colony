class_name ShopRow
extends Control
## One upgrade's row in the [ShopPanel] (spec 017): its number key, name and one-line description
## on the left, its rank and current bonus in the middle, and a buy button with the price on the
## right, or [code]MAX[/code] at the top rank. [method refresh] reads everything from the
## simulation each frame; the row keeps no copy of a rank or a price.
##
## Spec 052: from the rank that also costs the upgrade's resource, the resource's icon and price
## stand left of the buy button, greyed while the party has too little; the gold price is dimmed
## as before. The row can be bought only when both are paid.

## The row's size in pixels.
const SIZE: Vector2 = Vector2(304, 22)
## The price on an affordable row, and on one the party cannot pay for yet.
const PRICE_AFFORDABLE: StringName = &"yellow"
const PRICE_TOO_DEAR: StringName = &"brick"
## Seconds a row flashes after a purchase.
const FLASH_SECONDS: float = 0.5
## The resource price when the party holds enough of it, and when it does not.
const RESOURCE_AFFORDABLE: StringName = &"white"
const RESOURCE_TOO_FEW: StringName = &"slate"
## Where the rank and bonus column starts, the resource price's column, and the buy button's width.
const RANK_X: float = 170.0
const RESOURCE_X: float = 218.0
const BUTTON_WIDTH: float = 44.0

## The upgrade this row shows.
var id: StringName
var key_label: Label
var name_label: Label
var description_label: Label
var rank_label: Label
var bonus_label: Label
## "MAX", shown in place of the buy button at the top rank.
var max_label: Label
var buy_button: HudButton
## The resource's icon and price (spec 052), shown from the rank that costs it.
var resource_icon: TextureRect
var resource_label: Label

var _flash: float = 0.0
var _affordable: bool = false
var _gold_affordable: bool = false
var _resource_affordable: bool = true


## A row for upgrade [param upgrade_id], the [param index]th in the shop (0-based).
func _init(upgrade_id: StringName, index: int) -> void:
	id = upgrade_id
	name = "Row%d" % (index + 1)
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var def: UpgradeDef = Content.upgrade(upgrade_id)
	key_label = _label("Key", str(index + 1), &"slate", Vector2(4, 1))
	name_label = _label("Name", def.display_name, &"white", Vector2(14, 1))
	description_label = _label("Description", def.description, &"steel", Vector2(14, 11))
	rank_label = _label("Rank", "", &"silver", Vector2(RANK_X, 1))
	bonus_label = _label("Bonus", "", &"green", Vector2(RANK_X, 11))
	buy_button = HudButton.new("")
	buy_button.name = "Buy"
	buy_button.custom_minimum_size = Vector2(BUTTON_WIDTH, HudButton.HEIGHT)
	buy_button.size = buy_button.get_combined_minimum_size()
	buy_button.position = Vector2(
		SIZE.x - 4.0 - BUTTON_WIDTH, floorf((SIZE.y - HudButton.HEIGHT) / 2)
	)
	add_child(buy_button)
	resource_icon = ResourceIcon.rect(def.resource)
	resource_icon.name = "ResourceIcon"
	resource_icon.position = Vector2(RESOURCE_X, floorf((SIZE.y - ResourceIcon.SIZE.y) / 2.0))
	add_child(resource_icon)
	resource_label = _label(
		"ResourcePrice", "", RESOURCE_AFFORDABLE, Vector2(RESOURCE_X + ResourceIcon.SIZE.x + 2.0, 6)
	)
	max_label = _label("Max", "MAX", &"yellow", Vector2.ZERO)
	max_label.position = Vector2(
		buy_button.position.x + floorf((BUTTON_WIDTH - PixelText.width("MAX")) / 2.0), 6
	)


func _draw() -> void:
	if _flash <= 0.0:
		return
	var bright: bool = _flash > FLASH_SECONDS / 2.0
	var rect := Rect2(Vector2.ZERO, size)
	var fill: Color = Palette.color(&"forest" if bright else &"dusk")
	var edge: Color = Palette.color(&"green" if bright else &"slate")
	HudPanel.draw_panel(self, rect, fill, edge, edge)


## Brings the row up to date with [param upgrades] and what [param party] holds, and runs its
## flash down by [param delta] seconds.
func refresh(upgrades: Upgrades, party: Party, delta: float) -> void:
	var def: UpgradeDef = Content.upgrade(id)
	var rank: int = upgrades.rank(id)
	var price: int = upgrades.cost(id)
	var needed: int = upgrades.resource_cost(id)
	_gold_affordable = price >= 0 and price <= party.gold
	_resource_affordable = needed <= party.resource(def.resource)
	_affordable = _gold_affordable and _resource_affordable
	var costs_resource: bool = needed > 0
	resource_icon.visible = costs_resource
	resource_label.visible = costs_resource
	if costs_resource:
		_set_text(resource_label, Hud.group_thousands(needed))
		resource_label.add_theme_color_override(&"font_color", Palette.color(resource_colour()))
	_set_text(rank_label, "Rank %d/%d" % [rank, def.max_rank])
	_set_text(bonus_label, "+%d%%" % roundi(rank * def.per_rank * 100.0))
	var maxed: bool = price < 0
	buy_button.visible = not maxed
	max_label.visible = maxed
	if not maxed:
		var price_text: String = Hud.group_thousands(price)
		if buy_button.text != price_text:
			buy_button.text = price_text
			buy_button.size = buy_button.get_combined_minimum_size()
		buy_button.disabled = not _affordable
		buy_button.text_colour = PRICE_AFFORDABLE if _gold_affordable else PRICE_TOO_DEAR
	if _flash > 0.0:
		var was_bright: bool = _flash > FLASH_SECONDS / 2.0
		_flash = maxf(_flash - delta, 0.0)
		if was_bright != (_flash > FLASH_SECONDS / 2.0) or _flash == 0.0:
			queue_redraw()
	var lit: bool = _flash > 0.0
	rank_label.add_theme_color_override(
		&"font_color", Palette.color(&"yellow" if lit else &"silver")
	)


## Starts the row's flash: the upgrade was just bought.
func start_flash() -> void:
	_flash = FLASH_SECONDS
	queue_redraw()


## Seconds of the row's flash left; 0 when still.
func flash() -> float:
	return _flash


## True when the party can pay for the next rank: its gold and its resource.
func affordable() -> bool:
	return _affordable


## The palette colour the price is drawn in.
func price_colour() -> StringName:
	return buy_button.text_colour


## The palette colour the resource price is drawn in: grey while the party has too little.
func resource_colour() -> StringName:
	return RESOURCE_AFFORDABLE if _resource_affordable else RESOURCE_TOO_FEW


## The row's tooltip (spec 052 R5): the next rank's prices, then where its resource comes from and,
## if that area is closed, how it is opened. [code]Rank 4: 91 gold and 4 clay. Clay comes from
## the Claypits: beat the Slime King in Mossy Hollow to open it.[/code]
func tip_text(simulation: Simulation) -> String:
	var def: UpgradeDef = Content.upgrade(id)
	var rank: int = simulation.upgrades.rank(id)
	var price: int = simulation.upgrades.cost(id)
	var where: String = ResourceIcon.where_from(simulation, def.resource)
	if price < 0:
		return "%s is at its top rank." % def.display_name
	var needed: int = simulation.upgrades.resource_cost(id)
	if needed <= 0:
		var from: int = def.resource_from_rank + 1
		return (
			"Rank %d: %s gold. From rank %d it costs %s too. %s"
			% [rank + 1, Hud.group_thousands(price), from, ResourceIcon.plural(def.resource), where]
		)
	return (
		"Rank %d: %s gold and %s %s. %s"
		% [
			rank + 1,
			Hud.group_thousands(price),
			Hud.group_thousands(needed),
			ResourceIcon.plural(def.resource),
			where
		]
	)


func _label(label_name: String, text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.name = label_name
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()

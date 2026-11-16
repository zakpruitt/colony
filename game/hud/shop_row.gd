class_name ShopRow
extends Control
## One upgrade's row in the [ShopPanel] (spec 017): its number key, name and one-line description
## on the left, its rank and current bonus in the middle, and a buy button with the price on the
## right, or [code]MAX[/code] at the top rank. [method refresh] reads everything from the
## simulation each frame; the row keeps no copy of a rank or a price.

## The row's size in pixels.
const SIZE: Vector2 = Vector2(268, 22)
## The price on an affordable row, and on one the party cannot pay for yet.
const PRICE_AFFORDABLE: StringName = &"yellow"
const PRICE_TOO_DEAR: StringName = &"brick"
## Seconds a row flashes after a purchase.
const FLASH_SECONDS: float = 0.5
## Where the rank and bonus column starts, and the buy button's width.
const RANK_X: float = 170.0
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

var _flash: float = 0.0
var _affordable: bool = false


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


## Brings the row up to date with [param upgrades] and the party's [param gold], and runs its
## flash down by [param delta] seconds.
func refresh(upgrades: Upgrades, gold: int, delta: float) -> void:
	var def: UpgradeDef = Content.upgrade(id)
	var rank: int = upgrades.rank(id)
	var price: int = upgrades.cost(id)
	_affordable = price >= 0 and price <= gold
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
		buy_button.text_colour = PRICE_AFFORDABLE if _affordable else PRICE_TOO_DEAR
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


## True when the party can pay for the next rank.
func affordable() -> bool:
	return _affordable


## The palette colour the price is drawn in.
func price_colour() -> StringName:
	return buy_button.text_colour


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

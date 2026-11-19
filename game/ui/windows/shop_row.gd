class_name ShopRow
extends PanelContainer
## One upgrade's row in the Shop window (spec 017, laid out afresh by spec 059 R2): its picture
## (spec 063), then its number key
## and its name in bold over what one rank gives, in a full sentence; its rank as
## [code]3 / 20[/code] over a thin bar and the bonus it gives now; and one buy button with the
## whole price: the gold, and from the rank that also costs the upgrade's resource (spec 052) that
## price with the resource's icon. The button is in its normal state when the party can pay and
## disabled when it cannot, and then the line under the sentence says what is missing
## ([code]Needs 12 more clay, from The Claypits[/code]). At the top rank it reads
## [code]Max[/code].
##
## [method refresh] reads everything from the simulation every frame; the row keeps no copy of a
## rank or a price. A purchase, by the player or by auto-buy, flashes the row.

## Seconds a row flashes after a purchase.
const FLASH_SECONDS: float = 0.5
## UI pixels: the gap between the text and the button, and the rank bar's width and height.
const GAP: int = 6
const BAR_WIDTH: int = 48
const BAR_HEIGHT: int = 5
## Space between the row's edge and what it holds, as the flash's box has it.
const PAD: int = 3

## The upgrade this row shows.
var id: StringName
var key_label: Label
var name_label: Label
## What one rank gives: "Each rank gives +5% damage and healing."
var description_label: Label
## What is missing while the party cannot pay: "Needs 12 more clay, from The Claypits"; "" else.
var needs_label: Label
var rank_label: Label
var rank_bar: UiBar
## The bonus all ranks bought give now: "+15% now".
var bonus_label: Label
## Buys the next rank: its text is the whole price, its icon the resource's from that rank on.
var buy_button: UiButton
## The upgrade's own picture, at its own size before its number key.
var picture: TextureRect

var _flash: float = 0.0
var _affordable: bool = false
var _flash_bright: bool = false


## A row for upgrade [param upgrade_id], the [param index]th in the shop (0-based). Its number key
## and name, the sentence and the rank line stand in a column beside the buy button; the line of
## what is missing runs under both, so the longest fits.
func _init(upgrade_id: StringName, index: int) -> void:
	id = upgrade_id
	name = "Row%d" % (index + 1)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override(&"panel", _box(&""))
	var def: UpgradeDef = Content.upgrade(upgrade_id)
	var whole := VBoxContainer.new()
	whole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No gaps between the lines (spec 063): the picture makes the name's line 3 pixels taller than
	# the text's 13, and the three gaps give them back, so the row keeps its height.
	whole.add_theme_constant_override(&"separation", 0)
	add_child(whole)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override(&"separation", GAP)
	whole.add_child(top)
	var text := _column(top, 0)
	text.custom_minimum_size.x = text_width()
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 4)
	text.add_child(head)
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.custom_minimum_size = UiIcon.PICTURE_SIZE
	picture.texture = UiIcon.picture(upgrade_id)
	head.add_child(picture)
	key_label = _line(head, "Key", str(index + 1), &"slate", true)
	name_label = _line(head, "Name", def.display_name, &"white", true)
	description_label = _line(text, "Description", sentence(def), &"silver")
	var rank := HBoxContainer.new()
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank.add_theme_constant_override(&"separation", 5)
	text.add_child(rank)
	rank_label = _line(rank, "Rank", "", &"white")
	rank_label.custom_minimum_size.x = UiText.width("%d / %d" % [def.max_rank, def.max_rank])
	rank_bar = UiBar.new(&"green", &"forest", BAR_HEIGHT)
	rank_bar.custom_minimum_size.x = BAR_WIDTH
	rank_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank.add_child(rank_bar)
	bonus_label = _line(rank, "Bonus", "", &"green")
	# The button keeps one width whatever its price: a UiButton sizes itself, its holder does not.
	var holder := VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.custom_minimum_size.x = button_width()
	top.add_child(holder)
	buy_button = UiButton.new("")
	buy_button.name = "Buy"
	buy_button.toggle_mode = false
	buy_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	holder.add_child(buy_button)
	needs_label = _line(whole, "Needs", "", &"orange")
	needs_label.custom_minimum_size.y = UiText.LINE_HEIGHT  # kept, so the row never jumps


## What one rank of [param def] gives, as a sentence: "Each rank gives +5% damage and healing."
static func sentence(def: UpgradeDef) -> String:
	return "Each rank gives %s." % def.description


## The text column's width: the widest name and sentence the shop can show, and room for the
## line of what is missing under the text and the button together, so no row's text is ever cut.
static func text_width() -> int:
	var widest: int = 0
	var needs: int = 0
	for upgrade: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(upgrade)
		var shown: int = int(UiIcon.PICTURE_SIZE.x) + 4  # the picture before the key
		widest = maxi(
			widest, shown + UiText.width("5", true) + 4 + UiText.width(def.display_name, true)
		)
		widest = maxi(widest, UiText.width(sentence(def)))
		var most: int = def.cost_at(def.max_rank - 1)
		var resource: int = def.resource_cost_at(def.max_rank - 1)
		needs = maxi(needs, UiText.width(needs_for(def, most, resource)))
	return maxi(widest, needs - GAP - button_width())


## The buy button's width: room for its dearest price.
static func button_width() -> int:
	var widest: int = UiText.width("Max", true)
	for upgrade: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(upgrade)
		var price: String = price_text(
			def.cost_at(def.max_rank - 1), def.resource_cost_at(def.max_rank - 1)
		)
		widest = maxi(widest, UiText.width(price, true) + int(ResourceIcon.SIZE.x) + 4)
	return widest + 2 * (UiTheme.BUTTON_PAD_X + 1)


## A price as the buy button shows it: "91 gold", or "91 gold + 4" when it costs the resource too
## (its icon follows).
static func price_text(gold: int, resource: int) -> String:
	if resource > 0:
		return "%s gold + %s" % [Hud.group_thousands(gold), Hud.group_thousands(resource)]
	return "%s gold" % Hud.group_thousands(gold)


## What a party short of [param gold] gold and [param resource] of [param def]'s resource is
## missing, in words: "Needs 40 more gold", "Needs 12 more clay, from The Claypits", or both
## joined with "and"; "" when it is short of nothing.
static func needs_for(def: UpgradeDef, gold: int, resource: int) -> String:
	var parts: PackedStringArray = []
	if gold > 0:
		parts.append("%s more gold" % Hud.group_thousands(gold))
	if resource > 0:
		var plural: String = ResourceIcon.plural(def.resource)
		parts.append("%s more %s" % [Hud.group_thousands(resource), plural])
	if parts.is_empty():
		return ""
	var text: String = "Needs " + " and ".join(parts)
	if resource > 0:
		text += ", from " + PlaceText.area_name(Content.area_of_resource(def.resource))
	return text


## Brings the row up to date with [param upgrades] and what [param party] holds, and runs its
## flash down by [param delta] seconds.
func refresh(upgrades: Upgrades, party: Party, delta: float) -> void:
	var def: UpgradeDef = Content.upgrade(id)
	var rank: int = upgrades.rank(id)
	var price: int = upgrades.cost(id)
	var needed: int = upgrades.resource_cost(id)
	_affordable = upgrades.can_pay(id, party)
	_set_text(rank_label, "%d / %d" % [rank, def.max_rank])
	rank_bar.fraction = float(rank) / maxf(def.max_rank, 1)
	_set_text(bonus_label, "+%d%% now" % roundi(rank * def.per_rank * 100.0))
	var maxed: bool = price < 0
	var text: String = "Max" if maxed else price_text(price, needed)
	if buy_button.text != text:
		buy_button.text = text
	buy_button.icon = ResourceIcon.texture(def.resource) if not maxed and needed > 0 else null
	buy_button.disabled = maxed or not _affordable
	var short_gold: int = maxi(price - party.gold, 0) if not maxed else 0
	var short_resource: int = maxi(needed - party.resource(def.resource), 0) if not maxed else 0
	_set_text(needs_label, needs_for(def, short_gold, short_resource))
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	var bright: bool = _flash > FLASH_SECONDS / 2.0
	if _flash_bright != bright or (_flash == 0.0 and get_theme_stylebox(&"panel") is StyleBoxFlat):
		_flash_bright = bright
		add_theme_stylebox_override(
			&"panel", _box(&"" if _flash <= 0.0 else (&"bright" if bright else &"dim"))
		)
	rank_label.add_theme_color_override(
		&"font_color", Palette.color(&"yellow" if _flash > 0.0 else &"white")
	)


## Starts the row's flash: the upgrade was just bought.
func start_flash() -> void:
	_flash = FLASH_SECONDS
	_flash_bright = true
	add_theme_stylebox_override(&"panel", _box(&"bright"))


## Seconds of the row's flash left; 0 when still.
func flash() -> float:
	return _flash


## True when the party can pay for the next rank: its gold and its resource.
func affordable() -> bool:
	return _affordable


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


## The row's background: none at rest, then a bright and a dim box as it flashes.
func _box(state: StringName) -> StyleBox:
	match state:
		&"bright":
			return UiTheme.box(&"forest", &"green", PAD - 1, PAD - 1)
		&"dim":
			return UiTheme.box(&"dusk", &"slate", PAD - 1, PAD - 1)
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(PAD)
	return empty


func _column(row: HBoxContainer, separation: int) -> VBoxContainer:
	var made := VBoxContainer.new()
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_constant_override(&"separation", separation)
	row.add_child(made)
	return made


func _line(
	column: Control, label_name: String, text: String, colour: StringName, bold: bool = false
) -> Label:
	var made: Label = UiText.label(text, colour, bold)
	made.name = label_name
	column.add_child(made)
	return made


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text

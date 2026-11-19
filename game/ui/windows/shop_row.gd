class_name ShopRow
extends PanelContainer
## One upgrade's card in the Shop window (spec 017, laid out by spec 059 R2, made a card by spec
## 065). At its left the upgrade's picture in a large [UiIcon] (spec 063) with the rank as its
## count: ready (a pulsing yellow frame) when the party can pay, locked when it cannot, owned in
## gold for good at the top rank. Beside it the number key and the name in bold with the rank in
## words at the end of the line ([code]3 / 20[/code]), under them the ranks as [ShopPips] across
## the whole text column, and one buy button with the whole price: the
## gold, and from the rank that also costs the upgrade's resource (spec 052) that price with the
## resource's icon; at the top rank it reads [code]Max[/code]. Under those, what the upgrade gives
## now and what the next rank gives, side by side with an arrow, the gain in green
## ([code]Damage and healing  +15%  >  +20%[/code]; at the top rank the total with
## [code]Mastered[/code]); and across the card's foot, while the party cannot pay, what is missing
## in words ([code]Needs 12 more clay, from The Claypits[/code]).
##
## [method refresh] reads everything from the simulation every frame; the card keeps no copy of a
## rank or a price. A purchase heard fresh fills its pip with a flash ([method start_flash]); the
## player's own also steps the numbers to their new values ([method start_step]) while the shop
## bursts the icon. Pointing at the card shows a card tooltip ([method card]).

## Seconds the numbers take to step to their new values after the player's purchase.
const STEP_SECONDS: float = 0.3
## UI pixels: the gap between the picture, the text and the button, and the space between the
## parts of the numbers' line.
const GAP: int = 6
const NUMBERS_GAP: int = 6
## Space between the card's edge and what it holds.
const PAD: int = 3
## The words after the total at the top rank.
const MASTERED: String = "Mastered"

## The upgrade this card shows.
var id: StringName
## The picture in its framed slot, the rank as its count.
var icon: UiIcon
## The picture inside [member icon] (spec 063's tests read it).
var picture: TextureRect
var key_label: Label
var name_label: Label
## The ranks as pips, under the name, and the rank in words beside them: "3 / 20".
var pips: ShopPips
var rank_label: Label
## What the upgrade raises ("Damage and healing"), what it gives now ("+15%"), the arrow and what
## the next rank gives ("+20%", or "Mastered" at the top rank).
var gives_label: Label
var now_label: Label
var arrow_label: Label
var next_label: Label
## What is missing while the party cannot pay: "Needs 12 more clay, from The Claypits"; "" else.
var needs_label: Label
## Buys the next rank: its text is the whole price, its icon the resource's from that rank on.
var buy_button: UiButton

var _affordable: bool = false
## The numbers stepping: the rank they step from, and the seconds of the step left.
var _step_from: int = 0
var _step: float = 0.0


## A card for upgrade [param upgrade_id], the [param index]th in the shop (0-based).
func _init(upgrade_id: StringName, index: int) -> void:
	id = upgrade_id
	name = "Row%d" % (index + 1)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(PAD)
	add_theme_stylebox_override(&"panel", empty)
	var def: UpgradeDef = Content.upgrade(upgrade_id)
	var whole := _box(self, true, 0)
	var top := _box(whole, false, GAP)
	icon = UiIcon.new(upgrade_id)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS  # pointing at it points at the card
	icon.mouse_default_cursor_shape = Control.CURSOR_ARROW
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(icon)
	picture = icon.picture_rect
	var right := _box(top, true, 0)
	var upper := _box(right, false, GAP)
	var text := _box(upper, true, 0)
	text.custom_minimum_size.x = text_width()
	# The name line ends with the rank in words at the column's right edge, so the pips under it
	# have the whole column.
	var head := _box(text, false, 4)
	key_label = _line(head, "Key", str(index + 1), &"slate", true)
	name_label = _line(head, "Name", def.display_name, &"white", true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_label = _line(head, "Rank", "", &"steel")
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rank := _box(text, false, 0)
	rank.custom_minimum_size.y = UiText.LINE_HEIGHT
	pips = ShopPips.new()
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.show_ranks(0, def.max_rank)
	rank.add_child(pips)
	# The button keeps one width whatever its price: a UiButton sizes itself, its holder does not.
	var holder := _box(upper, true, 0)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.custom_minimum_size.x = button_width()
	buy_button = UiButton.new("")
	buy_button.name = "Buy"
	buy_button.toggle_mode = false
	buy_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	holder.add_child(buy_button)
	var numbers := _box(right, false, NUMBERS_GAP)
	gives_label = _line(numbers, "Gives", def.gives, &"silver")
	now_label = _line(numbers, "Now", "", &"white", true)
	arrow_label = _line(numbers, "Arrow", ">", &"slate")
	next_label = _line(numbers, "Next", "", &"green", true)
	needs_label = _line(whole, "Needs", "", &"orange")
	needs_label.custom_minimum_size.y = UiText.LINE_HEIGHT  # kept, so the card never jumps


## What one rank of [param def] gives, as a sentence: "Each rank gives +5% damage and healing."
static func sentence(def: UpgradeDef) -> String:
	return "Each rank gives %s." % def.description


## What [param rank] ranks of [param def] give, in whole percent: "+15%".
static func percent(def: UpgradeDef, rank: int) -> String:
	return "+%d%%" % roundi(rank * def.per_rank * 100.0)


## The banner's headline for rank [param rank] of [param def] (spec 065 R6): "Sharp Blades, rank
## 5", or "Sharp Blades mastered" at the top rank.
static func milestone_headline(def: UpgradeDef, rank: int) -> String:
	if rank >= def.max_rank:
		return "%s mastered" % def.display_name
	return "%s, rank %d" % [def.display_name, rank]


## The banner's line under it: what all [param rank] ranks give, "+25% damage and healing".
static func milestone_line(def: UpgradeDef, rank: int) -> String:
	return "%s %s" % [percent(def, rank), def.gives.to_lower()]


## True when rank [param rank] of [param def] is a milestone: every fifth rank, and the top one.
static func is_milestone(def: UpgradeDef, rank: int) -> bool:
	return rank > 0 and (rank % 5 == 0 or rank >= def.max_rank)


## The text column's width beside the picture: the widest name line and pips line the shop can
## show, and room for the line of what is missing across the whole card, so nothing is cut.
static func text_width() -> int:
	var widest: int = 0
	var needs: int = 0
	for upgrade: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(upgrade)
		var ranks: String = "%d / %d" % [def.max_rank, def.max_rank]
		var head: int = UiText.width("5", true) + UiText.width(def.display_name, true)
		widest = maxi(widest, head + 4 + 4 + UiText.width(ranks))
		widest = maxi(widest, ShopPips.width_for(def.max_rank))
		var most: int = def.cost_at(def.max_rank - 1)
		var resource: int = def.resource_cost_at(def.max_rank - 1)
		needs = maxi(needs, UiText.width(needs_for(def, most, resource)))
	var beside: int = int(UiIcon.PICTURE_SIZE.x * 2 + UiIcon.LARGE_FRAME * 2) + GAP
	return maxi(widest, needs - beside - GAP - button_width())


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


## Brings the card up to date with [param upgrades] and what [param party] holds, and runs its
## flash, its pulse and its stepping numbers on by [param delta] seconds.
func refresh(upgrades: Upgrades, party: Party, delta: float) -> void:
	var def: UpgradeDef = Content.upgrade(id)
	var rank: int = upgrades.rank(id)
	var price: int = upgrades.cost(id)
	var needed: int = upgrades.resource_cost(id)
	var maxed: bool = price < 0
	_affordable = upgrades.can_pay(id, party)
	if maxed:
		icon.show_state(UiIcon.State.OWNED)
	else:
		icon.show_state(UiIcon.State.READY if _affordable else UiIcon.State.LOCKED)
	if icon.count_label.text != str(rank) or not icon.count_label.visible:
		icon.set_count(str(rank))
	icon.advance(delta)
	pips.show_ranks(rank, def.max_rank)
	pips.advance(delta)
	rank_label.text = "%d / %d" % [rank, def.max_rank]
	_show_numbers(def, rank, delta)
	var text: String = "Max" if maxed else price_text(price, needed)
	if buy_button.text != text:
		buy_button.text = text
	buy_button.icon = ResourceIcon.texture(def.resource) if not maxed and needed > 0 else null
	buy_button.disabled = maxed or not _affordable
	var short_gold: int = maxi(price - party.gold, 0) if not maxed else 0
	var short_resource: int = maxi(needed - party.resource(def.resource), 0) if not maxed else 0
	needs_label.text = needs_for(def, short_gold, short_resource)
	rank_label.add_theme_color_override(
		&"font_color", Palette.color(&"yellow" if flash() > 0.0 else &"steel")
	)


## Fills the pip of rank [param rank] (1-based) with a flash: that rank was just bought.
func start_flash(rank: int) -> void:
	pips.flash_pip(rank - 1)


## Steps the numbers from what [param from_rank] ranks gave to what the ranks now give, over
## [constant STEP_SECONDS]: the player just bought a rank. While the numbers already step, they
## keep stepping from the earlier rank (two ranks bought in one frame step from two below).
func start_step(from_rank: int) -> void:
	_step_from = mini(_step_from, from_rank) if _step > 0.0 else from_rank
	_step = STEP_SECONDS


## Stops the flash and the stepping at once (the world caught up).
func stop() -> void:
	pips.stop_flash()
	_step = 0.0


## True while the numbers step to their new values.
func stepping() -> bool:
	return _step > 0.0


## Seconds of the card's flash left; 0 when still.
func flash() -> float:
	return pips.flash_left()


## True when the party can pay for the next rank: its gold and its resource.
func affordable() -> bool:
	return _affordable


## The card's tooltip (spec 065 R4): its picture, its name, the kind and rank, the next rank's
## prices and where the resource comes from ([method tip_text]), and what one rank gives.
func card(simulation: Simulation) -> UiTip.Card:
	var def: UpgradeDef = Content.upgrade(id)
	var made := UiTip.Card.new()
	made.picture_id = id
	made.title = def.display_name
	made.kind = "Camp upgrade, rank %d of %d" % [simulation.upgrades.rank(id), def.max_rank]
	made.body = tip_text(simulation)
	made.stand = sentence(def)
	made.stand_colour = &"green"
	return made


## The next rank's prices, then where its resource comes from and, if that area is closed, how
## it is opened (spec 052 R5). [code]Rank 4: 91 gold and 4 clay. Clay comes from the Claypits:
## beat the Slime King in Mossy Hollow to open it.[/code]
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


## Shows what the upgrade gives now and at the next rank; while stepping, the numbers count from
## [member _step_from]'s toward [param rank]'s, the total in yellow.
func _show_numbers(def: UpgradeDef, rank: int, delta: float) -> void:
	if _step > 0.0:
		_step = maxf(_step - delta, 0.0)
	var shown: float = float(rank)
	if _step > 0.0 and _step_from < rank:
		shown = lerpf(float(_step_from), float(rank), 1.0 - _step / STEP_SECONDS)
	var now: String = "+%d%%" % roundi(shown * def.per_rank * 100.0)
	now_label.text = now
	now_label.add_theme_color_override(
		&"font_color", Palette.color(&"yellow" if _step > 0.0 else &"white")
	)
	var top: bool = rank >= def.max_rank
	arrow_label.visible = not top
	if top:
		next_label.text = MASTERED
		next_label.add_theme_color_override(&"font_color", Palette.color(&"yellow"))
		return
	next_label.text = "+%d%%" % roundi((shown + 1.0) * def.per_rank * 100.0)
	next_label.add_theme_color_override(&"font_color", Palette.color(&"green"))


## A box container in [param parent]: a column ([param column]) or a row, its children
## [param separation] apart, never taking the mouse.
func _box(parent: Control, column: bool, separation: int) -> BoxContainer:
	var made: BoxContainer
	if column:
		made = VBoxContainer.new()
	else:
		made = HBoxContainer.new()
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_constant_override(&"separation", separation)
	parent.add_child(made)
	return made


func _line(
	column: Control, label_name: String, text: String, colour: StringName, bold: bool = false
) -> Label:
	var made: Label = UiText.label(text, colour, bold)
	made.name = label_name
	column.add_child(made)
	return made

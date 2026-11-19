class_name Purse
extends Panel
## The purse at the top right (spec 061 R3), on the sharp layer: the game-speed button (spec 032,
## lit above 1x), the gold with its coin, then each resource the party holds with its icon and count
## (spec 052), in [method Content.resource_ids] order; one it has none of is not shown. Counts are
## in the font's equal-width digits, shortened from 10,000 ([method Hud.short_count]).
##
## The gold count is the HUD's ([method Hud.shown_gold]), which counts each coin in as it lands. The
## resource counts tick up the same way (spec 052 R8): a drop's icons ([ResourceEffects]) count in
## as they arrive, a count still behind catches up [constant CATCH_UP_SECONDS] after the last
## arrival, and a count above the party's (an upgrade paid for) drops to it at once. It moves only
## in [method advance], so a test can step it.

## Seconds after the last icon before a count that is still behind catches up.
const CATCH_UP_SECONDS: float = 3.0
## UI pixels inside the panel's edge, between an icon and its count, and between entries.
const PAD: float = 6.0
const ICON_GAP: float = 3.0
const ENTRY_GAP: float = 8.0
## The icons' size on the sharp layer: their pixel art drawn at a whole multiple.
const ICON: Vector2 = Vector2(16, 16)
## The widest a row of counts runs before the next goes on a second row, in UI pixels.
const ROW_WIDTH: float = 180.0

## The game's speed: "1x", "2x" or "4x", lit above 1x. [Main] connects its click.
var speed_button: UiButton
var coin_icon: TextureRect
var gold_label: Label
## Each resource's icon and count, by id, whether shown or not.
var icons: Dictionary[StringName, TextureRect] = {}
var labels: Dictionary[StringName, Label] = {}

var _simulation: Simulation
var _effects: ResourceEffects
var _shown: Dictionary[StringName, int] = {}
var _since_icon: float = 0.0
var _lift: float = 0.0


func _init(coin: Texture2D = null) -> void:
	name = "Purse"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP  # a click here goes no further (to the world)
	speed_button = UiButton.new("1x")  # every speed is as wide: the digits are
	speed_button.name = "SpeedButton"
	add_child(speed_button)
	coin_icon = _icon_rect("Coin", coin)
	add_child(coin_icon)
	gold_label = UiText.label("0", &"yellow", true)
	gold_label.name = "Gold"
	add_child(gold_label)
	for id: StringName in Content.resource_ids():
		var icon: TextureRect = _icon_rect("Icon_%s" % id, ResourceIcon.texture(id))
		add_child(icon)
		icons[id] = icon
		var label: Label = UiText.label("", &"white", true)
		label.name = "Count_%s" % id
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


## Brings the resource counts up to date. Called every frame by the HUD; tests call it.
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
			catch_up()
	if not behind or _since_icon >= CATCH_UP_SECONDS:
		_since_icon = 0.0


## Every resource count shows the party's at once (after a stall: spec 061 R9).
func catch_up() -> void:
	if _simulation == null:
		return
	for id: StringName in Content.resource_ids():
		_shown[id] = _simulation.party.resource(id)
	_since_icon = 0.0


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


## Shows the gold as [param text] in [param colour], lifted [param lift] UI pixels (its bump),
## lays the purse out at [param height] UI pixels tall and returns its width.
func show_gold(text: String, colour: StringName, lift: float, height: float) -> float:
	if gold_label.text != text:
		gold_label.text = text
		gold_label.reset_size()
	gold_label.add_theme_color_override(&"font_color", Palette.color(colour))
	_lift = lift
	return lay_out(height)


## Lays the purse out from left to right at [param height] UI pixels tall, and returns its width:
## the speed button, then the gold and each resource held, running onto a second row past
## [constant ROW_WIDTH] so that a rich party's purse leaves room for the boss bar.
func lay_out(height: float) -> float:
	speed_button.reset_size()
	speed_button.size = speed_button.get_combined_minimum_size()
	speed_button.position = Vector2(PAD - 2.0, floorf((height - speed_button.size.y) / 2.0))
	var start: float = speed_button.position.x + speed_button.size.x + ENTRY_GAP
	# Each entry: an icon and its count.
	var entries: Array[Array] = [[coin_icon, gold_label]]
	if _simulation != null:
		for id: StringName in Content.resource_ids():
			var held: bool = _simulation.party.resource(id) > 0 or shown(id) > 0
			icons[id].visible = held
			labels[id].visible = held
			if not held:
				continue
			var text: String = Hud.short_count(shown(id))
			if labels[id].text != text:
				labels[id].text = text
				labels[id].reset_size()
			entries.append([icons[id], labels[id]])
	# Which row each entry goes on.
	var rows: Array[int] = []
	var row: int = 0
	var run: float = 0.0
	for entry: Array in entries:
		var width: float = ICON.x + ICON_GAP + WindowText.ink(entry[1] as Label)
		if run > 0.0 and run + ENTRY_GAP + width > ROW_WIDTH:
			row = 1
			run = 0.0
		run += (ENTRY_GAP if run > 0.0 else 0.0) + width
		rows.append(row)
	var two_rows: bool = row > 0
	var right: float = start
	var x: float = start
	for i: int in entries.size():
		if i > 0 and rows[i] != rows[i - 1]:
			x = start
		elif i > 0:
			x += ENTRY_GAP
		var icon_y: float = floorf((height - ICON.y) / 2.0)
		if two_rows:
			icon_y = (
				floorf(height / 2.0) - ICON.y - 1.0 if rows[i] == 0 else floorf(height / 2.0) + 1.0
			)
		var lift: float = _lift if i == 0 else 0.0
		var icon: TextureRect = entries[i][0]
		var label: Label = entries[i][1]
		icon.position = Vector2(x, icon_y - lift)
		label.position = Vector2(
			x + ICON.x + ICON_GAP, icon_y + floorf((ICON.y - UiText.LINE_HEIGHT) / 2.0) - lift
		)
		x = label.position.x + WindowText.ink(label)
		right = maxf(right, x)
	size = Vector2(ceilf(right + PAD), height)
	return size.x


## The middle of resource [param id]'s icon, in this purse's canvas: where its drops fly to.
func target(id: StringName) -> Vector2:
	return icons[id].get_global_rect().get_center()


func _on_collected(index: int, amount: int) -> void:
	var ids: Array[StringName] = Content.resource_ids()
	if index < 0 or index >= ids.size() or _simulation == null:
		return
	var id: StringName = ids[index]
	_shown[id] = mini(shown(id) + maxi(amount, 0), _simulation.party.resource(id))
	_since_icon = 0.0


static func _icon_rect(icon_name: String, texture: Texture2D) -> TextureRect:
	var made := TextureRect.new()
	made.name = icon_name
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	made.stretch_mode = TextureRect.STRETCH_SCALE
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.texture = texture
	made.size = ICON
	return made

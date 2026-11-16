extends GutTest
## Acceptance tests for specs/017-upgrade-shop/spec.md, one per requirement.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 17
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
const BOTTOM_BAND: float = 40.0
const BLADES: StringName = &"sharp_blades"
const ARMOR: StringName = &"stout_armor"
const MEDICINE: StringName = &"field_medicine"

var _sim: Simulation
var _world: World
var _effects: CombatEffects
var _hud: Hud


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_effects = CombatEffects.new()
	add_child_autofree(_effects)
	_effects.setup(_world, _sim)
	_effects.set_process(false)
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _effects)
	_hud.advance(0.0)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _price(id: StringName) -> int:
	return _sim.upgrades.cost(id)


func _row(id: StringName) -> ShopRow:
	var index: int = Content.upgrade_ids().find(id)
	if _hud.shop == null or index < 0 or index >= _hud.shop.rows.size():
		return null
	return _hud.shop.rows[index]


## Steps the simulation once and lets the world report its events, as a frame would.
func _step() -> void:
	_sim.step()
	_world.sync(0.016)
	_hud.advance(0.016)


# --- R1 ------------------------------------------------------------------------


func test_r1_button_and_keys_open_and_close() -> void:
	var shop: ShopPanel = _hud.shop
	assert_not_null(shop, "the HUD has a shop")
	assert_not_null(_hud.shop_button, "and a Shop button")
	if shop == null or _hud.shop_button == null:
		return
	assert_eq(_hud.shop_button.text, "Shop")
	var button: Rect2 = _hud.shop_button.get_global_rect()
	var gold: Rect2 = _hud.gold_panel.get_global_rect()
	assert_lte(button.end.y, TOP_BAND, "in the top band")
	assert_lte(button.end.x, gold.position.x, "left of the gold")
	assert_lt(gold.position.x - button.end.x, 16.0, "beside it")
	assert_false(shop.is_open(), "closed at first")
	assert_false(shop.is_visible_in_tree(), "and not shown")

	_hud.shop_button.pressed.emit()
	assert_true(shop.is_open(), "the button opens it")
	assert_true(shop.is_visible_in_tree(), "and it shows")
	_hud.shop_button.pressed.emit()
	assert_false(shop.is_open(), "and closes it")
	_key(KEY_U)
	assert_true(shop.is_open(), "U opens it")
	_key(KEY_U)
	assert_false(shop.is_open(), "and closes it")
	_key(KEY_U)
	_key(KEY_ESCAPE)
	assert_false(shop.is_open(), "Esc closes it")
	_key(KEY_ESCAPE)
	assert_false(shop.is_open(), "and does not open it")

	var away := AwayPanel.new(AwayReport.new(), _sim.party)
	_hud.get_parent().add_child(away)
	shop.open()
	assert_true(away.is_queued_for_deletion(), "opening the shop closes the away panel")
	if is_instance_valid(away) and not away.is_queued_for_deletion():
		away.free()


# --- R2 ------------------------------------------------------------------------


func test_r2_marker_when_affordable() -> void:
	var marker: ShopMarker = _hud.shop_marker
	assert_not_null(marker, "the HUD has a marker")
	if marker == null:
		return
	_sim.party.gold = 0
	_hud.advance(0.016)
	assert_eq(_hud.shop.affordable_count(), 0)
	assert_false(marker.is_visible_in_tree(), "no marker with nothing affordable")

	var cheapest: int = mini(_price(MEDICINE), _price(BLADES))
	_sim.party.gold = cheapest - 1
	_hud.advance(0.016)
	assert_false(marker.is_visible_in_tree(), "none just below a price")
	_sim.party.gold = _price(MEDICINE)  # 25: field medicine and quick march
	_hud.advance(0.016)
	assert_eq(_hud.shop.affordable_count(), 2, "two upgrades cost 25")
	assert_true(marker.is_visible_in_tree(), "the marker shows when gold reaches a price")
	assert_eq(marker.count, 2, "with the number affordable")
	assert_string_contains(marker.text(), "2", "drawn as a number")
	var first: float = marker.pulse()
	_hud.advance(0.3)
	assert_ne(marker.pulse(), first, "and it is animated")
	assert_lte(marker.get_global_rect().end.y, TOP_BAND, "in the top band")

	_sim.party.gold = 10_000
	_hud.advance(0.016)
	assert_eq(marker.count, 5, "every upgrade")
	_hud.shop.open()
	_hud.advance(0.016)
	assert_false(marker.is_visible_in_tree(), "no marker while the shop is open")
	_hud.shop.close()
	_hud.advance(0.016)
	assert_true(marker.is_visible_in_tree(), "back once it closes")
	_sim.party.gold = 0
	_hud.advance(0.016)
	assert_false(marker.is_visible_in_tree(), "gone when gold falls short")


# --- R3 ------------------------------------------------------------------------


func test_r3_lists_every_upgrade() -> void:
	var shop: ShopPanel = _hud.shop
	_sim.upgrades.set_rank(ARMOR, 3)
	shop.open()
	_hud.advance(0.016)
	var ids: Array[StringName] = Content.upgrade_ids()
	assert_eq(shop.rows.size(), ids.size(), "one row per upgrade")
	if shop.rows.size() != ids.size():
		return
	for i: int in ids.size():
		var def: UpgradeDef = Content.upgrade(ids[i])
		var row: ShopRow = shop.rows[i]
		var rank: int = _sim.upgrades.rank(ids[i])
		assert_eq(row.id, ids[i], "row %d is in shop order" % i)
		assert_eq(row.name_label.text, def.display_name, "name")
		assert_eq(row.description_label.text, def.description, "description")
		assert_eq(row.rank_label.text, "Rank %d/%d" % [rank, def.max_rank], "rank")
		var bonus: int = roundi(rank * def.per_rank * 100.0)
		assert_eq(row.bonus_label.text, "+%d%%" % bonus, "bonus")
		assert_true(row.buy_button.is_visible_in_tree(), "a buy button")
		assert_string_contains(row.buy_button.text, str(def.cost_at(rank)), "with the price")
	assert_eq(_row(ARMOR).bonus_label.text, "+15%", "three ranks of 5%")
	if shop.rows.size() > 1:
		assert_lt(shop.rows[0].position.y, shop.rows[1].position.y, "top to bottom")

	var rect: Rect2 = shop.get_global_rect()
	assert_gte(rect.position.y, TOP_BAND, "below the top band")
	assert_lte(rect.end.y, SCREEN.y - BOTTOM_BAND, "above the party frames")
	for frame: HeroFrame in _hud.frames:
		assert_false(rect.intersects(frame.get_global_rect()), "clear of %s" % frame.name)
	assert_gte(rect.position.x, 0.0)
	assert_lte(rect.end.x, SCREEN.x)
	var labels: Array[Label] = []
	_collect_labels(shop, labels)
	for label: Label in labels:
		if label.is_visible_in_tree():
			var where: String = "%s %s" % [label.name, label.get_global_rect()]
			assert_true(rect.encloses(label.get_global_rect()), "%s inside the panel" % where)

	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.hud.shop.open()
	main.driver.advance(1_000_000)
	var tick: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(main.hud.shop.is_open(), "the shop is open")
	assert_gt(main.simulation.tick, tick, "and the game runs behind it")
	assert_false(get_tree().paused, "unpaused")


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


# --- R4 ------------------------------------------------------------------------


func test_r4_rows_show_affordability() -> void:
	_sim.upgrades.set_rank(MEDICINE, Content.upgrade(MEDICINE).max_rank)
	_sim.party.gold = _price(ARMOR)
	_hud.shop.open()
	_hud.advance(0.016)
	var blades: ShopRow = _row(BLADES)
	var armor: ShopRow = _row(ARMOR)
	var medicine: ShopRow = _row(MEDICINE)
	var fat_purse: ShopRow = _row(&"fat_purse")
	assert_not_null(fat_purse)
	if fat_purse == null:
		return
	assert_true(armor.affordable(), "a price within reach")
	assert_false(armor.buy_button.disabled, "is enabled")
	assert_eq(armor.price_colour(), ShopRow.PRICE_AFFORDABLE, "and bright")
	assert_false(fat_purse.affordable(), "a price out of reach")
	assert_true(fat_purse.buy_button.disabled, "does nothing")
	assert_eq(fat_purse.price_colour(), ShopRow.PRICE_TOO_DEAR, "and is dim red")
	assert_ne(ShopRow.PRICE_AFFORDABLE, ShopRow.PRICE_TOO_DEAR)
	assert_false(medicine.buy_button.is_visible_in_tree(), "a maxed row has no button")
	assert_true(medicine.max_label.is_visible_in_tree(), "it says MAX")
	assert_eq(medicine.max_label.text, "MAX")
	assert_false(armor.max_label.is_visible_in_tree(), "the others do not")

	_sim.party.gold = _price(&"fat_purse")
	_hud.advance(0.016)
	assert_true(fat_purse.affordable(), "gold arriving makes a row affordable")
	assert_false(fat_purse.buy_button.disabled, "enabled without reopening")
	assert_eq(fat_purse.price_colour(), ShopRow.PRICE_AFFORDABLE, "and bright")
	assert_true(blades.affordable())


# --- R5 ------------------------------------------------------------------------


func test_r5_buying() -> void:
	var shop: ShopPanel = _hud.shop
	shop.open()
	var blades: ShopRow = _row(BLADES)
	var armor: ShopRow = _row(ARMOR)
	assert_not_null(armor)
	if armor == null:
		return
	var price: int = _price(BLADES)
	_sim.party.gold = 1000
	_hud.advance(0.016)
	assert_eq(blades.flash(), 0.0, "no flash at rest")

	blades.buy_button.pressed.emit()
	assert_eq(_sim.upgrades.rank(BLADES), 0, "the command waits for the step")
	_step()
	assert_eq(_sim.upgrades.rank(BLADES), 1, "the button bought a rank")
	assert_eq(_sim.party.gold, 1000 - price, "for its price")
	assert_gt(blades.flash(), 0.0, "the row flashes")
	assert_eq(armor.flash(), 0.0, "only that row")
	assert_eq(blades.rank_label.text, "Rank 1/20", "its rank changed")
	assert_string_contains(blades.buy_button.text, str(_price(BLADES)), "and its price")
	assert_ne(_price(BLADES), price, "to the next rank's")
	assert_eq(_hud.shown_gold(), _sim.party.gold, "the HUD shows the real gold at once")
	_hud.advance(1.0)
	assert_eq(blades.flash(), 0.0, "the flash is brief")

	var armor_price: int = _price(ARMOR)
	var gold: int = _sim.party.gold
	_key(KEY_2)
	_step()
	assert_eq(_sim.upgrades.rank(ARMOR), 1, "the row's number key buys")
	assert_eq(_sim.party.gold, gold - armor_price)
	assert_gt(armor.flash(), 0.0, "and the row flashes")
	assert_eq(_hud.shown_gold(), _sim.party.gold)

	_sim.party.gold = 0
	_hud.advance(0.016)
	assert_true(blades.buy_button.disabled, "unaffordable")
	blades.buy_button.pressed.emit()
	_key(KEY_1)
	_sim.party.gold = 1000
	_sim.step()
	assert_eq(_sim.upgrades.rank(BLADES), 1, "a disabled button and its key send nothing")


# --- R6 ------------------------------------------------------------------------


func test_r6_follows_the_simulation() -> void:
	var shop: ShopPanel = _hud.shop
	shop.open()
	_sim.party.gold = 0
	_hud.advance(0.016)
	var blades: ShopRow = _row(BLADES)
	assert_not_null(blades)
	if blades == null:
		return
	assert_eq(blades.rank_label.text, "Rank 0/20")
	_sim.upgrades.set_rank(BLADES, 7)
	_sim.party.gold = 5000
	_hud.advance(0.016)
	assert_eq(blades.rank_label.text, "Rank 7/20", "a rank set directly shows at once")
	assert_eq(blades.bonus_label.text, "+35%")
	assert_string_contains(blades.buy_button.text, str(_price(BLADES)), "with its price")
	assert_true(blades.affordable(), "and the gold set directly")
	_sim.upgrades.set_rank(BLADES, 20)
	_hud.advance(0.016)
	assert_true(blades.max_label.is_visible_in_tree(), "maxed directly")
	assert_eq(blades.flash(), 0.0, "no flash without a purchase event")

	var loaded: Simulation = Simulation.from_save(_sim.to_save())
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(loaded, null, null)
	hud.shop.open()
	hud.advance(0.016)
	assert_eq(hud.shop.rows[0].rank_label.text, "Rank 20/20", "a loaded save shows")


# --- R7 ------------------------------------------------------------------------


func test_r7_keys() -> void:
	_sim.set_auto_push(false)
	_sim.party.gold = 1000
	_hud.advance(0.016)
	for open: bool in [false, true]:
		if open:
			_hud.shop.open()
		else:
			_hud.shop.close()
		var what: String = "open" if open else "closed"
		var target: int = _sim.expedition.target_depth
		_key(KEY_EQUAL)
		_sim.step()
		assert_eq(_sim.expedition.target_depth, target + 1, "= works with the shop %s" % what)
		_key(KEY_MINUS)
		_sim.step()
		assert_eq(_sim.expedition.target_depth, target, "- works with the shop %s" % what)
		var auto: bool = _sim.expedition.auto_push
		_key(KEY_A)
		assert_ne(_sim.expedition.auto_push, auto, "A works with the shop %s" % what)
		var clock := Label.new()
		_hud.clock_label = clock
		add_child_autofree(clock)
		clock.visible = false
		_key(KEY_F3)
		assert_true(clock.visible, "F3 works with the shop %s" % what)
		_hud.clock_label = null
		assert_eq(_hud.shop.is_open(), open, "and the shop stays %s" % what)

	_hud.shop.close()
	_key(KEY_1)
	_sim.step()
	assert_eq(_sim.upgrades.rank(BLADES), 0, "1 does nothing while the shop is closed")
	_hud.shop.open()
	_key(KEY_1)
	_sim.step()
	assert_eq(_sim.upgrades.rank(BLADES), 1, "and buys while it is open")

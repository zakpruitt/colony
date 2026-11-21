extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/017-upgrade-shop/spec.md, one per requirement.

const SEED: int = 17
const BLADES: StringName = &"sharp_blades"
const ARMOR: StringName = &"stout_armor"
const MEDICINE: StringName = &"field_medicine"


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()
	_hud.advance(0.0)


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
	# Spec 059: the Shop button is the shop window's button on the UI layer's bar.
	var shop: ShopWindow = _hud.shop
	var shop_button: UiButton = _ui.bar.buttons.get(ShopWindow.ID, null)
	assert_not_null(shop, "the HUD has a shop")
	assert_not_null(shop_button, "and a Shop button")
	if shop == null or shop_button == null:
		return
	assert_string_contains(_ui.bar.tip.text_for(shop_button), "upgrades", "named")
	assert_false(shop.is_visible_in_tree(), "and not shown")

	shop_button.pressed.emit()
	assert_true(shop.is_visible_in_tree(), "and it shows")
	shop_button.pressed.emit()
	press(KEY_ESCAPE)
	assert_false(shop.is_open(), "and does not open it")

	var away := AwayWindow.new(AwayReport.new(), _sim.party)
	_ui.windows.add_child(away)  # spec 062: the report is a window
	away.open()
	shop.open()
	assert_true(away.is_queued_for_deletion(), "opening the shop closes the away panel")
	if is_instance_valid(away) and not away.is_queued_for_deletion():
		away.free()


# --- R2 ------------------------------------------------------------------------


func test_r2_marker_when_affordable() -> void:
	# Spec 059 R6: the marker is the amber tag on the bar's Shop button.
	var marker: UiBadge = _ui.bar.badges.get(ShopWindow.ID, null)
	assert_not_null(marker, "the Shop button has a marker")
	if marker == null:
		return
	_sim.party.gold = 0
	_advance(0.016)
	assert_eq(_hud.shop.affordable_count(), 0)
	assert_false(marker.is_visible_in_tree(), "no marker with nothing affordable")

	var cheapest: int = mini(_price(MEDICINE), _price(BLADES))
	_sim.party.gold = cheapest - 1
	_advance(0.016)
	assert_false(marker.is_visible_in_tree(), "none just below a price")
	_sim.party.gold = _price(MEDICINE)  # 25: field medicine and quick march
	_advance(0.016)
	assert_eq(_hud.shop.affordable_count(), 2, "two upgrades cost 25")
	assert_true(marker.is_visible_in_tree(), "the marker shows when gold reaches a price")
	assert_eq(marker.count, 2, "with the number affordable")
	assert_string_contains(marker.text(), "2", "drawn as a number")
	var first: float = marker.pulse()
	_advance(0.3)
	assert_ne(marker.pulse(), first, "and it is animated")
	# Spec 062 R12: on a layer of its own over the bar, at the Shop button's corner.
	var shop_button: Rect2 = _ui.bar.buttons[ShopWindow.ID].get_global_rect()
	assert_true(marker.get_global_rect().intersects(shop_button), "on the Shop button")

	_sim.party.gold = 10_000
	_advance(0.016)
	assert_eq(marker.count, 5, "every upgrade")
	_hud.shop.open()
	_advance(0.016)
	assert_false(marker.is_visible_in_tree(), "no marker while the shop is open")
	_hud.shop.close()
	_advance(0.016)
	assert_true(marker.is_visible_in_tree(), "back once it closes")
	_sim.party.gold = 0
	_advance(0.016)
	assert_false(marker.is_visible_in_tree(), "gone when gold falls short")


## Advances the HUD and the bar by [param delta] seconds, as a frame does.
func _advance(delta: float) -> void:
	_hud.advance(delta)
	_ui.bar.advance(delta)


# --- R3 ------------------------------------------------------------------------


func test_r3_lists_every_upgrade() -> void:
	var shop: ShopWindow = _hud.shop
	shop.open()
	_hud.advance(0.016)
	await get_tree().process_frame  # the window's containers lay out
	await get_tree().process_frame
	if shop.rows.size() > 1:
		assert_lt(shop.rows[0].position.y, shop.rows[1].position.y, "top to bottom")

	var main: Main = make_main()
	add_child_autofree(main)
	main.hud.shop.open()
	main.driver.advance(1_000_000)
	var tick: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(main.hud.shop.is_open(), "the shop is open")
	assert_gt(main.simulation.tick, tick, "and the game runs behind it")
	assert_false(get_tree().paused, "unpaused")


# --- R5 ------------------------------------------------------------------------


func test_r5_buying() -> void:
	var shop: ShopWindow = _hud.shop
	shop.open()
	var blades: ShopRow = _row(BLADES)
	var armor: ShopRow = _row(ARMOR)
	assert_not_null(armor)
	if armor == null:
		return
	_sim.party.gold = 1000
	_hud.advance(0.016)

	blades.buy_button.pressed.emit()
	assert_eq(_sim.upgrades.rank(BLADES), 0, "the command waits for the step")
	_step()
	assert_eq(_hud.shown_gold(), _sim.party.gold, "the HUD shows the real gold at once")

	press(KEY_2)
	_step()
	assert_eq(_hud.shown_gold(), _sim.party.gold)

	_sim.party.gold = 0
	_hud.advance(0.016)
	assert_true(blades.buy_button.disabled, "unaffordable")
	blades.buy_button.pressed.emit()
	press(KEY_1)
	_sim.party.gold = 1000
	_sim.step()
	assert_eq(_sim.upgrades.rank(BLADES), 1, "a disabled button and its key send nothing")


# --- R6 ------------------------------------------------------------------------


func test_r6_follows_the_simulation() -> void:
	var shop: ShopWindow = _hud.shop
	shop.open()
	_sim.party.gold = 0
	_hud.advance(0.016)
	var blades: ShopRow = _row(BLADES)
	assert_not_null(blades)
	if blades == null:
		return
	assert_eq(blades.rank_label.text, "0 / 20")
	_sim.upgrades.set_rank(BLADES, 7)
	_sim.party.gold = 5000
	_sim.party.set_resource(&"old_bones", 1000)  # spec 052: rank 8 costs old bones too
	_hud.advance(0.016)
	assert_eq(blades.rank_label.text, "7 / 20", "a rank set directly shows at once")
	assert_eq(blades.now_label.text, "+35%")  # spec 065: the line of numbers
	assert_string_contains(blades.buy_button.text, str(_price(BLADES)), "with its price")
	assert_true(blades.affordable(), "and the gold set directly")
	_sim.upgrades.set_rank(BLADES, 20)
	_hud.advance(0.016)
	assert_eq(blades.buy_button.text, "Max", "maxed directly")
	assert_eq(blades.flash(), 0.0, "no flash without a purchase event")

	var loaded: Simulation = Simulation.from_save(_sim.to_save())
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(loaded, null, null)
	hud.advance(0.016)
	assert_eq(hud.shop.rows[0].rank_label.text, "20 / 20", "a loaded save shows")


# --- R7 ------------------------------------------------------------------------


func test_r7_keys() -> void:
	_sim.set_auto_push(false)
	_hud.advance(0.016)
	for open: bool in [false, true]:
		if open:
			_hud.shop.open()
		else:
			_hud.shop.close()
		var what: String = "open" if open else "closed"
		var target: int = _sim.expedition.target_depth
		press(KEY_EQUAL)
		_sim.step()
		assert_eq(_sim.expedition.target_depth, target + 1, "= works with the shop %s" % what)
		press(KEY_MINUS)
		_sim.step()
		assert_eq(_sim.expedition.target_depth, target, "- works with the shop %s" % what)
		var auto: bool = _sim.expedition.auto_push
		press(KEY_A)
		assert_ne(_sim.expedition.auto_push, auto, "A works with the shop %s" % what)
		var clock := Label.new()
		_hud.clock_label = clock
		add_child_autofree(clock)
		clock.visible = false
		press(KEY_F3)
		assert_true(clock.visible, "F3 works with the shop %s" % what)
		_hud.clock_label = null
		assert_not_null(_world.camera, "the world has its camera")
		if _world.camera != null:
			var zoom: int = _world.camera.zoom_level()
			press(KEY_Z)
			assert_ne(_world.camera.zoom_level(), zoom, "Z zooms with the shop %s" % what)
			press(KEY_Z)
			assert_eq(_world.camera.zoom_level(), zoom, "and Z zooms back")
		assert_eq(_hud.shop.is_open(), open, "and the shop stays %s" % what)

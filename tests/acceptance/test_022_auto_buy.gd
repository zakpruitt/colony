extends ColonyTest
## Acceptance tests for specs/022-auto-buy/spec.md, one per requirement. Nothing here reads or
## writes a save file: saves are dictionaries passed through JSON in memory.

## State hashes of an untouched simulation every 1500 ticks up to 20 minutes, recorded on dev
## before this spec changed any sim code. Re-recorded by spec 023, whose monster ids (part of
## the hash) come from where the monster is; the game is otherwise the same. Re-recorded by
## spec 025, whose side quests stand in for some chambers' monsters.
## Re-recorded by spec 036, whose opening (stability, respawn and XP) is quicker.
## Re-recorded by spec 052, whose hash includes the resources the party holds; the game is
## otherwise the same (test_052 R11 checks it against spec 016's hashes from before).
const RECORDED_HASHES: Dictionary = {
	5:
	[
		2175997582,
		763909170,
		504535480,
		977110909,
		1672667560,
		3599790346,
		3333976926,
		3308732211,
	],
	17:
	[
		3055813990,
		2078239010,
		1371108405,
		1490681253,
		1127691303,
		2999623990,
		686771038,
		3864756292,
	],
}
const HOUR_TICKS: int = 36_000
const SEED: int = 17

var _sim: Simulation
var _world: World
var _effects: CombatEffects
var _hud: Hud

# --- Helpers -------------------------------------------------------------------


func _events_of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(parsed is Dictionary, "the save survives JSON")
	return parsed as Dictionary


func _any_names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.contains(field):
			return true
	return false


## A HUD over a world over [param sim], none of them processing by themselves.
func _make_hud(sim: Simulation) -> void:
	_sim = sim
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
	var ui := UiRoot.new()  # spec 059: the shop is a window on the UI layer
	add_child_autofree(ui)
	ui.setup(_sim, _hud, null)
	_hud.advance(0.0)


## Steps the simulation once and lets the world report its events, as a frame would.
func _frame() -> void:
	_sim.step()
	_world.sync(0.016)
	_hud.advance(0.016)


# --- Requirements --------------------------------------------------------------


func test_r1_switch() -> void:
	var sim := Simulation.new(SEED)
	assert_false(sim.auto_buy, "off in a new game")
	sim.set_auto_buy(true)
	assert_false(sim.auto_buy, "not before the next step")
	sim.step()
	assert_true(sim.auto_buy, "on after the step")
	sim.set_auto_buy(false)
	assert_true(sim.auto_buy, "still on until the next step")
	sim.step()
	assert_false(sim.auto_buy, "off again after the step")
	assert_eq(Simulation.AUTO_BUY_SECONDS, 1.0)
	assert_push_error_count(0)


func test_r2_buys_the_cheapest() -> void:
	var sim := Simulation.new(SEED)
	sim.party.gold = 5000
	# Off: nothing is bought, however rich.
	for i: int in 50:
		sim.step()
	var off_events: Array[SimEvent] = sim.drain_events()
	assert_eq(_events_of(off_events, SimEvent.Kind.UPGRADE_BOUGHT).size(), 0, "nothing while off")
	assert_false(sim.upgrades.any(), "no ranks while off")

	sim.set_auto_buy(true)
	var bought_ticks: Array[int] = []
	var ids: Array[StringName] = Content.upgrade_ids()
	for i: int in 200:
		var expected: StringName = sim.upgrades.cheapest_affordable(sim.party)
		var ranks_before: Array = sim.upgrades.hash_parts()
		var gold_before: int = sim.party.gold
		sim.step()
		assert_gte(sim.party.gold, 0, "gold never negative")
		var bought: Array[SimEvent] = _events_of(sim.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT)
		assert_lte(bought.size(), 1, "at most one purchase a tick")
		if bought.is_empty():
			continue
		var event: SimEvent = bought[0]
		var id: StringName = ids[event.source_id]
		assert_eq(id, expected, "tick %d buys the cheapest affordable" % sim.tick)
		var index: int = ids.find(id)
		var before_rank: int = ranks_before[index]
		assert_eq(sim.upgrades.rank(id), before_rank + 1, "the rank rose by one")
		assert_eq(event.amount, before_rank + 1, "the event carries the new rank")
		assert_lte(sim.party.gold, gold_before, "gold was taken")
		bought_ticks.append(sim.tick)
	assert_gt(bought_ticks.size(), 5, "several purchases: %s" % [bought_ticks])
	for i: int in range(1, bought_ticks.size()):
		assert_gte(
			bought_ticks[i] - bought_ticks[i - 1],
			Simulation.TICKS_PER_SECOND,
			"at most one purchase a second"
		)
	for i: int in range(1, mini(bought_ticks.size(), 6)):
		assert_eq(
			bought_ticks[i] - bought_ticks[i - 1],
			Simulation.TICKS_PER_SECOND,
			"one a second while gold lasts"
		)

	# Off again: nothing more.
	sim.set_auto_buy(false)
	sim.party.gold = 1_000_000
	sim.drain_events()
	for i: int in 50:
		sim.step()
	assert_eq(
		_events_of(sim.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT).size(), 0, "off stops it"
	)

	# Everything at the maximum: on, rich, and nothing to buy.
	for id: StringName in ids:
		sim.upgrades.set_rank(id, Content.upgrade(id).max_rank)
	sim.set_auto_buy(true)
	sim.party.gold = 1_000_000_000
	for i: int in 50:
		sim.step()
	assert_eq(
		_events_of(sim.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT).size(),
		0,
		"nothing once all are at maximum"
	)
	assert_eq(sim.party.gold >= 1_000_000_000, true, "no gold spent at maximum")
	assert_push_error_count(0)


func test_r3_works_while_away() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_buy(true)
	for i: int in 600:
		sim.step()
	sim.drain_events()
	var saved: Dictionary = _through_json(sim.to_save())
	var ranks_before: int = 0
	for rank: int in Simulation.from_save(saved).upgrades.hash_parts():
		ranks_before += rank

	# The reference: the same save stepped an hour by hand, counting purchases.
	var reference: Simulation = Simulation.from_save(saved)
	assert_true(reference.auto_buy, "the save carries the switch")
	var purchases: int = 0
	for i: int in HOUR_TICKS:
		reference.step()
		purchases += _events_of(reference.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT).size()

	var replay := AwayReplay.new(Simulation.from_save(saved), 3600.0)
	while not replay.run(1_000_000):
		pass
	var ranks_after: int = 0
	for rank: int in replay.simulation.upgrades.hash_parts():
		ranks_after += rank
	assert_gt(ranks_after, ranks_before, "ranks rose while away")
	assert_gt(purchases, 0, "upgrades were bought")
	assert_eq(replay.report.upgrades_bought, purchases, "the report counts every purchase")
	assert_eq(replay.simulation.state_hash(), reference.state_hash(), "the replay is the game")

	var panel := AwayWindow.new(replay.report, replay.simulation.party)
	add_child_autofree(panel)
	assert_string_contains(panel.text(), "Upgrades bought %d" % purchases, "the panel says so")
	assert_push_error_count(0)


func test_r4_saved() -> void:
	for enabled: bool in [true, false]:
		var sim := Simulation.new(SEED)
		sim.set_auto_buy(enabled)
		for i: int in 30:
			sim.step()
		var data: Dictionary = _through_json(sim.to_save())
		var version: int = data["version"]
		assert_eq(version, Simulation.SAVE_VERSION, "save version 3, 4 since spec 029")
		var saved_switch: Variant = data.get("auto_buy")
		assert_eq(typeof(saved_switch), TYPE_BOOL, "the switch is in the save")
		assert_eq(str(saved_switch), str(enabled), "as it was")
		var loaded: Simulation = Simulation.from_save(data)
		assert_not_null(loaded, "loads: %s" % Simulation.save_problems(data))
		if loaded != null:
			assert_eq(loaded.auto_buy, enabled, "round trip of %s" % enabled)
	assert_eq(Simulation.SAVE_VERSION, 8, "6 since spec 049, 7 since spec 051, 8 since spec 052")

	# A version 2 save loads with auto-buy off, through the upgrade step.
	var current: Dictionary = _through_json(Simulation.new(SEED).to_save())
	var old: Dictionary = current.duplicate(true)
	old["version"] = 2
	old.erase("auto_buy")
	var upgraded: Dictionary = Simulation.upgrade_save(old)
	var upgraded_version: int = upgraded["version"]
	assert_eq(upgraded_version, Simulation.SAVE_VERSION, "through the upgrade steps")
	var added: Variant = upgraded.get("auto_buy")
	assert_eq(typeof(added), TYPE_BOOL, "the step adds the switch")
	assert_eq(str(added), "false", "off")
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "version 2 loads: %s" % Simulation.save_problems(old))
	if from_old != null:
		assert_false(from_old.auto_buy, "off")

	# A value that is not true or false is refused by name.
	for bad_value: Variant in [1, 0, "true", null, [], 1.0]:
		var bad: Dictionary = current.duplicate(true)
		bad["auto_buy"] = bad_value
		var problems: PackedStringArray = Simulation.save_problems(bad)
		assert_true(
			_any_names(problems, "auto_buy"), "%s refused by name: %s" % [bad_value, problems]
		)
		assert_null(Simulation.from_save(bad))
	var missing: Dictionary = current.duplicate(true)
	missing.erase("auto_buy")
	assert_true(_any_names(Simulation.save_problems(missing), "auto_buy"), "missing is refused")
	assert_push_error_count(0)


func test_r5_off_changes_nothing() -> void:
	for seed_value: int in RECORDED_HASHES:
		var sim := Simulation.new(seed_value)
		var hashes: Array = []
		for i: int in 12_000:
			sim.step()
			sim.drain_events()
			if sim.tick % 1500 == 0:
				hashes.append(sim.state_hash())
		var recorded: Array = RECORDED_HASHES[seed_value]
		assert_eq(hashes, recorded, "seed %d hashes as before" % seed_value)


func test_r6_toggle_in_the_shop() -> void:
	_make_hud(Simulation.new(SEED))
	var shop: ShopWindow = _hud.shop
	var toggle: UiButton = shop.auto_buy_button
	assert_not_null(toggle, "the shop has an auto-buy toggle")
	if toggle == null:
		return
	assert_eq(toggle.text, "Auto-buy off")
	assert_false(toggle.lit, "shown off")

	# B does nothing with the shop closed.
	assert_false(shop.is_open())
	press(KEY_B)
	await wait_physics_frames(2)
	_frame()
	assert_false(_sim.auto_buy, "B with the shop closed does nothing")

	_hud.shop.open()
	assert_true(shop.is_open())
	assert_true(shop.is_ancestor_of(toggle), "the toggle is in the shop")
	await wait_physics_frames(2)  # the window lays out
	var rect: Rect2 = shop.window().get_global_rect()
	assert_true(rect.encloses(toggle.get_global_rect()), "inside the panel")

	press(KEY_B)
	await wait_physics_frames(2)
	_frame()
	assert_true(_sim.auto_buy, "B turns it on")
	assert_eq(toggle.text, "Auto-buy on")
	assert_true(toggle.lit, "shown on, lit like the Auto button")

	toggle.pressed.emit()
	_frame()
	assert_false(_sim.auto_buy, "the toggle turns it off")
	assert_eq(toggle.text, "Auto-buy off")
	assert_false(toggle.lit)

	# The display follows the simulation, not its own memory.
	_sim.set_auto_buy(true)
	_frame()
	assert_eq(toggle.text, "Auto-buy on", "follows the simulation")

	# A loaded save with auto-buy on shows it on.
	var data: Dictionary = _through_json(_sim.to_save())
	var loaded: Simulation = Simulation.from_save(data)
	_make_hud(loaded)
	_hud.shop.open()
	assert_eq(_hud.shop.auto_buy_button.text, "Auto-buy on", "a loaded save shows it on")
	assert_true(_hud.shop.auto_buy_button.lit)


func test_r7_auto_buys_are_visible() -> void:
	_make_hud(Simulation.new(SEED))
	_hud.shop.open()
	var shop: ShopWindow = _hud.shop
	_sim.party.gold = 500
	_hud.advance(4.0)
	assert_eq(_hud.shown_gold(), 500, "the count shows the gold")
	_sim.set_auto_buy(true)
	var flashed: int = -1
	for i: int in 20:
		_frame()
		for row: ShopRow in shop.rows:
			if row.flash() > 0.0:
				flashed = shop.rows.find(row)
		if flashed >= 0:
			break
	assert_gte(flashed, 0, "a row flashed")
	assert_lt(_sim.party.gold, 500, "gold was spent")
	assert_eq(_hud.shown_gold(), _sim.party.gold, "the count dropped at once")
	if flashed >= 0:
		assert_eq(_sim.upgrades.rank(shop.rows[flashed].id), 1, "the flashing row was bought")

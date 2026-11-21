extends "res://tests/support/main_fixture.gd"
## Acceptance tests for specs/065-camp-upgrades-you-can-see/spec.md, one per requirement.
##
## Each test runs the main scene with its processing off and the UI layer laid out for a chosen
## room (helpers in MainFixture), puts the simulation where it wants it by hand, steps it
## a tick at a time (the world and the HUD after each), and drives the shop with real clicks and
## keys, checking the simulation after each command.

const BLADES: StringName = &"sharp_blades"
const ARMOR: StringName = &"stout_armor"
const MEDICINE: StringName = &"field_medicine"
const CLAY: StringName = &"clay"
const BONES: StringName = &"old_bones"
const CLAYPITS: StringName = &"claypits"
const WIKI: String = "res://docs/wiki/index.html"
const SHOWCASE: String = "res://game/dev/showcase.tscn"

# --- Helpers -------------------------------------------------------------------


## A main scene laid out for [param room], its world caught up once (so the next frame is not a
## catch-up) and its moment run by hand.
func before_each() -> void:
	_frame_parts = [&"hud", &"moment"]


func _start(room: Vector2i = ROOM_LARGE) -> Main:
	var main: Main = _main(room)
	main.ui.set_process(false)  # the moment's owner: it is run by hand
	main.ui.tip.set_process(false)
	_frame(main, 0)
	return main


func _row(main: Main, id: StringName) -> ShopRow:
	return main.hud.shop.rows[Content.upgrade_ids().find(id)]


func _open_shop(main: Main) -> void:
	press(KEY_U)
	main.hud.advance(STEP)


func _bold(label: Label) -> bool:
	return label.get_theme_font(&"font") == UiText.font(true)


func _percent(def: UpgradeDef, rank: int) -> String:
	return "+%d%%" % roundi(rank * def.per_rank * 100.0)


## Every headline the moment shows over the next [param seconds], in order, each once.
func _headlines(main: Main, seconds: float = 12.0) -> Array[String]:
	var shown: Array[String] = []
	var moment: UiMoment = main.ui.moment
	for i: int in roundi(seconds / 0.05):
		moment.advance(0.05)
		var headline: String = moment.shown_headline()
		if not headline.is_empty() and (shown.is_empty() or shown[-1] != headline):
			shown.append(headline)
	return shown


## Sets every upgrade but [param keep] to its top rank, so auto-buy can only buy [param keep].
func _only_left(main: Main, keep: StringName) -> void:
	for id: StringName in Content.upgrade_ids():
		if id != keep:
			main.simulation.upgrades.set_rank(id, Content.upgrade(id).max_rank)


## Steps a tick at a time until an upgrade is bought, at most [param limit] ticks; true if one was.
func _until_bought(main: Main, limit: int = 40) -> bool:
	var bought: Array[bool] = [false]
	var heard := func(event: SimEvent) -> void:
		if event.kind == SimEvent.Kind.UPGRADE_BOUGHT:
			bought[0] = true
	main.world.sim_event.connect(heard)
	for i: int in limit:
		_frame(main)
		if bought[0]:
			break
	main.world.sim_event.disconnect(heard)
	return bought[0]


# --- R1 ------------------------------------------------------------------------


func test_r1_a_card_per_upgrade() -> void:
	var main: Main = _start()
	var sim: Simulation = main.simulation
	sim.party.gold = 10_000
	sim.upgrades.set_rank(ARMOR, 3)  # rank 4 costs clay, and there is none
	sim.upgrades.set_rank(MEDICINE, Content.upgrade(MEDICINE).max_rank)
	_open_shop(main)
	await _frames()
	var ids: Array[StringName] = Content.upgrade_ids()
	assert_eq(main.hud.shop.rows.size(), ids.size(), "a card per upgrade")
	for i: int in mini(ids.size(), main.hud.shop.rows.size()):
		var card: ShopRow = main.hud.shop.rows[i]
		var def: UpgradeDef = Content.upgrade(ids[i])
		var rank: int = sim.upgrades.rank(ids[i])
		assert_not_null(card.icon, "%s: a slot" % ids[i])
		if card.icon == null:
			continue
		assert_true(card.icon.is_visible_in_tree(), "%s: it shows" % ids[i])
		assert_eq(card.icon.size, Vector2(36, 36), "%s: large" % ids[i])
		assert_eq(card.icon.picture_rect.texture, UiIcon.picture(ids[i]), "its picture")
		assert_true(card.icon.count_label.visible, "%s: a count" % ids[i])
		assert_eq(card.icon.count_label.text, str(rank), "%s: the rank as its count" % ids[i])
		assert_eq(card.name_label.text, def.display_name, "its name")
		assert_true(_bold(card.name_label), "in bold")
		var tip: UiTip.Card = main.hud.shop.tip.card_for(card)
		var sentence: String = tip.stand if tip != null else ""
		assert_eq(sentence, "Each rank gives %s." % def.description, "a sentence")
		assert_eq(card.key_label.text, str(i + 1), "with its number key")
		assert_true(card.buy_button.is_visible_in_tree(), "one buy button")
		var icon_rect: Rect2 = card.icon.get_global_rect()
		assert_lt(icon_rect.end.x, card.name_label.get_global_rect().position.x, "picture first")
	var blades: ShopRow = _row(main, BLADES)
	var armor: ShopRow = _row(main, ARMOR)
	var medicine: ShopRow = _row(main, MEDICINE)
	assert_eq(blades.icon.state(), UiIcon.State.READY, "ready when the party can pay")
	assert_eq(
		blades.buy_button.text, "%s gold" % UiFormat.group_thousands(sim.upgrades.cost(BLADES))
	)
	assert_null(blades.buy_button.icon, "gold alone before rank 4")
	assert_eq(armor.icon.state(), UiIcon.State.LOCKED, "locked when it cannot")
	var clay: int = sim.upgrades.resource_cost(ARMOR)
	assert_eq(
		armor.buy_button.text,
		"%s gold + %d" % [UiFormat.group_thousands(sim.upgrades.cost(ARMOR)), clay],
		"the whole price"
	)
	assert_eq(armor.buy_button.icon, ResourceIcon.texture(CLAY), "the resource with its icon")
	assert_true(armor.buy_button.disabled, "and it cannot be pressed")
	assert_eq(medicine.icon.state(), UiIcon.State.OWNED, "owned, in gold, at the top rank")
	assert_eq(medicine.buy_button.text, "Max", "where the button reads Max")
	assert_true(medicine.buy_button.disabled)
	# A real click on the button buys, and the card follows.
	var gold: int = sim.party.gold
	var price: int = sim.upgrades.cost(BLADES)
	_click_on(main, blades.buy_button)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 1, "the button bought a rank")
	assert_eq(sim.party.gold, gold - price, "for its price")
	assert_eq(blades.icon.count_label.text, "1", "the count follows")
	# Clay arriving makes the armour ready; spending the gold locks both.
	sim.party.set_resource(CLAY, clay)
	_frame(main, 0)
	assert_eq(armor.icon.state(), UiIcon.State.READY, "ready once the clay is there")
	assert_false(armor.buy_button.disabled, "enabled without reopening")
	sim.party.gold = 0
	_frame(main, 0)
	assert_eq(armor.icon.state(), UiIcon.State.LOCKED, "locked without the gold")
	assert_eq(blades.icon.state(), UiIcon.State.LOCKED)
	assert_eq(medicine.icon.state(), UiIcon.State.OWNED, "owned for good")


# --- R2 ------------------------------------------------------------------------


func test_r2_what_you_get_as_numbers() -> void:
	for id: StringName in Content.upgrade_ids():
		var hint: String = Content.upgrade(id).gives
		assert_false(hint.is_empty(), "%s names its stat" % id)
		assert_lt(UiText.width(hint), 130, "%s: a short name" % id)
	var bad: UpgradeDef = Content.upgrade(BLADES).duplicate() as UpgradeDef
	bad.gives = ""
	assert_has(bad.validate(), "gives is empty", "validate() refuses an upgrade without it")
	var main: Main = _start()
	var sim: Simulation = main.simulation
	sim.party.gold = 10_000
	sim.upgrades.set_rank(ARMOR, 3)
	sim.upgrades.set_rank(MEDICINE, Content.upgrade(MEDICINE).max_rank)
	_open_shop(main)
	await _frames()
	for id: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(id)
		var card: ShopRow = _row(main, id)
		var rank: int = sim.upgrades.rank(id)
		assert_eq(card.gives_label.text, def.gives, "%s: what it raises" % id)
		assert_eq(card.now_label.text, _percent(def, rank), "%s: what it gives now" % id)
		if rank >= def.max_rank:
			continue
		assert_eq(card.arrow_label.text, ">", "%s: an arrow" % id)
		assert_eq(card.next_label.text, _percent(def, rank + 1), "%s: the next rank's" % id)
		assert_eq(_colour(card.next_label), Palette.color(&"green"), "%s: the gain in green" % id)
		var line: Array[Label] = [
			card.gives_label, card.now_label, card.arrow_label, card.next_label
		]
		for i: int in range(1, line.size()):
			var before: Rect2 = line[i - 1].get_global_rect()
			var after: Rect2 = line[i].get_global_rect()
			assert_lt(before.end.x, after.position.x, "%s: side by side, %d" % [id, i])
			assert_almost_eq(before.position.y, after.position.y, 0.5, "%s: on one line" % id)
	var armor: ShopRow = _row(main, ARMOR)
	assert_eq(
		[armor.gives_label.text, armor.now_label.text, armor.next_label.text],
		["Maximum health", "+15%", "+20%"],
		"Maximum health  +15%  >  +20%"
	)
	assert_eq(_row(main, BLADES).now_label.text, "+0%", "rank 0 reads +0%")
	var medicine: ShopRow = _row(main, MEDICINE)
	assert_eq(medicine.now_label.text, "+100%", "the top rank: the total")
	assert_false(medicine.arrow_label.is_visible_in_tree(), "no arrow")
	assert_eq(medicine.next_label.text, "Mastered", "with Mastered")
	# A rank bought with its key moves the numbers on.
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 1, "1 bought a rank")
	for i: int in 60:
		_frame(main, 0)  # let the numbers finish stepping
	assert_eq(_row(main, BLADES).now_label.text, "+5%", "now")
	assert_eq(_row(main, BLADES).next_label.text, "+10%", "and next")


# --- R3 ------------------------------------------------------------------------


func test_r3_ranks_as_pips() -> void:
	var main: Main = _start(ROOM_SMALL)
	var sim: Simulation = main.simulation
	sim.party.gold = 10_000
	sim.upgrades.set_rank(BLADES, 7)
	sim.upgrades.set_rank(ARMOR, Content.upgrade(ARMOR).max_rank)
	sim.party.set_resource(BONES, 1000)
	_open_shop(main)
	await _frames()
	for id: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(id)
		var card: ShopRow = _row(main, id)
		var pips: ShopPips = card.pips
		assert_not_null(pips, "%s has pips" % id)
		if pips == null:
			continue
		assert_eq(pips.count(), def.max_rank, "%s: one pip per rank" % id)
		assert_eq(pips.filled(), sim.upgrades.rank(id), "%s: filled for each bought" % id)
		var name_rect: Rect2 = card.name_label.get_global_rect()
		var card_rect: Rect2 = card.get_global_rect()
		var first: Rect2 = pips.pip_rect(0)
		assert_gte(first.position.y, name_rect.end.y - 0.5, "%s: under the name" % id)
		for i: int in pips.count():
			var pip: Rect2 = pips.pip_rect(i)
			var large: bool = (i + 1) % 5 == 0
			assert_eq(pips.is_large(i), large, "%s: pip %d large every fifth" % [id, i + 1])
			if large:
				assert_gt(pip.size.x, first.size.x, "%s: pip %d is larger" % [id, i + 1])
			assert_almost_eq(
				pip.get_center().y, first.get_center().y, 0.5, "%s: one line, no wrap" % id
			)
			if i > 0:
				assert_gt(pip.position.x, pips.pip_rect(i - 1).end.x - 0.5, "left to right")
			assert_true(card_rect.encloses(pip), "%s: pip %d inside the card" % [id, i + 1])
			assert_eq(pips.is_filled(i), i < sim.upgrades.rank(id), "%s: pip %d" % [id, i + 1])
	# A rank bought fills the next pip.
	var blades: ShopRow = _row(main, BLADES)
	_click_on(main, blades.buy_button)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 8, "the button bought rank 8")
	assert_eq(blades.pips.filled(), 8, "and its pip is filled")
	assert_true(blades.pips.is_filled(7))
	assert_false(blades.pips.is_filled(8))


# --- R4 ------------------------------------------------------------------------


func test_r4_what_is_missing() -> void:
	var main: Main = _start()
	var sim: Simulation = main.simulation
	sim.party.gold = 10_000
	sim.upgrades.set_rank(ARMOR, 3)
	sim.party.set_resource(CLAY, 1)
	sim.expedition.travel.open[CLAYPITS] = true
	_open_shop(main)
	await _frames()
	var armor: ShopRow = _row(main, ARMOR)
	var clay: int = sim.upgrades.resource_cost(ARMOR)
	assert_true(armor.needs_label.is_visible_in_tree(), "the card says what is missing")
	assert_eq(armor.needs_label.text, "Needs %d more clay, from The Claypits" % (clay - 1))
	assert_eq(_colour(armor.needs_label), Palette.color(&"orange"), "in orange")
	assert_true(armor.get_global_rect().encloses(armor.needs_label.get_global_rect()), "on it")
	assert_eq(_row(main, BLADES).needs_label.text, "", "nothing missing where it can pay")
	sim.party.gold = 0
	_frame(main, 0)
	assert_string_starts_with(
		armor.needs_label.text, "Needs %s more gold and" % UiFormat.group_thousands(91), "both"
	)
	# Pointing at the card shows a card tooltip.
	var tip: UiTip = main.ui.tip
	mouse_move(main.ui.ui_to_world(armor.get_global_rect().get_center()))
	tip.advance(UiTip.DELAY + 0.05)
	assert_eq(tip.hovered(), armor, "the mouse is on the card")
	assert_true(tip.card_shown(), "a card tooltip")
	assert_eq(tip.card_picture.texture, UiIcon.picture(ARMOR), "with the picture")
	assert_eq(tip.card_title.text, "Stout Armor", "its name")
	var body: String = tip.card_body.text.replace("\n", " ")
	assert_string_contains(body, "Rank 4: 91 gold and %d clay." % clay, "the next rank's prices")
	assert_string_contains(body, "Clay comes from the Claypits.", "where its resource comes from")
	assert_false(tip.get_global_rect().intersects(armor.get_global_rect()), "not over the card")
	# A closed area's card says how it is opened.
	var blades: ShopRow = _row(main, BLADES)
	sim.upgrades.set_rank(BLADES, 3)
	_frame(main, 0)
	mouse_move(main.ui.ui_to_world(blades.get_global_rect().get_center()))
	tip.advance(UiTip.DELAY + 0.05)
	assert_true(tip.card_shown(), "a card for Sharp Blades")
	assert_string_contains(
		tip.card_body.text.replace("\n", " "),
		"beat the Clay Colossus in the Claypits to open it",
		"how the Old Crypt is opened"
	)


# --- R5 ------------------------------------------------------------------------


func test_r5_buying_is_a_moment() -> void:
	var main: Main = _start()
	var sim: Simulation = main.simulation
	var moment: UiMoment = main.ui.moment
	sim.party.gold = 100_000
	sim.party.set_resource(BONES, 1000)
	sim.upgrades.set_rank(BLADES, 2)
	_open_shop(main)
	await _frames()
	var blades: ShopRow = _row(main, BLADES)
	var armor: ShopRow = _row(main, ARMOR)
	assert_eq(blades.flash(), 0.0, "still at rest")
	assert_false(blades.stepping(), "the numbers at rest")
	# The player's purchase, by the button: a burst, the new pip flashing, the numbers stepping.
	var bursts: int = moment.bursts_seen()
	_click_on(main, blades.buy_button)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 3, "the button bought rank 3")
	assert_true(moment.is_bursting(blades.icon), "the icon bursts")
	assert_eq(moment.bursts_seen(), bursts + 1, "once")
	assert_gt(blades.flash(), 0.0, "the new pip flashes")
	assert_eq(blades.pips.flashing(), 2, "the third pip")
	assert_eq(armor.flash(), 0.0, "only that card's")
	assert_true(blades.stepping(), "the numbers step")
	var seen: Array[String] = [blades.now_label.text]
	for i: int in 60:
		_frame(main, 0)
		if seen[-1] != blades.now_label.text:
			seen.append(blades.now_label.text)
	assert_eq(seen[-1], "+15%", "to the new total")
	assert_eq(blades.next_label.text, "+20%", "and the next rank's")
	assert_gt(seen.size(), 1, "through more than one value: %s" % [seen])
	assert_false(blades.stepping(), "then rest")
	assert_eq(blades.flash(), 0.0, "the flash is brief")
	assert_false(moment.is_bursting(blades.icon), "and the burst")
	# By the key: the same.
	bursts = moment.bursts_seen()
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 4, "1 bought rank 4")
	assert_true(moment.is_bursting(blades.icon), "the key's purchase bursts too")
	assert_eq(moment.bursts_seen(), bursts + 1)
	assert_eq(blades.pips.flashing(), 3, "its pip flashes")
	for i: int in 60:
		_frame(main, 0)
	# Auto-buy's purchase: the pip flashes, no burst, no stepping.
	_only_left(main, BLADES)
	sim.set_auto_buy(true)
	bursts = moment.bursts_seen()
	assert_true(_until_bought(main), "auto-buy bought")
	assert_eq(sim.upgrades.rank(BLADES), 5, "rank 5, by auto-buy")
	assert_gt(blades.flash(), 0.0, "its pip flashes")
	assert_eq(blades.pips.flashing(), 4)
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	assert_false(moment.is_bursting(blades.icon))
	assert_false(blades.stepping(), "the numbers just change")
	assert_eq(blades.now_label.text, "+25%")
	sim.set_auto_buy(false)
	for i: int in 60:
		_frame(main, 0)
	# A stale purchase: asked for, then heard only after a frame of 300 ticks.
	bursts = moment.bursts_seen()
	press(KEY_1)
	_frame(main, 300)
	assert_eq(sim.upgrades.rank(BLADES), 6, "1 bought rank 6")
	assert_eq(moment.bursts_seen(), bursts, "no burst for a stale purchase")
	assert_eq(blades.flash(), 0.0, "nor a flash")
	assert_false(blades.stepping(), "nor stepping numbers")
	assert_eq(blades.now_label.text, "+30%", "the numbers simply true")
	# Heard in the last tick of a catch-up: recent, but the world is catching up.
	_frame(main, 0)
	for i: int in 299:
		sim.step()
	press(KEY_1)
	_frame(main)
	assert_true(main.world.catching_up(), "setup: a catch-up")
	assert_eq(sim.upgrades.rank(BLADES), 7, "1 bought rank 7")
	assert_eq(moment.bursts_seen(), bursts, "no burst in a catch-up")
	assert_eq(blades.flash(), 0.0, "nor a flash")
	# A stall while the flash and the step run: the world catches up, and both stop at once.
	_frame(main, 0)
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 8, "1 bought rank 8")
	assert_true(blades.flash() > 0.0 and blades.stepping(), "setup: flashing and stepping")
	for i: int in 300:
		sim.step()
	_frame(main, 0)
	assert_true(main.world.catching_up(), "setup: a stall")
	assert_eq(blades.flash(), 0.0, "the flash stops when the world catches up")
	assert_false(blades.stepping(), "and the numbers stop stepping")
	assert_eq(blades.now_label.text, "+40%", "showing the truth")
	_frame(main, 0)
	# Two ranks bought in one tick: the numbers step from where they were, two ranks below.
	press(KEY_1)
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 10, "two ranks, 9 and 10, in one tick")
	var first: int = blades.now_label.text.trim_prefix("+").trim_suffix("%").to_int()
	assert_lt(first, 45, "stepping from rank 8, not rank 9: +%d%%" % first)
	for i: int in 60:
		_frame(main, 0)
	assert_eq(blades.now_label.text, "+50%", "to +50%")
	_moment_is_the_players(main)


## The player's purchase and auto-buy's in one tick, and an ask that failed on the tick auto-buy
## bought another upgrade: only what the player bought bursts.
func _moment_is_the_players(main: Main) -> void:
	var sim: Simulation = main.simulation
	var moment: UiMoment = main.ui.moment
	var blades: ShopRow = _row(main, BLADES)
	var armor: ShopRow = _row(main, ARMOR)
	sim.upgrades.set_rank(ARMOR, 0)  # 30 gold, the cheapest: auto-buy's
	sim.party.gold = 100_000
	sim.set_auto_buy(true)
	var every: int = roundi(Simulation.AUTO_BUY_SECONDS * Simulation.TICKS_PER_SECOND)
	for each: bool in [true, false]:
		_frame(main)
		while (sim.tick + 1) % every != 0:  # the next tick is one auto-buy buys on
			_frame(main)
		for i: int in 60:
			_frame(main, 0)  # the last bursts end
		var blades_rank: int = sim.upgrades.rank(BLADES)
		var armor_rank: int = sim.upgrades.rank(ARMOR)
		press(KEY_1)
		if not each:
			sim.party.gold = sim.upgrades.cost(ARMOR)  # the ask fails; auto-buy buys armour
		_frame(main)
		var what: String = "both bought" if each else "the ask failed"
		assert_eq(sim.upgrades.rank(ARMOR), armor_rank + 1, "%s: auto-buy bought armour" % what)
		assert_eq(sim.upgrades.rank(BLADES), blades_rank + (1 if each else 0), what)
		assert_eq(moment.is_bursting(blades.icon), each, "%s: blades bursts if bought" % what)
		assert_false(moment.is_bursting(armor.icon), "%s: auto-buy's armour does not" % what)
		assert_gt(armor.flash(), 0.0, "%s: its pip flashes" % what)
		sim.party.gold = 100_000
	sim.set_auto_buy(false)


# --- R6 ------------------------------------------------------------------------


func test_r6_milestones() -> void:
	var main: Main = _start()
	var sim: Simulation = main.simulation
	var moment: UiMoment = main.ui.moment
	sim.party.gold = 1_000_000
	sim.party.set_resource(BONES, 100_000)
	sim.upgrades.set_rank(BLADES, 3)
	_open_shop(main)
	await _frames()
	# The player's fourth rank: no banner. The fifth: a banner with the picture.
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 4, "rank 4")
	assert_eq(_headlines(main, 3.0), [] as Array[String], "no banner for rank 4")
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 5, "rank 5")
	moment.advance(0.0)
	assert_eq(moment.shown_headline(), "Sharp Blades, rank 5", "a banner for the fifth rank")
	assert_eq(moment.banner_line.text, "+25% damage and healing", "over what it gives")
	assert_eq(moment.banner_picture.texture, UiIcon.picture(BLADES), "with the picture")
	_headlines(main, 3.0)
	# Auto-buy's tenth rank: a banner too.
	sim.upgrades.set_rank(BLADES, 9)
	_only_left(main, BLADES)
	sim.set_auto_buy(true)
	assert_true(_until_bought(main), "auto-buy bought")
	assert_eq(sim.upgrades.rank(BLADES), 10)
	sim.set_auto_buy(false)
	moment.advance(0.0)
	assert_eq(moment.shown_headline(), "Sharp Blades, rank 10", "whoever bought it")
	assert_eq(moment.banner_line.text, "+50% damage and healing")
	_headlines(main, 3.0)
	# The top rank.
	sim.upgrades.set_rank(BLADES, 19)
	_frame(main, 0)
	press(KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), 20, "the top rank")
	moment.advance(0.0)
	assert_eq(moment.shown_headline(), "Sharp Blades mastered", "the top rank's banner")
	assert_eq(moment.banner_line.text, "+100% damage and healing")
	_headlines(main, 3.0)
	# A stale fifth rank, and one heard while catching up: no banner, no burst.
	sim.upgrades.set_rank(BLADES, 14)
	_frame(main, 0)
	var bursts: int = moment.bursts_seen()
	press(KEY_1)
	_frame(main, 300)
	assert_eq(sim.upgrades.rank(BLADES), 15, "a stale rank 15")
	assert_eq(_headlines(main, 3.0), [] as Array[String], "no banner for a stale purchase")
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	sim.upgrades.set_rank(BLADES, 19)
	_frame(main, 0)
	for i: int in 299:
		sim.step()
	press(KEY_1)
	_frame(main)
	assert_true(main.world.catching_up(), "setup: a catch-up")
	assert_eq(sim.upgrades.rank(BLADES), 20, "the top rank, heard in a catch-up")
	assert_eq(_headlines(main, 3.0), [] as Array[String], "no banner in a catch-up")
	assert_eq(moment.bursts_seen(), bursts, "no burst")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_foot_and_the_keys() -> void:
	var main: Main = _start(ROOM_SMALL)
	var sim: Simulation = main.simulation
	var shop: ShopWindow = main.hud.shop
	sim.party.gold = 25  # Field Medicine and Quick March
	_frame(main, 0)
	main.ui.bar.advance(STEP)
	var badge: UiBadge = main.ui.bar.badges[ShopWindow.ID]
	assert_eq(badge.count, 2, "the bar button counts what the party can pay for")
	assert_true(badge.is_visible_in_tree(), "while the shop is closed")
	press(KEY_3)
	_frame(main)
	assert_eq(sim.upgrades.rank(MEDICINE), 0, "3 buys nothing with the shop closed")
	_open_shop(main)
	await _frames()
	main.ui.bar.advance(STEP)
	assert_false(badge.visible, "no count while it is open")
	assert_eq(shop.auto_buy_button.text, "Auto-buy off", "the switch")
	assert_true(shop.is_ancestor_of(shop.auto_buy_caption), "with its sentence")
	assert_eq(shop.auto_buy_caption.text, ShopWindow.AUTO_BUY_LINE)
	press(KEY_3)
	_frame(main)
	assert_eq(sim.upgrades.rank(MEDICINE), 1, "3 buys while the shop is in front")
	sim.party.gold = 10_000
	for i: int in 5:
		var id: StringName = Content.upgrade_ids()[i]
		var rank: int = sim.upgrades.rank(id)
		press((KEY_1 + i) as Key)
		_frame(main)
		assert_eq(sim.upgrades.rank(id), rank + 1, "%d buys %s" % [i + 1, id])
	_click_on(main, shop.auto_buy_button)
	_frame(main)
	assert_true(sim.auto_buy, "a click turns auto-buy on")
	assert_true(shop.auto_buy_button.lit, "lit")
	press(KEY_B)
	_frame(main)
	assert_false(sim.auto_buy, "B turns it off")
	press(KEY_J)
	assert_eq(main.ui.windows.front(), main.ui.windows.window(UiRoot.JOURNAL), "setup: behind")
	var blades: int = sim.upgrades.rank(BLADES)
	press(KEY_1)
	press(KEY_B)
	_frame(main)
	assert_eq(sim.upgrades.rank(BLADES), blades, "1 buys nothing with the shop behind")
	assert_false(sim.auto_buy, "nor does B switch")


# --- R8 ------------------------------------------------------------------------


func test_r8_nothing_lost() -> void:
	var main: Main = _start()
	var sim: Simulation = main.simulation
	var shop: ShopWindow = main.hud.shop
	sim.party.gold = 10_000
	sim.upgrades.set_rank(ARMOR, 3)
	sim.party.set_resource(CLAY, 50)
	sim.expedition.travel.open[CLAYPITS] = true
	_open_shop(main)
	await _frames()
	# Every fact a row showed: its key, name, rank, what one rank gives, the bonus now, the whole
	# price with the resource's icon, what is missing, and its tooltip.
	for i: int in Content.upgrade_ids().size():
		var id: StringName = Content.upgrade_ids()[i]
		var def: UpgradeDef = Content.upgrade(id)
		var card: ShopRow = shop.rows[i]
		var rank: int = sim.upgrades.rank(id)
		assert_eq(card.key_label.text, str(i + 1), "%s: its key" % id)
		assert_eq(card.name_label.text, def.display_name, "%s: its name" % id)
		assert_eq(card.rank_label.text, "%d / %d" % [rank, def.max_rank], "%s: its rank" % id)
		assert_eq(card.now_label.text, _percent(def, rank), "%s: the bonus now" % id)
		var price: String = ShopRow.price_text(
			sim.upgrades.cost(id), sim.upgrades.resource_cost(id)
		)
		assert_eq(card.buy_button.text, price, "%s: the whole price" % id)
		var shown: UiTip.Card = shop.tip.card_for(card)
		assert_not_null(shown, "%s: a card tooltip" % id)
		if shown == null:
			continue
		assert_eq(shown.stand, ShopRow.sentence(def), "%s: what one rank gives" % id)
		assert_eq(shown.body, card.tip_text(sim), "%s: the prices and where from" % id)
	# Every command, with the same effect: the button, the key, the switch.
	var armor: ShopRow = _row(main, ARMOR)
	for how: String in ["by the button", "by the key"]:
		var rank: int = sim.upgrades.rank(ARMOR)
		var gold: int = sim.party.gold
		var clay: int = sim.party.resource(CLAY)
		var price: int = sim.upgrades.cost(ARMOR)
		var clay_price: int = sim.upgrades.resource_cost(ARMOR)
		if how == "by the button":
			_click_on(main, armor.buy_button)
		else:
			press(KEY_2)
		_frame(main)
		assert_eq(sim.upgrades.rank(ARMOR), rank + 1, "buy_upgrade %s" % how)
		assert_eq(sim.party.gold, gold - price, "%s: the gold paid" % how)
		assert_eq(sim.party.resource(CLAY), clay - clay_price, "%s: and the clay" % how)
	_click_on(main, shop.auto_buy_button)
	_frame(main)
	assert_true(sim.auto_buy, "set_auto_buy, by a click on the switch")


# --- R9 ------------------------------------------------------------------------


func test_r9_true_in_a_crowded_frame() -> void:
	var main: Main = _start(ROOM_SMALL)
	var sim: Simulation = main.simulation
	sim.party.gold = 3_000
	sim.party.set_resource(CLAY, 30)
	_open_shop(main)
	await _frames()
	var bought: Array[int] = [0]
	main.world.sim_event.connect(
		func(event: SimEvent) -> void:
			if event.kind == SimEvent.Kind.UPGRADE_BOUGHT:
				bought[0] += 1
	)
	# The player's purchases, then auto-buy's, all in one frame of 300 ticks.
	press(KEY_1)
	press(KEY_2)
	press(KEY_2)
	sim.set_auto_buy(true)
	_frame(main, 300)
	assert_gt(bought[0], 4, "setup: the player and auto-buy bought")
	for id: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(id)
		var card: ShopRow = _row(main, id)
		var rank: int = sim.upgrades.rank(id)
		var price: int = sim.upgrades.cost(id)
		var needed: int = sim.upgrades.resource_cost(id)
		assert_eq(card.icon.count_label.text, str(rank), "%s: the rank" % id)
		assert_eq(card.rank_label.text, "%d / %d" % [rank, def.max_rank], "%s: rank" % id)
		assert_eq(card.pips.filled(), rank, "%s: the pips" % id)
		assert_eq(card.now_label.text, _percent(def, rank), "%s: the numbers" % id)
		assert_eq(card.next_label.text, _percent(def, rank + 1), "%s: the next" % id)
		assert_eq(card.buy_button.text, ShopRow.price_text(price, needed), "%s: the price" % id)
		var short_gold: int = maxi(price - sim.party.gold, 0)
		var short_res: int = maxi(needed - sim.party.resource(def.resource), 0)
		assert_eq(
			card.needs_label.text,
			ShopRow.needs_for(def, short_gold, short_res),
			"%s: what is missing" % id
		)
		var state: UiIcon.State = (
			UiIcon.State.READY if sim.upgrades.can_pay(id, sim.party) else UiIcon.State.LOCKED
		)
		assert_eq(card.icon.state(), state, "%s: the slot's state" % id)
		assert_false(card.stepping(), "%s: nothing stepping" % id)
		assert_eq(card.flash(), 0.0, "%s: nothing flashing" % id)


# --- R10 -----------------------------------------------------------------------


## Each upgrade at [param rank_of]'s rank, no gold and no resource: the longest needs and prices.
func _fill(main: Main, mastered: bool) -> void:
	var sim: Simulation = main.simulation
	for id: StringName in Content.upgrade_ids():
		var top: int = Content.upgrade(id).max_rank
		sim.upgrades.set_rank(id, top if mastered and id != BLADES else top - 1)
	sim.party.gold = 0
	for id: StringName in Content.resource_ids():
		sim.party.set_resource(id, 0)
	_frame(main, 0)


func test_r10_fits_both_rooms() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		for mastered: bool in [false, true]:
			var main: Main = _start(room)
			var ui: UiRoot = main.ui
			_fill(main, mastered)
			for id: StringName in [&"shop", &"map", &"tally"]:
				ui.windows.open_window(id)
			_frame(main, 0)
			await _frames()
			var what: String = "%s%s" % [room, " mastered" if mastered else ""]
			var shop: UiWindow = ui.windows.window(ShopWindow.ID)
			var rect: Rect2 = shop.get_rect()
			assert_lte(rect.size.y, float(room.y), "%s: never taller than the room" % what)
			var frames_top: float = floorf(ui.world_to_ui(Vector2(0, ui.frames_top())).y)
			assert_lte(rect.end.y, frames_top, "%s: above the frames' line" % what)
			var bar_top: float = ui.bar.get_global_rect().position.y - UiRoot.PLACE_GAP / 2.0
			assert_lte(rect.end.y, bar_top, "%s: above the bar" % what)
			for other: StringName in [&"map", &"tally"]:
				var them: Rect2 = ui.windows.window(other).get_rect()
				assert_false(rect.intersects(them), "%s: clear of the %s" % [what, other])
			assert_eq(shop.position, shop.default_place, "%s: at its default place" % what)
			for card: ShopRow in main.hud.shop.rows:
				var box: Rect2 = card.get_global_rect()
				assert_true(rect.encloses(box), "%s: %s inside the window" % [what, card.id])
				for part: Control in [card.icon, card.buy_button, card.pips]:
					assert_true(
						box.encloses(part.get_global_rect()),
						"%s: %s's %s inside its card" % [what, card.id, part.name]
					)
				for i: int in card.pips.count():
					assert_true(box.encloses(card.pips.pip_rect(i)), "%s: pips fit" % what)
				var labels: Array[Label] = []
				_labels(card, labels)
				for label: Label in labels:
					var at: Rect2 = label.get_global_rect()
					var where: String = "%s: %s '%s' %s" % [what, card.id, label.text, at]
					assert_true(box.encloses(at), "%s inside its card" % where)
					assert_gte(
						at.size.x,
						float(UiText.width(label.text, _bold(label)) - UiText.SPACING),
						"%s not cut" % where
					)
				var parts: Array[Control] = [card.icon, card.buy_button, card.pips]
				for label: Label in labels:
					if not label.text.is_empty() and not card.icon.is_ancestor_of(label):
						parts.append(label)
				for a: int in parts.size():
					for b: int in range(a + 1, parts.size()):
						var one: Rect2 = parts[a].get_global_rect()
						var two: Rect2 = parts[b].get_global_rect()
						assert_false(
							one.intersects(two),
							"%s: %s's %s and %s overlap" % [what, card.id, parts[a], parts[b]]
						)
			main.free()


# --- R11 -----------------------------------------------------------------------


func test_r11_help_wiki_and_showcase() -> void:
	var keys: Dictionary[String, String] = {}
	for entry: Array in KeyBook.entries():
		keys[str(entry[0])] = str(entry[1])
	# Spec 068 R2: the help calls the shop what its button does, the Camp.
	assert_string_contains(str(keys.get("U", "")), "Camp", "U opens the shop")
	assert_string_contains(str(keys.get("1-5", "")), "Camp", "1-5 buy in it")
	assert_string_contains(str(keys.get("B", "")), "Camp", "B switches auto-buy")
	var help: String = "\n".join(PackedStringArray(HelpPanel.IDEA))
	assert_string_contains(help, "fifth rank", "help tells of the milestones")
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for phrase: String in ["065 Camp upgrades you can see", "pips", "Mastered", "every fifth rank"]:
		assert_true(wiki.contains(phrase), "the wiki tells of it: %s" % phrase)
	var showcase: Showcase = (load(SHOWCASE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"shop")
	var start: float = showcase.elapsed
	var headlines: Array[String] = []
	var bursts: int = showcase.main.ui.moment.bursts_seen()
	while showcase.moment() == &"shop" and showcase.elapsed - start < 10.0:
		showcase.advance(1.0 / 30.0)
		showcase.main.ui.moment.advance(1.0 / 30.0)
		var headline: String = showcase.main.ui.moment.shown_headline()
		if not headline.is_empty() and not headlines.has(headline):
			headlines.append(headline)
		if showcase.evidence.has(&"shop") and not headlines.is_empty():
			break
	assert_true(showcase.evidence.has(&"shop"), "the shop moment happens")
	assert_true(showcase.main.ui.windows.is_open(ShopWindow.ID), "in the shop's window")
	assert_gt(showcase.main.ui.moment.bursts_seen(), bursts, "a rank bought, with its burst")
	assert_eq(headlines, ["Sharp Blades, rank 5"] as Array[String], "and a fifth rank's banner")
	showcase.free()

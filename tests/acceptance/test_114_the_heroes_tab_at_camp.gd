extends "res://tests/acceptance/hero_windows_test_base.gd"
## Acceptance tests for specs/114-the-heroes-tab-at-camp/spec.md, one per requirement.
##
## Each test runs the main scene with its processing off and the UI layer laid out for a chosen
## room (MainFixture), puts the simulation where it wants it by hand, steps it a tick at a time
## (the world, the HUD and the moment after each), and drives the Camp window with real clicks,
## keys and mouse motion, checking the simulation after each command. The class to recruit is
## ColonyTest's copy of the Knight.

## The id the first recruit takes, and the Knight's, whose cache finds the artifact.
const RECRUIT: int = 5
const KNIGHT: int = 1
## The test class's request.
const GOLD: int = 300
const GLOWCAPS: StringName = &"glowcaps"
const CAPS: int = 40
## Ticks in a frame that is long past: its events are stale, and the world catches up.
const STALE_TICKS: int = 300
## Frames in which the camp sets up and the heroes sit before a swap is asked.
const SETTLE_FRAMES: int = 40

# --- Helpers -------------------------------------------------------------------


func before_each() -> void:
	_frame_parts = [&"hud", &"moment"]


## The main scene in [param room], the test class among the data unless [param plain], its world
## caught up once (so the next frame is not a catch-up) and its moment and tips run by hand.
func _camp_main(room: Vector2i = ROOM_LARGE, plain: bool = false) -> Main:
	if not plain:
		add_recruit_class()
	var main: Main = _main(room)
	main.ui.set_process(false)
	main.ui.tip.set_process(false)
	_frame(main, 0)
	return main


## The test class's artifact found in a cache the Knight opened, the frame it is heard in, and the
## frames the cards made for it are laid out in.
func _find(main: Main) -> void:
	ArtifactFinds._find(main.simulation.expedition, RECRUIT_CLASS, KNIGHT)
	_frame(main)
	await _frames()


## The party paid for the test class and the frame it joins in.
func _recruited(main: Main) -> void:
	await _find(main)
	var sim: Simulation = main.simulation
	sim.party.gold = GOLD
	sim.party.set_resource(GLOWCAPS, CAPS)
	sim.roster.recruit(RECRUIT_CLASS)
	_frame(main)
	await _frames()
	assert_not_null(sim.party.hero(RECRUIT), "setup: the recruit is on the bench")


## Opens the Camp window with its key and its Heroes tab with a click, and returns the tab.
func _open_heroes(main: Main) -> RosterTab:
	var shop: ShopWindow = main.hud.shop
	if not shop.is_open():
		_press(main, KEY_U)
		await _frames()
	if shop.page() != ShopWindow.Page.HEROES:
		_click(main, shop.tab_buttons[ShopWindow.Page.HEROES])
	_frame(main, 0)
	await _frames()
	return shop.heroes


## The party, all but down, starts to rest where it stands; the camp sets up and the heroes sit.
func _camp_out(main: Main) -> void:
	for hero: Hero in main.simulation.party.heroes:
		hero.health = 1
	main.simulation.expedition._start_rest()
	for i: int in SETTLE_FRAMES:
		_frame(main)
	assert_eq(main.simulation.expedition.state, Expedition.State.RESTING, "the party rests")


static func _card_ids(cards: Array[RosterCard]) -> Array[int]:
	var ids: Array[int] = []
	for card: RosterCard in cards:
		ids.append(card.hero_id)
	return ids


static func _hero_ids(heroes: Array[Hero]) -> Array[int]:
	var ids: Array[int] = []
	for hero: Hero in heroes:
		ids.append(hero.id)
	return ids


static func _card_of(cards: Array[RosterCard], hero_id: int) -> RosterCard:
	for card: RosterCard in cards:
		if card.hero_id == hero_id:
			return card
	return null


## Rests the mouse on [param control] long enough for its tip, and returns what the tip shows.
func _tip_on(main: Main, control: Control) -> String:
	mouse_move(main.ui.ui_to_world(control.get_global_rect().get_center()))
	main.ui.tip.advance(1.0)
	main.ui.tip.advance(1.0)
	var shown: String = main.ui.tip.shown_text()
	mouse_move(Vector2(-50, -50))
	main.ui.tip.advance(0.1)
	return shown


# --- R1 ------------------------------------------------------------------------


func test_r1_two_tabs() -> void:
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	var shop: ShopWindow = main.hud.shop
	var window: UiWindow = main.ui.windows.window(ShopWindow.ID)
	assert_eq(ShopWindow.TITLE, "Camp", "the title")
	assert_eq(window.title_label.text, "Camp", "the title shows")
	assert_eq(window.keycode, KEY_U, "its key")
	var names: Array[String] = []
	for tab: UiButton in shop.tab_buttons:
		names.append(tab.text)
	assert_eq(names, ["Upgrades", "Heroes"] as Array[String], "two tabs, the tally's way")
	_press(main, KEY_U)
	await _frames()
	assert_true(shop.is_open(), "U opens the Camp")
	assert_eq(shop.page(), ShopWindow.Page.UPGRADES, "on Upgrades first")
	assert_true(shop.rows[0].is_visible_in_tree(), "the cards show")
	assert_false(shop.heroes.is_visible_in_tree(), "the heroes do not")
	sim.party.gold = RICH
	var first: StringName = shop.rows[0].id
	_press(main, KEY_1)
	_frame(main)
	assert_eq(sim.upgrades.rank(first), 1, "1 buys on the Upgrades tab")
	_press(main, KEY_E)
	assert_eq(shop.page(), ShopWindow.Page.HEROES, "E: the Heroes tab")
	assert_true(shop.heroes.is_visible_in_tree(), "the heroes show")
	assert_false(shop.rows[0].is_visible_in_tree(), "the cards do not")
	assert_true(shop.tab_buttons[ShopWindow.Page.HEROES].lit, "its tab is lit")
	_press(main, KEY_1)
	_press(main, KEY_B)
	_frame(main)
	_frame(main)
	assert_eq(sim.upgrades.rank(first), 1, "1 buys nothing on the Heroes tab")
	assert_false(sim.auto_buy, "B switches nothing there")
	_press(main, KEY_Q)
	assert_eq(shop.page(), ShopWindow.Page.UPGRADES, "Q: back to Upgrades")
	_press(main, KEY_Q)
	assert_eq(shop.page(), ShopWindow.Page.HEROES, "Q wraps round")
	_press(main, KEY_E)
	assert_eq(shop.page(), ShopWindow.Page.UPGRADES, "so does E")
	_press(main, KEY_B)
	_frame(main)
	assert_true(sim.auto_buy, "B switches auto-buy on Upgrades")
	_click(main, shop.tab_buttons[ShopWindow.Page.HEROES])
	assert_eq(shop.page(), ShopWindow.Page.HEROES, "a click on the tab")
	# The tab remembered.
	_press(main, KEY_U)
	assert_false(shop.is_open(), "closed")
	_press(main, KEY_U)
	assert_eq(shop.page(), ShopWindow.Page.HEROES, "it opens on the tab it last showed")
	# Q and E belong to the window in front.
	_press(main, KEY_T)
	var measure: Tally.Measure = main.hud.tally.measure()
	_press(main, KEY_E)
	assert_ne(main.hud.tally.measure(), measure, "the tally in front takes E")
	assert_eq(shop.page(), ShopWindow.Page.HEROES, "not the Camp behind it")
	_press(main, KEY_T)
	# The tag counts the upgrades it can pay for and the classes it can recruit.
	_press(main, KEY_U)
	assert_false(shop.is_open(), "closed for its tag")
	sim.set_auto_buy(false)
	sim.party.gold = GOLD
	sim.party.set_resource(GLOWCAPS, CAPS)
	_frame(main)
	var upgrades: int = shop.affordable_count()
	assert_eq(shop.badge(), upgrades, "only upgrades before a find")
	await _find(main)
	_frame(main)
	assert_true(sim.roster.can_recruit(RECRUIT_CLASS), "setup: a class it can recruit")
	assert_eq(shop.badge(), shop.affordable_count() + 1, "and one class it can recruit")
	assert_eq(window.badge, shop.badge(), "on the bar's Camp button")
	sim.party.set_resource(GLOWCAPS, CAPS - 1)
	_frame(main)
	assert_eq(shop.badge(), shop.affordable_count(), "short of it: not counted")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_four_and_the_bench() -> void:
	# No one at camp.
	var plain: Main = _camp_main(ROOM_LARGE, true)
	var empty: RosterTab = await _open_heroes(plain)
	assert_eq(empty.bench_cards.size(), 0, "no bench cards")
	assert_true(empty.empty_line.is_visible_in_tree(), "the empty line shows")
	assert_eq(empty.empty_line.text, "No one at Camp. Recruit below.", "and says so")
	plain.free()
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	await _recruited(main)
	sim.party.heroes[0].level = 7
	var tab: RosterTab = await _open_heroes(main)
	_frame(main)
	assert_false(tab.empty_line.is_visible_in_tree(), "no empty line with someone at camp")
	assert_eq(tab.going_heading.text, "Going down", "the first group")
	assert_eq(tab.bench_heading.text, "At Camp", "the second")
	assert_eq(
		_card_ids(tab.field_cards), _hero_ids(sim.party.heroes), "the four, in formation order"
	)
	assert_eq(_card_ids(tab.bench_cards), _hero_ids(sim.party.bench), "the bench, by id")
	assert_eq(_card_ids(tab.bench_cards), [RECRUIT] as Array[int], "the recruit at camp")
	var sheet: PixelSheet = PixelSheet.load_sheet(HudFrame.ICONS_PATH)
	for card: RosterCard in tab.field_cards + tab.bench_cards:
		var hero: Hero = sim.party.hero(card.hero_id)
		var what: String = "card %d" % hero.id
		assert_eq(card.picture.texture_normal, sheet.part(hero.def().look()), "%s picture" % what)
		assert_eq(card.title_label.text, HeroTalentsTab.title(hero), "%s title" % what)
		assert_string_contains(card.title_label.text, hero.def().display_name, "%s class" % what)
		assert_eq(card.level_label.text, "Level %d" % hero.level, "%s level" % what)
		assert_eq(card.camp_label.is_visible_in_tree(), card.benched, "%s: At Camp" % what)
		assert_eq(card.benched, sim.party.bench.has(hero), "%s: its group" % what)
	assert_eq(tab.bench_cards[0].camp_label.text, "At Camp", "a card at camp says so")
	assert_eq(tab.field_cards[0].level_label.text, "Level 7", "a level as it is now")
	# A path walked names the hero.
	var knight: Hero = sim.party.hero(KNIGHT)
	knight.set_talents([Content.talent_tree(&"knight").path(0).nodes[0]] as Array[StringName])
	knight.ranks.set_xp(0, 50)
	_frame(main)
	var knight_card: RosterCard = _card_of(tab.field_cards, KNIGHT)
	assert_eq(knight_card.title_label.text, HeroTalentsTab.title(knight), "the title follows")
	assert_ne(knight_card.title_label.text, "Knight", "a path's name in it")
	# The tooltip.
	var tip: String = _tip_on(main, knight_card.title_label)
	assert_string_contains(tip, "Level %d" % knight.level, "the tip: level")
	assert_string_contains(tip, "%d talent point" % knight.talent_points(), "unspent points")
	var tree: TalentTreeDef = Content.talent_tree(&"knight")
	for path: int in tree.paths.size():
		var rank: String = (
			"%s rank %d" % [tree.path(path).display_name, knight.ranks.rank(path, tree)]
		)
		assert_string_contains(tip, rank, "the tip: a path's rank")
	# A click on a picture opens that hero's window.
	_click(main, knight_card.picture)
	assert_true(main.hud.hero_windows.is_open(KNIGHT), "the Knight's window opens")
	_click(main, tab.bench_cards[0].picture)
	var bench: UiWindow = main.ui.windows.window(HeroWindows.BENCH_ID)
	assert_true(bench != null and bench.is_open(), "the bench window opens")
	assert_eq(main.hud.hero_windows.window_of(RECRUIT), bench, "with the recruit")


# --- R3 ------------------------------------------------------------------------


func test_r3_two_clicks() -> void:
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	await _recruited(main)
	var tab: RosterTab = await _open_heroes(main)
	var benched: RosterCard = tab.bench_cards[0]
	var knight: RosterCard = _card_of(tab.field_cards, KNIGHT)
	# The lit card's own button drops the choice.
	_click(main, benched.swap_button)
	assert_eq(tab.chosen(), RECRUIT, "a click lights the recruit")
	assert_true(benched.lit, "its card is lit")
	assert_eq(tab.choosing_line.text, "Choose who the Test Recruit replaces", "the line")
	_click(main, benched.swap_button)
	assert_eq(tab.chosen(), -1, "its own button drops it")
	assert_false(benched.lit, "unlit")
	assert_eq(tab.choosing_line.text, "", "no line")
	# A Swap in the same group drops it.
	_click(main, knight.swap_button)
	assert_eq(tab.chosen(), KNIGHT, "the Knight lit")
	assert_eq(tab.choosing_line.text, "Choose who replaces the Knight", "from a card going down")
	_click(main, tab.field_cards[1].swap_button)
	assert_eq(tab.chosen(), -1, "a Swap in the same group drops it")
	# A click on a card of the same group drops it.
	_click(main, knight.swap_button)
	_click(main, tab.field_cards[2].title_label)
	assert_eq(tab.chosen(), -1, "a click on a card in the same group drops it")
	# Esc drops it, and leaves the window open.
	_click(main, benched.swap_button)
	_press(main, KEY_ESCAPE)
	assert_eq(tab.chosen(), -1, "Esc drops it")
	assert_true(main.hud.shop.is_open(), "the Camp stays open")
	_frame(main)
	assert_eq(sim.roster.waiting(), [] as Array[Vector2i], "nothing was asked")
	# Two clicks during a fight: the swap waits.
	var battle: Battle = _fight(main)
	assert_not_null(battle, "setup: a fight")
	_click(main, benched.swap_button)
	_click(main, knight.swap_button)
	assert_eq(sim.roster.waiting(), [Vector2i(RECRUIT, KNIGHT)] as Array[Vector2i], "asked")
	assert_eq(tab.chosen(), -1, "the light goes")
	_frame(main)
	assert_eq(benched.mark_label.text, "After this fight", "the recruit's card marked")
	assert_eq(knight.mark_label.text, "After this fight", "and the Knight's")
	assert_eq(tab.field_cards[1].mark_label.text, "", "no other")
	var done: bool = step_until(
		sim, func() -> bool: return sim.expedition.state != Expedition.State.FIGHTING, LIMIT_TICKS
	)
	assert_true(done, "setup: the fight ends")
	_frame(main, 0)
	_camp_out(main)
	assert_eq(sim.roster.waiting(), [] as Array[Vector2i], "made at camp")
	assert_true(sim.party.heroes.has(sim.party.hero(RECRUIT)), "the recruit goes down")
	assert_eq(_card_ids(tab.bench_cards), [KNIGHT] as Array[int], "the Knight at camp")
	assert_true(_card_ids(tab.field_cards).has(RECRUIT), "the recruit's card going down")
	for card: RosterCard in tab.field_cards + tab.bench_cards:
		assert_eq(card.mark_label.text, "", "no mark once made: %d" % card.hero_id)


func test_r3_cards_move_in_the_frame_heard() -> void:
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	await _recruited(main)
	var tab: RosterTab = await _open_heroes(main)
	_camp_out(main)
	_click(main, tab.bench_cards[0].swap_button)
	_click(main, _card_of(tab.field_cards, KNIGHT).swap_button)
	var heard: Array[bool] = [false]
	var check := func(event: SimEvent) -> void:
		if event.kind == SimEvent.Kind.HERO_FIELDED:
			heard[0] = true
			assert_eq(_card_ids(tab.bench_cards), [KNIGHT] as Array[int], "moved as it is heard")
	main.world.sim_event.connect(check)
	main.simulation.step()
	main.world.sync(STEP)
	assert_true(heard[0], "the swap is heard")
	assert_eq(_card_ids(tab.bench_cards), [KNIGHT] as Array[int], "the Knight's card at camp")
	assert_eq(_card_ids(tab.field_cards), _hero_ids(sim.party.heroes), "the four's cards")


# --- R4 ------------------------------------------------------------------------


func test_r4_recruiting() -> void:
	assert_true(UiIcon.has_picture(&"artifact"), "the shared artifact picture is found")
	assert_eq(UiIcon.picture(&"artifact").get_size(), UiIcon.PICTURE_SIZE, "16x16")
	assert_eq(
		RosterTab.hidden_text(3),
		"3 more heroes are out there. Their artifacts lie in caches down the side paths.",
		"many hidden"
	)
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	var def: HeroClassDef = Content.hero_class(RECRUIT_CLASS)
	sim.party.gold = 0
	var tab: RosterTab = await _open_heroes(main)
	_frame(main)
	assert_eq(tab.waiting_heading.text, "Waiting at Camp", "the section")
	assert_eq(tab.recruit_cards.size(), 0, "no one waits before a find")
	assert_true(tab.hidden_line.is_visible_in_tree(), "only the hidden line")
	assert_eq(
		tab.hidden_line.text.replace("\n", " "),
		"1 more hero is out there. Its artifact lies in caches down the side paths.",
		"one hidden"
	)
	assert_false(tab.hidden_line.text.contains(def.display_name), "no hidden class named")
	await _find(main)
	assert_eq(tab.recruit_cards.size(), 1, "a card for the class waiting")
	assert_false(tab.hidden_line.is_visible_in_tree(), "none hidden now")
	var card: RosterCard = tab.recruit_cards[0]
	assert_eq(card.class_id, RECRUIT_CLASS, "its class")
	assert_eq(card.title_label.text, "Test Recruit", "its name")
	assert_eq(card.picture.texture_normal, RosterCard.portrait(def), "its picture")
	assert_eq(card.artifact_label.text, "Test Whistle", "the artifact found")
	assert_eq(card.artifact_picture.texture, UiIcon.picture(&"artifact"), "the shared picture")
	assert_eq(
		card.arrives_label.text, "Arrives at level %d" % sim.roster.recruit_level(), "its level"
	)
	assert_eq(card.request_label.text, "Bring 300 gold and 40 Glowcaps", "its request")
	assert_eq(card.request_icon.texture, ResourceIcon.texture(GLOWCAPS), "with the icon")
	assert_true(card.request_icon.is_visible_in_tree(), "showing")
	sim.party.heroes[0].level = 9
	for hero: Hero in sim.party.heroes.slice(1):
		hero.level = 12
	_frame(main)
	assert_eq(card.arrives_label.text, "Arrives at level 9", "the lowest going down")
	# Short of it.
	sim.party.gold = 180
	sim.party.set_resource(GLOWCAPS, 25)
	_frame(main)
	assert_true(card.recruit_button.disabled, "off while short")
	assert_eq(
		_tip_on(main, card.recruit_button),
		"Needs 120 more gold and 15 more Glowcaps",
		"its tip says what is short"
	)
	sim.party.gold = GOLD
	_frame(main)
	assert_eq(_tip_on(main, card.recruit_button), "Needs 15 more Glowcaps", "only the caps")
	_click(main, card.recruit_button)
	_frame(main)
	_frame(main)
	assert_true(sim.party.bench.is_empty(), "a click on it does nothing")
	# Enough.
	sim.party.set_resource(GLOWCAPS, CAPS)
	_frame(main)
	assert_false(card.recruit_button.disabled, "on")
	_click(main, card.recruit_button)
	_frame(main)
	assert_eq(_hero_ids(sim.party.bench), [RECRUIT] as Array[int], "recruited")
	assert_eq(sim.party.gold, 0, "the gold paid")
	assert_eq(sim.party.resource(GLOWCAPS), 0, "the caps paid")
	assert_eq(tab.recruit_cards.size(), 0, "no one waits")
	assert_eq(_card_ids(tab.bench_cards), [RECRUIT] as Array[int], "the recruit at camp")
	assert_true(tab.hidden_line.is_visible_in_tree(), "the last line")
	assert_eq(tab.hidden_line.text, "Every class has joined the colony.", "says all have joined")
	# A request of gold alone.
	def.recruit_resource = &""
	def.recruit_resource_count = 0
	assert_eq(RosterCard.request_text(def), "Bring 300 gold", "gold alone")


# --- R5 ------------------------------------------------------------------------


func test_r5_moments() -> void:
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	var moment: UiMoment = main.ui.moment
	var tab: RosterTab = await _open_heroes(main)
	# A find: its banner.
	await _find(main)
	assert_true(moment.holds("Found a Test Whistle"), "a banner for the find")
	moment.advance(0.05)
	assert_eq(moment.shown_headline(), "Found a Test Whistle", "showing")
	assert_eq(moment.banner_line.text, "A Test Recruit waits at Camp", "and under it")
	assert_eq(moment.banner_picture.texture, UiIcon.picture(&"artifact"), "the artifact's picture")
	moment.banner_clicked()
	# A recruit: the card bursts and a banner.
	sim.party.gold = GOLD
	sim.party.set_resource(GLOWCAPS, CAPS)
	var bursts: int = moment.bursts_seen()
	_frame(main, 0)
	_click(main, tab.recruit_cards[0].recruit_button)
	_frame(main)
	assert_eq(_card_ids(tab.bench_cards), [RECRUIT] as Array[int], "setup: recruited")
	assert_true(moment.is_bursting(tab.bench_cards[0]), "the new hero's card bursts")
	assert_gt(moment.bursts_seen(), bursts, "a burst")
	assert_true(moment.holds("The Test Recruit joins the colony"), "and a banner")
	var picture: Texture2D = RosterCard.portrait(Content.hero_class(RECRUIT_CLASS))
	for i: int in 10:
		moment.advance(0.05)
		if moment.shown_headline() == "The Test Recruit joins the colony":
			break
	assert_eq(moment.banner_picture.texture, picture, "with its picture")
	moment.banner_clicked()
	await _frames()
	# A swap: both cards burst, no banner.
	_camp_out(main)
	moment.advance(UiMoment.BANNER_SECONDS * 2)
	_click(main, tab.bench_cards[0].swap_button)
	_click(main, _card_of(tab.field_cards, KNIGHT).swap_button)
	bursts = moment.bursts_seen()
	_frame(main)
	assert_eq(_card_ids(tab.bench_cards), [KNIGHT] as Array[int], "setup: swapped")
	assert_true(moment.is_bursting(tab.bench_cards[0]), "the Knight's card bursts")
	assert_true(moment.is_bursting(_card_of(tab.field_cards, RECRUIT)), "and the recruit's")
	assert_eq(moment.bursts_seen(), bursts + 2, "two bursts")
	assert_eq(moment.shown_headline(), "", "no banner")
	assert_eq(moment.waiting(), 0, "none waiting")


func test_r5_nothing_for_stale_ones() -> void:
	var main: Main = _camp_main()
	var sim: Simulation = main.simulation
	var moment: UiMoment = main.ui.moment
	var tab: RosterTab = await _open_heroes(main)
	ArtifactFinds._find(sim.expedition, RECRUIT_CLASS, KNIGHT)
	_frame(main, STALE_TICKS)
	await _frames()
	assert_eq(tab.recruit_cards.size(), 1, "a stale find: the card is there")
	assert_false(moment.holds("Found a Test Whistle"), "no banner")
	sim.party.gold = GOLD
	sim.party.set_resource(GLOWCAPS, CAPS)
	_frame(main, 0)
	_click(main, tab.recruit_cards[0].recruit_button)
	var bursts: int = moment.bursts_seen()
	_frame(main, STALE_TICKS)
	await _frames()
	assert_eq(
		_card_ids(tab.bench_cards), [RECRUIT] as Array[int], "a stale recruit: its card moves"
	)
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	assert_false(moment.holds("The Test Recruit joins the colony"), "no banner")
	_camp_out(main)
	_click(main, tab.bench_cards[0].swap_button)
	_click(main, _card_of(tab.field_cards, KNIGHT).swap_button)
	bursts = moment.bursts_seen()
	_frame(main, STALE_TICKS)
	await _frames()
	assert_eq(_card_ids(tab.bench_cards), [KNIGHT] as Array[int], "a stale swap: the cards move")
	assert_eq(moment.bursts_seen(), bursts, "no burst")


# --- R6 ------------------------------------------------------------------------


## Checks that every text the Heroes tab shows is whole, inside the scrolled content, and clear of
## every other, and that every card is inside the window.
func _check_tab(main: Main, what: String) -> void:
	var shop: ShopWindow = main.hud.shop
	var window: Rect2 = shop.window().get_global_rect()
	var room := Rect2(Vector2.ZERO, Vector2(main.ui.room()))
	assert_lte(window.size.y, room.size.y, "%s: never taller than the room" % what)
	assert_true(room.encloses(window), "%s: inside the room" % what)
	var view: Rect2 = shop.heroes_scroll.get_global_rect()
	assert_true(window.encloses(view), "%s: the tab inside the window" % what)
	var content: Rect2 = view
	content.position.y -= shop.heroes_scroll.scroll_vertical
	content.size.y = maxf(view.size.y, shop.heroes_scroll.get_v_scroll_bar().max_value)
	content.size.x = view.size.x
	var tab: RosterTab = shop.heroes
	for card: RosterCard in tab.field_cards + tab.bench_cards + tab.recruit_cards:
		var box: Rect2 = card.get_global_rect()
		assert_true(
			content.encloses(box), "%s: %s inside: %s in %s" % [what, card.name, box, content]
		)
	var labels: Array[Label] = _shown_labels(tab)
	var rects: Array[Rect2] = []
	for label: Label in labels:
		var inked: Rect2 = _text_rect(label)
		rects.append(inked)
		var named: String = "%s: '%s'" % [what, label.text.replace("\n", " / ")]
		assert_true(content.encloses(inked), "%s inside" % named)
		assert_lte(inked.size.x, label.size.x + 1.0, "%s not cut at its right" % named)
		assert_false(label.clip_text, "%s not clipped" % named)
	for a: int in labels.size():
		for b: int in range(a + 1, labels.size()):
			if rects[a].intersects(rects[b]):
				fail_test("%s: '%s' overlaps '%s'" % [what, labels[a].text, labels[b].text])


## Gives [param hero] the first node of the path with the longest name, so its title is longest.
static func _longest_title(hero: Hero) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var longest: int = 0
	for path: int in tree.paths.size():
		if tree.path(path).display_name.length() > tree.path(longest).display_name.length():
			longest = path
	hero.set_talents([tree.path(longest).nodes[0]] as Array[StringName])


func test_r6_fits() -> void:
	for room: Vector2i in [ROOM_SMALL, ROOM_LARGE]:
		var bare: Main = _camp_main(room, true)
		_frame(bare, 0)
		await _frames()
		var bar_size: Vector2 = bare.ui.bar.size
		var upgrades_height: float = bare.ui.windows.window(ShopWindow.ID).size.y
		bare.free()
		var main: Main = _camp_main(room)
		var sim: Simulation = main.simulation
		for hero: Hero in sim.party.heroes:
			_longest_title(hero)
			hero.level = 250
		sim.party.gold = 0
		await _find(main)
		var tab: RosterTab = await _open_heroes(main)
		_click(main, tab.field_cards[0].swap_button)
		_frame(main, 0)
		await _frames()
		_check_tab(main, "%s, one waiting, a choice" % room)
		assert_eq(main.ui.bar.size, bar_size, "%s: the bar's size unchanged" % room)
		await _recruited(main)
		var benched: Hero = sim.party.hero(RECRUIT)
		benched.level = 250
		_longest_title(benched)
		_click(main, tab.bench_cards[0].swap_button)
		_click(main, tab.field_cards[0].swap_button)
		_frame(main)
		await _frames()
		main.ui.moment.advance(UiMoment.BURST_SECONDS)  # the bursts over, the cards at rest
		_check_tab(main, "%s, one at camp, a swap waiting" % room)
		var window: UiWindow = main.ui.windows.window(ShopWindow.ID)
		assert_eq(window.size.y, upgrades_height, "%s: as tall on either tab" % room)
		assert_eq(main.ui.bar.size, bar_size, "%s: the bar's size unchanged" % room)
		main.free()


# --- R7 ------------------------------------------------------------------------


func test_r7_keys_help_wiki_showcase() -> void:
	var keys: Dictionary[String, String] = {}
	for entry: Array in KeyBook.entries():
		keys[str(entry[0])] = str(entry[1])
	assert_eq(str(keys.get("B", "")), "Upgrades tab: auto-buy on or off", "B")
	assert_eq(str(keys.get("1-5", "")), "Upgrades tab: buy that upgrade", "1-5")
	assert_eq(str(keys.get("Q E", "")), "Hero window, Tally or Camp: change tab", "Q E")
	var help: String = " ".join(PackedStringArray(HelpPanel.IDEA))
	assert_string_contains(help, "Heroes tab", "help: where heroes are recruited")
	assert_string_contains(help, "Camp", "in the Camp")
	assert_string_contains(help, "Going down", "help: who fights")
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for phrase: String in [
		"The colony and recruiting",
		"112 The roster",
		"113 The party changes on screen",
		"114 The Heroes tab at camp",
		"After this fight",
		"Waiting at Camp",
	]:
		assert_true(wiki.contains(phrase), "the wiki tells of it: %s" % phrase)
	var planned: int = wiki.find("Not built yet")
	var line: String = wiki.substr(planned, wiki.find("</p>", planned) - planned)
	assert_false(line.contains("spec 114"), "the roster is built: %s" % line)
	assert_false(line.to_lower().contains("recruit"), "nothing to recruit is planned")
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"camp_heroes")
	var start: float = showcase.elapsed
	while showcase.moment() == &"camp_heroes" and showcase.elapsed - start < 10.0:
		showcase.advance(1.0 / 30.0)
		if showcase.evidence.has(&"camp_heroes"):
			break
	assert_true(showcase.evidence.has(&"camp_heroes"), "the showcase's moment is seen")
	var shop: ShopWindow = showcase.main.hud.shop
	assert_true(shop.is_open(), "the Camp window open")
	assert_eq(shop.page(), ShopWindow.Page.HEROES, "on its Heroes tab")
	assert_eq(shop.heroes.field_cards.size(), 4, "the four going down")
	showcase.free()

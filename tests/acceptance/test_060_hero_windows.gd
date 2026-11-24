extends "res://tests/acceptance/hero_windows_test_base.gd"
## Acceptance tests for specs/060-hero-windows/spec.md, one per requirement.
##
## Each test runs the main scene with its processing off, the UI layer laid out for a chosen room,
## and drives the hero windows with real clicks and keys pushed into the viewport (the helpers are
## in hero_windows_test_base.gd and MainFixture); the simulation is stepped after each
## command and checked.

# --- R1 ------------------------------------------------------------------------


func test_r1_a_window_per_hero() -> void:
	var settings := SoundSettings.new(_settings_path)
	var main: Main = _main(ROOM_LARGE, settings)
	await _frames()
	var windows: UiWindows = main.ui.windows
	var heroes: Array[Hero] = main.simulation.party.heroes
	# A click opens a hero's window; a second closes it.
	_click_frame(main, heroes[0])
	assert_true(windows.is_open(&"hero_0"), "a click on the frame opens its window")
	assert_true(windows.window(&"hero_0") is HeroWindow, "a window of spec 058")
	assert_eq(_window(main, heroes[0]).hero_id, heroes[0].id, "the hero's own")
	assert_true(_frame_of(main, heroes[0]).marked, "its frame has the yellow edge")
	_click_frame(main, heroes[0])
	assert_false(windows.is_open(&"hero_0"), "a second click closes it")
	assert_false(_frame_of(main, heroes[0]).marked, "and the edge goes")
	# Four at once, one per hero, the last opened in front.
	for hero: Hero in heroes:
		_click_frame(main, hero)
	for i: int in heroes.size():
		var id := StringName("hero_%d" % i)
		assert_true(windows.is_open(id), "%s open beside the others" % id)
		assert_true(_frame_of(main, heroes[i]).marked, "frame %d edged" % i)
	assert_eq(windows.front(), _window(main, heroes[3]), "the last opened in front")
	_click_frame(main, heroes[1])
	assert_false(windows.is_open(&"hero_1"), "one closed")
	# Shift+Tab closes the front hero window only.
	_press(main, KEY_TAB, true)
	assert_false(windows.is_open(&"hero_3"), "Shift+Tab closes the front hero window")
	assert_true(windows.is_open(&"hero_0") and windows.is_open(&"hero_2"), "and only it")
	assert_false(_frame_of(main, heroes[3]).marked, "its frame loses its edge")
	# Tab opens the next hero's window and brings it to the front, closing none.
	assert_eq(windows.front(), _window(main, heroes[2]), "hero 2 in front")
	_press(main, KEY_TAB)
	assert_true(windows.is_open(&"hero_3"), "Tab opens the next hero's window")
	assert_eq(windows.front(), _window(main, heroes[3]), "in front")
	assert_true(windows.is_open(&"hero_0") and windows.is_open(&"hero_2"), "closing none")
	_press(main, KEY_TAB)
	assert_eq(windows.front(), _window(main, heroes[0]), "an open one is brought to the front")
	_press(main, KEY_TAB)
	assert_true(windows.is_open(&"hero_1"), "and on to the next closed one")
	assert_eq(windows.front(), _window(main, heroes[1]), "in front")
	# Movable and layered: a click on one brings it to the front; a drag moves it.
	var back: HeroWindow = _window(main, heroes[2])
	_click_ui(main.ui, _visible_point(main, back))
	assert_eq(windows.front(), back, "a click raises it")
	var was: Vector2 = back.position
	_drag(main.ui, back, Vector2(40, 30))
	assert_eq(back.position, was + Vector2(40, 30), "dragged by its title bar")
	# Remembered per hero: a new game with the same settings puts each back as it was.
	var open_before: Array[bool] = []
	for hero: Hero in heroes:
		open_before.append(main.hud.hero_windows.is_open(hero.id))
	main.free()
	var again: Main = _main(ROOM_LARGE, settings)
	again.ui.windows.open_waiting()
	await _frames()
	for i: int in heroes.size():
		var id := StringName("hero_%d" % i)
		assert_eq(again.ui.windows.is_open(id), open_before[i], "%s open as it was" % id)
	assert_eq(again.ui.windows.window(&"hero_2").position, was + Vector2(40, 30), "its place")
	var other: UiWindow = again.ui.windows.window(&"hero_0")
	assert_eq(other.position, other.default_place, "another hero's window keeps its own")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_header() -> void:
	var main: Main = _main(ROOM_LARGE)
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 8)
	knight.set_talents(Content.talent_tree(&"knight").trunk)
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.STATS)
	await _frames()
	var icon: Texture2D = main.hud.icon(&"knight")
	assert_eq(shown.portrait.texture, icon, "the class portrait")
	assert_eq(shown.portrait.size, Vector2(icon.get_size()) * 2.0, "at twice the size")
	assert_eq(shown.line(&"class"), "Knight", "the class")
	assert_eq(shown.class_label.get_theme_font(&"font"), UiText.font(true), "in bold")
	set_level_keeping_health(knight, 10)
	knight.set_talents(_walked(&"knight", 1, 1))
	main.hud.advance(STEP)
	assert_eq(shown.line(&"class"), "Knight, Berserker", "and its path")
	assert_eq(shown.line(&"role"), "Tank", "the role")
	assert_eq(shown.line(&"level"), "Level 10", "the level")
	var doing: String = shown.line(&"activity")
	assert_true(doing in ["Walking", "Resting", "Moving on"], "what it does now: %s" % doing)
	knight.health = knight.max_health() / 2
	main.hud.advance(STEP)
	assert_eq(
		shown.line(&"health"),
		"%d / %d" % [knight.health, knight.max_health()],
		"health with numbers"
	)
	main.hud.advance(1.0)
	assert_almost_eq(shown.bar_fraction(&"health"), 0.5, 0.01, "and a bar")
	var floor_xp: int = Hero.xp_for_level(10)
	var next_xp: int = Hero.xp_for_level(11)
	knight.xp = floor_xp + 30
	main.hud.advance(1.0)
	assert_eq(
		shown.line(&"xp"),
		"%d / %d XP, %d to level 11" % [30, next_xp - floor_xp, next_xp - knight.xp],
		"XP with numbers"
	)
	assert_almost_eq(shown.bar_fraction(&"xp"), 30.0 / (next_xp - floor_xp), 0.01, "and a bar")
	# The header shows on every tab.
	for page: HeroWindow.Page in [HeroWindow.Page.TALENTS, HeroWindow.Page.SKILLS]:
		_click(main, shown.tab_buttons[page])
		assert_true(shown.class_label.is_visible_in_tree(), "the header on tab %d" % page)
		assert_true(shown.portrait.is_visible_in_tree(), "the portrait on tab %d" % page)


# --- R3 ------------------------------------------------------------------------


func test_r3_tabs() -> void:
	var main: Main = _main(ROOM_LARGE)
	var knight: Hero = _hero(main, &"knight")
	var mage: Hero = _hero(main, &"mage")
	set_level_keeping_health(knight, 4)
	var first: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var names: Array[String] = []
	for button: UiButton in first.tab_buttons:
		names.append(button.text)
	assert_eq(names, ["Stats", "Talents", "Skills"] as Array[String], "three tabs")
	assert_eq(
		HeroWindow.TAB_NAMES, ["Stats", "Talents", "Skills"] as Array[String], "Training is Talents"
	)
	assert_eq(first.tab_buttons[HeroWindow.Page.TALENTS].text, "Talents", "the tab's name")
	# A node's picture is its ability's 16x16 at twice its size, in every class's tree.
	for hero: Hero in main.simulation.party.heroes:
		for node: TalentNode in _window(main, hero).talents.tree_view().nodes():
			assert_eq(node.icon.size, Vector2(32, 32), "%s: 16x16 at twice its size" % node.name)
	# The window keeps one size on every tab: it does not grow for the tree.
	var tall: Vector2 = first.size
	_click(main, first.tab_buttons[HeroWindow.Page.STATS])
	main.hud.advance(STEP)
	assert_eq(first.size, tall, "Stats, the same size")
	_click(main, first.tab_buttons[HeroWindow.Page.TALENTS])
	# The tags count what waits on each tab.
	assert_true(first.talents_tag.is_visible_in_tree(), "a tag on Talents")
	assert_eq(first.talents_tag.text, "2", "two talent points")
	var tab: Rect2 = first.tab_buttons[HeroWindow.Page.TALENTS].get_global_rect()
	assert_true(first.talents_tag.get_global_rect().intersects(tab), "on the tab")
	_click(main, first.talents.node(Content.talent_tree(&"knight").trunk[0]))
	_frame(main)
	assert_eq(first.talents_tag.text, "1", "one left")
	set_level_keeping_health(mage, 3)
	var second: HeroWindow = _open(main, mage, HeroWindow.Page.STATS)
	var learned: int = mage.microskills().size()
	set_level_keeping_health(mage, 6)
	main.hud.advance(STEP)
	var new_skills: int = mage.microskills().size() - learned
	assert_gt(new_skills, 0, "the mage learns a microskill between levels 3 and 6")
	assert_true(second.skills_tag.is_visible_in_tree(), "a tag on Skills: a new microskill")
	assert_eq(second.skills_tag.text, str(new_skills), "counting it")
	# Q and E change the front window's tab only, wrapping.
	assert_eq(main.ui.windows.front(), second, "the mage's in front")
	_press(main, KEY_E)
	assert_eq(second.page(), HeroWindow.Page.TALENTS, "E: the next tab")
	assert_eq(first.page(), HeroWindow.Page.TALENTS, "the other keeps its own")
	_press(main, KEY_E)
	assert_eq(second.page(), HeroWindow.Page.SKILLS, "E again")
	assert_false(second.skills_tag.is_visible_in_tree(), "the Skills tab seen: no tag")
	_press(main, KEY_E)
	assert_eq(second.page(), HeroWindow.Page.STATS, "wrapping")
	_press(main, KEY_Q)
	assert_eq(second.page(), HeroWindow.Page.SKILLS, "Q: the previous tab, wrapping")
	assert_eq(first.page(), HeroWindow.Page.TALENTS, "the knight's still on Talents")
	# Each window remembers its own tab, closed and opened again.
	_click_frame(main, knight)
	_click_frame(main, knight)
	assert_eq(first.page(), HeroWindow.Page.TALENTS, "the knight's opens on Talents")
	assert_eq(second.page(), HeroWindow.Page.SKILLS, "the mage's on Skills")
	assert_true(first.talents.is_visible_in_tree(), "showing it")
	assert_false(first.stats.is_visible_in_tree(), "and only it")


func test_r3_keys_reach_only_the_front_window() -> void:
	# Since spec 059 the shop and the tally are windows too: the shop, a hero window on Talents and
	# the tally stand open together, and each key goes to the front window only. 1 to 5 and B are
	# the shop's, 1 to 3 the hero window's on Talents, Q and E the hero window's or the tally's.
	var main: Main = _main(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var windows: UiWindows = main.ui.windows
	sim.party.gold = RICH
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 20)
	knight.set_talents(_walked(&"knight", 0, 4))
	main.hud.advance(STEP)
	_press(main, KEY_U)
	_frame(main)
	var shop: UiWindow = windows.window(ShopWindow.ID)
	assert_true(shop.is_open(), "U opens the shop")
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	assert_true(shop.is_open(), "a hero window opening leaves the shop open")
	_press(main, KEY_T)
	main.hud.advance(STEP)
	await _frames()
	var tally: TallyWindow = main.hud.tally
	assert_true(tally.is_open() and shown.is_open() and shop.is_open(), "all three open together")

	for front: String in ["tally", "hero", "shop"]:
		match front:
			"tally":
				_click_ui(main.ui, _plain_point(main, windows.window(TallyWindow.ID)))
			"hero":
				_click_ui(main.ui, _visible_point(main, shown))
			"shop":
				_click_ui(main.ui, _plain_point(main, shop))
		main.hud.advance(STEP)
		var expected: UiWindow = {
			"tally": windows.window(TallyWindow.ID), "hero": shown, "shop": shop
		}[front]
		assert_eq(windows.front(), expected, "a click makes the %s the front window" % front)
		var blades: int = sim.party.upgrades.rank(&"sharp_blades")
		var gold: int = sim.party.gold
		var power: int = knight.paragon_rank(TrainingDef.Stat.POWER)
		var auto: bool = sim.auto_buy
		var measure: Tally.Measure = tally.measure()
		var page: HeroWindow.Page = shown.page()
		_press(main, KEY_1)
		_frame(main)  # a command lands on the next tick
		var bought: int = 1 if front == "shop" else 0
		var trained: int = 1 if front == "hero" else 0
		var why: String = "the %s in front" % front
		assert_eq(sim.party.upgrades.rank(&"sharp_blades"), blades + bought, "1, %s: a buy" % why)
		if bought == 0:
			assert_eq(sim.party.gold, gold, "1, %s: no gold spent" % why)
		var points: int = knight.paragon_rank(TrainingDef.Stat.POWER)
		assert_eq(points, power + trained, "1, %s: a paragon point" % why)
		_press(main, KEY_B)
		_frame(main)
		assert_eq(sim.auto_buy, auto != (front == "shop"), "B, %s: auto-buy" % why)
		if sim.auto_buy:
			sim.set_auto_buy(false)
			_frame(main)
		_press(main, KEY_E)
		var tally_tab: Tally.Measure = tally.measure()
		var moved: bool = front == "tally"
		assert_eq(tally_tab != measure, moved, "E, %s: the tally's tab" % why)
		assert_eq(shown.page() != page, front == "hero", "E, %s: the hero window's tab" % why)
		_press(main, KEY_Q)
		assert_eq(tally.measure(), measure, "Q, %s: the tally's tab back" % why)
		assert_eq(shown.page(), page, "Q, %s: the hero window's tab back" % why)
		assert_true(tally.is_open() and shown.is_open() and shop.is_open(), "%s: all open" % why)

	# Tab brings the next hero's window in front whatever is in front; Esc closes the front one.
	assert_eq(windows.front(), shop, "the shop in front")
	_press(main, KEY_TAB)
	main.hud.advance(STEP)
	var next: UiWindow = windows.front()
	assert_true(next is HeroWindow and next != shown, "Tab: the next hero's window in front")
	assert_true(shop.is_open(), "the shop stays open")
	_press(main, KEY_ESCAPE)
	main.hud.advance(STEP)
	assert_false(next.is_open(), "Esc closes the front window")
	assert_true(shown.is_open() and shop.is_open() and tally.is_open(), "and only it")


## A point on [param shown] that shows it, on no button: its title bar's, if one shows, else
## [method _visible_point]'s.
func _plain_point(main: Main, shown: UiWindow) -> Vector2:
	var bar: Rect2 = shown.title_bar.get_global_rect()
	for x: int in range(int(bar.position.x) + 4, int(bar.end.x) - 24, 8):
		var at := Vector2(x, bar.get_center().y)
		if main.ui.windows.window_at(main.ui.ui_to_world(at)) == shown:
			return at
	return _visible_point(main, shown)


# --- R4 ------------------------------------------------------------------------


func test_r4_stats_with_reasons() -> void:
	var main: Main = _main(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var cleric: Hero = _hero(main, &"cleric")
	var shown: HeroWindow = _open(main, cleric, HeroWindow.Page.STATS)
	var plain: Combatant = cleric.combatant()
	assert_eq(shown.line(&"stat_damage"), "Damage %d" % plain.damage, "no bonus: no reason")
	sim.upgrades.set_rank(&"sharp_blades", 3)
	sim.upgrades.set_rank(&"stout_armor", 2)
	set_level_keeping_health(cleric, 17)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.QUICKNESS)
	_frame(main)
	var fighter: Combatant = cleric.combatant()
	assert_eq(
		shown.line(&"stat_damage"),
		"Damage %d +15%% Sharp Blades, +6%% Power" % fighter.damage,
		"what raises damage, in words"
	)
	assert_eq(
		shown.line(&"stat_healing"),
		"Healing %d +15%% Sharp Blades, +6%% Power" % fighter.heal_power,
		"and healing"
	)
	assert_eq(
		shown.line(&"stat_health"),
		"Health %d +10%% Stout Armor" % cleric.max_health(),
		"health from the camp's armour"
	)
	var speed: float = 1.03 / cleric.def().attack_interval
	assert_eq(
		shown.line(&"stat_attack_speed"),
		"Attack speed %.1f/s +3%% Quickness" % speed,
		"attack speed from Quickness"
	)
	assert_eq(shown.line(&"stat_armor"), "Armor %d" % fighter.armor, "armour: nothing raises it")
	for key: StringName in [&"stat_damage", &"stat_health", &"stat_attack_speed"]:
		var reason: Label = shown.stats.reason_labels[key]
		assert_eq(reason.get_theme_color(&"font_color"), Palette.color(&"green"), "%s green" % key)
		var value: Label = shown.stats.value_labels[key]
		assert_gt(reason.position.x, value.position.x, "%s: beside the value" % key)
		assert_eq(reason.position.y, value.position.y, "%s: on its line" % key)
	# Each stat on a line of its own.
	var rows: Dictionary[float, bool] = {}
	for key: StringName in shown.stats.value_labels:
		var value: Label = shown.stats.value_labels[key]
		if value.is_visible_in_tree():
			assert_false(rows.has(value.position.y), "%s on its own line" % key)
			rows[value.position.y] = true


# --- R5 ------------------------------------------------------------------------


func test_r5_the_tree_readable_without_pointing() -> void:
	var main: Main = _main(ROOM_LARGE)
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var class_tree: TalentTreeDef = Content.talent_tree(class_id)
		for path: int in 2:
			set_level_keeping_health(hero, 10)
			hero.set_talents(_walked(class_id, path, 1))
			var opened: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
			main.hud.advance(STEP)
			var view: TalentTreeView = opened.talents.tree_view()
			for id: StringName in class_tree.path_nodes(1 - path):
				var closed: TalentNode = view.node(id)
				# Spec 064: its name, where spec 060 had its description.
				assert_true(closed.name_label.is_visible_in_tree(), "%s: still readable" % id)
				assert_eq(
					closed.name_label.get_theme_color(&"font_color"),
					Palette.color(TalentNode.DIM),
					"%s: dimmed" % id
				)
			_click_frame(main, hero)


func test_r5_keys_1_to_3_reach_only_the_front_window_on_talents() -> void:
	var main: Main = _main(ROOM_LARGE)
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 17)
	_open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	# Keys 1 to 3 belong to the front hero window, on its Talents tab only.
	var mage: Hero = _hero(main, &"mage")
	set_level_keeping_health(mage, 17)
	var front: HeroWindow = _open(main, mage, HeroWindow.Page.STATS)
	assert_eq(main.ui.windows.front(), front, "the mage's in front, on Stats")
	_press(main, KEY_3)
	_frame(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.QUICKNESS), 0, "not the window behind")
	assert_eq(mage.paragon_rank(TrainingDef.Stat.QUICKNESS), 0, "not on Stats")
	_click(main, front.tab_buttons[HeroWindow.Page.TALENTS])
	_press(main, KEY_3)
	_frame(main)
	assert_eq(mage.paragon_rank(TrainingDef.Stat.QUICKNESS), 1, "the front one, on Talents")


func test_r5_a_question_seen_without_scrolling() -> void:
	var main: Main = _main(ROOM_SMALL)
	var mage: Hero = _hero(main, &"mage")
	var tree: TalentTreeDef = Content.talent_tree(&"mage")
	set_level_keeping_health(mage, 8)
	mage.set_talents(tree.trunk)
	var shown: HeroWindow = _open(main, mage, HeroWindow.Page.TALENTS)
	await _frames()
	assert_true(shown.scrolls(), "the tab scrolls at 960x540")
	# Scrolled to the bottom, or as near it as leaves the path's first node in view.
	var first: TalentNode = shown.talents.node(tree.path_nodes(1)[0])
	var bar: VScrollBar = shown.scroll.get_v_scroll_bar()
	shown.scroll.scroll_vertical = int(bar.max_value)
	await _frames()
	var view: Rect2 = shown.scroll.get_global_rect()
	var over: float = view.position.y - first.get_global_rect().position.y
	if over > 0.0:
		shown.scroll.scroll_vertical -= ceili(over)
		await _frames()
	var scrolled: int = shown.scroll.scroll_vertical
	assert_gt(scrolled, 0, "scrolled down")
	assert_true(view.encloses(first.get_global_rect()), "the path's first node in view")
	_click(main, first)
	await _frames()
	assert_eq(shown.talents.asking(), HeroTalentsTab.Asking.PATH, "the question")
	var window: Rect2 = shown.get_global_rect()
	for control: Control in [
		shown.talents.ask_label, shown.talents.choose_button, shown.talents.not_yet_button
	]:
		assert_true(control.is_visible_in_tree(), "%s shows" % control.name)
		assert_true(
			window.encloses(control.get_global_rect()), "%s inside the window" % control.name
		)
		assert_false(shown.scroll.is_ancestor_of(control), "%s outside what scrolls" % control.name)
	assert_eq(shown.scroll.scroll_vertical, scrolled, "the view stays where it was")
	assert_true(view.encloses(first.get_global_rect()), "the node clicked still in view")
	_click(main, shown.talents.choose_button)
	_frame(main)
	assert_eq(mage.path(), 1, "Choose sends it")


# --- R6 ------------------------------------------------------------------------


func test_r6_skills() -> void:
	var main: Main = _main(ROOM_LARGE)
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var def: HeroClassDef = hero.def()
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.SKILLS)
		var cards: Array[HeroSkillsTab.Card] = shown.skills.cards
		assert_eq(cards.size(), def.microskills.size(), "%s: a card per microskill" % class_id)
		# At level 1 every card is to come, at level 30 every one is learned.
		for hero_level: int in [1, 30]:
			set_level_keeping_health(hero, hero_level)
			main.hud.advance(STEP)
			for i: int in cards.size():
				var card: HeroSkillsTab.Card = cards[i]
				var skill: MicroskillDef = Content.microskill(def.microskills[i])
				var level: int = def.microskill_levels[i]
				var named: String = "%s at level %d: %s" % [class_id, hero_level, skill.id]
				assert_true(card.is_visible_in_tree(), "%s shows" % named)
				assert_eq(card.name_label.text, skill.display_name, "%s: its name" % named)
				var answers: Array[String] = []
				for quest_id: StringName in Content.quest_ids():
					var quest: QuestDef = Content.quest(quest_id)
					if quest.microskill == skill.id:
						answers.append(quest.display_name)
				assert_eq(hero.level >= level, hero_level == 30, "%s: learned only by 30" % named)
				if hero.level >= level:
					assert_true(card.learned, "%s learned" % named)
					assert_eq(
						card.text_label.text.replace("\n", " "), skill.description + ".", named
					)
					for answer: String in answers:
						assert_true(
							card.answers_label.text.contains(answer),
							"%s answers %s" % [named, answer]
						)
					assert_eq(
						card.name_label.get_theme_color(&"font_color"),
						Palette.color(&"white"),
						named
					)
				else:
					assert_false(card.learned, "%s to come" % named)
					assert_eq(
						card.text_label.text, "Comes at level %d" % level, "%s: its level" % named
					)
					assert_eq(
						card.name_label.get_theme_color(&"font_color"),
						Palette.color(TalentNode.DIM),
						"%s: dimmed" % named
					)
		_click_frame(main, hero)


# --- R7 ------------------------------------------------------------------------


func test_r7_compare() -> void:
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		var main: Main = _main(room)
		var heroes: Array[Hero] = main.simulation.party.heroes
		var named_room: String = "%dx%d" % [room.x, room.y]
		# Alone, and with all four open: inside the room, under the top band, clear of the button
		# bar and of the frames' line (spec 058's own check leaves hero windows out).
		for hero: Hero in heroes:
			var alone: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
			await _frames()
			_check_clear(main, alone, "%s %s alone" % [named_room, hero.class_id])
			_click_frame(main, hero)
		for hero: Hero in heroes:
			_open(main, hero, HeroWindow.Page.TALENTS)
		await _frames()
		for hero: Hero in heroes:
			_check_clear(main, _window(main, hero), "%s %s of four" % [named_room, hero.class_id])
		main.hud.hero_windows.close_all()
		# Any two heroes compare: side by side at 1280x720, cascaded with both titles at 960x540.
		for i: int in heroes.size():
			for j: int in range(i + 1, heroes.size()):
				var back: HeroWindow = _open(main, heroes[i], HeroWindow.Page.TALENTS)
				var over: HeroWindow = _open(main, heroes[j], HeroWindow.Page.TALENTS)
				await _frames()
				var named: String = "%s heroes %d and %d" % [named_room, i, j]
				var first: Rect2 = back.get_global_rect()
				var second: Rect2 = over.get_global_rect()
				if room == ROOM_LARGE:
					assert_false(first.intersects(second), "%s: side by side" % named)
					assert_eq(first.position.y, second.position.y, "%s: level" % named)
					assert_false(back.scrolls(), "%s: the whole tree shows" % named)
				else:
					assert_ne(first.position, second.position, "%s: offset" % named)
					var title: Rect2 = back.title_label.get_global_rect()
					title.size.x = UiText.width(back.title, true)
					assert_false(second.intersects(title), "%s: the back title shows" % named)
				for shown: HeroWindow in [back, over]:
					_check_clear(main, shown, named)
				main.hud.hero_windows.close_all()
		main.free()
	# Too short at 960x540 for the whole tree: the Talents tab scrolls inside the window.
	var small: Main = _main(ROOM_SMALL)
	var front: HeroWindow = _open(small, small.simulation.party.heroes[3], HeroWindow.Page.TALENTS)
	await _frames()
	assert_true(front.scrolls(), "960x540: the Talents tab scrolls")
	var view: Rect2 = front.scroll.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, Vector2(ROOM_SMALL)).encloses(view), "the scrolled view shows")
	var bar: VScrollBar = front.scroll.get_v_scroll_bar()
	assert_true(bar.is_visible_in_tree(), "960x540: with its scroll bar")
	var lowest: TalentNode = front.talents.tree_view().path_nodes[0][3]
	var at: Vector2 = small.ui.ui_to_world(view.get_center())
	mouse_button(at, true, MOUSE_BUTTON_WHEEL_DOWN)
	mouse_button(at, false, MOUSE_BUTTON_WHEEL_DOWN)
	assert_gt(front.scroll.scroll_vertical, 0, "960x540: the wheel scrolls it")
	front.scroll.scroll_vertical = int(bar.max_value)
	await _frames()
	# Spec 064: the last node's name, and the strip at the tree's foot (the paragon row shows only
	# once there are paragon points).
	assert_true(
		view.encloses(_text_rect(lowest.name_label)),
		"960x540: scrolled down, the last node reads whole"
	)
	assert_true(view.encloses(front.talents.strip.get_global_rect()), "and the strip too")
	front.open_page(HeroWindow.Page.STATS)
	assert_eq(front.scroll.scroll_vertical, 0, "another tab starts at its top")


# --- R9 ------------------------------------------------------------------------


func test_r9_true_in_a_crowded_frame() -> void:
	var main: Main = _main(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var cleric: Hero = _hero(main, &"cleric")
	var tree: TalentTreeDef = Content.talent_tree(&"knight")
	var first: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var second: HeroWindow = _open(main, cleric, HeroWindow.Page.STATS)
	main.hud.advance(STEP)
	var told: Array[SimEvent] = []
	main.world.sim_event.connect(func(event: SimEvent) -> void: told.append(event))
	# Level-ups, a talent taken and a fight, all in one frame of 300 ticks.
	cleric.xp = Hero.xp_for_level(3) - 1
	set_level_keeping_health(knight, 2)
	knight.xp = Hero.xp_for_level(4) - 1
	sim.take_talent(knight.id, tree.trunk[0])
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)
	var kinds: Dictionary[SimEvent.Kind, bool] = {}
	for event: SimEvent in told:
		kinds[event.kind] = true
	assert_true(kinds.has(SimEvent.Kind.LEVEL_UP), "the frame held level-ups")
	assert_true(kinds.has(SimEvent.Kind.TALENT_TAKEN), "a talent taken")
	assert_true(kinds.has(SimEvent.Kind.ENCOUNTER_STARTED), "and a fight")
	for pair: Array in [[first, knight], [second, cleric]]:
		var shown: HeroWindow = pair[0]
		var hero: Hero = pair[1]
		var named: String = hero.def().display_name
		var points: int = hero.talent_points()
		var said: String = "%d point%s to spend" % [points, "" if points == 1 else "s"]
		if points == 0:
			said = shown.talents.points_label.text  # the next point's level, checked below
			assert_true(said.begins_with("Next point at level"), "%s: %s" % [named, said])
		assert_eq(shown.line(&"talent_points"), said, "%s: the points" % named)
		assert_eq(shown.line(&"level"), "Level %d" % hero.level, "%s: the level" % named)
		var fighter: Combatant = null
		if sim.expedition.battle != null:
			fighter = sim.expedition.battle.combatant(hero.id)
		var health: int = fighter.health if fighter != null else hero.health
		var most: int = fighter.max_health if fighter != null else hero.max_health()
		assert_eq(shown.line(&"health"), "%d / %d" % [maxi(health, 0), most], "%s: health" % named)
		var damage: int = hero.combatant().damage
		assert_true(
			shown.line(&"stat_damage").begins_with("Damage %d" % damage), "%s: stats" % named
		)
		var doing: String = shown.line(&"activity")
		if sim.expedition.state == Expedition.State.FIGHTING:
			assert_true(
				doing.begins_with("Fighting") or doing.begins_with("Healing") or doing == "Down",
				"%s: doing %s" % [named, doing]
			)
		else:
			assert_ne(doing, "", "%s: doing something" % named)
			assert_false(doing.begins_with("Fighting"), "%s: not fighting now" % named)


# --- R10 -----------------------------------------------------------------------


func test_r10_fits() -> void:
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		var main: Main = _main(room)
		main.simulation.party.gold = RICH
		for class_id: StringName in CLASSES:
			var hero: Hero = _hero(main, class_id)
			for path: int in 2:
				set_level_keeping_health(hero, 17)
				hero.set_talents(_walked(class_id, path, 1))
				var shown: HeroWindow = null
				var one_size: Vector2 = _window(main, hero).size
				for page: HeroWindow.Page in [
					HeroWindow.Page.STATS, HeroWindow.Page.TALENTS, HeroWindow.Page.SKILLS
				]:
					shown = _open(main, hero, page)
					shown.place_at(shown.default_place, Vector2(room))
					await _frames()
					_check_fits(main, shown, "%s %s path %d tab %d" % [room, class_id, path, page])
					assert_eq(
						shown.size, one_size, "%s %s: tab %d the same size" % [room, class_id, page]
					)
				# The questions fit too.
				_open(main, hero, HeroWindow.Page.TALENTS)
				hero.set_talents(Content.talent_tree(class_id).trunk)
				main.hud.advance(STEP)
				_click(main, shown.talents.node(Content.talent_tree(class_id).path_nodes(path)[0]))
				await _frames()
				_check_fits(main, shown, "%s %s asking" % [room, class_id])
				shown.talents.cancel()
				_click(main, shown.talents.reset_button)
				await _frames()
				_check_fits(main, shown, "%s %s asking to reset" % [room, class_id])
				shown.talents.cancel()
				_click_frame(main, hero)
		# The extreme values: twenty ranks of each upgrade asked for, every hero at level 99.
		for i: int in 20:
			main.simulation.buy_upgrade(&"sharp_blades")
			main.simulation.buy_upgrade(&"stout_armor")
		_frame(main)
		for hero: Hero in main.simulation.party.heroes:
			set_level_keeping_health(hero, 99)
		for hero: Hero in main.simulation.party.heroes:
			var one_size: Vector2 = _window(main, hero).size
			for page: HeroWindow.Page in [
				HeroWindow.Page.STATS, HeroWindow.Page.TALENTS, HeroWindow.Page.SKILLS
			]:
				var extreme: HeroWindow = _open(main, hero, page)
				extreme.place_at(extreme.default_place, Vector2(room))
				await _frames()
				_check_fits(main, extreme, "%s %s at level 99 tab %d" % [room, hero.class_id, page])
				assert_eq(
					extreme.size, one_size, "%s at level 99: tab %d the same size" % [room, page]
				)
			_click_frame(main, hero)
		main.free()


# --- R11 -----------------------------------------------------------------------


func test_r11_help_wiki_and_showcase() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	assert_true(wiki.contains("hero window"), "the wiki describes hero windows")
	assert_true(wiki.contains("side by side"), "and comparing them")

extends "res://tests/acceptance/ui_layer_test_base.gd"
## Acceptance tests for specs/075-a-smaller-hud/spec.md, one per requirement. The screen tests run
## the main scene at both rooms; the code tests read every script under res://game.

const ROOMS: Array[Vector2i] = [ROOM_SMALL, ROOM_LARGE]
## Frames an idle or a busy screen is watched for.
const WATCHED_FRAMES: int = 120
## Real seconds the screen is left to settle (its bars ease) before it is watched.
const SETTLE_SECONDS: float = 0.6
## The most public methods the HUD may have, statics included.
const MOST_PUBLIC: int = 15
## The UI's code, where every label's colour goes through one setter: the spec's paths. The art
## gallery and the character demo, scenes for developers outside them, set their own.
const UI_CODE: Array[String] = [
	"res://game/hud", "res://game/ui", "res://game/effects", "res://game/save", "res://game/main.gd"
]

## Draws heard while a screen is watched, by the path of the control that drew.
var _draws: Dictionary[String, int] = {}


func after_each() -> void:
	_draws.clear()
	super()


# --- Helpers -------------------------------------------------------------------


## One frame of the HUD and of the UI layer.
func _advance_ui(main: Main) -> void:
	main.hud.advance(STEP)
	main.ui.advance(STEP)


## Every script under res://game but [param skip] (a file name), its comments taken out.
func _code(skip: String = "") -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	scripts_in("res://game", texts)
	var code: Dictionary[String, String] = {}
	for path: String in texts:
		if path.get_file() != skip:
			code[path] = _without_comments(texts[path])
	return code


## [param text] with every comment taken out: a line's text from a # that is not in a string.
static func _without_comments(text: String) -> String:
	var lines: PackedStringArray = []
	for line: String in text.split("\n"):
		var quoted: bool = false
		var cut: int = line.length()
		for i: int in line.length():
			if line[i] == '"':
				quoted = not quoted
			elif line[i] == "#" and not quoted:
				cut = i
				break
		lines.append(line.left(cut))
	return "\n".join(lines)


## Opens a hero window on each tab (the first hero on Stats, the second on Talents, the third on
## Skills) and the shop.
func _open_windows(main: Main) -> void:
	var heroes: Array[Hero] = main.simulation.party.heroes
	main.hud.hero_windows.open(heroes[0].id, HeroWindow.Page.STATS)
	main.hud.hero_windows.open(heroes[1].id, HeroWindow.Page.TALENTS)
	main.hud.hero_windows.open(heroes[2].id, HeroWindow.Page.SKILLS)
	main.ui.windows.open_window(ShopWindow.ID)


## What R4 watches: the hero frames, the open hero windows, the place panel, the goals, the shop,
## the purse and the button bar with its tags.
func _idle_parts(main: Main) -> Array[Control]:
	var parts: Array[Control] = []
	parts.append_array(main.hud.frames)
	for hero: Hero in main.simulation.party.heroes:
		var shown: HeroWindow = main.hud.hero_windows.window_of(hero.id)
		if shown.is_open():
			parts.append(shown)
	parts.append(main.hud.place_panel)
	parts.append(main.hud.goals_view)
	parts.append(main.ui.windows.window(ShopWindow.ID))
	parts.append(main.hud.purse)
	parts.append(main.ui.bar)
	parts.append(main.ui.bar.tag_layer)
	return parts


## Counts each draw of [param root] and of every control under it in [member _draws].
func _hear_draws(root: Control) -> void:
	var all: Array[Control] = [root]
	_controls(root, all)
	for control: Control in all:
		control.draw.connect(_drew.bind(str(control.get_path())))


func _drew(path: String) -> void:
	_draws[path] = _draws.get(path, 0) + 1


## Waits [param seconds] of real time.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Index of the shown goal of [param kind], or -1.
func _goal_of(goals: Goals, kind: Goals.Kind) -> int:
	for i: int in goals.count():
		if goals.goal_at(i).kind == kind:
			return i
	return -1


## The palette colour [param label]'s text is drawn in.
func _colour_of(label: Control) -> Color:
	return label.get_theme_color(&"font_color")


func _assert_colour(label: Control, colour: StringName, what: String) -> void:
	assert_eq(_colour_of(label), Palette.color(colour), "%s is %s" % [what, colour])


# --- R2 ------------------------------------------------------------------------


func test_r2_nobody_borrows_from_the_hud() -> void:
	var code: Dictionary[String, String] = _code("hud.gd")
	var borrowed := RegEx.create_from_string("\\bHud\\.(\\w+)")
	for path: String in code:
		for found: RegExMatch in borrowed.search_all(code[path]):
			assert_eq(found.get_string(1), "new", "%s borrows Hud.%s" % [path, found.get_string(1)])
	var hud_code: String = _without_comments(FileAccess.get_file_as_string("res://game/hud/hud.gd"))
	assert_false(hud_code.contains("static func"), "the HUD has no static function")
	# The formatting has its home, and says what it said.
	assert_eq(UiFormat.group_thousands(1234567), "1,234,567")
	assert_eq(UiFormat.group_thousands(-1234), "-1,234")
	assert_eq(UiFormat.short_count(9_999), "9,999")
	assert_eq(UiFormat.short_count(12_345), "12.3k")
	assert_eq(UiFormat.short_count(123_456_789), "123M")
	assert_eq(UiFormat.clock(61.2), "1:02")
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var coin: Rect2 = UiFormat.on_screen(main.hud.purse.coin_icon)
		var seen: Rect2 = main.hud.purse.coin_icon.get_global_rect()
		var scale: float = float(main.ui.ui_scale()) / main.ui.world_scale()
		assert_almost_eq(coin.position, seen.position * scale, Vector2.ONE * 0.01, "%s" % room)
		main.free()


# --- R3 ------------------------------------------------------------------------


func test_r3_the_hud_is_handed_what_it_needs() -> void:
	var code: Dictionary[String, String] = _code()
	var emits_other := RegEx.create_from_string("\\w+\\.\\w+\\.emit\\(")
	for path: String in code:
		assert_false(code[path].contains("as Hud"), "%s finds the HUD for itself" % path)
		if path.get_file() == "area_map_window.gd":
			assert_null(emits_other.search(code[path]), "the map emits another's signal")
	var hud_code: String = code["res://game/hud/hud.gd"]
	for lookup: String in ["get_node", "find_child", "get_parent()"]:
		assert_false(hud_code.contains(lookup), "the HUD looks a node up (%s)" % lookup)
	# The windows' keys are the windows' business.
	for key: String in ["KEY_TAB", "KEY_B", "KEY_1", "KEY_Q", "KEY_E", "front"]:
		var named := RegEx.create_from_string("\\b%s\\b" % key)
		assert_null(named.search(hud_code), "the HUD handles a window's key (%s)" % key)
	# They still act: B, 1 to 5 in the shop, Q and E on a hero window, Tab and Shift+Tab.
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		main.simulation.party.gold = 100_000
		main.ui.windows.open_window(ShopWindow.ID)
		_advance_ui(main)
		var auto_buy: bool = hud.shop.auto_buy_on()
		_press(main, KEY_B)
		assert_ne(hud.shop.auto_buy_on(), auto_buy, "%s: B switches auto-buy" % room)
		_press(main, KEY_B)
		_press(main, KEY_1)
		main.simulation.step()
		assert_eq(main.simulation.upgrades.rank(hud.shop.rows[0].id), 1, "%s: 1 buys" % room)
		_press(main, KEY_TAB)
		var front: HeroWindow = main.ui.windows.front() as HeroWindow
		assert_not_null(front, "%s: Tab opens a hero window in front" % room)
		_press(main, KEY_E)
		assert_eq(front.page(), HeroWindow.Page.TALENTS, "%s: E is the next tab" % room)
		_press(main, KEY_Q)
		assert_eq(front.page(), HeroWindow.Page.STATS, "%s: Q the one before" % room)
		_press(main, KEY_TAB, true)
		assert_false(front.is_open(), "%s: Shift+Tab closes it" % room)
		main.free()


func test_r3_the_hud_has_few_public_methods() -> void:
	var text: String = FileAccess.get_file_as_string("res://game/hud/hud.gd")
	var method := RegEx.create_from_string("(?m)^(?:static )?func ([a-z]\\w*)\\(")
	var public: Array[String] = []
	for found: RegExMatch in method.search_all(text):
		public.append(found.get_string(1))
	assert_lte(public.size(), MOST_PUBLIC, "the HUD's public methods: %s" % [public])


# --- R4 ------------------------------------------------------------------------


func test_r4_an_idle_screen_sets_nothing() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		main.hud.set_process(true)  # every frame as in play; only the simulation stands still
		_open_windows(main)
		await _wait(SETTLE_SECONDS)
		for part: Control in _idle_parts(main):
			_hear_draws(part)
		var changes: int = WindowText.changes
		for i: int in WATCHED_FRAMES:
			await get_tree().process_frame
		assert_eq(WindowText.changes - changes, 0, "%s: no text or colour set" % room)
		assert_eq(_draws.keys(), [], "%s: nothing redrawn" % room)
		_draws.clear()
		main.free()


func test_r4_a_change_shows_on_the_next_frame() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var hero: Hero = sim.party.heroes[0]
		hud.hero_windows.open(hero.id, HeroWindow.Page.STATS)
		main.ui.windows.open_window(ShopWindow.ID)
		_advance_ui(main)
		var frame: HeroFrameView = hud.frames[0]
		var shown: HeroWindow = hud.hero_windows.window_of(hero.id)
		var what: String = "%s" % room
		# Gold, counted in by a coin.
		sim.party.gold += 1234
		main.effects.coin_collected.emit(1234)
		_advance_ui(main)
		assert_eq(hud.purse.gold_label.text, "1,234", "%s: the gold" % what)
		assert_false(hud.shop.rows[0].buy_button.disabled, "%s: the shop sees it" % what)
		# Health.
		hero.health = hero.max_health() - 7
		_advance_ui(main)
		var health: String = "%d / %d" % [hero.health, hero.max_health()]
		assert_eq(frame.health_label.text, health, "%s: the frame's health" % what)
		assert_eq(shown.line(&"health"), health, "%s: the window's health" % what)
		# XP, and the goal it moves.
		var skill: int = _goal_of(hud.goals, Goals.Kind.MICROSKILL)
		assert_gte(skill, 0, "%s: a microskill goal shows" % what)
		var detail: String = hud.goals_view.rows[skill].detail_label.text
		var xp_shown: float = frame.shown_xp()
		for each: Hero in sim.party.heroes:
			each.xp += 5
		_advance_ui(main)
		var to_go: int = Hero.xp_for_level(2) - hero.xp
		assert_eq(shown.line(&"xp"), "5 / 20 XP, %d to level 2" % to_go, "%s: the XP" % what)
		assert_gt(frame.shown_xp(), xp_shown, "%s: the frame's XP bar moves" % what)
		assert_ne(hud.goals_view.rows[skill].detail_label.text, detail, "%s: the goal" % what)
		assert_eq(
			hud.goals_view.rows[skill].detail_label.text,
			hud.goals.detail(skill),
			"%s: the goal shows its progress" % what
		)
		# A level.
		set_level_keeping_health(hero, 4)
		_advance_ui(main)
		assert_eq(frame.level_label.text, "Lv 4", "%s: the frame's level" % what)
		assert_eq(shown.line(&"level"), "Level 4", "%s: the window's level" % what)
		var damage: String = str(hero.combatant().damage)
		assert_string_contains(shown.line(&"stat_damage"), damage, "%s: the damage" % what)
		# The place.
		sim.expedition.target_depth = 3
		_advance_ui(main)
		assert_eq(hud.place_panel.target_label.text, "3", "%s: the target" % what)
		assert_eq(
			hud.place_panel.status_label.text, "Heading on to stage 3", "%s: the status" % what
		)
		main.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_a_closed_window_does_no_work() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var what: String = "%s" % room
		var ids: Array[StringName] = [ShopWindow.ID, AreaMapWindow.ID, TallyWindow.ID]
		for id: StringName in ids:
			assert_false(main.ui.windows.is_open(id), "%s: %s closed" % [what, id])
		assert_false(hud.hero_windows.is_open(), "%s: every hero window closed" % what)
		# Busy frames: the party earns, heals, levels and gathers, and only the windows advance.
		var row: ShopRow = hud.shop.rows[0]
		var needs: String = row.needs_label.text
		assert_true(row.buy_button.disabled, "%s: nothing affordable at first" % what)
		var changes: int = WindowText.changes
		for i: int in WATCHED_FRAMES:
			sim.step()
			sim.party.gold += 37
			sim.party.set_resource(Content.resource_ids()[0], i)
			for hero: Hero in sim.party.heroes:
				hero.xp += 1
			hud.shop.advance(STEP)
			hud.area_map.advance(STEP)
			hud.tally.advance(STEP)
			hud.hero_windows.advance(STEP)
		assert_eq(WindowText.changes - changes, 0, "%s: closed windows set nothing" % what)
		assert_true(row.buy_button.disabled, "%s: a closed shop's card is left alone" % what)
		assert_eq(row.needs_label.text, needs, "%s: its words too" % what)
		# Opened, each shows what is true now.
		main.ui.windows.open_window(ShopWindow.ID)
		var gold: int = sim.upgrades.cost(row.id)
		assert_eq(
			row.buy_button.text, "%s gold" % UiFormat.group_thousands(gold), "%s: price" % what
		)
		assert_eq(row.buy_button.disabled, sim.party.gold < gold, "%s: affordable" % what)
		main.ui.windows.open_window(AreaMapWindow.ID)
		var card: AreaMapRow = hud.area_map.rows[0]
		var first: StringName = Content.area_ids()[0]
		var count: int = sim.party.resource(Content.area(first).resource)
		assert_string_contains(card.resource_label.text, str(count), "%s: the map's count" % what)
		var hero: Hero = sim.party.heroes[0]
		hud.hero_windows.open(hero.id, HeroWindow.Page.STATS)
		var shown: HeroWindow = hud.hero_windows.window_of(hero.id)
		var floor_xp: int = Hero.xp_for_level(hero.level)
		assert_string_starts_with(
			shown.line(&"xp"), "%d / " % (hero.xp - floor_xp), "%s: the window's XP" % what
		)
		# A hero window refreshes only the tab showing; another is right as it opens.
		raise(hero, hero.level + 2)
		_advance_ui(main)
		# The label itself: line() reads a hidden tab as it would show.
		var points: String = shown.talents.points_label.text
		shown.open_page(HeroWindow.Page.TALENTS)
		assert_ne(shown.talents.points_label.text, points, "%s: not refreshed while hidden" % what)
		var left: int = hero.talent_points()
		var said: String = "%d point%s to spend" % [left, "" if left == 1 else "s"]
		assert_eq(shown.line(&"talent_points"), said, "%s: right as it shows" % what)
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_a_badge_follows_its_content() -> void:
	var made := UiButtonBar.new()
	assert_false(_has_method(made, "_process"), "the bar has no _process of its own")
	made.free()
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var bar: UiButtonBar = main.ui.bar
		var what: String = "%s" % room
		var shop_tag: UiBadge = bar.badges[ShopWindow.ID]
		var map_tag: UiBadge = bar.badges[AreaMapWindow.ID]
		_advance_ui(main)
		assert_false(shop_tag.visible, "%s: no shop tag with no gold" % what)
		assert_false(map_tag.visible, "%s: no map tag in a new game" % what)
		main.simulation.party.gold = 100_000
		hud.shop.advance(STEP)
		assert_true(shop_tag.visible, "%s: the shop's tag shows" % what)
		assert_eq(shop_tag.count, hud.shop.affordable_count(), "%s: counting" % what)
		main.simulation.party.gold = 0
		hud.shop.advance(STEP)
		assert_false(shop_tag.visible, "%s: and goes" % what)
		hud.area_map.news.unseen = 2
		hud.area_map.advance(STEP)
		assert_true(map_tag.visible, "%s: the map's tag shows" % what)
		assert_eq(map_tag.count, 2, "%s: two areas" % what)
		main.ui.windows.open_window(AreaMapWindow.ID)
		assert_false(map_tag.visible, "%s: and goes as the map opens" % what)
		main.free()
	# A loaded game that can already pay for an upgrade, or has an area it has not seen, shows the
	# tags from the start: the window takes its content's tag as it is built.
	var rich := Simulation.new(Main.SIMULATION_SEED)
	rich.party.gold = 100_000
	assert_true(SaveStore.new(_save_path).write(rich.to_save()), "the test's save was written")
	for room: Vector2i in ROOMS:
		var loaded: Main = make_main()
		loaded.save_store = SaveStore.new(_save_path)
		add_child_autofree(loaded)
		loaded.driver.set_process(false)
		loaded.world.set_process(false)
		loaded.effects.set_process(false)
		loaded.hud.set_process(false)
		loaded.ui.set_room_for_test(room)
		for i: int in 3:
			_advance_ui(loaded)
		var tag: UiBadge = loaded.ui.bar.badges[ShopWindow.ID]
		assert_true(tag.visible, "%s: a loaded game's shop tag shows" % room)
		assert_eq(tag.count, loaded.hud.shop.affordable_count(), "%s: counting" % room)
		loaded.free()


static func _has_method(object: Object, method: String) -> bool:
	for each: Dictionary in (object.get_script() as Script).get_script_method_list():
		if each.get("name", "") == method:
			return true
	return false


# --- R7 ------------------------------------------------------------------------


func test_r7_a_labels_colour_is_set_one_way() -> void:
	var override := RegEx.create_from_string('add_theme_color_override\\(\\s*&?"font_color"')
	for path: String in _code("window_text.gd"):
		if not UI_CODE.any(func(root: String) -> bool: return path.begins_with(root)):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		assert_null(override.search(_without_comments(text)), "%s sets a font colour" % path)
	var label := Label.new()
	var changes: int = WindowText.changes
	WindowText.set_colour(label, &"orange")
	WindowText.set_colour(label, &"orange")
	assert_eq(WindowText.changes - changes, 1, "the same colour twice is set once")
	_assert_colour(label, &"orange", "the label")
	WindowText.set_colour(label, &"green")
	assert_eq(WindowText.changes - changes, 2, "a new colour is set")
	_assert_colour(label, &"green", "the label")
	label.free()


## Every colour on screen is the one it is today: the frame's pieces, the shop, the map, the
## ticker and each tab of a hero window, alive, down and with points to spend.
func test_r7_every_colour_is_todays() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var heroes: Array[Hero] = sim.party.heroes
		_open_windows(main)
		main.ui.windows.open_window(AreaMapWindow.ID)
		hud.area_map.choose(Content.area_ids()[0])
		hud.journal.announce("A line for the ticker")
		_advance_ui(main)
		var what: String = "%s" % room
		for frame: HeroFrameView in hud.frames:
			_assert_colour(frame.level_label, &"yellow", "%s: a level" % what)
			_assert_colour(frame.name_label, &"white", "%s: a name" % what)
		_assert_colour(hud.place_panel.stage_label, &"white", "%s: the stage" % what)
		_assert_colour(hud.place_panel.status_label, &"silver", "%s: the status" % what)
		_assert_colour(hud.place_panel.safe_label, &"silver", "%s: the safe stage" % what)
		_assert_colour(hud.countdown.note_label, &"silver", "%s: the countdown" % what)
		_assert_colour(hud.purse.gold_label, &"yellow", "%s: the gold" % what)
		_assert_colour(hud.ticker.label, &"white", "%s: the ticker" % what)
		for i: int in hud.goals.count():
			var row: GoalRow = hud.goals_view.rows[i]
			_assert_colour(row.sentence_label, &"white", "%s: goal %d" % [what, i])
			var price: StringName = &"yellow" if GoalRow.is_gold(hud.goals.goal_at(i)) else &"steel"
			_assert_colour(row.detail_label, price, "%s: goal %d's count" % [what, i])
		var card: ShopRow = hud.shop.rows[0]
		_assert_colour(card.rank_label, &"steel", "%s: a card's rank" % what)
		_assert_colour(card.now_label, &"white", "%s: what it gives" % what)
		_assert_colour(card.next_label, &"green", "%s: what it will" % what)
		var risk: StringName = DepthLadder.RISK_COLOURS[hud.area_map.risk(Content.area_ids()[0], 1)]
		_assert_colour(hud.area_map.stage_label, risk, "%s: the map's stage" % what)
		_assert_colour(hud.area_map.risk_label, risk, "%s: the map's risk" % what)
		var stats: HeroWindow = hud.hero_windows.window_of(heroes[0].id)
		assert_eq(stats.line_colour(&"activity"), Palette.color(&"silver"), "%s: walking" % what)
		var talents: HeroWindow = hud.hero_windows.window_of(heroes[1].id)
		_assert_colour(talents.talents.points_label, &"steel", "%s: no points" % what)
		var skills: HeroWindow = hud.hero_windows.window_of(heroes[2].id)
		_assert_colour(skills.skills.cards[0].name_label, TalentNode.DIM, "%s: to come" % what)
		# A hero down, a point to spend and a microskill learned.
		heroes[0].health = 0
		raise(heroes[1], 2)
		raise(heroes[2], skills.skills.cards[0].level)
		_advance_ui(main)
		_assert_colour(hud.frames[0].level_label, &"red", "%s: down" % what)
		_assert_colour(hud.frames[0].name_label, &"slate", "%s: a name, down" % what)
		assert_eq(stats.line_colour(&"activity"), Palette.color(&"red"), "%s: down" % what)
		_assert_colour(talents.talents.points_label, &"yellow", "%s: a point" % what)
		_assert_colour(skills.skills.cards[0].name_label, &"white", "%s: learned" % what)
		main.free()

extends "res://tests/acceptance/ui_layer_test.gd"
## Acceptance tests for specs/060-hero-windows/spec.md, one per requirement.
##
## Each test runs the main scene with its processing off, the UI layer laid out for a chosen room,
## and drives the hero windows with real clicks and keys pushed into the viewport (the helpers are
## in ui_layer_test.gd); the simulation is stepped after each command and checked.

const STEP: float = 1.0 / 60.0
const RICH: int = 1_000_000
const LIMIT_TICKS: int = 30_000
const CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const WIKI: String = "res://docs/wiki/index.html"
const OLD_SHEET: String = "res://game/hud/hero_sheet.gd"

# --- Helpers -------------------------------------------------------------------


func _hero(main: Main, class_id: StringName) -> Hero:
	for hero: Hero in main.simulation.party.heroes:
		if hero.class_id == class_id:
			return hero
	return null


func _level(hero: Hero, level: int) -> void:
	hero.level = level
	hero.xp = Hero.xp_for_level(level)


## The trunk and the first [param steps] nodes of path [param path] of [param class_id]'s tree.
func _walked(class_id: StringName, path: int, steps: int) -> Array[StringName]:
	var tree: TalentTreeDef = Content.talent_tree(class_id)
	var nodes: Array[StringName] = tree.trunk.duplicate()
	nodes.append_array(tree.path_nodes(path).slice(0, steps))
	return nodes


func _frame_of(main: Main, hero: Hero) -> HeroFrame:
	for frame: HeroFrame in main.hud.frames:
		if frame.hero_id == hero.id:
			return frame
	return null


## A real click on [param hero]'s frame, then a frame of the HUD.
func _click_frame(main: Main, hero: Hero) -> void:
	_click_world(_frame_of(main, hero).get_global_rect().get_center())
	main.hud.advance(STEP)


## A real click on [param control], a control on the UI layer, then a frame of the HUD.
func _click(main: Main, control: Control) -> void:
	_click_ui(main.ui, control.get_global_rect().get_center())
	main.hud.advance(STEP)


func _press(main: Main, keycode: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.shift_pressed = shift
		event.pressed = pressed
		get_viewport().push_input(event)
	main.hud.advance(STEP)


## One frame of one tick: the simulation, the world, the HUD.
func _tick(main: Main) -> void:
	main.simulation.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)


func _window(main: Main, hero: Hero) -> HeroWindow:
	return main.hud.hero_windows.window_of(hero.id)


## Opens [param hero]'s window with a click on its frame and its [param page] with a click on the
## tab.
func _open(main: Main, hero: Hero, page: HeroWindow.Page) -> HeroWindow:
	if not main.hud.hero_windows.is_open(hero.id):
		_click_frame(main, hero)
	var shown: HeroWindow = _window(main, hero)
	if shown.page() != page:
		_click(main, shown.tab_buttons[page])
	return shown


## The rectangle [param label]'s text inks, in UI pixels: as wide as its widest line in its font,
## a line tall per line.
func _text_rect(label: Label) -> Rect2:
	var bold: bool = label.get_theme_font(&"font") == UiText.font(true)
	var widest: int = 0
	var lines: PackedStringArray = label.text.split("\n")
	for line: String in lines:
		widest = maxi(widest, UiText.width(line, bold) - UiText.SPACING)
	var at: Vector2 = label.get_global_rect().position
	return Rect2(at, Vector2(widest, lines.size() * UiText.LINE_HEIGHT))


## Every label of [param node]'s branch that shows text.
func _shown_labels(node: Node) -> Array[Label]:
	var all: Array[Control] = []
	_controls(node, all)
	var labels: Array[Label] = []
	for control: Control in all:
		var label: Label = control as Label
		if label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			labels.append(label)
	return labels


## Checks that every text shown on [param shown]'s open tab and header is inside the window and the
## room, inside its own label, and clear of every other text.
func _check_fits(main: Main, shown: HeroWindow, what: String) -> void:
	var window: Rect2 = shown.get_global_rect()
	var room := Rect2(Vector2.ZERO, Vector2(main.ui.room()))
	assert_lte(window.size.y, room.size.y, "%s: never taller than the room" % what)
	var labels: Array[Label] = _shown_labels(shown)
	var rects: Array[Rect2] = []
	for label: Label in labels:
		var inked: Rect2 = _text_rect(label)
		rects.append(inked)
		var named: String = "%s: '%s'" % [what, label.text.replace("\n", " / ")]
		assert_true(window.encloses(inked), "%s inside the window" % named)
		assert_true(room.encloses(inked), "%s inside the room" % named)
		assert_lte(inked.size.x, label.size.x + 1.0, "%s not cut at its right" % named)
		assert_eq(label.clip_text, false, "%s not clipped" % named)
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s whole" % named)
		assert_lte(label.max_lines_visible, 0, "%s every line" % named)
	for a: int in labels.size():
		for b: int in range(a + 1, labels.size()):
			if rects[a].intersects(rects[b]):
				fail_test(
					(
						"%s: '%s' overlaps '%s'"
						% [what, labels[a].text.left(30), labels[b].text.left(30)]
					)
				)


## A point, in UI pixels, where [param shown] is the front-most window, under its title bar (so
## not on its close button).
func _visible_point(main: Main, shown: UiWindow) -> Vector2:
	var rect: Rect2 = shown.get_global_rect()
	var below: int = int(shown.title_bar.get_global_rect().end.y) + 4
	for y: int in range(below, int(rect.end.y), 8):
		for x: int in range(int(rect.position.x) + 2, int(rect.end.x), 8):
			var at := Vector2(x, y)
			if main.ui.windows.window_at(main.ui.ui_to_world(at)) == shown:
				return at
	return rect.get_center()


## Steps until a fight is under way, and returns it (null if none came).
func _fight(main: Main) -> Battle:
	var ticks: int = 0
	while main.simulation.expedition.battle == null and ticks < LIMIT_TICKS:
		_tick(main)
		ticks += 1
	return main.simulation.expedition.battle


func _state_name(state: TalentNode.State) -> String:
	return TalentNode.State.keys()[state]


# --- R1 ------------------------------------------------------------------------


func test_r1_a_window_per_hero() -> void:
	var settings := SoundSettings.new(_settings_path)
	var main: Main = _main(ROOM_LARGE, settings)
	await _frames()
	var windows: UiWindows = main.ui.windows
	var heroes: Array[Hero] = main.simulation.party.heroes
	assert_false(ResourceLoader.exists(OLD_SHEET), "the old sheet is removed")
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
	_level(knight, 8)
	knight.set_talents(Content.talent_tree(&"knight").trunk)
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.STATS)
	await _frames()
	var icon: Texture2D = main.hud.icon(&"knight")
	assert_eq(shown.portrait.texture, icon, "the class portrait")
	assert_eq(shown.portrait.size, Vector2(icon.get_size()) * 2.0, "at twice the size")
	assert_eq(shown.line(&"class"), "Knight", "the class")
	assert_eq(shown.class_label.get_theme_font(&"font"), UiText.font(true), "in bold")
	_level(knight, 10)
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
	_level(knight, 4)
	var first: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var names: Array[String] = []
	for button: UiButton in first.tab_buttons:
		names.append(button.text)
	assert_eq(names, ["Stats", "Talents", "Skills"] as Array[String], "three tabs")
	# The tags count what waits on each tab.
	assert_true(first.talents_tag.is_visible_in_tree(), "a tag on Talents")
	assert_eq(first.talents_tag.text, "2", "two talent points")
	var tab: Rect2 = first.tab_buttons[HeroWindow.Page.TALENTS].get_global_rect()
	assert_true(first.talents_tag.get_global_rect().intersects(tab), "on the tab")
	_click(main, first.talents.node(Content.talent_tree(&"knight").trunk[0]))
	_tick(main)
	assert_eq(first.talents_tag.text, "1", "one left")
	_level(mage, 3)
	var second: HeroWindow = _open(main, mage, HeroWindow.Page.STATS)
	var learned: int = mage.microskills().size()
	_level(mage, 6)
	main.hud.advance(STEP)
	var new_skills: int = mage.microskills().size() - learned
	if new_skills > 0:
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
	_level(cleric, 17)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.QUICKNESS)
	_tick(main)
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
			var what: String = "%s on %s" % [class_id, class_tree.path_names[path]]
			_level(hero, 10)
			hero.set_talents(_walked(class_id, path, 1))
			var opened: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
			main.hud.advance(STEP)
			var view: TalentTreeView = opened.talents.tree_view()
			assert_eq(view.tree, class_tree, "%s: its own tree" % what)
			assert_eq(view.trunk_nodes.size(), 3, "%s: the trunk" % what)
			for index: int in 2:
				assert_eq(view.path_labels[index].text, class_tree.path_names[index], "path names")
				assert_eq(view.path_nodes[index].size(), 4, "%s: four on each path" % what)
			var window: Rect2 = opened.get_global_rect()
			for node: TalentNode in view.nodes():
				var ability: AbilityDef = Content.ability(node.ability_id)
				var named: String = "%s: %s" % [what, node.ability_id]
				assert_true(node.is_visible_in_tree(), "%s shows" % named)
				assert_eq(node.name_label.text, ability.display_name, "%s: its name" % named)
				var kind: String = "Action" if ability.is_action() else "Passive"
				assert_true(node.kind_label.text.begins_with(kind), "%s: %s" % [named, kind])
				assert_eq(
					node.description_label.text.replace("\n", " "),
					ability.description,
					"%s: the whole description, beside the node" % named
				)
				assert_true(node.description_label.is_visible_in_tree(), "%s: shown" % named)
				assert_true(
					window.encloses(_text_rect(node.description_label)), "%s: inside" % named
				)
				var lines: PackedStringArray = node.description_label.text.split("\n")
				for line: String in lines:
					assert_lte(
						UiText.width(line),
						node.description_label.size.x + 1.0,
						"%s: wrapped" % named
					)
				# The picture, from the data.
				assert_has(
					AbilityDef.PICTURES, ability.picture, "%s: a picture of its kind" % named
				)
				var state: TalentNode.State = node.state()
				if state != TalentNode.State.CLOSED:
					assert_true(node.icon.is_visible_in_tree(), "%s: the picture shows" % named)
					assert_eq(node.icon.texture, TalentNode.picture(node.ability_id), named)
			# The four states.
			for id: StringName in class_tree.trunk:
				assert_eq(_state_name(view.state_of(id)), "TAKEN", "%s: %s taken" % [what, id])
				assert_true(view.node(id).is_ticked(), "%s ticked" % id)
			var mine: Array[StringName] = class_tree.path_nodes(path)
			assert_eq(_state_name(view.state_of(mine[1])), "AVAILABLE", "%s: next" % what)
			assert_true(view.node(mine[1]).is_pulsing(), "%s: it pulses" % what)
			assert_eq(_state_name(view.state_of(mine[2])), "LOCKED", "%s: not yet" % what)
			for id: StringName in class_tree.path_nodes(1 - path):
				var closed: TalentNode = view.node(id)
				assert_eq(_state_name(closed.state()), "CLOSED", "%s: %s closed" % [what, id])
				assert_true(
					closed.description_label.is_visible_in_tree(), "%s: still readable" % id
				)
				assert_eq(
					closed.description_label.get_theme_color(&"font_color"),
					Palette.color(TalentNode.DIM),
					"%s: dimmed" % id
				)
			assert_true(view.is_closed(1 - path), "%s: the other path closed" % what)
			_click_frame(main, hero)
	# The picture is data the check validates.
	var copy: AbilityDef = Content.ability(&"taunt").duplicate() as AbilityDef
	copy.picture = &""
	assert_has(copy.validate(), "picture is empty", "a missing picture is refused")
	copy.picture = &"moon"
	assert_eq(copy.validate().size(), 1, "so is one not of the eight")
	# The commands, as spec 055 had them, on the front window's Talents tab.
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = Content.talent_tree(&"knight")
	_level(knight, 4)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	assert_eq(tab.points_label.text, "2 talent points", "the unspent points")
	_click(main, tab.node(tree.trunk[0]))
	_tick(main)
	assert_eq(knight.talents(), [tree.trunk[0]] as Array[StringName], "a click takes a node")
	_click(main, tab.node(tree.trunk[1]))
	_tick(main)
	assert_eq(tab.points_label.text, "Next point at level 6", "the next point's level")
	_level(knight, 8)
	_click(main, tab.node(tree.trunk[2]))
	_tick(main)
	_click(main, tab.node(tree.path_b[0]))
	assert_eq(tab.asking(), HeroTalentsTab.Asking.PATH, "the question before a path")
	assert_eq(tab.ask_label.text, "Choose Berserker? This closes Guardian.", "in words")
	assert_true(tab.choose_button.is_visible_in_tree(), "with its answers")
	_tick(main)
	assert_eq(knight.path(), -1, "asking sends nothing")
	_click(main, tab.choose_button)
	_tick(main)
	assert_eq(knight.path(), 1, "Choose sends it")
	main.simulation.party.gold = RICH
	main.hud.advance(STEP)
	assert_eq(tab.reset_button.text, "Reset 800", "the reset with its price")
	_level(knight, 17)
	main.hud.advance(STEP)
	assert_eq(tab.paragon_label.text, "3 paragon points", "the paragon points")
	_click(main, tab.paragon_cells[0].buy_button)
	_tick(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 1, "+1")
	_press(main, KEY_2)
	_tick(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "key 2 on the front Talents tab")
	# Keys 1 to 3 belong to the front hero window, on its Talents tab only.
	var mage: Hero = _hero(main, &"mage")
	_level(mage, 17)
	var front: HeroWindow = _open(main, mage, HeroWindow.Page.STATS)
	assert_eq(main.ui.windows.front(), front, "the mage's in front, on Stats")
	_press(main, KEY_3)
	_tick(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.QUICKNESS), 0, "not the window behind")
	assert_eq(mage.paragon_rank(TrainingDef.Stat.QUICKNESS), 0, "not on Stats")
	_click(main, front.tab_buttons[HeroWindow.Page.TALENTS])
	_press(main, KEY_3)
	_tick(main)
	assert_eq(mage.paragon_rank(TrainingDef.Stat.QUICKNESS), 1, "the front one, on Talents")
	_click(main, shown.title_label)  # the knight's window to the front again
	while main.simulation.expedition.battle != null:
		_tick(main)
	_click(main, tab.reset_button)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.RESET, "the question before a reset")
	assert_eq(tab.ask_label.text, "Reset the Knight's tree for 1,700 gold?", "with its price")
	_click(main, tab.choose_button)
	_tick(main)
	assert_eq(knight.talents(), [] as Array[StringName], "reset")
	assert_eq(main.simulation.party.gold, RICH - 1700, "for its price")


# --- R6 ------------------------------------------------------------------------


func test_r6_skills() -> void:
	var main: Main = _main(ROOM_LARGE)
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var def: HeroClassDef = hero.def()
		_level(hero, 1)
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.SKILLS)
		main.hud.advance(STEP)
		var cards: Array[HeroSkillsTab.Card] = shown.skills.cards
		assert_eq(cards.size(), def.microskills.size(), "%s: a card per microskill" % class_id)
		for i: int in cards.size():
			var card: HeroSkillsTab.Card = cards[i]
			var skill: MicroskillDef = Content.microskill(def.microskills[i])
			var level: int = def.microskill_levels[i]
			var named: String = "%s: %s" % [class_id, skill.id]
			assert_true(card.is_visible_in_tree(), "%s shows" % named)
			assert_eq(card.name_label.text, skill.display_name, "%s: its name" % named)
			var answers: Array[String] = []
			for quest_id: StringName in Content.side_quest_ids():
				var quest: SideQuestDef = Content.side_quest(quest_id)
				if quest.microskill == skill.id:
					answers.append(quest.display_name)
			if hero.level >= level:
				assert_true(card.learned, "%s learned" % named)
				assert_eq(card.text_label.text.replace("\n", " "), skill.description + ".", named)
				for answer: String in answers:
					assert_true(
						card.answers_label.text.contains(answer), "%s answers %s" % [named, answer]
					)
				assert_eq(
					card.name_label.get_theme_color(&"font_color"), Palette.color(&"white"), named
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
		_level(hero, 30)
		main.hud.advance(STEP)
		for card: HeroSkillsTab.Card in cards:
			assert_true(card.learned, "%s: all learned at 30" % class_id)
		_click_frame(main, hero)


# --- R7 ------------------------------------------------------------------------


func test_r7_compare() -> void:
	var main: Main = _main(ROOM_LARGE)
	var heroes: Array[Hero] = main.simulation.party.heroes
	var places: Dictionary[Vector2, bool] = {}
	for hero: Hero in heroes:
		places[_window(main, hero).default_place] = true
	assert_eq(places.size(), heroes.size(), "each hero's window has its own place")
	var frames_top: float = main.ui.world_to_ui(main.hud.frames[0].get_global_rect().position).y
	var room := Rect2(Vector2.ZERO, Vector2(ROOM_LARGE))
	for pair: Array in [[0, 1], [2, 3], [0, 3], [1, 2]]:
		var a: Hero = heroes[pair[0]]
		var b: Hero = heroes[pair[1]]
		_open(main, a, HeroWindow.Page.TALENTS)
		_open(main, b, HeroWindow.Page.TALENTS)
		await _frames()
		var first: Rect2 = _window(main, a).get_global_rect()
		var second: Rect2 = _window(main, b).get_global_rect()
		var named: String = "heroes %d and %d at 1280x720" % pair
		assert_false(first.intersects(second), "%s: side by side" % named)
		if pair[0] / 2 == pair[1] / 2:
			assert_eq(first.position.y, second.position.y, "%s: level" % named)
		for rect: Rect2 in [first, second]:
			assert_true(room.encloses(rect), "%s: in the room" % named)
			assert_lte(rect.end.y, frames_top, "%s: clear of the frames' line" % named)
		_click_frame(main, a)
		_click_frame(main, b)
	main.free()
	var small: Main = _main(ROOM_SMALL)
	var small_room := Rect2(Vector2.ZERO, Vector2(ROOM_SMALL))
	var opened: Array[HeroWindow] = []
	for hero: Hero in small.simulation.party.heroes:
		opened.append(_open(small, hero, HeroWindow.Page.TALENTS))
	await _frames()
	for i: int in opened.size():
		assert_true(small_room.encloses(opened[i].get_global_rect()), "960x540: %d in the room" % i)
		for j: int in range(i + 1, opened.size()):
			var back: HeroWindow = opened[i]
			var over: HeroWindow = opened[j]
			assert_ne(back.position, over.position, "960x540: %d and %d offset" % [i, j])
			var title: Rect2 = back.title_label.get_global_rect()
			title.size.x = UiText.width(back.title, true)
			assert_false(
				over.get_global_rect().intersects(title),
				"960x540: %d's title shows past %d" % [i, j]
			)


# --- R8 ------------------------------------------------------------------------


func test_r8_nothing_lost() -> void:
	var main: Main = _main(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = Content.talent_tree(&"knight")
	# take_talent, spend_paragon and reset_talents, each with the same effect as before.
	_level(knight, 17)
	sim.party.gold = RICH
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	for id: StringName in tree.trunk:
		_click(main, tab.node(id))
		_tick(main)
	assert_eq(knight.talents(), tree.trunk, "take_talent, click by click")
	_click(main, tab.paragon_cells[1].buy_button)
	_tick(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "spend_paragon")
	# A reset is never charged at a price the player did not read.
	_click(main, tab.reset_button)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.RESET, "asked")
	_level(knight, 18)
	main.hud.advance(STEP)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.NOTHING, "a new price: the question goes")
	tab.confirm()
	_tick(main)
	assert_eq(knight.talents(), tree.trunk, "nothing reset at a price never read")
	assert_eq(sim.party.gold, RICH, "nothing charged")
	_click(main, tab.reset_button)
	var ticks: int = 0
	while sim.expedition.battle == null and ticks < LIMIT_TICKS:
		_tick(main)
		ticks += 1
	assert_not_null(sim.expedition.battle, "a fight")
	assert_eq(tab.asking(), HeroTalentsTab.Asking.NOTHING, "a fight starts: the question goes")
	tab.confirm()
	_tick(main)
	assert_eq(knight.talents(), tree.trunk, "nothing reset in a fight")
	assert_eq(sim.party.gold, RICH, "nothing charged in a fight")
	while sim.expedition.battle != null and ticks < LIMIT_TICKS * 2:
		_tick(main)
		ticks += 1
	var gold: int = sim.party.gold
	_click(main, tab.reset_button)
	_click(main, tab.choose_button)
	_tick(main)
	assert_eq(knight.talents(), [] as Array[StringName], "reset_talents, read and answered")
	assert_eq(sim.party.gold, gold - 1800, "at the price read")
	_click_frame(main, knight)
	# A goal opens the hero's window on its tab, as it opened the old sheet.
	_window(main, knight).open_page(HeroWindow.Page.STATS)
	main.hud.advance(STEP)
	var row: int = main.hud.goals.lines().find("Spend the Knight's talent points")
	assert_gte(row, 0, "a goal: %s" % [main.hud.goals.lines()])
	if row >= 0:
		_click_world(main.hud.goals.rows[row].get_global_rect().get_center())
		main.hud.advance(STEP)
		assert_true(main.hud.hero_windows.is_open(knight.id), "the goal opens the knight's window")
		assert_eq(_window(main, knight).page(), HeroWindow.Page.TALENTS, "on its Talents tab")
		assert_eq(main.ui.windows.front(), _window(main, knight), "in front")
	# The defeat note's advice does too.
	_click_frame(main, knight)
	_window(main, knight).open_page(HeroWindow.Page.SKILLS)
	for fighter: Combatant in _fight(main).heroes:
		fighter.health = 0
	ticks = 0
	while sim.expedition.state != Expedition.State.REVIVING and ticks < LIMIT_TICKS:
		_tick(main)
		ticks += 1
	main.hud.advance(STEP)
	var offered: Array[String] = main.hud.defeat_note.suggestions()
	assert_eq(offered[0] if not offered.is_empty() else "", "Spend talent points", "%s" % [offered])
	main.hud.defeat_note.press(0)
	main.hud.advance(STEP)
	assert_true(main.hud.hero_windows.is_open(knight.id), "the note opens the knight's window")
	assert_eq(_window(main, knight).page(), HeroWindow.Page.TALENTS, "on its Talents tab")


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
	knight.xp = Hero.xp_for_level(4) - 1
	cleric.xp = Hero.xp_for_level(3) - 1
	_level(knight, 2)
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
		var said: String = "%d talent point%s" % [points, "" if points == 1 else "s"]
		if points == 0:
			said = shown.talents.points_label.text  # the next point's level, checked below
			assert_true(said.begins_with("Next point at level"), "%s: %s" % [named, said])
		assert_eq(shown.line(&"talent_points"), said, "%s: the points" % named)
		assert_eq(shown.line(&"level"), "Level %d" % hero.level, "%s: the level" % named)
		var view: TalentTreeView = shown.talents.tree_view()
		for node: TalentNode in view.nodes():
			var taken: bool = hero.talents().has(node.ability_id)
			assert_eq(node.state() == TalentNode.State.TAKEN, taken, "%s: %s" % [named, node.name])
			if not taken:
				assert_eq(
					node.state() == TalentNode.State.AVAILABLE,
					hero.can_take(node.ability_id),
					"%s: %s can be taken" % [named, node.ability_id]
				)
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
	assert_eq(first.talents.tree_view().state_of(tree.trunk[0]), TalentNode.State.TAKEN, "taken")


# --- R10 -----------------------------------------------------------------------


func test_r10_fits() -> void:
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		var main: Main = _main(room)
		main.simulation.party.gold = RICH
		for class_id: StringName in CLASSES:
			var hero: Hero = _hero(main, class_id)
			for path: int in 2:
				_level(hero, 17)
				hero.set_talents(_walked(class_id, path, 1))
				var shown: HeroWindow = null
				for page: HeroWindow.Page in [
					HeroWindow.Page.STATS, HeroWindow.Page.TALENTS, HeroWindow.Page.SKILLS
				]:
					shown = _open(main, hero, page)
					shown.place_at(shown.default_place, Vector2(room))
					await _frames()
					_check_fits(main, shown, "%s %s path %d tab %d" % [room, class_id, path, page])
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
		main.free()


# --- R11 -----------------------------------------------------------------------


func test_r11_help_wiki_and_showcase() -> void:
	var listed: Array[String] = []
	for entry: Array in HelpPanel.KEYS:
		listed.append(str(entry[0]))
	assert_has(listed, "Shift+Tab", "the help lists Shift+Tab")
	assert_has(HelpPanel.keycodes("Shift+Tab"), KEY_TAB, "the Tab key, with Shift")
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	assert_true(wiki.contains("hero window"), "the wiki describes hero windows")
	assert_true(wiki.contains("side by side"), "and comparing them")
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"talent_tree")
	var knight: Hero = showcase.main.simulation.party.heroes[0]
	var windows: HeroWindows = showcase.main.hud.hero_windows
	assert_true(windows.is_open(knight.id), "the talent moment opens the knight's window")
	assert_eq(windows.window_of(knight.id).page(), HeroWindow.Page.TALENTS, "on Talents")
	var asked: bool = false
	var start: float = showcase.elapsed
	while showcase.moment() == &"talent_tree" and showcase.elapsed - start < 10.0:
		showcase.advance(1.0 / 30.0)
		asked = asked or windows.window_of(knight.id).talents.asking() == HeroTalentsTab.Asking.PATH
	assert_true(asked, "the path asked first")
	assert_gte(knight.path(), 0, "and chosen")

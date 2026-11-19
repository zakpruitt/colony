extends GutTest
## Acceptance tests for specs/034-hero-sheet-tabs/spec.md, one per requirement. R8 is the existing
## suite (specs 026, 028 and 029) passing. Since spec 060 the sheet is a window per hero on the UI
## layer ([HeroWindow]), each keeping its own tab: these tests read the hero's window.

const SEED: int = 34
## The UI layer's room these tests lay it out in (spec 058).
const ROOM: Vector2i = Vector2i(1280, 720)
const PAGES: Array[HeroWindow.Page] = [
	HeroWindow.Page.STATS, HeroWindow.Page.TALENTS, HeroWindow.Page.SKILLS
]
const HEADER_KEYS: Array[StringName] = [&"class", &"role", &"level", &"activity", &"health", &"xp"]
const STAT_KEYS: Array[StringName] = [
	&"stat_health", &"stat_damage", &"stat_armor", &"stat_attack_speed", &"stat_crit", &"stat_range"
]
const POWER: StringName = &"power"

var _sim: Simulation
var _world: World
var _hud: Hud
var _ui: UiRoot


func before_each() -> void:
	_make_hud(Simulation.new(SEED))


func after_each() -> void:
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


# --- Helpers -------------------------------------------------------------------


func _make_hud(simulation: Simulation) -> Hud:
	_sim = simulation
	_world = World.new()
	_world.simulation = simulation
	add_child_autofree(_world)
	_world.set_process(false)
	var effects := CombatEffects.new()
	add_child_autofree(effects)
	effects.setup(_world, simulation)
	effects.set_process(false)
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.set_process(false)
	_hud.setup(simulation, _world, effects)
	# Spec 060: the hero windows live on the UI layer, which gives them to the HUD.
	_ui = UiRoot.new()
	add_child_autofree(_ui)
	_ui.set_room_for_test(ROOM)
	_ui.setup(simulation, _hud, null)
	_hud.advance(0.0)
	return _hud


## Hero [param hero_id]'s window, opened and in front (spec 060: that hero's sheet).
func _open(hero_id: int) -> HeroWindow:
	_hud.hero_windows.open(hero_id)
	return _hud.hero_windows.window_of(hero_id)


## Raises [param hero] to the level that gives it [param points] paragon points (spec 051 took
## the gold off training: a row spends a paragon point). Its tree is filled, so the paragon
## points are all it has to spend (spec 055 counts talent points on the same tab).
func _give_paragon(hero: Hero, points: int) -> void:
	var level: int = Hero.TALENT_POINTS * Hero.TALENT_EVERY + points
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var full: Array[StringName] = tree.trunk.duplicate()
	full.append_array(tree.path_a)
	hero.set_talents(full)
	assert_eq(hero.talent_points(), 0, "%s: no talent point to spend" % hero.class_id)


## The paragon points [param hero] has in the stat of training [param id].
func _rank(hero: Hero, id: StringName) -> int:
	return hero.paragon_rank(Content.training(id).stat)


func _hero(index: int) -> Hero:
	return _sim.party.heroes[index]


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## A click on [param button], as the other HUD tests make one: its pressed signal. A hidden
## button cannot be clicked at all (the GUI skips it); this shows that even a press reaching it
## does nothing.
func _click(button: BaseButton) -> void:
	button.pressed.emit()


func _collect(node: Node, into: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Label or child is UiButton:
			into.append(child)
		_collect(child, into)


## The window's controls shown on screen: labels with text (the tags among them) and buttons.
func _shown(sheet: HeroWindow) -> Array[Control]:
	var all: Array[Control] = []
	_collect(sheet, all)
	var shown: Array[Control] = []
	for control: Control in all:
		var label: Label = control as Label
		if control.is_visible_in_tree() and (label == null or not label.text.is_empty()):
			shown.append(control)
	return shown


## True when a label showing exactly [param text] is on screen in the sheet.
func _text_shown(sheet: HeroWindow, text: String) -> bool:
	for control: Control in _shown(sheet):
		var label: Label = control as Label
		if label != null and label.text == text:
			return true
	return false


func _name(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is UiButton:
		return "[%s]" % (control as UiButton).text
	return control.name


func _page_name(page: HeroWindow.Page) -> String:
	return HeroWindow.Page.keys()[page]


# --- R1 ------------------------------------------------------------------------


func test_r1_compact() -> void:
	# Spec 060 R7 and R10 replace the 240x150 sheet (278 tall on Talents): a hero window is the
	# same size on every tab, so two line up when compared, and fits in the room.
	_sim.party.gold = 1_000_000_000
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(99))
	var room := Vector2(_ui.room())
	for hero: Hero in _sim.party.heroes:
		var sheet: HeroWindow = _open(hero.id)
		var first: Vector2 = sheet.size
		for page: HeroWindow.Page in PAGES:
			sheet.open_page(page)
			_hud.advance(0.5)
			var rect: Rect2 = sheet.get_global_rect()
			var what: String = "%s on %s: %s" % [hero.class_id, _page_name(page), rect.size]
			assert_eq(rect.size, first, "%s the same size on every tab" % what)
			assert_lte(rect.size.x, room.x, "%s no wider than the room" % what)
			assert_lte(rect.size.y, room.y, "%s no taller than the room" % what)


# --- R2 ------------------------------------------------------------------------


func test_r2_header_never_changes() -> void:
	var rogue: Hero = _hero(1)
	rogue.gain_xp(70)
	rogue.health -= 9
	var sheet: HeroWindow = _open(rogue.id)
	_hud.advance(1.0)
	var before: Dictionary[StringName, String] = {}
	for key: StringName in HEADER_KEYS:
		before[key] = sheet.line(key)
		assert_ne(before[key], "", "%s has text" % key)
	var health: float = sheet.bar_fraction(&"health")
	var xp: float = sheet.bar_fraction(&"xp")
	assert_lt(health, 1.0, "the health bar is part full")
	assert_gt(xp, 0.0, "the XP bar is part full")
	for page: HeroWindow.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		for key: StringName in HEADER_KEYS:
			assert_eq(sheet.line(key), before[key], "%s unchanged %s" % [key, on])
			assert_true(_text_shown(sheet, before[key]), "%s shown %s" % [key, on])
		assert_true(_text_shown(sheet, "Health"), "the Health caption %s" % on)
		assert_true(_text_shown(sheet, "XP"), "the XP caption %s" % on)
		assert_almost_eq(sheet.bar_fraction(&"health"), health, 0.001, "health bar %s" % on)
		assert_almost_eq(sheet.bar_fraction(&"xp"), xp, 0.001, "XP bar %s" % on)
		assert_true(sheet.portrait.is_visible_in_tree(), "the portrait %s" % on)
		assert_eq(sheet.portrait.texture, _hud.icon(&"rogue"), "the rogue's portrait %s" % on)
		# The bars sit above the tabs.
		var bars: float = sheet.content.get_global_rect().position.y + HeroWindow.BARS_Y
		for tab: UiButton in sheet.tab_buttons:
			var top: float = tab.get_global_rect().position.y
			var bar_end: float = bars + HeroWindow.HEALTH_BAR_HEIGHT
			assert_gte(top, bar_end, "the tabs under the header %s" % on)


# --- R3 ------------------------------------------------------------------------


func test_r3_three_tabs() -> void:
	var rogue: Hero = _hero(1)
	rogue.gain_xp(Hero.xp_for_level(2))
	var sheet: HeroWindow = _open(rogue.id)
	_hud.advance(0.016)
	assert_eq(sheet.tab_buttons.size(), 3, "three tab buttons")
	if sheet.tab_buttons.size() != 3:
		return
	var names: Array[String] = []
	for tab: UiButton in sheet.tab_buttons:
		names.append(tab.text)
	assert_eq(names, ["Stats", "Talents", "Skills"] as Array[String], "named in order")
	var stat_text: String = sheet.line(&"stat_damage")
	var skill_text: String = sheet.line(&"microskills").split("\n")[0]
	assert_eq(skill_text, "Lockpicker: Opens locks", "the rogue's first microskill")
	for page: HeroWindow.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		assert_eq(sheet.page(), page, "the page is open")
		for i: int in sheet.tab_buttons.size():
			assert_eq(sheet.tab_buttons[i].lit, i == page, "tab %d lit only when open %s" % [i, on])
			assert_true(sheet.tab_buttons[i].is_visible_in_tree(), "every tab shows %s" % on)
		var stats: bool = page == HeroWindow.Page.STATS
		var talents: bool = page == HeroWindow.Page.TALENTS
		var skills: bool = page == HeroWindow.Page.SKILLS
		var damage: String = stat_text.get_slice(" ", 1)
		assert_eq(_text_shown(sheet, "Damage"), stats, "the stat names only on Stats %s" % on)
		assert_eq(_text_shown(sheet, damage), stats, "and their values %s" % on)
		assert_eq(sheet.talents.is_visible_in_tree(), talents, "the tree only on Talents %s" % on)
		# Spec 060 R6: a card, its name over what it does.
		var skill_name: String = skill_text.get_slice(":", 0)
		assert_eq(_text_shown(sheet, skill_name), skills, "microskills only on Skills %s" % on)

	# A hidden tab's train button is not shown, so it takes no click, and a press does nothing.
	_give_paragon(rogue, 5)
	_hud.advance(0.016)
	var power: ParagonCell = sheet.talents.paragon_cells[0]
	assert_eq(power.id, POWER, "the first paragon stat is Power")
	for page: HeroWindow.Page in [HeroWindow.Page.STATS, HeroWindow.Page.SKILLS]:
		sheet.open_page(page)
		_hud.advance(0.016)
		# Spec 064 R9: the stat's medallion is what a click spends a point on.
		assert_false(power.medallion.is_visible_in_tree(), "hidden on %s" % _page_name(page))
		power.medallion.clicked.emit()
		_sim.step()
		assert_eq(_rank(rogue, POWER), 0, "no training from %s" % _page_name(page))
	# The same press on the Talents tab trains.
	sheet.open_page(HeroWindow.Page.TALENTS)
	_hud.advance(0.016)
	assert_true(power.medallion.is_visible_in_tree(), "shown on Talents")
	power.medallion.clicked.emit()
	_sim.step()
	assert_eq(_rank(rogue, POWER), 1, "the medallion trains on the Talents tab")


# --- R4 ------------------------------------------------------------------------


func test_r4_easy_to_reach() -> void:
	var windows: HeroWindows = _hud.hero_windows
	assert_eq(windows.window_of(_hero(0).id).page(), HeroWindow.Page.STATS, "a new HUD: Stats")
	var sheet: HeroWindow = _open(_hero(0).id)
	_hud.advance(0.016)
	assert_eq(sheet.page(), HeroWindow.Page.STATS, "and opens on Stats")

	# Clicking a tab opens it.
	for page: HeroWindow.Page in [HeroWindow.Page.SKILLS, HeroWindow.Page.TALENTS]:
		_click(sheet.tab_buttons[page])
		assert_eq(sheet.page(), page, "clicking %s opens it" % _page_name(page))
	_click(sheet.tab_buttons[HeroWindow.Page.STATS])
	assert_eq(sheet.page(), HeroWindow.Page.STATS, "clicking Stats opens it")

	# E is next and Q is previous, wrapping.
	_key(KEY_E)
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "E: Stats to Talents")
	_key(KEY_E)
	assert_eq(sheet.page(), HeroWindow.Page.SKILLS, "E: Talents to Skills")
	_key(KEY_E)
	assert_eq(sheet.page(), HeroWindow.Page.STATS, "E wraps: Skills to Stats")
	_key(KEY_Q)
	assert_eq(sheet.page(), HeroWindow.Page.SKILLS, "Q wraps: Stats to Skills")
	_key(KEY_Q)
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "Q: Skills to Talents")
	sheet.next_page()
	sheet.previous_page()
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "next then previous comes back")

	# Spec 060 R3: each hero's window keeps its own tab; Q and E change the front one's.
	_key(KEY_TAB)
	var next: HeroWindow = windows.window_of(_hero(1).id)
	assert_eq(windows.front(), next, "Tab opens the next hero's window")
	assert_eq(next.page(), HeroWindow.Page.STATS, "on its own tab")
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "the first keeps its own")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	assert_false(windows.is_open(), "Esc closes them")
	_key(KEY_E)
	_key(KEY_Q)
	_key(KEY_Q)
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "Q and E do nothing while closed")
	sheet = _open(_hero(0).id)
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "reopened on Talents")
	sheet.close_button.pressed.emit()
	_key(KEY_TAB)
	assert_true(sheet.is_open(), "Tab reopens it")
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "still on Talents")

	# A new session starts on Stats.
	var fresh: Hud = _make_hud(Simulation.new(SEED))
	fresh.hero_windows.open(_sim.party.heroes[0].id)
	var page: HeroWindow.Page = fresh.hero_windows.window_of(_sim.party.heroes[0].id).page()
	assert_eq(page, HeroWindow.Page.STATS, "a new HUD's window starts on Stats")


# --- R5 ------------------------------------------------------------------------


func test_r5_talents_marker() -> void:
	var knight: Hero = _hero(0)
	var rogue: Hero = _hero(1)
	var sheet: HeroWindow = _hud.hero_windows.window_of(rogue.id)
	assert_not_null(sheet.talents_tag, "the Talents tab has a marker")
	if sheet.talents_tag == null:
		return
	_sim.party.gold = 1_000_000
	sheet = _open(rogue.id)
	for page: HeroWindow.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		assert_false(sheet.page_marked(HeroWindow.Page.TALENTS), "no point: no marker %s" % on)
		assert_false(sheet.talents_tag.is_visible_in_tree(), "and none shown %s" % on)
	_give_paragon(rogue, 1)
	for page: HeroWindow.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		assert_true(sheet.page_marked(HeroWindow.Page.TALENTS), "a point to spend: marked %s" % on)
		assert_true(sheet.talents_tag.is_visible_in_tree(), "and shown %s" % on)
		assert_false(sheet.page_marked(HeroWindow.Page.STATS), "Stats is never marked %s" % on)
		var tab: Rect2 = sheet.tab_buttons[HeroWindow.Page.TALENTS].get_global_rect()
		var mark: Rect2 = sheet.talents_tag.get_global_rect()
		assert_true(mark.intersects(tab), "pinned on the Talents tab %s" % on)
		assert_gt(mark.end.x, tab.end.x - 1.0, "at its right %s" % on)

	# It is the hero's own: a hero with no paragon point is not marked.
	var other: HeroWindow = _open(knight.id)
	_hud.advance(0.016)
	assert_false(other.page_marked(HeroWindow.Page.TALENTS), "the knight has no point")
	assert_false(other.talents_tag.is_visible_in_tree(), "no marker for the knight")
	assert_true(sheet.page_marked(HeroWindow.Page.TALENTS), "the rogue's window: marked")
	sheet.close()
	_hud.advance(0.016)
	assert_false(sheet.talents_tag.is_visible_in_tree(), "nothing shows while closed")


# --- R6 ------------------------------------------------------------------------


func test_r6_skills_marker() -> void:
	var knight: Hero = _hero(0)
	var mage: Hero = _hero(2)
	var sheet: HeroWindow = _hud.hero_windows.window_of(knight.id)
	var mage_sheet: HeroWindow = _hud.hero_windows.window_of(mage.id)
	assert_not_null(sheet.skills_tag, "the Skills tab has a marker")
	if sheet.skills_tag == null:
		return
	for hero: Hero in _sim.party.heroes:
		var shown: HeroWindow = _open(hero.id)
		_hud.advance(0.016)
		assert_false(shown.page_marked(HeroWindow.Page.SKILLS), "%s: nothing new" % hero.class_id)
		shown.close()

	# The knight learns Strongarm at level 3 while its window is closed.
	knight.gain_xp(Hero.xp_for_level(3))
	assert_true(knight.has_microskill(&"strongarm"), "the knight learned Strongarm")
	_hud.advance(0.016)
	sheet = _open(knight.id)
	sheet.open_page(HeroWindow.Page.STATS)
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroWindow.Page.SKILLS), "the Skills tab is marked")
	assert_true(sheet.skills_tag.is_visible_in_tree(), "and shows it")
	var tab: Rect2 = sheet.tab_buttons[HeroWindow.Page.SKILLS].get_global_rect()
	assert_true(sheet.skills_tag.get_global_rect().intersects(tab), "pinned on the Skills tab")
	sheet.open_page(HeroWindow.Page.TALENTS)
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroWindow.Page.SKILLS), "still marked from Talents")
	mage_sheet = _open(mage.id)
	_hud.advance(0.016)
	assert_false(mage_sheet.page_marked(HeroWindow.Page.SKILLS), "the mage learned nothing")
	assert_false(mage_sheet.skills_tag.is_visible_in_tree(), "no marker on the mage's window")
	mage_sheet.close()
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroWindow.Page.SKILLS), "the knight's mark waits")

	# Opening the tab clears it, for good.
	sheet.open_page(HeroWindow.Page.SKILLS)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroWindow.Page.SKILLS), "opening Skills clears the marker")
	assert_false(sheet.skills_tag.is_visible_in_tree(), "it no longer shows")
	sheet.open_page(HeroWindow.Page.STATS)
	sheet.close()
	sheet = _open(knight.id)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroWindow.Page.SKILLS), "and does not come back")

	# Learned while Skills is open for that hero: seen at once.
	mage_sheet = _open(mage.id)
	mage_sheet.open_page(HeroWindow.Page.SKILLS)
	_hud.advance(0.016)
	mage.gain_xp(Hero.xp_for_level(4))
	assert_true(mage.has_microskill(&"runereader"), "the mage learned Runereader")
	_hud.advance(0.016)
	mage_sheet.open_page(HeroWindow.Page.STATS)
	_hud.advance(0.016)
	assert_false(mage_sheet.page_marked(HeroWindow.Page.SKILLS), "learned in view: no marker")


# --- R7 ------------------------------------------------------------------------


func test_r7_number_keys() -> void:
	var rogue: Hero = _hero(1)
	_give_paragon(rogue, 5)
	var sheet: HeroWindow = _open(rogue.id)
	for page: HeroWindow.Page in [HeroWindow.Page.STATS, HeroWindow.Page.SKILLS]:
		sheet.open_page(page)
		_hud.advance(0.016)
		_key(KEY_1)
		_key(KEY_2)
		_key(KEY_3)
		sheet.train_row(0)
		_sim.step()
		for id: StringName in Content.training_ids():
			assert_eq(_rank(rogue, id), 0, "1 to 3 train nothing on %s" % _page_name(page))
		assert_eq(rogue.paragon_points(), 5, "no point spent on %s" % _page_name(page))
	sheet.open_page(HeroWindow.Page.TALENTS)
	_hud.advance(0.016)
	var ids: Array[StringName] = Content.training_ids()
	var codes: Array[Key] = [KEY_1, KEY_2, KEY_3]
	for i: int in 3:
		_key(codes[i])
		_sim.step()
		assert_eq(_rank(rogue, ids[i]), 1, "%d trains %s on Talents" % [i + 1, ids[i]])


# --- R9 ------------------------------------------------------------------------


func test_r9_out_of_the_way() -> void:
	_sim.party.gold = 1_000_000_000
	_sim.upgrades.set_rank(&"sharp_blades", 20)
	_sim.upgrades.set_rank(&"stout_armor", 20)
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _sim.party.heroes[i]
		hero.gain_xp(Hero.xp_for_level(99))
		hero.set_paragon_rank(i % 3 as TrainingDef.Stat, 99)
		hero.set_paragon_rank(TrainingDef.Stat.POWER, 1999 - i)
	# Spec 060: the windows are on the UI layer, measured in its pixels; each opens alone at its
	# own place (spec 060 R7 checks two side by side).
	var top_band: float = _ui.world_to_ui(Vector2(0, Hud.TOP_BAND)).y
	var frames_top: float = _ui.world_to_ui(Vector2(0, _ui.frames_top())).y
	var room := Vector2(_ui.room())
	for hero: Hero in _sim.party.heroes:
		var sheet: HeroWindow = _open(hero.id)
		for page: HeroWindow.Page in PAGES:
			sheet.open_page(page)
			_hud.advance(0.5)
			var rect: Rect2 = sheet.get_global_rect()
			var what: String = "%s on %s %s" % [hero.class_id, _page_name(page), rect]
			assert_gte(rect.position.y, top_band, "%s: below the top band" % what)
			assert_lte(rect.end.y, frames_top, "%s: above the frames" % what)
			assert_gte(rect.position.x, 0.0, "%s: on screen" % what)
			assert_lte(rect.end.x, room.x, "%s: on screen" % what)
			var shown: Array[Control] = _shown(sheet)
			assert_gt(shown.size(), 12, "%s: the sheet's text" % what)
			for control: Control in shown:
				var box: Rect2 = control.get_global_rect()
				var where: String = "%s %s %s" % [what, _name(control), box]
				if sheet.talents.is_ancestor_of(control) and box.end.y > rect.end.y:
					# Spec 064 R9: the paragon medallions sit under the tree, past the first view
					# of the part that scrolls (test_064's R9 scrolls to them, its R13 checks the
					# tab fits): inside the window across, below its top.
					var across: bool = box.position.x >= rect.position.x and box.end.x <= rect.end.x
					assert_true(across, "%s inside the window" % where)
					assert_gte(box.position.y, rect.position.y, "%s inside the window" % where)
					continue
				assert_true(rect.encloses(box), "%s inside the window" % where)
				if control is HeroWindow.Tag:
					continue
				for other: Control in shown:
					if other == control or other is HeroWindow.Tag:
						continue
					if other.get_global_rect().intersects(box):
						fail_test("%s overlaps %s" % [where, _name(other)])
		sheet.close()

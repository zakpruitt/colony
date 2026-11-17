extends GutTest
## Acceptance tests for specs/034-hero-sheet-tabs/spec.md, one per requirement. R8 is the existing
## suite (specs 026, 028 and 029) passing.

const SEED: int = 34
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
## Pixels kept clear just above the party frames (spec 027's ticker).
const TICKER_STRIP: float = 12.0
const MOST: Vector2 = Vector2(240, 150)
const PAGES: Array[HeroSheet.Page] = [
	HeroSheet.Page.STATS, HeroSheet.Page.TRAINING, HeroSheet.Page.SKILLS
]
const HEADER_KEYS: Array[StringName] = [&"class", &"role", &"level", &"activity", &"health", &"xp"]
const STAT_KEYS: Array[StringName] = [
	&"stat_health", &"stat_damage", &"stat_armor", &"stat_attack_speed", &"stat_crit", &"stat_range"
]
const POWER: StringName = &"power"

var _sim: Simulation
var _world: World
var _hud: Hud


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
	_hud.advance(0.0)
	return _hud


func _sheet() -> HeroSheet:
	return _hud.hero_sheet


## Raises [param hero] to the level that gives it [param points] paragon points (spec 051 took
## the gold off training: a row spends a paragon point).
func _give_paragon(hero: Hero, points: int) -> void:
	var level: int = Hero.TALENT_POINTS * Hero.TALENT_EVERY + points
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)


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
func _click(button: HudButton) -> void:
	button.pressed.emit()


func _collect(node: Node, into: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Label or child is HudButton or child is ShopMarker:
			into.append(child)
		_collect(child, into)


## The sheet's controls shown on screen: labels with text, buttons and markers.
func _shown(sheet: HeroSheet) -> Array[Control]:
	var all: Array[Control] = []
	_collect(sheet, all)
	var shown: Array[Control] = []
	for control: Control in all:
		var label: Label = control as Label
		if control.is_visible_in_tree() and (label == null or not label.text.is_empty()):
			shown.append(control)
	return shown


## True when a label showing exactly [param text] is on screen in the sheet.
func _text_shown(sheet: HeroSheet, text: String) -> bool:
	for control: Control in _shown(sheet):
		var label: Label = control as Label
		if label != null and label.text == text:
			return true
	return false


func _name(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is HudButton:
		return "[%s]" % (control as HudButton).text
	return control.name


func _page_name(page: HeroSheet.Page) -> String:
	return HeroSheet.Page.keys()[page]


# --- R1 ------------------------------------------------------------------------


func test_r1_compact() -> void:
	var sheet: HeroSheet = _sheet()
	_sim.party.gold = 1_000_000_000
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(99))
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		for page: HeroSheet.Page in PAGES:
			sheet.open_page(page)
			_hud.advance(0.5)
			var rect: Rect2 = sheet.get_global_rect()
			var what: String = "%s on %s: %s" % [hero.class_id, _page_name(page), rect.size]
			assert_lte(rect.size.x, MOST.x, "%s at most 240 wide" % what)
			assert_lte(rect.size.y, MOST.y, "%s at most 150 tall" % what)


# --- R2 ------------------------------------------------------------------------


func test_r2_header_never_changes() -> void:
	var sheet: HeroSheet = _sheet()
	var rogue: Hero = _hero(1)
	rogue.gain_xp(70)
	rogue.health -= 9
	sheet.open(rogue.id)
	_hud.advance(1.0)
	var before: Dictionary[StringName, String] = {}
	for key: StringName in HEADER_KEYS:
		before[key] = sheet.line(key)
		assert_ne(before[key], "", "%s has text" % key)
	var health: float = sheet.bar_fraction(&"health")
	var xp: float = sheet.bar_fraction(&"xp")
	assert_lt(health, 1.0, "the health bar is part full")
	assert_gt(xp, 0.0, "the XP bar is part full")
	for page: HeroSheet.Page in PAGES:
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
		for tab: HudButton in sheet.tab_buttons:
			var top: float = tab.get_global_rect().position.y - sheet.get_global_rect().position.y
			assert_gte(top, HeroSheet.XP_BAR.end.y, "the tabs under the header %s" % on)


# --- R3 ------------------------------------------------------------------------


func test_r3_three_tabs() -> void:
	var sheet: HeroSheet = _sheet()
	var rogue: Hero = _hero(1)
	rogue.gain_xp(Hero.xp_for_level(2))
	sheet.open(rogue.id)
	_hud.advance(0.016)
	assert_eq(sheet.tab_buttons.size(), 3, "three tab buttons")
	if sheet.tab_buttons.size() != 3:
		return
	var names: Array[String] = []
	for tab: HudButton in sheet.tab_buttons:
		names.append(tab.text)
	assert_eq(names, ["Stats", "Training", "Skills"] as Array[String], "named in order")
	var stat_text: String = sheet.line(&"stat_damage")
	var skill_text: String = sheet.line(&"microskills").split("\n")[0]
	assert_eq(skill_text, "Lockpicker: Opens locks", "the rogue's first microskill")
	for page: HeroSheet.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		assert_eq(sheet.page(), page, "the page is open")
		for i: int in sheet.tab_buttons.size():
			assert_eq(sheet.tab_buttons[i].lit, i == page, "tab %d lit only when open %s" % [i, on])
			assert_true(sheet.tab_buttons[i].is_visible_in_tree(), "every tab shows %s" % on)
		var stats: bool = page == HeroSheet.Page.STATS
		var training: bool = page == HeroSheet.Page.TRAINING
		var skills: bool = page == HeroSheet.Page.SKILLS
		var damage: String = stat_text.get_slice(" ", 1)
		assert_eq(_text_shown(sheet, "Damage"), stats, "the stat names only on Stats %s" % on)
		assert_eq(_text_shown(sheet, damage), stats, "and their values %s" % on)
		for row: HeroSheet.TrainingRow in sheet.training_rows:
			assert_eq(
				row.is_visible_in_tree(), training, "%s row only on Training %s" % [row.id, on]
			)
		assert_eq(_text_shown(sheet, skill_text), skills, "microskills only on Skills %s" % on)

	# A hidden tab's train button is not shown, so it takes no click, and a press does nothing.
	_give_paragon(rogue, 5)
	_hud.advance(0.016)
	var power: HeroSheet.TrainingRow = sheet.training_row(&"training_power")
	for page: HeroSheet.Page in [HeroSheet.Page.STATS, HeroSheet.Page.SKILLS]:
		sheet.open_page(page)
		_hud.advance(0.016)
		assert_false(power.buy_button.is_visible_in_tree(), "hidden on %s" % _page_name(page))
		_click(power.buy_button)
		_sim.step()
		assert_eq(_rank(rogue, POWER), 0, "no training from %s" % _page_name(page))
	# The same press on the Training tab trains.
	sheet.open_page(HeroSheet.Page.TRAINING)
	_hud.advance(0.016)
	assert_true(power.buy_button.is_visible_in_tree(), "shown on Training")
	_click(power.buy_button)
	_sim.step()
	assert_eq(_rank(rogue, POWER), 1, "the button trains on the Training tab")


# --- R4 ------------------------------------------------------------------------


func test_r4_easy_to_reach() -> void:
	var sheet: HeroSheet = _sheet()
	assert_eq(sheet.page(), HeroSheet.Page.STATS, "a new HUD starts on Stats")
	sheet.open(_hero(0).id)
	_hud.advance(0.016)
	assert_eq(sheet.page(), HeroSheet.Page.STATS, "and opens on Stats")

	# Clicking a tab opens it.
	for page: HeroSheet.Page in [HeroSheet.Page.SKILLS, HeroSheet.Page.TRAINING]:
		_click(sheet.tab_buttons[page])
		assert_eq(sheet.page(), page, "clicking %s opens it" % _page_name(page))
	_click(sheet.tab_buttons[HeroSheet.Page.STATS])
	assert_eq(sheet.page(), HeroSheet.Page.STATS, "clicking Stats opens it")

	# E is next and Q is previous, wrapping.
	_key(KEY_E)
	assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "E: Stats to Training")
	_key(KEY_E)
	assert_eq(sheet.page(), HeroSheet.Page.SKILLS, "E: Training to Skills")
	_key(KEY_E)
	assert_eq(sheet.page(), HeroSheet.Page.STATS, "E wraps: Skills to Stats")
	_key(KEY_Q)
	assert_eq(sheet.page(), HeroSheet.Page.SKILLS, "Q wraps: Stats to Skills")
	_key(KEY_Q)
	assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "Q: Skills to Training")
	sheet.next_page()
	sheet.previous_page()
	assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "next then previous comes back")

	# The tab is kept across heroes, closing and reopening.
	for i: int in _sim.party.heroes.size():
		_key(KEY_TAB)
		assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "kept on hero %d" % (i + 1))
	_key(KEY_ESCAPE)
	assert_false(sheet.is_open(), "Esc closes the sheet")
	_key(KEY_E)
	_key(KEY_Q)
	_key(KEY_Q)
	assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "Q and E do nothing while closed")
	sheet.open(_hero(2).id)
	assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "reopened on Training")
	sheet.close_button.pressed.emit()
	_key(KEY_TAB)
	assert_true(sheet.is_open(), "Tab reopens it")
	assert_eq(sheet.page(), HeroSheet.Page.TRAINING, "still on Training")

	# A new session starts on Stats.
	var fresh: Hud = _make_hud(Simulation.new(SEED))
	fresh.hero_sheet.open(_sim.party.heroes[0].id)
	assert_eq(fresh.hero_sheet.page(), HeroSheet.Page.STATS, "a new HUD's sheet starts on Stats")


# --- R5 ------------------------------------------------------------------------


func test_r5_training_marker() -> void:
	var sheet: HeroSheet = _sheet()
	var knight: Hero = _hero(0)
	var rogue: Hero = _hero(1)
	assert_not_null(sheet.training_marker, "the Training tab has a marker")
	if sheet.training_marker == null:
		return
	_sim.party.gold = 1_000_000
	sheet.open(rogue.id)
	for page: HeroSheet.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		assert_false(
			sheet.page_marked(HeroSheet.Page.TRAINING), "no paragon point: no marker %s" % on
		)
		assert_false(sheet.training_marker.is_visible_in_tree(), "and none shown %s" % on)
	_give_paragon(rogue, 1)
	for page: HeroSheet.Page in PAGES:
		sheet.open_page(page)
		_hud.advance(0.016)
		var on: String = "on %s" % _page_name(page)
		assert_true(sheet.page_marked(HeroSheet.Page.TRAINING), "a point to spend: marked %s" % on)
		assert_true(sheet.training_marker.is_visible_in_tree(), "and shown %s" % on)
		assert_false(sheet.page_marked(HeroSheet.Page.STATS), "Stats is never marked %s" % on)
		var tab: Rect2 = sheet.tab_buttons[HeroSheet.Page.TRAINING].get_global_rect()
		var mark: Rect2 = sheet.training_marker.get_global_rect()
		assert_true(mark.intersects(tab), "pinned on the Training tab %s" % on)
		assert_gt(mark.end.x, tab.end.x - 1.0, "at its right %s" % on)

	# It is the shown hero's: a hero with no paragon point is not marked.
	sheet.open(knight.id)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroSheet.Page.TRAINING), "the knight has no point")
	assert_false(sheet.training_marker.is_visible_in_tree(), "no marker for the knight")
	sheet.open(rogue.id)
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroSheet.Page.TRAINING), "back on the rogue: marked")
	sheet.close()
	_hud.advance(0.016)
	assert_false(sheet.training_marker.is_visible_in_tree(), "nothing shows while closed")


# --- R6 ------------------------------------------------------------------------


func test_r6_skills_marker() -> void:
	var sheet: HeroSheet = _sheet()
	var knight: Hero = _hero(0)
	var mage: Hero = _hero(2)
	assert_not_null(sheet.skills_marker, "the Skills tab has a marker")
	if sheet.skills_marker == null:
		return
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		_hud.advance(0.016)
		assert_false(sheet.page_marked(HeroSheet.Page.SKILLS), "%s: nothing new" % hero.class_id)
	sheet.close()

	# The knight learns Strongarm at level 3 while the sheet is closed.
	knight.gain_xp(Hero.xp_for_level(3))
	assert_true(knight.has_microskill(&"strongarm"), "the knight learned Strongarm")
	_hud.advance(0.016)
	sheet.open(knight.id)
	sheet.open_page(HeroSheet.Page.STATS)
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroSheet.Page.SKILLS), "the Skills tab is marked")
	assert_true(sheet.skills_marker.is_visible_in_tree(), "and shows it")
	var tab: Rect2 = sheet.tab_buttons[HeroSheet.Page.SKILLS].get_global_rect()
	assert_true(sheet.skills_marker.get_global_rect().intersects(tab), "pinned on the Skills tab")
	sheet.open_page(HeroSheet.Page.TRAINING)
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroSheet.Page.SKILLS), "still marked from Training")
	sheet.open(mage.id)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroSheet.Page.SKILLS), "the mage learned nothing")
	assert_false(sheet.skills_marker.is_visible_in_tree(), "no marker on the mage's sheet")
	sheet.open(knight.id)
	_hud.advance(0.016)
	assert_true(sheet.page_marked(HeroSheet.Page.SKILLS), "the knight's mark waits")

	# Opening the tab clears it, for good.
	sheet.open_page(HeroSheet.Page.SKILLS)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroSheet.Page.SKILLS), "opening Skills clears the marker")
	assert_false(sheet.skills_marker.is_visible_in_tree(), "it no longer shows")
	sheet.open_page(HeroSheet.Page.STATS)
	sheet.close()
	sheet.open(knight.id)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroSheet.Page.SKILLS), "and does not come back")

	# Learned while Skills is open for that hero: seen at once.
	sheet.open(mage.id)
	sheet.open_page(HeroSheet.Page.SKILLS)
	_hud.advance(0.016)
	mage.gain_xp(Hero.xp_for_level(4))
	assert_true(mage.has_microskill(&"runereader"), "the mage learned Runereader")
	_hud.advance(0.016)
	sheet.open_page(HeroSheet.Page.STATS)
	_hud.advance(0.016)
	assert_false(sheet.page_marked(HeroSheet.Page.SKILLS), "learned in view: no marker")


# --- R7 ------------------------------------------------------------------------


func test_r7_number_keys() -> void:
	var sheet: HeroSheet = _sheet()
	var rogue: Hero = _hero(1)
	_give_paragon(rogue, 5)
	sheet.open(rogue.id)
	for page: HeroSheet.Page in [HeroSheet.Page.STATS, HeroSheet.Page.SKILLS]:
		sheet.open_page(page)
		_hud.advance(0.016)
		_key(KEY_1)
		_key(KEY_2)
		_key(KEY_3)
		sheet.train_row(0)
		_sim.step()
		assert_false(rogue.has_grown(), "1 to 3 train nothing on %s" % _page_name(page))
		assert_eq(rogue.paragon_points(), 5, "no point spent on %s" % _page_name(page))
	sheet.open_page(HeroSheet.Page.TRAINING)
	_hud.advance(0.016)
	var ids: Array[StringName] = Content.training_ids()
	var codes: Array[Key] = [KEY_1, KEY_2, KEY_3]
	for i: int in 3:
		_key(codes[i])
		_sim.step()
		assert_eq(_rank(rogue, ids[i]), 1, "%d trains %s on Training" % [i + 1, ids[i]])


# --- R9 ------------------------------------------------------------------------


func test_r9_out_of_the_way() -> void:
	var sheet: HeroSheet = _sheet()
	_sim.party.gold = 1_000_000_000
	_sim.upgrades.set_rank(&"sharp_blades", 20)
	_sim.upgrades.set_rank(&"stout_armor", 20)
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _sim.party.heroes[i]
		hero.gain_xp(Hero.xp_for_level(99))
		hero.set_paragon_rank(i % 3 as TrainingDef.Stat, 99)
		hero.set_paragon_rank(TrainingDef.Stat.POWER, 1999 - i)
	var frames_top: float = SCREEN.y
	for frame: HeroFrame in _hud.frames:
		frames_top = minf(frames_top, frame.get_global_rect().position.y)
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		for page: HeroSheet.Page in PAGES:
			sheet.open_page(page)
			_hud.advance(0.5)
			var rect: Rect2 = sheet.get_global_rect()
			var what: String = "%s on %s %s" % [hero.class_id, _page_name(page), rect]
			assert_gte(rect.position.y, TOP_BAND, "%s: below the top band" % what)
			assert_lte(rect.end.y, frames_top - TICKER_STRIP, "%s: 12 px above the frames" % what)
			assert_gte(rect.position.x, 0.0, "%s: on screen" % what)
			assert_lte(rect.end.x, SCREEN.x, "%s: on screen" % what)
			var shown: Array[Control] = _shown(sheet)
			assert_gt(shown.size(), 12, "%s: the sheet's text" % what)
			for control: Control in shown:
				var box: Rect2 = control.get_global_rect()
				var where: String = "%s %s %s" % [what, _name(control), box]
				assert_true(rect.encloses(box), "%s inside the sheet" % where)
				if control is ShopMarker:
					continue
				for other: Control in shown:
					if other == control or other is ShopMarker:
						continue
					if other.get_global_rect().intersects(box):
						fail_test("%s overlaps %s" % [where, _name(other)])

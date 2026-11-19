extends ColonyTest
## Acceptance tests for specs/026-hero-sheet/spec.md, one per requirement. Since spec 060 the
## sheet is a window per hero on the UI layer ([HeroWindows]): these tests read the hero's window.

const SEED: int = 26
## The UI layer's room these tests lay it out in (spec 058).
const ROOM: Vector2i = Vector2i(1280, 720)
const BLADES: StringName = &"sharp_blades"
const ARMOR: StringName = &"stout_armor"
const ROLES: Dictionary[StringName, String] = {
	&"knight": "Tank",
	&"rogue": "Striker",
	&"mage": "Caster",
	&"cleric": "Healer",
}
const STAT_KEYS: Array[StringName] = [
	&"stat_health",
	&"stat_damage",
	&"stat_armor",
	&"stat_attack_speed",
	&"stat_crit",
	&"stat_range",
	&"stat_healing",
]

var _sim: Simulation
var _world: World
var _effects: CombatEffects
var _hud: Hud
var _ui: UiRoot


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_hud = _make_hud(_sim)


func after_each() -> void:
	super()
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


func _make_hud(simulation: Simulation) -> Hud:
	_world = World.new()
	_world.simulation = simulation
	add_child_autofree(_world)
	_world.set_process(false)
	_effects = CombatEffects.new()
	add_child_autofree(_effects)
	_effects.setup(_world, simulation)
	_effects.set_process(false)
	var made := Hud.new()
	add_child_autofree(made)
	made.set_process(false)
	made.setup(simulation, _world, _effects)
	# Spec 060: the hero windows live on the UI layer, which gives them to the HUD.
	_ui = UiRoot.new()
	add_child_autofree(_ui)
	_ui.set_room_for_test(ROOM)
	_ui.setup(simulation, made, null)
	made.advance(0.0)
	return made


## A left click on [param frame], delivered as the GUI delivers one.
func _click(frame: HeroFrameView) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = frame.size / 2.0
		frame._gui_input(event)


func _windows() -> HeroWindows:
	return _hud.hero_windows


## Hero [param hero_id]'s window, opened (spec 060: the sheet of that hero).
func _open(hero_id: int, hud: Hud = _hud) -> HeroWindow:
	hud.hero_windows.open(hero_id)
	return hud.hero_windows.window_of(hero_id)


func _hero(index: int) -> Hero:
	return _sim.party.heroes[index]


## Steps until the expedition is in [param wanted], at most [param limit] ticks.
func _step_until(wanted: Expedition.State, limit: int = 20000) -> bool:
	return step_until(_sim, func() -> bool: return _sim.expedition.state == wanted, limit)


func _marked_ids() -> Array[int]:
	var marked: Array[int] = []
	for frame: HeroFrameView in _hud.frames:
		if frame.marked:
			marked.append(frame.hero_id)
	return marked


## What an upgrade adds, as the Stats tab says it beside the stat (spec 060 R4):
## [code] +15% Sharp Blades[/code].
static func _bonus(multiplier: float, upgrade_id: StringName) -> String:
	var percent: int = roundi((multiplier - 1.0) * 100.0)
	return " +%d%% %s" % [percent, Content.upgrade(upgrade_id).display_name]


# --- R1 ------------------------------------------------------------------------


func test_r1_opening_and_closing() -> void:
	var windows: HeroWindows = _windows()
	assert_not_null(windows, "the HUD has hero windows")
	if windows == null:
		return
	assert_false(windows.is_open(), "closed at first")
	assert_eq(_marked_ids(), [] as Array[int], "no frame is marked")

	var first: HeroFrameView = _hud.frames[0]
	var second: HeroFrameView = _hud.frames[1]
	var first_window: HeroWindow = windows.window_of(first.hero_id)
	var second_window: HeroWindow = windows.window_of(second.hero_id)
	assert_false(first_window.is_visible_in_tree(), "not shown")
	_click(first)
	assert_true(first_window.is_open(), "clicking a frame opens its hero's window")
	assert_true(first_window.is_visible_in_tree(), "and it shows")
	assert_eq(_marked_ids(), [first.hero_id] as Array[int], "that frame is marked")
	var plain: HeroFrameView = _hud.frames[2]
	assert_ne(
		first.edge_colour(),
		plain.edge_colour(),
		"visibly: its edge differs from an unmarked frame's"
	)
	_click(first)
	assert_false(first_window.is_open(), "clicking the same frame closes it")
	assert_eq(_marked_ids(), [] as Array[int], "and unmarks it")

	# Spec 060 R1: another frame opens another window beside the first, rather than switching.
	_click(first)
	_click(second)
	assert_true(second_window.is_open(), "clicking another frame opens that hero's window")
	assert_true(first_window.is_open(), "beside the first")
	assert_eq(_marked_ids(), [first.hero_id, second.hero_id] as Array[int], "both marked")
	press(KEY_ESCAPE)
	assert_false(second_window.is_open(), "Esc closes the front one")
	press(KEY_ESCAPE)
	assert_false(first_window.is_open(), "and again the next")
	press(KEY_ESCAPE)
	assert_false(windows.is_open(), "and does not open one")

	_click(second)
	assert_not_null(second_window.close_button, "the window has a close button")
	if second_window.close_button != null:
		assert_true(second_window.close_button.is_visible_in_tree(), "shown on the window")
		second_window.close_button.pressed.emit()
		assert_false(second_window.is_open(), "the close button closes it")
		assert_eq(_marked_ids(), [] as Array[int], "and unmarks the frame")

	var opened: Array[int] = []
	for i: int in _sim.party.heroes.size():
		press(KEY_TAB)
		opened.append(_hero(i).id)
		var told: String = "Tab %d: hero %d in front" % [i + 1, i + 1]
		assert_eq(windows.front(), windows.window_of(_hero(i).id), told)
		assert_eq(_marked_ids(), opened, "and marks its frame")
	press(KEY_TAB)
	assert_eq(windows.front(), windows.window_of(_hero(0).id), "after the last hero, the first")

	# Specs 059 and 060: the shop is a window too, and opens beside the hero windows; Tab, with the
	# shop in front, brings the next hero's window in front and leaves the shop open.
	press(KEY_U)
	assert_true(_hud.shop.is_open(), "U opens the shop")
	assert_true(windows.is_open(_hero(0).id), "beside the hero windows")
	assert_eq(_hud.windows.front().content, _hud.shop, "in front")
	press(KEY_TAB)
	assert_eq(windows.front(), windows.window_of(_hero(1).id), "Tab: the next hero in front")
	assert_true(_hud.shop.is_open(), "the shop stays open")

	var main: Main = make_main()
	add_child_autofree(main)
	main.hud.hero_windows.open(main.simulation.party.heroes[0].id)
	main.driver.advance(1_000_000)
	var tick: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(main.hud.hero_windows.is_open(), "the window is open")
	assert_gt(main.simulation.tick, tick, "and the game runs behind it")
	assert_false(get_tree().paused, "unpaused")


# --- R2 ------------------------------------------------------------------------


func test_r2_who_they_are() -> void:
	assert_not_null(_windows(), "the HUD has hero windows")
	if _windows() == null:
		return
	assert_eq(_sim.party.heroes.size(), 4, "four heroes")
	_hero(2).gain_xp(Hero.xp_for_level(4))
	var sheet: HeroWindow
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _hero(i)
		sheet = _open(hero.id)
		_hud.advance(0.016)
		var what: String = String(hero.class_id)
		assert_eq(sheet.line(&"class"), hero.def().display_name, "%s: the class name" % what)
		assert_eq(sheet.line(&"role"), ROLES[hero.class_id], "%s: the role in one word" % what)
		assert_eq(sheet.line(&"level"), "Level %d" % hero.level, "%s: the level" % what)
		assert_not_null(sheet.portrait, "%s: a portrait" % what)
		if sheet.portrait != null:
			assert_eq(sheet.portrait.texture, _hud.icon(hero.class_id), "%s: its class's" % what)
			var frame_icon: Vector2 = _hud.frames[i].icon.size
			assert_eq(sheet.portrait.size, frame_icon * 2.0, "%s: twice the frame's size" % what)
			assert_true(sheet.portrait.is_visible_in_tree(), "%s: shown" % what)
	assert_eq(sheet.line(&"level"), "Level %d" % _hero(3).level)
	sheet = _open(_hero(2).id)
	assert_eq(sheet.line(&"level"), "Level 4", "the mage's levels show")


# --- R3 ------------------------------------------------------------------------


func _expected_xp(hero: Hero) -> String:
	var floor_xp: int = Hero.xp_for_level(hero.level)
	var next_xp: int = Hero.xp_for_level(hero.level + 1)
	return (
		"%d / %d XP, %d to level %d"
		% [hero.xp - floor_xp, next_xp - floor_xp, next_xp - hero.xp, hero.level + 1]
	)


func test_r3_where_they_stand() -> void:
	assert_not_null(_windows(), "the HUD has hero windows")
	if _windows() == null:
		return
	var hero: Hero = _hero(1)
	var sheet: HeroWindow = _open(hero.id)
	_hud.advance(0.016)
	assert_eq(sheet.line(&"health"), "%d / %d" % [hero.max_health(), hero.max_health()], "full")
	assert_eq(sheet.line(&"xp"), "0 / 20 XP, 20 to level 2", "no XP yet")
	assert_almost_eq(sheet.bar_fraction(&"health"), 1.0, 0.001, "a full health bar")
	assert_almost_eq(sheet.bar_fraction(&"xp"), 0.0, 0.001, "an empty XP bar")

	hero.health -= 23
	hero.gain_xp(12)
	_hud.advance(1.0)
	assert_eq(sheet.line(&"health"), "%d / %d" % [hero.health, hero.max_health()], "after damage")
	assert_eq(sheet.line(&"xp"), "12 / 20 XP, 8 to level 2", "after XP")
	assert_eq(sheet.line(&"xp"), _expected_xp(hero))
	var health: float = float(hero.health) / hero.max_health()
	assert_almost_eq(sheet.bar_fraction(&"health"), health, 0.001, "the health bar follows")
	assert_almost_eq(sheet.bar_fraction(&"xp"), 0.6, 0.001, "and the XP bar")

	hero.gain_xp(400)
	_hud.advance(1.0)
	assert_eq(sheet.line(&"xp"), _expected_xp(hero), "several levels on")

	# Mid-fight, the hero's health is its fighter's.
	assert_true(_step_until(Expedition.State.FIGHTING), "the party meets a fight")
	var fighter: Combatant = _sim.expedition.battle.combatant(hero.id)
	fighter.health = fighter.max_health - 17
	_hud.advance(0.016)
	assert_eq(sheet.line(&"health"), "%d / %d" % [fighter.health, fighter.max_health], "in a fight")


# --- R4 ------------------------------------------------------------------------


func _expected_stats(hero: Hero) -> Dictionary[StringName, String]:
	var fighter: Combatant = hero.combatant()
	var def: HeroClassDef = hero.def()
	var health_bonus: float = _sim.upgrades.multiplier(UpgradeDef.Stat.HEALTH)
	var power: float = _sim.upgrades.multiplier(UpgradeDef.Stat.DAMAGE)
	var stats: Dictionary[StringName, String] = {}
	stats[&"stat_health"] = "Health %d" % hero.max_health()
	stats[&"stat_damage"] = "Damage %d" % fighter.damage
	if health_bonus > 1.0:
		stats[&"stat_health"] += _bonus(health_bonus, ARMOR)
	if power > 1.0:
		stats[&"stat_damage"] += _bonus(power, BLADES)
	stats[&"stat_armor"] = "Armor %d" % fighter.armor
	stats[&"stat_attack_speed"] = "Attack speed %.1f/s" % (1.0 / def.attack_interval)
	stats[&"stat_crit"] = "Crit chance %d%%" % roundi(def.crit_chance * 100.0)
	var reach: String = "Melee"
	if def.attack_range > Battle.MELEE_REACH:
		reach = "%s tiles" % HeroWindow.tiles(def.attack_range)
	stats[&"stat_range"] = "Range %s" % reach
	stats[&"stat_healing"] = ""
	if def.heal_power > 0:
		stats[&"stat_healing"] = "Healing %d" % fighter.heal_power
		if power > 1.0:
			stats[&"stat_healing"] += _bonus(power, BLADES)
	return stats


func _check_stats(sheet: HeroWindow, hero: Hero, when: String) -> void:
	var expected: Dictionary[StringName, String] = _expected_stats(hero)
	for key: StringName in STAT_KEYS:
		var want: String = expected[key]
		assert_eq(sheet.line(key), want, "%s %s: %s" % [hero.class_id, when, key])


## The colour the Stats tab draws [param key]'s bonus in (spec 060 R4: beside the stat).
func _bonus_colour(sheet: HeroWindow, key: StringName) -> Color:
	return sheet.stats.reason_labels[key].get_theme_color(&"font_color")


func test_r4_what_they_can_do() -> void:
	assert_not_null(_windows(), "the HUD has hero windows")
	if _windows() == null:
		return
	var sheet: HeroWindow
	for hero: Hero in _sim.party.heroes:
		sheet = _open(hero.id)
		_hud.advance(0.016)
		_check_stats(sheet, hero, "before upgrades")
		assert_false(sheet.line(&"stat_damage").contains("+"), "no bonus before any upgrade")
	sheet = _open(_hero(0).id)
	assert_eq(sheet.line(&"stat_range"), "Range Melee", "the knight fights in melee")
	assert_eq(sheet.line(&"stat_healing"), "", "and does not heal")
	sheet = _open(_hero(2).id)
	assert_eq(sheet.line(&"stat_range"), "Range 7 tiles", "the mage casts from 7 tiles")
	assert_eq(sheet.line(&"stat_attack_speed"), "Attack speed 0.5/s", "every two seconds")
	assert_eq(sheet.line(&"stat_crit"), "Crit chance 10%")
	sheet = _open(_hero(3).id)
	assert_eq(sheet.line(&"stat_healing"), "Healing 22", "the cleric heals")

	_sim.party.gold = 100_000
	for i: int in 3:
		_sim.buy_upgrade(BLADES)
		_sim.buy_upgrade(ARMOR)
	_sim.step()
	assert_eq(_sim.upgrades.rank(BLADES), 3, "three ranks of sharp blades bought")
	_hud.advance(0.016)
	for hero: Hero in _sim.party.heroes:
		sheet = _open(hero.id)
		_hud.advance(0.016)
		_check_stats(sheet, hero, "after upgrades")
		assert_string_contains(sheet.line(&"stat_damage"), "+15% ", "the damage bonus")
		assert_string_contains(sheet.line(&"stat_health"), "+15% ", "the health bonus")
		assert_eq(_bonus_colour(sheet, &"stat_damage"), Palette.color(&"green"), "in green")
		assert_eq(_bonus_colour(sheet, &"stat_health"), Palette.color(&"green"))
		assert_false(sheet.line(&"stat_armor").contains("+"), "armor has no upgrade")
	sheet = _open(_hero(3).id)
	assert_string_contains(sheet.line(&"stat_healing"), "+15% ", "healing gains the bonus")
	assert_eq(_bonus_colour(sheet, &"stat_healing"), Palette.color(&"green"))


# --- R5 ------------------------------------------------------------------------


func _activity(hero: Hero) -> String:
	var sheet: HeroWindow = _open(hero.id)
	_hud.advance(0.016)
	return sheet.line(&"activity")


func test_r5_what_they_are_doing() -> void:
	assert_not_null(_windows(), "the HUD has hero windows")
	if _windows() == null:
		return
	for hero: Hero in _sim.party.heroes:
		assert_eq(_activity(hero), "Walking", "%s walks at first" % hero.class_id)

	assert_true(_step_until(Expedition.State.FIGHTING), "the party meets a fight")
	var battle: Battle = _sim.expedition.battle
	for hero: Hero in _sim.party.heroes:
		assert_eq(_activity(hero), "Fighting", "%s: no target yet" % hero.class_id)
	var knight: Hero = _hero(0)
	var cleric: Hero = _hero(3)
	var hurt: Combatant = battle.combatant(knight.id)
	hurt.health = hurt.max_health / 5
	_sim.step()
	var fighter: Combatant = battle.combatant(_hero(1).id)
	assert_gte(fighter.target_id, 0, "the rogue has a target")
	var target: Combatant = battle.combatant(fighter.target_id)
	var monster: String = Content.monster(target.def_id).display_name
	assert_eq(_activity(_hero(1)), "Fighting %s" % monster, "fighting a named monster")
	assert_eq(battle.combatant(cleric.id).target_id, knight.id, "the cleric aims at the knight")
	assert_eq(_activity(cleric), "Healing Knight", "a healer healing an ally")
	var sheet: HeroWindow = _windows().window_of(cleric.id)
	assert_ne(sheet.line_colour(&"activity"), Palette.color(&"red"), "not in red")

	var rogue: Combatant = battle.combatant(_hero(1).id)
	rogue.health = 0
	rogue.state = Combatant.State.DEAD
	assert_eq(_activity(_hero(1)), "Down", "a hero fallen in the fight is down")
	sheet = _windows().window_of(_hero(1).id)
	assert_eq(sheet.line_colour(&"activity"), Palette.color(&"red"), "in red")

	_sim.expedition.battle = null
	_sim.expedition.state = Expedition.State.RESTING
	assert_eq(_activity(knight), "Resting")
	_sim.expedition.state = Expedition.State.CLIMBING
	assert_eq(_activity(knight), "Moving on")  # spec 054 R6: never "Climbing"
	_sim.expedition.state = Expedition.State.TRAVELLING
	knight.health = 0
	assert_eq(_activity(knight), "Down", "a dead hero is down")
	sheet = _windows().window_of(knight.id)
	assert_eq(sheet.line_colour(&"activity"), Palette.color(&"red"), "in red")
	assert_eq(_activity(cleric), "Walking", "while the others walk")
	_sim.expedition.state = Expedition.State.REVIVING
	assert_eq(_activity(knight), "Recovering", "during a revival")
	assert_eq(_activity(cleric), "Recovering")


# --- R6 ------------------------------------------------------------------------


func test_r6_follows_the_simulation() -> void:
	assert_not_null(_windows(), "the HUD has hero windows")
	if _windows() == null:
		return
	var hero: Hero = _hero(0)
	var sheet: HeroWindow = _open(hero.id)
	_hud.advance(0.016)
	assert_eq(sheet.line(&"level"), "Level 1")
	var damage: String = sheet.line(&"stat_damage")
	hero.gain_xp(Hero.xp_for_level(3))
	_hud.advance(0.016)
	assert_eq(sheet.line(&"level"), "Level 3", "a level up shows without reopening")
	assert_eq(sheet.line(&"health"), "%d / %d" % [hero.health, hero.max_health()])
	assert_eq(sheet.line(&"stat_health"), "Health %d" % hero.max_health())
	assert_ne(sheet.line(&"stat_damage"), damage, "and the damage it brings")
	assert_eq(sheet.line(&"xp"), _expected_xp(hero))

	_sim.party.gold = 100_000
	_sim.buy_upgrade(BLADES)
	_sim.step()
	_hud.advance(0.016)
	assert_eq(
		sheet.line(&"stat_damage"),
		"Damage %d +5%% Sharp Blades" % hero.combatant().damage,
		"an upgrade shows without reopening"
	)

	hero.gain_xp(Hero.xp_for_level(6))
	_hero(3).gain_xp(Hero.xp_for_level(2))
	var data: Dictionary = _sim.to_save()
	var loaded: Simulation = Simulation.from_save(data)
	assert_not_null(loaded, "the save loads")
	if loaded == null:
		return
	var loaded_hud: Hud = _make_hud(loaded)
	var loaded_sheet: HeroWindow
	for saved: Hero in loaded.party.heroes:
		loaded_sheet = _open(saved.id, loaded_hud)
		loaded_hud.advance(0.016)
		assert_eq(loaded_sheet.line(&"level"), "Level %d" % saved.level, "the saved level")
		assert_eq(loaded_sheet.line(&"xp"), _expected_xp(saved), "the saved XP")
	loaded_sheet = _open(loaded.party.heroes[0].id, loaded_hud)
	assert_eq(loaded_sheet.line(&"level"), "Level %d" % hero.level, "the knight's levels kept")
	assert_eq(
		loaded_sheet.line(&"stat_damage"),
		"Damage %d +5%% Sharp Blades" % loaded.party.heroes[0].combatant().damage,
		"and the upgrade"
	)


# --- R7 ------------------------------------------------------------------------


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func test_r7_it_fits() -> void:
	var windows: HeroWindows = _windows()
	assert_not_null(windows, "the HUD has hero windows")
	if windows == null:
		return
	_sim.party.gold = 1_000_000
	for i: int in 20:
		_sim.buy_upgrade(BLADES)
		_sim.buy_upgrade(ARMOR)
	_sim.step()
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(99))
	# Spec 060: the windows are on the UI layer, measured in its pixels.
	var top_band: float = _ui.world_to_ui(Vector2(0, Hud.TOP_BAND)).y
	var frames_top: float = _ui.world_to_ui(Vector2(0, _ui.frames_top())).y
	var room := Vector2(_ui.room())
	for hero: Hero in _sim.party.heroes:
		var sheet: HeroWindow = _open(hero.id)
		_hud.advance(0.5)
		var rect: Rect2 = sheet.get_global_rect()
		var what: String = "%s %s" % [hero.class_id, rect]
		assert_gte(rect.position.y, top_band, "%s: below the top band" % what)
		assert_lte(rect.end.y, frames_top, "%s: above the frames" % what)
		assert_gte(rect.position.x, 0.0, "%s: on screen" % what)
		assert_lte(rect.end.x, room.x, "%s: on screen" % what)
		var labels: Array[Label] = []
		_collect_labels(sheet, labels)
		var shown: Array[Label] = []
		for label: Label in labels:
			if label.is_visible_in_tree() and not label.text.is_empty():
				shown.append(label)
		assert_gt(shown.size(), 12, "%s: the window's text" % what)
		for label: Label in shown:
			var where: String = "%s %s %s" % [hero.class_id, label.text, label.get_global_rect()]
			assert_true(rect.encloses(label.get_global_rect()), "%s inside the window" % where)
			for other: Label in shown:
				if other != label and other.get_global_rect().intersects(label.get_global_rect()):
					fail_test("%s overlaps %s" % [where, other.text])
		assert_true(rect.encloses(sheet.close_button.get_global_rect()), "the close button")
		sheet.close()


# --- R8 ------------------------------------------------------------------------


func test_r8_keys() -> void:
	var main: Main = make_main()
	add_child_autofree(main)
	var hud: Hud = main.hud
	assert_not_null(hud.hero_windows, "the HUD has hero windows")
	if hud.hero_windows == null:
		return
	var hero_id: int = main.simulation.party.heroes[1].id
	hud.hero_windows.open(hero_id)
	var sheet: HeroWindow = hud.hero_windows.window_of(hero_id)

	var target: int = main.simulation.expedition.target_depth
	press(KEY_EQUAL)
	assert_eq(hud.place_panel.target_label.text, str(target + 1), "= raises the target")
	press(KEY_MINUS)
	assert_eq(hud.place_panel.target_label.text, str(target), "- lowers it")
	assert_true(sheet.is_open(), "the window stays open")

	var auto: bool = main.simulation.expedition.auto_push
	press(KEY_A)
	assert_ne(main.simulation.expedition.auto_push, auto, "A switches auto-push")
	press(KEY_A)
	assert_eq(main.simulation.expedition.auto_push, auto, "and back")

	var zoom: int = main.world.camera.zoom_level()
	press(KEY_Z)
	assert_ne(main.world.camera.zoom_level(), zoom, "Z zooms")
	press(KEY_Z)

	var muted: bool = main.sound.is_muted()
	press(KEY_M)
	assert_ne(main.sound.is_muted(), muted, "M mutes")
	press(KEY_M)
	assert_eq(main.sound.is_muted(), muted, "and unmutes")
	assert_true(sheet.is_open(), "the window is still open")
	assert_eq(hud.hero_windows.front(), sheet, "the same hero's")

	press(KEY_U)
	assert_true(hud.shop.is_open(), "U opens the shop")
	assert_true(sheet.is_open(), "and the hero's window stays open beside it")

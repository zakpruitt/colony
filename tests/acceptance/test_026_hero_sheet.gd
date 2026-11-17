extends GutTest
## Acceptance tests for specs/026-hero-sheet/spec.md, one per requirement.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 26
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
## Pixels kept clear just above the party frames (spec 027 puts a one-line ticker there).
const TICKER_STRIP: float = 12.0
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


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_hud = _make_hud(_sim)


func after_each() -> void:
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
	made.advance(0.0)
	return made


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## A left click on [param frame], delivered as the GUI delivers one.
func _click(frame: HeroFrame) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = frame.size / 2.0
		frame._gui_input(event)


func _sheet() -> HeroSheet:
	return _hud.hero_sheet


func _hero(index: int) -> Hero:
	return _sim.party.heroes[index]


## Steps until the expedition is in [param wanted], at most [param limit] ticks.
func _step_until(wanted: Expedition.State, limit: int = 20000) -> bool:
	for i: int in limit:
		if _sim.expedition.state == wanted:
			return true
		_sim.step()
	return _sim.expedition.state == wanted


func _marked_ids() -> Array[int]:
	var marked: Array[int] = []
	for frame: HeroFrame in _hud.frames:
		if frame.marked:
			marked.append(frame.hero_id)
	return marked


static func _percent(multiplier: float) -> String:
	return " (+%d%%)" % roundi((multiplier - 1.0) * 100.0)


# --- R1 ------------------------------------------------------------------------


func test_r1_opening_and_closing() -> void:
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	assert_false(sheet.is_open(), "closed at first")
	assert_false(sheet.is_visible_in_tree(), "and not shown")
	assert_eq(sheet.shown_hero_id(), -1, "showing nobody")
	assert_eq(_marked_ids(), [] as Array[int], "no frame is marked")

	var first: HeroFrame = _hud.frames[0]
	var second: HeroFrame = _hud.frames[1]
	_click(first)
	assert_true(sheet.is_open(), "clicking a frame opens the sheet")
	assert_true(sheet.is_visible_in_tree(), "and it shows")
	assert_eq(sheet.shown_hero_id(), first.hero_id, "on that hero")
	assert_eq(_marked_ids(), [first.hero_id] as Array[int], "that frame is marked")
	var plain: HeroFrame = _hud.frames[2]
	assert_ne(first.border, plain.border, "visibly: its edge differs from an unmarked frame's")
	_click(first)
	assert_false(sheet.is_open(), "clicking the same frame closes it")
	assert_eq(_marked_ids(), [] as Array[int], "and unmarks it")

	_click(first)
	_click(second)
	assert_true(sheet.is_open(), "clicking another frame keeps it open")
	assert_eq(sheet.shown_hero_id(), second.hero_id, "and switches to that hero")
	assert_eq(_marked_ids(), [second.hero_id] as Array[int], "the mark moves")
	_key(KEY_ESCAPE)
	assert_false(sheet.is_open(), "Esc closes it")
	_key(KEY_ESCAPE)
	assert_false(sheet.is_open(), "and does not open it")

	_click(second)
	assert_not_null(sheet.close_button, "the sheet has a close button")
	if sheet.close_button != null:
		assert_true(sheet.close_button.is_visible_in_tree(), "shown on the sheet")
		sheet.close_button.pressed.emit()
		assert_false(sheet.is_open(), "the close button closes it")
		assert_eq(_marked_ids(), [] as Array[int], "and unmarks the frame")

	for i: int in _sim.party.heroes.size():
		_key(KEY_TAB)
		assert_true(sheet.is_open(), "Tab opens or keeps the sheet open")
		assert_eq(sheet.shown_hero_id(), _hero(i).id, "Tab %d shows hero %d" % [i + 1, i + 1])
		assert_eq(_marked_ids(), [_hero(i).id] as Array[int], "and marks its frame")
	_key(KEY_TAB)
	assert_eq(sheet.shown_hero_id(), _hero(0).id, "Tab after the last hero wraps to the first")

	_key(KEY_U)
	assert_true(_hud.shop.is_open(), "U opens the shop")
	assert_false(sheet.is_open(), "which closes the sheet")
	assert_eq(_marked_ids(), [] as Array[int], "and unmarks the frame")
	_click(first)
	assert_true(sheet.is_open(), "opening the sheet")
	assert_false(_hud.shop.is_open(), "closes the shop")
	_hud.shop_button.pressed.emit()
	assert_true(_hud.shop.is_open(), "the Shop button")
	assert_false(sheet.is_open(), "closes the sheet too")
	_key(KEY_TAB)
	assert_true(sheet.is_open(), "Tab")
	assert_false(_hud.shop.is_open(), "closes the shop")

	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.hud.hero_sheet.open(main.simulation.party.heroes[0].id)
	main.driver.advance(1_000_000)
	var tick: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(main.hud.hero_sheet.is_open(), "the sheet is open")
	assert_gt(main.simulation.tick, tick, "and the game runs behind it")
	assert_false(get_tree().paused, "unpaused")


# --- R2 ------------------------------------------------------------------------


func test_r2_who_they_are() -> void:
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	assert_eq(_sim.party.heroes.size(), 4, "four heroes")
	_hero(2).gain_xp(Hero.xp_for_level(4))
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _hero(i)
		sheet.open(hero.id)
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
	sheet.open(_hero(2).id)
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
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	var hero: Hero = _hero(1)
	sheet.open(hero.id)
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
		stats[&"stat_health"] += _percent(health_bonus)
	if power > 1.0:
		stats[&"stat_damage"] += _percent(power)
	stats[&"stat_armor"] = "Armor %d" % fighter.armor
	stats[&"stat_attack_speed"] = "Attack speed %.1f/s" % (1.0 / def.attack_interval)
	stats[&"stat_crit"] = "Crit chance %d%%" % roundi(def.crit_chance * 100.0)
	var reach: String = "Melee"
	if def.attack_range > Battle.MELEE_REACH:
		reach = "%s tiles" % HeroSheet.tiles(def.attack_range)
	stats[&"stat_range"] = "Range %s" % reach
	stats[&"stat_healing"] = ""
	if def.heal_power > 0:
		stats[&"stat_healing"] = "Healing %d" % fighter.heal_power
		if power > 1.0:
			stats[&"stat_healing"] += _percent(power)
	return stats


func _check_stats(sheet: HeroSheet, hero: Hero, when: String) -> void:
	var expected: Dictionary[StringName, String] = _expected_stats(hero)
	for key: StringName in STAT_KEYS:
		var want: String = expected[key]
		assert_eq(sheet.line(key), want, "%s %s: %s" % [hero.class_id, when, key])


func test_r4_what_they_can_do() -> void:
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		_hud.advance(0.016)
		_check_stats(sheet, hero, "before upgrades")
		assert_false(sheet.line(&"stat_damage").contains("+"), "no bonus before any upgrade")
	sheet.open(_hero(0).id)
	assert_eq(sheet.line(&"stat_range"), "Range Melee", "the knight fights in melee")
	assert_eq(sheet.line(&"stat_healing"), "", "and does not heal")
	sheet.open(_hero(2).id)
	assert_eq(sheet.line(&"stat_range"), "Range 7 tiles", "the mage casts from 7 tiles")
	assert_eq(sheet.line(&"stat_attack_speed"), "Attack speed 0.5/s", "every two seconds")
	assert_eq(sheet.line(&"stat_crit"), "Crit chance 10%")
	sheet.open(_hero(3).id)
	assert_eq(sheet.line(&"stat_healing"), "Healing 22", "the cleric heals")

	_sim.party.gold = 100_000
	for i: int in 3:
		_sim.buy_upgrade(BLADES)
		_sim.buy_upgrade(ARMOR)
	_sim.step()
	assert_eq(_sim.upgrades.rank(BLADES), 3, "three ranks of sharp blades bought")
	_hud.advance(0.016)
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		_hud.advance(0.016)
		_check_stats(sheet, hero, "after upgrades")
		assert_string_contains(sheet.line(&"stat_damage"), "(+15%)", "the damage bonus")
		assert_string_contains(sheet.line(&"stat_health"), "(+15%)", "the health bonus")
		assert_eq(sheet.bonus_colour(&"stat_damage"), Palette.color(&"green"), "in green")
		assert_eq(sheet.bonus_colour(&"stat_health"), Palette.color(&"green"))
		assert_false(sheet.line(&"stat_armor").contains("+"), "armor has no upgrade")
	sheet.open(_hero(3).id)
	assert_string_contains(sheet.line(&"stat_healing"), "(+15%)", "healing gains the bonus")
	assert_eq(sheet.bonus_colour(&"stat_healing"), Palette.color(&"green"))


# --- R5 ------------------------------------------------------------------------


func _activity(hero: Hero) -> String:
	_sheet().open(hero.id)
	_hud.advance(0.016)
	return _sheet().line(&"activity")


func test_r5_what_they_are_doing() -> void:
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
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
	assert_ne(sheet.line_colour(&"activity"), Palette.color(&"red"), "not in red")

	var rogue: Combatant = battle.combatant(_hero(1).id)
	rogue.health = 0
	rogue.state = Combatant.State.DEAD
	assert_eq(_activity(_hero(1)), "Down", "a hero fallen in the fight is down")
	assert_eq(sheet.line_colour(&"activity"), Palette.color(&"red"), "in red")

	_sim.expedition.battle = null
	_sim.expedition.state = Expedition.State.RESTING
	assert_eq(_activity(knight), "Resting")
	_sim.expedition.state = Expedition.State.CLIMBING
	assert_eq(_activity(knight), "Moving on")  # spec 054 R6: never "Climbing"
	_sim.expedition.state = Expedition.State.TRAVELLING
	knight.health = 0
	assert_eq(_activity(knight), "Down", "a dead hero is down")
	assert_eq(sheet.line_colour(&"activity"), Palette.color(&"red"), "in red")
	assert_eq(_activity(cleric), "Walking", "while the others walk")
	_sim.expedition.state = Expedition.State.REVIVING
	assert_eq(_activity(knight), "Recovering", "during a revival")
	assert_eq(_activity(cleric), "Recovering")


# --- R6 ------------------------------------------------------------------------


func test_r6_follows_the_simulation() -> void:
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	var hero: Hero = _hero(0)
	sheet.open(hero.id)
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
		"Damage %d (+5%%)" % hero.combatant().damage,
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
	var loaded_sheet: HeroSheet = loaded_hud.hero_sheet
	for saved: Hero in loaded.party.heroes:
		loaded_sheet.open(saved.id)
		loaded_hud.advance(0.016)
		assert_eq(loaded_sheet.line(&"level"), "Level %d" % saved.level, "the saved level")
		assert_eq(loaded_sheet.line(&"xp"), _expected_xp(saved), "the saved XP")
	loaded_sheet.open(loaded.party.heroes[0].id)
	assert_eq(loaded_sheet.line(&"level"), "Level %d" % hero.level, "the knight's levels kept")
	assert_eq(
		loaded_sheet.line(&"stat_damage"),
		"Damage %d (+5%%)" % loaded.party.heroes[0].combatant().damage,
		"and the upgrade"
	)


# --- R7 ------------------------------------------------------------------------


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func test_r7_it_fits() -> void:
	var sheet: HeroSheet = _sheet()
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	_sim.party.gold = 1_000_000
	for i: int in 20:
		_sim.buy_upgrade(BLADES)
		_sim.buy_upgrade(ARMOR)
	_sim.step()
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(99))
	var frames_top: float = SCREEN.y
	for frame: HeroFrame in _hud.frames:
		frames_top = minf(frames_top, frame.get_global_rect().position.y)
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		_hud.advance(0.5)
		var rect: Rect2 = sheet.get_global_rect()
		var what: String = "%s %s" % [hero.class_id, rect]
		assert_gte(rect.position.y, TOP_BAND, "%s: below the top band" % what)
		assert_lte(rect.end.y, frames_top - TICKER_STRIP, "%s: above the frames" % what)
		assert_gte(rect.position.x, 0.0, "%s: on screen" % what)
		assert_lte(rect.end.x, SCREEN.x, "%s: on screen" % what)
		for frame: HeroFrame in _hud.frames:
			assert_false(rect.intersects(frame.get_global_rect()), "%s: off the frames" % what)
		var labels: Array[Label] = []
		_collect_labels(sheet, labels)
		var shown: Array[Label] = []
		for label: Label in labels:
			if label.is_visible_in_tree() and not label.text.is_empty():
				shown.append(label)
		assert_gt(shown.size(), 12, "%s: the sheet's text" % what)
		for label: Label in shown:
			var where: String = "%s %s %s" % [hero.class_id, label.text, label.get_global_rect()]
			assert_true(rect.encloses(label.get_global_rect()), "%s inside the sheet" % where)
			var font_size: int = label.get_theme_font_size(&"font_size")
			assert_eq(font_size % PixelText.SIZE, 0, "%s: the pixel font at a whole size" % where)
			for other: Label in shown:
				if other != label and other.get_global_rect().intersects(label.get_global_rect()):
					fail_test("%s overlaps %s" % [where, other.text])
		if sheet.close_button != null:
			assert_true(rect.encloses(sheet.close_button.get_global_rect()), "the close button")


# --- R8 ------------------------------------------------------------------------


func test_r8_keys() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var hud: Hud = main.hud
	var sheet: HeroSheet = hud.hero_sheet
	assert_not_null(sheet, "the HUD has a hero sheet")
	if sheet == null:
		return
	var hero_id: int = main.simulation.party.heroes[1].id
	sheet.open(hero_id)

	var target: int = main.simulation.expedition.target_depth
	_key(KEY_EQUAL)
	assert_eq(hud.target_label.text, str(target + 1), "= raises the target")
	_key(KEY_MINUS)
	assert_eq(hud.target_label.text, str(target), "- lowers it")
	assert_true(sheet.is_open(), "the sheet stays open")

	var auto: bool = main.simulation.expedition.auto_push
	_key(KEY_A)
	assert_ne(main.simulation.expedition.auto_push, auto, "A switches auto-push")
	_key(KEY_A)
	assert_eq(main.simulation.expedition.auto_push, auto, "and back")

	var zoom: int = main.world.camera.zoom_level()
	_key(KEY_Z)
	assert_ne(main.world.camera.zoom_level(), zoom, "Z zooms")
	_key(KEY_Z)

	var muted: bool = main.sound.is_muted()
	_key(KEY_M)
	assert_ne(main.sound.is_muted(), muted, "M mutes")
	_key(KEY_M)
	assert_eq(main.sound.is_muted(), muted, "and unmutes")
	assert_true(sheet.is_open(), "the sheet is still open")
	assert_eq(sheet.shown_hero_id(), hero_id, "on the same hero")

	_key(KEY_U)
	assert_true(hud.shop.is_open(), "U opens the shop")
	assert_false(sheet.is_open(), "and closes the sheet")

extends GutTest
## Acceptance tests for specs/011-hud/spec.md, one per requirement.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 11
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
const BOTTOM_BAND: float = 40.0
const KNIGHT: int = 1
const MAGE: int = 3

var _sim: Simulation
var _world: World
var _effects: CombatEffects
var _hud: Hud


func before_each() -> void:
	_sim = Simulation.new(SEED)
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
	_hud.advance(0.0)


## Emits [param event] as the world does, stamped with the current tick so it is recent.
func _emit(kind: SimEvent.Kind, target: int, amount: int = 0) -> void:
	_world.sim_event.emit(SimEvent.new(kind, _sim.tick, -1, target, amount))


func _set_health(hero: Hero, fraction: float) -> void:
	hero.health = roundi(hero.max_health() * fraction)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _steps(count: int) -> void:
	for i: int in count:
		_sim.step()


# --- R1 ------------------------------------------------------------------------


func test_r1_party_frames() -> void:
	var frames: Array[HeroFrame] = _hud.frames
	assert_eq(frames.size(), 4, "one frame per hero")
	if frames.size() != 4:
		return
	var names: Array[String] = ["Knight", "Rogue", "Mage", "Cleric"]
	for i: int in 4:
		var hero: Hero = _sim.party.heroes[i]
		var slot: HeroFrame = frames[i]
		assert_eq(slot.hero_id, hero.id, "frame %d is the hero in formation slot %d" % [i, i])
		assert_eq(slot.icon_part(), hero.class_id, "class icon")
		assert_not_null(slot.icon.texture, "the icon is drawn")
		assert_eq(slot.icon.size, Vector2(16, 16), "a 16x16 icon")
		assert_eq(slot.name_label.text, names[i], "class name")
		assert_string_contains(slot.level_label.text, "1", "level")
	if frames.size() > 1:
		assert_lt(frames[0].position.x, frames[1].position.x, "left to right in formation order")
	var left: float = frames[0].get_global_rect().position.x
	var right: float = SCREEN.x - frames[3].get_global_rect().end.x
	assert_almost_eq(left, right, 1.0, "the row of frames is centred")

	var knight: Hero = _sim.party.hero(KNIGHT)
	var frame: HeroFrame = frames[0]
	assert_almost_eq(frame.shown_health(), 1.0, 0.001, "full health")
	assert_eq(frame.health_color(), Palette.color(&"green"), "green at 100%")

	_set_health(knight, 0.4)
	_hud.advance(0.05)
	assert_lt(frame.shown_health(), 0.99, "the bar starts to empty at once")
	assert_gt(frame.shown_health(), 0.45, "but eases rather than jumps")
	_hud.advance(0.1)
	_hud.advance(0.2)
	assert_almost_eq(frame.shown_health(), 0.4, 0.001, "and arrives within about 0.3 s")
	assert_eq(frame.health_color(), Palette.color(&"yellow"), "yellow at 40%")

	_set_health(knight, 0.1)
	_hud.advance(0.4)
	assert_almost_eq(frame.shown_health(), 0.1, 0.001, "10%")
	assert_eq(frame.health_color(), Palette.color(&"red"), "red at 10%")

	var mage: Hero = _sim.party.hero(MAGE)
	mage.level = 3
	mage.xp = Hero.xp_for_level(3) + (Hero.xp_for_level(4) - Hero.xp_for_level(3)) / 4
	_hud.advance(0.5)
	assert_almost_eq(frames[2].shown_xp(), 0.25, 0.01, "XP bar is the progress to the next level")
	assert_string_contains(frames[2].level_label.text, "3", "level follows the hero")


# --- R2 ------------------------------------------------------------------------


func test_r2_frames_react() -> void:
	var frames: Array[HeroFrame] = _hud.frames
	if frames.size() != 4:
		fail_test("no frames")
		return
	var knight_frame: HeroFrame = frames[0]
	var rogue_frame: HeroFrame = frames[1]
	assert_eq(knight_frame.flash(), 0.0, "no flash at rest")
	_emit(SimEvent.Kind.HIT, KNIGHT, 5)
	_hud.advance(0.016)
	assert_gt(knight_frame.flash(), 0.0, "the hit hero's frame flashes")
	assert_eq(rogue_frame.flash(), 0.0, "the others do not")
	_hud.advance(0.5)
	assert_eq(knight_frame.flash(), 0.0, "only for an instant")

	var knight: Hero = _sim.party.hero(KNIGHT)
	knight.health = 0
	_hud.advance(0.016)
	assert_true(knight_frame.is_dimmed(), "a dead hero's frame is dimmed")
	assert_eq(knight_frame.icon_part(), &"skull", "and shows a skull")
	assert_eq(knight_frame.icon.texture, _hud.icon(&"skull"), "drawn as the skull")
	assert_false(rogue_frame.is_dimmed(), "the living are not")
	knight.health = knight.max_health()
	_hud.advance(0.016)
	assert_false(knight_frame.is_dimmed(), "normal again once alive")
	assert_eq(knight_frame.icon_part(), &"knight", "with its class icon back")

	var mage: Hero = _sim.party.hero(MAGE)
	var mage_frame: HeroFrame = frames[2]
	mage.xp = Hero.xp_for_level(2) - 1
	_hud.advance(1.0)
	assert_gt(mage_frame.shown_xp(), 0.9, "nearly a level of XP")
	assert_eq(mage_frame.level_pulse(), 0.0, "no pulse yet")
	mage.gain_xp(1 + (Hero.xp_for_level(3) - Hero.xp_for_level(2)) / 2)
	_emit(SimEvent.Kind.LEVEL_UP, MAGE, 2)
	_hud.advance(0.016)
	assert_gt(mage_frame.level_pulse(), 0.0, "the level number pulses")
	assert_lt(mage_frame.shown_xp(), 0.2, "the XP bar restarts from empty")
	assert_string_contains(mage_frame.level_label.text, "2", "showing the new level")
	_hud.advance(1.0)
	assert_almost_eq(mage_frame.shown_xp(), 0.5, 0.02, "then fills to the new progress")
	assert_eq(mage_frame.level_pulse(), 0.0, "and the pulse ends")


# --- R3 ------------------------------------------------------------------------


func test_r3_gold_follows_the_coins() -> void:
	assert_eq(_hud.shown_gold(), 0, "no gold yet")
	_sim.party.gold = 100
	_hud.advance(0.1)
	assert_eq(_hud.shown_gold(), 0, "real gold alone does not move the count")
	_effects.coin_collected.emit(10)
	assert_eq(_hud.shown_gold(), 10, "each coin adds its share")
	assert_gt(_hud.gold_bump(), 0.0, "and bumps the count")
	_hud.advance(1.0)
	_effects.coin_collected.emit(30)
	assert_eq(_hud.shown_gold(), 40, "share by share")
	_effects.coin_collected.emit(500)
	assert_eq(_hud.shown_gold(), 100, "never more than the party has")

	_sim.party.gold = 1_234_567
	_hud.advance(2.9)
	assert_eq(_hud.shown_gold(), 100, "behind until 3 s after the last coin")
	_hud.advance(0.2)
	assert_eq(_hud.shown_gold(), 1_234_567, "then catches up at once")
	# Spec 052: from 10,000 the top bar shortens the count so the resources fit beside it; below
	# that it keeps its thousands separators.
	assert_eq(_hud.gold_label.text, "1.2M", "shortened")
	_sim.party.gold = 9_876
	_hud.advance(0.016)
	assert_eq(_hud.gold_label.text, "9,876", "with thousands separators")

	_sim.party.gold = 50
	_hud.advance(0.016)
	assert_eq(_hud.shown_gold(), 50, "never shows more than the party has")
	assert_eq(_hud.gold_label.text, "50")

	var icon_centre: Vector2 = _hud.coin_icon.get_global_rect().get_center()
	assert_eq(_effects.gold_screen_target, icon_centre, "coins fly to the coin icon")
	assert_gt(icon_centre.x, SCREEN.x / 2.0, "top right")
	assert_lt(icon_centre.y, TOP_BAND, "top right")


# --- R4 ------------------------------------------------------------------------


func test_r4_depth_readout() -> void:
	assert_eq(_hud.depth_label.text, "1", "current depth")
	assert_string_contains(_hud.stable_label.text, "1", "last stable depth")
	assert_eq(_hud.target_label.text, "1", "target depth")
	assert_eq(_hud.depth_emphasis(), 0.0, "no emphasis at rest")
	var big: int = _hud.depth_label.get_theme_font_size(&"font_size")
	assert_gt(big, _hud.stable_label.get_theme_font_size(&"font_size"), "current is the biggest")
	assert_gt(big, _hud.target_label.get_theme_font_size(&"font_size"), "current is the biggest")
	for label: Label in [_hud.depth_caption, _hud.stable_label, _hud.target_caption]:
		assert_ne(label.text.strip_edges(), "", "each is labelled")

	_sim.expedition.depth = 4
	_sim.expedition.last_stable_depth = 3
	_sim.expedition.target_depth = 6
	_hud.advance(0.016)
	assert_eq(_hud.depth_label.text, "4", "current depth updates")
	assert_string_contains(_hud.stable_label.text, "3", "stable depth updates")
	assert_eq(_hud.target_label.text, "6", "target depth updates")
	assert_gt(_hud.depth_emphasis(), 0.0, "a change of depth is emphasised")
	_hud.advance(2.0)
	assert_eq(_hud.depth_emphasis(), 0.0, "briefly")


# --- R5 ------------------------------------------------------------------------


func test_r5_state_word() -> void:
	# Spec 027 R1 turned the one word into a short line; its own tests check each line.
	var states: Array[Expedition.State] = [
		Expedition.State.TRAVELLING,
		Expedition.State.FIGHTING,
		Expedition.State.RESTING,
		Expedition.State.CLIMBING,
		Expedition.State.REVIVING,
	]
	var shown: Dictionary[String, bool] = {}
	for state: Expedition.State in states:
		_sim.expedition.state = state
		_hud.advance(0.016)
		assert_eq(_hud.state_label.text, _hud.status_text(), "the line for state %d" % state)
		assert_ne(_hud.state_label.text, "", "something is shown")
		shown[_hud.state_label.text] = true
	assert_eq(shown.size(), states.size(), "each state reads differently")
	assert_lt(_hud.state_label.get_global_rect().position.x, SCREEN.x / 2.0, "next to the depth")


# --- R6 ------------------------------------------------------------------------


func test_r6_target_depth_control() -> void:
	var expedition: Expedition = _sim.expedition
	_sim.set_auto_push(false)
	_steps(1)
	assert_eq(expedition.target_depth, 1)

	_hud.plus_button.pressed.emit()
	_hud.plus_button.pressed.emit()
	_hud.advance(0.016)
	assert_eq(_hud.target_label.text, "3", "two presses before a tick count twice")
	_steps(1)
	_hud.advance(0.016)
	assert_eq(expedition.target_depth, 3, "+ raises the simulation's target")
	_hud.minus_button.pressed.emit()
	_steps(1)
	_hud.advance(0.016)
	assert_eq(expedition.target_depth, 2, "- lowers it")
	for i: int in 3:
		_hud.minus_button.pressed.emit()
		_steps(1)
		_hud.advance(0.016)
	assert_eq(expedition.target_depth, 1, "never below 1")
	assert_eq(_hud.target_label.text, "1")

	_key(KEY_EQUAL)
	_steps(1)
	_hud.advance(0.016)
	assert_eq(expedition.target_depth, 2, "= raises it")
	_key(KEY_MINUS)
	_steps(1)
	_hud.advance(0.016)
	assert_eq(expedition.target_depth, 1, "- lowers it")

	assert_false(expedition.auto_push)
	assert_false(_hud.auto_on(), "shown off")
	_hud.auto_button.pressed.emit()
	_hud.advance(0.016)
	assert_true(expedition.auto_push, "Auto turns auto-push on")
	assert_true(_hud.auto_on(), "shown on")
	var on_text: String = _hud.auto_button.text
	_key(KEY_A)
	_hud.advance(0.016)
	assert_false(expedition.auto_push, "A turns it off")
	assert_false(_hud.auto_on(), "shown off")
	assert_ne(_hud.auto_button.text, on_text, "on and off look different")

	expedition.target_depth = 7
	_hud.advance(0.016)
	assert_eq(_hud.target_label.text, "7", "the display follows the simulation")
	expedition.auto_push = true
	_hud.advance(0.016)
	assert_true(_hud.auto_on(), "and its auto-push")


# --- R7 ------------------------------------------------------------------------


func test_r7_dev_clock_hidden_until_f3() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var clock: Label = main.get_node("HUD/ClockLabel")
	assert_false(clock.is_visible_in_tree(), "hidden by default")
	main.hud.advance(0.016)
	_key(KEY_F3)
	assert_true(clock.is_visible_in_tree(), "F3 shows it")
	main.driver.advance(2_500_000)
	main.driver.advance(0)
	var tick: int = main.simulation.tick
	assert_gt(tick, 0)
	assert_string_contains(clock.text, str(tick), "the tick")
	assert_string_contains(clock.text, "%.1f" % main.simulation.seconds(), "and seconds")
	var rect: Rect2 = clock.get_global_rect()
	assert_gt(rect.position.x, SCREEN.x / 2.0, "bottom right")
	assert_gte(rect.position.y, SCREEN.y - BOTTOM_BAND, "bottom right")
	assert_lte(rect.end.x, SCREEN.x)
	assert_lte(rect.end.y, SCREEN.y)
	assert_ne(clock.get_theme_color(&"font_color"), Palette.color(&"white"), "in a dim colour")
	_key(KEY_F3)
	assert_false(clock.is_visible_in_tree(), "F3 hides it again")


# --- R8 ------------------------------------------------------------------------


func test_r8_stays_in_its_bands() -> void:
	_sim.party.gold = 9_876_543
	_sim.expedition.depth = 120
	_sim.expedition.target_depth = 123
	_sim.expedition.last_stable_depth = 119
	_effects.coin_collected.emit(9_876_543)
	_hud.advance(0.5)
	var controls: Array[Control] = []
	_collect(_hud, controls)
	assert_gt(controls.size(), 20, "the HUD has its controls")
	var labels: int = 0
	for control: Control in controls:
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		var what: String = "%s %s" % [control.name, rect]
		assert_true(_in_band(rect), "%s lies in the top 28 or bottom 40 pixels" % what)
		if control is Label:
			labels += 1
			assert_true(_backed(control as Label), "%s sits on a dark backing panel" % what)
	assert_gt(labels, 10, "every label was checked")
	for frame: HeroFrame in _hud.frames:
		assert_true(frame is HudPanel, "the bars are drawn on their frame's dark panel")


func _collect(node: Node, into: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is DepthLadder:
			continue  # spec 033's ladder sits below the top band; test_033 R6 places it
		if child is Goals:
			continue  # spec 037's goals sit under the depth panel; test_037 R6 places them
		if child is Control:
			into.append(child)
		_collect(child, into)


func _in_band(rect: Rect2) -> bool:
	if rect.position.x < 0.0 or rect.end.x > SCREEN.x:
		return false
	var top: bool = rect.position.y >= 0.0 and rect.end.y <= TOP_BAND
	var bottom: bool = rect.position.y >= SCREEN.y - BOTTOM_BAND and rect.end.y <= SCREEN.y
	return top or bottom


func _backed(label: Label) -> bool:
	var rect: Rect2 = label.get_global_rect()
	var node: Node = label.get_parent()
	while node != null:
		if node is HudPanel and (node as HudPanel).get_global_rect().encloses(rect):
			return true
		node = node.get_parent()
	return false

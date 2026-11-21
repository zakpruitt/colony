extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/011-hud/spec.md, one per requirement.

const SEED: int = 11
const BOTTOM_BAND: float = 40.0
const KNIGHT: int = 1
const MAGE: int = 3

var _effects: CombatEffects


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud(false)
	_effects = _fx
	_hud.advance(0.0)


## Emits [param event] as the world does, stamped with the current tick so it is recent.
func _emit(kind: SimEvent.Kind, target: int, amount: int = 0) -> void:
	_world.sim_event.emit(SimEvent.new(kind, _sim.tick, -1, target, amount))


func _set_health(hero: Hero, fraction: float) -> void:
	hero.health = roundi(hero.max_health() * fraction)


func _steps(count: int) -> void:
	for i: int in count:
		_sim.step()


# --- R1 ------------------------------------------------------------------------


func test_r1_party_frames() -> void:
	var frames: Array[HeroFrameView] = _hud.frames
	for slot: HeroFrameView in frames:
		assert_eq(slot.icon.size, Vector2(16, 16), "a 16x16 icon")

	var knight: Hero = _sim.party.hero(KNIGHT)
	var frame: HeroFrameView = frames[0]
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
	var frames: Array[HeroFrameView] = _hud.frames
	if frames.size() != 4:
		fail_test("no frames")
		return
	var rogue_frame: HeroFrameView = frames[1]
	_emit(SimEvent.Kind.HIT, KNIGHT, 5)
	_hud.advance(0.016)
	assert_eq(rogue_frame.flash(), 0.0, "the others do not")

	var mage: Hero = _sim.party.hero(MAGE)
	var mage_frame: HeroFrameView = frames[2]
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
	_sim.party.gold = 100
	_hud.advance(0.1)
	_effects.coin_collected.emit(10)
	assert_gt(_hud.gold_bump(), 0.0, "and bumps the count")
	_hud.advance(1.0)
	_effects.coin_collected.emit(30)
	_effects.coin_collected.emit(500)
	assert_eq(_hud.shown_gold(), 100, "never more than the party has")

	_sim.party.gold = 1_234_567
	_hud.advance(2.9)
	assert_eq(_hud.shown_gold(), 100, "behind until 3 s after the last coin")
	_hud.advance(0.2)
	assert_eq(_hud.shown_gold(), 1_234_567, "then catches up at once")
	# Spec 052: from 10,000 the top bar shortens the count so the resources fit beside it; below
	# that it keeps its thousands separators.
	assert_eq(_hud.purse.gold_label.text, "1.2M", "shortened")

	_sim.party.gold = 50
	_hud.advance(0.016)
	assert_eq(_hud.shown_gold(), 50, "never shows more than the party has")
	assert_eq(_hud.purse.gold_label.text, "50")


# --- R4 ------------------------------------------------------------------------


func test_r4_depth_readout() -> void:
	assert_eq(_hud.depth_emphasis(), 0.0, "no emphasis at rest")
	assert_gt(
		_hud.place_panel.stage_label.get_theme_font_size(&"font_size"),
		_hud.place_panel.target_label.get_theme_font_size(&"font_size"),
		"current is the biggest"
	)
	assert_ne(_hud.place_panel.target_caption.text.strip_edges(), "", "each is labelled")
	_sim.expedition.depth = 4
	_sim.expedition.last_stable_depth = 3
	_sim.expedition.target_depth = 6
	_hud.advance(0.016)
	assert_eq(_hud.place_panel.safe_label.text, "Safe 3", "the stage the party falls back to")
	assert_gt(_hud.depth_emphasis(), 0.0, "a change of depth is emphasised")
	_hud.advance(2.0)
	assert_eq(_hud.depth_emphasis(), 0.0, "briefly")


# --- R6 ------------------------------------------------------------------------


func test_r6_target_depth_control() -> void:
	var expedition: Expedition = _sim.expedition
	_sim.set_auto_push(false)
	_steps(1)
	assert_eq(expedition.target_depth, 1)

	_hud.place_panel.plus_button.pressed.emit()
	_hud.place_panel.plus_button.pressed.emit()
	_hud.advance(0.016)
	assert_eq(_hud.place_panel.target_label.text, "3", "two presses before a tick count twice")
	_steps(1)
	_hud.advance(0.016)
	for i: int in 3:
		_hud.place_panel.minus_button.pressed.emit()
		_steps(1)
		_hud.advance(0.016)
	assert_eq(expedition.target_depth, 1, "never below 1")
	assert_eq(_hud.place_panel.target_label.text, "1")

	_hud.place_panel.auto_button.pressed.emit()
	_hud.advance(0.016)
	var on_text: String = _hud.place_panel.auto_button.text
	press(KEY_A)
	_hud.advance(0.016)
	assert_false(expedition.auto_push, "A turns it off")
	assert_false(_hud.auto_on(), "shown off")
	assert_ne(_hud.place_panel.auto_button.text, on_text, "on and off look different")

	expedition.target_depth = 7
	_hud.advance(0.016)
	assert_eq(_hud.place_panel.target_label.text, "7", "the display follows the simulation")
	expedition.auto_push = true
	_hud.advance(0.016)
	assert_true(_hud.auto_on(), "and its auto-push")


# --- R7 ------------------------------------------------------------------------


func test_r7_dev_clock_hidden_until_f3() -> void:
	var main: Main = make_main()
	add_child_autofree(main)
	var clock: Label = main.get_node("HUD/ClockLabel")
	assert_false(clock.is_visible_in_tree(), "hidden by default")
	main.hud.advance(0.016)
	press(KEY_F3)
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
	press(KEY_F3)
	assert_false(clock.is_visible_in_tree(), "F3 hides it again")


# --- R8 ------------------------------------------------------------------------


func test_r8_frames_are_drawn_on_a_dark_panel() -> void:
	assert_eq(_hud.frames.size(), 4, "a frame per hero")
	for frame: HeroFrameView in _hud.frames:
		assert_eq(
			frame.fill_colour(),
			Palette.color(&"night"),
			"the bars are drawn on their frame's dark panel"
		)

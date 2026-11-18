extends "res://tests/acceptance/frame_061_test.gd"
## Acceptance tests for specs/061-the-frame-of-the-screen/spec.md, one per requirement: the place
## panel, the countdown, the purse, the hero frames, the boss bar and their tooltips on the sharp
## layer, driven by real clicks and keys at both rooms.

## Every tooltip sentence the old pieces had (spec 030 R4, spec 053 R8), by the piece's control.
const OLD_TIPS: Dictionary[String, String] = {
	"stage": "The stage the party is on now.",
	"status": "What the party is doing right now, and why.",
	"safe": "The last safe stage: a wipe sends the party back there.",
	"target": "The stage the party is heading for.",
	"minus": "Set the target one stage back.",
	"plus": "Set the target one stage further.",
	"auto": "When on, the party goes a stage further each time it holds its target long enough.",
	"speed": "How fast the game runs: click (or press F) for 1x, 2x or 4x.",
	"gold": "Gold from fights, to spend in the Shop.",
	"area": "The area the party is in: click (or press W) for the map of every area.",
}

# --- R1 ------------------------------------------------------------------------


func test_r1_the_place_panel() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var panel: PlacePanel = hud.place_panel
		var what: String = "%s" % room
		assert_true(main.ui.is_ancestor_of(panel), "%s: on the sharp layer" % what)
		var rect: Rect2 = panel.get_global_rect()
		assert_lt(rect.position.x, 16.0, "%s: at the left" % what)
		assert_lt(rect.position.y, 8.0, "%s: at the top" % what)
		sim.expedition.depth = 3
		sim.expedition.last_stable_depth = 3
		sim.expedition.target_depth = 3
		hud.advance(STEP)
		assert_eq(panel.area_button.text, PlaceText.area_name(sim.expedition.place), "the area")
		assert_eq(panel.stage_label.text, "3", "the stage")
		assert_gt(
			panel.stage_label.get_theme_font_size(&"font_size"),
			panel.safe_label.get_theme_font_size(&"font_size"),
			"the stage in large digits"
		)
		assert_eq(panel.safe_label.text, "Safe 3")
		assert_eq(panel.target_label.text, "3", "the target")
		assert_eq(panel.status_label.text, hud.status_text(), "what the party is doing and why")
		for button: UiButton in [
			panel.area_button, panel.minus_button, panel.plus_button, panel.auto_button
		]:
			assert_gte(button.get_global_rect().size.y, 20.0, "%s: %s tall enough" % [what, button])
			assert_true(rect.encloses(button.get_global_rect()), "%s: %s inside" % [what, button])
		# Real clicks on the buttons.
		_click(main, panel.plus_button)
		sim.step()
		hud.advance(STEP)
		assert_eq(sim.expedition.target_depth, 4, "%s: + raises the target" % what)
		assert_eq(panel.target_label.text, "4")
		_click(main, panel.minus_button)
		_click(main, panel.minus_button)
		sim.step()
		hud.advance(STEP)
		assert_eq(sim.expedition.target_depth, 2, "%s: - lowers it" % what)
		var auto: bool = sim.expedition.auto_push
		_click(main, panel.auto_button)
		sim.step()
		hud.advance(STEP)
		assert_ne(sim.expedition.auto_push, auto, "%s: the Auto switch" % what)
		assert_eq(panel.auto_button.lit, sim.expedition.auto_push, "lit while on")
		# The area's name opens the map, and marks a newly opened area until it is opened.
		assert_false(hud.area_map.is_open(), "the map is closed")
		_click(main, panel.area_button)
		assert_true(hud.area_map.is_open(), "%s: a click on the area's name opens the map" % what)
		hud.area_map.close()
		hud.advance(STEP)
		assert_false(panel.area_mark.visible, "no mark with nothing new")
		var opened: StringName = Content.area_ids()[1]
		sim.expedition.travel.open[opened] = true
		_emit(main, SimEvent.Kind.AREA_OPENED, -1, Content.area_ids().find(opened), 0)
		hud.advance(STEP)
		assert_true(panel.area_mark.is_visible_in_tree(), "%s: a new area is marked" % what)
		assert_eq(panel.area_mark.count, 1, "counting it")
		assert_true(
			rect.encloses(panel.area_mark.get_global_rect()), "%s: the mark inside the panel" % what
		)
		_click(main, panel.area_button)
		hud.advance(STEP)
		assert_false(panel.area_mark.visible, "%s: gone once the map is opened" % what)
		hud.area_map.close()
		main.free()


# --- R2 ------------------------------------------------------------------------


func test_r2_the_countdown() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var e: Expedition = main.simulation.expedition
		var countdown: Countdown = hud.countdown
		var what: String = "%s" % room
		assert_true(main.ui.is_ancestor_of(countdown), "%s: on the sharp layer" % what)
		e.stable_seconds = 600.0
		e.depth = 2
		e.target_depth = 2
		e.last_stable_depth = 1
		main.simulation.set_auto_push(false)
		main.simulation.step()
		hud.advance(STEP)
		var place: Rect2 = hud.place_panel.get_global_rect()
		var rect: Rect2 = countdown.get_global_rect()
		assert_gte(rect.position.x, place.end.x, "%s: beside the place panel" % what)
		assert_lt(rect.position.x - place.end.x, 16.0, "%s: right beside it" % what)
		assert_eq(rect.position.y, place.position.y, "%s: level with it" % what)
		assert_string_starts_with(countdown.note_label.text, "Stable in ", "counting to stable")
		assert_eq(countdown.note_label.text, "Stable in " + Hud.clock(e.seconds_to_stable()))
		assert_true(countdown.bar.is_visible_in_tree(), "over its bar")
		assert_almost_eq(countdown.progress(), hud.stable_progress(), 0.001, "filled as far")
		var bar: Rect2 = countdown.bar.get_global_rect()
		assert_gt(bar.position.y, countdown.note_label.get_global_rect().position.y, "under it")
		# Stable, staying on the stage.
		e.last_stable_depth = 2
		hud.advance(STEP)
		assert_eq(countdown.note_label.text, "Stable")
		assert_eq(countdown.next_label.text, "staying on stage 2")
		assert_false(countdown.bar.is_visible_in_tree(), "no bar")
		# Further in, with what comes next.
		main.simulation.set_auto_push(true)
		main.simulation.step()
		hud.advance(STEP)
		assert_string_starts_with(countdown.note_label.text, "Further in ", "counting to a push")
		assert_eq(countdown.next_label.text, "then stage 3", "what comes next")
		assert_true(countdown.bar.is_visible_in_tree(), "with its bar")
		assert_eq(
			"%s, %s" % [countdown.note_label.text, countdown.next_label.text],
			hud.stable_text(),
			"exactly the HUD's road to stable"
		)
		# Holding.
		main.simulation.set_guardian_order(Expedition.GuardianOrder.HOLD)
		_before_guardian(main, Expedition.GUARDIAN_EVERY)
		main.simulation.step()
		hud.advance(STEP)
		if e.is_holding():
			assert_eq(countdown.note_label.text, "Holding")
			assert_eq(countdown.next_label.text, "Orders (O) to go in")
		else:
			fail_test("the party should hold at the guardian")
		main.free()


# --- R3 ------------------------------------------------------------------------


func test_r3_the_purse() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var purse: Purse = hud.purse
		var what: String = "%s" % room
		assert_true(main.ui.is_ancestor_of(purse), "%s: on the sharp layer" % what)
		var rect: Rect2 = purse.get_global_rect()
		assert_gt(rect.end.x, room.x - 16.0, "%s: at the right" % what)
		assert_lt(rect.position.y, 8.0, "%s: at the top" % what)
		assert_not_null(purse.coin_icon.texture, "the coin")
		assert_true(
			(
				purse.coin_icon.get_global_rect().end.x
				<= purse.gold_label.position.x + rect.position.x + 1.0
			),
			"the coin before the gold"
		)
		# Counting up as coins land.
		sim.party.gold = 12_345
		hud.advance(STEP)
		assert_eq(purse.gold_label.text, "0", "real gold alone does not move the count")
		main.effects.coin_collected.emit(9_000)
		hud.advance(STEP)
		assert_eq(purse.gold_label.text, "9,000", "a coin lands")
		main.effects.coin_collected.emit(5_000)
		hud.advance(STEP)
		assert_eq(purse.gold_label.text, "12.3k", "shortened from 10,000")
		# Each resource held, in order, with its icon and count, counting up as icons land.
		var ids: Array[StringName] = Content.resource_ids()
		sim.party.set_resource(ids[2], 40)
		sim.party.set_resource(ids[0], 123_456)
		hud.advance(STEP)
		assert_eq(purse.shown_ids(), [ids[0], ids[2]] as Array[StringName], "those held, in order")
		main.effects.resource_effects.resource_collected.emit(0, 123_456)
		main.effects.resource_effects.resource_collected.emit(2, 15)
		hud.advance(STEP)
		assert_eq(purse.labels[ids[0]].text, "123k", "shortened")
		assert_eq(purse.labels[ids[2]].text, "15", "counting up as the icons land")
		hud.advance(Purse.CATCH_UP_SECONDS + 0.1)
		assert_eq(purse.labels[ids[2]].text, "40", "then catching up")
		var first: Rect2 = purse.icons[ids[0]].get_global_rect()
		var second: Rect2 = purse.icons[ids[2]].get_global_rect()
		assert_gt(second.position.x, first.position.x, "in order")
		assert_gt(first.position.x, purse.gold_label.get_global_rect().position.x, "after the gold")
		for label: Label in [purse.gold_label, purse.labels[ids[0]], purse.labels[ids[2]]]:
			assert_eq(label.get_theme_font(&"font"), UiText.font(true), "in the UI font's digits")
		assert_eq(UiText.width("1111", true), UiText.width("8888", true), "which are equal-width")
		# The game-speed button sits with it, lit above 1x.
		var speed: UiButton = purse.speed_button
		assert_true(
			purse.get_global_rect().encloses(speed.get_global_rect()),
			"%s: the speed button in the purse" % what
		)
		assert_eq(speed.text, "1x")
		assert_false(speed.lit, "unlit at 1x")
		_click(main, speed)
		assert_eq(main.speed, 2, "a click speeds the game up")
		assert_eq(speed.text, "2x")
		assert_true(speed.lit, "lit above 1x")
		_press(main, KEY_F)
		_press(main, KEY_F)
		assert_eq(main.speed, 1, "F cycles back")
		assert_false(speed.lit)
		assert_true(
			purse.get_global_rect().end.x <= room.x, "%s: inside the room at the widest" % what
		)
		main.free()


# --- R4 ------------------------------------------------------------------------


func test_r4_things_still_fly_to_it() -> void:
	for window: Vector2i in WINDOWS:
		var main: Main = _main()
		main.ui.set_window_for_test(window)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var what: String = "%s window" % window
		assert_true(_fight(main), "a fight")
		var battle: Battle = sim.expedition.battle
		var monster: Combatant = battle.monsters[0]
		var hero: Hero = sim.party.heroes[2]
		var ids: Array[StringName] = Content.resource_ids()
		sim.party.set_resource(ids[1], 30)
		hud.purse.catch_up()
		hud.advance(STEP)
		var gold_before: int = hud.shown_gold()
		sim.party.gold += 50
		_emit(main, SimEvent.Kind.DIED, monster.id, -1, 0)
		_emit(main, SimEvent.Kind.GOLD_GAINED, monster.id, -1, 50)
		_emit(main, SimEvent.Kind.XP_GAINED, monster.id, hero.id, 40)
		sim.party.set_resource(ids[1], 32)
		_emit(main, SimEvent.Kind.RESOURCE_GAINED, monster.id, 1, 2)
		var coin_end := Vector2.INF
		var mote_end := Vector2.INF
		var icon_end := Vector2.INF
		var flown: int = 0
		var landed: bool = false
		for frame: int in 300:
			for coin: FxCoin in main.effects._coins:
				coin_end = _on_ui(main, coin)
			for mote: FxMote in main.effects._motes:
				mote_end = _on_ui(main, mote)
			var flying: int = main.effects.resource_effects.live_icons().size()
			for icon: FxResource in main.effects.resource_effects.live_icons():
				icon_end = _on_ui(main, icon)
			main.effects.advance(STEP)
			hud.advance(STEP)
			if landed:
				continue
			if main.effects.resource_effects.live_icons().size() < flying:
				landed = true  # the first landed on this frame: the count rises with it, not later
				assert_gt(hud.purse.shown(ids[1]), 30, "%s: the resource as an icon lands" % what)
			else:
				flown += 1 if flying > 0 else 0
				assert_eq(hud.purse.shown(ids[1]), 30, "%s: unchanged while they fly" % what)
		assert_true(landed, "%s: the icons landed" % what)
		assert_gt(flown, 5, "%s: after a flight" % what)
		assert_eq(hud.purse.shown(ids[1]), 32, "%s: the resource, once they all land" % what)
		var coin: Rect2 = hud.purse.coin_icon.get_global_rect().grow(3.0)
		var counter: Rect2 = hud.purse.icons[ids[1]].get_global_rect().grow(3.0)
		var frame_rect: Rect2 = hud.frames[2].get_global_rect()
		assert_true(
			coin.has_point(coin_end), "%s: a coin ends on the coin %s %s" % [what, coin_end, coin]
		)
		assert_true(
			counter.has_point(icon_end),
			"%s: an icon ends on its counter %s %s" % [what, icon_end, counter]
		)
		assert_true(
			frame_rect.has_point(mote_end),
			"%s: a mote ends on its hero's frame %s %s" % [what, mote_end, frame_rect]
		)
		assert_eq(hud.shown_gold(), gold_before + 50, "%s: the gold counts up as coins land" % what)
		main.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_hero_frames() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var what: String = "%s" % room
		assert_eq(hud.frames.size(), 4, "a frame per hero")
		for i: int in hud.frames.size():
			var frame: HeroFrameView = hud.frames[i]
			var hero: Hero = sim.party.heroes[i]
			assert_true(main.ui.is_ancestor_of(frame), "%s: on the sharp layer" % what)
			assert_eq(frame.hero_id, hero.id, "in marching order")
			if i > 0:
				assert_gt(frame.position.x, hud.frames[i - 1].position.x, "left to right")
			var rect: Rect2 = frame.get_global_rect()
			assert_gt(rect.position.y, room.y * 0.8, "%s: at the bottom" % what)
			assert_lte(rect.end.y, room.y, "%s: inside the room" % what)
			assert_eq(frame.icon.texture, hud.icon(hero.class_id), "the portrait")
			assert_eq(frame.name_label.text, hero.def().display_name, "the class")
			assert_eq(frame.name_label.get_theme_font(&"font"), UiText.font(true), "in bold")
			assert_eq(frame.level_label.text, "Lv %d" % hero.level, "the level")
			assert_eq(
				frame.health_label.text,
				"%d / %d" % [hero.health, hero.max_health()],
				"the health as a number on its bar"
			)
			var bar := Rect2(
				rect.position + HeroFrameView.HEALTH_BAR.position, HeroFrameView.HEALTH_BAR.size
			)
			assert_true(bar.encloses(_ink(frame.health_label)), "%s: the number on the bar" % what)
		var knight: HeroFrameView = hud.frames[0]
		var first: Hero = sim.party.heroes[0]
		# The tag for points to spend.
		assert_false(knight.marker.visible, "nothing to spend")
		first.gain_xp(Hero.xp_for_level(2) - first.xp)
		hud.advance(STEP)
		assert_true(knight.marker.is_visible_in_tree(), "%s: a talent point's tag" % what)
		assert_true(knight.get_global_rect().encloses(knight.marker.get_global_rect()), "on it")
		# A click opens the hero's window, and the frame's edge turns yellow.
		_click(main, knight)
		assert_true(hud.hero_windows.is_open(first.id), "%s: a click opens its window" % what)
		assert_true(knight.marked, "the yellow edge while it is open")
		_click(main, knight)
		assert_false(hud.hero_windows.is_open(first.id), "a second click closes it")
		assert_false(knight.marked)
		# The flash when hit, the skull and Down, Recovering.
		_emit(main, SimEvent.Kind.HIT, -1, first.id, 3)
		hud.advance(STEP)
		assert_gt(knight.flash(), 0.0, "a hit flashes the frame")
		hud.advance(0.5)
		assert_eq(knight.flash(), 0.0, "for an instant")
		first.health = 0
		hud.advance(STEP)
		assert_eq(knight.icon_part(), &"skull", "the skull")
		assert_eq(knight.level_label.text, "Down")
		sim.expedition.state = Expedition.State.REVIVING
		hud.advance(STEP)
		assert_eq(knight.level_label.text, "Recovering")
		sim.expedition.state = Expedition.State.TRAVELLING
		first.health = first.max_health()
		hud.advance(STEP)
		assert_eq(knight.icon_part(), first.class_id, "its portrait back")
		assert_true(knight.status_icons.get_parent() == knight, "its status marks")
		assert_eq(StatusIcons.MOST, 3, "up to three")
		# Blow by blow: in a fight the number follows each hit at once and the bar eases after it.
		assert_true(_fight(main), "a fight")
		var followed: int = 0
		for i: int in 600:
			if main.simulation.expedition.battle == null:
				break
			_tick(main)
			for frame: HeroFrameView in hud.frames:
				var fighter: Combatant = (
					main.simulation.expedition.battle.combatant(frame.hero_id)
					if main.simulation.expedition.battle != null
					else null
				)
				if fighter == null:
					continue
				var number: String = "%d / %d" % [maxi(fighter.health, 0), fighter.max_health]
				if fighter.is_alive():
					assert_eq(frame.health_label.text, number, "the number is the blow's")
					followed += 1
		assert_gt(followed, 50, "a fight was followed")
		main.free()


func test_r5_the_bar_and_the_ticker_sit_on_the_frames() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var ui: UiRoot = main.ui
		var what: String = "%s" % room
		var line: float = main.hud.frames[0].get_global_rect().position.y
		assert_almost_eq(
			ui.world_to_ui(Vector2(0, ui.frames_top())).y, line, 1.0, "%s: the frames' top" % what
		)
		var bar: Rect2 = ui.bar.get_global_rect()
		assert_lte(bar.end.y, line, "%s: the button bar above the frames" % what)
		assert_gt(bar.end.y, line - 8.0, "%s: just above them" % what)
		main.hud.journal.announce("Something happened.")
		main.hud.advance(STEP)
		var ticker: Rect2 = Hud.on_screen(main.hud.ticker)
		var on_ui := Rect2(ui.world_to_ui(ticker.position), ui.world_to_ui(ticker.size))
		assert_true(main.hud.ticker.is_visible_in_tree(), "%s: the ticker shows" % what)
		assert_lte(on_ui.end.y, line, "%s: the ticker above the frames" % what)
		assert_gt(on_ui.end.y, line - 12.0, "%s: just above them" % what)
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_the_boss_bar() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var bar: BossBarView = hud.boss_bar
		var what: String = "%s" % room
		assert_false(bar.is_visible_in_tree(), "no bar outside a guardian fight")
		assert_true(_guardian_fight(main), "a guardian fight")
		assert_true(main.ui.is_ancestor_of(bar), "%s: on the sharp layer" % what)
		assert_true(bar.is_visible_in_tree(), "%s: the bar shows" % what)
		var rect: Rect2 = bar.get_global_rect()
		assert_lt(rect.position.y, 8.0, "%s: at the top" % what)
		assert_almost_eq(
			rect.get_center().x, room.x / 2.0, room.x * 0.12, "%s: at the centre" % what
		)
		assert_gte(rect.size.x, 200.0, "%s: wide" % what)
		var guardian: Combatant = null
		for monster: Combatant in main.simulation.expedition.battle.monsters:
			if Content.monster(monster.def_id).guardian:
				guardian = monster
		assert_eq(bar.name_label.text, Content.monster(guardian.def_id).display_name.to_upper())
		assert_eq(bar.name_label.get_theme_font(&"font"), UiText.font(true), "in bold")
		assert_eq(
			bar.health_label.text,
			(
				"%s / %s"
				% [Hud.group_thousands(guardian.health), Hud.group_thousands(guardian.max_health)]
			),
			"its health as a number"
		)
		assert_true(rect.encloses(_ink(bar.health_label)), "%s: inside the bar" % what)
		assert_lt(
			bar.name_label.get_global_rect().position.y,
			bar.health_label.get_global_rect().position.y,
			"the name over the bar"
		)
		# Draining smoothly, flashing on a hit.
		var before: float = bar.shown_fraction()
		guardian.health = guardian.max_health / 2
		_emit(main, SimEvent.Kind.HIT, -1, guardian.id, 10)
		hud.advance(STEP)
		assert_true(bar.is_flashing(), "a hit flashes it")
		assert_lt(bar.shown_fraction(), before, "draining")
		assert_gt(bar.shown_fraction(), 0.5, "smoothly, not at once")
		hud.advance(1.0)
		assert_almost_eq(bar.shown_fraction(), 0.5, 0.01, "to the guardian's health")
		assert_false(bar.is_flashing(), "the flash is brief")
		main.free()


# --- R7 ------------------------------------------------------------------------


func test_r7_tooltips() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var tip: UiTip = hud.frame_tip
		var panel: PlacePanel = hud.place_panel
		var purse: Purse = hud.purse
		var ids: Array[StringName] = Content.resource_ids()
		main.simulation.party.set_resource(ids[0], 5)
		hud.purse.catch_up()
		hud.advance(STEP)
		var tipped: Dictionary[String, Control] = {
			"stage": panel.stage_label,
			"status": panel.status_label,
			"safe": panel.safe_label,
			"target": panel.target_label,
			"minus": panel.minus_button,
			"plus": panel.plus_button,
			"auto": panel.auto_button,
			"speed": purse.speed_button,
			"gold": purse.gold_label,
			"area": panel.area_button,
		}
		for key: String in tipped:
			var control: Control = tipped[key]
			var text: String = _rest_on(main, control)
			assert_eq(text, OLD_TIPS[key], "%s %s: the old tooltip, kept" % [room, key])
			_check_box(main, control, "%s %s" % [room, key])
		var countdown: String = _rest_on(main, hud.countdown.note_label)
		assert_true(countdown.length() > 10, "%s: the countdown's tooltip" % room)
		var resource: String = _rest_on(main, purse.labels[ids[0]])
		assert_eq(resource, purse.tip_text(ids[0]), "%s: the resource's own" % room)
		for frame: HeroFrameView in hud.frames:
			var said: String = _rest_on(main, frame)
			assert_eq(said, frame.tip(), "%s: a frame's tooltip, as before" % room)
			assert_eq(tip.shown_title(), frame.tip_title(), "under a title")
			assert_eq(tip.title_label.get_theme_font(&"font"), UiText.font(true), "in bold")
			_check_box(main, frame, "%s %s" % [room, frame.name])
		# A long one wraps.
		_rest_on(main, panel.auto_button)
		assert_lte(tip.label.size.x, UiTip.WIDTH + 1.0, "wrapped to the tip's width")
		assert_gt(tip.label.get_line_count(), 1, "onto a second line")
		_move(Vector2(-50, -50))
		hud.advance(STEP)
		assert_eq(tip.shown_text(), "", "gone when the mouse leaves")
		assert_true(_guardian_fight(main), "a guardian fight")
		var boss: String = _rest_on(main, hud.boss_bar)
		assert_eq(boss, "A guardian holds the way on: beat it to go further.", "the boss bar's")
		_check_box(main, hud.boss_bar, "%s boss bar" % room)
		main.free()


func test_r7_a_frame_tip_is_drawn_over_everything() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var tip: UiTip = hud.frame_tip
		# Every tag on the bar showing (they draw over their neighbours).
		for id: StringName in main.ui.windows.ids():
			main.ui.windows.window(id).badge = 9
		main.ui.bar.refresh()
		for frame: HeroFrameView in hud.frames:
			var what: String = "%s %s" % [room, frame.name]
			assert_eq(_rest_on(main, frame), frame.tip(), "%s: its tip shows" % what)
			assert_eq(_drawn_over(main.ui, tip), [] as Array[String], "%s: nothing over it" % what)
			# A window open under where the tip shows, clear of the frame the mouse is on.
			var help: UiWindow = main.ui.windows.window(UiRoot.HELP)
			main.ui.windows.open_window(UiRoot.HELP)
			var box: Rect2 = tip.get_global_rect()
			help.position = Vector2(
				box.position.x - 8.0, frame.get_global_rect().position.y - 2.0 - help.size.y
			)
			assert_true(help.get_global_rect().intersects(box), "%s: the window under it" % what)
			assert_eq(_rest_on(main, frame), frame.tip(), "%s: its tip still shows" % what)
			assert_eq(
				_drawn_over(main.ui, tip),
				[] as Array[String],
				"%s: nothing over it, the window either" % what
			)
			main.ui.windows.close_window(UiRoot.HELP)
		main.free()


## The names of what on [param layer] draws over [param tip]'s box: anything later in the draw
## order (the tree's, or a higher z) whose rectangle meets it.
func _drawn_over(layer: CanvasLayer, tip: UiTip) -> Array[String]:
	var order: Array[CanvasItem] = []
	_in_draw_order(layer, order)
	var box: Rect2 = tip.get_global_rect()
	var over: Array[String] = []
	var after: bool = false
	for item: CanvasItem in order:
		if item == tip:
			after = true
			continue
		if tip.is_ancestor_of(item) or not item.is_visible_in_tree():
			continue
		var later: bool = _z_of(item) > _z_of(tip) or (after and _z_of(item) == _z_of(tip))
		var control: Control = item as Control
		# Anything not a control is taken to cover the whole layer.
		var rect: Rect2 = control.get_global_rect() if control != null else box
		if later and rect.intersects(box):
			over.append(String(item.get_path()))
	return over


func _in_draw_order(node: Node, order: Array[CanvasItem]) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem:
			order.append(child as CanvasItem)
		_in_draw_order(child, order)


func _z_of(item: CanvasItem) -> int:
	var z: int = 0
	var at: Node = item
	while at is CanvasItem:
		var canvas_item: CanvasItem = at as CanvasItem
		z += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		at = at.get_parent()
	return z


func _check_box(main: Main, control: Control, what: String) -> void:
	var tip: UiTip = main.hud.frame_tip
	var box: Rect2 = tip.get_global_rect()
	assert_true(tip.is_visible_in_tree(), "%s: the tip shows" % what)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(main.ui.room())).encloses(box), "%s: never off screen" % what
	)
	assert_false(
		box.intersects(control.get_global_rect()), "%s: never over what it explains" % what
	)
	assert_eq(tip.label.get_theme_font(&"font"), UiText.font(), "%s: in the UI font" % what)
	var lines: int = tip.label.get_line_count() + (1 if tip.title_label.visible else 0)
	assert_lte(
		box.size.y, lines * (UiText.LINE_HEIGHT + 4) + 12.0, "%s: as tall as its lines" % what
	)


# --- R8 ------------------------------------------------------------------------


func test_r8_nothing_drawn_twice_nothing_lost() -> void:
	var main: Main = _main()
	var hud: Hud = main.hud
	# Nothing of the old pieces is left on the old HUD.
	var old: Array[Control] = []
	_controls(hud, old)
	for control: Control in old:
		var old_panel: bool = String(control.name) in ["DepthPanel", "GoldPanel", "SpeedTab"]
		assert_false(control is Panel and old_panel, "%s is gone" % control.name)
		var label: Label = control as Label
		if label != null and label.is_visible_in_tree():
			for gone: String in ["Safe 1", "Target", hud.status_text()]:
				assert_ne(label.text, gone, "'%s' is not drawn on the old HUD too" % gone)
	for path: String in [
		"res://game/hud/hero_frame.gd",
		"res://game/hud/boss_bar.gd",
		"res://game/hud/resource_purse.gd"
	]:
		assert_false(FileAccess.file_exists(path), "%s is removed" % path)
	# Every piece is on the sharp layer, drawn once.
	for piece: Control in _pieces(main).values():
		assert_true(main.ui.is_ancestor_of(piece), "%s on the sharp layer" % piece.name)
	# Every key still works.
	var sim: Simulation = main.simulation
	var target: int = sim.expedition.target_depth
	_press(main, KEY_EQUAL)
	sim.step()
	hud.advance(STEP)
	assert_eq(sim.expedition.target_depth, target + 1, "= raises the target")
	_press(main, KEY_MINUS)
	sim.step()
	hud.advance(STEP)
	assert_eq(sim.expedition.target_depth, target, "- lowers it")
	var auto: bool = sim.expedition.auto_push
	_press(main, KEY_A)
	sim.step()
	hud.advance(STEP)
	assert_ne(sim.expedition.auto_push, auto, "A switches Auto")
	assert_eq(hud.place_panel.auto_button.lit, sim.expedition.auto_push, "as the panel shows")
	_press(main, KEY_TAB)
	assert_true(hud.hero_windows.is_open(sim.party.heroes[0].id), "Tab opens a hero's window")
	assert_true(hud.frames[0].marked, "marked on its frame")
	hud.hero_windows.close_all()
	_press(main, KEY_W)
	assert_true(hud.area_map.is_open(), "W opens the map")
	hud.area_map.close()
	_press(main, KEY_F)
	assert_eq(main.speed, 2, "F speeds the game")
	assert_true(hud.purse.speed_button.lit, "shown on the purse")


func test_r8_a_click_on_the_frame_goes_no_further() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		assert_true(_guardian_fight(main), "a guardian fight")
		# Over everything the world's viewport holds, a probe that hears every press reaching it.
		var heard: Array[Vector2] = []
		var probe := Control.new()
		probe.size = Hud.SCREEN
		probe.mouse_filter = Control.MOUSE_FILTER_STOP
		probe.gui_input.connect(
			func(event: InputEvent) -> void:
				var press: InputEventMouseButton = event as InputEventMouseButton
				if press != null and press.pressed:
					heard.append(press.position)
		)
		hud.add_child(probe)
		_click_ui(main.ui, Vector2(main.ui.room()) / 2.0)
		assert_eq(heard.size(), 1, "%s: a click on the world reaches it" % room)
		var spots: Dictionary[String, Vector2] = {
			"the gold": hud.purse.gold_label.get_global_rect().get_center(),
			"the purse's edge": hud.purse.get_global_rect().end - Vector2(3, 3),
			"the countdown": hud.countdown.get_global_rect().get_center(),
			"the boss bar": hud.boss_bar.get_global_rect().get_center(),
			"the place panel": hud.place_panel.status_label.get_global_rect().get_center(),
		}
		for spot: String in spots:
			heard.clear()
			_click_ui(main.ui, spots[spot])
			assert_eq(
				heard, [] as Array[Vector2], "%s: a click on %s goes no further" % [room, spot]
			)
		main.free()


# --- R9 ------------------------------------------------------------------------


func test_r9_true_in_a_crowded_frame() -> void:
	var main: Main = _main()
	var hud: Hud = main.hud
	var sim: Simulation = main.simulation
	_raise(main, 6)
	sim.set_auto_push(true)
	assert_true(_fight(main), "a fight")
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	main.effects.advance(STEP)
	hud.advance(STEP)
	var e: Expedition = sim.expedition
	var panel: PlacePanel = hud.place_panel
	assert_eq(panel.stage_label.text, str(e.depth), "the stage")
	assert_eq(panel.safe_label.text, "Safe %d" % e.last_stable_depth, "the safe stage")
	assert_eq(panel.target_label.text, str(e.target_depth), "the target")
	assert_eq(panel.status_label.text, hud.status_text(), "the status line")
	var road: String = hud.countdown.note_label.text
	if not hud.countdown.next_label.text.is_empty():
		road += ", " + hud.countdown.next_label.text
	assert_eq(road, hud.stable_text(), "the countdown")
	var flying: int = 0
	for coin: FxCoin in main.effects._coins:
		flying += coin.share
	assert_eq(hud.shown_gold() + flying, sim.party.gold, "the gold, but for coins in the air")
	for id: StringName in Content.resource_ids():
		var held: int = sim.party.resource(id)
		assert_lte(hud.purse.shown(id), held, "%s never more than held" % id)
	var recent_hits: Dictionary[int, bool] = {}
	var tally: TallyWindow = hud.tally
	for frame: HeroFrameView in hud.frames:
		var hero: Hero = sim.party.hero(frame.hero_id)
		var fighter: Combatant = (
			e.battle.combatant(hero.id)
			if e.battle != null and e.state == Expedition.State.FIGHTING
			else null
		)
		var health: int = fighter.health if fighter != null else hero.health
		var most: int = fighter.max_health if fighter != null else hero.max_health()
		var alive: bool = fighter.is_alive() if fighter != null else hero.is_alive()
		if alive:
			assert_eq(frame.level_label.text, "Lv %d" % hero.level, "%s: its level" % frame.name)
			assert_eq(frame.health_label.text, "%d / %d" % [health, most], "its health")
		assert_almost_eq(
			frame.shown_health(),
			clampf(float(health) / most, 0.0, 1.0),
			0.0001,
			"%s: the bar at the end, not on its way" % frame.name
		)
		assert_almost_eq(
			frame.shown_xp(), HeroFrameView.xp_progress(hero), 0.0001, "the XP bar too"
		)
		assert_eq(frame.level_pulse(), 0.0, "no stale level pulse")
		var statuses: Array[int] = []
		for status: ShownStatus in tally.tally.credit.statuses.statuses_of(hero.id):
			if statuses.size() < StatusIcons.MOST:
				statuses.append(status.kind)
		if alive:
			assert_eq(frame.status_icons.kinds, statuses, "%s: its statuses" % frame.name)
		recent_hits[hero.id] = false
	for frame: HeroFrameView in hud.frames:
		assert_eq(frame.flash(), 0.0, "%s: no stale flash" % frame.name)
	assert_eq(hud.gold_bump(), 0.0, "no stale bump on the gold")
	assert_eq(hud.depth_emphasis(), 0.0, "no stale emphasis on the stage")


# --- R10 -----------------------------------------------------------------------


func test_r10_fits_both_rooms_and_clears_the_windows() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var what: String = "%s" % room
		# The widest the frame gets: every resource held at 99.9k beside 9.9M gold, the Claypits at
		# stage 999 fighting the Clay Colossus, and the countdown's longest note and next.
		sim.party.gold = 9_900_000
		hud.advance(STEP)
		main.effects.coin_collected.emit(9_900_000)
		for id: StringName in Content.resource_ids():
			sim.party.set_resource(id, 99_900)
		hud.purse.catch_up()
		assert_true(_guardian_fight(main), "%s: a guardian fight" % what)
		hud.advance(STEP)
		_show_widest(main)
		hud.fit_frame(room)
		var pieces: Dictionary[String, Control] = _pieces(main)
		assert_true(pieces.has("boss bar"), "the boss bar is up")
		assert_eq(hud.purse.gold_label.text, "9.9M", "%s: the widest gold" % what)
		assert_eq(hud.purse.shown_ids().size(), Content.resource_ids().size(), "every resource")
		assert_gte(hud.boss_bar.size.x, 200.0, "%s: the boss bar stays wide" % what)
		var names: Array[String] = pieces.keys()
		var room_rect := Rect2(Vector2.ZERO, Vector2(room))
		for a: int in names.size():
			var rect_a: Rect2 = pieces[names[a]].get_global_rect()
			assert_true(room_rect.encloses(rect_a), "%s: %s inside the room" % [what, names[a]])
			for b: int in range(a + 1, names.size()):
				assert_false(
					rect_a.intersects(pieces[names[b]].get_global_rect()),
					"%s: %s clear of %s" % [what, names[a], names[b]]
				)
		for name_key: String in names:
			var piece: Control = pieces[name_key]
			for label: Label in _shown_labels(piece):
				assert_true(
					piece.get_global_rect().encloses(_ink(label)),
					"%s: '%s' not cut in %s" % [what, label.text, name_key]
				)
		# The default places of every window clear every piece of the frame.
		main.ui.windows.reset_places()
		for id: StringName in main.ui.windows.ids():
			var window: UiWindow = main.ui.windows.window(id)
			var place := Rect2(window.default_place, window.size)
			for name_key: String in names:
				assert_false(
					place.intersects(pieces[name_key].get_global_rect()),
					"%s: window %s's place clear of %s" % [what, id, name_key]
				)
		for hero: Hero in sim.party.heroes:
			main.hud.hero_windows.open(hero.id)
		for hero: Hero in sim.party.heroes:
			var window: HeroWindow = main.hud.hero_windows.window_of(hero.id)
			for name_key: String in names:
				assert_false(
					window.get_global_rect().intersects(pieces[name_key].get_global_rect()),
					"%s: hero window %d clear of %s" % [what, hero.id, name_key]
				)
		main.free()


## Puts the widest texts the frame shows on its pieces (as the HUD's advance would put them, were
## the party there): the Claypits at stage 999, fighting the Clay Colossus, "Further in 12:00" and
## "then stage 100", and the Colossus's name and a six-figure health on the boss bar.
func _show_widest(main: Main) -> void:
	var hud: Hud = main.hud
	var colossus: String = Content.monster(&"clay_colossus").display_name
	hud.place_panel.show_place(
		PlaceText.area_name(&"claypits"),
		999,
		&"white",
		0.0,
		998,
		999,
		true,
		"Fighting the %s" % colossus,
		&"red"
	)
	hud.countdown.show_road("Further in 12:00", "then stage 100", 0.5, PlacePanel.HEIGHT)
	hud.boss_bar.name_label.text = colossus.to_upper()
	hud.boss_bar.name_label.reset_size()
	hud.boss_bar.health_label.text = "888,888 / 888,888"
	hud.boss_bar.health_label.reset_size()


# --- R11 -----------------------------------------------------------------------


func test_r11_showcase_help_and_wiki() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	assert_string_contains(wiki, "frame of the screen", "the wiki tells of it")
	for said: String in ["Stable in", "Safe", "Auto", "1x"]:
		assert_string_contains(wiki, said, "the wiki names %s" % said)
	var keys: Dictionary[String, bool] = {}
	for entry: Array in HelpPanel.KEYS:
		keys[str(entry[0])] = true
	for key: String in ["- +", "A", "F", "W", "Tab"]:
		assert_true(keys.has(key), "help lists %s" % key)
	var showcase: String = FileAccess.get_file_as_string(SHOWCASE)
	assert_false(showcase.contains("depth_panel"), "the showcase names no old piece")
	assert_false(showcase.contains("gold_panel"), "the showcase names no old piece")

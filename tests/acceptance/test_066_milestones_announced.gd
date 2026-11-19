extends "res://tests/acceptance/frame_061_test.gd"
## Acceptance tests for specs/066-milestones-announced/spec.md, one per requirement.
##
## Each test runs the main scene with its own processing off, laid out for a chosen room, and steps
## it a frame at a time by hand: the simulation, the world, the effects, the HUD, the milestones
## and the moment. The events are the simulation's own (a guardian fought and slain, XP given
## through the expedition, a stage stood on until it is safe); where the simulation cannot report
## what a requirement names (an area opened with no guardian, a stage made safe twice, an event
## long past), one is sent through the world's signal as the world sends its own.

const GUARDIAN_STAGE: int = Expedition.GUARDIAN_EVERY
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"

# --- Helpers -------------------------------------------------------------------


## A main scene laid out for [param room], its world synced twice (so it is not catching up) and
## its milestones and moment run by hand.
func _start(room: Vector2i = ROOM_LARGE) -> Main:
	var main: Main = _main(room)
	main.ui.moment.set_process(false)
	main.ui.tip.set_process(false)
	main.milestones.set_process(false)
	main.simulation.set_auto_push(false)
	_frame(main, 0)
	_frame(main, 0)
	assert_false(main.world.catching_up(), "the world has caught up")
	return main


## A frame of [param ticks] ticks: the simulation, then all that shows it.
func _frame(main: Main, ticks: int = 1, delta: float = STEP) -> void:
	for i: int in ticks:
		main.simulation.step()
	main.world.sync(delta)
	main.effects.advance(delta)
	main.sound._process(delta)  # its clock: a voice is free again once its sound has ended
	main.hud.advance(delta)
	main.milestones.advance(delta)
	main.ui.moment.advance(delta)


## Frames of one tick until [param done] is true, at most [param ticks]; true if it came true.
func _frames_until(main: Main, done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		if done.call():
			return true
		_frame(main)
	return done.call()


func _frame_of(main: Main, hero_id: int) -> HeroFrameView:
	for frame: HeroFrameView in main.hud.frames:
		if frame.hero_id == hero_id:
			return frame
	return null


## Raises [param hero] to [param level] with no event.
func _set_level(hero: Hero, level: int) -> void:
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
	hero.health = hero.max_health()


## The expedition gives [param hero] the XP to reach [param level], reporting it as a kill would.
func _earn_level(main: Main, hero: Hero, level: int) -> void:
	main.simulation.expedition._give_xp(hero, Hero.xp_for_level(level) - hero.xp)


## The party fights the guardian of [param stage] and slays it; true once GUARDIAN_SLAIN is heard.
func _slay_guardian(main: Main, stage: int = GUARDIAN_STAGE) -> bool:
	var slain: Array[bool] = [false]
	var heard := func(event: SimEvent) -> void:
		if event.kind == SimEvent.Kind.GUARDIAN_SLAIN:
			slain[0] = true
	main.world.sim_event.connect(heard)
	_before_guardian(main, stage)
	_raise(main, STRONG_LEVEL)
	var met: bool = _frames_until(
		main, func() -> bool: return GuardianSpacing.fighting_guardian(main.simulation) != null
	)
	if met:
		GuardianSpacing.fighting_guardian(main.simulation).health = 1
		_frames_until(main, func() -> bool: return slain[0], 2_000)
	main.world.sim_event.disconnect(heard)
	return slain[0]


## Every headline the moment shows over the next [param seconds], in order, each once.
func _headlines(main: Main, seconds: float = 8.0) -> Array[String]:
	var shown: Array[String] = []
	for i: int in roundi(seconds / STEP):
		_frame(main)
		var headline: String = main.ui.moment.shown_headline()
		if not headline.is_empty() and (shown.is_empty() or shown[-1] != headline):
			shown.append(headline)
	return shown


func _colour(label: Label) -> Color:
	return label.get_theme_color(&"font_color")


## An event of [param kind] stamped [param ticks_ago] ticks before now, sent as the world sends.
func _emit_old(
	main: Main, kind: SimEvent.Kind, source: int, target: int, amount: int, ticks_ago: int
) -> void:
	var tick: int = main.simulation.tick - ticks_ago
	main.world.sim_event.emit(SimEvent.new(kind, tick, source, target, amount))


func _has_line(main: Main, wanted: String) -> bool:
	for line: String in main.hud.journal.lines():
		if line.contains(wanted):
			return true
	return false


## True when nothing of spec 066 is running in [param main].
func _all_still(main: Main) -> bool:
	var moment: UiMoment = main.ui.moment
	var still: bool = moment.shown_headline().is_empty() and moment.waiting() == 0
	still = still and moment.spark_count() == 0 and main.hud.place_panel.safe_step == 0.0
	for frame: HeroFrameView in main.hud.frames:
		still = still and frame.level_step == 0.0 and frame.tag_pulse == 0.0
		still = still and frame.marker.scale == Vector2.ONE
	return still


# --- R1 ------------------------------------------------------------------------


func test_r1_a_guardian_beaten() -> void:
	var main: Main = _start()
	var moment: UiMoment = main.ui.moment
	assert_false(main.simulation.is_area_open(&"claypits"), "the Claypits are closed")
	assert_true(_slay_guardian(main), "the guardian is slain")
	assert_true(main.simulation.is_area_open(&"claypits"), "which opens the Claypits")
	_frame(main)
	assert_eq(moment.shown_headline(), "Slime King is beaten", "a banner for the guardian")
	assert_eq(moment.banner_line.text, "The Claypits are open", "saying what that gave")
	var picture: Texture2D = Milestones.guardian_picture(&"slime_king")
	assert_not_null(picture, "the guardian has a picture")
	assert_eq(moment.banner_picture.texture, picture, "the guardian's own sprite")
	if picture != null:
		var image: Image = picture.get_image()
		var sheet: PixelSheet = PixelSheet.load_sheet(
			"res://assets/sprites/monsters/slime_king.png"
		)
		var body: Image = sheet.part(&"body").get_image()
		var solid: int = 0
		var same: int = 0
		var used: Rect2i = body.get_used_rect()
		assert_lte(image.get_width(), sheet.size.x, "no wider than the sprite")
		assert_eq(image.get_width(), image.get_height(), "square, so it is not stretched")
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					solid += 1
		for y: int in range(used.position.y, used.end.y):
			for x: int in range(used.position.x, used.end.x):
				if body.get_pixel(x, y).a > 0.5:
					same += 1
		assert_gte(solid, same, "all of its body is in the picture (%d of %d)" % [solid, same])
		assert_gt(same, 200, "a body of some size")
	var seen: Array[String] = _headlines(main)
	assert_eq(seen, ["Slime King is beaten"] as Array[String], "one banner, not two")

	# A guardian that opens nothing: the stage it held is behind the party.
	var again: Main = _start()
	again.simulation.expedition.travel.open[&"claypits"] = true
	assert_true(_slay_guardian(again, 2 * GUARDIAN_STAGE), "a later guardian is slain")
	_frame(again)
	assert_eq(again.ui.moment.shown_headline(), "Slime King is beaten", "a banner again")
	assert_eq(again.ui.moment.banner_line.text, "Mossy Hollow 10 is behind you", "the stage")
	assert_eq(_headlines(again), ["Slime King is beaten"] as Array[String], "and only it")


# --- R2 ------------------------------------------------------------------------


func test_r2_an_area_opened() -> void:
	var main: Main = _start()
	var moment: UiMoment = main.ui.moment
	var ids: Array[StringName] = Content.area_ids()
	_emit(main, SimEvent.Kind.AREA_OPENED, -1, -1, ids.find(&"claypits"))
	_frame(main)
	assert_eq(moment.shown_headline(), "The Claypits are open", "a banner of its own")
	assert_eq(moment.banner_line.text, "It gives clay", "saying what it gives")
	assert_not_null(ResourceIcon.texture(&"clay"), "clay has an icon")
	assert_eq(moment.banner_picture.texture, ResourceIcon.texture(&"clay"), "the resource's icon")
	moment.banner_clicked()
	_emit(main, SimEvent.Kind.AREA_OPENED, -1, -1, ids.find(&"ember_deep"))
	_frame(main)
	assert_eq(moment.shown_headline(), "Ember Deep is open", "one area, one thing")
	assert_eq(moment.banner_line.text, "It gives embers")
	assert_eq(moment.banner_picture.texture, ResourceIcon.texture(&"embers"))


# --- R3 ------------------------------------------------------------------------


func test_r3_a_level() -> void:
	var main: Main = _start()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = main.simulation.party.heroes[0]
	var frame: HeroFrameView = _frame_of(main, knight.id)
	_set_level(knight, 4)  # level 5 brings no talent point and no microskill
	_frame(main)
	var rest: Vector2 = frame.level_label.position
	assert_eq(frame.level_step, 0.0, "nothing before the level")
	_earn_level(main, knight, 5)
	_frame(main)
	assert_eq(knight.level, 5, "the knight levelled")
	assert_true(moment.is_bursting(frame), "the hero's frame bursts")
	for other: HeroFrameView in main.hud.frames:
		if other != frame:
			assert_false(moment.is_bursting(other), "%s does not" % other.name)
			assert_eq(other.level_step, 0.0, "%s: nor steps" % other.name)
	assert_eq(frame.level_label.text, "Lv 5", "the new level")
	assert_eq(
		frame.level_label.position.y, rest.y - HeroFrameView.STEP_LIFT, "the level number steps up"
	)
	var elapsed: float = STEP
	var lifts: Array[float] = []
	while elapsed < 0.55:
		assert_gt(frame.level_step, 0.0, "stepping at %.2f s" % elapsed)
		assert_eq(_colour(frame.level_label), Palette.color(&"yellow"), "in yellow")
		var lift: float = rest.y - frame.level_label.position.y
		assert_gt(lift, 0.0, "raised at %.2f s" % elapsed)
		if lifts.is_empty() or lifts[-1] != lift:
			lifts.append(lift)
		_frame(main, 0)
		elapsed += STEP
	assert_eq(lifts, [3.0, 2.0, 1.0] as Array[float], "it comes down a step at a time")
	while elapsed < 1.0:
		_frame(main, 0)
		elapsed += STEP
	assert_eq(frame.level_step, 0.0, "for 0.6 s")
	assert_false(moment.is_bursting(frame), "the burst over")
	assert_eq(frame.level_label.position, rest, "the number back in its place")
	assert_eq(frame.scale, Vector2.ONE, "the frame at its own size")
	assert_eq(moment.shown_headline(), "", "no banner for a level")
	assert_eq(moment.waiting(), 0, "none waiting")


# --- R4 ------------------------------------------------------------------------


func test_r4_a_talent_point() -> void:
	var main: Main = _start()
	var knight: Hero = main.simulation.party.heroes[0]
	var frame: HeroFrameView = _frame_of(main, knight.id)
	_set_level(knight, 4)
	_frame(main)
	_earn_level(main, knight, 5)  # no point at level 5
	_frame(main)
	assert_eq(frame.tag_pulse, 0.0, "a level without a point pulses nothing")
	_earn_level(main, knight, 6)
	_frame(main)
	assert_true(frame.marker.visible, "the tag shows the point")
	assert_gt(frame.tag_pulse, 0.0, "and pulses")
	var peaks: int = 0
	var rising: bool = false
	var before: float = 1.0
	var biggest: float = 1.0
	var elapsed: float = 0.0
	while elapsed < 1.5:
		var now: float = frame.marker.scale.x
		biggest = maxf(biggest, now)
		if now > before + 0.001:
			rising = true
		elif now < before - 0.001 and rising:
			rising = false
			peaks += 1
		before = now
		_frame(main, 0)
		elapsed += STEP
	assert_eq(peaks, 3, "three times")
	assert_gt(biggest, 1.3, "each a swell one can see (%.2f)" % biggest)
	assert_eq(frame.marker.scale, Vector2.ONE, "then the tag is its own size")
	assert_eq(frame.tag_pulse, 0.0, "and still")
	for other: HeroFrameView in main.hud.frames:
		if other != frame:
			assert_eq(other.tag_pulse, 0.0, "%s: no pulse" % other.name)


# --- R5 ------------------------------------------------------------------------


func test_r5_a_new_safe_stage() -> void:
	var main: Main = _start()
	var moment: UiMoment = main.ui.moment
	var panel: PlacePanel = main.hud.place_panel
	var e: Expedition = main.simulation.expedition
	_raise(main, STRONG_LEVEL)
	e.stable_seconds = 2.0
	e.depth = 2
	e.target_depth = 2
	_frame(main)
	var rest: Vector2 = panel.safe_label.position
	assert_eq(_colour(panel.safe_label), Palette.color(&"silver"), "silver at rest")
	var safe: bool = _frames_until(main, func() -> bool: return e.last_stable_depth == 2, 2_000)
	assert_true(safe, "stage 2 becomes safe")
	_frame(main, 0)
	assert_eq(panel.safe_label.text, "Safe 2", "the panel says so")
	assert_true(moment.is_bursting(panel.safe_label), "Safe N bursts")
	assert_gt(panel.safe_step, 0.0, "and steps up")
	assert_eq(_colour(panel.safe_label), Palette.color(&"yellow"), "in yellow")
	assert_lt(panel.safe_label.position.y, rest.y, "raised")
	assert_eq(panel.safe_label.position.x, rest.x, "in its place sideways")
	var elapsed: float = 0.0
	while elapsed < 1.0:
		_frame(main, 0)
		elapsed += STEP
	assert_eq(panel.safe_step, 0.0, "the step ends")
	assert_eq(_colour(panel.safe_label), Palette.color(&"silver"), "silver again")
	assert_eq(panel.safe_label.position, rest, "back in its place")
	assert_false(moment.is_bursting(panel.safe_label), "the burst over")

	# A stage that was safe already, told safe again (after a defeat): nothing.
	var bursts: int = moment.bursts_seen()
	for stage: int in [2, 1]:
		_emit(main, SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, stage)
		_frame(main, 0)
		assert_eq(moment.bursts_seen(), bursts, "stage %d safe again: no burst" % stage)
		assert_eq(panel.safe_step, 0.0, "stage %d safe again: no step" % stage)
	_emit(main, SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 3)
	_frame(main, 0)
	assert_eq(moment.bursts_seen(), bursts + 1, "a further stage bursts again")


# --- R6 ------------------------------------------------------------------------


func test_r6_only_for_what_just_happened() -> void:
	var main: Main = _start()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = main.simulation.party.heroes[0]
	var ids: Array[StringName] = Content.area_ids()
	_set_level(knight, 4)
	_frame(main)
	_frame(main)
	assert_false(main.world.catching_up(), "not catching up")
	var bursts: int = moment.bursts_seen()

	# Events long past, heard now.
	var old: int = 10 * Simulation.TICKS_PER_SECOND
	_emit_old(main, SimEvent.Kind.GUARDIAN_SLAIN, Expedition.FIRST_MONSTER_ID, -1, 5, old)
	_emit_old(main, SimEvent.Kind.AREA_OPENED, -1, -1, ids.find(&"claypits"), old)
	_emit_old(main, SimEvent.Kind.AREA_OPENED, -1, -1, ids.find(&"old_crypt"), old - 1)
	_emit_old(main, SimEvent.Kind.LEVEL_UP, -1, knight.id, 5, old)
	_emit_old(main, SimEvent.Kind.TALENT_POINT_GAINED, knight.id, -1, 6, old)
	_emit_old(main, SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 4, old)
	_frame(main, 0)
	assert_eq(moment.bursts_seen(), bursts, "no burst for an old event")
	assert_true(_all_still(main), "nothing starts for an old event")

	# The same, recent: everything starts (so the check above means something).
	_emit(main, SimEvent.Kind.GUARDIAN_SLAIN, Expedition.FIRST_MONSTER_ID, -1, 5)
	_emit(main, SimEvent.Kind.LEVEL_UP, -1, knight.id, 5)
	_emit(main, SimEvent.Kind.TALENT_POINT_GAINED, knight.id, -1, 6)
	_emit(main, SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 5)
	_frame(main, 0)
	var frame: HeroFrameView = _frame_of(main, knight.id)
	assert_eq(moment.shown_headline(), "Slime King is beaten", "recent: the banner")
	assert_gt(frame.level_step, 0.0, "recent: the level steps")
	assert_gt(frame.tag_pulse, 0.0, "recent: the tag pulses")
	assert_gt(main.hud.place_panel.safe_step, 0.0, "recent: the safe stage steps")
	assert_eq(moment.bursts_seen(), bursts + 2, "recent: the frame and the safe stage burst")

	# A catch-up starts: what is running is cleared, and its own events start nothing.
	for i: int in 4 * Simulation.TICKS_PER_SECOND:
		main.simulation.step()
	main.simulation.drain_events()
	_earn_level(main, knight, 6)  # a level and a talent point, on the tick the world catches up
	bursts = moment.bursts_seen()
	main.world.sync(STEP)
	assert_true(main.world.catching_up(), "the world is catching up")
	_emit(main, SimEvent.Kind.GUARDIAN_SLAIN, Expedition.FIRST_MONSTER_ID, -1, 5)
	_emit(main, SimEvent.Kind.AREA_OPENED, -1, -1, ids.find(&"old_crypt"))
	_emit(main, SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 9)
	main.hud.advance(STEP)
	main.milestones.advance(STEP)
	moment.advance(STEP)
	assert_eq(knight.level, 6, "the knight levelled meanwhile")
	assert_eq(moment.bursts_seen(), bursts, "no burst while catching up")
	assert_true(_all_still(main), "what was running is cleared, and nothing starts")
	_frame(main, 0)
	_frame(main, 0)
	assert_true(_all_still(main), "nor afterwards")


## R6's last sentence: the report after time away still tells what happened meanwhile, and nothing
## of it is announced.
func test_r6_the_away_report_still_tells() -> void:
	var played := Simulation.new(Main.SIMULATION_SEED)
	for i: int in 600:
		played.step()
	played.drain_events()
	var data: Dictionary = played.to_save()
	data[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system()
	assert_true(SaveStore.new(_save_path).write(data), "the test's save was written")
	var main: Main = MAIN_SCENE.instantiate()
	main.save_store = SaveStore.new(_save_path)
	main.away_seconds_override = 900.0
	add_child_autofree(main)
	for i: int in 2_000:
		if not main.is_catching_up():
			break
		await get_tree().process_frame
	assert_false(main.is_catching_up(), "the time away was replayed")
	await _frames()
	var report: AwayReport = main.away_report
	assert_not_null(report, "there is a report")
	var levels: int = 0
	for hero_id: int in report.levels_gained:
		levels += report.levels_gained[hero_id]
	assert_gt(levels, 0, "it tells of the levels gained meanwhile")
	assert_true(is_instance_valid(main.away_window) and main.away_window.is_open(), "and shows")
	assert_eq(main.ui.moment.bursts_seen(), 0, "none of it bursts")
	assert_true(_all_still(main), "or is announced")
	main.save_store = null


# --- R7 ------------------------------------------------------------------------


func test_r7_nothing_lost() -> void:
	var main: Main = _start()
	var knight: Hero = main.simulation.party.heroes[0]
	var frame: HeroFrameView = _frame_of(main, knight.id)
	var e: Expedition = main.simulation.expedition
	# A level and its talent point.
	_set_level(knight, 5)
	_frame(main)
	main.sound.drain_started()
	_earn_level(main, knight, 6)
	_frame(main)
	var sounds: Array[StringName] = main.sound.drain_started()
	assert_has(sounds, &"level_up", "the level's own sound")
	assert_gt(frame.level_pulse(), 0.0, "the level's old pulse")
	assert_true(_has_line(main, "Knight reached level 6"), "the journal's line for the level")
	assert_true(_has_line(main, "The Knight has a talent point to spend"), "and for the point")
	assert_eq(
		main.hud.journal.ticker_text(), "The Knight has a talent point to spend", "the ticker"
	)
	# A new safe stage.
	_raise(main, STRONG_LEVEL)
	e.stable_seconds = 2.0
	e.depth = 2
	e.target_depth = 2
	_frame(main)
	main.sound.drain_started()
	var world_effects: int = 0
	sounds.clear()
	for i: int in 2_000:
		_frame(main)
		sounds.append_array(main.sound.drain_started())
		if e.last_stable_depth == 2:
			world_effects = main.world.effects_layer.get_child_count()
			break
	assert_has(sounds, &"depth_stable", "the safe stage's own sound")
	assert_gt(world_effects, 0, "and the world's own banner")
	assert_true(_has_line(main, "Mossy Hollow 2 is now stable"), "the journal's line for it")
	# A guardian, and the area it opens.
	sounds.clear()
	var heard := func(_event: SimEvent) -> void: sounds.append_array(main.sound.drain_started())
	main.world.sim_event.connect(heard)
	assert_true(_slay_guardian(main), "the guardian is slain")
	_frame(main)
	sounds.append_array(main.sound.drain_started())
	main.world.sim_event.disconnect(heard)
	assert_has(sounds, &"guardian_slain", "the guardian's fanfare")
	assert_true(_has_line(main, "Slew the Slime King on Mossy Hollow 5"), "the journal's line")
	assert_true(_has_line(main, "The Claypits is open"), "and the area's, as it was")
	assert_eq(main.hud.area_map.news.unseen, 1, "the area map's mark")


# --- R8 ------------------------------------------------------------------------


func test_r8_fits_both_rooms() -> void:
	var guardian: String = ""
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if def.guardian and def.display_name.length() > guardian.length():
			guardian = def.display_name
	assert_false(guardian.is_empty(), "there is a guardian")
	for room: Vector2i in ROOMS:
		var main: Main = _start(room)
		var moment: UiMoment = main.ui.moment
		assert_true(_guardian_fight(main), "%s: a guardian fight, its bar showing" % room)
		_frame(main, 0)
		_frame(main, 0)
		for area: StringName in Content.area_ids():
			var def: AreaDef = Content.area(area)
			var banners: Array[PackedStringArray] = [
				[Milestones.beaten_text(guardian), Milestones.behind_text(area, 95)],
				[
					Milestones.beaten_text(guardian),
					Milestones.open_text([area] as Array[StringName])
				],
				[
					Milestones.open_text([area] as Array[StringName]),
					Milestones.gives_text(def.resource)
				],
			]
			for words: PackedStringArray in banners:
				var what: String = "%s, %s / %s" % [room, words[0], words[1]]
				moment.announce_picture(
					Milestones.guardian_picture(def.guardian), words[0], words[1]
				)
				moment.advance(0.0)
				moment.advance(0.5)
				assert_eq(moment.shown_headline(), words[0], "%s: it shows" % what)
				assert_eq(moment.banner_headline.text, words[0], "%s: the headline whole" % what)
				assert_eq(moment.banner_line.text, words[1], "%s: the line whole" % what)
				var box: Rect2 = moment.banner.get_global_rect()
				var all: Rect2 = Rect2(Vector2.ZERO, Vector2(room))
				assert_true(all.encloses(box), "%s: in the room %s" % [what, box])
				for label: Label in [moment.banner_headline, moment.banner_line]:
					var ink: Rect2 = _ink(label)
					assert_true(box.grow(0.5).encloses(ink), "%s: %s inside" % [what, label.name])
				assert_true(
					box.encloses(moment.banner_picture.get_global_rect()), "%s: its picture" % what
				)
				var pieces: Dictionary[String, Control] = _pieces(main)
				pieces["goals"] = main.hud.goals_view
				pieces["stage list"] = main.hud.ladder
				assert_true(pieces.has("boss bar"), "%s: the boss bar is one of them" % what)
				for piece: String in pieces:
					if not pieces[piece].is_visible_in_tree():
						continue
					assert_false(
						box.intersects(pieces[piece].get_global_rect()),
						"%s: clear of the %s %s" % [what, piece, pieces[piece].get_global_rect()]
					)
				moment.banner_clicked()
		main.free()


# --- R9 ------------------------------------------------------------------------


func test_r9_wiki_and_showcase() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for words: String in ["is beaten", "is behind you", "steps up", "pulses three times", "Safe"]:
		assert_true(wiki.contains(words), "the wiki tells of '%s'" % words)
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"guardian_fight")
	var moment: UiMoment = showcase.main.ui.moment
	var headlines: Dictionary[String, bool] = {}
	var with_banner: float = 0.0
	var start: float = showcase.elapsed
	var frame: float = 1.0 / 30.0
	while showcase.moment() == &"guardian_fight" and showcase.elapsed - start < 40.0:
		showcase.advance(frame)
		showcase.main.hud.advance(frame)
		showcase.main.milestones.advance(frame)
		moment.advance(frame)
		headlines[moment.shown_headline()] = true
		if moment.shown_headline() == "Slime King is beaten":
			with_banner += frame
	var fought: bool = showcase.evidence.get(&"guardian_fight", false)
	assert_true(fought, "the guardian's fight happened")
	assert_true(headlines.has("Slime King is beaten"), "its banner shows: %s" % [headlines.keys()])
	assert_gt(with_banner, 2.0, "for as long as a banner stays")

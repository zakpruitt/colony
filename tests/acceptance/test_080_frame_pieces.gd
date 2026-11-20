extends "res://tests/acceptance/frame_061_test_base.gd"
## Acceptance tests for specs/080-frame-pieces-and-an-idle-frame/spec.md, one per requirement, at
## both rooms.

## Frames an idle screen is watched for.
const WATCHED_FRAMES: int = 120
## Where each panel of the frame stood before the frame's pieces had a base type, by room and
## moment: at rest, with a line in the ticker, on a journey (the countdown hidden) and in a
## guardian fight (the boss bar up). Recorded from the code as it was.
const RECORDED: Dictionary[String, Dictionary] = {
	"960x540 rest":
	{
		"countdown": Rect2(311, 1, 141, 41),
		"goals": Rect2(6, 48, 230, 84),
		"place": Rect2(6, 1, 299, 41),
		"purse": Rect2(881, 1, 73, 41),
		"stages": Rect2(804, 48, 150, 312),
	},
	"960x540 ticker":
	{
		"countdown": Rect2(311, 1, 141, 41),
		"goals": Rect2(6, 48, 230, 84),
		"place": Rect2(6, 1, 299, 41),
		"purse": Rect2(881, 1, 73, 41),
		"stages": Rect2(804, 48, 150, 312),
		"ticker": Rect2(425, 463, 110, 19),
	},
	"960x540 journey":
	{
		"goals": Rect2(6, 48, 230, 84),
		"place": Rect2(6, 1, 299, 41),
		"purse": Rect2(881, 1, 73, 41),
		"stages": Rect2(804, 48, 150, 312),
		"ticker": Rect2(425, 463, 110, 19),
	},
	"960x540 guardian":
	{
		"boss": Rect2(415, 1, 268, 41),
		"countdown": Rect2(312, 1, 97, 41),
		"goals": Rect2(6, 48, 230, 115),
		"place": Rect2(6, 1, 300, 41),
		"purse": Rect2(881, 1, 73, 41),
		"stages": Rect2(804, 48, 150, 312),
	},
	"1280x720 rest":
	{
		"countdown": Rect2(311, 1, 141, 41),
		"goals": Rect2(6, 48, 230, 84),
		"place": Rect2(6, 1, 299, 41),
		"purse": Rect2(1201, 1, 73, 41),
		"stages": Rect2(1124, 48, 150, 312),
	},
	"1280x720 ticker":
	{
		"countdown": Rect2(311, 1, 141, 41),
		"goals": Rect2(6, 48, 230, 84),
		"place": Rect2(6, 1, 299, 41),
		"purse": Rect2(1201, 1, 73, 41),
		"stages": Rect2(1124, 48, 150, 312),
		"ticker": Rect2(585, 643, 110, 19),
	},
	"1280x720 journey":
	{
		"goals": Rect2(6, 48, 230, 84),
		"place": Rect2(6, 1, 299, 41),
		"purse": Rect2(1201, 1, 73, 41),
		"stages": Rect2(1124, 48, 150, 312),
		"ticker": Rect2(585, 643, 110, 19),
	},
	"1280x720 guardian":
	{
		"boss": Rect2(461, 1, 358, 41),
		"countdown": Rect2(312, 1, 97, 41),
		"goals": Rect2(6, 48, 230, 115),
		"place": Rect2(6, 1, 300, 41),
		"purse": Rect2(1201, 1, 73, 41),
		"stages": Rect2(1124, 48, 150, 312),
	},
}
## Where the first hero frame stood in each room; the others follow every FRAME_STEP pixels.
const FIRST_FRAME: Dictionary[String, Vector2] = {
	"960x540": Vector2(43, 486),
	"1280x720": Vector2(203, 666),
}
const FRAME_STEP: float = 220.0

## How many times the goals said they were read again while watched.
var _refreshes: int = 0


func after_each() -> void:
	_refreshes = 0
	super()


# --- Helpers -------------------------------------------------------------------


static func _room_name(room: Vector2i) -> String:
	return "%dx%d" % [room.x, room.y]


## The seven panels of the frame that show, each with its rect in the frame, by name.
func _rects(main: Main) -> Dictionary[String, Rect2]:
	var hud: Hud = main.hud
	var named: Dictionary[String, Control] = {
		"place": hud.place_panel,
		"countdown": hud.countdown,
		"purse": hud.purse,
		"boss": hud.boss_bar,
		"ticker": hud.ticker,
		"goals": hud.goals_view,
		"stages": hud.ladder,
	}
	var rects: Dictionary[String, Rect2] = {}
	for key: String in named:
		if named[key].visible:
			rects[key] = Rect2(named[key].position, named[key].size)
	return rects


## Every piece of [param main]'s frame is where it stood in [param room] at [param moment].
func _assert_where_it_was(main: Main, room: Vector2i, moment: String) -> void:
	var what: String = "%s %s" % [_room_name(room), moment]
	var rects: Dictionary[String, Rect2] = _rects(main)
	var recorded: Dictionary = RECORDED[what]
	var shown: Array = rects.keys()
	shown.sort()
	var kept: Array = recorded.keys()
	kept.sort()
	assert_eq(shown, kept, "%s: the same pieces show" % what)
	for key: String in recorded:
		var was: Rect2 = recorded[key]
		var now: Rect2 = rects.get(key, Rect2())
		assert_eq(now, was, "%s: the %s" % [what, key])
	var at: Vector2 = FIRST_FRAME[_room_name(room)]
	for i: int in main.hud.frames.size():
		var frame: HeroFrameView = main.hud.frames[i]
		var expected: Vector2 = at + Vector2(FRAME_STEP * i, 0)
		assert_eq(frame.position, expected, "%s: hero frame %d" % [what, i])


func _on_refreshed() -> void:
	_refreshes += 1


## The status line, the road to stable and the goals as one text, for an assertion's message.
func _said(hud: Hud) -> String:
	return (
		"%s | %s %s | %s"
		% [
			hud.place_panel.status_label.text,
			hud.countdown.note_label.text,
			hud.countdown.next_label.text,
			hud.goals.lines(),
		]
	)


# --- R1 ------------------------------------------------------------------------


func test_r1_every_piece_is_where_it_was() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		main.hud.advance(STEP)
		main.hud.advance(STEP)
		_assert_where_it_was(main, room, "rest")
		# Laid out in the other room and back.
		var other: Vector2i = ROOMS[1 - ROOMS.find(room)]
		main.ui.set_room_for_test(other)
		main.hud.advance(STEP)
		_assert_where_it_was(main, other, "rest")
		main.ui.set_room_for_test(room)
		main.hud.advance(STEP)
		_assert_where_it_was(main, room, "rest")
		main.hud.journal.announce("The party sets out")
		main.hud.advance(STEP)
		_assert_where_it_was(main, room, "ticker")
		var sim: Simulation = main.simulation
		sim.expedition.travel.open[&"claypits"] = true
		sim.set_destination(&"claypits", 1)
		_tick(main)
		_tick(main)
		_assert_where_it_was(main, room, "journey")
		main.free()
		main = _main(room)
		assert_true(_guardian_fight(main), "%s: a guardian fight" % room)
		_assert_where_it_was(main, room, "guardian")
		main.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_a_change_shows_on_the_next_frame() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var e: Expedition = sim.expedition
		var hero: Hero = sim.party.heroes[0]
		var what: String = _room_name(room)
		hud.advance(STEP)
		hud.advance(STEP)
		# Auto off, then on: the road to stable and the depth goal follow.
		sim.set_auto_push(false)
		hud.advance(STEP)
		assert_eq(hud.countdown.next_label.text, "staying on stage 1", "%s: auto off" % what)
		assert_eq(hud.goals.detail(0), "Auto is off", "%s: the goal says so" % what)
		sim.set_auto_push(true)
		hud.advance(STEP)
		assert_eq(hud.countdown.next_label.text, "then stage 2", "%s: auto on" % what)
		assert_string_starts_with(hud.goals.detail(0), "in ", "%s: the goal counts" % what)
		# Gold: an upgrade within reach.
		sim.party.gold = 100_000
		hud.advance(STEP)
		assert_has(hud.goals.lines(), "Buy an upgrade", "%s: gold: %s" % [what, _said(hud)])
		# A level: a talent point to spend.
		set_level_keeping_health(hero, 2)
		hud.advance(STEP)
		var spend: String = "Spend the %s's talent point" % hero.def().display_name
		assert_has(hud.goals.lines(), spend, "%s: a level: %s" % [what, _said(hud)])
		# The point spent: its goal goes.
		var first: StringName = Content.talent_tree(hero.class_id).trunk[0]
		sim.take_talent(hero.id, first)
		sim.step()
		hud.advance(STEP)
		assert_does_not_have(hud.goals.lines(), spend, "%s: the point spent" % what)
		# The target.
		e.target_depth = 3
		hud.advance(STEP)
		assert_eq(hud.place_panel.target_label.text, "3", "%s: the target" % what)
		assert_eq(
			hud.place_panel.status_label.text, "Heading on to stage 3", "%s: its status" % what
		)
		# The stage.
		e.depth = 3
		hud.advance(STEP)
		assert_eq(hud.place_panel.stage_label.text, "3", "%s: the stage" % what)
		assert_eq(hud.place_panel.status_label.text, "Hunting on stage 3", "%s: status" % what)
		assert_string_starts_with(
			hud.countdown.note_label.text, "Stable in ", "%s: the road: %s" % [what, _said(hud)]
		)
		main.free()


# --- R2, R3 ----------------------------------------------------------------------


func test_r3_a_new_piece_is_driven_like_the_rest() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = _room_name(room)
		for piece: Control in [
			hud.place_panel,
			hud.countdown,
			hud.purse,
			hud.boss_bar,
			hud.ticker,
			hud.goals_view,
			hud.ladder,
		]:
			assert_true(piece is FramePiece, "%s: %s is a frame piece" % [what, piece.name])
			assert_has(hud.pieces, piece, "%s: %s is in the list" % [what, piece.name])
		assert_eq(hud.pieces.size(), 7, "%s: seven pieces" % what)
		var counting := CountingPiece.new()
		hud.add_piece(counting)
		assert_eq(counting.tipped, 1, "%s: given its tips as it joins" % what)
		assert_eq(counting.get_parent(), hud.screen_frame, "%s: on the frame" % what)
		for i: int in 5:
			hud.advance(STEP)
		assert_eq(counting.advanced, 5, "%s: advanced once a frame" % what)
		assert_eq(counting.caught, 0, "%s: nothing to catch up on" % what)
		for i: int in World.STALL_TICKS + 1:
			main.simulation.step()
		hud.advance(STEP)
		assert_eq(counting.advanced, 6, "%s: advanced on the stalled frame too" % what)
		assert_eq(counting.caught, 1, "%s: caught up once after the stall" % what)
		assert_eq(counting.tipped, 1, "%s: tipped only once" % what)
		main.free()


# --- R4 ------------------------------------------------------------------------


func test_r4_an_idle_frame_is_not_laid_out() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = _room_name(room)
		for i: int in 3:
			hud.advance(STEP)
		var laid: int = hud.layouts
		for i: int in WATCHED_FRAMES:
			hud.advance(STEP)
		assert_lte(hud.layouts - laid, 1, "%s: an idle frame is not laid out" % what)
		laid = hud.layouts
		main.ui.set_room_for_test(ROOMS[1 - ROOMS.find(room)])
		for i: int in 3:
			hud.advance(STEP)
		assert_eq(hud.layouts - laid, 1, "%s: laid out once for a new room" % what)
		main.free()


# --- R5 ------------------------------------------------------------------------


func test_r5_idle_goals_build_nothing() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var what: String = _room_name(room)
		for i: int in 3:
			hud.advance(STEP)
		hud.goals.refreshed.connect(_on_refreshed)
		_refreshes = 0
		var built: int = Goals.built
		var asked: int = KeyBook.asked
		var worded: int = hud.worded
		for i: int in WATCHED_FRAMES:
			hud.advance(STEP)
		assert_eq(Goals.built - built, 0, "%s: no goal built" % what)
		assert_lte(_refreshes, 1, "%s: the goals refreshed at most once" % what)
		assert_eq(KeyBook.asked - asked, 0, "%s: KeyBook asked for nothing" % what)
		assert_eq(hud.worded - worded, 0, "%s: no status worded" % what)
		main.free()


# --- R6 ------------------------------------------------------------------------


func test_r6_an_open_talents_tab_is_still() -> void:
	for room: Vector2i in ROOMS:
		var main: Main = _main(room)
		var hud: Hud = main.hud
		var sim: Simulation = main.simulation
		var hero: Hero = sim.party.heroes[0]
		var what: String = _room_name(room)
		set_level_keeping_health(hero, 2)
		hud.hero_windows.open(hero.id, HeroWindow.Page.TALENTS)
		var tab: HeroTalentsTab = hud.hero_windows.window_of(hero.id).talents
		for i: int in 3:
			hud.advance(STEP)
			main.ui.advance(STEP)
		var first: StringName = Content.talent_tree(hero.class_id).trunk[0]
		var state: TalentNode.State = tab.tree.state_of(first)
		assert_eq(state, TalentNode.State.AVAILABLE, "%s: a node to take" % what)
		var worded: int = tab.worded
		var read: int = tab.tree.states_read
		for i: int in WATCHED_FRAMES:
			hud.advance(STEP)
			main.ui.advance(STEP)
		assert_eq(tab.worded - worded, 0, "%s: an idle tab formats nothing" % what)
		assert_eq(tab.tree.states_read - read, 0, "%s: and asks no node can_take" % what)
		# A point spent.
		sim.take_talent(hero.id, first)
		sim.step()
		hud.advance(STEP)
		assert_eq(tab.worded - worded, 1, "%s: the spent point is worded once" % what)
		assert_eq(tab.tree.states_read - read, 1, "%s: and read once" % what)
		state = tab.tree.state_of(first)
		assert_eq(state, TalentNode.State.TAKEN, "%s: the tree shows it" % what)
		assert_eq(tab.points_label.text, "Next point at level 4", "%s: the top line" % what)
		assert_ne(tab.strip.ability_id, first, "%s: the strip moves on" % what)
		# A point gained.
		set_level_keeping_health(hero, 4)
		hud.advance(STEP)
		assert_eq(tab.points_label.text, "1 point to spend", "%s: a point gained" % what)
		main.free()


# --- R7 ------------------------------------------------------------------------


func test_r7_one_owner_advances() -> void:
	for path: String in [
		"res://game/hud/crossing_veil.gd",
		"res://game/ui/frame/milestones.gd",
		"res://game/ui/ui_moment.gd",
	]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_false(text.contains("func _process("), "%s has no _process" % path.get_file())
	# A milestone and a moment, through Main's own frames.
	var main: Main = make_main()
	add_child_autofree(main)
	main.driver.set_process(false)
	await _wait_seconds(0.2)
	var sim: Simulation = main.simulation
	var panel: PlacePanel = main.hud.place_panel
	var safe: int = sim.expedition.last_stable_depth
	_emit(main, SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, safe + 1)
	assert_gt(panel.safe_step, 0.0, "a new safe stage steps up")
	assert_true(main.ui.moment.is_bursting(panel.safe_label), "and bursts")
	var stage: int = Content.area(sim.expedition.place).guardian_stage
	_emit(main, SimEvent.Kind.GUARDIAN_SLAIN, -1, -1, stage)
	await _wait_seconds(1.0)
	assert_eq(panel.safe_step, 0.0, "the step ran out")
	assert_false(main.ui.moment.is_bursting(panel.safe_label), "the burst ran out")
	var guardian: StringName = EncounterRoll.guardian_at(Content.area(sim.expedition.place), stage)
	assert_eq(
		main.ui.moment.shown_headline(),
		Milestones.beaten_text(Content.monster(guardian).display_name),
		"the guardian's banner shows"
	)
	main.free()
	# A crossing, through Main's own frames.
	main = make_main()
	add_child_autofree(main)
	main.simulation.expedition.travel.open[&"claypits"] = true
	main.simulation.set_destination(&"claypits", 1)
	var veil: CrossingVeil = main.hud.veil
	var darkest: float = 0.0
	for i: int in 30:
		await _wait_seconds(0.1)
		darkest = maxf(darkest, veil.darkness())
		if veil.visible and veil.darkness() >= 1.0:
			break
	assert_true(veil.visible, "the veil shows in a crossing")
	assert_gt(darkest, 0.5, "and darkens")
	assert_ne(veil.title_label.text, "", "with its title")
	main.free()


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- R8 ------------------------------------------------------------------------


func test_r8_small_leftovers() -> void:
	var texts: Dictionary[String, String] = {}
	scripts_in("res://game", texts)
	var lowering: Array[String] = []
	var clicks: Array[String] = []
	var declares := RegEx.create_from_string("func \\w*lower\\w*\\(")
	for path: String in texts:
		for found: RegExMatch in declares.search_all(texts[path]):
			lowering.append(path)
		for i: int in texts[path].count('"Click for details"'):
			clicks.append(path)
	assert_eq(lowering, ["res://game/ui/ui_format.gd"], "one lowering helper, on UiFormat")
	assert_eq(clicks.size(), 1, "one 'Click for details': %s" % [clicks])
	assert_false(ShownValues.new().has_method("forget"), "ShownValues has no forget")
	var hud_text: String = FileAccess.get_file_as_string("res://game/hud/hud.gd")
	assert_false(hud_text.contains("KEY_"), "the HUD names no key code: KeyBook has them")


class CountingPiece:
	extends FramePiece

	var advanced: int = 0
	var caught: int = 0
	var tipped: int = 0

	func advance(_delta: float) -> void:
		advanced += 1

	func catch_up() -> void:
		caught += 1

	func add_tips(_tips: UiTip) -> void:
		tipped += 1

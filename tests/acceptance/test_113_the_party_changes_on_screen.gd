extends "res://tests/acceptance/hero_windows_test_base.gd"
## Spec 113: everything on screen follows a change of the four going down. The hero who leaves
## fades away, the one who comes in fades in at its place and says a line; the frames, the hero
## windows and the tally show the new four; a benched hero has a window of its own; the journal
## says it; and a class with no pictures of its own is drawn as the class it looks like.

## The id a first recruit takes, and the Knight's, whose place it takes.
const RECRUIT: int = 5
const KNIGHT: int = 1
## Frames in which the camp sets up and the heroes sit before a swap is asked.
const SETTLE_FRAMES: int = 40
const KNIGHT_SHEET: String = CharacterSprite.HEROES_DIR + "/knight.png"

## Every event the world told, in order.
var _heard: Array[SimEvent] = []


func before_each() -> void:
	_heard.clear()
	_frame_parts = [&"effects", &"hud"]


# --- Helpers -------------------------------------------------------------------


## The main scene at 1280x720 with the test class's hero recruited onto the bench, the world
## past its first sync, and every event the world tells kept in [member _heard].
func _with_recruit() -> Main:
	var class_id: StringName = add_recruit_class()
	var main: Main = _main(ROOM_LARGE)
	main.world.sim_event.connect(func(event: SimEvent) -> void: _heard.append(event))
	var sim: Simulation = main.simulation
	sim.party.gold = RICH
	sim.party.set_resource(&"glowcaps", 50)
	ArtifactFinds._find(sim.expedition, class_id, KNIGHT)
	_frame(main)
	sim.roster.recruit(class_id)
	_frame(main)
	return main


## The party, all but down, starts to rest where it stands; the camp sets up and the heroes sit.
func _rest(main: Main) -> void:
	for hero: Hero in main.simulation.party.heroes:
		hero.health = 1
	main.simulation.expedition._start_rest()
	for i: int in SETTLE_FRAMES:
		_frame(main)
	assert_eq(main.simulation.expedition.state, Expedition.State.RESTING, "the party rests")


## Asks for [param coming] to go down in [param leaving]'s place and plays the frame of
## [param ticks] ticks it is made in; true when it was.
func _swap(main: Main, coming: int, leaving: int, ticks: int = 1) -> bool:
	_heard.clear()
	main.simulation.roster.swap(coming, leaving)
	_frame(main, ticks)
	return not _of_kind(_heard, SimEvent.Kind.HERO_FIELDED).is_empty()


## Plays [param seconds] of frames, a tick each.
func _play(main: Main, seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_frame(main)


## The world's puffs of a party change now in the effects.
func _puffs(main: Main) -> int:
	var found: int = 0
	for node: Node2D in main.world.fx.nodes(&"combat"):
		var particle: FxParticle = node as FxParticle
		if particle != null and particle.kind == RosterArrivals.PUFF_KIND:
			found += 1
	return found


## How many hero sprites under the world's characters are drawn from [param sheet_path].
func _sprites_of(main: Main, sheet_path: String) -> int:
	var sheet: PixelSheet = PixelSheet.load_sheet(sheet_path)
	var found: int = 0
	for child: Node in main.world.get_node("Characters").get_children():
		var sprite: CharacterSprite = child as CharacterSprite
		if sprite != null and sprite._sheet == sheet:
			found += 1
	return found


## The ids of [param heroes], in order.
static func _ids(heroes: Array[Hero]) -> Array[int]:
	var ids: Array[int] = []
	for hero: Hero in heroes:
		ids.append(hero.id)
	return ids


## Fails unless every frame shows the hero going down at its place: class, level, picture.
func _check_frames(main: Main, what: String) -> void:
	var heroes: Array[Hero] = main.simulation.party.heroes
	assert_eq(main.hud.frames.size(), heroes.size(), "%s: a frame each" % what)
	for i: int in mini(heroes.size(), main.hud.frames.size()):
		var frame: HeroFrameView = main.hud.frames[i]
		var hero: Hero = heroes[i]
		assert_eq(frame.hero_id, hero.id, "%s: frame %d's hero" % [what, i])
		assert_eq(frame.name_label.text, hero.def().display_name, "%s: frame %d" % [what, i])
		assert_eq(frame.level_label.text, "Lv %d" % hero.level, "%s: frame %d level" % [what, i])
		assert_eq(frame.icon_part(), hero.def().look(), "%s: frame %d picture" % [what, i])
		assert_string_contains(frame.tip_title(), hero.def().display_name)


## The tally's hero rows' names, top first.
static func _tally_names(main: Main) -> Array[String]:
	var names: Array[String] = []
	for row: String in main.hud.tally.rows().slice(1, 1 + main.hud.tally.hero_lines.size()):
		names.append(row.rsplit(" ", true, 2)[0])
	return names


static func _names_of(heroes: Array[Hero]) -> Array[String]:
	var names: Array[String] = []
	for hero: Hero in heroes:
		names.append(hero.def().display_name)
	return names


## True when [param journal] has a line that ends with [param sentence].
static func _written(journal: Journal, sentence: String) -> bool:
	for line: String in journal.lines():
		if line.ends_with(sentence):
			return true
	return false


## The tally's row for [param hero]: "<class> <number> <share>%".
static func _row_of(main: Main, hero: Hero) -> String:
	for row: String in main.hud.tally.rows():
		if row.begins_with(hero.def().display_name + " "):
			return row
	return ""


# --- R1 ------------------------------------------------------------------------


func test_r1_the_world_follows_a_swap() -> void:
	var main: Main = _with_recruit()
	var world: World = main.world
	assert_null(world.character(RECRUIT), "no sprite for a benched hero")
	_rest(main)
	var leaving: CharacterSprite = world.character(KNIGHT)
	var fire_place: Vector2 = world.camp.goal_for(KNIGHT, Vector2.INF)
	assert_true(world.camp.sits(KNIGHT), "the Knight sits at the fire")
	assert_true(_swap(main, RECRUIT, KNIGHT), "the swap is made")
	assert_false(world.catching_up(), "a frame that may animate")
	assert_null(world.character(KNIGHT), "the Knight is no character any more")
	assert_true(is_instance_valid(leaving) and leaving.is_inside_tree(), "its sprite fades")
	var coming: CharacterSprite = world.character(RECRUIT)
	assert_not_null(coming, "the recruit's sprite appears")
	if coming == null:
		return
	assert_eq(coming.position, fire_place, "at the Knight's place by the fire")
	assert_true(world.camp.sits(RECRUIT), "the place is the recruit's now")
	assert_eq(_puffs(main), 2, "a puff for each")
	var said: String = main.ui.bubbles.line_of(RECRUIT)
	assert_true(RosterArrivals.LINES.has(said), "a line from the table: %s" % said)
	assert_lt(coming.modulate.a, 0.5, "fading in")
	_play(main, RosterArrivals.FADE_SECONDS / 2.0)
	assert_between(coming.modulate.a, 0.2, 0.9, "half way in")
	assert_between(leaving.modulate.a, 0.1, 0.8, "half way out")
	_play(main, RosterArrivals.FADE_SECONDS)
	assert_eq(coming.modulate.a, 1.0, "faded in")
	assert_false(is_instance_valid(leaving), "the Knight's sprite is gone")
	assert_true(coming.sitting and coming.shown_sit() == 1.0, "the recruit sits by the fire")
	assert_eq(_sprites_of(main, KNIGHT_SHEET), 1, "the recruit's alone: nothing left")

	# A swap heard while catching up changes the sprites at once, with nothing else.
	_play(main, 1.0)
	assert_eq(_puffs(main), 0, "the puffs are over")
	assert_true(_swap(main, KNIGHT, RECRUIT, World.STALL_TICKS + 5), "swapped back")
	assert_true(world.catching_up(), "a stalled frame")
	assert_null(world.character(RECRUIT), "the recruit's sprite is gone at once")
	var back: CharacterSprite = world.character(KNIGHT)
	assert_not_null(back, "the Knight's is back")
	if back == null:
		return
	assert_eq(back.modulate.a, 1.0, "whole at once")
	assert_eq(back.position, fire_place, "at its place by the fire")
	assert_eq(_puffs(main), 0, "no puff")
	assert_eq(main.ui.bubbles.line_of(KNIGHT), "", "no line")
	_frame(main)
	assert_eq(_sprites_of(main, KNIGHT_SHEET), 1, "one sprite of the Knight's sheet")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_frames_follow() -> void:
	var main: Main = _with_recruit()
	var sim: Simulation = main.simulation
	set_level_keeping_health(sim.party.hero(RECRUIT), 7)
	_rest(main)
	_check_frames(main, "before")
	assert_true(_swap(main, RECRUIT, KNIGHT), "the swap is made")
	_check_frames(main, "after")
	assert_eq(main.hud.frames[0].hero_id, RECRUIT, "the recruit in the Knight's frame")
	assert_eq(main.hud.frames[0].level_label.text, "Lv 7", "with its level")
	main.hud.hero_windows.close_all()
	_click_frame(main, sim.party.hero(RECRUIT))
	assert_true(main.hud.hero_windows.is_open(RECRUIT), "a click opens the recruit's window")
	assert_false(main.hud.hero_windows.is_open(KNIGHT), "not the Knight's")


# --- R3 ------------------------------------------------------------------------


func test_r3_the_windows_follow() -> void:
	var main: Main = _with_recruit()
	var sim: Simulation = main.simulation
	var windows: HeroWindows = main.hud.hero_windows
	_rest(main)
	var knight: Hero = sim.party.hero(KNIGHT)
	var was: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var at: Vector2 = was.position
	assert_true(_swap(main, RECRUIT, KNIGHT), "the swap is made")
	main.hud.advance(STEP)
	var shown: HeroWindow = windows.window_of(RECRUIT)
	assert_not_null(shown, "the recruit has a window")
	if shown == null:
		return
	assert_eq(shown.window_id, HeroWindows.id_for(0), "the Knight's place's")
	assert_true(shown.is_open(), "still open")
	assert_eq(shown.position, at, "where it was")
	assert_eq(shown.page(), HeroWindow.Page.TALENTS, "on its tab")
	assert_string_contains(shown.line(&"class"), "Test Recruit")

	# The benched Knight's window.
	windows.open_hero(KNIGHT)
	var bench: HeroWindow = windows.window_of(KNIGHT)
	assert_not_null(bench, "the Knight has the bench window")
	if bench == null:
		return
	assert_eq(bench.window_id, HeroWindows.BENCH_ID, "hero_bench")
	assert_true(bench.is_open() and windows.top() == bench, "open in front")
	assert_eq(bench.line(&"activity"), "At camp", "at camp")
	assert_eq(bench.line(&"health"), "%d / %d" % [knight.max_health(), knight.max_health()])
	assert_eq(main.ui.windows.window(HeroWindows.BENCH_ID), bench, "a window like any other")

	# Tab goes round the four going down only.
	var seen: Array[int] = []
	for i: int in 5:
		_press(main, KEY_TAB)
		var top: HeroWindow = windows.top()
		assert_ne(top, bench, "Tab never opens the bench")
		if top != null:
			seen.append(top.hero_id)
	assert_eq(seen.slice(0, 4), _ids(sim.party.heroes), "Tab goes round the four")

	# The bench window's Talents tab plans the Knight's tree.
	set_level_keeping_health(knight, 40)
	knight.set_talents([] as Array[StringName])
	windows.open_hero(KNIGHT)
	_click(main, bench.tab_buttons[HeroWindow.Page.TALENTS])
	_frame(main)
	var first: StringName = Content.talent_tree(&"knight").path(0).nodes[0]
	_click(main, bench.talents.node(first).slot)
	_frame(main)
	assert_eq(knight.talents(), [first] as Array[StringName], "a click takes a node")
	var points: int = knight.paragon_points()
	assert_gt(points, 0, "a paragon point to spend")
	_press(main, KEY_1)
	_frame(main)
	assert_eq(knight.paragon_points(), points - 1, "a paragon key spends one")

	# A hero going down opens its place's window.
	var rogue: Hero = sim.party.heroes[1]
	windows.open_hero(rogue.id)
	assert_eq(windows.top().window_id, HeroWindows.id_for(1), "the rogue's place's window")
	windows.open_hero(99)
	assert_eq(windows.top().window_id, HeroWindows.id_for(1), "an unknown id does nothing")

	# The Knight goes down again: the bench window closes and its place's window shows it.
	windows.open_hero(KNIGHT)
	assert_true(_swap(main, KNIGHT, RECRUIT), "swapped back")
	main.hud.advance(STEP)
	assert_false(bench.is_open(), "the bench window closes")
	var place: HeroWindow = windows.window_of(KNIGHT)
	assert_eq(place.window_id if place != null else &"", HeroWindows.id_for(0), "hero_0 again")
	assert_string_contains(place.line(&"class") if place != null else "", "Knight")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_tally_follows() -> void:
	var main: Main = _with_recruit()
	var sim: Simulation = main.simulation
	var tally: TallyWindow = main.hud.tally
	main.ui.windows.open_window(TallyWindow.ID)
	_rest(main)
	var knight: Hero = sim.party.hero(KNIGHT)
	var recruit: Hero = sim.party.hero(RECRUIT)
	var counts: Tally = tally.tally
	counts.observe(SimEvent.new(SimEvent.Kind.ENCOUNTER_STARTED, sim.tick, -1, -1, 0))
	counts.observe(SimEvent.new(SimEvent.Kind.HIT, sim.tick, KNIGHT, 100, 70))
	assert_true(_swap(main, RECRUIT, KNIGHT), "the swap is made")
	main.hud.advance(STEP)
	assert_eq(_tally_names(main), _names_of(sim.party.heroes), "the rows are the four")
	assert_eq(tally.portraits[0].texture, main.hud.icon(&"knight"), "drawn as the Knight")
	assert_eq(_row_of(main, recruit), "Test Recruit 0 0%", "the recruit starts the fight at 0")
	tally.set_span(Tally.Span.SESSION)
	main.hud.advance(STEP)
	assert_eq(_row_of(main, knight), "", "the Knight has no row")

	# The recruit fights; the Knight comes back with its session's counts.
	tally.set_span(Tally.Span.LAST_FIGHT)
	counts.observe(SimEvent.new(SimEvent.Kind.ENCOUNTER_STARTED, sim.tick, -1, -1, 0))
	counts.observe(SimEvent.new(SimEvent.Kind.HIT, sim.tick, RECRUIT, 100, 30))
	main.hud.advance(STEP)
	assert_string_starts_with(_row_of(main, recruit), "Test Recruit 30 ")
	assert_true(_swap(main, KNIGHT, RECRUIT), "swapped back")
	main.hud.advance(STEP)
	assert_eq(_tally_names(main), _names_of(sim.party.heroes), "the four again")
	assert_eq(_row_of(main, knight), "Knight 0 0%", "back in the fight under way at 0")
	tally.set_span(Tally.Span.SESSION)
	main.hud.advance(STEP)
	assert_string_starts_with(_row_of(main, knight), "Knight 70 ")
	assert_eq(counts.value(RECRUIT, Tally.Measure.DAMAGE, Tally.Span.SESSION), 30, "kept")
	tally.open_hero(KNIGHT)
	main.hud.advance(STEP)
	assert_eq(tally.opened_hero(), KNIGHT, "the Knight's line opens")
	tally.hero_lines[0].emit_signal(&"pressed")
	assert_eq(tally.opened_hero(), -1, "a press on its row closes it")


# --- R5 ------------------------------------------------------------------------


func test_r5_the_journal_says_it() -> void:
	var main: Main = _with_recruit()
	var journal: Journal = main.hud.journal
	var found: String = "Found a Test Whistle: a Test Recruit waits at camp"
	assert_true(_written(journal, found), "the find: %s" % [journal.lines()])
	assert_true(_written(journal, "The Test Recruit joins the colony"), "the recruit")
	assert_eq(journal.ticker_text(), "The Test Recruit joins the colony", "in the ticker")
	_rest(main)
	assert_true(_swap(main, RECRUIT, KNIGHT), "the swap is made")
	var fielded: String = "The Test Recruit goes down in the Knight's place"
	assert_string_ends_with(journal.lines()[0], fielded)
	assert_eq(journal.ticker_text(), fielded, "in the ticker")


# --- R6 ------------------------------------------------------------------------


func test_r6_drawn_as_it_looks() -> void:
	var main: Main = _with_recruit()
	var sim: Simulation = main.simulation
	main.ui.windows.open_window(TallyWindow.ID)
	_rest(main)
	assert_true(_swap(main, RECRUIT, KNIGHT), "the swap is made")
	main.hud.advance(STEP)
	var recruit: Hero = sim.party.hero(RECRUIT)
	assert_eq(recruit.def().look(), &"knight", "the test class looks like the Knight")
	var sprite: CharacterSprite = main.world.character(RECRUIT)
	assert_not_null(sprite, "a sprite")
	if sprite == null:
		return
	assert_eq(sprite._sheet, PixelSheet.load_sheet(KNIGHT_SHEET), "the Knight's sheet")
	var frame: HeroFrameView = _frame_of(main, recruit)
	assert_eq(frame.icon.texture, main.hud.icon(&"knight"), "the Knight's picture on its frame")
	assert_eq(frame.name_label.text, "Test Recruit", "under its own name")
	var shown: HeroWindow = _open(main, recruit, HeroWindow.Page.STATS)
	assert_eq(shown.portrait.texture, main.hud.icon(&"knight"), "and in its window")
	assert_string_starts_with(shown.line(&"class"), "Test Recruit")
	assert_eq(shown.title, "Test Recruit", "its window's title")
	assert_eq(main.hud.tally.portraits[0].texture, main.hud.icon(&"knight"), "and the tally")
	assert_eq(_tally_names(main)[0], "Test Recruit", "under its name")
	_check_bench_picture(main)


## The bench window draws its hero as it looks too.
func _check_bench_picture(main: Main) -> void:
	var windows: HeroWindows = main.hud.hero_windows
	var knight: Hero = main.simulation.party.hero(KNIGHT)
	assert_true(_swap(main, KNIGHT, RECRUIT), "swapped back")
	windows.open_hero(RECRUIT)
	var bench: HeroWindow = windows.window_of(RECRUIT)
	assert_eq(bench.portrait.texture if bench != null else null, main.hud.icon(&"knight"))
	assert_eq(windows.window_of(knight.id).portrait.texture, main.hud.icon(&"knight"))


# --- R7 ------------------------------------------------------------------------


func test_r7_true_in_a_crowded_frame() -> void:
	var main: Main = _with_recruit()
	var sim: Simulation = main.simulation
	var windows: HeroWindows = main.hud.hero_windows
	main.ui.windows.open_window(TallyWindow.ID)
	for hero: Hero in sim.party.heroes:
		windows.open(hero.id)
	# A short rest begins: the swap is made on the frame's first tick, then the party walks on to
	# its first fight and wins it, and the Mage, one XP short of a level, levels.
	for hero: Hero in sim.party.heroes:
		hero.health = hero.max_health() * 9 / 10
	sim.expedition._start_rest()
	var mage: Hero = sim.party.heroes[2]
	mage.xp = Hero.xp_for_level(mage.level + 1) - 1
	var level: int = mage.level
	_heard.clear()
	sim.roster.swap(RECRUIT, KNIGHT)
	_frame(main, 300)
	main.hud.advance(STEP)
	assert_eq(_of_kind(_heard, SimEvent.Kind.HERO_FIELDED).size(), 1, "a swap in the frame")
	assert_false(_of_kind(_heard, SimEvent.Kind.LEVEL_UP).is_empty(), "a level")
	assert_false(_of_kind(_heard, SimEvent.Kind.ENCOUNTER_ENDED).is_empty(), "a fight")
	assert_gt(mage.level, level, "the Mage levelled")
	_check_frames(main, "the frame")
	for i: int in sim.party.heroes.size():
		var hero: Hero = sim.party.heroes[i]
		var shown: HeroWindow = windows.window_of(hero.id)
		assert_eq(shown.window_id if shown != null else &"", HeroWindows.id_for(i), "its window")
		if shown == null:
			continue
		assert_true(shown.is_open(), "%s: open" % hero.class_id)
		assert_eq(shown.line(&"level"), "Level %d" % hero.level, "%s: level" % hero.class_id)
		assert_string_starts_with(shown.line(&"class"), hero.def().display_name)
	assert_eq(_tally_names(main), _names_of(sim.party.heroes), "the tally's rows")
	assert_null(main.world.character(KNIGHT), "no sprite for the Knight")
	assert_not_null(main.world.character(RECRUIT), "one for the recruit")
	var framed: Array[int] = []
	for frame: HeroFrameView in main.hud.frames:
		framed.append(frame.hero_id)
	assert_false(framed.has(KNIGHT), "no frame for the Knight")
	assert_eq(_sprites_of(main, KNIGHT_SHEET), 1, "one sprite of the Knight's sheet")

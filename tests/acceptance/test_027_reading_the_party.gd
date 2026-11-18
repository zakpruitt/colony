extends GutTest
## Acceptance tests for specs/027-reading-the-party/spec.md, one per requirement.
##
## Most tests build a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, and step the simulation by hand. R6 and R7 also run the main scene, to see
## the game going on and every key reaching its owner.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 1
const STEP: float = 1.0 / 60.0
const STRONG_LEVEL: int = 40
## The longest a test waits for something to happen, in simulation ticks.
const LIMIT_TICKS: int = 6000
const KNIGHT: int = 1
const MAGE: int = 3

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
var _main: Main
var _was_muted: bool = false


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_hud = Hud.new()
	add_child_autofree(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_main = null
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	_was_muted = bus >= 0 and AudioServer.is_bus_mute(bus)


func after_each() -> void:
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, _was_muted)


# --- Helpers -------------------------------------------------------------------


## Raises every hero to [param level], at full health.
func _raise(level: int) -> void:
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


## Steps the simulation until [param done] returns true (true), or the limit (false). The HUD and
## the world are brought up to date after each tick, as a frame would.
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(0.1)
		_hud.advance(0.1)
		if done.call():
			return true
	return false


func _in_state(state: Expedition.State) -> Callable:
	return func() -> bool: return _sim.expedition.state == state


func _at_depth(depth: int) -> Callable:
	return func() -> bool:
		return (
			_sim.expedition.depth == depth and _sim.expedition.state == Expedition.State.TRAVELLING
		)


## Puts the party on [param depth] just outside its guardian's chamber, walking in, no auto-push.
func _before_guardian(depth: int) -> void:
	var e: Expedition = _sim.expedition
	var shaft: LabyrinthChamber = _sim.labyrinth.level(depth).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


## Takes a strong party down to depth 2, auto-push off, and leaves it travelling there.
func _down_to_two() -> bool:
	_raise(STRONG_LEVEL)
	_sim.set_auto_push(false)
	_sim.set_target_depth(2)
	return _step_until(_at_depth(2))


## Lets the party hunt on its depth for 10 s, away from where it landed, and stop out of a fight.
func _walk_away() -> void:
	var depth: int = _sim.expedition.depth
	var until: int = _sim.tick + 100
	_step_until(func() -> bool: return _sim.tick >= until and _at_depth(depth).call())


## Emits [param kind] as the world does, stamped [param age] ticks ago.
func _emit(kind: SimEvent.Kind, source: int, target: int, amount: int, age: int = 0) -> void:
	_world.sim_event.emit(SimEvent.new(kind, _sim.tick - age, source, target, amount))


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## Runs the main scene; the test's own world and HUD stop taking keys.
func _start_main() -> Main:
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.process_mode = Node.PROCESS_MODE_DISABLED
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)
	return _main


func _alive_monsters() -> int:
	var count: int = 0
	for monster: Combatant in _sim.expedition.battle.monsters:
		if monster.is_alive():
			count += 1
	return count


func _party_percent() -> int:
	var health: int = 0
	var most: int = 0
	for hero: Hero in _sim.party.heroes:
		health += hero.health
		most += hero.max_health()
	return floori(100.0 * health / most)


## Every rectangle in [param rects] is clear of [param rect].
func _clear_of(rect: Rect2, rects: Dictionary, what: String) -> void:
	for other_name: String in rects:
		var other: Rect2 = rects[other_name]
		assert_false(
			rect.intersects(other), "%s %s is clear of %s %s" % [what, rect, other_name, other]
		)


# --- R1 ------------------------------------------------------------------------


func test_r1_status_line() -> void:
	var e: Expedition = _sim.expedition
	_hud.advance(0.0)
	assert_eq(e.state, Expedition.State.TRAVELLING)
	assert_eq(_hud.status_text(), "Hunting on stage 1", "travelling at the target depth")
	assert_eq(_hud.place_panel.status_label.text, _hud.status_text(), "the panel shows the line")

	_raise(STRONG_LEVEL)
	_sim.set_auto_push(false)
	_sim.set_target_depth(2)
	_sim.step()
	_hud.advance(0.0)
	assert_eq(e.state, Expedition.State.TRAVELLING)
	assert_eq(_hud.status_text(), "Heading on to stage 2", "travelling toward a further target")

	assert_true(_step_until(_in_state(Expedition.State.FIGHTING)), "a fight starts")
	var count: int = _alive_monsters()
	assert_gt(count, 1, "with several monsters")
	assert_eq(_hud.status_text(), "Fighting %d monsters" % count, "fighting ordinary monsters")
	var healths: Array[int] = []
	for monster: Combatant in e.battle.monsters:
		healths.append(monster.health)
	for monster: Combatant in e.battle.monsters.slice(1):
		monster.health = 0
	_hud.advance(0.0)
	assert_eq(_hud.status_text(), "Fighting 1 monster", "one monster left")
	for i: int in healths.size():
		e.battle.monsters[i].health = healths[i]  # the fight goes on as it was

	assert_true(_step_until(_in_state(Expedition.State.CLIMBING)), "the party climbs")
	assert_eq(_hud.status_text(), "Going on to stage 2", "crossing to the next stage (spec 054)")
	assert_true(_step_until(_at_depth(2)), "and arrives")
	_walk_away()
	_sim.set_target_depth(1)
	assert_true(_step_until(_at_depth(2)), "on its way up, out of any fight")
	assert_eq(_hud.status_text(), "Heading back to stage 1", "toward an earlier target")
	assert_true(_step_until(_in_state(Expedition.State.CLIMBING)), "the party climbs back")
	assert_eq(_hud.status_text(), "Going back to stage 1", "crossing back (spec 054)")
	assert_true(_step_until(_at_depth(1)), "and arrives")

	# Resting: a won fight leaves the party hurt.
	_sim.set_target_depth(2)
	assert_true(_step_until(_in_state(Expedition.State.FIGHTING)), "another fight")
	for fighter: Combatant in e.battle.heroes:
		fighter.health = maxi(fighter.max_health / 4, 1)
	assert_true(_step_until(_in_state(Expedition.State.RESTING)), "the party rests")
	assert_eq(_hud.status_text(), "Resting, %d%% health" % _party_percent(), "with its health")
	assert_string_contains(_hud.status_text(), "Resting")

	# Wiped, once rested and on the move again.
	assert_true(_step_until(_in_state(Expedition.State.TRAVELLING)), "the rest ends")
	for hero: Hero in _sim.party.heroes:
		hero.health = 0
	assert_true(_step_until(_in_state(Expedition.State.REVIVING), 5), "the party is wiped")
	assert_eq(_hud.status_text(), "Chased home! Regrouping", "wiped, reviving")

	# A guardian, once the party is back on its feet.
	assert_true(_step_until(_in_state(Expedition.State.TRAVELLING)), "the party revives")
	_before_guardian(5)
	_raise(STRONG_LEVEL)
	assert_true(_step_until(_in_state(Expedition.State.FIGHTING)), "the guardian's fight starts")
	assert_eq(_hud.status_text(), "Fighting the Slime King", "fighting a guardian")


func test_r1_status_line_working() -> void:
	# Spec 025's side quests: the party stops to work, and the line names the quest.
	var e: Expedition = _sim.expedition
	_raise(STRONG_LEVEL)
	_sim.set_auto_push(false)
	var found: bool = false
	for depth: int in range(1, 6):
		for room: LabyrinthChamber in _sim.labyrinth.level(depth).chambers:
			if found or e.side_quest_in(depth, room.index) == &"":
				continue
			e.depth = depth
			e.target_depth = depth
			e.x = room.rect.position.x - 0.1
			e.facing = 1
			found = true
	assert_true(found, "a side quest near the top")
	assert_true(_step_until(_in_state(Expedition.State.WORKING), 50), "the party stops to work")
	var quest: SideQuestDef = Content.side_quest(e.working_quest())
	assert_eq(_hud.status_text(), "Working: %s" % quest.display_name, "working on a side quest")
	assert_eq(_hud.place_panel.status_label.text, _hud.status_text(), "the panel shows the line")


func test_r1_status_line_fits() -> void:
	# The guardian with the longest name, in a fight on its depth, with a wide gold count and the
	# longest stable text: the panel holds the line and stays clear of the boss bar and the shop.
	var longest: StringName = &""
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		var best: MonsterDef = Content.monster(longest) if longest != &"" else null
		if (
			def.guardian
			and (best == null or def.display_name.length() > best.display_name.length())
		):
			longest = id
	# Spec 049: guardians stand in their areas; the party goes to this one's.
	for area: StringName in Content.area_ids():
		if Content.area(area).guardian == longest:
			_sim.expedition.travel.open[area] = true
			_sim.set_destination(area, 1)
	assert_true(_step_until(_in_state(Expedition.State.JOURNEYING)), "the party leaves")
	assert_true(_step_until(_in_state(Expedition.State.TRAVELLING)), "and arrives")
	var depth: int = Expedition.GUARDIAN_EVERY
	assert_eq(_sim.expedition.guardian_of(depth), longest, "it guards its own area's stage 5")
	_before_guardian(depth)
	_raise(STRONG_LEVEL)
	assert_true(_step_until(_in_state(Expedition.State.FIGHTING)), "the guardian's fight starts")
	_sim.expedition.target_depth = depth
	_sim.set_auto_push(true)
	_sim.party.gold = 9_876_543
	_fx.coin_collected.emit(9_876_543)
	_hud.advance(0.0)
	var line: String = "Fighting the %s" % Content.monster(longest).display_name
	assert_eq(_hud.status_text(), line)
	assert_string_contains(_hud.stable_text(), "then stage %d" % (depth + 1))
	_check_depth_panel("a guardian fight")
	assert_true(_hud.boss_bar.is_showing(), "the boss bar shows")
	var panel: Rect2 = _hud.place_panel.get_global_rect()
	assert_false(panel.intersects(_hud.boss_bar.get_global_rect()), "clear of the boss bar")
	# Spec 049 names the area over the stage ("The Claypits" where "Depth" was), so the panel is
	# about 28 pixels wider and the bar, which fills the space left, that much narrower.
	assert_gt(_hud.boss_bar.get_global_rect().size.x, 130.0, "which is still wide")

	# Every other line, with a deep target: the widest the travelling lines get.
	var e: Expedition = _sim.expedition
	for state: Expedition.State in [Expedition.State.TRAVELLING, Expedition.State.REVIVING]:
		e.battle = null
		e.state = state
		e.depth = 4321
		e.target_depth = 9876
		_hud.advance(0.0)
		_check_depth_panel(_hud.status_text())


func _check_depth_panel(what: String) -> void:
	var panel: Rect2 = _hud.place_panel.get_global_rect()
	assert_true(
		panel.encloses(_hud.place_panel.status_label.get_global_rect()), "%s: the line fits" % what
	)
	for label: Control in [
		_hud.countdown.note_label, _hud.countdown.next_label, _hud.countdown.bar
	]:
		if label.visible:
			assert_true(
				_hud.countdown.get_global_rect().encloses(label.get_global_rect()),
				"%s: %s fits" % [what, label.name]
			)
	assert_lte(panel.end.y, Hud.TOP_BAND, "in the top band")
	assert_false(panel.intersects(_hud.purse.get_global_rect()), "%s: clear of gold" % what)


# --- R2 ------------------------------------------------------------------------


func test_r2_road_to_stable() -> void:
	var e: Expedition = _sim.expedition
	e.stable_seconds = 30.0
	_hud.advance(0.0)
	assert_eq(e.seconds_to_stable(), 0.0, "depth 1 is stable from the start")
	_sim.set_auto_push(false)
	_hud.advance(0.0)
	# Spec 039 R2: at the target with auto-push off, the note says the party stays.
	assert_eq(_hud.stable_text(), "Stable, staying on stage 1", "a stable depth reads Stable")
	assert_false(_hud.countdown.bar.visible, "with no bar")

	assert_true(_down_to_two(), "the party reaches depth 2")
	var arrived: int = _sim.tick
	_hud.advance(0.0)
	assert_almost_eq(e.seconds_to_stable(), 30.0, 0.001, "the whole time is still to hold")
	assert_eq(_hud.stable_text(), "Stable in 0:30", "counting from the arrival")
	assert_true(_hud.countdown.bar.visible, "with its bar")
	_step_until(func() -> bool: return _sim.tick >= arrived + 15)
	assert_almost_eq(e.seconds_to_stable(), 28.5, 0.001, "1.5 s later")
	assert_eq(_hud.stable_text(), "Stable in 0:29", "the text counts down")
	assert_almost_eq(_hud.stable_progress(), 1.5 / 30.0, 0.001, "and the bar fills")

	# Reading changes nothing.
	var before: int = _sim.state_hash()
	for i: int in 3:
		e.seconds_to_stable()
		_hud.stable_text()
		_hud.status_text()
	assert_eq(_sim.state_hash(), before, "reading leaves the state hash unchanged")

	# The simulation's own timing: the depth becomes stable exactly when the count runs out.
	var predicted: int = roundi(e.seconds_to_stable() * Simulation.TICKS_PER_SECOND)
	var started: int = _sim.tick
	var stable_at: int = -1
	for i: int in 600:
		_sim.step()
		for event: SimEvent in _sim.drain_events():
			if event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED and stable_at < 0:
				stable_at = event.tick
		if stable_at >= 0:
			break
	assert_eq(stable_at - started, predicted, "the count ends on the tick the depth turns stable")
	_hud.advance(0.0)
	assert_eq(e.seconds_to_stable(), 0.0, "0 at a stable depth")
	assert_eq(_hud.stable_text(), "Stable, staying on stage 2", "Stable (spec 039 R2)")
	assert_false(_hud.countdown.bar.visible, "no bar")

	# Auto-push: what happens next.
	e.last_stable_depth = 1
	e.target_depth = 2
	_sim.set_auto_push(true)
	_hud.advance(0.0)
	assert_string_starts_with(_hud.stable_text(), "Stable in ", "not stable again")
	assert_string_ends_with(_hud.stable_text(), ", then stage 3", "auto-push says what is next")
	_sim.set_auto_push(false)
	_hud.advance(0.0)
	assert_eq(_hud.stable_text().find("then"), -1, "not with auto-push off")


# --- R3 ------------------------------------------------------------------------


func test_r3_journal() -> void:
	var journal: Journal = _hud.journal
	assert_not_null(journal, "the HUD has a journal")
	if journal == null:
		return
	for i: int in 125:
		_sim.step()
	_sim.drain_events()
	_hud.advance(0.0)
	assert_eq(journal.lines().size(), 0, "nothing yet")
	assert_eq(journal.ticker_text(), "", "nothing showing")
	var upgrade: UpgradeDef = Content.upgrade(Content.upgrade_ids()[1])
	var slain: MonsterDef = Content.monster(_sim.expedition.guardian_of(5))

	_emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, 2)
	assert_eq(
		journal.lines()[0], "0:12  Reached Mossy Hollow 2, the furthest yet", "a new deepest depth"
	)
	_emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, 1)
	_emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, 2)
	assert_eq(journal.lines().size(), 1, "only a new deepest depth is written")
	_emit(SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 2)
	assert_eq(journal.lines()[0], "0:12  Mossy Hollow 2 is now stable", "a depth becoming stable")
	_emit(SimEvent.Kind.LEVEL_UP, -1, MAGE, 4)
	assert_eq(journal.lines()[0], "0:12  Mage reached level 4", "a level up")
	_sim.expedition.depth = 7
	_sim.expedition.last_stable_depth = 3
	_hud.advance(0.0)
	_emit(SimEvent.Kind.PARTY_WIPED, -1, -1, 0)
	# Spec 041 R6, spec 046 R6: the defeat note's first line (with no fight lost, only where),
	# then where the party falls back to.
	assert_eq(
		journal.lines()[0],
		"0:12  Beaten on Mossy Hollow 7; falling back to Mossy Hollow 3",
		"a wipe"
	)
	_sim.expedition.last_stable_depth = 7
	_hud.advance(0.0)
	_emit(SimEvent.Kind.PARTY_WIPED, -1, -1, 0)
	assert_eq(
		journal.lines()[0], "0:12  Beaten on Mossy Hollow 7; regrouping there", "on a stable depth"
	)
	_emit(SimEvent.Kind.GUARDIAN_SLAIN, 777, -1, 5)
	var guardian_line: String = "0:12  Slew the %s on Mossy Hollow 5" % slain.display_name
	assert_eq(journal.lines()[0], guardian_line, "a guardian slain")
	_emit(SimEvent.Kind.UPGRADE_BOUGHT, 1, -1, 2)
	var bought: String = "0:12  Bought %s, rank 2" % upgrade.display_name
	assert_eq(journal.lines()[0], bought, "an upgrade bought")
	_emit(SimEvent.Kind.HIT, 1, 100, 5)
	_emit(SimEvent.Kind.GOLD_GAINED, 100, -1, 5)
	assert_eq(journal.lines().size(), 7, "nothing else is written")

	# The ticker shows the newest for 4 seconds, then fades.
	assert_eq(journal.ticker_text(), "Bought %s, rank 2" % upgrade.display_name, "the newest")
	assert_true(_hud.ticker.visible, "on screen")
	journal.advance(3.9)
	assert_ne(journal.ticker_text(), "", "still showing at 3.9 s")
	journal.advance(1.0)
	assert_eq(journal.ticker_text(), "", "gone after 4 s and its fade")
	assert_false(_hud.ticker.visible, "off screen")

	# Old events go in the journal, not the ticker.
	_emit(SimEvent.Kind.LEVEL_UP, -1, KNIGHT, 9, World.ANIMATE_TICKS + 1)
	assert_eq(journal.lines()[0], "0:11  Knight reached level 9", "an old event is written")
	assert_eq(journal.ticker_text(), "", "but not shown")

	# The journal keeps the last 50, newest at the top. (Spec 058 moved its panel to a window on
	# the UI layer, which shows them all; J opening and closing it is tested there, in R8.)
	for level: int in range(10, 70):
		_emit(SimEvent.Kind.LEVEL_UP, -1, KNIGHT, level)
	assert_eq(journal.lines().size(), 50, "at most 50 lines are kept")
	assert_eq(journal.lines()[0], "0:12  Knight reached level 69", "newest first")
	assert_eq(journal.lines()[49], "0:12  Knight reached level 20", "the oldest kept")
	var view := JournalView.new()
	add_child_autofree(view)
	view.setup(journal)
	assert_eq(
		view.shown_lines(), journal.lines(), "the journal window shows them, newest at the top"
	)


# --- R4 ------------------------------------------------------------------------


func test_r4_frames_show_who_is_down() -> void:
	var frames: Array[HeroFrameView] = _hud.frames
	assert_eq(frames.size(), 4)
	_raise(5)
	_hud.advance(0.0)
	var knight: Hero = _sim.party.hero(KNIGHT)
	knight.health = 0
	_hud.advance(0.016)
	assert_true(frames[0].is_dimmed(), "a dead hero's frame is dimmed")
	assert_eq(frames[0].level_label.text, "Down", "and reads Down where the level was")
	for i: int in range(1, 4):
		assert_eq(frames[i].level_label.text, "Lv 5", "the living show their level")
		assert_false(frames[i].is_dimmed())

	for hero: Hero in _sim.party.heroes:
		hero.health = 0
	assert_true(_step_until(_in_state(Expedition.State.REVIVING), 5), "a wipe")
	for frame: HeroFrameView in frames:
		assert_eq(frame.level_label.text, "Recovering", "all four recover")
		assert_true(frame.is_dimmed())
	assert_true(_step_until(_in_state(Expedition.State.TRAVELLING), 100), "the revival")
	for frame: HeroFrameView in frames:
		assert_eq(frame.level_label.text, "Lv 5", "back to the level afterwards")
		assert_false(frame.is_dimmed())


# --- R5 ------------------------------------------------------------------------


func test_r5_marker() -> void:
	var marker: TargetMarker = _world.target_marker
	assert_not_null(marker, "the world has a marker")
	if marker == null:
		return
	_world.sync(0.0)
	assert_false(marker.visible, "hidden at the target depth")

	_raise(STRONG_LEVEL)
	_sim.set_auto_push(false)
	_sim.set_target_depth(2)
	_sim.step()
	_world.sync(0.1)
	assert_true(marker.visible, "shown for a deeper target")
	assert_eq(marker.pointing(), 1, "showing the way on (spec 054: sideways, not down)")
	var leader: Vector2 = _world.feet_position(KNIGHT)
	assert_lt(marker.position.y, leader.y - 24.0, "above the party's heads")
	var low: float = INF
	var high: float = -INF
	for hero: Hero in _sim.party.heroes:
		low = minf(low, _world.feet_position(hero.id).x)
		high = maxf(high, _world.feet_position(hero.id).x)
	assert_between(marker.position.x, low - 1.0, high + 1.0, "over the party")
	var heights: Dictionary[float, bool] = {}
	for i: int in 60:
		_world.sync(STEP)
		heights[marker.position.y - _world.feet_position(KNIGHT).y] = true
	assert_gt(heights.size(), 1, "it bobs")

	assert_true(_step_until(_in_state(Expedition.State.FIGHTING)), "a fight")
	assert_false(marker.visible, "hidden in a fight")
	assert_true(_step_until(_at_depth(2)), "the party reaches depth 2")
	assert_false(marker.visible, "hidden at the target depth")
	_walk_away()
	_sim.set_target_depth(1)
	assert_true(_step_until(_at_depth(2)), "on its way up, out of any fight")
	assert_true(marker.visible, "shown for a shallower target")
	assert_eq(marker.pointing(), -1, "showing the way back (spec 054: sideways, not up)")


# --- R6 ------------------------------------------------------------------------


func test_r6_it_fits() -> void:
	_before_guardian(5)
	_raise(STRONG_LEVEL)
	assert_true(_step_until(_in_state(Expedition.State.FIGHTING)), "a guardian fight")
	_hud.advance(0.0)
	assert_true(_hud.boss_bar.is_showing(), "the boss bar shows")
	assert_true(_hud.countdown.bar.visible, "depth 5 is not stable: the bar shows")
	_emit(SimEvent.Kind.UPGRADE_BOUGHT, 4, -1, 12)
	for level: int in 20:
		_emit(SimEvent.Kind.LEVEL_UP, -1, KNIGHT, level + 2)
	_emit(SimEvent.Kind.PARTY_WIPED, -1, -1, 0)
	_hud.advance(0.0)
	assert_true(_hud.ticker.visible, "the ticker shows")

	var frames: Dictionary = {}
	for frame: HeroFrameView in _hud.frames:
		frames[frame.name] = frame.get_global_rect()
	var top: Dictionary = {
		"gold": _hud.purse.get_global_rect(),
		"boss bar": _hud.boss_bar.get_global_rect(),
	}
	var depth: Rect2 = _hud.place_panel.get_global_rect()
	var shop: Rect2 = _hud.shop.get_global_rect()
	var ticker: Rect2 = _hud.ticker.get_global_rect()
	var bar: Rect2 = _hud.countdown.bar.get_global_rect()
	_clear_of(ticker, frames, "ticker")
	_clear_of(ticker, top, "ticker")
	_clear_of(ticker, {"depth panel": depth, "shop": shop}, "ticker")
	_clear_of(bar, frames, "stable bar")
	_clear_of(bar, top, "stable bar")
	_clear_of(bar, {"shop": shop}, "stable bar")
	assert_true(
		_hud.countdown.get_global_rect().encloses(bar), "the stable bar is in the depth panel"
	)
	for rect: Rect2 in [ticker, bar]:
		assert_true(Rect2(Vector2.ZERO, Hud.SCREEN).encloses(rect), "on the screen")
	# (Spec 058: the journal is a window on the UI layer now, which floats over the HUD and the
	# shop beside it, as the hero windows of spec 060 do; where windows go is tested there.)

	# The game goes on with the journal open.
	var main: Main = _start_main()
	main.ui.windows.open_window(UiRoot.JOURNAL)
	main.driver.advance(0)
	var before: int = main.simulation.tick
	main.driver.advance(2_000_000)
	assert_true(main.ui.windows.is_open(UiRoot.JOURNAL), "the journal is open")
	assert_gt(main.simulation.tick, before, "and the ticks go on")


# --- R7 ------------------------------------------------------------------------


func test_r7_keys() -> void:
	var main: Main = _start_main()
	var sim: Simulation = main.simulation
	var windows: UiWindows = main.ui.windows
	main.hud.advance(0.0)
	_key(KEY_J)
	assert_true(windows.is_open(UiRoot.JOURNAL), "J opens the journal")

	var target: int = sim.expedition.target_depth
	_key(KEY_EQUAL)
	sim.step()
	assert_eq(sim.expedition.target_depth, target + 1, "= raises the target")
	_key(KEY_MINUS)
	sim.step()
	assert_eq(sim.expedition.target_depth, target, "- lowers it")
	var auto: bool = sim.expedition.auto_push
	_key(KEY_A)
	assert_ne(sim.expedition.auto_push, auto, "A switches auto-push")
	var zoom: int = main.world.camera.zoom_level()
	_key(KEY_Z)
	assert_ne(main.world.camera.zoom_level(), zoom, "Z zooms")
	var muted: bool = main.sound.is_muted()
	_key(KEY_M)
	assert_ne(main.sound.is_muted(), muted, "M mutes")
	assert_true(windows.is_open(UiRoot.JOURNAL), "the journal stays open through them all")
	_key(KEY_ESCAPE)
	assert_false(windows.is_open(UiRoot.JOURNAL), "Esc closes it")
	main.hud.hero_windows.open(KNIGHT)  # spec 060: a hero's sheet is its window
	_key(KEY_ESCAPE)
	assert_false(main.hud.hero_windows.is_open(KNIGHT), "Esc closes a hero window too")
	_key(KEY_J)
	assert_true(windows.is_open(UiRoot.JOURNAL))
	_key(KEY_U)
	main.hud.advance(0.0)
	assert_true(main.hud.shop.is_open(), "U opens the shop")

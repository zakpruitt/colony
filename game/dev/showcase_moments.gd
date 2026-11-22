class_name ShowcaseMoments
extends RefCounted
## How each of the [Showcase]'s moments begins and how it is known to have been seen, as its row
## in [constant Showcase.ROWS] names them (&"x" in the row calls [code]_begin_x[/code] or
## [code]_watch_x[/code] here), and the cuts they make: stepping the simulation to a fight, a
## depth, an area, the way on or a side quest at once. A cut that places the party gives it a
## distance along its stage's course and the way it travels along it, never a world column. The
## showcase hands it its [Main].

## The areas of the band fights (one in each area after the first, each its own look), and the
## stage each is fought on there.
const BAND_AREAS: Dictionary[StringName, StringName] = {
	&"clay_fight": &"claypits", &"stone_fight": &"old_crypt", &"deep_fight": &"ember_deep"
}
const BAND_STAGE: int = 3
## Seconds each area is shown in the four areas' moment, and the heroes' level there.
const AREA_SECONDS: float = 1.0
const AREA_LEVEL: int = 20
## The hero level used in a band's fight, so it lasts long enough to watch.
const BAND_LEVELS: Dictionary[StringName, int] = {
	&"clay_fight": 8, &"stone_fight": 13, &"deep_fight": 18
}
## The depth of the guardian's fight (the first guardian's), and the heroes' level there: strong
## enough to stand, not to end it before it has been seen.
const GUARDIAN_DEPTH: int = Expedition.GUARDIAN_EVERY
const GUARDIAN_LEVEL: int = 10
## Seconds the guardian's fight is watched before the guardian is made to fall.
const GUARDIAN_WATCH: float = 3.2
## The side quest each quest moment walks into, and the depth its search starts from.
const QUEST_OF: Dictionary[StringName, StringName] = {
	&"quest_done": &"locked_chest",
	&"quest_missed": &"locked_chest",
	&"tripwire_sprung": &"tripwire",
	&"microskill_learned": &"rune_stone",
}
const QUEST_DEPTH: int = 2
## The level of the heroes in the quest moments (all four can then do every quest), and the
## deepest depth searched for a quest.
const QUEST_LEVEL: int = 6
const QUEST_SEARCH: int = 40
## The rogue's id, and the level of its first microskill.
const ROGUE: int = 2
const FIRST_SKILL_LEVEL: int = 2
## How many tiles of course before a quest's chamber the party is put, at most, so the walk in
## shows.
const QUEST_APPROACH: float = 3.0
## How many tiles of course before the room that lights the party is put.
const ROOM_APPROACH: float = 2.0
## The side path moments: the stage their search starts from, the heroes' level (every
## microskill learned), and how many tiles of course short of where the path leaves the party is
## put.
const GATE_DEPTH: int = 2
const GATE_LEVEL: int = 12
const GATE_APPROACH: float = 2.5
## The gate a level-1 rogue learns to open within a fight or two: not the one to show sealed.
const SOON_OPENED: StringName = &"locked_gate"
## How many tiles of course outside a guardian's chamber the party is put.
const GUARDIAN_APPROACH: float = 1.0
## The depth the climbs happen from (down to the next and back up).
const CLIMB_DEPTH: int = 2
## How many tiles of course short of the way on the cut to a climb stops, so the walk to the
## doorway shows.
const WAY_ON_APPROACH: float = 4.0
## The most ticks stepped at once to cut to the next fight.
const CUT_TICKS: int = 1200
## The area the map moments open and the journey goes to.
const NEW_AREA: StringName = &"claypits"
## The gold the shop moment gives the party, enough for a few ranks.
const SHOP_GOLD: int = 300
## The upgrade the shop moment buys, and the rank it reaches, a milestone with a banner.
const SHOP_UPGRADE: StringName = &"sharp_blades"
const SHOP_RANK: int = 5
## In a class's moment: the heroes' level (every talent point earned), how many different moves
## the class's hero's abilities make (an action's among them) before its moment is seen, and the
## stage of the fight.
const CLASS_LEVEL: int = 14
const CLASS_MOVES_SEEN: int = 2
const CLASS_STAGE: int = 2
## The tree's moment: the knight's level (four talent points), and seconds between its clicks
## (long enough to see each node burst, short enough for test_018's limit).
const TREE_LEVEL: int = 8
const TREE_STEP: float = 0.6

## The game the showcase runs.
var main: Main

## The moment being started or watched, and, while it is watched, the seconds it has shown and
## those since it was seen (-1 before).
var _moment: StringName = &""
var _moment_time: float = 0.0
var _since: float = -1.0
## Set by a watch once its moment has been seen.
var _seen: bool = false
## True once the journey's map has been opened on the way.
var _map_on_the_way: bool = false
## The tree's moment: the clicks made so far.
var _tree_clicks: int = 0
## A class's moment: the moves of the abilities its hero has used so far, and whether
## one was an action.
var _moves_used: Dictionary[StringName, bool] = {}
var _actions_used: bool = false
## The four areas' moment: the area being shown (an index into the areas), and those seen.
var _area_turn: int = -1
var _areas_seen: Dictionary[StringName, bool] = {}


## Begins moment [param current] as its row's [param how] says (&"" for nothing to do).
func begin(how: StringName, current: StringName) -> void:
	_moment = current
	_moves_used.clear()
	_actions_used = false
	if how != &"":
		call("_begin_%s" % how, current)


## True once moment [param current], watched as its row's [param how] says, has been seen: told
## of [param event], or with null of the frame's state. [param moment_time] is the seconds it has
## shown, [param since_seen] those since it was seen (-1 before).
func watch(
	how: StringName, current: StringName, event: SimEvent, moment_time: float, since_seen: float
) -> bool:
	_moment = current
	_moment_time = moment_time
	_since = since_seen
	_seen = false
	call("_watch_%s" % how, event)
	return _seen


# --- How each moment begins ---------------------------------------------------


func _begin_level_up(_current: StringName) -> void:
	# The front hero is one XP short of its next level: the next kill pays for it.
	var hero: Hero = main.simulation.party.heroes[0]
	hero.xp = Hero.xp_for_level(hero.level + 1) - 1


func _begin_climb_down(_current: StringName) -> void:
	settle_now()
	_cut_to_depth(CLIMB_DEPTH, CLIMB_DEPTH + 1)
	_cut_to_way_on()


func _begin_climb_up(_current: StringName) -> void:
	main.simulation.set_target_depth(CLIMB_DEPTH)


func _begin_wipe(_current: StringName) -> void:
	for hero: Hero in main.simulation.party.heroes:
		hero.health = 0


func _begin_depth_stable(_current: StringName) -> void:
	var expedition: Expedition = main.simulation.expedition
	main.simulation.set_auto_push(false)
	expedition.last_stable_depth = expedition.depth - 1
	expedition.stable_seconds = 1.0


func _begin_band(current: StringName) -> void:
	main.simulation.expedition.stable_seconds = 600.0
	settle_now()
	for hero: Hero in main.simulation.party.heroes:
		hero.level = BAND_LEVELS[current]
		hero.health = hero.max_health()
	_cut_to_area(BAND_AREAS[current])
	_cut_to_depth(BAND_STAGE, BAND_STAGE)
	cut_to_fight()


## A class's moment, or the statuses': every hero at CLASS_LEVEL, the class's own hero with its
## trunk and path taken.
func _begin_class(current: StringName) -> void:
	settle_now()
	_cut_to_area(AreaTravel.first_area())
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, CLASS_LEVEL)
		hero.set_talents([])
		if Showcase.CLASS_MOMENTS.get(current, &"") == hero.class_id:
			var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
			var nodes: Array[StringName] = tree.trunk.duplicate()
			nodes.append_array(tree.path_nodes(Showcase.CLASS_PATHS[hero.class_id]))
			hero.set_talents(nodes)
	_cut_to_depth(CLASS_STAGE, CLASS_STAGE)
	cut_to_fight()


func _begin_guardian(_current: StringName) -> void:
	settle_now()
	_cut_to_area(AreaTravel.first_area())
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, GUARDIAN_LEVEL)
	_cut_to_depth(GUARDIAN_DEPTH, GUARDIAN_DEPTH + 1)
	_cut_to_guardian()


func _begin_quest(current: StringName) -> void:
	settle_now()
	var sim: Simulation = main.simulation
	for hero: Hero in sim.party.heroes:
		_set_level(hero, QUEST_LEVEL)
	var rogue: Hero = sim.party.hero(ROGUE)
	if current != &"quest_done":
		# Nobody else picks locks or spots traps: at level 1, neither does the rogue.
		_set_level(rogue, 1)
	if current == &"microskill_learned":
		# One XP short of level 2, and Lockpicker: the rune stone's XP pays for it.
		rogue.xp = Hero.xp_for_level(FIRST_SKILL_LEVEL) - 1
	_cut_to_quest(QUEST_OF[current])


## The party a few steps short of the widest room of its stage that it has not stood in, so the
## most torches catch.
func _begin_room(_current: StringName) -> void:
	settle_now()
	var sim: Simulation = main.simulation
	sim.set_auto_push(false)
	_cut_to_depth(sim.expedition.depth, sim.expedition.depth)
	settle_now()
	var rooms: Array[LabyrinthChamber] = sim.labyrinth.level(sim.expedition.depth).chambers
	var widest: LabyrinthChamber = rooms[1]
	for room: LabyrinthChamber in rooms.slice(1):
		if room.rect.size.x > widest.rect.size.x:
			widest = room
	_stand_before(widest.index, ROOM_APPROACH)


## A side path: the party a few steps short of one, able to open its gate, or, for the sealed
## gate's moment, with the heroes who would learn its microskill back at level 1.
func _begin_gate(current: StringName) -> void:
	settle_now()
	var sim: Simulation = main.simulation
	var sealed: bool = current == &"gate_sealed"
	for depth: int in range(GATE_DEPTH, QUEST_SEARCH + 1):
		var paths: Array[SidePath] = sim.labyrinth.level(depth).side_paths
		for index: int in paths.size():
			var gate: GateDef = Content.gate(paths[index].gate)
			var full: bool = SidePathRules.is_full(sim.expedition, depth, index)
			if not full or (sealed and gate.id == SOON_OPENED):
				continue
			for hero: Hero in sim.party.heroes:
				var learns: bool = hero.def().microskills.has(gate.microskill)
				_set_level(hero, 1 if sealed and learns else GATE_LEVEL)
			sim.set_auto_push(false)
			_cut_to_depth(depth, depth)
			settle_now()
			var line: StageCourse = PartyPlaces.course(sim.expedition)
			sim.expedition.x = clampf(paths[index].at - GATE_APPROACH, line.start, line.end)
			sim.expedition.facing = 1
			return


## The side path moments are over: the heroes sent back to level 1 are the others' level again.
func end_gates() -> void:
	settle_now()
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, QUEST_LEVEL)


## True while moment [param current] waits for the party to walk to a side path, to its gate or
## on to its cache: the fights on the way are ended at once, and the walk is hurried.
func walks_to_a_gate(current: StringName) -> bool:
	if current not in [&"gate_opened", &"cache_opened", &"gate_sealed"]:
		return false
	var expedition: Expedition = main.simulation.expedition
	if (
		expedition.state == Expedition.State.FIGHTING
		or expedition.state == Expedition.State.RESTING
	):
		settle_now()
	return expedition.state == Expedition.State.TRAVELLING


## The shop's window, gold for a few ranks, and the first row bought: Sharp Blades' fifth rank,
## so the card bursts and a banner drops in.
func _begin_shop(_current: StringName) -> void:
	settle_now()
	var sim: Simulation = main.simulation
	sim.party.gold = SHOP_GOLD
	sim.upgrades.set_rank(SHOP_UPGRADE, SHOP_RANK - 1)
	var bones: StringName = Content.upgrade(SHOP_UPGRADE).resource
	sim.party.set_resource(bones, sim.upgrades.resource_cost(SHOP_UPGRADE))
	main.hud.shop.open()
	main.hud.shop.buy_row(0)


func _begin_area_map(_current: StringName) -> void:
	settle_now()
	main.simulation.expedition.travel.open[NEW_AREA] = true
	main.hud.area_map.open()
	main.hud.area_map.choose(NEW_AREA)


func _begin_journey(_current: StringName) -> void:
	settle_now()
	_map_on_the_way = false
	main.simulation.expedition.travel.open[NEW_AREA] = true  # on its own too, after skip_to
	main.hud.area_map.open()
	main.hud.area_map.choose(NEW_AREA)
	main.hud.area_map.go()


func _begin_four_areas(_current: StringName) -> void:
	settle_now()
	main.simulation.set_auto_push(false)
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, AREA_LEVEL)
	_area_turn = -1
	_areas_seen.clear()


## The knight at level 8 with two trunk nodes taken and two points to spend: one for the last
## trunk node, one for a path.
func _begin_talent_tree(_current: StringName) -> void:
	settle_now()
	var knight: Hero = main.simulation.party.heroes[0]
	_set_level(knight, TREE_LEVEL)
	var trunk: Array[StringName] = Content.talent_tree(knight.class_id).trunk
	knight.set_talents(trunk.slice(0, 2))
	main.hud.hero_windows.open(knight.id, HeroWindow.Page.TALENTS)
	_tree_clicks = 0


## The report after time away, as a window over the game.
func _begin_away_report(_current: StringName) -> void:
	settle_now()
	main.away_window = main.ui.show_away(_away_report(), main.simulation.party)


# --- How each moment is seen --------------------------------------------------


func _watch_travelling(event: SimEvent) -> void:
	var expedition: Expedition = main.simulation.expedition
	if event == null and expedition.state == Expedition.State.TRAVELLING:
		if expedition.chamber() == null:
			_seen = true


func _watch_crit(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.HIT and event.flag:
		_seen = true


func _watch_heal(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.HEALED and event.amount > 0:
		_seen = true


func _watch_resting(event: SimEvent) -> void:
	if event == null and main.simulation.expedition.state == Expedition.State.RESTING:
		_seen = true


func _watch_climb(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.DEPTH_CHANGED:
		var wanted: int = CLIMB_DEPTH + (1 if _moment == &"climb_down" else 0)
		if event.amount == wanted:
			_seen = true


func _watch_band(event: SimEvent) -> void:
	var expedition: Expedition = main.simulation.expedition
	if (
		event == null
		and expedition.state == Expedition.State.FIGHTING
		and expedition.battle != null
		and expedition.place == BAND_AREAS[_moment]
	):
		_seen = true


func _watch_guardian(event: SimEvent) -> void:
	var guardian: Combatant = GuardianSpacing.fighting_guardian(main.simulation)
	if event == null and guardian != null:
		_seen = true
		if _since >= GUARDIAN_WATCH:
			guardian.health = mini(guardian.health, 1)  # it falls, for its banner


func _watch_class(event: SimEvent) -> void:
	if event == null or event.kind != SimEvent.Kind.ABILITY_USED:
		return
	var ability: AbilityDef = Content.ability(event.ability_id)
	var hero: Hero = main.simulation.party.hero(event.source_id)
	if ability == null or hero == null or not main.world.may_animate(event):
		return
	if hero.class_id == Showcase.CLASS_MOMENTS[_moment]:
		_moves_used[ability.move] = true
		_actions_used = _actions_used or ability.is_action()
		if _actions_used and _moves_used.size() >= CLASS_MOVES_SEEN:
			_seen = true


func _watch_statuses(event: SimEvent) -> void:
	if event != null:
		return
	var seen: Dictionary[int, bool] = {}
	var marks: StatusMarks = main.effects.ability_effects.marks
	for id: int in marks.book.fighters():
		for kind: int in marks.shown(id):
			seen[kind] = true
	if seen.size() == AbilityEffect.Status.size():
		_seen = true


func _watch_stable(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED:
		_seen = true


func _watch_room(event: SimEvent) -> void:
	if event == null and main.world.ambience.rooms.flares() > 0:
		_seen = true


func _watch_quest_done(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.SIDE_QUEST_DONE:
		_seen = true


func _watch_learned(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.MICROSKILL_LEARNED:
		_seen = true


func _watch_missed(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.SIDE_QUEST_MISSED and not event.flag:
		_seen = true


func _watch_sprung(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.SIDE_QUEST_MISSED and event.flag:
		_seen = true


func _watch_shop(event: SimEvent) -> void:
	if event == null or event.kind != SimEvent.Kind.UPGRADE_BOUGHT:
		return
	if main.hud.shop.is_open() and event.amount == SHOP_RANK:
		_seen = true


func _watch_area_map(event: SimEvent) -> void:
	if event == null and main.hud.area_map.is_open():
		_seen = true


## On the way, the map shows where to and how long; the arrival is the moment.
func _watch_journey(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.AREA_CHANGED:
		_seen = true
	var journeying: bool = main.simulation.expedition.state == Expedition.State.JOURNEYING
	if event == null and journeying and not _map_on_the_way:
		_map_on_the_way = true
		main.hud.area_map.open()


func _watch_four_areas(event: SimEvent) -> void:
	if event == null:
		_show_areas()


func _watch_talent_tree(event: SimEvent) -> void:
	if event == null:
		_click_through_tree()
		return
	var tree: TalentTreeDef = Content.talent_tree(main.simulation.party.heroes[0].class_id)
	if event.kind == SimEvent.Kind.TALENT_TAKEN and tree.path_of(event.ability_id) >= 0:
		_seen = true


func _watch_away_report(event: SimEvent) -> void:
	if event == null and is_instance_valid(main.away_window) and main.away_window.is_open():
		_seen = true


# --- Cuts ----------------------------------------------------------------------


## Ends any fight and rest at once, stepping the simulation (the world snaps to the result).
func settle_now() -> void:
	var sim: Simulation = main.simulation
	for i: int in CUT_TICKS:
		var expedition: Expedition = sim.expedition
		if expedition.state == Expedition.State.FIGHTING and expedition.battle != null:
			for monster: Combatant in expedition.battle.monsters:
				if monster.is_alive():
					monster.health = 1
		elif expedition.state == Expedition.State.RESTING:
			for hero: Hero in sim.party.heroes:
				hero.health = hero.max_health()
		else:
			return
		sim.step()


## Stands the party at the arrival point of [param depth], heading for [param target].
func _cut_to_depth(depth: int, target: int) -> void:
	var sim: Simulation = main.simulation
	var expedition: Expedition = sim.expedition
	var deepest: int = maxi(expedition.deepest_depth, depth)
	Arrival.from_save(expedition, sim.tick, depth, deepest, target, false)
	for hero: Hero in sim.party.heroes:
		hero.health = hero.max_health()
	# More ticks at once than the world animates: it puts everything in place.
	for i: int in World.STALL_TICKS + 1:
		sim.step()


## Steps the simulation until the party is in a fight.
func cut_to_fight() -> void:
	var sim: Simulation = main.simulation
	for i: int in CUT_TICKS:
		if sim.expedition.state == Expedition.State.FIGHTING:
			return
		sim.step()


## Steps the simulation (ending any fight on the way at once) until the party is a few tiles of
## course short of the way on from its stage, or leaving by it.
func _cut_to_way_on() -> void:
	var sim: Simulation = main.simulation
	for i: int in CUT_TICKS:
		var expedition: Expedition = sim.expedition
		if expedition.state == Expedition.State.CLIMBING:
			return
		if expedition.state == Expedition.State.TRAVELLING:
			var way_on: float = PartyPlaces.course(expedition).exit
			if absf(expedition.x - way_on) <= WAY_ON_APPROACH:
				return
		settle_now()
		sim.step()


## Puts the party a step outside the chamber of the guardian holding its stage's way on, walking
## in.
func _cut_to_guardian() -> void:
	var line: StageCourse = PartyPlaces.course(main.simulation.expedition)
	_stand_before(ChamberRules.way_on_room(line), GUARDIAN_APPROACH)


## Cuts to the first depth from QUEST_DEPTH holding [param quest] in a chamber, and puts the party
## a few tiles of course before that chamber, walking in.
func _cut_to_quest(quest: StringName) -> void:
	var sim: Simulation = main.simulation
	for depth: int in range(QUEST_DEPTH, QUEST_SEARCH + 1):
		var level: LabyrinthLevel = sim.labyrinth.level(depth)
		var found: LabyrinthChamber = null
		for room: LabyrinthChamber in level.chambers:
			if sim.expedition.side_quest_in(depth, room.index) == quest:
				found = room
				break
		if found == null:
			continue
		sim.set_auto_push(false)
		_cut_to_depth(depth, depth)
		settle_now()
		if sim.expedition.side_quest_in(depth, found.index) != quest:
			continue
		_stand_before(found.index, QUEST_APPROACH)
		return


## Stands the party [param back] tiles of course before chamber [param index] of its stage,
## nearer if that would be inside another chamber, travelling on along the course: it walks in
## from the side the course comes from, off a tunnel or a ladder.
func _stand_before(index: int, back: float) -> void:
	var expedition: Expedition = main.simulation.expedition
	var line: StageCourse = PartyPlaces.course(expedition)
	var first: float = line.stretch_of(index).x
	var gap: float = back
	while gap > 0.1 and line.chamber_at(first - gap) not in [-1, index]:
		gap -= 0.5
	expedition.x = maxf(first - maxf(gap, 0.1), line.start)
	expedition.facing = 1


## The four areas' moment: each area in turn for AREA_SECONDS, cut to its first stage; seen once
## the party has stood in all four.
func _show_areas() -> void:
	var ids: Array[StringName] = Content.area_ids()
	var turn: int = floori(_moment_time / AREA_SECONDS)
	if turn >= ids.size():
		if _areas_seen.size() == ids.size():
			_seen = true
		return
	if turn != _area_turn:
		_area_turn = turn
		_cut_to_area(ids[turn])
		_cut_to_depth(1, 1)
	var expedition: Expedition = main.simulation.expedition
	if expedition.state != Expedition.State.JOURNEYING:
		_areas_seen[expedition.place] = true


## Sends the party to area [param id] and steps the simulation (ending fights and rests on the way)
## until it has arrived; the world shows the arrival as it would after a long frame.
func _cut_to_area(id: StringName) -> void:
	var sim: Simulation = main.simulation
	if sim.expedition.place == id and sim.expedition.state != Expedition.State.JOURNEYING:
		return
	sim.expedition.travel.open[id] = true
	sim.set_destination(id, 1)
	for i: int in CUT_TICKS:
		settle_now()
		sim.step()
		var there: bool = sim.expedition.place == id
		if there and sim.expedition.state != Expedition.State.JOURNEYING:
			return


## The tree's moment: at once and then every TREE_STEP seconds, the next click on the knight's
## Talents tab: the trunk node left, then the first Berserker node, which asks, then Choose.
func _click_through_tree() -> void:
	var knight_id: int = main.simulation.party.heroes[0].id
	var tab: HeroTalentsTab = main.hud.hero_windows.window_of(knight_id).talents
	var tree: TalentTreeDef = Content.talent_tree(main.simulation.party.heroes[0].class_id)
	var clicks: Array[StringName] = [tree.trunk[2], tree.path_b[0], &"choose"]
	var due: int = mini(floori(_moment_time / TREE_STEP) + 1, clicks.size())
	while _tree_clicks < due:
		var click: StringName = clicks[_tree_clicks]
		if click == &"choose":
			tab.confirm()
		else:
			tab.press_node(click)
		_tree_clicks += 1


## An evening's time away to tell of: gold, levels, a guardian, a quest, a microskill.
func _away_report() -> AwayReport:
	var report := AwayReport.new()
	var e: Expedition = main.simulation.expedition
	report.seconds = 3.0 * 3600.0 + 25.0 * 60.0
	report.gold_gained = 12_480
	report.area_before = e.place
	report.area_after = e.place
	report.depth_before = maxi(e.depth - 2, 1)
	report.depth_after = e.depth
	report.kills = 1_342
	report.wipes = 2
	report.guardians_slain = 1
	report.deepest_guardian = e.guardian_of(Expedition.GUARDIAN_EVERY)
	report.side_quests_done = 3
	for hero: Hero in main.simulation.party.heroes:
		report.levels_gained[hero.id] = 2
	return report


func _set_level(hero: Hero, level: int) -> void:
	hero.level = level
	hero.xp = Hero.xp_for_level(level)
	hero.health = hero.max_health()

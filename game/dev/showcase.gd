class_name Showcase
extends Node
## A development scene (spec 018) that plays the loop's moments on demand, one after another, each
## labelled on screen: travel, a crit, a kill, a heal, a level up, a rest, going on a stage and
## back (spec 054: the crossing), a wipe and the revival, a stage becoming stable, a fight in each
## other area, a guardian's fight (spec 038), side quests (spec 028): one done, one nobody can do,
## a tripwire sprung and a microskill learned; then the area map (spec 053) with two areas open
## and the rest closed, a journey to the Claypits and the arrival there, with the map open on the
## way; the four areas' looks in turn (spec 054); and the knight's talent tree (spec 055), a node
## taken and a path chosen.
##
## It runs a real [Main] (with no save store) and steers its simulation only through the
## simulation's own classes: hero health, level and XP, a combatant's crit chance, the expedition's
## target depth, stable time and place, and [method Arrival.from_save] to cut to another
## depth. The
## pictures are the game's own. Everything moves in [method advance], so a test can drive a pass.
##
## Run it with [code]godot --path . res://game/dev/showcase.tscn[/code].

## Emitted when a moment starts.
signal moment_started(moment: StringName)
## Emitted once, when the last moment is over.
signal finished

## The moments, in order.
const MOMENTS: Array[StringName] = [
	&"travelling",
	&"crit",
	&"monster_death",
	&"heal",
	&"level_up",
	&"resting",
	&"climb_down",
	&"climb_up",
	&"wipe",
	&"revival",
	&"depth_stable",
	&"clay_fight",
	&"stone_fight",
	&"deep_fight",
	&"guardian_fight",
	&"quest_done",
	&"quest_missed",
	&"tripwire_sprung",
	&"microskill_learned",
	&"area_map",
	&"journey",
	&"four_areas",
	&"talent_tree",
]
## What the label says during each moment.
const CAPTIONS: Dictionary[StringName, String] = {
	&"travelling": "TRAVELLING IN A TUNNEL",
	&"crit": "A FIGHT WITH A CRIT",
	&"monster_death": "A MONSTER DIES: COINS AND XP",
	&"heal": "THE CLERIC HEALS",
	&"level_up": "A LEVEL UP",
	&"resting": "RESTING",
	&"climb_down": "ON TO THE NEXT STAGE",
	&"climb_up": "BACK A STAGE",
	&"wipe": "THE PARTY IS WIPED",
	&"revival": "THE REVIVAL",
	&"depth_stable": "A STAGE BECOMES STABLE",
	&"clay_fight": "A FIGHT IN THE CLAYPITS, FOR CLAY",
	&"stone_fight": "A FIGHT IN THE OLD CRYPT, FOR OLD BONES",
	&"deep_fight": "A FIGHT IN EMBER DEEP, FOR EMBERS",
	&"guardian_fight": "A GUARDIAN HOLDS THE WAY ON",
	&"quest_done": "A SIDE QUEST: THE ROGUE PICKS A LOCK",
	&"quest_missed": "A SIDE QUEST NOBODY CAN DO",
	&"tripwire_sprung": "A TRIPWIRE NOBODY SPOTS",
	&"microskill_learned": "THE ROGUE LEARNS A MICROSKILL",
	&"area_map": "THE AREA MAP: WHERE THE PARTY CAN GO",
	&"journey": "A JOURNEY TO THE CLAYPITS",
	&"four_areas": "THE FOUR AREAS",
	&"talent_tree": "THE KNIGHT CHOOSES A PATH",
}
## Seconds a moment goes on showing once what it is about has happened.
const LINGER: Dictionary[StringName, float] = {
	&"travelling": 2.5,
	&"crit": 1.5,
	&"monster_death": 1.6,
	&"heal": 1.2,
	&"level_up": 1.6,
	&"resting": 2.5,
	&"climb_down": 1.0,
	&"climb_up": 1.0,
	&"wipe": 2.5,
	&"revival": 2.0,
	&"depth_stable": 2.2,
	&"clay_fight": 3.0,
	&"stone_fight": 3.0,
	&"deep_fight": 3.0,
	&"guardian_fight": 3.5,
	&"quest_done": 2.2,
	&"quest_missed": 2.0,
	&"tripwire_sprung": 1.8,
	&"microskill_learned": 2.2,
	&"area_map": 3.0,
	&"journey": 2.5,
	&"four_areas": 0.2,
	&"talent_tree": 0.6,
}
## A moment whose event has not come after this many seconds is given up (and has no evidence).
const GIVE_UP_SECONDS: float = 20.0
## How much faster than real time the simulation runs while the party walks to its next fight.
const WALK_SPEED_UP: float = 3.0
## The areas of the band fights (spec 054: one in each area after the first, each its own look),
## and the stage each is fought on there: levels 8, 13 and 18, as the old depths were.
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
## How many times their health the monsters of the first fight have.
const TOUGHER: int = 3
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
## How many tiles before a quest's chamber the party is put, at most, so the walk in shows.
const QUEST_APPROACH: float = 3.0
## The depth the climbs happen from (down to the next and back up).
const CLIMB_DEPTH: int = 2
## How many tiles short of the shaft the cut to a climb stops, so the walk onto the ladder shows.
const SHAFT_APPROACH: float = 4.0
## The most ticks stepped at once to cut to the next fight.
const CUT_TICKS: int = 1200
## Where the showcase's Main would keep a save: a per-process name under user:// that is only
## ever read (it does not exist), never written. The store is dropped as soon as Main is ready.
const NO_SAVE_PATH: String = "user://showcase_no_save_%d.json"
## The area the map moments open and the journey goes to.
const NEW_AREA: StringName = &"claypits"
## The tree's moment: the knight's level (four talent points), and seconds between its clicks
## (short: the whole pass must stay within test_018's 90 seconds).
const TREE_LEVEL: int = 8
const TREE_STEP: float = 0.2

## The game, as the main scene builds it.
var main: Main
## The moment showing now (an index into MOMENTS), or MOMENTS.size() once the pass is over.
var moment_index: int = -1
## Per moment: true once the matching state or event was really present in the simulation.
var evidence: Dictionary[StringName, bool] = {}
## Seconds since the pass started.
var elapsed: float = 0.0
## True once every moment has been shown.
var done: bool = false

var _moment_time: float = 0.0
## Seconds since the moment's evidence appeared, or -1 before it does.
var _since_evidence: float = -1.0
var _caption: Label
## Battles already steered in this moment (by its first combatant's id), so a change is made once.
var _steered: Dictionary[int, bool] = {}
## True once the journey's map has been opened on the way.
var _map_on_the_way: bool = false
## The tree's moment: the clicks made so far.
var _tree_clicks: int = 0
## The four areas' moment: the area being shown (an index into the areas), and those seen.
var _area_turn: int = -1
var _areas_seen: Dictionary[StringName, bool] = {}


func _ready() -> void:
	main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	main.name = "Main"
	# A store on a file that does not exist makes Main start a new game rather than load the
	# player's; it is dropped before Main could ever write.
	main.save_store = SaveStore.new(NO_SAVE_PATH % OS.get_process_id())
	add_child(main)
	main.save_store = null
	main.driver.set_process(false)
	main.world.set_process(false)
	main.effects.set_process(false)
	main.world.sim_event.connect(_on_sim_event)
	var layer := CanvasLayer.new()
	layer.name = "Caption"
	layer.layer = 20
	add_child(layer)
	_caption = PixelText.label("", &"white")
	_caption.add_theme_font_size_override(&"font_size", PixelText.SIZE * 2)
	_caption.add_theme_constant_override(&"shadow_offset_x", 2)
	_caption.add_theme_constant_override(&"shadow_offset_y", 2)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(0, 296)
	_caption.size = Vector2(640, 20)
	layer.add_child(_caption)
	_next_moment()


func _process(delta: float) -> void:
	advance(delta)


## Starts the moment [param wanted] now, skipping those before it (for tests and a quick look).
func skip_to(wanted: StringName) -> void:
	var index: int = MOMENTS.find(wanted)
	if index < 0 or done:
		return
	moment_index = index - 1
	_next_moment()


## The moment showing now, or &"" once the pass is over.
func moment() -> StringName:
	if moment_index < 0 or moment_index >= MOMENTS.size():
		return &""
	return MOMENTS[moment_index]


## Moves the showcase on by [param delta] seconds: steers the simulation, steps it, and brings
## the world, the effects and the moment up to date. Called every frame; tests call it.
func advance(delta: float) -> void:
	if main == null:
		return
	elapsed += delta
	var speed: float = 1.0
	if _walks_to_a_fight() or _on_a_journey():
		speed = WALK_SPEED_UP
	_steer()
	main.driver.advance(roundi(delta * speed * 1_000_000.0))
	_look()
	main.world.sync(delta)
	main.effects.advance(delta)
	if done:
		return
	_moment_time += delta
	if _since_evidence >= 0.0:
		_since_evidence += delta
	var current: StringName = moment()
	if _since_evidence >= LINGER[current] or _moment_time >= GIVE_UP_SECONDS:
		_end_moment()
		_next_moment()


# --- Moments -------------------------------------------------------------------


func _next_moment() -> void:
	moment_index += 1
	_moment_time = 0.0
	_since_evidence = -1.0
	_steered.clear()
	if moment_index >= MOMENTS.size():
		done = true
		_caption.text = "THE SHOWCASE IS OVER"
		finished.emit()
		return
	var current: StringName = moment()
	_caption.text = "%d/%d  %s" % [moment_index + 1, MOMENTS.size(), CAPTIONS[current]]
	_begin(current)
	moment_started.emit(current)


func _see() -> void:
	if not evidence.get(moment(), false):
		evidence[moment()] = true
		_since_evidence = 0.0


## Sets the stage for [param current], the moment starting now.
func _begin(current: StringName) -> void:
	var sim: Simulation = main.simulation
	var expedition: Expedition = sim.expedition
	match current:
		&"level_up":
			# The front hero is one XP short of its next level: the next kill pays for it.
			var hero: Hero = sim.party.heroes[0]
			hero.xp = Hero.xp_for_level(hero.level + 1) - 1
		&"climb_down":
			_settle_now()
			_cut_to_depth(CLIMB_DEPTH, CLIMB_DEPTH + 1)
			_cut_to_shaft()
		&"climb_up":
			sim.set_target_depth(CLIMB_DEPTH)
		&"wipe":
			for hero: Hero in sim.party.heroes:
				hero.health = 0
		&"depth_stable":
			sim.set_auto_push(false)
			expedition.last_stable_depth = expedition.depth - 1
			expedition.stable_seconds = 1.0
		&"clay_fight", &"stone_fight", &"deep_fight":
			expedition.stable_seconds = 600.0
			_settle_now()
			for hero: Hero in sim.party.heroes:
				hero.level = BAND_LEVELS[current]
				hero.health = hero.max_health()
			_cut_to_area(BAND_AREAS[current])
			_cut_to_depth(BAND_STAGE, BAND_STAGE)
			_cut_to_fight()
		&"guardian_fight":
			_settle_now()
			_cut_to_area(AreaTravel.first_area())
			for hero: Hero in sim.party.heroes:
				_set_level(hero, GUARDIAN_LEVEL)
			_cut_to_depth(GUARDIAN_DEPTH, GUARDIAN_DEPTH + 1)
			_cut_to_guardian()
		&"quest_done", &"quest_missed", &"tripwire_sprung", &"microskill_learned":
			_settle_now()
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
		&"area_map":
			_settle_now()
			expedition.travel.open[NEW_AREA] = true
			main.hud.area_map.open()
			main.hud.area_map.choose(NEW_AREA)
		&"journey":
			_settle_now()
			_map_on_the_way = false
			expedition.travel.open[NEW_AREA] = true  # on its own too, after skip_to
			main.hud.area_map.open()
			main.hud.area_map.choose(NEW_AREA)
			main.hud.area_map.go()
		&"four_areas":
			_settle_now()
			sim.set_auto_push(false)
			for hero: Hero in sim.party.heroes:
				_set_level(hero, AREA_LEVEL)
			_area_turn = -1
			_areas_seen.clear()
		&"talent_tree":
			# Spec 055: the knight at level 8 with one trunk node taken, three points to spend.
			_settle_now()
			var knight: Hero = sim.party.heroes[0]
			_set_level(knight, TREE_LEVEL)
			knight.set_talents([Content.talent_tree(knight.class_id).trunk[0]] as Array[StringName])
			main.hud.hero_sheet.open(knight.id)
			main.hud.hero_sheet.open_page(HeroSheet.Page.TALENTS)
			_tree_clicks = 0


func _end_moment() -> void:
	var sim: Simulation = main.simulation
	match moment():
		&"crit":
			# Crits were for this moment only: the heroes go back to their own chances.
			var battle: Battle = sim.expedition.battle
			if battle != null:
				for hero: Hero in sim.party.heroes:
					var fighter: Combatant = battle.combatant(hero.id)
					if fighter != null:
						var own: Combatant = Combatant.from_hero(hero.def(), hero.level, hero.id)
						fighter.crit_chance = own.crit_chance
		&"resting":
			# The rest has been seen: everyone is whole, and the party moves on.
			for hero: Hero in sim.party.heroes:
				hero.health = hero.max_health()
		&"depth_stable":
			sim.expedition.stable_seconds = 600.0
		&"area_map", &"journey":
			main.hud.area_map.close()
		&"talent_tree":
			main.hud.hero_sheet.close()


## Changes made every frame while a moment waits for its event: in a fight, once per fight.
func _steer() -> void:
	var expedition: Expedition = main.simulation.expedition
	var battle: Battle = expedition.battle
	if done or expedition.state != Expedition.State.FIGHTING or battle == null:
		return
	if evidence.get(moment(), false) or battle.heroes.is_empty():
		return
	var key: int = battle.monsters[0].id if not battle.monsters.is_empty() else 0
	match moment():
		&"crit":
			for fighter: Combatant in battle.heroes:
				fighter.crit_chance = 1.0
			if _steered.has(key):
				return
			_steered[key] = true
			# Tougher monsters: this one fight holds the crit, a death, a heal and a level up.
			for monster: Combatant in battle.monsters:
				monster.max_health = monster.max_health * TOUGHER
				monster.health = monster.max_health
		&"heal":
			if _steered.has(key):
				return
			_steered[key] = true
			var front: Combatant = battle.heroes[0]
			if front.is_alive():
				front.health = maxi(1, front.max_health * 2 / 5)
		&"resting":
			if _steered.has(key):
				return
			_steered[key] = true
			# Hurt the heroes and weaken the monsters: the fight ends soon, and they need a rest.
			for fighter: Combatant in battle.heroes:
				if fighter.is_alive():
					fighter.health = maxi(1, fighter.max_health * 3 / 10)
			for monster: Combatant in battle.monsters:
				if monster.is_alive():
					monster.health = 1


## Records what the simulation's state shows this frame.
func _look() -> void:
	if done:
		return
	var expedition: Expedition = main.simulation.expedition
	match moment():
		&"travelling":
			if expedition.state == Expedition.State.TRAVELLING and expedition.chamber() == null:
				_see()
		&"resting":
			if expedition.state == Expedition.State.RESTING:
				_see()
		&"clay_fight", &"stone_fight", &"deep_fight":
			if (
				expedition.state == Expedition.State.FIGHTING
				and expedition.battle != null
				and expedition.place == BAND_AREAS[moment()]
			):
				_see()
		&"guardian_fight":
			if GuardianSpacing.fighting_guardian(main.simulation) != null:
				_see()
		&"area_map":
			if main.hud.area_map.is_open():
				_see()
		&"journey":
			# On the way, the map shows where to and how long.
			if expedition.state == Expedition.State.JOURNEYING and not _map_on_the_way:
				_map_on_the_way = true
				main.hud.area_map.open()
		&"four_areas":
			_show_areas()
		&"talent_tree":
			_click_through_tree()


func _on_sim_event(event: SimEvent) -> void:
	if done:
		return
	match moment():
		&"crit":
			if event.kind == SimEvent.Kind.HIT and event.flag:
				_see()
		&"monster_death":
			if event.kind == SimEvent.Kind.GOLD_GAINED:
				_see()
		&"heal":
			if event.kind == SimEvent.Kind.HEALED and event.amount > 0:
				_see()
		&"level_up":
			if event.kind == SimEvent.Kind.LEVEL_UP:
				_see()
		&"climb_down", &"climb_up":
			if event.kind == SimEvent.Kind.DEPTH_CHANGED:
				var wanted: int = CLIMB_DEPTH + (1 if moment() == &"climb_down" else 0)
				if event.amount == wanted:
					_see()
		&"wipe":
			if event.kind == SimEvent.Kind.PARTY_WIPED:
				_see()
		&"revival":
			if event.kind == SimEvent.Kind.PARTY_REVIVED:
				_see()
		&"depth_stable":
			if event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED:
				_see()
		&"quest_done":
			if event.kind == SimEvent.Kind.SIDE_QUEST_DONE:
				_see()
		&"quest_missed":
			if event.kind == SimEvent.Kind.SIDE_QUEST_MISSED and not event.flag:
				_see()
		&"tripwire_sprung":
			if event.kind == SimEvent.Kind.SIDE_QUEST_MISSED and event.flag:
				_see()
		&"microskill_learned":
			if event.kind == SimEvent.Kind.MICROSKILL_LEARNED:
				_see()
		&"journey":
			if event.kind == SimEvent.Kind.AREA_CHANGED:
				_see()
		&"talent_tree":
			var tree: TalentTreeDef = Content.talent_tree(main.simulation.party.heroes[0].class_id)
			if event.kind == SimEvent.Kind.TALENT_TAKEN and tree.path_of(event.ability_id) >= 0:
				_see()


## True while the moment waits for a fight the party is still walking to.
func _walks_to_a_fight() -> bool:
	if done or main.simulation.expedition.state != Expedition.State.TRAVELLING:
		return false
	var current: StringName = moment()
	return current in [&"crit", &"monster_death", &"heal", &"level_up", &"resting"]


## True while the journey's moment waits for the party to arrive.
func _on_a_journey() -> bool:
	if done or moment() != &"journey":
		return false
	return main.simulation.expedition.state == Expedition.State.JOURNEYING


# --- Cuts ----------------------------------------------------------------------


## Ends any fight and rest at once, stepping the simulation (the world snaps to the result).
func _settle_now() -> void:
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
func _cut_to_fight() -> void:
	var sim: Simulation = main.simulation
	for i: int in CUT_TICKS:
		if sim.expedition.state == Expedition.State.FIGHTING:
			return
		sim.step()


## Steps the simulation (ending any fight on the way at once) until the party is a few tiles from
## the shaft down from its depth, or on it.
func _cut_to_shaft() -> void:
	var sim: Simulation = main.simulation
	var shaft: float = sim.labyrinth.shaft_column(CLIMB_DEPTH) + Labyrinth.SHAFT_WIDTH / 2.0
	for i: int in CUT_TICKS:
		var expedition: Expedition = sim.expedition
		if expedition.state == Expedition.State.CLIMBING:
			return
		if expedition.state == Expedition.State.TRAVELLING:
			if absf(expedition.x - shaft) <= SHAFT_APPROACH:
				return
		_settle_now()
		sim.step()


## Puts the party a step outside the chamber of the guardian holding its depth's way down,
## walking in.
func _cut_to_guardian() -> void:
	var expedition: Expedition = main.simulation.expedition
	var lair: LabyrinthChamber = main.simulation.labyrinth.level(expedition.depth).shaft_chamber()
	if lair.index > 0:
		expedition.x = lair.rect.position.x - 1.0
		expedition.facing = 1
	else:
		expedition.x = lair.rect.end.x
		expedition.facing = -1


## Cuts to the first depth from QUEST_DEPTH holding [param quest] in a chamber, and puts the party
## a few tiles before that chamber, in the tunnel, walking in.
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
		_settle_now()
		if sim.expedition.side_quest_in(depth, found.index) != quest:
			continue
		var back: float = QUEST_APPROACH
		while back > 0.1 and level.chamber_at(floori(found.rect.position.x - back)) != null:
			back -= 0.5
		sim.expedition.x = found.rect.position.x - maxf(back, 0.1)
		sim.expedition.facing = 1
		return


## The four areas' moment: each area in turn for AREA_SECONDS, cut to its first stage; seen once
## the party has stood in all four.
func _show_areas() -> void:
	var ids: Array[StringName] = Content.area_ids()
	var turn: int = floori(_moment_time / AREA_SECONDS)
	if turn >= ids.size():
		if _areas_seen.size() == ids.size():
			_see()
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
		_settle_now()
		sim.step()
		var there: bool = sim.expedition.place == id
		if there and sim.expedition.state != Expedition.State.JOURNEYING:
			return


## The tree's moment: at once and then every TREE_STEP seconds, the next click on the knight's
## Talents tab: the two trunk nodes left, then the first Berserker node, which asks, then Choose.
func _click_through_tree() -> void:
	var tab: TalentTab = main.hud.hero_sheet.talents
	var tree: TalentTreeDef = Content.talent_tree(main.simulation.party.heroes[0].class_id)
	var clicks: Array[StringName] = [tree.trunk[1], tree.trunk[2], tree.path_b[0], &"choose"]
	var due: int = mini(floori(_moment_time / TREE_STEP) + 1, clicks.size())
	while _tree_clicks < due:
		var click: StringName = clicks[_tree_clicks]
		if click == &"choose":
			tab.confirm()
		else:
			tab.press_node(click)
		_tree_clicks += 1


func _set_level(hero: Hero, level: int) -> void:
	hero.level = level
	hero.xp = Hero.xp_for_level(level)
	hero.health = hero.max_health()

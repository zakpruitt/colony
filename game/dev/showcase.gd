class_name Showcase
extends Node
## A development scene that plays the loop's moments on demand, one after another, each labelled
## on screen: travel, a crit, a kill, a heal, a level up, a rest, going on a stage and back (the
## crossing), a wipe and the revival, a stage becoming stable, a fight in each other area, a
## guardian's fight, each class's hero using its actions, every status on a row of fighters (each
## labelled with its statuses), side quests (one done, one nobody can do, a tripwire sprung and a
## microskill learned), the shop, the area map with two areas open and the rest closed, a journey
## to the Claypits and the arrival there (with the map open on the way), the four areas' looks in
## turn, the knight's talent tree (a node taken and a path chosen) and the report after time away.
##
## It runs a real [Main] (with no save store) and steers its simulation only through the
## simulation's own classes: hero health, level and XP, a combatant's crit chance, the expedition's
## target depth, stable time and place, and [method Arrival.from_save] to cut to another depth.
## The pictures are the game's own. Everything moves in [method advance], so a test can drive a
## pass.
##
## Run it with [code]godot --path . res://game/dev/showcase.tscn[/code].

## Emitted when a moment starts.
signal moment_started(moment: StringName)
## Emitted once, when the last moment is over.
signal finished

## The moments, in order, one row each: its name, what the label says, the seconds it goes on
## showing once seen, how it begins (&"x" calls _begin_x with its name; &"" for nothing), and how
## it is known to have been seen: an event of that kind, or &"x", which calls _watch_x.
const ROWS: Array[Array] = [
	[&"travelling", "TRAVELLING IN A TUNNEL", 1.0, &"", &"travelling"],
	[&"crit", "A FIGHT WITH A CRIT", 1.2, &"", &"crit"],
	[&"monster_death", "A MONSTER DIES: COINS AND XP", 1.2, &"", SimEvent.Kind.GOLD_GAINED],
	[&"heal", "THE CLERIC HEALS", 1.2, &"", &"heal"],
	[&"level_up", "A LEVEL UP", 1.2, &"level_up", SimEvent.Kind.LEVEL_UP],
	[&"resting", "RESTING", 1.5, &"", &"resting"],
	[&"climb_down", "ON TO THE NEXT STAGE", 1.0, &"climb_down", &"climb"],
	[&"climb_up", "BACK A STAGE", 1.0, &"climb_up", &"climb"],
	[&"wipe", "THE PARTY IS WIPED", 1.8, &"wipe", SimEvent.Kind.PARTY_WIPED],
	[&"revival", "THE REVIVAL", 1.5, &"", SimEvent.Kind.PARTY_REVIVED],
	[&"depth_stable", "A STAGE BECOMES STABLE", 1.0, &"depth_stable", &"stable"],
	[&"clay_fight", "A FIGHT IN THE CLAYPITS, FOR CLAY", 1.5, &"band", &"band"],
	[&"stone_fight", "A FIGHT IN THE OLD CRYPT, FOR OLD BONES", 1.5, &"band", &"band"],
	[&"deep_fight", "A FIGHT IN EMBER DEEP, FOR EMBERS", 1.5, &"band", &"band"],
	# The fight, then the guardian falls and its banner shows.
	[&"guardian_fight", "A GUARDIAN HOLDS THE WAY ON", 7.0, &"guardian", &"guardian"],
	[&"knight_actions", "THE KNIGHT'S ACTIONS", 1.2, &"class", &"class"],
	[&"rogue_actions", "THE ROGUE'S ACTIONS", 1.2, &"class", &"class"],
	[&"mage_actions", "THE MAGE'S ACTIONS", 1.2, &"class", &"class"],
	[&"cleric_actions", "THE CLERIC'S ACTIONS", 1.2, &"class", &"class"],
	[&"statuses", "EVERY STATUS, ON A ROW OF FIGHTERS", 2.0, &"class", &"statuses"],
	[&"quest_done", "A SIDE QUEST: THE ROGUE PICKS A LOCK", 1.0, &"quest", &"quest_done"],
	[&"quest_missed", "A SIDE QUEST NOBODY CAN DO", 1.0, &"quest", &"missed"],
	[&"tripwire_sprung", "A TRIPWIRE NOBODY SPOTS", 1.0, &"quest", &"sprung"],
	[&"microskill_learned", "THE ROGUE LEARNS A MICROSKILL", 1.0, &"quest", &"learned"],
	[&"shop", "THE CAMP WINDOW: A FIFTH RANK BOUGHT", 2.5, &"shop", &"shop"],
	[&"area_map", "THE MAP: WHERE THE PARTY CAN GO", 1.5, &"area_map", &"area_map"],
	[&"journey", "A JOURNEY TO THE CLAYPITS", 1.2, &"journey", &"journey"],
	[&"four_areas", "THE FOUR AREAS", 0.2, &"four_areas", &"four_areas"],
	# The path's banner shows after the node's.
	[&"talent_tree", "THE KNIGHT CHOOSES A PATH", 2.5, &"talent_tree", &"talent_tree"],
	[&"away_report", "THE AWAY REPORT", 2.0, &"away_report", &"away_report"],
]
## A moment whose event has not come after this many seconds is given up (and has no evidence).
const GIVE_UP_SECONDS: float = 20.0
## How much faster than real time the simulation runs while the party walks to its next fight.
const WALK_SPEED_UP: float = 3.0
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
## The gold the shop moment gives the party, enough for a few ranks.
const SHOP_GOLD: int = 300
## The upgrade the shop moment buys, and the rank it reaches, a milestone with a banner.
const SHOP_UPGRADE: StringName = &"sharp_blades"
const SHOP_RANK: int = 5
## Each class's moment, the path its hero takes there (the one whose actions look most
## unlike the trunk's), the heroes' level (every talent point earned), the stage of the fight and
## how many times their health the monsters have, so the hero's actions are seen.
const CLASS_MOMENTS: Dictionary[StringName, StringName] = {
	&"knight_actions": &"knight",
	&"rogue_actions": &"rogue",
	&"mage_actions": &"mage",
	&"cleric_actions": &"cleric",
}
const CLASS_PATHS: Dictionary[StringName, int] = {
	&"knight": 1, &"rogue": 1, &"mage": 0, &"cleric": 1
}
const CLASS_LEVEL: int = 14
## How many different moves the class's hero's abilities make (an action's among them)
## before its moment is seen.
const CLASS_MOVES_SEEN: int = 2
const CLASS_STAGE: int = 2
const CLASS_TOUGHER: int = 6
## In the statuses' moment, the statuses on each hero (by place in the party) and on
## each monster (by place in the fight; the last also takes any left over), the ability each is
## said to come from, and how long each lasts. The fight needs this many monsters at least.
const HERO_STATUSES: Array[Array] = [
	[AbilityEffect.Status.TAUNTING, AbilityEffect.Status.SHIELDED],
	[AbilityEffect.Status.UNTOUCHABLE, AbilityEffect.Status.HASTED],
	[AbilityEffect.Status.NIMBLE, AbilityEffect.Status.MIGHTY],
	[AbilityEffect.Status.MENDING],
]
const MONSTER_STATUSES: Array[Array] = [
	[AbilityEffect.Status.STUNNED, AbilityEffect.Status.BURNING],
	[AbilityEffect.Status.BLEEDING, AbilityEffect.Status.SLOWED],
	[AbilityEffect.Status.CHILLED, AbilityEffect.Status.WEAKENED],
	[AbilityEffect.Status.MARKED],
]
const STATUS_FROM: Dictionary[int, StringName] = {
	AbilityEffect.Status.STUNNED: &"shield_bash",
	AbilityEffect.Status.TAUNTING: &"taunt",
	AbilityEffect.Status.SHIELDED: &"bulwark",
	AbilityEffect.Status.BURNING: &"ignite",
	AbilityEffect.Status.BLEEDING: &"poisoned_blades",
	AbilityEffect.Status.MENDING: &"renewal",
	AbilityEffect.Status.HASTED: &"battle_hymn",
	AbilityEffect.Status.SLOWED: &"caltrops",
	AbilityEffect.Status.MIGHTY: &"killing_spree",
	AbilityEffect.Status.WEAKENED: &"smite",
	AbilityEffect.Status.MARKED: &"mark_for_death",
	AbilityEffect.Status.NIMBLE: &"smoke_step",
	AbilityEffect.Status.UNTOUCHABLE: &"vanish",
	AbilityEffect.Status.CHILLED: &"blizzard",
}
const STATUS_SECONDS: float = 30.0
const STATUS_MONSTERS: int = 3
## The tree's moment: the knight's level (four talent points), and seconds between its clicks
## (long enough to see each node burst, short enough for test_018's limit).
const TREE_LEVEL: int = 8
const TREE_STEP: float = 0.6

## The game, as the main scene builds it.
var main: Main
## The moment showing now (an index into [method table]), or its size once the pass is over.
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
## A class's moment: the moves of the abilities its hero has used so far, and whether
## one was an action.
var _moves_used: Dictionary[StringName, bool] = {}
var _actions_used: bool = false
## The four areas' moment: the area being shown (an index into the areas), and those seen.
var _area_turn: int = -1
var _areas_seen: Dictionary[StringName, bool] = {}
## The statuses' moment's labels, one under each fighter bearing a status.
var _status_labels: Array[Label] = []


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


## The moments' names, in order.
static func names() -> Array[StringName]:
	var found: Array[StringName] = []
	for row: Array in ROWS:
		found.append(row[0])
	return found


## What the label says during moment [param wanted], or "" for no moment.
static func caption(wanted: StringName) -> String:
	var index: int = names().find(wanted)
	return ROWS[index][1] if index >= 0 else ""


## Starts the moment [param wanted] now, skipping those before it (for tests and a quick look).
func skip_to(wanted: StringName) -> void:
	var index: int = names().find(wanted)
	if index < 0 or done:
		return
	moment_index = index - 1
	_next_moment()


## The moment showing now, or &"" once the pass is over.
func moment() -> StringName:
	return _row()[0] if not _row().is_empty() else &""


## The row of the moment showing now (see [constant ROWS]), or an empty one.
func _row() -> Array:
	return ROWS[moment_index] if moment_index >= 0 and moment_index < ROWS.size() else []


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
	_watch(null)
	main.world.sync(delta)
	main.effects.advance(delta)
	_label_statuses()
	if done:
		return
	_moment_time += delta
	if _since_evidence >= 0.0:
		_since_evidence += delta
	var linger: float = _row()[2]
	if _since_evidence >= linger or _moment_time >= GIVE_UP_SECONDS:
		_end_moment()
		_next_moment()


# --- Moments -------------------------------------------------------------------


func _next_moment() -> void:
	moment_index += 1
	_moment_time = 0.0
	_since_evidence = -1.0
	_steered.clear()
	_moves_used.clear()
	_actions_used = false
	var row: Array = _row()
	if row.is_empty():
		done = true
		_caption.text = "THE SHOWCASE IS OVER"
		finished.emit()
		return
	_caption.text = "%d/%d  %s" % [moment_index + 1, ROWS.size(), row[1]]
	if row[3] != &"":
		call("_begin_%s" % row[3], row[0])
	moment_started.emit(row[0])


func _see() -> void:
	if not evidence.get(moment(), false):
		evidence[moment()] = true
		_since_evidence = 0.0


## Tells the moment showing of [param event], or with null of the frame's state: it is seen once
## its row says so.
func _watch(event: SimEvent) -> void:
	var row: Array = _row()
	if done or row.is_empty():
		return
	if row[4] is int:
		if event != null and event.kind == row[4]:
			_see()
	else:
		call("_watch_%s" % row[4], event)


# --- How each moment begins ---------------------------------------------------


func _begin_level_up(_current: StringName) -> void:
	# The front hero is one XP short of its next level: the next kill pays for it.
	var hero: Hero = main.simulation.party.heroes[0]
	hero.xp = Hero.xp_for_level(hero.level + 1) - 1


func _begin_climb_down(_current: StringName) -> void:
	_settle_now()
	_cut_to_depth(CLIMB_DEPTH, CLIMB_DEPTH + 1)
	_cut_to_shaft()


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
	_settle_now()
	for hero: Hero in main.simulation.party.heroes:
		hero.level = BAND_LEVELS[current]
		hero.health = hero.max_health()
	_cut_to_area(BAND_AREAS[current])
	_cut_to_depth(BAND_STAGE, BAND_STAGE)
	_cut_to_fight()


## A class's moment, or the statuses': every hero at CLASS_LEVEL, the class's own hero with its
## trunk and path taken.
func _begin_class(current: StringName) -> void:
	_settle_now()
	_cut_to_area(AreaTravel.first_area())
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, CLASS_LEVEL)
		hero.set_talents([])
		if CLASS_MOMENTS.get(current, &"") == hero.class_id:
			var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
			var nodes: Array[StringName] = tree.trunk.duplicate()
			nodes.append_array(tree.path_nodes(CLASS_PATHS[hero.class_id]))
			hero.set_talents(nodes)
	_cut_to_depth(CLASS_STAGE, CLASS_STAGE)
	_cut_to_fight()


func _begin_guardian(_current: StringName) -> void:
	_settle_now()
	_cut_to_area(AreaTravel.first_area())
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, GUARDIAN_LEVEL)
	_cut_to_depth(GUARDIAN_DEPTH, GUARDIAN_DEPTH + 1)
	_cut_to_guardian()


func _begin_quest(current: StringName) -> void:
	_settle_now()
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


## The shop's window, gold for a few ranks, and the first row bought: Sharp Blades' fifth rank,
## so the card bursts and a banner drops in.
func _begin_shop(_current: StringName) -> void:
	_settle_now()
	var sim: Simulation = main.simulation
	sim.party.gold = SHOP_GOLD
	sim.upgrades.set_rank(SHOP_UPGRADE, SHOP_RANK - 1)
	var bones: StringName = Content.upgrade(SHOP_UPGRADE).resource
	sim.party.set_resource(bones, sim.upgrades.resource_cost(SHOP_UPGRADE))
	main.hud.shop.open()
	main.hud.shop.buy_row(0)


func _begin_area_map(_current: StringName) -> void:
	_settle_now()
	main.simulation.expedition.travel.open[NEW_AREA] = true
	main.hud.area_map.open()
	main.hud.area_map.choose(NEW_AREA)


func _begin_journey(_current: StringName) -> void:
	_settle_now()
	_map_on_the_way = false
	main.simulation.expedition.travel.open[NEW_AREA] = true  # on its own too, after skip_to
	main.hud.area_map.open()
	main.hud.area_map.choose(NEW_AREA)
	main.hud.area_map.go()


func _begin_four_areas(_current: StringName) -> void:
	_settle_now()
	main.simulation.set_auto_push(false)
	for hero: Hero in main.simulation.party.heroes:
		_set_level(hero, AREA_LEVEL)
	_area_turn = -1
	_areas_seen.clear()


## The knight at level 8 with two trunk nodes taken and two points to spend: one for the last
## trunk node, one for a path.
func _begin_talent_tree(_current: StringName) -> void:
	_settle_now()
	var knight: Hero = main.simulation.party.heroes[0]
	_set_level(knight, TREE_LEVEL)
	var trunk: Array[StringName] = Content.talent_tree(knight.class_id).trunk
	knight.set_talents(trunk.slice(0, 2))
	main.hud.hero_windows.open(knight.id, HeroWindow.Page.TALENTS)
	_tree_clicks = 0


## The report after time away, as a window over the game.
func _begin_away_report(_current: StringName) -> void:
	_settle_now()
	main.away_window = main.ui.show_away(_away_report(), main.simulation.party)


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
		&"shop":
			main.hud.shop.close()
		&"area_map", &"journey":
			main.hud.area_map.close()
		&"statuses":
			for hero: Hero in sim.party.heroes:
				hero.set_talents([])  # the class moments' trees are for those moments only
		&"talent_tree":
			main.hud.hero_windows.close_all()
		&"away_report":
			if is_instance_valid(main.away_window):
				main.away_window.close()


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
		&"knight_actions", &"rogue_actions", &"mage_actions", &"cleric_actions":
			if _steered.has(key):
				return
			_steered[key] = true
			for monster: Combatant in battle.monsters:
				monster.max_health = monster.max_health * CLASS_TOUGHER
				monster.health = monster.max_health
		&"statuses":
			if not _steered.has(key):
				_steered[key] = true
				_put_on_statuses(battle)
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


# --- How each moment is seen --------------------------------------------------


func _watch_travelling(event: SimEvent) -> void:
	var expedition: Expedition = main.simulation.expedition
	if event == null and expedition.state == Expedition.State.TRAVELLING:
		if expedition.chamber() == null:
			_see()


func _watch_crit(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.HIT and event.flag:
		_see()


func _watch_heal(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.HEALED and event.amount > 0:
		_see()


func _watch_resting(event: SimEvent) -> void:
	if event == null and main.simulation.expedition.state == Expedition.State.RESTING:
		_see()


func _watch_climb(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.DEPTH_CHANGED:
		var wanted: int = CLIMB_DEPTH + (1 if moment() == &"climb_down" else 0)
		if event.amount == wanted:
			_see()


func _watch_band(event: SimEvent) -> void:
	var expedition: Expedition = main.simulation.expedition
	if (
		event == null
		and expedition.state == Expedition.State.FIGHTING
		and expedition.battle != null
		and expedition.place == BAND_AREAS[moment()]
	):
		_see()


func _watch_guardian(event: SimEvent) -> void:
	var guardian: Combatant = GuardianSpacing.fighting_guardian(main.simulation)
	if event == null and guardian != null:
		_see()
		if _since_evidence >= GUARDIAN_WATCH:
			guardian.health = mini(guardian.health, 1)  # it falls, for its banner


func _watch_class(event: SimEvent) -> void:
	if event == null or event.kind != SimEvent.Kind.ABILITY_USED:
		return
	var ability: AbilityDef = Content.ability(event.ability_id)
	var hero: Hero = main.simulation.party.hero(event.source_id)
	if ability == null or hero == null or not main.world.may_animate(event):
		return
	if hero.class_id == CLASS_MOMENTS[moment()]:
		_moves_used[ability.move] = true
		_actions_used = _actions_used or ability.is_action()
		if _actions_used and _moves_used.size() >= CLASS_MOVES_SEEN:
			_see()


func _watch_statuses(event: SimEvent) -> void:
	if event != null:
		return
	var seen: Dictionary[int, bool] = {}
	var marks: StatusMarks = main.effects.ability_effects.marks
	for id: int in marks.book.fighters():
		for kind: int in marks.shown(id):
			seen[kind] = true
	if seen.size() == AbilityEffect.Status.size():
		_see()


func _watch_stable(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.STABLE_DEPTH_REACHED:
		_see()


func _watch_quest_done(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.SIDE_QUEST_DONE:
		_see()


func _watch_learned(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.MICROSKILL_LEARNED:
		_see()


func _watch_missed(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.SIDE_QUEST_MISSED and not event.flag:
		_see()


func _watch_sprung(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.SIDE_QUEST_MISSED and event.flag:
		_see()


func _watch_shop(event: SimEvent) -> void:
	if event == null or event.kind != SimEvent.Kind.UPGRADE_BOUGHT:
		return
	if main.hud.shop.is_open() and event.amount == SHOP_RANK:
		_see()


func _watch_area_map(event: SimEvent) -> void:
	if event == null and main.hud.area_map.is_open():
		_see()


## On the way, the map shows where to and how long; the arrival is the moment.
func _watch_journey(event: SimEvent) -> void:
	if event != null and event.kind == SimEvent.Kind.AREA_CHANGED:
		_see()
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
		_see()


func _watch_away_report(event: SimEvent) -> void:
	if event == null and is_instance_valid(main.away_window) and main.away_window.is_open():
		_see()


func _on_sim_event(event: SimEvent) -> void:
	_watch(event)


## True while the moment waits for a fight the party is still walking to.
func _walks_to_a_fight() -> bool:
	if done or main.simulation.expedition.state != Expedition.State.TRAVELLING:
		return false
	var current: StringName = moment()
	return current in [&"crit", &"monster_death", &"heal", &"level_up", &"resting"]


## Puts every status on the fight's fighters through the battle's own rules (each with
## its STATUS_BEGAN), for STATUS_SECONDS, and makes the fight harmless and long, so the row stands
## still to be read. A fight with too few monsters is ended and the next one taken.
func _put_on_statuses(battle: Battle) -> void:
	if battle.monsters.size() < STATUS_MONSTERS:
		_settle_now()
		_cut_to_fight()
		return
	# Spread out in their order and kept where they stand (each strikes from there, for 1), so
	# every fighter's marks and label can be read.
	var row: Array[Combatant] = battle.heroes + battle.monsters
	row.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.x < b.x)
	# Evenly between the outermost two, which the fight's bounds already hold.
	var first: float = row[0].x
	var step: float = (row[row.size() - 1].x - first) / maxf(row.size() - 1, 1)
	for i: int in row.size():
		var fighter: Combatant = row[i]
		fighter.x = first + i * step
		fighter.max_health *= 100
		fighter.health = fighter.max_health
		fighter.damage = 1
		fighter.move_speed = 0.0
		fighter.attack_range = 100.0
		fighter.abilities = []
	var left: Array = MONSTER_STATUSES.duplicate()
	for i: int in battle.monsters.size():
		var kinds: Array = []
		if i == battle.monsters.size() - 1:
			for rest: Array in left:
				kinds.append_array(rest)
		elif not left.is_empty():
			kinds = left.pop_front()
		for kind: int in kinds:
			_put_on(battle, battle.heroes[0], battle.monsters[i], kind)
	for i: int in mini(battle.heroes.size(), HERO_STATUSES.size()):
		for kind: int in HERO_STATUSES[i]:
			_put_on(battle, battle.heroes[i], battle.heroes[i], kind)


func _put_on(battle: Battle, source: Combatant, receiver: Combatant, kind: int) -> void:
	var effect := AbilityEffect.new()
	effect.does = AbilityEffect.Does.STATUS
	effect.status = kind as AbilityEffect.Status
	effect.seconds = STATUS_SECONDS
	effect.scale = AbilityEffect.Scale.RECEIVER_MAX_HEALTH
	match kind:
		AbilityEffect.Status.SHIELDED:
			effect.amount = 0.5
		AbilityEffect.Status.BURNING, AbilityEffect.Status.BLEEDING:
			effect.amount = 0.001
		AbilityEffect.Status.CHILLED, AbilityEffect.Status.MENDING:
			effect.amount = 0.001
		AbilityEffect.Status.HASTED, AbilityEffect.Status.WEAKENED:
			effect.amount = 0.7
		AbilityEffect.Status.NIMBLE:
			effect.amount = 0.5
		_:
			effect.amount = 1.3
	BattleStatuses.apply(battle, source, receiver, effect, STATUS_FROM[kind])


func _x_of(id: int) -> float:
	var sprite: CharacterSprite = main.world.character(id)
	return sprite.position.x if sprite != null else 0.0


## While the statuses' moment shows, a label under each fighter names its statuses.
func _label_statuses() -> void:
	var marks: StatusMarks = main.effects.ability_effects.marks
	var ids: Array[int] = []
	if moment() == &"statuses":
		ids = marks.book.fighters()
		ids.sort_custom(func(a: int, b: int) -> bool: return _x_of(a) < _x_of(b))
	var camera: WorldCamera = main.world.camera
	var view: Vector2 = camera.get_viewport_rect().size
	var shown: int = 0
	for id: int in ids:
		var sprite: CharacterSprite = main.world.character(id)
		var kinds: Array[int] = marks.shown(id)
		if sprite == null or kinds.is_empty():
			continue
		if shown >= _status_labels.size():
			var made: Label = PixelText.label("", &"white")
			made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_caption.get_parent().add_child(made)
			_status_labels.append(made)
		var label: Label = _status_labels[shown]
		shown += 1
		var said: PackedStringArray = []
		for kind: int in kinds:
			said.append(ShownStatus.status_name(kind))
		label.text = "\n".join(said)
		label.reset_size()
		var feet: Vector2 = (
			(sprite.position - camera.position - camera.offset) * camera.zoom + view / 2.0
		)
		# Every other label a tier lower, so neighbours never run into each other.
		var tier: float = (shown % 2) * 2.0 * (PixelText.SIZE + 1)
		label.position = Vector2(roundf(feet.x - label.size.x / 2.0), roundf(feet.y + 3.0 + tier))
		label.visible = true
	for i: int in range(shown, _status_labels.size()):
		_status_labels[i].visible = false


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

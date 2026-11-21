extends ColonyTest
## Acceptance tests for specs/076-one-pool-for-effects/spec.md, one per requirement.
##
## R1 (normal play looks the same) is the rest of the suite passing and the showcase's shots
## beside the baseline; R5's shared guardian record is read through CombatEffects.is_guardian and
## the sounds by test_024 and test_021.

const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const KNIGHT: int = 1
const MAGE: int = 3
## The moments of the showcase, in order, with their captions, as they were before this spec.
const MOMENTS: Array[Array] = [
	[&"travelling", "TRAVELLING IN A TUNNEL"],
	[&"crit", "A FIGHT WITH A CRIT"],
	[&"monster_death", "A MONSTER DIES: COINS AND XP"],
	[&"heal", "THE CLERIC HEALS"],
	[&"level_up", "A LEVEL UP"],
	[&"resting", "RESTING"],
	[&"climb_down", "ON TO THE NEXT STAGE"],
	[&"climb_up", "BACK A STAGE"],
	[&"wipe", "THE PARTY IS WIPED"],
	[&"revival", "THE REVIVAL"],
	[&"depth_stable", "A STAGE BECOMES STABLE"],
	[&"clay_fight", "A FIGHT IN THE CLAYPITS, FOR CLAY"],
	[&"stone_fight", "A FIGHT IN THE OLD CRYPT, FOR OLD BONES"],
	[&"deep_fight", "A FIGHT IN EMBER DEEP, FOR EMBERS"],
	[&"guardian_fight", "A GUARDIAN HOLDS THE WAY ON"],
	[&"knight_actions", "THE KNIGHT'S ACTIONS"],
	[&"rogue_actions", "THE ROGUE'S ACTIONS"],
	[&"mage_actions", "THE MAGE'S ACTIONS"],
	[&"cleric_actions", "THE CLERIC'S ACTIONS"],
	[&"statuses", "EVERY STATUS, ON A ROW OF FIGHTERS"],
	[&"quest_done", "A SIDE QUEST: THE ROGUE PICKS A LOCK"],
	[&"quest_missed", "A SIDE QUEST NOBODY CAN DO"],
	[&"tripwire_sprung", "A TRIPWIRE NOBODY SPOTS"],
	[&"microskill_learned", "THE ROGUE LEARNS A MICROSKILL"],
	[&"shop", "THE CAMP WINDOW: A FIFTH RANK BOUGHT"],
	[&"area_map", "THE MAP: WHERE THE PARTY CAN GO"],
	[&"journey", "A JOURNEY TO THE CLAYPITS"],
	[&"four_areas", "THE FOUR AREAS"],
	[&"talent_tree", "THE KNIGHT CHOOSES A PATH"],
	[&"away_report", "THE AWAY REPORT"],
]
## The calls of World.catching_up() outside the world allowed: code that clears what is running
## when the world catches up, as "file:function".
const CLEARING: Array[String] = [
	"game/effects/spell_effects.gd:advance",
	"game/ui/frame/milestones.gd:_on_sim_event",
	"game/ui/frame/milestones.gd:advance",
	"game/ui/ui_moment.gd:advance",
	"game/ui/windows/hero_windows.gd:_catching_up",
	"game/ui/windows/shop_window.gd:advance",
]

var _main: Main
## Level ups sent so far, so each is to a new level.
var _levels_told: int = 0


func _start_main() -> Main:
	_main = make_main()
	add_child_autofree(_main)
	_main.driver.set_process(false)
	_main.world.set_process(false)
	_main.effects.set_process(false)
	# Far enough in that an event can be old.
	for i: int in World.ANIMATE_TICKS * 4:
		_main.simulation.step()
	_step_frame()
	return _main


## One quiet frame: the world shows the simulation, the effects move on.
func _step_frame() -> void:
	_main.simulation.step()
	_main.world.sync(FRAME)
	_main.effects.advance(FRAME)


## The id of a monster the world shows.
func _monster() -> int:
	for id: int in _main.world._monsters:
		if _main.world.character(id) != null:
			return id
	return -1


func _code_files() -> Array[String]:
	var found: Array[String] = []
	var dirs: Array[String] = ["res://game"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				found.append(dir + "/" + file)
	return found


## A Main in a fight nobody can win or lose, synced, with every listener's window set up for what
## it starts: the boss bar on a guardian, the shop's rows built.
func _start_fight() -> void:
	_start_main()
	var sim: Simulation = _main.simulation
	for i: int in 6000:
		if sim.expedition.battle != null and _monster() > 0:
			break
		_step_frame()
	assert_not_null(sim.expedition.battle, "(a fight)")
	var fighters: Array[Combatant] = []
	fighters.append_array(sim.expedition.battle.heroes)
	fighters.append_array(sim.expedition.battle.monsters)
	for fighter: Combatant in fighters:
		fighter.max_health *= 1000
		fighter.health = fighter.max_health
	_main.hud.boss_bar._guardian_id = _monster()
	_step_frame()
	assert_false(_main.world.catching_up(), "(the world is caught up)")


## Every listener that starts something, by name: [the events of tick t that start it, given
## (tick, monster); what it shows now, as a number a start changes; what puts it back at rest].
func _probes() -> Dictionary[String, Array]:
	var fx: CombatEffects = _main.effects
	var hud: Hud = _main.hud
	var moment: UiMoment = _main.ui.moment
	var frame: HeroFrameView = hud.frames[0]
	var shop: ShopWindow = hud.shop
	var knight: CharacterSprite = _main.world.character(KNIGHT)
	return {
		"combat numbers": [_hit.bind(KNIGHT, false), fx.live_numbers, func() -> void: pass],
		"ability words":
		[
			_kind.bind(SimEvent.Kind.MISSED),
			func() -> int: return fx.ability_effects.texts().size(),
			func() -> void: pass
		],
		"spells": [_spell, fx.spell_effects.live, func() -> void: pass],
		"quest words": [_learned, _main.world.fx.count.bind(&"quest_text"), func() -> void: pass],
		"resource icons":
		[
			_resource,
			func() -> int: return fx.resource_effects.live_icons().size(),
			func() -> void: pass
		],
		"world bolts":
		[_bolt, func() -> int: return _main.world._bolts.size(), func() -> void: pass],
		"sounds":
		[
			_hit.bind(KNIGHT, false),
			func() -> int: return _main.sound.drain_started().size(),
			_quiet,
		],
		"hero frame flash":
		[
			_struck,
			func() -> int: return 1 if frame._flash > 0.0 else 0,
			func() -> void: frame._flash = 0.0
		],
		"journal ticker":
		[_level_up, func() -> int: return hud.journal.ticker_text().hash(), func() -> void: pass],
		"boss bar flash":
		[
			_hit.bind(KNIGHT, false),
			func() -> int: return 1 if hud.boss_bar.is_flashing() else 0,
			func() -> void: hud.boss_bar._flash = 0.0
		],
		# Goals start their celebration on the next advance unless an event was stale.
		"goals":
		[
			_hit.bind(KNIGHT, false),
			func() -> int: return 0,
			func() -> void: hud.goals._stale = false
		],
		"shop row flash":
		[
			_bought,
			func() -> int: return 1 if shop.rows[0].pips.flashing() >= 0 else 0,
			func() -> void: shop.rows[0].stop()
		],
		"hero windows' banner": [_learned, moment.waiting, func() -> void: moment._waiting.clear()],
		"milestones' burst":
		[
			_level_up,
			func() -> int: return 1 if moment.is_bursting(frame) else 0,
			func() -> void: moment._drop_all()
		],
		"ui moment": [_nothing, moment.bursts_seen, func() -> void: pass],
		"fight moves":
		[
			_hit.bind(KNIGHT, true),
			func() -> int: return knight.moves.names().size(),
			func() -> void: knight.play_move(&"", 0.0)
		],
		# Last: a wipe changes what the world shows.
		"defeat note":
		[
			_kind.bind(SimEvent.Kind.PARTY_WIPED),
			func() -> int: return 1 if hud.defeat_note._telling else 0,
			func() -> void: hud.defeat_note._telling = false
		],
	}


## Sends what probe [param probe_name] listens for, of [param tick], through the simulation and the
## world's sync, and says whether it started anything; with [param stall], a stall comes first.
func _send(probe_name: String, tick: int, stall: bool = false) -> bool:
	var probe: Array = _probes()[probe_name]
	var rest: Callable = probe[2]
	var shown: Callable = probe[1]
	rest.call()
	var before: int = shown.call()
	if stall:
		for i: int in World.STALL_TICKS * maxi(_main.world.speed, 1) + 2:
			_main.simulation.step()
	var monster: int = _monster()
	assert_gt(monster, 0, "(a monster on screen)")
	var made: Callable = probe[0]
	var events: Array[SimEvent] = []
	var sent: Array = made.call(tick if not stall else _main.simulation.tick, monster)
	events.assign(sent)
	_main.simulation._events.append_array(events)
	_main.world.sync(FRAME)
	if probe_name == "ui moment":
		_main.ui.moment.burst(_main.hud.frames[1], events[0])
	if probe_name == "goals":
		return not _main.hud.goals._stale
	return shown.call() != before


## Every voice free and no sound just played, so the next may start.
func _quiet() -> void:
	var sound: SoundPlayer = _main.sound
	sound.drain_started()
	sound._last_start.clear()
	for i: int in sound._ends.size():
		sound._ends[i] = -INF


func _hit(tick: int, monster: int, source: int, crit: bool) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.HIT, tick, source, monster, 7, crit)]


func _struck(tick: int, monster: int) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.HIT, tick, monster, KNIGHT, 3)]


func _kind(tick: int, monster: int, kind: SimEvent.Kind) -> Array[SimEvent]:
	return [SimEvent.new(kind, tick, KNIGHT, monster)]


func _resource(tick: int, monster: int) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.RESOURCE_GAINED, tick, monster, 0, 2)]


func _spell(tick: int, monster: int) -> Array[SimEvent]:
	var spell := SimEvent.new(SimEvent.Kind.ABILITY_USED, tick, MAGE, monster)
	spell.ability_id = &"frost_nova"
	return [spell]


func _bolt(tick: int, monster: int) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.PROJECTILE_LAUNCHED, tick, MAGE, monster, 20)]


func _learned(tick: int, _monster_id: int) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.MICROSKILL_LEARNED, tick, KNIGHT, 0, 2)]


## A level up to a level not told before, so the journal has a new line for it.
func _level_up(tick: int, _monster_id: int) -> Array[SimEvent]:
	_levels_told += 1
	var level: int = _main.simulation.party.hero(KNIGHT).level + _levels_told
	return [SimEvent.new(SimEvent.Kind.LEVEL_UP, tick, -1, KNIGHT, level)]


func _bought(tick: int, _monster_id: int) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.UPGRADE_BOUGHT, tick, 0, -1, 1)]


## An event no listener acts on, for a burst started by hand.
func _nothing(tick: int, _monster_id: int) -> Array[SimEvent]:
	return [SimEvent.new(SimEvent.Kind.TARGET_DEPTH_CHANGED, tick, -1, -1, 1)]


# --- R2 ------------------------------------------------------------------------


func test_r2_every_kind_stops_at_its_budget() -> void:
	var sim := Simulation.new(SEED)
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	var fx := CombatEffects.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.setup(world, sim)
	var makers: Dictionary[StringName, Callable] = {
		&"combat": fx.new_particle.bind(&"filler"),
		&"ability": fx.ability_effects._particle.bind(&"filler"),
		&"spell": fx.spell_effects._particle.bind(&"filler"),
		&"quest": fx.quest_effects._particle.bind(&"filler"),
	}
	var caps: Dictionary[StringName, int] = {
		&"combat": CombatEffects.MAX_PARTICLES,
		&"ability": AbilityEffects.MAX_PARTICLES,
		&"spell": SpellEffects.MAX_PARTICLES,
		&"quest": QuestEffects.MAX_PARTICLES,
	}
	assert_eq(caps, {&"combat": 300, &"ability": 150, &"spell": 120, &"quest": 120}, "the caps")
	for budget: StringName in makers:
		var made: Object = null
		for i: int in caps[budget]:
			made = makers[budget].call()
			assert_not_null(made, "%s: particle %d is made" % [budget, i])
		made = makers[budget].call()
		assert_null(made, "%s: one more than its cap is not" % budget)
		assert_eq(world.fx.count(budget), caps[budget], "%s: holds its cap" % budget)
	assert_eq(fx.quest_effects.live_particles(), 120, "quest effects stop at theirs")
	var guardian: FxParticle = fx.new_particle(&"guardian", CombatEffects.GUARDIAN_ALLOWANCE)
	assert_not_null(guardian, "a guardian's death may go past combat's cap by its allowance")
	assert_eq(world.effects_layer.get_child_count(), 300 + 150 + 120 + 120 + 1, "all on the layer")


func test_r2_the_layer_empties_after_quiet() -> void:
	_start_main()
	var sim: Simulation = _main.simulation
	var died: Array[bool] = [false]
	_main.world.sim_event.connect(
		func(event: SimEvent) -> void:
			if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
				died[0] = true
	)
	var busy: int = 0
	for i: int in 6000:
		_step_frame()
		busy = maxi(busy, _main.world.fx.count())
		if died[0] and sim.expedition.state == Expedition.State.FIGHTING:
			break
	assert_true(died[0], "(a monster died in a fight)")
	assert_gt(busy, 0, "(the fight made effects)")
	for i: int in roundi(5.0 / FRAME):
		_main.world.sync(FRAME)
		_main.effects.advance(FRAME)
	await get_tree().process_frame
	assert_eq(_main.world.fx.count(), 0, "the pool holds nothing")
	assert_eq(_main.world.effects_layer.get_child_count(), 0, "nor does the effects layer")


# --- R3 ------------------------------------------------------------------------


func test_r3_nothing_starts_for_an_old_event() -> void:
	_start_fight()
	for probe: String in _probes():
		var old: int = _main.simulation.tick - World.ANIMATE_TICKS * maxi(_main.world.speed, 1) - 1
		assert_false(_send(probe, old), "an old event starts nothing: %s" % probe)
		assert_true(_send(probe, _main.simulation.tick), "a fresh one starts it: %s" % probe)


func test_r3_nothing_starts_while_catching_up() -> void:
	_start_fight()
	for probe: String in _probes():
		assert_false(_send(probe, 0, true), "a fresh event in a stall starts nothing: %s" % probe)
		assert_true(_main.world.catching_up(), "(that sync caught up on a stall: %s)" % probe)
		assert_true(_send(probe, _main.simulation.tick), "the next one starts it: %s" % probe)


func test_r3_listeners_ask_the_gate() -> void:
	var calls: RegEx = RegEx.create_from_string("\\.catching_up\\(\\)")
	for path: String in _code_files():
		if path == "res://game/world/world.gd":
			continue
		var file: String = path.trim_prefix("res://")
		var function: String = ""
		var number: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			if line.begins_with("func ") or line.begins_with("static func "):
				function = line.get_slice("func ", 1).get_slice("(", 0)
			var code: String = line.get_slice("#", 0)
			assert_false(code.contains("is_recent("), "%s:%d asks is_recent" % [file, number])
			if calls.search(code) != null:
				var where: String = "%s:%s" % [file, function]
				assert_has(CLEARING, where, "%s:%d asks catching_up to start" % [file, number])


# --- R4 ------------------------------------------------------------------------


func test_r4_handlers_have_one_name() -> void:
	var connects: RegEx = RegEx.create_from_string("sim_event\\.connect\\(([^,)]*)")
	var connected: int = 0
	for path: String in _code_files():
		var text: String = FileAccess.get_file_as_string(path)
		assert_false(text.contains("func hear("), "%s has a hear" % path)
		for found: RegExMatch in connects.search_all(text):
			connected += 1
			assert_eq(found.get_string(1), "_on_sim_event", "%s connects its own handler" % path)
	assert_gt(connected, 10, "(the listeners were read)")
	_start_main()
	var hears: Array[String] = []
	for connection: Dictionary in _main.world.sim_event.get_connections():
		var handler: Callable = connection["callable"]
		hears.append(handler.get_method())
	for method: String in hears:
		if method != "_on_sim_event":
			assert_true(method.begins_with("<anonymous"), "%s hears the world's events" % method)


# --- R6 ------------------------------------------------------------------------


func test_r6_a_still_level_is_not_redrawn() -> void:
	_start_main()
	_main.world.set_process(true)
	for i: int in 5:
		await get_tree().process_frame
	var levels: Array[AmbienceLevel] = []
	var before: Array[int] = []
	for depth: int in _main.world.ambience.built_depths():
		var level: AmbienceLevel = _main.world.ambience.level(depth)
		levels.append(level)
		before.append(level.buried_draws)
	assert_false(levels.is_empty(), "(a level is built)")
	for i: int in 60:
		await get_tree().process_frame
	for i: int in levels.size():
		assert_gt(before[i], 0, "depth %d's buried things were drawn" % levels[i].depth)
		assert_eq(levels[i].buried_draws, before[i], "and not again while it is still")


# --- R7 ------------------------------------------------------------------------


func test_r7_every_moment_is_one_row() -> void:
	var rows: Array[Array] = []
	for row: Array in Showcase.ROWS:
		rows.append([row[0], row[1]])
	assert_eq(rows, MOMENTS, "the moments' names and captions, in order")
	assert_eq(Showcase.names().size(), MOMENTS.size(), "one row each")
	for row: Array in Showcase.ROWS:
		assert_eq(row.size(), 5, "%s: name, caption, linger, start and how it is seen" % row[0])

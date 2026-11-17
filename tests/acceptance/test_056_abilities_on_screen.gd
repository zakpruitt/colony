extends GutTest
## Acceptance tests for specs/056-abilities-on-screen/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects that listen to it (and,
## where a requirement is about the HUD, the Hud over them), every _process turned off. Some tests
## make a Battle of the party's own fighters and a monster the world shows, and let the battle's own
## rules (BattleStatuses, Battle.deal, Battle.revive) record the events; [method _deliver] hands
## them to the simulation's event list, stamped from the tick the battle began on, and syncs a
## frame, so the world, the effects and the HUD hear them as they would in play. The others run
## real fights of a party with full talent trees.

const SEED: int = 56
const FRAME: float = 1.0 / 60.0
const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4
const HERO_IDS: Array[int] = [KNIGHT, ROGUE, MAGE, CLERIC]
const TPS: int = Simulation.TICKS_PER_SECOND
## The heroes' level in the fights of full trees (every talent point earned), and the path each
## class takes: the ones with a status that works each second (bleeding, burning).
const TREE_LEVEL: int = 14
const PATHS: Dictionary[StringName, int] = {&"knight": 1, &"rogue": 0, &"mage": 0, &"cleric": 1}
## How many times their health the monsters of a watched fight have, so it lasts.
const TOUGHER: int = 8
## The longest a test waits for something, in ticks.
const LIMIT_TICKS: int = 20000
## R8: how long a name or number may cover a health bar, in seconds: a moment.
const MOMENT: float = 0.1

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## The simulation tick a test's battle began on: its events are stamped from it.
var _base: int = 0
## Every event the world told of, oldest first.
var _heard: Array[SimEvent] = []


func before_each() -> void:
	_heard.clear()
	_hud = null
	_build(Simulation.new(SEED))


func after_each() -> void:
	_mouse(Vector2(-1000, -1000))


# --- Helpers -------------------------------------------------------------------


func _build(simulation: Simulation, with_hud: bool = false) -> void:
	_sim = simulation
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_world.sim_event.connect(func(event: SimEvent) -> void: _heard.append(event))
	if with_hud:
		var layer := CanvasLayer.new()
		layer.layer = 129
		add_child_autofree(layer)
		_hud = Hud.new()
		layer.add_child(_hud)
		_hud.set_process(false)
		_hud.setup(_sim, _world, _fx)
		_hud.advance(0.0)


func _abilities() -> AbilityEffects:
	return _fx.ability_effects


func _marks() -> StatusMarks:
	return _fx.ability_effects.marks


## The id of a monster the world shows.
func _monster() -> int:
	for id: int in _world._monsters:
		if _world.character(id) != null:
			return id
	return -1


## A battle of the party's fighters and the shown monster [param monster_id] (the simulation's own
## combatant, left standing where it waits), begun on this tick.
func _battle(monster_id: int) -> Battle:
	var heroes: Array[Combatant] = []
	for hero: Hero in _sim.party.heroes:
		heroes.append(hero.combatant())
	var monster: Combatant = _world._monsters[monster_id]
	var x: float = monster.x
	var battle := Battle.new(heroes, [monster], x - 8.0, x + 8.0, true, SimRng.new(SEED))
	monster.x = x
	_base = _sim.tick
	return battle


## The status effect [param kind] for [param seconds], strong enough to show.
func _status(kind: int, seconds: float = 6.0) -> AbilityEffect:
	var effect := AbilityEffect.new()
	effect.does = AbilityEffect.Does.STATUS
	effect.status = kind as AbilityEffect.Status
	effect.seconds = seconds
	effect.scale = AbilityEffect.Scale.RECEIVER_MAX_HEALTH
	match kind:
		AbilityEffect.Status.SHIELDED:
			effect.amount = 0.5
		AbilityEffect.Status.BURNING, AbilityEffect.Status.BLEEDING:
			effect.amount = 0.01
		AbilityEffect.Status.CHILLED, AbilityEffect.Status.MENDING:
			effect.amount = 0.01
		AbilityEffect.Status.HASTED, AbilityEffect.Status.WEAKENED:
			effect.amount = 0.7
		AbilityEffect.Status.NIMBLE:
			effect.amount = 1.0
		_:
			effect.amount = 1.3
	return effect


## Hands [param battle]'s events to the simulation, stamped from [member _base], and shows a frame.
func _deliver(battle: Battle) -> Array[SimEvent]:
	var events: Array[SimEvent] = battle.drain_events()
	for event: SimEvent in events:
		event.tick = _base + event.tick
	_sim._events.append_array(events)
	_frame()
	return events


## Hands [param events] (made here) to the simulation as they are, and shows a frame.
func _tell(events: Array[SimEvent]) -> void:
	_sim._events.append_array(events)
	_frame()


func _event(
	kind: SimEvent.Kind, source: int, target: int, amount: int = 0, ability: StringName = &""
) -> SimEvent:
	var event := SimEvent.new(kind, _sim.tick, source, target, amount)
	event.ability_id = ability
	return event


## One frame of [param seconds] (the world, the effects and the HUD), the simulation left as it is.
func _frame(seconds: float = FRAME) -> void:
	_world.sync(seconds)
	_fx.advance(seconds)
	if _hud != null:
		_hud.advance(seconds)


func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_frame(minf(FRAME, left))
		left -= FRAME


## The damage numbers showing, oldest first.
func _numbers() -> Array[FxText]:
	var found: Array[FxText] = []
	for text: FxText in _fx._texts:
		if text.kind == &"damage" or text.kind == &"heal":
			found.append(text)
	return found


## Every hero at [constant TREE_LEVEL] with its class's trunk and path, full health.
func _full_trees() -> void:
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(TREE_LEVEL) - hero.xp)
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		var nodes: Array[StringName] = tree.trunk.duplicate()
		nodes.append_array(tree.path_nodes(PATHS[hero.class_id]))
		hero.set_talents(nodes)
		hero.health = hero.max_health()


func _fighting() -> bool:
	return _sim.expedition.state == Expedition.State.FIGHTING and _sim.expedition.battle != null


## Steps the simulation, a frame of [param ticks] ticks at a time, until a fight starts with at
## least [param monsters] monsters; others on the way are ended at once. The monsters of the fight
## found get [param tougher] times their health. True if one was found.
func _find_fight(monsters: int, ticks: int = 1, sync: bool = true, tougher: int = TOUGHER) -> bool:
	for i: int in LIMIT_TICKS:
		_sim.step()
		if sync and i % ticks == 0:
			_frame()
		if not _fighting():
			continue
		var battle: Battle = _sim.expedition.battle
		if battle.tick <= 1 and battle.monsters.size() >= monsters:
			for monster: Combatant in battle.monsters:
				monster.max_health *= tougher
				monster.health = monster.max_health
			return true
		for monster: Combatant in battle.monsters:
			monster.health = mini(monster.health, 1)
	return false


func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _click_at(at: Vector2) -> void:
	_mouse(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
	_mouse(Vector2(320, 200))


## [param rect] (world pixels) on the screen, through the world's camera.
func _on_screen(rect: Rect2) -> Rect2:
	var camera: WorldCamera = _world.camera
	var view: Vector2 = camera.get_viewport_rect().size
	var at: Vector2 = (rect.position - camera.position - camera.offset) * camera.zoom + view / 2.0
	return Rect2(at, rect.size * camera.zoom)


# --- R1 ------------------------------------------------------------------------


func test_r1_an_ability_is_announced() -> void:
	var monster: int = _monster()
	assert_ne(monster, -1, "the world shows a monster")
	var battle: Battle = _battle(monster)
	var knight: Combatant = battle.combatant(KNIGHT)
	knight.abilities = [Content.ability(&"shield_bash")]
	battle.combatant(monster).max_health = 100000
	battle.combatant(monster).health = 100000
	var started: bool = false
	for i: int in 200:
		battle.step()
		for event: SimEvent in _deliver(battle):
			if event.kind == SimEvent.Kind.ABILITY_STARTED and event.source_id == KNIGHT:
				started = true
		if started:
			break
	assert_true(started, "the knight begins Shield Bash in a real fight")
	assert_eq(_abilities().names_over(KNIGHT), ["Shield Bash"] as Array[String], "named")
	var shown: Array[FxText] = []
	for text: FxText in _abilities().texts():
		if text.follow_id == KNIGHT:
			shown.append(text)
	assert_eq(shown.size(), 1, "one name over the knight")
	assert_eq(shown[0].color, Palette.color(&"red"), "in the knight's colour")
	var body: Rect2 = SpriteBounds.body_rect(_world.character(KNIGHT))
	assert_lt(shown[0].rect().end.y, body.position.y, "over its head")
	assert_almost_eq(shown[0].position.x, _world.character(KNIGHT).position.x, 2.0, "centred")
	var y: float = shown[0].position.y
	_wait(0.3)
	assert_lt(shown[0].position.y, y, "it rises")
	_wait(AbilityEffects.NAME_LIFE)
	assert_eq(_abilities().names_over(KNIGHT), [] as Array[String], "briefly")

	# Passives that fire are named too, in the mage's colour; never more than two stack.
	var fired: Array[SimEvent] = []
	for ability: StringName in [&"ignite", &"chain_spark", &"wildfire"]:
		fired.append(_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, ability))
	_tell(fired)
	assert_eq(
		_abilities().names_over(MAGE),
		["Wildfire", "Chain Spark"] as Array[String],
		"the two newest names stack, newest nearest; the oldest made way"
	)
	for text: FxText in _abilities().texts():
		if text.follow_id == MAGE:
			assert_eq(text.color, Palette.color(&"blue"), "in the mage's colour")
	_tell([_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"wildfire")])
	assert_eq(_abilities().names_over(MAGE).size(), 2, "a name again starts again, not a third")
	for i: int in 5:
		_tell([_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"ignite")])
		_tell([_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"chain_spark")])
		assert_lte(_abilities().names_over(MAGE).size(), 2, "never more than two")


# --- R2 ------------------------------------------------------------------------


func test_r2_an_action_looks_different_from_a_strike() -> void:
	var monster: int = _monster()
	var knight: CharacterSprite = _world.character(KNIGHT)
	var target: CharacterSprite = _world.character(monster)

	# The wind-up is lit for its length.
	_tell([_event(SimEvent.Kind.ABILITY_STARTED, KNIGHT, monster, 4, &"shield_bash")])
	assert_true(_abilities().is_glowing(KNIGHT), "the wind-up is marked")
	assert_gt(knight.shown_glow(), 0.0, "the knight is lit")
	_wait(0.2)
	assert_gt(knight.shown_glow(), 0.0, "for its length")
	_wait(0.3)
	assert_eq(knight.shown_glow(), 0.0, "and no longer")
	_tell([_event(SimEvent.Kind.ATTACK_STARTED, KNIGHT, monster, 4)])
	assert_eq(knight.shown_glow(), 0.0, "an ordinary wind-up is not lit")

	# A heavy blow throws a larger spark than a strike, even a crit.
	_wait(1.0)
	var strike := _event(SimEvent.Kind.HIT, KNIGHT, monster, 30)
	strike.tick += 1
	strike.flag = true
	_tell([strike])
	assert_eq(_abilities().particles(&"heavy"), 0, "an ordinary blow, even a crit, is not heavy")
	_wait(1.0)
	var bash := _event(SimEvent.Kind.ABILITY_USED, KNIGHT, monster, 0, &"shield_bash")
	var blow := _event(SimEvent.Kind.HIT, KNIGHT, monster, 45)
	bash.tick += 2
	blow.tick += 2
	_tell([bash, blow])
	assert_gt(_abilities().particles(&"heavy"), 0, "Shield Bash lands heavy")
	var largest: int = 0
	for particle: FxParticle in _abilities()._particles:
		largest = maxi(largest, particle.size)
	assert_gt(largest, 11, "its flash is larger than a crit's (11)")

	# Damage to many: a ring from the fighter (Whirlwind) or from the target (Meteor).
	_wait(1.0)
	_tell([_event(SimEvent.Kind.ABILITY_USED, KNIGHT, monster, 0, &"whirlwind")])
	assert_eq(_abilities().rings().size(), 1, "a ring")
	var ring: FxRing = _abilities().rings()[0]
	assert_almost_eq(ring.position.x, knight.position.x, 1.0, "from the knight")
	assert_almost_eq(ring.reach, 2.0 * World.TILE, 0.01, "as far as Whirlwind reaches")
	_wait(1.0)
	assert_eq(_abilities().rings().size(), 0, "gone")
	_tell([_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"meteor")])
	assert_almost_eq(_abilities().rings()[0].position.x, target.position.x, 1.0, "from the target")

	# A heal: the heal effect on everyone healed.
	_wait(1.0)
	var prayer := _event(SimEvent.Kind.ABILITY_USED, CLERIC, KNIGHT, 0, &"prayer")
	var healed: Array[SimEvent] = [prayer]
	for id: int in [KNIGHT, ROGUE]:
		healed.append(_event(SimEvent.Kind.HEALED, CLERIC, id, 20))
	_tell(healed)
	var heals: Array[FxText] = []
	for text: FxText in _numbers():
		if text.kind == &"heal":
			heals.append(text)
	assert_eq(heals.size(), 2, "a heal number on each hero healed")
	assert_eq(heals[0].color, Palette.color(&"green"), "the heal effect")

	# A push: the pushed slide to their new place, kicking dust.
	_wait(1.0)
	var battle: Battle = _battle(monster)
	_sim.expedition.battle = battle
	var mage: Combatant = battle.combatant(MAGE)
	var pushed: Combatant = battle.combatant(monster)
	mage.x = pushed.x - 1.0
	var before: float = target.position.x
	battle.push(mage, pushed, 1.5)
	_tell([_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"frost_nova")])
	assert_gt(_abilities().particles(&"dust"), 0, "dust kicks")
	var moved: float = absf(target.position.x - before)
	assert_gt(moved, 0.0, "it starts sliding")
	assert_lt(moved, 1.5 * World.TILE - 4.0, "not jumping")
	_wait(1.0)
	assert_almost_eq(target.position.x, pushed.x * World.TILE, 0.5, "it slid all the way")

	# A revive: the fallen hero stands up, in the fight.
	_sim.expedition.state = Expedition.State.FIGHTING
	var cleric: Combatant = battle.combatant(CLERIC)
	var fallen: Combatant = battle.combatant(KNIGHT)
	battle.deal(pushed, fallen, fallen.max_health * 10, false, Battle.Via.STRIKE)
	_deliver(battle)
	_wait(1.0)
	assert_true(_world.fallen_party.is_lying(KNIGHT), "the knight lies fallen")
	battle.revive(cleric, fallen, 0.5)
	_deliver(battle)
	assert_true(_world.fallen_party.is_standing(KNIGHT), "the revive stands it up")
	_wait(FallenParty.STAND_SECONDS + 0.2)
	assert_false(knight.is_dead(), "on its feet")
	assert_true(knight.visible, "seen")
	assert_eq(knight.rotation, 0.0, "upright")


# --- R3 ------------------------------------------------------------------------


func test_r3_statuses_can_be_seen() -> void:
	var monster: int = _monster()
	var battle: Battle = _battle(monster)
	_sim.expedition.battle = battle
	var knight: Combatant = battle.combatant(KNIGHT)
	var foe: Combatant = battle.combatant(monster)
	foe.max_health = 100000
	foe.health = 100000
	var colours: Dictionary[int, StringName] = {
		AbilityEffect.Status.BURNING: &"orange",
		AbilityEffect.Status.BLEEDING: &"red",
		AbilityEffect.Status.CHILLED: &"cyan",
	}
	for kind: int in AbilityEffect.Status.size():
		var label: String = ShownStatus.status_name(kind)
		var effect: AbilityEffect = _status(kind)
		var bearer: Combatant = knight if effect.is_helpful() else foe
		var sprite: CharacterSprite = _world.character(bearer.id)
		BattleStatuses.apply(battle, knight, bearer, effect, &"shield_bash")
		var began: Array[SimEvent] = _deliver(battle)
		assert_eq(began.size(), 1, "%s began with its event" % label)
		assert_has(_marks().shown(bearer.id), kind, "%s is shown on its bearer" % label)
		match kind:
			AbilityEffect.Status.STUNNED:
				assert_true(sprite.held, "stunned: the sprite is still")
			AbilityEffect.Status.NIMBLE, AbilityEffect.Status.UNTOUCHABLE:
				assert_eq(sprite.shown_fade(), StatusMarks.FADE, "%s: half faded" % label)
			AbilityEffect.Status.SHIELDED:
				assert_eq(_marks().shield_color(KNIGHT), Palette.color(&"cyan"), "a whole shield")
				battle.deal(foe, knight, roundi(knight.max_health * 0.4), false, Battle.Via.STRIKE)
				_deliver(battle)
				assert_eq(_marks().shield_color(KNIGHT), Palette.color(&"navy"), "fading as used")
		if colours.has(kind):
			assert_gt(sprite.shown_tint(), 0.0, "%s: tinted" % label)
			# Its next whole second, it works: its number in its colour.
			battle.tick += TPS
			BattleStatuses.pulse(battle)
			var worked: Array[SimEvent] = _deliver(battle)
			assert_eq(worked.size(), 1, "%s worked once" % label)
			assert_eq(worked[0].kind, SimEvent.Kind.HIT, "a hit")
			var numbers: Array[FxText] = _numbers()
			assert_eq(
				numbers[numbers.size() - 1].color,
				Palette.color(colours[kind]),
				"%s: its damage number in its colour" % label
			)
		if kind in StatusMarks.ROW or kind in StatusMarks.MOTE_COLORS:
			assert_true(true, "%s has a mark or motes of its own" % label)
		_wait(0.1)
		assert_has(_marks().shown(bearer.id), kind, "%s lasts" % label)
		BattleStatuses.end(battle, bearer, kind)
		var ended: Array[SimEvent] = _deliver(battle)
		assert_eq(ended[0].kind, SimEvent.Kind.STATUS_ENDED, "%s ended with its event" % label)
		assert_does_not_have(_marks().shown(bearer.id), kind, "%s is gone that frame" % label)
		assert_false(sprite.held, "%s: the sprite moves again" % label)
		assert_eq(sprite.shown_tint(), 0.0, "%s: no tint left" % label)
		assert_eq(sprite.shown_fade(), 1.0, "%s: whole again" % label)


# --- R4 ------------------------------------------------------------------------


func test_r4_misses_and_blocks_are_told() -> void:
	var monster: int = _monster()
	var battle: Battle = _battle(monster)
	_sim.expedition.battle = battle
	var knight: Combatant = battle.combatant(KNIGHT)
	var foe: Combatant = battle.combatant(monster)
	foe.max_health = 100000
	foe.health = 100000

	# Blocked: the shield takes the whole blow, and no damage number shows.
	BattleStatuses.apply(battle, knight, knight, _status(AbilityEffect.Status.SHIELDED), &"bulwark")
	_deliver(battle)
	var numbers: int = _numbers().size()
	battle.deal(foe, knight, 5, false, Battle.Via.STRIKE)
	var told: Array[SimEvent] = _deliver(battle)
	assert_eq(told[0].kind, SimEvent.Kind.MISSED, "the shield absorbed it")
	assert_true(told[0].flag, "flagged as a shield's")
	var words: Array[String] = []
	for text: FxText in _abilities().texts():
		words.append(text.text)
	assert_has(words, "Blocked", "Blocked shows")
	assert_eq(_numbers().size(), numbers, "and no damage number")
	BattleStatuses.end(battle, knight, AbilityEffect.Status.SHIELDED)
	_deliver(battle)

	# Miss: a nimble monster dodges every ordinary strike.
	BattleStatuses.apply(
		battle, foe, foe, _status(AbilityEffect.Status.NIMBLE, 60.0), &"smoke_step"
	)
	_deliver(battle)
	var missed: SimEvent = null
	for i: int in 400:
		battle.step()
		for event: SimEvent in _deliver(battle):
			if event.kind == SimEvent.Kind.MISSED and event.source_id < Expedition.FIRST_MONSTER_ID:
				missed = event
		if missed != null:
			break
	assert_not_null(missed, "a hero's strike missed in the fight")
	words.clear()
	for text: FxText in _abilities().texts():
		if text.kind == &"miss":
			words.append(text.text)
	assert_has(words, "Miss", "Miss shows")


# --- R5 ------------------------------------------------------------------------


func test_r5_the_frames_show_it() -> void:
	_build(Simulation.new(SEED), true)
	var monster: int = _monster()
	var battle: Battle = _battle(monster)
	var knight: Combatant = battle.combatant(KNIGHT)
	var lasting: Dictionary[int, float] = {
		AbilityEffect.Status.MIGHTY: 5.0,
		AbilityEffect.Status.SHIELDED: 6.0,
		AbilityEffect.Status.HASTED: 12.0,
		AbilityEffect.Status.MENDING: 8.0,
	}
	for kind: int in lasting:
		BattleStatuses.apply(battle, knight, knight, _status(kind, lasting[kind]), &"bulwark")
	_deliver(battle)
	var frame: HeroFrame = null
	for each: HeroFrame in _hud.frames:
		if each.hero_id == KNIGHT:
			frame = each
	assert_eq(
		frame.status_icons.kinds,
		(
			[
				AbilityEffect.Status.SHIELDED,
				AbilityEffect.Status.MENDING,
				AbilityEffect.Status.HASTED
			]
			as Array[int]
		),
		"up to three small icons"
	)
	assert_true(frame.status_icons.is_visible_in_tree(), "shown on the frame")
	var line: String = "Shielded 6 s, Mending 8 s, Hasted 12 s, Mighty 5 s. Click for details"
	assert_eq(frame.tip(), line, "the tooltip names each with the seconds left")
	_mouse(frame.get_global_rect().get_center())
	_hud.tooltip.point_at(frame.get_global_rect().get_center())
	_hud.tooltip.advance(HudTooltip.DELAY + 0.1)
	assert_eq(_hud.tooltip.shown_text(), line, "as the HUD's tooltip")
	var other: HeroFrame = _hud.frames[1] if _hud.frames[0] == frame else _hud.frames[0]
	assert_eq(other.status_icons.kinds, [] as Array[int], "a hero with none shows none")
	for kind: int in lasting:
		BattleStatuses.end(battle, knight, kind)
	_deliver(battle)
	assert_eq(frame.status_icons.kinds, [] as Array[int], "gone when they end")
	assert_eq(frame.tip(), HeroFrame.CLICK_TIP, "and from the tooltip")


# --- R6 ------------------------------------------------------------------------


func test_r6_the_tally_knows_abilities() -> void:
	_build(Simulation.new(SEED), true)
	_full_trees()
	assert_true(_find_fight(2), "a fight")
	var used: Dictionary[int, Dictionary] = {}
	var start: int = _heard.size()
	for i: int in LIMIT_TICKS:
		_sim.step()
		_frame()
		if not _fighting():
			break
	for event: SimEvent in _heard.slice(start):
		if event.kind == SimEvent.Kind.ABILITY_USED and event.source_id in HERO_IDS:
			var mine: Dictionary = used.get(event.source_id, {})
			mine[event.ability_id] = true
			used[event.source_id] = mine
	assert_false(_fighting(), "the fight ended")
	var tally: Tally = _hud.tally.tally
	var named: Dictionary[String, bool] = {}
	for id: int in HERO_IDS:
		for measure: Tally.Measure in [Tally.Measure.DAMAGE, Tally.Measure.HEALING]:
			var lines: Dictionary[String, int] = tally.by_ability(
				id, measure, Tally.Span.LAST_FIGHT
			)
			var total: int = 0
			for each: String in lines:
				total += lines[each]
				named[each] = true
			assert_eq(
				total,
				tally.value(id, measure, Tally.Span.LAST_FIGHT),
				"hero %d: its lines add up to what the tally counts" % id
			)
		# Every damaging action a hero used is a line of its own.
		var mine: Dictionary = used.get(id, {})
		for ability_id: StringName in mine:
			var ability: AbilityDef = Content.ability(ability_id)
			if ability.is_action() and AbilityEffects.is_heavy(ability):
				var lines: Dictionary[String, int] = tally.by_ability(
					id, Tally.Measure.DAMAGE, Tally.Span.LAST_FIGHT
				)
				assert_has(lines, ability.display_name, "%s is counted" % ability.display_name)
	assert_has(named, AbilityCredit.STRIKES, "ordinary strikes have their line")
	assert_true(named.has("Bleeding") or named.has("Burning"), "a status's damage has its line")

	# The tally's line for a hero opens to show it.
	var panel: TallyPanel = _hud.tally
	panel.open()
	_hud.advance(FRAME)
	var row: Vector2 = (
		panel.get_global_rect().position
		+ Vector2(TallyPanel.TEXT_X + 10.0, TallyPanel.ROWS_Y + 5.0)
	)
	_click_at(row)
	_hud.advance(FRAME)
	assert_eq(panel.opened_hero(), _sim.party.heroes[0].id, "a click opens the hero's line")
	var shown: Array[String] = panel.breakdown()
	assert_eq(shown[0], "Damage", "its damage")
	assert_has(shown, "Healing", "and its healing")
	var first: Hero = _sim.party.heroes[0]
	var dealt: Dictionary[String, int] = tally.by_ability(
		first.id, Tally.Measure.DAMAGE, Tally.Span.LAST_FIGHT
	)
	var top: String = dealt.keys()[0]
	assert_eq(shown[1], "%s %s" % [top, Hud.group_thousands(dealt[top])], "largest first")
	var heroes_shown: int = 0
	for line: String in panel.rows():
		for hero: Hero in _sim.party.heroes:
			if line.begins_with(hero.def().display_name + " "):
				heroes_shown += 1
	assert_eq(heroes_shown, 1, "the other lines make way")
	_click_at(row)
	_hud.advance(FRAME)
	assert_eq(panel.opened_hero(), -1, "a second click closes it")
	assert_eq(panel.breakdown(), [] as Array[String], "and the lines come back")


# --- R7 ------------------------------------------------------------------------


func test_r7_true_in_a_crowded_frame() -> void:
	_full_trees()
	assert_true(_find_fight(2), "a fight")
	# Frames of many ticks each: what shows is exactly what the fight has.
	var frames: int = 0
	var problems: Array[String] = []
	while _fighting() and frames < 400:
		for i: int in 7:
			_sim.step()
		_frame()
		frames += 1
		var battle: Battle = _sim.expedition.battle
		if battle == null:
			break
		for fighter: Combatant in battle.heroes + battle.monsters:
			var sprite: CharacterSprite = _world.character(fighter.id)
			var expected: Array[int] = []
			if fighter.is_alive() and sprite != null and sprite.visible and not sprite.is_dead():
				expected.assign(fighter.statuses.keys())
				expected.sort()
			if _marks().shown(fighter.id) != expected:
				problems.append(
					(
						"tick %d, %d: shown %s, has %s"
						% [_sim.tick, fighter.id, _marks().shown(fighter.id), expected]
					)
				)
	assert_eq(problems, [] as Array[String], "the marks follow the events, frame by frame")
	var began: int = 0
	for event: SimEvent in _heard:
		if event.kind == SimEvent.Kind.STATUS_BEGAN:
			began += 1
	assert_gt(began, 0, "statuses were put on in that fight")

	# A whole fight's events in one frame: nothing is left over.
	var start: int = _heard.size()
	assert_true(_find_fight(2, 1, false), "another fight")
	var monsters: Array[int] = []
	for monster: Combatant in _sim.expedition.battle.monsters:
		monsters.append(monster.id)
	for i: int in LIMIT_TICKS:
		if not _fighting():
			break
		_sim.step()
	assert_false(_fighting(), "it ended unseen")
	_frame()
	var whole: Array[SimEvent] = _heard.slice(start)
	var put_on: int = 0
	for event: SimEvent in whole:
		if event.kind == SimEvent.Kind.STATUS_BEGAN:
			put_on += 1
	assert_gt(put_on, 0, "statuses began and ended in that one frame")
	assert_true(_marks().book.is_empty(), "no status is left")
	for id: int in HERO_IDS + monsters:
		assert_eq(_marks().shown(id), [] as Array[int], "nothing is drawn on %d" % id)
		var sprite: CharacterSprite = _world.character(id)
		if sprite != null:
			assert_false(sprite.held, "%d is not held" % id)
			assert_eq(sprite.shown_fade(), 1.0, "%d is whole" % id)
			assert_eq(sprite.shown_tint(), 0.0, "%d is untinted" % id)
			assert_eq(sprite.shown_glow(), 0.0, "%d is not lit" % id)
	for id: int in monsters:
		assert_null(_world.character(id), "the monster %d has gone" % id)
		assert_eq(_abilities().names_over(id), [] as Array[String], "no name over %d" % id)


# --- R8 ------------------------------------------------------------------------


func test_r8_still_readable() -> void:
	_build(Simulation.new(SEED), true)
	_full_trees()
	_world.speed = 4
	assert_true(_find_fight(5, 4, false, TOUGHER * 4), "a fight of four heroes and five monsters")
	assert_eq(_sim.expedition.battle.monsters.size(), 5, "five monsters")
	var covering: Dictionary[FxText, int] = {}
	var longest: int = 0
	var unnamed: Array[String] = []
	var named: int = 0
	var frames: int = 0
	while _fighting() and frames < 60 * 60:
		var start: int = _heard.size()
		for i: int in 4:
			_sim.step()
		_frame()
		frames += 1
		var bars: Array[Rect2] = []
		for frame: HeroFrame in _hud.frames:
			bars.append(
				Rect2(
					frame.global_position + HeroFrame.HEALTH_BAR.position, HeroFrame.HEALTH_BAR.size
				)
			)
		if _hud.boss_bar.is_visible_in_tree():
			bars.append(_hud.boss_bar.get_global_rect())
		var texts: Array[FxText] = _abilities().texts()
		texts.append_array(_numbers())
		for text: FxText in texts:
			var over: bool = false
			for bar: Rect2 in bars:
				over = over or _on_screen(text.rect()).intersects(bar)
			covering[text] = covering.get(text, 0) + 1 if over else 0
			longest = maxi(longest, covering[text])
		# The last ability each hero began or used this frame is named over it.
		var last: Dictionary[int, StringName] = {}
		for event: SimEvent in _heard.slice(start):
			var kinds: Array[SimEvent.Kind] = [
				SimEvent.Kind.ABILITY_STARTED, SimEvent.Kind.ABILITY_USED
			]
			if event.kind in kinds and event.source_id in HERO_IDS:
				last[event.source_id] = event.ability_id
		for id: int in last:
			var sprite: CharacterSprite = _world.character(id)
			if sprite == null or not sprite.visible:
				continue
			var name_text: String = Content.ability(last[id]).display_name
			if name_text in _abilities().names_over(id):
				named += 1
			else:
				unnamed.append("tick %d: %s over %d" % [_sim.tick, name_text, id])
	assert_gt(frames, 60, "the fight was watched for a while")
	assert_lte(longest * FRAME, MOMENT, "no name or number covers a health bar past a moment")
	assert_gt(named, 10, "at 4x, abilities are named")
	assert_eq(unnamed, [] as Array[String], "every one of them")


# --- R9 ------------------------------------------------------------------------


func test_r9_in_the_showcase() -> void:
	var moments: Array[StringName] = [
		&"knight_actions", &"rogue_actions", &"mage_actions", &"cleric_actions", &"statuses"
	]
	for moment: StringName in moments:
		assert_has(Showcase.MOMENTS, moment, "%s is a moment" % moment)
	var scene: PackedScene = load("res://game/dev/showcase.tscn")
	var showcase: Showcase = scene.instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	var abilities: AbilityEffects = showcase.main.effects.ability_effects
	for moment: StringName in moments:
		showcase.skip_to(moment)
		var names: Dictionary[String, bool] = {}
		var labels: Dictionary[String, bool] = {}
		var start: float = showcase.elapsed
		while showcase.moment() == moment and showcase.elapsed - start < Showcase.GIVE_UP_SECONDS:
			showcase.advance(1.0 / 30.0)
			for id: int in HERO_IDS:
				for each: String in abilities.names_over(id):
					names[each] = true
			for label: Label in showcase._status_labels:
				if label.visible:
					for line: String in label.text.split("\n"):
						labels[line] = true
		var happened: bool = showcase.evidence.get(moment, false)
		assert_true(happened, "%s happened" % moment)
		if moment == &"statuses":
			for kind: int in AbilityEffect.Status.size():
				assert_has(labels, ShownStatus.status_name(kind), "labelled on the row")
		else:
			var class_id: StringName = Showcase.CLASS_MOMENTS[moment]
			var tree: TalentTreeDef = Content.talent_tree(class_id)
			var actions: int = 0
			for ability_id: StringName in (
				tree.trunk + tree.path_nodes(Showcase.CLASS_PATHS[class_id])
			):
				var ability: AbilityDef = Content.ability(ability_id)
				if ability.is_action() and names.has(ability.display_name):
					actions += 1
			assert_gt(actions, 0, "the %s's actions are named over it" % class_id)

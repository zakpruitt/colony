extends "res://tests/support/main_fixture.gd"
## Acceptance tests for specs/116-summoned-allies-on-screen/spec.md, one per requirement.
##
## Each test plays the main scene a frame at a time (a tick every [constant FRAMES_PER_TICK]
## frames, so the game runs as fast as real time), finds a fight, makes its monsters last and
## gives the Knight's fighter summoning actions built here, as spec 115's tests build theirs: a
## hawk (moves, strikes from 4 tiles), a turret (never moves, range 5), a totem (heals) and their
## kin. The abilities are put into Content for the test and taken out after it.

## Frames a tick lasts at 60 frames a second and 10 ticks a second.
const FRAMES_PER_TICK: int = 6
const TILE: float = World.TILE
const KNIGHT_COLOUR: StringName = &"red"
## The most ticks a test waits for a summon to arrive, strike, end.
const WAIT_TICKS: int = 300

## Abilities a test put into Content for a while, taken out after it.
var _added: Array[StringName] = []
## Every event the world told of since [method _fight].
var _heard: Array[SimEvent] = []


func before_each() -> void:
	_frame_parts = [&"effects", &"hud"]
	_heard.clear()


func after_each() -> void:
	for id: StringName in _added:
		Content._defs[Content.Kind.ABILITIES].erase(id)
	_added.clear()
	super()


# --- Helpers -------------------------------------------------------------------


func _summon_def(id: StringName, props: Dictionary) -> SummonDef:
	var def := SummonDef.new()
	def.id = id
	def.display_name = String(id).capitalize()
	for key: String in props:
		def.set(key, props[key])
	return def


func _hawk(props: Dictionary = {}) -> SummonDef:
	var values: Dictionary = {"move_speed": 3.0, "attack_range": 4.0, "seconds": 8.0}
	values.merge({"health_share": 0.5, "ahead": 2.0, "attack_interval": 0.8})
	values.merge(props, true)
	return _summon_def(&"hawk", values)


func _turret(props: Dictionary = {}) -> SummonDef:
	var values: Dictionary = {"move_speed": 0.0, "attack_range": 5.0, "seconds": 12.0}
	values.merge(props, true)
	return _summon_def(&"turret", values)


## An action of [param id] (named for it) with [param effects], ready at once, a one-tick
## wind-up, coming round every [param cooldown] seconds; put into Content for the test.
func _action(id: StringName, effects: Array[AbilityEffect], cooldown: float) -> AbilityDef:
	var ability := AbilityDef.new()
	ability.id = id
	ability.display_name = String(id).trim_prefix("test_").capitalize()
	ability.description = "Does what the test needs."
	ability.move = &"leap"
	ability.kind = AbilityDef.Kind.ACTION
	ability.aim = AbilityDef.Aim.SELF
	ability.cooldown = cooldown
	ability.windup = 0.1
	ability.ready_at_start = true
	ability.anywhere = true
	ability.effects = effects
	Content.ability(id)
	Content._defs[Content.Kind.ABILITIES][id] = ability
	_added.append(id)
	return ability


## An action that brings [param def], [param count] at a time, at most [param cap] at once.
func _summoning(
	id: StringName, def: SummonDef, cooldown: float = 1000.0, count: int = 1, cap: int = 1
) -> AbilityDef:
	var effect := AbilityEffect.new()
	effect.does = AbilityEffect.Does.SUMMON
	effect.lands = AbilityEffect.Lands.SELF
	effect.summon = def
	effect.count = count
	effect.summon_cap = cap
	return _action(id, [effect] as Array[AbilityEffect], cooldown)


## A hawk's own action: a dive on the nearest monster that hastes the hawk for a while.
func _dive() -> AbilityDef:
	var hit := AbilityEffect.new()
	hit.does = AbilityEffect.Does.DAMAGE
	hit.lands = AbilityEffect.Lands.TARGET
	hit.multiplier = 1.0
	var haste := AbilityEffect.new()
	haste.does = AbilityEffect.Does.STATUS
	haste.lands = AbilityEffect.Lands.SELF
	haste.status = AbilityEffect.Status.HASTED
	haste.seconds = 6.0
	haste.amount = 0.7
	var dive: AbilityDef = _action(&"test_dive", [hit, haste] as Array[AbilityEffect], 2.0)
	dive.aim = AbilityDef.Aim.NEAREST_ENEMY
	dive.reach = 4.0
	return dive


## A main scene in a fight whose monsters last (and, unless [param harmless] is false, barely
## hurt), the world settled on it; its events are heard into [member _heard] from then on.
func _fight(harmless: bool = true) -> Main:
	var main: Main = _main(ROOM_LARGE)
	var sim: Simulation = main.simulation
	var fighting: Callable = func() -> bool:
		var e: Expedition = sim.expedition
		return e.state == Expedition.State.FIGHTING and e.battle != null
	assert_true(step_until(sim, fighting, LIMIT_TICKS_5_MIN), "a fight")
	for monster: Combatant in sim.expedition.battle.monsters:
		monster.max_health *= 60
		monster.health = monster.max_health
		if harmless:
			monster.damage = 1
	_frame(main, 0)
	_frame(main, 0)
	assert_false(main.world.catching_up(), "the world has caught up with the fight")
	main.world.sim_event.connect(func(event: SimEvent) -> void: _heard.append(event))
	return main


func _knight(main: Main) -> Combatant:
	for hero: Hero in main.simulation.party.heroes:
		if hero.class_id == &"knight":
			return main.simulation.expedition.battle.combatant(hero.id)
	return null


## Gives the Knight's fighter [param ability], ready now.
func _give_knight(main: Main, ability: AbilityDef) -> void:
	var knight: Combatant = _knight(main)
	knight.abilities.append(ability)
	knight.action_ready_tick[ability.id] = main.simulation.expedition.battle.tick


## One tick of play: the tick, then the frames it lasts. Returns the events told in it.
func _tick(main: Main) -> Array[SimEvent]:
	var before: int = _heard.size()
	_frame(main, 1)
	for i: int in FRAMES_PER_TICK - 1:
		_frame(main, 0)
	return _heard.slice(before)


## Plays ticks until an event of [param kind] (from [param source], unless -2) is told, at most
## [param ticks]: that event, or null.
func _until(main: Main, kind: SimEvent.Kind, source: int = -2, ticks: int = WAIT_TICKS) -> SimEvent:
	for i: int in ticks:
		var before: int = _heard.size()
		_frame(main, 1)
		var found: SimEvent = _first(_heard.slice(before), kind, source)
		if found != null:
			return found
		for f: int in FRAMES_PER_TICK - 1:
			_frame(main, 0)
	return null


static func _first(events: Array[SimEvent], kind: SimEvent.Kind, source: int = -2) -> SimEvent:
	for event: SimEvent in events:
		if event.kind == kind and (source == -2 or event.source_id == source):
			return event
	return null


## The summons' puffs showing within a tile of [param at].
func _puffs_near(main: Main, at: Vector2) -> int:
	var count: int = 0
	for node: Node2D in main.world.fx.nodes(&"combat"):
		var particle: FxParticle = node as FxParticle
		if particle != null and particle.shape == FxParticle.Shape.PUFF:
			if particle.position.distance_to(at) <= TILE:
				count += 1
	return count


## The ids of every summon with a sprite in the world.
static func _summon_sprites(main: Main) -> Array[int]:
	var ids: Array[int] = []
	for id: int in main.world._sprites:
		if id >= Battle.FIRST_SUMMON_ID and id <= Battle.LAST_SUMMON_ID:
			ids.append(id)
	return ids


static func _facing(sprite: CharacterSprite) -> int:
	return -1 if (sprite.get_node("Mirror") as Node2D).scale.x < 0.0 else 1


# --- R1 ------------------------------------------------------------------------


func test_r1_a_summon_is_drawn() -> void:
	var main: Main = _fight()
	_give_knight(main, _summoning(&"test_call_hawk", _hawk()))
	var came: SimEvent = _until(main, SimEvent.Kind.SUMMONED)
	assert_not_null(came, "the Knight called its hawk")
	if came == null:
		return
	var battle: Battle = main.simulation.expedition.battle
	var hawk: Combatant = battle.combatant(came.target_id)
	var sprite: CharacterSprite = main.world.character(came.target_id)
	assert_not_null(sprite, "a sprite for the hawk, the frame it came")
	if sprite == null or hawk == null:
		return
	var sheet: Texture2D = SpriteBounds.sheet_of(sprite)
	assert_eq(
		sheet.resource_path if sheet != null else "",
		"%s/placeholder.png" % CharacterSprite.SUMMONS_DIR,
		"a summon with no sheet of its own is drawn with the placeholder"
	)
	assert_lte(SpriteBounds.body_rect(sprite).size.y, 12.0, "a small creature")
	assert_almost_eq(sprite.position.x, hawk.x * TILE, 0.5, "at the summon's place")
	assert_gt(_puffs_near(main, sprite.position), 0, "with a puff, for a summon just come")
	var monster: Combatant = battle.monsters[0]
	var toward: int = 1 if monster.x * TILE > sprite.position.x else -1
	assert_eq(_facing(sprite), toward, "facing the monsters")
	assert_true(sprite.visible and sprite.modulate.a > 0.99, "shown whole")
	assert_false(sprite in main.world.effects_layer.get_children(), "not a passing effect")

	# It follows the simulation's place, walking while it goes.
	var walked: bool = false
	var gap: float = INF
	for i: int in 60:
		_tick(main)
		if battle.combatant(came.target_id) != hawk:
			break
		walked = walked or sprite._walking
		gap = absf(sprite.position.x - hawk.x * TILE)
		assert_lt(gap, TILE, "never far from where the simulation has it")
	assert_true(walked, "it walked as the hawk went")

	# A summon seen only after a stall appears with no puff; one ended in it never appears.
	_give_knight(main, _summoning(&"test_build_turret", _turret()))
	var flash: SummonDef = _turret({"seconds": 0.5})
	flash.id = &"flash"
	_give_knight(main, _summoning(&"test_flash", flash))
	var before: int = _heard.size()
	_frame(main, World.STALL_TICKS + 60)
	assert_true(main.world.catching_up(), "a stall")
	var stale: Array[SimEvent] = _heard.slice(before)
	var turret_id: int = -1
	var flash_id: int = -1
	for event: SimEvent in stale:
		if event.kind == SimEvent.Kind.SUMMONED:
			if event.ability_id == &"test_build_turret":
				turret_id = event.target_id
			elif event.ability_id == &"test_flash":
				flash_id = event.target_id
	assert_true(turret_id >= 0 and flash_id >= 0, "both came in the stall")
	assert_not_null(_first(stale, SimEvent.Kind.SUMMON_ENDED, flash_id), "the flash ended in it")
	var turret: CharacterSprite = main.world.character(turret_id)
	assert_not_null(turret, "the turret still standing is shown")
	if turret != null:
		assert_eq(_puffs_near(main, turret.position), 0, "with no puff: it came a while ago")
	if flash_id != turret_id:
		assert_null(main.world.character(flash_id), "the flash, gone already, is never shown")

	# A turret that is moved is followed there.
	_frame(main, 0)
	var placed: Combatant = battle.combatant(turret_id)
	if placed != null and turret != null:
		placed.x += 2.0
		var walking: bool = false
		for i: int in 90:
			_frame(main, 0)
			walking = walking or turret._walking
		assert_almost_eq(turret.position.x, placed.x * TILE, 0.5, "it stands where it was put")
		assert_true(walking, "and walked there")


# --- R2 ------------------------------------------------------------------------


func test_r2_fights_on_screen() -> void:
	var main: Main = _fight()
	var hawk_def: SummonDef = _hawk({"seconds": 30.0})
	hawk_def.abilities = [_dive().id] as Array[StringName]
	_give_knight(main, _summoning(&"test_call_hawk", hawk_def))
	var came: SimEvent = _until(main, SimEvent.Kind.SUMMONED)
	assert_not_null(came, "the Knight called its hawk")
	if came == null:
		return
	var id: int = came.target_id
	var sprite: CharacterSprite = main.world.character(id)
	var effects: CombatEffects = main.effects
	var red: Color = Palette.color(KNIGHT_COLOUR)
	var struck: bool = false
	var moved: bool = false
	var coloured: bool = false
	var hasted: bool = false
	var white_from_knight: bool = false
	for i: int in WAIT_TICKS:
		var before: Array[FxText] = effects.texts()
		var events: Array[SimEvent] = _tick(main)
		if main.simulation.expedition.battle == null:
			break
		for event: SimEvent in events:
			if event.source_id != id:
				continue
			match event.kind:
				SimEvent.Kind.ATTACK_STARTED:
					struck = struck or sprite.is_attacking()
				SimEvent.Kind.ABILITY_STARTED:
					moved = moved or sprite.moves.names().has(&"leap")
		var from_hawk: SimEvent = _first(events, SimEvent.Kind.HIT, id)
		var from_knight: SimEvent = _first(events, SimEvent.Kind.HIT, _knight(main).id)
		for text: FxText in effects.texts():
			if text in before or text.kind != &"damage":
				continue
			var hawk_words: String = str(from_hawk.amount) if from_hawk != null else ""
			# The monsters barely hurt (1 a blow), and a hero's wounds are red too.
			if from_hawk != null and from_hawk.amount > 1 and text.text.begins_with(hawk_words):
				coloured = coloured or text.color == red
			if from_hawk == null and from_knight != null and text.color == Color.WHITE:
				white_from_knight = true
		var marks: StatusMarks = effects.ability_effects.marks
		hasted = hasted or marks.shown(id).has(AbilityEffect.Status.HASTED)
		if struck and moved and coloured and hasted and white_from_knight:
			break
	assert_true(struck, "the hawk winds up and strikes as any fighter's sprite does")
	assert_true(moved, "its own action plays its move")
	assert_true(coloured, "its damage numbers are in the Knight's colour")
	assert_true(white_from_knight, "while the Knight's own stay white")
	assert_true(hasted, "a status on it shows its mark")


# --- R3 ------------------------------------------------------------------------


func test_r3_ends_on_screen() -> void:
	var main: Main = _fight()
	_give_knight(main, _summoning(&"test_brief", _hawk({"seconds": 2.0}), 4.0))
	_give_knight(main, _summoning(&"test_frail", _hawk({"seconds": 30.0}), 4.0))
	# One ward at most: the next replaces the one standing.
	_give_knight(main, _summoning(&"test_ward", _turret(), 1.5))
	var battle: Battle = main.simulation.expedition.battle
	# Per summon ending: its sprite, and the seconds since its end was heard.
	var ending: Dictionary[int, CharacterSprite] = {}
	var since: Dictionary[int, float] = {}
	var reasons: Dictionary[int, bool] = {}
	var ending_fight: bool = false
	for i: int in WAIT_TICKS * 3:
		for event: SimEvent in _tick_watching(main, ending, since):
			if event.kind == SimEvent.Kind.SUMMONED:
				var made: Combatant = battle.combatant(event.target_id)
				if made != null and event.ability_id == &"test_frail":
					made.health = 1
					for monster: Combatant in battle.monsters:
						monster.damage = 5
				elif made != null and event.ability_id in [&"test_brief", &"test_ward"]:
					made.max_health = 1_000_000
					made.health = made.max_health
			elif event.kind == SimEvent.Kind.SUMMON_ENDED:
				reasons[event.amount] = true
		var known: bool = reasons.has(BattleSummons.Ended.TIME_UP)
		known = known and reasons.has(BattleSummons.Ended.FELL)
		known = known and reasons.has(BattleSummons.Ended.REPLACED)
		if known and not ending_fight:
			ending_fight = true
			for monster: Combatant in battle.monsters:
				monster.health = 1
				monster.damage = 1
		if main.simulation.expedition.battle == null:
			break
	assert_true(reasons.has(BattleSummons.Ended.TIME_UP), "one's time ran out")
	assert_true(reasons.has(BattleSummons.Ended.FELL), "one fell")
	assert_true(reasons.has(BattleSummons.Ended.REPLACED), "one was replaced")
	assert_true(reasons.has(BattleSummons.Ended.FIGHT_ENDED), "the rest ended with the fight")
	for i: int in 30:
		_tick_watching(main, ending, since)
	assert_eq(_summon_sprites(main), [] as Array[int], "no summon's sprite is left after the fight")
	for i: int in 60 * 4:
		_frame(main, 0)
	assert_eq(main.world.effects_layer.get_child_count(), 0, "nothing on the effects layer")


## A tick of play that checks, frame by frame, each summon seen ending: [param ending] holds its
## sprite and [param since] the seconds since its end. Returns the events told.
func _tick_watching(
	main: Main, ending: Dictionary[int, CharacterSprite], since: Dictionary[int, float]
) -> Array[SimEvent]:
	var told: Array[SimEvent] = []
	for f: int in FRAMES_PER_TICK:
		var before: int = _heard.size()
		_frame(main, 1 if f == 0 else 0)
		for id: int in since.keys():
			since[id] += STEP
			var sprite: CharacterSprite = ending[id]
			if is_instance_valid(sprite) and main.world.character(id) == sprite:
				assert_false(sprite.is_dead(), "an ending summon has no death pose")
				assert_lt(sprite.modulate.a, 1.0, "it fades")
				assert_lt(since[id], SummonSprites.FADE_SECONDS + STEP * 2, "within its fade")
			else:
				since.erase(id)
				ending.erase(id)
		for event: SimEvent in _heard.slice(before):
			told.append(event)
			if event.kind == SimEvent.Kind.DIED:
				assert_false(SummonSprites.is_summon_id(event.source_id), "no summon dies")
			if event.kind != SimEvent.Kind.SUMMON_ENDED:
				continue
			var sprite: CharacterSprite = main.world.character(event.source_id)
			assert_not_null(sprite, "a summon ending is still shown as it fades")
			if sprite == null:
				continue
			assert_gt(_puffs_near(main, sprite.position), 0, "with a puff")
			assert_false(main.world.fallen_party.is_lying(event.source_id), "and no fall")
			ending[event.source_id] = sprite
			since[event.source_id] = 0.0
	return told


# --- R4 ------------------------------------------------------------------------


func test_r4_the_tally_credits_the_summoner() -> void:
	var main: Main = _fight(false)
	var totem: SummonDef = _turret({"seconds": 30.0, "heal_share": 0.6, "attack_range": 20.0})
	totem.id = &"totem"
	totem.display_name = "Totem"
	_give_knight(main, _summoning(&"test_call_hawk", _hawk({"seconds": 30.0})))
	_give_knight(main, _summoning(&"test_raise_totem", totem))
	var tally: TallyWindow = main.hud.tally
	var knight: int = _knight(main).id
	var dealt: Dictionary[int, int] = {}
	var healed: Dictionary[int, int] = {}
	var taken: int = 0
	var hawk_dealt: int = 0
	var totem_healed: int = 0
	var summoned_by: Dictionary[int, StringName] = {}
	var summon_killed: bool = false
	var last_hit: Dictionary[int, int] = {}
	for i: int in WAIT_TICKS:
		for event: SimEvent in _tick(main):
			var by: int = knight if summoned_by.has(event.source_id) else event.source_id
			var what: StringName = summoned_by.get(event.source_id, &"")
			match event.kind:
				SimEvent.Kind.SUMMONED:
					summoned_by[event.target_id] = event.ability_id
				SimEvent.Kind.HIT:
					if event.target_id >= Expedition.FIRST_MONSTER_ID:
						dealt[by] = dealt.get(by, 0) + event.amount
						last_hit[event.target_id] = event.source_id
						hawk_dealt += event.amount if what == &"test_call_hawk" else 0
					elif event.target_id < Battle.FIRST_SUMMON_ID:
						taken += event.amount
				SimEvent.Kind.HEALED:
					if event.target_id < Battle.FIRST_SUMMON_ID and event.source_id >= 0:
						healed[by] = healed.get(by, 0) + event.amount
						totem_healed += event.amount if what == &"test_raise_totem" else 0
				SimEvent.Kind.ATTACK_STARTED:
					# A blow of the hawk's is to kill.
					var aimed: Combatant = main.simulation.expedition.battle.combatant(
						event.target_id
					)
					if what == &"test_call_hawk" and aimed != null and not summon_killed:
						aimed.health = 1
				SimEvent.Kind.DIED:
					var killer: int = last_hit.get(event.source_id, -1)
					summon_killed = summon_killed or summoned_by.has(killer)
		var battle: Battle = main.simulation.expedition.battle
		if battle == null or (hawk_dealt > 0 and totem_healed > 0 and summon_killed):
			break
		# The Knight is hurt now and then, so the totem has someone to heal, and nobody falls.
		for hero: Combatant in battle.heroes:
			hero.health = maxi(hero.health, hero.max_health / 4)
		var hurt: Combatant = _knight(main)
		if i % 10 == 0:
			hurt.health = mini(hurt.health, roundi(hurt.max_health * 0.4))
	assert_gt(hawk_dealt, 0, "the hawk dealt damage")
	assert_gt(totem_healed, 0, "the totem healed")
	assert_true(summon_killed, "a summon dealt a killing blow")
	var counted: Tally = tally.tally
	for span: Tally.Span in [Tally.Span.LAST_FIGHT, Tally.Span.SESSION]:
		var damage: int = counted.value(knight, Tally.Measure.DAMAGE, span)
		var knight_dealt: int = dealt.get(knight, 0)
		assert_eq(damage, knight_dealt, "the Knight's damage holds its summons' (%d)" % span)
		var by_ability: Dictionary[String, int] = counted.by_ability(
			knight, Tally.Measure.DAMAGE, span
		)
		var hawk_line: int = by_ability.get("Hawk", 0)
		assert_eq(hawk_line, hawk_dealt, "the hawk's line by ability")
		var healing: int = counted.value(knight, Tally.Measure.HEALING, span)
		var knight_healed: int = healed.get(knight, 0)
		assert_eq(healing, knight_healed, "the Knight's healing holds the totem's")
		var heals: Dictionary[String, int] = counted.by_ability(knight, Tally.Measure.HEALING, span)
		var totem_line: int = heals.get("Totem", 0)
		assert_eq(totem_line, totem_healed, "the totem's line by ability")
		var all_taken: int = 0
		for hero: Hero in main.simulation.party.heroes:
			all_taken += counted.value(hero.id, Tally.Measure.TAKEN, span)
		assert_eq(all_taken, taken, "what the summons took is not on Taken")
	for id: int in summoned_by:
		for measure: int in Tally.Measure.size():
			var own: int = counted.value(id, measure as Tally.Measure, Tally.Span.SESSION)
			assert_eq(own, 0, "a summon has no line of its own")
	# The window: the Knight's line opened by ability shows the hawk's share under its name.
	tally.open()
	tally.set_span(Tally.Span.LAST_FIGHT)
	tally.set_measure(Tally.Measure.DAMAGE)
	tally.open_hero(knight)
	tally.advance(STEP)
	var shown: Array[String] = tally.breakdown()
	var line: String = "Hawk %s" % UiFormat.group_thousands(hawk_dealt)
	assert_has(shown, line, "the hawk's line under the Knight's: %s" % [shown])
	assert_eq(tally.hero_lines.size(), main.simulation.party.heroes.size(), "heroes' lines only")


# --- R5 ------------------------------------------------------------------------


func test_r5_no_view_mistakes_it() -> void:
	_frame_parts = [&"effects", &"sound", &"hud", &"milestones", &"moment"]
	var main: Main = _fight(false)
	var hawk_def: SummonDef = _hawk({"seconds": 30.0})
	hawk_def.abilities = [_dive().id] as Array[StringName]
	_give_knight(main, _summoning(&"test_call_hawk", hawk_def))
	_give_knight(main, _summoning(&"test_build_turret", _turret({"seconds": 4.0}), 3.0, 1, 2))
	var knight: int = _knight(main).id
	var red: Color = Palette.color(KNIGHT_COLOUR)
	var effects: AbilityEffects = main.effects.ability_effects
	var names_seen: int = 0
	var summons: Dictionary[int, bool] = {}
	var ended: int = 0
	for i: int in WAIT_TICKS:
		for event: SimEvent in _tick(main):
			match event.kind:
				SimEvent.Kind.SUMMONED:
					summons[event.target_id] = true
				SimEvent.Kind.SUMMON_ENDED:
					ended += 1
		var battle: Battle = main.simulation.expedition.battle
		if battle == null:
			break
		for hero: Combatant in battle.heroes:
			hero.health = maxi(hero.health, hero.max_health / 3)
		for id: int in summons:
			if main.world.summons.has(id):
				assert_eq(main.world.summons.owner_of(id), knight, "a summon's summoner")
				assert_eq(effects._fighter_color(id), red, "a summon is coloured as its summoner")
				var named: String = main.world.summons.name_of(id)
				assert_true(named in ["Hawk", "Turret"], "named by its summon's name: %s" % named)
			for text: FxText in effects._names():
				if text.follow_id == id:
					names_seen += 1
					assert_eq(text.text, "Dive", "a name over the hawk is its ability's")
					assert_eq(text.color, red, "in its summoner's colour")
		if names_seen > 0 and ended > 0:
			break
	assert_gt(summons.size(), 1, "summons came")
	assert_gt(names_seen, 0, "a name rose over the hawk")
	assert_gt(ended, 0, "and one ended")
	# What a hero window says of a fighter aimed at a summon.
	var window: HeroWindow = main.ui.hero_windows.window_of(knight)
	var probe := Combatant.new()
	for id: int in summons:
		if main.simulation.expedition.battle.combatant(id) != null:
			probe.target_id = id
			break
	if probe.target_id >= 0:
		var line: String = window._fighting(probe)
		assert_true(line.contains("Hawk") or line.contains("Turret"), "named: %s" % line)
	# Heroes only on the frames, the hero windows and the goals.
	var heroes: int = main.simulation.party.heroes.size()
	assert_eq(main.hud.frames.size(), heroes, "a frame per hero, none for a summon")
	for frame: HeroFrameView in main.hud.frames:
		assert_lt(frame.hero_id, Battle.FIRST_SUMMON_ID, "a hero's frame")
	for id: int in summons:
		assert_null(main.ui.hero_windows.window_of(id), "no hero window for a summon")
	for row: String in main.hud.goals.lines():
		assert_false(row.contains("Hawk") or row.contains("Turret"), "no goal names a summon")


# --- R6 ------------------------------------------------------------------------


func test_r6_light_enough() -> void:
	var main: Main = _fight()
	var swarm: SummonDef = _hawk({"seconds": 6.0})
	_give_knight(main, _summoning(&"test_swarm", swarm, 4.0, 2, 4))
	var summons: SummonSprites = main.world.summons
	var made_before: int = summons.made
	var summoned: int = 0
	var sprites: Dictionary[int, CharacterSprite] = {}
	var distinct: Dictionary[int, bool] = {}
	for i: int in 300:
		for event: SimEvent in _tick(main):
			if event.kind == SimEvent.Kind.SUMMONED:
				summoned += 1
				var sprite: CharacterSprite = main.world.character(event.target_id)
				assert_not_null(sprite, "a sprite as it comes")
				if sprite != null:
					sprites[event.target_id] = sprite
					distinct[sprite.get_instance_id()] = true
			elif event.kind == SimEvent.Kind.SUMMON_ENDED:
				sprites.erase(event.source_id)
		for id: int in sprites:
			assert_eq(main.world.character(id), sprites[id], "one sprite for a summon's life")
		var battle: Battle = main.simulation.expedition.battle
		if battle == null:
			break
	assert_gte(summoned, 12, "twelve summons came and went")
	assert_eq(summons.made - made_before, summoned, "a sprite made for each summon, no more")
	assert_eq(distinct.size(), summoned, "each its own")
	assert_eq(summons.refused, 0, "no puff refused by the pool")

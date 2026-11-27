extends "res://tests/unit/abilities_on_screen_test_base.gd"
## Acceptance tests for specs/056-abilities-on-screen/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects that listen to it (and,
## where a requirement is about the HUD, the Hud over them), every _process turned off. Some tests
## make a Battle of the party's own fighters and a monster the world shows, and let the battle's own
## rules (BattleStatuses, Battle.deal, Battle.revive) record the events; [method _deliver] hands
## them to the simulation's event list, stamped from the tick the battle began on, and syncs a
## frame, so the world, the effects and the HUD hear them as they would in play. The others run
## real fights of a party with full talent trees.

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
	assert_true(shown[0].outline, "outlined in ink, so it reads against the wall")
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
	for particle: FxParticle in _abilities().all_particles():
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

	# Meteor's every blow lands heavy, though Ignite fires between two of them.
	var first_blow: Array[SimEvent] = [_event(SimEvent.Kind.HIT, MAGE, monster, 40)]
	_tell(first_blow)
	var one: int = _abilities().particles(&"heavy")
	assert_gt(one, 0, "the first receiver's blow is heavy")
	var ignite := _event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"ignite")
	var burning := _event(SimEvent.Kind.STATUS_BEGAN, MAGE, monster, 30, &"ignite")
	burning.status = AbilityEffect.Status.BURNING
	_tell([ignite, burning, _event(SimEvent.Kind.HIT, MAGE, monster, 40)])
	assert_gt(_abilities().particles(&"heavy"), one, "and so is the next, after Ignite")
	var ended := _event(SimEvent.Kind.STATUS_ENDED, MAGE, monster, 0, &"ignite")
	ended.status = AbilityEffect.Status.BURNING
	_tell([ended])
	_at += 10

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

	# A push: those pushed kick dust, as the events tell it (Frost Nova slows, then pushes, those
	# round its target), before the fight is even looked at.
	_wait(1.0)
	_at += 10
	var nova := _event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"frost_nova")
	var slowed := _event(SimEvent.Kind.STATUS_BEGAN, MAGE, monster, 30, &"frost_nova")
	slowed.status = AbilityEffect.Status.SLOWED
	_tell([nova, slowed])
	assert_gt(_abilities().particles(&"dust"), 0, "dust kicks at the pushed one's feet")
	var unslowed := _event(SimEvent.Kind.STATUS_ENDED, MAGE, monster, 0, &"frost_nova")
	unslowed.status = AbilityEffect.Status.SLOWED
	_tell([unslowed])
	# And the pushed slide to their new place.
	_wait(1.0)
	var battle: Battle = _battle(monster)
	_sim.expedition.battle = battle
	var mage: Combatant = battle.combatant(MAGE)
	var pushed: Combatant = battle.combatant(monster)
	mage.x = pushed.x - 1.0
	var before: float = target.position.x
	battle.push(mage, pushed, 1.5)
	_frame()
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
	_assert_up(KNIGHT, "revived")

	# Fallen and revived in one frame, as Guardian Angel does: it still stands up, and stays up.
	battle.deal(pushed, fallen, fallen.max_health * 10, false, Battle.Via.STRIKE)
	battle.revive(cleric, fallen, 0.5)
	_deliver(battle)
	_wait(FallenParty.STAND_SECONDS + 0.5)
	_assert_up(KNIGHT, "revived in the frame it fell")

	# Fallen again while it rises: it lies down again and stays down.
	battle.deal(pushed, fallen, fallen.max_health * 10, false, Battle.Via.STRIKE)
	_deliver(battle)
	_wait(1.0)
	battle.revive(cleric, fallen, 0.5)
	_deliver(battle)
	_wait(FallenParty.STAND_SECONDS / 3.0)
	battle.deal(pushed, fallen, fallen.max_health * 10, false, Battle.Via.STRIKE)
	_deliver(battle)
	var stood: int = 0
	for i: int in roundi((FallenParty.STAND_SECONDS + 0.5) / FRAME):
		_frame()
		if not knight.is_dead() or _world.fallen_party.is_standing(KNIGHT):
			stood += 1
	assert_eq(stood, 0, "fallen again while rising: it never finishes standing")
	assert_true(_world.fallen_party.is_lying(KNIGHT), "it lies")
	assert_true(knight.is_dead(), "and stays down")


## R2 in a real fight: a cleric with Guardian Angel stands a fallen hero up, and it is seen up.
func test_r2_a_revive_in_a_real_fight() -> void:
	var paths: Dictionary[StringName, int] = PATHS.duplicate()
	paths[&"cleric"] = 0  # Renewal, Sanctuary, Guardian Angel, Miracle
	_full_trees(paths)
	assert_true(_find_fight(2), "a fight")
	# Monsters that fell a hero in a few blows, so one falls and Guardian Angel answers.
	var hardiest: int = 0
	for hero: Hero in _sim.party.heroes:
		hardiest = maxi(hardiest, hero.max_health())
	for monster: Combatant in _sim.expedition.battle.monsters:
		monster.damage = hardiest / 3
	var revived: int = -1
	var since: float = 0.0
	var seen: bool = false
	var frames: int = 0
	while _fighting() and frames < 60 * 300 and not seen:
		var start: int = _heard.size()
		_play_at_speed()
		frames += 1
		for event: SimEvent in _heard.slice(start):
			if event.kind == SimEvent.Kind.REVIVED:
				revived = event.target_id
				since = 0.0
				for monster: Combatant in _sim.expedition.battle.monsters:
					monster.damage = 1  # so the revived one lives to be seen
		if revived < 0:
			continue
		since += FRAME
		if since >= FallenParty.STAND_SECONDS + 0.3:
			_assert_up(revived, "the hero Guardian Angel revived")
			seen = true
	assert_true(seen, "Guardian Angel revived a hero in a real fight, and it was seen up")


# --- R3 ------------------------------------------------------------------------


func test_r3_statuses_can_be_seen() -> void:
	var monster: int = _monster()
	var battle: Battle = _battle(monster)
	# The fight is not looked at: what shows is what the events tell.
	_sim.expedition.battle = null
	var knight: Combatant = battle.combatant(KNIGHT)
	var foe: Combatant = battle.combatant(monster)
	foe.max_health = 100000
	foe.health = 100000
	var colours: Dictionary[int, StringName] = {
		AbilityEffect.Status.BURNING: &"orange",
		AbilityEffect.Status.BLEEDING: &"red",
		AbilityEffect.Status.CHILLED: &"cyan",
	}
	var drawn_as: Dictionary[int, String] = {
		AbilityEffect.Status.STUNNED: "star",
		AbilityEffect.Status.TAUNTING: "mark:taunting",
		AbilityEffect.Status.SHIELDED: "outline:cyan",
		AbilityEffect.Status.BURNING: "mote:burning",
		AbilityEffect.Status.BLEEDING: "mote:bleeding",
		AbilityEffect.Status.MENDING: "mote:mending",
		AbilityEffect.Status.HASTED: "mark:hasted",
		AbilityEffect.Status.SLOWED: "mark:slowed",
		AbilityEffect.Status.MIGHTY: "mark:mighty",
		AbilityEffect.Status.WEAKENED: "mark:weakened",
		AbilityEffect.Status.MARKED: "mark:marked",
		AbilityEffect.Status.CHILLED: "mote:chilled",
	}
	for kind: int in AbilityEffect.Status.size():
		var label: String = ShownStatus.status_name(kind)
		var effect: AbilityEffect = _status(kind)
		var from: StringName = &"shield_bash"
		if kind == AbilityEffect.Status.SHIELDED:
			effect = _bulwark_shield()
			from = &"bulwark"
		var bearer: Combatant = knight if effect.is_helpful() else foe
		var sprite: CharacterSprite = _world.character(bearer.id)
		BattleStatuses.apply(battle, knight, bearer, effect, from)
		var began: Array[SimEvent] = _deliver(battle)
		await get_tree().process_frame
		assert_eq(began.size(), 1, "%s began with its event" % label)
		assert_has(_marks().shown(bearer.id), kind, "%s is shown on its bearer" % label)
		var drawn: Array[String] = _marks().drawn(bearer.id)
		if drawn_as.has(kind):
			assert_has(drawn, drawn_as[kind], "%s: drawn" % label)
		match kind:
			AbilityEffect.Status.STUNNED:
				assert_eq(drawn.count("star"), StatusMarks.STARS, "stunned: stars round the head")
				var pose: Array = _pose_of(sprite)
				_wait(0.4)
				assert_eq(_pose_of(sprite), pose, "stunned: the sprite holds still")
			AbilityEffect.Status.NIMBLE, AbilityEffect.Status.UNTOUCHABLE:
				assert_eq(_opacity_of(sprite), StatusMarks.FADE, "%s: half faded" % label)
				assert_eq(drawn, [] as Array[String], "%s: nothing drawn over it" % label)
			AbilityEffect.Status.SHIELDED:
				var shield: CombatStatus = knight.status(AbilityEffect.Status.SHIELDED)
				battle.deal(foe, knight, roundi(shield.amount * 0.8), false, Battle.Via.STRIKE)
				_deliver(battle)
				await get_tree().process_frame
				assert_has(_marks().drawn(KNIGHT), "outline:navy", "fading as it is used")
		if colours.has(kind):
			assert_eq(_tint_of(sprite), StatusMarks.TINT_SHARE, "%s: tinted" % label)
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
		_wait(0.1)
		assert_has(_marks().shown(bearer.id), kind, "%s lasts" % label)
		BattleStatuses.end(battle, bearer, kind)
		var ended: Array[SimEvent] = _deliver(battle)
		await get_tree().process_frame
		assert_eq(ended[0].kind, SimEvent.Kind.STATUS_ENDED, "%s ended with its event" % label)
		assert_does_not_have(_marks().shown(bearer.id), kind, "%s is gone that frame" % label)
		assert_eq(_marks().drawn(bearer.id), [] as Array[String], "%s: nothing drawn" % label)
		assert_eq(_tint_of(sprite), 0.0, "%s: no tint left" % label)
		assert_eq(_opacity_of(sprite), 1.0, "%s: whole again" % label)
		if kind == AbilityEffect.Status.STUNNED:
			var still: Array = _pose_of(sprite)
			_wait(0.4)
			assert_ne(_pose_of(sprite), still, "unstunned, the sprite moves again")


## R3: a fighter stunned in its wind-up loses the swing; it does not finish it when the stun ends.
func test_r3_a_stun_takes_the_swing() -> void:
	var monster: int = _monster()
	var foe: CharacterSprite = _world.character(monster)
	_tell([_event(SimEvent.Kind.ATTACK_STARTED, monster, KNIGHT, 8)])
	_wait(0.1)
	assert_true(foe.is_attacking(), "winding up")
	var stunned := _event(SimEvent.Kind.STATUS_BEGAN, KNIGHT, monster, 10, &"shield_bash")
	stunned.status = AbilityEffect.Status.STUNNED
	_tell([stunned])
	assert_false(foe.is_attacking(), "the stun took its wind-up")
	var ended := _event(SimEvent.Kind.STATUS_ENDED, KNIGHT, monster, 0, &"shield_bash")
	ended.status = AbilityEffect.Status.STUNNED
	_tell([ended])
	_wait(1.0)
	assert_false(foe.is_attacking(), "and it does not swing at nothing after")


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
	for i: int in 4:
		battle.deal(foe, knight, 1, false, Battle.Via.STRIKE)
	_deliver(battle)
	assert_eq(_blocked(), 1, "one Blocked for the shield, not one a blow")
	battle.tick += TPS
	battle.deal(foe, knight, 1, false, Battle.Via.STRIKE)
	_deliver(battle)
	assert_eq(_blocked(), 2, "and another a second later")
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


## How many Blocked words show.
func _blocked() -> int:
	var count: int = 0
	for text: FxText in _abilities().texts():
		if text.text == "Blocked":
			count += 1
	return count


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
	var frame: HeroFrameView = null
	for each: HeroFrameView in _hud.frames:
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
	mouse_move(UiFormat.on_screen(frame).get_center())
	_hud.frame_tip.point_at(frame.get_global_rect().get_center())
	_hud.frame_tip.advance(UiTip.DELAY + 0.1)
	assert_eq(_hud.frame_tip.shown_text(), line, "as the HUD's tooltip")
	# With a path chosen (spec 055), the class and its path come first, then the statuses.
	var hero: Hero = _sim.party.hero(KNIGHT)
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var taken: Array[StringName] = [tree.path(0).nodes[0]]
	hero.gain_xp(Hero.xp_for_level(TREE_LEVEL) - hero.xp)
	hero.set_talents(taken)
	var titled: String = HeroTalentsTab.title(hero)
	assert_true(titled.begins_with("Knight, "), "the knight has a path")
	var both: String = "%s: Shielded 6 s, Mending 8 s, Hasted 12 s, Mighty 5 s. Click for details"
	mouse_move(Vector2(-1000, -1000))
	_hud.frame_tip.point_at(UiTip.NOWHERE)
	_hud.frame_tip.point_at(frame.get_global_rect().get_center())
	_hud.frame_tip.advance(UiTip.DELAY + 0.1)
	assert_eq(_hud.frame_tip.shown_text(), both % titled, "path and statuses, in one tooltip")
	hero.set_talents([])
	var other: HeroFrameView = _hud.frames[1] if _hud.frames[0] == frame else _hud.frames[0]
	assert_eq(other.status_icons.kinds, [] as Array[int], "a hero with none shows none")
	for kind: int in lasting:
		BattleStatuses.end(battle, knight, kind)
	_deliver(battle)
	assert_eq(frame.status_icons.kinds, [] as Array[int], "gone when they end")
	assert_eq(frame.tip(), HeroFrameView.CLICK_TIP, "and from the tooltip")


# --- R6 ------------------------------------------------------------------------


func test_r6_the_tally_knows_abilities() -> void:
	_build(Simulation.new(SEED), true)
	var by_name: Dictionary[String, AbilityDef] = {}
	for file: String in DirAccess.get_files_at("res://data/abilities"):
		if file.ends_with(".tres"):
			var ability: AbilityDef = Content.ability(StringName(file.get_basename()))
			by_name[ability.display_name] = ability
	var named: Dictionary[String, bool] = {}
	var problems: Array[String] = []
	var tally: Tally = _hud.tally.tally
	# Every path of every tree, in turn, over a long run of real fights.
	for path: int in 2:
		var paths: Dictionary[StringName, int] = {}
		for class_id: StringName in PATHS:
			paths[class_id] = path
		_full_trees(paths)
		var fights: int = 0
		for i: int in 6:
			if not _find_fight(2):
				break
			fights += 1
			for tick: int in FIGHT_LIMIT_TICKS:
				_sim.step()
				if tick % 3 == 0:
					_frame()
				if not _fighting():
					break
			_frame()
		assert_gt(fights, 3, "path %d: fights were fought" % path)
	for id: int in HERO_IDS:
		for measure: Tally.Measure in [Tally.Measure.DAMAGE, Tally.Measure.HEALING]:
			var lines: Dictionary[String, int] = tally.by_ability(id, measure, Tally.Span.SESSION)
			for each: String in lines:
				named[each] = true
				var ability: AbilityDef = by_name.get(each, null)
				if ability == null:
					continue
				var healing: bool = measure == Tally.Measure.HEALING
				var fits: bool = (
					AbilityCredit.heals(ability) if healing else AbilityCredit.damages(ability)
				)
				if not fits:
					problems.append("%s on hero %d's %s" % [each, id, BY[measure]])
	assert_eq(problems, [] as Array[String], "no line names an ability that does not do it")
	assert_has(named, AbilityCredit.STRIKES, "ordinary strikes have their line")
	assert_true(named.has("Bleeding") or named.has("Burning"), "a status's damage has its line")
	var actions: int = 0
	for each: String in named:
		if by_name.has(each) and by_name[each].is_action():
			actions += 1
	assert_gt(actions, 3, "actions have lines of their own")

	# The tally's line for a hero opens to show it.
	# Spec 059 R4: a window on the UI layer; the open tab's measure opens under the hero's line,
	# and the other heroes' lines stay.
	var panel: TallyWindow = _hud.tally
	panel.open()
	_hud.advance(FRAME)
	await get_tree().process_frame  # the window lays out
	await get_tree().process_frame
	var row: Vector2 = _ui.ui_to_world(panel.hero_lines[0].get_global_rect().get_center())
	_click_at(row)
	_hud.advance(FRAME)
	assert_eq(panel.opened_hero(), _sim.party.heroes[0].id, "a click opens the hero's line")
	var shown: Array[String] = panel.breakdown()
	assert_eq(shown[0], "Damage by ability", "its damage")
	var first: Hero = _sim.party.heroes[0]
	var dealt: Dictionary[String, int] = tally.by_ability(
		first.id, Tally.Measure.DAMAGE, panel.span()
	)
	var top: String = dealt.keys()[0]
	assert_eq(shown[1], "%s %s" % [top, UiFormat.group_thousands(dealt[top])], "largest first")
	panel.set_measure(Tally.Measure.HEALING)
	assert_eq(panel.breakdown()[0], "Healing by ability", "and its healing, on that tab")
	panel.set_measure(Tally.Measure.DAMAGE)
	var heroes_shown: int = 0
	for line: String in panel.rows():
		for hero: Hero in _sim.party.heroes:
			if line.begins_with(hero.def().display_name + " "):
				heroes_shown += 1
	assert_eq(heroes_shown, _sim.party.heroes.size(), "the other lines stay")
	await get_tree().process_frame
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
	for i: int in FIGHT_LIMIT_TICKS:
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


## R7: what the view does for itself, with no STATUS_ENDED to tell it: a fight's end, a wipe, a
## change of area or of stage takes every mark with it.
func test_r7_nothing_outlives_its_fight() -> void:
	var enders: Array[SimEvent.Kind] = [
		SimEvent.Kind.ENCOUNTER_ENDED,
		SimEvent.Kind.PARTY_WIPED,
		SimEvent.Kind.AREA_CHANGED,
		SimEvent.Kind.DEPTH_CHANGED,
	]
	for ender: SimEvent.Kind in enders:
		_build(Simulation.new(SEED))
		var label: String = str(SimEvent.Kind.keys()[ender])
		var monster: int = _monster()
		var put: Array[SimEvent] = []
		for id: int in [KNIGHT, monster]:
			var began := _event(SimEvent.Kind.STATUS_BEGAN, KNIGHT, id, 300, &"shield_bash")
			began.status = AbilityEffect.Status.STUNNED
			put.append(began)
		_tell(put)
		assert_eq(
			_marks().shown(KNIGHT), [AbilityEffect.Status.STUNNED] as Array[int], "%s: on" % label
		)
		var depth: int = _sim.expedition.depth
		_tell([_event(ender, -1, -1, depth)])
		await get_tree().process_frame
		assert_true(_marks().book.is_empty(), "%s: no status left" % label)
		for id: int in [KNIGHT, monster]:
			assert_eq(_marks().shown(id), [] as Array[int], "%s: nothing on %d" % [label, id])
			assert_eq(_marks().drawn(id), [] as Array[String], "%s: nothing drawn" % label)
			var sprite: CharacterSprite = _world.character(id)
			if sprite != null:
				assert_false(sprite.held, "%s: %d moves" % [label, id])


## R7: nothing is drawn on a fighter that has fallen or gone, though no event ended its statuses.
func test_r7_nothing_on_the_fallen_or_gone() -> void:
	var monster: int = _monster()
	var put: Array[SimEvent] = []
	for id: int in [KNIGHT, monster]:
		var began := _event(SimEvent.Kind.STATUS_BEGAN, KNIGHT, id, 300, &"mark_for_death")
		began.status = AbilityEffect.Status.MARKED
		put.append(began)
	_tell(put)
	await get_tree().process_frame
	assert_has(_marks().drawn(monster), "mark:marked", "marked")
	_tell([_event(SimEvent.Kind.DIED, monster, -1), _event(SimEvent.Kind.DIED, KNIGHT, -1)])
	await get_tree().process_frame
	for id: int in [KNIGHT, monster]:
		assert_eq(_marks().shown(id), [] as Array[int], "%d fell: nothing shown" % id)
		assert_eq(_marks().drawn(id), [] as Array[String], "%d fell: nothing drawn" % id)
	_wait(3.0)
	await get_tree().process_frame
	assert_eq(_marks().drawn(monster), [] as Array[String], "nor once it has gone")


## R7: the marks are the events', never the fight's own state, which runs ahead of what is shown.
func test_r7_marks_follow_the_events_not_the_fight() -> void:
	var monster: int = _monster()
	var battle: Battle = _battle(monster)
	_sim.expedition.battle = battle
	var knight: Combatant = battle.combatant(KNIGHT)
	var foe: Combatant = battle.combatant(monster)
	BattleStatuses.apply(battle, knight, knight, _status(AbilityEffect.Status.TAUNTING), &"taunt")
	var held_back: Array[SimEvent] = battle.drain_events()
	_frame()
	assert_eq(_marks().shown(KNIGHT), [] as Array[int], "not shown before its event is heard")
	for event: SimEvent in held_back:
		event.tick += _base
	_tell(held_back)
	assert_eq(_marks().shown(KNIGHT), [AbilityEffect.Status.TAUNTING] as Array[int], "then shown")
	BattleStatuses.end(battle, knight, AbilityEffect.Status.TAUNTING)
	held_back = battle.drain_events()
	_frame()
	assert_eq(
		_marks().shown(KNIGHT),
		[AbilityEffect.Status.TAUNTING] as Array[int],
		"shown until its end is heard"
	)
	for event: SimEvent in held_back:
		event.tick += _base
	_tell(held_back)
	assert_eq(_marks().shown(KNIGHT), [] as Array[int], "gone once it is")

	# The shield's outline dims by what the events say it absorbed, not by what is left now.
	BattleStatuses.apply(battle, knight, knight, _bulwark_shield(), &"bulwark")
	_deliver(battle)
	var shield: CombatStatus = knight.status(AbilityEffect.Status.SHIELDED)
	battle.deal(foe, knight, roundi(shield.amount * 0.8), false, Battle.Via.STRIKE)
	held_back = battle.drain_events()
	_frame()
	await get_tree().process_frame
	assert_has(_marks().drawn(KNIGHT), "outline:cyan", "whole, until the blow is heard")
	for event: SimEvent in held_back:
		event.tick += _base
	_tell(held_back)
	await get_tree().process_frame
	assert_has(_marks().drawn(KNIGHT), "outline:navy", "worn down once it is")


# --- R8 ------------------------------------------------------------------------


func test_r8_still_readable() -> void:
	_build(Simulation.new(SEED), true)
	_full_trees()
	_world.speed = 4
	assert_true(_find_fight(5, 4, false, TOUGHER * 4), "a fight of four heroes and five monsters")
	assert_eq(_sim.expedition.battle.monsters.size(), 5, "five monsters")
	_frame()  # the world catches up on the hunt, which starts nothing (spec 076 R3)
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
		for frame: HeroFrameView in _hud.frames:
			bars.append(frame.get_global_transform() * HeroFrameView.HEALTH_BAR)
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


## R8: names, numbers and resource drops (spec 052) that would start on a hero frame's health bar
## or the boss bar are kept off it: fighters are put right under the bars, and every text and
## every rising icon is measured, frame by frame. (An icon flying to the purse beside the gold
## crosses the screen to get there, as a coin does; only its rise and hang are measured.)
func test_r8_kept_off_the_bars() -> void:
	_build(Simulation.new(SEED), true)
	_world.speed = 4
	var monster: int = _monster()
	var frame: HeroFrameView = _hud.frames[0]
	var health := frame.get_global_transform() * HeroFrameView.HEALTH_BAR
	var boss := UiFormat.on_screen(_hud.boss_bar)
	var places: Array[Array] = []
	for dy: int in range(-8, 40, 6):
		places.append([KNIGHT, health.get_center() + Vector2(0, dy), health])
		places.append([monster, boss.get_center() + Vector2(0, dy + 16), boss])
	var longest: int = 0
	var started_on: int = 0
	var drops: int = 0
	for place: Array in places:
		var id: int = place[0]
		var bar: Rect2 = place[2]
		var sprite: CharacterSprite = _world.character(id)
		var at: Vector2 = place[1]
		sprite.position = _to_world(at).round()
		var target: int = monster if id == KNIGHT else KNIGHT
		var ability: StringName = &"whirlwind" if id == KNIGHT else &"meteor"
		var told: Array[SimEvent] = [
			_event(SimEvent.Kind.ABILITY_USED, id, target, 0, ability),
			_event(SimEvent.Kind.HIT, target, id, 123),
			_event(SimEvent.Kind.RESOURCE_GAINED, id, 0, 3),
		]
		for event: SimEvent in told:
			_world.sim_event.emit(event)
		var covering: Dictionary[Node2D, int] = {}
		for i: int in 60:
			if i == 0:
				# Where the number starts: on the bar, unless it is kept off.
				var feet: Rect2 = _on_screen(Rect2(sprite.position, Vector2.ONE))
				if bar.grow(12.0).has_point(feet.position):
					started_on += 1
			_fx.advance(FRAME)
			var texts: Array[FxText] = _abilities().texts()
			texts.append_array(_numbers())
			var boxes: Dictionary[Node2D, Rect2] = {}
			for text: FxText in texts:
				boxes[text] = text.rect()
			for icon: FxResource in _fx.resource_effects.live_icons():
				if icon.phase == FxResource.Phase.RISE:
					boxes[icon] = Rect2(icon.position - ResourceIcon.SIZE / 2.0, ResourceIcon.SIZE)
					drops += 1
			for shown: Node2D in boxes:
				var over: bool = _on_screen(boxes[shown]).intersects(bar)
				covering[shown] = covering.get(shown, 0) + 1 if over else 0
				longest = maxi(longest, covering[shown])
		_at += 20
	assert_gt(started_on, 4, "names and numbers began on the bars")
	assert_gt(drops, 0, "resource drops rose there too")
	assert_lte(longest * FRAME, MOMENT, "none stayed over a bar past a moment")


# --- R9 ------------------------------------------------------------------------


func test_r9_in_the_showcase() -> void:
	var moments: Array[StringName] = [
		&"knight_actions", &"rogue_actions", &"mage_actions", &"cleric_actions", &"statuses"
	]
	for moment: StringName in moments:
		assert_has(Showcase.names(), moment, "%s is a moment" % moment)
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
				tree.path(Showcase.CLASS_PATHS[class_id]).nodes
			):
				var ability: AbilityDef = Content.ability(ability_id)
				if ability.is_action() and names.has(ability.display_name):
					actions += 1
			assert_gt(actions, 0, "the %s's actions are named over it" % class_id)

extends "res://tests/unit/lively_moves_test_base.gd"
## Acceptance tests for specs/057-lively-moves/spec.md, one per requirement.
##
## They use spec 056's rig: a World on a seeded simulation with the CombatEffects that listen to
## it, every _process turned off, and frames played by hand. A move is read from the sprite itself:
## its Rig node (the whole body: position, turn, scale) and its parts' angles, and from
## [member CharacterSprite.moves], which says what is playing and what the moves add to the pose.
## Spell visuals are read from the [SpellEffects] that [CombatEffects] makes.

## The seed and the guardian of spec 038's guardian fights: the Slime King on stage 5, on the
## party's right.
const GUARDIAN_SEED: int = 1
const GUARDIAN_DEPTH: int = 5
const GUARDIAN_LEVEL: int = 40
## How many times its health the guardian has in R3, so the heroes' actions come round.
const GUARDIAN_TOUGHER: int = 6
## The lead given to each move in R2, in seconds: a wind-up of the usual length.
const LEAD: float = 0.5
## The longest recovery after a blow (R3).
const RECOVERY: float = 0.4
## How close (in frames) a move's blow falls to the event that says it lands: within one tick.
const SAME_TICK_FRAMES: int = 60 / TPS
const TICK_SECONDS: float = 1.0 / TPS
## R4: one real ability for each kind of spell visual, and the hero that uses it.
const SPELLS: Array[Array] = [
	[&"fireball", MAGE],
	[&"meteor", MAGE],
	[&"ice_lance", MAGE],
	[&"frost_nova", MAGE],
	[&"blizzard", MAGE],
	[&"chain_spark", MAGE],
	[&"inferno", MAGE],
	[&"prayer", CLERIC],
	[&"smite", CLERIC],
	[&"fan_of_knives", ROGUE],
	[&"mark_for_death", ROGUE],
]
## R4: the colour each family reads as.
const FAMILY_COLOR: Dictionary[StringName, StringName] = {
	&"fire": &"orange", &"frost": &"cyan", &"holy": &"yellow", &"shadow": &"orchid"
}

# --- R1 ------------------------------------------------------------------------


func test_r1_every_ability_has_a_move() -> void:
	var moves: Array[StringName] = AbilityDef.MOVES
	assert_between(moves.size(), 10, 14, "a small set of moves")
	for needed: StringName in [
		&"leap",
		&"spin",
		&"dash",
		&"heavy_swing",
		&"throw",
		&"brace",
		&"shout",
		&"cast",
		&"channel",
		&"prayer",
		&"flourish"
	]:
		assert_has(moves, needed, "the set holds %s" % needed)
	var ids: Array[StringName] = Content.ability_ids()
	assert_eq(ids.size(), 60, "the 60 abilities")
	var used: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		var ability: AbilityDef = Content.ability(id)
		assert_has(moves, ability.move, "%s names a move of the set" % id)
		assert_eq(ability.validate(), PackedStringArray(), "%s is valid" % id)
		used[ability.move] = true
	assert_eq(used.size(), moves.size(), "every move is some ability's")
	# A few the spec names.
	assert_eq(Content.ability(&"whirlwind").move, &"spin", "Whirlwind spins")
	assert_eq(Content.ability(&"meteor").move, &"channel", "Meteor channels")
	assert_eq(Content.ability(&"backstab").move, &"dash", "Backstab dashes")
	assert_has([&"leap", &"heavy_swing"], Content.ability(&"shield_bash").move, "Shield Bash")
	assert_eq(Content.ability(&"prayer").move, &"prayer", "Prayer prays")

	# The data check fails on an ability with no move, or one not in the set.
	var copy: AbilityDef = Content.ability(&"whirlwind").duplicate(true)
	copy.move = &""
	assert_gt(copy.validate().size(), 0, "no move is a problem")
	assert_string_contains(" ".join(copy.validate()), "move")
	copy.move = &"moonwalk"
	assert_gt(copy.validate().size(), 0, "an unknown move is a problem")
	assert_string_contains(" ".join(copy.validate()), "moonwalk")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_body_really_moves() -> void:
	for class_id: StringName in [&"knight", &"rogue", &"mage", &"cleric"]:
		for move: StringName in AbilityDef.MOVES:
			_measure_move(class_id, move)


## Plays [param move] on a real sprite of [param class_id], frame by frame, and measures it.
func _measure_move(class_id: StringName, move: StringName) -> void:
	var sprite: CharacterSprite = _hero_sprite(class_id)
	var rig: Node2D = _rig(sprite)
	sprite.advance(FRAME)
	assert_eq(rig.position, Vector2.ZERO, "at rest before")
	var label: String = "%s's %s" % [class_id, move]
	sprite.play_move(move, LEAD)
	var rise: float = 0.0
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var flip: float = 1.0
	var turned: float = 0.0
	var parts: float = 0.0
	var squash: float = 0.0
	var tall_in_air: bool = false
	var wide_on_landing: bool = false
	var frames: int = 0
	var limit: int = ceili((LEAD + RECOVERY) / FRAME) + 2
	while sprite.moves.is_moving() and frames < limit * 2:
		sprite.advance(FRAME)
		frames += 1
		var at: Vector2 = rig.position
		rise = maxf(rise, -at.y)
		low = Vector2(minf(low.x, at.x), minf(low.y, at.y))
		high = Vector2(maxf(high.x, at.x), maxf(high.y, at.y))
		flip = minf(flip, rig.scale.x)
		turned = maxf(turned, absf(rig.rotation))
		parts = maxf(parts, _part_turn(sprite))
		squash = maxf(squash, maxf(absf(rig.scale.x - 1.0), absf(rig.scale.y - 1.0)))
		if at.y <= -4.0 and rig.scale.y > 1.0:
			tall_in_air = true
		if at.y > -1.0 and rig.scale.y < 0.95 and rig.scale.x > 1.0:
			wide_on_landing = true
	assert_lte(frames, limit, "%s ends within its lead and recovery" % label)
	assert_true(
		rise >= 2.0 or high.x - low.x >= 2.0 or turned >= 0.1 or parts >= 0.3 or flip < 0.0,
		(
			"%s moves the body (rise %.1f, travel %.1f, turn %.2f, parts %.2f)"
			% [label, rise, high.x - low.x, turned, parts]
		)
	)
	assert_gt(squash, 0.05, "%s squashes and stretches" % label)
	match move:
		&"leap":
			assert_gte(rise, 8.0, "%s rises 8 pixels or more" % label)
			assert_true(tall_in_air, "%s is taller in the air" % label)
			assert_true(wide_on_landing, "%s is shorter and wider on landing" % label)
		&"spin":
			assert_true(flip <= -0.9 or turned >= TAU, "%s turns right round" % label)
		&"dash":
			assert_gte(high.x - low.x, 12.0, "%s travels 12 pixels or more" % label)
		&"cast":
			assert_gte(rise, 3.0, "%s lifts 3 pixels or more" % label)
	# At rest again: exactly.
	assert_eq(rig.position, Vector2.ZERO, "%s: back in place" % label)
	assert_eq(rig.rotation, 0.0, "%s: upright" % label)
	assert_eq(rig.scale, Vector2.ONE, "%s: its scale back to 1" % label)
	assert_eq(_part_turn(sprite), 0.0, "%s: every part at rest" % label)
	assert_true(_move_at_rest(sprite), "%s: nothing left of it" % label)


func test_r2_a_flourish_does_not_interrupt() -> void:
	var sprite: CharacterSprite = _hero_sprite(&"rogue")
	sprite.play_attack(0.4, false)
	sprite.advance(0.1)
	sprite.play_move(&"flourish", 0.0)
	var rise: float = 0.0
	for i: int in 10:
		sprite.advance(FRAME)
		assert_true(sprite.is_attacking(), "the strike goes on")
		rise = maxf(rise, -sprite.moves.shift.y)
	assert_gte(rise, 3.0, "over a hop")


# --- R3 ------------------------------------------------------------------------


func test_r3_a_move_keeps_the_fight_true() -> void:
	for path: int in 2:
		_guardian_fight(path)


## Puts the party of [constant GUARDIAN_LEVEL] with every class's full tree down path [param path]
## outside the guardian's chamber, as spec 038's tests do, and plays its fight frame by frame.
func _guardian_fight(path: int) -> void:
	var simulation := Simulation.new(GUARDIAN_SEED)
	for hero: Hero in simulation.party.heroes:
		hero.gain_xp(Hero.xp_for_level(GUARDIAN_LEVEL) - hero.xp)
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		hero.set_talents(tree.path(path).nodes)
		hero.health = hero.max_health()
	var e: Expedition = simulation.expedition
	var lair: LabyrinthChamber = simulation.labyrinth.level(GUARDIAN_DEPTH).shaft_chamber()
	simulation.set_auto_push(false)
	e.depth = GUARDIAN_DEPTH
	e.target_depth = GUARDIAN_DEPTH + 1
	e.x = lair.rect.position.x - 1.0
	e.facing = 1
	_heard.clear()
	_owed = 0.0
	_build(simulation)
	var label: String = "path %d" % path
	var frames: int = 0
	while not _fighting() and frames < 60 * 120:
		_play_at_speed()
		frames += 1
	var guardian: Combatant = GuardianSpacing.fighting_guardian(_sim)
	assert_not_null(guardian, "%s: the guardian's fight starts" % label)
	if guardian == null:
		return
	guardian.max_health *= GUARDIAN_TOUGHER
	guardian.health = guardian.max_health
	var floor_y: float = (_sim.labyrinth.level(GUARDIAN_DEPTH).floor_y + 1) * World.TILE
	var started: Dictionary[int, StringName] = {}
	var used_frames: Dictionary[int, Array] = {}
	var impact_frames: Dictionary[int, Array] = {}
	var impacts: Dictionary[int, int] = {}
	var moving: Dictionary[int, bool] = {}
	var main: Dictionary[int, bool] = {}
	var landed_at: Dictionary[int, int] = {}

	var problems: Array[String] = []
	var blow_frames: int = 0
	var numbered: int = 0
	var ends: int = 0
	var leaps: int = 0
	for id: int in HERO_IDS:
		used_frames[id] = []
		impact_frames[id] = []
		impacts[id] = 0
		moving[id] = false
		main[id] = false
	frames = 0
	while _fighting() and frames < 60 * 90:
		var start: int = _heard.size()
		_play_at_speed()
		frames += 1
		var hits: int = 0
		for event: SimEvent in _heard.slice(start):
			if event.kind == SimEvent.Kind.HIT and event.amount > 0:
				hits += 1
			if not event.source_id in HERO_IDS or not _world.is_recent(event):
				continue
			match event.kind:
				SimEvent.Kind.ABILITY_STARTED:
					started[event.source_id] = event.ability_id
				SimEvent.Kind.ABILITY_USED:
					if started.get(event.source_id, &"") == event.ability_id:
						used_frames[event.source_id].append(frames)
						started.erase(event.source_id)
						# The move got to its blow by its own timing: the landing brought it forward
						# a tick at most (a wrong lead would leave it far short of its blow).
						var mover: CharacterSprite = _world.character(event.source_id)
						if mover.moves.brought_forward > TICK_SECONDS + 0.001:
							problems.append(
								(
									"frame %d: hero %d's %s short of its blow"
									% [frames, event.source_id, event.ability_id]
								)
							)
		# A blow's number shows in the frame its tick is heard (one frame old then), never later.
		# (Spec 018 leaves out a number with nowhere clear to go: a few blows show none.)
		var fresh: int = 0
		for text: FxText in _fx.texts():
			if text.kind == &"damage" and text.age <= FRAME * 1.01:
				fresh += 1
		if fresh > 0 and hits == 0:
			problems.append("frame %d: a number with no blow heard" % frames)
		if hits > 0:
			blow_frames += 1
			numbered += 1 if fresh > 0 else 0
		var guardian_pixels: Dictionary[Vector2i, bool] = {}
		var guardian_sprite: CharacterSprite = _world.character(guardian.id)
		for id: int in HERO_IDS:
			var sprite: CharacterSprite = _world.character(id)
			if sprite == null:
				continue
			if sprite.moves.impacts != impacts[id]:
				impacts[id] = sprite.moves.impacts
				impact_frames[id].append(frames)
				landed_at[id] = frames
				var played: StringName = sprite.moves.landed_move()
				if played in [&"leap", &"dash"] and guardian_sprite != null:
					leaps += 1
					if guardian_pixels.is_empty():
						guardian_pixels = _drawn(guardian_sprite, false)
					if _shares(_drawn(sprite, true), guardian_pixels):
						problems.append(
							"frame %d: hero %d's %s lands on the guardian" % [frames, id, played]
						)
			# The main move (an action's): its recovery after its blow is short.
			var main_now: bool = sprite.moves.playing() != &""
			if main[id] and not main_now:
				var after: int = frames - landed_at.get(id, frames)
				if after * FRAME > RECOVERY + 2.0 * FRAME:
					problems.append(
						"frame %d: hero %d recovered for %d frames" % [frames, id, after]
					)
			main[id] = main_now
			# Every move: on the screen and over the floor while it plays; at rest, in its place
			# and off the guardian once none is left.
			var now: bool = sprite.moves.is_moving()
			if now:
				var box: Rect2 = _drawn_rect(sprite)
				var view: Rect2 = Rect2(_to_world(Vector2.ZERO), _to_world(Vector2(640, 360)))
				view.size -= view.position
				if box.size.x > 0.0 and not view.grow(1.0).encloses(box):
					problems.append("frame %d: hero %d leaves the screen" % [frames, id])
				if box.end.y > floor_y + 1.0:
					problems.append(
						(
							"frame %d: hero %d below the floor (%s) by %.1f"
							% [frames, id, sprite.moves.names(), box.end.y - floor_y]
						)
					)
			if moving[id] and not now:
				ends += 1
				if not _move_at_rest(sprite):
					problems.append("frame %d: hero %d not at rest" % [frames, id])
				# Where the world puts it, easing after its place in the fight as ever.
				var gap: float = sprite.position.distance_to(_world._goals[id])
				if gap > World.RUN_SPEED / World.FOLLOW_RATE + 1.0:
					problems.append("frame %d: hero %d %.1f px from its place" % [frames, id, gap])
				if guardian_sprite != null:
					if guardian_pixels.is_empty():
						guardian_pixels = _drawn(guardian_sprite, false)
					if _shares(_drawn(sprite, false), guardian_pixels):
						problems.append("frame %d: hero %d ends on the guardian" % [frames, id])
			moving[id] = now
	assert_gt(frames, 120, "%s: a fight of some length" % label)
	assert_gt(blow_frames, 60, "%s: blows were struck" % label)
	assert_gte(numbered, blow_frames * 0.95, "%s: their numbers show as they land" % label)

	assert_eq(problems.slice(0, 20), [] as Array[String], "%s: no problems" % label)
	problems.clear()
	var matched: int = 0
	for id: int in HERO_IDS:
		for used: int in used_frames[id]:
			var near: bool = false
			for landed: int in impact_frames[id]:
				near = near or absi(landed - used) <= SAME_TICK_FRAMES
			if near:
				matched += 1
			else:
				problems.append(
					(
						"hero %d: an action landed on frame %d, its move not: %s"
						% [id, used, impact_frames[id]]
					)
				)
	assert_gt(matched, 6, "%s: actions were watched land" % label)
	assert_eq(problems.slice(0, 8), [] as Array[String], "%s: every blow on its tick" % label)
	assert_gt(ends, 6, "%s: moves ended" % label)
	assert_gt(leaps, 0, "%s: a leap or dash on the guardian" % label)


# --- R4 ------------------------------------------------------------------------


func test_r4_spells_are_seen() -> void:
	assert_true(_find_fight(2), "a fight of two monsters or more")
	var battle: Battle = _sim.expedition.battle
	for fighter: Combatant in battle.heroes:
		fighter.abilities = []
	for spell: Array in SPELLS:
		var ability_id: StringName = spell[0]
		var hero_id: int = spell[1]
		_see_spell(ability_id, hero_id)


## Gives hero [param hero_id] the one ability [param ability_id] in the fight going on, lets it
## use it, and watches its visual from its first event to a second after it lands.
func _see_spell(ability_id: StringName, hero_id: int) -> void:
	var battle: Battle = _sim.expedition.battle
	var ability: AbilityDef = Content.ability(ability_id)
	var kind: StringName = SpellEffects.KINDS.get(ability_id, &"")
	assert_ne(kind, &"", "%s has a spell visual" % ability_id)
	if kind == &"" or battle == null:
		return
	var family: Array = SpellEffects.FAMILIES[SpellEffects.FAMILY_OF[kind]]
	var main_color: StringName = FAMILY_COLOR.get(SpellEffects.FAMILY_OF[kind], family[0])
	var fighter: Combatant = battle.combatant(hero_id)
	fighter.abilities = [ability]
	fighter.pending_action = null
	fighter.chasing = &""
	fighter.action_ready_tick[ability_id] = battle.tick
	if ability_id == &"chain_spark":
		fighter.crit_chance = 1.0
	var started: bool = false
	var flew: bool = false
	var landed: int = -1
	var frames: int = 0
	while landed < 0 and frames < 60 * 30:
		_keep_going(battle, ability_id)
		var start: int = _heard.size()
		_play_at_speed()
		frames += 1
		for event: SimEvent in _heard.slice(start):
			if event.source_id != hero_id or event.ability_id != ability_id:
				continue
			if event.kind == SimEvent.Kind.ABILITY_STARTED:
				started = true
			elif event.kind == SimEvent.Kind.ABILITY_USED and landed < 0:
				landed = frames
		if started and landed < 0 and not _spells().particles(kind).is_empty():
			flew = true
	assert_gt(landed, -1, "%s was used in the fight" % ability_id)
	fighter.abilities = []
	fighter.crit_chance = 0.0
	if landed < 0:
		return
	if kind in [&"fireball", &"meteor", &"ice_shard"]:
		assert_true(flew, "%s's %s is seen in flight" % [ability_id, kind])
	var shown: Array[FxParticle] = _spells().particles(kind)
	assert_gt(shown.size(), 0, "%s's %s shows as it lands" % [ability_id, kind])
	var main_seen: bool = false
	for particle: FxParticle in shown:
		var named: bool = false
		for color_name: StringName in family:
			named = named or particle.color == Palette.color(color_name)
		assert_true(named, "%s: every square of %s's colours" % [kind, family])
		main_seen = main_seen or particle.color == Palette.color(main_color)
	assert_true(main_seen, "%s reads %s" % [kind, main_color])
	for i: int in 60:
		_keep_going(battle, &"")
		_play_at_speed()
	assert_eq(_spells().particles(kind).size(), 0, "%s is gone a second after landing" % kind)


## Keeps the watched fight going: no one dies, and the heroes are hurt enough for a heal.
func _keep_going(battle: Battle, ability_id: StringName) -> void:
	for monster: Combatant in battle.monsters:
		if monster.is_alive():
			monster.health = monster.max_health
			monster.damage = 1
	for fighter: Combatant in battle.heroes:
		if fighter.is_alive():
			fighter.health = fighter.max_health
	if ability_id == &"prayer":
		var knight: Combatant = battle.combatant(KNIGHT)
		knight.health = knight.max_health / 2


## A spell that shows on whom it lands shows only on the fighters the simulation says it reached
## (as a radius that leaves one enemy out would): its HIT, HEALED or STATUS_BEGAN events.
func test_r4_a_spell_shows_only_on_whom_it_reached() -> void:
	_build(Simulation.new(SEED))
	_at = 0
	var monsters: Array[int] = []
	for id: int in _world._monsters:
		if _world.character(id) != null:
			monsters.append(id)
	assert_gte(monsters.size(), 2, "enemies to leave one out of")
	var reached: int = monsters[0]
	var burning := _event(SimEvent.Kind.STATUS_BEGAN, MAGE, reached, 50, &"inferno")
	burning.status = AbilityEffect.Status.BURNING
	_tell([_event(SimEvent.Kind.ABILITY_USED, MAGE, reached, 0, &"inferno"), burning])
	_only_on(&"flames", reached, [] as Array[int] + monsters.slice(1), "Inferno")
	_wait(1.2)
	var blessed := _event(SimEvent.Kind.STATUS_BEGAN, CLERIC, KNIGHT, 30, &"blessing")
	blessed.status = AbilityEffect.Status.MIGHTY
	_tell([_event(SimEvent.Kind.ABILITY_USED, CLERIC, KNIGHT, 0, &"blessing"), blessed])
	_only_on(&"light_column", KNIGHT, [ROGUE, MAGE, CLERIC] as Array[int], "Blessing")
	# A beam from above starts under the HUD's top band: it never covers the boss bar (R8).
	_wait(1.2)
	_tell(
		[
			_event(SimEvent.Kind.ABILITY_USED, CLERIC, reached, 0, &"smite"),
			_event(SimEvent.Kind.HIT, CLERIC, reached, 40),
		]
	)
	_only_on(&"holy_beam", reached, [] as Array[int] + monsters.slice(1), "Smite")
	for particle: FxParticle in _spells().particles(&"holy_beam"):
		var box: Rect2 = _on_screen(particle.rect())
		assert_gt(box.position.y, HudFrame.TOP_BAND, "the beam starts under the boss bar")
		if particle.shape == FxParticle.Shape.COLUMN:
			assert_gt(box.size.y, 40.0, "and falls from high above its target")


# --- R5 ------------------------------------------------------------------------


func test_r5_ordinary_fighting_has_more_bounce() -> void:
	# A melee strike: a clear draw back, a step in, a settle; its timing as before.
	var knight: CharacterSprite = _hero_sprite(&"knight")
	var swing: Vector2 = _swing(knight, false)
	assert_lte(swing.x, -3.0, "the knight draws back 3 pixels or more")
	assert_gte(swing.y, 4.0, "and steps in 4 pixels or more")
	assert_eq(_rig(knight).position, Vector2.ZERO, "and settles")
	assert_eq(CharacterSprite.STRIKE_TIME, 0.06, "the strike takes as long as before")
	assert_eq(CharacterSprite.HOLD_TIME, 0.14, "")
	assert_eq(CharacterSprite.SETTLE_TIME, 0.22, "")
	# A shot: a small recoil.
	var mage: CharacterSprite = _hero_sprite(&"mage")
	mage.play_attack(0.3, true)
	var recoil: float = 0.0
	var released: Array[bool] = [false]
	mage.struck.connect(func() -> void: released[0] = true)
	for i: int in 60:
		mage.advance(FRAME)
		if released[0]:
			recoil = minf(recoil, _rig(mage).position.x)
	assert_lte(recoil, -1.5, "the mage's shot kicks it back")
	assert_eq(_rig(mage).position, Vector2.ZERO, "then it settles")
	# A monster's strike: the same draw back and step.
	for monster_id: StringName in Content.monster_ids():
		var monster: CharacterSprite = CharacterSprite.for_monster(monster_id)
		add_child_autofree(monster)
		monster.set_process(false)
		var lunge: Vector2 = _swing(monster, false)
		assert_lte(lunge.x, -3.0, "the %s draws back" % monster_id)
		assert_gte(lunge.y, 4.0, "the %s steps in" % monster_id)

	# A kill and a crit: a small hop.
	var monster_id: int = _monster()
	_tell(
		[
			_event(SimEvent.Kind.HIT, KNIGHT, monster_id, 30),
			_event(SimEvent.Kind.DIED, monster_id, -1)
		]
	)
	assert_gte(_hop(KNIGHT), 3.0, "the knight hops on its kill")
	_at += 10
	var crit := _event(SimEvent.Kind.HIT, ROGUE, KNIGHT, 30)
	crit.flag = true
	_tell([crit])
	assert_gte(_hop(ROGUE), 3.0, "the rogue hops on its crit")
	_wait(1.0)

	# A fight won: each hero cheers, not all at the same instant.
	_at += 10
	var won := _event(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1)
	won.flag = true
	_tell([won])
	var first: Dictionary[int, int] = {}
	for frame: int in 60:
		for id: int in HERO_IDS:
			var sprite: CharacterSprite = _world.character(id)
			if not first.has(id) and sprite.moves.shift.y < -0.5:
				first[id] = frame
		_frame()
	assert_eq(first.size(), 4, "every hero cheers")
	var frames_used: Dictionary[int, bool] = {}
	for id: int in first:
		frames_used[first[id]] = true
	assert_eq(frames_used.size(), 4, "each on its own frame: %s" % first)

	# None of it changes how long a fight takes.
	var alone := Simulation.new(SEED)
	_full_trees_of(alone)
	_full_trees_of(_sim)
	var watched: int = _first_fight_end(_sim, true)
	var unwatched: int = _first_fight_end(alone, false)
	assert_gt(watched, 0, "a fight was watched to its end")
	assert_eq(watched, unwatched, "it ends on the same tick watched or not")
	assert_eq(_sim.state_hash(), alone.state_hash(), "with the same state")


# --- R6 ------------------------------------------------------------------------


func test_r6_interrupted_cleanly() -> void:
	var enders: Array[String] = ["stun", "death", "fight end", "wipe", "stage", "area"]
	for ender: String in enders:
		_build(Simulation.new(SEED))
		_at = 0
		var monster: int = _monster()
		_tell(
			[
				_event(SimEvent.Kind.ABILITY_STARTED, KNIGHT, monster, 5, &"shield_bash"),
				_event(SimEvent.Kind.ABILITY_STARTED, MAGE, monster, 6, &"fireball"),
			]
		)
		_wait(0.3)
		var knight: CharacterSprite = _world.character(KNIGHT)
		assert_lt(knight.moves.shift.y, -2.0, "%s: the knight is in the air" % ender)
		assert_gt(_spells().live(), 0, "%s: the fireball is on its way" % ender)
		_at += 1
		var told: Array[SimEvent] = []
		match ender:
			"stun":
				for id: int in [KNIGHT, MAGE]:
					var stun := _event(SimEvent.Kind.STATUS_BEGAN, monster, id, 20, &"")
					stun.status = AbilityEffect.Status.STUNNED
					told.append(stun)
			"death":
				told.append(_event(SimEvent.Kind.DIED, KNIGHT, -1))
				told.append(_event(SimEvent.Kind.DIED, MAGE, -1))
			"fight end":
				told.append(_event(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1))
			"wipe":
				told.append(_event(SimEvent.Kind.PARTY_WIPED, -1, -1))
			"stage":
				told.append(_event(SimEvent.Kind.DEPTH_CHANGED, -1, -1, _sim.expedition.depth))
			"area":
				told.append(_event(SimEvent.Kind.AREA_CHANGED, -1, -1))
		_tell(told)
		for id: int in [KNIGHT, MAGE]:
			var sprite: CharacterSprite = _world.character(id)
			assert_true(_move_at_rest(sprite), "%s: the move ends at once" % ender)
			assert_false(sprite.moves.is_moving(), "%s: over" % ender)
			# In its place: where the world has it, its body over that place and on the floor.
			assert_almost_eq(
				sprite.position.distance_to(_world._goals[id]), 0.0, 0.5, "%s: in place" % ender
			)
			if not sprite.is_dead():
				assert_almost_eq(_rig(sprite).position.x, 0.0, 0.5, "%s: over it" % ender)
				assert_gte(_rig(sprite).position.y, -CharacterSprite.STEP_HOP, "%s: down" % ender)
		assert_eq(_spells().live(), 0, "%s: no spell visual left" % ender)
		_wait(1.0)
		assert_eq(_spells().live(), 0, "%s: nor later" % ender)


func test_r6_a_held_hero_starts_no_move() -> void:
	_build(Simulation.new(SEED))
	_at = 0
	var monster: int = _monster()
	var knight: CharacterSprite = _world.character(KNIGHT)
	knight.held = true  # stunned: spec 056's marks hold it still
	var passive := _event(SimEvent.Kind.ABILITY_USED, KNIGHT, monster, 0, &"bloodthirst")
	_tell([passive])
	assert_false(knight.moves.is_moving(), "a passive that fires on a stunned hero moves nothing")
	knight.held = false
	_wait(0.5)
	assert_false(knight.moves.is_moving(), "nor once the stun is over")
	assert_eq(knight.moves.impacts, 0, "nothing played late")


## A move that ends during a hit-stop lets go of its pose at once, not when the stop is over.
func test_r6_a_move_ended_in_a_hit_stop_is_at_rest() -> void:
	_build(Simulation.new(SEED))
	var knight: CharacterSprite = _world.character(KNIGHT)
	knight.play_move(&"heavy_swing", 0.1)
	var frames: int = 0
	while (knight.moves.impacts == 0 or absf(knight.moves.turn) < 0.05) and frames < 60:
		_frame()
		frames += 1
	assert_gt(absf(knight.moves.turn), 0.05, "the swing's recovery leans the body")
	_world._frozen = 2.0
	frames = 0
	while knight.moves.is_moving() and frames < 60:
		_frame()
		frames += 1
	assert_false(knight.moves.is_moving(), "the move ends inside the hit-stop")
	# Its body is already as the sprite poses it now, with nothing of the swing.
	var shown: Transform2D = _rig(knight).transform
	knight.advance(0.0)
	assert_eq(shown, _rig(knight).transform, "and the body lets go of the swing at once")


## An action whose start was too old to move for (heard only as it lands) plays no move after.
func test_r3_an_action_heard_only_as_it_lands_moves_nothing() -> void:
	_build(Simulation.new(SEED))
	_at = 0
	var monster: int = _monster()
	var knight: CharacterSprite = _world.character(KNIGHT)
	_tell([_event(SimEvent.Kind.ABILITY_USED, KNIGHT, monster, 0, &"shield_bash")])
	assert_false(knight.moves.is_moving(), "no leap after its blow")
	var passive := _event(SimEvent.Kind.ABILITY_USED, KNIGHT, monster, 0, &"bloodthirst")
	_tell([passive])
	assert_true(knight.moves.is_moving(), "while a passive firing still shows its move")


# --- R7 ------------------------------------------------------------------------


func test_r7_true_in_a_crowded_frame() -> void:
	_full_trees()
	assert_true(_find_fight(2, 1, true, 1), "a fight, watched")
	# Watched to its end, with moves and spells under way; then 300 ticks unwatched before one
	# frame, again until those ticks hold a whole fight with actions in it.
	var under_way: int = 0
	for i: int in 3000:
		if not _fighting():
			break
		_sim.step()
		for f: int in 6:
			_frame()
			for id: int in HERO_IDS:
				if _world.character(id).moves.is_moving():
					under_way += 1
	assert_gt(under_way, 0, "moves were played in the watched fight")
	var whole: bool = false
	for tries: int in 20:
		_play_at_speed()
		var start: int = _heard.size()
		for i: int in 300:
			_sim.step()
		_frame()
		var kinds: Dictionary[SimEvent.Kind, bool] = {}
		for event: SimEvent in _heard.slice(start):
			kinds[event.kind] = true
		whole = (
			kinds.has(SimEvent.Kind.ENCOUNTER_STARTED)
			and kinds.has(SimEvent.Kind.ENCOUNTER_ENDED)
			and kinds.has(SimEvent.Kind.ABILITY_STARTED)
		)
		if whole:
			break
	assert_true(whole, "300 ticks held a whole fight with actions in it")
	for id: int in _world._sprites:
		var sprite: CharacterSprite = _world.character(id)
		assert_false(sprite.moves.is_moving(), "%d starts no move" % id)
		assert_true(_move_at_rest(sprite), "%d at rest" % id)
		assert_eq(sprite.position, _world._goals[id], "%d where the simulation has it" % id)
	assert_eq(_spells().live(), 0, "no spell visual")

	# At 4x a move is shortened to fit, and still shows.
	_shortened_at_4x()


## A stall that ends a tick or two after a hero's action began, a crit, a kill or a won fight
## starts nothing for them, and leaves nothing of what was under way before it.
func test_r7_a_stall_starts_nothing_and_leaves_nothing() -> void:
	for won: bool in [false, true]:
		var label: String = "a stall ending on a won fight" if won else "a stall in a fight"
		_build(Simulation.new(SEED))
		_at = 0
		var monster: int = _monster()
		_tell(
			[
				_event(SimEvent.Kind.ABILITY_STARTED, KNIGHT, monster, 5, &"shield_bash"),
				_event(SimEvent.Kind.ABILITY_STARTED, MAGE, monster, 6, &"fireball"),
			]
		)
		_wait(0.3)
		assert_true(_world.character(KNIGHT).moves.is_moving(), "%s: a move under way" % label)
		assert_gt(_spells().live(), 0, "%s: a spell under way" % label)
		var before: Array[FxParticle] = _spells().all_particles()
		# Ticks go by with no frame; the frame after them hears events a tick old.
		_sim._tick += World.STALL_TICKS + 4
		_at = -1
		var crit := _event(SimEvent.Kind.HIT, ROGUE, monster, 30)
		crit.flag = true
		var late: Array[SimEvent] = [
			_event(SimEvent.Kind.ABILITY_STARTED, ROGUE, monster, 5, &"backstab"),
			_event(SimEvent.Kind.ABILITY_STARTED, MAGE, monster, 6, &"ice_lance"),
			_event(SimEvent.Kind.ABILITY_USED, MAGE, monster, 0, &"frost_nova"),
			_event(SimEvent.Kind.ABILITY_USED, CLERIC, monster, 0, &"smite"),
			_event(SimEvent.Kind.HIT, CLERIC, monster, 20),
			crit,
		]
		if won:
			late.append(_event(SimEvent.Kind.DIED, monster, -1))
			var end := _event(SimEvent.Kind.ENCOUNTER_ENDED, -1, -1)
			end.flag = true
			late.append(end)
		_sim._events.append_array(late)
		_world.sync(FRAME)
		# Before the effects move on: nothing was started for the events past.
		var started: int = 0
		for particle: FxParticle in _spells().all_particles():
			started += 0 if particle in before else 1
		for flight: SpellEffects.Flight in _spells()._flights:
			started += 1 if flight.ability == &"ice_lance" else 0
		assert_eq(started, 0, "%s: no spell starts for them" % label)
		_fx.advance(FRAME)
		for id: int in _world._sprites:
			var sprite: CharacterSprite = _world.character(id)
			assert_eq(sprite.moves.names(), [] as Array[StringName], "%s: %d still" % [label, id])
			assert_true(_move_at_rest(sprite), "%s: %d at rest" % [label, id])
		assert_eq(_spells().live(), 0, "%s: no spell visual left" % label)


func _shortened_at_4x() -> void:
	_build(Simulation.new(SEED))
	_world.speed = 4
	var monster: int = _monster()
	_tell([_event(SimEvent.Kind.ABILITY_STARTED, KNIGHT, monster, 4, &"shield_bash")])
	var knight: CharacterSprite = _world.character(KNIGHT)
	var rise: float = 0.0
	var frames: int = 0
	var landed: int = -1
	while knight.moves.is_moving() and frames < 120:
		_frame()
		frames += 1
		rise = maxf(rise, -knight.moves.shift.y)
		if landed < 0 and knight.moves.impacts > 0:
			landed = frames
	assert_gte(rise, 8.0, "the leap still rises 8 pixels")
	assert_almost_eq(landed * FRAME, 0.4 / 4.0, 2.0 * FRAME, "it lands a quarter as soon")
	assert_lte(frames * FRAME, (0.4 + RECOVERY) / 4.0 + 2.0 * FRAME, "and is over as soon")


# --- R8 ------------------------------------------------------------------------


func test_r8_still_readable() -> void:
	_build(Simulation.new(SEED), true)
	_full_trees()
	_world.speed = 4
	assert_true(_find_fight(5, 4, false, TOUGHER * 4), "a fight of four heroes and five monsters")
	assert_eq(_sim.expedition.battle.monsters.size(), 5, "five monsters")
	var covering: Dictionary[Object, int] = {}
	var longest: int = 0
	var moves: int = 0
	var spells: int = 0
	var most_particles: int = 0
	var frames: int = 0
	while _fighting() and frames < 60 * 40:
		for i: int in 4:
			_sim.step()
		_frame()
		frames += 1
		var bars: Array[Rect2] = []
		for frame: HeroFrameView in _hud.frames:
			bars.append(frame.get_global_rect())
		if _hud.boss_bar.is_visible_in_tree():
			bars.append(_hud.boss_bar.get_global_rect())
		var boxes: Dictionary[Object, Rect2] = {}
		for id: int in HERO_IDS:
			var sprite: CharacterSprite = _world.character(id)
			if sprite != null and sprite.moves.is_moving():
				moves += 1
				boxes[sprite] = _on_screen(_drawn_rect(sprite))
		for particle: FxParticle in _spells().all_particles():
			spells += 1
			boxes[particle] = _on_screen(particle.rect())
		for shown: Object in boxes:
			var over: bool = false
			for bar: Rect2 in bars:
				over = over or boxes[shown].intersects(bar)
			covering[shown] = covering.get(shown, 0) + 1 if over else 0
			longest = maxi(longest, covering[shown])
		var count: int = _fx.live_particles()
		most_particles = maxi(most_particles, count)
		assert_lte(count, CombatEffects.MAX_PARTICLES, "spec 010's particle limit")
		assert_lte(_spells().live(), SpellEffects.MAX_PARTICLES, "the spells' own limit")

	assert_gt(frames, 60, "the fight was watched for a while")
	assert_gt(moves, 0, "moves were played")
	assert_gt(spells, 0, "spells were seen")
	assert_lte(longest * FRAME, MOMENT, "nothing covers a health frame past a moment")


# --- R9 ------------------------------------------------------------------------


func test_r9_in_the_showcase_and_the_cast_demo() -> void:
	var demo: CharacterDemo = (
		(load("res://game/entities/character_demo.tscn") as PackedScene).instantiate()
	)
	add_child_autofree(demo)
	demo.set_process(false)
	var listed: Array[StringName] = CharacterDemo.MOVES.duplicate()
	listed.sort()
	var all: Array[StringName] = AbilityDef.MOVES.duplicate()
	all.sort()
	assert_eq(listed, all, "the demo's list holds every move")
	var played: Dictionary[StringName, bool] = {}
	var labelled: Dictionary[StringName, bool] = {}
	for i: int in roundi(CharacterDemo.moves_cycle() / FRAME) + 2:
		demo.advance(FRAME)
		var playing: StringName = demo.mover().moves.playing()
		if playing != &"":
			played[playing] = true
			labelled[playing] = demo.move_label().text.contains(String(playing).replace("_", " "))
	for move: StringName in AbilityDef.MOVES:
		assert_true(played.has(move), "the demo plays %s" % move)
		var shown: bool = labelled.get(move, false)
		assert_true(shown, "labelled %s" % move)

	var scene: PackedScene = load("res://game/dev/showcase.tscn")
	for moment: StringName in Showcase.CLASS_MOMENTS:
		# A showcase of its own for each: one class's moment runs on into the next's.
		var showcase: Showcase = scene.instantiate() as Showcase
		add_child_autofree(showcase)
		showcase.set_process(false)
		var class_id: StringName = Showcase.CLASS_MOMENTS[moment]
		var tree: TalentTreeDef = Content.talent_tree(class_id)
		var own: Dictionary[StringName, bool] = {}
		for ability_id: StringName in tree.path(Showcase.CLASS_PATHS[class_id]).nodes:
			own[Content.ability(ability_id).move] = true
		showcase.skip_to(moment)
		var seen: Dictionary[StringName, bool] = {}

		var start: float = showcase.elapsed
		while showcase.moment() == moment and showcase.elapsed - start < Showcase.GIVE_UP_SECONDS:
			showcase.advance(1.0 / 30.0)
			for hero: Hero in showcase.main.simulation.party.heroes:
				if hero.class_id != class_id:
					continue
				var sprite: CharacterSprite = showcase.main.world.character(hero.id)
				if sprite == null:
					continue
				for move: StringName in sprite.moves.names():
					if move in AbilityDef.MOVES:
						seen[move] = true
		for move: StringName in seen:
			assert_true(own.has(move), "%s: %s is one of its moves" % [class_id, move])
		assert_gte(
			seen.size(),
			2,
			"%s's moment shows more than one of its moves: %s" % [class_id, seen.keys()]
		)

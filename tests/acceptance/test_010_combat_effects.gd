extends ColonyTest
## Acceptance tests for specs/010-combat-effects/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation and the CombatEffects that listens to it, with
## both their _process turned off, feeds events through World.sim_event, and steps the effects with
## advance. Where a test needs what an effect is (its kind, colour, motion) it reads the effect's
## own fields, and the effects' private lists (_texts, _particles, _coins, _motes).

const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _collected: Array[int] = []


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
	_collected = []
	_fx.coin_collected.connect(func(amount: int) -> void: _collected.append(amount))


# --- Helpers -------------------------------------------------------------------


## A fresh event of [param kind], as the simulation would report it now.
func _emit(
	kind: SimEvent.Kind, source: int = -1, target: int = -1, amount: int = 0, flag: bool = false
) -> SimEvent:
	var event := SimEvent.new(kind, _sim.tick, source, target, amount, flag)
	_world.sim_event.emit(event)
	return event


## The id of a monster the world shows.
func _monster() -> int:
	for id: int in _world._monsters:
		if _world.character(id) != null:
			return id
	return -1


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_fx.advance(minf(FRAME, left))
		left -= FRAME


func _texts(kind: StringName) -> Array[FxText]:
	var found: Array[FxText] = []
	for text: FxText in _fx._texts:
		if text.kind == kind:
			found.append(text)
	return found


func _particles(kind: StringName) -> Array[FxParticle]:
	var found: Array[FxParticle] = []
	for particle: FxParticle in _fx._particles:
		if particle.kind == kind:
			found.append(particle)
	return found


## Every colour drawn in the sheet the sprite of [param id] was built from, read from its PNG.
func _sheet_colors(id: int) -> Dictionary[String, bool]:
	var colors: Dictionary[String, bool] = {}
	var sprite: CharacterSprite = _world.character(id)
	var part: Sprite2D = sprite.find_children("*", "Sprite2D", true, false)[0]
	var path: String = (part.texture as AtlasTexture).atlas.resource_path
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.5:
				colors[pixel.to_html(false)] = true
	return colors


# --- Tests ---------------------------------------------------------------------


func test_r1_damage_numbers() -> void:
	var monster: int = _monster()
	assert_ne(monster, -1, "the world shows a monster")
	var feet: Vector2 = _world.feet_position(monster)

	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 7)
	var numbers: Array[FxText] = _texts(&"damage")
	assert_eq(numbers.size(), 1, "a hit shows one number")
	var number: FxText = numbers[0]
	assert_eq(number.text, "7", "the number is the amount")
	assert_eq(number.color, Palette.color(&"white"), "a number on a monster is white")
	assert_almost_eq(number.position.x, feet.x, 8.0, "it appears over the target")
	assert_lt(number.position.y, feet.y - 8.0, "from the target's upper body")
	var start_y: float = number.position.y
	_advance(0.15)
	assert_lt(number.position.y, start_y, "it rises")

	_emit(SimEvent.Kind.HIT, monster, KNIGHT, 3)
	var on_hero: FxText = _texts(&"damage")[1]
	assert_eq(on_hero.color, Palette.color(&"red"), "a number on a hero is red")

	_emit(SimEvent.Kind.HIT, ROGUE, monster, 12, true)
	var crit: FxText = _texts(&"damage")[2]
	assert_eq(crit.text, "12!", "a crit has a !")
	assert_eq(crit.color, Palette.color(&"amber"), "a crit is gold")
	assert_gt(crit.scale_factor, number.scale_factor, "a crit is larger")
	_advance(0.1)
	assert_gt(crit.font_size(), number.font_size(), "and is drawn larger")

	_advance(0.8)
	assert_eq(_fx.live_numbers(), 0, "every number is gone within 0.8 seconds")

	# Two hits in quick succession on one target.
	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 4)
	_advance(0.05)
	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 5)
	var pair: Array[FxText] = _texts(&"damage")
	assert_eq(pair.size(), 2)
	_advance(FRAME)
	var dx: float = absf(pair[0].position.x - pair[1].position.x)
	var dy: float = absf(pair[0].position.y - pair[1].position.y)
	assert_true(
		dy >= 7.0 or dx >= 6.0, "two quick numbers do not overlap (dx %s, dy %s)" % [dx, dy]
	)


func test_r2_heal_numbers() -> void:
	var feet: Vector2 = _world.feet_position(KNIGHT)
	_emit(SimEvent.Kind.HEALED, CLERIC, KNIGHT, 9)
	var numbers: Array[FxText] = _texts(&"heal")
	assert_eq(numbers.size(), 1, "a heal shows a number")
	assert_eq(numbers[0].text, "+9")
	assert_eq(numbers[0].color, Palette.color(&"green"), "in green")
	assert_almost_eq(numbers[0].position.x, feet.x, 8.0, "over the healed hero")
	var sparkles: Array[FxParticle] = _particles(&"sparkle")
	assert_gte(sparkles.size(), 3, "with a few sparkles")
	var green: bool = false
	for sparkle: FxParticle in sparkles:
		green = green or sparkle.color == Palette.color(&"green")
		assert_lt(sparkle.position.distance_to(feet), 32.0, "around the hero")
	assert_true(green, "green sparkles")
	var start_y: float = numbers[0].position.y
	_advance(0.2)
	assert_lt(numbers[0].position.y, start_y, "rising")

	_advance(1.0)
	var texts_before: int = _fx._texts.size()
	var particles_before: int = _fx.live_particles()
	_emit(SimEvent.Kind.HEALED, CLERIC, KNIGHT, 0)
	assert_eq(_fx._texts.size(), texts_before, "a heal of 0 shows no number")
	assert_eq(_fx.live_particles(), particles_before, "and no sparkles")


func test_r3_hit_sparks() -> void:
	var monster: int = _monster()
	var away: float = signf(_world.feet_position(monster).x - _world.feet_position(KNIGHT).x)
	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 6)
	var sparks: Array[FxParticle] = _particles(&"spark")
	assert_between(sparks.size(), 4, 8, "a hit throws 4 to 8 sparks")
	var falls: Array[float] = []
	for spark: FxParticle in sparks:
		assert_gt(spark.velocity.x * away, 0.0, "away from the attacker")
		falls.append(spark.velocity.y)
	_advance(FRAME)
	for i: int in sparks.size():
		assert_gt(sparks[i].velocity.y, falls[i], "falling under gravity")
	var normal: int = sparks.size()

	_advance(1.0)
	assert_eq(_particles(&"spark").size(), 0, "sparks are gone in a moment")
	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 6, true)
	var crit_sparks: Array[FxParticle] = _particles(&"spark")
	assert_gte(crit_sparks.size(), 2 * normal, "a crit throws at least twice as many")
	assert_gte(crit_sparks.size(), 2 * CombatEffects.SPARKS_MAX, "whatever the hit threw")
	var white: int = 0
	for spark: FxParticle in crit_sparks:
		if spark.color == Palette.color(&"white"):
			white += 1
	assert_gt(white, 0, "and brighter: white among them")


func test_r4_crit_and_death_weight() -> void:
	var monster: int = _monster()
	var camera: WorldCamera = _world.camera
	var knight: CharacterSprite = _world.character(KNIGHT)

	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 6)
	assert_eq(camera._shake, 0.0, "a normal hit does not shake the camera")
	assert_eq(_world._frozen, 0.0, "nor freeze anything")

	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 6, true)
	var crit_shake: float = camera._shake
	assert_gt(crit_shake, 0.0, "a crit shakes the camera")
	assert_lte(crit_shake, 4.0, "lightly")
	var frozen_for: float = 0.0
	var tick: int = _sim.tick
	while true:
		var time_before: float = knight._time
		_sim.step()
		_world.sync(FRAME)
		if knight._time != time_before:
			break
		frozen_for += FRAME
		assert_lt(frozen_for, 1.0, "the freeze ends")
		if frozen_for >= 1.0:
			break
	assert_almost_eq(frozen_for, 0.06, 0.03, "animation stands still for about 0.06 s")
	assert_gt(_sim.tick, tick, "while the simulation goes on")

	camera._process(5.0)
	assert_eq(camera._shake, 0.0, "the shake has died away")
	_emit(SimEvent.Kind.DIED, ROGUE)
	assert_gt(camera._shake, crit_shake, "a hero's death shakes harder")


func test_r5_monster_burst() -> void:
	var monster: int = _monster()
	var palette: Dictionary[String, bool] = _sheet_colors(monster)
	_emit(SimEvent.Kind.DIED, monster)
	var bits: Array[FxParticle] = _particles(&"burst")
	assert_between(bits.size(), 10, 20, "10 to 20 particles")
	for bit: FxParticle in bits:
		assert_true(palette.has(bit.color.to_html(false)), "%s is in the sheet" % bit.color)
	var puffs: Array[FxParticle] = _particles(&"puff")
	assert_eq(puffs.size(), 1, "and a puff")
	var size: int = puffs[0].current_size()
	_advance(0.2)
	assert_lt(puffs[0].current_size(), size, "that shrinks away")
	_advance(0.2)
	assert_false(_fx._particles.has(puffs[0]), "and is gone")
	assert_gt(bits[0].velocity.y, -1000.0)
	var outward: int = 0
	for bit: FxParticle in bits:
		if bit.position.distance_to(_world.feet_position(monster)) > 10.0:
			outward += 1
	assert_gt(outward, bits.size() / 2, "thrown outward")


func test_r6_coins() -> void:
	assert_eq(CombatEffects.coin_count(1), 1)
	assert_eq(CombatEffects.coin_count(5), 1)
	assert_eq(CombatEffects.coin_count(23), 4)
	assert_eq(CombatEffects.coin_count(500), 12)

	var monster: int = _monster()
	var feet: Vector2 = _world.feet_position(monster)
	_emit(SimEvent.Kind.DIED, monster)
	_emit(SimEvent.Kind.GOLD_GAINED, monster, -1, 23)
	var coins: Array[FxCoin] = _fx._coins.duplicate()
	assert_eq(coins.size(), 4, "one coin per 5 gold")
	for coin: FxCoin in coins:
		assert_lt(coin.position.distance_to(feet), 20.0, "out of the dead monster")
	var waited: float = 0.0
	var all_landed: bool = false
	while waited < 3.0 and not all_landed:
		_advance(FRAME)
		waited += FRAME
		all_landed = true
		for coin: FxCoin in coins:
			all_landed = all_landed and coin.landed
			if coin.landed and coin.phase == FxCoin.Phase.REST:
				assert_almost_eq(coin.position.y, feet.y, 4.0, "resting on the floor")
	assert_true(all_landed, "every coin reaches the floor")
	assert_eq(_collected.size(), 0, "before any reaches the purse")
	_advance(5.0)
	assert_eq(_collected.size(), 4, "each coin arrives")
	var total: int = 0
	for share: int in _collected:
		total += share
	assert_eq(total, 23, "the shares add up to the gain")
	assert_eq(_fx._coins.size(), 0)

	_collected.clear()
	_emit(SimEvent.Kind.GOLD_GAINED, monster, -1, 500)
	assert_eq(_fx._coins.size(), 12, "at most 12 coins")
	_advance(6.0)
	total = 0
	for share: int in _collected:
		total += share
	assert_eq(_collected.size(), 12)
	assert_eq(total, 500, "the shares add up to the gain")


func test_r7_xp_motes() -> void:
	var monster: int = _monster()
	var from: Vector2 = _world.feet_position(monster)
	_emit(SimEvent.Kind.DIED, monster)
	_emit(SimEvent.Kind.XP_GAINED, -1, MAGE, 25)
	var motes: Array[FxMote] = _fx._motes.duplicate()
	assert_gte(motes.size(), 1, "motes rise from the monster")
	for mote: FxMote in motes:
		assert_eq(mote.hero_id, MAGE, "for the hero who gained it")
		assert_lt(mote.position.distance_to(from), 16.0, "starting at the monster")
	var hero: Vector2 = _world.feet_position(MAGE)
	var closest: float = INF
	var waited: float = 0.0
	while not _fx._motes.is_empty() and waited < 3.0:
		for mote: FxMote in _fx._motes:
			closest = minf(closest, mote.position.distance_to(hero))
		_advance(FRAME)
		waited += FRAME
	assert_eq(_fx._motes.size(), 0, "every mote arrives")
	assert_lt(closest, 24.0, "at the hero")
	var flashed: bool = false
	for flash: FxParticle in _particles(&"flash"):
		flashed = flashed or flash.position.distance_to(hero) < 24.0
	assert_true(flashed, "with a tiny flash")
	await wait_physics_frames(2)
	for mote: FxMote in motes:
		assert_false(is_instance_valid(mote), "freed on arrival")


func test_r8_level_up() -> void:
	var hero: Vector2 = _world.feet_position(ROGUE)
	_emit(SimEvent.Kind.LEVEL_UP, -1, ROGUE, 2)
	var bits: Array[FxParticle] = _particles(&"rise")
	assert_gt(bits.size(), 8, "a burst of particles")
	for bit: FxParticle in bits:
		assert_lt(bit.position.distance_to(hero), 24.0, "around the hero")
		assert_lt(bit.velocity.y, 0.0, "rising")
	var gold: bool = false
	for bit: FxParticle in bits:
		gold = gold or bit.color == Palette.color(&"yellow") or bit.color == Palette.color(&"amber")
	assert_true(gold, "gold")
	var words: FxText = null
	for text: FxText in _fx._texts:
		if text.text == "LEVEL UP":
			words = text
	assert_not_null(words, "LEVEL UP is shown")
	assert_almost_eq(words.position.x, hero.x, 4.0, "over the hero")
	assert_lt(words.position.y, hero.y - 20.0, "above them")
	_advance(1.1)
	assert_true(_fx._texts.has(words), "for about 1.2 seconds")
	_advance(0.15)
	assert_false(_fx._texts.has(words), "then it goes")


func test_r9_bolt_trail_and_flash() -> void:
	var from := Vector2(100, 100)
	var to := Vector2(200, 100)
	var bolt: Bolt = Bolt.launch(from, to, 0.5, 0.0, false, _monster())
	_world.effects_layer.add_child(bolt)
	_fx.advance(FRAME)
	bolt.advance(0.1)
	_fx.advance(FRAME)
	var trail: Array[FxParticle] = _particles(&"trail")
	assert_gt(trail.size(), 0, "a bolt in flight leaves a trail")
	for piece: FxParticle in trail:
		assert_eq(piece.color, bolt.color, "in its own colour")
		assert_between(piece.position.x, from.x, bolt.position.x, "behind it")
	var sizes: Array[int] = []
	for piece: FxParticle in trail:
		sizes.append(piece.current_size())
	_advance(0.08)
	var shrank: bool = false
	for i: int in trail.size():
		if not _fx._particles.has(trail[i]) or trail[i].current_size() < sizes[i]:
			shrank = true
	assert_true(shrank, "of shrinking squares")
	assert_eq(_particles(&"flash").size(), 0, "no flash in flight")
	bolt.advance(1.0)
	_fx.advance(FRAME)
	var flashes: Array[FxParticle] = _particles(&"flash")
	assert_gt(flashes.size(), 0, "a flash where it lands")
	for flash: FxParticle in flashes:
		assert_lt(flash.position.distance_to(to), 4.0, "at the landing point")
	var count: int = flashes.size()
	_fx.advance(FRAME)
	assert_lte(_particles(&"flash").size(), count, "only once")


func test_r10_loop_beats() -> void:
	_advance(2.0)
	assert_eq(_texts(&"z").size(), 0, "no z while not resting")
	_emit(SimEvent.Kind.REST_STARTED)
	_advance(1.5)
	assert_gt(_texts(&"z").size(), 0, "a z drifts up while resting")
	var z: FxText = _texts(&"z")[0]
	var z_y: float = z.position.y
	_advance(0.2)
	assert_lt(z.position.y, z_y, "drifting up")
	_emit(SimEvent.Kind.REST_ENDED)
	_advance(2.0)
	assert_eq(_texts(&"z").size(), 0, "until the rest ends")

	var middle: Vector2 = _fx._screen_to_world(_fx._view_size() * 0.5)
	_emit(SimEvent.Kind.PARTY_WIPED)
	var wiped: FxText = _find_text("WIPED")
	assert_not_null(wiped, "WIPED is shown")
	assert_almost_eq(wiped.position.x, middle.x, 2.0, "centred")
	assert_almost_eq(wiped.position.y, middle.y, 2.0, "centred")
	_advance(Expedition.REVIVE_SECONDS - 0.1)
	assert_true(_fx._texts.has(wiped), "for the revive delay")
	_advance(0.2)
	assert_false(_fx._texts.has(wiped), "and then no longer")

	_emit(SimEvent.Kind.PARTY_REVIVED, -1, -1, 1)
	_advance(FRAME)
	var lights: Array[FxParticle] = _particles(&"light")
	assert_gte(lights.size(), _sim.party.heroes.size(), "a column of light on each hero")
	for hero: Hero in _sim.party.heroes:
		var lit: bool = false
		for light: FxParticle in lights:
			lit = lit or light.position.distance_to(_world.feet_position(hero.id)) < 2.0
		assert_true(lit, "on hero %d" % hero.id)
	_advance(1.0)
	assert_eq(_particles(&"light").size(), 0, "brief")

	_emit(SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 3)
	var stable: FxText = _find_text("MOSSY HOLLOW 3 STABLE")  # spec 049 names the area
	assert_not_null(stable, "MOSSY HOLLOW 3 STABLE is shown")
	assert_almost_eq(stable.position.x, middle.x, 2.0, "centred")
	_advance(1.9)
	assert_true(_fx._texts.has(stable), "for 2 seconds")
	_advance(0.2)
	assert_false(_fx._texts.has(stable))


func _find_text(words: String) -> FxText:
	for text: FxText in _fx._texts:
		if text.text == words:
			return text
	return null


func test_r11_nothing_piles_up() -> void:
	var monster: int = _monster()
	for i: int in 500:
		if i % 2 == 0:
			_emit(SimEvent.Kind.HIT, KNIGHT, monster, 5 + i % 7, i % 5 == 0)
		else:
			_emit(SimEvent.Kind.HIT, monster, 1 + i % 4, 3, i % 7 == 0)
	_fx.advance(FRAME)
	assert_lte(_fx.live_numbers(), CombatEffects.MAX_NUMBERS, "at most 40 numbers")
	assert_lte(_fx.live_particles(), CombatEffects.MAX_PARTICLES, "at most 300 particles")
	assert_gt(_fx.live_numbers(), 0)

	_advance(2.0)
	var numbers: int = _fx.live_numbers()
	var particles: int = _fx.live_particles()
	var old_tick: int = _sim.tick - World.ANIMATE_TICKS - 1
	var old_hit := SimEvent.new(SimEvent.Kind.HIT, old_tick, KNIGHT, monster, 9, true)
	_world.sim_event.emit(old_hit)
	var old_gold := SimEvent.new(SimEvent.Kind.GOLD_GAINED, old_tick, monster, -1, 37)
	_world.sim_event.emit(old_gold)
	var old_death := SimEvent.new(SimEvent.Kind.DIED, old_tick, monster)
	_world.sim_event.emit(old_death)
	assert_eq(_fx.live_numbers(), numbers, "an old hit starts no number")
	assert_eq(_fx.live_particles(), particles, "nor sparks, nor a burst")
	assert_eq(_fx._coins.size(), 0, "old gold throws no coins")
	assert_eq(_collected, [37] as Array[int], "but is credited at once")

	_advance(5.0)
	await wait_physics_frames(2)
	assert_eq(_world.effects_layer.get_child_count(), 0, "after 5 quiet seconds, nothing is left")


func test_r12_advance_drives_everything() -> void:
	var monster: int = _monster()
	_emit(SimEvent.Kind.HIT, KNIGHT, monster, 8, true)
	_emit(SimEvent.Kind.DIED, monster)
	_emit(SimEvent.Kind.GOLD_GAINED, monster, -1, 10)
	var number: FxText = _texts(&"damage")[0]
	var spark: FxParticle = _particles(&"spark")[0]
	var coin: FxCoin = _fx._coins[0]
	var where: Array[Vector2] = [number.position, spark.position, coin.position]
	await wait_physics_frames(10)
	assert_eq(number.position, where[0], "a number does not move by itself")
	assert_eq(spark.position, where[1], "nor a spark")
	assert_eq(coin.position, where[2], "nor a coin")
	_fx.advance(0.1)
	assert_ne(number.position, where[0], "advance moves the number")
	assert_ne(spark.position, where[1], "and the spark")
	assert_ne(coin.position, where[2], "and the coin")

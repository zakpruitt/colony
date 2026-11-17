extends GutTest
## Acceptance tests for specs/008-world-integration/spec.md, one per requirement.
##
## Each test builds a World (or Main) on a seeded simulation, steps the simulation directly and
## calls sync, as the game's driver and frame loop would: one tick every six frames at 60 frames
## a second. Where a test needs to see what a sprite was asked to do it reads the sprite's own
## animation state (_walking, _facing, _attack_time, ...): CharacterSprite has no getters for it.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const FRAMES_PER_TICK: int = 6
const TILE: float = 16.0
const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4
const HERO_IDS: Array[int] = [KNIGHT, ROGUE, MAGE, CLERIC]
## Ticks in three minutes: the longest any test waits for something to happen.
const LIMIT_TICKS: int = 1800


## A simulation whose drain_events also hands out events a test injects, and remembers
## everything it has handed out.
class Spy:
	extends Simulation

	var injected: Array[SimEvent] = []
	var handed_out: Array[SimEvent] = []

	func _init(seed_value: int) -> void:
		super(seed_value)

	func drain_events() -> Array[SimEvent]:
		var events: Array[SimEvent] = super()
		events.append_array(injected)
		injected = []
		handed_out.append_array(events)
		return events


# --- Helpers -------------------------------------------------------------------

var _emitted: Array[SimEvent] = []


func before_each() -> void:
	_emitted = []


func _world(sim: Simulation) -> World:
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.sim_event.connect(func(event: SimEvent) -> void: _emitted.append(event))
	return world


## The feet pixel of a hero's simulation position.
func _feet(sim: Simulation, hero_id: int) -> Vector2:
	var tiles: Vector2 = sim.expedition.hero_position(hero_id)
	return Vector2(tiles.x * TILE, (tiles.y + 1.0) * TILE)


## One rendered frame: a tick every FRAMES_PER_TICK frames, then sync. Returns the frame count.
func _frame(sim: Simulation, world: World, frame: int) -> int:
	if frame % FRAMES_PER_TICK == 0:
		sim.step()
	world.sync(FRAME)
	return frame + 1


## Plays frames until [param done] returns true, at most LIMIT_TICKS ticks. False if it never did.
func _play_until(sim: Simulation, world: World, done: Callable) -> bool:
	var frame: int = 0
	while frame < LIMIT_TICKS * FRAMES_PER_TICK:
		frame = _frame(sim, world, frame)
		if done.call():
			return true
	return false


func _state(sim: Simulation) -> Expedition.State:
	return sim.expedition.state


func _emitted_since(start: int, kind: SimEvent.Kind) -> bool:
	for i: int in range(start, _emitted.size()):
		if _emitted[i].kind == kind:
			return true
	return false


## Puts the party a few tiles inside the START chamber on the side away from the shaft, so it
## has the whole chamber and a tunnel to walk before anything can happen.
func _start_far_from_shaft(sim: Simulation) -> void:
	var level: LabyrinthLevel = sim.labyrinth.level(1)
	var start: LabyrinthChamber = sim.expedition.chamber()
	if sim.expedition.facing > 0:
		sim.expedition.x = start.rect.position.x + 3.0
	else:
		sim.expedition.x = start.rect.end.x - 4.0
	assert_eq(level.chamber_at(floori(sim.expedition.x)), start, "still in the START chamber")


## Every hero dies where it stands (outside a fight): the next tick wipes the party.
func _force_wipe(sim: Simulation) -> void:
	for hero: Hero in sim.party.heroes:
		hero.health = 0


## Some monster waiting in a built level, or null.
func _waiting_monster(sim: Simulation, world: World, skip: int = -1) -> Combatant:
	for depth: int in world.labyrinth_view.built_depths():
		var level: LabyrinthLevel = sim.labyrinth.level(depth)
		for chamber_index: int in level.chambers.size():
			for monster: Combatant in sim.expedition.monsters_in(depth, chamber_index):
				if monster.id != skip:
					return monster
	return null


func _bolts(world: World) -> Array[Bolt]:
	var bolts: Array[Bolt] = []
	for child: Node in world.effects_layer.get_children():
		if child is Bolt:
			bolts.append(child as Bolt)
	return bolts


func _event(
	kind: SimEvent.Kind,
	tick: int,
	source: int,
	target: int = -1,
	amount: int = 0,
	flag: bool = false
) -> SimEvent:
	return SimEvent.new(kind, tick, source, target, amount, flag)


# --- R1 ------------------------------------------------------------------------


func test_r1_main_scene_shows_the_world() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_not_null(main.world, "the main scene has a world")
	assert_not_null(main.hud_layer, "the main scene has a HUD layer")
	if main.world == null or main.hud_layer == null:
		return
	var world: World = main.world
	assert_eq(world.simulation, main.simulation, "the world shows the running simulation")
	var depth: int = main.simulation.expedition.depth
	assert_has(world.labyrinth_view.built_depths(), depth, "the party's level is built")
	assert_has(world.labyrinth_view.built_depths(), depth + 1, "and the one below")
	var party: Vector2 = _feet(main.simulation, KNIGHT)
	assert_lt(world.camera.target.distance_to(party), 6.0 * TILE, "the camera is on the party")
	assert_true(world.camera.is_current() or not world.camera.is_inside_tree(), "camera in use")
	var label: Label = main.hud_layer.get_node_or_null("ClockLabel")
	assert_not_null(label, "the clock label is on the HUD layer")
	if label != null:
		assert_string_contains(label.text, "Tick")


# --- R2 ------------------------------------------------------------------------


func test_r2_hero_sprites_follow_smoothly() -> void:
	var sim := Simulation.new(SEED)
	_start_far_from_shaft(sim)
	var world: World = _world(sim)
	var sprites: Array[CharacterSprite] = []
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = world.character(id)
		assert_not_null(sprite, "hero %d has a sprite" % id)
		if sprite == null:
			return
		assert_false(sprites.has(sprite), "one sprite per hero")
		sprites.append(sprite)
		assert_eq(sprite.position, _feet(sim, id), "hero %d starts at its position" % id)

	# Warm up half a second, then watch three seconds of travel.
	var frame: int = 0
	for i: int in 30:
		frame = _frame(sim, world, frame)
	var last: Array[Vector2] = []
	for sprite: CharacterSprite in sprites:
		last.append(sprite.position)
	var still: int = 0
	var far: int = 0
	for i: int in 180:
		frame = _frame(sim, world, frame)
		assert_eq(_state(sim), Expedition.State.TRAVELLING, "the party is still travelling")
		for h: int in sprites.size():
			if sprites[h].position == last[h]:
				still += 1
			if sprites[h].position.distance_to(_feet(sim, HERO_IDS[h])) > TILE:
				far += 1
			last[h] = sprites[h].position
	assert_eq(still, 0, "every hero sprite moves on every frame of travel")
	assert_eq(far, 0, "no hero sprite is ever more than a tile from its position")

	# Through a fight starting and ending, and a climb down: no jumps.
	sim.set_target_depth(2)
	var seen: Dictionary[Expedition.State, bool] = {}
	var ended: bool = false
	var biggest: float = 0.0
	var start: int = _emitted.size()
	while frame < LIMIT_TICKS * FRAMES_PER_TICK and not (ended and sim.expedition.depth == 2):
		for h: int in sprites.size():
			last[h] = sprites[h].position
		var before: int = _emitted.size()
		frame = _frame(sim, world, frame)
		seen[_state(sim)] = true
		ended = ended or _emitted_since(before, SimEvent.Kind.ENCOUNTER_ENDED)
		if _emitted_since(before, SimEvent.Kind.PARTY_REVIVED):
			continue
		for h: int in sprites.size():
			biggest = maxf(biggest, sprites[h].position.distance_to(last[h]))
	assert_true(_emitted_since(start, SimEvent.Kind.ENCOUNTER_STARTED), "a fight started")
	assert_true(ended, "and ended")
	assert_true(seen.has(Expedition.State.CLIMBING), "the party climbed")
	assert_eq(sim.expedition.depth, 2, "down to depth 2")
	assert_lte(biggest, TILE / 2.0, "no sprite moved more than half a tile in one frame")

	# A revival snaps. (Spec 038: each hero appears there still lying on its back, its feet raised
	# by as much as its back reaches below them, and rises.)
	_force_wipe(sim)
	var revived: bool = _play_until(
		sim, world, func() -> bool: return _emitted_since(start, SimEvent.Kind.PARTY_REVIVED)
	)
	assert_true(revived, "the party was revived")
	for id: int in HERO_IDS:
		var at: Vector2 = world.character(id).position
		assert_eq(at.x, _feet(sim, id).x, "hero %d snapped" % id)
		assert_between(at.y, _feet(sim, id).y - TILE, _feet(sim, id).y, "lying on that floor")


# --- R3 ------------------------------------------------------------------------


func test_r3_heroes_act_out_the_state() -> void:
	var sim := Simulation.new(SEED)
	var world: World = _world(sim)
	var originals: Array[CharacterSprite] = []
	for id: int in HERO_IDS:
		originals.append(world.character(id))

	# Travelling: walking, facing the party's way.
	var frame: int = 0
	for i: int in 60:
		frame = _frame(sim, world, frame)
	assert_eq(_state(sim), Expedition.State.TRAVELLING)
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = world.character(id)
		assert_true(sprite._walking, "hero %d walks while travelling" % id)
		assert_eq(sprite._facing, sim.expedition.facing, "hero %d faces the party's way" % id)

	# Fighting: idle between attacks, facing the target.
	assert_true(
		_play_until(sim, world, func() -> bool: return _state(sim) == Expedition.State.FIGHTING),
		"a fight"
	)
	for i: int in 90:
		frame = _frame(sim, world, frame)
	var checked: int = 0
	for id: int in HERO_IDS:
		var battle: Battle = sim.expedition.battle
		if battle == null:
			break
		var fighter: Combatant = battle.combatant(id)
		var sprite: CharacterSprite = world.character(id)
		var target: CharacterSprite = world.character(fighter.target_id)
		if not fighter.is_alive() or fighter.state == Combatant.State.MOVING or target == null:
			continue
		if sprite.position.distance_to(_feet(sim, id)) > 1.0:
			continue
		checked += 1
		assert_false(sprite._walking, "hero %d stands between attacks" % id)
		var toward: int = 1 if target.position.x >= sprite.position.x else -1
		assert_eq(sprite._facing, toward, "hero %d faces its target" % id)
	assert_gt(checked, 0, "at least one hero was standing in the fight")

	# Resting: idle. Hurt heroes rest after their next fight.
	var walking: bool = _play_until(
		sim, world, func() -> bool: return _state(sim) == Expedition.State.TRAVELLING
	)
	assert_true(walking, "the fight ended")
	for hero: Hero in sim.party.heroes:
		hero.health = roundi(hero.max_health() * 0.4)
	var rested: bool = _play_until(
		sim, world, func() -> bool: return _state(sim) == Expedition.State.RESTING
	)
	assert_true(rested, "the party rested")
	for i: int in 120:
		frame = _frame(sim, world, frame)
	if _state(sim) == Expedition.State.RESTING:
		for id: int in HERO_IDS:
			assert_false(world.character(id)._walking, "hero %d is idle while resting" % id)
	else:
		fail_test("the rest ended within two seconds; cannot see it")

	# Climbing: walking on the shaft.
	sim.set_target_depth(sim.expedition.depth + 1)
	var climbing: bool = _play_until(
		sim, world, func() -> bool: return _state(sim) == Expedition.State.CLIMBING
	)
	assert_true(climbing, "the party climbed")
	for i: int in 12:
		frame = _frame(sim, world, frame)
	for id: int in HERO_IDS:
		assert_true(world.character(id)._walking, "hero %d walks on the shaft" % id)

	# Wiped: down until the revival, then back, the same sprites. (Spec 038: the fallen lie where
	# they fell, shown, and rise after the revival.)
	assert_true(
		_play_until(sim, world, func() -> bool: return _state(sim) == Expedition.State.TRAVELLING),
		"travelling"
	)
	_force_wipe(sim)
	for i: int in 60:
		frame = _frame(sim, world, frame)
	assert_eq(_state(sim), Expedition.State.REVIVING)
	for id: int in HERO_IDS:
		var fallen: CharacterSprite = world.character(id)
		assert_true(fallen.is_dead(), "hero %d is down after the wipe" % id)
		assert_true(world.fallen_party.is_lying(id), "hero %d lies where it fell" % id)
	var start: int = _emitted.size()
	var revived: bool = _play_until(
		sim, world, func() -> bool: return _emitted_since(start, SimEvent.Kind.PARTY_REVIVED)
	)
	assert_true(revived, "the party was revived")
	var risen: bool = _play_until(
		sim, world, func() -> bool: return not world.fallen_party.is_standing(KNIGHT)
	)
	assert_true(risen, "the party has risen")
	for h: int in HERO_IDS.size():
		var sprite: CharacterSprite = world.character(HERO_IDS[h])
		assert_eq(sprite, originals[h], "hero %d keeps its sprite" % HERO_IDS[h])
		assert_true(sprite.visible and not sprite.is_dead(), "hero %d is back" % HERO_IDS[h])
		assert_lt(sprite._attack_time, 0.0, "hero %d is not attacking" % HERO_IDS[h])


# --- R4 ------------------------------------------------------------------------


func test_r4_waiting_monsters_are_shown() -> void:
	var sim := Simulation.new(SEED)
	var world: World = _world(sim)
	var built: Array[int] = world.labyrinth_view.built_depths()
	var party_x: float = sim.expedition.x
	var shown: Array[int] = []
	for depth: int in built:
		var level: LabyrinthLevel = sim.labyrinth.level(depth)
		for chamber_index: int in level.chambers.size():
			if not sim.expedition.is_populated(depth, chamber_index):
				continue
			for monster: Combatant in sim.expedition.monsters_in(depth, chamber_index):
				var sprite: CharacterSprite = world.character(monster.id)
				assert_not_null(sprite, "monster %d has a sprite" % monster.id)
				if sprite == null:
					continue
				shown.append(monster.id)
				var feet := Vector2(monster.x * TILE, (level.floor_y + 1) * TILE)
				assert_eq(sprite.position, feet, "monster %d stands where it waits" % monster.id)
				assert_eq(world.feet_position(monster.id), feet)
				assert_false(sprite._walking, "monster %d is idle" % monster.id)
				var toward: int = 1 if party_x >= monster.x else -1
				assert_eq(sprite._facing, toward, "monster %d faces the party" % monster.id)
	assert_gt(shown.size(), 3, "monsters wait in the built levels")

	# A level that is not built shows none.
	var unbuilt: int = built.max() + 2
	var level_below: LabyrinthLevel = sim.labyrinth.level(unbuilt)
	var hidden: int = 0
	for chamber_index: int in level_below.chambers.size():
		for monster: Combatant in sim.expedition.monsters_in(unbuilt, chamber_index):
			hidden += 1
			assert_null(world.character(monster.id), "no sprite on an unbuilt level")
	world.sync(FRAME)
	for chamber_index: int in level_below.chambers.size():
		for monster: Combatant in sim.expedition.monsters_in(unbuilt, chamber_index):
			assert_null(world.character(monster.id), "still none after a sync")
	assert_gt(hidden, 0, "the unbuilt level has monsters to not show")

	# Freed with their level.
	sim.expedition.depth = 8
	world.sync(FRAME)
	assert_does_not_have(world.labyrinth_view.built_depths(), 1, "depth 1 was freed")
	for id: int in shown:
		assert_null(world.character(id), "monster %d went with its level" % id)


func test_r4_refilled_chamber_shows_its_monsters() -> void:
	var sim := Simulation.new(SEED)
	var world: World = _world(sim)
	var won: Array[SimEvent] = []
	var cleared: bool = _play_until(
		sim,
		world,
		func() -> bool:
			for event: SimEvent in _emitted:
				if event.kind == SimEvent.Kind.ENCOUNTER_ENDED and event.flag:
					won.append(event)
					return true
			return false
	)
	assert_true(cleared, "a chamber was cleared")
	if not cleared:
		return
	var depth: int = sim.expedition.depth
	var chamber_index: int = won[0].amount
	assert_false(sim.expedition.is_populated(depth, chamber_index), "empty once cleared")

	# Up to the refill one tick a frame (no stall), then less than a second of frames.
	var limit: int = Combatant.seconds_to_ticks(Expedition.RESPAWN_SECONDS) + 10
	for i: int in limit:
		if sim.expedition.is_populated(depth, chamber_index):
			break
		sim.step()
		world.sync(0.1)
	assert_true(sim.expedition.is_populated(depth, chamber_index), "the chamber refilled")
	for i: int in 45:
		world.sync(FRAME)
	var refilled: Array[Combatant] = sim.expedition.monsters_in(depth, chamber_index)
	assert_gt(refilled.size(), 0)
	for monster: Combatant in refilled:
		assert_not_null(world.character(monster.id), "refilled monster %d is shown" % monster.id)


# --- R5 ------------------------------------------------------------------------


func test_r5_strike_due_as_its_target_dies_is_cut_short() -> void:
	var sim := Spy.new(SEED)
	var world: World = _world(sim)
	var target: Combatant = _waiting_monster(sim, world)
	var t: int = sim.tick
	var knight: CharacterSprite = world.character(KNIGHT)
	var strikes: Array[int] = [0]
	knight.struck.connect(func() -> void: strikes[0] += 1)
	sim.injected = [_event(SimEvent.Kind.ATTACK_STARTED, t, KNIGHT, target.id, 3)]
	world.sync(0.0)
	world.sync(0.25)
	assert_eq(strikes[0], 0, "still winding up")
	# The target dies from another hand on the very tick the knight's strike was due.
	sim.injected = [
		_event(SimEvent.Kind.HIT, t + 3, MAGE, target.id, 50),
		_event(SimEvent.Kind.DIED, t + 3, target.id),
	]
	world.sync(FRAME)
	for i: int in 60:
		world.sync(FRAME)
	assert_eq(strikes[0], 0, "no strike at a corpse")
	assert_lt(knight._attack_time, 0.0, "the wind-up was cut short")


func test_r7_is_recent() -> void:
	var sim := Simulation.new(SEED)
	var world: World = _world(sim)
	for i: int in 20:
		sim.step()
	assert_true(world.is_recent(_event(SimEvent.Kind.HIT, sim.tick, 1)), "this tick")
	var edge: SimEvent = _event(SimEvent.Kind.HIT, sim.tick - World.ANIMATE_TICKS, 1)
	assert_true(world.is_recent(edge), "half a second ago")
	var old: SimEvent = _event(SimEvent.Kind.HIT, sim.tick - World.ANIMATE_TICKS - 1, 1)
	assert_false(world.is_recent(old), "older than half a second")


func test_r5_events_drive_fight_animation() -> void:
	var sim := Spy.new(SEED)
	var world: World = _world(sim)
	var first: Combatant = _waiting_monster(sim, world)
	var second: Combatant = _waiting_monster(sim, world, first.id)
	var t: int = sim.tick
	var knight: CharacterSprite = world.character(KNIGHT)
	var mage: CharacterSprite = world.character(MAGE)
	var rogue: CharacterSprite = world.character(ROGUE)
	var monster: CharacterSprite = world.character(first.id)

	sim.injected = [
		_event(SimEvent.Kind.ATTACK_STARTED, t, KNIGHT, first.id, 7),
		_event(SimEvent.Kind.ATTACK_STARTED, t, MAGE, first.id, 9),
	]
	world.sync(0.0)
	assert_gte(knight._attack_time, 0.0, "the knight attacks")
	assert_almost_eq(knight._windup, 0.7, 0.001, "with the event's wind-up")
	assert_false(knight._ranged, "in melee")
	assert_gte(mage._attack_time, 0.0, "the mage attacks")
	assert_almost_eq(mage._windup, 0.9, 0.001, "with the event's wind-up")
	assert_true(mage._ranged, "at range")

	sim.injected = [_event(SimEvent.Kind.HIT, t, KNIGHT, first.id, 5)]
	world.sync(0.0)
	assert_gte(monster._hit_time, 0.0, "the target flinches")

	# The target dies during wind-ups aimed at it: they are cut short.
	sim.injected = [
		_event(SimEvent.Kind.ATTACK_STARTED, t, ROGUE, first.id, 10),
		_event(SimEvent.Kind.DIED, t, first.id),
	]
	world.sync(0.0)
	assert_true(monster.is_dead(), "the target plays its death")
	assert_lt(rogue._attack_time, 0.0, "the rogue's wind-up is cut short")
	assert_gte(rogue._cancel_time, 0.0, "and eases back")
	for i: int in 30:
		world.sync(FRAME)
	assert_null(world.character(first.id), "the dead monster's sprite is gone")
	assert_false(is_instance_valid(monster), "and freed")

	# The encounter ends with an attack winding up and a bolt in flight.
	sim.injected = [
		_event(SimEvent.Kind.ATTACK_STARTED, t, ROGUE, second.id, 10),
		_event(SimEvent.Kind.PROJECTILE_LAUNCHED, t, MAGE, second.id, 6),
	]
	world.sync(0.0)
	assert_gte(rogue._attack_time, 0.0, "the rogue winds up again")
	assert_eq(_bolts(world).size(), 1, "a bolt flies")
	sim.injected = [_event(SimEvent.Kind.ENCOUNTER_ENDED, t, -1, -1, 0, true)]
	world.sync(0.0)
	assert_lt(rogue._attack_time, 0.0, "the wind-up is cut short when the encounter ends")
	assert_eq(_bolts(world).size(), 0, "and the bolt is removed")


# --- R6 ------------------------------------------------------------------------


func test_r6_projectiles_fly_and_arrive() -> void:
	var sim := Spy.new(SEED)
	var world: World = _world(sim)
	var target: Combatant = _waiting_monster(sim, world)
	var t: int = sim.tick
	sim.injected = [_event(SimEvent.Kind.PROJECTILE_LAUNCHED, t, MAGE, target.id, 4)]
	world.sync(0.0)
	var bolts: Array[Bolt] = _bolts(world)
	assert_eq(bolts.size(), 1, "the launch made a bolt")
	if bolts.is_empty():
		return
	var bolt: Bolt = bolts[0]
	var aim := Vector2(0, -World.AIM_HEIGHT)
	var goal: Vector2 = world.feet_position(target.id) + aim
	assert_almost_eq(bolt.position, world.feet_position(MAGE) + aim, Vector2.ONE, "from the mage")
	world.sync(0.2)
	assert_gt(bolt.position.distance_to(goal), 4.0, "half way, it has not arrived")
	world.sync(0.2)
	assert_almost_eq(bolt.position, goal, Vector2.ONE, "it reaches the target at the flight time")
	var attack_color: Color = bolt.color
	world.sync(FRAME)
	assert_false(is_instance_valid(bolt), "then it is freed")
	assert_eq(_bolts(world).size(), 0)

	sim.injected = [_event(SimEvent.Kind.PROJECTILE_LAUNCHED, t, CLERIC, KNIGHT, 3, true)]
	world.sync(0.0)
	bolts = _bolts(world)
	assert_eq(bolts.size(), 1, "a heal makes a bolt too")
	if not bolts.is_empty():
		assert_ne(bolts[0].color, attack_color, "in another colour")


# --- R7 ------------------------------------------------------------------------


func test_r7_events_emitted_once_in_order() -> void:
	var sim := Spy.new(SEED)
	var world: World = _world(sim)
	var fought: bool = _play_until(
		sim, world, func() -> bool: return _emitted_since(0, SimEvent.Kind.ENCOUNTER_ENDED)
	)
	assert_true(fought, "a fight was fought")
	assert_true(_emitted_since(0, SimEvent.Kind.HIT), "with hits")
	assert_true(_emitted_since(0, SimEvent.Kind.DIED), "and deaths")
	assert_eq(_emitted.size(), sim.handed_out.size(), "every event was emitted once")
	var same: bool = _emitted.size() == sim.handed_out.size()
	for i: int in mini(_emitted.size(), sim.handed_out.size()):
		same = same and _emitted[i] == sim.handed_out[i]
		if i > 0:
			assert_gte(_emitted[i].tick, _emitted[i - 1].tick, "in tick order")
	assert_true(same, "in the order the simulation reported them")
	var count: int = _emitted.size()
	world.sync(FRAME)
	assert_eq(_emitted.size(), count, "a frame without ticks emits nothing")

	for id: int in HERO_IDS:
		assert_not_null(world.character(id), "hero %d answers" % id)
		assert_eq(world.feet_position(id), world.character(id).position)
	var waiting: Combatant = _waiting_monster(sim, world)
	world.sync(FRAME)
	assert_not_null(world.character(waiting.id), "a waiting monster answers")
	assert_eq(world.feet_position(waiting.id), world.character(waiting.id).position)
	assert_null(world.character(99_999), "an unknown id has no sprite")
	assert_eq(world.feet_position(99_999), Vector2.ZERO)


# --- R8 ------------------------------------------------------------------------


func test_r8_stall_leaves_a_true_picture() -> void:
	var sim := Spy.new(SEED)
	var world: World = _world(sim)
	var fighting: bool = _play_until(
		sim, world, func() -> bool: return _state(sim) == Expedition.State.FIGHTING
	)
	assert_true(fighting, "a fight started")
	var start: int = sim.handed_out.size()
	for i: int in 20 * Simulation.TICKS_PER_SECOND:
		sim.step()
	world.sync(FRAME)

	var now: int = sim.tick
	var recent: Dictionary[int, bool] = {}
	var dead_monsters: int = 0
	var old_attacks: int = 0
	for i: int in range(start, sim.handed_out.size()):
		var event: SimEvent = sim.handed_out[i]
		if event.kind == SimEvent.Kind.DIED and event.source_id >= Expedition.FIRST_MONSTER_ID:
			dead_monsters += 1
			assert_null(world.character(event.source_id), "no sprite for dead %d" % event.source_id)
		if event.kind == SimEvent.Kind.ATTACK_STARTED:
			if now - event.tick <= World.ANIMATE_TICKS:
				recent[event.source_id] = true
			else:
				old_attacks += 1
	assert_gt(dead_monsters, 0, "monsters died during the stall")
	assert_gt(old_attacks, 0, "attacks started long ago during the stall")
	for id: int in HERO_IDS:
		var sprite: CharacterSprite = world.character(id)
		assert_lte(sprite.position.distance_to(_feet(sim, id)), TILE, "hero %d is in place" % id)
		if not recent.has(id):
			assert_lt(sprite._attack_time, 0.0, "hero %d plays no old attack" % id)


# --- R9 ------------------------------------------------------------------------


func test_r9_camera_and_focus_follow_the_party() -> void:
	var sim := Simulation.new(SEED)
	var world: World = _world(sim)
	var frame: int = 0
	for i: int in 30:
		frame = _frame(sim, world, frame)
	var lead: float = world.camera.target.x - world.feet_position(KNIGHT).x
	assert_eq(signi(roundi(lead)), sim.expedition.facing, "the camera looks ahead")
	assert_lt(absf(lead), 8.0 * TILE, "but not far")

	# Down a shaft, smoothly.
	sim.set_target_depth(2)
	var biggest: float = 0.0
	var climbed: bool = false
	while frame < LIMIT_TICKS * FRAMES_PER_TICK:
		var before: Vector2 = world.camera.position
		frame = _frame(sim, world, frame)
		if _state(sim) == Expedition.State.CLIMBING:
			climbed = true
			biggest = maxf(biggest, world.camera.position.distance_to(before))
		if climbed and _state(sim) != Expedition.State.CLIMBING:
			break
	assert_true(climbed, "the party climbed down")
	assert_eq(sim.expedition.depth, 2)
	assert_lte(biggest, 6.0, "the camera glides down the shaft")
	assert_eq(world.labyrinth_view.built_depths(), [1, 2, 3] as Array[int], "focus on depth 2")

	# Revival snaps.
	_force_wipe(sim)
	var start: int = _emitted.size()
	var revived: bool = _play_until(
		sim, world, func() -> bool: return _emitted_since(start, SimEvent.Kind.PARTY_REVIVED)
	)
	assert_true(revived, "the party was revived")
	var half: float = world.get_viewport_rect().size.x * 0.5
	var band: float = Labyrinth.LEVEL_WIDTH * TILE
	var target: Vector2 = world.camera.target
	var expected := Vector2(clampf(target.x, ceilf(half), floorf(band - half)), target.y).round()
	assert_eq(world.camera.position, expected, "the camera snapped to the party")


# --- R10 -----------------------------------------------------------------------


func test_r10_layers_exist() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var world: World = main.world
	assert_not_null(world, "the main scene has a world")
	if world == null:
		return
	assert_true(world.effects_layer is Node2D, "an effects layer")
	assert_eq(world.effects_layer.get_parent(), world, "in the world")
	assert_eq(world.labyrinth_view.get_index(), 0, "the labyrinth is drawn first")
	var characters: Node = world.character(KNIGHT).get_parent()
	assert_true(characters is Node2D, "heroes are in a characters node")
	assert_eq(characters.get_parent(), world, "in the world")
	assert_gt(
		characters.get_index(), world.labyrinth_view.get_index(), "characters over the labyrinth"
	)
	assert_gt(
		world.effects_layer.get_index(), characters.get_index(), "effects after the characters"
	)
	# Ambience (spec 012) sits between the view and the characters, so props draw behind heroes.
	assert_gt(
		world.ambience.get_index(), world.labyrinth_view.get_index(), "ambience over the view"
	)
	assert_lt(world.ambience.get_index(), characters.get_index(), "ambience under the characters")
	assert_eq(world.camera.get_parent(), world, "the camera is the world's")
	assert_eq(world.position, Vector2.ZERO, "the world stays at the origin")
	assert_true(main.hud_layer is CanvasLayer, "a HUD layer")
	assert_gt(main.hud_layer.layer, 0, "above the world")

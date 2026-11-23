extends "res://tests/support/play_fixture.gd"
## Spec 102: the party sets up a camp where it rests and sits round its fire; a hero who fell in a
## won fight lies there and gets up at the camp; every revival shows the same light and sparks.

const KNIGHT: int = 1
## The hero that falls in the fights of R6 and R7.
const FALLEN: int = 4
const FRAME: float = 1.0 / 60.0
const SHOWCASE: String = "res://game/dev/showcase.tscn"

## What a test found wrong, a line each: asserted empty at its end.
var _wrong: PackedStringArray = []


func before_each() -> void:
	_wrong = []


func _mark_wrong(problem: String) -> void:
	if _wrong.size() < 6:
		_wrong.append(problem)


func _assert_nothing_wrong(what: String) -> void:
	assert_eq(_wrong.size(), 0, "%s:\n%s" % [what, "\n".join(_wrong)])
	_wrong = []


## Plays [param seconds] of frames, the simulation stepping unless not [param stepping].
func _play(seconds: float, stepping: bool = true) -> void:
	for i: int in roundi(seconds / FRAME):
		_play_frame(stepping)


## The party, hurt, starts to rest where it stands.
func _begin_rest() -> void:
	for hero: Hero in _sim.party.heroes:
		hero.health = maxi(1, hero.max_health() / 2)
	_sim.expedition._start_rest()
	# A step hands its REST_STARTED on, as the step a rest begins in does: the next frame tells it.
	_sim.step()


## Every hero is whole: the rest ends on the next tick.
func _end_rest() -> void:
	for hero: Hero in _sim.party.heroes:
		hero.health = hero.max_health()
	assert_true(_play_until(SimEvent.Kind.REST_ENDED, 20), "the rest ends")


func _camp() -> CampView:
	return _world.camp


func _faces(sprite: CharacterSprite) -> int:
	return -1 if (sprite.get_node("Mirror") as Node2D).scale.x < 0.0 else 1


## The rectangle a camp sprite covers, in world pixels.
func _rect_of(part: String) -> Rect2:
	var sprite: Sprite2D = _camp().get_node(part)
	var local: Rect2 = sprite.get_rect()
	return Rect2(sprite.global_position + local.position, local.size)


## Every hero's sprite has sat all the way down.
func _all_sat() -> bool:
	for hero: Hero in _sim.party.heroes:
		if _world.character(hero.id).shown_sit() < 1.0:
			return false
	return true


## How far above its feet a standing [param class_id] hero's head part is, in pixels.
func _standing_head(class_id: StringName) -> float:
	var fresh: CharacterSprite = CharacterSprite.for_hero(class_id)
	var head: float = (fresh.get_node("Mirror/Rig/head") as Node2D).position.y
	fresh.free()
	return head


## The revival's columns of light and its rising sparks at [param feet].
func _revival_at(feet: Vector2) -> Vector2i:
	var lights: int = 0
	var sparks: int = 0
	for node: Node2D in _world.fx.nodes(&"combat"):
		var bit: FxParticle = node as FxParticle
		if bit == null:
			continue
		if bit.kind == &"light" and bit.position.distance_to(feet) < 2.0:
			lights += 1
		elif bit.kind == &"revival_spark" and absf(bit.position.x - feet.x) < 7.0:
			if bit.position.y <= feet.y + 1.0 and bit.position.y > feet.y - 24.0:
				if bit.velocity.y < 0.0:
					sparks += 1
	return Vector2i(lights, sparks)


## Plays to the next fight, kills hero FALLEN in it and lets it lie, then has the monsters fall.
## With [param stale] the world sees nothing from then until the hero is alive again and a stall
## more has passed. True if it came to that.
func _win_with_one_fallen(stale: bool = false) -> bool:
	if not _play_until(SimEvent.Kind.ENCOUNTER_STARTED):
		return false
	_play(0.1)
	var battle: Battle = _sim.expedition.battle
	if battle == null:
		return false
	battle.combatant(FALLEN).health = 0
	_sim.party.hero(FALLEN).health = 0
	_play(0.5)
	if _sim.expedition.battle != null:
		for monster: Combatant in _sim.expedition.battle.monsters:
			if monster.is_alive():
				monster.health = 1
	if not stale:
		return true
	for i: int in 600:
		if _sim.expedition.state == Expedition.State.RESTING:
			break
		_sim.step()
	if _sim.expedition.state != Expedition.State.RESTING:
		return false
	while not _sim.party.hero(FALLEN).is_alive():
		_sim.step()
	for i: int in World.STALL_TICKS + 2:
		_sim.step()
	return true


# --- R1 ------------------------------------------------------------------------


func test_r1_a_camp_while_resting() -> void:
	_show(ColonyTest.winding_simulation())
	_play(0.5)
	assert_false(_camp().is_shown(), "no camp before a rest")
	var parts: Array[Node] = _camp().get_children()
	_begin_rest()
	_play(1.0)
	assert_eq(_sim.expedition.state, Expedition.State.RESTING, "the party rests")
	assert_true(_camp().is_shown(), "a camp while it rests")
	var fire: Vector2 = _camp().fire_feet()
	var low: float = INF
	var high: float = -INF
	for hero: Hero in _sim.party.heroes:
		var sprite: CharacterSprite = _world.character(hero.id)
		low = minf(low, sprite.position.x)
		high = maxf(high, sprite.position.x)
		assert_eq(sprite.position.y, fire.y, "hero %d stands on the fire's floor" % hero.id)
	assert_between(fire.x, low, high, "the fire between the first and the last hero")
	assert_lte(_rect_of("BedrollRed").end.x, low, "a bedroll past the leftmost hero")
	assert_gte(_rect_of("BedrollGreen").position.x, high, "a bedroll past the rightmost hero")
	assert_eq(_rect_of("Logs").end.y, fire.y, "the fire stands on the floor")
	for part: String in ["Logs", "Flame", "BedrollRed", "BedrollGreen"]:
		assert_true((_camp().get_node(part) as Node2D).visible, "%s shown" % part)
	_end_rest()
	_play(1.0, false)
	assert_false(_camp().is_shown(), "a second after the rest, no camp")
	for part: Node in _camp().get_children():
		assert_false((part as CanvasItem).visible, "%s gone" % part.name)
	_begin_rest()
	_play(1.0)
	assert_true(_camp().is_shown(), "a camp at the next rest")
	assert_eq(_camp().get_children(), parts, "made of the same nodes")


# --- R2 ------------------------------------------------------------------------


func test_r2_heroes_face_the_fire() -> void:
	_show(ColonyTest.winding_simulation())
	_play(0.5)
	_begin_rest()
	_play(1.0)
	var e: Expedition = _sim.expedition
	var fire: Vector2 = _camp().fire_feet()
	for hero: Hero in _sim.party.heroes:
		var sprite: CharacterSprite = _world.character(hero.id)
		var toward: int = 1 if fire.x > sprite.position.x else -1
		assert_eq(_faces(sprite), toward, "hero %d faces the fire" % hero.id)
		assert_gte(
			sprite.position.distance_to(fire),
			CampView.CAMP_CLEARANCE,
			"hero %d's feet clear of the fire" % hero.id
		)
		var placed: Vector2 = WorldPlaces.feet(e.hero_position(hero.id))
		assert_lte(sprite.position.distance_to(placed), 12.0, "hero %d moved a little" % hero.id)
	_end_rest()
	_play(1.0)
	assert_eq(e.state, Expedition.State.TRAVELLING, "the party walks on")
	var ahead: int = PartyPlaces.world_facing(e)
	for hero: Hero in _sim.party.heroes:
		assert_eq(_faces(_world.character(hero.id)), ahead, "hero %d faces ahead" % hero.id)


# --- R3 ------------------------------------------------------------------------


func test_r3_they_sit() -> void:
	_show(ColonyTest.winding_simulation())
	_play(0.5)
	for hero: Hero in _sim.party.heroes:
		assert_eq(_world.character(hero.id).shown_sit(), 0.0, "hero %d stands" % hero.id)
	_begin_rest()
	_play(1.0)
	for hero: Hero in _sim.party.heroes:
		var sprite: CharacterSprite = _world.character(hero.id)
		assert_eq(sprite.shown_sit(), 1.0, "hero %d sits" % hero.id)
		var head: Node2D = sprite.get_node("Mirror/Rig/head")
		assert_gte(
			head.global_position.y - sprite.global_position.y,
			_standing_head(hero.class_id) + 3.0,
			"hero %d's head is lower" % hero.id
		)
	_end_rest()
	_play(1.0)
	for hero: Hero in _sim.party.heroes:
		assert_eq(
			_world.character(hero.id).shown_sit(), 0.0, "travelling: hero %d stands" % hero.id
		)
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED), "a fight")
	_play(0.5)
	for hero: Hero in _sim.party.heroes:
		assert_eq(_world.character(hero.id).shown_sit(), 0.0, "fighting: hero %d stands" % hero.id)
	var easing: CharacterSprite = CharacterSprite.for_hero(&"knight")
	easing.sitting = true
	easing.advance(CharacterSprite.SIT_TIME / 2.0)
	assert_between(easing.shown_sit(), 0.01, 0.99, "half way through, half sat")
	easing.free()


# --- R4 ------------------------------------------------------------------------


func test_r4_set_up_and_packed() -> void:
	_show(ColonyTest.winding_simulation())
	_play(0.5)
	_begin_rest()
	var shares: Array[float] = []
	for i: int in ceili(CampView.CAMP_SETUP / FRAME) + 1:
		_play_frame()
		shares.append(_camp().setup_share())
	assert_lt(shares[0], 0.1, "a fresh rest sets up from nothing")
	assert_eq(shares[-1], 1.0, "and is whole within CAMP_SETUP and a frame")
	for i: int in range(1, shares.size()):
		if shares[i] < shares[i - 1]:
			_mark_wrong("frame %d: %f after %f" % [i, shares[i], shares[i - 1]])
	_assert_nothing_wrong("it only rises")
	for part: Node in _camp().get_children():
		assert_false(
			_world.effects_layer.is_ancestor_of(part), "%s not a passing effect" % part.name
		)
	_end_rest()
	_play(1.0, false)

	# A rest seen while the world catches up.
	_begin_rest()
	for i: int in World.STALL_TICKS + 2:
		_sim.step()
	_world.sync(FRAME)
	assert_eq(_camp().setup_share(), 1.0, "a rest seen late is set up whole")
	assert_true(_all_sat(), "with the heroes sitting")
	_end_rest()
	_play(1.0, false)

	# A short rest packs from wherever it had got to.
	_begin_rest()
	_play(0.2)
	var reached: float = _camp().setup_share()
	assert_lt(reached, 1.0, "not set up yet")
	for hero: Hero in _sim.party.heroes:
		hero.health = hero.max_health()
	var after: float = 1.0
	for i: int in 20:
		_play_frame()
		if _sim.expedition.state != Expedition.State.RESTING:
			after = _camp().setup_share()
			break
	assert_lt(after, 1.0, "it packs from below whole")
	_play(1.0, false)
	assert_eq(_camp().setup_share(), 0.0, "and is packed")


func test_r4_a_rest_found_after_time_away() -> void:
	var saved: Dictionary = Simulation.new(Main.SIMULATION_SEED, Main.STAGE_SHAPE).to_save()
	saved[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system()
	var path: String = save_path("rest")
	SaveStore.new(path).write(saved)
	var main: Main = make_main()
	main.save_store = SaveStore.new(path)
	main.away_seconds_override = 60.0
	add_child_autofree(main)
	assert_not_null(main.replay, "a replay of the time away")
	if main.replay == null:
		return
	main.replay.done_ticks = main.replay.total_ticks - 2
	for hero: Hero in main.simulation.party.heroes:
		hero.health = maxi(1, hero.max_health() / 2)
	main.simulation.expedition._start_rest()
	for i: int in 10:
		if main.replay == null:
			break
		main._process(FRAME)
	assert_null(main.replay, "the replay is over")
	assert_eq(main.simulation.expedition.state, Expedition.State.RESTING, "the party rests")
	assert_eq(main.world.camp.setup_share(), 1.0, "the camp is whole on the first frame")
	for hero: Hero in main.simulation.party.heroes:
		assert_eq(main.world.character(hero.id).shown_sit(), 1.0, "hero %d sits" % hero.id)


# --- R5 ------------------------------------------------------------------------


func test_r5_the_fire_gives_light() -> void:
	_show(ColonyTest.winding_simulation())
	_play(0.5)
	var before: int = _world.ambience.lights().size()
	_begin_rest()
	_play(1.0)
	var lights: Array[AmbienceLight] = _world.ambience.lights()
	assert_eq(lights.size(), before + 1, "one more light while the fire burns")
	var near: bool = false
	for light: AmbienceLight in lights:
		near = near or light.position.distance_to(_camp().fire_feet()) < TILE
	assert_true(near, "at the fire")
	_end_rest()
	_play(1.0, false)
	assert_eq(_world.ambience.lights().size(), before, "and none once it is out")


# --- R6 ------------------------------------------------------------------------


func test_r6_fallen_rise_at_camp() -> void:
	_show(ColonyTest.winding_simulation())
	assert_true(_win_with_one_fallen(), "a fight with a fallen hero")
	var lay: int = 0
	var rose: bool = false
	var since_fall: float = 0.6
	for i: int in roundi(8.0 / FRAME):
		_play_frame()
		since_fall += FRAME
		var state: Expedition.State = _sim.expedition.state
		if state == Expedition.State.FIGHTING:
			continue
		var sprite: CharacterSprite = _world.character(FALLEN)
		if not _sim.party.hero(FALLEN).is_alive():
			lay += 1
			if not sprite.visible or not sprite.is_dead():
				_mark_wrong("frame %d: hidden or up while dead" % i)
			var toppled: bool = since_fall > FallenParty.FALL_AT + FallenParty.TOPPLE_SECONDS
			if toppled and absf(absf(sprite.rotation) - PI / 2.0) > 0.01:
				_mark_wrong("frame %d: not on its back (%f)" % [i, sprite.rotation])
		elif not rose:
			rose = true
			assert_true(_world.fallen_party.is_standing(FALLEN), "alive again, it rises")
		if not sprite.visible:
			_mark_wrong("frame %d: hidden" % i)
	_assert_nothing_wrong("lying, then rising")
	assert_gt(lay, 0, "it lay there after the fight")
	assert_true(rose, "and rose")
	assert_eq(_sim.expedition.state, Expedition.State.RESTING, "the party still rests")
	assert_false(_world.fallen_party.is_standing(FALLEN), "its rise is over")
	assert_eq(_world.character(FALLEN).shown_sit(), 1.0, "and it sits at the camp")


func test_r6_seen_late_it_sits() -> void:
	_show(ColonyTest.winding_simulation())
	assert_true(_win_with_one_fallen(true), "a fight with a fallen hero, seen late")
	_world.sync(FRAME)
	var sprite: CharacterSprite = _world.character(FALLEN)
	assert_true(sprite.visible, "shown")
	assert_false(sprite.is_dead(), "alive")
	assert_eq(sprite.rotation, 0.0, "upright")
	assert_false(_world.fallen_party.is_standing(FALLEN), "with no rise")
	assert_eq(sprite.shown_sit(), 1.0, "sitting at once")
	for i: int in 30:
		_play_frame()
		if _world.fallen_party.is_standing(FALLEN):
			_mark_wrong("frame %d: rising" % i)
	_assert_nothing_wrong("no rise later")


# --- R7 ------------------------------------------------------------------------


func test_r7_one_revival_effect() -> void:
	_show(ColonyTest.winding_simulation(), 1, true)
	assert_true(_win_with_one_fallen(), "a fight with a fallen hero")
	var at_camp: Vector2i = Vector2i(-1, -1)
	for i: int in roundi(8.0 / FRAME):
		_play_frame()
		if _world.fallen_party.is_standing(FALLEN):
			at_camp = _revival_at(_world.feet_position(FALLEN))
			break
	var whole := Vector2i(2, LoopBeats.REVIVAL_SPARKS)
	assert_eq(at_camp, whole, "rising at camp: two columns and the sparks")
	_play(2.0)

	var revived := SimEvent.new(SimEvent.Kind.REVIVED, _sim.tick, KNIGHT, KNIGHT)
	_world.sim_event.emit(revived)
	assert_eq(_revival_at(_world.feet_position(KNIGHT)), whole, "a revive in a fight")
	_play(2.0)

	var old := SimEvent.new(SimEvent.Kind.REVIVED, _sim.tick - 1000, KNIGHT, KNIGHT)
	_world.sim_event.emit(old)
	assert_eq(_revival_at(_world.feet_position(KNIGHT)), Vector2i.ZERO, "none for a stale one")

	_world.sim_event.emit(SimEvent.new(SimEvent.Kind.PARTY_REVIVED, _sim.tick))
	_fx.advance(0.0)
	for hero: Hero in _sim.party.heroes:
		assert_eq(
			_revival_at(_world.feet_position(hero.id)),
			whole,
			"the party's revival: hero %d" % hero.id
		)


# --- R8 ------------------------------------------------------------------------


func test_r8_showcase_moments() -> void:
	var names: Array[StringName] = Showcase.names()
	assert_eq(names.find(&"camp_rise"), names.find(&"resting") + 1, "right after the rest")
	assert_eq(Showcase.caption(&"camp_rise"), "A HERO FALLS AND RISES AT CAMP")
	var showcase: Showcase = (load(SHOWCASE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	var world: World = showcase.main.world
	var rose: bool = false
	showcase.skip_to(&"camp_rise")
	while showcase.moment() == &"camp_rise" and showcase.elapsed < 60.0:
		showcase.advance(FRAME)
		for hero: Hero in showcase.main.simulation.party.heroes:
			if world.fallen_party.is_standing(hero.id) and world.camp.setup_share() >= 1.0:
				rose = true
	var seen: bool = showcase.evidence.get(&"camp_rise", false)
	assert_true(seen, "the moment was seen")
	assert_true(rose, "a hero rose with the camp up")

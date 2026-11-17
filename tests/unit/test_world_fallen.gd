extends GutTest
## Unit tests for the fallen party (spec 038) that the acceptance tests reach only indirectly: the
## revival's place worked out ahead of the simulation, the cut to a far revival, a fallen hero
## after a won fight, the heroes' spacing at a guardian, and the camera's travel.

const FRAME: float = 1.0 / 60.0
const FRAMES_PER_TICK: int = 6
const TILE: float = 16.0
const KNIGHT: int = 1


func _world(sim: Simulation) -> World:
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	return world


func _wipe(sim: Simulation) -> void:
	for hero: Hero in sim.party.heroes:
		hero.health = 0


## Steps [param sim] until the party is revived; false if it never is.
func _until_revived(sim: Simulation) -> bool:
	for i: int in 200:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.PARTY_REVIVED:
				return true
	return false


func test_the_revival_spot_is_where_the_simulation_revives() -> void:
	for seed_value: int in [1, 2, 3]:
		for stable: int in [1, 2, 4]:
			var sim := Simulation.new(seed_value)
			sim.expedition.last_stable_depth = stable
			sim.expedition.deepest_depth = stable
			var spot: Vector3 = FallenParty.revival_spot(sim)
			_wipe(sim)
			assert_true(_until_revived(sim), "revived")
			var feet: Vector2 = sim.expedition.hero_position(KNIGHT)
			var label: String = "seed %d, stable depth %d" % [seed_value, stable]
			assert_eq(Vector2(spot.x, spot.y), Vector2(feet.x * TILE, (feet.y + 1) * TILE), label)
			assert_eq(int(spot.z), sim.expedition.facing, label + ": facing")


func test_a_far_revival_is_a_cut() -> void:
	var sim := Simulation.new(1)
	var world: World = _world(sim)
	sim.expedition.last_stable_depth = 8
	sim.expedition.deepest_depth = 8
	for i: int in 30:
		world.sync(FRAME)
	_wipe(sim)
	var biggest: float = 0.0
	var last: Vector2 = world.camera.position
	var built_there: bool = false
	for i: int in roundi(4.0 / FRAME):
		if i % FRAMES_PER_TICK == 0:
			sim.step()
		world.sync(FRAME)
		biggest = maxf(biggest, world.camera.position.distance_to(last))
		last = world.camera.position
		built_there = built_there or world.labyrinth_view.built_depths().has(8)
	var screens: float = 3.0 * world.get_viewport_rect().size.y
	assert_gt(biggest, screens, "more than three screens away: the camera cuts")
	assert_true(built_there, "and the labyrinth is built where it cut to")
	var there: Vector2 = world.fallen_party.destination()
	var half: float = world.get_viewport_rect().size.x * 0.5
	there.x = clampf(there.x, ceilf(half), floorf(WorldCamera.BAND_WIDTH - half))
	assert_lt(world.camera.position.distance_to(there), 1.0, "onto the revival's place")


func test_a_hero_fallen_in_a_won_fight_goes_when_it_ends() -> void:
	var sim := Simulation.new(1)
	var world: World = _world(sim)
	var fought: bool = false
	var frame: int = 0
	while frame < 3000 * FRAMES_PER_TICK and not fought:
		if frame % FRAMES_PER_TICK == 0:
			sim.step()
		frame += 1
		world.sync(FRAME)
		fought = sim.expedition.state == Expedition.State.FIGHTING
	assert_true(fought, "a fight starts")
	var cleric: Hero = sim.party.hero(4)
	sim.expedition.battle.combatant(4).health = 0
	cleric.health = 0
	var lay: bool = false
	while sim.expedition.state == Expedition.State.FIGHTING and frame < 6000 * FRAMES_PER_TICK:
		if frame % FRAMES_PER_TICK == 0:
			sim.step()
		frame += 1
		world.sync(FRAME)
		lay = lay or world.fallen_party.is_lying(4)
	assert_true(lay, "the fallen cleric lay on the field")
	for i: int in 3:
		world.sync(FRAME)
	assert_false(world.fallen_party.is_lying(4), "the fight won, it lies there no longer")
	assert_false(world.character(4).visible, "it is out of sight, as a fallen hero was before")
	assert_eq(world.character(4).rotation, 0.0, "and upright again for when it is healed")


func test_bodies_are_their_opaque_pixels_either_side_of_the_feet() -> void:
	var king: CharacterSprite = CharacterSprite.for_monster(&"slime_king")
	var knight: CharacterSprite = CharacterSprite.for_hero(&"knight")
	var body: Rect2 = SpriteBounds.body_rect(king, Vector2(800, 192))
	assert_eq(body.size.x, 64.0, "the Slime King's body is its 64 pixels across")
	assert_eq(body.get_center().x, 800.0, "centred on its feet")
	assert_eq(body.end.y, 192.0 + World.FEET_LIFT.y + 1.0, "standing on them")
	assert_lt(SpriteBounds.half_width(knight), 16.0, "a hero is narrower than its 32-pixel canvas")
	king.free()
	knight.free()


func test_without_a_guardian_no_hero_is_moved() -> void:
	var sim := Simulation.new(1)
	var world: World = _world(sim)
	var spacing := GuardianSpacing.new()
	var goals: Dictionary[int, Vector2] = {}
	for hero: Hero in sim.party.heroes:
		goals[hero.id] = Vector2(790 - hero.id, 192)
	spacing.space(world, goals)
	for hero: Hero in sim.party.heroes:
		assert_eq(goals[hero.id], Vector2(790 - hero.id, 192))


func test_the_camera_travels_eased_and_ends_on_its_place() -> void:
	var camera := WorldCamera.new()
	add_child_autofree(camera)
	camera.snap_to(Vector2(400, 200))
	camera.travel(Vector2(1000, 500), 1.0)
	assert_true(camera.is_travelling())
	var steps: Array[float] = []
	var last: Vector2 = camera.position
	for i: int in 60:
		camera.target = Vector2(0, 0)  # what the target says meanwhile does not matter
		camera._process(1.0 / 60.0)
		steps.append(camera.position.distance_to(last))
		last = camera.position
	assert_false(camera.is_travelling(), "done after its time")
	assert_eq(camera.position, Vector2(1000, 500), "exactly on its place")
	assert_lt(steps[0], steps[30], "it eases in")
	assert_lt(steps[59], steps[30], "and out")
	camera.travel(Vector2(400, 200), 1.0)
	camera.snap_to(Vector2(700, 300))
	assert_false(camera.is_travelling(), "a snap ends a travel")

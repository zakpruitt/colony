extends GutTest
## Acceptance tests for specs/018-seeing-the-loop/spec.md, one per testable requirement (R3 is
## judged by eye, from the showcase's screenshots).

const FRAME: float = 1.0 / 30.0
const SEED: int = 1
const KNIGHT: int = 1
## The showcase's pass must end within this many seconds (90 at first; raised for spec 056's class
## and status moments, which the lead allowed).
const PASS_LIMIT: float = 150.0
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"

# --- R1 ------------------------------------------------------------------------


func _press_z(world: World) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.pressed = true
	world._unhandled_input(key)


func _run(main: Main, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(FRAME, left)
		main.world.sync(step)
		main.effects.advance(step)
		left -= step


func test_r1_zoom() -> void:
	var main: Main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	add_child_autofree(main)
	main.driver.set_process(false)
	main.world.set_process(false)
	main.effects.set_process(false)
	var camera: WorldCamera = main.world.camera
	var hud_transform: Transform2D = main.hud_layer.transform
	var hud_scale: Vector2 = main.hud_layer.scale
	assert_eq(camera.zoom_level(), 1, "the game starts at the normal view")
	assert_eq(camera.zoom, Vector2.ONE)

	_press_z(main.world)
	assert_eq(camera.zoom_level(), 2, "Z asks for the close view")
	_run(main, 0.1)
	assert_between(camera.zoom.x, 1.01, 1.99, "the zoom eases, it does not jump")
	_run(main, 0.2)
	assert_eq(camera.zoom, Vector2(2, 2), "after 0.3 s the zoom is exactly 2")
	assert_eq(main.hud_layer.transform, hud_transform, "the HUD does not zoom")
	assert_eq(main.hud_layer.scale, hud_scale)
	assert_eq(camera.position, camera.position.round(), "the camera sits on whole pixels")

	# The party is in the middle of the close view (within the look-ahead's share of it).
	var leader: Vector2 = main.world.feet_position(KNIGHT)
	var centre: Vector2 = camera.position
	assert_lt(absf(leader.x - centre.x), 160.0 / 2.0, "the party is on screen across")
	assert_lt(absf(leader.y - centre.y), 90.0 / 2.0, "and up and down")

	# A coin's target, carried into world space, still lands on the HUD's coin icon.
	main.hud.advance(0.0)
	var icon: TextureRect = main.hud.purse.coin_icon
	var icon_centre: Vector2 = icon.get_global_rect().get_center()
	var target: Vector2 = main.effects.gold_screen_target
	assert_lt(target.distance_to(icon_centre), 3.0, "the coin target is the coin icon")
	var in_world: Vector2 = main.effects._screen_to_world(target)
	var on_screen: Vector2 = main.world.get_viewport().get_canvas_transform() * in_world
	assert_lt(on_screen.distance_to(icon_centre), 2.0, "the world point is under the icon at 2x")

	_press_z(main.world)
	_run(main, 0.3)
	assert_eq(camera.zoom_level(), 1, "Z again goes back")
	assert_eq(camera.zoom, Vector2.ONE, "after 0.3 s the zoom is exactly 1")
	assert_eq(main.hud_layer.transform, hud_transform, "the HUD still has not moved")


# --- R2 ------------------------------------------------------------------------


func test_r2_showcase_plays_every_moment() -> void:
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	var seen: Array[StringName] = []
	showcase.moment_started.connect(func(moment: StringName) -> void: seen.append(moment))
	add_child_autofree(showcase)
	showcase.set_process(false)
	while not showcase.done and showcase.elapsed < 150.0:
		showcase.advance(FRAME)
	assert_true(showcase.done, "the pass finishes")
	assert_lt(showcase.elapsed, PASS_LIMIT, "within %d seconds" % PASS_LIMIT)
	assert_eq(seen, Showcase.MOMENTS, "every moment, in order")
	for moment: StringName in Showcase.MOMENTS:
		var happened: bool = showcase.evidence.get(moment, false)
		assert_true(happened, "%s really happened in the simulation" % moment)


# --- R4 ------------------------------------------------------------------------


func test_r4_showcase_is_separate() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(main_path, "res://game/main.tscn", "the game's main scene is Main")
	var main: Node = (load(main_path) as PackedScene).instantiate()
	add_child_autofree(main)
	var showcases: Array[Node] = main.find_children("*", "Showcase", true, false)
	assert_eq(showcases.size(), 0, "the main scene has no showcase")
	for node: Node in main.find_children("*", "", true, false):
		assert_false(node is Showcase, "no node of the main scene is a showcase")

	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	assert_null(showcase.main.save_store, "the showcase's Main has no save store")
	showcase.advance(FRAME)
	showcase.main.save_now()
	assert_false(
		FileAccess.file_exists(Showcase.NO_SAVE_PATH % OS.get_process_id()),
		"nothing was written for it"
	)


# --- R5 ------------------------------------------------------------------------


func test_r5_numbers_stay_readable() -> void:
	var sim := Simulation.new(SEED)
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	var fx := CombatEffects.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.setup(world, sim)
	var monsters: Array[int] = []
	for id: int in world._monsters:
		if monsters.size() < 5:
			monsters.append(id)
	assert_eq(monsters.size(), 5, "five monsters to hit the hero")

	var view: Rect2 = fx._view_rect()
	assert_true(view.has_point(world.feet_position(KNIGHT)), "the hero is on screen")
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	# Each monster hits every 0.5 to 1.1 s, a few of them on the very same frame.
	var next_hit: Array[float] = [0.0, 0.0, 0.05, 0.3, 0.3]
	var clock: float = 0.0
	var worst: float = 0.0
	var outside: int = 0
	var shown: int = 0
	var hits: int = 0
	while clock < 10.0:
		for i: int in monsters.size():
			if clock >= next_hit[i]:
				var crit: bool = rng.randf() < 0.15
				var event := SimEvent.new(
					SimEvent.Kind.HIT, sim.tick, monsters[i], KNIGHT, rng.randi_range(1, 120), crit
				)
				world.sim_event.emit(event)
				hits += 1
				next_hit[i] = clock + rng.randf_range(0.5, 1.1)
		fx.advance(FRAME)
		clock += FRAME
		var numbers: Array[FxText] = []
		for text: FxText in fx._texts:
			if text.kind == &"damage" and text.visible:
				numbers.append(text)
		shown = maxi(shown, numbers.size())
		for a: int in numbers.size():
			var box: Rect2 = numbers[a].rect()
			if not view.encloses(box):
				outside += 1
			for b: int in range(a + 1, numbers.size()):
				var other: Rect2 = numbers[b].rect()
				var smaller: float = minf(box.get_area(), other.get_area())
				worst = maxf(worst, box.intersection(other).get_area() / smaller)
	assert_gt(shown, 3, "several numbers were showing at once")
	assert_lte(worst, 1.0 / 3.0, "no two numbers overlap by more than a third (worst %.2f)" % worst)
	assert_eq(outside, 0, "no number is drawn outside the screen")
	assert_gt(hits, 50, "five monsters hit the hero for ten seconds")

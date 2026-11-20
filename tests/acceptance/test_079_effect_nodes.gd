extends ColonyTest
## Acceptance tests for specs/079-effect-nodes-and-room-in-big-files/spec.md, one per requirement.
##
## R1 (normal play looks and sounds the same) is the rest of the suite passing, R4's numbers
## starting where they did, and the showcase's shots beside the baseline. R8 is the standards page.

const SEED: int = 1
const FRAME: float = 1.0 / 60.0
const SHOW_FRAME: float = 1.0 / 30.0
const KNIGHT: int = 1
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const BIG_FILES: Array[String] = [
	"res://game/effects/combat_effects.gd", "res://game/dev/showcase.gd"
]
const MOST_LINES: int = 750
## The budgets the order test spreads its nodes over: two capped, two only names.
const BUDGETS: Array[StringName] = [&"combat", &"ability", &"coin", &"ring"]
## The caption's place on screen at 1280x720, as it has always been.
const CAPTION_AT_720 := Rect2(0, 296, 640, 20)
## Where each number of the bursts started, recorded from the code before this spec.
const STARTS: Array[Vector2] = [
	Vector2(692, 177),
	Vector2(702, 150),
	Vector2(662, 159),
	Vector2(678, 132),
	Vector2(111, 9),
	Vector2(136, -2),
	Vector2(696, 150),
	Vector2(702, 132),
	Vector2(113, 9),
	Vector2(136, -2),
	Vector2(698, 177),
	Vector2(694, 159),
	Vector2(662, 159),
	Vector2(125, 9),
	Vector2(678, 168),
	Vector2(702, 186),
	Vector2(654, 177),
	Vector2(702, 132),
	Vector2(144, 9),
	Vector2(702, 150),
	Vector2(126, 18),
	Vector2(702, 177),
	Vector2(684, 150),
	Vector2(654, 177),
	Vector2(110, 9),
	Vector2(700, 177),
	Vector2(117, 9),
	Vector2(702, 177),
	Vector2(692, 150),
	Vector2(670, 177),
	Vector2(136, -2),
	Vector2(710, 177),
	Vector2(121, 18),
	Vector2(686, 177),
	Vector2(654, 177),
	Vector2(702, 177),
	Vector2(136, -2),
	Vector2(670, 177),
	Vector2(662, 159),
	Vector2(702, 141),
	Vector2(670, 141),
	Vector2(115, 9),
	Vector2(691, 186),
	Vector2(695, 159),
	Vector2(110, 9),
	Vector2(144, 9),
	Vector2(695, 177),
	Vector2(110, 9),
	Vector2(702, 177),
	Vector2(700, 159),
	Vector2(670, 177),
	Vector2(697, 141),
	Vector2(118, 9),
	Vector2(670, 141),
	Vector2(144, 9),
	Vector2(684, 177),
	Vector2(688, 150),
	Vector2(128, 9),
	Vector2(654, 177),
	Vector2(110, 9),
	Vector2(702, 177),
	Vector2(698, 159),
	Vector2(702, 141),
	Vector2(670, 141),
	Vector2(110, 9),
	Vector2(136, -2),
	Vector2(702, 186),
	Vector2(662, 159),
	Vector2(654, 177),
]

var _sim: Simulation
var _world: World
var _fx: CombatEffects


func _start_effects() -> void:
	_sim = Simulation.new(SEED)
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)


## The id of a monster the world shows.
func _monster() -> int:
	for id: int in _world._monsters:
		if _world.character(id) != null:
			return id
	return -1


## True when [param node]'s script is FxNode or extends it.
func _is_fx_node(node: Object) -> bool:
	var script: Script = node.get_script() as Script
	while script != null:
		if script.get_global_name() == &"FxNode":
			return true
		script = script.get_base_script()
	return false


func _showcase() -> Showcase:
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	return showcase


# --- R2 ------------------------------------------------------------------------


func test_r2_every_pooled_effect_is_an_fx_node() -> void:
	var source: String = FileAccess.get_file_as_string("res://game/effects/fx_pool.gd")
	assert_false(source.contains(".call("), "the pool calls advance directly")
	var pool_script: Script = load("res://game/effects/fx_pool.gd")
	for method: Dictionary in pool_script.get_script_method_list():
		if method["name"] == "add":
			var node: Dictionary = method["args"][0]
			var taken: StringName = node["class_name"]
			assert_eq(taken, &"FxNode", "add takes an FxNode")
	var showcase: Showcase = _showcase()
	var pool: FxPool = showcase.main.world.fx
	var layer: Node2D = showcase.main.world.effects_layer
	var kinds: Dictionary[String, bool] = {}
	var others: Dictionary[String, bool] = {}
	for moment: StringName in [&"clay_fight", &"guardian_fight", &"knight_actions", &"quest_done"]:
		showcase.skip_to(moment)
		var start: float = showcase.elapsed
		while showcase.moment() == moment and showcase.elapsed - start < Showcase.GIVE_UP_SECONDS:
			showcase.advance(SHOW_FRAME)
			for child: Node in layer.get_children():
				if not pool.has(child as Node2D):
					continue
				var named: String = (child.get_script() as Script).get_global_name()
				if _is_fx_node(child):
					kinds[named] = true
				else:
					others[named] = true
		var happened: bool = showcase.evidence.get(moment, false)
		assert_true(happened, "(%s happened)" % moment)
	assert_eq(others.keys(), [], "every node the pool held was an FxNode")
	for named: String in ["FxParticle", "FxText", "FxCoin", "FxMote", "FxResource", "FxRing"]:
		assert_true(kinds.has(named), "(the pool held an %s)" % named)


# --- R3 ------------------------------------------------------------------------


## A pool on a layer of its own holding 300 particles spread over BUDGETS, each finishing on a
## frame of its own (some on the same frame); [param held] and [param budgets] get them, oldest
## first.
func _fill_pool(pool: FxPool, held: Array[FxParticle], budgets: Array[StringName]) -> void:
	var layer := Node2D.new()
	add_child_autofree(layer)
	pool.setup(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 79
	for i: int in 300:
		var particle := FxParticle.new()
		particle.life = FRAME * rng.randi_range(1, 40) - FRAME / 2.0
		var budget: StringName = BUDGETS[rng.randi_range(0, BUDGETS.size() - 1)]
		assert_true(pool.add(particle, budget), "(particle %d is taken)" % i)
		held.append(particle)
		budgets.append(budget)


func test_r3_the_pool_keeps_its_order_and_counts() -> void:
	var pool := FxPool.new()
	var held: Array[FxParticle] = []
	var budgets: Array[StringName] = []
	_fill_pool(pool, held, budgets)
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	for frame: int in 45:
		if frame % 7 == 3 and not held.is_empty():
			# One taken away early, before its end.
			var at: int = rng.randi_range(0, held.size() - 1)
			var gone: FxParticle = held[at]
			held.remove_at(at)
			budgets.remove_at(at)
			pool.remove(gone)
			assert_false(pool.has(gone), "frame %d: a removed node is not held" % frame)
		if frame == 20:
			for i: int in 5:
				var late := FxParticle.new()
				late.life = 0.2
				pool.add(late, BUDGETS[i % BUDGETS.size()])
				held.append(late)
				budgets.append(BUDGETS[i % BUDGETS.size()])
		pool.advance(FRAME)
		for i: int in range(held.size() - 1, -1, -1):
			if held[i].age >= held[i].life:
				held.remove_at(i)
				budgets.remove_at(i)
		assert_eq(pool.count(), held.size(), "frame %d: the count" % frame)
		for budget: StringName in BUDGETS:
			var expected: Array[Node2D] = []
			for i: int in held.size():
				if budgets[i] == budget:
					expected.append(held[i])
			assert_eq(pool.count(budget), expected.size(), "frame %d: %s's count" % [frame, budget])
			assert_eq(
				pool.nodes(budget), expected, "frame %d: %s's nodes, in order" % [frame, budget]
			)
		for particle: FxParticle in held:
			assert_true(pool.has(particle), "frame %d: a node still going is held" % frame)
	pool.clear()
	assert_eq(pool.count(), 0, "clear takes every node away")
	for budget: StringName in BUDGETS:
		assert_eq(pool.nodes(budget).size(), 0, "%s is empty after clear" % budget)


func test_r3_tidying_makes_no_new_list() -> void:
	var pool := FxPool.new()
	var held: Array[FxParticle] = []
	var budgets: Array[StringName] = []
	_fill_pool(pool, held, budgets)
	var all: Array = pool._nodes
	var lists: Dictionary[StringName, Array] = {}
	for budget: StringName in BUDGETS:
		lists[budget] = pool._kinds[budget]
	var before: int = pool.count()
	pool.advance(FRAME * 5.0)
	assert_lt(pool.count(), before, "(nodes finished in that advance)")
	assert_true(is_same(pool._nodes, all), "the list of every node is the same array")
	for budget: StringName in BUDGETS:
		assert_true(is_same(pool._kinds[budget], lists[budget]), "%s's list is the same" % budget)
	assert_eq(pool._nodes.size(), pool.count(), "and holds only the nodes still going")


# --- R4, R5 --------------------------------------------------------------------


func test_r4_the_big_files_have_room() -> void:
	for path: String in BIG_FILES:
		var lines: int = FileAccess.get_file_as_string(path).count("\n")
		assert_lte(lines, MOST_LINES, "%s is at most %d lines" % [path, MOST_LINES])


## The start of every number in 40 bursts over one monster (a seeded number of hits each, some
## crits, a seeded pause between bursts), in the order they appeared. Every other burst the monster
## stands near the top left of the screen, so its numbers are kept on it.
func _burst_starts() -> Array[Vector2]:
	_start_effects()
	var monster: int = _monster()
	assert_ne(monster, -1, "(the world shows a monster)")
	var sprite: CharacterSprite = _world.character(monster)
	var places: Array[Vector2] = [sprite.position, _fx._view_rect().position + Vector2(8, 60)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4079
	var starts: Array[Vector2] = []
	var seen: Dictionary[FxText, bool] = {}
	for burst: int in 40:
		sprite.position = places[burst % 2].round()
		var n: int = rng.randi_range(1, 6)
		for i: int in n:
			var crit: bool = rng.randf() < 0.25
			var amount: int = rng.randi_range(1, 999)
			var hit := SimEvent.new(SimEvent.Kind.HIT, _sim.tick, KNIGHT, monster, amount, crit)
			_world.sim_event.emit(hit)
		for text: FxText in _fx.texts():
			if text.kind == &"damage" and not seen.has(text):
				seen[text] = true
				starts.append(text.position)
		var pause: float = rng.randf_range(0.05, 0.6)
		while pause > 0.0:
			_fx.advance(minf(FRAME, pause))
			pause -= FRAME
	return starts


func test_r4_numbers_start_where_they_did() -> void:
	var starts: Array[Vector2] = _burst_starts()
	assert_eq(starts.size(), STARTS.size(), "as many numbers as before")
	for i: int in mini(starts.size(), STARTS.size()):
		assert_eq(starts[i], STARTS[i], "number %d starts where it did" % i)


# --- R6 ------------------------------------------------------------------------


## The bar's rect on screen, in the world's 640x360 pixels.
func _bar_on_screen(ui: UiRoot) -> Rect2:
	var rect: Rect2 = ui.bar.rect_in(ui.room())
	return Rect2(ui.ui_to_world(rect.position), ui.ui_to_world(rect.size))


## The caption's rect on screen, as wide as its words at least.
func _caption_on_screen(caption: Label) -> Rect2:
	return Rect2(caption.position, caption.size.max(caption.get_minimum_size()))


func test_r6_the_caption_clears_the_bar() -> void:
	var showcase: Showcase = _showcase()
	var ui: UiRoot = showcase.main.ui
	var caption: Label = showcase._caption
	ui.set_room_for_test(Vector2i(1280, 720))
	showcase.advance(SHOW_FRAME)
	assert_eq(Rect2(caption.position, caption.size), CAPTION_AT_720, "at 1280x720, today's place")
	ui.set_room_for_test(Vector2i(960, 540))
	showcase.advance(SHOW_FRAME)
	var bar: Rect2 = _bar_on_screen(ui)
	for index: int in Showcase.ROWS.size():
		caption.text = "%d/%d  %s" % [index + 1, Showcase.ROWS.size(), Showcase.ROWS[index][1]]
		var shown: Rect2 = _caption_on_screen(caption)
		assert_false(shown.intersects(bar), "at 960x540, %s clears the bar" % caption.text)
		assert_gte(shown.position.x, 0.0, "and starts on screen")
	ui.set_room_for_test(Vector2i(1280, 720))
	showcase.advance(SHOW_FRAME)
	assert_eq(Rect2(caption.position, caption.size), CAPTION_AT_720, "and back at 1280x720")


# --- R7 ------------------------------------------------------------------------


func test_r7_sound_is_handed_its_goals() -> void:
	var files: Dictionary[String, String] = {}
	scripts_in("res://game/audio", files)
	assert_gt(files.size(), 0, "(the audio scripts were read)")
	for path: String in files:
		assert_false(
			files[path].contains("get_parent("), "%s finds nothing through its parent" % path
		)
	var goals: bool = false
	var sound_script: Script = load("res://game/audio/sound_player.gd")
	for method: Dictionary in sound_script.get_script_method_list():
		if method["name"] == "setup":
			for arg: Dictionary in method["args"]:
				goals = goals or arg["class_name"] == &"Goals"
	assert_true(goals, "setup is handed the goals")


func test_r7_a_finished_goal_chimes_in_the_game() -> void:
	var main: Main = make_main()
	add_child_autofree(main)
	main.driver.set_process(false)
	main.world.set_process(false)
	main.effects.set_process(false)
	main.sound.drain_started()
	main.hud.goals.goal_finished.emit("Goal: reached Mossy Hollow 2")
	assert_has(main.sound.drain_started(), &"depth_stable", "a finished goal plays the chime")

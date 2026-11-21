extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/028-seeing-side-quests/spec.md, one per requirement.
##
## Most tests find a seed whose labyrinth has the side quest wanted on its first visit, put the
## party one step outside that chamber walking in (as spec 025's tests do), build the world, the
## effects, the HUD and the sound player on it with their own clocks turned off, and step them
## all together one tick at a time.

const FRAME: float = 1.0 / Simulation.TICKS_PER_SECOND
const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4
## [side quest, its prop's sheet, the words when done, the reward's colour].
const QUESTS: Array = [
	[&"locked_chest", "res://assets/sprites/props/chest.png", "Chest opened", &"yellow"],
	[&"stuck_door", "res://assets/sprites/props/door.png", "Door forced", &"yellow"],
	[&"hurt_wanderer", "res://assets/sprites/props/wanderer.png", "Wanderer mended", &"yellow"],
	[&"rune_stone", "res://assets/sprites/props/stone.png", "Runes read", &"cyan"],
	[&"tripwire", "res://assets/sprites/props/wire.png", "Trap disarmed", &"yellow"],
]
## [class, microskill, level learned at, description], as the class data has them.
const MICROSKILLS: Array = [
	[&"rogue", "Lockpicker", 2, "Opens locks"],
	[&"knight", "Strongarm", 3, "Forces what is stuck"],
	[&"cleric", "Mender", 3, "Patches up strangers"],
	[&"mage", "Runereader", 4, "Reads old runes"],
	[&"rogue", "Trapspotter", 6, "Sees a trap before it sees you"],
]

var _sound: SoundPlayer
## Where [method _before_quest] put the party: Vector2i(depth, chamber index).
var _quest_at: Vector2i = Vector2i(0, -1)

# --- Helpers -------------------------------------------------------------------


## A simulation whose party stands one step outside a chamber holding [param kind] on its first
## visit, at [param min_depth] or a little deeper, walking in, with auto-push off and every hero
## at [param level]. Its place is left in [member _quest_at].
func _before_quest(kind: StringName, level: int = 6, min_depth: int = 2) -> Simulation:
	for seed_value: int in range(1, 1000):
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for depth: int in range(min_depth, min_depth + 3):
			for room: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
				if e.side_quest_in(depth, room.index) != kind:
					continue
				sim.set_auto_push(false)
				e.depth = depth
				e.target_depth = depth
				e.deepest_depth = depth
				e.x = room.rect.position.x - 0.1
				e.facing = 1
				for hero: Hero in sim.party.heroes:
					_set_level(hero, level)
				_quest_at = Vector2i(depth, room.index)
				return sim
	fail_test("no seed has a %s near depth %d" % [kind, min_depth])
	return null


## Builds the world, the effects, the HUD and the sound player on [param simulation].
func _show(simulation: Simulation) -> void:
	_sim = simulation
	_build_world()
	_add_hud()
	_add_ui(Vector2i(1280, 720))
	_sound = SoundPlayer.new()
	add_child_autofree(_sound)
	_sound.set_process(false)
	_sound.setup(_world, _fx, simulation, null)
	_frame_parts = [_fx.advance, _hud.advance, _sound._process]
	_frame(0, 0.0)


## Ticks until [param done] is true or [param limit] ticks have passed. Returns whether it came.
func _until(done: Callable, limit: int = 600) -> bool:
	for i: int in limit:
		var now: bool = done.call()
		if now:
			return true
		_frame(1, FRAME)
	var last: bool = done.call()
	return last


func _working() -> bool:
	return _sim.expedition.state == Expedition.State.WORKING


func _not_working() -> bool:
	return _sim.expedition.state != Expedition.State.WORKING


## The quest effects' words on the effects layer.
func _labels() -> Array[FxText]:
	var found: Array[FxText] = []
	for child: Node in _world.effects_layer.get_children():
		var text: FxText = child as FxText
		if text != null and not text.is_queued_for_deletion() and text.kind == &"quest":
			found.append(text)
	return found


func _label(words: String) -> FxText:
	for text: FxText in _labels():
		if text.text == words:
			return text
	return null


func _bursts() -> Array[FxParticle]:
	var found: Array[FxParticle] = []
	for child: Node in _world.effects_layer.get_children():
		var bit: FxParticle = child as FxParticle
		if bit != null and not bit.is_queued_for_deletion() and bit.kind == &"quest_burst":
			found.append(bit)
	return found


func _floor_pixels(depth: int) -> float:
	return (_sim.labyrinth.level(depth).floor_y + 1) * World.TILE


func _room_pixels(at: Vector2i) -> Rect2:
	var room: LabyrinthChamber = _sim.labyrinth.level(at.x).chambers[at.y]
	return Rect2(room.rect.position.x * World.TILE, 0, room.rect.size.x * World.TILE, 1)


func _sentences() -> Array[String]:
	var found: Array[String] = []
	for line: String in _hud.journal.lines():
		found.append(line.get_slice("  ", 1))
	return found


func _flash(sprite: CharacterSprite) -> float:
	var rig: Node2D = sprite.get_node("Mirror/Rig") as Node2D
	var material: ShaderMaterial = rig.material as ShaderMaterial
	return material.get_shader_parameter("flash")


# --- R1 ------------------------------------------------------------------------


func test_r1_props_wait_in_chambers() -> void:
	for row: Array in QUESTS:
		var quest: StringName = row[0]
		var sheet_path: String = row[1]
		var sim: Simulation = _before_quest(quest)
		if sim == null:
			return
		_show(sim)
		var props: QuestProps = _world.quest_props
		assert_not_null(props, "the world has its quest props")
		if props == null:
			return
		var prop: Sprite2D = props.prop(_quest_at.x, _quest_at.y)
		assert_not_null(prop, "%s: a prop waits in its chamber" % quest)
		if prop == null:
			continue
		assert_eq(prop.name, String(quest), "%s: its own prop" % quest)
		var sheet: PixelSheet = PixelSheet.load_sheet(sheet_path)
		assert_not_null(sheet, "%s: its sheet is baked" % sheet_path)
		var atlas: AtlasTexture = prop.texture as AtlasTexture
		assert_true(
			atlas != null and atlas.atlas == sheet.part(StringName(sheet.part_names[0])).atlas,
			"the sheet"
		)
		var feet: Vector2 = prop.position
		assert_eq(feet.y, _floor_pixels(_quest_at.x), "%s: on the floor line" % quest)
		var room: Rect2 = _room_pixels(_quest_at)
		var middle: float = room.position.x + room.size.x / 2.0
		assert_lt(absf(feet.x - middle), room.size.x / 4.0, "%s: near the middle" % quest)
		assert_true(prop.is_visible_in_tree(), "%s: shown" % quest)

		# A prop for every chamber of the built levels with a quest, and none elsewhere.
		var wanted: int = 0
		for depth: int in _world.labyrinth_view.built_depths():
			for chamber: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
				var holds: bool = sim.expedition.side_quest_in(depth, chamber.index) != &""
				if holds:
					wanted += 1
				var shown: Sprite2D = props.prop(depth, chamber.index)
				assert_eq(
					shown != null, holds, "d%d c%d: a prop iff a quest" % [depth, chamber.index]
				)
		assert_eq(props.prop_count(), wanted, "%s: one prop per quest" % quest)

		# Done (everyone is level 6, so someone can), the prop is gone.
		assert_true(_until(_working, 30), "%s: the party works it" % quest)
		assert_true(_until(_not_working), "%s: and finishes" % quest)
		_frame(1, FRAME)
		assert_null(props.prop(_quest_at.x, _quest_at.y), "%s: gone once cleared" % quest)
		assert_eq(props.prop_count(), wanted - 1, "%s: the others stay" % quest)


# --- R2 ------------------------------------------------------------------------


func test_r2_worker_steps_forward() -> void:
	var sim: Simulation = _before_quest(&"locked_chest")
	if sim == null:
		return
	_set_level(sim.party.hero(ROGUE), 2)
	_set_level(sim.party.hero(KNIGHT), 1)
	_show(sim)
	assert_true(_until(_working, 30), "the party works the chest")
	assert_eq(sim.expedition.worker_id(), ROGUE, "the rogue picks the lock")
	var props: QuestProps = _world.quest_props
	var prop: Sprite2D = props.prop(_quest_at.x, _quest_at.y)
	var strikes: Dictionary[int, int] = {}
	for hero: Hero in sim.party.heroes:
		strikes[hero.id] = 0
		var count: Callable = func() -> void: strikes[hero.id] += 1
		_world.character(hero.id).struck.connect(count)
	# Give the rogue a moment to walk up.
	for i: int in 10:
		_frame(1, FRAME)
	var rogue: CharacterSprite = _world.character(ROGUE)
	assert_lt(absf(rogue.position.x - prop.position.x), 14.0, "the worker is at the prop")
	assert_eq(rogue.position.y, prop.position.y, "on the floor")
	for hero: Hero in sim.party.heroes:
		if hero.id == ROGUE:
			continue
		var other: CharacterSprite = _world.character(hero.id)
		var gap: float = absf(other.position.x - rogue.position.x)
		assert_gt(gap, 8.0, "hero %d stands apart from the worker" % hero.id)
	assert_eq(props.worker_label(), "Lockpicker", "the microskill's name over the worker")
	assert_almost_eq(props.bar_fraction(), sim.expedition.work_progress(), 0.001, "the bar")
	var before: float = props.bar_fraction()
	for i: int in 10:
		_frame(1, FRAME)
	assert_gt(props.bar_fraction(), before, "the bar fills")
	assert_almost_eq(props.bar_fraction(), sim.expedition.work_progress(), 0.001)
	_until(_not_working)
	assert_gte(strikes[ROGUE], 2, "the worker swings again and again")
	for hero: Hero in sim.party.heroes:
		if hero.id != ROGUE:
			assert_eq(strikes[hero.id], 0, "hero %d idles" % hero.id)
	_frame(1, FRAME)
	assert_eq(props.bar_fraction(), -1.0, "no bar once it is done")
	assert_eq(props.worker_label(), "", "no name once it is done")


# --- R3 ------------------------------------------------------------------------


func test_r3_done_looks_like_a_win() -> void:
	for row: Array in QUESTS:
		var quest: StringName = row[0]
		var sheet_path: String = row[1]
		var words: String = row[2]
		var colour: StringName = row[3]
		var sim: Simulation = _before_quest(quest)
		if sim == null:
			return
		_show(sim)
		var prop: Sprite2D = _world.quest_props.prop(_quest_at.x, _quest_at.y)
		var at: Vector2 = prop.position
		assert_true(_until(_working, 30), "%s: worked" % quest)
		assert_null(_label(words), "%s: nothing before it is done" % quest)
		assert_true(_until(_not_working), "%s: done" % quest)
		var label: FxText = _label(words)
		assert_not_null(label, "%s: the label says %s" % [quest, words])
		if label != null:
			assert_eq(label.color, Palette.color(colour), "%s: in the reward's colour" % quest)
			assert_lt(absf(label.position.x - at.x), 24.0, "%s: over the prop" % quest)
		var bits: Array[FxParticle] = _bursts()
		assert_gte(bits.size(), 6, "%s: the prop bursts" % quest)
		var colours: PackedColorArray = CombatEffects.sheet_colors(_sheet(sheet_path))
		for bit: FxParticle in bits:
			assert_true(colours.has(bit.color), "%s: a bit in the prop's colours" % quest)


func _sheet(path: String) -> Texture2D:
	var sheet: PixelSheet = PixelSheet.load_sheet(path)
	return sheet.part(StringName(sheet.part_names[0])).atlas


# --- R4 ------------------------------------------------------------------------


func test_r4_a_miss_says_what_was_needed() -> void:
	# Nobody can pick the lock: the party walks past, and the label rises once per visit.
	var sim: Simulation = _before_quest(&"locked_chest", 1)
	if sim == null:
		return
	_show(sim)
	var made: Array[String] = []
	_world.effects_layer.child_entered_tree.connect(
		func(node: Node) -> void:
			var text: FxText = node as FxText
			if text != null:
				made.append(text.text)
	)
	var prop: Sprite2D = _world.quest_props.prop(_quest_at.x, _quest_at.y)
	_frame(1, FRAME)
	_frame(0, 0.0)
	var label: FxText = _label("Needs Lockpicker")
	assert_not_null(label, "the label names the microskill")
	if label != null:
		assert_eq(label.color, Palette.color(&"steel"), "in a muted colour")
		assert_lt(absf(label.position.x - prop.position.x), 24.0, "rising from the prop")
		var y: float = label.position.y
		for i: int in 5:
			_frame(0, FRAME)
		assert_lt(label.position.y, y, "it rises")
	assert_not_null(_world.quest_props.prop(_quest_at.x, _quest_at.y), "the chest still waits")
	# Walk on, turn at the end of the level and come back through the same visit.
	var entries: int = 0
	var inside: bool = true
	for i: int in 1500:
		_frame(1, FRAME)
		var here: LabyrinthChamber = sim.expedition.chamber()
		var now: bool = here != null and here.index == _quest_at.y
		if now and not inside:
			entries += 1
		inside = now
		if entries >= 1 and not inside:
			break
	assert_gte(entries, 1, "the party came back through the chamber")
	assert_eq(made.count("Needs Lockpicker"), 1, "once per visit")

	# A tripwire nobody spots springs: red words, a shake and every hero flashing.
	sim = _before_quest(&"tripwire", 5)
	_show(sim)
	assert_eq(_world.camera._shake, 0.0, "still before")
	sim.step()
	_frame(0, 0.01)
	var sprung: FxText = _label("Sprung!")
	assert_not_null(sprung, "Sprung!")
	if sprung != null:
		assert_eq(sprung.color, Palette.color(&"red"), "in red")
	assert_gt(_world.camera._shake, 0.0, "the camera shakes")
	for hero: Hero in sim.party.heroes:
		assert_eq(_flash(_world.character(hero.id)), 1.0, "hero %d flashes" % hero.id)
	assert_null(_label("Needs Trapspotter"), "a sprung trap says Sprung! instead")


# --- R5 ------------------------------------------------------------------------


func test_r5_learning_is_marked() -> void:
	# The mage reads a rune stone; the XP takes the rogue to level 2, and Lockpicker.
	var sim: Simulation = _before_quest(&"rune_stone", 4)
	if sim == null:
		return
	_set_level(sim.party.hero(ROGUE), 1)
	sim.party.hero(ROGUE).xp = Hero.xp_for_level(2) - 1
	_show(sim)
	assert_true(_until(_working, 30), "the mage reads")
	_sound.drain_started()
	assert_true(_until(_not_working), "and finishes")
	assert_eq(sim.party.hero(ROGUE).level, 2, "the rogue reached level 2")
	var label: FxText = _label("Learned Lockpicker")
	assert_not_null(label, "the rogue's label")
	if label != null:
		assert_eq(label.follow_id, ROGUE, "over the rogue")
		var rogue: CharacterSprite = _world.character(ROGUE)
		assert_lt(absf(label.position.x - rogue.position.x), 30.0, "above the rogue")
		assert_lt(label.position.y, rogue.position.y - 24.0, "above the rogue's head")
	assert_has(_sound.drain_started(), &"level_up", "the level-up sound")
	assert_has(_sentences(), "Rogue learned Lockpicker", "the journal's line")

	# The sound plays for a lone MICROSKILL_LEARNED too.
	_sound._process(1.0)
	var skill: int = Content.microskill_ids().find(&"trapspotter")
	_world.sim_event.emit(SimEvent.new(SimEvent.Kind.MICROSKILL_LEARNED, sim.tick, ROGUE, skill, 6))
	assert_has(_sound.drain_started(), &"level_up", "on its own")
	assert_not_null(_label("Learned Trapspotter"))
	assert_has(_sentences(), "Rogue learned Trapspotter")


# --- R6 ------------------------------------------------------------------------


func test_r6_journal_and_status() -> void:
	var sim: Simulation = _before_quest(&"locked_chest")
	if sim == null:
		return
	_show(sim)
	assert_true(_until(_working, 30), "working")
	assert_eq(_hud.status_text(), "Working: Locked Chest", "the status line")
	assert_eq(_hud.place_panel.status_label.text, "Working: Locked Chest", "as the panel shows it")
	var gold: int = sim.party.gold
	assert_true(_until(_not_working), "done")
	var reward: int = sim.party.gold - gold
	assert_has(_sentences(), "Chest opened: %d gold" % reward, "a done line with its gold")
	assert_ne(_hud.status_text(), "Working: Locked Chest", "not once it is done")

	sim = _before_quest(&"rune_stone")
	_show(sim)
	assert_true(_until(_working, 30))
	var xp: int = sim.party.hero(KNIGHT).xp
	_until(_not_working)
	var each: int = sim.party.hero(KNIGHT).xp - xp
	assert_has(_sentences(), "Runes read: %d XP each" % each, "a done line with its XP")

	sim = _before_quest(&"stuck_door", 1)
	_show(sim)
	_frame(1, FRAME)
	assert_has(_sentences(), "Passed a Stuck Door: needs Strongarm", "a miss with what it needs")

	sim = _before_quest(&"tripwire", 1)
	_show(sim)
	_frame(1, FRAME)
	assert_has(_sentences(), "Sprang a Tripwire: needs Trapspotter", "a sprung trap")


# --- R7 ------------------------------------------------------------------------


func test_r7_sheet_lists_microskills() -> void:
	var sim := Simulation.new(28)
	_show(sim)
	# Spec 060: each hero's sheet is its own window; spec 034: the microskills are on Skills.
	for hero: Hero in sim.party.heroes:
		_hud.hero_windows.window_of(hero.id).open_page(HeroWindow.Page.SKILLS)
	var sheet: HeroWindow
	var ids: Dictionary[StringName, int] = {
		&"knight": KNIGHT, &"rogue": ROGUE, &"mage": MAGE, &"cleric": CLERIC
	}
	for row: Array in MICROSKILLS:
		var class_id: StringName = row[0]
		var skill: String = row[1]
		var level: int = row[2]
		var description: String = row[3]
		var hero: Hero = sim.party.hero(ids[class_id])
		_set_level(hero, level - 1)
		sheet = _open(hero.id)
		_hud.advance(0.0)
		var text: String = sheet.line(&"microskills")
		var upcoming: String = "%s, level %d" % [skill, level]
		assert_true(
			text.split("\n").has(upcoming), "%s before: %s in %s" % [class_id, upcoming, text]
		)
		assert_false(text.contains(description), "%s: no description yet" % class_id)
		var row_label: Label = _row(sheet, skill)
		assert_not_null(row_label, "%s's row" % skill)
		if row_label != null:
			var grey: Color = row_label.get_theme_color(&"font_color")
			assert_ne(grey, Palette.color(&"white"), "%s: grey while to come" % skill)
		_set_level(hero, level)
		_hud.advance(0.0)
		text = sheet.line(&"microskills")
		var learned: String = "%s: %s" % [skill, description]
		assert_true(text.split("\n").has(learned), "%s after: %s in %s" % [class_id, learned, text])
		assert_false(text.contains(upcoming), "%s: no longer to come" % class_id)
		row_label = _row(sheet, skill)
		if row_label != null:
			var white: Color = row_label.get_theme_color(&"font_color")
			assert_eq(white, Palette.color(&"white"), "%s: white once learned" % skill)
	# Rogue at level 2: one of each, in the class's order.
	_set_level(sim.party.hero(ROGUE), 2)
	sheet = _open(ROGUE)
	_hud.advance(0.0)
	assert_eq(
		sheet.line(&"microskills"), "Lockpicker: Opens locks\nTrapspotter, level 6", "the rogue's"
	)


func _row(sheet: HeroWindow, skill: String) -> Label:
	var shown: Array[Label] = []
	_collect_shown_labels(sheet, shown)
	for label: Label in shown:
		if label.text.begins_with(skill):
			return label
	return null


func _collect_shown_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		var label: Label = child as Label
		if label != null and label.is_visible_in_tree() and not label.text.is_empty():
			into.append(label)
		_collect_shown_labels(child, into)


# --- R9 ------------------------------------------------------------------------


func test_r9_sounds() -> void:
	var sim: Simulation = _before_quest(&"stuck_door")
	if sim == null:
		return
	_show(sim)
	assert_true(_until(_working, 30), "working")
	_sound.drain_started()
	var clicks: int = 0
	while _working():
		_frame(1, FRAME)
		clicks += _sound.drain_started().count(&"ui_click")
	assert_gte(clicks, 3, "a click repeats while the party works")
	assert_lte(clicks, 10, "softly, not every frame")
	for i: int in 20:
		_frame(1, FRAME)
		assert_false(_sound.drain_started().has(&"ui_click"), "and stops when the work does")

	sim = _before_quest(&"tripwire", 5)
	_show(sim)
	_sound.drain_started()
	_frame(1, FRAME)
	assert_has(_sound.drain_started(), &"hero_hurt", "a sprung tripwire hurts")

	# Even when every hero is too hurt to lose more (no HIT follows), it still sounds.
	sim = _before_quest(&"tripwire", 5)
	for hero: Hero in sim.party.heroes:
		hero.health = 1
	_show(sim)
	_sound.drain_started()
	_frame(1, FRAME)
	assert_has(_sound.drain_started(), &"hero_hurt", "the trap's own sound")
	for sound: StringName in [&"ui_click", &"hero_hurt"]:
		assert_has(SoundPlayer.SOUNDS, sound, "no new sounds")


# --- R10 -----------------------------------------------------------------------


func test_r10_old_events_show_nothing() -> void:
	# A chest done, a door passed and a trap sprung, all while the view was not looking.
	for row: Array in [[&"locked_chest", 6], [&"stuck_door", 1], [&"tripwire", 1]]:
		var quest: StringName = row[0]
		var level: int = row[1]
		var sim: Simulation = _before_quest(quest, level)
		if sim == null:
			return
		_show(sim)
		var lines: int = _hud.journal.lines().size()
		# Unwatched: to the end of the work if there is any, then a little more, so every event of
		# the quest is older than the world animates (and no fight has begun since).
		sim.step()
		while sim.expedition.state == Expedition.State.WORKING:
			sim.step()
		for i: int in World.ANIMATE_TICKS + 2:
			sim.step()
		_sound.drain_started()
		_frame(0, FRAME)
		assert_eq(_labels().size(), 0, "%s: no labels for old events" % quest)
		assert_eq(_bursts().size(), 0, "%s: no particles" % quest)
		assert_eq(_world.camera._shake, 0.0, "%s: no shake" % quest)
		var started: Array[StringName] = _sound.drain_started()
		assert_false(started.has(&"hero_hurt"), "%s: no sound" % quest)
		assert_false(started.has(&"level_up"), "%s: no sound" % quest)
		assert_gt(_hud.journal.lines().size(), lines, "%s: the journal still has it" % quest)
		var props: QuestProps = _world.quest_props
		var wanted: int = 0
		for depth: int in _world.labyrinth_view.built_depths():
			for chamber: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
				var holds: bool = sim.expedition.side_quest_in(depth, chamber.index) != &""
				wanted += 1 if holds else 0
				var shown: bool = props.prop(depth, chamber.index) != null
				assert_eq(shown, holds, "%s: d%d c%d matches" % [quest, depth, chamber.index])
		assert_eq(props.prop_count(), wanted, "%s: props match the simulation" % quest)

	# A lone old MICROSKILL_LEARNED: written, but no label and no sound.
	_sound._process(1.0)
	_sound.drain_started()
	var skill: int = Content.microskill_ids().find(&"lockpicker")
	var old := SimEvent.new(SimEvent.Kind.MICROSKILL_LEARNED, _sim.tick - 100, ROGUE, skill, 2)
	_world.sim_event.emit(old)
	assert_null(_label("Learned Lockpicker"), "no label")
	assert_false(_sound.drain_started().has(&"level_up"), "no sound")
	assert_has(_sentences(), "Rogue learned Lockpicker", "but the journal has it")


# --- R11 -----------------------------------------------------------------------


func test_r11_showcase() -> void:
	var moments: Array[StringName] = [
		&"quest_done", &"quest_missed", &"tripwire_sprung", &"microskill_learned"
	]
	for moment: StringName in moments:
		assert_has(Showcase.names(), moment, "%s is a moment" % moment)
		assert_true(Showcase.caption(moment) != "", "%s is labelled" % moment)

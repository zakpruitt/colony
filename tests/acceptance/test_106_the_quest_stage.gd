extends "res://tests/support/side_path_fixture.gd"
## Acceptance tests for specs/106-the-quest-stage/spec.md, one per requirement.
##
## Most find a flat stage whose room holds the quest wanted on its first visit, stand the party
## a step outside it walking in, and play the world frame by frame (a tick every
## FRAMES_PER_TICK frames) as the game does.

const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4
## The second cleric, standing in for the mage.
const SECOND_CLERIC: int = 5
## The level of every hero: each can do every quest of its class.
const LEVEL: int = 6
const WANDERER: StringName = &"hurt_wanderer"
const CHEST: StringName = &"locked_chest"
const STONE: StringName = &"rune_stone"
## The rows R8 adds to the showcase, and the quest each shows.
const ROWS: Dictionary[StringName, StringName] = {
	&"quest_chest": &"locked_chest",
	&"quest_door": &"stuck_door",
	&"quest_stone": &"rune_stone",
	&"quest_wire": &"tripwire",
}
const TWO_CLERICS: StringName = &"two_clerics"
## Each quest's states as R4 names them.
const STATES: Dictionary[StringName, Array] = {
	&"locked_chest": [&"locked", &"open"],
	&"stuck_door": [&"stuck", &"open"],
	&"rune_stone": [&"dim", &"lit", &"rune_1", &"rune_2", &"rune_3", &"rune_4"],
	&"tripwire": [&"taut", &"slack"],
	&"hurt_wanderer": [&"hurt", &"stand", &"walk_0", &"walk_1"],
}
const SHOWCASE_FRAME: float = 1.0 / 30.0

## Where [method _before] put the party: Vector2i(stage, chamber index).
var _at: Vector2i = Vector2i(0, -1)

# --- Helpers -------------------------------------------------------------------


## A flat simulation whose party (every hero at LEVEL) stands a step outside a room holding
## [param quest] on its first visit, walking in, auto-push off. With [param clerics] the mage is
## a second cleric (id SECOND_CLERIC), so two mend.
func _before(quest: StringName, clerics: bool = false) -> Simulation:
	for seed_value: int in range(1, 1000):
		var sim := Simulation.new(seed_value)
		var e: Expedition = sim.expedition
		for depth: int in range(1, 4):
			for room: LabyrinthChamber in sim.labyrinth.level(depth).chambers:
				if e.quest_in(depth, room.index) != quest:
					continue
				sim.set_auto_push(false)
				e.depth = depth
				e.target_depth = depth
				e.deepest_depth = depth
				e.x = room.rect.position.x - 0.1
				e.facing = 1
				if clerics:
					var at: int = sim.party.heroes.find(sim.party.hero(MAGE))
					sim.party.heroes[at] = Hero.new(SECOND_CLERIC, Content.hero_class(&"cleric"))
				raise_party(sim, LEVEL)
				_at = Vector2i(depth, room.index)
				return sim
	fail_test("no seed has a %s on stages 1 to 3" % quest)
	return null


func _working() -> bool:
	return _sim.expedition.state == Expedition.State.WORKING


## Plays frames until every worker of the quest stands at its spot: true, or false after
## [param frames].
func _until_at_spots(frames: int = 600) -> bool:
	for i: int in frames:
		var workers: Array[int] = _world.quest_stage.workers()
		var there: bool = not workers.is_empty()
		for id: int in workers:
			var spot: Vector2 = _world.quest_stage.goal_for(id, Vector2.INF)
			there = there and _world.character(id).position.distance_to(spot) <= 0.5
		if there:
			return true
		_play_frame()
	return false


## The way the sprite of hero [param id] faces: 1 right, -1 left.
func _facing(id: int) -> int:
	return _world.character(id)._facing


## The x of the walls of [param room]'s open floor as [param view] draws it, in world pixels,
## found from its shape.
func _walls(view: LabyrinthView, stage: int, room: LabyrinthChamber) -> Vector2:
	var shape: RoomShape = view.shapes(stage).shape_of(room)
	var row: int = room.floor_row()
	var middle: int = (room.rect.position.x + room.rect.end.x) / 2
	var left: int = middle
	var right: int = middle
	while left > room.rect.position.x and shape.is_open(Vector2i(left - 1, row)):
		left -= 1
	while right < room.rect.end.x and shape.is_open(Vector2i(right, row)):
		right += 1
	return Vector2(left, right) * TILE


# --- R1 ------------------------------------------------------------------------


func test_r1_the_prop_stands_on_the_far_side() -> void:
	var headings: Dictionary[int, bool] = {}
	var tried: int = 0
	for seed_value: int in range(1, 9):
		var winding: Simulation = winding_simulation(seed_value)
		for stage: int in range(1, 4):
			var view: LabyrinthView = zoned_view(winding.labyrinth, stage)
			var level: LabyrinthLevel = winding.labyrinth.level(stage)
			for room: LabyrinthChamber in level.chambers:
				var walls: Vector2 = _walls(view, stage, room)
				if walls.y - walls.x < QuestProps.NARROW_TILES * TILE:
					continue
				var what: String = "seed %d stage %d room %d" % [seed_value, stage, room.index]
				var halfway: float = (walls.x + walls.y) / 2.0
				var line: StageCourse = level.course
				var heading: int = line.heading_at(line.distance_in(room.index, halfway / TILE))
				var spot: Vector2 = QuestProps.spot_in(view, stage, room.index)
				assert_eq(spot.y, WorldPlaces.floor_line(room), "%s: on the floor line" % what)
				assert_gt((spot.x - halfway) * heading, 0.0, "%s: past the middle" % what)
				assert_gte(spot.x, walls.x + 2 * TILE, "%s: 2 tiles from the left wall" % what)
				assert_lte(spot.x, walls.y - 2 * TILE, "%s: 2 tiles from the right wall" % what)
				headings[heading] = true
				tried += 1
	assert_gt(tried, 20, "many wide rooms tried")
	assert_true(headings.has(1) and headings.has(-1), "rooms walked each way")

	# The world stands each prop on its spot.
	var sim: Simulation = _before(CHEST)
	_show(sim)
	_play_frame(false)
	var prop: Sprite2D = _world.quest_props.prop(_at.x, _at.y)
	assert_not_null(prop, "the chest's prop")
	if prop != null:
		var spot: Vector2 = QuestProps.spot_in(_world.labyrinth_view, _at.x, _at.y)
		assert_eq(prop.position, spot, "the prop stands on its spot")
		var room: LabyrinthChamber = sim.labyrinth.level(_at.x).chambers[_at.y]
		assert_gt(spot.x, (room.rect.position.x + room.rect.end.x) / 2.0 * TILE, "past the middle")

	# A room narrower than 6 tiles keeps it at its middle.
	var narrow: Simulation = Simulation.new(1)
	var flat := zoned_view(narrow.labyrinth, 1)
	var small: LabyrinthChamber = narrow.labyrinth.level(1).chambers[1]
	small.rect.size.x = QuestProps.NARROW_TILES - 1
	var at: Vector2 = QuestProps.spot_in(flat, 1, small.index)
	var middle: float = floorf((small.rect.position.x + small.rect.end.x) / 2.0) * TILE
	assert_eq(at, Vector2(middle, WorldPlaces.floor_line(small)), "a narrow room: the middle")


# --- R2 ------------------------------------------------------------------------


func test_r2_every_worker_works_at_the_prop() -> void:
	var sim: Simulation = _before(WANDERER, true)
	if sim == null:
		return
	_show(sim)
	var swings: Dictionary[int, Array] = {}
	_world.quest_props.worked.connect(
		func(id: int) -> void:
			if not swings.has(id):
				swings[id] = []
			swings[id].append(_frames_played)
	)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the clerics find the wanderer")
	assert_eq(_world.quest_stage.workers(), [CLERIC, SECOND_CLERIC] as Array[int], "both work")
	assert_true(_until_at_spots(), "both reach their spots")
	var prop: float = _world.quest_props.spot(_at.x, _at.y).x
	var back: int = -PartyPlaces.world_facing(sim.expedition)
	var lead: CharacterSprite = _world.character(CLERIC)
	var second: CharacterSprite = _world.character(SECOND_CLERIC)
	assert_almost_eq(lead.position.x, prop + back * QuestProps.WORK_GAP, 0.5, "the lead's spot")
	assert_almost_eq(second.position.x, prop - back * QuestProps.WORK_GAP, 0.5, "the second's")
	assert_ne(signf(lead.position.x - prop), signf(second.position.x - prop), "one each side")
	assert_eq(_facing(CLERIC), signi(roundi(prop - lead.position.x)), "the lead faces the prop")
	assert_eq(_facing(SECOND_CLERIC), signi(roundi(prop - second.position.x)), "so does the second")
	for i: int in 150:
		_play_frame()
	assert_true(_working(), "still working")
	assert_eq(swings.keys().size(), 2, "only the workers work: %s" % [swings.keys()])
	var lead_swings: Array = swings.get(CLERIC, [])
	var second_swings: Array = swings.get(SECOND_CLERIC, [])
	assert_gte(lead_swings.size(), 2, "the lead works again and again")
	assert_gte(second_swings.size(), 2, "so does the second")
	# Spec 107: each plays the quest's work_move, not an attack.
	var move: StringName = Content.quest(WANDERER).work_move
	assert_eq(lead.moves.playing(), move, "the lead plays the quest's work_move")
	assert_eq(second.moves.playing(), move, "so does the second")
	assert_false(lead.is_attacking() or second.is_attacking(), "neither attacks")
	for frame: int in lead_swings:
		assert_false(second_swings.has(frame), "not on the same frame")

	# A gate: one opener, and nobody sits.
	var found: Vector2i = _find(1, false)
	var gated: Simulation = winding_simulation(found.x)
	for i: int in 4:
		var twin := Hero.new(5 + i, Content.hero_class(gated.party.heroes[i].class_id))
		gated.party.heroes.append(twin)
	raise_party(gated, 12)
	_stand_before(gated, 1, found.y, 1)
	_show(gated)
	var opened: Dictionary[int, bool] = {}
	_world.quest_props.worked.connect(func(id: int) -> void: opened[id] = true)
	assert_true(_play_until(SimEvent.Kind.GATE_STARTED, 200), "the party opens a gate")
	var opener: int = gated.expedition.worker_id()
	for i: int in 120:
		_play_frame()
		assert_false(_world.quest_stage.is_working(), "a gate is no quest")
		for hero: Hero in gated.party.heroes:
			assert_false(_world.quest_stage.sits(hero.id), "nobody sits at a gate")
	assert_eq(opened.keys(), [opener], "one opener swings")


# --- R3 ------------------------------------------------------------------------


func test_r3_everyone_else_sits() -> void:
	var sim: Simulation = _before(WANDERER, true)
	if sim == null:
		return
	_show(sim)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the clerics start")
	assert_true(_until_at_spots(), "at their spots")
	for i: int in 30:
		_play_frame()
	var prop: float = _world.quest_props.spot(_at.x, _at.y).x
	for id: int in [KNIGHT, ROGUE]:
		var sprite: CharacterSprite = _world.character(id)
		assert_true(sprite.sitting, "hero %d sits" % id)
		assert_eq(sprite.position, _world._goals[id], "hero %d stays where it stopped" % id)
		assert_eq(_facing(id), 1 if prop >= sprite.position.x else -1, "and faces the prop")
	for id: int in [CLERIC, SECOND_CLERIC]:
		assert_false(_world.character(id).sitting, "cleric %d works on its feet" % id)
	assert_false(_world.camp.is_shown(), "no campfire, no bedrolls")
	# The dead are left to the fallen party.
	sim.party.hero(ROGUE).health = 0
	_play_frame(false)
	assert_false(_world.quest_stage.sits(ROGUE), "a dead hero does not sit")
	assert_true(_play_until(SimEvent.Kind.QUEST_DONE), "the wanderer is mended")
	for i: int in 3:
		_play_frame()
	for hero: Hero in sim.party.heroes:
		assert_false(_world.character(hero.id).sitting, "hero %d is up" % hero.id)
	assert_false(_world.camp.is_shown(), "still no camp")


# --- R4 ------------------------------------------------------------------------


func test_r4_the_props_have_states() -> void:
	for quest: StringName in STATES:
		var sheet: PixelSheet = QuestProps.sheet_of(quest)
		assert_not_null(sheet, "%s has a sheet" % quest)
		if sheet == null:
			continue
		var bottom_centre := Vector2i(sheet.size.x / 2, sheet.size.y - 1)
		assert_eq(sheet.pivot, bottom_centre, "%s: its pivot at the bottom centre" % quest)
		for look: StringName in QuestLooks.LOOKS[quest]:
			for state: StringName in STATES[quest]:
				var part := StringName("%s_%s" % [look, state])
				assert_true(sheet.has_part(part), "%s has %s" % [quest, part])
				assert_eq(sheet.part_pivot(part), sheet.pivot, "%s: one pivot" % part)
	assert_eq(QuestProps.sheet_of(WANDERER).size, Vector2i(16, 24), "the wanderer is 16x24")

	# The stone lights a rune for each quarter of the work, and is lit when read.
	var sim: Simulation = _before(STONE)
	if sim == null:
		return
	_show(sim)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the mage reads")
	var props: QuestProps = _world.quest_props
	var seen: Dictionary[int, bool] = {}
	while _working():
		_play_frame()
		if not _working():
			break
		var lit: int = floori(sim.expedition.work_progress() * 4.0)
		var overlay: StringName = props.overlay_of(_at.x, _at.y)
		assert_eq(overlay, &"" if lit == 0 else StringName("rune_%d" % lit), "runes at quarters")
		assert_eq(props.part_of(_at.x, _at.y), &"dim", "the stone is dim under them")
		seen[lit] = true
	assert_eq(seen.keys(), [0, 1, 2, 3], "0 to 3 runes while read")
	_play_frame(false)
	assert_eq(props.part_of(_at.x, _at.y), &"lit", "then all of them: lit")
	assert_eq(props.overlay_of(_at.x, _at.y), &"", "no overlay over the lit stone")


# --- R5 ------------------------------------------------------------------------


func test_r5_a_done_prop_stays_and_the_wanderer_leaves() -> void:
	var sim: Simulation = _before(CHEST)
	if sim == null:
		return
	_show(sim)
	var props: QuestProps = _world.quest_props
	assert_eq(props.part_of(_at.x, _at.y), &"locked", "locked while it waits")
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the rogue picks the lock")
	assert_eq(props.part_of(_at.x, _at.y), &"locked", "and while it is worked")
	assert_true(_play_until(SimEvent.Kind.QUEST_DONE), "open")
	_play_frame()
	assert_eq(props.part_of(_at.x, _at.y), &"open", "the lid is up")
	assert_true(props.is_done(_at.x, _at.y), "a done prop")
	assert_null(props.prop(_at.x, _at.y), "no longer a waiting one")
	for i: int in 600:
		_play_frame()
	assert_eq(sim.expedition.depth, _at.x, "the party is on the same stage")
	assert_eq(props.part_of(_at.x, _at.y), &"open", "still open 10 s later")
	# Off to another stage: it goes.
	var e: Expedition = sim.expedition
	var next: int = _at.x + 1
	Arrival.from_save(e, sim.tick, next, maxi(next, e.deepest_depth), next, false)
	for i: int in 600:
		if _world.shown_stage() == next:
			break
		_play_frame()
	assert_eq(_world.shown_stage(), next, "the world shows the next stage")
	assert_eq(props.part_of(_at.x, _at.y), &"", "the open chest is gone")
	assert_false(props.is_done(_at.x, _at.y), "no longer done")

	# The wanderer stands, then walks off the way the party came, and goes.
	sim = _before(WANDERER, true)
	_show(sim)
	props = _world.quest_props
	assert_true(_play_until(SimEvent.Kind.QUEST_DONE), "the wanderer is mended")
	var way: int = -PartyPlaces.world_facing(sim.expedition)
	_play_frame()
	var key := Vector2i(_at.x, _at.y)
	assert_eq(props.part_of(key.x, key.y), &"stand", "it stands")
	assert_true(props.is_done(key.x, key.y), "done while it is there")
	var body: Sprite2D = props._done[key].sprite
	var from: float = body.position.x
	var parts: Dictionary[StringName, bool] = {}
	for i: int in 30:
		_play_frame()
	assert_eq(body.position.x, from, "it stands still for 0.6 s")
	var room: LabyrinthChamber = sim.labyrinth.level(key.x).chambers[key.y]
	var last: float = from
	for i: int in 900:
		if not props.is_done(key.x, key.y):
			break
		parts[props.part_of(key.x, key.y)] = true
		last = body.position.x
		_play_frame()
		if props.is_done(key.x, key.y):
			assert_true((body.position.x - last) * way >= 0.0, "it walks one way only")
	assert_true(parts.has(&"walk_0") and parts.has(&"walk_1"), "its steps: %s" % [parts.keys()])
	assert_gt((last - from) * way, 0.0, "back the way the party came")
	assert_false(props.is_done(key.x, key.y), "gone once out of its room")
	var edge: float = (room.rect.position.x if way < 0 else room.rect.end.x) * TILE
	assert_lt(absf(last - edge), 4.0, "at its room's edge")


# --- R6 ------------------------------------------------------------------------


func test_r6_late_events_snap() -> void:
	for quest: StringName in [CHEST, WANDERER]:
		var sim: Simulation = _before(quest, quest == WANDERER)
		if sim == null:
			return
		_show(sim)
		assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "%s worked" % quest)
		# Unwatched to the end of the work and on, then one frame catches up.
		while _working():
			sim.step()
		for i: int in World.STALL_TICKS + 2:
			sim.step()
		_play_frame(false)
		var props: QuestProps = _world.quest_props
		if quest == CHEST:
			assert_eq(props.part_of(_at.x, _at.y), &"open", "the chest is open at once")
			assert_true(props.is_done(_at.x, _at.y), "and done")
		else:
			assert_eq(props.part_of(_at.x, _at.y), &"", "no wanderer at all")
			assert_false(props.is_done(_at.x, _at.y), "none walking off")
			assert_eq(props.find_children(String(WANDERER), "Sprite2D", false, false).size(), 0)
	# A wanderer already walking off when a catch-up comes is gone with it.
	var again: Simulation = _before(WANDERER, true)
	if again == null:
		return
	_show(again)
	assert_true(_play_until(SimEvent.Kind.QUEST_DONE), "mended in view")
	for i: int in 30:
		_play_frame()
	var shown: QuestProps = _world.quest_props
	assert_true(shown.is_done(_at.x, _at.y), "(walking off)")
	for i: int in World.STALL_TICKS + 2:
		again.step()
	_play_frame(false)
	assert_false(shown.is_done(_at.x, _at.y), "the walking wanderer is gone after a catch-up")


# --- R7 ------------------------------------------------------------------------


func test_r7_the_bar_over_the_prop() -> void:
	for clerics: bool in [true, false]:
		var sim: Simulation = _before(WANDERER, clerics)
		if sim == null:
			return
		_show(sim)
		assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "mending")
		for i: int in 10:
			_play_frame()
		var props: QuestProps = _world.quest_props
		var prop: Vector2 = props.spot(_at.x, _at.y)
		var middle: float = props._bar_at.x + QuestProps.BAR_SIZE.x / 2.0
		assert_almost_eq(middle, prop.x, 1.0, "the bar's middle over the prop")
		assert_eq(props._bar_at.y, prop.y - QuestProps.BAR_RAISE, "BAR_RAISE above the floor")
		# Spec 107: the microskill's name moves into the story; the bar stays.
		assert_eq(props.worker_label(), "", "no name over the bar")


# --- R8 ------------------------------------------------------------------------


func test_r8_the_showcase_shows_each_quest() -> void:
	var names: Array[StringName] = Showcase.names()
	assert_false(names.has(&"quest_done"), "the one quest row is replaced")
	for moment: StringName in ROWS:
		assert_has(names, moment, "%s is a row" % moment)
		assert_true(Showcase.caption(moment).begins_with("A QUEST: "), "%s's caption" % moment)
		assert_eq(ShowcaseMoments.QUEST_OF[moment], ROWS[moment], "%s's quest" % moment)
	assert_eq(Showcase.caption(TWO_CLERICS), "TWO CLERICS MEND A WANDERER", "the clerics' row")
	var scene: PackedScene = load("res://game/dev/showcase.tscn")
	var showcase: Showcase = scene.instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	var workers: int = 0
	for moment: StringName in [
		&"quest_chest", &"quest_door", &"quest_stone", &"quest_wire", TWO_CLERICS
	]:
		showcase.skip_to(moment)
		var limit: float = showcase.elapsed + 30.0
		while showcase.moment() == moment and showcase.elapsed < limit:
			showcase.advance(SHOWCASE_FRAME)
			if moment == TWO_CLERICS:
				workers = maxi(workers, showcase.main.world.quest_stage.workers().size())
		var seen: bool = showcase.evidence.get(moment, false)
		assert_true(seen, "%s was seen" % moment)
	assert_eq(workers, 2, "two clerics worked")


# --- R9 ------------------------------------------------------------------------


func test_r9_each_room_looks_its_own() -> void:
	var spot := Vector2(400, 160)
	var span := Vector2(160, 640)
	for quest: StringName in STATES:
		var kinds: Dictionary[String, bool] = {}
		for chamber: int in 40:
			var looks: QuestLooks = QuestLooks.choose(
				&"mossy_hollow", 1 + chamber / 6, chamber % 6, quest, spot, span
			)
			kinds["%s %d %s" % [looks.look, looks.tint, looks.mirrored]] = true
			assert_between(looks.dressing.size(), 1, 3, "%s: 1 to 3 pieces" % quest)
			for piece: StringName in looks.dressing:
				assert_has(QuestLooks.DRESSING[quest], piece, "%s's own dressing" % quest)
		assert_gte(kinds.size(), 3, "%s shows %d ways" % [quest, kinds.size()])
		for look: StringName in QuestLooks.LOOKS[quest]:
			for state: StringName in STATES[quest]:
				var part := StringName("%s_%s" % [look, state])
				assert_true(QuestProps.sheet_of(quest).has_part(part), "%s has %s" % [quest, part])

	# No dressing on a work spot, nor off the open floor, in any room of a winding stage.
	for seed_value: int in range(1, 4):
		var sim: Simulation = winding_simulation(seed_value)
		var view: LabyrinthView = zoned_view(sim.labyrinth, 2)
		for room: LabyrinthChamber in sim.labyrinth.level(2).chambers:
			var at: Vector2 = QuestProps.spot_in(view, 2, room.index)
			var walls: Vector2 = QuestProps.floor_span(view, 2, room.index)
			for quest: StringName in STATES:
				var looks: QuestLooks = QuestProps.looks_in(view, 2, room.index, quest)
				for box: Rect2 in looks.dressing_rects(at):
					assert_gte(box.position.x, walls.x, "on the floor")
					assert_lte(box.end.x, walls.y, "on the floor")
					assert_gte(box.position.x, at.x - 2 * TILE, "within 2 tiles of the prop")
					assert_lte(box.end.x, at.x + 2 * TILE, "within 2 tiles of the prop")
					for gap: float in [
						QuestProps.WORK_GAP, QuestProps.WORK_GAP + QuestStage.BEHIND
					]:
						for side: float in [-1.0, 1.0]:
							var work: float = at.x + side * gap
							assert_false(
								work >= box.position.x and work < box.end.x,
								(
									"seed %d room %d: no %s dressing on a work spot"
									% [seed_value, room.index, quest]
								)
							)

	# The same chamber built twice shows the same look and dressing.
	var shown: Array = []
	for twice: int in 2:
		var sim: Simulation = _before(CHEST)
		_show(sim)
		_play_frame(false)
		var props: QuestProps = _world.quest_props
		var looks: QuestLooks = props.looks_of(_at.x, _at.y)
		var pieces: Array = []
		for piece: Sprite2D in props.dressing_of(_at.x, _at.y):
			pieces.append([piece.name, piece.global_position])
		var prop: Sprite2D = props.prop(_at.x, _at.y)
		shown.append([looks.look, looks.tint, looks.mirrored, prop.flip_h, pieces])
		assert_eq(pieces.size(), looks.dressing.size(), "each piece of dressing is shown")
		assert_eq(prop.material, looks.material(), "with its tint")
	var first: Array = shown[0]
	var second: Array = shown[1]
	assert_eq(str(first), str(second), "the same both times")
	# Chosen from the area, the depth and the chamber, never the simulation's stream: games of
	# two seeds show their first chamber's chest of stage 2 the same way.
	var chosen: Array[String] = []
	for seed_value: int in [11, 29]:
		var sim: Simulation = winding_simulation(seed_value)
		var view: LabyrinthView = zoned_view(sim.labyrinth, 2)
		var looks: QuestLooks = QuestProps.looks_in(view, 2, 0, CHEST)
		chosen.append("%s %d %s" % [looks.look, looks.tint, looks.mirrored])
	assert_eq(chosen[0], chosen[1], "the same look in games of different seeds")

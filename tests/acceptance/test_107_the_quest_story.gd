extends "res://tests/support/play_fixture.gd"
## Acceptance tests for specs/107-the-quest-story/spec.md, one per requirement.
##
## Most find a flat stage whose room holds the quest wanted on its first visit, stand the party a
## step outside it walking in, and play the world frame by frame (a tick every FRAMES_PER_TICK
## frames) as the game does, with bubbles for the world to speak in.

const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4
## The level of every hero: each can do every quest of its class.
const LEVEL: int = 6
const WANDERER: StringName = &"hurt_wanderer"
const CHEST: StringName = &"locked_chest"
const DOOR: StringName = &"stuck_door"
const STONE: StringName = &"rune_stone"
const WIRE: StringName = &"tripwire"
## Each quest's pose, as R1 names it.
const POSES: Dictionary[StringName, StringName] = {
	&"locked_chest": &"kneel_work",
	&"tripwire": &"kneel_work",
	&"stuck_door": &"push",
	&"rune_stone": &"read",
	&"hurt_wanderer": &"tend",
}
## The beats of a story in the order R5 tells them on a wanderer mended by one cleric.
const STORY: Array[StringName] = [
	&"plea", &"arrive", &"work", &"watch", &"work", &"done", &"thanks"
]
const FRAME: float = 1.0 / 60.0

## Where [method _party_before] put the party: Vector2i(stage, chamber index).
var _at: Vector2i = Vector2i(0, -1)
var _bubbles: SpeechBubbles

# --- Helpers -------------------------------------------------------------------


## A flat simulation whose party (every hero at LEVEL) stands a step outside a room holding
## [param quest] on its first visit, walking in, auto-push off.
func _party_before(quest: StringName) -> Simulation:
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
				raise_party(sim, LEVEL)
				_at = Vector2i(depth, room.index)
				return sim
	fail_test("no seed has a %s on stages 1 to 3" % quest)
	return null


## The world over [param sim] at [param speed], with its effects and bubbles to speak in.
func _show_talking(sim: Simulation, speed: int = 1) -> void:
	_show(sim, speed, true)
	_bubbles = SpeechBubbles.new()
	add_child_autofree(_bubbles)
	_world.bubbles = _bubbles


func _story() -> QuestStory:
	return _world.quest_props.story


func _is_working() -> bool:
	return _sim.expedition.state == Expedition.State.WORKING


## True when hero [param id]'s sprite stands at its work spot.
func _at_spot(id: int) -> bool:
	var sprite: CharacterSprite = _world.character(id)
	var spot: Vector2 = _world.quest_stage.goal_for(id, Vector2.INF)
	return spot.is_finite() and sprite.position.distance_to(spot) <= QuestProps.ARRIVED


## The beat of [param def]'s line [param text], or &"" when it has none.
static func _beat_of(def: QuestDef, text: String) -> StringName:
	for line: QuestLine in def.lines:
		if line.text == text:
			return line.beat
	return &""


static func _line_of(def: QuestDef, text: String) -> QuestLine:
	for line: QuestLine in def.lines:
		if line.text == text:
			return line
	return null


## Plays a wanderer quest from before the room to a second after its thanks at [param speed],
## and returns each new line said, in order, as [speaker, text]: the speaker a hero id, or -1
## for the wanderer.
func _story_lines(speed: int) -> Array[Array]:
	var said: Array[Array] = []
	var sim: Simulation = _party_before(WANDERER)
	if sim == null:
		return said
	_show_talking(sim, speed)
	var shown: Dictionary[int, String] = {}
	var done_for: int = -1
	for i: int in 3000:
		_play_frame()
		var speakers: Dictionary[int, Variant] = {-1: _story().subject()}
		for hero: Hero in sim.party.heroes:
			speakers[hero.id] = hero.id
		for key: int in speakers:
			var text: String = _bubbles.line_of(speakers[key])
			if text != "" and text != shown.get(key, ""):
				said.append([key, text])
			shown[key] = text
		if done_for < 0 and _world.quest_props.is_done(_at.x, _at.y):
			done_for = 0
		if done_for >= 0:
			done_for += 1
			if done_for > 90:
				break
	return said


# --- R1 ------------------------------------------------------------------------


func test_r1_each_job_has_its_pose() -> void:
	var loops: Array[StringName] = [&"kneel_work", &"push", &"read", &"tend"]
	for quest: StringName in Content.quest_ids():
		assert_eq(Content.quest(quest).work_move, POSES[quest], "%s's work_move" % quest)
		assert_has(loops, Content.quest(quest).work_move, "%s: one of the four poses" % quest)

	# Each pose keeps the feet on the floor line, moves, and begins one cycle a cycle.
	for move: StringName in loops:
		var moves := CharacterMoves.new()
		moves.play(move, 0.0, INF, 1.0)
		var began: int = moves.cycles
		var moved: bool = false
		var cycle: float = CharacterMoves.LOOPS[move]
		for i: int in roundi(cycle / FRAME) * 2 + 1:
			moves.advance(FRAME)
			var lift: float = absf(sin(moves.turn)) * CharacterMoves.FOOT_REACH
			assert_almost_eq(moves.shift.y, -lift, 0.001, "%s: the feet stay down" % move)
			moved = moved or not moves.at_rest()
		assert_true(moved, "%s moves" % move)
		assert_eq(moves.playing(), move, "%s loops on" % move)
		assert_eq(moves.cycles - began, 2, "%s: a cycle each %s s" % [move, cycle])

	# The knight shoulders the stuck door, not with a swing, and works once a cycle.
	var sim: Simulation = _party_before(DOOR)
	if sim == null:
		return
	_show(sim)
	var worked: Array[int] = []
	_world.quest_props.worked.connect(func(id: int) -> void: worked.append(id))
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the knight finds the door")
	var lead: int = sim.expedition.worker_id()
	for i: int in 600:
		if _at_spot(lead):
			break
		_play_frame()
	_play_frame()
	var knight: CharacterSprite = _world.character(lead)
	assert_eq(knight.moves.playing(), &"push", "the knight pushes")
	worked.clear()
	var cycles: int = knight.moves.cycles
	var frames: int = 0
	var feet_y: float = knight.position.y
	while _is_working() and frames < 150:
		_play_frame()
		frames += 1
		assert_false(knight.is_attacking(), "not an attack")
		assert_eq(knight.position.y, feet_y, "on the floor line")
	assert_eq(knight.moves.playing(), &"push", "still pushing")
	assert_gte(knight.moves.cycles - cycles, 2, "push after push")
	assert_eq(worked.count(lead), knight.moves.cycles - cycles, "worked once a cycle")


# --- R2 ------------------------------------------------------------------------


func test_r2_the_wanderer_is_healed() -> void:
	var sim: Simulation = _party_before(WANDERER)
	if sim == null:
		return
	_show_talking(sim)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the cleric finds the wanderer")
	var spot: Vector2 = _world.quest_props.spot(_at.x, _at.y)
	var cleric: CharacterSprite = _world.character(CLERIC)
	var prayers: Array[float] = []
	var praying: bool = false
	var light_on_wanderer: bool = false
	var sparkles: int = 0
	while _is_working():
		var progress: float = sim.expedition.work_progress()
		_play_frame()
		var now: bool = cleric.moves.playing() == &"prayer"
		if now and not praying:
			prayers.append(progress)
		praying = now
		# Only while the work goes on: DONE lights a wanderer no prayer lit, and must not hide it.
		var lights: Array[Node2D] = []
		if _is_working():
			lights = _world.fx.nodes(&"spell")
		for node: Node2D in lights:
			var bit := node as FxParticle
			if bit != null and bit.kind == &"light_column":
				light_on_wanderer = light_on_wanderer or absf(bit.position.x - spot.x) <= 4.0
		for node: Node2D in _world.fx.nodes(&"quest"):
			var bit := node as FxParticle
			if bit != null and bit.kind == &"heal_sparkle":
				assert_almost_eq(bit.position.x, spot.x, 8.0, "a sparkle over the wanderer")
				sparkles += 1
	assert_eq(prayers.size(), 1, "the cleric prays once")
	if not prayers.is_empty():
		assert_gte(prayers[0], 0.74, "past three quarters of the work")
	assert_true(light_on_wanderer, "the heal light stands on the wanderer before it is done")
	assert_gt(sparkles, 0, "small heal sparkles while it is tended")


# --- R3 ------------------------------------------------------------------------


func test_r3_each_job_ends_visibly() -> void:
	# The chest spills coins, which fly to the hero who opened it.
	assert_true(_quest_done(CHEST), "the chest opens")
	var coins: int = _effects_of(FxCoin)
	assert_between(coins, 5, 8, "5 to 8 coins out of the chest")
	var opener: int = -1
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.QUEST_DONE:
			opener = event.source_id
	assert_eq(opener, ROGUE, "the rogue opened it")
	var chest: Vector2 = _world.feet_position(opener) + Vector2(0, -QuestEffects.CHEST_HEIGHT)
	for node: Node2D in _world.fx.nodes(&"quest"):
		var coin := node as FxCoin
		if coin != null:
			var goal: Vector2 = coin.target.call()
			assert_eq(goal, chest, "a coin flies to the opener")
	# The stone sends a mote to each living hero, and its runes flare.
	assert_true(_quest_done(STONE), "the stone is read")
	assert_eq(_effects_of(FxMote), _sim.party.heroes.size(), "a mote for each living hero")
	assert_gt(_particles_of(&"rune_flare"), 0, "the runes flare")
	# The wire snips.
	assert_true(_quest_done(WIRE), "the wire is cut")
	assert_gt(_particles_of(&"snip"), 0, "a snip spark")
	# Each shove at the door puffs dust at its foot.
	var sim: Simulation = _party_before(DOOR)
	if sim == null:
		return
	_show(sim, 1, true)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the door")
	var dust: Dictionary[Node2D, bool] = {}
	var foot: Vector2 = _world.quest_props.spot(_at.x, _at.y)
	for i: int in 180:
		_play_frame()
		for node: Node2D in _world.fx.nodes(&"quest"):
			var bit := node as FxParticle
			if bit != null and bit.kind == &"door_dust" and not dust.has(bit):
				assert_almost_eq(bit.position.y, foot.y, 4.0, "at the door's foot")
				dust[bit] = true
	assert_gt(dust.size(), 0, "dust puffs as the door is shoved")

	# A DONE seen only after a stall adds nothing.
	sim = _party_before(CHEST)
	_show(sim, 1, true)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the chest again")
	while _is_working():
		sim.step()
	for i: int in World.STALL_TICKS + 2:
		sim.step()
	_play_frame(false)
	assert_eq(_effects_of(FxCoin), 0, "no coins for a stale DONE")


## Plays [param quest] from before its room to the frame its DONE is heard: true when it was.
func _quest_done(quest: StringName) -> bool:
	var sim: Simulation = _party_before(quest)
	if sim == null:
		return false
	_show(sim, 1, true)
	return _play_until(SimEvent.Kind.QUEST_DONE)


## The quest effects of class [param kind] showing.
func _effects_of(kind: Variant) -> int:
	var found: int = 0
	for node: Node2D in _world.fx.nodes(&"quest"):
		if is_instance_of(node, kind):
			found += 1
	return found


func _particles_of(kind: StringName) -> int:
	var found: int = 0
	for node: Node2D in _world.fx.nodes(&"quest"):
		var bit := node as FxParticle
		if bit != null and bit.kind == kind:
			found += 1
	return found


# --- R4 ------------------------------------------------------------------------


func test_r4_the_lines_are_data() -> void:
	var total: int = 0
	for quest: StringName in Content.quest_ids():
		var def: QuestDef = Content.quest(quest)
		assert_eq(def.validate(), PackedStringArray(), "%s validates" % quest)
		total += def.lines.size()
		var watch: int = def.lines_for(&"watch", &"watcher", &"").size()
		assert_gte(watch, 2, "%s has 2 watch lines" % quest)
	assert_between(total, 50, 80, "about 60 lines")

	var wanderer: QuestDef = Content.quest(WANDERER)
	var bad_beat: QuestDef = wanderer.duplicate(true)
	bad_beat.lines[0].beat = &"dance"
	_reported(bad_beat, "dance", "a beat that is no beat")
	var bad_speaker: QuestDef = wanderer.duplicate(true)
	bad_speaker.lines[0].speaker = &"narrator"
	_reported(bad_speaker, "narrator", "a speaker that is none")
	var bad_class: QuestDef = wanderer.duplicate(true)
	bad_class.lines[0].class_id = &"bard"
	_reported(bad_class, "bard", "a class that is no hero class")
	var long: QuestDef = wanderer.duplicate(true)
	long.lines[0].text = "x".repeat(49)
	_reported(long, "48", "a 49-character line")
	var few: QuestDef = Content.quest(CHEST).duplicate(true)
	var kept: Array[QuestLine] = []
	for line: QuestLine in few.lines:
		if line.beat != &"arrive":
			kept.append(line)
	few.lines = kept
	_reported(few, "arrive", "too few arrive lines")
	var no_plea: QuestDef = wanderer.duplicate(true)
	var pleas: Array[QuestLine] = []
	for line: QuestLine in no_plea.lines:
		if line.beat != &"plea":
			pleas.append(line)
	no_plea.lines = pleas
	_reported(no_plea, "plea", "a wanderer with no pleas")

	# Class-tagged lines come first, then the lines for anyone.
	var fit: Array[QuestLine] = wanderer.lines_for(&"arrive", &"worker", &"cleric")
	assert_gt(fit.size(), 2, "the arrive lines a cleric may say")
	assert_eq(fit[0].class_id, &"cleric", "a cleric's own first")
	var last: QuestLine = fit.back()
	assert_eq(last.class_id, &"", "then anyone's")
	for line: QuestLine in wanderer.lines_for(&"arrive", &"worker", &"knight"):
		assert_eq(line.class_id, &"", "a knight gets no cleric's line")


func _reported(def: QuestDef, word: String, what: String) -> void:
	var problems: PackedStringArray = def.validate()
	assert_gt(problems.size(), 0, "%s is reported" % what)
	assert_string_contains("\n".join(problems), word, what)


# --- R5 ------------------------------------------------------------------------


func test_r5_the_lines_come_at_the_beats() -> void:
	var said: Array[Array] = _story_lines(1)
	var def: QuestDef = Content.quest(WANDERER)
	var beats: Array[StringName] = []
	for entry: Array in said:
		var speaker: int = entry[0]
		var text: String = entry[1]
		var line: QuestLine = _line_of(def, text)
		assert_not_null(line, "'%s' is one of the wanderer's lines" % text)
		if line == null:
			continue
		beats.append(line.beat)
		match line.speaker:
			&"subject":
				assert_eq(speaker, -1, "the wanderer says '%s'" % line.text)
			&"worker":
				assert_eq(speaker, CLERIC, "the cleric says '%s'" % line.text)
				var mine: Array[QuestLine] = def.lines_for(line.beat, &"worker", &"cleric")
				if mine[0].class_id == &"cleric":
					assert_eq(line.class_id, &"cleric", "a cleric's own line for %s" % line.beat)
			&"watcher":
				assert_has([KNIGHT, ROGUE, MAGE], speaker, "a sitting hero says '%s'" % line.text)
	assert_eq(beats, STORY, "the story in its order")
	assert_eq(_story_lines(1), said, "the same moment says the same lines")

	var fast: Array[StringName] = []
	for entry: Array in _story_lines(4):
		var text: String = entry[1]
		fast.append(_beat_of(def, text))
	assert_eq(fast, [&"plea", &"done", &"thanks"] as Array[StringName], "at speed 4")


# --- R6 ------------------------------------------------------------------------


func test_r6_the_name_moves_into_the_story() -> void:
	var sim: Simulation = _party_before(WANDERER)
	if sim == null:
		return
	_show_talking(sim)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "mending")
	var props: QuestProps = _world.quest_props
	var def: QuestDef = Content.quest(WANDERER)
	var arrived: String = ""
	var named: String = ""
	while _is_working() and arrived == "":
		_play_frame()
		if named == "":
			named = props.worker_label()
		var line: QuestLine = _line_of(def, _bubbles.line_of(CLERIC))
		if line != null and line.beat == &"arrive":
			arrived = line.text
	assert_eq(named, "", "no microskill's name over the bar")
	assert_gt(props.bar_fraction(), 0.0, "the bar stays")
	assert_ne(arrived, "", "the arrive line shows over the lead")
	assert_true(_at_spot(CLERIC), "as the lead reaches its spot")


# --- R7 ------------------------------------------------------------------------


func test_r7_late_events_stay_quiet() -> void:
	var sim: Simulation = _party_before(WANDERER)
	if sim == null:
		return
	_show_talking(sim)
	_play_frame()
	# The party reaches the wanderer during a stall: nothing it says or does is started late.
	while not _is_working():
		sim.step()
	for i: int in World.STALL_TICKS + 2:
		sim.step()
	_play_frame(false)
	var cleric: CharacterSprite = _world.character(CLERIC)
	assert_eq(_bubbles.shown_count(), 0, "no bubble for the stale start")
	assert_eq(cleric.moves.playing(), &"", "no pose in the catch-up")

	# A worker still walking plays no pose; once there, it tends; a stall stops it.
	sim = _party_before(WANDERER)
	_show_talking(sim)
	assert_true(_play_until(SimEvent.Kind.QUEST_STARTED, 60), "the cleric finds the wanderer")
	cleric = _world.character(CLERIC)
	var walked: int = 0
	while not _at_spot(CLERIC) and walked < 600:
		assert_eq(cleric.moves.playing(), &"", "no pose while walking over")
		_play_frame()
		walked += 1
	assert_gt(walked, 0, "the cleric walked over")
	for i: int in 30:
		_play_frame()
	assert_eq(cleric.moves.playing(), &"tend", "it tends")
	for i: int in World.STALL_TICKS + 2:
		sim.step()
	_play_frame(false)
	assert_eq(cleric.moves.playing(), &"", "a catch-up stops the pose")
	assert_eq(_bubbles.shown_count(), 0, "and clears the bubbles")

	# A stall across the start and past half the work: what it passed is not told late.
	sim = _party_before(WANDERER)
	sim.expedition.x -= 2.0  # far enough out that the world sees the party before it starts
	_show_talking(sim)
	_play_frame()
	assert_false(_is_working(), "the world has seen the party before the work")
	while not _is_working():
		sim.step()
	while sim.expedition.work_progress() < 0.51:
		sim.step()
	_play_frame(false)
	var def: QuestDef = Content.quest(WANDERER)
	var posed: bool = false
	var late: Array[StringName] = []
	var prayed: bool = false
	for i: int in 90:
		_play_frame()
		posed = posed or _world.character(CLERIC).moves.playing() == &"tend"
		prayed = prayed or _world.character(CLERIC).moves.playing() == &"prayer"
		for hero: Hero in sim.party.heroes:
			var line: QuestLine = _line_of(def, _bubbles.line_of(hero.id))
			if line != null and line.beat in [&"work", &"watch"] and not late.has(line.beat):
				late.append(line.beat)
	assert_eq(late, [] as Array[StringName], "no work or watch line told late")
	assert_false(prayed, "no prayer")
	assert_true(posed, "the cleric reached the wanderer and tended")
	assert_lt(sim.expedition.work_progress(), 2.0 / 3.0, "still short of the next beat")

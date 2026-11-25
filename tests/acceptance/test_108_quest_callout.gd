extends "res://tests/support/play_fixture.gd"
## Acceptance tests for specs/108-quest-callout/spec.md, one per requirement.
##
## Most find a flat stage whose room holds the quest wanted on its first visit, stand the party a
## step outside it walking in, and play the world and its effects frame by frame (a tick every
## FRAMES_PER_TICK frames) as the game does. A few tell the world an event of their own, stamped
## with the simulation's tick, to see what the effects make of it.

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
const WIRE: StringName = &"tripwire"
## The pool's budget the words are counted under.
const CALLOUTS: StringName = &"quest_callout"
## An ability a cleric is named for over its head.
const NAMED: StringName = &"blessing"

## Where [method _party_at] put the party: Vector2i(stage, chamber index).
var _at: Vector2i = Vector2i(0, -1)

# --- Helpers -------------------------------------------------------------------


## A flat simulation whose party (every hero at [param level]) stands a step outside a room
## holding [param quest] on its first visit, walking in, auto-push off. With [param clerics] the
## mage is a second cleric (id SECOND_CLERIC), so two mend.
func _party_at(quest: StringName, clerics: bool = false, level: int = LEVEL) -> Simulation:
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
				raise_party(sim, level)
				_at = Vector2i(depth, room.index)
				return sim
	fail_test("no seed has a %s on stages 1 to 3" % quest)
	return null


## Two clerics a step outside a hurt wanderer, the world and its effects playing, up to the
## frame the quest starts in. False if it never did.
func _clerics_meet_the_wanderer() -> bool:
	var sim: Simulation = _party_at(WANDERER, true)
	if sim == null:
		return false
	_show(sim, 1, true)
	return _play_until(SimEvent.Kind.QUEST_STARTED, 60)


## The "QUEST!" words showing, oldest first.
func _callouts() -> Array[FxText]:
	var found: Array[FxText] = []
	found.assign(_world.fx.nodes(CALLOUTS))
	return found


func _callouts_now() -> int:
	return _fx.quest_effects.callouts_shown()


## The word over hero [param id], or null.
func _callout_over(id: int) -> FxText:
	for text: FxText in _callouts():
		if text.follow_id == id:
			return text
	return null


## Tells the world [param kind] now, as the simulation would.
func _emit_now(
	kind: SimEvent.Kind, source: int, target: int, amount: int = 0, flag: bool = false
) -> SimEvent:
	var event := SimEvent.new(kind, _sim.tick, source, target, amount, flag)
	_world.sim_event.emit(event)
	return event


## A world over a fresh party at [param level], its heroes drawn, with its effects.
func _fresh_world(level: int = LEVEL) -> Simulation:
	var sim := Simulation.new(7)
	raise_party(sim, level)
	_show(sim, 1, true)
	for i: int in 3:
		_play_frame(false)
	return sim


## Every word or name over hero [param id] other than its "QUEST!".
func _other_words_over(id: int) -> Array[FxText]:
	var found: Array[FxText] = []
	for budget: StringName in [&"quest_text", &"ability_name"]:
		for node: Node2D in _world.fx.nodes(budget):
			var text := node as FxText
			if text != null and text.follow_id == id and text.visible:
				found.append(text)
	return found


# --- R1 ------------------------------------------------------------------------


func test_r1_quest_pops_over_every_worker() -> void:
	assert_true(_clerics_meet_the_wanderer(), "the clerics find the wanderer")
	var workers: Array[int] = QuestWork.workers(_sim.expedition)
	assert_eq(workers.size(), 2, "two clerics work")
	assert_eq(_callouts_now(), 2, "two words")
	for id: int in workers:
		var text: FxText = _callout_over(id)
		assert_not_null(text, "a word over hero %d" % id)
		if text == null:
			return
		assert_eq(text.text, QuestEffects.CALLOUT, "it reads QUEST!")
		assert_eq(QuestEffects.CALLOUT, "QUEST!", "the word")
		assert_eq(text.color, Palette.color(&"orange"), "in orange")
		assert_eq(QuestEffects.CALLOUT_COLOUR, &"orange", "the colour")
		assert_eq(text.scale_factor, 2, "at twice the font's size")
		assert_true(text.outline, "with the ink outline of an ability name")
		var sprite: CharacterSprite = _world.character(id)
		assert_almost_eq(text.position.x, sprite.position.x, 2.0, "over its hero")
		var head: float = SpriteBounds.body_rect(sprite).position.y
		assert_lt(text.rect().end.y, head, "clear of its hero's head")
	var first: FxText = _callouts()[0]
	assert_lt(first.scale.x, 1.0, "it starts small")
	var peak: float = first.scale.x
	var frames: int = 1
	while frames < 18:
		_play_frame()
		frames += 1
		peak = maxf(peak, first.scale.x)
	assert_gt(peak, 1.0, "it pops past its size")
	assert_almost_eq(peak, 1.25, 0.05, "to 1.25")
	assert_eq(first.scale, Vector2.ONE, "then settles at its size")
	var gone_at: int = -1
	while frames < 120 and gone_at < 0:
		_play_frame()
		frames += 1
		if _callouts_now() == 0:
			gone_at = frames
	assert_between(gone_at, 60, 84, "gone after about 1.2 s, and by 1.4 s")


# --- R2 ------------------------------------------------------------------------


func test_r2_it_follows_its_hero() -> void:
	assert_true(_clerics_meet_the_wanderer(), "the clerics find the wanderer")
	var starts: Dictionary[int, float] = {}
	var walked: Dictionary[int, float] = {}
	for id: int in QuestWork.workers(_sim.expedition):
		starts[id] = _world.character(id).position.x
		walked[id] = 0.0
	var frames: int = 0
	while _callouts_now() > 0 and frames < 120:
		for id: int in starts:
			var text: FxText = _callout_over(id)
			var sprite: CharacterSprite = _world.character(id)
			if text == null:
				continue
			assert_almost_eq(text.position.x, sprite.position.x, 2.0, "over %d as it walks" % id)
			walked[id] = maxf(walked[id], absf(sprite.position.x - starts[id]))
		_play_frame()
		frames += 1
	var most: float = walked.values().max()
	assert_gt(most, 20.0, "a cleric walked 20 pixels or more under its word")


# --- R3 ------------------------------------------------------------------------


func test_r3_gates_too() -> void:
	_fresh_world()
	_emit_now(SimEvent.Kind.GATE_STARTED, ROGUE, 0, 30)
	_play_frame(false)
	assert_eq(_callouts_now(), 1, "one word")
	var text: FxText = _callout_over(ROGUE)
	assert_not_null(text, "over the opener")
	if text != null:
		assert_eq(text.text, "QUEST!", "the same word")
		assert_eq(text.color, Palette.color(&"orange"), "in the same colour")
		assert_almost_eq(text.position.x, _world.character(ROGUE).position.x, 2.0, "over it")


# --- R4 ------------------------------------------------------------------------


func test_r4_only_when_someone_can() -> void:
	# A chest nobody can open (a level-1 rogue picks no locks): the party walks past.
	var sim: Simulation = _party_at(CHEST, false, 1)
	if sim == null:
		return
	_show(sim, 1, true)
	assert_true(_play_until(SimEvent.Kind.QUEST_MISSED, 120), "the chest is walked past")
	for i: int in 10:
		_play_frame()
	assert_eq(_callouts_now(), 0, "no word for a walked-past quest")

	# A tripwire nobody spots springs.
	sim = _party_at(WIRE, false, 1)
	_show(sim, 1, true)
	assert_true(_play_until(SimEvent.Kind.QUEST_MISSED, 120), "the tripwire springs")
	var sprung: bool = false
	for event: SimEvent in _events:
		sprung = sprung or (event.kind == SimEvent.Kind.QUEST_MISSED and event.flag)
	assert_true(sprung, "it sprang")
	for i: int in 10:
		_play_frame()
	assert_eq(_callouts_now(), 0, "no word for a sprung hazard")

	# A sealed gate; the same world shows a word for a gate that is opened.
	_fresh_world(1)
	_emit_now(SimEvent.Kind.GATE_SEALED, -1, 0, 0)
	_play_frame(false)
	assert_eq(_callouts_now(), 0, "no word for a sealed gate")
	_emit_now(SimEvent.Kind.GATE_STARTED, ROGUE, 0, 30)
	_play_frame(false)
	assert_eq(_callouts_now(), 1, "but one for a gate being opened")


# --- R5 ------------------------------------------------------------------------


func test_r5_stale_time_shows_nothing() -> void:
	# The party reaches the wanderer during a stall: the start is heard in a catch-up.
	var sim: Simulation = _party_at(WANDERER, true)
	if sim == null:
		return
	sim.expedition.x -= 2.0  # far enough out that the world sees the party before it starts
	_show(sim, 1, true)
	_play_frame()
	assert_ne(sim.expedition.state, Expedition.State.WORKING, "seen before the start")
	while sim.expedition.state != Expedition.State.WORKING:
		sim.step()
	for i: int in World.STALL_TICKS + 2:
		sim.step()
	_play_frame(false)
	assert_true(_world.catching_up(), "a catch-up")
	assert_eq(_callouts_now(), 0, "no word for a start heard in a catch-up")

	# A start older than ANIMATE_TICKS, heard with no catch-up; a fresh one is called out.
	for i: int in 5:
		_play_frame(false)
	assert_false(_world.catching_up(), "caught up")
	var stale := SimEvent.new(
		SimEvent.Kind.QUEST_STARTED, sim.tick - World.ANIMATE_TICKS - 1, CLERIC, 0, 100
	)
	_world.sim_event.emit(stale)
	_play_frame(false)
	assert_eq(_callouts_now(), 0, "no word for a stale start")
	_emit_now(SimEvent.Kind.QUEST_STARTED, CLERIC, 0, 100)
	_play_frame(false)
	assert_eq(_callouts_now(), 2, "a fresh one is called out over both clerics")


# --- R6 ------------------------------------------------------------------------


func test_r6_it_does_not_crowd() -> void:
	# "QUEST!" first, then a lesson and an ability name over the same cleric.
	assert_true(_clerics_meet_the_wanderer(), "the clerics find the wanderer")
	_emit_now(SimEvent.Kind.MICROSKILL_LEARNED, CLERIC, 0, LEVEL)
	var named := SimEvent.new(SimEvent.Kind.ABILITY_USED, _sim.tick, CLERIC, CLERIC)
	named.ability_id = NAMED
	_world.sim_event.emit(named)
	_never_crowded(CLERIC, "a lesson and a name after it")

	# A lesson and a name first, then "QUEST!" over the same cleric.
	_emit_now(SimEvent.Kind.MICROSKILL_LEARNED, CLERIC, 1, LEVEL)
	named = SimEvent.new(SimEvent.Kind.ABILITY_USED, _sim.tick, CLERIC, CLERIC)
	named.ability_id = NAMED
	_world.sim_event.emit(named)
	_play_frame()
	_emit_now(SimEvent.Kind.QUEST_STARTED, CLERIC, 0, 100)
	_never_crowded(CLERIC, "a lesson and a name before it")


## Plays the life of hero [param id]'s "QUEST!", asserting each frame that it overlaps none of
## the other words over that hero, and that at least one other word showed with it.
func _never_crowded(id: int, what: String) -> void:
	var met: int = 0
	var frames: int = 0
	var overlaps: int = 0
	_play_frame()
	while frames < 90:
		var text: FxText = _callout_over(id)
		if text == null:
			break
		for other: FxText in _other_words_over(id):
			met += 1
			if other.rect().intersects(text.rect()):
				overlaps += 1
		_play_frame()
		frames += 1
	assert_gt(frames, 30, "%s: the word showed" % what)
	assert_gt(met, 0, "%s: other words showed with it" % what)
	assert_eq(overlaps, 0, "%s: never on top of one another" % what)


# --- R7 ------------------------------------------------------------------------


func test_r7_the_showcase_shows_it() -> void:
	var scene: PackedScene = load("res://game/dev/showcase.tscn")
	var showcase: Showcase = scene.instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"two_clerics")
	var most: int = 0
	var over: Dictionary[int, bool] = {}
	var limit: float = showcase.elapsed + 30.0
	while showcase.moment() == &"two_clerics" and showcase.elapsed < limit:
		showcase.advance(1.0 / 30.0)
		var effects: QuestEffects = showcase.main.effects.quest_effects
		most = maxi(most, effects.callouts_shown())
		for node: Node2D in showcase.main.world.fx.nodes(CALLOUTS):
			over[(node as FxText).follow_id] = true
	assert_eq(most, 2, "two words at once")
	assert_eq(over.size(), 2, "one over each cleric")
	var seen: bool = showcase.evidence.get(&"two_clerics", false)
	assert_true(seen, "the row was seen")

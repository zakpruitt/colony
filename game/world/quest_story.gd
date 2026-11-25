class_name QuestStory
extends Node
## A quest played out as a short story: the workers work in their quest's own pose
## ([member QuestDef.work_move], a looping [CharacterMoves] work pose) once they stand at their
## spots, and lines from the quest's data ([member QuestDef.lines]) are said at its beats, through
## [method World.say_for]:
##
## - plea: the wanderer, as the quest starts, and once as a party that cannot help walks past;
## - arrive: the lead, as it first reaches its spot;
## - work: the workers in turn, as the work passes a third and two thirds;
## - watch: one sitting hero, as it passes half;
## - done: the lead, as it is done;
## - thanks: the wanderer, [constant THANKS_AFTER] seconds after that, while it stands.
##
## A wanderer is tended: from three quarters of the work each cleric at it prays once
## ([constant PRAYER]), and the heal light ([method SpellEffects.light_column_at]) stands on the
## wanderer as the prayer's blow falls; small heal sparkles rise over it while it is tended.
##
## The beats follow [method Expedition.work_progress], not the clock, so at any speed they come in
## order; at [constant QUIET_SPEED] or above only the plea, done and thanks are said. A line is
## picked at random among those that fit, a line for the speaker's class before one for anyone,
## by a [RandomNumberGenerator] seeded from the chamber and the tick: the same moment always says
## the same line, and the simulation's stream is never touched.
##
## [QuestProps] makes it, asks [method pose] for each worker, and calls [method advance] once a
## frame and [method catch_up] when the world catches up: then the poses stop, and nothing is
## started in that frame or told late.

## The pose a cleric takes once at a wanderer, and the seconds to its blow.
const PRAYER: StringName = &"prayer"
const PRAYER_LEAD: float = 0.5
const CLERIC: StringName = &"cleric"
## The share of the work from which a cleric prays.
const PRAY_FROM: float = 0.75
## The shares of the work at which a worker and a watcher speak.
const WORK_AT: Array[float] = [1.0 / 3.0, 2.0 / 3.0]
const WATCH_AT: float = 0.5
## Seconds between the lead's done line and the wanderer's thanks.
const THANKS_AFTER: float = 0.4
## The game speed from which only the plea, done and thanks are said.
const QUIET_SPEED: int = 4
## Seconds between two heal sparkles over a tended wanderer, and how high above its feet they
## start, in pixels.
const SPARKLE_EVERY: float = 0.3
const SPARKLE_RAISE: Vector2 = Vector2(4.0, 14.0)
const SPARKLE_COLOURS: Array[StringName] = [&"sand", &"white", &"yellow"]

var _world: World
var _simulation: Simulation
var _props: QuestProps
## The wanderer as a speaker: one Callable for every line it says, so a new line replaces the last.
var _subject: Callable
## The chamber whose quest the story tells (index -1 with none), the quest and its definition.
var _key: Vector2i = Vector2i(0, -1)
var _def: QuestDef
## What has been told: the lead's arrival, the work beats, the watch, the prayer, the light.
var _arrived: bool = false
var _work_told: int = 0
var _watch_told: bool = false
var _prayed: bool = false
var _lit: bool = true
## Seconds to the heal light (below 0: none waiting), to the thanks, and to the next sparkle.
var _light_in: float = -1.0
var _thanks_in: float = -1.0
var _sparkle_in: float = 0.0
## The workers posing now, and the cycles of each one's pose last told as work.
var _posing: Dictionary[int, bool] = {}
var _cycles: Dictionary[int, int] = {}
## True from a catch-up to the end of the frame: nothing is started in it.
var _held: bool = false
var _rng := RandomNumberGenerator.new()
var _fx_rng := RandomNumberGenerator.new()


## Call once, before the first [method advance].
func setup(world: World, simulation: Simulation, props: QuestProps) -> void:
	_world = world
	_simulation = simulation
	_props = props
	_subject = _subject_point
	_fx_rng.seed = 107
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## The wanderer as a speaker of [method World.say]: the one Callable its lines are said by.
func subject() -> Callable:
	return _subject


## Hero [param id], worker of rank [param rank] at a quest worked for [param clock] seconds, plays
## [param move] once it stands at its spot (each rank a little after the one before). True when a
## new cycle of it begins this frame: one stroke of the work. A worker still walking, praying or
## in a catch-up starts nothing.
func pose(id: int, rank: int, clock: float, move: StringName) -> bool:
	var worker: CharacterSprite = _world.character(id)
	if not _may_work(worker, id, rank, clock) or move == &"":
		return false
	var playing: StringName = worker.moves.playing()
	if playing == PRAYER:
		return false
	if playing != move:
		worker.play_move(move, 0.0)
		if worker.moves.playing() != move:
			return false
		_posing[id] = true
	var cycles: int = worker.moves.cycles
	if _cycles.get(id, -1) == cycles:
		return false
	_cycles[id] = cycles
	return true


## True when [param worker] (hero [param id], of [param rank]) may work now: alive, its turn come
## after [param clock] seconds of work, standing at its spot, and the world not catching up.
func _may_work(worker: CharacterSprite, id: int, rank: int, clock: float) -> bool:
	if _held or worker == null or worker.is_dead() or clock < rank * QuestProps.SWING_OFFSET:
		return false
	var place: Vector2 = _world.quest_stage.goal_for(id, worker.position)
	return worker.position.distance_to(place) <= QuestProps.ARRIVED


## Tells the beats the work has reached, prays, lights and sparkles, and stops the poses once no
## quest is worked. [param delta] in real seconds.
func advance(delta: float) -> void:
	var working: bool = _world.quest_stage.is_working()
	if not working and not _posing.is_empty():
		_stop_poses()
	if working:
		_follow_work()
		if not _held:
			_tell_work(delta)
	if _thanks_in >= 0.0:
		_thanks_in -= delta
		if _thanks_in < 0.0 and not _held:
			_say_for(_now(), _subject, &"thanks", &"subject", &"")
	if _light_in >= 0.0:
		_light_in -= delta
		if _light_in < 0.0 and not _held:
			_light()
	_held = false


## The world is catching up on a stall: the poses stop, nothing waits to be told, and the beats
## the work is past are not told late.
func catch_up() -> void:
	_held = true
	_stop_poses()
	_thanks_in = -1.0
	_light_in = -1.0
	# The stage is brought up to date after this, so the simulation says whether a quest is worked.
	if _simulation.expedition.working_quest() != &"":
		_follow_work()
		_pass_to(_simulation.expedition.work_progress())


func _on_sim_event(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.QUEST_STARTED:
			_begin(_props.party_chamber(), _quest(event.target_id))
			if _def != null and _def.id == QuestProps.WANDERER:
				_say_for(event, _subject, &"plea", &"subject", &"")
		SimEvent.Kind.QUEST_MISSED:
			if not event.flag and _quest(event.target_id) == QuestProps.WANDERER:
				_begin(_props.party_chamber(), QuestProps.WANDERER)
				_say_for(event, _subject, &"plea", &"subject", &"")
		SimEvent.Kind.QUEST_DONE:
			_done(event)


## The story of [param quest] in chamber [param key] begins, nothing yet told.
func _begin(key: Vector2i, quest: StringName) -> void:
	_key = key
	_def = Content.quest(quest)
	_arrived = false
	_work_told = 0
	_watch_told = false
	_prayed = false
	_lit = false
	_light_in = -1.0
	_thanks_in = -1.0
	_sparkle_in = 0.0


## A quest worked that the story did not hear begin (a world made part way through it): its
## story starts here, what the work is past untold.
func _follow_work() -> void:
	var key: Vector2i = _props.party_chamber()
	var quest: StringName = _simulation.expedition.working_quest()
	if key == _key and _def != null and _def.id == quest:
		return
	_begin(key, quest)
	_pass_to(_simulation.expedition.work_progress())


## Marks every beat at or before [param progress] as told.
func _pass_to(progress: float) -> void:
	_arrived = _arrived or progress > 0.0
	while _work_told < WORK_AT.size() and progress >= WORK_AT[_work_told]:
		_work_told += 1
	_watch_told = _watch_told or progress >= WATCH_AT
	_prayed = _prayed or progress >= PRAY_FROM
	_lit = _lit or _prayed


func _tell_work(delta: float) -> void:
	if _def == null:
		return
	var workers: Array[int] = _world.quest_stage.workers()
	if workers.is_empty():
		return
	var lead: int = workers[0]
	var progress: float = _simulation.expedition.work_progress()
	var quiet: bool = _world.speed >= QUIET_SPEED
	if not _arrived and _posing.has(lead):
		_arrived = true
		if not quiet:
			_say_for(_now(), lead, &"arrive", &"worker", _class_of(lead))
	while _work_told < WORK_AT.size() and progress >= WORK_AT[_work_told]:
		var speaker: int = workers[_work_told % workers.size()]
		_work_told += 1
		if _arrived and not quiet:
			_say_for(_now(), speaker, &"work", &"worker", _class_of(speaker))
	if not _watch_told and progress >= WATCH_AT:
		_watch_told = true
		var watcher: int = _watcher()
		if watcher >= 0 and _arrived and not quiet:
			_say_for(_now(), watcher, &"watch", &"watcher", _class_of(watcher))
	if _def.id == QuestProps.WANDERER:
		_tend(workers, progress, delta)


## A wanderer is tended: sparkles over it while a worker is at it, and from PRAY_FROM each cleric
## at it prays once, the heal light falling with the prayer.
func _tend(workers: Array[int], progress: float, delta: float) -> void:
	if not _posing.has(workers[0]):
		return
	_sparkle_in -= delta
	if _sparkle_in <= 0.0:
		_sparkle_in = SPARKLE_EVERY
		_sparkle()
	if _prayed or progress < PRAY_FROM:
		return
	_prayed = true
	var pace: float = maxf(_world.speed, 1)
	for id: int in workers:
		var hero: Hero = _simulation.party.hero(id)
		var sprite: CharacterSprite = _world.character(id)
		if hero == null or sprite == null or hero.class_id != CLERIC or not _posing.has(id):
			continue
		sprite.play_move(PRAYER, PRAYER_LEAD / pace, INF, pace)
		if not _lit:
			_lit = true
			_light_in = PRAYER_LEAD / pace


## The lead says it is done; the wanderer thanks it a moment later, and is lit if no prayer lit it.
func _done(event: SimEvent) -> void:
	var quest: StringName = _quest(event.target_id)
	if _def == null or _def.id != quest:
		_begin(_props.party_chamber(), quest)
	_say_for(event, event.source_id, &"done", &"worker", _class_of(event.source_id))
	if quest == QuestProps.WANDERER and _world.may_animate(event):
		_thanks_in = THANKS_AFTER
		if not _lit:
			_light()


func _light() -> void:
	_lit = true
	_light_in = -1.0
	var feet: Vector2 = _props.spot(_key.x, _key.y)
	SpellEffects.light_column_at(_world.fx, feet, _fx_rng)


## One small sparkle rising over the wanderer.
func _sparkle() -> void:
	var made := FxParticle.new()
	made.name = "HealSparkle"
	made.kind = &"heal_sparkle"
	if not _world.fx.add(made, &"quest"):
		return
	made.color = Palette.color(SPARKLE_COLOURS[_fx_rng.randi() % SPARKLE_COLOURS.size()])
	made.size = 1
	made.velocity = Vector2(0, -_fx_rng.randf_range(10.0, 18.0))
	made.life = _fx_rng.randf_range(0.6, 0.9)
	var feet: Vector2 = _props.spot(_key.x, _key.y)
	var off := Vector2(
		_fx_rng.randf_range(-SPARKLE_RAISE.x, SPARKLE_RAISE.x),
		-_fx_rng.randf_range(4.0, SPARKLE_RAISE.y)
	)
	made.start((feet + off).round())


func _stop_poses() -> void:
	for id: int in _posing:
		var sprite: CharacterSprite = _world.character(id)
		if sprite != null and CharacterMoves.LOOPS.has(sprite.moves.playing()):
			sprite.play_move(&"", 0.0)
	_posing.clear()
	_cycles.clear()


## The living hero who sits watching to speak for the watchers, or -1 when none sits.
func _watcher() -> int:
	var sitting: Array[int] = []
	for hero: Hero in _simulation.party.heroes:
		if _world.quest_stage.sits(hero.id):
			sitting.append(hero.id)
	if sitting.is_empty():
		return -1
	_seed(_simulation.tick, &"watcher")
	return sitting[_rng.randi() % sitting.size()]


## Says a line of [param beat] by [param speaker] for an event of [param event]'s moment.
func _say_for(
	event: SimEvent, speaker: Variant, beat: StringName, kind: StringName, class_id: StringName
) -> void:
	if _def == null or _held:
		return
	var text: String = _pick(beat, kind, class_id, event.tick)
	if not text.is_empty():
		_world.say_for(event, speaker, text)


## A fresh event stamped with the simulation's tick, for a beat that has no event of its own
## (one told by the work's progress, or the thanks).
func _now() -> SimEvent:
	return SimEvent.new(SimEvent.Kind.QUEST_STARTED, _simulation.tick)


## One of the lines that fit, for the speaker's class first; "" with none.
func _pick(beat: StringName, kind: StringName, class_id: StringName, tick: int) -> String:
	var fit: Array[QuestLine] = _def.lines_for(beat, kind, class_id)
	if fit.is_empty():
		return ""
	var count: int = 0
	while count < fit.size() and fit[count].class_id != &"":
		count += 1
	if count == 0:
		count = fit.size()
	_seed(tick, beat)
	return fit[_rng.randi() % count].text


func _seed(tick: int, what: StringName) -> void:
	_rng.seed = hash([_key.x, _key.y, tick, what])


func _class_of(id: int) -> StringName:
	var hero: Hero = _simulation.party.hero(id)
	return hero.class_id if hero != null else &""


func _quest(index: int) -> StringName:
	var ids: Array[StringName] = Content.quest_ids()
	return ids[index] if index >= 0 and index < ids.size() else &""


## Where the wanderer speaks from: over its head, wherever it has walked; not finite once gone.
func _subject_point() -> Vector2:
	if _key.y < 0:
		return Vector2.INF
	return _props.head_of(_key.x, _key.y)

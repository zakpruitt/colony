class_name Journal
extends Node
## The party's journal (spec 027 R3): the last [constant CAPACITY] notable happenings as plain
## sentences stamped with the game time, newest first.
##
## It listens to [signal World.sim_event] and writes a line for a new deepest depth, a depth turning
## stable, a level up, a wipe (and the depth the party falls back to), a guardian slain, an upgrade
## bought, a microskill learned, a side quest done (with its reward), passed by or sprung (with
## the microskill it needed) (spec 028), an order changed (spec 035), a talent point gained
## and a path chosen (spec 055, [code]The Knight is now a Berserker[/code]) and the first of each
## resource gathered (spec 052). The newest line shows in the ticker just above the party frames
## for [constant TICKER_SECONDS], then fades through the palette and goes; events too old to
## animate ([method World.is_recent]) are written but not shown there. Spec 058 moved the list of
## lines onto the UI layer: the Journal window ([kbd]J[/kbd]) is a [JournalView] of this journal,
## told by [signal written]; spec 062 draws the ticker there too ([Ticker]), from
## [method ticker_text] and [method ticker_colour].
##
## The node draws nothing. It moves only in [method advance], so a test can step it exactly.

## Emitted after a line is written.
signal written

## Lines kept, newest first.
const CAPACITY: int = 50
## Seconds the newest line shows in the ticker at full strength.
const TICKER_SECONDS: float = 4.0
## Then its text steps down through these colours, each for FADE_STEP seconds, and it goes.
const FADE_COLOURS: Array[StringName] = [&"silver", &"steel", &"slate"]
const FADE_STEP: float = 0.2
var _simulation: Simulation
var _world: World
## Lines as written, newest first: the game time and the sentence.
var _times: Array[String] = []
var _sentences: Array[String] = []
## The ticker's line, and seconds since it was written.
var _ticker_line: String = ""
var _ticker_age: float = INF
## What the journal knows of the party, kept in step with the events.
var _depth: int = 1
var _deepest: int = 1
## The area the events are in, kept from AREA_CHANGED in event order (spec 049), and each other
## area's furthest stage.
var _area: StringName = &""
var _deepest_in: Dictionary[StringName, int] = {}
## Resources the party has held, as heard (spec 052): the first of each is written.
var _gathered: Dictionary[StringName, bool] = {}


func _init() -> void:
	name = "Journal"


## Call once, before the first advance. [param world] may be null (nothing is written then).
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	_depth = simulation.expedition.depth
	_deepest = simulation.expedition.deepest_depth
	_area = simulation.expedition.place
	for id: StringName in Content.area_ids():
		_deepest_in[id] = simulation.area_progress(id).y
	for id: StringName in Content.resource_ids():
		if simulation.has_gathered(id):
			_gathered[id] = true
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	advance(0.0)


## Runs the ticker on by [param delta] seconds. Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	_depth = _simulation.expedition.depth
	_ticker_age += delta


## Every line kept, newest first, each the game time then the sentence: [code]12:04  Mage
## reached level 4[/code].
func lines() -> Array[String]:
	var all: Array[String] = []
	for i: int in _sentences.size():
		all.append("%s  %s" % [_times[i], _sentences[i]])
	return all


## The sentence in the ticker, or "" when nothing is showing.
func ticker_text() -> String:
	var fade: float = _ticker_age - TICKER_SECONDS
	return _ticker_line if fade < FADE_STEP * FADE_COLOURS.size() else ""


## The ticker's text colour now: white while fresh, then each of [constant FADE_COLOURS].
func ticker_colour() -> StringName:
	var fade: float = _ticker_age - TICKER_SECONDS
	if fade < 0.0:
		return &"white"
	return FADE_COLOURS[mini(floori(fade / FADE_STEP), FADE_COLOURS.size() - 1)]


## Writes [param sentence] as a line now, without showing it in the ticker: the goals tracker's
## line for a finished goal (spec 037 R3), which the tracker itself celebrates.
func write(sentence: String) -> void:
	if _simulation == null or sentence.is_empty():
		return
	_times.push_front(clock(_simulation.tick))
	_sentences.push_front(sentence)
	if _sentences.size() > CAPACITY:
		_times.resize(CAPACITY)
		_sentences.resize(CAPACITY)
	written.emit()


## Writes [param sentence] as a line now and shows it in the ticker: the ladder's warning for a
## dangerous target (spec 043 R3).
func announce(sentence: String) -> void:
	if _simulation == null or sentence.is_empty():
		return
	write(sentence)
	_ticker_line = sentence
	_ticker_age = 0.0


## Game time as m:ss, or h:mm:ss from an hour on.
static func clock(tick: int) -> String:
	var seconds: int = floori(float(tick) / Simulation.TICKS_PER_SECOND)
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]


# --- Writing -------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	var sentence: String = _sentence(event)
	if sentence.is_empty():
		return
	_times.push_front(clock(event.tick))
	_sentences.push_front(sentence)
	if _sentences.size() > CAPACITY:
		_times.resize(CAPACITY)
		_sentences.resize(CAPACITY)
	if _world == null or _world.is_recent(event):
		_ticker_line = sentence
		_ticker_age = 0.0
	written.emit()


## The sentence for [param event], or "" for an event the journal does not write.
func _sentence(event: SimEvent) -> String:
	var sentence: String = ""
	match event.kind:
		SimEvent.Kind.DEPTH_CHANGED:
			_depth = event.amount
			if event.amount > _deepest:
				_deepest = event.amount
				sentence = "Reached %s, the furthest yet" % _place(event.amount)
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			sentence = "%s is now stable" % _place(event.amount)
		SimEvent.Kind.AREA_CHANGED:
			# Spec 049: each area has its own furthest stage.
			var arrived: StringName = _area_at(event.amount)
			_deepest_in[_area] = _deepest
			_area = arrived
			# The party arrives no deeper than it has been (stage 1 of a new area), so the
			# arrival is not a new deepest.
			var been: int = _deepest_in.get(arrived, 0)
			_deepest = maxi(been, 1)
			sentence = "Arrived in %s" % PlaceText.area_name(arrived)
		SimEvent.Kind.AREA_OPENED:
			sentence = "%s is open" % PlaceText.area_name(_area_at(event.amount))
		SimEvent.Kind.LEVEL_UP:
			var hero: Hero = _simulation.party.hero(event.target_id)
			var who: String = hero.def().display_name if hero != null else "A hero"
			sentence = "%s reached level %d" % [who, event.amount]
		SimEvent.Kind.PARTY_WIPED:
			# Spec 041 R6, spec 046 R6: the defeat note's first line, what beat the party and
			# where, then where it falls back to.
			var hud: Hud = get_parent() as Hud
			if hud != null and hud.defeat_note != null:
				return hud.defeat_note.journal_line(event)
			var back_to: int = _simulation.expedition.last_stable_depth
			sentence = "Wiped on %s, falling back to %s" % [_place(_depth), _place(back_to)]
			if back_to == _depth:
				sentence = "Wiped on %s, regrouping there" % _place(_depth)
		SimEvent.Kind.GUARDIAN_SLAIN:
			var slain: StringName = EncounterRoll.guardian_at(Content.area(_area), event.amount)
			var def: MonsterDef = Content.monster(slain)
			var guardian: String = def.display_name if def != null else "guardian"
			sentence = "Slew the %s on %s" % [guardian, _place(event.amount)]
		SimEvent.Kind.UPGRADE_BOUGHT:
			# The event is the same whether the player or auto-buy bought it.
			var ids: Array[StringName] = Content.upgrade_ids()
			if event.source_id >= 0 and event.source_id < ids.size():
				var upgrade: UpgradeDef = Content.upgrade(ids[event.source_id])
				sentence = "Bought %s, rank %d" % [upgrade.display_name, event.amount]
		SimEvent.Kind.MICROSKILL_LEARNED:
			var learner: Hero = _simulation.party.hero(event.source_id)
			var skill: MicroskillDef = _microskill(event.target_id)
			if learner != null and skill != null:
				sentence = "%s learned %s" % [learner.def().display_name, skill.display_name]
		SimEvent.Kind.SIDE_QUEST_DONE, SimEvent.Kind.SIDE_QUEST_MISSED:
			sentence = _quest_sentence(event)
		SimEvent.Kind.ORDER_CHANGED:
			sentence = _order_sentence(event)
		SimEvent.Kind.RESOURCE_GAINED:
			sentence = _resource_sentence(event)
		SimEvent.Kind.TALENT_POINT_GAINED, SimEvent.Kind.TALENT_TAKEN:
			sentence = _talent_sentence(event)
	return sentence


## The sentence for the first of a resource the party gathers (spec 052): "First glowcaps, from
## Mossy Hollow"; "" for any after it.
func _resource_sentence(event: SimEvent) -> String:
	var ids: Array[StringName] = Content.resource_ids()
	if event.target_id < 0 or event.target_id >= ids.size():
		return ""
	var id: StringName = ids[event.target_id]
	if _gathered.has(id):
		return ""
	_gathered[id] = true
	var from: String = PlaceText.area_name(Content.area_of_resource(id))
	return "First %s, from %s" % [ResourceIcon.plural(id), from]


## The sentence for a talent point gained ([code]The Knight has a talent point to spend[/code]) or
## a path chosen ([code]The Knight is now a Berserker[/code]), read from the event alone; "" for
## any other node taken.
func _talent_sentence(event: SimEvent) -> String:
	var hero: Hero = _simulation.party.hero(event.source_id)
	if hero == null:
		return ""
	var who: String = hero.def().display_name
	if event.kind == SimEvent.Kind.TALENT_POINT_GAINED:
		return "The %s has a talent point to spend" % who
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var on: int = tree.path_of(event.ability_id) if tree != null else -1
	if on < 0 or tree.path_nodes(on).find(event.ability_id) != 0:
		return ""
	var walked: String = tree.path_names[on]
	var article: String = "an" if walked.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
	return "The %s is now %s %s" % [who, article, walked]


## The sentence for an order changed (spec 035): "Ordered a Bold pace", "Ordered to hold at
## guardians", or "".
func _order_sentence(event: SimEvent) -> String:
	if event.target_id == PartyOrders.PACE and event.amount in Expedition.Pace.values():
		return "Ordered a %s pace" % OrdersPanel.PACE_NAMES[event.amount]
	if event.target_id != PartyOrders.GUARDIANS:
		return ""
	match event.amount:
		Expedition.GuardianOrder.CHALLENGE:
			return "Ordered to challenge guardians"
		Expedition.GuardianOrder.HOLD:
			return "Ordered to hold at guardians"
	return ""


## The sentence for a side quest done, passed by or sprung, or "".
func _quest_sentence(event: SimEvent) -> String:
	var ids: Array[StringName] = Content.side_quest_ids()
	if event.target_id < 0 or event.target_id >= ids.size():
		return ""
	var quest: SideQuestDef = Content.side_quest(ids[event.target_id])
	if event.kind == SimEvent.Kind.SIDE_QUEST_DONE:
		var done: String = QuestProps.DONE_WORDS.get(quest.id, quest.display_name)
		if quest.reward == SideQuestDef.Reward.XP:
			return "%s: %d XP each" % [done, event.amount]
		return "%s: %d gold" % [done, event.amount]
	var skill: MicroskillDef = _microskill(event.amount)
	var needs: String = skill.display_name if skill != null else "?"
	if event.flag:
		return "Sprang a %s: needs %s" % [quest.display_name, needs]
	return "Passed a %s: needs %s" % [quest.display_name, needs]


func _microskill(index: int) -> MicroskillDef:
	var ids: Array[StringName] = Content.microskill_ids()
	return Content.microskill(ids[index]) if index >= 0 and index < ids.size() else null


## [param stage] of the area the events are in, as the screen names it (spec 049).
func _place(stage: int) -> String:
	return PlaceText.of(_area, stage)


## The area at [param index] in [method Content.area_ids], or &"".
static func _area_at(index: int) -> StringName:
	var ids: Array[StringName] = Content.area_ids()
	return ids[index] if index >= 0 and index < ids.size() else &""

class_name Tally
extends RefCounted
## The counting behind the party tally: each hero's damage dealt, healing done and damage taken,
## for the last fight and for the session, and the quests each hero has done. It is fed
## the simulation's events one at a time through [method observe] and changes nothing.
##
## What counts, from [SimEvent]: [constant SimEvent.Kind.HIT] from a hero to a monster is damage
## dealt by its source; a [constant SimEvent.Kind.HIT] on a hero is damage taken by its target
## (a sprung hazard's too, which has no source, in the session only: it is never part of a fight);
## [constant SimEvent.Kind.HEALED] from a hero to a hero is healing done by its source. A heal's
## amount is what the target gained, already stopped at full health by the battle, so healing
## beyond full health is never counted. A hit's amount is the whole blow, and the events do not say
## how much health its target had left, so a killing blow's overkill is counted in damage dealt and
## taken; the tally's tooltips say so.
## [constant SimEvent.Kind.ENCOUNTER_STARTED] begins a new
## last fight; [constant SimEvent.Kind.QUEST_DONE] counts one quest for its worker. Counts are kept
## by hero for the session, so a hero who leaves the four going down keeps them and shows them again
## when it comes back; [constant SimEvent.Kind.HERO_FIELDED] starts the hero who came in at 0 in
## the last fight.
## A hero is any id below [constant Battle.FIRST_SUMMON_ID]. A summon's blows and heals count
## to its summoner (the source of its [constant SimEvent.Kind.SUMMONED], or
## [method note_summon]), by ability as one line under the summon's name; the blows it takes are
## not the party's, and are not counted. The side paths' gates and caches are counted by
## [member side_paths].
##
## Each hero's damage dealt and healing done is also kept by what dealt or gave it (an ability, a
## status working, or an ordinary strike or heal), as an [AbilityCredit] reading the same events
## works it out. Its [member AbilityCredit.statuses] are the statuses the hero frames show.

## What is counted.
enum Measure { DAMAGE, HEALING, TAKEN }
## Over how long.
enum Span { LAST_FIGHT, SESSION }

## The start of a summon's key among the lines by ability, before its id.
const SUMMON_KEY: String = "summon:"

## What each blow and heal was, and the statuses on every fighter.
var credit: AbilityCredit = AbilityCredit.new()
## The side paths' counting: gates, caches and what the caches paid, by area.
var side_paths: SidePathTally = SidePathTally.new()

## Amounts by span, then measure, then hero id.
var _amounts: Array[Array] = []
## Amounts by span, then measure (damage and healing only), then hero id, then
## [method AbilityCredit.key].
var _by_ability: Array[Array] = []
var _quests: Dictionary[int, int] = {}
## Per summon standing: its summoner's id, and the key its line by ability is kept under.
var _summoners: Dictionary[int, int] = {}
var _summon_keys: Dictionary[int, String] = {}
## The name of each summon's line by ability, by its key; and each summon id's key, made once.
var _summon_names: Dictionary[String, String] = {}
var _key_of: Dictionary[StringName, String] = {}
var _fights: int = 0
var _in_fight: bool = false


func _init() -> void:
	for span: int in Span.size():
		var by_measure: Array[Dictionary] = []
		for measure: int in Measure.size():
			by_measure.append({})
		_amounts.append(by_measure)
		var by_credit: Array[Dictionary] = [{}, {}]
		_by_ability.append(by_credit)


## Counts what [param event] adds, if anything.
func observe(event: SimEvent) -> void:
	credit.observe(event)
	side_paths.observe(event)
	match event.kind:
		SimEvent.Kind.ENCOUNTER_STARTED:
			for measure: int in Measure.size():
				_table(Span.LAST_FIGHT, measure).clear()
			for table: Dictionary in _by_ability[Span.LAST_FIGHT]:
				table.clear()
			_fights += 1
			_in_fight = true
		SimEvent.Kind.ENCOUNTER_ENDED:
			_in_fight = false
		SimEvent.Kind.SUMMONED:
			var def: SummonDef = SummonSprites.summoned(event)
			if def != null:
				note_summon(event.target_id, event.source_id, def.id, def.display_name)
		SimEvent.Kind.SUMMON_ENDED:
			_summoners.erase(event.source_id)
			_summon_keys.erase(event.source_id)
		SimEvent.Kind.HIT:
			if _is_hero(event.target_id):
				_add(Measure.TAKEN, event.target_id, event.amount, event.source_id >= 0)
			elif event.target_id >= Expedition.FIRST_MONSTER_ID:
				_dealt(Measure.DAMAGE, event)
		SimEvent.Kind.HEALED:
			if _is_hero(event.target_id):
				_dealt(Measure.HEALING, event)
		SimEvent.Kind.QUEST_DONE:
			if _is_hero(event.source_id):
				_quests[event.source_id] = _quests.get(event.source_id, 0) + 1
		SimEvent.Kind.HERO_FIELDED:
			for measure: int in Measure.size():
				_table(Span.LAST_FIGHT, measure).erase(event.source_id)
			for table: Dictionary in _by_ability[Span.LAST_FIGHT]:
				table.erase(event.source_id)


## Summon [param summon_id], standing in the fight, is [param summoner_id]'s, of the
## [SummonDef] [param def_id] named [param display_name]: what it deals and gives counts to
## its summoner, by ability under that name. The events tell it of each summon as it comes; a
## tally made mid-fight is told of those standing.
func note_summon(
	summon_id: int, summoner_id: int, def_id: StringName, display_name: String
) -> void:
	var key: String = _key_of.get(def_id, "")
	if key.is_empty():
		key = SUMMON_KEY + String(def_id)
		_key_of[def_id] = key
	_summoners[summon_id] = summoner_id
	_summon_keys[summon_id] = key
	_summon_names[key] = display_name


## How much of [param measure] the hero with id [param hero_id] has over [param span].
func value(hero_id: int, measure: Measure, span: Span) -> int:
	var amount: int = _table(span, measure).get(hero_id, 0)
	return amount


## The hero's part of the party's whole [param measure] over [param span], from 0 to 1; 0 while
## the whole is nothing.
func share(hero_id: int, measure: Measure, span: Span) -> float:
	var total: int = 0
	var table: Dictionary = _table(span, measure)
	for id: int in table:
		var amount: int = table[id]
		total += amount
	return float(value(hero_id, measure, span)) / total if total > 0 else 0.0


## The hero's [param measure] (damage or healing) over [param span] by what dealt or
## gave it, as name to amount, largest first: [code]{"Strikes": 950, "Whirlwind": 412}[/code].
## Empty for the damage taken.
func by_ability(hero_id: int, measure: Measure, span: Span) -> Dictionary[String, int]:
	var found: Dictionary[String, int] = {}
	if measure == Measure.TAKEN:
		return found
	var table: Dictionary = _by_ability[span][measure]
	var mine: Dictionary = table.get(hero_id, {})
	var keys: Array = mine.keys()
	keys.sort_custom(
		func(a: String, b: String) -> bool:
			var left: int = mine[a]
			var right: int = mine[b]
			return left > right or (left == right and a < b)
	)
	for credit_key: String in keys:
		var amount: int = mine[credit_key]
		var named: String = _summon_names.get(credit_key, "")
		if named.is_empty():
			named = AbilityCredit.name_of(credit_key, measure == Measure.HEALING)
		found[named] = amount
	return found


## How many quests the hero with id [param hero_id] has done this session.
func quests(hero_id: int) -> int:
	return _quests.get(hero_id, 0)


## How many fights have begun this session.
func fights() -> int:
	return _fights


## True from a fight's start to its end.
func in_fight() -> bool:
	return _in_fight


## Whole percentages of [param amounts]' total, one per amount, that sum to exactly 100 (or are all
## 0 when the total is): each is rounded down, then the ones that lost most get a point each, the
## first on a tie.
static func percents(amounts: Array[int]) -> Array[int]:
	var total: int = 0
	for amount: int in amounts:
		total += amount
	var result: Array[int] = []
	result.resize(amounts.size())
	result.fill(0)
	if total <= 0:
		return result
	var left: int = 100
	var remainders: Array[Vector2i] = []
	for i: int in amounts.size():
		var scaled: int = amounts[i] * 100
		result[i] = scaled / total
		left -= result[i]
		remainders.append(Vector2i(scaled % total, i))
	remainders.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y)
	)
	for i: int in left:
		result[remainders[i].y] += 1
	return result


func _table(span: int, measure: int) -> Dictionary:
	var table: Dictionary = _amounts[span][measure]
	return table


func _add(measure: Measure, hero_id: int, amount: int, in_last_fight: bool) -> void:
	var spans: Array[int] = [Span.SESSION]
	if in_last_fight:
		spans.append(Span.LAST_FIGHT)
	for span: int in spans:
		var table: Dictionary = _table(span, measure)
		var before: int = table.get(hero_id, 0)
		table[hero_id] = before + amount


## Counts [param event]'s amount of [param measure] (damage or healing) to its source: a hero,
## or a summon's summoner under the summon's line. Nothing for any other source.
func _dealt(measure: Measure, event: SimEvent) -> void:
	var hero_id: int = event.source_id
	var credit_key: String = ""
	if _summoners.has(hero_id):
		credit_key = _summon_keys[hero_id]
		hero_id = _summoners[hero_id]
	elif _is_hero(hero_id):
		credit_key = credit.key()
	else:
		return
	_add(measure, hero_id, event.amount, true)
	_add_credit(measure, hero_id, event.amount, credit_key)


## Adds [param amount] of [param measure] to [param hero_id]'s line under [param credit_key]
## ([method AbilityCredit.key], or a summon's), in the session and the last fight.
func _add_credit(measure: Measure, hero_id: int, amount: int, credit_key: String) -> void:
	for span: int in Span.size():
		var table: Dictionary = _by_ability[span][measure]
		var mine: Dictionary = table.get(hero_id, {})
		var before: int = mine.get(credit_key, 0)
		mine[credit_key] = before + amount
		table[hero_id] = mine


static func _is_hero(id: int) -> bool:
	return id >= 0 and id < Battle.FIRST_SUMMON_ID

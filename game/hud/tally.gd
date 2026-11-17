class_name Tally
extends RefCounted
## The counting behind the party tally (spec 045): each hero's damage dealt, healing done and damage
## taken, for the last fight and for the session, and the side quests each hero has done. It is fed
## the simulation's events one at a time through [method observe] and changes nothing.
##
## What counts, from [SimEvent]: [constant SimEvent.Kind.HIT] from a hero to a monster is damage
## dealt by its source; a [constant SimEvent.Kind.HIT] on a hero is damage taken by its target
## (a sprung hazard's too, which has no source, in the session only: it is never part of a fight);
## [constant SimEvent.Kind.HEALED] from a hero to a hero is healing done by its source. A heal's
## amount is what the target gained, already stopped at full health by the battle, so healing
## beyond full health is never counted. A hit's amount is the whole blow, and the events do not say
## how much health its target had left, so a killing blow's overkill is counted in damage dealt and
## taken; the tally's tooltips say so (spec 046 R8).
## [constant SimEvent.Kind.ENCOUNTER_STARTED] begins a new
## last fight; [constant SimEvent.Kind.SIDE_QUEST_DONE] counts one side quest for its worker.
## A hero is any id below [constant Expedition.FIRST_MONSTER_ID].
##
## Spec 056 R6: each hero's damage dealt and healing done is also kept by what dealt or gave it (an
## ability, a status working, or an ordinary strike or heal), as an [AbilityCredit] reading the
## same events works it out. Its [member AbilityCredit.statuses] are the statuses the hero frames
## show (R5).

## What is counted.
enum Measure { DAMAGE, HEALING, TAKEN }
## Over how long.
enum Span { LAST_FIGHT, SESSION }

## What each blow and heal was, and the statuses on every fighter (spec 056).
var credit: AbilityCredit = AbilityCredit.new()

## Amounts by span, then measure, then hero id.
var _amounts: Array[Array] = []
## Spec 056 R6: amounts by span, then measure (damage and healing only), then hero id, then
## [method AbilityCredit.key].
var _by_ability: Array[Array] = []
var _quests: Dictionary[int, int] = {}
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
		SimEvent.Kind.HIT:
			if _is_hero(event.target_id):
				_add(Measure.TAKEN, event.target_id, event.amount, event.source_id >= 0)
			elif _is_hero(event.source_id):
				_add(Measure.DAMAGE, event.source_id, event.amount, true)
				_add_credit(Measure.DAMAGE, event.source_id, event.amount)
		SimEvent.Kind.HEALED:
			if _is_hero(event.source_id) and _is_hero(event.target_id):
				_add(Measure.HEALING, event.source_id, event.amount, true)
				_add_credit(Measure.HEALING, event.source_id, event.amount)
		SimEvent.Kind.SIDE_QUEST_DONE:
			if _is_hero(event.source_id):
				_quests[event.source_id] = _quests.get(event.source_id, 0) + 1


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


## Spec 056 R6: the hero's [param measure] (damage or healing) over [param span] by what dealt or
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
		found[AbilityCredit.name_of(credit_key, measure == Measure.HEALING)] = amount
	return found


## How many side quests the hero with id [param hero_id] has done this session.
func side_quests(hero_id: int) -> int:
	return _quests.get(hero_id, 0)


## How many fights have begun this session.
func fights() -> int:
	return _fights


## True from a fight's start to its end.
func in_fight() -> bool:
	return _in_fight


## [param amounts] (name to amount, largest first) as at most [param most] lines, "Whirlwind 412";
## past that many, the smallest are summed as "Others". "None yet" when there are none.
static func lines_by_ability(amounts: Dictionary[String, int], most: int) -> Array[String]:
	var lines: Array[String] = []
	var names: Array[String] = []
	names.assign(amounts.keys())
	if names.is_empty():
		lines.append("None yet")
		return lines
	var others: int = 0
	for i: int in names.size():
		if names.size() > most and i >= most - 1:
			others += amounts[names[i]]
		else:
			lines.append("%s %s" % [names[i], Hud.group_thousands(amounts[names[i]])])
	if names.size() > most:
		lines.append("Others %s" % Hud.group_thousands(others))
	return lines


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


## Adds [param amount] of [param measure] to [param hero_id]'s line for what [member credit] says
## the event was, in the session and the last fight.
func _add_credit(measure: Measure, hero_id: int, amount: int) -> void:
	for span: int in Span.size():
		var table: Dictionary = _by_ability[span][measure]
		var mine: Dictionary = table.get(hero_id, {})
		var credit_key: String = credit.key()
		var before: int = mine.get(credit_key, 0)
		mine[credit_key] = before + amount
		table[hero_id] = mine


static func _is_hero(id: int) -> bool:
	return id >= 0 and id < Expedition.FIRST_MONSTER_ID

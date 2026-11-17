class_name AbilityCredit
extends RefCounted
## What each blow and heal was (spec 056): an ordinary strike or heal, an ability, or a status
## working, worked out from the simulation's events alone and in their order, for the effects
## (a heavy blow's spark, a status's coloured number) and the tally's lines by ability.
##
## A HIT, HEALED or MISSED event does not name its ability, so [method observe] reads the events
## around it. Within one tick a battle lets statuses work first, then lands shots, then lets each
## fighter act, and every ability's effects follow its ABILITY_USED. So a blow is, in this order:
## [br]- a status working: its bearer has burning, bleeding or chilled (mending for a heal) that
## works on this tick and has not yet worked in it;
## [br]- an ordinary strike or heal: its fighter's wind-up on that target (ATTACK_STARTED) or
## shot at it (PROJECTILE_LAUNCHED) is due; a passive that multiplies the strike (it is used just
## before the strike lands) takes the credit then;
## [br]- the ability its fighter used last in this tick;
## [br]- otherwise an ordinary strike or heal (one begun before the events were heard).

## The names of ordinary blows and heals, as the tally shows them.
const STRIKES: String = "Strikes"
const HEALS: String = "Heals"
## The statuses that work each second, by what they do.
const HURTING: Array[AbilityEffect.Status] = [
	AbilityEffect.Status.BURNING, AbilityEffect.Status.BLEEDING, AbilityEffect.Status.CHILLED
]

## The statuses on every fighter, kept from the same events.
var statuses: StatusBook = StatusBook.new()
## What the last HIT, HEALED or MISSED observed was: the ability credited ([code]&""[/code] for
## none), and the status credited (-1 for none). Neither: an ordinary strike or heal.
var ability_id: StringName = &""
var status: int = -1

## The tick the events now being read are on.
var _tick: int = -1
## Per fighter: the ability it used last in this tick.
var _used: Dictionary[int, StringName] = {}
## Per fighter: its wind-up, as Vector2i(target id, the tick it strikes on).
var _windups: Dictionary[int, Vector2i] = {}
## Per fighter: its shots in flight, each Vector2i(target id, the tick it lands on).
var _shots: Dictionary[int, Array] = {}
## The statuses that have worked in this tick, as "bearer:kind".
var _worked: Dictionary[String, bool] = {}


## Reads [param event]: notes what it says of statuses, wind-ups, shots and abilities, and for a
## blow, a heal or a miss works out what it was ([member ability_id], [member status]).
func observe(event: SimEvent) -> void:
	if event.tick != _tick:
		_tick = event.tick
		_used.clear()
		_worked.clear()
	statuses.observe(event)
	match event.kind:
		SimEvent.Kind.ATTACK_STARTED:
			_windups[event.source_id] = Vector2i(event.target_id, event.tick + event.amount)
		SimEvent.Kind.PROJECTILE_LAUNCHED:
			_windups.erase(event.source_id)
			var shots: Array = _shots.get(event.source_id, [])
			shots.append(Vector2i(event.target_id, event.tick + event.amount))
			_shots[event.source_id] = shots
		SimEvent.Kind.ABILITY_USED:
			_used[event.source_id] = event.ability_id
		SimEvent.Kind.HIT:
			_credit(event, HURTING)
		SimEvent.Kind.HEALED:
			_credit(event, [AbilityEffect.Status.MENDING])
		SimEvent.Kind.MISSED:
			ability_id = &""
			status = -1
			if not event.flag:
				_take_strike(event.source_id, event.target_id)  # a strike that did not land
		SimEvent.Kind.ENCOUNTER_STARTED, SimEvent.Kind.ENCOUNTER_ENDED:
			_windups.clear()
			_shots.clear()
			_used.clear()


## The name of what the last blow or heal was: an ability's ("Whirlwind"), a status's
## ("Bleeding"), or "Strikes" or "Heals".
func label(healing: bool = false) -> String:
	return name_of(key(), healing)


## A key for what the last blow or heal was, the same for every blow of that kind: an ability's
## id, "status:<kind>", or "" for an ordinary strike or heal.
func key() -> String:
	if status >= 0:
		return "status:%d" % status
	return String(ability_id)


## The name the screen gives [param credit_key] (see [method key]); [param healing] chooses the
## name of an ordinary heal over a strike's.
static func name_of(credit_key: String, healing: bool) -> String:
	if credit_key.is_empty():
		return HEALS if healing else STRIKES
	if credit_key.begins_with("status:"):
		return ShownStatus.status_name(int(credit_key.get_slice(":", 1)))
	var ability: AbilityDef = Content.ability(StringName(credit_key))
	return ability.display_name if ability != null else credit_key


func _credit(event: SimEvent, working: Array) -> void:
	ability_id = &""
	status = -1
	var worked: int = _worked_status(event, working)
	if worked >= 0:
		status = worked
		return
	var used: StringName = _used.get(event.source_id, &"")
	if _take_strike(event.source_id, event.target_id):
		var boost: AbilityDef = Content.ability(used) if used != &"" else null
		if boost != null and boost.boosts_strike():
			ability_id = used
		return
	ability_id = used


## The status of [param event]'s target, one of [param working], that works in this tick and has
## not yet, now marked as worked; -1 if there is none. One its fighter put there comes first.
func _worked_status(event: SimEvent, working: Array) -> int:
	var fallback: int = -1
	for kind: int in working:
		var on: ShownStatus = statuses.find(event.target_id, kind)
		var mark: String = "%d:%d" % [event.target_id, kind]
		if on == null or _worked.has(mark) or not on.pulses_on(event.tick):
			continue
		if on.source_id == event.source_id:
			_worked[mark] = true
			return kind
		if fallback < 0:
			fallback = kind
	if fallback >= 0:
		_worked["%d:%d" % [event.target_id, fallback]] = true
	return fallback


## Takes off the wind-up or shot of [param source] at [param target] that is due now; false if
## it has none.
func _take_strike(source: int, target: int) -> bool:
	if _windups.has(source):
		var windup: Vector2i = _windups[source]
		if windup.x == target and windup.y <= _tick:
			_windups.erase(source)
			return true
	var shots: Array = _shots.get(source, [])
	for i: int in shots.size():
		var shot: Vector2i = shots[i]
		if shot.x == target and shot.y <= _tick:
			shots.remove_at(i)
			return true
	return false

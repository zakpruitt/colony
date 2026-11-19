class_name PartyOrders
extends RefCounted
## The rules and names of the party's standing orders (spec 035), kept apart from [Expedition],
## which holds the orders themselves ([member Expedition.pace], [member Expedition.guardian_order]).
## Plain functions; nothing here keeps state.

## Which order an [constant SimEvent.Kind.ORDER_CHANGED] event is about, in its target_id.
const PACE: int = 0
const GUARDIANS: int = 1
## The same names as the save writes them.
const PACE_SAVED: Array[String] = ["cautious", "steady", "bold"]
const GUARDIAN_SAVED: Array[String] = ["challenge", "hold"]
## The share of its health below which a hero makes the party rest after a fight, at each pace.
const _CAUTIOUS_REST_BELOW: float = 0.8
const _BOLD_REST_BELOW: float = 0.4


## The share of a hero's health below which the party rests after a fight at [param pace]. Steady
## is [constant Expedition.REST_BELOW], the rule from before orders.
static func rest_below(pace: Expedition.Pace) -> float:
	match pace:
		Expedition.Pace.CAUTIOUS:
			return _CAUTIOUS_REST_BELOW
		Expedition.Pace.BOLD:
			return _BOLD_REST_BELOW
	return Expedition.REST_BELOW


## True if the party must rest after a fight at [param pace]: any of [param heroes] is down or
## below its own share of its own maximum health (spec 040 R3: per hero, not the party's total).
static func needs_rest(heroes: Array[Hero], pace: Expedition.Pace) -> bool:
	for hero: Hero in heroes:
		if not hero.is_alive() or hero.health < rest_below(pace) * hero.max_health():
			return true
	return false


## [param goal], or the column just outside [param room] if the walk from [param from] to
## [param goal] would enter it: where a party under Hold turns back from a guardian's chamber.
static func short_of(room: LabyrinthChamber, from: float, goal: float) -> float:
	if room == null:
		return goal
	var first: float = room.floor_columns().x
	var last: float = room.floor_columns().y
	if goal > from and from < first and goal > first - 1.0:
		return first - 1.0
	if goal < from and from > last and goal < last + 1.0:
		return last + 1.0
	return goal

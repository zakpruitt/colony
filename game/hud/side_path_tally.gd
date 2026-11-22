class_name SidePathTally
extends RefCounted
## The counting of side paths behind the party tally: gates opened, caches opened and the gold,
## the XP and the resources that came from caches, by the area they were in. Fed the simulation's
## events one at a time through [method observe]; it changes nothing.

## What is counted, but for the resources.
enum Count { GATES, CACHES, GOLD, XP }

## The area the events are in: set at the start, then kept from AREA_CHANGED in event order.
var area: StringName = &""
## How many times something has been counted: what is read from here is the same until it moves.
var changes: int = 0

## Counts by area, then by [enum Count].
var _counts: Dictionary[StringName, Array] = {}
## Resources from caches by area, then by resource id.
var _resources: Dictionary[StringName, Dictionary] = {}
var _reader: CacheReader = CacheReader.new()
## The area of the cache whose gains the reader is gathering.
var _cache_area: StringName = &""


## Counts what [param event] adds, if anything.
func observe(event: SimEvent) -> void:
	var pay: CacheReader.Pay = _reader.heard(event)
	if pay != null:
		_add(_cache_area, Count.GOLD, pay.gold)
		_add(_cache_area, Count.XP, pay.xp)
		if pay.resource != &"":
			var held: Dictionary = _resources.get_or_add(_cache_area, {})
			var before: int = held.get(pay.resource, 0)
			held[pay.resource] = before + pay.resource_amount
			changes += 1
	match event.kind:
		SimEvent.Kind.AREA_CHANGED:
			var ids: Array[StringName] = Content.area_ids()
			if event.amount >= 0 and event.amount < ids.size():
				area = ids[event.amount]
		SimEvent.Kind.GATE_OPENED:
			_add(area, Count.GATES, 1)
		SimEvent.Kind.CACHE_OPENED:
			_cache_area = area
			_add(area, Count.CACHES, 1)


## How much of [param what] this session in area [param in_area], or in every area (&"").
func count(what: Count, in_area: StringName = &"") -> int:
	var total: int = 0
	for id: StringName in _counts:
		if in_area == &"" or id == in_area:
			var amount: int = _counts[id][what]
			total += amount
	return total


## How many of each resource came from caches in area [param in_area], or in every area (&""),
## by resource id in [method Content.resource_ids] order; none that came to nothing.
func resources(in_area: StringName = &"") -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for resource: StringName in Content.resource_ids():
		var total: int = 0
		for id: StringName in _resources:
			if in_area == &"" or id == in_area:
				var amount: int = _resources[id].get(resource, 0)
				total += amount
		if total > 0:
			found[resource] = total
	return found


## The areas with anything counted, in [method Content.area_ids] order.
func areas() -> Array[StringName]:
	var found: Array[StringName] = []
	for id: StringName in Content.area_ids():
		if _counts.has(id):
			found.append(id)
	return found


## What is counted in area [param in_area], or in every area (&""), as two lines: [code]2 gates,
## 2 caches[/code] and [code]+240 gold, +18 glowcaps, 80 XP[/code].
func lines(in_area: StringName = &"") -> Array[String]:
	var gates: int = count(Count.GATES, in_area)
	var caches: int = count(Count.CACHES, in_area)
	var paid: PackedStringArray = [
		"+%s gold" % UiFormat.group_thousands(count(Count.GOLD, in_area))
	]
	var held: Dictionary[StringName, int] = resources(in_area)
	for resource: StringName in held:
		paid.append(
			"+%s %s" % [UiFormat.group_thousands(held[resource]), ResourceIcon.plural(resource)]
		)
	paid.append("%s XP" % UiFormat.group_thousands(count(Count.XP, in_area)))
	return [
		(
			"%d gate%s, %d cache%s"
			% [gates, "" if gates == 1 else "s", caches, "" if caches == 1 else "s"]
		),
		", ".join(paid),
	]


func _add(in_area: StringName, what: Count, amount: int) -> void:
	if not _counts.has(in_area):
		_counts[in_area] = [0, 0, 0, 0]
	var before: int = _counts[in_area][what]
	_counts[in_area][what] = before + amount
	changes += 1

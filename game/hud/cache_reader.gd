class_name CacheReader
extends RefCounted
## Reads what each opened cache paid out of the simulation's events. A cache's gains follow its
## [constant SimEvent.Kind.CACHE_OPENED] on the same tick: its gold, XP for each living hero,
## then the area's resource, which ends them. Fed every event in order through [method heard],
## it hands back each cache's [CacheReader.Pay] as its last gain arrives.

## The cache whose gains are still arriving, or null.
var _open: Pay


## Takes [param event]; returns the pay of the cache it completes, or null. A cache whose
## resource never came is complete at the first event of a later tick.
func heard(event: SimEvent) -> Pay:
	var done: Pay = null
	if _open != null and (event.tick != _open.tick or event.kind == SimEvent.Kind.CACHE_OPENED):
		done = _open
		_open = null
	if event.kind == SimEvent.Kind.CACHE_OPENED:
		_open = Pay.new()
		_open.tick = event.tick
		_open.opener = event.source_id
		return done
	if _open == null:
		return done
	match event.kind:
		SimEvent.Kind.GOLD_GAINED:
			_open.gold += event.amount
		SimEvent.Kind.XP_GAINED:
			_open.xp += event.amount
			_open.xp_each = maxi(_open.xp_each, event.amount)
		SimEvent.Kind.RESOURCE_GAINED:
			var ids: Array[StringName] = Content.resource_ids()
			if event.target_id >= 0 and event.target_id < ids.size():
				_open.resource = ids[event.target_id]
				_open.resource_amount = event.amount
			done = _open
			_open = null
	return done


## What one cache paid.
class Pay:
	extends RefCounted

	## The tick it was opened on, and the hero who opened its gate.
	var tick: int = -1
	var opener: int = -1
	## The party's gold, each living hero's XP and all of theirs together.
	var gold: int = 0
	var xp_each: int = 0
	var xp: int = 0
	## The area's resource and how many of it; &"" for none.
	var resource: StringName = &""
	var resource_amount: int = 0

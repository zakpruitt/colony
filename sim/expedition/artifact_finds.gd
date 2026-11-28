class_name ArtifactFinds
extends RefCounted
## Whether a cache opened holds a new class's artifact. Kept out of [Expedition] and
## [SidePathWalk] so neither file grows.
##
## The roll comes from a stream forked for that cache alone, as [ResourceDrops] forks one per
## kill: it draws nothing from the expedition's stream, and with no class left to find nothing is
## forked at all, so every other roll and every state hash is as it would be without it.


## Called once by [SidePathWalk] as the cache of the side path [param run]'s party is on pays,
## after the cache's own events, [param opener] having opened its gate. One number from 0 to 1
## is drawn; walking the classes not yet found and adding up their chances, the first whose
## running total passes it is found, with [constant SimEvent.Kind.ARTIFACT_FOUND].
static func on_cache(run: Expedition, opener: int) -> void:
	var candidates: Array[StringName] = _candidates(run._party)
	if candidates.is_empty():
		return
	var label: String = "artifact/%s/%d/%d/%d" % [run.place, run.depth, run.side_path, run._tick]
	var roll: float = run._rng.fork(label).next_float()
	var total: float = 0.0
	for class_id: StringName in candidates:
		total += Content.hero_class(class_id).artifact_chance
		if total > roll:
			_find(run, class_id, opener)
			return


## The classes not in [constant Party.STARTING_CLASSES] whose artifact [param party] has not
## found, in [method Content.hero_class_ids] order.
static func _candidates(party: Party) -> Array[StringName]:
	var found: Array[StringName] = []
	for class_id: StringName in Content.hero_class_ids():
		if not Party.STARTING_CLASSES.has(class_id) and not party.artifacts.has(class_id):
			found.append(class_id)
	return found


## Marks [param class_id]'s artifact found, keeping [member Party.artifacts] in class order.
static func _find(run: Expedition, class_id: StringName, opener: int) -> void:
	var ids: Array[StringName] = Content.hero_class_ids()
	var found: Array[StringName] = run._party.artifacts
	found.append(class_id)
	found.sort_custom(func(a: StringName, b: StringName) -> bool: return ids.find(a) < ids.find(b))
	run._emit(SimEvent.Kind.ARTIFACT_FOUND, opener, ids.find(class_id))

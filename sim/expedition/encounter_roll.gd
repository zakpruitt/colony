class_name EncounterRoll
extends RefCounted
## Which monsters wait in a chamber, and where they stand: [Expedition]'s rolls, kept apart so the
## expedition stays a readable size, with its guardians and the fighters' part of its state hash.
## Plain functions of their arguments; nothing here keeps state.


## The id of the guardian that holds that depth's way down, or &"" if the depth has none:
## on every [constant Expedition.GUARDIAN_EVERY]-th depth, the guardian with the deepest
## [member MonsterDef.min_depth] at or above it.
static func guardian_at(level_depth: int) -> StringName:
	var every: int = Expedition.GUARDIAN_EVERY
	if level_depth < every or level_depth % every != 0:
		return &""
	var found: StringName = &""
	var found_depth: int = 0
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if def.guardian and def.min_depth <= level_depth and def.min_depth > found_depth:
			found = id
			found_depth = def.min_depth
	return found


## The monsters of visit [param visit] to [param room] at [param level_depth]: the guardian
## [param guardian] alone when it is not &"", otherwise a count and mix drawn from [param rng].
## Their ids come from [method Expedition.monster_id].
static func roll(
	room: LabyrinthChamber, level_depth: int, visit: int, guardian: StringName, rng: SimRng
) -> Array[Combatant]:
	var monsters: Array[Combatant] = []
	if guardian != &"":
		# The guardian alone, whatever the chamber's kind.
		var guardian_id: int = Expedition.monster_id(level_depth, room.index, visit, 0)
		monsters.append(Combatant.from_monster(Content.monster(guardian), level_depth, guardian_id))
		spread(monsters, room)
		return monsters
	var count_range: Vector2i = Expedition.PLAIN_MONSTERS
	if room.kind == LabyrinthChamber.Kind.DEN:
		count_range = Expedition.DEN_MONSTERS
	elif room.kind == LabyrinthChamber.Kind.VAULT:
		count_range = Expedition.VAULT_MONSTERS
	var count: int = rng.next_int(count_range.x, count_range.y)

	# Eligible monsters, each as likely as its min_depth: deeper dwellers are favoured.
	var eligible: Array[MonsterDef] = []
	var total_weight: int = 0
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if def.min_depth <= level_depth and not def.guardian:
			eligible.append(def)
			total_weight += def.min_depth
	if eligible.is_empty():
		return monsters
	for i: int in count:
		var roll_value: int = rng.next_int(1, total_weight)
		var picked: MonsterDef = eligible[eligible.size() - 1]
		for def: MonsterDef in eligible:
			roll_value -= def.min_depth
			if roll_value <= 0:
				picked = def
				break
		var id: int = Expedition.monster_id(level_depth, room.index, visit, i)
		monsters.append(Combatant.from_monster(picked, level_depth, id))
	spread(monsters, room)
	return monsters


## Stands waiting monsters evenly over the middle half of the chamber's floor.
static func spread(monsters: Array[Combatant], room: LabyrinthChamber) -> void:
	var left: float = room.rect.position.x
	var right: float = room.rect.end.x - 1
	var quarter: float = (right - left) / 4.0
	for i: int in monsters.size():
		var share: float = (i + 0.5) / monsters.size()
		monsters[i].x = left + quarter + (right - left - 2.0 * quarter) * share


## [param fighters] as plain values, for the expedition's state hash.
static func hash_parts(fighters: Array) -> Array:
	var parts: Array = []
	for c: Combatant in fighters:
		var part: Array = [c.id, c.def_id, c.x, c.health, c.max_health, c.damage, c.state]
		part.append_array([c.target_id, c.strike_tick, c.ready_tick])
		parts.append(part)
	return parts

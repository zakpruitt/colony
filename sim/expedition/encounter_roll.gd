class_name EncounterRoll
extends RefCounted
## Which monsters wait in a chamber, and where they stand: [Expedition]'s rolls, kept apart so the
## expedition stays a readable size, with its guardians and the fighters' part of its state hash.
## Plain functions of their arguments; nothing here keeps state.


## The id of the guardian that holds stage [param stage] of [param area], or &"" if the stage has
## none: the area's guardian at its [member AreaDef.guardian_stage] and every
## [constant Expedition.GUARDIAN_EVERY] stages after it.
static func guardian_at(area: AreaDef, stage: int) -> StringName:
	if area == null or stage < area.guardian_stage:
		return &""
	if (stage - area.guardian_stage) % Expedition.GUARDIAN_EVERY != 0:
		return &""
	return area.guardian


## The monsters of visit [param visit] to [param room] at stage [param stage] of [param area]: the
## guardian [param guardian] alone when it is not &"", otherwise a count and mix drawn from
## [param rng] of the area's monsters that have appeared by that stage. They are as strong as the
## stage's level makes them ([method AreaDef.level_at]); their ids come from
## [method Expedition.monster_id].
static func roll(
	room: LabyrinthChamber, area: AreaDef, stage: int, visit: int, guardian: StringName, rng: SimRng
) -> Array[Combatant]:
	var monsters: Array[Combatant] = []
	var level: int = area.level_at(stage)
	if guardian != &"":
		# The guardian alone, whatever the chamber's kind.
		var guardian_id: int = Expedition.monster_id(stage, room.index, visit, 0)
		monsters.append(Combatant.from_monster(Content.monster(guardian), level, guardian_id))
		spread(monsters, room)
		return monsters
	var count_range: Vector2i = Expedition.PLAIN_MONSTERS
	if room.kind == LabyrinthChamber.Kind.DEN:
		count_range = Expedition.DEN_MONSTERS
	elif room.kind == LabyrinthChamber.Kind.VAULT:
		count_range = Expedition.VAULT_MONSTERS
	var count: int = rng.next_int(count_range.x, count_range.y)

	# The area's monsters that have appeared, in content order, each as likely as its base level:
	# the stronger kinds are favoured.
	var appeared: Dictionary[StringName, bool] = {}
	for i: int in mini(area.monsters.size(), area.monster_stages.size()):
		if area.monster_stages[i] <= stage:
			appeared[area.monsters[i]] = true
	var eligible: Array[MonsterDef] = []
	var total_weight: int = 0
	for id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(id)
		if appeared.has(id) and not def.guardian:
			eligible.append(def)
			total_weight += def.base_level
	if eligible.is_empty():
		return monsters
	for i: int in count:
		var roll_value: int = rng.next_int(1, total_weight)
		var picked: MonsterDef = eligible[eligible.size() - 1]
		for def: MonsterDef in eligible:
			roll_value -= def.base_level
			if roll_value <= 0:
				picked = def
				break
		var id: int = Expedition.monster_id(stage, room.index, visit, i)
		monsters.append(Combatant.from_monster(picked, level, id))
	spread(monsters, room)
	return monsters


## Stands waiting monsters evenly over the middle half of the chamber's floor.
static func spread(monsters: Array[Combatant], room: LabyrinthChamber) -> void:
	var left: float = room.floor_columns().x
	var right: float = room.floor_columns().y
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

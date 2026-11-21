class_name ChamberRules
extends RefCounted
## What a chamber of an area's labyrinth holds on a visit, as [Expedition] reads it: whether it is
## always empty or a guardian's, its side quest and its monsters. Plain functions of their
## arguments, depending only on the seed, the stage, the chamber and the visit; nothing here
## keeps state or changes the game.

## The chance that a plain chamber holds a side quest instead of monsters, on each visit.
const SIDE_QUEST_SHARE: float = 0.3


## True if chamber [param chamber_index] of [param level] never holds monsters or a side quest: the
## START chamber, and the chambers a party arrives in and the way on leaves from, unless a
## guardian of [param area] holds it.
static func always_empty(
	labyrinth: Labyrinth, area: AreaDef, level: LabyrinthLevel, chamber_index: int
) -> bool:
	if level.chambers[chamber_index].kind == LabyrinthChamber.Kind.START:
		return true
	if is_guardians(labyrinth, area, level.depth, chamber_index):
		return false
	var line: StageCourse = level.course
	return chamber_index == way_on_room(line) or chamber_index == line.chamber_at(line.entry)


## Index of the chamber the way on leaves [param line] from, which a guardian holds on its
## stages; -1 if it leaves from no chamber.
static func way_on_room(line: StageCourse) -> int:
	return line.chamber_at(line.exit)


## True for the chamber the way on leaves from, on a stage of [param area] that a guardian holds.
static func is_guardians(
	labyrinth: Labyrinth, area: AreaDef, level_depth: int, chamber_index: int
) -> bool:
	if chamber_index < 0 or EncounterRoll.guardian_at(area, level_depth) == &"":
		return false
	return way_on_room(labyrinth.level(level_depth).course) == chamber_index


## The visit a chamber with record [param fill] (null if none) is on at [param tick]: the next one
## once a cleared chamber's time to refill has come, though the record still says the last.
static func visit_now(fill: ChamberState, tick: int) -> int:
	if fill == null:
		return 0
	if fill.cleared_tick >= 0 and tick >= fill.refill_tick():
		return fill.visit + 1
	return fill.visit


## The side quest a chamber holds on [param visit] in place of monsters, or &"": only a plain
## chamber that is not always empty and holds no guardian, with chance [constant SIDE_QUEST_SHARE],
## drawn from a fork of [param rng].
static func quest_on_visit(
	labyrinth: Labyrinth,
	area: AreaDef,
	rng: SimRng,
	level_depth: int,
	chamber_index: int,
	visit: int
) -> StringName:
	var level: LabyrinthLevel = labyrinth.level(level_depth)
	if level.chambers[chamber_index].kind != LabyrinthChamber.Kind.PLAIN:
		return &""
	if is_guardians(labyrinth, area, level_depth, chamber_index):
		return &""
	if always_empty(labyrinth, area, level, chamber_index):
		return &""
	# Joined by hand: a format string builds an array, and this is asked as the party walks.
	var where: String = str(level_depth) + "/" + str(chamber_index) + "/" + str(visit)
	var quest_rng: SimRng = rng.fork(AreaTravel.label(area.id) + "sidequest/" + where)
	if not quest_rng.chance(SIDE_QUEST_SHARE):
		return &""
	var ids: Array[StringName] = Content.side_quest_ids()
	if ids.is_empty():
		return &""
	return ids[quest_rng.next_int(0, ids.size() - 1)]


## The monsters of one visit to a chamber, drawn from a fork of [param rng]. Which monsters, and
## their ids, depend only on the seed, stage, chamber and visit
## (see [method Expedition.monster_id]).
static func monsters_of(
	labyrinth: Labyrinth,
	area: AreaDef,
	rng: SimRng,
	level_depth: int,
	chamber_index: int,
	visit: int
) -> Array[Combatant]:
	var room: LabyrinthChamber = labyrinth.level(level_depth).chambers[chamber_index]
	var guardian: StringName = &""
	if is_guardians(labyrinth, area, level_depth, chamber_index):
		guardian = EncounterRoll.guardian_at(area, level_depth)
	var label: String = AreaTravel.label(area.id)
	var encounter: SimRng = rng.fork(
		label + "encounter/%d/%d/%d" % [level_depth, chamber_index, visit]
	)
	return EncounterRoll.roll(room, area, level_depth, visit, guardian, encounter)

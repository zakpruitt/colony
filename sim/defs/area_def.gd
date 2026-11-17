class_name AreaDef
extends Resource
## A place in the labyrinth the party can work in (spec 049): its own monsters and guardian, and
## stages that get harder from [member base_level]. One .tres file per area under res://data/areas.

@export var id: StringName
@export var display_name: String
## Where the area comes in the list of areas, lowest first.
@export var order: int
## The level of the area's first stage: stage s is level [code]base_level + s - 1[/code].
@export var base_level: int
## The monsters that live in the area.
@export var monsters: Array[StringName]
## The same length as [member monsters]: the first stage each appears at.
@export var monster_stages: Array[int]
## The guardian that holds the area's way on.
@export var guardian: StringName
## The stage the guardian first stands at; it stands again, stronger, every
## [constant Expedition.GUARDIAN_EVERY] stages after.
@export var guardian_stage: int
## The area whose guardian must be beaten to open this one; &"" for an area open from the start.
@export var opened_by: StringName
## The resource its monsters drop (spec 052), a [ResourceDef] id.
@export var resource: StringName


## The level of [param stage] in this area.
func level_at(stage: int) -> int:
	return base_level + stage - 1


## One line per problem; empty when the area is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id.is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if order < 1:
		problems.append("order %d is below 1" % order)
	if base_level < 1:
		problems.append("base_level %d is below 1" % base_level)
	if monsters.is_empty():
		problems.append("monsters is empty")
	if monsters.size() != monster_stages.size():
		problems.append(
			(
				"monsters (%d) and monster_stages (%d) are of different length"
				% [monsters.size(), monster_stages.size()]
			)
		)
	for i: int in monsters.size():
		var def: MonsterDef = Content.monster(monsters[i])
		if def == null:
			problems.append("monsters[%d]: unknown monster '%s'" % [i, monsters[i]])
		elif def.guardian:
			problems.append("monsters[%d]: '%s' is a guardian" % [i, monsters[i]])
	for i: int in monster_stages.size():
		if monster_stages[i] < 1:
			problems.append("monster_stages[%d] %d is below 1" % [i, monster_stages[i]])
	var boss: MonsterDef = Content.monster(guardian)
	if boss == null:
		problems.append("guardian: unknown monster '%s'" % guardian)
	elif not boss.guardian or boss.size != MonsterDef.Size.BOSS:
		problems.append("guardian: '%s' is not a boss" % guardian)
	if guardian_stage < 1:
		problems.append("guardian_stage %d is below 1" % guardian_stage)
	if opened_by != &"" and (opened_by == id or Content.area(opened_by) == null):
		problems.append("opened_by: unknown area '%s'" % opened_by)
	if Content.resource_def(resource) == null:
		problems.append("resource: unknown resource '%s'" % resource)
	return problems

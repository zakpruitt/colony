class_name TrainingDef
extends Resource
## Training bought for one hero with gold, rank by rank (spec 029). Each rank adds
## [member per_rank] to one of that hero's multipliers; the hero's next rank costs
## [code]base_cost * cost_growth ^ rank[/code], from that hero's own rank alone. One .tres file
## per training under res://data/training.

## What a training raises: damage and healing, maximum health, or attack speed.
enum Stat { POWER, TOUGHNESS, QUICKNESS }

@export var id: StringName
@export var display_name: String
@export var description: String  # one short line, e.g. "+5% damage and healing"
@export var order: int  # position on the hero sheet, lowest first
@export var stat: Stat
@export var per_rank: float
@export var base_cost: int
@export var cost_growth: float
@export var max_rank: int


## The price of rank [param rank] + 1, or 0 when [param rank] is the maximum or beyond.
func cost_at(rank: int) -> int:
	if rank < 0 or rank >= max_rank:
		return 0
	return roundi(base_cost * pow(cost_growth, rank))


## One line per problem; empty when the training is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if description.is_empty():
		problems.append("description is empty")
	if per_rank <= 0.0:
		problems.append("per_rank %s is not above 0" % per_rank)
	if base_cost < 1:
		problems.append("base_cost %d is below 1" % base_cost)
	if cost_growth <= 1.0:
		problems.append("cost_growth %s is not above 1" % cost_growth)
	if max_rank < 1:
		problems.append("max_rank %d is below 1" % max_rank)
	return problems

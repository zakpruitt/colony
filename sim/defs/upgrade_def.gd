class_name UpgradeDef
extends Resource
## A party-wide camp upgrade bought with gold, rank by rank. Each rank adds
## [member per_rank] to one stat's multiplier; the next rank costs
## [code]base_cost * cost_growth ^ rank[/code]. One .tres file per upgrade under
## res://data/upgrades.

enum Stat { DAMAGE, HEALTH, REST_HEALING, TRAVEL_SPEED, GOLD }

@export var id: StringName
@export var display_name: String
@export var description: String  # one short line, e.g. "+5% damage and healing"
@export var order: int  # position in the shop, lowest first
@export var stat: Stat
@export var per_rank: float
@export var base_cost: int
@export var cost_growth: float
@export var max_rank: int
## The resource the later ranks also cost, a [ResourceDef] id.
@export var resource: StringName
## The first rank (counting from 0) that also costs the resource: the ranks before it cost gold
## alone.
@export var resource_from_rank: int = 3
## The resource rank [member resource_from_rank] costs; each later rank costs [member cost_growth]
## times the one before, as the gold does.
@export var resource_base: int
## What the upgrade raises, in a few words for the shop's line of numbers:
## "Damage and healing". A view hint: no rule reads it.
@export var gives: String


## The price of rank [param rank] + 1, or -1 when [param rank] is the maximum or beyond.
func cost_at(rank: int) -> int:
	if rank < 0 or rank >= max_rank:
		return -1
	return roundi(base_cost * pow(cost_growth, rank))


## The resource the step from rank [param rank] to the next costs: 0 before
## [member resource_from_rank],
## [code]resource_base * cost_growth ^ (rank - resource_from_rank)[/code] from it, and -1
## when [param rank] is the maximum or beyond (as [method cost_at]).
func resource_cost_at(rank: int) -> int:
	if rank < 0 or rank >= max_rank:
		return -1
	if rank < resource_from_rank:
		return 0
	return roundi(resource_base * pow(cost_growth, rank - resource_from_rank))


## One line per problem; empty when the upgrade is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if description.is_empty():
		problems.append("description is empty")
	if gives.is_empty():
		problems.append("gives is empty")
	if per_rank <= 0.0:
		problems.append("per_rank %s is not above 0" % per_rank)
	if base_cost < 1:
		problems.append("base_cost %d is below 1" % base_cost)
	if cost_growth <= 1.0:
		problems.append("cost_growth %s is not above 1" % cost_growth)
	if max_rank < 1:
		problems.append("max_rank %d is below 1" % max_rank)
	if Content.resource_def(resource) == null:
		problems.append("resource: unknown resource '%s'" % resource)
	if resource_from_rank < 0:
		problems.append("resource_from_rank %d is below 0" % resource_from_rank)
	if resource_base < 1:
		problems.append("resource_base %d is below 1" % resource_base)
	return problems

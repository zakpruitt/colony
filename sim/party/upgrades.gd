class_name Upgrades
extends RefCounted
## The party's camp upgrades: the rank bought of each [UpgradeDef], and the
## multipliers they give. Ranks of one upgrade add up: rank r gives
## [code]1 + r * per_rank[/code].

var _ranks: Dictionary[StringName, int] = {}


## The rank bought of upgrade [param id]; 0 if none or unknown.
func rank(id: StringName) -> int:
	return _ranks.get(id, 0)


## The price of the next rank of [param id]; -1 at the maximum or unknown.
func cost(id: StringName) -> int:
	var def: UpgradeDef = Content.upgrade(id)
	if def == null:
		return -1
	return def.cost_at(rank(id))


## The factor every upgrade of [param stat] gives together; 1.0 with no ranks.
func multiplier(stat: UpgradeDef.Stat) -> float:
	var bonus: float = 0.0
	for id: StringName in _ranks:
		var def: UpgradeDef = Content.upgrade(id)
		if def != null and def.stat == stat:
			bonus += _ranks[id] * def.per_rank
	return 1.0 + bonus


## Sets the rank of [param id] directly (loading a save, tests). Unknown ids are ignored;
## the rank is clamped to 0 .. the maximum.
func set_rank(id: StringName, new_rank: int) -> void:
	var def: UpgradeDef = Content.upgrade(id)
	if def == null:
		return
	var clamped: int = clampi(new_rank, 0, def.max_rank)
	if clamped == 0:
		_ranks.erase(id)
	else:
		_ranks[id] = clamped


## The id of the cheapest next rank [param gold] can pay for, earlier in the shop
## on a tie; &"" when none.
func cheapest_affordable(gold: int) -> StringName:
	var best: StringName = &""
	var best_cost: int = -1
	for id: StringName in Content.upgrade_ids():
		var price: int = cost(id)
		if price < 0 or price > gold:
			continue
		if best_cost < 0 or price < best_cost:
			best = id
			best_cost = price
	return best


## True when any upgrade has a rank above 0.
func any() -> bool:
	return not _ranks.is_empty()


## The ranks as plain values, in shop order, for the state hash.
func hash_parts() -> Array:
	var parts: Array = []
	for id: StringName in Content.upgrade_ids():
		parts.append(rank(id))
	return parts

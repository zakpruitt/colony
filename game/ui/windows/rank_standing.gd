class_name RankStanding
extends RefCounted
## Where a hero stands in one of its paths, worked out once from the tree's rank table: the rank,
## the XP into it and the span to the next, and whether it is the top. The rank bar, its tooltip,
## the strip and the node states all read it, so they say the same thing.

var rank: int = 0
## XP gained since the rank's threshold, and the XP between that threshold and the next (0 at the
## top).
var into: int = 0
var span: int = 0
var top: bool = false


## [param hero]'s standing in path [param path] of [param tree].
static func of(hero: Hero, path: int, tree: TalentTreeDef) -> RankStanding:
	var made := RankStanding.new()
	made.rank = hero.ranks.rank(path, tree)
	made.top = made.rank >= tree.rank_xp.size()
	var floor_xp: int = tree.rank_xp[made.rank - 1] if made.rank > 0 else 0
	made.into = hero.ranks.xp(path) - floor_xp
	made.span = 0 if made.top else tree.rank_xp[made.rank] - floor_xp
	return made


## The rank short of which [param hero] is for [param ability_id] of [param tree]: the rank that
## opens it while its path is below that, else 0.
static func short_of(hero: Hero, ability_id: StringName, tree: TalentTreeDef) -> int:
	var needed: int = tree.rank_needed(ability_id)
	return needed if hero.ranks.rank(tree.path_of(ability_id), tree) < needed else 0


## How much of the bar is filled: the XP into the rank of its span, full at the top.
func share() -> float:
	return 1.0 if top else float(into) / maxf(span, 1.0)


## [code]6 of 28 XP to rank 4[/code]; "" at the top.
func progress() -> String:
	return "" if top else "%d of %d XP to rank %d" % [into, span, rank + 1]

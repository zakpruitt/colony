class_name PathRanks
extends RefCounted
## One hero's XP in each of its class's three paths, and the rank it gives by the class's
## [member TalentTreeDef.rank_xp]. XP only grows, so a rank never goes down; a fresh start of the
## talents keeps it.

var _xp: Array[int] = []


func _init() -> void:
	_xp.resize(TalentTreeDef.PATH_COUNT)
	_xp.fill(0)


## The XP in path [param path] (0 to 2); 0 for any other index.
func xp(path: int) -> int:
	return _xp[path] if path >= 0 and path < _xp.size() else 0


## The rank of path [param path] by [param tree]'s thresholds; 0 without a tree.
func rank(path: int, tree: TalentTreeDef) -> int:
	return tree.rank_at(xp(path)) if tree != null else 0


## Adds amount (0 or more) to path's XP; returns the rank before.
func add(path: int, amount: int, tree: TalentTreeDef) -> int:
	var before: int = rank(path, tree)
	if path >= 0 and path < _xp.size():
		_xp[path] += maxi(amount, 0)
	return before


## Sets path [param path]'s XP directly (loading a save, tests).
func set_xp(path: int, value: int) -> void:
	if path >= 0 and path < _xp.size():
		_xp[path] = maxi(value, 0)


## True when some path has XP above 0.
func any() -> bool:
	for each: int in _xp:
		if each > 0:
			return true
	return false

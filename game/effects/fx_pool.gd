class_name FxPool
extends RefCounted
## Every passing effect node on the world's effects layer: particles, texts, flashes, rings,
## coins, motes and resource icons. Each effect class adds what it makes under a budget; the pool
## puts it on the layer, advances everything once a frame and frees what has finished, so nothing
## stays on the layer once its effects are over.
##
## A pooled node has [code]advance(delta: float) -> bool[/code], false once it is finished. A
## budget in [constant CAPS] holds at most that many nodes at once (an add past it is refused and
## the node freed); any other budget is only a name to count by.

## The particles each effect class may have at once.
const COMBAT: int = 300
const ABILITY: int = 150
const SPELL: int = 120
const QUEST: int = 120
## The capped budgets, by name.
const CAPS: Dictionary[StringName, int] = {
	&"combat": COMBAT,
	&"ability": ABILITY,
	&"spell": SPELL,
	&"quest": QUEST,
}

var _layer: Node2D
## Every node held, oldest first, and the budget each was added under.
var _nodes: Array[Node2D] = []
var _budget_of: Dictionary[Node2D, StringName] = {}
var _counts: Dictionary[StringName, int] = {}


## Call once: what is added goes on [param layer].
func setup(layer: Node2D) -> void:
	_layer = layer


## Puts [param node] on the layer under [param budget], whose cap [param allowance] raises for
## this one add. False, with the node freed, when the budget is spent.
func add(node: Node2D, budget: StringName, allowance: int = 0) -> bool:
	if _layer == null or (CAPS.has(budget) and count(budget) >= CAPS[budget] + allowance):
		node.free()
		return false
	_layer.add_child(node)
	_nodes.append(node)
	_budget_of[node] = budget
	_counts[budget] = _counts.get(budget, 0) + 1
	return true


## Advances every node by [param delta] seconds, in the order they were added, and frees each
## that has finished.
func advance(delta: float) -> void:
	for node: Node2D in _nodes.duplicate():
		if not _budget_of.has(node):
			continue  # taken away by another's advance this frame
		var going: bool = node.call(&"advance", delta)
		if not going:
			remove(node)


## How many nodes are held under [param kind], or in all with none.
func count(kind: StringName = &"") -> int:
	if kind == &"":
		return _nodes.size()
	return _counts.get(kind, 0)


## The nodes held under [param kind], oldest first.
func nodes(kind: StringName) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node2D in _nodes:
		if _budget_of[node] == kind:
			found.append(node)
	return found


## True while [param node] is held.
func has(node: Node2D) -> bool:
	return node != null and _budget_of.has(node)


## Takes [param node] off the layer and frees it now, before its end (a spell grounded, a name
## pushed out). Nothing for a node the pool does not hold.
func remove(node: Node2D) -> void:
	if not has(node):
		return
	var budget: StringName = _budget_of[node]
	_budget_of.erase(node)
	_nodes.erase(node)
	_counts[budget] -= 1
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


## Takes every node away.
func clear() -> void:
	for node: Node2D in _nodes.duplicate():
		remove(node)

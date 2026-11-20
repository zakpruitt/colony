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
## Every node added, oldest first: the order they advance in. A node taken away early stays here
## until the next advance drops it.
var _nodes: Array[Node2D] = []
## The nodes held under each budget, oldest first.
var _kinds: Dictionary[StringName, Array] = {}
var _budget_of: Dictionary[Node2D, StringName] = {}
## Per budget, the nodes finished in the advance under way, still in its list until it ends.
var _done: Dictionary[StringName, int] = {}


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
	_kind(budget).append(node)
	_budget_of[node] = budget
	return true


## Advances every node by [param delta] seconds, in the order they were added, and frees each
## that has finished. A node added meanwhile first moves on the next frame.
func advance(delta: float) -> void:
	var held: int = _nodes.size()
	var finished: int = 0
	for i: int in held:
		var node: Node2D = _nodes[i]
		if _budget_of.has(node) and not node.call(&"advance", delta):
			var budget: StringName = _budget_of[node]
			_done[budget] = _done.get(budget, 0) + 1
			_let_go(node)
			finished += 1
	if finished == 0 and held == _nodes.size() and _budget_of.size() == held:
		return
	var kept: Array[Node2D] = []
	for node: Node2D in _nodes:
		if _budget_of.has(node):
			kept.append(node)
	_nodes = kept
	_done.clear()
	for kind: StringName in _kinds:
		_kinds[kind] = []
	for node: Node2D in kept:
		_kinds[_budget_of[node]].append(node)


## How many nodes are held under [param kind], or in all with none.
func count(kind: StringName = &"") -> int:
	if kind == &"":
		return _budget_of.size()
	if not _kinds.has(kind):
		return 0
	return _kinds[kind].size() - _done.get(kind, 0)


## The nodes held under [param kind], oldest first.
func nodes(kind: StringName) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not _kinds.has(kind):
		return found
	if _done.get(kind, 0) == 0:
		found.assign(_kinds[kind])
		return found
	for node: Node2D in _kinds[kind]:
		if _budget_of.has(node):
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
	_kinds[_budget_of[node]].erase(node)
	_let_go(node)  # erased from its list already, so not counted as done


## Takes every node away.
func clear() -> void:
	for node: Node2D in _budget_of.keys():
		_let_go(node)
	_nodes.clear()
	_done.clear()
	for kind: StringName in _kinds:
		_kinds[kind] = []


## The nodes of [param budget], made the first time it is used.
func _kind(budget: StringName) -> Array:
	if not _kinds.has(budget):
		_kinds[budget] = []
	return _kinds[budget]


## Forgets [param node] and frees it. Its budget's list is put right by the caller.
func _let_go(node: Node2D) -> void:
	_budget_of.erase(node)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

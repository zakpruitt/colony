class_name TalentTreeDef
extends Resource
## One class's talent tree (spec 051): a trunk of nodes taken in order, then two named paths of
## nodes taken in order, of which a hero may walk only one. Each node is an [AbilityDef] id. One
## .tres file per class under res://data/talents.

## Nodes in the trunk, and in each path.
const TRUNK_LENGTH: int = 3
const PATH_LENGTH: int = 4

@export var class_id: StringName
@export var trunk: Array[StringName] = []  # ability ids, in order
@export var path_names: Array[String] = []  # two
@export var path_a: Array[StringName] = []
@export var path_b: Array[StringName] = []


## Path [param index] (0 or 1), or an empty list for any other index.
func path_nodes(index: int) -> Array[StringName]:
	match index:
		0:
			return path_a
		1:
			return path_b
	var none: Array[StringName] = []
	return none


## Which path [param ability_id] is on: 0 or 1, or -1 if it is in neither.
func path_of(ability_id: StringName) -> int:
	if path_a.has(ability_id):
		return 0
	if path_b.has(ability_id):
		return 1
	return -1


## True if [param ability_id] is a node anywhere in this tree.
func has_node(ability_id: StringName) -> bool:
	return trunk.has(ability_id) or path_of(ability_id) >= 0


## The nodes that may be taken after [param taken] (a legal order of nodes): the next trunk node,
## then the first node of either path, then the next node of the path begun; empty when full.
func next_nodes(taken: Array[StringName]) -> Array[StringName]:
	var count: int = taken.size()
	var next: Array[StringName] = []
	if count < trunk.size():
		next.append(trunk[count])
	elif count == trunk.size():
		for index: int in 2:
			if not path_nodes(index).is_empty():
				next.append(path_nodes(index)[0])
	else:
		var walked: Array[StringName] = path_nodes(path_of(taken[trunk.size()]))
		var step: int = count - trunk.size()
		if step < walked.size():
			next.append(walked[step])
	return next


## Why [param taken] is not a legal order of this tree's nodes, naming the first node that breaks
## it by its place ("[2] 'meteor' ..."), or "" when it is legal.
func order_problem(taken: Array[StringName]) -> String:
	var so_far: Array[StringName] = []
	for i: int in taken.size():
		var node: StringName = taken[i]
		if not has_node(node):
			return "[%d]: '%s' is not in the %s tree" % [i, node, class_id]
		if not next_nodes(so_far).has(node):
			return "[%d]: '%s' cannot be taken there (trunk in order, then one path)" % [i, node]
		so_far.append(node)
	return ""


## One line per problem; empty when the tree is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(class_id).is_empty():
		problems.append("class_id is empty")
	elif Content.hero_class(class_id) == null:
		problems.append("class_id '%s' is not a hero class" % class_id)
	if trunk.size() != TRUNK_LENGTH:
		problems.append("trunk has %d nodes, not %d" % [trunk.size(), TRUNK_LENGTH])
	if path_names.size() != 2:
		problems.append("path_names has %d names, not 2" % path_names.size())
	for name_text: String in path_names:
		if name_text.is_empty():
			problems.append("a path name is empty")
	for label: String in ["path_a", "path_b"]:
		var nodes: Array[StringName] = path_a if label == "path_a" else path_b
		if nodes.size() != PATH_LENGTH:
			problems.append("%s has %d nodes, not %d" % [label, nodes.size(), PATH_LENGTH])
	var seen: Dictionary[StringName, bool] = {}
	for node: StringName in trunk + path_a + path_b:
		if seen.has(node):
			problems.append("'%s' is in the tree twice" % node)
		seen[node] = true
		var ability: AbilityDef = Content.ability(node)
		if ability == null:
			problems.append("'%s' is not an ability under %s" % [node, Content.ABILITIES_DIR])
	return problems

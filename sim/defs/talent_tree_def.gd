class_name TalentTreeDef
extends ContentDef
## One class's talent tree: three named [SkillPathDef]s of five nodes, each node an
## [AbilityDef] id. Nothing closes a path: a hero may take every node of all three, each once the
## node before it in its path is taken. One .tres file per class under res://data/talents.

const PATH_COUNT: int = 3
const PATH_LENGTH: int = 5
## The tier of each place in SkillPathDef.nodes.
const TIERS: Array[int] = [1, 2, 2, 3, 4]
## The longest a path's summary may be, in characters: one short line.
const _SUMMARY_LENGTH: int = 60

@export var class_id: StringName
@export var paths: Array[SkillPathDef] = []


## Path [param index] (0 to 2), or null for any other index.
func path(index: int) -> SkillPathDef:
	if index < 0 or index >= paths.size():
		return null
	return paths[index]


## Which path [param ability_id] is on: 0 to 2, or -1 if it is on none.
func path_of(ability_id: StringName) -> int:
	for index: int in paths.size():
		if paths[index] != null and paths[index].nodes.has(ability_id):
			return index
	return -1


## The tier of [param ability_id] in its path, 1 to 4, or 0 if it is not in this tree.
func tier_of(ability_id: StringName) -> int:
	var place: int = _place_of(ability_id)
	return TIERS[place] if place >= 0 and place < TIERS.size() else 0


## True if [param ability_id] is a node anywhere in this tree.
func has_node(ability_id: StringName) -> bool:
	return path_of(ability_id) >= 0


## The nodes any one of which must be taken before [param ability_id]; empty for tier 1, and
## for a node not in this tree.
func needs(ability_id: StringName) -> Array[StringName]:
	var before: Array[StringName] = []
	var on: int = path_of(ability_id)
	if on < 0:
		return before
	var nodes: Array[StringName] = paths[on].nodes
	var place: int = nodes.find(ability_id)
	var tier: int = TIERS[place] if place < TIERS.size() else 0
	for other: int in mini(nodes.size(), TIERS.size()):
		if TIERS[other] == tier - 1:
			before.append(nodes[other])
	return before


## The nodes not in [param taken] whose needs [param taken] meets, by path, then tier, then left
## to right.
func open_nodes(taken: Array[StringName]) -> Array[StringName]:
	var open: Array[StringName] = []
	for each: SkillPathDef in paths:
		if each == null:
			continue
		for node: StringName in each.nodes:
			if not taken.has(node) and _needs_met(node, taken):
				open.append(node)
	return open


## "" if [param taken] is a legal order of this tree's nodes, else why not, naming the first node
## that breaks it by its place ("[2]: 'meteor' ...").
func order_problem(taken: Array[StringName]) -> String:
	var so_far: Array[StringName] = []
	for i: int in taken.size():
		var node: StringName = taken[i]
		if not has_node(node):
			return "[%d]: '%s' is not in the %s tree" % [i, node, class_id]
		if so_far.has(node):
			return "[%d]: '%s' is taken twice" % [i, node]
		if not _needs_met(node, so_far):
			return "[%d]: '%s' is taken before %s" % [i, node, " or ".join(needs(node))]
		so_far.append(node)
	return ""


## [param taken] in the order a fighter tries them: the highest tier first; within a tier, the
## first path first; within a path's tier, left before right.
func fight_order(taken: Array[StringName]) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for tier: int in range(TIERS[TIERS.size() - 1], 0, -1):
		for each: SkillPathDef in paths:
			if each == null:
				continue
			for place: int in mini(each.nodes.size(), TIERS.size()):
				if TIERS[place] == tier and taken.has(each.nodes[place]):
					ordered.append(each.nodes[place])
	return ordered


## The path holding the most of [param taken] (a tie goes to the earlier path), or -1 for none.
func main_path(taken: Array[StringName]) -> int:
	var best: int = -1
	var most: int = 0
	for index: int in paths.size():
		var held: int = 0
		if paths[index] != null:
			for node: StringName in paths[index].nodes:
				if taken.has(node):
					held += 1
		if held > most:
			most = held
			best = index
	return best


## What Content finds this definition by: its class.
func key() -> StringName:
	return class_id


## One line per problem; empty when the tree is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(class_id).is_empty():
		problems.append("class_id is empty")
	elif Content.hero_class(class_id) == null:
		problems.append("class_id '%s' is not a hero class" % class_id)
	else:
		var known: TalentTreeDef = Content.talent_tree(class_id)
		if known != null and known != self and known.resource_path != resource_path:
			problems.append(
				"the %s already has a tree, %s: one tree a class" % [class_id, known.resource_path]
			)
	if paths.size() != PATH_COUNT:
		problems.append("it has %d paths, not %d" % [paths.size(), PATH_COUNT])
	var seen: Dictionary[StringName, bool] = {}
	for index: int in paths.size():
		var each: SkillPathDef = paths[index]
		var where: String = "paths[%d]" % index
		if each == null:
			problems.append("%s is empty" % where)
			continue
		if each.display_name.strip_edges().is_empty():
			problems.append("%s: the path name is empty" % where)
		if each.summary.strip_edges().is_empty():
			problems.append("%s: the path summary is empty" % where)
		elif each.summary.length() > _SUMMARY_LENGTH:
			problems.append(
				(
					"%s: the path summary '%s' is over %d characters"
					% [where, each.summary, _SUMMARY_LENGTH]
				)
			)
		if each.nodes.size() != PATH_LENGTH:
			problems.append("%s has %d nodes, not %d" % [where, each.nodes.size(), PATH_LENGTH])
		for node: StringName in each.nodes:
			if seen.has(node):
				problems.append("'%s' is in the tree twice" % node)
			seen[node] = true
			var ability: AbilityDef = Content.ability(node)
			if ability == null:
				problems.append("'%s' is not an ability under %s" % [node, Content.ABILITIES_DIR])
			elif ability.is_action() and not ability.ready_at_start:
				# Fights last seconds, so an action waits only for its condition.
				problems.append("'%s' is an action not ready as a fight starts" % node)
	return problems


func _place_of(ability_id: StringName) -> int:
	var on: int = path_of(ability_id)
	return paths[on].nodes.find(ability_id) if on >= 0 else -1


func _needs_met(node: StringName, taken: Array[StringName]) -> bool:
	var before: Array[StringName] = needs(node)
	if before.is_empty():
		return true
	for other: StringName in before:
		if taken.has(other):
			return true
	return false

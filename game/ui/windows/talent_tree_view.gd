class_name TalentTreeView
extends Control
## One class's talent tree as a hero window's Talents tab draws it (spec 055, on the UI layer by
## spec 060): the trunk's three nodes in a row, then each path's name over its four nodes in a
## column, the two paths side by side, and the lines that join them, drawn in [method _draw].
## Every node shows its words in full ([TalentNode]), so the view is as tall as they need.

## UI pixels between two trunk nodes, between the two path columns and between two nodes of a
## path.
const TRUNK_GAP: float = 12.0
const COLUMN_GAP: float = 12.0
const NODE_GAP: float = 5.0
## UI pixels from the trunk's bottom to the line the paths fork from, and from it to the paths'
## names.
const FORK_DROP: float = 5.0
const NAME_DROP: float = 3.0

## The tree shown.
var tree: TalentTreeDef
## The trunk's nodes, left to right.
var trunk_nodes: Array[TalentNode] = []
## Each path's nodes, top to bottom.
var path_nodes: Array[Array] = [[], []]
## Each path's name.
var path_labels: Array[Label] = []

## The line the paths fork from, under the trunk.
var _fork_y: float = 0.0
## The hero's path, or -1: a closed path's name is struck through.
var _walked: int = -1
var _by_id: Dictionary[StringName, TalentNode] = {}


## The view of [param tree_def], [param width] UI pixels wide.
func _init(tree_def: TalentTreeDef, width: float) -> void:
	tree = tree_def
	name = "Tree_%s" % tree.class_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trunk_width: float = floorf((width - TRUNK_GAP * (tree.trunk.size() - 1)) / 3.0)
	var x: float = 0.0
	var trunk_bottom: float = 0.0
	for id: StringName in tree.trunk:
		var made: TalentNode = _add(id, -1, trunk_width)
		made.position = Vector2(x, 0)
		trunk_nodes.append(made)
		x += trunk_width + TRUNK_GAP
		trunk_bottom = maxf(trunk_bottom, made.size.y)
	_fork_y = trunk_bottom + FORK_DROP
	var column_width: float = floorf((width - COLUMN_GAP) / 2.0)
	var bottom: float = _fork_y
	for index: int in 2:
		var column: float = index * (column_width + COLUMN_GAP)
		var label_text: String = tree.path_names[index] if index < tree.path_names.size() else ""
		var label: Label = WindowText.label("Path%d" % index, label_text, &"steel", true)
		label.mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip
		label.position = Vector2(column + TalentNode.TEXT_X, _fork_y + NAME_DROP)
		add_child(label)
		path_labels.append(label)
		# The line through a closed path's name, over the text.
		var strike := ColorRect.new()
		strike.name = "Strike"
		strike.color = Palette.color(&"silver")
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strike.position = Vector2(-1, 6)
		strike.size = Vector2(UiText.width(label_text, true) + 1.0, 1)
		strike.visible = false
		label.add_child(strike)
		var y: float = label.position.y + UiText.LINE_HEIGHT + NODE_GAP
		for id: StringName in tree.path_nodes(index):
			var made: TalentNode = _add(id, index, column_width)
			made.position = Vector2(column, y)
			path_nodes[index].append(made)
			y += made.size.y + NODE_GAP
		bottom = maxf(bottom, y - NODE_GAP)
	size = Vector2(width, bottom)
	custom_minimum_size = size


## Every node, the trunk first.
func nodes() -> Array[TalentNode]:
	var all: Array[TalentNode] = trunk_nodes.duplicate()
	for index: int in 2:
		for made: TalentNode in path_nodes[index]:
			all.append(made)
	return all


## The node of [param ability_id], or null.
func node(ability_id: StringName) -> TalentNode:
	return _by_id.get(ability_id, null)


## True if [param ability_id] is a node of this tree.
func has_ability(ability_id: StringName) -> bool:
	return _by_id.has(ability_id)


## How the node of [param ability_id] stands, as last refreshed.
func state_of(ability_id: StringName) -> TalentNode.State:
	var found: TalentNode = node(ability_id)
	return found.state() if found != null else TalentNode.State.LOCKED


## True while path [param index]'s name is struck through: the hero walks the other.
func is_closed(index: int) -> bool:
	return _walked >= 0 and _walked != index


## Sets every node's state from [param hero] and runs the pulses on by [param delta] seconds.
func refresh(hero: Hero, delta: float) -> void:
	var taken: Array[StringName] = hero.talents()
	var walked: int = hero.path()
	for made: TalentNode in nodes():
		var stands: TalentNode.State = TalentNode.State.LOCKED
		if taken.has(made.ability_id):
			stands = TalentNode.State.TAKEN
		elif walked >= 0 and made.path >= 0 and made.path != walked:
			stands = TalentNode.State.CLOSED
		elif hero.can_take(made.ability_id):
			stands = TalentNode.State.AVAILABLE
		made.show_state(stands, stands == TalentNode.State.AVAILABLE)
		made.advance(delta)
	for index: int in path_labels.size():
		var colour: StringName = &"steel"
		if walked == index:
			colour = &"white"
		elif walked >= 0:
			colour = &"slate"
		path_labels[index].add_theme_color_override(&"font_color", Palette.color(colour))
	_walked = walked
	for index: int in path_labels.size():
		(path_labels[index].get_node("Strike") as ColorRect).visible = is_closed(index)
	queue_redraw()


## The lines that join the nodes, each [Rect2, the nodes it joins]: between the trunk's nodes,
## then the fork down from the last trunk node's picture, across to both paths and down each,
## every line beside the words, never through them.
func joins() -> Array[Array]:
	var all: Array[Array] = []
	var middle: float = TalentNode.BOX.y / 2.0
	for i: int in range(1, trunk_nodes.size()):
		var from: TalentNode = trunk_nodes[i - 1]
		var to: TalentNode = trunk_nodes[i]
		var start: float = from.position.x + from.size.x + 2.0
		all.append([Rect2(start, middle, to.position.x - 2.0 - start, 2), [from, to]])
	if trunk_nodes.is_empty():
		return all
	var last: TalentNode = trunk_nodes[trunk_nodes.size() - 1]
	var drop_x: float = last.position.x + middle - 1.0
	var under: float = TalentNode.BOX.y + 2.0
	all.append([Rect2(drop_x, under, 2, _fork_y - under), [last]])
	var spines: Array[float] = []
	for index: int in 2:
		var column: Array = path_nodes[index]
		var first_x: float = (column[0] as TalentNode).position.x if not column.is_empty() else 0.0
		spines.append(first_x + middle - 1.0)
	var left: float = minf(spines[0], drop_x)
	var right: float = maxf(spines[1], drop_x)
	all.append([Rect2(left, _fork_y, right - left + 2.0, 2), [last]])
	for index: int in 2:
		var column: Array = path_nodes[index]
		if column.is_empty():
			continue
		var first: TalentNode = column[0]
		var top: float = _fork_y + 2.0
		all.append([Rect2(spines[index], top, 2, first.position.y - 2.0 - top), [last, first]])
		for step: int in range(1, column.size()):
			var above: TalentNode = column[step - 1]
			var below: TalentNode = column[step]
			var from_y: float = above.position.y + TalentNode.BOX.y + 2.0
			var gap: float = below.position.y - 2.0 - from_y
			all.append([Rect2(spines[index], from_y, 2, gap), [above, below]])
	return all


func _draw() -> void:
	for join: Array in joins():
		var rect: Rect2 = join[0]
		var ends: Array = join[1]
		_line(rect, ends)


func _add(id: StringName, on_path: int, width: float) -> TalentNode:
	var made := TalentNode.new(id, on_path, width)
	add_child(made)
	_by_id[id] = made
	return made


## Draws one joining line: silver when every node it joins is taken, dusk when any is closed,
## slate otherwise.
func _line(rect: Rect2, ends: Array) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var colour: StringName = &"silver"
	for end: TalentNode in ends:
		if end.state() == TalentNode.State.CLOSED:
			colour = &"dusk"
			break
		if end.state() != TalentNode.State.TAKEN:
			colour = &"slate"
	draw_rect(rect, Palette.color(colour))

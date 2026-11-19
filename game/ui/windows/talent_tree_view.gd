class_name TalentTreeView
extends Control
## One class's talent tree as a hero window's Talents tab draws it (spec 064 R1 to R3, R8): a tree
## of pictures that forks. The trunk's three nodes run down the middle from the top, joined by lines
## with arrowheads; under the last one the line splits left and right into the two paths, each a
## column of four nodes under its [PathBanner], the two columns far apart. Each path has its own
## colour ([PathColours]): its banner, the lines lit along it and its nodes' tint.
##
## A line into a taken node is lit (the path's colour, or [constant TRUNK_LIT] on the trunk), one
## into a node of the closed path is dark, any other plain. [method light] makes the line into a
## node just taken flash; [method close_path] closes a path before the player's eyes, its banner and
## then its nodes one after another, within [constant CLOSE_SECONDS]. Both are only started for
## what just happened ([HeroWindows] asks).

## UI pixels between two node columns' middles: the trunk's and each path's.
const PATH_SPREAD: float = 180.0
## The least clear space between the two paths' columns, names included (a test holds the tree to
## it): the fork is the plainest thing on the tab.
const PATH_GAP: float = 160.0
## UI pixels from a node's name down to the next node's slot: the line and its arrowhead.
const ARROW: float = 5.0
## The line's thickness, and the arrowhead's rows (widths, top to bottom) above a node's slot.
const LINE: float = 2.0
const HEAD: Array[int] = [5, 3, 1]
## UI pixels between an arrowhead's tip and the slot it points at (the path's tint ring is there).
const HEAD_CLEAR: float = 1.0
## UI pixels from the trunk's last name down to the fork's line.
const STUB: float = 2.0
## The banners' width, and the gap between a banner and the fork's line under it.
const BANNER_WIDTH: float = 220.0
const BANNER_CLEAR: float = 4.0
## Line colours: lit on the trunk, plain, and dark (into a closed path); a flash just lit.
const TRUNK_LIT: StringName = &"sand"
const UNLIT: StringName = &"steel"
const DARK: StringName = &"dusk"
const FLASH: StringName = &"white"
## Seconds the line into a node just taken flashes.
const FLASH_SECONDS: float = 0.5
## Seconds a path takes to close before the player's eyes, and between its banner and each node.
const CLOSE_SECONDS: float = 0.4
const CLOSE_STEP: float = 0.08

## The tree shown.
var tree: TalentTreeDef
## The trunk's nodes, top to bottom.
var trunk_nodes: Array[TalentNode] = []
## Each path's nodes, top to bottom.
var path_nodes: Array[Array] = [[], []]
## Each path's banner, and its name (kept for the callers of spec 055).
var banners: Array[PathBanner] = []
var path_labels: Array[Label] = []

## The fork's line, under the trunk.
var _fork_y: float = 0.0
var _middle: float = 0.0
## The hero's path, or -1.
var _walked: int = -1
var _by_id: Dictionary[StringName, TalentNode] = {}
## Seconds left of each node's line flash.
var _flashes: Dictionary[StringName, float] = {}
## The path closing before the player's eyes (-1: none), and how far it has got.
var _closing: int = -1
var _closing_time: float = 0.0
var _hovered: StringName = &""


## The view of [param tree_def], [param width] UI pixels wide.
func _init(tree_def: TalentTreeDef, width: float) -> void:
	tree = tree_def
	name = "Tree_%s" % tree.class_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_middle = floorf(width / 2.0)
	var y: float = 0.0
	var trunk_bottom: float = 0.0
	for id: StringName in tree.trunk:
		var made: TalentNode = _add(id, -1)
		made.position = Vector2(_middle - TalentNode.SLOT.x / 2.0, y)
		trunk_nodes.append(made)
		trunk_bottom = y + made.full_height()
		y = trunk_bottom + ARROW
	_fork_y = trunk_bottom + STUB
	var columns: Array[float] = [_middle - PATH_SPREAD, _middle + PATH_SPREAD]
	for index: int in 2:
		for id: StringName in tree.path_nodes(index):
			path_nodes[index].append(_add(id, index))
	y = _fork_y + LINE + ARROW
	var bottom: float = y
	for step: int in TalentTreeDef.PATH_LENGTH:
		var tall: float = 0.0
		for index: int in 2:
			if step >= path_nodes[index].size():
				continue
			var made: TalentNode = path_nodes[index][step]
			made.position = Vector2(columns[index] - TalentNode.SLOT.x / 2.0, y)
			tall = maxf(tall, made.full_height())
		bottom = y + tall
		y = bottom + ARROW
	var banner_height: float = 0.0
	for index: int in 2:
		if index >= tree.path_names.size():
			continue
		var banner := PathBanner.new(tree, index, BANNER_WIDTH)
		var left: float = clampf(columns[index] - BANNER_WIDTH / 2.0, 0.0, width - BANNER_WIDTH)
		banner.position.x = floorf(left)
		add_child(banner)
		banners.append(banner)
		path_labels.append(banner.name_label)
		banner_height = maxf(banner_height, banner.size.y)
	for banner: PathBanner in banners:
		banner.set_height(banner_height)
		banner.position.y = _fork_y - BANNER_CLEAR - banner_height
	size = Vector2(width, bottom)
	custom_minimum_size = size


## Every node, the trunk first, then the first path's, then the second's.
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


## True while path [param index] is closed: the hero walks the other.
func is_closed(index: int) -> bool:
	return _walked >= 0 and _walked != index


## The palette name of path [param index]'s colour.
func path_colour(index: int) -> StringName:
	return PathColours.of(tree.class_id, index)


## The node under the mouse, or &"" for none.
func hovered() -> StringName:
	return _hovered


## Sets every node's state from [param hero] and runs the pulses, the flashes and a closing on by
## [param delta] seconds.
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
		made.show_state(stands)
		made.advance(delta)
	_walked = walked
	for id: StringName in _flashes.keys():
		_flashes[id] -= delta
		if _flashes[id] <= 0.0:
			_flashes.erase(id)
	if _closing >= 0:
		_closing_time += delta
		if not is_visible_in_tree() or _closing_time >= CLOSE_SECONDS or not is_closed(_closing):
			_finish_closing()
	_show_closing()
	queue_redraw()


## Makes the line into node [param ability_id] flash: it was just taken.
func light(ability_id: StringName) -> void:
	if has_ability(ability_id):
		_flashes[ability_id] = FLASH_SECONDS
		queue_redraw()


## True while the line into node [param ability_id] flashes.
func is_lit(ability_id: StringName) -> bool:
	return _flashes.has(ability_id)


## Closes path [param index] before the player's eyes: its banner, then its nodes from the top, the
## last within [constant CLOSE_SECONDS]. Nothing plays while the view is hidden.
func close_path(index: int) -> void:
	if index < 0 or index > 1 or not is_visible_in_tree():
		return
	_closing = index
	_closing_time = 0.0
	_show_closing()


## True while a path is closing before the player's eyes.
func is_closing() -> bool:
	return _closing >= 0


## The lines that join the nodes, each [Rect2, the nodes it joins]: down the trunk, the fork's stub
## under the last trunk node, its line across to each path and down into each path's first node,
## then down each path. Every line is beside the names, never through them.
func joins() -> Array[Array]:
	var all: Array[Array] = []
	var half: float = LINE / 2.0
	for i: int in range(1, trunk_nodes.size()):
		var from: TalentNode = trunk_nodes[i - 1]
		var to: TalentNode = trunk_nodes[i]
		all.append([_down(_middle, from, to.position.y), [from, to]])
	if trunk_nodes.is_empty():
		return all
	var last: TalentNode = trunk_nodes[trunk_nodes.size() - 1]
	var under: float = last.position.y + last.full_height()
	all.append([Rect2(_middle - half, under, LINE, _fork_y - under), [last]])
	for index: int in 2:
		var column: Array = path_nodes[index]
		if column.is_empty():
			continue
		var first: TalentNode = column[0]
		var x: float = first.position.x + TalentNode.SLOT.x / 2.0
		var from_x: float = minf(x, _middle) - half
		var across := Rect2(from_x, _fork_y, absf(x - _middle) + LINE, LINE)
		all.append([across, [last, first]])
		var top: float = _fork_y + LINE
		var head_top: float = first.position.y - HEAD_CLEAR - HEAD.size()
		all.append([Rect2(x - half, top, LINE, head_top - top), [last, first]])
		for step: int in range(1, column.size()):
			var above: TalentNode = column[step - 1]
			var below: TalentNode = column[step]
			all.append([_down(x, above, below.position.y), [above, below]])
	return all


## The arrowheads, each [Rect2 of the head, the node it points into]: one over every node but the
## trunk's first.
func arrows() -> Array[Array]:
	var all: Array[Array] = []
	for made: TalentNode in nodes():
		if made == trunk_nodes[0]:
			continue
		var x: float = made.position.x + TalentNode.SLOT.x / 2.0
		var widest: float = HEAD[0]
		var top: float = made.position.y - HEAD_CLEAR - HEAD.size()
		all.append([Rect2(x - widest / 2.0, top, widest, HEAD.size()), made])
	return all


## The palette name the line into node [param ability_id] is drawn in now.
func colour_into(ability_id: StringName) -> StringName:
	var into: TalentNode = node(ability_id)
	if into == null:
		return UNLIT
	if _flashes.has(ability_id):
		return FLASH
	match into.state():
		TalentNode.State.TAKEN:
			return TRUNK_LIT if into.path < 0 else path_colour(into.path)
	if into.tint() == PathColours.DIM:
		return DARK
	return UNLIT


func _draw() -> void:
	for join: Array in joins():
		var rect: Rect2 = join[0]
		var ends: Array = join[1]
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var into: TalentNode = ends[ends.size() - 1]
		var colour: StringName = colour_into(into.ability_id)
		if ends.size() == 1:  # the stub under the trunk: lit once the trunk is
			colour = TRUNK_LIT if into.state() == TalentNode.State.TAKEN else UNLIT
		draw_rect(rect, Palette.color(colour))
	for arrow: Array in arrows():
		var head: Rect2 = arrow[0]
		var into: TalentNode = arrow[1]
		var colour: Color = Palette.color(colour_into(into.ability_id))
		var middle: float = head.position.x + head.size.x / 2.0
		for row: int in HEAD.size():
			var wide: float = HEAD[row]
			draw_rect(Rect2(middle - wide / 2.0, head.position.y + row, wide, 1), colour)
	if _closing >= 0 and not path_nodes[_closing].is_empty():
		# The closing's front: a bright line sweeping down the path as it closes.
		var column: Array = path_nodes[_closing]
		var first: TalentNode = column[0]
		var last: TalentNode = column[column.size() - 1]
		var banner: PathBanner = banners[_closing] if _closing < banners.size() else null
		var top: float = banner.position.y if banner != null else first.position.y
		var bottom: float = last.position.y + last.full_height()
		var done: float = clampf(_closing_time / CLOSE_SECONDS, 0.0, 1.0)
		var front: float = roundf(top + (bottom - top) * done)
		var x: float = first.position.x + TalentNode.SLOT.x / 2.0
		var reach: float = BANNER_WIDTH / 2.0
		draw_rect(
			Rect2(x - reach, top, reach * 2.0, front - top), Color(Palette.color(&"ink"), 0.35)
		)
		draw_rect(Rect2(x - reach, front, reach * 2.0, LINE), Palette.color(&"silver"))


## A line down from [param from]'s name to the arrowhead over the node at [param to_y], at
## [param x].
func _down(x: float, from: TalentNode, to_y: float) -> Rect2:
	var top: float = from.position.y + from.full_height()
	var head_top: float = to_y - HEAD_CLEAR - HEAD.size()
	return Rect2(x - LINE / 2.0, top, LINE, head_top - top)


func _add(id: StringName, on_path: int) -> TalentNode:
	var made := TalentNode.new(id, on_path, path_colour(on_path) if on_path >= 0 else &"")
	add_child(made)
	_by_id[id] = made
	made.hovered.connect(_on_hovered)
	return made


func _on_hovered(ability_id: StringName, inside: bool) -> void:
	if inside:
		_hovered = ability_id
	elif _hovered == ability_id:
		_hovered = &""


## Shows each banner and each node of a closing path as far as the closing has got: what it has not
## reached yet keeps its old look.
func _show_closing() -> void:
	for index: int in banners.size():
		var closed: bool = is_closed(index)
		if index == _closing and _closing_time < CLOSE_STEP:
			closed = false
		banners[index].show_closed(closed)
	for index: int in 2:
		for step: int in path_nodes[index].size():
			var made: TalentNode = path_nodes[index][step]
			if index == _closing and _closing_time < CLOSE_STEP * (step + 2):
				made.hold(TalentNode.State.LOCKED)
			else:
				made.release()


func _finish_closing() -> void:
	_closing = -1
	_closing_time = 0.0
	_show_closing()

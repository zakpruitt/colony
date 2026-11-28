class_name TalentTreeView
extends Control
## One class's talent tree as a hero window's Talents tab draws it: its three paths as three
## columns side by side, each under its [PathBanner], its five nodes in four rows, one per tier,
## the two tier-2 nodes side by side. Lines with arrowheads join each node to each node that needs
## it: tier 1 splits into both tier-2 nodes, both join into tier 3, and tier 3 runs down into the
## capstone. Each path has its own colour ([PathColours]): its banner, the lines lit along it and
## its nodes' tint.
##
## A line into a taken node is lit in its path's colour, any other plain. [method light] makes the
## line into a node just taken flash; it is only started for what just happened ([HeroWindows]
## asks).

## UI pixels between a tier-2 node's middle and its column's middle, and the widest its name runs:
## the two sit side by side and their names never meet.
const SIDE: float = 46.0
const SIDE_NAME_WIDTH: float = 88.0
## The widest the name of a node alone on its row runs.
const NAME_WIDTH: float = 116.0
## UI pixels between a banner and its column's edge, and between the banners and the first row.
const BANNER_MARGIN: float = 5.0
const BANNER_CLEAR: float = 4.0
## UI pixels from a name down to the line across (where a line splits or joins).
const STUB: float = 3.0
## UI pixels from a line across down to the arrowhead.
const DROP: float = 3.0
## The line's thickness, and the arrowhead's rows (widths, top to bottom) above a node's slot.
const LINE: float = 2.0
const HEAD: Array[int] = [5, 3, 1]
## UI pixels between an arrowhead's tip and the slot it points at (the path's tint ring is there).
const HEAD_CLEAR: float = 1.0
## Line colours: plain, and a flash just lit.
const UNLIT: StringName = &"steel"
const FLASH: StringName = &"white"
## Seconds the line into a node just taken flashes.
const FLASH_SECONDS: float = 0.5

## The tree shown.
var tree: TalentTreeDef
## Each path's nodes, in the order of [member SkillPathDef.nodes].
var path_nodes: Array[Array] = []
## Each path's banner, and its name label (the banner's own, which carries its tooltip).
var banners: Array[PathBanner] = []
var path_labels: Array[Label] = []
## How many times the nodes' states have been read from a hero ([method show_hero]), ever.
var states_read: int = 0

## Each path's column middle.
var _middles: Array[float] = []
## [method joins] and [method arrows], worked out once the nodes are placed.
var _joins: Array[Array] = []
var _arrows: Array[Array] = []
var _by_id: Dictionary[StringName, TalentNode] = {}
## Seconds left of each node's line flash.
var _flashes: Dictionary[StringName, float] = {}
var _hovered: StringName = &""


## The view of [param tree_def], [param width] UI pixels wide.
func _init(tree_def: TalentTreeDef, width: float) -> void:
	tree = tree_def
	name = "Tree_%s" % tree.class_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: int = maxi(tree.paths.size(), 1)
	var column: float = floorf(width / count)
	var banner_height: float = 0.0
	for index: int in tree.paths.size():
		var middle: float = floorf(column * index + column / 2.0)
		_middles.append(middle)
		var banner := PathBanner.new(tree, index, column - BANNER_MARGIN * 2.0)
		banner.position.x = floorf(column * index + BANNER_MARGIN)
		add_child(banner)
		banners.append(banner)
		path_labels.append(banner.name_label)
		banner_height = maxf(banner_height, banner.size.y)
		var made: Array[TalentNode] = []
		var ids: Array[StringName] = tree.paths[index].nodes
		for place: int in ids.size():
			var side: bool = place < TalentTreeDef.TIERS.size() and TalentTreeDef.TIERS[place] == 2
			made.append(_add(ids[place], index, SIDE_NAME_WIDTH if side else NAME_WIDTH))
		path_nodes.append(made)
	for banner: PathBanner in banners:
		banner.set_height(banner_height)
	var y: float = banner_height + BANNER_CLEAR
	var bottom: float = y
	var tiers: int = TalentTreeDef.TIERS[TalentTreeDef.TIERS.size() - 1]
	for tier: int in range(1, tiers + 1):
		var tall: float = 0.0
		for index: int in path_nodes.size():
			for place: int in path_nodes[index].size():
				if place >= TalentTreeDef.TIERS.size() or TalentTreeDef.TIERS[place] != tier:
					continue
				var placed: TalentNode = path_nodes[index][place]
				placed.position = Vector2(_x_of(index, place) - TalentNode.SLOT.x / 2.0, y)
				tall = maxf(tall, placed.full_height())
		bottom = y + tall
		y = bottom + STUB + LINE + DROP + HEAD.size() + HEAD_CLEAR
	size = Vector2(width, bottom)
	custom_minimum_size = size
	_joins = _lay_joins()
	_arrows = _lay_arrows()


## Every node, path by path, in the order of each path's nodes.
func nodes() -> Array[TalentNode]:
	var all: Array[TalentNode] = []
	for column: Array in path_nodes:
		for made: TalentNode in column:
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


## The palette name of path [param index]'s colour.
func path_colour(index: int) -> StringName:
	return PathColours.of(tree.class_id, index)


## The node under the mouse, or &"" for none.
func hovered() -> StringName:
	return _hovered


## Sets every node's state from [param hero] and runs the pulses and the flashes on by
## [param delta] seconds.
func refresh(hero: Hero, delta: float) -> void:
	show_hero(hero)
	advance(delta)


## Sets every node's state from [param hero], and each banner's rank. The lines are drawn from the
## nodes' states: the view is drawn again when one of them changed. A node its path's rank still
## holds shut is locked, as one whose path above it is not yet taken.
func show_hero(hero: Hero) -> void:
	states_read += 1
	for banner: PathBanner in banners:
		banner.show_rank(hero.ranks.rank(banner.index, tree))
	var taken: Array[StringName] = hero.talents()
	var redraw: bool = false
	for column: Array in path_nodes:
		for made: TalentNode in column:
			var stands: TalentNode.State = TalentNode.State.LOCKED
			if taken.has(made.ability_id):
				stands = TalentNode.State.TAKEN
			elif hero.can_take(made.ability_id):
				stands = TalentNode.State.AVAILABLE
			redraw = redraw or made.state() != stands
			made.show_state(stands)
	if redraw:
		queue_redraw()


## Runs the pulses and the flashes on by [param delta] seconds: the view is drawn again only while
## a flash plays.
func advance(delta: float) -> void:
	var redraw: bool = not _flashes.is_empty()
	for column: Array in path_nodes:
		for made: TalentNode in column:
			made.advance(delta)
	if not _flashes.is_empty():
		for id: StringName in _flashes.keys():
			_flashes[id] -= delta
			if _flashes[id] <= 0.0:
				_flashes.erase(id)
	if redraw:
		queue_redraw()


## Makes the line into node [param ability_id] flash: it was just taken.
func light(ability_id: StringName) -> void:
	if has_ability(ability_id):
		_flashes[ability_id] = FLASH_SECONDS
		queue_redraw()


## True while the line into node [param ability_id] flashes.
func is_lit(ability_id: StringName) -> bool:
	return _flashes.has(ability_id)


## Drops the flashes under way: the window closed, or the world is catching up, and nothing plays
## later for an event long past.
func stop() -> void:
	_flashes.clear()
	queue_redraw()


## The lines that join the nodes, each [Rect2, [the node needed, the node that needs it]]: from tier
## 1 down, across and down into each tier-2 node; from each tier-2 node down, across and down into
## tier 3; from tier 3 down into the capstone. Every line is beside the names, never through them.
func joins() -> Array[Array]:
	return _joins


## The arrowheads, each [Rect2 of the head, the node it points into]: one over every node but the
## tier-1 nodes.
func arrows() -> Array[Array]:
	return _arrows


func _lay_joins() -> Array[Array]:
	var all: Array[Array] = []
	for index: int in path_nodes.size():
		var column: Array = path_nodes[index]
		if column.size() < TalentTreeDef.PATH_LENGTH:
			continue
		var top: TalentNode = column[0]
		var cap: TalentNode = column[4]
		var deep: TalentNode = column[3]
		var middle: float = _middles[index]
		var split_y: float = _row_bottom(1) + STUB
		var join_y: float = _row_bottom(2) + STUB
		for place: int in [1, 2]:
			var side: TalentNode = column[place]
			var x: float = _x_of(index, place)
			var pair: Array = [top, side]
			all.append([_vertical(middle, _bottom_of(top), split_y), pair])
			all.append([_across(middle, x, split_y), pair])
			all.append([_vertical(x, split_y + LINE, _head_top(side)), pair])
			var into: Array = [side, deep]
			all.append([_vertical(x, _bottom_of(side), join_y), into])
			all.append([_across(x, middle, join_y), into])
			all.append([_vertical(middle, join_y + LINE, _head_top(deep)), into])
		all.append([_vertical(middle, _bottom_of(deep), _head_top(cap)), [deep, cap]])
	return all


func _lay_arrows() -> Array[Array]:
	var all: Array[Array] = []
	for column: Array in path_nodes:
		for place: int in range(1, column.size()):
			var made: TalentNode = column[place]
			var x: float = made.position.x + TalentNode.SLOT.x / 2.0
			var widest: float = HEAD[0]
			all.append([Rect2(x - widest / 2.0, _head_top(made), widest, HEAD.size()), made])
	return all


## The palette name the line into node [param ability_id] is drawn in now.
func colour_into(ability_id: StringName) -> StringName:
	var into: TalentNode = node(ability_id)
	if into == null:
		return UNLIT
	if _flashes.has(ability_id):
		return FLASH
	if into.state() == TalentNode.State.TAKEN:
		return path_colour(into.path)
	return UNLIT


func _draw() -> void:
	# Plain lines first, then lit ones over them, then a flash: a piece two lines share shows lit
	# when either is.
	for rank: int in 3:
		for join: Array in _joins:
			var rect: Rect2 = join[0]
			var into: TalentNode = (join[1] as Array)[1]
			var colour: StringName = colour_into(into.ability_id)
			if _rank(colour) == rank and rect.size.x > 0.0 and rect.size.y > 0.0:
				draw_rect(rect, Palette.color(colour))
	for arrow: Array in _arrows:
		var head: Rect2 = arrow[0]
		var into: TalentNode = arrow[1]
		var colour: Color = Palette.color(colour_into(into.ability_id))
		var middle: float = head.position.x + head.size.x / 2.0
		for row: int in HEAD.size():
			var wide: float = HEAD[row]
			draw_rect(Rect2(middle - wide / 2.0, head.position.y + row, wide, 1), colour)


func _rank(colour: StringName) -> int:
	if colour == UNLIT:
		return 0
	return 2 if colour == FLASH else 1


## The middle of the node at [param place] of path [param index].
func _x_of(index: int, place: int) -> float:
	var middle: float = _middles[index]
	match place:
		1:
			return middle - SIDE
		2:
			return middle + SIDE
	return middle


## The lowest name's foot on tier [param tier]'s row.
func _row_bottom(tier: int) -> float:
	var lowest: float = 0.0
	for column: Array in path_nodes:
		for place: int in mini(column.size(), TalentTreeDef.TIERS.size()):
			if TalentTreeDef.TIERS[place] == tier:
				lowest = maxf(lowest, _bottom_of(column[place] as TalentNode))
	return lowest


func _bottom_of(made: TalentNode) -> float:
	return made.position.y + made.full_height()


func _head_top(made: TalentNode) -> float:
	return made.position.y - HEAD_CLEAR - HEAD.size()


func _vertical(x: float, from_y: float, to_y: float) -> Rect2:
	return Rect2(x - LINE / 2.0, from_y, LINE, to_y - from_y)


func _across(from_x: float, to_x: float, y: float) -> Rect2:
	return Rect2(minf(from_x, to_x) - LINE / 2.0, y, absf(to_x - from_x) + LINE, LINE)


func _add(id: StringName, on_path: int, name_width: float) -> TalentNode:
	var made := TalentNode.new(id, on_path, path_colour(on_path), name_width)
	add_child(made)
	_by_id[id] = made
	made.hovered.connect(_on_hovered)
	return made


func _on_hovered(ability_id: StringName, inside: bool) -> void:
	if inside:
		_hovered = ability_id
	elif _hovered == ability_id:
		_hovered = &""

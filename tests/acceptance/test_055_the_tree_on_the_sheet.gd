extends GutTest
## Acceptance tests for specs/055-the-tree-on-the-sheet/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, and drives the hero sheet's Talents tab with mouse moves and clicks pushed
## into the viewport, as the window sends them; the simulation is stepped after each command and
## checked. Since spec 060 the sheet is a hero window on the UI layer ([HeroWindow]), so the HUD
## has a [UiRoot] over it, laid out for a 1280x720 room; a click on one of its controls is pushed
## at the world point under it ([method UiRoot.ui_to_world]).

const SEED: int = 55
const STEP: float = 1.0 / 60.0
const RICH: int = 1_000_000
const LIMIT_TICKS: int = 30_000
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(420, 200)
const NOWHERE: Vector2 = Vector2(-1000, -1000)
const CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
## The UI layer's room (spec 058): two hero windows side by side, clear of the frames' line.
const ROOM: Vector2i = Vector2i(1280, 720)
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const GUARDIAN_DEPTH: int = 5

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
var _ui: UiRoot


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_build_hud()


func after_each() -> void:
	_mouse(NOWHERE)
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


# --- Helpers -------------------------------------------------------------------


func _build_hud() -> void:
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	# On a layer of its own, as Main has it, above GUT's runner (layer 128), whose window would
	# take the mouse.
	var layer := CanvasLayer.new()
	layer.layer = 129
	add_child_autofree(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.set_process(false)
	_hud.setup(_sim, _world, _fx)
	_ui = UiRoot.new()
	add_child_autofree(_ui)
	_ui.layer = 130  # over the HUD, as Main has it
	_ui.setup(_sim, _hud, null)
	_ui.set_room_for_test(ROOM)
	_hud.advance(0.0)


## The front hero window (spec 060: the sheet is a window per hero), or null when none is open.
func _sheet() -> HeroWindow:
	return _hud.hero_windows.front()


func _tab() -> HeroTalentsTab:
	return _sheet().talents


## The tooltip [param control] has on the UI layer (spec 058's tips, which the hero windows'
## controls use), or "".
func _tip_text(control: Control) -> String:
	for found: Node in _ui.find_children("*", "", true, false):
		var tip: UiTip = found as UiTip
		if tip != null and not tip.text_for(control).is_empty():
			return tip.text_for(control)
	return ""


## Where to push a mouse event for [param control]: its centre, turned into the world's screen
## pixels when it is on the UI layer.
func _at(control: Control) -> Vector2:
	var centre: Vector2 = control.get_global_rect().get_center()
	return _ui.ui_to_world(centre) if _ui.is_ancestor_of(control) else centre


func _hero(class_id: StringName) -> Hero:
	for hero: Hero in _sim.party.heroes:
		if hero.class_id == class_id:
			return hero
	return null


func _tree(class_id: StringName) -> TalentTreeDef:
	return Content.talent_tree(class_id)


func _level(hero: Hero, level: int) -> void:
	hero.level = level
	hero.xp = Hero.xp_for_level(level)


## The trunk and the first [param steps] nodes of path [param path] of [param class_id]'s tree.
func _walked(class_id: StringName, path: int, steps: int) -> Array[StringName]:
	var tree: TalentTreeDef = _tree(class_id)
	var nodes: Array[StringName] = tree.trunk.duplicate()
	nodes.append_array(tree.path_nodes(path).slice(0, steps))
	return nodes


## Opens [param hero]'s sheet on its Talents tab as the player would: a click on its frame, then
## on the tab.
func _open_talents(hero: Hero) -> void:
	for frame: HeroFrame in _hud.frames:
		if frame.hero_id == hero.id:
			_click_at(frame.get_global_rect().get_center())
	_hud.advance(STEP)
	_click_at(_at(_sheet().tab_buttons[HeroWindow.Page.TALENTS]))
	_hud.advance(STEP)


## One frame of one tick: the simulation, the world, the HUD.
func _frame() -> void:
	_sim.step()
	_world.sync(STEP)
	_hud.advance(STEP)


func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


## Clicks the left button at [param at], in screen pixels, then moves the mouse away.
func _click_at(at: Vector2) -> void:
	_mouse(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
	_mouse(AWAY)


func _click(control: Control) -> void:
	_click_at(_at(control))
	_hud.advance(STEP)


func _click_node(ability_id: StringName) -> void:
	var node: TalentNode = _tab().node(ability_id)
	assert_not_null(node, "%s is on the tab" % ability_id)
	if node != null:
		_click(node)


func _state(ability_id: StringName) -> TalentNode.State:
	return _tab().node(ability_id).state()


func _state_name(state: TalentNode.State) -> String:
	return TalentNode.State.keys()[state]


func _journal_has(sentence: String) -> bool:
	for line: String in _hud.journal.lines():
		if line.ends_with(sentence):
			return true
	return false


## Steps a tick per frame until [param done] returns true (true), or the limit (false).
func _step_until(done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		_sim.step()
		_world.sync(0.1)
		_hud.advance(0.1)
		if done.call():
			return true
	return false


## Puts the party just outside the guardian's chamber on [constant GUARDIAN_DEPTH], walking in, as
## spec 041's tests do.
func _before_guardian() -> void:
	var e: Expedition = _sim.expedition
	var lair: LabyrinthChamber = _sim.labyrinth.level(GUARDIAN_DEPTH).shaft_chamber()
	_sim.set_auto_push(false)
	e.depth = GUARDIAN_DEPTH
	e.deepest_depth = maxi(e.deepest_depth, GUARDIAN_DEPTH)
	e.last_stable_depth = GUARDIAN_DEPTH - 1
	e.target_depth = GUARDIAN_DEPTH + 1
	if lair.index > 0:
		e.x = lair.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = lair.rect.end.x
		e.facing = -1


## Every Control under [param node] (and itself).
func _controls(node: Node, into: Array[Control]) -> void:
	if node is Control:
		into.append(node as Control)
	for child: Node in node.get_children():
		_controls(child, into)


# --- R1 ------------------------------------------------------------------------


func test_r1_the_tree_is_drawn() -> void:
	assert_eq(
		HeroWindow.TAB_NAMES, ["Stats", "Talents", "Skills"] as Array[String], "Training is Talents"
	)
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(class_id)
		var tree: TalentTreeDef = _tree(class_id)
		_open_talents(hero)
		var sheet: HeroWindow = _sheet()
		assert_eq(sheet.tab_buttons[HeroWindow.Page.TALENTS].text, "Talents", "the tab's name")
		assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "%s: on the Talents tab" % class_id)
		var view: TalentTreeView = _tab().tree_view()
		assert_not_null(view, "%s: a tree" % class_id)
		if view == null:
			continue
		assert_true(view.is_visible_in_tree(), "%s: shown" % class_id)
		assert_eq(view.tree, tree, "%s: its own class's tree" % class_id)
		# The trunk: three nodes in a row, left to right.
		assert_eq(view.trunk_nodes.size(), 3, "%s: three trunk nodes" % class_id)
		for i: int in view.trunk_nodes.size():
			var node: TalentNode = view.trunk_nodes[i]
			assert_eq(node.ability_id, tree.trunk[i], "%s: trunk %d in order" % [class_id, i])
			assert_eq(node.position.y, view.trunk_nodes[0].position.y, "%s: in a row" % class_id)
			if i > 0:
				var before: TalentNode = view.trunk_nodes[i - 1]
				assert_gt(node.position.x, before.get_rect().end.x, "%s: left to right" % class_id)
		var trunk_bottom: float = view.trunk_nodes[0].get_global_rect().end.y
		# The paths: side by side under their names, four nodes each, top to bottom.
		for path: int in 2:
			var label: Label = view.path_labels[path]
			assert_eq(label.text, tree.path_names[path], "%s: path %d's name" % [class_id, path])
			assert_true(label.is_visible_in_tree(), "%s: the name shows" % class_id)
			var column: Array = view.path_nodes[path]
			assert_eq(column.size(), 4, "%s: four nodes on path %d" % [class_id, path])
			for step: int in column.size():
				var node: TalentNode = column[step]
				assert_eq(node.ability_id, tree.path_nodes(path)[step], "%s: in order" % class_id)
				var rect: Rect2 = node.get_global_rect()
				assert_gt(rect.position.y, label.get_global_rect().end.y, "under its name")
				assert_gt(rect.position.y, trunk_bottom, "%s: under the trunk" % class_id)
				assert_eq(node.position.x, (column[0] as TalentNode).position.x, "in a column")
				if step > 0:
					assert_gt(node.position.y, (column[step - 1] as TalentNode).position.y)
		var left: TalentNode = view.path_nodes[0][0]
		var right: TalentNode = view.path_nodes[1][0]
		assert_eq(left.position.y, right.position.y, "%s: side by side" % class_id)
		assert_gt(right.position.x, left.get_rect().end.x, "%s: the second to the right" % class_id)
		# Each node: a picture of its kind and its ability's name.
		for node: TalentNode in view.nodes():
			var ability: AbilityDef = Content.ability(node.ability_id)
			assert_eq(node.name_label.text, ability.display_name, "%s's name" % node.ability_id)
			assert_not_null(node.icon.texture, "%s has a picture" % node.ability_id)
			assert_eq(node.icon.size, Vector2(24, 24), "a 12x12 picture at twice its size")
			assert_has(
				["strike", "guard", "heal", "fire", "frost", "shadow", "light", "rally"],
				String(Content.ability(node.ability_id).picture),
				"%s's picture is one of the eight kinds" % node.ability_id
			)
		# Joined by lines: each node to the next in its order, the trunk to both paths.
		var joined: Dictionary[String, bool] = {}
		for join: Array in view.joins():
			var rect: Rect2 = join[0]
			assert_true(rect.has_area(), "%s: a line has length" % class_id)
			var ends: Array = join[1]
			if ends.size() == 2:
				var a: TalentNode = ends[0]
				var b: TalentNode = ends[1]
				joined["%s>%s" % [a.ability_id, b.ability_id]] = true
		var order: Array[StringName] = tree.trunk.duplicate()
		for i: int in range(1, order.size()):
			assert_true(joined.has("%s>%s" % [order[i - 1], order[i]]), "trunk %d joined" % i)
		for path: int in 2:
			var nodes: Array[StringName] = [tree.trunk[2]]
			nodes.append_array(tree.path_nodes(path))
			for i: int in range(1, nodes.size()):
				var key: String = "%s>%s" % [nodes[i - 1], nodes[i]]
				assert_true(joined.has(key), "%s: %s joined" % [class_id, key])
		# Spec 060: a hero window keeps one size on every tab (it no longer grows for the tree).
		var tall: Vector2 = sheet.size
		sheet.open_page(HeroWindow.Page.STATS)
		_hud.advance(STEP)
		assert_eq(sheet.size, tall, "%s: Stats, the same size" % class_id)
		sheet.close()
		_hud.advance(STEP)


# --- R2 ------------------------------------------------------------------------


func test_r2_a_node_shows_its_state() -> void:
	for class_id: StringName in [&"knight", &"mage"]:
		var hero: Hero = _hero(class_id)
		var tree: TalentTreeDef = _tree(class_id)
		_open_talents(hero)
		# A new hero with a point: the first trunk node can be taken, the rest are plain.
		_level(hero, 2)
		hero.set_talents([] as Array[StringName])
		_hud.advance(STEP)
		var first: TalentNode = _tab().node(tree.trunk[0])
		assert_eq(_state_name(first.state()), "AVAILABLE", "%s: the first node" % class_id)
		assert_eq(first.frame_colour(), &"yellow", "framed in yellow")
		assert_true(first.is_pulsing(), "and pulsing")
		_hud.advance(TalentNode.PULSE_SECONDS * 0.6)
		assert_eq(first.frame_colour(), &"amber", "gently: yellow, then amber")
		for id: StringName in tree.trunk.slice(1) + tree.path_a + tree.path_b:
			assert_eq(_state_name(_state(id)), "LOCKED", "%s: %s is plain" % [class_id, id])
			assert_false(_tab().node(id).is_pulsing(), "%s does not pulse" % id)
		# Without a point the next node is plain too.
		_level(hero, 1)
		_hud.advance(STEP)
		assert_eq(_state_name(first.state()), "LOCKED", "%s: no point, plain" % class_id)
		assert_false(first.is_pulsing(), "and still")
		for path: int in 2:
			_level(hero, 10)  # five points: the trunk, the path's first node and one more
			hero.set_talents(_walked(class_id, path, 1))
			_hud.advance(STEP)
			var on: String = "%s on %s" % [class_id, tree.path_names[path]]
			for id: StringName in tree.trunk:
				assert_eq(_state_name(_state(id)), "TAKEN", "%s: trunk %s taken" % [on, id])
			var mine: Array[StringName] = tree.path_nodes(path)
			var taken: TalentNode = _tab().node(mine[0])
			assert_eq(_state_name(taken.state()), "TAKEN", "%s: the path's first" % on)
			assert_true(taken.is_ticked(), "%s: ticked" % on)
			assert_eq(taken.name_label.get_theme_color(&"font_color"), Palette.color(&"white"))
			var next: TalentNode = _tab().node(mine[1])
			assert_eq(_state_name(next.state()), "AVAILABLE", "%s: the next can be taken" % on)
			assert_true(next.is_pulsing(), "%s: it pulses" % on)
			for id: StringName in mine.slice(2):
				assert_eq(_state_name(_state(id)), "LOCKED", "%s: %s not yet" % [on, id])
			for id: StringName in tree.path_nodes(1 - path):
				var closed: TalentNode = _tab().node(id)
				assert_eq(_state_name(closed.state()), "CLOSED", "%s: %s is closed" % [on, id])
				assert_false(closed.icon.visible, "%s: dark, no picture" % on)
				assert_eq(closed.frame_colour(), &"ink", "%s: dark" % on)
			var view: TalentTreeView = _tab().tree_view()
			assert_true(view.is_closed(1 - path), "%s: the other name struck through" % on)
			var strike: ColorRect = view.path_labels[1 - path].get_node("Strike")
			assert_true(strike.is_visible_in_tree(), "%s: a line through it" % on)
			var through: Rect2 = strike.get_global_rect()
			assert_true(
				through.intersects(view.path_labels[1 - path].get_global_rect()), "over the name"
			)
			assert_false(
				(view.path_labels[path].get_node("Strike") as ColorRect).visible, "not its own"
			)
			assert_false(view.is_closed(path), "%s: its own name is not" % on)
			assert_eq(
				view.path_labels[1 - path].get_theme_color(&"font_color"),
				Palette.color(&"slate"),
				"%s: the other name dark" % on
			)
		_sheet().close()
		_hud.advance(STEP)


# --- R3 ------------------------------------------------------------------------


func test_r3_every_ability_can_be_read() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	# Every node of all four trees tells its name, kind and whole description. Spec 060 shows them
	# beside each node without pointing, in place of spec 055's one place under the tree that told
	# the node pointed at (test_060's R5 checks they are never cut).
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(class_id)
		_level(hero, 1)
		_open_talents(hero)
		var panel: Rect2 = _sheet().get_global_rect()
		for node: TalentNode in _tab().tree_view().nodes():
			var ability: AbilityDef = Content.ability(node.ability_id)
			var kind: String = "Passive"
			if ability.is_action():
				kind = "Action, every %s s" % HeroWindow.tiles(ability.cooldown)
			assert_eq(node.name_label.text, ability.display_name, "%s: its name" % ability.id)
			assert_eq(node.kind_label.text, kind, "%s: its kind" % ability.id)
			var description: String = node.description_label.text.replace("\n", " ")
			assert_eq(description, ability.description, "%s: all of its description" % ability.id)
			for label: Label in [node.name_label, node.kind_label, node.description_label]:
				assert_true(label.is_visible_in_tree(), "%s: %s shows" % [ability.id, label.name])
				var box: Rect2 = label.get_global_rect()
				assert_true(panel.encloses(box), "%s: '%s' fits" % [ability.id, label.text])
		_sheet().close()
		_hud.advance(STEP)
	assert_true(Content.ability(&"shield_bash").is_action(), "an action is told")
	assert_false(Content.ability(&"bottle_top_block").is_action(), "and a passive")
	# Why it cannot be taken: in the node's tooltip (spec 060 keeps the reasons there).
	_open_talents(knight)
	assert_eq(HeroTalentsTab.reason(knight, tree.trunk[0]), "No talent point", "without a point")
	assert_string_contains(
		_tip_text(_tab().node(tree.trunk[0])).to_lower(), "no talent point", "in its tooltip"
	)
	_level(knight, 2)
	knight.set_talents([tree.trunk[0]] as Array[StringName])
	_hud.advance(STEP)
	assert_eq(HeroTalentsTab.reason(knight, tree.trunk[2]), "Take Taunt first", "further on")
	assert_string_contains(
		_tip_text(_tab().node(tree.trunk[2])).to_lower(), "take taunt first", "in its tooltip"
	)
	_level(knight, 8)
	knight.set_talents(_walked(&"knight", 1, 1))
	_hud.advance(STEP)
	var closed: String = HeroTalentsTab.reason(knight, tree.path_a[1])
	assert_eq(closed, "The Guardian path is closed", "the other path")
	assert_string_contains(
		_tip_text(_tab().node(tree.path_a[1])).to_lower(), closed.to_lower(), "in its tooltip"
	)
	# A click on a node it cannot take takes nothing and asks nothing.
	_click_node(tree.path_a[2])
	_frame()
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "no question")
	assert_eq(knight.talents(), _walked(&"knight", 1, 1), "and nothing is taken")


# --- R4 ------------------------------------------------------------------------


func test_r4_taking_a_node() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 10)  # five points
	_open_talents(knight)
	# A click on a trunk node that can be taken takes it.
	_click_node(tree.trunk[0])
	_frame()
	assert_eq(knight.talents(), [tree.trunk[0]] as Array[StringName], "taken by a click")
	_click_node(tree.trunk[1])
	_frame()
	_click_node(tree.trunk[2])
	_frame()
	assert_eq(knight.talents(), tree.trunk, "the trunk, click by click")
	# A click on a node that cannot be taken takes nothing.
	_click_node(tree.path_b[2])
	_frame()
	assert_eq(knight.talents(), tree.trunk, "not reachable: nothing")
	# The first node of a path asks first, in the fixed place.
	_click_node(tree.path_b[0])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.PATH, "it asks")
	assert_eq(_tab().ask_label.text, "Choose Berserker? This closes Guardian.", "the question")
	assert_eq(_tab().choose_button.text, "Choose")
	assert_eq(_tab().not_yet_button.text, "Not yet")
	assert_true(_tab().choose_button.is_visible_in_tree(), "Choose shows")
	assert_true(_tab().not_yet_button.is_visible_in_tree(), "Not yet shows")
	# Spec 060: the question takes the top row, in place of the reset, above the tree.
	assert_lt(
		_tab().ask_label.position.y, _tab().tree_view().position.y, "in the top row, over the tree"
	)
	assert_false(_tab().reset_button.is_visible_in_tree(), "in the reset's place")
	_frame()
	assert_eq(knight.talents(), tree.trunk, "asking sends nothing")
	_click(_tab().not_yet_button)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "Not yet: no question")
	_frame()
	assert_eq(knight.talents(), tree.trunk, "Not yet sends nothing")
	assert_eq(knight.path(), -1, "both paths open")
	_click_node(tree.path_b[0])
	_click(_tab().choose_button)
	_frame()
	assert_eq(knight.talents(), _walked(&"knight", 1, 1), "Choose sends the command")
	assert_eq(knight.path(), 1, "a Berserker")
	# Further down the path, no question.
	_click_node(tree.path_b[1])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "no question further on")
	_frame()
	assert_eq(knight.talents(), _walked(&"knight", 1, 2), "taken at once")
	# While the page is hidden its handlers do nothing, whatever reaches them.
	_level(knight, 14)
	_sim.party.gold = RICH
	_click(_sheet().tab_buttons[HeroWindow.Page.STATS])
	_tab().press_node(tree.path_b[2])
	_tab().press_reset()
	_tab().confirm()
	_frame()
	assert_eq(knight.talents(), _walked(&"knight", 1, 2), "a hidden page takes nothing")
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "and asks nothing")
	assert_eq(_sim.party.gold, RICH, "and resets nothing")


# --- R5 ------------------------------------------------------------------------


func test_r5_unspent_points_are_shown() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 4)
	_open_talents(knight)
	var sheet: HeroWindow = _sheet()
	assert_eq(_tab().points_label.text, "2 talent points", "at the top of the tab")
	assert_true(_tab().points_label.is_visible_in_tree(), "shown")
	var points_y: float = _tab().points_label.get_global_rect().position.y
	var trunk_y: float = _tab().tree_view().trunk_nodes[0].get_global_rect().position.y
	assert_lt(points_y, trunk_y, "at the top")
	var tab: Rect2 = sheet.tab_buttons[HeroWindow.Page.TALENTS].get_global_rect()
	assert_true(sheet.talents_tag.is_visible_in_tree(), "on the tab's name")
	assert_eq(sheet.talents_tag.count, 2, "two")
	assert_true(sheet.talents_tag.get_global_rect().intersects(tab), "pinned to the tab")
	_click_node(tree.trunk[0])
	_frame()
	assert_eq(_tab().points_label.text, "1 talent point", "one")
	assert_eq(sheet.talents_tag.count, 1, "the tab says one")
	_click_node(tree.trunk[1])
	_frame()
	assert_eq(_tab().points_label.text, "Next point at level 6", "none: when the next comes")
	assert_false(sheet.talents_tag.is_visible_in_tree(), "no mark")
	_level(knight, 5)
	_hud.advance(STEP)
	assert_eq(_tab().points_label.text, "Next point at level 6", "level 5")
	_level(knight, 6)
	_hud.advance(STEP)
	assert_eq(_tab().points_label.text, "1 talent point", "level 6 brings one")


# --- R6 ------------------------------------------------------------------------


func test_r6_a_fresh_start() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 8)
	_sim.party.gold = 0
	_open_talents(knight)
	var reset: UiButton = _tab().reset_button
	assert_eq(reset.text, "Reset 800", "the price: 100 gold a level")
	assert_true(reset.disabled, "nothing to reset: greyed")
	assert_eq(_tab().reset_reason_label.text, "Nothing to reset", "with the reason")
	knight.set_talents(tree.trunk)
	_hud.advance(STEP)
	assert_true(reset.disabled, "too poor: greyed")
	assert_eq(_tab().reset_reason_label.text, "Not enough gold", "with the reason")
	_sim.party.gold = RICH
	_hud.advance(STEP)
	assert_false(reset.disabled, "usable")
	assert_eq(_tab().reset_reason_label.text, "", "no reason")
	assert_true(
		_tab().reset_reason_label.get_global_rect().end.x <= reset.get_global_rect().position.x
	)
	# It asks first.
	_click(reset)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.RESET, "it asks")
	assert_eq(_tab().ask_label.text, "Reset the Knight's tree for 800 gold?", "the question")
	_frame()
	assert_eq(knight.talents(), tree.trunk, "asking resets nothing")
	_click(_tab().not_yet_button)
	_frame()
	assert_eq(knight.talents(), tree.trunk, "Not yet resets nothing")
	_click(reset)
	assert_eq(_tab().choose_button.text, "Reset", "the answer says what it does")
	_click(_tab().choose_button)
	_frame()
	assert_eq(knight.talents(), [] as Array[StringName], "reset")
	assert_eq(_sim.party.gold, RICH - 800, "for its price")
	assert_eq(_tab().reset_reason_label.text, "Nothing to reset", "nothing left")
	# A question never outlives what it asked: another tab, the sheet closed, a new price.
	var gold: int = _sim.party.gold
	knight.set_talents(tree.trunk)
	_hud.advance(STEP)
	_click(reset)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.RESET, "asked again")
	_click(_sheet().tab_buttons[HeroWindow.Page.STATS])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "another tab: the question goes")
	_click(_sheet().tab_buttons[HeroWindow.Page.TALENTS])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "and does not come back")
	_click(reset)
	_hud.hero_windows.window_of(knight.id).close()
	_hud.advance(STEP)
	_open_talents(knight)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "the sheet closed: gone")
	_click(reset)
	assert_eq(_tab().ask_label.text, "Reset the Knight's tree for 800 gold?", "asked at 800")
	_level(knight, 17)
	_hud.advance(STEP)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "a new price: the old question goes")
	_tab().confirm()
	_frame()
	assert_eq(knight.talents(), tree.trunk, "nothing reset at a price never read")
	assert_eq(_sim.party.gold, gold, "nothing charged")
	assert_eq(reset.text, "Reset 1,700", "the new price shows")
	# A path question goes with the tab too.
	_click_node(tree.path_b[0])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.PATH, "a path question")
	_click(_sheet().tab_buttons[HeroWindow.Page.SKILLS])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "another tab: it goes")
	_click(_sheet().tab_buttons[HeroWindow.Page.TALENTS])
	# In a fight: an open question goes when the fight starts.
	_click(reset)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.RESET, "asked before the fight")
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a fight")
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "the fight starts: the question goes")
	assert_true(reset.disabled, "in a fight: greyed")
	assert_eq(_tab().reset_reason_label.text, "In a fight", "with the reason")


# --- R7 ------------------------------------------------------------------------


func test_r7_paragon() -> void:
	var knight: Hero = _hero(&"knight")
	_level(knight, 13)
	_open_talents(knight)
	assert_eq(_tab().paragon_label.text, "Paragon points come after level 14", "before then")
	for cell: ParagonCell in _tab().paragon_cells:
		assert_false(cell.is_visible_in_tree(), "no stats before then")
	_level(knight, 14)
	_hud.advance(STEP)
	assert_eq(_tab().paragon_label.text, "0 paragon points", "every talent point earned")
	_level(knight, 17)
	_hud.advance(STEP)
	assert_eq(_tab().paragon_label.text, "3 paragon points", "the unspent paragon points")
	var tree_bottom: float = 0.0
	for node: TalentNode in _tab().tree_view().nodes():
		tree_bottom = maxf(tree_bottom, node.get_global_rect().end.y)
	var names: Array[String] = []
	for cell: ParagonCell in _tab().paragon_cells:
		assert_true(cell.is_visible_in_tree(), "%s shows" % cell.id)
		assert_gt(cell.get_global_rect().position.y, tree_bottom, "under the tree")
		assert_eq(cell.buy_button.text, "+1", "a +1 each")
		assert_false(cell.buy_button.disabled, "lit with a point")
		names.append(cell.name_label.text)
	assert_eq(names, ["Power", "Toughness", "Quickness"] as Array[String], "the three stats")
	var power: ParagonCell = _tab().paragon_cells[0]
	assert_eq(power.text(), "Power 0 +0%", "no bonus yet")
	_click(power.buy_button)
	_frame()
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 1, "a point in Power")
	assert_eq(power.text(), "Power 1 +3%", "its bonus so far")
	assert_eq(_tab().paragon_label.text, "2 paragon points", "one fewer")


# --- R8 ------------------------------------------------------------------------


func test_r8_the_game_points_at_it() -> void:
	var knight: Hero = _hero(&"knight")
	var frame: HeroFrame = _hud.frames[0]
	_hud.advance(STEP)
	assert_false(frame.marker.visible, "no point: no mark")
	# A level-up in play: the mark, the goal and the journal.
	knight.xp = Hero.xp_for_level(2) - 1
	var levelled: Callable = func() -> bool: return knight.level >= 2
	assert_true(_step_until(levelled), "the knight reaches level 2")
	assert_true(frame.marker.visible, "a mark on its frame")
	assert_gte(frame.marker.count, 1, "counting the point")
	assert_true(_journal_has("The Knight has a talent point to spend"), "the journal notes it")
	var sentence: String = "Spend the Knight's talent point"
	var row: int = _hud.goals.lines().find(sentence)
	assert_gte(row, 0, "a goal: %s" % [_hud.goals.lines()])
	if row >= 0:
		_click(_hud.goals.rows[row])
		assert_true(_hud.hero_windows.is_open(knight.id), "the goal opens the knight's window")
		assert_eq(_sheet().hero_id, knight.id, "in front")
		assert_eq(_sheet().page(), HeroWindow.Page.TALENTS, "on its Talents tab")
	# A path chosen.
	_level(knight, 8)
	knight.set_talents(_tree(&"knight").trunk)
	_hud.advance(STEP)
	_click_node(&"whirlwind")
	_click(_tab().choose_button)
	_frame()
	assert_true(_journal_has("The Knight is now a Berserker"), "the journal notes the path")
	_level(knight, 10)  # a point to spend again
	_sheet().close()
	_hud.advance(STEP)
	# The defeat note offers to spend talent points ahead of its other advice.
	_sim.party.gold = RICH
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a fight")
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	var down: Callable = func() -> bool: return _sim.expedition.state == Expedition.State.REVIVING
	assert_true(_step_until(down), "the party is wiped")
	var offered: Array[String] = _hud.defeat_note.suggestions()
	assert_gt(offered.size(), 1, "advice: %s" % [offered])
	if offered.is_empty():
		return
	assert_eq(offered[0], "Spend talent points", "first: %s" % [offered])
	assert_has(offered, "Buy an upgrade", "then the rest")
	_hud.defeat_note.press(0)
	_hud.advance(STEP)
	assert_true(_hud.hero_windows.is_open(), "it opens a hero window")
	assert_eq(_sheet().hero_id, knight.id, "of a hero with a point")
	assert_eq(_sheet().page(), HeroWindow.Page.TALENTS, "on its Talents tab")
	_sheet().close()
	_hud.advance(STEP)
	# At a guardian, with talent points, a paragon point and gold: four things would help, and the
	# upgrade gives way, never Hold here.
	var standing: Callable = func() -> bool:
		return _sim.expedition.state != Expedition.State.REVIVING
	assert_true(_step_until(standing), "the party stands")
	_level(knight, 15)
	_sim.party.gold = RICH
	_before_guardian()
	assert_true(_step_until(fighting), "the guardian fight")
	assert_ne(_sim.expedition.guardian_of(GUARDIAN_DEPTH), &"", "a guardian")
	for fighter: Combatant in _sim.expedition.battle.heroes:
		fighter.health = 0
	assert_true(_step_until(down), "the party loses to the guardian")
	assert_eq(
		_hud.defeat_note.suggestions(),
		["Spend talent points", "Train Knight", "Hold here"] as Array[String],
		"Hold here keeps its place"
	)


# --- R9 ------------------------------------------------------------------------


func test_r9_the_path_is_part_of_who_it_is() -> void:
	var knight: Hero = _hero(&"knight")
	var frame: HeroFrame = _hud.frames[0]
	_level(knight, 8)
	knight.set_talents(_tree(&"knight").trunk)
	_open_talents(knight)
	assert_eq(_sheet().line(&"class"), "Knight", "no path yet")
	_click_node(&"whirlwind")
	_click(_tab().choose_button)
	_frame()
	assert_eq(_sheet().line(&"class"), "Knight, Berserker", "at the top of the sheet")
	assert_true(
		_sheet().get_global_rect().encloses(_sheet().class_label.get_global_rect()), "and it fits"
	)
	_sheet().close()
	_hud.advance(STEP)
	_mouse(frame.get_global_rect().get_center())
	_hud.advance(0.2)
	_hud.advance(0.3)
	assert_eq(
		_hud.tooltip.shown_text(), "Knight, Berserker: click for details", "on the frame's tooltip"
	)
	_mouse(AWAY)
	_hud.advance(STEP)
	_mouse(_hud.frames[1].get_global_rect().get_center())
	_hud.advance(0.5)
	assert_eq(_hud.tooltip.shown_text(), "Click for details", "a hero with no path")


# --- R10 -----------------------------------------------------------------------


func test_r10_true_in_a_crowded_frame() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_open_talents(knight)
	var told: Array[SimEvent] = []
	_world.sim_event.connect(func(event: SimEvent) -> void: told.append(event))
	# Three level-ups and a command, all in one frame: the simulation steps without the world.
	knight.xp = Hero.xp_for_level(4) - 1
	var ticks: int = 0
	while knight.level < 4 and ticks < LIMIT_TICKS:
		_sim.step()
		ticks += 1
	assert_eq(knight.level, 4, "three levels in one award")
	_sim.take_talent(knight.id, tree.trunk[0])
	_sim.step()
	_world.sync(STEP)
	_hud.advance(STEP)
	var levels: Array[int] = []
	var points: Array[int] = []
	for event: SimEvent in told:
		if event.source_id == knight.id and event.kind == SimEvent.Kind.TALENT_POINT_GAINED:
			points.append(event.amount)
		if event.target_id == knight.id and event.kind == SimEvent.Kind.LEVEL_UP:
			levels.append(event.amount)
	assert_eq(levels, [2, 3, 4] as Array[int], "the frame held three level-ups")
	assert_eq(points, [2, 4] as Array[int], "and two talent points")
	assert_eq(knight.talents(), [tree.trunk[0]] as Array[StringName], "and the command")
	# The end state, with no stale mark.
	assert_eq(_tab().points_label.text, "1 talent point", "one left")
	assert_eq(_sheet().talents_tag.count, 1, "the tab's mark says one")
	assert_eq(_state_name(_state(tree.trunk[0])), "TAKEN", "the node taken")
	assert_eq(_state_name(_state(tree.trunk[1])), "AVAILABLE", "the next can be taken")
	_sheet().close()
	_hud.advance(STEP)
	assert_has(_hud.goals.lines(), "Spend the Knight's talent point", "the goal: one point")
	var skills: int = 0
	for skill_level: int in knight.def().microskill_levels:
		if skill_level <= 4:
			skills += 1
	assert_eq(_hud.frames[0].marker.count, 1 + skills, "the frame: the point (and new skills)")
	# The journal, in the order of the events.
	var lines: Array[String] = _hud.journal.lines()
	var order: Array[String] = []
	for line: String in lines:
		var sentence: String = line.substr(line.find("  ") + 2)
		if sentence.contains("Knight"):
			order.push_front(sentence)
	var expected: Array[String] = [
		"Knight reached level 2",
		"The Knight has a talent point to spend",
		"Knight reached level 3",
		"Knight reached level 4",
		"The Knight has a talent point to spend",
	]
	var found: Array[String] = []
	for sentence: String in order:
		if sentence in expected:
			found.append(sentence)
	assert_eq(found, expected, "in order")


# --- R11 -----------------------------------------------------------------------


func test_r11_it_fits_and_is_explained() -> void:
	# Spec 060: the sheet is a hero window in UI pixels, inside the room and over the frames' line
	# no more (test_060's R7 and R10 check every class, both rooms and the longest data).
	var screen := Rect2(Vector2.ZERO, Vector2(_ui.room()))
	var top_band: float = _ui.world_to_ui(Vector2(0, Hud.TOP_BAND)).y
	var frames_top: float = _ui.world_to_ui(Vector2(0, UiRoot.frames_top())).y
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(class_id)
		_level(hero, 17)
		_sim.party.gold = RICH
		hero.set_talents(_walked(class_id, 1, 1))
		_open_talents(hero)
		var sheet: HeroWindow = _sheet()
		var panel: Rect2 = sheet.get_global_rect()
		assert_true(screen.encloses(panel), "%s: on the screen" % class_id)
		assert_gte(panel.position.y, top_band, "%s: under the top band" % class_id)
		assert_lte(panel.end.y, frames_top, "%s: clear of the frames" % class_id)
		var nodes: Array[TalentNode] = _tab().tree_view().nodes()
		for node: TalentNode in nodes:
			var box: Rect2 = node.get_global_rect()
			var label: Rect2 = node.name_label.get_global_rect()
			var named: String = "%s: %s's name" % [class_id, node.ability_id]
			assert_true(panel.encloses(label), "%s on the sheet" % named)
			assert_true(panel.encloses(box), "%s: %s on the sheet" % [class_id, node.ability_id])
			for other: TalentNode in nodes:
				if other == node:
					continue
				var other_box := Rect2(other.global_position, TalentNode.BOX)
				var other_label: Rect2 = other.name_label.get_global_rect()
				assert_false(label.intersects(other_box), "%s clear of %s" % [named, other.name])
				assert_false(label.intersects(other_label), "%s clear of its name" % named)
		for label: Label in _tab().tree_view().path_labels:
			assert_true(panel.encloses(label.get_global_rect()), "%s: path name fits" % class_id)
		# Every control of the tab shows inside the window.
		var all: Array[Control] = []
		_controls(_tab(), all)
		for control: Control in all:
			if control.is_visible_in_tree() and (control is Label or control is Button):
				var rect: Rect2 = control.get_global_rect()
				assert_true(panel.encloses(rect), "%s: %s inside" % [class_id, control.name])
		sheet.close()
		_hud.advance(STEP)
	# Every control has a tooltip, one sentence (the UI layer's, spec 058).
	var knight: Hero = _hero(&"knight")
	_open_talents(knight)
	var tips: Array[Control] = [_tab().reset_button, _tab().points_label, _tab().paragon_label]
	for node: TalentNode in _tab().tree_view().nodes():
		tips.append(node)
	for label: Label in _tab().tree_view().path_labels:
		tips.append(label)
	for cell: ParagonCell in _tab().paragon_cells:
		tips.append(cell.buy_button)
	for control: Control in tips:
		var text: String = _tip_text(control)
		assert_ne(text, "", "%s has a tooltip" % control.name)
		assert_true(text.ends_with("."), "%s: one sentence: %s" % [control.name, text])
	knight.set_talents(_tree(&"knight").trunk)
	_hud.advance(STEP)
	_click_node(&"whirlwind")
	for control: Control in [_tab().choose_button, _tab().not_yet_button]:
		assert_true(control.is_visible_in_tree(), "%s shows" % control.name)
		assert_ne(_tip_text(control), "", "%s has a tooltip" % control.name)
	# The help panel's text about training is replaced.
	var keys: Array[String] = []
	for entry: Array in HelpPanel.KEYS:
		keys.append(str(entry[1]))
	for text: String in keys:
		assert_false(text.contains("Training"), "no Training tab in help: %s" % text)
	# Spec 058 shortened the row to fit the help window's column on one line.
	assert_has(keys, "Talents tab: a paragon point to a stat", "Talents")


# --- R12 -----------------------------------------------------------------------


func test_r12_in_the_showcase() -> void:
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"talent_tree")
	assert_eq(showcase.moment(), &"talent_tree", "a moment for the tree")
	var sim: Simulation = showcase.main.simulation
	var knight: Hero = sim.party.heroes[0]
	var tree: TalentTreeDef = Content.talent_tree(knight.class_id)
	var sheet: HeroWindow = showcase.main.hud.hero_windows.front()
	assert_not_null(sheet, "a hero window is open")
	if sheet == null:
		return
	assert_eq(sheet.hero_id, knight.id, "on a hero")
	assert_eq(sheet.page(), HeroWindow.Page.TALENTS, "on its tree")
	assert_eq(knight.talents(), [tree.trunk[0]] as Array[StringName], "one trunk node taken")
	assert_gt(knight.talent_points(), 0, "a point to spend")
	var asked: bool = false
	var start: float = showcase.elapsed
	while showcase.moment() == &"talent_tree" and showcase.elapsed - start < 10.0:
		showcase.advance(1.0 / 30.0)
		asked = asked or sheet.talents.asking() == HeroTalentsTab.Asking.PATH
	assert_true(showcase.evidence.has(&"talent_tree"), "seen")
	assert_true(asked, "the path asked first")
	assert_true(knight.talents().has(tree.trunk[1]), "a node taken")
	assert_gte(knight.path(), 0, "and a path chosen")

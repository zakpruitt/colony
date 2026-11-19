extends "res://tests/acceptance/talent_tree_test.gd"
## Acceptance tests for specs/064-the-talent-tree-as-a-tree/spec.md, one per requirement.
##
## Each test runs the main scene with its own processing off, laid out for a chosen room, and drives
## the hero windows with clicks, keys and mouse motion pushed into the viewport as the window sends
## them (on the UI layer, turned into the world's 640x360 points); the simulation is stepped and
## checked after each command. A "tick" is one step of the simulation, one sync of the world and
## one frame of the HUD, so the events it holds are recent.

# --- R1 ------------------------------------------------------------------------


func test_r1_the_shape() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var tree: TalentTreeDef = _tree(class_id)
		_level(hero, 10)
		hero.set_talents(_walked(class_id, 1, 2))
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
		var view: TalentTreeView = _view(shown)
		var middle: float = view.get_global_rect().get_center().x
		# The trunk runs down the middle from the top.
		assert_eq(view.trunk_nodes.size(), 3, "%s: three trunk nodes" % class_id)
		var above: Rect2 = Rect2()
		for i: int in view.trunk_nodes.size():
			var node: TalentNode = view.trunk_nodes[i]
			var rect: Rect2 = node.get_global_rect()
			assert_eq(node.ability_id, tree.trunk[i], "%s: trunk %d in order" % [class_id, i])
			assert_almost_eq(rect.get_center().x, middle, 1.0, "%s centred" % _rect_text(node))
			if i == 0:
				assert_lt(rect.position.y - view.get_global_rect().position.y, 4.0, "at the top")
			else:
				assert_gt(rect.position.y, above.end.y, "%s under the one before" % node.ability_id)
			above = rect
		var trunk_end: float = view.trunk_nodes[2].name_label.get_global_rect().end.y
		# Under the last one, two columns of four, apart by a stated gap, each under its banner.
		var columns: Array[Rect2] = []
		for path: int in 2:
			var column: Array = view.path_nodes[path]
			assert_eq(column.size(), 4, "%s: four on path %d" % [class_id, path])
			var span: Rect2 = Rect2()
			for step: int in column.size():
				var node: TalentNode = column[step]
				assert_eq(node.ability_id, tree.path_nodes(path)[step], "%s: in order" % class_id)
				var rect: Rect2 = node.get_global_rect().merge(node.name_label.get_global_rect())
				assert_gt(rect.position.y, trunk_end, "%s under the trunk" % node.ability_id)
				span = rect if step == 0 else span.merge(rect)
				assert_almost_eq(
					node.get_global_rect().get_center().x,
					(column[0] as TalentNode).get_global_rect().get_center().x,
					0.5,
					"%s: a column" % node.ability_id
				)
				if step > 0:
					var before: TalentNode = column[step - 1]
					assert_gt(node.get_global_rect().position.y, before.get_global_rect().end.y)
			columns.append(span)
			var banner: PathBanner = view.banners[path]
			var flag: Rect2 = banner.get_global_rect()
			assert_eq(banner.name_label.text, tree.path_names[path], "%s: its banner" % class_id)
			assert_lt(flag.end.y, span.position.y, "%s: the banner over its column" % class_id)
			assert_true(
				flag.position.x <= span.get_center().x and flag.end.x >= span.get_center().x,
				"%s: the banner above path %d's column" % [class_id, path]
			)
		assert_lt(columns[0].end.x, middle, "%s: the first path to the left" % class_id)
		assert_gt(columns[1].position.x, middle, "%s: the second to the right" % class_id)
		assert_gte(
			columns[1].position.x - columns[0].end.x,
			TalentTreeView.PATH_GAP,
			"%s: clear space between the paths" % class_id
		)
		assert_gte(TalentTreeView.PATH_GAP, 120.0, "plainly apart")
		for path: int in 2:
			for node: TalentNode in view.path_nodes[1 - path]:
				var x_range: Rect2 = Rect2(columns[path].position.x, 0, columns[path].size.x, 1)
				var mine: Rect2 = node.get_global_rect()
				assert_false(
					x_range.intersects(Rect2(mine.position.x, 0, mine.size.x, 1)),
					"%s: not in the other path's column" % node.ability_id
				)
		_check_joins(view, tree, class_id)
		# Each path its own colour: banner, lines and frame tint, and wherever it is named.
		var first: StringName = view.path_colour(0)
		var second: StringName = view.path_colour(1)
		assert_ne(first, second, "%s: two colours" % class_id)
		for colour: StringName in [first, second]:
			assert_false(
				[&"amber", &"yellow", &"white", &"slate", &"dusk", &"ink"].has(colour),
				"%s: a path colour is not a state's" % colour
			)
		assert_eq(
			view.path_colour(1), PathColours.of(class_id, 1), "a view table by class and path"
		)
		assert_eq(
			view.banners[1].colour(), second, "%s: the walked banner in its colour" % class_id
		)
		assert_eq(view.colour_into(tree.path_b[1]), second, "%s: its lit lines" % class_id)
		assert_eq(view.node(tree.path_b[2]).tint(), second, "%s: its frame tint" % class_id)
		assert_eq(view.node(tree.path_a[2]).tint(), PathColours.dim(), "the closed one's is dark")
		assert_eq(shown.path_tint.colour_of(tree.path_names[1]), second, "the window's title")
		_click_frame(main, hero)
	# The question before a path names both, each in its colour.
	var knight: Hero = _hero(main, &"knight")
	_level(knight, 8)
	knight.set_talents(_tree(&"knight").trunk)
	var window: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	_click(main, window.talents.node(&"whirlwind").slot)
	assert_eq(window.talents.asking(), HeroTalentsTab.Asking.PATH, "asked")
	var said: WordTint = window.talents.ask_tint
	assert_eq(said.colour_of("Berserker"), PathColours.of(&"knight", 1), "Berserker in its colour")
	assert_eq(said.colour_of("Guardian"), PathColours.of(&"knight", 0), "Guardian in its colour")


# --- R2 ------------------------------------------------------------------------


func test_r2_a_node_is_a_picture() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		_level(hero, 1)
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
		var view: TalentTreeView = _view(shown)
		var nodes: Array[TalentNode] = view.nodes()
		assert_eq(nodes.size(), 11, "%s: eleven nodes" % class_id)
		for node: TalentNode in nodes:
			var ability: AbilityDef = Content.ability(node.ability_id)
			var named: String = "%s: %s" % [class_id, node.ability_id]
			var slot: UiIcon = node.slot
			assert_not_null(slot, "%s: a slot" % named)
			assert_eq(slot.size, Vector2(36, 36), "%s: a large slot" % named)
			assert_eq(slot.picture_rect.texture, UiIcon.picture(node.ability_id), "%s" % named)
			var shape: UiIcon.Shape = (
				UiIcon.Shape.SQUARE if ability.is_action() else UiIcon.Shape.CUT
			)
			assert_eq(
				slot.frame_shape(), shape, "%s: square for an action, cut for a passive" % named
			)
			# The name under it, centred, one or two lines, never cut.
			var label: Label = node.name_label
			assert_eq(label.text.replace("\n", " "), ability.display_name, "%s: its name" % named)
			assert_lte(label.text.split("\n").size(), 2, "%s: two lines at most" % named)
			var slot_rect: Rect2 = slot.get_global_rect()
			var inked: Rect2 = _text_rect(label)
			assert_gte(inked.position.y, slot_rect.end.y - 0.5, "%s: under the picture" % named)
			assert_almost_eq(
				label.get_global_rect().get_center().x,
				slot_rect.get_center().x,
				1.0,
				"%s: centred" % named
			)
			for line: String in label.text.split("\n"):
				assert_lte(
					UiText.width(line, true) - UiText.SPACING, label.size.x, "%s: whole" % named
				)
			assert_true(label.is_visible_in_tree(), "%s: the name shows" % named)
			for other: TalentNode in nodes:
				if other != node:
					assert_false(
						inked.intersects(_text_rect(other.name_label)),
						"%s clear of %s's name" % [named, other.ability_id]
					)
					assert_false(
						inked.intersects(other.slot.get_global_rect()),
						"%s clear of %s" % [named, other.ability_id]
					)
		# No description written in the tree.
		var written: Array[String] = _texts(view)
		for node: TalentNode in nodes:
			var description: String = Content.ability(node.ability_id).description
			for text: String in written:
				assert_false(
					text.contains(description.left(24)),
					"%s's description is not in the tree" % node.ability_id
				)
		_click_frame(main, hero)


# --- R3 ------------------------------------------------------------------------


func test_r3_the_states_read_at_a_glance() -> void:
	var main: Main = _game()
	for class_id: StringName in [&"knight", &"cleric"]:
		var hero: Hero = _hero(main, class_id)
		var tree: TalentTreeDef = _tree(class_id)
		for path: int in 2:
			_level(hero, 10)  # five points: the trunk, the path's first and one more
			hero.set_talents(_walked(class_id, path, 1))
			var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
			main.hud.advance(STEP)
			var view: TalentTreeView = _view(shown)
			var on: String = "%s on %s" % [class_id, tree.path_names[path]]
			var colour: StringName = view.path_colour(path)
			# Taken: the owned frame, and the line into it lit (the path's colour on a path).
			for id: StringName in _walked(class_id, path, 1):
				assert_eq(view.node(id).slot.state(), UiIcon.State.OWNED, "%s: %s owned" % [on, id])
			assert_eq(view.colour_into(tree.path_nodes(path)[0]), colour, "%s: lit" % on)
			assert_eq(view.colour_into(tree.trunk[1]), TalentTreeView.TRUNK_LIT, "the trunk lit")
			# Can be taken now: the ready frame, pulsing.
			var next: TalentNode = view.node(tree.path_nodes(path)[1])
			assert_eq(next.slot.state(), UiIcon.State.READY, "%s: the next is ready" % on)
			var seen: Dictionary[StringName, bool] = {}
			for i: int in 12:
				seen[next.slot.frame_colour()] = true
				main.hud.advance(0.1)
			assert_gt(seen.size(), 1, "%s: it pulses" % on)
			assert_eq(view.colour_into(next.ability_id), TalentTreeView.UNLIT, "not lit yet")
			# Not yet: locked.
			for id: StringName in tree.path_nodes(path).slice(2):
				assert_eq(
					view.node(id).slot.state(), UiIcon.State.LOCKED, "%s: %s locked" % [on, id]
				)
			# The path not chosen: closed, its banner dimmed with a padlock and Not chosen, its lines
			# dark.
			for id: StringName in tree.path_nodes(1 - path):
				assert_eq(
					view.node(id).slot.state(), UiIcon.State.CLOSED, "%s: %s closed" % [on, id]
				)
				assert_eq(view.colour_into(id), TalentTreeView.DARK, "%s: its line dark" % id)
			var closed: PathBanner = view.banners[1 - path]
			assert_true(closed.is_closed(), "%s: the other banner closed" % on)
			assert_true(closed.has_lock(), "%s: with a padlock" % on)
			assert_true(closed.closed_label.is_visible_in_tree(), "%s: saying so" % on)
			assert_eq(closed.closed_label.text, "Not chosen", "%s: Not chosen" % on)
			assert_ne(closed.colour(), view.path_colour(1 - path), "%s: dimmed" % on)
			assert_false(view.banners[path].is_closed(), "%s: its own open" % on)
			assert_false(view.banners[path].closed_label.is_visible_in_tree(), "not marked")
			# A closed node can still be pointed at.
			var shut: TalentNode = view.node(tree.path_nodes(1 - path)[2])
			_point(main, shut.slot)
			assert_true(main.ui.tip.card_shown(), "%s: a closed node still tells" % on)
			assert_eq(main.ui.tip.card_title.text, Content.ability(shut.ability_id).display_name)
			_point_away(main)
			_click_frame(main, hero)
	# With no point, the next node is locked, not ready.
	var knight: Hero = _hero(main, &"knight")
	_level(knight, 1)
	knight.set_talents([] as Array[StringName])
	var window: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	var first: TalentNode = _view(window).node(_tree(&"knight").trunk[0])
	assert_eq(first.slot.state(), UiIcon.State.LOCKED, "no point: locked")


# --- R4 ------------------------------------------------------------------------


func test_r4_a_path_says_what_it_is() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var tree: TalentTreeDef = _tree(class_id)
		assert_eq(tree.path_summaries.size(), 2, "%s: a line per path" % class_id)
		assert_eq(tree.validate(), PackedStringArray(), "%s: a good tree" % class_id)
		var shown: HeroWindow = _open(main, _hero(main, class_id), HeroWindow.Page.TALENTS)
		for path: int in 2:
			var summary: String = tree.path_summaries[path]
			assert_false(summary.is_empty(), "%s: a summary" % class_id)
			assert_lte(summary.length(), 60, "%s: short" % class_id)
			var banner: PathBanner = _view(shown).banners[path]
			assert_eq(banner.name_label.text, tree.path_names[path], "%s: its name" % class_id)
			assert_eq(
				banner.name_label.get_theme_font(&"font"), UiText.font(true), "the name in bold"
			)
			assert_eq(
				banner.summary_label.text.replace("\n", " "),
				summary,
				"%s: what it becomes" % class_id
			)
			assert_true(banner.summary_label.is_visible_in_tree(), "%s: shown" % class_id)
			assert_true(
				banner.get_global_rect().encloses(_text_rect(banner.summary_label)), "inside it"
			)
		_click_frame(main, _hero(main, class_id))
	# The line is data, checked by validate(): two, none empty, none over 60 characters.
	var bad: TalentTreeDef = _tree(&"rogue").duplicate()
	bad.resource_path = ""
	bad.path_summaries = ["one line only"] as Array[String]
	assert_true("\n".join(bad.validate()).contains("path_summaries"), "%s" % bad.validate())
	bad.path_summaries = ["", "fine"] as Array[String]
	assert_true("\n".join(bad.validate()).contains("summary is empty"), "%s" % bad.validate())
	bad.path_summaries = ["x".repeat(61), "fine"] as Array[String]
	assert_true("\n".join(bad.validate()).contains("over 60"), "%s" % bad.validate())
	# A view hint: the state hash leaves it out, and no rule reads it.
	var sim := Simulation.new(64)
	var before: int = sim.state_hash()
	var knight_tree: TalentTreeDef = _tree(&"knight")
	var kept: Array[String] = knight_tree.path_summaries.duplicate()
	knight_tree.path_summaries = ["changed", "changed too"] as Array[String]
	assert_eq(sim.state_hash(), before, "the hash leaves it out")
	knight_tree.path_summaries = kept
	for script_path: String in _scripts("res://sim"):
		if script_path.ends_with("talent_tree_def.gd"):
			continue
		var source: String = FileAccess.get_file_as_string(script_path)
		assert_false(source.contains("path_summaries"), "%s reads no summary" % script_path)


# --- R5 ------------------------------------------------------------------------


func test_r5_pointing_tells_all() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 2)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	var tip: UiTip = main.ui.tip
	# Every node's card: picture, name, kind, the whole description.
	for node: TalentNode in view.nodes():
		var ability: AbilityDef = Content.ability(node.ability_id)
		_point(main, node.slot)
		assert_true(tip.card_shown(), "%s: a card" % node.ability_id)
		assert_eq(tip.card_picture.texture, UiIcon.picture(node.ability_id), "its picture")
		assert_eq(tip.card_title.text, ability.display_name, "its name")
		var kind: String = "Passive"
		if ability.is_action():
			kind = "Action, every %s s" % HeroWindow.tiles(ability.cooldown)
		assert_eq(tip.card_kind.text, kind, "%s: its kind" % node.ability_id)
		assert_eq(tip.card_body.text.replace("\n", " "), ability.description, "the whole of it")
		_point_away(main)
	# How it stands, in words.
	assert_eq(_stands(main, view, tree.trunk[0]), "Click to learn", "one to take")
	assert_eq(_stands(main, view, tree.trunk[2]), "Take Taunt first", "further on")
	_level(knight, 3)
	knight.set_talents([tree.trunk[0]] as Array[StringName])
	main.hud.advance(STEP)
	assert_eq(
		_stands(main, view, tree.trunk[1]), "No points: the next comes at level 4", "no point"
	)
	assert_eq(_stands(main, view, tree.trunk[0]), "Learned", "taken")
	_level(knight, 8)
	knight.set_talents(_walked(&"knight", 1, 1))
	main.hud.advance(STEP)
	assert_eq(_stands(main, view, tree.path_a[1]), "Guardian was not chosen", "the other path")
	_point(main, view.node(tree.path_a[1]).slot)
	assert_eq(tip.card_stand.get_theme_color(&"font_color"), Palette.color(view.path_colour(0)))
	_point_away(main)
	# The words are no longer written in the tree: they are a point away.
	assert_false(_texts(view).has(Content.ability(tree.trunk[0]).description), "not in the tree")


## The last line of the card of [param view]'s node [param id]: how it stands.
func _stands(main: Main, view: TalentTreeView, id: StringName) -> String:
	_point(main, view.node(id).slot)
	var said: String = main.ui.tip.card_stand.text
	_point_away(main)
	return said


# --- R6 ------------------------------------------------------------------------


func test_r6_what_is_next_without_pointing() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 4)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	var strip: NextStrip = tab.strip
	var view: TalentTreeView = _view(shown)
	_point_away(main)
	# At the foot of the tree, the whole node.
	assert_true(strip.is_visible_in_tree(), "the strip shows")
	var tree_bottom: float = 0.0
	for node: TalentNode in view.nodes():
		tree_bottom = maxf(tree_bottom, node.name_label.get_global_rect().end.y)
	assert_gte(strip.get_global_rect().position.y, tree_bottom, "at the foot of the tree")
	var check: Callable = func(id: StringName, stand: String, learn: bool, what: String) -> void:
		var ability: AbilityDef = Content.ability(id)
		assert_eq(strip.ability_id, id, "%s: shows %s" % [what, id])
		assert_eq(strip.slot.picture_rect.texture, UiIcon.picture(id), "%s: its picture" % what)
		assert_eq(strip.name_label.text, ability.display_name, "%s: its name" % what)
		assert_eq(strip.kind_label.text, HeroTalentsTab.kind_text(id), "%s: its kind" % what)
		assert_eq(
			strip.description_label.text.replace("\n", " "), ability.description, "%s: all" % what
		)
		assert_eq(strip.stand_label.text, stand, "%s: how it stands" % what)
		assert_eq(strip.learn_button.is_visible_in_tree(), learn, "%s: Learn button" % what)
		var box: Rect2 = shown.get_global_rect()
		for label: Label in [strip.name_label, strip.kind_label, strip.description_label]:
			assert_true(box.encloses(_text_rect(label)), "%s: %s inside" % [what, label.name])
	# With nothing under the mouse: the first node it can take now.
	check.call(tree.trunk[0], "Click to learn", true, "the first to take")
	# The node under the mouse.
	_move(main.ui.ui_to_world(view.node(tree.trunk[2]).slot.get_global_rect().get_center()))
	main.hud.advance(STEP)
	check.call(tree.trunk[2], "Take Taunt first", false, "pointed at")
	_point_away(main)
	check.call(tree.trunk[0], "Click to learn", true, "the mouse gone")
	# The Learn button takes it.
	_click(main, strip.learn_button)
	_tick(main)
	assert_eq(knight.talents(), [tree.trunk[0]] as Array[StringName], "Learn takes it")
	check.call(tree.trunk[1], "Click to learn", true, "then the next")
	_click(main, strip.learn_button)
	_tick(main)
	# No point left: the first not yet taken on the hero's way, with no button.
	check.call(tree.trunk[2], "No points: the next comes at level 6", false, "nothing to take")
	# On a path: the next on it; Learn on a path's first node asks first.
	_level(knight, 8)
	knight.set_talents(tree.trunk)
	main.hud.advance(STEP)
	check.call(tree.path_a[0], "Click to learn", true, "the paths open")
	_click(main, strip.learn_button)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.PATH, "a path asks first")
	_click(main, tab.not_yet_button)
	_tick(main)
	assert_eq(knight.talents(), tree.trunk, "nothing taken")
	knight.set_talents(_walked(&"knight", 1, 2))
	_level(knight, 12)
	main.hud.advance(STEP)
	check.call(tree.path_b[2], "Click to learn", true, "down the path")


# --- R7 ------------------------------------------------------------------------


func test_r7_points() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 4)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	assert_eq(tab.points_label.text, "2 points to spend", "how many wait")
	assert_gte(
		tab.points_label.get_theme_font_size(&"font_size"),
		UiText.SIZE * 2,
		"large enough to notice"
	)
	assert_true(tab.points_label.is_visible_in_tree(), "at the top")
	assert_lt(
		tab.points_label.get_global_rect().position.y,
		_view(shown).trunk_nodes[0].get_global_rect().position.y,
		"over the tree"
	)
	_click(main, tab.node(tree.trunk[0]).slot)
	_tick(main)
	assert_eq(tab.points_label.text, "1 point to spend", "one")
	_click(main, tab.node(tree.trunk[1]).slot)
	_tick(main)
	assert_eq(tab.points_label.text, "Next point at level 6", "when the next comes")
	# The reset, with its price and reasons, asks first.
	main.simulation.party.gold = 0
	main.hud.advance(STEP)
	assert_eq(tab.reset_button.text, "Reset 400", "its price")
	assert_eq(tab.reset_reason_label.text, "Not enough gold", "and why not")
	main.simulation.party.gold = RICH
	main.hud.advance(STEP)
	_click(main, tab.reset_button)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.RESET, "it asks")
	assert_eq(tab.ask_label.text, "Reset the Knight's tree for 400 gold?", "at its price")
	assert_false(tab.question_card.is_visible_in_tree(), "no path to show")
	_click(main, tab.not_yet_button)
	_tick(main)
	assert_eq(knight.talents().size(), 2, "nothing reset")
	# The question before a path shows that path's banner and its four pictures.
	_level(knight, 8)
	knight.set_talents(tree.trunk)
	main.hud.advance(STEP)
	_click(main, tab.node(tree.path_b[0]).slot)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.PATH, "the question")
	assert_eq(tab.ask_label.text, "Choose Berserker? This closes Guardian.", "in words")
	var card: Control = tab.question_card
	assert_true(card.is_visible_in_tree(), "with the path")
	assert_eq(tab.question_banner.name_label.text, "Berserker", "its banner")
	assert_eq(tab.question_banner.summary_label.text.replace("\n", " "), tree.path_summaries[1])
	assert_eq(tab.question_icons.size(), 4, "four pictures")
	for i: int in tab.question_icons.size():
		var icon: UiIcon = tab.question_icons[i]
		assert_true(icon.is_visible_in_tree(), "picture %d shows" % i)
		assert_eq(icon.picture_rect.texture, UiIcon.picture(tree.path_b[i]), "in order")
	assert_true(shown.get_global_rect().encloses(card.get_global_rect()), "inside the window")
	_tick(main)
	assert_eq(knight.path(), -1, "asking sends nothing")
	_click(main, tab.choose_button)
	_tick(main)
	assert_eq(knight.path(), 1, "Choose sends it")
	assert_false(card.is_visible_in_tree(), "the question gone")


# --- R8 ------------------------------------------------------------------------


func test_r8_taking_a_node_is_a_moment() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 10)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	_clear_banners(main)
	# A click: the node bursts, the line into it lights, a banner names it.
	_click(main, view.node(tree.trunk[0]).slot)
	_tick(main)
	assert_eq(knight.talents(), [tree.trunk[0]] as Array[StringName], "taken")
	assert_true(moment.is_bursting(view.node(tree.trunk[0]).slot), "the node bursts")
	assert_eq(_banner(main), "Knight learned Shield Bash", "a banner")
	var bash: AbilityDef = Content.ability(tree.trunk[0])
	assert_eq(moment.banner_line.text.replace("\n", " "), _first_sentence(bash.description))
	assert_eq(moment.banner_picture.texture, UiIcon.picture(tree.trunk[0]), "with its picture")
	_clear_banners(main)
	# The Learn button: the line into it lights too.
	_point_away(main)
	_click(main, shown.talents.strip.learn_button)
	_tick(main)
	assert_true(moment.is_bursting(view.node(tree.trunk[1]).slot), "Learn: a burst")
	assert_true(view.is_lit(tree.trunk[1]), "the line into it lights")
	assert_eq(_banner(main), "Knight learned Taunt", "and a banner")
	_clear_banners(main)
	_click(main, view.node(tree.trunk[2]).slot)
	_tick(main)
	_clear_banners(main)
	# The question's yes, on the first node of a path: the path's banner, and the other closes
	# before the player's eyes within half a second.
	_click(main, view.node(tree.path_b[0]).slot)
	_click(main, shown.talents.choose_button)
	_tick(main)
	assert_eq(knight.path(), 1, "a Berserker")
	assert_true(moment.is_bursting(view.node(tree.path_b[0]).slot), "the node bursts")
	assert_eq(_banner(main), "Knight is now a Berserker", "the path's banner")
	assert_eq(
		moment.banner_line.text.replace("\n", " "),
		"Fights hurt, strikes faster and heals by hitting.",
		"with the path's line"
	)
	assert_true(view.is_closing(), "the other path closing")
	var last: TalentNode = view.node(tree.path_a[3])
	assert_ne(last.slot.state(), UiIcon.State.CLOSED, "not all at once")
	var waited: float = 0.0
	while view.is_closing() and waited < 1.0:
		main.hud.advance(0.05)
		waited += 0.05
	assert_lte(waited, 0.5 + 0.001, "within half a second")
	for id: StringName in tree.path_a:
		assert_eq(view.node(id).slot.state(), UiIcon.State.CLOSED, "%s closed" % id)
	assert_true(view.banners[0].is_closed(), "its banner closed")
	# A stale event, heard as the world catches up: the tree changes, with no burst and no banner.
	_clear_banners(main)
	var bursts: int = moment.bursts_seen()
	main.simulation.take_talent(knight.id, tree.path_b[1])
	for i: int in STALE_TICKS:
		main.simulation.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)
	assert_true(knight.talents().has(tree.path_b[1]), "taken")
	assert_eq(view.node(tree.path_b[1]).slot.state(), UiIcon.State.OWNED, "the tree shows it")
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	assert_false(view.is_lit(tree.path_b[1]), "no lighting up")
	assert_eq(_banner(main), "", "no banner")
	# A path chosen in the past closes the other at once.
	var mage: Hero = _hero(main, &"mage")
	_level(mage, 8)
	mage.set_talents(_tree(&"mage").trunk)
	var other: HeroWindow = _open(main, mage, HeroWindow.Page.TALENTS)
	main.simulation.take_talent(mage.id, _tree(&"mage").path_a[0])
	for i: int in STALE_TICKS:
		main.simulation.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)
	assert_false(_view(other).is_closing(), "nothing to watch")
	for id: StringName in _tree(&"mage").path_b:
		assert_eq(_view(other).node(id).slot.state(), UiIcon.State.CLOSED, "%s closed" % id)
	assert_eq(_banner(main), "", "no banner for it")
	assert_eq(moment.bursts_seen(), bursts, "nor a burst")


# --- R9 ------------------------------------------------------------------------


func test_r9_paragon() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = _hero(main, &"knight")
	_level(knight, 13)
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	for cell: ParagonCell in tab.paragon_cells:
		assert_false(cell.is_visible_in_tree(), "no medallion before paragon points")
	_level(knight, PARAGON_LEVEL)
	main.hud.advance(STEP)
	assert_eq(tab.paragon_label.text, "3 paragon points", "the points waiting")
	assert_true(tab.paragon_label.is_visible_in_tree(), "shown")
	var bottom: float = tab.strip.get_global_rect().end.y
	var names: Array[String] = []
	for cell: ParagonCell in tab.paragon_cells:
		var def: TrainingDef = Content.training(cell.id)
		assert_true(cell.is_visible_in_tree(), "%s: a medallion" % cell.id)
		var medal: UiIcon = cell.medallion
		assert_eq(medal.size, Vector2(36, 36), "%s: large" % cell.id)
		assert_eq(medal.picture_rect.texture, UiIcon.picture(cell.id), "%s: its picture" % cell.id)
		assert_eq(medal.count_label.text, "0", "%s: its rank as the count" % cell.id)
		assert_gte(medal.get_global_rect().position.y, bottom, "%s: under the tree" % cell.id)
		assert_eq(cell.name_label.text, def.display_name, "%s: its name" % cell.id)
		assert_gt(
			cell.name_label.get_global_rect().position.y,
			medal.get_global_rect().end.y - 0.5,
			"under"
		)
		assert_gt(
			cell.total_label.get_global_rect().position.y,
			cell.name_label.get_global_rect().position.y
		)
		names.append(cell.name_label.text)
		# Beside them, the points waiting.
		var label: Rect2 = tab.paragon_label.get_global_rect()
		assert_false(label.intersects(cell.get_global_rect()), "beside, not over")
		assert_lt(label.position.y, medal.get_global_rect().end.y, "on the same band")
	assert_eq(names, ["Power", "Toughness", "Quickness"] as Array[String])
	assert_eq(tab.paragon_cells[0].total_label.text, "+0% damage and healing", "the total")
	# A click on a medallion spends a point: it bursts and its count goes up.
	var power: ParagonCell = tab.paragon_cells[0]
	await _into_view(main, shown, power)
	_click(main, power.medallion)
	_tick(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 1, "a point in Power")
	assert_eq(power.medallion.count_label.text, "1", "its count")
	assert_eq(power.total_label.text, "+3% damage and healing", "its total")
	assert_true(moment.is_bursting(power.medallion), "it bursts")
	assert_eq(tab.paragon_label.text, "2 paragon points", "one fewer")
	# The key, on the front window's Talents tab.
	_press(main, KEY_2)
	_tick(main)
	var toughness: ParagonCell = tab.paragon_cells[1]
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "key 2")
	assert_eq(toughness.medallion.count_label.text, "1", "its count")
	assert_true(moment.is_bursting(toughness.medallion), "it bursts")
	assert_eq(toughness.total_label.text, "+3% maximum health")
	# Every tenth rank gets a banner.
	_clear_banners(main)
	_level(knight, 40)
	for i: int in 8:
		main.simulation.spend_paragon(knight.id, TrainingDef.Stat.POWER)
	_tick(main)
	_clear_banners(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 9, "nine")
	_click(main, power.medallion)
	_tick(main)
	assert_eq(power.medallion.count_label.text, "10", "ten")
	assert_eq(_banner(main), "Knight: Power 10, +30% damage and healing", "a banner")
	assert_eq(moment.banner_picture.texture, UiIcon.picture(&"power"))
	_clear_banners(main)
	_click(main, power.medallion)
	_tick(main)
	assert_eq(_banner(main), "", "the eleventh: none")


# --- R10 -----------------------------------------------------------------------


func test_r10_skills() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var rogue: Hero = _hero(main, &"rogue")
	var def: HeroClassDef = rogue.def()
	_level(rogue, 1)
	var shown: HeroWindow = _open(main, rogue, HeroWindow.Page.SKILLS)
	main.hud.advance(STEP)
	for card: HeroSkillsTab.Card in shown.skills.cards:
		var slot: UiIcon = card.slot
		assert_eq(slot.size, Vector2(36, 36), "%s: a large slot" % card.skill.id)
		assert_eq(slot.picture_rect.texture, UiIcon.picture(card.skill.id), "its picture")
		var owned: bool = rogue.level >= card.level
		var state: UiIcon.State = UiIcon.State.OWNED if owned else UiIcon.State.LOCKED
		assert_eq(slot.state(), state, "%s: owned when learned, locked if not" % card.skill.id)
		assert_eq(card.level_label.is_visible_in_tree(), not owned, "the level shows when locked")
		if not owned:
			assert_eq(card.level_label.text, "Level %d" % card.level, "%s's level" % card.skill.id)
	# A microskill learned: a banner, and a burst with the window open on Skills.
	var first: HeroSkillsTab.Card = null
	for card: HeroSkillsTab.Card in shown.skills.cards:
		if card.level > rogue.level and first == null:
			first = card
	assert_not_null(first, "a microskill to come")
	_clear_banners(main)
	rogue.xp = Hero.xp_for_level(first.level) - 1
	var ticks: int = 0
	while rogue.level < first.level and ticks < LIMIT_TICKS:
		_tick(main)
		ticks += 1
	assert_eq(rogue.level, first.level, "it levels")
	assert_true(moment.is_bursting(first.slot), "the card bursts")
	assert_eq(first.slot.state(), UiIcon.State.OWNED, "owned now")
	var banners: Array[String] = []
	for i: int in 4:
		banners.append(_banner(main))
		main.ui.moment.advance(UiMoment.BANNER_SECONDS)
	assert_has(banners, "Rogue learned %s" % first.skill.display_name, "a banner: %s" % [banners])
	# With the window on another tab: a banner, no burst.
	var second: HeroSkillsTab.Card = null
	for card: HeroSkillsTab.Card in shown.skills.cards:
		if card.level > rogue.level and second == null:
			second = card
	if second != null:
		_click(main, shown.tab_buttons[HeroWindow.Page.STATS])
		_clear_banners(main)
		rogue.xp = Hero.xp_for_level(second.level) - 1
		while rogue.level < second.level and ticks < LIMIT_TICKS * 2:
			_tick(main)
			ticks += 1
		assert_false(moment.is_bursting(second.slot), "not on Skills: no burst")
		banners.clear()
		for i: int in 4:
			banners.append(_banner(main))
			main.ui.moment.advance(UiMoment.BANNER_SECONDS)
		assert_has(banners, "Rogue learned %s" % second.skill.display_name, "still a banner")
	# One heard long after: nothing.
	_click(main, shown.tab_buttons[HeroWindow.Page.SKILLS])
	_clear_banners(main)
	var bursts: int = moment.bursts_seen()
	var cleric: Hero = _hero(main, &"cleric")
	var later: int = cleric.def().microskill_levels[cleric.def().microskill_levels.size() - 1]
	_level(cleric, later - 1)
	cleric.xp = Hero.xp_for_level(later) - 1
	ticks = 0
	while cleric.level < later and ticks < LIMIT_TICKS:
		main.simulation.step()
		ticks += 1
	for i: int in STALE_TICKS:
		main.simulation.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)
	assert_eq(moment.bursts_seen(), bursts, "a stale one: no burst")
	assert_eq(_banner(main), "", "and no banner")


# --- R11 -----------------------------------------------------------------------


func test_r11_nothing_lost() -> void:
	var main: Main = _game()
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, PARAGON_LEVEL)
	sim.party.gold = RICH
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	assert_eq(shown.talents_tag.count, HeroWindow.unspent(knight), "the tag counts what waits")
	for id: StringName in tree.trunk:
		_click(main, tab.node(id).slot)
		_tick(main)
	assert_eq(knight.talents(), tree.trunk, "take_talent, click by click")
	await _into_view(main, shown, tab.paragon_cells[1])
	_click(main, tab.paragon_cells[1].medallion)
	_tick(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "spend_paragon")
	assert_eq(shown.talents_tag.count, HeroWindow.unspent(knight), "the tag still counts")
	# A reset is never charged at a price the player did not read.
	_click(main, tab.reset_button)
	_level(knight, PARAGON_LEVEL + 1)
	main.hud.advance(STEP)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.NOTHING, "a new price: the question goes")
	tab.confirm()
	_tick(main)
	assert_eq(sim.party.gold, RICH, "nothing charged")
	_click(main, tab.reset_button)
	_click(main, tab.choose_button)
	_tick(main)
	assert_eq(knight.talents(), [] as Array[StringName], "reset_talents, read and answered")
	assert_eq(sim.party.gold, RICH - 1800, "at the price read")
	# A goal opens the hero's window on its Talents tab.
	_click_frame(main, knight)
	main.hud.advance(STEP)
	var row: int = main.hud.goals.lines().find("Spend the Knight's talent points")
	assert_gte(row, 0, "a goal: %s" % [main.hud.goals.lines()])
	if row >= 0:
		_click_world(Hud.on_screen(main.hud.goals_view.rows[row]).get_center())
		main.hud.advance(STEP)
		assert_true(main.hud.hero_windows.is_open(knight.id), "the goal opens the window")
		assert_eq(_window(main, knight).page(), HeroWindow.Page.TALENTS, "on Talents")


# --- R12 -----------------------------------------------------------------------


func test_r12_true_in_a_crowded_frame() -> void:
	var main: Main = _game()
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var cleric: Hero = _hero(main, &"cleric")
	var tree: TalentTreeDef = _tree(&"knight")
	_level(knight, 15)  # the tree's points all earned, one paragon point
	knight.set_talents(tree.trunk)
	knight.xp = Hero.xp_for_level(PARAGON_LEVEL) - 1
	_level(cleric, 2)
	cleric.xp = Hero.xp_for_level(4) - 1
	var first: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var second: HeroWindow = _open(main, cleric, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	# Level-ups, a node taken and paragon spent, all in one frame of 300 ticks.
	sim.take_talent(knight.id, tree.path_b[0])
	sim.spend_paragon(knight.id, TrainingDef.Stat.QUICKNESS)
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)
	assert_gte(knight.level, PARAGON_LEVEL, "the knight levelled")
	assert_gte(cleric.level, 4, "and the cleric")
	assert_eq(knight.paragon_rank(TrainingDef.Stat.QUICKNESS), 1, "the point spent")
	for pair: Array in [[first, knight], [second, cleric]]:
		var shown: HeroWindow = pair[0]
		var hero: Hero = pair[1]
		var named: String = hero.def().display_name
		var view: TalentTreeView = _view(shown)
		assert_false(view.is_closing(), "%s: nothing playing for the past" % named)
		for node: TalentNode in view.nodes():
			var state: UiIcon.State = UiIcon.State.LOCKED
			if hero.talents().has(node.ability_id):
				state = UiIcon.State.OWNED
			elif hero.path() >= 0 and node.path >= 0 and node.path != hero.path():
				state = UiIcon.State.CLOSED
			elif hero.can_take(node.ability_id):
				state = UiIcon.State.READY
			assert_eq(node.slot.state(), state, "%s: %s" % [named, node.ability_id])
		var points: int = hero.talent_points()
		var said: String = "%d point%s to spend" % [points, "" if points == 1 else "s"]
		if points > 0:
			assert_eq(shown.talents.points_label.text, said, "%s: the points" % named)
		var takeable: StringName = &""
		for node: TalentNode in view.nodes():
			if hero.can_take(node.ability_id) and takeable == &"":
				takeable = node.ability_id
		if takeable != &"":
			assert_eq(shown.talents.strip.ability_id, takeable, "%s: the strip" % named)
		for cell: ParagonCell in shown.talents.paragon_cells:
			var stat: TrainingDef.Stat = Content.training(cell.id).stat
			if cell.is_visible_in_tree():
				assert_eq(cell.medallion.count_label.text, str(hero.paragon_rank(stat)), cell.id)
		var waiting: int = hero.paragon_points()
		if TalentRules.talent_points_at(hero.level) >= Hero.TALENT_POINTS:
			assert_eq(
				shown.talents.paragon_label.text,
				"%d paragon point%s" % [waiting, "" if waiting == 1 else "s"],
				"%s: paragon points" % named
			)
	assert_eq(_view(first).node(tree.path_b[0]).slot.state(), UiIcon.State.OWNED, "taken")
	assert_eq(_view(first).node(tree.path_a[0]).slot.state(), UiIcon.State.CLOSED, "closed")


# --- R13 -----------------------------------------------------------------------


func test_r13_fits_and_still_compares() -> void:
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		var main: Main = _game(room)
		main.simulation.party.gold = RICH
		for class_id: StringName in CLASSES:
			var hero: Hero = _hero(main, class_id)
			var tree: TalentTreeDef = _tree(class_id)
			for path: int in 2:
				var what: String = "%dx%d %s path %d" % [room.x, room.y, class_id, path]
				_level(hero, 30)
				hero.set_talents(_walked(class_id, path, 2))
				var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
				shown.place_at(shown.default_place, Vector2(room))
				await _frames()
				_check_fits(main, shown, what)
				_check_tree(shown, what)
				# The question before the path fits too.
				hero.set_talents(tree.trunk)
				main.hud.advance(STEP)
				_click(main, shown.talents.node(tree.path_nodes(path)[0]).slot)
				await _frames()
				assert_true(shown.talents.question_card.is_visible_in_tree(), "%s: asking" % what)
				_check_fits(main, shown, "%s asking" % what)
				shown.talents.cancel()
				_click_frame(main, hero)
		if room == ROOM_LARGE:
			# Two hero windows on Talents still sit side by side, the whole tree showing.
			var heroes: Array[Hero] = main.simulation.party.heroes
			for hero: Hero in heroes:
				_level(hero, 10)
				hero.set_talents(_walked(hero.class_id, 0, 1))
			var back: HeroWindow = _open(main, heroes[0], HeroWindow.Page.TALENTS)
			var over: HeroWindow = _open(main, heroes[1], HeroWindow.Page.TALENTS)
			await _frames()
			assert_false(back.get_global_rect().intersects(over.get_global_rect()), "side by side")
			assert_eq(back.get_global_rect().position.y, over.get_global_rect().position.y, "level")
			for shown: HeroWindow in [back, over]:
				var seen: Rect2 = shown.scroll.get_global_rect()
				var strip: Rect2 = shown.talents.strip.get_global_rect()
				assert_true(
					seen.encloses(strip),
					"the whole tree and its strip show: %s in %s" % [strip, seen]
				)
			for shown: HeroWindow in [back, over]:
				_check_clear(main, shown, "side by side")
		main.free()


# --- R14 -----------------------------------------------------------------------


func test_r14_help_wiki_and_showcase() -> void:
	var idea: String = " ".join(PackedStringArray(HelpPanel.IDEA))
	assert_true(idea.contains("path"), "the help tells of the two paths: %s" % idea)
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for words: String in ["Not chosen", "Learn", "medallion", "points to spend", "banner"]:
		assert_true(wiki.contains(words), "the wiki tells of '%s'" % words)
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"talent_tree")
	var knight: Hero = showcase.main.simulation.party.heroes[0]
	var moment: UiMoment = showcase.main.ui.moment
	var bursts: int = moment.bursts_seen()
	var headlines: Dictionary[String, bool] = {}
	var closing: bool = false
	var start: float = showcase.elapsed
	while showcase.moment() == &"talent_tree" and showcase.elapsed - start < 20.0:
		showcase.advance(1.0 / 30.0)
		showcase.main.hud.advance(1.0 / 30.0)  # a frame of the HUD and the layer, as _process gives
		moment.advance(1.0 / 30.0)
		headlines[moment.shown_headline()] = true
		var window: HeroWindow = showcase.main.hud.hero_windows.window_of(knight.id)
		closing = closing or window.talents.tree_view().is_closing()
	assert_true(
		headlines.has("Knight learned Bottle-top Block"), "a node taken: %s" % [headlines.keys()]
	)
	assert_true(headlines.has("Knight is now a Berserker"), "a path chosen")
	assert_gt(moment.bursts_seen(), bursts, "with a burst")
	assert_true(closing, "and the other path closing")
	assert_gte(knight.path(), 0, "chosen")

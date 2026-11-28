extends "res://tests/acceptance/talent_tree_test_base.gd"
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
		set_level_keeping_health(hero, 10)
		hero.set_talents(_walked(class_id, 1, 2))
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
		var view: TalentTreeView = _view(shown)
		# Three columns side by side, each under its banner, its nodes in four rows.
		var columns: Array[Rect2] = []
		for path: int in 3:
			var column: Array = view.path_nodes[path]
			assert_eq(column.size(), 5, "%s: five on path %d" % [class_id, path])
			var span: Rect2 = Rect2()
			for place: int in column.size():
				var node: TalentNode = column[place]
				assert_eq(node.ability_id, tree.path(path).nodes[place], "%s: in order" % class_id)
				var rect: Rect2 = node.get_global_rect().merge(_text_rect(node.name_label))
				span = rect if place == 0 else span.merge(rect)
			columns.append(span)
			var banner: PathBanner = view.banners[path]
			var flag: Rect2 = banner.get_global_rect()
			assert_eq(banner.name_label.text, tree.path(path).display_name, "its banner")
			assert_lt(flag.end.y, span.position.y, "%s: the banner over its column" % class_id)
			assert_true(
				flag.position.x <= span.get_center().x and flag.end.x >= span.get_center().x,
				"%s: the banner above path %d's column" % [class_id, path]
			)
			if path > 0:
				assert_lt(columns[path - 1].end.x, span.position.x, "%s: apart" % class_id)
		_check_joins(view, tree, class_id)
		# Each path its own colour: banner, lines and frame tint, and wherever it is named.
		var colours: Dictionary[StringName, bool] = {}
		for path: int in 3:
			colours[view.path_colour(path)] = true
			_check_not_a_state(view.path_colour(path))
			assert_eq(view.path_colour(path), PathColours.of(class_id, path), "a view table")
			assert_eq(view.banners[path].colour(), view.path_colour(path), "the banner's colour")
			assert_eq(view.node(tree.path(path).nodes[3]).tint(), view.path_colour(path), "tint")
		assert_eq(colours.size(), 3, "%s: three colours" % class_id)
		var second: StringName = view.path_colour(1)
		assert_eq(view.colour_into(tree.path(1).nodes[1]), second, "%s: its lit lines" % class_id)
		assert_eq(
			shown.path_tint.colour_of(tree.path(1).display_name), second, "the window's title"
		)
		_click_frame(main, hero)


# --- R2 ------------------------------------------------------------------------


func test_r2_a_node_is_a_picture() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		set_level_keeping_health(hero, 1)
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
		var view: TalentTreeView = _view(shown)
		var nodes: Array[TalentNode] = view.nodes()
		assert_eq(nodes.size(), 15, "%s: fifteen nodes" % class_id)
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
					UiText.width(line, node.is_end()) - UiText.SPACING,
					label.size.x,
					"%s: whole" % named
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
	var main: Main = _ranked_game()
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var tree: TalentTreeDef = _tree(class_id)
		for path: int in 3:
			set_level_keeping_health(hero, 10)  # five points: one spent, four to spend
			hero.set_talents(_walked(class_id, path, 1))
			var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
			main.hud.advance(STEP)
			var view: TalentTreeView = _view(shown)
			var on: String = "%s on %s" % [class_id, tree.path(path).display_name]
			var nodes: Array[StringName] = tree.path(path).nodes
			# Taken: the owned frame, and the line into it lit in the path's colour.
			assert_eq(view.node(nodes[0]).slot.state(), UiIcon.State.OWNED, "%s: owned" % on)
			assert_eq(view.colour_into(nodes[0]), view.path_colour(path), "%s: lit" % on)
			# Can be taken now: the ready frame, pulsing.
			for place: int in [1, 2]:
				var next: TalentNode = view.node(nodes[place])
				assert_eq(next.slot.state(), UiIcon.State.READY, "%s: tier 2 is ready" % on)
				assert_eq(view.colour_into(next.ability_id), TalentTreeView.UNLIT, "not lit yet")
			var pulsing: TalentNode = view.node(nodes[1])
			assert_eq(pulsing.frame_colour(), &"yellow", "%s: framed in yellow" % on)
			main.hud.advance(UiIcon.PULSE_SECONDS * 0.6)
			assert_eq(pulsing.frame_colour(), &"white", "%s: gently: yellow, then white" % on)
			var seen: Dictionary[StringName, bool] = {}
			for i: int in 12:
				seen[pulsing.slot.frame_colour()] = true
				main.hud.advance(0.1)
			assert_gt(seen.size(), 1, "%s: it pulses" % on)
			# Not yet: locked.
			for id: StringName in nodes.slice(3):
				assert_eq(view.node(id).slot.state(), UiIcon.State.LOCKED, "%s: %s" % [on, id])
			# Nothing closes: every other path's tier 1 is ready too.
			for other: int in 3:
				if other != path:
					var first: TalentNode = view.node(tree.path(other).nodes[0])
					assert_eq(first.slot.state(), UiIcon.State.READY, "%s: still open" % on)
			for node: TalentNode in view.nodes():
				assert_ne(node.slot.state(), UiIcon.State.CLOSED, "%s: nothing closed" % on)
			_click_frame(main, hero)
	# With no point, tier 1 is locked, not ready.
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 1)
	knight.set_talents([] as Array[StringName])
	var window: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	var top: TalentNode = _view(window).node(_tree(&"knight").path(0).nodes[0])
	assert_eq(top.slot.state(), UiIcon.State.LOCKED, "no point: locked")


# --- R4 ------------------------------------------------------------------------


func test_r4_a_path_says_what_it_is() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var tree: TalentTreeDef = _tree(class_id)
		assert_eq(tree.validate(), PackedStringArray(), "%s: a good tree" % class_id)
		var shown: HeroWindow = _open(main, _hero(main, class_id), HeroWindow.Page.TALENTS)
		for path: int in 3:
			var summary: String = tree.path(path).summary
			assert_false(summary.is_empty(), "%s: a summary" % class_id)
			assert_lte(summary.length(), 60, "%s: short" % class_id)
			var banner: PathBanner = _view(shown).banners[path]
			assert_eq(banner.name_label.text, tree.path(path).display_name, "its name")
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
	# A view hint: the state hash leaves it out, and no rule reads it.
	var sim := Simulation.new(64)
	var before: int = sim.state_hash()
	var knight_path: SkillPathDef = _tree(&"knight").path(0)
	var kept: String = knight_path.summary
	knight_path.summary = "changed"
	assert_eq(sim.state_hash(), before, "the hash leaves it out")
	knight_path.summary = kept
	for script_path: String in _scripts("res://sim"):
		if (
			script_path.ends_with("talent_tree_def.gd")
			or script_path.ends_with("skill_path_def.gd")
		):
			continue
		var source: String = FileAccess.get_file_as_string(script_path)
		assert_false(source.contains(".summary"), "%s reads no summary" % script_path)


# --- R5 ------------------------------------------------------------------------


func test_r5_pointing_tells_all() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 2)
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
	# How it stands, in words (what a node waits for is spec 111's R5).
	assert_eq(_stands(main, view, &"taunt"), "Click to learn", "one to take")
	set_level_keeping_health(knight, 3)
	knight.set_talents([&"taunt"] as Array[StringName])
	main.hud.advance(STEP)
	assert_eq(_stands(main, view, &"taunt"), "Learned", "taken")
	_point(main, view.node(&"taunt").slot)
	assert_eq(tip.card_stand.get_theme_color(&"font_color"), Palette.color(&"green"), "in green")
	_point_away(main)
	# The words are no longer written in the tree: they are a point away.
	assert_false(_texts(view).has(Content.ability(&"taunt").description), "not in the tree")


# --- R6 ------------------------------------------------------------------------


func test_r6_what_is_next_without_pointing() -> void:
	var main: Main = _ranked_game()
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	var guardian: Array[StringName] = tree.path(0).nodes
	set_level_keeping_health(knight, 4)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var strip: NextStrip = shown.talents.strip
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
		assert_eq(strip.slot.state(), view.node(id).slot.state(), "%s: framed as its node" % what)
		var box: Rect2 = shown.get_global_rect()
		for label: Label in [strip.name_label, strip.kind_label, strip.description_label]:
			assert_true(box.encloses(_text_rect(label)), "%s: %s inside" % [what, label.name])
	# With nothing under the mouse: the first node it can take now.
	check.call(guardian[0], "Click to learn", true, "the first to take")
	# The node under the mouse.
	mouse_move(main.ui.ui_to_world(view.node(guardian[3]).slot.get_global_rect().get_center()))
	main.hud.advance(STEP)
	check.call(guardian[3], "Take Hold the Line or Bottle-top Block first", false, "pointed at")
	_point_away(main)
	check.call(guardian[0], "Click to learn", true, "the mouse gone")
	# The Learn button takes it, and then the next.
	_click(main, strip.learn_button)
	_frame(main)
	assert_eq(knight.talents(), [guardian[0]] as Array[StringName], "Learn takes it")
	check.call(guardian[1], "Click to learn", true, "then the next")
	_click(main, strip.learn_button)
	_frame(main)
	# No point left: the first not yet taken, with no button.
	check.call(guardian[2], "No points: the next comes at level 6", false, "nothing to take")
	# A node taken: framed as it stands, not as locked.
	mouse_move(main.ui.ui_to_world(view.node(guardian[0]).slot.get_global_rect().get_center()))
	main.hud.advance(STEP)
	assert_eq(strip.ability_id, guardian[0], "pointed at")
	assert_eq(strip.slot.state(), UiIcon.State.OWNED, "framed as it stands")
	_point_away(main)
	# A full tree: its last node, owned.
	var all: Array[StringName] = []
	for path: int in 3:
		all.append_array(tree.path(path).nodes)
	set_level_keeping_health(knight, 30)
	knight.set_talents(all)
	main.hud.advance(STEP)
	assert_eq(strip.ability_id, all[all.size() - 1], "the full tree's last")
	assert_eq(strip.slot.state(), UiIcon.State.OWNED, "framed as owned")


# --- R7 ------------------------------------------------------------------------


func test_r7_points() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 4)
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
		_view(shown).banners[0].get_global_rect().position.y,
		"over the tree"
	)
	_click(main, tab.node(&"whirlwind").slot)
	_frame(main)
	assert_eq(tab.points_label.text, "1 point to spend", "one")
	_click(main, tab.node(&"taunt").slot)
	_frame(main)
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
	_click(main, tab.not_yet_button)
	_frame(main)
	assert_eq(knight.talents().size(), 2, "nothing reset")


# --- R8 ------------------------------------------------------------------------


func test_r8_taking_a_node_is_a_moment() -> void:
	var main: Main = _ranked_game()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 10)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	_clear_banners(main)
	# A click: the node bursts, the line into it lights, a banner names it.
	_click(main, view.node(&"shield_bash").slot)
	_frame(main)
	assert_eq(knight.talents(), [&"shield_bash"] as Array[StringName], "taken")
	assert_true(moment.is_bursting(view.node(&"shield_bash").slot), "the node bursts")
	assert_eq(_banner(main), "Knight learned Shield Bash", "a banner")
	var bash: AbilityDef = Content.ability(&"shield_bash")
	assert_eq(moment.banner_line.text.replace("\n", " "), _first_sentence(bash.description))
	assert_eq(moment.banner_picture.texture, UiIcon.picture(&"shield_bash"), "with its picture")
	_clear_banners(main)
	# The Learn button: the line into it lights too.
	_point_away(main)
	_click(main, shown.talents.strip.learn_button)
	_frame(main)
	var learned: StringName = knight.talents()[1]
	assert_true(moment.is_bursting(view.node(learned).slot), "Learn: a burst")
	assert_true(view.is_lit(learned), "the line into it lights")
	assert_eq(_banner(main), "Knight learned %s" % Content.ability(learned).display_name)
	_clear_banners(main)
	# A stale event, heard as the world catches up: the tree changes, with no burst and no banner.
	var bursts: int = moment.bursts_seen()
	main.simulation.take_talent(knight.id, &"last_stand")
	_frame(main, STALE_TICKS)
	assert_true(knight.talents().has(&"last_stand"), "taken")
	assert_eq(view.node(&"last_stand").slot.state(), UiIcon.State.OWNED, "the tree shows it")
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	assert_false(view.is_lit(&"last_stand"), "no lighting up")
	assert_eq(_banner(main), "", "no banner")
	# A window closed while its line flashes plays nothing more when it opens again later.
	var rogue: Hero = _hero(main, &"rogue")
	var closed: HeroWindow = _take_now(main, rogue)
	closed.close()
	main.hud.advance(STEP)
	for i: int in STALE_TICKS:
		main.simulation.step()
	main.hud.hero_windows.open(rogue.id)
	main.hud.advance(STEP)
	assert_false(_view(closed).is_lit(_tree(&"rogue").path(0).nodes[0]), "no line lit later")
	# As the world catches up, what was playing stops.
	_frame(main)  # the world level with the simulation again
	var cleric: Hero = _hero(main, &"cleric")
	var caught: HeroWindow = _take_now(main, cleric)
	_frame(main, STALE_TICKS)
	assert_false(_view(caught).is_lit(_tree(&"cleric").path(0).nodes[0]), "the lit line stops")


# --- R9 ------------------------------------------------------------------------


func test_r9_paragon() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 29)
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	assert_eq(tab.paragon_label.text, "Paragon points come after level 30", "before then")
	for cell: ParagonCell in tab.paragon_cells:
		assert_false(cell.is_visible_in_tree(), "no medallion before paragon points")
	set_level_keeping_health(knight, 30)
	main.hud.advance(STEP)
	assert_eq(tab.paragon_label.text, "0 paragon points", "every talent point earned")
	set_level_keeping_health(knight, PARAGON_LEVEL)
	main.hud.advance(STEP)
	assert_eq(tab.paragon_label.text, "3 paragon points", "the points waiting")
	assert_true(tab.paragon_label.is_visible_in_tree(), "shown")
	_check_medallions(tab)
	assert_eq(tab.paragon_cells[0].total_label.text, "+0% damage and healing", "the total")
	# A click on a medallion spends a point: it bursts and its count goes up.
	var power: ParagonCell = tab.paragon_cells[0]
	assert_eq(power.text(), "Power 0 +0%", "no bonus yet")
	await _into_view(main, shown, power)
	_click(main, power.medallion)
	_frame(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 1, "a point in Power")
	assert_eq(power.medallion.count_label.text, "1", "its count")
	assert_eq(power.total_label.text, "+3% damage and healing", "its total")
	assert_eq(power.text(), "Power 1 +3%", "its bonus so far")
	assert_true(moment.is_bursting(power.medallion), "it bursts")
	assert_eq(tab.paragon_label.text, "2 paragon points", "one fewer")
	# The key, on the front window's Talents tab.
	_press(main, KEY_2)
	_frame(main)
	var toughness: ParagonCell = tab.paragon_cells[1]
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "key 2")
	assert_eq(toughness.medallion.count_label.text, "1", "its count")
	assert_true(moment.is_bursting(toughness.medallion), "it bursts")
	assert_eq(toughness.total_label.text, "+3% maximum health")
	# Every tenth rank gets a banner.
	_clear_banners(main)
	set_level_keeping_health(knight, 60)
	for i: int in 8:
		main.simulation.spend_paragon(knight.id, TrainingDef.Stat.POWER)
	_frame(main)
	_clear_banners(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 9, "nine")
	_click(main, power.medallion)
	_frame(main)
	assert_eq(power.medallion.count_label.text, "10", "ten")
	assert_eq(_banner(main), "Knight: Power 10, +30% damage and healing", "a banner")
	assert_eq(moment.banner_picture.texture, UiIcon.picture(&"power"))
	_clear_banners(main)
	_click(main, power.medallion)
	_frame(main)
	assert_eq(_banner(main), "", "the eleventh: none")
	# A point spent long ago, or heard as the world catches up, flashes nothing.
	main.hud.advance(ParagonCell.FLASH_SECONDS)
	assert_eq(power.flash(), 0.0, "at rest")
	main.simulation.spend_paragon(knight.id, TrainingDef.Stat.POWER)
	_frame(main, STALE_TICKS)
	assert_eq(power.flash(), 0.0, "no flash for a point spent long ago")
	for i: int in STALE_TICKS:
		main.simulation.step()
	main.simulation.spend_paragon(knight.id, TrainingDef.Stat.POWER)
	_frame(main, 1)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 13, "both spent")
	assert_eq(power.flash(), 0.0, "nor for one heard as the world catches up")


# --- R10 -----------------------------------------------------------------------


func test_r10_skills() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var rogue: Hero = _hero(main, &"rogue")
	var def: HeroClassDef = rogue.def()
	set_level_keeping_health(rogue, 1)
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
		_frame(main)
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
	assert_not_null(second, "a second microskill to come")
	_click(main, shown.tab_buttons[HeroWindow.Page.STATS])
	_clear_banners(main)
	rogue.xp = Hero.xp_for_level(second.level) - 1
	while rogue.level < second.level and ticks < LIMIT_TICKS * 2:
		_frame(main)
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
	set_level_keeping_health(cleric, later - 1)
	cleric.xp = Hero.xp_for_level(later) - 1
	ticks = 0
	while cleric.level < later and ticks < LIMIT_TICKS:
		main.simulation.step()
		ticks += 1
	_frame(main, STALE_TICKS)
	assert_eq(moment.bursts_seen(), bursts, "a stale one: no burst")
	assert_eq(_banner(main), "", "and no banner")


# --- R11 -----------------------------------------------------------------------


func test_r11_nothing_lost() -> void:
	var main: Main = _ranked_game()
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var three: Array[StringName] = _walked(&"knight", 0, 3)
	set_level_keeping_health(knight, PARAGON_LEVEL)
	sim.party.gold = RICH
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	assert_eq(shown.talents_tag.count, HeroWindow.unspent(knight), "the tag counts what waits")
	for id: StringName in three:
		_click(main, tab.node(id).slot)
		_frame(main)
	assert_eq(knight.talents(), three, "take_talent, click by click")
	await _into_view(main, shown, tab.paragon_cells[1])
	_click(main, tab.paragon_cells[1].medallion)
	_frame(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "spend_paragon")
	assert_eq(shown.talents_tag.count, HeroWindow.unspent(knight), "the tag still counts")
	# A reset is never charged at a price the player did not read.
	_click(main, tab.reset_button)
	set_level_keeping_health(knight, PARAGON_LEVEL + 1)
	main.hud.advance(STEP)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.NOTHING, "a new price: the question goes")
	tab.confirm()
	_frame(main)
	assert_eq(sim.party.gold, RICH, "nothing charged")
	# Nor when the answer comes before the tab has looked again: the click lands on the question
	# still up, in the frame the price changed.
	_click(main, tab.reset_button)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.RESET, "asked at the price shown")
	set_level_keeping_health(knight, PARAGON_LEVEL + 2)
	_click_ui(main.ui, tab.choose_button.get_global_rect().get_center())
	_frame(main)
	assert_eq(sim.party.gold, RICH, "answered at a price not read: nothing charged")
	assert_eq(knight.talents(), three, "and nothing reset")
	set_level_keeping_health(knight, PARAGON_LEVEL + 1)
	main.hud.advance(STEP)
	_click(main, tab.reset_button)
	assert_eq(tab.ask_label.text, "Reset the Knight's tree for 3,400 gold?", "with its price")
	_click(main, tab.choose_button)
	_frame(main)
	assert_eq(knight.talents(), [] as Array[StringName], "reset_talents, read and answered")
	assert_eq(sim.party.gold, RICH - 3400, "at the price read")
	# Nor in a fight: one starting drops the question, and an answer then does nothing.
	knight.set_talents(three)
	main.hud.advance(STEP)
	_click(main, tab.reset_button)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.RESET, "asked before the fight")
	assert_not_null(_fight(main), "a fight")
	assert_eq(tab.asking(), HeroTalentsTab.Asking.NOTHING, "a fight starts: the question goes")
	tab.confirm()
	_frame(main)
	assert_eq(knight.talents(), three, "nothing reset in a fight")
	assert_eq(sim.party.gold, RICH - 3400, "nothing charged in a fight")
	_fight_over(main)
	# A goal opens the hero's window on its Talents tab.
	_click_frame(main, knight)
	main.hud.advance(STEP)
	var row: int = main.hud.goals.lines().find("Spend the Knight's talent points")
	assert_gte(row, 0, "a goal: %s" % [main.hud.goals.lines()])
	if row >= 0:
		click(UiFormat.on_screen(main.hud.goals_view.rows[row]).get_center())
		main.hud.advance(STEP)
		assert_true(main.hud.hero_windows.is_open(knight.id), "the goal opens the window")
		assert_eq(_window(main, knight).page(), HeroWindow.Page.TALENTS, "on Talents")
	# The defeat note's button opens a hero with points to spend on Talents, whatever tab it had.
	_click(main, shown.tab_buttons[HeroWindow.Page.STATS])
	main.hud.hero_windows.close_all()
	assert_true(_answer_defeat(main, "Spend talent points"), "the note offers it after a wipe")
	var opened: HeroWindow = main.hud.hero_windows.front()
	assert_not_null(opened, "the note opens a hero window")
	if opened != null:
		assert_eq(opened.hero_id, knight.id, "the hero with points to spend")
		assert_eq(opened.page(), HeroWindow.Page.TALENTS, "on Talents")


# --- R12 -----------------------------------------------------------------------


func test_r12_true_in_a_crowded_frame() -> void:
	var main: Main = _game()
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var cleric: Hero = _hero(main, &"cleric")
	var tree: TalentTreeDef = _tree(&"knight")
	set_level_keeping_health(knight, 31)  # the tree's points all earned, one paragon point
	knight.set_talents(tree.path(0).nodes)
	knight.xp = Hero.xp_for_level(PARAGON_LEVEL) - 1
	set_level_keeping_health(cleric, 2)
	cleric.xp = Hero.xp_for_level(4) - 1
	# The cleric's window at the back changes only by its level-ups: no event of its own refreshes it.
	var second: HeroWindow = _open(main, cleric, HeroWindow.Page.TALENTS)
	var first: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	assert_eq(main.hud.hero_windows.front(), first, "the knight's in front")
	# Level-ups, a node taken and paragon spent, all in one frame of 300 ticks.
	sim.take_talent(knight.id, tree.path(1).nodes[0])
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
		assert_false(view.is_lit(tree.path(1).nodes[0]), "%s: nothing playing for the past" % named)
		for node: TalentNode in view.nodes():
			var state: UiIcon.State = UiIcon.State.LOCKED
			if hero.talents().has(node.ability_id):
				state = UiIcon.State.OWNED
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
	var berserk: TalentNode = _view(first).node(tree.path(1).nodes[0])
	assert_eq(berserk.slot.state(), UiIcon.State.OWNED, "taken")


# --- R13 -----------------------------------------------------------------------


func test_r13_fits_and_still_compares() -> void:
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		var main: Main = _game(room)
		main.simulation.party.gold = RICH
		for class_id: StringName in CLASSES:
			var hero: Hero = _hero(main, class_id)
			for path: int in 3:
				var what: String = "%dx%d %s path %d" % [room.x, room.y, class_id, path]
				set_level_keeping_health(hero, 30)
				hero.set_talents(_walked(class_id, path, 2))
				var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
				shown.place_at(shown.default_place, Vector2(room))
				await _frames()
				_check_fits(main, shown, what)
				_check_tree(shown, what)
				_click_frame(main, hero)
		if room == ROOM_LARGE:
			# With two hero windows on Talents, the whole tree shows in each.
			var heroes: Array[Hero] = main.simulation.party.heroes
			for hero: Hero in heroes:
				set_level_keeping_health(hero, 10)
				hero.set_talents(_walked(hero.class_id, 0, 1))
			var back: HeroWindow = _open(main, heroes[0], HeroWindow.Page.TALENTS)
			var over: HeroWindow = _open(main, heroes[1], HeroWindow.Page.TALENTS)
			await _frames()
			for shown: HeroWindow in [back, over]:
				var seen: Rect2 = shown.scroll.get_global_rect()
				var strip: Rect2 = shown.talents.strip.get_global_rect()
				assert_true(
					seen.encloses(strip),
					"the whole tree and its strip show: %s in %s" % [strip, seen]
				)
		main.free()


# --- R14 -----------------------------------------------------------------------


## The help and the showcase's tree moment are spec 111's R11 now.
func test_r14_help_wiki_and_showcase() -> void:
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	for words: String in ["three paths", "Learn", "medallion", "points to spend", "banner"]:
		assert_true(wiki.contains(words), "the wiki tells of '%s'" % words)

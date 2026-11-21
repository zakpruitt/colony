extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/055-the-tree-on-the-sheet/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation with the CombatEffects and the Hud on it, every
## _process turned off, and drives the hero sheet's Talents tab with mouse moves and clicks pushed
## into the viewport, as the window sends them; the simulation is stepped after each command and
## checked. Since spec 060 the sheet is a hero window on the UI layer ([HeroWindow]), so the HUD
## has a [UiRoot] over it, laid out for a 1280x720 room; a click on one of its controls is pushed
## at the world point under it ([method UiRoot.ui_to_world]).

const SEED: int = 55
const RICH: int = 1_000_000
## Where the mouse is when it is over nothing of the HUD's.
const AWAY: Vector2 = Vector2(420, 200)
const NOWHERE: Vector2 = Vector2(-1000, -1000)
const CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
## The UI layer's room (spec 058): two hero windows side by side, clear of the frames' line.
const ROOM: Vector2i = Vector2i(1280, 720)
const GUARDIAN_DEPTH: int = 5


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_mouse_rest = AWAY
	_build_hud(true, true)
	_ui.set_room_for_test(ROOM)
	_hud.advance(0.0)


func after_each() -> void:
	super()
	mouse_move(NOWHERE)


# --- Helpers -------------------------------------------------------------------


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


## The trunk and the first [param steps] nodes of path [param path] of [param class_id]'s tree.
func _walked(class_id: StringName, path: int, steps: int) -> Array[StringName]:
	var tree: TalentTreeDef = _tree(class_id)
	var nodes: Array[StringName] = tree.trunk.duplicate()
	nodes.append_array(tree.path_nodes(path).slice(0, steps))
	return nodes


## Opens [param hero]'s sheet on its Talents tab as the player would: a click on its frame, then
## on the tab.
func _open_talents(hero: Hero) -> void:
	for frame: HeroFrameView in _hud.frames:
		if frame.hero_id == hero.id:
			_click_at(UiFormat.on_screen(frame).get_center())
	_hud.advance(STEP)
	_click_at(_at(_sheet().tab_buttons[HeroWindow.Page.TALENTS]))
	_hud.advance(STEP)


func _click_and_show(control: Control) -> void:
	_click_at(_at(control))
	_hud.advance(STEP)


func _click_node(ability_id: StringName) -> void:
	var node: TalentNode = _tab().node(ability_id)
	assert_not_null(node, "%s is on the tab" % ability_id)
	if node != null:
		_click_and_show(node)


func _state(ability_id: StringName) -> TalentNode.State:
	return _tab().node(ability_id).state()


func _state_name(state: TalentNode.State) -> String:
	return TalentNode.State.keys()[state]


func _journal_has(sentence: String) -> bool:
	for line: String in _hud.journal.lines():
		if line.ends_with(sentence):
			return true
	return false


# --- R1 ------------------------------------------------------------------------


func test_r1_the_tree_is_drawn() -> void:
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(class_id)
		var tree: TalentTreeDef = _tree(class_id)
		_open_talents(hero)
		var view: TalentTreeView = _tab().tree_view()
		var left: TalentNode = view.path_nodes[0][0]
		var right: TalentNode = view.path_nodes[1][0]
		assert_eq(left.position.y, right.position.y, "%s: side by side" % class_id)
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
		_sheet().close()
		_hud.advance(STEP)


# --- R2 ------------------------------------------------------------------------


func test_r2_a_node_shows_its_state() -> void:
	for class_id: StringName in [&"knight", &"mage"]:
		var hero: Hero = _hero(class_id)
		var tree: TalentTreeDef = _tree(class_id)
		_open_talents(hero)
		for path: int in 2:
			set_level_keeping_health(hero, 10)  # five points: the trunk, the path's first node and one more
			hero.set_talents(_walked(class_id, path, 1))
			_hud.advance(STEP)
			var on: String = "%s on %s" % [class_id, tree.path_names[path]]
			var taken: TalentNode = _tab().node(tree.path_nodes(path)[0])
			assert_eq(taken.name_label.get_theme_color(&"font_color"), Palette.color(&"white"))
			for id: StringName in tree.path_nodes(1 - path):
				var closed: TalentNode = _tab().node(id)
				assert_eq(closed.frame_colour(), &"dusk", "%s: dark" % on)
		_sheet().close()
		_hud.advance(STEP)


# --- R4 ------------------------------------------------------------------------


func test_r4_taking_a_node() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	set_level_keeping_health(knight, 10)  # five points
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
	_click_and_show(_tab().not_yet_button)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "Not yet: no question")
	_frame()
	assert_eq(knight.talents(), tree.trunk, "Not yet sends nothing")
	assert_eq(knight.path(), -1, "both paths open")
	_click_node(tree.path_b[0])
	_click_and_show(_tab().choose_button)
	_frame()
	assert_eq(knight.talents(), _walked(&"knight", 1, 1), "Choose sends the command")
	assert_eq(knight.path(), 1, "a Berserker")
	# Further down the path, no question.
	_click_node(tree.path_b[1])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "no question further on")
	_frame()
	assert_eq(knight.talents(), _walked(&"knight", 1, 2), "taken at once")
	# While the page is hidden its handlers do nothing, whatever reaches them.
	set_level_keeping_health(knight, 14)
	_sim.party.gold = RICH
	_click_and_show(_sheet().tab_buttons[HeroWindow.Page.STATS])
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
	set_level_keeping_health(knight, 4)
	_open_talents(knight)
	var sheet: HeroWindow = _sheet()
	var tab: Rect2 = sheet.tab_buttons[HeroWindow.Page.TALENTS].get_global_rect()
	assert_true(sheet.talents_tag.is_visible_in_tree(), "on the tab's name")
	assert_eq(sheet.talents_tag.count, 2, "two")
	assert_true(sheet.talents_tag.get_global_rect().intersects(tab), "pinned to the tab")
	_click_node(tree.trunk[0])
	_frame()
	assert_eq(sheet.talents_tag.count, 1, "the tab says one")
	_click_node(tree.trunk[1])
	_frame()
	assert_false(sheet.talents_tag.is_visible_in_tree(), "no mark")
	set_level_keeping_health(knight, 5)
	_hud.advance(STEP)
	assert_eq(_tab().points_label.text, "Next point at level 6", "level 5")
	set_level_keeping_health(knight, 6)
	_hud.advance(STEP)
	assert_eq(_tab().points_label.text, "1 point to spend", "level 6 brings one")


# --- R6 ------------------------------------------------------------------------


func test_r6_a_fresh_start() -> void:
	var knight: Hero = _hero(&"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	set_level_keeping_health(knight, 8)
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
	_click_and_show(reset)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.RESET, "it asks")
	assert_eq(_tab().ask_label.text, "Reset the Knight's tree for 800 gold?", "the question")
	_frame()
	assert_eq(knight.talents(), tree.trunk, "asking resets nothing")
	_click_and_show(_tab().not_yet_button)
	_frame()
	assert_eq(knight.talents(), tree.trunk, "Not yet resets nothing")
	_click_and_show(reset)
	assert_eq(_tab().choose_button.text, "Reset", "the answer says what it does")
	_click_and_show(_tab().choose_button)
	_frame()
	assert_eq(knight.talents(), [] as Array[StringName], "reset")
	assert_eq(_sim.party.gold, RICH - 800, "for its price")
	assert_eq(_tab().reset_reason_label.text, "Nothing to reset", "nothing left")
	# A question never outlives what it asked: another tab, the sheet closed, a new price.
	var gold: int = _sim.party.gold
	knight.set_talents(tree.trunk)
	_hud.advance(STEP)
	_click_and_show(reset)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.RESET, "asked again")
	_click_and_show(_sheet().tab_buttons[HeroWindow.Page.STATS])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "another tab: the question goes")
	_click_and_show(_sheet().tab_buttons[HeroWindow.Page.TALENTS])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "and does not come back")
	_click_and_show(reset)
	_hud.hero_windows.window_of(knight.id).close()
	_hud.advance(STEP)
	_open_talents(knight)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "the sheet closed: gone")
	_click_and_show(reset)
	assert_eq(_tab().ask_label.text, "Reset the Knight's tree for 800 gold?", "asked at 800")
	set_level_keeping_health(knight, 17)
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
	_click_and_show(_sheet().tab_buttons[HeroWindow.Page.SKILLS])
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "another tab: it goes")
	_click_and_show(_sheet().tab_buttons[HeroWindow.Page.TALENTS])
	# In a fight: an open question goes when the fight starts.
	_click_and_show(reset)
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.RESET, "asked before the fight")
	var fighting: Callable = func() -> bool: return _sim.expedition.battle != null
	assert_true(_step_until(fighting), "a fight")
	assert_eq(_tab().asking(), HeroTalentsTab.Asking.NOTHING, "the fight starts: the question goes")
	assert_true(reset.disabled, "in a fight: greyed")
	assert_eq(_tab().reset_reason_label.text, "In a fight", "with the reason")


# --- R7 ------------------------------------------------------------------------


func test_r7_paragon() -> void:
	var knight: Hero = _hero(&"knight")
	set_level_keeping_health(knight, 17)
	_open_talents(knight)
	for cell: ParagonCell in _tab().paragon_cells:
		# Spec 064 R9: a medallion each, ready with a point, where spec 055 had a +1 button.
		assert_eq(cell.medallion.state(), UiIcon.State.READY, "lit with a point")


# --- R8 ------------------------------------------------------------------------


func test_r8_the_game_points_at_it() -> void:
	var knight: Hero = _hero(&"knight")
	var frame: HeroFrameView = _hud.frames[0]
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
		_click_and_show(_hud.goals_view.rows[row])
		assert_true(_hud.hero_windows.is_open(knight.id), "the goal opens the knight's window")
		assert_eq(_sheet().hero_id, knight.id, "in front")
		assert_eq(_sheet().page(), HeroWindow.Page.TALENTS, "on its Talents tab")
	# A path chosen.
	set_level_keeping_health(knight, 8)
	knight.set_talents(_tree(&"knight").trunk)
	_hud.advance(STEP)
	_click_node(&"whirlwind")
	_click_and_show(_tab().choose_button)
	_frame()
	assert_true(_journal_has("The Knight is now a Berserker"), "the journal notes the path")
	set_level_keeping_health(knight, 10)  # a point to spend again
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
	set_level_keeping_health(knight, 15)
	_sim.party.gold = RICH
	before_guardian(_sim, GUARDIAN_DEPTH, 0.0, true, true)
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
	var frame: HeroFrameView = _hud.frames[0]
	set_level_keeping_health(knight, 8)
	knight.set_talents(_tree(&"knight").trunk)
	_open_talents(knight)
	_click_node(&"whirlwind")
	_click_and_show(_tab().choose_button)
	_frame()
	_sheet().close()
	_hud.advance(STEP)
	mouse_move(UiFormat.on_screen(frame).get_center())
	_hud.advance(0.2)
	_hud.advance(0.3)
	assert_eq(
		_hud.frame_tip.shown_text(),
		"Knight, Berserker: click for details",
		"on the frame's tooltip"
	)
	mouse_move(AWAY)
	_hud.advance(STEP)
	mouse_move(UiFormat.on_screen(_hud.frames[1]).get_center())
	_hud.advance(0.5)
	assert_eq(_hud.frame_tip.shown_text(), "Click for details", "a hero with no path")


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
	assert_eq(_tab().points_label.text, "1 point to spend", "one left")
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
	# Every control has a tooltip, one sentence (the UI layer's, spec 058).
	var knight: Hero = _hero(&"knight")
	set_level_keeping_health(knight, 17)
	_open_talents(knight)
	var tips: Array[Control] = [_tab().reset_button, _tab().points_label, _tab().paragon_label]
	# Spec 064 R5: a node carries a card rather than a sentence (test_064's R5 points at each).
	for label: Label in _tab().tree_view().path_labels:
		tips.append(label)
	for cell: ParagonCell in _tab().paragon_cells:
		tips.append(cell.medallion)  # spec 064 R9: the medallion, where spec 055 had a button
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

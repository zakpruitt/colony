extends "res://tests/acceptance/talent_tree_test_base.gd"
## Acceptance tests for specs/111-skill-paths-the-window/spec.md, one per requirement.
##
## Each test runs the main scene laid out for a chosen room and drives the hero windows with
## clicks, keys and mouse motion pushed into the viewport; the simulation is stepped and checked
## after each command. A won fight is a real one: the party walks to it, its monsters fall, and the
## expedition hands out the path XP.

## The knight's paths, in order.
const GUARDIAN: int = 0
const BERSERKER: int = 1
const WARLORD: int = 2
## The bar's tooltip, after its numbers.
const BAR_TIP_END: String = (
	"Won fights give path XP: one for each node held here, and one each time one of its"
	+ " abilities acts."
)

# --- Helpers -------------------------------------------------------------------


## The total XP the knight's tree asks for rank [param rank] (1 or more).
func _xp_for(rank: int) -> int:
	return _tree(&"knight").rank_xp[rank - 1]


## [param rect], a rectangle in [param view]'s own pixels, on the UI layer.
func _global(view: Control, rect: Rect2) -> Rect2:
	return Rect2(view.get_global_transform() * rect.position, rect.size)


## Walks the party to its next fight and wins it: its monsters fall at once. With [param stale]
## the world hears of it only [constant STALE_TICKS] ticks later, as after a stall; else each tick
## is a frame. False when no fight came.
func _win(main: Main, stale: bool = false) -> bool:
	var battle: Battle = _fight(main)
	if battle == null:
		return false
	for monster: Combatant in battle.monsters:
		monster.health = 0
	var ticks: int = 0
	while main.simulation.expedition.battle != null and ticks < LIMIT_TICKS:
		if stale:
			main.simulation.step()
		else:
			_frame(main)
		ticks += 1
	if stale:
		_frame(main, STALE_TICKS)
	return main.simulation.expedition.battle == null


## Every headline [param main]'s moment shows from now, as the banners take their turns.
func _banners_in_turn(main: Main) -> Array[String]:
	var seen: Array[String] = []
	for i: int in UiMoment.MAX_WAITING + 2:
		var said: String = _banner(main)
		if not said.is_empty():
			seen.append(said)
		main.ui.moment.advance(UiMoment.BANNER_SECONDS)
	return seen


## Lets [param main]'s banners take their turns until the one headed [param headline] shows;
## false when none does.
func _shows(main: Main, headline: String) -> bool:
	for i: int in UiMoment.MAX_WAITING + 2:
		if _banner(main) == headline:
			return true
		main.ui.moment.advance(UiMoment.BANNER_SECONDS)
	return false


## What node [param id]'s slot says on its corner, or "" when nothing shows there.
func _corner(view: TalentTreeView, id: StringName) -> String:
	var count: Label = view.node(id).slot.count_label
	return count.text if count.is_visible_in_tree() else ""


## True when [param main]'s journal has a line ending in [param sentence].
func _journal_says(main: Main, sentence: String) -> bool:
	for line: String in main.hud.journal.lines():
		if line.ends_with(sentence):
			return true
	return false


## The knight with every node of its tree.
func _all_nodes(class_id: StringName) -> Array[StringName]:
	var all: Array[StringName] = []
	for path: int in 3:
		all.append_array(_tree(class_id).path(path).nodes)
	return all


## Sets each of [param hero]'s paths to the rank in [param ranks], XP [param extra] past it.
func _set_ranks(hero: Hero, ranks: Array, extra: int = 0) -> void:
	var tree: TalentTreeDef = _tree(hero.class_id)
	for path: int in ranks.size():
		var rank: int = ranks[path]
		var floor_xp: int = tree.rank_xp[rank - 1] if rank > 0 else 0
		hero.ranks.set_xp(path, floor_xp + extra)


# --- R1 ------------------------------------------------------------------------


func test_r1_three_panels() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var tree: TalentTreeDef = _tree(class_id)
		set_level_keeping_health(hero, 10)
		_set_ranks(hero, [3, 0, 10], 4)
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
		main.hud.advance(STEP)
		var view: TalentTreeView = _view(shown)
		var panels: Array[Rect2] = view.panels()
		assert_eq(panels.size(), 3, "%s: three panels" % class_id)
		var left: float = view.get_global_rect().position.x
		for path: int in panels.size():
			var named: String = "%s path %d" % [class_id, path]
			var panel: Rect2 = _global(view, panels[path])
			# Side by side across the window's width, in path order, apart by the stated gap.
			assert_gte(panel.position.x, left, "%s: in the window" % named)
			assert_lte(panel.end.x, left + HeroWindow.WIDTH, "%s: within 600 pixels" % named)
			if path > 0:
				var before: Rect2 = _global(view, panels[path - 1])
				assert_eq(panel.position.y, before.position.y, "%s: side by side" % named)
				assert_eq(
					panel.position.x - before.end.x, TalentTreeView.PANEL_GAP, "%s: apart" % named
				)
			assert_gt(TalentTreeView.PANEL_GAP, 0.0, "clear space between them")
			# Its banner on top, in the path's colour.
			var banner: PathBanner = view.banners[path]
			var flag: Rect2 = banner.get_global_rect()
			assert_true(panel.encloses(flag), "%s: the banner in its panel" % named)
			assert_almost_eq(flag.position.y, panel.position.y, 6.0, "%s: on top" % named)
			assert_eq(banner.colour(), PathColours.of(class_id, path), "%s: its colour" % named)
			for node: StringName in tree.path(path).nodes:
				var slot: Rect2 = view.node(node).slot.get_global_rect()
				assert_true(panel.encloses(slot), "%s: %s in its panel" % [named, node])
				assert_gt(slot.position.y, flag.end.y, "%s: %s under the banner" % [named, node])
			# The name in bold, the summary under it on up to two lines, the rank on the name's line.
			assert_eq(banner.name_label.text, tree.path(path).display_name, "%s: its name" % named)
			assert_eq(banner.name_label.get_theme_font(&"font"), UiText.font(true), "in bold")
			var summary: Label = banner.summary_label
			assert_eq(summary.text.replace("\n", " "), tree.path(path).summary, "%s" % named)
			assert_lte(summary.text.split("\n").size(), 2, "%s: two lines at most" % named)
			assert_true(flag.encloses(_text_rect(summary)), "%s: the summary whole" % named)
			assert_gt(summary.position.y, banner.name_label.position.y, "under the name")
			var rank: Rect2 = _text_rect(banner.rank_label)
			assert_eq(rank.position.y, _text_rect(banner.name_label).position.y, "the name's line")
			assert_false(rank.intersects(_text_rect(banner.name_label)), "clear of the name")
			assert_true(flag.encloses(rank), "%s: the rank inside" % named)
		assert_eq(view.banners[0].rank_label.text, "Rank 3", "%s: its rank" % class_id)
		assert_eq(view.banners[1].rank_label.text, "Rank 0", "%s: none yet" % class_id)
		_click_frame(main, hero)


# --- R2 ------------------------------------------------------------------------


func test_r2_a_bar_to_the_next_rank() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	set_level_keeping_health(knight, 10)
	knight.set_talents([&"taunt"] as Array[StringName])
	knight.ranks.set_xp(GUARDIAN, _xp_for(3) + 6)
	knight.ranks.set_xp(WARLORD, tree.rank_xp[tree.rank_xp.size() - 1] + 40)
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	var view: TalentTreeView = _view(shown)
	var guardian: PathBanner = view.banners[GUARDIAN]
	var span: int = _xp_for(4) - _xp_for(3)
	# Under the banner's words, in the path's colour, filled by how far the XP has come.
	var bar: RankBar = guardian.rank_bar
	assert_true(bar.is_visible_in_tree(), "a bar")
	assert_almost_eq(bar.share(), 6.0 / span, 0.001, "6 of %d XP into rank 3" % span)
	assert_eq(bar.fill, PathColours.of(&"knight", GUARDIAN), "in the path's colour")
	var bar_rect: Rect2 = bar.get_global_rect()
	assert_gte(bar_rect.position.y, _text_rect(guardian.summary_label).end.y, "under the words")
	assert_true(guardian.get_global_rect().encloses(bar_rect), "part of the banner")
	assert_gte(bar_rect.size.x, guardian.size.x * 0.8, "across the banner")
	assert_almost_eq(view.banners[BERSERKER].rank_bar.share(), 0.0, 0.001, "nothing yet")
	# At the top rank, full, and the banner says so.
	var warlord: PathBanner = view.banners[WARLORD]
	assert_eq(warlord.rank_label.text, "Rank 10, top", "the top rank")
	assert_almost_eq(warlord.rank_bar.share(), 1.0, 0.001, "full")
	# Pointing at the bar tells the numbers, read from the hero and the tree.
	var said: String = "Guardian rank 3: 6 of %d XP to rank 4. %s" % [span, BAR_TIP_END]
	assert_eq(main.ui.tip.text_for(bar), said, "the bar's tooltip")
	_point(main, bar)
	assert_eq(main.ui.tip.shown_text().replace("\n", " "), said, "shown when pointed at")
	_point_away(main)
	# A real won fight moves it on.
	assert_true(_win(main), "a fight won")
	main.hud.advance(1.0)
	var gained: int = knight.ranks.xp(GUARDIAN) - _xp_for(3)
	assert_gt(gained, 6, "the fight gave Guardian XP")
	assert_almost_eq(bar.share(), float(gained) / span, 0.001, "the bar shows it")
	var now: String = "Guardian rank 3: %d of %d XP to rank 4. %s" % [gained, span, BAR_TIP_END]
	assert_eq(main.ui.tip.text_for(bar), now, "and the tooltip")


# --- R3 ------------------------------------------------------------------------


func test_r3_tier_rows_with_lines() -> void:
	var main: Main = _game()
	for class_id: StringName in CLASSES:
		var hero: Hero = _hero(main, class_id)
		var tree: TalentTreeDef = _tree(class_id)
		set_level_keeping_health(hero, 12)
		var held: Array[StringName] = [tree.path(0).nodes[0], tree.path(1).nodes[0]]
		hero.set_talents(held)
		_set_ranks(hero, [2, 0, 10])
		var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
		main.hud.advance(STEP)
		var view: TalentTreeView = _view(shown)
		for path: int in 3:
			var named: String = "%s path %d" % [class_id, path]
			var ids: Array[StringName] = tree.path(path).nodes
			var rects: Array[Rect2] = []
			for id: StringName in ids:
				rects.append(view.node(id).slot.get_global_rect())
			var middle: float = _global(view, view.panels()[path]).get_center().x
			# Four rows, one per tier, each below the one before.
			assert_lt(rects[0].end.y, rects[1].position.y, "%s: tier 2 under tier 1" % named)
			assert_eq(rects[1].position.y, rects[2].position.y, "%s: the tier-2 pair" % named)
			assert_lt(rects[1].end.x, rects[2].position.x, "%s: side by side" % named)
			var west: Rect2 = rects[1].merge(_text_rect(view.node(ids[1]).name_label))
			var east: Rect2 = rects[2].merge(_text_rect(view.node(ids[2]).name_label))
			assert_false(west.intersects(east), "%s: clear of each other" % named)
			assert_lt(rects[2].end.y, rects[3].position.y, "%s: tier 3 under tier 2" % named)
			assert_lt(rects[3].end.y, rects[4].position.y, "%s: the capstone last" % named)
			for place: int in [0, 3, 4]:
				assert_almost_eq(rects[place].get_center().x, middle, 1.0, "%s: centred" % named)
			assert_almost_eq(
				(rects[1].get_center().x + rects[2].get_center().x) / 2.0, middle, 1.0, "the pair"
			)
			# Every node a large picture with its name under it, whole, on one or two lines.
			for id: StringName in ids:
				var node: TalentNode = view.node(id)
				var ability: AbilityDef = Content.ability(id)
				assert_eq(node.slot.size, Vector2(36, 36), "%s: large" % id)
				var shape: UiIcon.Shape = (
					UiIcon.Shape.SQUARE if ability.is_action() else UiIcon.Shape.CUT
				)
				assert_eq(node.slot.frame_shape(), shape, "%s: action or passive" % id)
				assert_eq(node.name_label.text.replace("\n", " "), ability.display_name, "%s" % id)
				assert_lte(node.name_label.text.split("\n").size(), 2, "%s: two lines at most" % id)
				var inked: Rect2 = _text_rect(node.name_label)
				assert_gte(inked.position.y, node.slot.get_global_rect().end.y - 0.5, "under it")
				assert_lte(inked.size.x, node.name_label.size.x + 1.0, "%s: never cut" % id)
				assert_almost_eq(
					inked.get_center().x, node.slot.get_global_rect().get_center().x, 1.5, "centred"
				)
			# The capstone marked as the path's end: bold, and a wider ring in every state.
			var cap: TalentNode = view.node(ids[4])
			assert_true(cap.is_end(), "%s: the capstone is the end" % named)
			assert_eq(cap.name_label.get_theme_font(&"font"), UiText.font(true), "its name bold")
			assert_eq(cap.tint(), view.path_colour(path), "%s: its ring" % named)
			for place: int in 4:
				var other: TalentNode = view.node(ids[place])
				assert_false(other.is_end(), "%s: not an end" % other.ability_id)
				assert_ne(other.name_label.get_theme_font(&"font"), UiText.font(true), "plain")
				assert_gt(cap.ring_width(), other.ring_width(), "the capstone's ring stands out")
		_check_joins(view, tree, class_id)
		# The lines: lit into a taken node, dark into one the rank holds shut, plain otherwise.
		var paths: Array[SkillPathDef] = tree.paths
		var lit: StringName = view.path_colour(0)
		assert_eq(view.colour_into(paths[0].nodes[1]), TalentTreeView.UNLIT, "rank 2: open, plain")
		assert_eq(view.colour_into(paths[0].nodes[3]), PathColours.dim(), "rank 2 shuts tier 3")
		assert_eq(view.colour_into(paths[1].nodes[1]), PathColours.dim(), "rank 0 shuts tier 2")
		assert_eq(view.colour_into(paths[2].nodes[1]), TalentTreeView.UNLIT, "top rank: plain")
		assert_ne(PathColours.dim(), TalentTreeView.UNLIT, "dark is not plain")
		_click(main, view.node(paths[0].nodes[1]).slot)
		_frame(main)
		assert_true(hero.talents().has(paths[0].nodes[1]), "%s: a click takes it" % class_id)
		main.hud.advance(TalentTreeView.FLASH_SECONDS + 0.1)
		assert_eq(view.colour_into(paths[0].nodes[1]), lit, "%s: lit once taken" % class_id)
		# The capstone's ring shows whatever its state.
		hero.set_talents(_all_nodes(class_id))
		set_level_keeping_health(hero, 30)
		main.hud.advance(STEP)
		assert_eq(view.node(paths[0].nodes[4]).tint(), lit, "%s: taken, still ringed" % class_id)
		_click_frame(main, hero)


# --- R4 ------------------------------------------------------------------------


func test_r4_the_states_read_at_a_glance() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 10)  # five points, one spent
	knight.set_talents([&"taunt"] as Array[StringName])
	_set_ranks(knight, [2, 0, 10])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	var view: TalentTreeView = _view(shown)
	# Taken: owned.
	assert_eq(view.node(&"taunt").slot.state(), UiIcon.State.OWNED, "taken: owned")
	assert_eq(_corner(view, &"taunt"), "", "no corner")
	# Can be taken now: ready, pulsing.
	var pulsing: TalentNode = view.node(&"hold_the_line")
	assert_eq(pulsing.slot.state(), UiIcon.State.READY, "ready")
	var colours: Dictionary[StringName, bool] = {}
	for i: int in 14:
		colours[pulsing.frame_colour()] = true
		main.hud.advance(0.1)
	assert_gt(colours.size(), 1, "it pulses")
	assert_eq(_corner(view, &"hold_the_line"), "", "no corner")
	# Waits for a node above it: locked, no corner.
	assert_eq(view.node(&"last_stand").slot.state(), UiIcon.State.LOCKED, "waits for above")
	assert_eq(_corner(view, &"last_stand"), "", "rank 10: no corner")
	# Held shut by its path's rank: locked, with the rank on the corner.
	var shut: Dictionary[StringName, String] = {
		&"bulwark": "Rank 5", &"rallying_cry": "Rank 9", &"bloodthirst": "Rank 2"
	}
	for id: StringName in shut:
		var slot: UiIcon = view.node(id).slot
		assert_eq(slot.state(), UiIcon.State.LOCKED, "%s: locked" % id)
		assert_eq(_corner(view, id), shut[id], "%s: the rank that opens it" % id)
		assert_true(
			slot.get_global_rect().grow(1.0).encloses(_text_rect(slot.count_label)), "on the slot"
		)
	# Waits for a point: locked.
	set_level_keeping_health(knight, 2)
	main.hud.advance(STEP)
	assert_eq(pulsing.slot.state(), UiIcon.State.LOCKED, "no point: locked")
	assert_eq(_corner(view, &"hold_the_line"), "", "and no corner: the rank is there")
	assert_eq(_corner(view, &"bulwark"), "Rank 5", "the corner stays while the rank is short")
	# A click on a shut node takes nothing.
	set_level_keeping_health(knight, 10)
	main.hud.advance(STEP)
	_click(main, view.node(&"bloodthirst").slot)
	_frame(main)
	assert_eq(knight.talents(), [&"taunt"] as Array[StringName], "a click takes nothing")


# --- R5 ------------------------------------------------------------------------


func test_r5_pointing_and_the_strip_tell_all() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	var tip: UiTip = main.ui.tip
	set_level_keeping_health(knight, 10)
	knight.set_talents([&"taunt", &"whirlwind"] as Array[StringName])
	_set_ranks(knight, [3, 5, 0])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	var strip: NextStrip = shown.talents.strip
	_point_away(main)
	# The card: picture, name, kind, description and its standing.
	_point(main, view.node(&"bulwark").slot)
	assert_true(tip.card_shown(), "a card")
	assert_eq(tip.card_title.text, "Bulwark", "its name")
	assert_eq(tip.card_picture.texture, UiIcon.picture(&"bulwark"), "its picture")
	assert_eq(tip.card_kind.text, HeroTalentsTab.kind_text(&"bulwark"), "its kind")
	_point_away(main)
	assert_eq(_stands(main, view, &"taunt"), "Learned")
	assert_eq(_stands(main, view, &"bloodthirst"), "Click to learn")
	assert_eq(_stands(main, view, &"rampage"), "Take Bloodthirst or Reckless Swing first")
	assert_eq(
		_stands(main, view, &"bulwark"),
		"Take Hold the Line or Bottle-top Block first\nRank 5 in Guardian opens this (now rank 3)",
		"the node above, then the rank"
	)
	_click(main, view.node(&"hold_the_line").slot)
	_frame(main)
	assert_true(knight.talents().has(&"hold_the_line"), "a click takes it")
	assert_eq(_stands(main, view, &"bulwark"), "Rank 5 in Guardian opens this (now rank 3)")
	# Several at once, in order: the node above, the rank, a point.
	set_level_keeping_health(knight, 6)  # three points, all spent
	main.hud.advance(STEP)
	assert_eq(_stands(main, view, &"reckless_swing"), "No points: the next comes at level 8")
	assert_eq(
		_stands(main, view, &"bulwark"),
		"Rank 5 in Guardian opens this (now rank 3)\nNo points: the next comes at level 8"
	)
	assert_eq(
		_stands(main, view, &"last_stand"),
		(
			"Take Shield Bash first\nRank 2 in Warlord opens this (now rank 0)\n"
			+ "No points: the next comes at level 8"
		)
	)
	set_level_keeping_health(knight, 11)
	main.hud.advance(STEP)
	assert_eq(_stands(main, view, &"reckless_swing"), "Click to learn", "two points again")
	# The strip: the node under the mouse.
	mouse_move(main.ui.ui_to_world(view.node(&"rampage").slot.get_global_rect().get_center()))
	main.hud.advance(STEP)
	assert_eq(strip.ability_id, &"rampage", "the strip shows the node pointed at")
	_point_away(main)
	# With none, the first that can be taken now; Learn takes it.
	assert_eq(strip.ability_id, &"bottle_top_block", "the first to take")
	assert_eq(strip.stand_label.text, "Click to learn")
	_click(main, strip.learn_button)
	_frame(main)
	assert_true(knight.talents().has(&"bottle_top_block"), "Learn takes it")
	# With none of those, the first held shut only by its rank, and how far its rank has to go.
	knight.set_talents([&"taunt", &"whirlwind", &"shield_bash"] as Array[StringName])
	_set_ranks(knight, [1, 1, 1], 2)
	set_level_keeping_health(knight, 8)  # four points, three spent
	main.hud.advance(STEP)
	assert_eq(strip.ability_id, &"hold_the_line", "held shut only by its rank")
	var need: String = "%d of %d XP to Rank 2" % [_xp_for(1) + 2, _xp_for(2)]
	assert_eq(strip.stand_label.text, need, "how far the rank has to go")
	assert_false(strip.learn_button.is_visible_in_tree(), "no Learn")
	_point(main, view.node(&"hold_the_line").slot)
	assert_eq(tip.card_stand.text, "Rank 2 in Guardian opens this (now rank 1)", "its card")
	_point_away(main)
	# With none of those either, the first not taken, by the first thing it waits for.
	set_level_keeping_health(knight, 6)  # three points, all spent
	main.hud.advance(STEP)
	assert_eq(strip.ability_id, &"hold_the_line", "the first not taken")
	assert_eq(strip.stand_label.text, "Rank 2 in Guardian opens this (now rank 1)")
	assert_false(strip.learn_button.is_visible_in_tree(), "nothing to learn")


# --- R6 ------------------------------------------------------------------------


func test_r6_points_and_paragon() -> void:
	var main: Main = _ranked_game()
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 4)
	knight.set_talents([] as Array[StringName])
	main.simulation.party.gold = RICH
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	main.hud.advance(STEP)
	assert_eq(tab.points_label.text, "2 points to spend", "the points")
	_click(main, tab.node(&"taunt").slot)
	_frame(main)
	assert_eq(tab.points_label.text, "1 point to spend", "one spent")
	_click(main, tab.reset_button)
	assert_eq(tab.ask_label.text, "Reset the Knight's tree for 400 gold?", "asked at its price")
	_click(main, tab.choose_button)
	_frame(main)
	assert_eq(knight.talents(), [] as Array[StringName], "reset")
	assert_eq(main.simulation.party.gold, RICH - 400, "at the price read")
	# All fifteen learned.
	set_level_keeping_health(knight, PARAGON_LEVEL)
	knight.set_talents(_all_nodes(&"knight"))
	main.hud.advance(STEP)
	assert_eq(tab.points_label.text, "All 15 learned", "the whole tree")
	# Paragon: the medallions and their keys.
	assert_eq(tab.paragon_label.text, "3 paragon points", "paragon points wait")
	await _into_view(main, shown, tab.paragon_cells[0])
	_click(main, tab.paragon_cells[0].medallion)
	_frame(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 1, "a click spends one")
	_press(main, KEY_3)
	_frame(main)
	assert_eq(knight.paragon_rank(TrainingDef.Stat.QUICKNESS), 1, "key 3 spends one")
	assert_eq(tab.paragon_label.text, "1 paragon point", "one left")


# --- R7 ------------------------------------------------------------------------


func test_r7_a_path_ranks_up_a_moment() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 10)
	knight.set_talents(
		[&"taunt", &"hold_the_line", &"whirlwind", &"shield_bash"] as Array[StringName]
	)
	knight.ranks.set_xp(GUARDIAN, _xp_for(5) - 1)  # one short of rank 5, which opens tier 3
	knight.ranks.set_xp(BERSERKER, _xp_for(3) - 1)  # one short of rank 3, which opens nothing
	knight.ranks.set_xp(WARLORD, _xp_for(10) - 1)  # one short of the top
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	main.hud.advance(STEP)
	_clear_banners(main)
	var guardian: PathBanner = view.banners[GUARDIAN]
	var before: float = guardian.rank_bar.share()
	assert_gt(before, 0.9, "nearly full")
	assert_eq(view.node(&"bulwark").slot.count_label.text, "Rank 5", "held shut")
	assert_true(_win(main), "a fight won")
	assert_eq(knight.ranks.rank(GUARDIAN, _tree(&"knight")), 5, "Guardian reached rank 5")
	assert_eq(knight.ranks.rank(BERSERKER, _tree(&"knight")), 3, "Berserker rank 3")
	assert_eq(knight.ranks.rank(WARLORD, _tree(&"knight")), 10, "Warlord at the top")
	# The rank number bursts; the bar fills, then starts again from empty.
	assert_eq(guardian.rank_label.text, "Rank 5", "the new rank")
	assert_true(moment.is_bursting(guardian.rank_label), "the rank bursts")
	assert_true(moment.is_bursting(view.banners[BERSERKER].rank_label), "every rank-up bursts")
	assert_true(guardian.rank_bar.is_sweeping(), "the bar sweeps")
	var shares: Array[float] = []
	for i: int in 60:
		shares.append(guardian.rank_bar.share())
		main.hud.advance(STEP)
	var top: int = 0
	for i: int in shares.size():
		if shares[i] > shares[top]:
			top = i
	assert_almost_eq(shares[top], 1.0, 0.001, "it fills: %s" % [shares])
	assert_gte(shares[0], before - 0.001, "from where it was")
	var lowest: float = 1.0
	for share: float in shares.slice(top):
		lowest = minf(lowest, share)
	assert_lt(lowest, 0.2, "then starts again from empty")
	var gained: int = knight.ranks.xp(GUARDIAN) - _xp_for(5)
	var span: int = _xp_for(6) - _xp_for(5)
	assert_false(guardian.rank_bar.is_sweeping(), "and ends")
	assert_almost_eq(guardian.rank_bar.share(), float(gained) / span, 0.001, "where the XP is")
	# The opened tier loses its corner and pulses, for a point waits.
	var bulwark: TalentNode = view.node(&"bulwark")
	assert_false(bulwark.slot.count_label.is_visible_in_tree(), "no corner now")
	assert_eq(bulwark.slot.state(), UiIcon.State.READY, "ready, pulsing")
	# Banners for the tier opened and for the top; none for the rank between.
	var headlines: Array[String] = _banners_in_turn(main)
	assert_has(headlines, "Knight: Guardian rank 5", "the tier's banner: %s" % [headlines])
	assert_has(headlines, "Knight: Warlord at its top rank", "the top's banner")
	assert_does_not_have(headlines, "Knight: Berserker rank 3", "no banner for an ordinary rank")
	main.simulation.take_talent(knight.id, &"bloodthirst")
	_frame(main)
	_clear_banners(main)
	knight.ranks.set_xp(BERSERKER, _xp_for(5) - 1)
	assert_true(_win(main), "another fight won")
	assert_true(_shows(main, "Knight: Berserker rank 5"), "a tier opened")
	assert_eq(moment.banner_line.text, "Rampage can be learned now", "naming its node")
	assert_eq(moment.banner_picture.texture, UiIcon.picture(&"rampage"), "with its picture")
	_clear_banners(main)
	# The journal, for a tier opened and for the top.
	assert_true(_journal_says(main, "The Knight's Guardian reached rank 5"), "the journal")
	assert_true(_journal_says(main, "The Knight's Warlord reached rank 10"), "the top")
	assert_false(_journal_says(main, "The Knight's Berserker reached rank 3"), "not every rank")
	# A tier-2 rank names both its nodes.
	var rogue: Hero = _hero(main, &"rogue")
	var venom: Array[StringName] = _tree(&"rogue").path(1).nodes
	set_level_keeping_health(rogue, 10)
	rogue.set_talents([venom[0]] as Array[StringName])
	rogue.ranks.set_xp(1, _tree(&"rogue").rank_xp[1] - 1)
	assert_true(_win(main), "a fight won")
	var said: String = (
		"%s and %s can be learned now"
		% [Content.ability(venom[1]).display_name, Content.ability(venom[2]).display_name]
	)
	assert_true(_shows(main, "Rogue: Venom rank 2"), "the rogue's tier 2")
	assert_eq(moment.banner_line.text, said, "both nodes of tier 2")
	_clear_banners(main)
	# A stale one changes the numbers with no burst, no banner and no sweep.
	var bursts: int = moment.bursts_seen()
	knight.ranks.set_xp(GUARDIAN, _xp_for(9) - 1)
	assert_true(_win(main, true), "a fight won, heard late")
	assert_eq(knight.ranks.rank(GUARDIAN, _tree(&"knight")), 9, "ranked")
	main.hud.advance(STEP)
	assert_eq(guardian.rank_label.text, "Rank 9", "the number changes")
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	assert_false(guardian.rank_bar.is_sweeping(), "no sweep")
	assert_eq(_banners_in_turn(main), [] as Array[String], "no banner")


# --- R8 ------------------------------------------------------------------------


func test_r8_a_capstone_learned_a_bigger_moment() -> void:
	var main: Main = _game()
	var moment: UiMoment = main.ui.moment
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, 10)
	knight.set_talents([&"taunt", &"hold_the_line", &"bulwark"] as Array[StringName])
	_set_ranks(knight, [9, 0, 0])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	main.hud.advance(STEP)
	_clear_banners(main)
	_click(main, view.node(&"rallying_cry").slot)
	_frame(main)
	assert_true(knight.talents().has(&"rallying_cry"), "the capstone taken")
	assert_true(moment.is_bursting(view.node(&"rallying_cry").slot), "it bursts")
	# The path's lines light up one after another, from tier 1 down, within 0.6 s.
	var lit_at: Dictionary[StringName, float] = {}
	var dark_at: Dictionary[StringName, float] = {}
	var time: float = 0.0
	for i: int in 50:
		for id: StringName in _tree(&"knight").path(GUARDIAN).nodes.slice(1):
			if view.is_lit(id) and not lit_at.has(id):
				lit_at[id] = time
			if not view.is_lit(id) and lit_at.has(id) and not dark_at.has(id):
				dark_at[id] = time
		main.hud.advance(STEP)
		time += STEP
	for id: StringName in [&"hold_the_line", &"bottle_top_block", &"bulwark", &"rallying_cry"]:
		assert_true(lit_at.has(id), "%s's line lit: %s" % [id, lit_at])
		assert_true(dark_at.has(id), "and back")
		if dark_at.has(id):
			assert_lte(dark_at[id], 0.6 + STEP * 2.0, "%s: within 0.6 s" % id)
	if lit_at.size() == 4:
		assert_lt(lit_at[&"hold_the_line"], lit_at[&"bulwark"], "tier 2 before tier 3")
		assert_lt(lit_at[&"bulwark"], lit_at[&"rallying_cry"], "tier 3 before the capstone")
	var lines: Array[StringName] = _tree(&"knight").path(BERSERKER).nodes
	assert_false(lit_at.has(lines[1]), "only its own path")
	assert_eq(view.colour_into(&"rallying_cry"), view.path_colour(GUARDIAN), "lit after")
	# Its banner, in place of the plain one.
	var headlines: Array[String] = []
	main.ui.moment.advance(0.01)
	headlines.append(moment.shown_headline())
	assert_eq(headlines[0], "Knight masters Guardian", "the banner")
	var cry: AbilityDef = Content.ability(&"rallying_cry")
	assert_eq(moment.banner_line.text.replace("\n", " "), _first_sentence(cry.description))
	assert_eq(moment.banner_picture.texture, UiIcon.picture(&"rallying_cry"), "its picture")
	headlines.append_array(_banners_in_turn(main))
	assert_does_not_have(headlines, "Knight learned Rallying Cry", "not the plain one")
	assert_true(_journal_says(main, "The Knight mastered Guardian"), "the journal")
	# A node short of the capstone still gets the plain moment.
	_click(main, view.node(&"bottle_top_block").slot)
	_frame(main)
	assert_eq(_banner(main), "Knight learned Bottle-top Block", "the plain banner")
	_clear_banners(main)
	# A stale one gets none of it.
	var bursts: int = moment.bursts_seen()
	knight.set_talents([&"whirlwind", &"bloodthirst", &"rampage"] as Array[StringName])
	_set_ranks(knight, [9, 9, 0])
	main.hud.advance(STEP)
	main.simulation.take_talent(knight.id, &"earthshaker")
	_frame(main, STALE_TICKS)
	assert_true(knight.talents().has(&"earthshaker"), "taken")
	assert_eq(view.node(&"earthshaker").slot.state(), UiIcon.State.OWNED, "the tree shows it")
	assert_eq(moment.bursts_seen(), bursts, "no burst")
	assert_false(view.is_lit(&"rampage"), "no lines lit")
	assert_eq(_banners_in_turn(main), [] as Array[String], "no banner")


# --- R9 ------------------------------------------------------------------------


func test_r9_fits_and_still_compares() -> void:
	for room: Vector2i in [ROOM_LARGE, ROOM_SMALL]:
		var main: Main = _game(room)
		for class_id: StringName in CLASSES:
			var hero: Hero = _hero(main, class_id)
			var half: Array[StringName] = _walked(class_id, 0, 2)
			half.append_array(_walked(class_id, 1, 3))
			var states: Array[Array] = [
				[1, [] as Array[StringName], [0, 0, 0]],
				[12, half, [1, 4, 8]],
				[PARAGON_LEVEL, _all_nodes(class_id), [10, 10, 10]],
			]
			for state: Array in states:
				var level: int = state[0]
				var ranks: Array = state[2]
				var what: String = "%dx%d %s level %d" % [room.x, room.y, class_id, level]
				set_level_keeping_health(hero, level)
				var held: Array[StringName] = state[1]
				hero.set_talents(held)
				_set_ranks(hero, ranks, 1)
				var shown: HeroWindow = _open(main, hero, HeroWindow.Page.TALENTS)
				shown.place_at(shown.default_place, Vector2(room))
				await _frames()
				_check_fits(main, shown, what)
				_check_tree(shown, what)
				for node: TalentNode in _view(shown).nodes():
					var count: Label = node.slot.count_label
					if count.is_visible_in_tree():
						var on: Rect2 = node.slot.get_global_rect().grow(1.0)
						assert_true(on.encloses(_text_rect(count)), "%s: corner whole" % what)
				_click_frame(main, hero)
		var heroes: Array[Hero] = main.simulation.party.heroes
		for hero: Hero in heroes:
			set_level_keeping_health(hero, 10)
			hero.set_talents(_walked(hero.class_id, 0, 1))
		var back: HeroWindow = _open(main, heroes[0], HeroWindow.Page.TALENTS)
		var over: HeroWindow = _open(main, heroes[1], HeroWindow.Page.TALENTS)
		await _frames()
		var a: Rect2 = back.get_global_rect()
		var b: Rect2 = over.get_global_rect()
		if room == ROOM_LARGE:
			assert_false(a.intersects(b), "side by side at 1280x720: %s and %s" % [a, b])
			for shown: HeroWindow in [back, over]:
				var seen: Rect2 = shown.scroll.get_global_rect()
				assert_true(seen.encloses(shown.talents.strip.get_global_rect()), "whole")
		else:
			assert_true(a.intersects(b), "cascaded at 960x540")
			assert_gt(b.position.x, a.position.x, "each right of the one before")
			assert_gt(b.position.y, a.position.y, "and down")
		main.free()


# --- R10 -----------------------------------------------------------------------


func test_r10_true_in_a_crowded_frame() -> void:
	var main: Main = _game()
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	var cleric: Hero = _hero(main, &"cleric")
	var tree: TalentTreeDef = _tree(&"knight")
	set_level_keeping_health(knight, 9)
	knight.xp = Hero.xp_for_level(10) - 1
	knight.set_talents([&"taunt"] as Array[StringName])
	knight.ranks.set_xp(GUARDIAN, _xp_for(2) - 1)
	set_level_keeping_health(cleric, 3)
	cleric.xp = Hero.xp_for_level(4) - 1
	var second: HeroWindow = _open(main, cleric, HeroWindow.Page.TALENTS)
	var first: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	main.hud.advance(STEP)
	var battle: Battle = _fight(main)
	assert_not_null(battle, "a fight")
	# A won fight, a node taken and level-ups, in one frame of 300 ticks.
	sim.take_talent(knight.id, &"whirlwind")
	for monster: Combatant in battle.monsters:
		monster.health = 0
	for i: int in 300:
		sim.step()
	main.world.sync(STEP)
	main.hud.advance(STEP)
	assert_null(sim.expedition.battle, "the fight is over")
	assert_gte(knight.ranks.rank(GUARDIAN, tree), 2, "Guardian ranked")
	assert_gte(knight.level, 10, "the knight levelled")
	assert_gte(cleric.level, 4, "and the cleric")
	assert_true(knight.talents().has(&"whirlwind"), "the node taken")
	for pair: Array in [[first, knight], [second, cleric]]:
		var shown: HeroWindow = pair[0]
		var hero: Hero = pair[1]
		var hero_tree: TalentTreeDef = _tree(hero.class_id)
		var named: String = hero.def().display_name
		var view: TalentTreeView = _view(shown)
		for path: int in 3:
			var banner: PathBanner = view.banners[path]
			var rank: int = hero.ranks.rank(path, hero_tree)
			var into: int = hero.ranks.xp(path) - (hero_tree.rank_xp[rank - 1] if rank > 0 else 0)
			var next: int = hero_tree.rank_xp[mini(rank, hero_tree.rank_xp.size() - 1)]
			var span: int = next - (hero_tree.rank_xp[rank - 1] if rank > 0 else 0)
			assert_eq(
				banner.rank_label.text, "Rank %d" % rank, "%s: path %d's rank" % [named, path]
			)
			assert_false(banner.rank_bar.is_sweeping(), "%s: nothing playing for the past" % named)
			assert_almost_eq(banner.rank_bar.share(), float(into) / span, 0.001, "%s: bar" % named)
		for node: TalentNode in view.nodes():
			var state: UiIcon.State = UiIcon.State.LOCKED
			if hero.talents().has(node.ability_id):
				state = UiIcon.State.OWNED
			elif hero.can_take(node.ability_id):
				state = UiIcon.State.READY
			assert_eq(node.slot.state(), state, "%s: %s" % [named, node.ability_id])
			var shut: bool = (
				not hero.talents().has(node.ability_id)
				and (
					hero.ranks.rank(hero_tree.path_of(node.ability_id), hero_tree)
					< hero_tree.rank_needed(node.ability_id)
				)
			)
			assert_eq(
				node.slot.count_label.visible, shut, "%s: %s's corner" % [named, node.ability_id]
			)
		var takeable: StringName = &""
		for node: TalentNode in view.nodes():
			if hero.can_take(node.ability_id) and takeable == &"":
				takeable = node.ability_id
		if takeable != &"":
			assert_eq(shown.talents.strip.ability_id, takeable, "%s: the strip" % named)
		var points: int = hero.talent_points()
		var said: String = "%d point%s to spend" % [points, "" if points == 1 else "s"]
		if points > 0:
			assert_eq(shown.talents.points_label.text, said, "%s: the points" % named)
	# A still tab words nothing.
	var worded: int = first.talents.worded
	for i: int in 3:
		main.hud.advance(STEP)
	assert_eq(first.talents.worded, worded, "a still tab words nothing")


# --- R11 -----------------------------------------------------------------------


func test_r11_help_wiki_and_showcase() -> void:
	var idea: String = " ".join(PackedStringArray(HelpPanel.IDEA))
	for words: String in ["three skill paths", "rank it up", "later tiers"]:
		assert_string_contains(idea, words, "the help tells of it")
	var wiki: String = FileAccess.get_file_as_string(WIKI)
	var heroes_at: int = wiki.find('<h2 id="heroes">')
	var heroes: String = wiki.substr(heroes_at, wiki.find('<h2 id="screen">') - heroes_at)
	for words: String in ["talent point", "tier", "rank"]:
		assert_string_contains(heroes, words, "the rules of %s" % words)
	var tree: TalentTreeDef = _tree(&"knight")
	for rank: int in tree.rank_xp.size():
		assert_string_contains(
			heroes, "<td>%d</td><td>%d</td>" % [rank + 1, tree.rank_xp[rank]], "the rank table"
		)
	for class_id: StringName in CLASSES:
		var class_tree: TalentTreeDef = _tree(class_id)
		for path: int in 3:
			for node: StringName in class_tree.path(path).nodes:
				var ability: AbilityDef = Content.ability(node)
				var kind: String = "Action" if ability.is_action() else "Passive"
				var row: String = (
					"<td>%d</td><td>%s</td><td>%s</td>"
					% [class_tree.tier_of(node), ability.display_name, kind]
				)
				assert_string_contains(heroes, row, "%s in the wiki" % node)
	for entry: String in [
		"109 Three paths of five", "110 Skill paths", "111 Skill paths: the window"
	]:
		assert_string_contains(wiki, entry, "the finished entry")
	assert_false(heroes.contains("planned (spec 111)"), "no longer planned")
	# The showcase: a node taken by a click, a path ranking up after a won fight, a capstone.
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(&"talent_tree")
	var knight: Hero = showcase.main.simulation.party.heroes[0]
	var windows: HeroWindows = showcase.main.hud.hero_windows
	assert_true(windows.is_open(knight.id), "the knight's window")
	assert_eq(windows.window_of(knight.id).page(), HeroWindow.Page.TALENTS, "on Talents")
	var moment: UiMoment = showcase.main.ui.moment
	var bursts: int = moment.bursts_seen()
	var headlines: Dictionary[String, bool] = {}
	var start: float = showcase.elapsed
	while showcase.moment() == &"talent_tree" and showcase.elapsed - start < 25.0:
		showcase.advance(1.0 / 30.0)
		showcase.main.hud.advance(1.0 / 30.0)
		moment.advance(1.0 / 30.0)
		headlines[moment.shown_headline()] = true
	var seen: bool = showcase.evidence.get(&"talent_tree", false)
	assert_true(seen, "the watcher saw it")
	assert_true(headlines.has("Knight learned Whirlwind"), "a click: %s" % [headlines.keys()])
	assert_true(headlines.has("Knight: Guardian rank 9"), "a rank-up: %s" % [headlines.keys()])
	assert_true(headlines.has("Knight masters Guardian"), "a capstone: %s" % [headlines.keys()])
	assert_gt(moment.bursts_seen(), bursts + 2, "with bursts")


# --- R12 -----------------------------------------------------------------------


func test_r12_nothing_lost() -> void:
	var main: Main = _ranked_game()
	var sim: Simulation = main.simulation
	var knight: Hero = _hero(main, &"knight")
	set_level_keeping_health(knight, PARAGON_LEVEL)
	sim.party.gold = RICH
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var tab: HeroTalentsTab = shown.talents
	assert_eq(shown.talents_tag.count, HeroWindow.unspent(knight), "the tag counts what waits")
	_click(main, tab.node(&"taunt").slot)
	_frame(main)
	assert_eq(knight.talents(), [&"taunt"] as Array[StringName], "take_talent by a click")
	assert_eq(shown.talents_tag.count, HeroWindow.unspent(knight), "the tag still counts")
	# A reset is never charged at a price the player did not read.
	_click(main, tab.reset_button)
	set_level_keeping_health(knight, PARAGON_LEVEL + 1)
	main.hud.advance(STEP)
	assert_eq(tab.asking(), HeroTalentsTab.Asking.NOTHING, "a new price: the question goes")
	tab.confirm()
	_frame(main)
	assert_eq(sim.party.gold, RICH, "nothing charged")
	assert_eq(knight.talents(), [&"taunt"] as Array[StringName], "nothing reset")
	# A goal opens the hero's window on its Talents tab.
	_click(main, shown.tab_buttons[HeroWindow.Page.STATS])
	_click_frame(main, knight)
	main.hud.advance(STEP)
	var row: int = main.hud.goals.lines().find("Spend the Knight's talent points")
	assert_gte(row, 0, "a goal: %s" % [main.hud.goals.lines()])
	if row >= 0:
		click(UiFormat.on_screen(main.hud.goals_view.rows[row]).get_center())
		main.hud.advance(STEP)
		assert_true(main.hud.hero_windows.is_open(knight.id), "the goal opens the window")
		assert_eq(_window(main, knight).page(), HeroWindow.Page.TALENTS, "on Talents")

extends "res://tests/support/main_fixture.gd"
## What the acceptance tests of spec 060 (the hero windows) share: their constants and helpers, on
## top of MainFixture's. Kept apart so the tests' own file stays under gdlint's length.

const RICH: int = 1_000_000
const CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const WIKI: String = "res://docs/wiki/index.html"
const OLD_SHEET: String = "res://game/hud/hero_sheet.gd"

# --- Helpers -------------------------------------------------------------------


func _hero(main: Main, class_id: StringName) -> Hero:
	for hero: Hero in main.simulation.party.heroes:
		if hero.class_id == class_id:
			return hero
	return null


## The trunk and the first [param steps] nodes of path [param path] of [param class_id]'s tree.
func _walked(class_id: StringName, path: int, steps: int) -> Array[StringName]:
	var tree: TalentTreeDef = Content.talent_tree(class_id)
	var nodes: Array[StringName] = tree.trunk.duplicate()
	nodes.append_array(tree.path_nodes(path).slice(0, steps))
	return nodes


func _frame_of(main: Main, hero: Hero) -> HeroFrameView:
	for frame: HeroFrameView in main.hud.frames:
		if frame.hero_id == hero.id:
			return frame
	return null


## A real click on [param hero]'s frame, then a frame of the HUD.
func _click_frame(main: Main, hero: Hero) -> void:
	click(UiFormat.on_screen(_frame_of(main, hero)).get_center())
	main.hud.advance(STEP)


func _window(main: Main, hero: Hero) -> HeroWindow:
	return main.hud.hero_windows.window_of(hero.id)


## Opens [param hero]'s window with a click on its frame and its [param page] with a click on the
## tab.
func _open(main: Main, hero: Hero, page: HeroWindow.Page) -> HeroWindow:
	if not main.hud.hero_windows.is_open(hero.id):
		_click_frame(main, hero)
	var shown: HeroWindow = _window(main, hero)
	if shown.page() != page:
		_click(main, shown.tab_buttons[page])
	return shown


## The rectangle [param label]'s text inks, in UI pixels: as wide as its widest line in its font,
## a line tall per line.
func _text_rect(label: Label) -> Rect2:
	var bold: bool = label.get_theme_font(&"font") == UiText.font(true)
	var widest: int = 0
	var lines: PackedStringArray = label.text.split("\n")
	for line: String in lines:
		widest = maxi(widest, UiText.width(line, bold) - UiText.SPACING)
	var at: Vector2 = label.get_global_rect().position
	return Rect2(at, Vector2(widest, lines.size() * UiText.LINE_HEIGHT))


## Every label of [param node]'s branch that shows text.
func _shown_labels(node: Node) -> Array[Label]:
	var all: Array[Control] = []
	_controls(node, all)
	var labels: Array[Label] = []
	for control: Control in all:
		var label: Label = control as Label
		if label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			labels.append(label)
	return labels


## Checks that every text shown on [param shown]'s open tab and header is inside the window and the
## room, inside its own label, and clear of every other text.
func _check_fits(main: Main, shown: HeroWindow, what: String) -> void:
	var window: Rect2 = shown.get_global_rect()
	var room := Rect2(Vector2.ZERO, Vector2(main.ui.room()))
	assert_lte(window.size.y, room.size.y, "%s: never taller than the room" % what)
	var labels: Array[Label] = _shown_labels(shown)
	var rects: Array[Rect2] = []
	# What scrolls is judged against the whole scrolled content, every line of it reachable.
	var view: Rect2 = shown.scroll.get_global_rect()
	assert_true(window.encloses(view), "%s: the scrolled view inside the window" % what)
	assert_true(room.encloses(view), "%s: the scrolled view inside the room" % what)
	var content: Rect2 = view
	content.position.y -= shown.scroll.scroll_vertical
	content.size.y = maxf(view.size.y, shown.scroll.get_v_scroll_bar().max_value)
	for label: Label in labels:
		var inked: Rect2 = _text_rect(label)
		rects.append(inked)
		var named: String = "%s: '%s'" % [what, label.text.replace("\n", " / ")]
		var scrolled: bool = shown.scroll.is_ancestor_of(label)
		assert_true((content if scrolled else window).encloses(inked), "%s inside" % named)
		if not scrolled:
			assert_true(room.encloses(inked), "%s inside the room" % named)
		assert_lte(inked.size.x, label.size.x + 1.0, "%s not cut at its right" % named)
		assert_eq(label.clip_text, false, "%s not clipped" % named)
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s whole" % named)
		assert_lte(label.max_lines_visible, 0, "%s every line" % named)
	for a: int in labels.size():
		for b: int in range(a + 1, labels.size()):
			if rects[a].intersects(rects[b]):
				fail_test(
					(
						"%s: '%s' overlaps '%s'"
						% [what, labels[a].text.left(30), labels[b].text.left(30)]
					)
				)


## A point, in UI pixels, where [param shown] is the front-most window, under its title bar (so
## not on its close button).
func _visible_point(main: Main, shown: UiWindow) -> Vector2:
	var rect: Rect2 = shown.get_global_rect()
	var below: int = int(shown.title_bar.get_global_rect().end.y) + 4
	for y: int in range(below, int(rect.end.y), 8):
		for x: int in range(int(rect.position.x) + 2, int(rect.end.x), 8):
			var at := Vector2(x, y)
			if main.ui.windows.window_at(main.ui.ui_to_world(at)) == shown:
				return at
	return rect.get_center()


## Steps until a fight is under way, and returns it (null if none came).
func _fight(main: Main) -> Battle:
	var ticks: int = 0
	while main.simulation.expedition.battle == null and ticks < LIMIT_TICKS:
		_frame(main)
		ticks += 1
	return main.simulation.expedition.battle


func _state_name(state: TalentNode.State) -> String:
	return TalentNode.State.keys()[state]


## Checks that [param shown] is inside the room, under the top band, and clear of the button bar
## and of the frames' line.
func _check_clear(main: Main, shown: HeroWindow, what: String) -> void:
	var rect: Rect2 = shown.get_global_rect()
	var band: float = main.ui.world_to_ui(Vector2(0, HudFrame.TOP_BAND)).y
	var frames: float = main.ui.world_to_ui(main.hud.frames[0].get_global_rect().position).y
	assert_true(
		Rect2(Vector2.ZERO, Vector2(main.ui.room())).encloses(rect), "%s: in the room" % what
	)
	assert_gte(rect.position.y, band, "%s: under the top band" % what)
	assert_lte(rect.end.y, frames, "%s: clear of the frames' line" % what)
	assert_false(rect.intersects(main.ui.bar.get_global_rect()), "%s: clear of the bar" % what)

extends "res://tests/acceptance/hero_windows_test.gd"
## What the acceptance tests of spec 064 (the talent tree as a tree) share: their constants and
## helpers, on top of hero_windows_test.gd's. Kept apart so the tests' own file stays under
## gdlint's length.

const SEED_TICKS: int = 5
## Ticks the simulation runs on before the world hears of it: what it reported is long past.
const STALE_TICKS: int = 400
## A level with every talent point earned and three paragon points.
const PARAGON_LEVEL: int = 17

# --- Helpers -------------------------------------------------------------------


## The main scene for [param room], the world synced a few times so its next sync is an ordinary
## frame (the first one catches up).
func _game(room: Vector2i = ROOM_LARGE) -> Main:
	var main: Main = _main(room)
	for i: int in SEED_TICKS:
		_tick(main)
	return main


func _tree(class_id: StringName) -> TalentTreeDef:
	return Content.talent_tree(class_id)


func _view(shown: HeroWindow) -> TalentTreeView:
	return shown.talents.tree_view()


## Moves the mouse onto [param control], a control on the UI layer, and lets a tooltip rest.
func _point(main: Main, control: Control) -> void:
	_move(main.ui.ui_to_world(control.get_global_rect().get_center()))
	main.ui.tip.advance(UiTip.DELAY + 0.1)


func _point_away(main: Main) -> void:
	_move(Vector2(-1000, -1000))
	main.ui.tip.advance(0.1)
	main.hud.advance(STEP)


## The first sentence of [param text]: up to the first full stop followed by a space, or all.
func _first_sentence(text: String) -> String:
	var at: int = text.find(". ")
	return text if at < 0 else text.left(at + 1)


## The banner [param main]'s moment shows next, once it has moved on a little.
func _banner(main: Main) -> String:
	main.ui.moment.advance(0.01)
	return main.ui.moment.shown_headline()


## Lets every banner showing or waiting go.
func _clear_banners(main: Main) -> void:
	for i: int in 8:
		main.ui.moment.advance(UiMoment.BANNER_SECONDS)


## Every Label under [param node] whose text is not empty.
func _texts(node: Node) -> Array[String]:
	var all: Array[Control] = []
	_controls(node, all)
	var found: Array[String] = []
	for control: Control in all:
		var label: Label = control as Label
		if label != null and not label.text.is_empty():
			found.append(label.text.replace("\n", " "))
	return found


func _rect_text(node: TalentNode) -> String:
	return "%s %s" % [node.ability_id, node.get_global_rect()]


## Checks that [param view]'s nodes are joined in order by lines with an arrowhead into each: down
## the trunk, and from its last node into each path and down it.
func _check_joins(view: TalentTreeView, tree: TalentTreeDef, class_id: StringName) -> void:
	# Joined by lines with arrowheads: each node to the next, the last trunk node to both paths.
	var joined: Dictionary[String, bool] = {}
	for join: Array in view.joins():
		var ends: Array = join[1]
		if ends.size() == 2:
			var a: StringName = (ends[0] as TalentNode).ability_id
			joined["%s>%s" % [a, (ends[1] as TalentNode).ability_id]] = true
	var headed: Dictionary[StringName, Rect2] = {}
	for arrow: Array in view.arrows():
		headed[(arrow[1] as TalentNode).ability_id] = arrow[0]
	for path: int in 2:
		var order: Array[StringName] = tree.trunk.duplicate()
		order.append_array(tree.path_nodes(path))
		for i: int in range(1, order.size()):
			var key: String = "%s>%s" % [order[i - 1], order[i]]
			assert_true(joined.has(key), "%s: %s joined" % [class_id, key])
			assert_true(headed.has(order[i]), "%s: an arrowhead into %s" % [class_id, order[i]])
			if headed.has(order[i]):
				var into: Rect2 = view.node(order[i]).get_global_rect()
				var head: Rect2 = headed[order[i]]
				head.position += view.global_position
				assert_lte(head.end.y, into.position.y + 0.5, "%s: the head points in" % order[i])
				assert_gt(head.end.y, into.position.y - 4.0, "%s: right at it" % order[i])


func _scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found


## Checks that no node's picture or name of [param shown]'s tree overlaps another's, or a banner.
func _check_tree(shown: HeroWindow, what: String) -> void:
	var view: TalentTreeView = _view(shown)
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	for node: TalentNode in view.nodes():
		boxes.append(node.slot.get_global_rect())
		names.append("%s's picture" % node.ability_id)
		boxes.append(_text_rect(node.name_label))
		names.append("%s's name" % node.ability_id)
	for banner: PathBanner in view.banners:
		boxes.append(banner.get_global_rect())
		names.append("banner %s" % banner.name_label.text)
	for a: int in boxes.size():
		for b: int in range(a + 1, boxes.size()):
			assert_false(
				boxes[a].intersects(boxes[b]), "%s: %s over %s" % [what, names[a], names[b]]
			)


## Turns the mouse wheel over [param shown]'s scrolled part until [param control] is wholly in view
## (as a player scrolls down to the medallions), at most twenty notches.
func _into_view(main: Main, shown: HeroWindow, control: Control) -> void:
	await _frames()  # the scroll learns how tall its content has grown
	for i: int in 20:
		var seen: Rect2 = shown.scroll.get_global_rect()
		if seen.encloses(control.get_global_rect()):
			return
		var at: Vector2 = main.ui.ui_to_world(seen.get_center())
		_move(at)
		_button(at, true, MOUSE_BUTTON_WHEEL_DOWN)
		_button(at, false, MOUSE_BUTTON_WHEEL_DOWN)
		main.hud.advance(STEP)
		await _frames()

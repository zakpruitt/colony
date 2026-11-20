extends "res://tests/acceptance/frame_061_test_base.gd"
## What the acceptance tests of spec 062 (goals, stages and news on the sharp layer) share, on top
## of frame_061_test_base.gd's: situations, the draw order and a probe for clicks that go through.
## Kept apart so the tests' own file stays under gdlint's length.

const RICH: int = 1_000_000
const GOAL_LEVEL: int = 40
const GUARDIAN_DEPTH: int = 5
## Where the mouse rests when it is on nothing, in the world's screen pixels.
const NOWHERE_WORLD: Vector2 = Vector2(-50, -50)

var _away_save: String = save_path("away")
var _away_settings: String = save_path("away", "settings")

# --- Situations ----------------------------------------------------------------


## Raises [param hero] to [param level] with its talent points spent (spec 055), and its paragon
## points (spec 051) unless [param keep_paragon].
func _level(hero: Hero, level: int, keep_paragon: bool = false) -> void:
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var order: Array[StringName] = tree.trunk.duplicate()
	order.append_array(tree.path_a)
	hero.set_talents(order.slice(0, TalentRules.talent_points_at(hero.level)))
	var quickness: TrainingDef.Stat = TrainingDef.Stat.QUICKNESS
	if not keep_paragon:
		hero.set_paragon_rank(quickness, hero.paragon_rank(quickness) + hero.paragon_points())
	hero.health = hero.max_health()


## Puts the party on [param depth] with [param deepest] and [param stable], auto-push on, and lets
## any goal finished by the jump have its moment and go.
func _situation(main: Main, depth: int, deepest: int, stable: int) -> void:
	var e: Expedition = main.simulation.expedition
	e.depth = depth
	e.x = main.simulation.labyrinth.level(depth).chambers[0].rect.position.x
	e.deepest_depth = deepest
	e.last_stable_depth = stable
	e.target_depth = depth
	e.auto_push = true
	main.hud.advance(STEP)
	main.hud.advance(STEP)
	main.hud.advance(Goals.CELEBRATE_SECONDS + 0.1)


## Spec 042's situation: [Reach Mossy Hollow 2, Train a hero, Buy an upgrade].
func _gold_situation(main: Main) -> void:
	for hero: Hero in main.simulation.party.heroes:
		_level(hero, GOAL_LEVEL, true)
	main.simulation.party.gold = RICH
	_situation(main, 1, 1, 1)


## Plays until the next fight starts, then loses it: the party is wiped. True once it is.
func _lose_next_fight(main: Main) -> bool:
	if not _fight(main):
		return false
	for fighter: Combatant in main.simulation.expedition.battle.heroes:
		fighter.health = 0
	return _until(
		main, func() -> bool: return main.simulation.expedition.state == Expedition.State.REVIVING
	)


## A wipe by the guardian of stage 5, the party weak, holding a fortune.
func _guardian_wipe(main: Main) -> bool:
	main.simulation.party.gold = RICH
	_before_guardian(main, GUARDIAN_DEPTH)
	main.simulation.expedition.last_stable_depth = GUARDIAN_DEPTH - 1
	return _lose_next_fight(main)


## Writes a stamped save of a game that has played a while, and settings with the Journal left
## open; returns the settings.
func _away_files(main_room: Vector2i) -> SoundSettings:
	var first: Main = _main(main_room, SoundSettings.new(_away_settings))
	first.ui.windows.open_window(UiRoot.JOURNAL)
	first.free()
	var played := Simulation.new(Main.SIMULATION_SEED)
	for i: int in 600:
		played.step()
	played.drain_events()
	var data: Dictionary = played.to_save()
	data[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system()
	assert_true(SaveStore.new(_away_save).write(data), "the test's save was written")
	return SoundSettings.new(_away_settings)


## A main scene loading the save after [param seconds] away, with [param settings].
func _main_after_away(seconds: float, settings: SoundSettings) -> Main:
	var main: Main = make_main()
	main.settings = settings
	main.save_store = SaveStore.new(_away_save)
	main.away_seconds_override = seconds
	add_child_autofree(main)
	return main


# --- Seeing --------------------------------------------------------------------


## The names of what on [param layer] draws over [param item]: anything later in the draw order
## (the tree's, or a higher z) whose rectangle meets [param item]'s.
func _drawn_over(layer: CanvasLayer, item: Control) -> Array[String]:
	var order: Array[CanvasItem] = []
	_in_draw_order(layer, order)
	var box: Rect2 = item.get_global_rect()
	var over: Array[String] = []
	var after: bool = false
	for other: CanvasItem in order:
		if other == item:
			after = true
			continue
		if item.is_ancestor_of(other) or other.is_ancestor_of(item):
			continue
		if not other.is_visible_in_tree():
			continue
		var later: bool = _z_of(other) > _z_of(item) or (after and _z_of(other) == _z_of(item))
		var control: Control = other as Control
		var rect: Rect2 = control.get_global_rect() if control != null else box
		if later and rect.intersects(box) and rect.has_area():
			over.append(String(other.get_path()))
	return over


## True when [param top] is drawn over [param below] on their layer.
func _is_over(layer: CanvasLayer, top: CanvasItem, below: CanvasItem) -> bool:
	var order: Array[CanvasItem] = []
	_in_draw_order(layer, order)
	if _z_of(top) != _z_of(below):
		return _z_of(top) > _z_of(below)
	return order.find(top) > order.find(below)


func _in_draw_order(node: Node, order: Array[CanvasItem]) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem:
			order.append(child as CanvasItem)
		_in_draw_order(child, order)


func _z_of(item: CanvasItem) -> int:
	var z: int = 0
	var at: Node = item
	while at is CanvasItem:
		var canvas_item: CanvasItem = at as CanvasItem
		z += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		at = at.get_parent()
	return z


## A control over the whole world that records every press reaching it, in world pixels.
func _probe(main: Main, heard: Array[Vector2]) -> Control:
	var probe := Control.new()
	probe.size = HudFrame.SCREEN
	probe.mouse_filter = Control.MOUSE_FILTER_STOP
	probe.gui_input.connect(
		func(event: InputEvent) -> void:
			var button_press: InputEventMouseButton = event as InputEventMouseButton
			if button_press != null and button_press.pressed:
				heard.append(button_press.position)
	)
	main.hud.add_child(probe)
	return probe


## Rests the real mouse on [param at] (UI pixels) and runs the HUD on by [param seconds].
func _rest_at(main: Main, at: Vector2, seconds: float) -> void:
	mouse_move(NOWHERE_WORLD)
	main.hud.advance(STEP)
	mouse_move(main.ui.ui_to_world(at))
	main.hud.advance(seconds)


## The stage list's label drawing the guardian named [param guardian], or null when none shows it.
func _guardian_label(list: StageList, guardian: String) -> Label:
	for node: Node in list.find_children("Guardian*", "Label", true, false):
		var label: Label = node as Label
		if label.is_visible_in_tree() and label.text == guardian:
			return label
	return null


## The font [param label] draws in.
func _font_of(label: Label) -> Font:
	return label.get_theme_font(&"font")


## The rectangle of every label of [param piece] that shows text, in UI pixels, must lie inside the
## piece: nothing cut.
func _assert_not_cut(piece: Control, what: String) -> void:
	for label: Label in _shown_labels(piece):
		assert_true(
			piece.get_global_rect().grow(0.5).encloses(_ink(label)),
			"%s: '%s' not cut" % [what, label.text]
		)

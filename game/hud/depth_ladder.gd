class_name DepthLadder
extends Control
## The depth ladder (spec 033): the whole descent as one picture, a column of [constant RUNGS]
## rungs down the right edge of the screen, one per depth, shallow at the top, with the party's
## depth always among them.
##
## A rung shows its depth and, drawn in code, what it is: the party's depth (a bright marker that
## bobs), the safe depth (green), held (solid: at or above the safe depth), visited (outlined:
## reached since), never reached (dim), the target (a yellow arrow) and a guardian's depth (a small
## skull, crossed out while its guardian is beaten). Every mark is read from the simulation each
## frame ([method marks]), so nothing can drift. Clicking a rung asks the simulation for that
## target depth ([method click_depth]); resting the mouse on one shows a line in words beside the
## ladder ([member hint]). [kbd]L[/kbd] hides and shows it, and it hides while the shop is open,
## which drops into the same place. It moves only in [method advance], so a test can step it.

## A click asked for a new target (the HUD mirrors it on its own target number at once).
signal target_asked(depth: int)

## Rungs on show at a time.
const RUNGS: int = 12
## Pixels from one rung to the next.
const PITCH: float = 20.0
## The panel's width.
const WIDTH: float = 52.0
## The caption's row at the top of the panel, and where the rungs start below it.
const CAPTION_HEIGHT: float = 13.0
const RUNGS_TOP: float = 15.0
const PADDING: float = 3.0
## Rungs shown above the party's: the rest are below, where it is heading.
const ABOVE: int = 4
## How fast the ladder scrolls to a new depth: the share of the way left covered per second,
## as a rate (higher is faster).
const SCROLL_RATE: float = 8.0
## Seconds of one bob of the party's marker (half up, half down).
const BOB_SECONDS: float = 0.8
## Columns inside a rung's row, in pixels from the row's left edge: the arrow, the right edge
## of the number, the rails either side of the rung and the skull.
const ARROW_X: float = 4.0
const NUMBER_RIGHT: float = 27.0
const RAIL_LEFT: float = 30.0
const RAIL_RIGHT: float = 42.0
const SKULL_X: float = 45.0
## The rung's bar height, and the party marker's half size.
const BAR_HEIGHT: float = 3.0
## What [method hover_text] adds to a rung that can be clicked.
const CLICK_HINT: String = "Click to send the party here"
## A skull in 5x5 pixels, drawn in code: [code]#[/code] is bone.
const SKULL: Array[String] = [".###.", "#####", "#.#.#", "#####", ".#.#."]

## The line beside the ladder while the mouse rests on a rung (R4).
var hint: HudPanel

var _simulation: Simulation
## The world the HUD shows; kept for symmetry with the other HUD parts, read by nothing yet.
var _world: World
var _caption: Label
var _hint_text: Label
var _hint_click: Label
## The drawn rungs, clipped to the panel so a part row shows while scrolling.
var _rungs: Control
var _numbers: Array[Label] = []
## Whether the player wants the ladder (L); the shop can still hide it.
var _wanted: bool = true
## The top of the ladder as drawn: a depth, fractional while it scrolls.
var _scroll: float = 1.0
## The party's depth, fractional while it climbs.
var _party_at: float = 1.0
var _time: float = 0.0
## The depth under the mouse, or 0.
var _hovered: int = 0
## A target asked for that the simulation has not applied yet (it applies on the next tick), or 0.
var _asked_target: int = 0


func _init() -> void:
	name = "DepthLadder"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = Vector2(WIDTH, RUNGS_TOP + RUNGS * PITCH + PADDING)
	position = Vector2(Hud.SCREEN.x - Hud.MARGIN - WIDTH, Hud.TOP_BAND + ShopPanel.DROP)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_L:
		return
	_wanted = not _wanted
	advance(0.0)
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_shown():
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_hovered = depth_at(motion.position)
		_show_hint()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var depth: int = depth_at(button.position)
		if depth > 0:
			click_depth(depth)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hint != null:
		_hovered = 0
		_show_hint()


func _draw() -> void:
	HudPanel.draw_panel(
		self,
		Rect2(Vector2.ZERO, size),
		Palette.color(&"night"),
		Palette.color(&"dusk"),
		Palette.color(&"ink")
	)
	draw_rect(Rect2(PADDING, CAPTION_HEIGHT, WIDTH - PADDING * 2.0, 1.0), Palette.color(&"dusk"))


## Call once, before the first advance. [param world] may be null.
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	_caption = PixelText.label("Depths", &"steel")
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.position = Vector2(PADDING + 2.0, 3.0)
	add_child(_caption)
	_rungs = Control.new()
	_rungs.name = "Rungs"
	_rungs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rungs.clip_contents = true
	_rungs.position = Vector2(0.0, RUNGS_TOP)
	_rungs.size = Vector2(WIDTH, RUNGS * PITCH)
	_rungs.draw.connect(_draw_rungs)
	add_child(_rungs)
	for i: int in RUNGS + 1:
		var number: Label = PixelText.label("", &"silver")
		number.name = "Number%d" % i
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rungs.add_child(number)
		_numbers.append(number)
	_build_hint()
	_party_at = _party_depth()
	_scroll = _top_for(_party_at)
	advance(0.0)


## Follows the simulation and moves the scroll and the marker on by [param delta] seconds.
## Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	visible = _wanted and not _shop_is_open()
	if not visible:
		_hovered = 0
	var e: Expedition = _simulation.expedition
	if _asked_target > 0 and e.target_depth == _asked_target:
		_asked_target = 0
	_time = fmod(_time + delta, BOB_SECONDS)
	_party_at = _party_depth()
	var goal: float = _top_for(_party_at)
	if absf(goal - _scroll) > RUNGS:
		_scroll = goal
	else:
		_scroll = lerpf(_scroll, goal, 1.0 - exp(-SCROLL_RATE * delta))
		if absf(goal - _scroll) < 0.01:
			_scroll = goal
	_place_numbers()
	_show_hint()
	_rungs.queue_redraw()


## True while the ladder is on screen.
func is_shown() -> bool:
	return visible


## The depth of the top rung: the party's depth stays among the [constant RUNGS] below it.
func first_depth() -> int:
	if _simulation == null:
		return 1
	return maxi(_simulation.expedition.depth - ABOVE, 1)


## What the rung at [param depth] shows, for tests: any of &"party", &"safe", &"held",
## &"visited", &"unreached", &"target", &"guardian", &"guardian_beaten". Exactly one of held,
## visited and unreached; a beaten guardian's depth has both guardian marks.
func marks(depth: int) -> Array[StringName]:
	var found: Array[StringName] = []
	if _simulation == null or depth < 1:
		return found
	var e: Expedition = _simulation.expedition
	if depth == e.depth:
		found.append(&"party")
	if depth == e.last_stable_depth:
		found.append(&"safe")
	if depth <= e.last_stable_depth:
		found.append(&"held")
	elif depth <= maxi(e.deepest_depth, e.depth):
		found.append(&"visited")
	else:
		found.append(&"unreached")
	if depth == shown_target():
		found.append(&"target")
	if e.guardian_of(depth) != &"":
		found.append(&"guardian")
		if _guardian_beaten(depth):
			found.append(&"guardian_beaten")
	return found


## The line shown while the mouse rests on the rung at [param depth]: [code]Depth 7:
## visited[/code], [code]Depth 5: Slime King (beaten)[/code] and so on, followed by
## [constant CLICK_HINT] when a click would send the party there.
func hover_text(depth: int) -> String:
	var parts: PackedStringArray = _hover_parts(depth)
	return parts[0] if parts[1].is_empty() else "%s. %s" % [parts[0], parts[1]]


## What a click on the rung at [param depth] does: asks the simulation for that target depth,
## as the HUD's - and + buttons do. Nothing while hidden or for a depth the simulation does not
## take as a target.
func click_depth(depth: int) -> void:
	if _simulation == null or not is_shown() or not _can_target(depth):
		return
	_asked_target = depth
	_simulation.set_target_depth(depth)
	target_asked.emit(depth)
	_rungs.queue_redraw()


## The target depth as shown: the one asked for until the simulation applies it, then its own.
func shown_target() -> int:
	return _asked_target if _asked_target > 0 else _simulation.expedition.target_depth


## The rectangle of the rung at [param depth] as drawn now, in the ladder's own coordinates.
## It may lie outside the panel for a depth not on show.
func rung_rect(depth: int) -> Rect2:
	return Rect2(0.0, RUNGS_TOP + (depth - _scroll) * PITCH, WIDTH, PITCH)


## The depth of the rung at [param at] (the ladder's own coordinates), or 0 for none.
func depth_at(at: Vector2) -> int:
	if at.x < 0.0 or at.x >= WIDTH or at.y < RUNGS_TOP or at.y >= RUNGS_TOP + RUNGS * PITCH:
		return 0
	var depth: int = floori(_scroll + (at.y - RUNGS_TOP) / PITCH)
	return depth if depth >= 1 else 0


## The text of the line beside the ladder, as [method hover_text] gives it; "" when none shows.
func hint_text() -> String:
	if not hint.visible:
		return ""
	if not _hint_click.visible:
		return _hint_text.text
	return "%s %s" % [_hint_text.text, _hint_click.text]


# --- Reading -------------------------------------------------------------------


## True for a depth the simulation takes as a target: [method Simulation.set_target_depth] takes
## any depth from 1 down.
func _can_target(depth: int) -> bool:
	return depth >= 1


## True while the guardian of [param depth] is beaten: its chamber holds nobody and no fight with
## it is going on there.
func _guardian_beaten(depth: int) -> bool:
	var e: Expedition = _simulation.expedition
	var shaft: LabyrinthChamber = _simulation.labyrinth.level(depth).shaft_chamber()
	if shaft == null:
		return false
	if e.battle != null and e.depth == depth and e.chamber() == shaft:
		return false
	return not e.is_populated(depth, shaft.index)


## The line's two parts: what the rung is, and the click hint (or "").
func _hover_parts(depth: int) -> PackedStringArray:
	var shown: Array[StringName] = marks(depth)
	var what: String = "not reached yet"
	if shown.has(&"held"):
		what = "held"
	elif shown.has(&"visited"):
		what = "visited"
	if shown.has(&"safe"):
		what = "safe, the party falls back here"
	if shown.has(&"party"):
		what = "the party is here"
	if shown.has(&"guardian"):
		var def: MonsterDef = Content.monster(_simulation.expedition.guardian_of(depth))
		what = def.display_name if def != null else "a guardian"
		if shown.has(&"guardian_beaten"):
			what += " (beaten)"
		if shown.has(&"party"):
			what += ", the party is here"
	if shown.has(&"target") and not shown.has(&"party"):
		what += ", the party is heading here"
	var click: String = ""
	if _can_target(depth) and not shown.has(&"target"):
		click = CLICK_HINT
	return PackedStringArray(["Depth %d: %s" % [depth, what], click])


## The party's depth, fractional while it climbs: its leader's height between two floors.
func _party_depth() -> float:
	var e: Expedition = _simulation.expedition
	if _simulation.party.heroes.is_empty():
		return float(e.depth)
	var leader_y: float = e.hero_position(_simulation.party.heroes[0].id).y
	var between: float = (
		(leader_y - _simulation.labyrinth.level(e.depth).floor_y) / Labyrinth.LEVEL_HEIGHT
	)
	return e.depth + clampf(between, -1.0, 1.0)


## The top of the ladder that keeps [param party_at] [constant ABOVE] rungs down.
func _top_for(party_at: float) -> float:
	return maxf(party_at - ABOVE, 1.0)


func _shop_is_open() -> bool:
	var hud: Hud = get_parent() as Hud
	return hud != null and hud.shop != null and hud.shop.is_open()


# --- Drawing -------------------------------------------------------------------


func _build_hint() -> void:
	hint = HudPanel.new()
	hint.name = "Hint"
	hint.visible = false
	add_child(hint)
	_hint_text = PixelText.label("", &"white")
	_hint_text.name = "Text"
	_hint_text.position = Vector2(5, 2)
	hint.add_child(_hint_text)
	_hint_click = PixelText.label(CLICK_HINT, &"yellow")
	_hint_click.name = "Click"
	hint.add_child(_hint_click)


## Shows the line for the rung under the mouse, to the left of the ladder and level with it.
func _show_hint() -> void:
	if hint == null:
		return
	var showing: bool = _hovered > 0 and is_shown()
	hint.visible = showing
	if not showing:
		return
	var parts: PackedStringArray = _hover_parts(_hovered)
	var clickable: bool = not parts[1].is_empty()
	var text: String = parts[0] + ("." if clickable else "")
	if _hint_text.text != text:
		_hint_text.text = text
		_hint_text.reset_size()
	_hint_click.visible = clickable
	var width: float = 5.0 + PixelText.width(text) + 5.0
	if clickable:
		_hint_click.position = Vector2(width - 1.0, 2.0)
		width += PixelText.width(CLICK_HINT) + 4.0
	hint.size = Vector2(width, 13.0)
	var row: Rect2 = rung_rect(_hovered)
	var y: float = clampf(row.get_center().y - 6.0, RUNGS_TOP, size.y - 13.0 - PADDING)
	hint.position = Vector2(-width - 2.0, floorf(y))


## Each number's text, colour and place, for the rungs on show now.
func _place_numbers() -> void:
	var top: int = floori(_scroll)
	for i: int in _numbers.size():
		var depth: int = top + i
		var number: Label = _numbers[i]
		var text: String = str(depth)
		if number.text != text:
			number.text = text
			number.reset_size()
		number.add_theme_color_override(&"font_color", Palette.color(_number_colour(depth)))
		var row: Rect2 = rung_rect(depth)
		number.position = Vector2(
			NUMBER_RIGHT - PixelText.width(text), floorf(row.position.y - RUNGS_TOP + 6.0)
		)


func _number_colour(depth: int) -> StringName:
	var shown: Array[StringName] = marks(depth)
	if shown.has(&"party"):
		return &"white"
	if shown.has(&"target"):
		return &"yellow"
	if shown.has(&"safe"):
		return &"green"
	if shown.has(&"held"):
		return &"silver"
	if shown.has(&"visited"):
		return &"steel"
	return &"slate"


## Draws the rails and every rung on show, then the party's marker and the target's arrow.
func _draw_rungs() -> void:
	var canvas: Control = _rungs
	var rail: Color = Palette.color(&"slate")
	var span: float = RUNGS * PITCH
	canvas.draw_rect(Rect2(RAIL_LEFT, 0.0, 1.0, span), rail)
	canvas.draw_rect(Rect2(RAIL_RIGHT, 0.0, 1.0, span), rail)
	var top: int = floori(_scroll)
	for depth: int in range(top, top + RUNGS + 1):
		var row: float = floorf(rung_rect(depth).position.y - RUNGS_TOP)
		_draw_rung(canvas, depth, row)
	var party_y: float = floorf((_party_at - _scroll) * PITCH + PITCH / 2.0)
	var bob: float = 1.0 if _time < BOB_SECONDS / 2.0 else 0.0
	_draw_marker(canvas, Vector2((RAIL_LEFT + RAIL_RIGHT + 1.0) / 2.0, party_y - bob))


func _draw_rung(canvas: Control, depth: int, row: float) -> void:
	var shown: Array[StringName] = marks(depth)
	var middle: float = row + floorf(PITCH / 2.0)
	if depth == _hovered:
		_outline(canvas, Rect2(1.0, row + 1.0, WIDTH - 2.0, PITCH - 2.0), Palette.color(&"slate"))
	var bar := Rect2(RAIL_LEFT, middle - 1.0, RAIL_RIGHT - RAIL_LEFT + 1.0, BAR_HEIGHT)
	if shown.has(&"safe"):
		canvas.draw_rect(bar, Palette.color(&"green"))
		canvas.draw_rect(
			Rect2(bar.position.x, bar.end.y - 1.0, bar.size.x, 1.0), Palette.color(&"forest")
		)
	elif shown.has(&"held"):
		canvas.draw_rect(bar, Palette.color(&"silver"))
		canvas.draw_rect(
			Rect2(bar.position.x, bar.end.y - 1.0, bar.size.x, 1.0), Palette.color(&"steel")
		)
	elif shown.has(&"visited"):
		_outline(canvas, bar, Palette.color(&"steel"))
	else:
		canvas.draw_rect(Rect2(bar.position.x, middle, bar.size.x, 1.0), Palette.color(&"dusk"))
	if shown.has(&"guardian"):
		_draw_skull(canvas, Vector2(SKULL_X, middle - 2.0), shown.has(&"guardian_beaten"))
	if shown.has(&"target"):
		_draw_arrow(canvas, Vector2(ARROW_X, middle))


func _outline(canvas: Control, rect: Rect2, colour: Color) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), colour)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), colour)
	canvas.draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), colour)
	canvas.draw_rect(Rect2(rect.end.x - 1.0, rect.position.y, 1.0, rect.size.y), colour)


## The party's marker: a white diamond with an ink edge, centred on [param at].
func _draw_marker(canvas: Control, at: Vector2) -> void:
	for dy: int in range(-4, 5):
		var half: int = 4 - absi(dy)
		canvas.draw_rect(
			Rect2(at.x - half - 1.0, at.y + dy, half * 2.0 + 3.0, 1.0), Palette.color(&"ink")
		)
	for dy: int in range(-3, 4):
		var half: int = 3 - absi(dy)
		canvas.draw_rect(
			Rect2(at.x - half, at.y + dy, half * 2.0 + 1.0, 1.0), Palette.color(&"white")
		)
	canvas.draw_rect(Rect2(at.x - 1.0, at.y - 2.0, 1.0, 1.0), Palette.color(&"cyan"))


## The target's arrow: a yellow triangle pointing right, its tip toward the rung.
func _draw_arrow(canvas: Control, at: Vector2) -> void:
	for column: int in 4:
		var half: int = 3 - column
		canvas.draw_rect(
			Rect2(at.x + column, at.y - half, 1.0, half * 2.0 + 1.0), Palette.color(&"yellow")
		)


## A guardian's skull at [param at] (its top-left), dim and crossed out in red when beaten.
func _draw_skull(canvas: Control, at: Vector2, beaten: bool) -> void:
	var bone: Color = Palette.color(&"slate") if beaten else Palette.color(&"white")
	for y: int in SKULL.size():
		for x: int in SKULL[y].length():
			if SKULL[y][x] == "#":
				canvas.draw_rect(Rect2(at.x + x, at.y + y, 1.0, 1.0), bone)
	if not beaten:
		return
	for i: int in 7:
		canvas.draw_rect(Rect2(at.x - 1.0 + i, at.y - 1.0 + i, 1.0, 1.0), Palette.color(&"red"))
		canvas.draw_rect(Rect2(at.x + 5.0 - i, at.y - 1.0 + i, 1.0, 1.0), Palette.color(&"red"))

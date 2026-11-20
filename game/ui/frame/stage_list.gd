class_name StageList
extends Panel
## The stage list on the sharp layer: the stages of this area as a column of [constant RUNGS] rows
## at the right edge, headed by the area's name, shallow at the top, with the party's stage always
## among them. What each stage is comes from [DepthLadder]; this draws it and hears the mouse.
##
## A row shows its number, coloured by how the stage looks for this party ([method risk]), and,
## drawn in code, what it is: the party's stage (a bright diamond that bobs, its number framed in
## white), the safe stage (a green bar), held (solid), visited (outlined), never reached (dim), the
## target (its number framed in yellow, with a yellow arrow) and a guardian's stage (a skull and the
## guardian's name beside it, struck through while it is beaten). A click on a row asks for that
## target ([method click_depth]); resting the mouse on one shows a line in words beside the list
## ([member hint]). The wheel scrolls it ([method scroll_by]); while scrolled away an arrow points
## toward the party, and a click on it, or [constant RETURN_SECONDS] without the mouse over the
## list, brings it back to following the party. [kbd]L[/kbd] hides and shows it; windows are drawn
## over it. A goal's click shows it and flashes a row ([method flash]).
## It moves only in [method advance], so a test can step it.

## A click asked for a new target (the HUD mirrors it on its own target number at once).
signal target_asked(depth: int)

## Rows on show at a time.
const RUNGS: int = 12
## UI pixels from one row to the next.
const PITCH: float = 24.0
## The panel's width: room for the longest guardian's name beside its stage.
const WIDTH: float = 150.0
## The caption's row at the top of the panel, and where the rows start below it.
const CAPTION_HEIGHT: float = 18.0
const RUNGS_TOP: float = 20.0
const PADDING: float = 4.0
## Rows shown above the party's: the rest are below, where it is heading.
const ABOVE: int = 4
## How fast the list scrolls to a new stage: the share of the way left covered per second, as a
## rate (higher is faster).
const SCROLL_RATE: float = 8.0
## Seconds of one bob of the party's diamond (half up, half down).
const BOB_SECONDS: float = 0.8
## Columns inside a row, in UI pixels from the row's left edge: the target's arrow, the right edge
## of the number, the rails either side of the row's bar, the skull and the guardian's name.
const ARROW_X: float = 5.0
const NUMBER_RIGHT: float = 38.0
const RAIL_LEFT: float = 44.0
const RAIL_RIGHT: float = 58.0
const SKULL_X: float = 62.0
const NAME_X: float = 70.0
## The row's bar height.
const BAR_HEIGHT: float = 4.0
## Seconds a row flashes after [method flash], and one blink of it (half lit, half not).
const FLASH_SECONDS: float = 1.0
const BLINK_SECONDS: float = 0.25
## A skull in 5x5 pixels, drawn in code: [code]#[/code] is bone.
const SKULL: Array[String] = [".###.", "#####", "#.#.#", "#####", ".#.#."]
## Rows the list can scroll below the furthest stage ever reached.
const BELOW_DEEPEST: int = 6
## Seconds without the mouse over the list before a scrolled list follows the party again.
const RETURN_SECONDS: float = 5.0
## The arrow toward the party while scrolled away: its box's size, centred on the rails.
const ARROW_SIZE: Vector2 = Vector2(17, 10)
## The frame round the number of the target's row and of the party's, in palette
## colours that are none of [constant DepthLadder.RISK_COLOURS].
const MARK_COLOURS: Dictionary[StringName, StringName] = {&"target": &"yellow", &"party": &"white"}
## Each frame's box inside its row (x from the row's left, y from its top): the target's round the
## number column, its left edge where the target's arrow points, and the party's one pixel inside
## it, so a party on its target shows both.
const MARK_BOXES: Dictionary[StringName, Rect2] = {
	&"target": Rect2(12, 2, 30, 20),
	&"party": Rect2(13, 3, 28, 18),
}
## Seconds the mouse rests on a row before its line shows, as for every tooltip.
const DELAY: float = UiTip.DELAY

## The line beside the list while the mouse rests on a row.
var hint: PanelContainer
## What the last drawing put where, by kind, in this control's own pixels (for tests).
var drawn: Dictionary[StringName, Array] = {}
## The stage whose row is outlined as under the mouse, or 0. The list sets it; others read it.
var hovered: int = 0
## What each stage is.
var ladder: DepthLadder

var _simulation: Simulation
var _caption: Label
var _hint_text: Label
var _hint_risk: Label
## The drawn rows, clipped to the panel so a part row shows while scrolling.
var _rungs: Control
var _numbers: Array[Label] = []
var _names: Array[Label] = []
## Whether the player wants the list (L); the shop can still hide it.
var _wanted: bool = true
## The top of the list as drawn: a stage, fractional while it scrolls.
var _scroll: float = 1.0
## The party's stage, as the world shows it.
var _party_at: float = 1.0
var _time: float = 0.0
## Seconds the mouse has rested on that row.
var _rested: float = 0.0
## The stage whose row flashes, and seconds of its flash left.
var _flash_depth: int = 0
var _flash: float = 0.0
## True while the list keeps the party's row in view; false while scrolled away.
var _following: bool = true
## The top row while scrolled away.
var _view_top: int = 1
## True while the mouse is over the list, from its enter and exit notifications only, and seconds
## since it last was.
var _mouse_in: bool = false
var _away: float = 0.0
## Where the last mouse event over the list put the mouse (the list's own coordinates), and
## whether it is still there: the row under it is read again whenever the rows move.
var _pointer: Vector2 = Vector2.ZERO
var _has_pointer: bool = false
## Drawn over the rows and unclipped: the arrow back to the party.
var _arrow_layer: Control
## Drawn over that, clipped to the rows: the strike through a beaten guardian's name and the
## party's diamond, so nothing covers them.
var _marker_layer: Control


func _init() -> void:
	name = "StageList"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = Vector2(WIDTH, RUNGS_TOP + RUNGS * PITCH + PADDING)


func _unhandled_input(event: InputEvent) -> void:
	if not KeyBook.pressed(event, KEY_L):
		return
	_wanted = not _wanted
	advance(0.0)
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_shown():
		return
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	# An event here says where the mouse is, not that it is over the list (a press
	# dragged off it keeps sending them); only the enter and exit notifications say that.
	_pointer = mouse.position
	_has_pointer = true
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if arrow_rect().has_point(button.position):
					follow()
				else:
					var depth: int = depth_at(button.position)
					if depth > 0:
						click_depth(depth)
			MOUSE_BUTTON_WHEEL_UP:
				scroll_by(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				scroll_by(1)
			_:
				return
		accept_event()
	elif button != null:
		accept_event()  # a release here goes no further either
	_hover(mouse.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_in = true
		_away = 0.0
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse_in = false
		_has_pointer = false
		if hint != null:
			hovered = 0
			_show_hint()


func _draw() -> void:
	draw_rect(Rect2(PADDING, CAPTION_HEIGHT, WIDTH - PADDING * 2.0, 1.0), Palette.color(&"dusk"))


## Call once, before the first advance: the list shows [param simulation]'s stages; [param journal]
## hears a dangerous target (may be null).
func setup(simulation: Simulation, journal: Journal) -> void:
	_simulation = simulation
	ladder = DepthLadder.new(simulation, journal)
	_caption = UiText.label(PlaceText.area_name(simulation.expedition.place), &"steel", true)
	_caption.name = "Caption"
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
		var number: Label = UiText.label("", &"silver", true)
		number.name = "Number%d" % i
		_rungs.add_child(number)
		_numbers.append(number)
		var guardian: Label = UiText.label("", &"white")
		guardian.name = "Guardian%d" % i
		_rungs.add_child(guardian)
		_names.append(guardian)
	_arrow_layer = Control.new()
	_arrow_layer.name = "ArrowLayer"
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_layer.size = size
	_arrow_layer.draw.connect(_draw_arrow_layer)
	add_child(_arrow_layer)
	_marker_layer = Control.new()
	_marker_layer.name = "MarkerLayer"
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_layer.clip_contents = true
	_marker_layer.position = _rungs.position
	_marker_layer.size = _rungs.size
	_marker_layer.draw.connect(_draw_marker_layer)
	add_child(_marker_layer)
	_build_hint()
	_party_at = _party_depth()
	_scroll = _top_for(_party_at)
	advance(0.0)


## Follows the simulation and moves the scroll and the diamond on by [param delta] seconds.
## Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	visible = _wanted  # windows, the shop's too, are drawn over it
	if not visible:
		hovered = 0
	ladder.advance()
	var e: Expedition = _simulation.expedition
	# The heading names the area whose stages the rows are.
	var heading: String = PlaceText.area_name(e.place)
	if _caption.text != heading:
		_caption.text = heading
		_caption.reset_size()
	_time = fmod(_time + delta, BOB_SECONDS)
	_flash = maxf(_flash - delta, 0.0)
	_rested += delta
	_party_at = _party_depth()
	if not _following and not _mouse_in:
		_away += delta
		if _away >= RETURN_SECONDS:
			follow()
	# A scrolled list stays where it was put, even when the party's own view comes to
	# the same rows; only the arrow's click and the timer above bring it back.
	if not _following:
		_view_top = clampi(_view_top, 1, _max_top())
	var goal: float = _top_for(_party_at) if _following else float(_view_top)
	if absf(goal - _scroll) > RUNGS:
		_scroll = goal
	else:
		_scroll = lerpf(_scroll, goal, 1.0 - exp(-SCROLL_RATE * delta))
		if absf(goal - _scroll) < 0.01:
			_scroll = goal
	# The rows may have moved under a still mouse; the outline and the line go to the
	# row under it now, on the frame the rows are drawn there.
	if _has_pointer and visible:
		hovered = _under(_pointer)
	_place_labels()
	_show_hint()
	_rungs.queue_redraw()
	_arrow_layer.queue_redraw()
	_marker_layer.queue_redraw()


## True while the list is on screen.
func is_shown() -> bool:
	return visible


## The stage of the top row: the party's stage stays among the [constant RUNGS] below it. While
## scrolled away, the top row the player scrolled to.
func first_depth() -> int:
	if _simulation == null:
		return 1
	if not _following:
		return _view_top
	return maxi(roundi(_party_depth()) - ABOVE, 1)  # the shown stage's


## How the stage at [param level_depth] looks for this party: see [method DepthLadder.risk].
func risk(level_depth: int) -> DepthLadder.Risk:
	return ladder.risk(level_depth) if ladder != null else DepthLadder.Risk.SAFE


## What the row at [param depth] shows: see [method DepthLadder.marks].
func marks(depth: int) -> Array[StringName]:
	return ladder.marks(depth) if ladder != null else [] as Array[StringName]


## The row's line in words: see [method DepthLadder.hover_text].
func hover_text(depth: int) -> String:
	return ladder.hover_text(depth)


## The target as shown: the one asked for until the simulation applies it, then its own.
func shown_target() -> int:
	return ladder.shown_target()


## Scrolls the list by [param rungs] (positive is deeper), from stage 1 at the top down to
## [constant BELOW_DEEPEST] rows below the furthest stage ever reached, and stops it following the
## party. While following, the first row is the next whole one from the list as drawn, so a notch
## moves it at most one row even while the party is between stages. Scrolling back
## onto exactly the party's own view follows it again.
func scroll_by(rungs: int) -> void:
	if _simulation == null or rungs == 0:
		return
	var from: int = _view_top
	if _following:
		from = floori(_scroll + 0.01) if rungs > 0 else ceili(_scroll - 0.01)
	_view_top = clampi(from + rungs, 1, _max_top())
	_following = absf(_view_top - _top_for(_party_at)) < 0.01
	_away = 0.0
	advance(0.0)


## Where [param mark] is drawn on the row at [param depth] now, in the list's own coordinates, or
## an empty rectangle when that row does not carry it: &"target" and &"party" are the frames round
## its number ([constant MARK_BOXES]), &"diamond" the box the party's diamond is drawn in at either
## height of its bob (on the party's row), &"name" the guardian's name.
func mark_rect(depth: int, mark: StringName) -> Rect2:
	if _simulation == null:
		return Rect2()
	var shown: Array[StringName] = marks(depth)
	if mark == &"name":
		return _name_rect(depth) if shown.has(&"guardian") else Rect2()
	if not shown.has(&"party" if mark == &"diamond" else mark):
		return Rect2()
	if mark == &"diamond":
		var at: Vector2 = _marker_at()
		return Rect2(at.x - 6.0, RUNGS_TOP + at.y - 6.0, 13.0, 12.0)
	if not MARK_BOXES.has(mark):
		return Rect2()
	var box: Rect2 = MARK_BOXES[mark]
	var top: float = floorf(rung_rect(depth).position.y)
	return Rect2(box.position + Vector2(0.0, top), box.size)


## Where the guardian's name on the row at [param depth] is drawn, in the list's coordinates.
func _name_rect(depth: int) -> Rect2:
	var row: float = floorf(rung_rect(depth).position.y)
	var width: float = UiText.width(ladder.guardian_name(depth)) - UiText.SPACING
	return Rect2(NAME_X, row + _text_y(), width, UiText.LINE_HEIGHT)


## True while the list keeps the party's row in view, false while scrolled away.
func is_following() -> bool:
	return _following


## Brings the list back to following the party (the arrow's click).
func follow() -> void:
	_following = true
	_away = 0.0


## The arrow toward the party's row while scrolled away, in the list's own coordinates: at the
## right of the caption's row when the party is above the rows, on the panel's bottom edge when
## below, so it never covers the party's diamond in the top or bottom row. Empty
## while following.
func arrow_rect() -> Rect2:
	if _following or _simulation == null:
		return Rect2()
	var x: float = floorf((RAIL_LEFT + RAIL_RIGHT + 1.0 - ARROW_SIZE.x) / 2.0)
	var y: float = size.y - ARROW_SIZE.y
	if arrow_points_up():
		# In the caption's row, right of the area's name, clear of the rows and so of the diamond.
		x = WIDTH - PADDING - ARROW_SIZE.x
		y = floorf((CAPTION_HEIGHT - ARROW_SIZE.y) / 2.0)
	return Rect2(Vector2(x, y), ARROW_SIZE)


## True when the party's row is above the view, so the arrow points up.
func arrow_points_up() -> bool:
	return _follow_top() < _view_top


## What a click on the row at [param depth] does: asks for that target (see
## [method DepthLadder.ask]). Nothing while hidden or for a stage the simulation does not take.
func click_depth(depth: int) -> void:
	if _simulation == null or not is_shown() or not ladder.ask(depth):
		return
	target_asked.emit(depth)
	_rungs.queue_redraw()


## Shows the list if L hid it and flashes the row of [param level_depth] for
## [constant FLASH_SECONDS] (a goal's click points at its stage). A row off the list is scrolled
## onto it first, at once, so it is on show while it blinks.
func flash(level_depth: int) -> void:
	_wanted = true
	_flash_depth = level_depth
	_flash = FLASH_SECONDS
	if _simulation != null and level_depth >= 1:
		var goal: float = _top_for(_party_depth()) if _following else float(_view_top)
		if not _within(level_depth, goal):
			_view_top = clampi(level_depth - ABOVE, 1, maxi(_max_top(), level_depth - RUNGS + 1))
			_following = false
			_away = 0.0
			goal = float(_view_top)
		if not _within(level_depth, _scroll):
			_scroll = goal
	advance(0.0)


## True while the row of [param level_depth] flashes.
func is_flashing(level_depth: int) -> bool:
	return _flash > 0.0 and level_depth == _flash_depth


## The rectangle of the row at [param depth] as drawn now, in the list's own coordinates. It may
## lie outside the panel for a stage not on show.
func rung_rect(depth: int) -> Rect2:
	return Rect2(0.0, RUNGS_TOP + (depth - _scroll) * PITCH, WIDTH, PITCH)


## The stage of the row at [param at] (the list's own coordinates), or 0 for none.
func depth_at(at: Vector2) -> int:
	if at.x < 0.0 or at.x >= WIDTH or at.y < RUNGS_TOP or at.y >= RUNGS_TOP + RUNGS * PITCH:
		return 0
	var depth: int = floori(_scroll + (at.y - RUNGS_TOP) / PITCH)
	return depth if depth >= 1 else 0


## The text of the line beside the list, as [method hover_text] gives it; "" when none shows.
func hint_text() -> String:
	if not hint.visible:
		return ""
	var text: String = _hint_text.text
	if _hint_risk.visible:
		text = "%s\n%s" % [text, _hint_risk.text]
	return text


# --- Reading -------------------------------------------------------------------


## The top row that keeps the party in view, as a whole stage.
func _follow_top() -> int:
	return roundi(_top_for(_party_at))


## The deepest top row the list scrolls to: its bottom row [constant BELOW_DEEPEST] below the
## furthest stage ever reached, never above the party's own view or a flashing row.
func _max_top() -> int:
	var e: Expedition = _simulation.expedition
	var deepest: int = maxi(e.deepest_depth, e.depth)
	var most: int = maxi(deepest + BELOW_DEEPEST - RUNGS + 1, _follow_top())
	if _flash > 0.0:
		most = maxi(most, _flash_depth - RUNGS + 1)
	return maxi(most, 1)


## True when the row of [param depth] lies wholly on the list with [param top] at its top.
func _within(depth: int, top: float) -> bool:
	return depth >= top - 0.01 and depth + 1 <= top + RUNGS + 0.01


## The mouse at [param at] (the list's own coordinates): the row under it, none over the arrow. A
## move of the mouse restarts the line's rest; rows moving under a still mouse do not.
func _hover(at: Vector2) -> void:
	var under: int = _under(at)
	if under != hovered:
		hovered = under
		_rested = 0.0
	_show_hint()


## The row at [param at] (the list's own coordinates) as drawn now, or 0 over the arrow or off the
## rows.
func _under(at: Vector2) -> int:
	return 0 if arrow_rect().has_point(at) else depth_at(at)


## The party's stage: the one the world shows, so the diamond moves a whole row when the
## stage changes in the dark of a crossing.
func _party_depth() -> float:
	return float(ZoneCrossing.stage_shown(_simulation))


## The top of the list that keeps [param party_at] [constant ABOVE] rows down.
func _top_for(party_at: float) -> float:
	return maxf(party_at - ABOVE, 1.0)


## Where a line of text sits in a row, from the row's top.
func _text_y() -> float:
	return floorf((PITCH - UiText.LINE_HEIGHT) / 2.0)


# --- Drawing -------------------------------------------------------------------


func _build_hint() -> void:
	hint = PanelContainer.new()
	hint.name = "Hint"
	hint.theme_type_variation = UiTheme.TIP
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	hint.z_index = 1  # over the pieces beside the list
	add_child(hint)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override(&"separation", 1)
	hint.add_child(lines)
	_hint_text = UiText.label("", &"white")
	_hint_text.name = "Text"
	lines.add_child(_hint_text)
	_hint_risk = UiText.label("", &"white")
	_hint_risk.name = "Risk"
	lines.add_child(_hint_risk)


## Shows the line for the row under the mouse, to the left of the list and level with it.
func _show_hint() -> void:
	if hint == null:
		return
	var showing: bool = hovered > 0 and is_shown() and _rested >= DELAY
	hint.visible = showing
	if not showing:
		return
	var parts: PackedStringArray = ladder.hover_parts(hovered)
	var text: String = parts[0] if parts[1].is_empty() else "%s. %s" % [parts[0], parts[1]]
	if _hint_text.text != text:
		_hint_text.text = text
	_hint_risk.visible = not parts[2].is_empty()
	if _hint_risk.visible:
		_hint_risk.text = parts[2]
		var colour: StringName = DepthLadder.RISK_COLOURS[risk(hovered)]
		_hint_risk.add_theme_color_override(&"font_color", Palette.color(colour))
	var panel: StyleBox = hint.get_theme_stylebox(&"panel")
	var inner_width: float = GoalRow.ink(text)
	var lines: int = 1
	if _hint_risk.visible:
		inner_width = maxf(inner_width, GoalRow.ink(parts[2]))
		lines = 2
	var inner := Vector2(inner_width + 1.0, lines * UiText.LINE_HEIGHT + (lines - 1))
	hint.reset_size()
	hint.size = (inner + panel.get_minimum_size()).ceil()
	var row: Rect2 = rung_rect(hovered)
	var y: float = clampf(
		row.get_center().y - hint.size.y / 2.0, RUNGS_TOP, size.y - hint.size.y - PADDING
	)
	hint.position = Vector2(-hint.size.x - 4.0, floorf(y))


## Each number's and guardian's name's text, colour and place, for the rows on show now.
func _place_labels() -> void:
	var top: int = floori(_scroll)
	for i: int in _numbers.size():
		var depth: int = top + i
		var number: Label = _numbers[i]
		var text: String = str(depth)
		if number.text != text:
			number.text = text
			number.reset_size()
		var colour: StringName = DepthLadder.RISK_COLOURS[risk(depth)]
		number.add_theme_color_override(&"font_color", Palette.color(colour))
		var row: float = floorf(rung_rect(depth).position.y - RUNGS_TOP)
		var ink: float = UiText.width(text, true) - UiText.SPACING
		number.position = Vector2(NUMBER_RIGHT - ink, row + _text_y())
		# The row below the last is drawn only while it scrolls into view.
		var on_show: bool = row < RUNGS * PITCH
		number.visible = on_show
		var guardian: Label = _names[i]
		var named: String = ladder.guardian_name(depth)
		guardian.visible = on_show and not named.is_empty()
		if guardian.text != named:
			guardian.text = named
			guardian.reset_size()
		var beaten: bool = guardian.visible and ladder.guardian_beaten(depth)
		guardian.add_theme_color_override(
			&"font_color", Palette.color(&"steel" if beaten else &"white")
		)
		guardian.position = Vector2(NAME_X, row + _text_y())


## Draws the rails and every row on show; the arrow, the strikes and the diamond are on layers
## over it.
func _draw_rungs() -> void:
	var canvas: Control = _rungs
	for kind: StringName in [&"arrow", &"target_frame", &"party_frame"]:
		drawn[kind] = []
	var rail: Color = Palette.color(&"slate")
	var span: float = RUNGS * PITCH
	canvas.draw_rect(Rect2(RAIL_LEFT, 0.0, 1.0, span), rail)
	canvas.draw_rect(Rect2(RAIL_RIGHT, 0.0, 1.0, span), rail)
	var top: int = floori(_scroll)
	for depth: int in range(top, top + RUNGS + 1):
		var row: float = floorf(rung_rect(depth).position.y - RUNGS_TOP)
		_draw_rung(canvas, depth, row)


## The arrow back to the party, over the rows and outside them.
func _draw_arrow_layer() -> void:
	var arrow: Rect2 = arrow_rect()
	if arrow.has_area():
		_draw_party_arrow(_arrow_layer, arrow)


## A strike through each beaten guardian's name, then the party's diamond, over everything else on
## the rows.
func _draw_marker_layer() -> void:
	drawn[&"strike"] = []
	var top: int = floori(_scroll)
	for depth: int in range(top, top + RUNGS + 1):
		var shown: Array[StringName] = marks(depth)
		if shown.has(&"guardian_beaten"):
			var name_box: Rect2 = mark_rect(depth, &"name")
			var y: float = name_box.position.y - RUNGS_TOP + UiText.ASCENT - 4.0
			var line := Rect2(name_box.position.x - 1.0, y, name_box.size.x + 2.0, 1.0)
			_paint(_marker_layer, &"strike", line, Palette.color(&"red"))
	var bob: float = 1.0 if _time < BOB_SECONDS / 2.0 else 0.0
	_draw_marker(_marker_layer, _marker_at() - Vector2(0.0, bob))


## The centre of the party's diamond before its bob, in the rows' coordinates.
func _marker_at() -> Vector2:
	var party_y: float = floorf((_party_at - _scroll) * PITCH + PITCH / 2.0)
	return Vector2(floorf((RAIL_LEFT + RAIL_RIGHT + 1.0) / 2.0), party_y)


## The arrow toward the party while scrolled away: a white triangle on a night box with an ink
## edge, pointing up or down.
func _draw_party_arrow(canvas: Control, box: Rect2) -> void:
	canvas.draw_rect(box, Palette.color(&"night"))
	_outline(canvas, box, Palette.color(&"steel"))
	var up: bool = arrow_points_up()
	var middle: float = box.position.x + floorf(box.size.x / 2.0)
	for row: int in 5:
		var half: int = row if up else 4 - row
		canvas.draw_rect(
			Rect2(middle - half, box.position.y + 2.0 + row, half * 2.0 + 1.0, 1.0),
			Palette.color(&"white")
		)


func _draw_rung(canvas: Control, depth: int, row: float) -> void:
	var shown: Array[StringName] = marks(depth)
	var middle: float = row + floorf(PITCH / 2.0)
	if depth == hovered:
		_outline(canvas, Rect2(1.0, row + 1.0, WIDTH - 2.0, PITCH - 2.0), Palette.color(&"slate"))
	if is_flashing(depth) and fmod(FLASH_SECONDS - _flash, BLINK_SECONDS) < BLINK_SECONDS / 2.0:
		var lit := Rect2(1.0, row + 1.0, WIDTH - 2.0, PITCH - 2.0)
		_outline(canvas, lit, Palette.color(&"yellow"))
		_outline(canvas, lit.grow(-1.0), Palette.color(&"amber"))
	# Frames round the target's and the party's numbers (drawn under the numbers).
	for mark: StringName in MARK_BOXES:
		if shown.has(mark):
			var box := Rect2(MARK_BOXES[mark].position + Vector2(0.0, row), MARK_BOXES[mark].size)
			_outline(canvas, box, Palette.color(MARK_COLOURS[mark]), StringName("%s_frame" % mark))
	var bar := Rect2(RAIL_LEFT, middle - 2.0, RAIL_RIGHT - RAIL_LEFT + 1.0, BAR_HEIGHT)
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
		_draw_skull(canvas, Vector2(SKULL_X, middle - 3.0), shown.has(&"guardian_beaten"))
	if shown.has(&"target"):
		_draw_arrow(canvas, Vector2(ARROW_X, middle))


## A 1-pixel edge round [param rect]; noted in [member drawn] as [param kind] unless that is empty.
func _outline(canvas: Control, rect: Rect2, colour: Color, kind: StringName = &"") -> void:
	if kind != &"":
		_record(canvas, kind, rect)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), colour)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), colour)
	canvas.draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), colour)
	canvas.draw_rect(Rect2(rect.end.x - 1.0, rect.position.y, 1.0, rect.size.y), colour)


## The party's diamond: white with an ink edge, centred on [param at].
func _draw_marker(canvas: Control, at: Vector2) -> void:
	for dy: int in range(-5, 6):
		var half: int = 5 - absi(dy)
		canvas.draw_rect(
			Rect2(at.x - half - 1.0, at.y + dy, half * 2.0 + 3.0, 1.0), Palette.color(&"ink")
		)
	for dy: int in range(-4, 5):
		var half: int = 4 - absi(dy)
		canvas.draw_rect(
			Rect2(at.x - half, at.y + dy, half * 2.0 + 1.0, 1.0), Palette.color(&"white")
		)
	canvas.draw_rect(Rect2(at.x - 1.0, at.y - 2.0, 1.0, 1.0), Palette.color(&"cyan"))


## The target's arrow: a yellow triangle pointing right, its tip toward the number.
func _draw_arrow(canvas: Control, at: Vector2) -> void:
	for column: int in 5:
		var half: int = 4 - column
		_paint(
			canvas,
			&"arrow",
			Rect2(at.x + column, at.y - half, 1.0, half * 2.0 + 1.0),
			Palette.color(&"yellow")
		)


## Fills [param rect] on [param canvas] in [param colour] and notes it in [member drawn].
func _paint(canvas: Control, kind: StringName, rect: Rect2, colour: Color) -> void:
	canvas.draw_rect(rect, colour)
	_record(canvas, kind, rect)


## Notes in [member drawn] that a [param kind] was drawn at [param rect] on [param canvas] (one of
## the list's own layers), in the list's coordinates.
func _record(canvas: Control, kind: StringName, rect: Rect2) -> void:
	var at: Array = drawn.get(kind, [])
	at.append(Rect2(rect.position + canvas.position, rect.size))
	drawn[kind] = at


## A guardian's skull at [param at] (its top-left), dim when beaten.
func _draw_skull(canvas: Control, at: Vector2, beaten: bool) -> void:
	var bone: Color = Palette.color(&"slate") if beaten else Palette.color(&"white")
	for y: int in SKULL.size():
		for x: int in SKULL[y].length():
			if SKULL[y][x] == "#":
				canvas.draw_rect(Rect2(at.x + x, at.y + y, 1.0, 1.0), bone)

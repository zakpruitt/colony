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
## which drops into the same place. A goal's click (spec 042) shows the ladder and flashes a rung
## ([method flash]). It moves only in [method advance], so a test can step it.
##
## Spec 043: each rung's number is coloured by how it looks for this party ([method risk]): safe,
## within reach or dangerous; the hover says it in words, and a click on a dangerous rung says so
## once in the journal's ticker. The mouse wheel scrolls the ladder ([method scroll_by]); while
## scrolled away an arrow points toward the party, and a click on it, or [constant RETURN_SECONDS]
## without the mouse over the ladder, brings it back to following the party.
##
## Spec 047: the outline and hint follow the rung under a still mouse as the rungs move; only the
## mouse's enter and exit say whether it is over the ladder; a scrolled ladder stays put until the
## arrow or the timer; a notch is at most a rung; the target's and the party's numbers are framed
## in `yellow` and `white` ([method mark_rect]), and the arrow sits clear of the party's diamond.

## A click asked for a new target (the HUD mirrors it on its own target number at once).
signal target_asked(depth: int)

## How a depth looks for this party: see [method risk].
enum Risk { SAFE, REACHABLE, DANGEROUS }

## Rungs on show at a time.
const RUNGS: int = 12
## Pixels from one rung to the next.
const PITCH: float = 20.0
## The panel's width: room for the longest area name in the heading (spec 049).
const WIDTH: float = 60.0
## Pixels between the panel and the HUD's top band above it.
const DROP: float = 2.0
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
## Seconds a rung flashes after [method flash], and one blink of it (half lit, half not).
const FLASH_SECONDS: float = 1.0
const BLINK_SECONDS: float = 0.25
## A skull in 5x5 pixels, drawn in code: [code]#[/code] is bone.
const SKULL: Array[String] = [".###.", "#####", "#.#.#", "#####", ".#.#."]
## A rung number's colour for each risk: none of them the white, yellow or green of the party's,
## the target's or the safe depth's marks.
const RISK_COLOURS: Dictionary[Risk, StringName] = {
	Risk.SAFE: &"cyan",
	Risk.REACHABLE: &"orange",
	Risk.DANGEROUS: &"red",
}
## Rungs the ladder can scroll below the deepest depth ever reached.
const BELOW_DEEPEST: int = 6
## Seconds without the mouse over the ladder before a scrolled ladder follows the party again.
const RETURN_SECONDS: float = 5.0
## The arrow toward the party while scrolled away: its box's size, centred on the rails.
const ARROW_SIZE: Vector2 = Vector2(15, 8)
## The hint's height for one line, and what a second line adds.
const HINT_HEIGHT: float = 13.0
const HINT_LINE: float = 9.0
## Spec 047 R5: the frame round the number of the target's rung and of the party's, in palette
## colours that are none of [constant RISK_COLOURS], so neither depends on the number's colour.
const MARK_COLOURS: Dictionary[StringName, StringName] = {&"target": &"yellow", &"party": &"white"}
## Each frame's box inside its rung's row (x from the row's left, y from its top): the target's
## round the number column, its left edge where the target's arrow points, and the party's one
## pixel inside it, so a party on its target shows both.
const MARK_BOXES: Dictionary[StringName, Rect2] = {
	&"target": Rect2(8, 3, 21, 14),
	&"party": Rect2(9, 4, 19, 12),
}

## The line beside the ladder while the mouse rests on a rung (R4).
var hint: HudPanel
## The depth whose rung is outlined as under the mouse, or 0. The ladder sets it; others read it.
var hovered: int = 0

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
## The party's stage, as the world shows it.
var _party_at: float = 1.0
var _time: float = 0.0
## Seconds the mouse has rested on that rung: the line shows after HudTooltip.DELAY, as the
## HUD's tooltips do.
var _rested: float = 0.0
## A target asked for that the simulation has not applied yet (it applies on the next tick), or 0.
var _asked_target: int = 0
## The depth whose rung flashes, and seconds of its flash left.
var _flash_depth: int = 0
var _flash: float = 0.0
var _hint_risk: Label
## True while the ladder keeps the party's rung in view; false while scrolled away.
var _following: bool = true
## The top rung while scrolled away.
var _view_top: int = 1
## True while the mouse is over the ladder, from its enter and exit notifications only (spec 047
## R2), and seconds since it last was.
var _mouse_in: bool = false
var _away: float = 0.0
## Where the last mouse event over the ladder put the mouse (the ladder's own coordinates), and
## whether it is still there: the rung under it is read again whenever the rungs move (R1).
var _pointer: Vector2 = Vector2.ZERO
var _has_pointer: bool = false
## Drawn over the rungs and unclipped: the arrow back to the party, which sits in the caption's
## row or on the panel's bottom edge.
var _arrow_layer: Control
## Drawn over that, clipped to the rungs: the party's diamond, so nothing covers it.
var _marker_layer: Control


func _init() -> void:
	name = "DepthLadder"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = Vector2(WIDTH, RUNGS_TOP + RUNGS * PITCH + PADDING)
	position = Vector2(Hud.SCREEN.x - Hud.MARGIN - WIDTH, Hud.TOP_BAND + DROP)


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
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	# Spec 047 R2: an event here says where the mouse is, not that it is over the ladder (a press
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
	_caption = PixelText.label(PlaceText.area_name(simulation.expedition.place), &"steel")
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


## Follows the simulation and moves the scroll and the marker on by [param delta] seconds.
## Called every frame by the HUD; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	visible = _wanted and not _shop_is_open()
	if not visible:
		hovered = 0
	var e: Expedition = _simulation.expedition
	if _asked_target > 0 and e.target_depth == _asked_target:
		_asked_target = 0
	# Spec 049 R9: the heading names the area whose stages the rungs are.
	var heading: String = PlaceText.area_name(e.place)
	if _caption.text != heading:
		_caption.text = heading
	_time = fmod(_time + delta, BOB_SECONDS)
	_flash = maxf(_flash - delta, 0.0)
	_rested += delta
	_party_at = _party_depth()
	if not _following and not _mouse_in:
		_away += delta
		if _away >= RETURN_SECONDS:
			follow()
	# Spec 047 R3: a scrolled ladder stays where it was put, even when the party's own view comes
	# to the same rungs; only the arrow's click and the timer above bring it back.
	if not _following:
		_view_top = clampi(_view_top, 1, _max_top())
	var goal: float = _top_for(_party_at) if _following else float(_view_top)
	if absf(goal - _scroll) > RUNGS:
		_scroll = goal
	else:
		_scroll = lerpf(_scroll, goal, 1.0 - exp(-SCROLL_RATE * delta))
		if absf(goal - _scroll) < 0.01:
			_scroll = goal
	# Spec 047 R1: the rungs may have moved under a still mouse; the outline and the hint go to the
	# rung under it now, on the frame the rungs are drawn there.
	if _has_pointer and visible:
		hovered = _under(_pointer)
	_place_numbers()
	_show_hint()
	_rungs.queue_redraw()
	_arrow_layer.queue_redraw()
	_marker_layer.queue_redraw()


## True while the ladder is on screen.
func is_shown() -> bool:
	return visible


## The depth of the top rung: the party's depth stays among the [constant RUNGS] below it.
## While scrolled away, the top rung the player scrolled to.
func first_depth() -> int:
	if _simulation == null:
		return 1
	if not _following:
		return _view_top
	return maxi(roundi(_party_depth()) - ABOVE, 1)  # the shown stage's (spec 054)


## How the rung at [param level_depth] looks for this party, from its lowest hero level L: safe at
## or above the safe depth, within reach down to depth L + 1, dangerous below that. A rough guide,
## not a promise: it loosely follows the guardians' balance (a party of level depth + 4 beats the
## guardian of that depth), and ordinary levels are easier than their guardians. It changes no
## rule: any depth can still be chosen.
func risk(level_depth: int) -> Risk:
	if _simulation == null:
		return Risk.SAFE
	var e: Expedition = _simulation.expedition
	var lowest: int = PartyLevels.lowest(_simulation.party)
	return StageRisk.judge(level_depth, e.last_stable_depth, e.level_at(level_depth), lowest)


## Scrolls the ladder by [param rungs] (positive is deeper), from depth 1 at the top down to
## [constant BELOW_DEEPEST] rungs below the deepest depth ever reached, and stops it following the
## party. While following, the first rung is the next whole one from the ladder as drawn, so a
## notch moves it at most one rung even while the party is between depths (spec 047 R4).
## Scrolling back onto exactly the party's own view follows it again.
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


## Where [param mark] is drawn on the rung at [param depth] now, in the ladder's own coordinates,
## or an empty rectangle when that rung does not carry it: &"target" and &"party" are the frames
## round its number ([constant MARK_BOXES]), &"diamond" the box the party's diamond is drawn in at
## either height of its bob (on the party's rung).
func mark_rect(depth: int, mark: StringName) -> Rect2:
	if _simulation == null or not marks(depth).has(&"party" if mark == &"diamond" else mark):
		return Rect2()
	if mark == &"diamond":
		var at: Vector2 = _marker_at()
		return Rect2(at.x - 5.0, RUNGS_TOP + at.y - 5.0, 11.0, 10.0)
	if not MARK_BOXES.has(mark):
		return Rect2()
	var box: Rect2 = MARK_BOXES[mark]
	var row: float = floorf(rung_rect(depth).position.y)
	return Rect2(box.position + Vector2(0.0, row), box.size)


## True while the ladder keeps the party's rung in view, false while scrolled away.
func is_following() -> bool:
	return _following


## Brings the ladder back to following the party (the arrow's click).
func follow() -> void:
	_following = true
	_away = 0.0


## The arrow toward the party's rung while scrolled away, in the ladder's own coordinates, on the
## rails: in the caption's row above the rungs when the party is above them, on the panel's bottom
## edge when below, so it never covers the party's diamond in the top or bottom row (spec 047
## R5). Empty while following.
func arrow_rect() -> Rect2:
	if _following or _simulation == null:
		return Rect2()
	var x: float = floorf((RAIL_LEFT + RAIL_RIGHT + 1.0 - ARROW_SIZE.x) / 2.0)
	var y: float = CAPTION_HEIGHT - ARROW_SIZE.y - 1.0
	if arrow_points_up():
		# Beside the caption, not over its last letter, when there is room for it there; past a
		# long area name (spec 049), at the right edge of the top row, clear of the rails and so
		# of the party's diamond.
		var beside: float = maxf(x, _caption_end())
		if beside + ARROW_SIZE.x <= WIDTH - PADDING:
			x = beside
		else:
			x = WIDTH - ARROW_SIZE.x - 1.0
			y = RUNGS_TOP + 1.0
	else:
		y = size.y - ARROW_SIZE.y
	return Rect2(Vector2(x, y), ARROW_SIZE)


## Where an arrow beside the caption may start: two pixels after its last letter.
func _caption_end() -> float:
	return _caption.position.x + PixelText.width(_caption.text) + 2.0


## True when the party's rung is above the view, so the arrow points up.
func arrow_points_up() -> bool:
	return _follow_top() < _view_top


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
## [constant CLICK_HINT] when a click would send the party there, then on a second line how the
## depth looks for this party (spec 043): [code]Within reach[/code] or [code]Dangerous: heroes
## are level 3[/code], nothing for a safe depth.
func hover_text(depth: int) -> String:
	var parts: PackedStringArray = _hover_parts(depth)
	var text: String = parts[0] if parts[1].is_empty() else "%s. %s" % [parts[0], parts[1]]
	return text if parts[2].is_empty() else "%s\n%s" % [text, parts[2]]


## What a click on the rung at [param depth] does: asks the simulation for that target depth,
## as the HUD's - and + buttons do, and for a dangerous depth that is not already the target,
## says so once in the journal's ticker. Nothing while hidden or for a depth the simulation does
## not take as a target.
func click_depth(depth: int) -> void:
	if _simulation == null or not is_shown() or not _can_target(depth):
		return
	var changed: bool = depth != shown_target()
	_asked_target = depth
	_simulation.set_target_depth(depth)
	target_asked.emit(depth)
	_rungs.queue_redraw()
	var journal: Journal = _journal()
	if changed and journal != null and risk(depth) == Risk.DANGEROUS:
		journal.announce(
			(
				"Target set to %s: dangerous for level %d heroes"
				% [PlaceText.here(_simulation, depth), PartyLevels.lowest(_simulation.party)]
			)
		)


## The target depth as shown: the one asked for until the simulation applies it, then its own.
func shown_target() -> int:
	return _asked_target if _asked_target > 0 else _simulation.expedition.target_depth


## Shows the ladder if L hid it and flashes the rung of [param level_depth] for
## [constant FLASH_SECONDS] (spec 042: a goal's click points at its depth). A rung off the ladder
## is scrolled onto it first, at once, so it is on show while it blinks (spec 043 R5).
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


## True while the rung of [param level_depth] flashes.
func is_flashing(level_depth: int) -> bool:
	return _flash > 0.0 and level_depth == _flash_depth


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
	var text: String = _hint_text.text
	if _hint_click.visible:
		text = "%s %s" % [text, _hint_click.text]
	if _hint_risk.visible:
		text = "%s\n%s" % [text, _hint_risk.text]
	return text


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
	var place: String = PlaceText.here(_simulation, depth)
	return PackedStringArray(["%s: %s" % [place, what], click, _risk_line(depth)])


## The hint's line for how [param depth] looks (spec 043 R2): "" for a safe depth.
func _risk_line(depth: int) -> String:
	match risk(depth):
		Risk.REACHABLE:
			return "Within reach"
		Risk.DANGEROUS:
			return "Dangerous: heroes are level %d" % PartyLevels.lowest(_simulation.party)
	return ""


## The top rung that keeps the party in view, as a whole depth.
func _follow_top() -> int:
	return roundi(_top_for(_party_at))


## The deepest top rung the ladder scrolls to: its bottom rung [constant BELOW_DEEPEST] below the
## deepest depth ever reached, never above the party's own view or a flashing rung.
func _max_top() -> int:
	var e: Expedition = _simulation.expedition
	var deepest: int = maxi(e.deepest_depth, e.depth)
	var most: int = maxi(deepest + BELOW_DEEPEST - RUNGS + 1, _follow_top())
	if _flash > 0.0:
		most = maxi(most, _flash_depth - RUNGS + 1)
	return maxi(most, 1)


## True when the rung of [param depth] lies wholly on the ladder with [param top] at its top.
func _within(depth: int, top: float) -> bool:
	return depth >= top - 0.01 and depth + 1 <= top + RUNGS + 0.01


func _journal() -> Journal:
	var hud: Hud = get_parent() as Hud
	return hud.journal if hud != null else null


## The mouse at [param at] (the ladder's own coordinates): the rung under it, none over the arrow.
## A move of the mouse restarts the hint's rest; rungs moving under a still mouse do not.
func _hover(at: Vector2) -> void:
	var under: int = _under(at)
	if under != hovered:
		hovered = under
		_rested = 0.0
	_show_hint()


## The rung at [param at] (the ladder's own coordinates) as drawn now, or 0 over the arrow or off
## the rungs.
func _under(at: Vector2) -> int:
	return 0 if arrow_rect().has_point(at) else depth_at(at)


## The party's stage (spec 054): the one the world shows, so the marker moves a whole rung when
## the stage changes in the dark of a crossing, never sliding by the climb's height.
func _party_depth() -> float:
	return float(ZoneCrossing.stage_shown(_simulation))


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
	# Edged like the HUD's tooltips (spec 030), so the line reads as one of them.
	hint.bevel = Palette.color(&"dusk")
	hint.border = Palette.color(&"slate")
	add_child(hint)
	_hint_text = PixelText.label("", &"white")
	_hint_text.name = "Text"
	_hint_text.position = Vector2(5, 2)
	hint.add_child(_hint_text)
	_hint_click = PixelText.label(CLICK_HINT, &"yellow")
	_hint_click.name = "Click"
	hint.add_child(_hint_click)
	_hint_risk = PixelText.label("", &"white")
	_hint_risk.name = "Risk"
	_hint_risk.position = Vector2(5, 2 + HINT_LINE)
	hint.add_child(_hint_risk)


## Shows the line for the rung under the mouse, to the left of the ladder and level with it.
func _show_hint() -> void:
	if hint == null:
		return
	var showing: bool = hovered > 0 and is_shown() and _rested >= HudTooltip.DELAY
	hint.visible = showing
	if not showing:
		return
	var parts: PackedStringArray = _hover_parts(hovered)
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
	var height: float = HINT_HEIGHT
	_hint_risk.visible = not parts[2].is_empty()
	if _hint_risk.visible:
		if _hint_risk.text != parts[2]:
			_hint_risk.text = parts[2]
			_hint_risk.reset_size()
		var colour: StringName = RISK_COLOURS[risk(hovered)]
		_hint_risk.add_theme_color_override(&"font_color", Palette.color(colour))
		width = maxf(width, 5.0 + PixelText.width(parts[2]) + 5.0)
		height += HINT_LINE
	hint.size = Vector2(width, height)
	var row: Rect2 = rung_rect(hovered)
	var y: float = clampf(row.get_center().y - 6.0, RUNGS_TOP, size.y - height - PADDING)
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


## A rung number's colour: how its depth looks for this party (spec 043 R1).
func _number_colour(depth: int) -> StringName:
	return RISK_COLOURS[risk(depth)]


## Draws the rails and every rung on show; the arrow and the party's marker are on layers over it.
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


## The arrow back to the party, over the rungs and outside them (spec 047 R5).
func _draw_arrow_layer() -> void:
	var arrow: Rect2 = arrow_rect()
	if arrow.has_area():
		_draw_party_arrow(_arrow_layer, arrow)


## The party's diamond, over everything else on the rungs, the arrow too.
func _draw_marker_layer() -> void:
	var bob: float = 1.0 if _time < BOB_SECONDS / 2.0 else 0.0
	_draw_marker(_marker_layer, _marker_at() - Vector2(0.0, bob))


## The centre of the party's diamond before its bob, in the rungs' coordinates.
func _marker_at() -> Vector2:
	var party_y: float = floorf((_party_at - _scroll) * PITCH + PITCH / 2.0)
	return Vector2((RAIL_LEFT + RAIL_RIGHT + 1.0) / 2.0, party_y)


## The arrow toward the party while scrolled away: a 7x4 `white` triangle on a `night` box with an
## `ink` edge, pointing up or down.
func _draw_party_arrow(canvas: Control, box: Rect2) -> void:
	canvas.draw_rect(box, Palette.color(&"night"))
	_outline(canvas, box, Palette.color(&"ink"))
	var up: bool = arrow_points_up()
	var middle: float = box.position.x + floorf(box.size.x / 2.0)
	for row: int in 4:
		var half: int = row if up else 3 - row
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
	# Spec 047 R5: frames round the target's and the party's numbers (drawn under the numbers).
	for mark: StringName in MARK_BOXES:
		if shown.has(mark):
			var box: Rect2 = MARK_BOXES[mark]
			_outline(
				canvas,
				Rect2(box.position + Vector2(0.0, row), box.size),
				Palette.color(MARK_COLOURS[mark])
			)
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

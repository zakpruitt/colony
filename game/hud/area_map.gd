class_name AreaMap
extends HudPanel
## The area map (spec 053): where the party can go. A panel under the top band, left of the depth
## ladder, with one [AreaMapRow] per area in order: its name, the monsters that live there, its
## guardian (ticked once beaten), the party's safe and furthest stage there and the level of its
## first stage. The area the party is in is marked [code]Here[/code]; on a journey the destination
## is marked [code]On the way[/code] with the seconds left. A closed area is dimmed and says which
## guardian opens it.
##
## Choosing an open area ([method choose], or a click on its row) shows a stage under the rows,
## starting at that area's safe stage, with [code]-[/code] and [code]+[/code] between 1 and one past
## its furthest stage, coloured by the ladder's rule (spec 043) judged by that area's levels, and a
## [code]Go[/code] button ([method go]) that sends the party there ([method
## Simulation.set_destination]) or, for the area it is in, sets the target as the ladder does; a
## dangerous Go writes the ladder's warning in the journal.
##
## [kbd]W[/kbd] or a click on the area's name in the place panel ([member PlacePanel.area_button],
## spec 061) opens and closes it; [kbd]Esc[/kbd] closes it. It never shares the screen with the
## other panels. When an area opens (R6), the area's name shows a mark until the map has been opened
## ([method has_mark]), and the goals tracker shows a goal to visit it ([member news]). Everything
## that depends on the order of events is kept by [AreaNews] (R7). It moves only in [method
## advance], so a test can step it.

## The title and the key hint.
const TITLE: String = "Areas"
const HINT: String = "W close"
## What the footer says while no area is chosen.
const CHOOSE_HINT: String = "Click an open area to choose where the party goes"
## Space inside the border; the title row's height; pixels between rows; the footer's height.
const PADDING: float = 4.0
const TITLE_HEIGHT: float = 13.0
const ROW_GAP: float = 2.0
const FOOTER_HEIGHT: float = 15.0
## Pixels between the panel and the top band above it.
const DROP: float = 2.0
## The panel's least width.
const MIN_WIDTH: float = 300.0
## The tags after an area's name, and their colours.
const HERE: String = "Here"
const ON_THE_WAY: String = "On the way, %d s"

## One row per area, in area order.
var rows: Array[AreaMapRow] = []
var close_button: HudButton
## The footer: the chosen area's name, the stage between - and +, Go, and how the stage looks.
var place_label: Label
var minus_button: HudButton
var stage_label: Label
var plus_button: HudButton
var go_button: HudButton
var risk_label: Label
var choose_label: Label
## What the map and its goal know, in the order of the events.
var news: AreaNews

var _simulation: Simulation
var _world: World
var _chosen: StringName = &""
var _stage: int = 0
## The last Go, as "area/stage", and the simulation's tick then.
var _asked: String = ""
var _asked_tick: int = -1


func _init() -> void:
	name = "AreaMap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_W:
			toggle()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			# Not marked handled, so the other panels close too.
			close()


## Call once, as a child of the [Hud], before the first advance. [param world] may be null.
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	news = AreaNews.new(simulation)
	if world != null and not world.sim_event.is_connected(news.hear):
		world.sim_event.connect(news.hear)
	_build()
	advance(0.0)


## Gives every control its tooltip (R8). Call once the HUD's tooltips exist. (The area's name has
## its own, on the frame of the screen: spec 061.)
func add_tips(tooltip: HudTooltip) -> void:
	tooltip.tip([close_button], "Close the map (W or Esc).")
	for each_row: AreaMapRow in rows:
		for thumb: MonsterThumb in each_row.thumbs:
			tooltip.tip([thumb], thumb.display_name())
		if each_row.guardian_thumb != null:
			tooltip.tip([each_row.guardian_thumb], _guardian_tip.bind(each_row))
		tooltip.tip([each_row], _row_tip.bind(each_row))
	tooltip.tip([minus_button], "One stage back.")
	tooltip.tip([plus_button], "One stage further.")
	tooltip.tip([stage_label, place_label], _stage_tip)
	tooltip.tip([risk_label], "How the stage looks for heroes of the party's lowest level.")
	tooltip.tip([go_button], _go_tip)


## Brings the rows and the footer up to date, and closes the map if another
## panel has opened. Called every frame by the HUD; tests call it.
func advance(_delta: float) -> void:
	if _simulation == null:
		return
	if is_open() and _another_is_open():
		close()
	if not is_open():
		return
	for each_row: AreaMapRow in rows:
		_show_row(each_row)
	_show_footer()


## True while the map is shown.
func is_open() -> bool:
	return visible


## Shows the map, closing every other panel, and takes the marker off its button.
func open() -> void:
	var hud: Hud = get_parent() as Hud
	if hud != null:
		for panel: Control in [hud.shop, hud.tally]:
			if panel != null:
				panel.call(&"close")
		var layer: Node = hud.get_parent()
		if layer != null:
			for child: Node in layer.get_children():
				if child is AwayPanel:
					(child as AwayPanel).close()
	if news != null:
		news.seen()
		news.watching = true
	visible = true
	advance(0.0)


## Hides the map.
func close() -> void:
	visible = false
	if news != null:
		news.watching = false


## Opens the map if it is closed, closes it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Chooses area [param area_id]: its stage shows, starting at its safe stage. A closed or unknown
## area is not chosen, and nothing changes.
func choose(area_id: StringName) -> void:
	if _simulation == null or Content.area(area_id) == null:
		return
	if not _simulation.is_area_open(area_id):
		return
	_chosen = area_id
	_stage = clampi(_simulation.area_progress(area_id).x, 1, stage_limit(area_id))
	advance(0.0)


## The area chosen, or &"" for none.
func chosen() -> StringName:
	return _chosen


## The stage shown for the chosen area, or 0 when none is chosen.
func stage_shown() -> int:
	return _stage if _chosen != &"" else 0


## Moves the stage shown by [param by], between 1 and one past the chosen area's furthest stage.
func step_stage(by: int) -> void:
	if _chosen == &"":
		return
	_stage = clampi(_stage + by, 1, stage_limit(_chosen))
	advance(0.0)


## The deepest stage that can be chosen in area [param area_id]: one past its furthest.
func stage_limit(area_id: StringName) -> int:
	return maxi(_simulation.area_progress(area_id).y + 1, 1)


## Sends the party to the stage shown of the chosen area and closes the map. For the area the
## party is in (or, on a journey, is going to) it sets the target as the depth ladder does;
## otherwise it asks for the journey, which on the way turns it. A dangerous choice that changes
## something writes the ladder's warning in the journal, once.
func go() -> void:
	if _simulation == null or _chosen == &"" or not _simulation.is_area_open(_chosen):
		return
	var e: Expedition = _simulation.expedition
	var hud: Hud = get_parent() as Hud
	# Warned once per change of where the party is going (review of spec 053): not when it is
	# already headed there, nor for a second Go before the simulation has taken the first.
	var asked: String = "%s/%d" % [_chosen, _stage]
	var changed: bool = asked != _heading(hud)
	if _asked == asked and _asked_tick == _simulation.tick:
		changed = false
	_asked = asked
	_asked_tick = _simulation.tick
	if _chosen == e.area:
		_simulation.set_target_depth(_stage)
		if hud != null:
			hud.ladder.target_asked.emit(_stage)
	else:
		_simulation.set_destination(_chosen, _stage)
	if changed and risk(_chosen, _stage) == DepthLadder.Risk.DANGEROUS and hud != null:
		hud.journal.announce(
			(
				"Target set to %s: dangerous for level %d heroes"
				% [PlaceText.of(_chosen, _stage), PartyLevels.lowest(_simulation.party)]
			)
		)
	close()


## Where the party is headed now, as "area/stage": a destination asked for, the journey's, or
## the target in the area it is in.
func _heading(hud: Hud) -> String:
	var e: Expedition = _simulation.expedition
	if e.travel.pending_area != &"":
		return "%s/%d" % [e.travel.pending_area, e.travel.pending_stage]
	if e.state == Expedition.State.JOURNEYING:
		return "%s/%d" % [e.area, e.travel.arrival_target(e)]
	var target: int = hud.ladder.shown_target() if hud != null else e.target_depth
	return "%s/%d" % [e.area, target]


## How [param stage] of area [param area_id] looks for this party, by the ladder's rule (spec
## 043) judged by that area's levels: safe at or above a safe stage the party has held there,
## within reach while the stage's level is at most the party's lowest level plus one, dangerous
## beyond.
func risk(area_id: StringName, stage: int) -> DepthLadder.Risk:
	var progress: Vector2i = _simulation.area_progress(area_id)
	var def: AreaDef = Content.area(area_id)
	var level: int = def.level_at(stage) if def != null else stage
	var lowest: int = PartyLevels.lowest(_simulation.party)
	return StageRisk.judge(stage, progress.x, level, lowest, progress.y)


## The row of area [param area_id], or null.
func row(area_id: StringName) -> AreaMapRow:
	for each: AreaMapRow in rows:
		if each.area_id == area_id:
			return each
	return null


## True while the area's name shows its mark: an area has opened since the map was opened.
func has_mark() -> bool:
	return news != null and news.unseen > 0 and not is_open()


## The panel's height holding [param count] areas.
static func height_for(count: int) -> float:
	var rows_height: float = count * (AreaMapRow.HEIGHT + ROW_GAP) - ROW_GAP
	return PADDING + TITLE_HEIGHT + 2.0 + rows_height + 4.0 + FOOTER_HEIGHT + PADDING


# --- Building ------------------------------------------------------------------


func _build() -> void:
	var title: Label = _add(TITLE, &"yellow", Vector2(PADDING + 2.0, PADDING))
	title.name = "Title"
	var hint: Label = _add(HINT, &"slate", Vector2.ZERO)
	hint.name = "Hint"
	close_button = HudButton.new("x")
	close_button.name = "CloseButton"
	close_button.custom_minimum_size = Vector2(HudButton.HEIGHT, HudButton.HEIGHT)
	close_button.size = close_button.get_combined_minimum_size()
	close_button.pressed.connect(close)
	add_child(close_button)
	var text_width: float = 0.0
	var thumbs_width: float = 0.0
	for id: StringName in Content.area_ids():
		var made := AreaMapRow.new(id)
		made.clicked.connect(choose.bind(id))
		add_child(made)
		rows.append(made)
		_show_row(made)
		text_width = maxf(text_width, made.text_width())
		thumbs_width = maxf(thumbs_width, made.thumbs_width())
	var thumbs_x: float = text_width + AreaMapRow.THUMBS_GAP
	var width: float = maxf(MIN_WIDTH, PADDING * 2.0 + thumbs_x + thumbs_width)
	width = maxf(width, PADDING * 2.0 + PixelText.width(CHOOSE_HINT) + 4.0)
	size = Vector2(ceilf(width), height_for(rows.size()))
	var y: float = PADDING + TITLE_HEIGHT + 2.0
	for each: AreaMapRow in rows:
		each.position = Vector2(PADDING, y)
		each.lay_out(size.x - PADDING * 2.0, thumbs_x)
		y += AreaMapRow.HEIGHT + ROW_GAP
	close_button.position = Vector2(size.x - PADDING - close_button.size.x, PADDING - 1.0)
	hint.position = Vector2(close_button.position.x - 6.0 - PixelText.width(HINT), PADDING)
	var divider := ColorRect.new()
	divider.color = Palette.color(&"dusk")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2(PADDING, PADDING + TITLE_HEIGHT - 1.0)
	divider.size = Vector2(size.x - PADDING * 2.0, 1.0)
	add_child(divider)
	_build_footer(size.y - PADDING - FOOTER_HEIGHT)
	# Under the top band, centred, but left of the depth ladder (spec 033) so the two never meet.
	var right: float = Hud.SCREEN.x - Hud.MARGIN - DepthLadder.WIDTH - Hud.GAP
	var x: float = minf(floorf((Hud.SCREEN.x - size.x) / 2.0), right - size.x)
	position = Vector2(maxf(x, Hud.MARGIN), Hud.TOP_BAND + DROP)


func _build_footer(top: float) -> void:
	var line := ColorRect.new()
	line.color = Palette.color(&"dusk")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(PADDING, top)
	line.size = Vector2(size.x - PADDING * 2.0, 1.0)
	add_child(line)
	var y: float = top + 4.0
	choose_label = _add(CHOOSE_HINT, &"steel", Vector2(PADDING + 2.0, y + 1.0))
	place_label = _add("", &"white", Vector2(PADDING + 2.0, y + 1.0))
	minus_button = _footer_button("Minus", "-", y)
	minus_button.pressed.connect(step_stage.bind(-1))
	stage_label = _add("", &"cyan", Vector2(0, y + 1.0))
	plus_button = _footer_button("Plus", "+", y)
	plus_button.pressed.connect(step_stage.bind(1))
	go_button = _footer_button("Go", "Go", y)
	go_button.custom_minimum_size = Vector2(24, HudButton.HEIGHT)
	go_button.size = go_button.get_combined_minimum_size()
	go_button.pressed.connect(go)
	risk_label = _add("", &"cyan", Vector2(0, y + 1.0))


func _footer_button(button_name: String, text: String, y: float) -> HudButton:
	var made := HudButton.new(text)
	made.name = button_name
	made.custom_minimum_size = Vector2(HudButton.HEIGHT, HudButton.HEIGHT)
	made.size = made.get_combined_minimum_size()
	made.position = Vector2(0, y)
	add_child(made)
	return made


func _add(text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


# --- Showing -------------------------------------------------------------------


## Shows [param shown]'s area as the simulation and the news have it now.
func _show_row(shown: AreaMapRow) -> void:
	var id: StringName = shown.area_id
	var def: AreaDef = Content.area(id)
	if def == null:
		return
	var e: Expedition = _simulation.expedition
	var is_open_now: bool = _simulation.is_area_open(id)
	var tag: String = ""
	var tag_colour: StringName = &"green"
	var journeying: bool = e.state == Expedition.State.JOURNEYING
	if journeying and id == e.area:
		var left: int = ceili(
			float(maxi(e.travel.arrive_tick - _simulation.tick, 0)) / Simulation.TICKS_PER_SECOND
		)
		tag = ON_THE_WAY % left
		tag_colour = &"tan"
	elif not journeying and id == news.here:
		tag = HERE
	var level: String = "Stage 1 is level %d" % def.level_at(1)
	var progress: Vector2i = _simulation.area_progress(id)
	var stages: String = "Not visited yet"
	if progress.y > 0:
		stages = "Safe %d, furthest %d" % [progress.x, progress.y]
	if not is_open_now:
		var opener: AreaDef = Content.area(def.opened_by)
		var guardian: MonsterDef = Content.monster(opener.guardian) if opener != null else null
		if guardian != null:
			stages = level
			level = "Beat the %s in %s" % [guardian.display_name, opener.display_name]
	shown.show_area(is_open_now, tag, tag_colour, level, stages, news.is_beaten(id))
	shown.show_resource(_simulation.party.resource(def.resource))  # spec 052
	shown.chosen = id == _chosen


func _show_footer() -> void:
	var chosen_now: bool = _chosen != &""
	choose_label.visible = not chosen_now
	for control: Control in [place_label, minus_button, stage_label, plus_button, go_button]:
		control.visible = chosen_now
	risk_label.visible = chosen_now
	if not chosen_now:
		return
	var colour: StringName = DepthLadder.RISK_COLOURS[risk(_chosen, _stage)]
	_set_text(place_label, "%s, stage" % PlaceText.area_name(_chosen))
	var x: float = place_label.position.x + place_label.size.x + 4.0
	minus_button.position.x = x
	x += minus_button.size.x + 3.0
	_set_text(stage_label, str(_stage))
	stage_label.add_theme_color_override(&"font_color", Palette.color(colour))
	stage_label.position.x = x
	x += maxf(stage_label.size.x, PixelText.width("00")) + 3.0
	plus_button.position.x = x
	x += plus_button.size.x + 6.0
	go_button.position.x = x
	go_button.text = "Go"
	x += go_button.size.x + 6.0
	minus_button.disabled = _stage <= 1
	plus_button.disabled = _stage >= stage_limit(_chosen)
	_set_text(risk_label, _risk_text(_chosen, _stage))
	risk_label.add_theme_color_override(&"font_color", Palette.color(colour))
	risk_label.position.x = x


## The words for how [param stage] of [param area_id] looks: "Safe", "Within reach" or
## "Dangerous: heroes are level L".
func _risk_text(area_id: StringName, stage: int) -> String:
	match risk(area_id, stage):
		DepthLadder.Risk.REACHABLE:
			return "Within reach"
		DepthLadder.Risk.DANGEROUS:
			return "Dangerous: heroes are level %d" % PartyLevels.lowest(_simulation.party)
	return "Safe"


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
		label.reset_size()


# --- Tooltips ------------------------------------------------------------------


func _row_tip(shown: AreaMapRow) -> String:
	var def: AreaDef = Content.area(shown.area_id)
	if shown.is_open:
		return "Click to choose %s, then Go to send the party." % def.display_name
	return "Closed: %s to open it." % shown.level_label.text


func _guardian_tip(shown: AreaMapRow) -> String:
	var who: String = shown.guardian_thumb.display_name()
	if shown.guardian_thumb.beaten:
		return "%s, the guardian: beaten" % who
	return "%s, the guardian: not beaten yet" % who


func _stage_tip() -> String:
	return "The stage the party goes to: - and + change it, from 1 to one past the furthest."


func _go_tip() -> String:
	if _chosen == &"":
		return ""
	var place: String = PlaceText.of(_chosen, _stage)
	if _chosen == _simulation.expedition.area:
		return "Set the party's target to %s." % place
	return "Send the party to %s: %d seconds on the way." % [place, AreaTravel.JOURNEY_SECONDS]


func _another_is_open() -> bool:
	var hud: Hud = get_parent() as Hud
	if hud == null:
		return false
	for panel: Control in [hud.shop, hud.tally]:
		if panel != null and panel.call(&"is_open"):
			return true
	return false

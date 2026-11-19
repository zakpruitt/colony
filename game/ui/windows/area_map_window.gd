class_name AreaMapWindow
extends WindowContent
## The area map (spec 053) as a window on the UI layer (spec 059 R3): where the party can go. One
## [AreaMapRow] card per area in order: its name, its monsters and guardian as sprites (named on
## hover, the guardian ticked once beaten), the level of its first stage, the party's safe and
## furthest stage there, its resource with the count held, and [code]Here[/code] or [code]On the
## way, 7 s[/code]. A closed area's card is dimmed and says which guardian opens it and what it
## gives.
##
## Choosing an open card ([method choose], or a click on it) shows the stage chooser under the
## cards: the stage, starting at that area's safe stage, between [code]-[/code] and [code]+[/code]
## (1 to one past its furthest), coloured by the ladder's rule (spec 043) judged by that area's
## levels with that word beside it, and a [code]Go[/code] button whose text says what it will do
## ([code]Travel to The Claypits 3[/code], [code]Set target: stage 4[/code]). Go ([method go]) asks
## for the journey ([method Simulation.set_destination]) or, for the area the party is in, sets the
## target as the ladder does; a dangerous Go writes the ladder's warning in the journal; then the
## map closes.
##
## [kbd]W[/kbd], the bar's Map button or a click on the area's name in the place panel ([member
## PlacePanel.area_button], spec 061, which the [Hud] connects) opens and closes it. When an area
## opens, the bar's Map button carries a mark until the map has been opened (spec 053 R6, spec 059
## R6), and the goals tracker shows a goal to visit it ([member news]). Everything that depends on
## the order of events is kept by [AreaNews] (spec 053 R7). It moves only in [method advance], so a
## test can step it.

## The window's id, title and key.
const ID: StringName = &"map"
const TITLE: String = "Area map"
## What the stage chooser's number and the place before it say under the mouse.
const STAGE_TIP: String = "The stage to go to: - and + change it, up to one past the furthest."
const HOTKEY: String = "W"
## What the foot says while no area is chosen.
const CHOOSE_HINT: String = "Click an open area to choose where the party goes."
## UI pixels between cards, and between the cards and the foot.
const CARD_GAP: int = 3
const FOOT_GAP: int = 6

## One card per area, in area order.
var rows: Array[AreaMapRow] = []
## The foot: the chosen area's name, the stage between - and +, how the stage looks, and Go.
var place_label: Label
var minus_button: UiButton
var stage_label: Label
var plus_button: UiButton
var risk_label: Label
var go_button: UiButton
var choose_label: Label
## What the map and its goal know, in the order of the events.
var news: AreaNews
## The tooltips of the cards and the foot, given by [method add_tips]; null until then.
var tip: UiTip

var _simulation: Simulation
var _chooser: HBoxContainer
var _chosen: StringName = &""
var _stage: int = 0
## The last Go, as "area/stage", and the simulation's tick then.
var _asked: String = ""
var _asked_tick: int = -1


func _init() -> void:
	super()
	name = "AreaMapWindow"
	add_theme_constant_override(&"separation", CARD_GAP)


## Call once, before the first advance. [param world] may be null; [param hud] is where the
## area's name is, and the ladder and journal Go speaks to.
func setup(simulation: Simulation, world: World, hud: Hud) -> void:
	_simulation = simulation
	_hud = hud
	news = AreaNews.new(simulation)
	if world != null and not world.sim_event.is_connected(news.hear):
		world.sim_event.connect(news.hear)
	for id: StringName in Content.area_ids():
		var made := AreaMapRow.new(id)
		made.clicked.connect(choose.bind(id))
		add_child(made)
		rows.append(made)
		_show_row(made)
	_build_foot()
	advance(0.0)


## Gives every control its tooltip (spec 053 R8): the cards, the sprites and the foot (the area's
## name has its own, on the frame of the screen). Call once, after the map is in its window.
func add_tips(tips: UiTip) -> void:
	tip = tips
	tip.attach(minus_button, "One stage back.")
	tip.attach(plus_button, "One stage further.")
	_tip_now()


## Brings the cards, the foot and the bar's mark up to date. Called every frame by the HUD;
## tests call it.
func advance(_delta: float) -> void:
	if _simulation == null:
		return
	var holder: UiWindow = window()
	if holder != null:
		holder.badge = news.unseen if has_mark() else 0
	if not is_open():
		return
	for each_row: AreaMapRow in rows:
		_show_row(each_row)
	_show_foot()
	_tip_now()


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
	# Warned once per change of where the party is going (review of spec 053): not when it is
	# already headed there, nor for a second Go before the simulation has taken the first.
	var asked: String = "%s/%d" % [_chosen, _stage]
	var changed: bool = asked != _heading()
	if _asked == asked and _asked_tick == _simulation.tick:
		changed = false
	_asked = asked
	_asked_tick = _simulation.tick
	if _chosen == e.area:
		_simulation.set_target_depth(_stage)
		if _hud != null:
			_hud.ladder.target_asked.emit(_stage)
	else:
		_simulation.set_destination(_chosen, _stage)
	if changed and risk(_chosen, _stage) == DepthLadder.Risk.DANGEROUS and _hud != null:
		_hud.journal.announce(
			(
				"Target set to %s: dangerous for level %d heroes"
				% [PlaceText.of(_chosen, _stage), PartyLevels.lowest(_simulation.party)]
			)
		)
	close()


## What Go will do, as its button says it: "Travel to The Claypits 3" for another area, "Set
## target: stage 4" for the one the party is in; "Go" while none is chosen.
func go_text() -> String:
	if _chosen == &"" or _simulation == null:
		return "Go"
	if _chosen == _simulation.expedition.area:
		return "Set target: stage %d" % _stage
	return "Travel to %s" % PlaceText.of(_chosen, _stage)


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


## The card of area [param area_id], or null.
func row(area_id: StringName) -> AreaMapRow:
	for each: AreaMapRow in rows:
		if each.area_id == area_id:
			return each
	return null


## True while the bar's Map button carries its mark: an area has opened since the map was opened.
func has_mark() -> bool:
	return news != null and news.unseen > 0 and not is_open()


func _shown() -> void:
	if news != null:
		news.seen()
		news.watching = true
	advance(0.0)


func _hidden() -> void:
	if news != null:
		news.watching = false


## Where the party is headed now, as "area/stage": a destination asked for, the journey's, or
## the target in the area it is in.
func _heading() -> String:
	var e: Expedition = _simulation.expedition
	if e.travel.pending_area != &"":
		return "%s/%d" % [e.travel.pending_area, e.travel.pending_stage]
	if e.state == Expedition.State.JOURNEYING:
		return "%s/%d" % [e.area, e.travel.arrival_target(e)]
	var target: int = _hud.ladder.shown_target() if _hud != null else e.target_depth
	return "%s/%d" % [e.area, target]


# --- Building ------------------------------------------------------------------


## The foot under the cards: the hint while none is chosen, else the stage chooser over Go. Both
## lines always keep their height, so choosing never moves the window's edge.
func _build_foot() -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size.y = FOOT_GAP - CARD_GAP
	add_child(spacer)
	var line := ColorRect.new()
	line.color = Palette.color(&"dusk")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size.y = 1
	add_child(line)
	var first := HBoxContainer.new()
	first.name = "Chooser"
	first.mouse_filter = Control.MOUSE_FILTER_IGNORE
	first.add_theme_constant_override(&"separation", 4)
	first.custom_minimum_size.y = UiTheme.BUTTON_HEIGHT
	add_child(first)
	choose_label = UiText.label(CHOOSE_HINT, &"steel")
	choose_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	choose_label.size_flags_vertical = Control.SIZE_FILL
	first.add_child(choose_label)
	_chooser = HBoxContainer.new()
	_chooser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chooser.add_theme_constant_override(&"separation", 4)
	first.add_child(_chooser)
	place_label = _foot_label("Place", &"white", true)
	minus_button = _foot_button("Minus", "-")
	minus_button.pressed.connect(step_stage.bind(-1))
	stage_label = _foot_label("Stage", &"cyan", true)
	stage_label.custom_minimum_size.x = UiText.width("000", true)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_button = _foot_button("Plus", "+")
	plus_button.pressed.connect(step_stage.bind(1))
	risk_label = _foot_label("Risk", &"cyan")
	var second := HBoxContainer.new()
	second.name = "GoLine"
	second.mouse_filter = Control.MOUSE_FILTER_IGNORE
	second.alignment = BoxContainer.ALIGNMENT_END
	second.custom_minimum_size.y = UiTheme.BUTTON_HEIGHT
	add_child(second)
	go_button = UiButton.new("Go")
	go_button.name = "Go"
	go_button.toggle_mode = false
	go_button.pressed.connect(go)
	second.add_child(go_button)


func _foot_label(label_name: String, colour: StringName, bold: bool = false) -> Label:
	var made: Label = UiText.label("", colour, bold)
	made.name = label_name
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	made.size_flags_vertical = Control.SIZE_FILL
	_chooser.add_child(made)
	return made


func _foot_button(button_name: String, text: String) -> UiButton:
	var made := UiButton.new(text)
	made.name = button_name
	made.toggle_mode = false
	made.custom_minimum_size.x = UiTheme.BUTTON_HEIGHT
	_chooser.add_child(made)
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
		tag = AreaMapRow.ON_THE_WAY % left
		tag_colour = &"tan"
	elif not journeying and id == news.here:
		tag = AreaMapRow.HERE
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
			level = AreaMapRow.opens_by(guardian, opener)
	shown.show_area(is_open_now, tag, tag_colour, level, stages, news.is_beaten(id))
	shown.show_resource(_simulation.party.resource(def.resource))  # spec 052
	shown.chosen = id == _chosen


func _show_foot() -> void:
	var chosen_now: bool = _chosen != &""
	choose_label.visible = not chosen_now
	_chooser.visible = chosen_now
	go_button.visible = chosen_now
	if not chosen_now:
		return
	var colour: StringName = DepthLadder.RISK_COLOURS[risk(_chosen, _stage)]
	place_label.text = "%s, stage" % PlaceText.area_name(_chosen)
	stage_label.text = str(_stage)
	stage_label.add_theme_color_override(&"font_color", Palette.color(colour))
	minus_button.disabled = _stage <= 1
	plus_button.disabled = _stage >= stage_limit(_chosen)
	risk_label.text = _risk_text(_chosen, _stage)
	risk_label.add_theme_color_override(&"font_color", Palette.color(colour))
	if go_button.text != go_text():
		go_button.text = go_text()


## The word for how [param stage] of [param area_id] looks: "Safe", "Within reach" or
## "Dangerous" (its tooltip says the levels).
func _risk_text(area_id: StringName, stage: int) -> String:
	match risk(area_id, stage):
		DepthLadder.Risk.REACHABLE:
			return "Within reach"
		DepthLadder.Risk.DANGEROUS:
			return "Dangerous"
	return "Safe"


# --- Tooltips ------------------------------------------------------------------


## Gives the cards, the sprites, the stage and Go the tooltips their state calls for now.
func _tip_now() -> void:
	if tip == null:
		return
	for each_row: AreaMapRow in rows:
		for thumb: MonsterThumb in each_row.thumbs:
			tip.attach(thumb, thumb.display_name())
		if each_row.guardian_thumb != null:
			tip.attach(each_row.guardian_thumb, _guardian_tip(each_row))
		tip.attach(each_row, _row_tip(each_row))
	var stage_tip: String = STAGE_TIP
	tip.attach(stage_label, stage_tip)
	tip.attach(place_label, stage_tip)
	tip.attach(go_button, _go_tip())
	tip.attach(risk_label, _level_tip())


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


## The levels behind the risk word: "Stage 6 is level 9; the heroes are level 6 at the lowest."
func _level_tip() -> String:
	if _chosen == &"":
		return ""
	var def: AreaDef = Content.area(_chosen)
	return (
		"Stage %d is level %d; the heroes are level %d at the lowest."
		% [_stage, def.level_at(_stage), PartyLevels.lowest(_simulation.party)]
	)


func _go_tip() -> String:
	if _chosen == &"":
		return ""
	var place: String = PlaceText.of(_chosen, _stage)
	if _chosen == _simulation.expedition.area:
		return "Set the party's target to %s." % place
	return "Send the party to %s: %d seconds on the way." % [place, AreaTravel.JOURNEY_SECONDS]

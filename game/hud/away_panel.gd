class_name AwayPanel
extends HudPanel
## The panel in the middle of the screen after a replay of the time away (spec 019, R5): how
## long the party was away and what changed. Closes on a click or any key, or by itself after
## [constant SHOW_SECONDS]. The game runs behind it. Spec 031 adds a line for each guardian count,
## side quest count and microskill learned, shown only when there is something to say.

## Seconds the panel stays up if nobody closes it.
const SHOW_SECONDS: float = 12.0
## Space inside the panel's border, and between lines.
const PADDING: Vector2 = Vector2(8, 6)
const LINE_HEIGHT: float = 10.0
## Microskills learned get a line each up to this many, then one "and N more".
const MAX_LEARNED_LINES: int = 4

var _left: float = SHOW_SECONDS
var _lines: Array[Label] = []


## Where the party was and is, as the panel says it (spec 049): "Mossy Hollow 3", "Mossy Hollow 3
## to 5", or "Mossy Hollow 5 to The Claypits 1".
static func where(report: AwayReport) -> String:
	var after: String = PlaceText.of(report.area_after, report.depth_after)
	if report.area_after != report.area_before:
		return "%s to %s" % [PlaceText.of(report.area_before, report.depth_before), after]
	if report.depth_after == report.depth_before:
		return after
	return "%s to %d" % [PlaceText.of(report.area_before, report.depth_before), report.depth_after]


## A panel telling of [param report]; [param party] names the heroes.
func _init(report: AwayReport, party: Party) -> void:
	super()
	name = "AwayPanel"
	_add_line("While you were away", &"yellow")
	_add_line("Away %s" % duration(report.seconds), &"white")
	_add_line("Gold +%s" % Hud.group_thousands(report.gold_gained), &"yellow")
	_add_line(where(report), &"silver")
	_add_line("Slain %s   Wipes %d" % [Hud.group_thousands(report.kills), report.wipes], &"silver")
	_add_quest_lines(report)
	for hero: Hero in party.heroes:
		var gained: int = report.levels_gained.get(hero.id, 0)
		var word: String = "level" if gained == 1 else "levels"
		var colour: StringName = &"green" if gained > 0 else &"steel"
		_add_line("%s +%d %s" % [hero.def().display_name, gained, word], colour)
	_add_learned_lines(report, party)
	if report.upgrades_bought > 0:
		_add_line("Upgrades bought %d" % report.upgrades_bought, &"green")
	_add_line("Click or press any key", &"steel")
	_layout()


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var button: InputEventMouseButton = event as InputEventMouseButton
	if (key != null and key.pressed and not key.echo) or (button != null and button.pressed):
		close()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## Counts down the time left; closes the panel when it runs out. Tests call it.
func advance(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		close()


## Hides the panel and frees it.
func close() -> void:
	if is_queued_for_deletion():
		return
	visible = false
	set_process(false)
	set_process_input(false)
	queue_free()


## Every line the panel shows, one per row.
func text() -> String:
	var rows: PackedStringArray = []
	for line: Label in _lines:
		rows.append(line.text)
	return "\n".join(rows)


## [param seconds] as hours and minutes: "8h 0m", "1h 5m", "30m".
static func duration(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %dm" % [minutes / 60, minutes % 60]


## Guardians slain, side quests done and missed, and the microskill the misses needed most.
func _add_quest_lines(report: AwayReport) -> void:
	if report.guardians_slain > 0:
		var deepest: String = (
			Content.monster(report.deepest_guardian).display_name
			if report.deepest_guardian != &""
			else "?"
		)
		_add_line(
			(
				"Guardians slain %s (furthest: %s)"
				% [Hud.group_thousands(report.guardians_slain), deepest]
			),
			&"amber"
		)
	if report.side_quests_done > 0:
		_add_line("Side quests done %s" % Hud.group_thousands(report.side_quests_done), &"green")
	if report.side_quests_missed > 0:
		_add_line(
			"Side quests missed %s" % Hud.group_thousands(report.side_quests_missed), &"orange"
		)
		if report.most_needed_microskill != &"":
			var skill: String = Content.microskill(report.most_needed_microskill).display_name
			_add_line("Most needed: %s" % skill, &"orange")


## One line per microskill learned, at most [constant MAX_LEARNED_LINES], then "and N more".
func _add_learned_lines(report: AwayReport, party: Party) -> void:
	var ids: Array[StringName] = Content.microskill_ids()
	var shown: int = mini(report.microskills_learned.size(), MAX_LEARNED_LINES)
	for i: int in shown:
		var learned: Vector2i = report.microskills_learned[i]
		var hero: Hero = party.hero(learned.x)
		var who: String = hero.def().display_name if hero != null else "A hero"
		var skill: String = (
			Content.microskill(ids[learned.y]).display_name
			if learned.y >= 0 and learned.y < ids.size()
			else "?"
		)
		_add_line("%s learned %s" % [who, skill], &"cyan")
	var rest: int = report.microskills_learned.size() - shown
	if rest > 0:
		_add_line("and %d more" % rest, &"steel")


func _add_line(line: String, colour: StringName) -> void:
	var label: Label = PixelText.label(line, colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_lines.append(label)


func _layout() -> void:
	var width: float = 0.0
	for line: Label in _lines:
		width = maxf(width, PixelText.width(line.text))
	size = Vector2(width + PADDING.x * 2.0, _lines.size() * LINE_HEIGHT + PADDING.y * 2.0 - 2.0)
	for i: int in _lines.size():
		var line: Label = _lines[i]
		var line_width: float = PixelText.width(line.text)
		var x: float = (
			PADDING.x if i > 0 and i < _lines.size() - 1 else floorf((size.x - line_width) / 2.0)
		)
		line.position = Vector2(x, PADDING.y + i * LINE_HEIGHT - 1.0)
	position = ((Hud.SCREEN - size) / 2.0).floor()

class_name GoalsView
extends Panel
## The goals on the sharp layer (spec 062 R1), under the place panel: a small panel titled
## [code]Goals[/code] with the [kbd]G[/kbd] hint, and a [GoalRow] per goal [Goals] shows, each a
## button; a click on one asks [method Goals.press]. It only draws what [Goals] decides, and lays
## itself out each time the goals move ([signal Goals.refreshed]), so it is never a frame behind.

## Space inside the panel's edge, the title row's height and the gap between rows, in UI pixels.
const PAD: float = 4.0
const TITLE_HEIGHT: float = 16.0
const ROW_GAP: float = 2.0
## The panel's least width; it grows to hold its longest goal.
const MIN_WIDTH: float = 230.0

## One row per goal slot, top to bottom; a slot with no goal is hidden.
var rows: Array[GoalRow] = []
var title_label: Label
var hint_label: Label

var _goals: Goals


func _init() -> void:
	name = "GoalsView"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label = UiText.label(Goals.TITLE, &"steel", true)
	title_label.name = "Title"
	title_label.position = Vector2(PAD + 2.0, PAD - 1.0)
	add_child(title_label)
	hint_label = UiText.label(Goals.HIDE_HINT, &"slate")
	hint_label.name = "Hint"
	add_child(hint_label)
	for i: int in Goals.MOST:
		var row := GoalRow.new()
		row.name = "Goal%d" % i
		row.visible = false
		add_child(row)
		rows.append(row)


## Call once: the view shows [param goals] and sends its rows' clicks to it.
func setup(goals: Goals) -> void:
	_goals = goals
	for i: int in rows.size():
		rows[i].pressed.connect(_on_pressed.bind(i))
	goals.refreshed.connect(refresh)
	refresh()


## Shows the goals as [Goals] has them now and sizes the panel to hold them.
func refresh() -> void:
	if _goals == null:
		return
	visible = _goals.is_shown()
	var width: float = MIN_WIDTH
	var detail_column: float = 0.0
	for i: int in _goals.count():
		var goal: Goals.Goal = _goals.goal_at(i)
		width = maxf(width, GoalRow.needed_width(goal) + PAD * 2.0)
		if goal.progress >= 0.0:
			detail_column = maxf(detail_column, GoalRow.ink(goal.detail))
	var y: float = PAD + TITLE_HEIGHT
	for i: int in rows.size():
		var row: GoalRow = rows[i]
		row.visible = i < _goals.count()
		if not row.visible:
			continue
		row.position = Vector2(PAD, y)
		row.show_goal(_goals.goal_at(i), width - PAD * 2.0, detail_column)
		y += row.size.y + ROW_GAP
	if _goals.count() == 0:
		y += UiText.LINE_HEIGHT
	size = Vector2(width, y - ROW_GAP + PAD)
	hint_label.position = Vector2(width - PAD - 2.0 - GoalRow.ink(Goals.HIDE_HINT), PAD - 1.0)


## The tooltip of row [param index]: how to get there, then what a click does (none for a
## finished goal).
func tip(index: int) -> String:
	if _goals == null:
		return ""
	var click: String = _goals.action(index)
	var how: String = _goals.hint(index)
	return how if click.is_empty() else how + " " + click


func _on_pressed(index: int) -> void:
	_goals.press(index)

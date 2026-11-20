class_name Countdown
extends FramePiece
## The road to stable beside the place panel, on the sharp layer: the note
## ([code]Stable in 8:29[/code], [code]Further in 0:42[/code], [code]Stable[/code] or
## [code]Holding[/code]) over a bar that fills toward it while it
## counts, and what comes next beside the bar ([code]then stage 4[/code], [code]staying on stage
## 3[/code], [code]Orders (O) to go in[/code]). The texts are the HUD's ([method Hud.stable_text]);
## this only draws them. Hidden while there is nothing to say (on the way to another area).

## UI pixels inside the panel's edge, the bar's size, and the gap between the bar and the next.
const PAD: float = 6.0
const BAR: Vector2 = Vector2(56, 7)
const BAR_GAP: float = 6.0
## Where the two rows' tops sit in the panel.
const NOTE_Y: float = 4.0
const NEXT_Y: float = 22.0

var note_label: Label
## The bar toward stable or toward the next push; shown only while the note counts.
var bar: Control
var next_label: Label

var _progress: float = 0.0
## The note and what comes next as last shown: the same words are not laid out again.
var _note: String = ""
var _next: String = ""


func _init() -> void:
	name = "Countdown"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP  # a click here goes no further (to the world)
	note_label = UiText.label("", &"silver", true)
	note_label.name = "Note"
	add_child(note_label)
	bar = Control.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size = BAR
	bar.draw.connect(_draw_bar)
	add_child(bar)
	next_label = UiText.label("", &"steel")
	next_label.name = "Next"
	add_child(next_label)


## Shows [param note] over its bar, [param filled] (0 to 1) filled while it counts, and
## [param next] beside the bar; [param height] is the panel's.
func show_road(note: String, next: String, filled: float, height: float) -> void:
	if note == _note and next == _next and height == size.y:
		if not is_equal_approx(_progress, filled):
			_progress = filled
			bar.queue_redraw()
		return
	_note = note
	_next = next
	var counting: bool = note.contains(" in ")
	WindowText.set_text(note_label, note)
	WindowText.set_text(next_label, next)
	WindowText.set_colour(note_label, &"green" if note == "Stable" else &"silver")
	bar.visible = counting
	if not is_equal_approx(_progress, filled):
		_progress = filled
		bar.queue_redraw()
	visible = not note.is_empty() or not next.is_empty()
	note_label.position = Vector2(PAD, NOTE_Y)
	var next_x: float = PAD
	if counting:
		bar.position = Vector2(PAD, NEXT_Y + floorf((UiText.LINE_HEIGHT - BAR.y) / 2.0))
		next_x += BAR.x + BAR_GAP
	next_label.position = Vector2(next_x, NEXT_Y)
	var right: float = maxf(PAD + note_label.size.x, next_x + next_label.size.x)
	if not next_label.text.is_empty() or counting:
		right = maxf(right, next_x + next_label.size.x)
	size = Vector2(ceilf(right + PAD), height)


## The share of the bar filled, as last shown.
func progress() -> float:
	return _progress


## The countdown's tooltip says what decides what happens next.
func add_tips(tips: UiTip) -> void:
	tips.attach(self, _tip)


func _tip() -> String:
	var note: String = note_label.text
	if note.begins_with("Further in"):
		return "Time left until Auto takes the party a stage further."
	if note == "Holding":
		return HudFrame.holding_tip()
	if bar.visible:
		return "Time left until this stage is safe."
	if next_label.text.begins_with("staying"):
		return "Safe, and Auto is off: the party stays until Auto is on or the target is further."
	return "This stage is safe: a wipe comes back here."


func _draw_bar() -> void:
	UiBar.draw_bar(
		bar,
		Rect2(Vector2.ZERO, BAR),
		_progress,
		Palette.color(&"yellow"),
		Palette.color(&"amber"),
		Palette.color(&"ink")
	)

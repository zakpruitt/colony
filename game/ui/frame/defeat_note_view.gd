class_name DefeatNoteView
extends Panel
## The note after a defeat on the sharp layer: what beat the party and where, the plainest
## reason, and up to [constant DefeatNote.MOST] [UiButton]s, centred
## across the room just above the WIPED banner. [DefeatNote] decides what it says and what each
## button does; this only draws it. On the UI layer it lies over every window, so it is never
## hidden; it stops every click on it.

## Space inside the edge, the gap between the lines and the buttons, and between two buttons.
const PAD: Vector2 = Vector2(10, 6)
const BUTTONS_GAP: float = 6.0
const BUTTON_GAP: float = 6.0

## The note's lines, the first and maybe a second.
var labels: Array[Label] = []
## One button per suggestion slot, left to right; a slot with no suggestion is hidden.
var buttons: Array[UiButton] = []


func _init() -> void:
	name = "DefeatNote"
	theme_type_variation = UiTheme.FRAME
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for i: int in 2:
		var label: Label = UiText.label("", &"white" if i == 0 else &"silver", i == 0)
		label.name = "Line%d" % i
		add_child(label)
		labels.append(label)
	for i: int in DefeatNote.MOST:
		var button := UiButton.new("")
		button.name = "Help%d" % i
		button.visible = false
		add_child(button)
		buttons.append(button)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()  # a click on the note goes no further


## Lays the note out: [param lines] over the buttons [param texts] ([param lit] lights one that is
## on), all in [param fade] while the note fades ([code]&""[/code] for their own colours), centred
## across [param room_width] with its bottom at [param bottom].
func show_note(
	lines: Array[String],
	texts: Array[String],
	lit: Array[bool],
	fade: StringName,
	room_width: float,
	bottom: float
) -> void:
	var width: float = 0.0
	var y: float = PAD.y - 1.0
	for i: int in labels.size():
		var label: Label = labels[i]
		label.visible = i < lines.size()
		if not label.visible:
			continue
		if label.text != lines[i]:
			label.text = lines[i]
			label.reset_size()
		var own: StringName = &"white" if i == 0 else &"silver"
		label.add_theme_color_override(&"font_color", Palette.color(own if fade == &"" else fade))
		width = maxf(width, WindowText.ink(label))
		label.position.y = y
		y += UiText.LINE_HEIGHT + 2.0
	var row: float = 0.0
	for i: int in buttons.size():
		var button: UiButton = buttons[i]
		button.visible = i < texts.size()
		if not button.visible:
			continue
		if button.text != texts[i]:
			button.text = texts[i]
		button.lit = lit[i]
		if fade == &"":
			button.remove_theme_color_override(&"font_color")
		else:
			button.add_theme_color_override(&"font_color", Palette.color(fade))
		button.reset_size()
		button.size = button.get_combined_minimum_size()
		row += button.size.x + (BUTTON_GAP if row > 0.0 else 0.0)
	width = maxf(width, row)
	var full: float = ceilf(width + PAD.x * 2.0)
	for label: Label in labels:
		label.position.x = floorf((full - WindowText.ink(label)) / 2.0)
	var x: float = floorf((full - row) / 2.0)
	if not texts.is_empty():
		y += BUTTONS_GAP
		for i: int in texts.size():
			buttons[i].position = Vector2(x, y)
			x += buttons[i].size.x + BUTTON_GAP
		y += UiTheme.BUTTON_HEIGHT
	size = Vector2(full, ceilf(y + PAD.y))
	position = Vector2(floorf((room_width - full) / 2.0), floorf(bottom - size.y))

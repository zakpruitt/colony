class_name UiFormat
extends RefCounted
## How the UI writes a number, a time or a sentence's piece, and where a control is on the screen:
## the one place each is worked out, for every piece of the frame, every window and the effects.


## [param value] with a comma between each group of three digits: 1234567 is "1,234,567".
static func group_thousands(value: int) -> String:
	var digits: String = str(absi(value))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


## [param value] short enough for the top bar: as [method group_thousands] below 10,000, then
## rounded down to three figures with k or M ("12.3k", "123k", "9.9M", "123M"), so a count never
## shows more than it is.
static func short_count(value: int) -> String:
	if absi(value) < 10_000:
		return group_thousands(value)
	var minus: String = "-" if value < 0 else ""
	var whole_value: int = absi(value)
	var suffix: String = "k"
	var unit: int = 1000
	if whole_value >= 1_000_000:
		suffix = "M"
		unit = 1_000_000
	var whole: int = whole_value / unit
	if whole >= 100:
		return "%s%s%s" % [minus, group_thousands(whole), suffix]
	var tenths: int = (whole_value * 10 / unit) % 10
	return "%s%d.%d%s" % [minus, whole, tenths, suffix]


## [param seconds] as a countdown, "m:ss", rounded up to the whole second.
static func clock(seconds: float) -> String:
	var whole: int = ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## [param text] as it reads inside a sentence: its first letter in lower case and no full stop at
## its end ("Opens locks" is "opens locks").
static func lower_first(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1).trim_suffix(".") if not text.is_empty() else ""


## Where [param control] is, as a rectangle in the screen's 640x360 pixels (where input events
## and the world are), wherever it is drawn: through its canvas layer's transform, never a
## camera's (a [Hud] built alone in a test sits on no layer, beside a world's camera).
static func on_screen(control: Control) -> Rect2:
	var xform: Transform2D = _screen_transform(control)
	return Rect2(xform.origin, control.size * xform.get_scale())


## From [param item]'s own pixels to the screen's: its canvas layer's transform, if any, times its
## global transform.
static func _screen_transform(item: CanvasItem) -> Transform2D:
	var layer: CanvasLayer = item.get_canvas_layer_node()
	var xform: Transform2D = item.get_global_transform()
	return layer.get_final_transform() * xform if layer != null else xform

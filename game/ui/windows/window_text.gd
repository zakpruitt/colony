class_name WindowText
extends RefCounted
## Text and buttons laid out by hand inside a window on the UI layer (spec 060): labels sized to
## the text they show, lines exactly [constant UiText.LINE_HEIGHT] apart, words wrapped at spaces
## to a width so nothing is ever cut, and buttons as wide as their words. A window whose content
## is placed this way is laid out the moment it changes, with nothing left for a later frame.


## A [Label] called [param label_name] showing [param text] in the UI font (its bold if
## [param bold]) in the palette colour [param colour], as big as its text, its lines
## [constant UiText.LINE_HEIGHT] apart, never taking the mouse.
static func label(
	label_name: String, text: String, colour: StringName, bold: bool = false
) -> Label:
	var made: Label = UiText.label(text, colour, bold)
	made.name = label_name
	made.add_theme_constant_override(&"line_spacing", 0)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_text(made, text)
	return made


## Shows [param text] on [param shown] and sizes it to the text: as wide as its widest line, a
## line tall per line.
static func set_text(shown: Label, text: String) -> void:
	if shown.text == text and shown.size != Vector2.ZERO:
		return
	shown.text = text
	var bold: bool = shown.get_theme_font(&"font") == UiText.font(true)
	var widest: int = 0
	var lines: PackedStringArray = text.split("\n")
	for line: String in lines:
		widest = maxi(widest, UiText.width(line, bold))
	shown.size = Vector2(widest, lines.size() * UiText.LINE_HEIGHT)


## How wide [param label]'s text inks in its own font (bold or not), in UI pixels: its width
## without the spacing after the last glyph.
@warning_ignore("shadowed_variable")
static func ink(label: Label) -> float:
	var bold: bool = label.get_theme_font(&"font") == UiText.font(true)
	return maxf(UiText.width(label.text, bold) - UiText.SPACING, 0.0)


## A [UiButton] called [param button_name] reading [param text], as wide as its words and padding.
static func button(button_name: String, text: String) -> UiButton:
	var made := UiButton.new(text)
	made.name = button_name
	fit_button(made)
	return made


## Sizes [param shown] to its text, after the text changed.
static func fit_button(shown: UiButton) -> void:
	var wide: float = (
		UiText.width(shown.text, true) - UiText.SPACING + 2 * (UiTheme.BUTTON_PAD_X + 1)
	)
	shown.custom_minimum_size = Vector2(wide, UiTheme.BUTTON_HEIGHT)
	shown.size = shown.custom_minimum_size


## [param text] broken at spaces into lines no wider than [param width] UI pixels (a single word
## wider than that keeps a line of its own).
static func wrap(text: String, width: float, bold: bool = false) -> Array[String]:
	var lines: Array[String] = []
	var current: String = ""
	for word: String in text.split(" ", false):
		var longer: String = word if current.is_empty() else current + " " + word
		if current.is_empty() or UiText.width(longer, bold) - UiText.SPACING <= width:
			current = longer
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines

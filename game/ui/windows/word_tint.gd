class_name WordTint
extends Control
## Words of a one-line label drawn again in colours of their own (spec 064 R1: a path's name in the
## path's colour wherever a hero window names it, as in [code]Knight, Berserker[/code] or the
## question before a path). It sits on the label, the size of it, and draws each word in the UI
## font exactly over the label's own letters, so the line reads as one text with those words
## coloured; the label keeps its whole text.

## The colour of each word drawn, by the word.
var _colours: Dictionary[String, StringName] = {}
var _label: Label


## A tint over [param label], added as its child.
static func over(label: Label) -> WordTint:
	var made := WordTint.new()
	made.name = "Tint"
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made._label = label
	label.add_child(made)
	return made


## Draws each word of [param colours] (word to palette name) in its colour over the label's text,
## at the word's first place in it; a word the text does not hold is not drawn.
func show_words(colours: Dictionary[String, StringName]) -> void:
	_colours = colours.duplicate()
	size = _label.size if _label != null else Vector2.ZERO
	queue_redraw()


## The palette name word [param word] is drawn in now, or &"" when it is not tinted (or not in
## the label's text).
func colour_of(word: String) -> StringName:
	if _label == null or not _colours.has(word) or _label.text.find(word) < 0:
		return &""
	return _colours[word]


func _draw() -> void:
	if _label == null:
		return
	var bold: bool = _label.get_theme_font(&"font") == UiText.font(true)
	var font: Font = UiText.font(bold)
	for word: String in _colours:
		var at: int = _label.text.find(word)
		if at < 0:
			continue
		var x: float = UiText.width(_label.text.left(at), bold)
		draw_string(
			font,
			Vector2(x, UiText.ASCENT),
			word,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			UiText.SIZE,
			Palette.color(_colours[word])
		)

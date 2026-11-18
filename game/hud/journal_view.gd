class_name JournalView
extends ScrollContainer
## The journal's lines on the UI layer (spec 058 R8): the content of the Journal window
## ([kbd]J[/kbd]). It lists every line the [Journal] keeps, newest first, the time in
## [code]steel[/code] then the sentence, the newest in white and the rest in silver; at least
## [constant SHOWN_LINES] show at once and the mouse wheel scrolls through all
## [constant Journal.CAPACITY]. It only reads the journal, which writes its lines in the order the
## events happened however many arrive in a frame.

## Lines in view at once.
const SHOWN_LINES: int = 20
## UI pixels between two lines; the time's column; the sentence's column.
const LINE_GAP: int = 0
const TIME_WIDTH: int = 52
const TEXT_WIDTH: int = 310
const EMPTY: String = "Nothing yet: the party's deeds will be written here"

var _journal: Journal
var _rows: Array[HBoxContainer] = []
var _times: Array[Label] = []
var _sentences: Array[Label] = []
var _empty: Label
## True when the journal has written since the lines were last shown.
var _dirty: bool = true


func _init() -> void:
	name = "JournalView"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override(&"separation", LINE_GAP)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(lines)
	_empty = UiText.label(EMPTY, &"slate")
	lines.add_child(_empty)
	for i: int in Journal.CAPACITY:
		var line_row := HBoxContainer.new()
		line_row.name = "Line%d" % i
		line_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_row.add_theme_constant_override(&"separation", 0)
		line_row.visible = false
		lines.add_child(line_row)
		var time: Label = UiText.label("", &"steel")
		time.custom_minimum_size.x = TIME_WIDTH
		line_row.add_child(time)
		var sentence: Label = UiText.label("", &"white" if i == 0 else &"silver")
		sentence.custom_minimum_size.x = TEXT_WIDTH
		line_row.add_child(sentence)
		_rows.append(line_row)
		_times.append(time)
		_sentences.append(sentence)
	var tall: int = SHOWN_LINES * UiText.LINE_HEIGHT + (SHOWN_LINES - 1) * LINE_GAP
	custom_minimum_size = Vector2(TIME_WIDTH + TEXT_WIDTH + 12, tall)


func _process(_delta: float) -> void:
	refresh()


## Call once: the view shows [param journal]'s lines.
func setup(journal: Journal) -> void:
	_journal = journal
	journal.written.connect(func() -> void: _dirty = true)
	_dirty = true
	refresh()


## Brings the list up to date with the journal if it has written since. Called every frame;
## tests call it.
func refresh() -> void:
	if not _dirty or _journal == null:
		return
	_dirty = false
	var all: Array[String] = _journal.lines()
	_empty.visible = all.is_empty()
	for i: int in _rows.size():
		var has: bool = i < all.size()
		_rows[i].visible = has
		if has:
			_times[i].text = all[i].get_slice("  ", 0)
			_sentences[i].text = all[i].substr(_times[i].text.length() + 2)


## Every line listed, top to bottom, as the journal writes them ("12:04  Mage reached level 4").
func shown_lines() -> Array[String]:
	var shown: Array[String] = []
	for i: int in _rows.size():
		if _rows[i].visible:
			shown.append("%s  %s" % [_times[i].text, _sentences[i].text])
	return shown


## The row of the line at [param index] (0 is the newest), for tests to measure.
func row(index: int) -> Control:
	return _rows[index]

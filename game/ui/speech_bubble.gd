class_name SpeechBubble
extends Control
## One line a character says: a rounded panel in the window's colours with the line in the UI font
## ([UiText]), wrapped to [constant WIDTH] on at most [constant MOST_LINES] lines, and a tail
## ([member tail]) under it whose tip is at [method tip]. [SpeechBubbles] keeps a few, reuses them
## and places them every frame.
##
## The line is measured and wrapped once, in [method start]; the panel is drawn again only when
## that happens. Placing it ([method place]) moves this control and its tail and draws nothing.
## It pops in over [constant POP_TIME] and blinks out over the last [constant FxText.BLINK_TIME]
## of its life, as the world's words do: its colours are always whole.

## The widest its text runs, in UI pixels, and the most lines it wraps onto.
const WIDTH: int = 160
const MOST_LINES: int = 3
## UI pixels between the panel's edge and the text: across, above and below. The font keeps a
## row of air over the capitals and three under the baseline, so the text sits in the middle.
const PAD_X: int = 4
const PAD_TOP: int = 1
const PAD_BOTTOM: int = 1
## How far the tail reaches below the panel, and how far it reaches either side of its tip.
const TAIL_DROP: int = 3
const TAIL_HALF: int = 3
## Columns of each side of the panel the tail keeps clear of: the rounded corner.
const CORNER: int = 2
## Seconds it pops in over, and its scale at each equal step of that time before it is whole.
const POP_TIME: float = 0.12
const POP_STEPS: Array[float] = [0.5, 0.8, 1.1]
## Shown at the end of a line cut short to fit [constant MOST_LINES].
const MORE: String = "..."

## Text measurements made by every bubble, for tests: only [method start] adds to it.
static var measures: int = 0
## The panel's colours, read once from the window's look in [UiTheme].
static var _fill: Color = Color.TRANSPARENT
static var _edge: Color = Color.TRANSPARENT

## Who says it: an int character id or a Callable returning a world point.
var speaker: Variant
## The line, as given.
var text: String = ""
## The sprite an id speaker had when it spoke, and its head above its position, in world pixels.
var sprite: CharacterSprite
var head: Vector2 = Vector2.ZERO
## The tail under the panel: its own control, so moving it draws nothing.
var tail: Control
## How many times its panel was drawn again, for tests.
var redraws: int = 0
## When it was shown, as [SpeechBubbles] counts: a later one is nudged clear of an earlier one.
var order: int = 0

var _lines: PackedStringArray = PackedStringArray()
var _life: float = 0.0
var _age: float = 0.0
var _tip: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "Bubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail = _Tail.new()
	tail.name = "Tail"
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.size = Vector2(2 * TAIL_HALF + 1, TAIL_DROP + 1)
	add_child(tail)


## Shows [param line] by [param who] for [param seconds]: wraps it, sizes the panel to it and
## draws it once.
func start(who: Variant, line: String, seconds: float) -> void:
	speaker = who
	sprite = null
	head = Vector2.ZERO
	_age = 0.0
	_life = seconds
	visible = true
	scale = Vector2.ONE * POP_STEPS[0]
	if line != text or _lines.is_empty():
		text = line
		_lines = wrap_line(line)
		var widest: int = 0
		for each: String in _lines:
			widest = maxi(widest, _width(each))
		var inside := Vector2i(widest, _lines.size() * UiText.LINE_HEIGHT)
		var panel := Vector2(
			maxi(inside.x + 2 * PAD_X + 2, 2 * (CORNER + TAIL_HALF) + 1),
			inside.y + PAD_TOP + PAD_BOTTOM + 2
		)
		size = panel
		tail.position.y = panel.y - 1
		redraws += 1
		queue_redraw()


## Moves it on by [param delta] seconds: false once its life is over.
func advance(delta: float) -> bool:
	_age += delta
	if _age >= _life:
		return false
	var step: int = int(_age / (POP_TIME / POP_STEPS.size()))
	var popped: float = POP_STEPS[step] if step < POP_STEPS.size() else 1.0
	if scale.x != popped:
		scale = Vector2.ONE * popped
	var left: float = _life - _age
	visible = left > FxText.BLINK_TIME or int(left / FxText.BLINK_STEP) % 2 == 0
	return true


## Puts its tail's tip at [param at] (UI pixels), its panel above it, slid sideways to stay within
## [param room] and lifted [param lift] pixels more.
func place(at: Vector2, room: Vector2, lift: float = 0.0) -> void:
	var tip_at: Vector2 = at.round()
	var left: float = clampf(tip_at.x - floorf(size.x / 2.0), 0.0, maxf(room.x - size.x, 0.0))
	var top: float = maxf(tip_at.y - size.y - TAIL_DROP - lift, 0.0)
	var column: float = clampf(
		tip_at.x - left, CORNER + TAIL_HALF, size.x - 1.0 - CORNER - TAIL_HALF
	)
	var moved_to := Vector2(left, top)
	if position != moved_to:
		position = moved_to
	if tail.position.x != column - TAIL_HALF:
		tail.position.x = column - TAIL_HALF
	_tip = moved_to + Vector2(column + 0.5, size.y + TAIL_DROP)
	if scale.x != 1.0:
		pivot_offset = _tip - moved_to


## Where its tail's tip is, in its parent's UI pixels (where it was last placed).
func tip() -> Vector2:
	return _tip


## The panel and its tail, in its parent's UI pixels.
func reach() -> Rect2:
	return Rect2(position, size + Vector2(0, TAIL_DROP))


## The line as it is shown, one entry a line.
func lines() -> PackedStringArray:
	return _lines


## [param line] broken between words so no line is wider than [constant WIDTH], on at most
## [constant MOST_LINES] lines, the last cut short with [constant MORE] if it does not all fit. A
## word wider than a line is cut between its letters.
static func wrap_line(line: String) -> PackedStringArray:
	var wrapped := PackedStringArray()
	var current: String = ""
	var current_width: int = 0
	var cut_short: bool = false
	for word: String in line.split(" ", false):
		var word_width: int = _width(word)
		while word_width > WIDTH:  # a word wider than a line: as much of it as fits
			var part: String = _fitting(word, WIDTH)
			if not current.is_empty():
				wrapped.append(current)
			wrapped.append(part)
			current = ""
			current_width = 0
			word = word.substr(part.length())
			word_width = _width(word)
		var with_space: int = current_width + UiText.SPACE_ADVANCE + word_width
		if current.is_empty():
			current = word
			current_width = word_width
		elif with_space <= WIDTH:
			current += " " + word
			current_width = with_space
		else:
			wrapped.append(current)
			current = word
			current_width = word_width
		if wrapped.size() >= MOST_LINES:
			cut_short = true
			break
	if not current.is_empty() and wrapped.size() < MOST_LINES:
		wrapped.append(current)
	elif not current.is_empty():
		cut_short = true
	if wrapped.size() > MOST_LINES:
		wrapped.resize(MOST_LINES)
	if cut_short:
		var last: int = wrapped.size() - 1
		wrapped[last] = _fitting(wrapped[last], WIDTH - _width(MORE)).strip_edges() + MORE
	return wrapped


## How wide [param words] are in the UI font: every measurement a bubble makes.
static func _width(words: String) -> int:
	measures += 1
	return UiText.width(words)


## The longest start of [param words] no wider than [param most].
static func _fitting(words: String, most: int) -> String:
	var length: int = words.length()
	while length > 1 and _width(words.left(length)) > most:
		length -= 1
	return words.left(length)


static func _colours() -> void:
	if _fill.a > 0.0:
		return
	var look: StyleBoxFlat = UiTheme.theme().get_stylebox(&"panel", UiTheme.WINDOW) as StyleBoxFlat
	_fill = look.bg_color if look != null else Palette.color(&"night")
	_edge = look.border_color if look != null else Palette.color(&"steel")


func _draw() -> void:
	_colours()
	var w: float = size.x
	var h: float = size.y
	# A panel with its corners cut off: the fill, then a one-pixel edge round it.
	draw_rect(Rect2(1, CORNER, w - 2, h - 2 * CORNER), _fill)
	draw_rect(Rect2(CORNER, 1, w - 2 * CORNER, h - 2), _fill)
	draw_rect(Rect2(CORNER, 0, w - 2 * CORNER, 1), _edge)
	draw_rect(Rect2(CORNER, h - 1, w - 2 * CORNER, 1), _edge)
	draw_rect(Rect2(0, CORNER, 1, h - 2 * CORNER), _edge)
	draw_rect(Rect2(w - 1, CORNER, 1, h - 2 * CORNER), _edge)
	for corner: Vector2 in [
		Vector2(1, 1), Vector2(w - 2, 1), Vector2(1, h - 2), Vector2(w - 2, h - 2)
	]:
		draw_rect(Rect2(corner, Vector2.ONE), _edge)
	var font: Font = UiText.font()
	var ink: Color = Palette.color(&"white")
	for index: int in _lines.size():
		var baseline: float = 1 + PAD_TOP + UiText.ASCENT + index * UiText.LINE_HEIGHT
		var at := Vector2(1 + PAD_X, baseline)
		draw_string(font, at, _lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, UiText.SIZE, ink)


## The tail: a small triangle pointing down, its top row over the panel's bottom edge so the two
## join. Drawn once; the bubble only moves it.
class _Tail:
	extends Control

	func _draw() -> void:
		SpeechBubble._colours()
		var half: int = SpeechBubble.TAIL_HALF
		for row: int in SpeechBubble.TAIL_DROP + 1:
			var reach_x: int = half - row
			if reach_x > 0:
				draw_rect(Rect2(half - reach_x + 1, row, 2 * reach_x - 1, 1), SpeechBubble._fill)
			draw_rect(Rect2(half - reach_x, row, 1, 1), SpeechBubble._edge)
			draw_rect(Rect2(half + reach_x, row, 1, 1), SpeechBubble._edge)

class_name GoalRow
extends Button
## One goal on the sharp layer: a button drawn by the theme with a
## dot (a tick once achieved), the goal's sentence and, under it, a thin bar with the count at its
## right; a goal with no bar shows its count (a price) at the sentence's right, and a goal the
## player can act on now a small [code]>[/code] at the row's right edge. A left click emits
## [signal Button.pressed]; a finished goal is disabled, so it is neither lit nor clicked, and it
## flashes then shows its tick in green.

## A line of text's height, the bar's height and the gap under the sentence, in UI pixels.
const LINE: float = UiText.LINE_HEIGHT
const BAR_HEIGHT: float = 6.0
## Space inside the row's edge, and where the sentence starts after the dot.
const PAD: float = 5.0
const TEXT_X: float = 16.0
## UI pixels between the bar and the count after it, and between the sentence and a price.
const DETAIL_GAP: float = 6.0
## The bar's least width.
const MIN_BAR: float = 90.0
## The bar's colours for each kind of goal: XP and levels in cyan, depth in yellow.
const BAR_COLOURS: Dictionary[Goals.Kind, Array] = {
	Goals.Kind.GUARDIAN: [&"cyan", &"blue"],
	Goals.Kind.DEPTH: [&"yellow", &"amber"],
	Goals.Kind.MICROSKILL: [&"cyan", &"blue"],
}
## A tick in 9x7 pixels, drawn in code: [code]#[/code] is green.
const TICK: Array[String] = [
	"........#",
	".......##",
	"#.....##.",
	"##...##..",
	".##.##...",
	"..###....",
	"...#.....",
]
## The [code]>[/code] in 4x7 pixels, drawn in code: [code]#[/code] is yellow.
const ARROW: Array[String] = ["#...", "##..", ".##.", "..##", ".##.", "##..", "#..."]
## UI pixels the arrow takes at the row's right, with the gap before it.
const ARROW_ROOM: float = 10.0

var sentence_label: Label
## What the last drawing put where, by kind, in this control's own pixels (for tests).
var drawn: Dictionary[StringName, Array] = {}
var detail_label: Label

var _goal: Goals.Goal
var _bar: Rect2 = Rect2()
var _arrow: Rect2 = Rect2()


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	sentence_label = UiText.label("", &"white")
	sentence_label.name = "Sentence"
	sentence_label.position = Vector2(TEXT_X, PAD - 2.0)
	add_child(sentence_label)
	detail_label = UiText.label("", &"steel")
	detail_label.name = "Detail"
	add_child(detail_label)


## The row width [param goal] needs to show on one line, in UI pixels.
static func needed_width(goal: Goals.Goal) -> float:
	var run: float = TEXT_X + ink(goal.sentence)
	if goal.progress < 0.0:
		run += DETAIL_GAP + ink(goal.detail)
		if is_gold(goal):
			run += ARROW_ROOM
	else:
		run = maxf(run, TEXT_X + MIN_BAR + DETAIL_GAP + ink(goal.detail))
	return ceilf(run + PAD)


## How wide [param words] ink in the UI font, in UI pixels.
static func ink(words: String) -> float:
	return maxf(UiText.width(words) - UiText.SPACING, 0.0)


## True for a goal the player can act on now: talent points, training (with paragon points) and
## upgrades (with gold).
static func is_gold(goal: Goals.Goal) -> bool:
	return goal.kind in [Goals.Kind.TALENT, Goals.Kind.TRAINING, Goals.Kind.UPGRADE]


## Shows [param goal] across [param width] UI pixels, a bar ending [param detail_column] pixels
## (and a gap) before the right edge, so every bar on the panel ends in the same place.
func show_goal(goal: Goals.Goal, width: float, detail_column: float) -> void:
	_goal = goal
	var finished: bool = goal.celebrate > 0.0
	disabled = finished
	mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if finished else Control.CURSOR_POINTING_HAND
	)
	# White over the flash's bright fill, then green with the tick.
	var green: bool = finished and goal.flash <= Goals.FLASH_SECONDS / 2.0
	_show(sentence_label, goal.sentence, &"green" if green else &"white")
	var price: bool = is_gold(goal)
	_show(detail_label, goal.detail, &"yellow" if price else &"steel")
	var right: float = width - PAD
	_arrow = Rect2()
	if price:
		_arrow = Rect2(right - 4.0, PAD + 1.0, 4.0, 7.0)
		right -= ARROW_ROOM
	var detail_width: float = ink(goal.detail)
	if goal.progress >= 0.0:
		size = Vector2(width, PAD + LINE + BAR_HEIGHT + PAD)
		var bar_y: float = PAD + LINE
		detail_label.position = Vector2(
			right - detail_width, bar_y + floorf((BAR_HEIGHT - LINE) / 2.0) - 1.0
		)
		var bar_right: float = right
		if detail_column > 0.0:
			bar_right -= detail_column + DETAIL_GAP
		_bar = Rect2(TEXT_X, bar_y, maxf(bar_right - TEXT_X, MIN_BAR), BAR_HEIGHT)
	else:
		size = Vector2(width, PAD + LINE + PAD - 2.0)
		detail_label.position = Vector2(right - detail_width, PAD - 2.0)
		_bar = Rect2()
	custom_minimum_size = size
	queue_redraw()


## True while the row is lit under the mouse: shown, not finished.
func is_highlighted() -> bool:
	return is_visible_in_tree() and not disabled and is_hovered()


## Where the [code]>[/code] is drawn, in the row's own pixels; empty for others.
func arrow_rect() -> Rect2:
	return _arrow


## The goal's bar, in the row's own pixels; empty for a goal with none.
func bar_rect() -> Rect2:
	return _bar


func _draw() -> void:
	drawn = {}
	if _goal == null:
		return
	if _goal.flash > 0.0:
		var bright: bool = _goal.flash > Goals.FLASH_SECONDS / 2.0
		var fill: Color = Palette.color(&"forest" if bright else &"dusk")
		var edge: Color = Palette.color(&"green" if bright else &"slate")
		draw_rect(Rect2(Vector2.ZERO, size), edge)
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), fill)
	if _arrow.has_area():
		_draw_pixels(ARROW, _arrow.position, Palette.color(&"yellow"))
	var dot_y: float = PAD + 1.0
	if _goal.celebrate > 0.0:
		_draw_pixels(TICK, Vector2(4, dot_y), Palette.color(&"green"), &"tick")
	else:
		draw_rect(Rect2(6, dot_y + 2.0, 5, 5), Palette.color(&"steel"))
		draw_rect(Rect2(6, dot_y + 2.0, 5, 1), Palette.color(&"silver"))
	if not _bar.has_area():
		return
	var colours: Array = BAR_COLOURS.get(_goal.kind, [&"yellow", &"amber"])
	if _goal.celebrate > 0.0:
		colours = [&"green", &"forest"]
	var colour: StringName = colours[0]
	var shade: StringName = colours[1]
	_draw_bar(Palette.color(colour), Palette.color(shade))


## The goal's bar in [param colour] with its [param shade] on an ink track, noted in
## [member drawn].
func _draw_bar(colour: Color, shade: Color) -> void:
	UiBar.draw_bar(self, _bar, _goal.progress, colour, shade, Palette.color(&"ink"))
	drawn[&"bar"] = [_bar]


## Draws [param pixels] ([code]#[/code] in [param colour]) at [param at], with an ink shadow a pixel
## below; noted in [member drawn] as [param kind] unless that is empty.
func _draw_pixels(
	pixels: Array[String], at: Vector2, colour: Color, kind: StringName = &""
) -> void:
	if kind != &"":
		drawn[kind] = [Rect2(at, Vector2(pixels[0].length(), pixels.size() + 1))]
	for y: int in pixels.size():
		for x: int in pixels[y].length():
			if pixels[y][x] == "#":
				draw_rect(Rect2(at + Vector2(x, y + 1), Vector2.ONE), Palette.color(&"ink"))
	for y: int in pixels.size():
		for x: int in pixels[y].length():
			if pixels[y][x] == "#":
				draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), colour)


## Shows [param words] on [param label], sized to them, in the palette colour [param colour].
static func _show(label: Label, words: String, colour: StringName) -> void:
	WindowText.set_text(label, words)
	label.add_theme_color_override(&"font_color", Palette.color(colour))
